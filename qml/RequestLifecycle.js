.pragma library

// Legacy mini-games must finish through the current room's request model.
// Setting Item.state alone does not reset the request UI in current clients.
function finish(room, popup, observer, sendReply, result) {
  if (observer) {
    popup.finished();
    return;
  }

  const model = room.dataModel;
  if (model && typeof model.replyToServer === "function") {
    model.replyToServer(result);
  } else {
    // Older room pages use state transitions to clean up the request.
    popup.finished();
    room.state = "notactive";
    sendReply(result);
  }
}
