#!/usr/bin/env bash
# install-caelestia.sh
#
# Fresh minimal Arch install -> Hyprland + Caelestia shell, fully set up.
#
# quickshell-git, caelestia-cli and caelestia-shell only exist in the AUR,
# so this bootstraps `yay` first (built once, manually, since yay itself
# is AUR-only) and then uses it for every package, official and AUR alike.
#
# Assumes: Arch already installed and booted, network up, you're a normal
# user with sudo, systemd (the Arch default). Run as yourself, not root.
#
# Options (environment variables):
#   REVIEW=1   don't pass --noconfirm to yay, so you can read PKGBUILDs
#   GPU=amd|nvidia|intel|none   override GPU auto-detection
#   WALLPAPER_REPO=<git url>    wallpaper repo to pull into ~/Pictures/Wallpapers

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run this as your normal user, not root." >&2
    exit 1
fi

BUILD_DIR="$HOME/.cache/caelestia-install"
mkdir -p "$BUILD_DIR"

CONFIRM="--noconfirm"
[[ "${REVIEW:-0}" == "1" ]] && CONFIRM=""

echo "==> Full system update"
sudo pacman -Syu --noconfirm

echo "==> Base build tools"
sudo pacman -S --needed --noconfirm base-devel git go pciutils

# --- bootstrap yay (only AUR package built by hand) ------------------------

if ! command -v yay &>/dev/null; then
    echo "==> Bootstrapping yay (built from source, not yay-bin, to avoid"
    echo "    libalpm.so version mismatches against a rolling-release pacman)"
    rm -rf "$BUILD_DIR/yay"
    git clone --depth=1 https://aur.archlinux.org/yay.git "$BUILD_DIR/yay"
    (cd "$BUILD_DIR/yay" && makepkg -si --noconfirm)
fi

install_pkg() {
    yay -S --needed $CONFIRM "$@"
}

# --- 1. GPU detection --------------------------------------------------------

detect_gpu() {
    local info
    info="$(lspci -nn | grep -Ei 'vga|3d|display' || true)"
    if grep -qi 'nvidia' <<<"$info"; then echo nvidia
    elif grep -Eqi 'amd|ati|radeon' <<<"$info"; then echo amd
    elif grep -qi 'intel' <<<"$info"; then echo intel
    else echo none
    fi
}

GPU="${GPU:-$(detect_gpu)}"
echo "==> GPU: $GPU"

GPU_PKGS=(mesa)
case "$GPU" in
    amd)    GPU_PKGS+=(vulkan-radeon) ;;
    nvidia) GPU_PKGS+=(nvidia-open-dkms nvidia-utils libva-nvidia-driver linux-headers) ;;
    intel)  GPU_PKGS+=(vulkan-intel intel-media-driver) ;;
    none)   echo "    No GPU matched, installing mesa only." ;;
esac

# libva-mesa-driver was merged into mesa on Arch; only add it if it still exists
if [[ "$GPU" == "amd" ]] && pacman -Si libva-mesa-driver &>/dev/null; then
    GPU_PKGS+=(libva-mesa-driver)
fi

# --- 2. Hyprland + portals + graphics ---------------------------------------

echo "==> Hyprland, portals, graphics"
install_pkg hyprland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
    "${GPU_PKGS[@]}" \
    ttf-jetbrains-mono-nerd

# --- 3. Default caelestia-dots components -----------------------------------

echo "==> Shell/terminal/file manager/tools"
install_pkg fish eza zoxide direnv \
    foot \
    fastfetch \
    btop \
    micro \
    yazi ffmpeg 7zip poppler fd fzf imagemagick \
    thunar thunar-archive-plugin thunar-volman gvfs tumbler file-roller \
    starship \
    adw-gtk-theme papirus-icon-theme \
    gnome-keyring polkit-gnome \
    networkmanager \
    bluez bluez-utils \
    pipewire pipewire-pulse pipewire-audio pipewire-alsa pipewire-jack wireplumber pavucontrol \
    wl-clipboard cliphist \
    noto-fonts noto-fonts-cjk noto-fonts-emoji \
    curl trash-cli jq lazygit bat ripgrep ydotool hyprpicker xdg-user-dirs

echo "==> Login manager (the dots don't ship one)"
# xorg-server is for SDDM's default X11 greeter; Hyprland itself still runs on Wayland.
install_pkg sddm xorg-server

# --- 4. GTK/QT theming: order matters (framework before darkly-bin) ---------

echo "==> GTK/QT theming"
install_pkg papirus-folders frameworkintegration darkly-bin qtengine

# --- 5. Quickshell + shell runtime deps -------------------------------------

echo "==> Quickshell + shell runtime deps"
install_pkg brightnessctl ddcutil lm_sensors aubio libqalculate power-profiles-daemon \
    libcava \
    qt6-base qt6-declarative qt6-imageformats qt6-shadertools \
    cmake ninja \
    qt6-m3shapes-git \
    ttf-material-symbols-variable ttf-rubik-vf ttf-cascadia-code-nerd \
    swappy \
    quickshell-git

# --- 6. caelestia-cli runtime deps, then the CLI and shell themselves -------

echo "==> caelestia-cli runtime deps"
install_pkg libnotify grim dart-sass slurp gpu-screen-recorder glib2 fuzzel

echo "==> caelestia-cli, caelestia-shell"
install_pkg caelestia-cli caelestia-shell

# --- 7. Pull the dots, lay down the default component configs ---------------

DOTS_DIR="$HOME/.local/share/caelestia-dots"
if [[ -d "$DOTS_DIR/.git" ]]; then
    git -C "$DOTS_DIR" pull --ff-only \
        || echo "    WARN: couldn't fast-forward $DOTS_DIR (local changes?), using it as-is."
else
    git clone https://github.com/caelestia-dots/caelestia.git "$DOTS_DIR"
fi

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
mkdir -p "$XDG_CONFIG_HOME"

BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
BACKED_UP=0

backup_if_exists() {
    local target="$1"
    if [[ -e "$target" ]]; then
        mkdir -p "$BACKUP_DIR"
        cp -a "$target" "$BACKUP_DIR/"
        BACKED_UP=1
    fi
}

copy_component() {
    local src="$1" dest="$2"
    backup_if_exists "$dest"
    mkdir -p "$(dirname "$dest")"
    cp -rT "$DOTS_DIR/$src" "$dest"
}

echo "==> Laying down default component configs"
copy_component hypr      "$XDG_CONFIG_HOME/hypr"
copy_component fish      "$XDG_CONFIG_HOME/fish"
copy_component foot      "$XDG_CONFIG_HOME/foot"
copy_component fastfetch "$XDG_CONFIG_HOME/fastfetch"
copy_component btop      "$XDG_CONFIG_HOME/btop"
copy_component micro     "$XDG_CONFIG_HOME/micro"
backup_if_exists "$XDG_CONFIG_HOME/starship.toml"
cp "$DOTS_DIR/starship.toml" "$XDG_CONFIG_HOME/starship.toml"

(( BACKED_UP )) && echo "    Existing configs backed up to $BACKUP_DIR"

# The dots launch Thunar as the file explorer, so that is left as the default.
# yazi gets its own keybind (Super+Shift+E) so both stay one keypress away.
# Hyprland 0.55+ prefers hyprland.lua and only falls back to the legacy
# hyprland.conf, so handle whichever layout the dots ship.
# NOTE: if Super+Shift+E is already bound in the dots, both binds will fire;
# change the key below if that happens.
HYPR_DIR="$XDG_CONFIG_HOME/hypr"
if [[ -f "$HYPR_DIR/hyprland.lua" ]]; then
    if ! grep -q 'foot -e yazi' "$HYPR_DIR/hyprland.lua"; then
        {
            echo
            echo '-- yazi (TUI file manager) alongside Thunar'
            echo 'hl.bind("SUPER + SHIFT + E", hl.dsp.exec_cmd("foot -e yazi"))'
        } >> "$HYPR_DIR/hyprland.lua"
    fi
    echo "    NOTE: Lua config detected. If the file explorer isn't Thunar, edit it in $HYPR_DIR."
elif [[ -f "$HYPR_DIR/hyprland.conf" ]]; then
    grep -rl '^\$fileExplorer' "$HYPR_DIR" 2>/dev/null \
        | xargs -r sed -i 's|^\(\$fileExplorer *= *\).*|\1thunar|' || true
    if ! grep -q 'foot -e yazi' "$HYPR_DIR/hyprland.conf"; then
        {
            echo
            echo "# yazi (TUI file manager) alongside Thunar"
            echo "bind = SUPER SHIFT, E, exec, foot -e yazi"
        } >> "$HYPR_DIR/hyprland.conf"
    fi
else
    echo "    WARN: no hyprland.lua or hyprland.conf found in $HYPR_DIR; skipped file manager setup."
fi

xdg-mime default thunar.desktop inode/directory 2>/dev/null || true

chmod u+x "$XDG_CONFIG_HOME/hypr/scripts/wsaction.fish" 2>/dev/null || true
mkdir -p "$XDG_CONFIG_HOME/caelestia"
touch "$XDG_CONFIG_HOME/caelestia/user-config.fish"

# --- Yazi: Material You theme driven by the Caelestia scheme ----------------
# caelestia-cli renders anything in ~/.config/caelestia/templates/ into
# ~/.local/state/caelestia/theme/ every time the scheme/wallpaper changes.
# We drop a yazi theme template there and symlink the output into yazi's config.

mkdir -p "$XDG_CONFIG_HOME/caelestia/templates" "$XDG_CONFIG_HOME/yazi"
cat > "$XDG_CONFIG_HOME/caelestia/templates/yazi-theme.toml" <<'EOF'
[mgr]
cwd           = { fg = "#{{ primary.hex }}" }
hovered       = { fg = "#{{ onPrimary.hex }}", bg = "#{{ primary.hex }}" }
border_style  = { fg = "#{{ outline.hex }}" }

[tabs]
active   = { fg = "#{{ onPrimary.hex }}", bg = "#{{ primary.hex }}", bold = true }
inactive = { fg = "#{{ onSurface.hex }}", bg = "#{{ surface.hex }}" }

[mode]
normal_main = { fg = "#{{ onPrimary.hex }}", bg = "#{{ primary.hex }}", bold = true }
normal_alt  = { fg = "#{{ primary.hex }}", bg = "#{{ surface.hex }}" }
select_main = { fg = "#{{ background.hex }}", bg = "#{{ tertiary.hex }}", bold = true }
select_alt  = { fg = "#{{ tertiary.hex }}", bg = "#{{ surface.hex }}" }
unset_main  = { fg = "#{{ background.hex }}", bg = "#{{ error.hex }}", bold = true }
unset_alt   = { fg = "#{{ error.hex }}", bg = "#{{ surface.hex }}" }

[status]
overall = { bg = "#{{ background.hex }}" }

[filetype]
rules = [
    { url = "*/", fg = "#{{ primary.hex }}" },
]
EOF

backup_if_exists "$XDG_CONFIG_HOME/yazi/theme.toml"
ln -sfn "$HOME/.local/state/caelestia/theme/yazi-theme.toml" "$XDG_CONFIG_HOME/yazi/theme.toml"

# `y` wrapper: quitting yazi cd's your shell into the directory you ended in
mkdir -p "$XDG_CONFIG_HOME/fish/functions"
cat > "$XDG_CONFIG_HOME/fish/functions/y.fish" <<'EOF'
function y
    set tmp (mktemp -t "yazi-cwd.XXXXXX")
    command yazi $argv --cwd-file="$tmp"
    if read -z cwd < "$tmp"; and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
        builtin cd -- "$cwd"
    end
    rm -f -- "$tmp"
end
EOF

# The vscode/discord/todoist/uwsm optional components from the dots are
# intentionally skipped here. Add them later straight from $DOTS_DIR.

# --- 7a. Wallpapers ----------------------------------------------------------
# Pulls your wallpaper repo and copies the images into ~/Pictures/Wallpapers,
# which is where the Caelestia wallpaper picker looks. Subfolders are kept,
# existing files are never overwritten, and a failed clone only warns.

WALLPAPER_REPO="${WALLPAPER_REPO:-https://github.com/Saltyfunnel/Wallpapers.git}"
WALLPAPER_SRC="$HOME/.local/share/wallpapers"
WALLPAPER_DEST="$HOME/Pictures/Wallpapers"

echo "==> Wallpapers"
if [[ -d "$WALLPAPER_SRC/.git" ]]; then
    git -C "$WALLPAPER_SRC" pull --ff-only \
        || echo "    WARN: couldn't update $WALLPAPER_SRC, using it as-is."
else
    git clone --depth=1 "$WALLPAPER_REPO" "$WALLPAPER_SRC" \
        || echo "    WARN: couldn't clone $WALLPAPER_REPO (wrong URL? set WALLPAPER_REPO=...)"
fi

if [[ -d "$WALLPAPER_SRC" ]]; then
    mkdir -p "$WALLPAPER_DEST"
    (
        cd "$WALLPAPER_SRC"
        find . -path ./.git -prune -o -type f \
            \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
               -o -iname '*.webp' -o -iname '*.avif' \) -print0 \
            | xargs -0 -r cp --update=none --parents -t "$WALLPAPER_DEST"
    )
    echo "    Copied wallpapers to $WALLPAPER_DEST"
fi

# --- 7b. Zen browser + Spotify with Spicetify -------------------------------

echo "==> Zen browser"
install_pkg zen-browser-bin

# Native messaging host the dots use to theme Zen live from the scheme.
ZEN_LIB="$HOME/.local/lib/caelestia"
if [[ -f "$DOTS_DIR/zen/native_app/manifest.json" ]]; then
    mkdir -p "$ZEN_LIB" "$HOME/.mozilla/native-messaging-hosts"
    sed 's|{{ \$lib }}|'"$ZEN_LIB"'|' "$DOTS_DIR/zen/native_app/manifest.json" \
        > "$HOME/.mozilla/native-messaging-hosts/caelestiafox.json"
    install -m755 "$DOTS_DIR/zen/native_app/app.fish" "$ZEN_LIB/caelestiafox"
fi
xdg-settings set default-web-browser zen.desktop 2>/dev/null || true

echo "==> Spotify + Spicetify"
if install_pkg spotify spicetify-cli; then
    # Spicetify patches Spotify in place, so it needs write access.
    sudo chmod a+wr /opt/spotify
    sudo chmod -R a+wr /opt/spotify/Apps

    copy_component spicetify "$XDG_CONFIG_HOME/spicetify"

    # Spicetify wants a prefs file, which Spotify only creates on first run.
    mkdir -p "$XDG_CONFIG_HOME/spotify"
    [[ -e "$XDG_CONFIG_HOME/spotify/prefs" ]] || touch "$XDG_CONFIG_HOME/spotify/prefs"

    spicetify config current_theme caelestia color_scheme caelestia
    if [[ -d "$XDG_CONFIG_HOME/spicetify/CustomApps/marketplace" ]]; then
        spicetify config custom_apps marketplace
    fi
    spicetify backup apply \
        || echo "    WARN: spicetify apply failed. After launching Spotify once, run: spicetify backup apply"
else
    echo "    WARN: Spotify/Spicetify install failed. If it was a PGP error, check the"
    echo "    'spotify' AUR page comments for the current signing key, import it, and re-run."
fi

# --- 8. Services -------------------------------------------------------------

echo "==> Enabling services"
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth
sudo systemctl enable --now power-profiles-daemon
sudo systemctl enable sddm

# ydotool ships a user unit; this can fail without a live user session, so
# don't let it abort the install. If it does, run it after first login:
#   systemctl --user enable --now ydotool
systemctl --user enable --now ydotool 2>/dev/null \
    || echo "    NOTE: run 'systemctl --user enable --now ydotool' after first login."

# --- 9. Default shell --------------------------------------------------------

if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "/usr/bin/fish" ]]; then
    echo "==> Setting fish as default shell"
    chsh -s /usr/bin/fish
fi

xdg-user-dirs-update

echo
echo "==> Done. Reboot, pick the Hyprland session in SDDM and log in; the Caelestia shell starts with it."
echo "    Optional: ./install-sddm-theme.sh gives SDDM a login theme that follows the Caelestia scheme."
echo "    First run:"
echo "      >wallpaper in the launcher (or: caelestia wallpaper -f <path>)"
echo "      caelestia scheme set -n dynamic"
echo
echo "    Zen (launch it once first so your profile exists), then theme it:"
echo "      mkdir -p ~/.zen/<profile>/chrome"
echo "      ln -sf $DOTS_DIR/zen/userChrome.css ~/.zen/<profile>/chrome/userChrome.css"
echo
echo "    Files: Thunar is the default file manager; Super+Shift+E opens yazi in foot."
echo "    Run 'y' in fish for yazi with cd-on-exit. Its theme is generated at"
echo "    ~/.local/state/caelestia/theme/yazi-theme.toml after the first scheme/wallpaper set."
echo "    Spotify: launch once; if the theme is missing, run: spicetify backup apply"
