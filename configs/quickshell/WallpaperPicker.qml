import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Window

Item {
  id: root

  property string popupName: "wallpaper"
  property string openPopup: ""
  signal toggle(string name)
  property alias popup: popupWindow

  property bool localOpen: false
  property bool isVisible: localOpen || (root.openPopup === root.popupName)

  property string homeDir: "/home/" + Quickshell.env("USER")
  property string wallpaperDir: homeDir + "/Pictures/Wallpapers"
  property string searchQuery: ""

  implicitWidth: 32
  implicitHeight: 24

  // Bar Icon Trigger
  Rectangle {
    anchors.fill: parent
    color: "transparent"

    Text {
      id: iconLabel
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
      onClicked: {
        root.localOpen = !root.localOpen;
        root.toggle(root.popupName);
      }
    }
  }

  // Full-Screen Centered Floating Overlay PanelWindow
  PanelWindow {
    id: popupWindow
    visible: root.isVisible
    focusable: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    onVisibleChanged: {
      if (!visible) {
        wallpaperModel.clear();
        root.searchQuery = "";
      } else {
        popupWindow.requestActivate();
        searchField.forceActiveFocus();
      }
    }

    // Scan wallpaper directory automatically when visible
    Process {
      id: loadWallpapers
      command: ["sh", "-c", "find " + root.wallpaperDir + " -maxdepth 1 -type f \\( -name '*.jpg' -o -name '*.png' -o -name '*.webp' -o -name '*.jpeg' \\) | sort"]
      running: root.isVisible
      onRunningChanged: {
        if (running) {
          wallpaperModel.clear();
        }
      }
      stdout: SplitParser {
        onRead: data => {
          var path = data.trim();
          if (path !== "") {
            var name = path.split("/").pop();
            wallpaperModel.append({ "filePath": path, "fileName": name });
          }
        }
      }
    }

    ListModel {
      id: wallpaperModel
    }

    // Transparent full-screen backdrop (clicking outside closes picker)
    Rectangle {
      anchors.fill: parent
      color: "transparent"

      TapHandler {
        onTapped: {
          root.localOpen = false;
          root.toggle(root.popupName);
        }
      }

      // Centered Floating Grid Card
      Rectangle {
        id: floatingCard
        anchors.centerIn: parent
        width: 980
        height: 640
        radius: 18
        color: Colors.surface
        border.color: Colors.accent
        border.width: 1.2
        clip: true

        // Absorb clicks inside the card so backdrop doesn't close it
        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.AllButtons
        }

        Column {
          anchors.fill: parent
          anchors.margins: 24
          spacing: 16

          // Header: Title & Search Bar
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

            // Search Input Box
            Rectangle {
              width: 320
              height: 38
              radius: 10
              color: Colors.card
              border.color: searchField.activeFocus ? Colors.accent : "transparent"
              border.width: 1.2
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

                  onTextChanged: {
                    root.searchQuery = text.trim().toLowerCase();
                  }

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

          // Subtle Divider
          Item {
            width: parent.width
            height: 4
            Rectangle {
              anchors.centerIn: parent
              width: parent.width
              height: 1
              color: Colors.accent
              opacity: 0.2
            }
          }

          // Direct GridView (Flickable handles its own scrolling)
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

                  // Bottom Filename Label Banner
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
                    ]);
                    root.localOpen = false;
                    root.toggle(root.popupName);
                  }
                }
              }
            }
          }

          // Hint Footer
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Click to apply wallpaper    ·    Type to search    ·    Esc to close"
            color: Colors.text
            opacity: 0.6
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
          }
        }
      }
    }
  }
}
