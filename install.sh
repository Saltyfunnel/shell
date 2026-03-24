#!/bin/bash
set -euo pipefail

# --- PRE-FLIGHT ---
[[ "$EUID" -eq 0 ]] || { echo "Run as root"; exit 1; }
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$USER_HOME/.config"
WALL_DIR="$USER_HOME/Pictures/Wallpapers"

# SUDO TRAP
echo "$USER_NAME ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/hypr-temp
chmod 0440 /etc/sudoers.d/hypr-temp
trap 'rm -f /etc/sudoers.d/hypr-temp' EXIT

# --- 1. HARDWARE & DRIVERS ---
pacman -Syu --noconfirm
GPU_INFO=$(lspci | grep -Ei "VGA|3D" || true)
mkdir -p "$CONFIG_DIR/hypr"
GPU_ENV_FILE="$CONFIG_DIR/hypr/gpu-env.conf"

if echo "$GPU_INFO" | grep -qi nvidia; then
    pacman -S --noconfirm --needed nvidia-open-dkms nvidia-utils lib32-nvidia-utils linux-headers
    cat > "$GPU_ENV_FILE" << 'EOF'
env = LIBVA_DRIVER_NAME,nvidia
env = XDG_SESSION_TYPE,wayland
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = GBM_BACKEND,nvidia-drm
env = WLR_NO_HARDWARE_CURSORS,1
cursor { no_hardware_cursors = true }
EOF
elif echo "$GPU_INFO" | grep -qi amd; then
    pacman -S --noconfirm --needed xf86-video-amdgpu mesa vulkan-radeon lib32-vulkan-radeon
    echo "env = LIBVA_DRIVER_NAME,radeonsi" > "$GPU_ENV_FILE"
else
    echo "env = XDG_SESSION_TYPE,wayland" > "$GPU_ENV_FILE"
fi

# --- 2. PACKAGE INSTALLATION ---
CORE=(hyprland waybar swww sddm xdg-desktop-portal-hyprland)
TERM=(kitty starship fastfetch fish)
UTIL=(grim slurp wl-clipboard polkit-kde-agent bluez bluez-utils blueman udiskie udisks2 gvfs networkmanager)
FILE=(thunar thunar-volman thunar-archive-plugin tumbler ffmpegthumbnailer file-roller)
APPS=(firefox mpv imv pavucontrol btop gnome-disk-utility zed)
DEV=(git base-devel wget curl nano jq)
FONT=(ttf-jetbrains-mono-nerd ttf-hack-nerd ttf-iosevka-nerd ttf-cascadia-code-nerd)
MEDIA=(poppler imagemagick ffmpeg chafa)
COMP=(unzip p7zip tar gzip xz bzip2 unrar trash-cli)
PY=(python-pyqt5 python-pyqt6 python-pillow python-opencv)
QT=(qt5-wayland qt6-wayland)

pacman -S --noconfirm --needed \
    "${CORE[@]}" "${TERM[@]}" "${UTIL[@]}" "${FILE[@]}" \
    "${APPS[@]}" "${DEV[@]}" "${FONT[@]}" "${MEDIA[@]}" \
    "${COMP[@]}" "${PY[@]}" "${QT[@]}"

# --- 3. AUR ---
if ! command -v yay &>/dev/null; then
    sudo -u "$USER_NAME" git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay && sudo -u "$USER_NAME" makepkg -si --noconfirm
fi
sudo -u "$USER_NAME" yay -S --noconfirm noctalia-shell

# --- 4. COLLOID ICON THEME ---
COLLOID_SRC="$CONFIG_DIR/colloid-src"
if [ ! -d "$COLLOID_SRC" ]; then
    sudo -u "$USER_NAME" git clone --depth 1 https://github.com/Saltyfunnel/colloid.git "$COLLOID_SRC"
fi
sudo -u "$USER_NAME" mkdir -p "$USER_HOME/.local/share/icons"
(cd "$COLLOID_SRC" && sudo -u "$USER_NAME" ./install.sh \
    -d "$USER_HOME/.local/share/icons" \
    -n Colloid-Dynamic \
    -s default)

# --- 5. GTK DARK THEME ---
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR/gtk-3.0" "$CONFIG_DIR/gtk-4.0"

sudo -u "$USER_NAME" bash -c "cat > '$CONFIG_DIR/gtk-3.0/settings.ini' << 'EOF'
[Settings]
gtk-icon-theme-name=Colloid-Dynamic-Dark
gtk-theme-name=Adwaita-dark
gtk-application-prefer-dark-theme=1
EOF"

sudo -u "$USER_NAME" bash -c "cat > '$CONFIG_DIR/gtk-4.0/settings.ini' << 'EOF'
[Settings]
gtk-icon-theme-name=Colloid-Dynamic-Dark
gtk-theme-name=Adwaita-dark
gtk-application-prefer-dark-theme=1
EOF"

# --- 6. FISH & QS ---
sudo -u "$USER_NAME" fish -c "set -U fish_user_paths /usr/bin /usr/local/bin \$fish_user_paths"
if ! command -v qs &>/dev/null; then
    QS_BIN=$(pacman -Ql noctalia-qs | grep -E '/usr/bin/qs$' | awk '{print $2}' || true)
    [[ -n "$QS_BIN" ]] && ln -sf "$QS_BIN" /usr/bin/qs
fi

# --- 7. DEPLOYMENT (CONFIGS, KITTY, WALLPAPERS) ---
mkdir -p "$CONFIG_DIR"
if [[ -d "$REPO_ROOT/configs" ]]; then
    cp -rf "$REPO_ROOT/configs/"* "$CONFIG_DIR/"
fi

if [[ -d "$REPO_ROOT/Pictures/Wallpapers" ]]; then
    sudo -u "$USER_NAME" mkdir -p "$WALL_DIR"
    cp -rf "$REPO_ROOT/Pictures/Wallpapers/"* "$WALL_DIR/"
fi

# --- 8. SERVICES & SHELL ---
systemctl enable --force NetworkManager.service sddm.service bluetooth.service
mkdir -p /etc/sddm.conf.d
echo -e "[General]\nDisplayServer=wayland" > /etc/sddm.conf.d/10-wayland.conf

if ! grep -q "/usr/bin/fish" /etc/shells; then echo "/usr/bin/fish" >> /etc/shells; fi
chsh -s /usr/bin/fish "$USER_NAME"

# --- OWNERSHIP FIX ---
chown -R "$USER_NAME:$USER_NAME" "$USER_HOME"

echo "DONE."
