// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Fk
import Fk.Components.Common
import LunarLtk
import LunarLtk.Components
import LunarLtk.Pages.Popups

// 2v2 十周年禁将BP：全屏禁将页面
// 轮询顺序 3、1、4、2 号位；第一次点击选中（忠臣黄/反贼绿），再次点击同一武将禁将（灰遮罩+禁）
GraphicsBox {
  id: root

  readonly property var roomScene: Ltk.roomScene

  property var pool: []
  property var banned: []
  property int turnId: -1
  property int banNum: 2
  property int reserveNum: 5
  property int timeout: 30
  property string myRole: "loyalist"
  property int selfId: -1
  property int selectedIdx: -1
  property bool autoTurn: false

  movable: false
  width: roomScene.width
  height: roomScene.height

  title.text: Lua.tr("2v2_bp_title")

  ColumnLayout {
    anchors.fill: parent
    anchors.leftMargin: 16
    anchors.rightMargin: 16
    anchors.topMargin: 34
    anchors.bottomMargin: 12
    spacing: 8

    // 倒计时（弹窗中间最上方，含数字倒计时）
    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: 28

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: Lua.tr("2v2_bp_banning")
          color: "#E4D5A0"
          font.pixelSize: 16
        }

        Text {
          id: countdownText
          anchors.verticalCenter: parent.verticalCenter
          text: Math.max(0, Math.ceil(progress.value / 100 * root.effectiveTimeout())) + "s"
          color: "white"
          font.pixelSize: 22
          font.bold: true
        }

        ProgressBar {
          id: progress
          anchors.verticalCenter: parent.verticalCenter
          width: 260
          height: 12
          from: 0
          to: 100
          value: 100

          background: Rectangle {
            implicitHeight: 12
            color: "black"
            radius: 6
          }

          contentItem: Rectangle {
            radius: 6
            gradient: Gradient {
              GradientStop { position: 0.0; color: "orange" }
              GradientStop { position: 1.0; color: "red" }
            }
          }
        }

        NumberAnimation {
          id: countdownAnim
          target: progress
          property: "value"
          from: 100
          to: 0
          running: false

          onFinished: {
            // 所有客户端都会触发；服务端只处理当前禁将者的 timeout
            ClientInstance.notifyServer("PushRequest", "updatemini,timeout");
          }
        }
      }
    }

    // 武将头像网格区域
    Item {
      id: gridArea
      Layout.fillWidth: true
      Layout.fillHeight: true

      Grid {
        id: generalGrid
        anchors.fill: parent
        columns: Math.max(1, Math.ceil(root.pool.length / root.calcRows(root.pool.length)))
        columnSpacing: 0
        rowSpacing: 0

        Repeater {
          model: root.pool

          delegate: Item {
            required property string modelData
            required property int index
            readonly property bool isBanned: root.banned.includes(modelData)
            readonly property bool isSelected: root.selectedIdx === index
            width: gridArea.width / generalGrid.columns
            height: gridArea.height / root.calcRows(root.pool.length)

            GeneralCardItem {
              id: card
              anchors.centerIn: parent
              width: 93
              height: 130
              dataModel: Ltk.createGeneralCardModel(modelData)
              selectable: true
              scale: Math.min(parent.width / 93, parent.height / 130)
              transformOrigin: Item.Center

              // 选中边框：loyalist 黄色，rebel 绿色
              Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: 3
                border.color: root.myRole === "loyalist" ? "#FFD700" : "#4CAF50"
                visible: isSelected
                z: 4
              }

              // 禁将遮罩 + 禁字
              Rectangle {
                anchors.fill: parent
                color: "#555555"
                opacity: 0.6
                visible: isBanned
                z: 5
              }

              Text {
                text: "禁"
                color: "red"
                font.pixelSize: 42
                font.bold: true
                style: Text.Outline
                styleColor: "black"
                anchors.centerIn: parent
                visible: isBanned
                z: 6
              }

              onClicked: {
                if (root.selfId !== root.turnId) return; // 非自己的禁将回合
                if (isBanned) return;                     // 已被禁的武将不可再选
                if (isSelected) {
                  // 第二次点击同一武将：确认禁将
                  root.selectedIdx = -1;
                  ClientInstance.notifyServer("PushRequest", "updatemini,ban," + modelData);
                } else {
                  // 第一次点击：选中（切换选中目标）
                  root.selectedIdx = index;
                }
              }

              // 右键或长按弹出武将技能详情
              onRightClicked: {
                root.roomScene.showInfoPopup(
                  Qt.createComponent("LunarLtk.Pages.InfoPopups", "GeneralDetail"),
                  { generals: [modelData] });
              }
            }
          }
        }
      }
    }

    // 玩家信息栏：头像 + 名称 + 汉字座位号，当前禁将者高亮
    Row {
      id: playerBar
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredHeight: 132
      spacing: 48

      Repeater {
        model: {
          const order = [3, 1, 4, 2]; // 按禁将轮询顺序排列
          const ps = [];
          const players = root.roomScene.dataModel.players;
          for (let i = 0; i < players.length; i++) {
            ps.push(players[i]);
          }
          ps.sort((a, b) => order.indexOf(a.seatNumber) - order.indexOf(b.seatNumber));
          return ps;
        }

        delegate: Column {
          required property var modelData
          spacing: 0
          width: 90

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Lua.tr("2v2_bp_banning")
            visible: modelData.playerid === root.turnId
            font.pixelSize: 11
            color: "#FFD700"
            style: Text.Outline
            styleColor: "black"
          }

          Rectangle {
            id: avatarFrame
            width: 64
            height: 64
            anchors.horizontalCenter: parent.horizontalCenter
            radius: 6
            color: "#1E1E1E"
            border.width: 3
            // 边框按身份：忠臣（1、4号位）土黄，反贼（2、3号位）绿
            border.color: (modelData.seatNumber === 1 || modelData.seatNumber === 4) ? "#C4A255" : "#4CAF50"

            Avatar {
              anchors.fill: parent
              anchors.margins: 3
              general: modelData.avatar
            }
          }

          GlowText {
            id: playerName
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            text: modelData.screenName
            font.pixelSize: 14
            elide: Text.ElideMiddle
            horizontalAlignment: Qt.AlignHCenter
            glow.radius: 6
          }

          GlowText {
            id: seatNum
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
              const seatChr = [
                "一", "二", "三", "四", "五", "六",
                "七", "八", "九", "十", "十一", "十二",
              ]
              return seatChr[modelData.seatNumber - 1];
            }
            font.family: Config.li2Name
            font.pixelSize: 24
            glow.color: "brown"
            glow.spread: 0.2
            glow.radius: 6
          }
        }
      }
    }
  }

  function calcRows(count) {
    return count > 30 ? 4 : 3;
  }

  // 机器人/离线回合使用 2 秒倒计时，真人回合使用禁将时间
  function effectiveTimeout() {
    return root.autoTurn ? 2 : root.timeout;
  }

  function restartCountdown() {
    countdownAnim.stop();
    progress.value = 100;
    countdownAnim.duration = root.effectiveTimeout() * 1000;
    countdownAnim.start();
  }

  function loadData(data) {
    // 全屏铺满：修正 showPopup 的居中偏移
    root.x = 0;
    root.y = 0;
    root.pool = data.generals ?? [];
    root.banned = data.banned ?? [];
    root.turnId = data.turnId ?? -1;
    root.autoTurn = data.autoTurn ?? false;
    root.banNum = data.banNum ?? 2;
    root.reserveNum = data.reserveNum ?? 5;
    root.timeout = data.timeout ?? 30;
    root.myRole = data.myRole ?? "loyalist";
    root.selfId = data.selfId ?? -1;
    root.selectedIdx = -1;
    root.restartCountdown();
  }

  function updateData(data) {
    const type = data[0];
    if (type === "state") {
      const st = data[1];
      root.pool = st.generals;
      root.banned = st.banned;
      root.turnId = st.turnId;
      root.autoTurn = st.autoTurn ?? false;
      root.selectedIdx = -1;
      root.restartCountdown();
    } else if (type === "finished") {
      // 所有队伍轮询禁将完毕，回复并关闭本窗口
      ClientInstance.replyToServer("", "");
      root.close();
    }
  }
}
