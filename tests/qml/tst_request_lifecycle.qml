import QtQuick
import QtTest
import "../../qml/RequestLifecycle.js" as RequestLifecycle

TestCase {
  id: testCase
  name: "MiniGameRequestLifecycle"
  property var events: []

  QtObject {
    id: popup
    property int finishes: 0
    function finished() {
      finishes++;
      testCase.events.push("finished");
    }
  }

  QtObject {
    id: requestModel
    property var lastReply
    property bool active: true
    function replyToServer(result) {
      lastReply = result;
      testCase.events.push("reply");
      // Current RoomModel.replyToServer invokes deActivate after sending.
      active = false;
      testCase.events.push("deActivate");
      popup.finished();
    }
  }

  QtObject {
    id: modernRoom
    property var dataModel: requestModel
    property string state: ""
  }

  QtObject {
    id: legacyRoom
    property string state: "active"
  }

  function init() {
    events = [];
    popup.finishes = 0;
    requestModel.active = true;
    requestModel.lastReply = undefined;
    legacyRoom.state = "active";
  }

  function unexpectedReply() { fail("Unexpected direct native reply"); }

  function test_default_interface() {
    RequestLifecycle.finish(modernRoom, popup, false, unexpectedReply, "tymou__simayi");
    compare(requestModel.lastReply, "tymou__simayi");
    compare(requestModel.active, false);
    compare(popup.finishes, 1);
    compare(events, ["reply", "deActivate", "finished"]);
    // The next skill request starts with the old mini-game already deactivated.
    requestModel.active = true;
    compare(popup.finishes, 1);
  }

  function test_bp_and_reserve() {
    RequestLifecycle.finish(modernRoom, popup, false, unexpectedReply, "");
    compare(requestModel.lastReply, "");
    compare(requestModel.active, false);
    compare(popup.finishes, 1);
  }

  function test_legacy_interface() {
    RequestLifecycle.finish(legacyRoom, popup, false, result => {
      compare(legacyRoom.state, "notactive");
      compare(popup.finishes, 1);
      compare(result, "legacy_general");
      events.push("reply");
    }, "legacy_general");
    compare(events, ["finished", "reply"]);
  }

  function test_observer_never_replies() {
    RequestLifecycle.finish(modernRoom, popup, true, unexpectedReply, "");
    compare(popup.finishes, 1);
    compare(requestModel.active, true);
    compare(requestModel.lastReply, undefined);
  }
}
