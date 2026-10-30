// Media.qml — now-playing for any MPRIS player (Spotify, mpv, Firefox...).
//   Bar item : music icon + "Artist - Title". Hidden when nothing is playing.
//   Card     : album art, title/artist, progress bar (click to seek), prev/play/next.
import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Effects

Item {
  id: root

  property string popupName: "media"
  property string openPopup: ""
  signal toggle(string name)

  // Prefer a player that is playing right now, otherwise the first one found
  property var player: {
    const list = Mpris.players.values
    for (let i = 0; i < list.length; i++) {
      if (list[i].isPlaying) return list[i]
    }
    return list.length > 0 ? list[0] : null
  }
  property bool playing: player?.isPlaying ?? false

  function fmt(s) {
    s = Math.max(0, Math.floor(s))
    const m = Math.floor(s / 60)
    const r = s % 60
    return m + ":" + (r < 10 ? "0" : "") + r
  }

  visible: player !== null
  implicitWidth: visible ? label.implicitWidth : 0
  implicitHeight: label.implicitHeight

  // MPRIS doesn't push position updates, so ask for one each second while the card is open
  Timer {
    running: root.playing && root.openPopup === root.popupName
    interval: 1000
    repeat: true
    onTriggered: root.player?.positionChanged()
  }

  // ---------- collapsed: what shows in the bar ----------
  Text {
    id: label
    color: Colors.text
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 14
    elide: Text.ElideRight
    width: Math.min(implicitWidth, 260)
    text: (root.playing ? "󰎆" : "󰏤") + " "
          + (root.player?.trackArtist ? root.player.trackArtist + " - " : "")
          + (root.player?.trackTitle ?? "")

    MouseArea {
      anchors.fill: parent
      onClicked: root.toggle(root.popupName)
    }
  }

  // ---------- expanded: the card ----------
  PopupWindow {
    anchor.item: root
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    visible: root.player !== null && root.openPopup === root.popupName
    implicitWidth: 280
    implicitHeight: 380
    color: "transparent"

    Rectangle {
      anchors.fill: parent
      anchors.topMargin: 8
      radius: 16
      color: Colors.card

      Column {
        anchors.centerIn: parent
        spacing: 12

        // album art with rounded corners
        Item {
          width: 200; height: 200
          anchors.horizontalCenter: parent.horizontalCenter

          Image {
            id: art
            anchors.fill: parent
            source: root.player?.trackArtUrl ?? ""
            fillMode: Image.PreserveAspectCrop
            visible: false           // drawn through the rounded mask below
          }
          Rectangle {
            id: mask
            anchors.fill: parent
            radius: 14
            layer.enabled: true
            visible: false
          }
          MultiEffect {
            anchors.fill: parent
            source: art
            maskEnabled: true
            maskSource: mask
            visible: art.status === Image.Ready
          }
          // placeholder while there is no art
          Rectangle {
            anchors.fill: parent
            radius: 14
            color: Colors.track
            visible: art.status !== Image.Ready
            Text {
              anchors.centerIn: parent
              text: "󰎆"
              color: Colors.subtext
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 48
            }
          }
        }

        // title + artist
        Column {
          spacing: 2
          anchors.horizontalCenter: parent.horizontalCenter
          Text {
            text: root.player?.trackTitle ?? ""
            color: Colors.text
            font.pixelSize: 16
            font.bold: true
            width: 230
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
          }
          Text {
            text: root.player?.trackArtist ?? ""
            color: Colors.subtext
            font.pixelSize: 13
            width: 230
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
          }
        }

        // progress bar (click to seek) + times
        Column {
          spacing: 4
          anchors.horizontalCenter: parent.horizontalCenter
          visible: root.player?.lengthSupported ?? false

          Rectangle {
            width: 230; height: 6; radius: 3
            color: Colors.track
            Rectangle {
              height: parent.height; radius: 3
              color: Colors.accent
              width: root.player && root.player.length > 0
                     ? parent.width * Math.min(1, root.player.position / root.player.length) : 0
            }
            MouseArea {
              anchors.fill: parent
              onPressed: mouse => {
                if (root.player?.canSeek && root.player.length > 0)
                  root.player.position = (mouse.x / width) * root.player.length
              }
            }
          }
          Item {
            width: 230; height: 14
            Text { text: root.fmt(root.player?.position ?? 0); color: Colors.subtext; font.pixelSize: 11 }
            Text {
              anchors.right: parent.right
              text: root.fmt(root.player?.length ?? 0)
              color: Colors.subtext; font.pixelSize: 11
            }
          }
        }

        // prev / play-pause / next
        Row {
          spacing: 28
          anchors.horizontalCenter: parent.horizontalCenter

          Text {
            text: "󰒮"; color: Colors.text; font.pixelSize: 26
            font.family: "JetBrainsMono Nerd Font"
            MouseArea { anchors.fill: parent; onClicked: root.player?.previous() }
          }
          Text {
            text: root.playing ? "󰏤" : "󰐊"; color: Colors.accent; font.pixelSize: 32
            font.family: "JetBrainsMono Nerd Font"
            MouseArea { anchors.fill: parent; onClicked: root.player?.togglePlaying() }
          }
          Text {
            text: "󰒭"; color: Colors.text; font.pixelSize: 26
            font.family: "JetBrainsMono Nerd Font"
            MouseArea { anchors.fill: parent; onClicked: root.player?.next() }
          }
        }
      }
    }
  }
}
