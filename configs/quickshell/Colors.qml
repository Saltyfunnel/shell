pragma Singleton
import Quickshell
import QtQuick

// FALLBACK colours. Running setwall.sh replaces this file with wallpaper colours.
Singleton {
  readonly property color surface: "#1e1e2e"
  readonly property color card:    "#313244"
  readonly property color text:    "#cdd6f4"
  readonly property color subtext: "#a6adc8"
  readonly property color accent:  "#89b4fa"
  readonly property color track:   "#45475a"
}
