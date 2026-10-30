import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

ShellRoot {
  id: root

  // Centralized state tracker to ensure mutually exclusive popups
  property string openPopup: ""

  function toggle(name) {
    root.openPopup = root.openPopup === name ? "" : name
  }

  // Multi-monitor support across all active screens
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: barWindow
      required property var modelData
      screen: modelData

      color: "transparent"
      width: screen.width
      height: 36

      anchors {
        top: true
        left: true
        right: true
      }

      // ---------- LEFT ISLAND: Workspaces & Window Title ----------
      Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: 28
        width: leftRow.implicitWidth + 20
        radius: 8
        color: Colors.surface
        border.color: Colors.accent
        border.width: 1

        Row {
          id: leftRow
          anchors.centerIn: parent
          spacing: 14

          Workspaces {
            anchors.verticalCenter: parent.verticalCenter
          }

          WindowTitle {
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }

      // ---------- CENTER ISLAND: Clock ----------
      Rectangle {
        anchors.centerIn: parent
        height: 28
        width: centerRow.implicitWidth + 20
        radius: 8
        color: Colors.surface
        border.color: Colors.accent
        border.width: 1

        Row {
          id: centerRow
          anchors.centerIn: parent

          Clock {
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }

      // ---------- RIGHT ISLAND: Hardware, Media, Volume ----------
      Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: 28
        width: rightRow.implicitWidth + 20
        radius: 8
        color: Colors.surface
        border.color: Colors.accent
        border.width: 1

        Row {
          id: rightRow
          anchors.centerIn: parent
          spacing: 14

          Hardware {
            anchors.verticalCenter: parent.verticalCenter
          }

          Media {
            openPopup: root.openPopup
            onToggle: name => root.toggle(name)
            anchors.verticalCenter: parent.verticalCenter
          }

          WallpaperPicker {
            id: wallpaperPicker
            openPopup: root.openPopup
            onToggle: name => root.toggle(name)
            anchors.verticalCenter: parent.verticalCenter
          }

         ScreenCaptureModule {
            anchors.verticalCenter: parent.verticalCenter
            }

          Volume {
            openPopup: root.openPopup
            onToggle: name => root.toggle(name)
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }

      // Native Hyprland focus grab including both the bar and the wallpaper popup window
      HyprlandFocusGrab {
        active: root.openPopup !== ""
        windows: [ barWindow, wallpaperPicker.popup ]
        onCleared: root.openPopup = ""
      }
    }
  }
}
