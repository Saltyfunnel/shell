#!/bin/bash
echo "gtk hook fired" >> /tmp/noctalia-gtk-hook-debug.log
SURFACE_FILE="/home/gerard/.config/noctalia/gtk-mode.txt"
[[ -f "$SURFACE_FILE" ]] || { echo "no surface file" >> /tmp/noctalia-gtk-hook-debug.log; exit 1; }
HEX=$(cat "$SURFACE_FILE" | tr -d '[:space:]')
[[ -z "$HEX" ]] && { echo "empty hex" >> /tmp/noctalia-gtk-hook-debug.log; exit 1; }

R=$((16#${HEX:0:2}))
G=$((16#${HEX:2:2}))
B=$((16#${HEX:4:2}))
LUMA=$(( (R*299 + G*587 + B*114) / 1000 ))

if [[ $LUMA -lt 128 ]]; then
    THEME="Colloid-Dark"
    SCHEME="prefer-dark"
else
    THEME="Colloid-Light"
    SCHEME="prefer-light"
fi

echo "surface=$HEX luma=$LUMA -> $THEME" >> /tmp/noctalia-gtk-hook-debug.log

gsettings set org.gnome.desktop.interface gtk-theme "$THEME"
gsettings set org.gnome.desktop.interface color-scheme "$SCHEME"

# force running Thunar instances to pick it up
thunar -q 2>/dev/null
