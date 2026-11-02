// DashPanel.qml — a rounded panel to sit inside a popup. Put anything inside it.
import QtQuick

Rectangle {
  default property alias content: holder.data

  radius: Theme.radiusMd
  color: Colors.card

  Item { id: holder; anchors.fill: parent }
}
