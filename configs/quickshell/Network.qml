// Network.qml — what you are connected to, plus nearby Wi-Fi networks (laptops), via nmcli.
//   Bar item : network icon. Click to open the card.
//   Card     : connection details; on machines with Wi-Fi, a list of nearby networks.
//              Click a saved or open network to connect. New password-protected networks
//              open nmtui-connect in a terminal, which asks for the password.
import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: root

  property string popupName: "network"
  property string openPopup: ""
  signal toggle(string name)
  property alias popup: card        // shell.qml's focus grab uses this

  // ---------- current connection ----------
  property bool connected: false
  property bool isWifi: false
  property string connName: ""
  property string device: ""
  property string ip: ""
  property string gateway: ""
  property int signalPct: -1        // -1 = not a Wi-Fi connection

  // ---------- nearby Wi-Fi ----------
  property bool wifiChecked: false  // have we asked yet?
  property bool hasWifi: false      // does this machine have a Wi-Fi device?
  property var accessPoints: []     // [{ ssid, signal, secure, active, known }]

  implicitWidth: label.implicitWidth
  implicitHeight: label.implicitHeight

  // ---------- reading the current connection ----------
  Process {
    id: netProc
    command: ["sh", "-c",
      "line=$(nmcli -t -f TYPE,DEVICE,NAME connection show --active | grep -E '^(802-3-ethernet|802-11-wireless|ethernet|wifi):' | head -1); "
      + "[ ${#line} -eq 0 ] && exit 0; "
      + "type=${line%%:*}; rest=${line#*:}; dev=${rest%%:*}; name=${rest#*:}; "
      + "echo type $type; echo dev $dev; echo name $name; "
      + "echo ip $(nmcli -g IP4.ADDRESS device show $dev | head -1); "
      + "echo gw $(nmcli -g IP4.GATEWAY device show $dev | head -1); "
      + "case $type in 802-11-wireless|wifi) echo signal $(nmcli -t -f IN-USE,SIGNAL device wifi list ifname $dev | grep '^[*]' | cut -d: -f2 | head -1);; esac"]

    stdout: StdioCollector {
      onStreamFinished: {
        let c = false, wifi = false, name = "", dev = "", ip = "", gw = "", sig = -1
        for (const raw of text.split("\n")) {
          const line = raw.trim()
          const i = line.indexOf(" ")
          const key = i < 0 ? line : line.slice(0, i)
          const val = i < 0 ? "" : line.slice(i + 1).trim()
          if (key === "type")   { c = true; wifi = (val === "802-11-wireless" || val === "wifi") }
          if (key === "dev")    dev = val
          if (key === "name")   name = val
          if (key === "ip")     ip = val
          if (key === "gw")     gw = val
          if (key === "signal" && val !== "") sig = Number(val)
        }
        root.connected = c
        root.isWifi = wifi
        root.connName = name
        root.device = dev
        root.ip = ip
        root.gateway = gw
        root.signalPct = sig
      }
    }
  }

  // ---------- scanning for Wi-Fi networks ----------
  Process {
    id: wifiProc
    command: ["sh", "-c",
      "nmcli device wifi rescan >/dev/null 2>&1; "
      + "echo haswifi $(nmcli -t -f TYPE device | grep -c '^wifi$'); "
      + "nmcli -t -f NAME connection show | sed 's/^/known /'; "
      + "nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list 2>/dev/null | sed 's/^/ap /'"]

    stdout: StdioCollector {
      onStreamFinished: {
        let hasWifi = false
        const known = {}
        const best = {}
        for (const raw of text.split("\n")) {
          if (raw.startsWith("haswifi ")) hasWifi = Number(raw.slice(8)) > 0
          else if (raw.startsWith("known ")) known[raw.slice(6).trim()] = true
          else if (raw.startsWith("ap ")) {
            // fields: IN-USE : SIGNAL : SECURITY : SSID  (the SSID is last, and may contain colons)
            const p = raw.slice(3).split(":")
            const ssid = p.slice(3).join(":").replace(/\\:/g, ":").trim()
            if (ssid === "") continue
            const ap = {
              ssid: ssid,
              signal: Number(p[1]),
              secure: (p[2] || "") !== "" && p[2] !== "--",
              active: p[0] === "*",
              known: false
            }
            const cur = best[ssid]
            if (!cur || (!cur.active && (ap.active || ap.signal > cur.signal))) best[ssid] = ap
          }
        }
        const list = Object.values(best)
        for (const a of list) a.known = known[a.ssid] === true
        list.sort((a, b) => (b.active - a.active) || (b.signal - a.signal))

        root.hasWifi = hasWifi
        root.accessPoints = list.slice(0, 7)
        root.wifiChecked = true
      }
    }
  }

  // ---------- timers ----------
  // Current connection: every 5 seconds
  Timer {
    running: true
    interval: 5000
    repeat: true
    triggeredOnStart: true
    onTriggered: netProc.running = true
  }
  // Wi-Fi scan: once at start (to find out if there is Wi-Fi at all),
  // then only while the card is open, so a closed card never wakes the radio
  Timer {
    running: true
    interval: 10000
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!root.wifiChecked || (root.hasWifi && card.visible)) wifiProc.running = true
  }
  // Re-check shortly after you click a network
  Timer {
    id: afterAction
    interval: 3500
    onTriggered: { netProc.running = true; wifiProc.running = true }
  }

  // ---------- connecting ----------
  function connectTo(ap) {
    if (ap.active) return
    if (ap.known) {
      Quickshell.execDetached(["nmcli", "connection", "up", "id", ap.ssid])
    } else if (!ap.secure) {
      Quickshell.execDetached(["nmcli", "device", "wifi", "connect", ap.ssid])
    } else {
      // new password-protected network: let nmtui-connect ask for the password
      root.toggle(root.popupName)
      Quickshell.execDetached(["kitty", "-e", "nmtui-connect", ap.ssid])
    }
    afterAction.restart()
  }

  // ---------- bar item ----------
  Text {
    id: label
    color: root.connected ? Colors.text : Colors.subtext
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 15
    text: !root.connected ? "󰖪" : (root.isWifi ? "󰖩" : "󰈀")

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

    // refresh the list the moment the card opens
    onVisibleChanged: if (visible && root.hasWifi) wifiProc.running = true

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
        spacing: 12

        Text {
          text: "Network"
          color: Colors.text
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 16
          font.bold: true
        }

        Text {
          visible: !root.connected
          text: "Not connected"
          color: Colors.subtext
          font.pixelSize: 13
        }

        InfoRow { visible: root.connected; label: "Connection"; value: root.connName }
        InfoRow { visible: root.connected; label: "Type";       value: root.isWifi ? "Wi-Fi" : "Wired" }
        InfoRow { visible: root.connected; label: "Device";     value: root.device }
        InfoRow { visible: root.connected && root.ip !== "";      label: "IP address"; value: root.ip }
        InfoRow { visible: root.connected && root.gateway !== ""; label: "Gateway";    value: root.gateway }

        StatBar {
          visible: root.isWifi && root.signalPct >= 0
          label: "Signal"
          valueText: root.signalPct + "%"
          fraction: root.signalPct / 100
        }

        // ----- nearby Wi-Fi (only on machines that have Wi-Fi) -----
        MenuDivider { visible: root.hasWifi }

        Text {
          visible: root.hasWifi
          text: "Wi-Fi networks"
          color: Colors.text
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 14
          font.bold: true
        }

        Text {
          visible: root.hasWifi && root.accessPoints.length === 0
          text: "Scanning..."
          color: Colors.subtext
          font.pixelSize: 13
        }

        Column {
          width: parent.width
          spacing: 4

          Repeater {
            model: root.hasWifi ? root.accessPoints : []

            MenuRow {
              required property var modelData
              icon: "󰖩"
              iconColor: modelData.active ? Colors.accent : Colors.subtext
              label: modelData.ssid + (modelData.secure ? "  󰌾" : "") + "   " + modelData.signal + "%"
              onClicked: root.connectTo(modelData)
            }
          }
        }
      }
    }
  }
}
