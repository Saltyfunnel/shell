// Hardware.qml — CPU / memory / disk / temperatures / battery.
//   Bar item : chip icon + CPU %. Click to open the card.
//   Card     : a bar for each reading. Readings refresh every 2 seconds.
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick

Item {
  id: root

  property string popupName: "hardware"
  property string openPopup: ""
  signal toggle(string name)
  property alias popup: card        // shell.qml's focus grab uses this

  // ---------- latest readings (-1 = no sensor, so that row stays hidden) ----------
  property real cpu: 0
  property real ram: 0
  property real ramUsedGb: 0
  property real ramTotalGb: 0
  property real diskUsedGb: 0
  property real diskTotalGb: 0
  property int cpuTemp: -1
  property int gpuTemp: -1
  property int gpuLoad: -1
  property real lastTotal: 0
  property real lastIdle: 0

  // last ~2 minutes of readings for the charts (one sample every 2 seconds)
  readonly property int historyLength: 60
  property var cpuHistory: []
  property var ramHistory: []

  readonly property bool hasBattery: UPower.displayDevice?.isLaptopBattery ?? false
  readonly property real batteryPct: (UPower.displayDevice?.percentage ?? 0) * 100

  implicitWidth: label.implicitWidth
  implicitHeight: label.implicitHeight

  // ---------- reading the system ----------

  // CPU: compare /proc/stat now against the last reading
  FileView {
    id: statFile
    path: "/proc/stat"
    onLoaded: {
      const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
      const idle = f[3] + f[4]
      const total = f.slice(0, 8).reduce((a, b) => a + b, 0)
      if (root.lastTotal > 0) {
        const dt = total - root.lastTotal
        const di = idle - root.lastIdle
        root.cpu = dt > 0 ? 100 * (1 - di / dt) : 0
      }
      if (root.lastTotal > 0) root.cpuHistory = root.cpuHistory.concat([root.cpu]).slice(-root.historyLength)
      root.lastTotal = total
      root.lastIdle = idle
    }
  }

  // Memory: used = total minus available
  FileView {
    id: memFile
    path: "/proc/meminfo"
    onLoaded: {
      const t = text()
      const total = Number(t.match(/MemTotal:\s+(\d+)/)[1])
      const avail = Number(t.match(/MemAvailable:\s+(\d+)/)[1])
      root.ram = 100 * (1 - avail / total)
      root.ramTotalGb = total / 1048576
      root.ramUsedGb = (total - avail) / 1048576
      root.ramHistory = root.ramHistory.concat([root.ram]).slice(-root.historyLength)
    }
  }

  // Temperatures, GPU load and disk. Sensors are found by NAME, not number,
  // because hwmon numbers differ from machine to machine.
  Process {
    id: slowProc
    command: ["sh", "-c",
      "for d in /sys/class/hwmon/hwmon*; do n=$(cat $d/name 2>/dev/null); case $n in k10temp|coretemp|zenpower) echo cpu $(cat $d/temp1_input);; amdgpu|nouveau) echo gpu $(cat $d/temp1_input);; esac; done; "
      + "for f in /sys/class/drm/card*/device/gpu_busy_percent; do [ -r $f ] && echo gpuload $(cat $f) && break; done; "
      + "set -- $(df -B1 --output=used,size / | tail -1); echo disk $1 $2"]
    stdout: StdioCollector {
      onStreamFinished: {
        let c = -1, g = -1, gl = -1
        for (const line of text.split("\n")) {
          const p = line.trim().split(" ")
          if (p[0] === "cpu") c = Math.round(Number(p[1]) / 1000)
          if (p[0] === "gpu") g = Math.round(Number(p[1]) / 1000)
          if (p[0] === "gpuload") gl = Number(p[1])
          if (p[0] === "disk") {
            root.diskUsedGb = Number(p[1]) / 1e9
            root.diskTotalGb = Number(p[2]) / 1e9
          }
        }
        root.cpuTemp = c
        root.gpuTemp = g
        root.gpuLoad = gl
      }
    }
  }

  // Refresh every 2 seconds, always (cheap: two small file reads and one tiny script)
  Timer {
    running: true
    interval: 2000
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      statFile.reload()
      memFile.reload()
      slowProc.running = true
    }
  }

  // ---------- bar item ----------
  Text {
    id: label
    color: Colors.text
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 14
    text: "\uf2db " + Math.round(root.cpu) + "%"

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
        spacing: 12

        Text {
          text: "System"
          color: Colors.text
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 16
          font.bold: true
        }

        StatBar {
          label: "CPU"
          valueText: Math.round(root.cpu) + "%"
          fraction: root.cpu / 100
        }
        Sparkline { values: root.cpuHistory; lineColor: Colors.accent }
        StatBar {
          label: "Memory"
          valueText: root.ramUsedGb.toFixed(1) + " / " + root.ramTotalGb.toFixed(1) + " GB"
          fraction: root.ram / 100
        }
        Sparkline { values: root.ramHistory; lineColor: Colors.subtext }
        StatBar {
          visible: root.diskTotalGb > 0
          label: "Disk  /"
          valueText: Math.round(root.diskUsedGb) + " / " + Math.round(root.diskTotalGb) + " GB"
          fraction: root.diskTotalGb > 0 ? root.diskUsedGb / root.diskTotalGb : 0
        }
        StatBar {
          visible: root.gpuLoad >= 0
          label: "GPU"
          valueText: root.gpuLoad + "%"
          fraction: root.gpuLoad / 100
        }
        StatBar {
          visible: root.cpuTemp >= 0
          label: "CPU temperature"
          valueText: root.cpuTemp + "°C"
          fraction: root.cpuTemp / 100
        }
        StatBar {
          visible: root.gpuTemp >= 0
          label: "GPU temperature"
          valueText: root.gpuTemp + "°C"
          fraction: root.gpuTemp / 100
        }
        StatBar {
          visible: root.hasBattery
          label: UPower.displayDevice?.state === UPowerDeviceState.Charging ? "Battery (charging)" : "Battery"
          valueText: Math.round(root.batteryPct) + "%"
          fraction: root.batteryPct / 100
        }
      }
    }
  }
}
