// CoverBackdrop.qml — blurred, darkened album art that fills its parent card.
// Shared by DashMedia and MediaPanel. The art is decoded at 96px: it is blurred anyway,
// so a full-size decode and a 64px blur would just waste GPU time and memory.
//   CoverBackdrop { source: player?.trackArtUrl ?? ""; radius: root.radius; dim: -0.3 }
import QtQuick
import QtQuick.Effects

Item {
  id: root
  property url source
  property real radius: 14
  property real dim: -0.3
  readonly property bool ready: img.status === Image.Ready

  Image {
    id: img
    anchors.fill: parent
    visible: false
    source: root.source
    sourceSize: Qt.size(96, 96)
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
  }

  Item {
    id: mask
    visible: false
    width: root.width
    height: root.height
    layer.enabled: true
    Rectangle { anchors.fill: parent; radius: root.radius; color: "black" }
  }

  MultiEffect {
    anchors.fill: parent
    visible: root.ready
    source: img
    autoPaddingEnabled: false
    blurEnabled: true
    blur: 1.0
    blurMax: 32
    brightness: root.dim
    saturation: 0.3
    maskEnabled: true
    maskSource: mask
    maskThresholdMin: 0.5
    maskSpreadAtMin: 1.0
  }
}
