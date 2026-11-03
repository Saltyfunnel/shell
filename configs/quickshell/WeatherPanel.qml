// WeatherPanel.qml — the dashboard's Weather tab: current conditions, details, 3-day forecast.
import QtQuick

DashPanel {
  Text {
    visible: !Weather.loaded
    anchors.centerIn: parent
    text: Weather.failed ? "Weather unavailable (check your network)" : "Loading weather..."
    color: Colors.subtext
    font.family: Theme.font
    font.pixelSize: 15
  }

  Row {
    visible: Weather.loaded
    anchors.fill: parent
    anchors.margins: 28
    spacing: 40

    // ----- now -----
    Column {
      width: (parent.width - parent.spacing) / 2
      anchors.verticalCenter: parent.verticalCenter
      spacing: 18

      Row {
        spacing: 20
        Text {
          text: Weather.icon
          color: Colors.accent
          font.family: Theme.font
          font.pixelSize: 72
          anchors.verticalCenter: parent.verticalCenter
        }
        Column {
          anchors.verticalCenter: parent.verticalCenter
          spacing: 2
          Text {
            text: Weather.tempC + "°C"
            color: Colors.text
            font.family: Theme.font
            font.pixelSize: 44
            font.bold: true
          }
          Text {
            text: Weather.desc + "  ·  feels like " + Weather.feelsC + "°"
            color: Colors.subtext
            font.family: Theme.font
            font.pixelSize: 13
          }
          Text {
            text: Config.weatherTown
            color: Colors.subtext
            font.family: Theme.font
            font.pixelSize: 12
            opacity: 0.7
          }
        }
      }

      Column {
        width: parent.width
        spacing: 8
        InfoRow { label: "Humidity";      value: Weather.humidity + "%" }
        InfoRow { label: "Wind";          value: Weather.windMph + " mph " + Weather.windDir }
        InfoRow { label: "Pressure";      value: Weather.pressure + " mb" }
        InfoRow { label: "UV index";      value: Weather.uv }
        InfoRow { label: "Precipitation"; value: Weather.precipMm + " mm" }
      }
    }

    // ----- next days -----
    Column {
      width: (parent.width - parent.spacing) / 2
      anchors.verticalCenter: parent.verticalCenter
      spacing: 12

      Repeater {
        model: Weather.forecast

        Rectangle {
          required property var modelData
          width: parent.width
          height: 70
          radius: Theme.radiusSm
          color: Colors.surface

          Row {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            spacing: 16

            Text {
              width: 100
              text: modelData.label
              color: Colors.text
              font.family: Theme.font
              font.pixelSize: 14
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              text: Weather.iconFor(modelData.code, false)
              color: Colors.accent
              font.family: Theme.font
              font.pixelSize: 28
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              text: modelData.maxC + "°  /  " + modelData.minC + "°"
              color: Colors.subtext
              font.family: Theme.font
              font.pixelSize: 14
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }
      }
    }
  }
}
