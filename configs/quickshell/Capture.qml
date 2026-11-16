// Capture.qml — screenshot / screen-record helpers, shared by the dashboard and the bar.
// Uses your scripts in ~/.config/scripts (screenshot.sh, screenrecord.sh).
// Recording state comes from a file screenrecord.sh writes ("1" / "0"), watched with
// inotify, so nothing polls.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  readonly property string scriptDir: Quickshell.env("HOME") + "/.config/scripts"
  readonly property string stateFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/recording-state"
  property bool isRecording: false

  // make sure the file exists (so it can be watched), then start watching it
  Process {
    running: true
    command: ["sh", "-c", "[ -e \"$1\" ] || echo 0 > \"$1\"", "sh", root.stateFile]
    onExited: state.path = root.stateFile
  }
  FileView {
    id: state
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.isRecording = text().trim() === "1"
    onLoadFailed: root.isRecording = false
  }

  // Run a command a moment later, so the dashboard has time to close
  // and is not in the screenshot.
  property var pending: []
  Timer {
    id: delay
    interval: 250
    onTriggered: Quickshell.execDetached(root.pending)
  }
  function run(args) {
    root.pending = args
    delay.restart()
  }
  function screenshot(mode) { run([scriptDir + "/screenshot.sh", mode]) }
  function toggleRecording() { Quickshell.execDetached([scriptDir + "/screenrecord.sh", "toggle"]) }
}
