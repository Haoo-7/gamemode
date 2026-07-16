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
import LunarLtk.Models.Popups

GraphicsBox {
  id: root

  required property ChooseGeneralModel dataModel
  readonly property var roomScene: Ltk.roomScene

  property var friends: []
  property var friendsVote: ({})
  property int timeout: Config.roomTimeout
  
  property int updateHook: 1
  property int updateHook2: 1

  readonly property var friendsAvatar: {
    const ret = {};
    ret[Lua.selfPlayer.id] = Lua.evaluate(`ClientInstance:getPlayerById(${Lua.selfPlayer.id}).player:getAvatar()`);
    friends.forEach(e =>
      ret[e] = Lua.evaluate(`ClientInstance:getPlayerById(${e}).player:getAvatar()`)
    )
    return ret;
  }

  Connections {
    target: root.dataModel
    function onGeneralChanged(idx, newname) {
      ClientInstance.notifyServer("PushRequest", "updatemini,changeGeneral," + idx + "," + newname);
      root.updateHook2 = (root.updateHook2 + 1) % 10000;
    }
  }
  
  title.text: dataModel.promptText

  width: 40 + 120 * Math.min(dataModel.generals.length, 8)
  height: 300

  RowLayout {
    id: delerow
    spacing: 20
    anchors.top: root.title.bottom
    anchors.topMargin: 20
    Layout.fillWidth: true
    anchors.horizontalCenter: parent.horizontalCenter

    Repeater {
      id: cardRepeater
      model: {
        root.updateHook2;
        return root.dataModel.generals
      }

      delegate: Column {
        required property string modelData
        required property int index
        Layout.fillHeight: true
        spacing: 5
        id: generalVoteItem

        GeneralCardItem {
          dataModel: root.dataModel.generalDict[parent.index]
          selectable: true
          draggable: false
          chosenInBox: root.dataModel.resultInt[0] === parent.index

          onClicked: {
            if (!selectable) return;
            root.dataModel.resultInt.pop();
            root.dataModel.selectGeneralCard(parent.index);
            ClientInstance.notifyServer("PushRequest", "updatemini,vote," + Lua.selfPlayer.id + "," + parent.index);
          }

          onRightClicked: {
            if (Lua.client.getSettings("enableFreeAssign")) {
              root.roomScene.showInfoPopup(Qt.createComponent("LunarLtk.Pages.InfoPopups", "FreeAssign"),
                { dataModel: root.dataModel, index: parent.index });
            } else {
              root.roomScene.showInfoPopup(Qt.createComponent("LunarLtk.Pages.InfoPopups", "GeneralDetail"),
                { generals: [root.dataModel.generals[parent.index]] });
            }
          }
        }

        Row {
          id: voteRow
          spacing: -15
          Layout.fillWidth: true
          anchors.horizontalCenter: parent.horizontalCenter

          Repeater {
            id: voteRepeater
            model: {
              // Re-evaluate when vote data is mutated in-place.
              root.updateHook;
              return root.getVote(generalVoteItem.index);
            }
            delegate: Avatar {
              required property string modelData
              width: 32
              height: 32
              general: modelData
            }
          }

          Text {
            id: numObverser
            Layout.leftMargin: 30
            visible: voteRepeater.count > 0
            text: "X" + voteRepeater.count;
            color: "#E4D5A0"
            font.family: Config.libianName
            font.pixelSize: 32
          }
        }
      }
    }
  }

  ProgressBar {
    id: progress
    implicitWidth: root.width - 80
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 30 + infoButton.height
    anchors.leftMargin: 40
    anchors.rightMargin: 40
    from: 0.0
    to: 100.0

    background: Rectangle {
      implicitWidth: 200
      implicitHeight: 12
      color: "black"
      radius: 6
    }

    contentItem: Item {
      implicitWidth: 196
      implicitHeight: 10

      Rectangle {
        width: progress.visualPosition * parent.width
        height: parent.height
        radius: 6
        gradient: Gradient {
          GradientStop { position: 0.0; color: "orange" }
          GradientStop { position: 0.3; color: "red" }
          GradientStop { position: 0.7; color: "red" }
          GradientStop { position: 1.0; color: "orange" }
        }
      }
    }

    NumberAnimation on value {
      id: progressAnim
      running: progress.visible
      from: 100.0
      to: 0.0
      duration: root.timeout * 1000

      onFinished: {
        root.dataModel.accepted();
      }
    }
  }

  MetroButton {
    id: infoButton
    text: Lua.tr("Info")
    anchors.horizontalCenter: progress.horizontalCenter
    anchors.top: progress.bottom
    anchors.topMargin: 10
    onClicked: {
      let results = root.dataModel.result
      if (results.length === 0) {
        results = root.dataModel.generals;
      }
      root.roomScene.showInfoPopup(Qt.createComponent("LunarLtk.Pages.InfoPopups", "GeneralDetail"),
        { generals: results });
    }
  }

  function getVote(id) {
    let ret = [];
    for (let [key, value] of Object.entries(friendsVote)) {
      if (value == id) {
        ret.push(key);
      }
    }
    if (root.dataModel.resultInt.includes(id)) {
      ret.push(Lua.selfPlayer.id);
    }
    return ret.map(e => friendsAvatar[e]);
  }

  function updateData(data) {
    let type = data[0];
    let value = data.slice(1);
    value = value ?? -1;
    if (type == "vote") {
      friendsVote[value[0]] = value[1];
      // 别问，这是神秘更新召唤函数
      root.updateHook = (root.updateHook + 1) % 10000;
    } else if (type == "changeGeneral") {
      const [idx, newname] = value;
      if (root.dataModel.generals[idx] !== newname)
        root.dataModel.changeGeneral(idx, Ltk.createGeneralCardModel(newname));
    }
  }
}
