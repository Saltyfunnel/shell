// Dashboard.qml — the clock in the bar; click it for a dashboard popup with an icon sidebar.
//   Dashboard : system info on top; clock, calendar, mixer and media card below
//   Media     : big now-playing view
//   Performance : CPU / memory charts, disk, temperatures, battery
//   Weather   : current conditions and a 3-day forecast (town set in Config.qml)
//   Connectivity : network + Wi-Fi list, Bluetooth devices
//   Capture   : screenshots and screen recording
//
// The tabs are a vertical column of icons on the left. At the bottom of that column sits a
// pill with the pending pacman update count (click to update); it only shows when updates exist.
//
// Other bar modules can open a specific tab with  dashboard.openTab(n)
//   0 Dashboard, 1 Media, 2 Performance, 3 Weather, 4 Connectivity, 5 Capture
import Quickshell
import QtQuick

Item {
  id: root

  property string popupName: "dashboard"
  property string openPopup: ""
  signal toggle(string name)
  property alias popup: card        // shell.qml's focus grab uses this

  property int tab: 0
  property int requestedTab: 0      // the tab the popup opens on next time

  // order here = tab index (keep in sync with the pages below).
  // Icons are UTF-16 surrogate pairs: \U escapes are not valid inside JS arrays in QML.
  readonly property var tabs: [
    { name: "Dashboard",    icon: "\uDB81\uDD6E" },
    { name: "Media",        icon: "\uDB80\uDF86" },
    { name: "Performance",  icon: "\uDB81\uDCC5" },
    { name: "Weather",      icon: "\uDB81\uDD95" },
    { name: "Connectivity", icon: "\uDB81\uDDA9" },
    { name: "Capture",      icon: "\uDB80\uDD00" }
  ]

  readonly property int sideWidth: 44

  // tell Connectivity.qml when its tab is on screen, so it only scans Wi-Fi then
  readonly property bool connectivityShowing: openPopup === popupName && tab === 4
  onConnectivityShowingChanged: Connectivity.scanning = connectivityShowing

  // same idea for the other data sources: they only run while their card is on screen
  readonly property bool shown: openPopup === popupName
  Binding { target: SystemStats; property: "active"; value: root.shown && root.tab === 2 }
  Binding { target: MediaPlayers; property: "watching"; value: root.shown && (root.tab === 0 || root.tab === 1) }

  // Open the dashboard on a given tab. If it's already open, just switch tab.
  function openTab(n) {
    root.requestedTab = n
    if (root.openPopup === root.popupName) root.tab = n
    else root.toggle(root.popupName)
  }

  implicitWidth: barClock.implicitWidth
  implicitHeight: barClock.implicitHeight

  // ---------- bar item: the clock ----------
  Clock { id: barClock }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: { root.requestedTab = 0; root.toggle(root.popupName) }
  }

  // ---------- the popup, centred under the clock ----------
  PopupWindow {
    id: card
    anchor.item: root
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    visible: root.openPopup === root.popupName
    implicitWidth: 780 + root.sideWidth + Theme.gap   // content area keeps its old width
    implicitHeight: 398
    color: "transparent"

    onVisibleChanged: if (visible) { root.tab = root.requestedTab; calendar.reset() }

    Rectangle {
      anchors.fill: parent
      anchors.topMargin: 8
      radius: Theme.radiusLg
      color: Qt.alpha(Colors.surface, 0.9)

      Row {
        anchors.fill: parent
        anchors.margins: Theme.pad
        spacing: Theme.gap

        // ----- sidebar: icon tabs on top, updates pill at the bottom -----
        DashPanel {
          id: sideBar
          z: 10                      // above the pages, so hover labels draw over them
          width: root.sideWidth
          height: parent.height

          Column {
            anchors.top: parent.top
            anchors.topMargin: 4
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            Repeater {
              model: root.tabs

              Rectangle {
                id: tabBtn
                required property var modelData
                required property int index
                readonly property bool active: root.tab === index

                width: 36
                height: 36
                radius: Theme.radiusSm
                color: active ? Colors.accent
                     : tabMouse.containsMouse ? Qt.alpha(Colors.accent, 0.15)
                     : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Text {
                  anchors.centerIn: parent
                  text: tabBtn.modelData.icon
                  color: tabBtn.active ? Colors.surface : Colors.subtext
                  font.family: Theme.font
                  font.pixelSize: 18
                }
                MouseArea {
                  id: tabMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.tab = tabBtn.index
                }

                // name label: appears to the right of the icon, over the page area (still inside the popup)
                Rectangle {
                  z: 100
                  x: tabBtn.width + 12
                  anchors.verticalCenter: parent.verticalCenter
                  width: tipText.implicitWidth + 20
                  height: 26
                  radius: 13
                  color: Colors.surface
                  border.width: 1
                  border.color: Colors.accent
                  opacity: tabMouse.containsMouse ? 1 : 0
                  visible: opacity > 0
                  Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

                  Text {
                    id: tipText
                    anchors.centerIn: parent
                    text: tabBtn.modelData.name
                    color: Colors.text
                    font.family: Theme.font
                    font.pixelSize: 12
                  }
                }
              }
            }
          }

          // updates pill: only shown when something is pending; click to update
          Rectangle {
            visible: Updates.total > 0
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            anchors.horizontalCenter: parent.horizontalCenter
            width: 36
            height: 44
            radius: Theme.radiusSm
            color: "transparent"
            border.width: 1
            border.color: Colors.accent

            Column {
              anchors.centerIn: parent
              spacing: 1
              Text {
                text: "\uDB81\uDEB0"
                color: Colors.accent
                font.family: Theme.font
                font.pixelSize: 16
                anchors.horizontalCenter: parent.horizontalCenter
              }
              Text {
                text: Updates.total
                color: Colors.text
                font.family: Theme.font
                font.pixelSize: 11
                anchors.horizontalCenter: parent.horizontalCenter
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: { root.toggle(root.popupName); Updates.upgrade() }
            }
          }
        }

        // ----- pages -----
        Item {
          width: parent.width - root.sideWidth - Theme.gap
          height: parent.height

          // Dashboard: top row, then clock + calendar + mixer + media
          Column {
            visible: root.tab === 0
            anchors.fill: parent
            spacing: Theme.gap

            Row {
              width: parent.width
              height: 96
              spacing: Theme.gap

              DashWeather { width: 260; height: parent.height }
              DashSysInfo { width: parent.width - 260 - Theme.gap; height: parent.height }
            }

            Row {
              width: parent.width
              height: parent.height - 96 - Theme.gap
              spacing: Theme.gap

              DashClock { width: 64; height: parent.height }
              DashCalendar { id: calendar; width: 280; height: parent.height }
              MixerPanel { width: 84; height: parent.height }
              DashMedia { width: parent.width - 64 - 280 - 84 - 3 * Theme.gap; height: parent.height }
            }
          }

          // tabs 1-5 are built only while selected, and freed when you leave or close the popup
          Loader { anchors.fill: parent; active: root.shown && root.tab === 1; source: "MediaPanel.qml" }
          Loader { anchors.fill: parent; active: root.shown && root.tab === 2; source: "PerformancePanel.qml" }
          Loader { anchors.fill: parent; active: root.shown && root.tab === 3; source: "WeatherPanel.qml" }
          Loader { anchors.fill: parent; active: root.shown && root.tab === 4; source: "ConnectivityPanel.qml" }
          Loader {
            id: captureLoader
            anchors.fill: parent
            active: root.shown && root.tab === 5
            source: "CapturePanel.qml"
            Connections {
              target: captureLoader.item
              function onCloseRequested() { root.toggle(root.popupName) }
            }
          }
        }
      }
    }
  }
}
