#!/usr/bin/env bash
# install-noctalia-clean.sh
#
# Fresh minimal Arch install -> Hyprland + Noctalia desktop shell (with Spicetify).
#
# noctalia-git only exists in the AUR, so this bootstraps `yay` first
# and then uses it for every package, official and AUR alike.
#
# Assumes: Arch already installed and booted, network up, normal user with sudo.

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

# --- bootstrap yay ---

if ! command -v yay &>/devnull; then
    echo "==> Bootstrapping yay from source"
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

if [[ "$GPU" == "amd" ]] && pacman -Si libva-mesa-driver &>/dev/null; then
    GPU_PKGS+=(libva-mesa-driver)
fi

# --- 2. Hyprland + Portals + Kitty -------------------------------------------

echo "==> Hyprland, portals, terminal (Kitty), graphics"
install_pkg hyprland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
    "${GPU_PKGS[@]}" \
    kitty \
    ttf-jetbrains-mono-nerd

# --- 3. Core Shell Tools & Utilities ----------------------------------------

echo "==> Core apps and system utilities"
install_pkg fish eza zoxide direnv \
    fastfetch \
    btop \
    yazi ffmpeg 7zip poppler fd fzf imagemagick \
    starship \
    adw-gtk-theme papirus-icon-theme \
    gnome-keyring polkit-gnome \
    networkmanager \
    bluez bluez-utils \
    pipewire pipewire-pulse pipewire-audio pipewire-alsa pipewire-jack wireplumber pavucontrol \
    wl-clipboard cliphist \
    noto-fonts noto-fonts-cjk noto-fonts-emoji \
    curl trash-cli jq lazygit bat ripgrep hyprpicker xdg-user-dirs

echo "==> Login manager"
install_pkg sddm xorg-server

# --- 4. Quickshell & Noctalia Shell ------------------------------------------

echo "==> Quickshell & Noctalia runtime deps"
install_pkg brightnessctl ddcutil lm_sensors power-profiles-daemon \
    qt6-base qt6-declarative qt6-imageformats qt6-shadertools \
    cmake ninja \
    ttf-material-symbols-variable ttf-rubik-vf ttf-cascadia-code-nerd \
    swappy \
    noctalia-git

# --- 5. Pull Noctalia dotfiles & configure components -----------------------

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

# Point Hyprland's file explorer variable directly to Kitty running Yazi
grep -rl '^\$fileExplorer' "$XDG_CONFIG_HOME/hypr" 2>/dev/null \
    | xargs -r sed -i 's|^\(\$fileExplorer *= *\).*|\1kitty -e yazi|' || true

# Yazi integration wrapper for Fish
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

# --- 6. Wallpapers ----------------------------------------------------------

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
            \(-iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp'\) -print0 \
            | xargs -0 -r cp --update=none --parents -t "$WALLPAPER_DEST"
    )
    echo "    Wallpapers linked to $WALLPAPER_DEST"
fi

# --- 7. Browser & Media (Spotify + Spicetify) -------------------------------

echo "==> Zen Browser"
install_pkg zen-browser-bin
xdg-settings set default-web-browser zen.desktop 2>/dev/null || true

echo "==> Spotify + Spicetify"
if install_pkg spotify spicetify-cli; then
    # Give Spicetify write access to Spotify binary files
    sudo chmod a+wr /opt/spotify
    sudo chmod -R a+wr /opt/spotify/Apps

    # Ensure spotify config directory and prefs file exist for spicetify initialization
    mkdir -p "$XDG_CONFIG_HOME/spotify"
    [[ -e "$XDG_CONFIG_HOME/spotify/prefs" ]] \vert{}\vert{} touch "$XDG_CONFIG_HOME/spotify/prefs"

    # Initial backup and patch so Spicetify is ready for Noctalia
    spicetify backup apply \
        || echo "    WARN: spicetify apply failed. Launch Spotify once, then run 'spicetify backup apply'."
else
    echo "    WARN: Spotify or Spicetify installation failed."
fi

# --- 8. Services -------------------------------------------------------------

echo "==> Enabling system services"
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth
sudo systemctl enable --now power-profiles-daemon
sudo systemctl enable sddm

# --- 9. Shell Default --------------------------------------------------------

if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "/usr/bin/fish" ]]; then
    echo "==> Setting fish as default shell"
    chsh -s /usr/bin/fish
fi

xdg-user-dirs-update

echo
echo "==> Installation complete! Reboot, select Hyprland in SDDM, and let Noctalia take over."
