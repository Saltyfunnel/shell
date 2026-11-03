// ConnectivityPanel.qml — the dashboard's Connectivity tab: network + Wi-Fi list, Bluetooth devices.
import QtQuick

DashPanel {
  Row {
    anchors.fill: parent
    anchors.margins: 28
    spacing: 40

    // ----- network -----
    Column {
      width: (parent.width - parent.spacing) / 2
      spacing: 8

      Text {
        text: "Network"
        color: Colors.text
        font.family: Theme.font
        font.pixelSize: 16
        font.bold: true
      }

      InfoRow { label: "Connection"; value: Connectivity.connected ? Connectivity.connName : "Not connected" }
      InfoRow { visible: Connectivity.connected; label: "Type"; value: Connectivity.isWifi ? "Wi-Fi" : "Wired" }
      InfoRow { visible: Connectivity.connected && Connectivity.ip !== ""; label: "IP address"; value: Connectivity.ip }

      MenuDivider { visible: Connectivity.hasWifi }

      Text {
        visible: Connectivity.hasWifi
        text: "Wi-Fi networks"
        color: Colors.text
        font.family: Theme.font
        font.pixelSize: 14
        font.bold: true
      }
      Text {
        visible: Connectivity.hasWifi && Connectivity.accessPoints.length === 0
        text: "Scanning..."
        color: Colors.subtext
        font.family: Theme.font
        font.pixelSize: 13
      }
      Repeater {
        model: Connectivity.hasWifi ? Connectivity.accessPoints.slice(0, 5) : []

        MenuRow {
          required property var modelData
          icon: "\udb81\udda9"
          iconColor: modelData.active ? Colors.accent : Colors.subtext
          label: modelData.ssid + (modelData.secure ? "  \udb80\udf3e" : "") + "   " + modelData.signal + "%"
          onClicked: Connectivity.connectTo(modelData)
        }
      }
    }

    // ----- bluetooth -----
    Column {
      width: (parent.width - parent.spacing) / 2
      spacing: 8

      Text {
        text: "Bluetooth"
        color: Colors.text
        font.family: Theme.font
        font.pixelSize: 16
        font.bold: true
      }

      Text {
        visible: !Connectivity.hasAdapter
        text: "No Bluetooth adapter found"
        color: Colors.subtext
        font.family: Theme.font
        font.pixelSize: 13
      }

      MenuRow {
        visible: Connectivity.hasAdapter
        icon: Connectivity.powered ? "\udb80\udcaf" : "\udb80\udcb2"
        label: Connectivity.powered ? "Turn off" : "Turn on"
        onClicked: Connectivity.runBt(["bluetoothctl", "power", Connectivity.powered ? "off" : "on"])
      }

      Text {
        visible: Connectivity.hasAdapter && Connectivity.powered && Connectivity.devices.length === 0
        text: "No paired devices"
        color: Colors.subtext
        font.family: Theme.font
        font.pixelSize: 13
      }

      Repeater {
        model: (Connectivity.hasAdapter && Connectivity.powered) ? Connectivity.devices : []

        MenuRow {
          required property var modelData
          icon: modelData.connected ? "\udb80\udcb1" : "\udb80\udcaf"
          iconColor: modelData.connected ? Colors.accent : Colors.subtext
          label: modelData.name + (modelData.connected ? "   connected" : "")
          onClicked: Connectivity.runBt(["bluetoothctl", modelData.connected ? "disconnect" : "connect", modelData.mac])
        }
      }
    }
  }
}
