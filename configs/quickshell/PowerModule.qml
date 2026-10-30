import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Window

Item {
  id: root

  property string popupName: "power"
  property string openPopup: ""
  signal toggle(string name)
  property alias popup: popupWindow

  property bool isVisible: root.openPopup === root.popupName

  implicitWidth: 32
  implicitHeight: 24

  // Bar Icon Trigger
  Rectangle {
    anchors.fill: parent
    color: "transparent"

    Text {
      anchors.centerIn: parent
      color: Colors.accent
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 15
      text: "󰐥"
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        root.toggle(root.popupName);
      }
    }
  }

  // Full-Screen Centered Floating Overlay PanelWindow
  PanelWindow {
    id: popupWindow
    visible: root.isVisible
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
        popupWindow.requestActivate();
      }
    }

    // Transparent backdrop to close menu when clicking outside
    Rectangle {
      anchors.fill: parent
      color: "transparent"

      TapHandler {
        onTapped: {
          root.toggle(root.popupName);
        }
      }

      // Centered Floating Power Card Menu
      Rectangle {
        id: menuCard
        anchors.centerIn: parent
        width: 260
        height: 280
        radius: 18
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
          anchors.margins: 20
          spacing: 10

          // Header Title
          Row {
            width: parent.width
            height: 30
            spacing: 10

            Text {
              text: "󰐥"
              color: Colors.accent
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 18
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              text: "Session"
              color: Colors.text
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 16
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

          // Option 1: Lock Screen
          PowerButton {
            icon: "󰌾"
            label: "Lock"
            actionCmd: "pidof hyprlock || hyprlock"
            onTriggered: {
              root.toggle(root.popupName);
            }
          }

          // Option 2: Logout / Exit Hyprland
          PowerButton {
            icon: "󰍃"
            label: "Logout"
            actionCmd: "hyprctl dispatch exit"
            onTriggered: {
              root.toggle(root.popupName);
            }
          }

          // Option 3: Reboot
          PowerButton {
            icon: "󰜉"
            label: "Reboot"
            actionCmd: "systemctl reboot"
            onTriggered: {
              root.toggle(root.popupName);
            }
          }

          // Option 4: Shutdown
          PowerButton {
            icon: "󰐥"
            label: "Shutdown"
            actionCmd: "systemctl poweroff"
            onTriggered: {
              root.toggle(root.popupName);
            }
          }
        }
      }
    }
  }

  // Reusable Power Row Component
  component PowerButton: Rectangle {
    property string icon: ""
    property string label: ""
    property string actionCmd: ""
    signal triggered()

    width: parent.width
    height: 38
    radius: 10
    color: btnMouse.containsMouse ? Colors.card : "transparent"
    Behavior on color { ColorAnimation { duration: 100 } }

    Row {
      anchors.fill: parent
      anchors.leftMargin: 12
      anchors.rightMargin: 12
      spacing: 14

      Text {
        text: parent.parent.icon
        color: Colors.accent
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 16
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        text: parent.parent.label
        color: Colors.text
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 13
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    MouseArea {
      id: btnMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        triggered();
        Quickshell.execDetached(["sh", "-c", parent.actionCmd]);
      }
    }
  }
}
