#!/bin/bash
export DISPLAY=:0
export WAYLAND_DISPLAY=wayland-1
ICON_DIR="$HOME/.local/share/icons/Colloid-Dynamic-Dark"
PREV_FILE="$HOME/.cache/noctalia/prev_icon_color"
LOG="/tmp/recolor-debug.log"

echo "--- recolor called with: $1 ---" >> "$LOG"

NEW_COLOR="#${1//\#/}"
[[ -z "$1" ]] && echo "No colour passed" >> "$LOG" && exit 1

PREV_COLOR=$(cat "$PREV_FILE" 2>/dev/null)
echo "PREV: $PREV_COLOR  NEW: $NEW_COLOR" >> "$LOG"

mkdir -p "$(dirname "$PREV_FILE")"

if [ -n "$PREV_COLOR" ] && [ "$PREV_COLOR" != "$NEW_COLOR" ]; then
    MATCHES=$(grep -rl "$PREV_COLOR" "$ICON_DIR" --include="*.svg" | wc -l)
    echo "fast path: $MATCHES files matched" >> "$LOG"
    grep -rl "$PREV_COLOR" "$ICON_DIR" --include="*.svg" | \
        xargs sed -i "s/$PREV_COLOR/$NEW_COLOR/gI"
else
    echo "slow path (same colour or first run)" >> "$LOG"
    find "$ICON_DIR" -name "*.svg" -exec \
        sed -i "/#ffffff\|#333333/!s/#[a-fA-F0-9]\{6\}/$NEW_COLOR/gI" {} +
fi

echo "$NEW_COLOR" > "$PREV_FILE"
echo "saved new prev: $NEW_COLOR" >> "$LOG"

gtk-update-icon-cache -f -t "$ICON_DIR"
rm -rf ~/.cache/thumbnails/*
rm -rf ~/.cache/icon-cache.kcache 2>/dev/null
find ~/.cache -name "*.cache" -path "*/icons/*" -delete 2>/dev/null

DBUS_SESSION=$(cat /run/user/$(id -u)/dbus-session 2>/dev/null || echo "")
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"

killall -9 nautilus 2>/dev/null || true
gsettings set org.gnome.desktop.interface icon-theme 'Adwaita'
sleep 0.5
gsettings set org.gnome.desktop.interface icon-theme 'Colloid-Dynamic-Dark'
echo "done" >> /tmp/recolor-debug.log
