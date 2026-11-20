#!/usr/bin/env bash
# Recolour the Colloid icons to the wallpaper accent.   usage: recolor-icons.sh '#rrggbb'
#   1. folder icons      (places/*.svg: current colour -> new accent)
#   2. file-type icons   (mimetypes/*.svg: the .qml / .txt / .pdf ... icons, tinted to the accent)
set -euo pipefail

ICON_ROOT="$HOME/.local/share/icons"
ICON_DIR="$ICON_ROOT/Colloid-Dynamic-Dark"
# The Dark theme symlinks its mimetypes/scalable to the Light one, so the real files live there.
MIME_DIR="$ICON_ROOT/Colloid-Dynamic-Light/mimetypes/scalable"
MIME_ORIG="$HOME/.cache/colloid-mime-orig"     # pristine copies, so tinting never drifts
STATE="$HOME/.cache/folder_accent"
MIME_STATE="$HOME/.cache/mime_accent"
new="${1:?usage: recolor-icons.sh '#rrggbb'}"
changed=0

# ---------------------------------------------------------------------------
# 1. Folders
# ---------------------------------------------------------------------------
if [[ -d "$ICON_DIR/places" ]]; then
    # Read the colour the folders have RIGHT NOW from folder.svg (skipping the neutral greys/whites).
    # Trusting only the state file breaks when the theme gets reinstalled: the icons go back to the
    # default blue while the state file still names the old accent, so nothing is ever replaced.
    current=$(grep -oiE '#[0-9a-f]{6}' "$ICON_DIR/places/scalable/folder.svg" 2>/dev/null \
              | grep -viE '^#(000000|333333|363636|dedede|ffffff)$' | head -1 || true)
    old="${current:-$(cat "$STATE" 2>/dev/null || echo "#60c0f0")}"

    if [[ "${new,,}" != "${old,,}" ]]; then
        # -type f skips symlinks, so sed can't turn them into copies
        find "$ICON_DIR/places" -type f -name '*.svg' -exec sed -i "s/${old}/${new}/Ig" {} +
        changed=1
    fi
    echo "$new" > "$STATE"
fi

# ---------------------------------------------------------------------------
# 2. File-type icons
#    Every colourful fill gets the accent's hue and saturation but keeps its own lightness, so the
#    light/dark shading survives. Whites, greys and near-black are left alone.
# ---------------------------------------------------------------------------
TINT_AWK='
function h2d(s) { s = tolower(s); return (index(D, substr(s,1,1)) - 1) * 16 + index(D, substr(s,2,1)) - 1 }
function hue2rgb(p, q, t) {
  if (t < 0) t += 1
  if (t > 1) t -= 1
  if (t < 1/6) return p + (q - p) * 6 * t
  if (t < 1/2) return q
  if (t < 2/3) return p + (q - p) * (2/3 - t) * 6
  return p
}
# sets the globals H, S, L (all 0..1) for a colour given as 0..1 r, g, b
function rgb2hsl(r, g, b,   mx, mn, d) {
  mx = (r > g) ? ((r > b) ? r : b) : ((g > b) ? g : b)
  mn = (r < g) ? ((r < b) ? r : b) : ((g < b) ? g : b)
  L = (mx + mn) / 2
  if (mx == mn) { H = 0; S = 0; return }
  d = mx - mn
  S = (L > 0.5) ? d / (2 - mx - mn) : d / (mx + mn)
  if (mx == r)      H = (g - b) / d + ((g < b) ? 6 : 0)
  else if (mx == g) H = (b - r) / d + 2
  else              H = (r - g) / d + 4
  H /= 6
}
function hsl2hex(h, s, l,   q, p) {
  q = (l < 0.5) ? l * (1 + s) : l + s - l * s
  p = 2 * l - q
  return sprintf("#%02x%02x%02x", int(hue2rgb(p, q, h + 1/3) * 255 + 0.5), int(hue2rgb(p, q, h) * 255 + 0.5), int(hue2rgb(p, q, h - 1/3) * 255 + 0.5))
}
BEGIN {
  D = "0123456789abcdef"
  rgb2hsl(h2d(substr(acc,1,2))/255, h2d(substr(acc,3,2))/255, h2d(substr(acc,5,2))/255)
  AH = H; AS = S
}
{
  line = $0; out = ""
  while (match(line, /#[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]/)) {
    rep = substr(line, RSTART, 7)
    nextc = substr(line, RSTART + 7, 1)
    if (nextc !~ /[0-9A-Za-z_-]/) {
      rgb2hsl(h2d(substr(rep,2,2))/255, h2d(substr(rep,4,2))/255, h2d(substr(rep,6,2))/255)
      if (S >= 0.2 && L >= 0.08 && L <= 0.97) rep = hsl2hex(AH, AS, L)
    }
    out = out substr(line, 1, RSTART - 1) rep
    line = substr(line, RSTART + 7)
  }
  print out line
}'

if [[ -d "$MIME_DIR" ]]; then
    acc="${new#\#}"
    acc="${acc,,}"

    # nothing to do if these icons are already tinted with this accent
    if [[ ! -d "$MIME_ORIG" || "$(cat "$MIME_STATE" 2>/dev/null || true)" != "$acc" ]]; then
        # first run: keep pristine copies of the real (non-symlink) icons
        if [[ ! -d "$MIME_ORIG" ]]; then
            mkdir -p "$MIME_ORIG"
            for f in "$MIME_DIR"/*.svg; do
                [[ -L "$f" ]] || cp "$f" "$MIME_ORIG/"
            done
        fi

        tmp=$(mktemp)
        for f in "$MIME_ORIG"/*.svg; do
            dest="$MIME_DIR/$(basename "$f")"
            [[ -L "$dest" ]] && continue
            awk -v acc="$acc" "$TINT_AWK" "$f" > "$tmp" && cat "$tmp" > "$dest"
        done
        rm -f "$tmp"

        echo "$acc" > "$MIME_STATE"
        changed=1
    fi
fi

# ---------------------------------------------------------------------------
# 3. Refresh the icon caches, only if something changed
# ---------------------------------------------------------------------------
if [[ $changed -eq 1 ]]; then
    for theme in Colloid-Dynamic-Dark Colloid-Dynamic-Light; do
        gtk-update-icon-cache -f -t "$ICON_ROOT/$theme" >/dev/null 2>&1 || true
    done
fi
