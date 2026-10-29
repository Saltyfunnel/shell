// shell.qml — the entry point. Quickshell loads this file first.
// Layout: workspaces + window title on the left, clock in the middle, status modules on the right.
import Quickshell
import QtQuick

ShellRoot {
  id: root

  // Only ONE card can be open at a time. "" means none are open.
  // A module calls toggle("volume") -> opens its card, or closes it if already open.
  property string openPopup: ""
  function toggle(name) { openPopup = (openPopup === name) ? "" : name }

  // One bar per monitor
  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData

      anchors { top: true; left: true; right: true }
      margins { top: 6; left: 8; right: 8 }
      implicitHeight: 38
      color: "transparent"

      // The floating pill background
      Rectangle {
        anchors.fill: parent
        radius: 14
        color: Colors.surface

        // ---- LEFT ----
        Row {
          anchors.left: parent.left
          anchors.leftMargin: 14
          anchors.verticalCenter: parent.verticalCenter
          spacing: 14

          Workspaces {}
          WindowTitle {}
        }

        // ---- CENTRE ----
        Clock { anchors.centerIn: parent }

        // ---- RIGHT ----
        Row {
          anchors.right: parent.right
          anchors.rightMargin: 14
          anchors.verticalCenter: parent.verticalCenter
          spacing: 14

          Volume {
            openPopup: root.openPopup
            onToggle: name => root.toggle(name)
          }
          // New modules go here, one line each.
        }
      }
    }
  }
}
