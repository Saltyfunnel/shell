// WallpaperPicker.qml — bar icon + a carousel wallpaper picker.
//   A big preview of the selected wallpaper, and a strip of thumbnails with the selected one enlarged.
//   Left / Right (or the mouse wheel) move along the strip, Enter or a click on the selected one applies it.
//   Type to search. Esc closes. Applying hands the path to setwall.sh, which recolours everything.
import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    property string popupName: "wallpaper"
    property string openPopup: ""
    signal toggle(string name)

    // Add this IPC bridge:
    IpcHandler {
        target: "WallpaperPicker"
        function toggle(): void {
            root.toggle(root.popupName)
        }
    }
  property alias popup: card        // shell.qml's focus grab uses this

  property bool isVisible: root.openPopup === root.popupName

  property string homeDir: Quickshell.env("HOME")
  property string wallpaperDir: homeDir + "/Pictures/Wallpapers"
  property string searchQuery: ""

  // every wallpaper found: [{ path, name }]
  property var all: []
  // the ones matching the search
  property var results: {
    const q = root.searchQuery
    if (q === "") return root.all
    return root.all.filter(w => w.name.toLowerCase().includes(q))
  }
  property var current: strip.currentIndex >= 0 && strip.currentIndex < results.length ? results[strip.currentIndex] : null

  implicitWidth: 32
  implicitHeight: 24

  function apply(w) {
    if (!w) return
    Quickshell.execDetached([
      "sh", "-c",
      "export PATH=\"$PATH:" + root.homeDir + "/.cargo/bin\"; " +
      "export HYPRLAND_INSTANCE_SIGNATURE=\"" + Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") + "\"; " +
      "\"" + root.homeDir + "/.config/scripts/setwall.sh\" \"" + w.path + "\""
    ])
    root.toggle(root.popupName)
  }

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

  // ---------- scanning the wallpaper folder whenever the card is open ----------
  Process {
    id: loadWallpapers
    command: ["sh", "-c", "find " + root.wallpaperDir + " -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.jpeg' \\) | sort"]
    running: root.isVisible
    onRunningChanged: if (running) root.all = []
    stdout: SplitParser {
      onRead: data => {
        const path = data.trim()
        if (path !== "") root.all = root.all.concat([{ path: path, name: path.split("/").pop() }])
      }
    }
  }

  // ---------- the card ----------
  OverlayCard {
    id: card
    shown: root.isVisible
    cardWidth: 1000
    cardHeight: 640
    cardRadius: 22
    onDismissed: root.toggle(root.popupName)

    onVisibleChanged: {
      if (!visible) {
        root.all = []
        root.searchQuery = ""
        searchField.text = ""
      } else {
        strip.currentIndex = 0
        searchField.forceActiveFocus()
      }
    }

    // Enable mouse wheel scrolling anywhere across the entire wallpaper card
    WheelHandler {
      onWheel: event => {
        const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
        if (delta > 0) {
          strip.decrementCurrentIndex()
        } else if (delta < 0) {
          strip.incrementCurrentIndex()
        }
        event.accepted = true
      }
    }

    Column {
      anchors.fill: parent
      anchors.margins: 24
      spacing: 14

      // ----- header: title + search -----
      Row {
        width: parent.width
        height: 38
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
          width: 280
          height: 34
          radius: 17
          color: Colors.card
          border.color: searchField.activeFocus ? Colors.accent : "transparent"
          border.width: 1
          anchors.verticalCenter: parent.verticalCenter

          Row {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 8

            Text {
              text: "󰍉"
              color: Colors.accent
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 14
              anchors.verticalCenter: parent.verticalCenter
            }

            TextInput {
              id: searchField
              width: parent.width - 28
              height: parent.height
              color: Colors.text
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 13
              verticalAlignment: TextInput.AlignVCenter
              clip: true

              onTextChanged: {
                root.searchQuery = text.trim().toLowerCase()
                strip.currentIndex = 0
              }
              Keys.onEscapePressed: root.toggle(root.popupName)
              Keys.onReturnPressed: root.apply(root.current)
              Keys.onEnterPressed: root.apply(root.current)
              // Left / Right move along the strip, unless you are editing a search
              Keys.onLeftPressed: event => { if (text === "") strip.decrementCurrentIndex(); else event.accepted = false }
              Keys.onRightPressed: event => { if (text === "") strip.incrementCurrentIndex(); else event.accepted = false }

              Text {
                text: "Search..."
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

      // ----- big preview of the selected wallpaper -----
      Item {
        width: parent.width
        height: 300

        Rectangle {
          anchors.fill: parent
          radius: 16
          color: Colors.card
        }
        RoundedImage {
          anchors.fill: parent
          radius: 16
          source: root.current ? "file://" + root.current.path : ""
        }
        Text {
          anchors.centerIn: parent
          visible: root.results.length === 0
          text: root.all.length === 0 ? "No wallpapers found in ~/Pictures/Wallpapers" : "No matches"
          color: Colors.subtext
          font.pixelSize: 14
        }
      }

      // ----- the strip -----
      ListView {
        id: strip
        width: parent.width
        height: 168
        orientation: ListView.Horizontal
        model: root.results
        clip: true
        currentIndex: 0
        highlightRangeMode: ListView.StrictlyEnforceRange     // keep the selected one centred
        preferredHighlightBegin: width / 2 - 120
        preferredHighlightEnd: width / 2 + 120
        highlightMoveDuration: 220

        delegate: Item {
          required property var modelData
          required property int index
          readonly property bool selected: ListView.isCurrentItem

          width: 240
          height: strip.height
          z: selected ? 2 : 1
          scale: selected ? 1.15 : 0.85
          opacity: selected ? 1 : 0.65
          Behavior on scale   { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
          Behavior on opacity { NumberAnimation { duration: 200 } }

          Column {
            anchors.centerIn: parent
            spacing: 8

            Item {
              width: 200
              height: 112

              Rectangle {
                anchors.fill: parent
                radius: 12
                color: Colors.card
              }
              RoundedImage {
                anchors.fill: parent
                radius: 12
                decodeWidth: 400
                source: "file://" + modelData.path
              }
              Rectangle {
                anchors.fill: parent
                radius: 12
                color: "transparent"
                border.width: selected ? 2 : 0
                border.color: Colors.accent
              }
            }

            Text {
              width: 200
              text: modelData.name
              color: selected ? Colors.text : Colors.subtext
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 11
              elide: Text.ElideMiddle
              horizontalAlignment: Text.AlignHCenter
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (selected) root.apply(modelData); else strip.currentIndex = index
          }
        }
      }

      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: "← → / scroll  browse    ·    Enter / click selected  apply    ·    type to search    ·    Esc  close"
        color: Colors.subtext
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 11
      }
    }
  }
}
