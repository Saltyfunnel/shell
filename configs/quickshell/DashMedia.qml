// DashMedia.qml — compact now-playing card: album art inside a progress ring, title, controls.
import Quickshell
import QtQuick

DashPanel {
  id: root

  readonly property var player: MediaPlayers.active

  Timer {
    running: MediaPlayers.playing && root.visible
    interval: 1000
    repeat: true
    onTriggered: root.player?.positionChanged()
  }

  Text {
    visible: root.player === null
    anchors.centerIn: parent
    text: "󰎆  Nothing playing"
    color: Colors.subtext
    font.family: Theme.font
    font.pixelSize: 13
  }

  Column {
    visible: root.player !== null
    anchors.fill: parent
    anchors.topMargin: 14
    anchors.leftMargin: 14
    anchors.rightMargin: 14
    spacing: 8

    // art + ring
    Item {
      width: 124
      height: 124
      anchors.horizontalCenter: parent.horizontalCenter

      Canvas {
        id: ring
        anchors.fill: parent
        property real progress: root.player && root.player.length > 0
                                ? Math.min(1, root.player.position / root.player.length) : 0
        onProgressChanged: requestPaint()
        onWidthChanged: requestPaint()

        onPaint: {
          const ctx = getContext("2d")
          ctx.clearRect(0, 0, width, height)
          const cx = width / 2, cy = height / 2, r = width / 2 - 5
          ctx.lineWidth = 5
          ctx.lineCap = "round"

          ctx.strokeStyle = Colors.track
          ctx.beginPath()
          ctx.arc(cx, cy, r, 0, 2 * Math.PI)
          ctx.stroke()

          if (progress > 0) {
            ctx.strokeStyle = Colors.accent
            ctx.beginPath()
            ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * progress)
            ctx.stroke()
          }
        }
      }

      Rectangle {
        anchors.centerIn: parent
        width: 98
        height: 98
        radius: 49
        color: Colors.track
        Text {
          anchors.centerIn: parent
          text: "󰎆"
          color: Colors.subtext
          font.family: Theme.font
          font.pixelSize: 30
        }
      }
      RoundedImage {
        anchors.centerIn: parent
        width: 98
        height: 98
        radius: 49
        source: root.player?.trackArtUrl ?? ""
      }
    }

    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: root.player?.trackTitle ?? ""
      color: Colors.text
      font.family: Theme.font
      font.pixelSize: 13
      font.bold: true
      elide: Text.ElideRight
    }
    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: root.player?.trackArtist ?? ""
      color: Colors.subtext
      font.family: Theme.font
      font.pixelSize: 11
      elide: Text.ElideRight
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 22
      Text {
        text: "󰒮"; color: Colors.text; font.pixelSize: 20; font.family: Theme.font
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.player?.previous() }
      }
      Text {
        text: MediaPlayers.playing ? "󰏤" : "󰐊"; color: Colors.accent; font.pixelSize: 24; font.family: Theme.font
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.player?.togglePlaying() }
      }
      Text {
        text: "󰒭"; color: Colors.text; font.pixelSize: 20; font.family: Theme.font
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.player?.next() }
      }
    }
  }
}
