// MediaPanel.qml — the dashboard's Media tab: big album art, title, progress, controls.
import Quickshell
import QtQuick

DashPanel {
  id: root

  readonly property var player: MediaPlayers.active

  // MPRIS doesn't push position updates, so ask for one each second while this is on screen
  Timer {
    running: MediaPlayers.playing && root.visible
    interval: 1000
    repeat: true
    onTriggered: root.player?.positionChanged()
  }

  Text {
    visible: root.player === null
    anchors.centerIn: parent
    text: "Nothing playing"
    color: Colors.subtext
    font.family: Theme.font
    font.pixelSize: 16
  }

  Row {
    visible: root.player !== null
    anchors.fill: parent
    anchors.margins: 24
    spacing: 28

    // album art
    Item {
      width: 250
      height: 250
      anchors.verticalCenter: parent.verticalCenter

      Rectangle {
        anchors.fill: parent
        radius: 18
        color: Colors.track
        Text {
          anchors.centerIn: parent
          text: "󰎆"
          color: Colors.subtext
          font.family: Theme.font
          font.pixelSize: 56
        }
      }
      RoundedImage {
        anchors.fill: parent
        radius: 18
        source: root.player?.trackArtUrl ?? ""
      }
    }

    Column {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - 250 - parent.spacing
      spacing: 18

      Column {
        width: parent.width
        spacing: 4
        Text {
          width: parent.width
          text: root.player?.trackTitle ?? ""
          color: Colors.text
          font.family: Theme.font
          font.pixelSize: 22
          font.bold: true
          elide: Text.ElideRight
        }
        Text {
          width: parent.width
          text: root.player?.trackArtist ?? ""
          color: Colors.subtext
          font.family: Theme.font
          font.pixelSize: 15
          elide: Text.ElideRight
        }
      }

      // progress bar (click to seek) + times
      Column {
        width: parent.width
        spacing: 6
        visible: root.player?.lengthSupported ?? false

        Rectangle {
          width: parent.width
          height: 6
          radius: 3
          color: Colors.track

          Rectangle {
            height: parent.height
            radius: 3
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
          width: parent.width
          height: 14
          Text { text: MediaPlayers.fmt(root.player?.position ?? 0); color: Colors.subtext; font.pixelSize: 11 }
          Text {
            anchors.right: parent.right
            text: MediaPlayers.fmt(root.player?.length ?? 0)
            color: Colors.subtext
            font.pixelSize: 11
          }
        }
      }

      // prev / play-pause / next
      Row {
        spacing: 34
        Text {
          text: "󰒮"; color: Colors.text; font.pixelSize: 30; font.family: Theme.font
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.player?.previous() }
        }
        Text {
          text: MediaPlayers.playing ? "󰏤" : "󰐊"; color: Colors.accent; font.pixelSize: 38; font.family: Theme.font
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.player?.togglePlaying() }
        }
        Text {
          text: "󰒭"; color: Colors.text; font.pixelSize: 30; font.family: Theme.font
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.player?.next() }
        }
      }
    }
  }
}
