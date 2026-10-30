import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Window

Item {
  id: root

  property string popupName: "wallpaper_picker"
  property string openPopup: ""
  signal toggle(string name)
  property alias popup: popupWindow

  property bool localOpen: false
  property bool isVisible: localOpen || (root.openPopup === root.popupName)

  property string homeDir: "/home/" + Quickshell.env("USER")
  property string wallpaperDir: homeDir + "/Pictures/Wallpapers"

  Component.onCompleted: console.log(">>> WallpaperPicker loaded successfully!")

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
        console.log(">>> Bar icon clicked. localOpen is now:", root.localOpen);
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
      console.log(">>> PanelWindow visibility changed to:", visible);
      if (!visible) {
        wallpaperModel.clear();
      } else {
        popupWindow.requestActivate();
        listView.forceActiveFocus();
      }
    }

    // Scan wallpaper directory
    Process {
      id: listWallpapers
      command: ["sh", "-c", "find " + root.wallpaperDir + " -maxdepth 1 -type f \\( -name '*.jpg' -o -name '*.png' -o -name '*.webp' -o -name '*.jpeg' \\) | sort"]
      running: root.isVisible
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

    // Transparent full-screen backdrop (clicking outside closes picker)
    Rectangle {
      anchors.fill: parent
      color: "transparent"

      TapHandler {
        onTapped: {
          console.log(">>> Backdrop tapped, closing picker");
          root.localOpen = false;
          root.toggle(root.popupName);
        }
      }

      // Centered Floating Carousel Card
      Rectangle {
        id: floatingCard
        anchors.centerIn: parent
        width: 1100
        height: 440
        radius: 18
        color: Colors.surface
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

          // Header Title & Active Filename
          Row {
            width: parent.width
            height: 30
            spacing: 12

            Text {
              text: "󰸉"
              color: Colors.accent
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 20
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              text: wallpaperModel.count > 0 && listView.currentIndex >= 0 && listView.currentIndex < wallpaperModel.count ? wallpaperModel.get(listView.currentIndex).fileName : "Select Wallpaper"
              color: Colors.text
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 16
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
              elide: Text.ElideMiddle
              width: parent.width - 60
            }
          }

          // Horizontal Cover Flow ListView Carousel Container
          Item {
            width: parent.width
            height: 300

            ListView {
              id: listView
              anchors.fill: parent
              orientation: ListView.Horizontal
              model: wallpaperModel
              spacing: 24
              clip: false
              focus: true
              preferredHighlightBegin: parent.width / 2 - 110
              preferredHighlightEnd: parent.width / 2 + 110
              highlightRangeMode: ListView.StrictlyEnforceRange
              highlightMoveDuration: 200

              // Keyboard navigation and Enter/Escape handler
              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Left || event.key === Qt.Key_H || event.key === Qt.Key_A) {
                  if (listView.currentIndex > 0) {
                    listView.currentIndex--;
                    listView.positionViewAtIndex(listView.currentIndex, ListView.Center);
                  }
                  event.accepted = true;
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L || event.key === Qt.Key_D) {
                  if (listView.currentIndex < wallpaperModel.count - 1) {
                    listView.currentIndex++;
                    listView.positionViewAtIndex(listView.currentIndex, ListView.Center);
                  }
                  event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                  var item = wallpaperModel.get(listView.currentIndex);
                  if (item) {
                    console.log(">>> Enter pressed, setting wallpaper:", item.filePath);
                    Quickshell.execDetached([
                      "sh", "-c",
                      "export PATH=\"$PATH:" + root.homeDir + "/.cargo/bin\"; " +
                      "export HYPRLAND_INSTANCE_SIGNATURE=\"" + Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") + "\"; " +
                      "\"" + root.homeDir + "/.config/scripts/setwall.sh\" \"" + item.filePath + "\""
                    ]);
                    root.localOpen = false;
                    root.toggle(root.popupName);
                  }
                  event.accepted = true;
                } else if (event.key === Qt.Key_Escape) {
                  console.log(">>> Escape pressed, closing picker");
                  root.localOpen = false;
                  root.toggle(root.popupName);
                  event.accepted = true;
                }
              }

              delegate: Item {
                id: cardDelegate
                width: 210
                height: 280

                property real viewCenterX: listView.contentX + listView.width / 2
                property real itemCenterX: x + width / 2
                property real distance: Math.abs(viewCenterX - itemCenterX)
                property real progress: Math.min(distance / (listView.width / 2.5), 1.0)

                scale: 1.45 - (0.5 * progress)
                opacity: 1.0 - (0.65 * progress)
                z: 100 - Math.round(distance)

                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                Rectangle {
                  anchors.fill: parent
                  radius: 16
                  color: Colors.card
                  clip: true

                  Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 12
                    color: "black"
                    clip: true

                    Image {
                      anchors.fill: parent
                      source: "file://" + filePath
                      fillMode: Image.PreserveAspectCrop
                      asynchronous: true
                      smooth: true
                    }

                    Rectangle {
                      anchors.fill: parent
                      color: "black"
                      opacity: listView.currentIndex === index ? 0.0 : 0.45
                      Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (listView.currentIndex !== index) {
                      listView.currentIndex = index;
                      listView.positionViewAtIndex(index, ListView.Center);
                    } else {
                      console.log(">>> Thumbnail clicked to set wallpaper:", filePath);
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
          }

          // Hint Footer
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "← → / Scroll to browse   ·   Enter to set   ·   Esc to close"
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
