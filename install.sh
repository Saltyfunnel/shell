#!/usr/bin/env bash
# install-noctalia-clean.sh
#
# Fresh minimal Arch install -> Hyprland + Noctalia v5 desktop shell (with Spicetify).
# Noctalia v5 is a native Wayland shell (no Quickshell/QML), so no Qt shell deps here.
# File manager: Thunar.

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run this as your normal user, not root." >&2
    exit 1
fi

BUILD_DIR="$HOME/.cache/noctalia-install"
mkdir -p "$BUILD_DIR"

CONFIRM="--noconfirm"
[[ "${REVIEW:-0}" == "1" ]] && CONFIRM=""

echo "==> pacman.conf tweaks (Color, ParallelDownloads, ILoveCandy, multilib for Steam)"
sudo sed -i 's/^#Color/Color/; s/^#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf
grep -q '^ILoveCandy' /etc/pacman.conf || sudo sed -i '/^\[options\]/a ILoveCandy' /etc/pacman.conf
sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf

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
    amd)    GPU_PKGS+=(vulkan-radeon lib32-mesa lib32-vulkan-radeon) ;;
    nvidia) GPU_PKGS+=(nvidia-open-dkms nvidia-utils lib32-nvidia-utils libva-nvidia-driver linux-headers) ;;
    intel)  GPU_PKGS+=(vulkan-intel lib32-mesa lib32-vulkan-intel intel-media-driver) ;;
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
    ffmpeg 7zip fd fzf imagemagick \
    thunar thunar-archive-plugin thunar-volman gvfs tumbler ffmpegthumbnailer file-roller \
    udiskie udisks2 \
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

echo "==> Apps"
install_pkg mpv imv qbittorrent libreoffice-fresh \
    steam gnome-disk-utility ntfs-3g dosfstools \
    localsend-bin

echo "==> Login manager"
install_pkg sddm xorg-server

# --- 4. Noctalia v5 ---
# noctalia-git pulls in its own runtime deps and lists the optional ones.
echo "==> Noctalia"
install_pkg noctalia-git \
    brightnessctl ddcutil lm_sensors power-profiles-daemon \
    swappy

# --- 5. Config ---
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
mkdir -p "$XDG_CONFIG_HOME"

# Hyprland 0.55+ loads ~/.config/hypr/hyprland.lua first and only falls back to
# the legacy hyprland.conf. Write a minimal Lua config if there is neither.
HYPR_DIR="$XDG_CONFIG_HOME/hypr"
if [[ ! -f "$HYPR_DIR/hyprland.lua" && ! -f "$HYPR_DIR/hyprland.conf" ]]; then
    echo "==> No Hyprland config found, writing a minimal hyprland.lua"
    mkdir -p "$HYPR_DIR"
    cat > "$HYPR_DIR/hyprland.lua" <<'EOF'
-- Minimal Hyprland (0.55+) Lua config. Extend it from the wiki: https://wiki.hypr.land

local terminal     = "kitty"
local fileExplorer = "thunar"

hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("XCURSOR_SIZE", "24")

hl.on("hyprland.start", function()
    hl.exec_cmd("noctalia")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd("udiskie")
end)

hl.bind("SUPER + Return", hl.dsp.exec_cmd(terminal))
hl.bind("SUPER + E", hl.dsp.exec_cmd(fileExplorer))
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + SHIFT + M", hl.dsp.exit())
EOF
else
    echo "    NOTE: existing Hyprland config found, not touching it. To autostart Noctalia add:"
    echo '      hl.on("hyprland.start", function() hl.exec_cmd("noctalia") end)'
fi

# Minimal fish config (only if you don't already have one)
mkdir -p "$XDG_CONFIG_HOME/fish"
if [[ ! -f "$XDG_CONFIG_HOME/fish/config.fish" ]]; then
    cat > "$XDG_CONFIG_HOME/fish/config.fish" <<'EOF'
if status is-interactive
    starship init fish | source
    zoxide init fish | source
    direnv hook fish | source
    alias ls 'eza --icons'
end
EOF
fi

# Thunar custom action: right-click a folder -> Open Kitty Here
mkdir -p "$XDG_CONFIG_HOME/Thunar"
if [[ ! -f "$XDG_CONFIG_HOME/Thunar/uca.xml" ]]; then
    cat > "$XDG_CONFIG_HOME/Thunar/uca.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<actions>
<action>
    <icon>kitty</icon>
    <name>Open Kitty Here</name>
    <unique-id>kitty-open-here</unique-id>
    <command>kitty --directory %f</command>
    <description>Open Kitty terminal in this directory</description>
    <patterns>*</patterns>
    <directories/>
</action>
</actions>
EOF
fi

mkdir -p "$XDG_CONFIG_HOME/fish/functions"

# Silence the fish welcome message (an empty fish_greeting function overrides
# the default, even if the copied config sets the variable).
cat > "$XDG_CONFIG_HOME/fish/functions/fish_greeting.fish" <<'EOF'
function fish_greeting
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
gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3' \
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
echo "==> Installation complete! Reboot, select Hyprland in SDDM, and Noctalia starts with the session."
echo
echo "After first login:"
echo "  - Noctalia Settings -> Color Scheme -> Templates: toggle on GTK and Qt"
echo "  - qt6ct: Color Scheme tab -> pick 'noctalia' -> Apply; Icon Theme tab -> Papirus-Dark"
echo "  - Fully restart Thunar so it picks up the theme"
