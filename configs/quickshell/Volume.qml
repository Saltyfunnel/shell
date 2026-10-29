// Volume.qml — THE TEMPLATE for every module that has a card.
//   Bar item : icon + percentage. Click = open/close card. Scroll = change volume.
//   Card     : device name, big percentage, slider, mute button.
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

Item {
  id: root

  property string popupName: "volume"   // this module's name
  property string openPopup: ""         // set by shell.qml
  signal toggle(string name)            // tells shell.qml to open/close us

  property var sink: Pipewire.defaultAudioSink
  property real vol: sink?.audio?.volume ?? 0
  property bool muted: sink?.audio?.muted ?? false

  function setVol(v) {
    if (sink?.audio) sink.audio.volume = Math.max(0, Math.min(1, v))
  }

  implicitWidth: label.implicitWidth
  implicitHeight: label.implicitHeight

  PwObjectTracker { objects: [ root.sink ] }

  // ---------- collapsed: what shows in the bar ----------
  Text {
    id: label
    color: Colors.text
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 14
    text: (root.muted ? "󰝟" : "󰕾") + " " + Math.round(root.vol * 100) + "%"

    MouseArea {
      anchors.fill: parent
      onClicked: root.toggle(root.popupName)
      onWheel: wheel => root.setVol(root.vol + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
    }
  }

  // ---------- expanded: the card ----------
  PopupWindow {
    anchor.item: root
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    visible: root.openPopup === root.popupName
    implicitWidth: 260
    implicitHeight: 150
    color: "transparent"

    Rectangle {
      anchors.fill: parent
      anchors.topMargin: 8
      radius: 16
      color: Colors.card

      Column {
        anchors.centerIn: parent
        spacing: 12

        Text {
          text: root.sink?.description ?? "No output device"
          color: Colors.subtext
          font.pixelSize: 12
          width: 220
          elide: Text.ElideRight
        }

        Text {
          text: Math.round(root.vol * 100) + "%"
          color: Colors.text
          font.pixelSize: 28
          font.bold: true
        }

        // slider
        Rectangle {
          width: 220; height: 10; radius: 5
          color: Colors.track

          Rectangle {
            width: parent.width * root.vol
            height: parent.height; radius: 5
            color: root.muted ? Colors.subtext : Colors.accent
            Behavior on width { NumberAnimation { duration: 80 } }
          }
          MouseArea {
            anchors.fill: parent
            onPressed: mouse => root.setVol(mouse.x / parent.width)
            onPositionChanged: mouse => root.setVol(mouse.x / parent.width)
          }
        }

        // mute button
        Rectangle {
          width: 220; height: 30; radius: 10
          color: root.muted ? Colors.accent : Colors.track
          Text {
            anchors.centerIn: parent
            text: root.muted ? "Unmute" : "Mute"
            color: root.muted ? Colors.surface : Colors.text
            font.pixelSize: 13
          }
          MouseArea {
            anchors.fill: parent
            onClicked: if (root.sink?.audio) root.sink.audio.muted = !root.muted
          }
        }
      }
    }
  }
}
