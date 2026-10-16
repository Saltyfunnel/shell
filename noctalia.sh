#!/usr/bin/env bash
# install-noctalia-clean.sh
#
# Fresh minimal Arch install -> Hyprland + Noctalia desktop shell (with Spicetify).
# File manager: Thunar (GUI) + yazi (TUI).

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run this as your normal user, not root." >&2
    exit 1
fi

BUILD_DIR="$HOME/.cache/noctalia-install"
mkdir -p "$BUILD_DIR"

CONFIRM="--noconfirm"
[[ "${REVIEW:-0}" == "1" ]] && CONFIRM=""

echo "==> Full system update"
sudo pacman -Syu --noconfirm

echo "==> Base build tools"
sudo pacman -S --needed --noconfirm base-devel git go pciutils

if ! command -v yay &>/dev/null; then
    echo "==> Bootstrapping yay from source"
    rm -rf "$BUILD_DIR/yay"
    git clone --depth=1 https://aur.archlinux.org/yay.git "$BUILD_DIR/yay"
    (cd "$BUILD_DIR/yay" && makepkg -si --noconfirm)
fi

install_pkg() {
    yay -S --needed $CONFIRM "$@"
}

# --- 1. GPU detection ---
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

# --- 2. Hyprland + Portals + Kitty ---
echo "==> Hyprland, portals, terminal (Kitty), graphics"
install_pkg hyprland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
    "${GPU_PKGS[@]}" \
    kitty \
    ttf-jetbrains-mono-nerd

# --- 3. Core Shell Tools & Utilities ---
echo "==> Core apps and system utilities"
install_pkg fish eza zoxide direnv \
    fastfetch \
    btop \
    yazi ffmpeg 7zip poppler fd fzf imagemagick \
    thunar thunar-archive-plugin thunar-volman gvfs tumbler file-roller \
    starship \
    adw-gtk-theme papirus-icon-theme \
    qt6ct nwg-look \
    gnome-keyring polkit-gnome \
    networkmanager \
    bluez bluez-utils \
    pipewire pipewire-pulse pipewire-audio pipewire-alsa pipewire-jack wireplumber pavucontrol \
    wl-clipboard cliphist \
    noto-fonts noto-fonts-cjk noto-fonts-emoji \
    curl trash-cli jq lazygit bat ripgrep hyprpicker xdg-user-dirs

echo "==> Login manager"
install_pkg sddm xorg-server

# --- 4. Quickshell & Noctalia Shell ---
echo "==> Quickshell & Noctalia runtime deps"
install_pkg brightnessctl ddcutil lm_sensors power-profiles-daemon \
    qt6-base qt6-declarative qt6-imageformats qt6-shadertools \
    cmake ninja \
    ttf-material-symbols-variable ttf-rubik-vf ttf-cascadia-code-nerd \
    swappy \
    noctalia-git

# --- 5. Pull Noctalia dotfiles & configure components ---
DOTS_DIR="$HOME/.local/share/noctalia-dots"
if [[ -d "$DOTS_DIR/.git" ]]; then
    git -C "$DOTS_DIR" pull --ff-only || true
else
    git clone https://github.com/noctalia-dev/noctalia.git "$DOTS_DIR" || true
fi

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
mkdir -p "$XDG_CONFIG_HOME"

copy_component() {
    local src="$1" dest="$2"
    if [[ -e "$dest" ]]; then
        mkdir -p "$HOME/.config-backup"
        cp -a "$dest" "$HOME/.config-backup/"
    fi
    mkdir -p "$(dirname "$dest")"
    cp -rT "$DOTS_DIR/$src" "$dest" 2>/dev/null || true
}

echo "==> Laying down configuration components"
copy_component hypr      "$XDG_CONFIG_HOME/hypr"
copy_component fish      "$XDG_CONFIG_HOME/fish"
copy_component fastfetch "$XDG_CONFIG_HOME/fastfetch"
copy_component btop      "$XDG_CONFIG_HOME/btop"
if [[ -f "$DOTS_DIR/starship.toml" ]]; then
    cp "$DOTS_DIR/starship.toml" "$XDG_CONFIG_HOME/starship.toml"
fi

# If the copy above produced no Hyprland config, write a minimal one.
if [[ ! -f "$XDG_CONFIG_HOME/hypr/hyprland.conf" ]]; then
    echo "==> No hyprland.conf found, writing a minimal one"
    mkdir -p "$XDG_CONFIG_HOME/hypr"
    cat > "$XDG_CONFIG_HOME/hypr/hyprland.conf" <<'EOF'
monitor = , preferred, auto, 1

$terminal = kitty
$fileExplorer = thunar
$tuiFiles = kitty -e yazi

env = QT_QPA_PLATFORMTHEME,qt6ct
env = XCURSOR_SIZE,24

# NOTE: check the Noctalia docs for the launch command your version expects.
exec-once = qs -c noctalia-shell
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1

bind = SUPER, Return, exec, $terminal
bind = SUPER, E, exec, $fileExplorer
bind = SUPER SHIFT, E, exec, $tuiFiles
bind = SUPER, Q, killactive
bind = SUPER SHIFT, M, exit
EOF
else
    # Existing config: point $fileExplorer at Thunar.
    grep -rl '^\$fileExplorer' "$XDG_CONFIG_HOME/hypr" 2>/dev/null \
        | xargs -r sed -i 's|^\(\$fileExplorer *= *\).*|\1thunar|' || true
fi

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

# --- 6. Wallpapers ---
WALLPAPER_REPO="${WALLPAPER_REPO:-https://github.com/Saltyfunnel/Wallpapers.git}"
WALLPAPER_SRC="$HOME/.local/share/wallpapers"
WALLPAPER_DEST="$HOME/Pictures/Wallpapers"

echo "==> Wallpapers"
if [[ ! -d "$WALLPAPER_SRC/.git" ]]; then
    git clone --depth=1 "$WALLPAPER_REPO" "$WALLPAPER_SRC" || true
fi

if [[ -d "$WALLPAPER_SRC" ]]; then
    mkdir -p "$WALLPAPER_DEST"
    (
        cd "$WALLPAPER_SRC"
        find . -path ./.git -prune -o -type f \
            \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print0 \
            | xargs -0 -r cp --update=none --parents -t "$WALLPAPER_DEST"
    )
fi

# --- 7. Browser & Media ---
echo "==> Zen Browser"
install_pkg zen-browser-bin
xdg-settings set default-web-browser zen.desktop 2>/dev/null || true

echo "==> Spotify + Spicetify"
if install_pkg spotify spicetify-cli; then
    sudo chmod a+wr /opt/spotify
    sudo chmod -R a+wr /opt/spotify/Apps

    mkdir -p "$XDG_CONFIG_HOME/spotify"
    [[ -e "$XDG_CONFIG_HOME/spotify/prefs" ]] || touch "$XDG_CONFIG_HOME/spotify/prefs"

    spicetify backup apply \
        || echo "    WARN: spicetify apply failed. Launch Spotify once, then run 'spicetify backup apply'."
else
    echo "    WARN: Spotify or Spicetify installation failed."
fi

# --- 8. GTK / icon theme defaults + file manager ---
echo "==> GTK / icon theme defaults"
# These can fail from a TTY with no D-Bus session; if so, run them once after first login.
gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' \
    || echo "    WARN: gsettings failed. After first login run the gsettings lines in this script."
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' || true
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || true
xdg-mime default thunar.desktop inode/directory || true

# --- 9. Services ---
echo "==> Enabling system services"
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth
sudo systemctl enable --now power-profiles-daemon
sudo systemctl enable sddm

# --- 10. Shell Default ---
if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "/usr/bin/fish" ]]; then
    echo "==> Setting fish as default shell"
    chsh -s /usr/bin/fish
fi

xdg-user-dirs-update

echo
echo "==> Installation complete! Reboot, select Hyprland in SDDM, and let Noctalia take over."
echo
echo "After first login:"
echo "  - Noctalia Settings -> Templates: enable GTK and Qt (KColorScheme if you use KDE apps)"
echo "  - qt6ct: set the icon theme to Papirus-Dark"
echo "  - Fully restart Thunar so it picks up the theme"
