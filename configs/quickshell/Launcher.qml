// Launcher.qml — Flipped 2-Pane Spotlight Layout with Actual Mini Wallpaper Preview on Left
import Quickshell
import Quickshell.Io
import QtQuick

Scope {
  id: root

  property string popupName: "launcher"
  property string openPopup: ""
  signal toggle(string name)
  property alias popup: card

  property string query: ""
  property string wallpaperPath: ""

  // Automatically fetch the active wallpaper path from common config/cache locations
  Process {
    id: wallpaperProc
    command: ["sh", "-c", "if [ -f \"$HOME/.config/hypr/wallpaper.png\" ]; then echo -n \"$HOME/.config/hypr/wallpaper.png\"; elif [ -f \"$HOME/.cache/current_wallpaper\" ]; then cat \"$HOME/.cache/current_wallpaper\"; else echo -n \"$HOME/.config/hypr/hyprpaper.conf\"; fi"]
    running: true
    stdout: SplitParser {
      onRead: data => {
        const cleaned = data.trim()
        if (cleaned !== "") {
          root.wallpaperPath = "file://" + cleaned
        }
      }
    }
  }

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
    cardWidth: 760
    cardHeight: 480
    onDismissed: root.toggle(root.popupName)

    onVisibleChanged: {
      if (visible) {
        searchField.text = ""
        root.query = ""
        list.currentIndex = 0
        searchField.forceActiveFocus()
        wallpaperProc.running = true
      }
    }

    Row {
      anchors.fill: parent
      anchors.margins: 16
      spacing: 16

      // ==========================================
      // LEFT PANE: Mini Wallpaper Preview & Details (42%)
      // ==========================================
      Rectangle {
        width: Math.floor(parent.width * 0.42) - 8
        height: parent.height
        radius: 16
        clip: true
        color: Qt.darker(Colors.card, 1.4)
        border.color: Qt.alpha(Colors.text, 0.1)
        border.width: 1

        // Actual Mini Wallpaper Image Copied Inside
        Image {
          id: miniWallpaper
          anchors.fill: parent
          source: root.wallpaperPath
          fillMode: Image.PreserveAspectCrop
          opacity: 0.6
        }

        // Dark Overlay Tint to keep text legible over the wallpaper
        Rectangle {
          anchors.fill: parent
          color: Qt.rgba(0, 0, 0, 0.55)
        }

        // Active Application Metadata Display
        Item {
          anchors.fill: parent

          property var activeEntry: root.results.length > 0 && list.currentIndex >= 0 && list.currentIndex < root.results.length
            ? root.results[list.currentIndex]
            : null

          Column {
            anchors.centerIn: parent
            width: parent.width - 32
            spacing: 14
            visible: parent.activeEntry !== null

            Image {
              width: 84
              height: 84
              anchors.horizontalCenter: parent.horizontalCenter
              source: parent.parent.activeEntry ? Quickshell.iconPath(parent.parent.activeEntry.icon, "application-x-executable") : ""
              sourceSize: Qt.size(84, 84)
              fillMode: Image.PreserveAspectFit
            }

            Column {
              width: parent.width
              spacing: 4

              Text {
                text: parent.parent.parent.activeEntry ? parent.parent.parent.activeEntry.name : ""
                color: Colors.text
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 18
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
                elide: Text.ElideRight
              }

              Text {
                text: parent.parent.parent.activeEntry ? (parent.parent.parent.activeEntry.comment ?? parent.parent.parent.activeEntry.genericName ?? "Application") : ""
                color: Colors.subtext
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
                wrapMode: Text.WordWrap
                opacity: 0.85
                maximumLineCount: 3
                elide: Text.ElideRight
              }
            }

            Rectangle {
              width: parent.width
              height: 1
              color: Qt.alpha(Colors.text, 0.2)
            }

            // Command Executable Pill
            Rectangle {
              height: 30
              width: Math.min(parent.width, cmdText.implicitWidth + 24)
              anchors.horizontalCenter: parent.horizontalCenter
              radius: 8
              color: Qt.alpha(Colors.card, 0.85)
              border.color: Qt.alpha(Colors.accent, 0.4)
              border.width: 1

              Text {
                id: cmdText
                text: "󰆍  " + (parent.parent.parent.parent.activeEntry ? (parent.parent.parent.parent.activeEntry.exec ?? "binary") : "")
                color: Colors.accent
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                anchors.centerIn: parent
                elide: Text.ElideRight
                width: parent.width - 16
              }
            }
          }
        }
      }

      // ==========================================
      // RIGHT PANE: Search Bar & Application List (58%)
      // ==========================================
      Column {
        width: Math.floor(parent.width * 0.58) - 8
        height: parent.height
        spacing: 14

        // Search Header Field
        Rectangle {
          width: parent.width
          height: 48
          radius: 12
          color: Qt.darker(Colors.card, 1.2)
          border.color: searchField.activeFocus ? Colors.accent : Qt.alpha(Colors.text, 0.1)
          border.width: searchField.activeFocus ? 2 : 1

          Behavior on border.color { ColorAnimation { duration: 120 } }

          Row {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12

            Text {
              text: "󰍉"
              color: Colors.accent
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 18
              anchors.verticalCenter: parent.verticalCenter
            }

            TextInput {
              id: searchField
              width: parent.width - 40
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
                color: Colors.subtext
                opacity: 0.4
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 15
                anchors.verticalCenter: parent.verticalCenter
                visible: searchField.text === ""
              }
            }
          }
        }

        // App List
        ListView {
          id: list
          width: parent.width
          height: parent.height - 48 - 14
          clip: true
          model: root.results
          currentIndex: 0
          spacing: 4
          boundsBehavior: Flickable.StopAtBounds

          delegate: Rectangle {
            required property var modelData
            required property int index

            width: list.width
            height: 46
            radius: 10
            color: list.currentIndex === index ? Qt.alpha(Colors.accent, 0.18) : "transparent"
            border.color: list.currentIndex === index ? Qt.alpha(Colors.accent, 0.4) : "transparent"
            border.width: 1

            Behavior on color { ColorAnimation { duration: 100 } }

            Row {
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              spacing: 12

              Image {
                width: 26
                height: 26
                anchors.verticalCenter: parent.verticalCenter
                source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                sourceSize: Qt.size(26, 26)
                fillMode: Image.PreserveAspectFit
              }

              Text {
                text: modelData.name
                color: list.currentIndex === index ? Colors.accent : Colors.text
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                font.weight: list.currentIndex === index ? Font.Bold : Font.Normal
                elide: Text.ElideRight
                width: parent.width - 70
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: "󰌑"
                color: Colors.accent
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
                visible: list.currentIndex === index
                opacity: 0.7
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
}
