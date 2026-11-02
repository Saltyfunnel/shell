// PerformancePanel.qml — the dashboard's Performance tab: bars and charts from SystemStats.
import QtQuick

DashPanel {
  Row {
    anchors.fill: parent
    anchors.margins: 20
    spacing: 28

    // left: the two charts
    Column {
      width: (parent.width - parent.spacing) / 2
      spacing: 10

      StatBar {
        label: "CPU"
        valueText: Math.round(SystemStats.cpu) + "%"
        fraction: SystemStats.cpu / 100
      }
      Sparkline { values: SystemStats.cpuHistory; lineColor: Colors.accent; height: 64 }

      Item { width: 1; height: 6 }

      StatBar {
        label: "Memory"
        valueText: SystemStats.ramUsedGb.toFixed(1) + " / " + SystemStats.ramTotalGb.toFixed(1) + " GB"
        fraction: SystemStats.ram / 100
      }
      Sparkline { values: SystemStats.ramHistory; lineColor: Colors.subtext; height: 64 }
    }

    // right: everything else
    Column {
      width: (parent.width - parent.spacing) / 2
      spacing: 16

      StatBar {
        visible: SystemStats.diskTotalGb > 0
        label: "Disk  /"
        valueText: Math.round(SystemStats.diskUsedGb) + " / " + Math.round(SystemStats.diskTotalGb) + " GB"
        fraction: SystemStats.diskTotalGb > 0 ? SystemStats.diskUsedGb / SystemStats.diskTotalGb : 0
      }
      StatBar {
        visible: SystemStats.gpuLoad >= 0
        label: "GPU"
        valueText: SystemStats.gpuLoad + "%"
        fraction: SystemStats.gpuLoad / 100
      }
      StatBar {
        visible: SystemStats.cpuTemp >= 0
        label: "CPU temperature"
        valueText: SystemStats.cpuTemp + "°C"
        fraction: SystemStats.cpuTemp / 100
      }
      StatBar {
        visible: SystemStats.gpuTemp >= 0
        label: "GPU temperature"
        valueText: SystemStats.gpuTemp + "°C"
        fraction: SystemStats.gpuTemp / 100
      }
      StatBar {
        visible: SystemStats.hasBattery
        label: SystemStats.charging ? "Battery (charging)" : "Battery"
        valueText: Math.round(SystemStats.batteryPct) + "%"
        fraction: SystemStats.batteryPct / 100
      }
    }
  }
}
