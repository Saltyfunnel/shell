// ScreenCaptureModule.qml — camera icon in the bar + a Capture & Record card.
// Joins the shared popup system (openPopup / toggle) like every other card.
import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: root

  property string popupName: "capture"
  property string openPopup: ""
  signal toggle(string name)
  property alias popup: card        // shell.qml's focus grab uses this

  property string scriptDir: Quickshell.env("HOME") + "/.config/scripts"
  property bool isRecording: false

  implicitWidth: 32
  implicitHeight: 24

  // Close the card FIRST so it is not in the screenshot, then run the script.
  function run(args) {
    root.toggle(root.popupName)
    Quickshell.execDetached(args)
  }

  // ---------- recording status: is wf-recorder running? ----------
  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: checkStatus.running = true
  }

  Process {
    id: checkStatus
    command: ["pgrep", "-x", "wf-recorder"]
    onExited: (exitCode, exitStatus) => root.isRecording = (exitCode === 0)
  }

  // ---------- bar icon (red and pulsing while recording) ----------
  Text {
    anchors.centerIn: parent
    color: root.isRecording ? "#FF5555" : Colors.text
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 15
    text: root.isRecording ? "󰑊" : "󰄀"

    SequentialAnimation on opacity {
      running: root.isRecording
      loops: Animation.Infinite
      NumberAnimation { to: 0.4; duration: 600 }
      NumberAnimation { to: 1.0; duration: 600 }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.toggle(root.popupName)
    }
  }

  // ---------- the card ----------
  OverlayCard {
    id: card
    shown: root.openPopup === root.popupName
    cardWidth: 280
    cardHeight: 330
    cardRadius: 16
    onDismissed: root.toggle(root.popupName)

    Column {
      anchors.fill: parent
      anchors.margins: 18
      spacing: 8

      MenuHeader { icon: "󰄀"; title: "Capture & Record" }
      MenuDivider {}

      MenuRow { icon: "󰩭"; label: "Screenshot Area";        onClicked: root.run([root.scriptDir + "/screenshot.sh", "area"]) }
      MenuRow { icon: "󱂬"; label: "Screenshot Window";      onClicked: root.run([root.scriptDir + "/screenshot.sh", "window"]) }
      MenuRow { icon: "󰔟"; label: "Fullscreen (3s Delay)";  onClicked: root.run([root.scriptDir + "/screenshot.sh", "screen"]) }
      MenuRow { icon: "󰹑"; label: "Fullscreen (Instant)";   onClicked: root.run([root.scriptDir + "/screenshot.sh", "screen-nodelay"]) }

      MenuDivider {}

      MenuRow {
        icon: "󰑊"
        iconColor: root.isRecording ? "#FF5555" : Colors.accent
        label: root.isRecording ? "Stop Recording" : "Record Screen"
        onClicked: root.run([root.scriptDir + "/screenrecord.sh", "toggle"])
      }
    }
  }
}
