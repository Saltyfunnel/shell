import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Window

Item {
  id: root

  property string homeDir: "/home/" + Quickshell.env("USER")
  property string screenshotScript: homeDir + "/.config/scripts/screenshot.sh"
  property string recorderScript: homeDir + "/.config/scripts/recorder.sh"
  property bool isRecording: false
  property bool menuOpen: false

  implicitWidth: 32
  implicitHeight: 24

  // Check recording status every 1 second
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
    onExited: (exitCode, exitStatus) => {
      root.isRecording = (exitCode === 0);
    }
  }

  // Bar Trigger Icon
  Rectangle {
    anchors.fill: parent
    color: "transparent"

    Text {
      id: iconLabel
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
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        root.menuOpen = !root.menuOpen;
        console.log(">>> ScreenCapture icon clicked! menuOpen is now:", root.menuOpen);
      }
    }
  }

  // Full-Screen Centered Floating Overlay PanelWindow
  PanelWindow {
    id: popupMenu
    visible: root.menuOpen
    focusable: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    onVisibleChanged: {
      if (visible) {
        popupMenu.requestActivate();
      }
    }

    // Transparent backdrop to close menu when clicking outside
    Rectangle {
      anchors.fill: parent
      color: "transparent"

      TapHandler {
        onTapped: {
          root.menuOpen = false;
        }
      }

      // Polished Floating Action Card Menu
      Rectangle {
        id: menuCard
        anchors.centerIn: parent
        width: 280
        height: 310
        radius: 16
        color: Colors.surface
        border.color: Colors.accent
        border.width: 1.2
        clip: true

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.AllButtons
        }

        Column {
          anchors.fill: parent
          anchors.margins: 18
          spacing: 8

          // Header Title
          Row {
            width: parent.width
            height: 30
            spacing: 10

            Text {
              text: "󰄀"
              color: Colors.accent
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 18
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              text: "Capture & Record"
              color: Colors.text
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 15
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          // Subtle Divider
          Item {
            width: parent.width
            height: 6
            Rectangle {
              anchors.centerIn: parent
              width: parent.width
              height: 1
              color: Colors.accent
              opacity: 0.2
            }
          }

          // 1. Screenshot Area
          Rectangle {
            width: parent.width
            height: 38
            radius: 10
            color: areaMouse.containsMouse ? Colors.card : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }
            Row {
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              spacing: 14
              Text { text: "󰩭"; color: Colors.accent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter }
              Text { text: "Screenshot Area"; color: Colors.text; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
              id: areaMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.menuOpen = false;
                Quickshell.execDetached([root.screenshotScript, "area"]);
              }
            }
          }

          // 2. Screenshot Window
          Rectangle {
            width: parent.width
            height: 38
            radius: 10
            color: windowMouse.containsMouse ? Colors.card : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }
            Row {
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              spacing: 14
              Text { text: "󱂬"; color: Colors.accent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter }
              Text { text: "Screenshot Window"; color: Colors.text; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
              id: windowMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.menuOpen = false;
                Quickshell.execDetached([root.screenshotScript, "window"]);
              }
            }
          }

          // 3. Fullscreen (3s Delay)
          Rectangle {
            width: parent.width
            height: 38
            radius: 10
            color: delayMouse.containsMouse ? Colors.card : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }
            Row {
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              spacing: 14
              Text { text: "󰔟"; color: Colors.accent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter }
              Text { text: "Fullscreen (3s Delay)"; color: Colors.text; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
              id: delayMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.menuOpen = false;
                Quickshell.execDetached([root.screenshotScript, "screen"]);
              }
            }
          }

          // 4. Fullscreen (Instant)
          Rectangle {
            width: parent.width
            height: 38
            radius: 10
            color: instantMouse.containsMouse ? Colors.card : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }
            Row {
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              spacing: 14
              Text { text: "󰹑"; color: Colors.accent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter }
              Text { text: "Fullscreen (Instant)"; color: Colors.text; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
              id: instantMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.menuOpen = false;
                Quickshell.execDetached([root.screenshotScript, "screen-nodelay"]);
              }
            }
          }

          // Divider before recorder
          Item {
            width: parent.width
            height: 6
            Rectangle {
              anchors.centerIn: parent
              width: parent.width
              height: 1
              color: Colors.accent
              opacity: 0.2
            }
          }

          // 5. Recorder Toggle
          Rectangle {
            width: parent.width
            height: 38
            radius: 10
            color: recorderMouse.containsMouse ? Colors.card : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }
            Row {
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              spacing: 14
              Text { text: "󰑊"; color: root.isRecording ? "#FF5555" : Colors.accent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter }
              Text { text: root.isRecording ? "Stop Recording" : "Record Screen"; color: Colors.text; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
              id: recorderMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.menuOpen = false;
                Quickshell.execDetached([root.recorderScript]);
              }
            }
          }
        }
      }
    }
  }
}
