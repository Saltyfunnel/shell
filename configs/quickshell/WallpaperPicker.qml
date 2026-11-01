// WallpaperPicker.qml — bar icon + a searchable thumbnail grid of ~/Pictures/Wallpapers.
// Clicking a wallpaper hands its path to setwall.sh, which sets it and recolours everything.
import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: root

  property string popupName: "wallpaper"
  property string openPopup: ""
  signal toggle(string name)
  property alias popup: card        // shell.qml's focus grab uses this

  property bool isVisible: root.openPopup === root.popupName

  property string homeDir: Quickshell.env("HOME")
  property string wallpaperDir: homeDir + "/Pictures/Wallpapers"
  property string searchQuery: ""

  implicitWidth: 32
  implicitHeight: 24

  // ---------- bar icon ----------
  Text {
    anchors.centerIn: parent
    color: Colors.text
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 15
    text: "󰸉"
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggle(root.popupName)
  }

  // ---------- wallpaper list (scanned whenever the card is open) ----------
  ListModel { id: wallpaperModel }

  Process {
    id: loadWallpapers
    command: ["sh", "-c", "find " + root.wallpaperDir + " -maxdepth 1 -type f \\( -name '*.jpg' -o -name '*.png' -o -name '*.webp' -o -name '*.jpeg' \\) | sort"]
    running: root.isVisible
    onRunningChanged: if (running) wallpaperModel.clear()
    stdout: SplitParser {
      onRead: data => {
        var path = data.trim()
        if (path !== "") {
          wallpaperModel.append({ "filePath": path, "fileName": path.split("/").pop() })
        }
      }
    }
  }

  // ---------- the card ----------
  OverlayCard {
    id: card
    shown: root.isVisible
    cardWidth: 980
    cardHeight: 640
    onDismissed: root.toggle(root.popupName)

    onVisibleChanged: {
      if (!visible) {
        wallpaperModel.clear()
        root.searchQuery = ""
      } else {
        searchField.forceActiveFocus()
      }
    }

    Column {
      anchors.fill: parent
      anchors.margins: 24
      spacing: 16

      // Header: title + search box
      Row {
        width: parent.width
        height: 40
        spacing: 16

        Row {
          spacing: 10
          anchors.verticalCenter: parent.verticalCenter

          Text {
            text: "󰸉"
            color: Colors.accent
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 22
            anchors.verticalCenter: parent.verticalCenter
          }
          Text {
            text: "Wallpapers"
            color: Colors.text
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 18
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        Rectangle {
          width: 320
          height: 38
          radius: 10
          color: Colors.card
          border.color: searchField.activeFocus ? Colors.accent : "transparent"
          border.width: 1
          anchors.verticalCenter: parent.verticalCenter

          Row {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            Text {
              text: "󰍉"
              color: Colors.accent
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 14
              anchors.verticalCenter: parent.verticalCenter
            }

            TextInput {
              id: searchField
              width: parent.width - 30
              height: parent.height
              color: Colors.text
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 13
              anchors.verticalCenter: parent.verticalCenter
              verticalAlignment: TextInput.AlignVCenter
              clip: true

              onTextChanged: root.searchQuery = text.trim().toLowerCase()
              Keys.onEscapePressed: root.toggle(root.popupName)

              Text {
                text: "Search wallpapers..."
                color: Colors.text
                opacity: 0.4
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
                visible: searchField.text === ""
              }
            }
          }
        }
      }

      MenuDivider {}

      // Thumbnail grid
      GridView {
        id: gridView
        width: parent.width
        height: 500
        cellWidth: 220
        cellHeight: 165
        model: wallpaperModel
        clip: true
        focus: true

        delegate: Item {
          width: gridView.cellWidth
          height: gridView.cellHeight

          readonly property bool matchesSearch: root.searchQuery === "" || fileName.toLowerCase().includes(root.searchQuery)
          visible: matchesSearch

          Item {
            anchors.fill: parent
            anchors.margins: 6
            visible: parent.visible

            Rectangle {
              anchors.fill: parent
              radius: 12
              color: Colors.card
              border.color: mouseArea.containsMouse ? Colors.accent : "transparent"
              border.width: 1.5
              clip: true

              Image {
                anchors.fill: parent
                source: "file://" + filePath
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
              }

              // filename banner along the bottom
              Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 28
                color: "#aa000000"

                Text {
                  anchors.centerIn: parent
                  width: parent.width - 12
                  text: fileName
                  color: Colors.text
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: 11
                  elide: Text.ElideMiddle
                  horizontalAlignment: Text.AlignHCenter
                }
              }
            }

            MouseArea {
              id: mouseArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                Quickshell.execDetached([
                  "sh", "-c",
                  "export PATH=\"$PATH:" + root.homeDir + "/.cargo/bin\"; " +
                  "export HYPRLAND_INSTANCE_SIGNATURE=\"" + Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") + "\"; " +
                  "\"" + root.homeDir + "/.config/scripts/setwall.sh\" \"" + filePath + "\""
                ])
                root.toggle(root.popupName)
              }
            }
          }
        }
      }

      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: "Click to apply wallpaper    ·    Type to search    ·    Esc to close"
        color: Colors.text
        opacity: 0.6
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
      }
    }
  }
}
