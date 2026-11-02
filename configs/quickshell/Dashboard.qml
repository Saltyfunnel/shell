// Dashboard.qml — the clock in the bar; click it for a tabbed dashboard popup.
//   Tabs: Dashboard (clock, calendar, system info) / Media / Performance (the last two come next).
import Quickshell
import QtQuick

Item {
  id: root

  property string popupName: "dashboard"
  property string openPopup: ""
  signal toggle(string name)
  property alias popup: card        // shell.qml's focus grab uses this

  property int tab: 0
  readonly property var tabNames: ["Dashboard", "Media", "Performance"]

  implicitWidth: barClock.implicitWidth
  implicitHeight: barClock.implicitHeight

  // ---------- bar item: the clock ----------
  Clock { id: barClock }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggle(root.popupName)
  }

  // ---------- the popup, centred under the clock ----------
  PopupWindow {
    id: card
    anchor.item: root
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    visible: root.openPopup === root.popupName
    implicitWidth: 660
    implicitHeight: 350
    color: "transparent"

    onVisibleChanged: if (visible) { root.tab = 0; calendar.reset() }

    Rectangle {
      anchors.fill: parent
      anchors.topMargin: 8
      radius: Theme.radiusLg
      color: Colors.surface

      Column {
        anchors.fill: parent
        anchors.margins: Theme.pad
        spacing: Theme.gap

        // ----- tab bar -----
        Row {
          id: tabBar
          spacing: 6

          Repeater {
            model: root.tabNames

            Rectangle {
              required property string modelData
              required property int index
              readonly property bool active: root.tab === index

              width: tabText.implicitWidth + 28
              height: 30
              radius: 15
              color: active ? Colors.accent : "transparent"
              Behavior on color { ColorAnimation { duration: Theme.animFast } }

              Text {
                id: tabText
                anchors.centerIn: parent
                text: modelData
                color: active ? Colors.surface : Colors.subtext
                font.family: Theme.font
                font.pixelSize: 13
                font.bold: active
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.tab = index
              }
            }
          }
        }

        // ----- pages -----
        Item {
          width: parent.width
          height: parent.height - tabBar.height - Theme.gap

          // Dashboard
          Row {
            visible: root.tab === 0
            anchors.fill: parent
            spacing: Theme.gap

            DashClock { width: 64; height: parent.height }
            DashCalendar { id: calendar; width: 280; height: parent.height }
            DashSysInfo { width: parent.width - 64 - 280 - 2 * Theme.gap; height: parent.height }
          }

          // Media and Performance arrive in the next step
          Text {
            visible: root.tab !== 0
            anchors.centerIn: parent
            text: "Coming in the next step"
            color: Colors.subtext
            font.family: Theme.font
            font.pixelSize: 14
          }
        }
      }
    }
  }
}
