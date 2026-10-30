// Hardware.qml — a slide-out drawer: CPU, RAM, temperatures, battery (laptops only).
// Click the dots to slide it open or shut. It only reads the system while it is open.
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick

Row {
  id: root
  spacing: 10

  property bool open: false

  property real cpu: 0
  property real ram: 0
  property int cpuTemp: -1      // -1 = no sensor found, so that stat stays hidden
  property int gpuTemp: -1
  property real lastTotal: 0
  property real lastIdle: 0

  // ---------- readings ----------

  // CPU usage: compare /proc/stat now against the last reading
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
      root.lastTotal = total
      root.lastIdle = idle
    }
  }

  // RAM used = total minus what is available
  FileView {
    id: memFile
    path: "/proc/meminfo"
    onLoaded: {
      const t = text()
      const total = Number(t.match(/MemTotal:\s+(\d+)/)[1])
      const avail = Number(t.match(/MemAvailable:\s+(\d+)/)[1])
      root.ram = 100 * (1 - avail / total)
    }
  }

  // Temperatures: find the right sensors by NAME, not by number (the numbers differ per machine)
  Process {
    id: tempProc
    command: ["sh", "-c",
      "for d in /sys/class/hwmon/hwmon*; do n=$(cat $d/name 2>/dev/null); case $n in k10temp|coretemp|zenpower) echo cpu $(cat $d/temp1_input);; amdgpu|nouveau) echo gpu $(cat $d/temp1_input);; esac; done"]
    stdout: StdioCollector {
      onStreamFinished: {
        let c = -1, g = -1
        for (const line of text.split("\n")) {
          const p = line.trim().split(" ")
          if (p[0] === "cpu") c = Math.round(Number(p[1]) / 1000)
          if (p[0] === "gpu") g = Math.round(Number(p[1]) / 1000)
        }
        root.cpuTemp = c
        root.gpuTemp = g
      }
    }
  }

  // Refresh every 2 seconds, but only while the drawer is open
  Timer {
    running: root.open
    interval: 2000
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      statFile.reload()
      memFile.reload()
      tempProc.running = true
    }
  }

  // ---------- the drawer (slides open to the LEFT of the dots) ----------
  Row {
    id: drawer
    spacing: 12
    clip: true
    anchors.verticalCenter: parent.verticalCenter

    width: root.open ? implicitWidth : 0
    opacity: root.open ? 1 : 0
    Behavior on width   { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 200 } }

    Stat { icon: "\uf2db";          value: Math.round(root.cpu) + "%" }          // CPU
    Stat { icon: "\udb80\udf5b";    value: Math.round(root.ram) + "%" }          // RAM
    Stat { visible: root.cpuTemp >= 0; icon: "\uf2c9"; value: root.cpuTemp + "°" }          // CPU temp
    Stat { visible: root.gpuTemp >= 0; icon: "\udb86\udd13"; value: root.gpuTemp + "°" }    // GPU temp

    // Battery: only exists on laptops
    Stat {
      visible: UPower.displayDevice.isLaptopBattery
      icon: UPower.displayDevice.state === UPowerDeviceState.Charging ? "\udb80\udc84" : "\udb80\udc79"
      value: Math.round(UPower.displayDevice.percentage * 100) + "%"
    }
  }

  // ---------- the toggle ----------
  Text {
    text: "\uf141"
    color: root.open ? Colors.accent : Colors.subtext
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 16
    anchors.verticalCenter: parent.verticalCenter
    Behavior on color { ColorAnimation { duration: 200 } }

    MouseArea {
      anchors.fill: parent
      onClicked: root.open = !root.open
    }
  }
}
