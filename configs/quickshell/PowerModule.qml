// PowerModule.qml — bar icon + a Session card (lock / logout / reboot / shutdown).
// Built from the shared pieces: OverlayCard, MenuHeader, MenuDivider, MenuRow.
import Quickshell
import QtQuick

Item {
  id: root

  property string popupName: "power"
  property string openPopup: ""
  signal toggle(string name)
  property alias popup: card        // shell.qml's focus grab uses this

  implicitWidth: 32
  implicitHeight: 24

  // run a shell command, then close the menu
  function run(cmd) {
    Quickshell.execDetached(["sh", "-c", cmd])
    root.toggle(root.popupName)
  }

  // ---------- bar icon ----------
  Text {
    anchors.centerIn: parent
    color: Colors.accent
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 15
    text: "󰐥"

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
    cardWidth: 260
    cardHeight: 280
    onDismissed: root.toggle(root.popupName)

    Column {
      anchors.fill: parent
      anchors.margins: 20
      spacing: 10

      MenuHeader { icon: "󰐥"; title: "Session" }
      MenuDivider {}

      MenuRow { icon: "󰌾"; label: "Lock";     onClicked: root.run("pidof hyprlock || hyprlock") }
      // Hyprland 0.55+ Lua syntax. If this ever fails, the blunt alternative is:
      //   root.run("loginctl terminate-user $USER")
      MenuRow { icon: "󰍃"; label: "Logout";   onClicked: root.run("hyprctl dispatch 'hl.dsp.exit()'") }
      MenuRow { icon: "󰜉"; label: "Reboot";   onClicked: root.run("systemctl reboot") }
      MenuRow { icon: "󰐥"; label: "Shutdown"; onClicked: root.run("systemctl poweroff") }
    }
  }
}
