import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

Item {
  id: root

  property string popupName: "wallpaper_picker"
  property string openPopup: ""
  signal toggle(string name)
  property alias popup: popupWindow

  property string homeDir: "/home/" + Quickshell.env("USER")
  property string wallpaperDir: homeDir + "/Pictures/Wallpapers"

  Component.onCompleted: console.log(">>> WallpaperPicker.qml loaded successfully!")

  implicitWidth: iconLabel.implicitWidth
  implicitHeight: iconLabel.implicitHeight

  // Bar Icon Trigger
  Text {
    id: iconLabel
    color: Colors.text
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 15
    text: "󰸉"

    MouseArea {
      anchors.fill: parent
      onClicked: {
        console.log(">>> Bar icon clicked, toggling popup:", root.popupName);
        root.toggle(root.popupName);
      }
    }
  }

  // Wallpaper Picker Popup Window
  PopupWindow {
    id: popupWindow
    anchor.item: root
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    visible: root.openPopup === root.popupName
    implicitWidth: 640
    implicitHeight: 420
    color: "transparent"

    onVisibleChanged: {
      console.log(">>> WallpaperPicker popup visibility changed to:", visible);
      if (!visible) {
        wallpaperModel.clear();
      } else {
        gridView.forceActiveFocus();
      }
    }

    // Scan wallpaper directory
    Process {
      id: listWallpapers
      command: ["sh", "-c", "find " + root.wallpaperDir + " -maxdepth 1 -type f \\( -name '*.jpg' -o -name '*.png' -o -name '*.webp' -o -name '*.jpeg' \\) | sort"]
      running: root.openPopup === root.popupName
      stdout: SplitParser {
        onRead: data => {
          var path = data.trim();
          if (path !== "") {
            wallpaperModel.append({ "filePath": path, "fileName": path.split("/").pop() })
          }
        }
      }
    }

    ListModel {
      id: wallpaperModel
    }

    Rectangle {
      anchors.fill: parent
      anchors.topMargin: 8
      radius: 14
      color: Colors.surface
      border.color: Colors.accent
      border.width: 1

      Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // Header Title
        Row {
          width: parent.width
          height: 24
          Text {
            text: "Select Wallpaper (" + wallpaperModel.count + ")"
            color: Colors.text
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            font.bold: true
          }
        }

        // Main Grid Container
        Item {
          width: parent.width
          height: parent.height - 34

          Text {
            anchors.centerIn: parent
            visible: wallpaperModel.count === 0
            text: "Scanning wallpapers..."
            color: Colors.text
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
          }

          GridView {
            id: gridView
            anchors.fill: parent
            model: wallpaperModel
            cellWidth: 145
            cellHeight: 115
            clip: true
            focus: true

            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                var item = wallpaperModel.get(gridView.currentIndex);
                if (item) {
                  console.log("-> Enter key pressed for wallpaper:", item.filePath);
                  Quickshell.execDetached([
                    "sh", "-c",
                    "export PATH=\"$PATH:" + root.homeDir + "/.cargo/bin\"; " +
                    "export HYPRLAND_INSTANCE_SIGNATURE=\"" + Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") + "\"; " +
                    "\"" + root.homeDir + "/.config/scripts/setwall.sh\" \"" + item.filePath + "\""
                  ]);
                  root.openPopup = "";
                }
                event.accepted = true;
              } else if (event.key === Qt.Key_Escape) {
                root.openPopup = "";
                event.accepted = true;
              }
            }

            delegate: Item {
              width: 135
              height: 105

              Rectangle {
                anchors.fill: parent
                radius: 8
                color: gridView.currentIndex === index ? Colors.accent : Colors.card
                border.color: gridView.currentIndex === index ? Colors.text : "transparent"
                border.width: 2
                clip: true

                Column {
                  anchors.fill: parent
                  anchors.margins: 6
                  spacing: 4

                  Rectangle {
                    width: 123
                    height: 72
                    radius: 6
                    color: "black"
                    clip: true

                    Image {
                      anchors.fill: parent
                      source: "file://" + filePath
                      fillMode: Image.PreserveAspectCrop
                      asynchronous: true
                      smooth: true
                    }
                  }

                  Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: fileName
                    color: Colors.text
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    elide: Text.ElideMiddle
                  }
                }

                // TapHandler reliably captures taps inside GridView/Flickable areas
                TapHandler {
                  onTapped: {
                    console.log(">>> TAP DETECTED ON WALLPAPER:", filePath);
                    gridView.currentIndex = index;
                    Quickshell.execDetached([
                      "sh", "-c",
                      "export PATH=\"$PATH:" + root.homeDir + "/.cargo/bin\"; " +
                      "export HYPRLAND_INSTANCE_SIGNATURE=\"" + Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") + "\"; " +
                      "\"" + root.homeDir + "/.config/scripts/setwall.sh\" \"" + filePath + "\""
                    ]);
                    root.openPopup = "";
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
