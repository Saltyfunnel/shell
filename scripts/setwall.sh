#!/usr/bin/env bash
# setwall.sh — set the wallpaper AND recolour the whole desktop from it.
#   setwall.sh /path/to/image.jpg   use this image
#   setwall.sh --random             random image from ~/Pictures/Wallpapers
#   setwall.sh --restore            re-apply the last one (run this at login)
set -euo pipefail
export PATH="$PATH:$HOME/.cargo/bin"

WALL_DIR="$HOME/Pictures/Wallpapers"
STATE="$HOME/.cache/current_wallpaper"
mkdir -p "$(dirname "$STATE")"

random_wall() {
    find "$WALL_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | shuf -n 1
}

case "${1:-}" in
    --restore) sleep 1; wall=$(cat "$STATE" 2>/dev/null || true); [[ -n "$wall" ]] || wall=$(random_wall) ;;
    --random|"") wall=$(random_wall) ;;
    *) wall="$1" ;;
esac

[[ -f "$wall" ]] || { echo "No wallpaper found: '$wall'" >&2; exit 1; }
echo "$wall" > "$STATE"

# 1. Show the wallpaper (hyprpaper)
hyprctl hyprpaper wallpaper ",$wall" >/dev/null 2>&1 \
    || echo "warning: hyprpaper call failed (is hyprpaper running?)" >&2

# 2. Recolour everything from it (Quickshell reloads on its own;
#    kitty and mako are reloaded by matugen hooks; reopen Thunar to see its new colours)
matugen image "$wall" -m dark --prefer saturation

# 3. Recolour the folder icons to match
"$HOME/.config/scripts/recolor-icons.sh" "$(cat "$HOME/.cache/accent_color")"
