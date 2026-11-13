import Quickshell
import QtQuick

Item {
  id: root

  property string popupName: "power"
  property string openPopup: ""
  signal toggle(string name)
  property alias popup: card        // shell.qml's focus grab uses this

  implicitWidth: 15
  implicitHeight: 24

  readonly property color danger: "#FF5555"

  // which destructive action is waiting for its confirming click ("" = none)
  property string pending: ""
  property string hoveredLabel: ""   // tracks currently hovered power button label
  onOpenPopupChanged: {
    pending = ""
    hoveredLabel = ""
  }

  Timer {
    id: confirmTimer
    interval: 3000
    onTriggered: root.pending = ""
  }

  // run a shell command, then close the menu
  function run(cmd) {
    Quickshell.execDetached(["sh", "-c", cmd])
    root.toggle(root.popupName)
  }

  // first click arms the action, second click (within 3s) runs it
  function confirmThenRun(key, cmd) {
    if (root.pending === key) {
      root.pending = ""
      root.run(cmd)
    } else {
      root.pending = key
      confirmTimer.restart()
    }
  }

  // ---------- bar icon ----------
  Text {
    anchors.centerIn: parent
    color: barMouse.containsMouse || card.shown ? Colors.text : Colors.accent
    font.family: "Hack Nerd Font"
    font.pixelSize: 15
    text: "󰐥"
    Behavior on color { ColorAnimation { duration: Theme.animFast } }
  }

  // covers the whole slot, so it's easier to hit than just the glyph
  MouseArea {
    id: barMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggle(root.popupName)
  }

  // ---------- the card (Horizontal Layout) ----------
  OverlayCard {
    id: card
    shown: root.openPopup === root.popupName
    cardWidth: 340
    cardHeight: 135
    onDismissed: {
      root.toggle(root.popupName)
      root.hoveredLabel = ""
    }

    Column {
      anchors.fill: parent
      anchors.margins: 16
      spacing: 12

      MenuHeader {
        icon: "󰐥"
        title: root.hoveredLabel !== "" ? root.hoveredLabel : "Session"
      }
      MenuDivider {}

      // Horizontal Row of Icon Buttons generated via Repeater
      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10

        Repeater {
          model: [
            { icon: "󰌾", label: "Lock", key: "lock", cmd: "pidof hyprlock || hyprlock", destructive: false },
            { icon: "󰤄", label: "Suspend", key: "suspend", cmd: "systemctl suspend", destructive: false },
            { icon: "󰍃", label: "Logout", key: "logout", cmd: "hyprctl dispatch 'hl.dsp.exit()'", destructive: true },
            { icon: "󰜉", label: "Reboot", key: "reboot", cmd: "systemctl reboot", destructive: true },
            { icon: "󰐥", label: "Shutdown", key: "poweroff", cmd: "systemctl poweroff", destructive: true }
          ]

          delegate: Column {
            id: btnRoot
            spacing: 4
            width: 54

            property bool isPending: modelData.destructive && root.pending === modelData.key

            Rectangle {
              width: 54
              height: 42
              radius: 8
              color: mouseArea.containsMouse ? Colors.surfaceHover : Colors.surface
              border.color: btnRoot.isPending ? root.danger : "transparent"
              border.width: btnRoot.isPending ? 1 : 0

              Behavior on color { ColorAnimation { duration: Theme.animFast } }

              Text {
                anchors.centerIn: parent
                font.family: "Hack Nerd Font"
                font.pixelSize: 16
                color: btnRoot.isPending ? root.danger : Colors.accent
                text: modelData.icon
              }

              MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.hoveredLabel = modelData.label
                onExited: root.hoveredLabel = ""
                onClicked: {
                  if (modelData.destructive) {
                    root.confirmThenRun(modelData.key, modelData.cmd)
                  } else {
                    root.run(modelData.cmd)
                  }
                }
              }
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              font.pixelSize: 9
              font.bold: btnRoot.isPending
              color: btnRoot.isPending ? root.danger : Colors.textSecondary
              text: btnRoot.isPending ? "Confirm" : modelData.label
              elide: Text.ElideRight
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
            }
          }
        }
      }
    }
  }
}
