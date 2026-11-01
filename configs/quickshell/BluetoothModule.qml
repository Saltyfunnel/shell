// BluetoothModule.qml — paired Bluetooth devices via bluetoothctl.
//   Bar item : bluetooth icon (hidden if this machine has no adapter).
//   Card     : power on/off, and your paired devices. Click one to connect / disconnect.
import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: root

  property string popupName: "bluetooth"
  property string openPopup: ""
  signal toggle(string name)
  property alias popup: card        // shell.qml's focus grab uses this

  // ---------- latest readings ----------
  property bool hasAdapter: false
  property bool powered: false
  property var devices: []          // [{ mac, name, connected }]
  readonly property bool anyConnected: devices.some(d => d.connected)

  // no adapter (a desktop without Bluetooth) -> take up no space in the bar
  visible: hasAdapter
  implicitWidth: visible ? label.implicitWidth : 0
  implicitHeight: label.implicitHeight

  // ---------- reading bluetoothctl ----------
  Process {
    id: btProc
    command: ["sh", "-c",
      "echo adapter $(bluetoothctl show 2>/dev/null | grep -c Controller); "
      + "echo powered $(bluetoothctl show 2>/dev/null | grep -c 'Powered: yes'); "
      + "bluetoothctl devices Paired 2>/dev/null | sed 's/^Device /paired /'; "
      + "bluetoothctl devices Connected 2>/dev/null | sed 's/^Device /connected /'"]

    stdout: StdioCollector {
      onStreamFinished: {
        let adapter = false, powered = false
        const names = {}
        const paired = []
        const connected = {}
        for (const raw of text.split("\n")) {
          const line = raw.trim()
          const parts = line.split(" ")
          if (parts[0] === "adapter") adapter = Number(parts[1]) > 0
          else if (parts[0] === "powered") powered = Number(parts[1]) > 0
          else if (parts[0] === "paired" || parts[0] === "connected") {
            const mac = parts[1]
            const name = parts.slice(2).join(" ") || mac
            if (parts[0] === "paired") { paired.push(mac); names[mac] = name }
            else connected[mac] = true
          }
        }
        root.hasAdapter = adapter
        root.powered = powered
        root.devices = paired.map(m => ({ mac: m, name: names[m], connected: connected[m] === true }))
      }
    }
  }

  // Check every 5 seconds, and again shortly after you click something
  Timer {
    running: true
    interval: 5000
    repeat: true
    triggeredOnStart: true
    onTriggered: btProc.running = true
  }
  Timer {
    id: afterAction
    interval: 2500
    onTriggered: btProc.running = true
  }

  function run(args) {
    Quickshell.execDetached(args)
    afterAction.restart()
  }

  // ---------- bar item ----------
  Text {
    id: label
    color: root.powered ? Colors.text : Colors.subtext
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 15
    // off / on / connected
    text: !root.powered ? "\udb80\udcb2" : (root.anyConnected ? "\udb80\udcb1" : "\udb80\udcaf")

    MouseArea {
      anchors.fill: parent
      onClicked: root.toggle(root.popupName)
    }
  }

  // ---------- the card ----------
  PopupWindow {
    id: card
    anchor.item: root
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    visible: root.openPopup === root.popupName
    implicitWidth: 300
    implicitHeight: content.implicitHeight + 44
    color: "transparent"

    Rectangle {
      anchors.fill: parent
      anchors.topMargin: 8
      radius: 16
      color: Colors.card

      Column {
        id: content
        x: 18
        y: 18
        width: parent.width - 36
        spacing: 8

        Text {
          text: "Bluetooth"
          color: Colors.text
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 16
          font.bold: true
        }

        MenuRow {
          icon: root.powered ? "\udb80\udcaf" : "\udb80\udcb2"
          label: root.powered ? "Turn off" : "Turn on"
          onClicked: root.run(["bluetoothctl", "power", root.powered ? "off" : "on"])
        }

        MenuDivider { visible: root.powered && root.devices.length > 0 }

        Text {
          visible: root.powered && root.devices.length === 0
          text: "No paired devices"
          color: Colors.subtext
          font.pixelSize: 13
        }

        Repeater {
          model: root.powered ? root.devices : []

          MenuRow {
            required property var modelData
            icon: modelData.connected ? "\udb80\udcb1" : "\udb80\udcaf"
            iconColor: modelData.connected ? Colors.accent : Colors.subtext
            label: modelData.name + (modelData.connected ? "   connected" : "")
            onClicked: root.run(["bluetoothctl", modelData.connected ? "disconnect" : "connect", modelData.mac])
          }
        }
      }
    }
  }
}
