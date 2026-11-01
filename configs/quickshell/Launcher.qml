// Launcher.qml — type to search installed apps, Enter to launch.
// One overlay for the whole shell (not per monitor). Opened with:  qs ipc call launcher toggle
//   Up / Down  move the selection      Enter  launch      Esc  close
import Quickshell
import QtQuick

Scope {
  id: root

  property string popupName: "launcher"
  property string openPopup: ""
  signal toggle(string name)
  property alias popup: card        // shell.qml's focus grab uses this

  property string query: ""

  // Installed apps that match the search, best matches first
  property var results: {
    const q = root.query.trim().toLowerCase()
    const list = DesktopEntries.applications.values
    const out = []
    for (let i = 0; i < list.length; i++) {
      const e = list[i]
      if (e.noDisplay) continue
      const name = (e.name ?? "").toLowerCase()
      const generic = (e.genericName ?? "").toLowerCase()
      if (q === "" || name.includes(q) || generic.includes(q)) out.push(e)
    }
    out.sort((a, b) => {
      const as = q !== "" && a.name.toLowerCase().startsWith(q)
      const bs = q !== "" && b.name.toLowerCase().startsWith(q)
      if (as !== bs) return as ? -1 : 1
      return a.name.localeCompare(b.name)
    })
    return out
  }

  function launch(i) {
    if (i < 0 || i >= root.results.length) return
    const entry = root.results[i]
    root.toggle(root.popupName)
    entry.execute()
  }

  OverlayCard {
    id: card
    shown: root.openPopup === root.popupName
    cardWidth: 560
    cardHeight: 480
    onDismissed: root.toggle(root.popupName)

    onVisibleChanged: {
      if (visible) {
        searchField.text = ""
        root.query = ""
        list.currentIndex = 0
        searchField.forceActiveFocus()
      }
    }

    Column {
      anchors.fill: parent
      anchors.margins: 20
      spacing: 14

      // ---------- search box ----------
      Rectangle {
        width: parent.width
        height: 44
        radius: 12
        color: Colors.card
        border.color: Colors.accent
        border.width: 1

        Row {
          anchors.fill: parent
          anchors.leftMargin: 14
          anchors.rightMargin: 14
          spacing: 10

          Text {
            text: "󰍉"
            color: Colors.accent
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            anchors.verticalCenter: parent.verticalCenter
          }

          TextInput {
            id: searchField
            width: parent.width - 34
            height: parent.height
            verticalAlignment: TextInput.AlignVCenter
            color: Colors.text
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
            clip: true

            onTextChanged: {
              root.query = text
              list.currentIndex = 0
            }
            Keys.onEscapePressed: root.toggle(root.popupName)
            Keys.onDownPressed: list.incrementCurrentIndex()
            Keys.onUpPressed: list.decrementCurrentIndex()
            Keys.onReturnPressed: root.launch(list.currentIndex)
            Keys.onEnterPressed: root.launch(list.currentIndex)

            Text {
              text: "Search apps..."
              color: Colors.text
              opacity: 0.4
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 15
              anchors.verticalCenter: parent.verticalCenter
              visible: searchField.text === ""
            }
          }
        }
      }

      // ---------- results ----------
      ListView {
        id: list
        width: parent.width
        height: parent.height - 44 - 14
        clip: true
        model: root.results
        currentIndex: 0
        highlightMoveDuration: 60
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
          required property var modelData
          required property int index

          width: list.width
          height: 48
          radius: 10
          color: list.currentIndex === index ? Colors.card : "transparent"

          Row {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 12

            Image {
              width: 32
              height: 32
              anchors.verticalCenter: parent.verticalCenter
              source: Quickshell.iconPath(modelData.icon, "application-x-executable")
              sourceSize: Qt.size(32, 32)
              fillMode: Image.PreserveAspectFit
            }

            Column {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - 44
              spacing: 1

              Text {
                text: modelData.name
                color: Colors.text
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                elide: Text.ElideRight
                width: parent.width
              }
              Text {
                visible: text !== ""
                text: modelData.comment ?? ""
                color: Colors.subtext
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                elide: Text.ElideRight
                width: parent.width
              }
            }
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: list.currentIndex = index
            onClicked: root.launch(index)
          }
        }
      }
    }
  }
}
