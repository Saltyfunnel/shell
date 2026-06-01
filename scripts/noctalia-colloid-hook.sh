#!/bin/bash
echo "hook fired, reading file" >> /tmp/noctalia-hook-debug.log

COLOR_FILE="/home/gerard/.config/noctalia/colloid-color.txt"
[[ -f "$COLOR_FILE" ]] || { echo "no color file" >> /tmp/noctalia-hook-debug.log; exit 1; }

HEX=$(cat "$COLOR_FILE" | tr -d '[:space:]')
echo "HEX: $HEX" >> /tmp/noctalia-hook-debug.log

[[ -z "$HEX" ]] && { echo "empty hex" >> /tmp/noctalia-hook-debug.log; exit 1; }

/home/gerard/.config/scripts/recolor_folders.sh "$HEX"
echo "recolor called" >> /tmp/noctalia-hook-debug.log
