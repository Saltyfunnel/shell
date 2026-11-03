// RingGauge.qml — a circular gauge: ring that fills with `fraction`, value in the middle, label under it.
// Turns red above 85%.
import QtQuick

Item {
  id: root

  property real fraction: 0          // 0..1
  property string valueText: ""
  property string label: ""
  property color ringColor: Colors.accent
  property int size: 104

  width: size
  height: size + 24

  // animated copy of fraction, so the ring glides instead of jumping
  property real shown: Math.max(0, Math.min(1, fraction))
  Behavior on shown { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
  onShownChanged: canvas.requestPaint()
  onRingColorChanged: canvas.requestPaint()

  Canvas {
    id: canvas
    width: root.size
    height: root.size
    anchors.horizontalCenter: parent.horizontalCenter

    onPaint: {
      const ctx = getContext("2d")
      ctx.reset()
      const cx = width / 2, cy = height / 2
      const r = width / 2 - 8
      ctx.lineWidth = 9
      ctx.lineCap = "round"

      ctx.strokeStyle = Colors.track
      ctx.beginPath()
      ctx.arc(cx, cy, r, 0, 2 * Math.PI)
      ctx.stroke()

      if (root.shown > 0.01) {
        ctx.strokeStyle = root.shown > 0.85 ? "#FF5555" : root.ringColor
        ctx.beginPath()
        ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + root.shown * 2 * Math.PI)
        ctx.stroke()
      }
    }
    Component.onCompleted: requestPaint()
  }

  Text {
    anchors.centerIn: canvas
    text: root.valueText
    color: Colors.text
    font.family: Theme.font
    font.pixelSize: 20
    font.bold: true
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    text: root.label
    color: Colors.subtext
    font.family: Theme.font
    font.pixelSize: 12
  }
}
