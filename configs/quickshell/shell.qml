import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

ShellRoot {
  id: root

  // Centralized state tracker to ensure mutually exclusive popups
  property string openPopup: ""

  function toggle(name) {
    root.openPopup = root.openPopup === name ? "" : name
  }

  // The app launcher: one overlay for the whole shell, opened from a keybind with
  //   qs ipc call launcher toggle
  Launcher {
    id: launcher
    openPopup: root.openPopup
    onToggle: name => root.toggle(name)
  }

  IpcHandler {
    target: "launcher"
    function toggle(): void { root.toggle("launcher") }
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

      // ---------- RIGHT ISLAND: Hardware, Network, Bluetooth, Media, Volume, Power ----------
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
            id: hardware
            openPopup: root.openPopup
            onToggle: name => root.toggle(name)
            anchors.verticalCenter: parent.verticalCenter
          }

          Network {
            id: network
            openPopup: root.openPopup
            onToggle: name => root.toggle(name)
            anchors.verticalCenter: parent.verticalCenter
          }

          BluetoothModule {
            id: bluetooth
            openPopup: root.openPopup
            onToggle: name => root.toggle(name)
            anchors.verticalCenter: parent.verticalCenter
          }

          Media {
            id: media
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
            id: screenCapture
            openPopup: root.openPopup
            onToggle: name => root.toggle(name)
            anchors.verticalCenter: parent.verticalCenter
          }

          Volume {
            id: volume
            openPopup: root.openPopup
            onToggle: name => root.toggle(name)
            anchors.verticalCenter: parent.verticalCenter
          }

          PowerModule {
            id: powerModule
            openPopup: root.openPopup
            onToggle: name => root.toggle(name)
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }

      // Native Hyprland focus grab including bar and popup windows
      HyprlandFocusGrab {
        active: root.openPopup !== ""
        windows: [ barWindow, wallpaperPicker.popup, powerModule.popup, screenCapture.popup, media.popup, volume.popup, hardware.popup, network.popup, bluetooth.popup, launcher.popup ]
        onCleared: root.openPopup = ""
      }
    }
  }
}
