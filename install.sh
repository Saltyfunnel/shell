#!/bin/bash
set -euo pipefail

# --- PRE-FLIGHT ---
[[ "$EUID" -eq 0 ]] || { echo "Run as root"; exit 1; }
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$USER_HOME/.config"
WALL_DIR="$USER_HOME/Pictures/Wallpapers"
ICON_DIR="$USER_HOME/.local/share/icons"

# SUDO TRAP
echo "$USER_NAME ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/hypr-temp
chmod 0440 /etc/sudoers.d/hypr-temp
trap 'rm -f /etc/sudoers.d/hypr-temp' EXIT

# DNS PREFLIGHT
if ! getent hosts aur.archlinux.org &>/dev/null; then
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
    echo "  → DNS fallback applied"
fi

# --- 1. HARDWARE & DRIVERS ---
echo "  [1/8] System update & driver detection"
pacman -Syu --noconfirm
GPU_INFO=$(lspci | grep -Ei "VGA|3D" || true)
mkdir -p "$CONFIG_DIR/hypr"
GPU_ENV_FILE="$CONFIG_DIR/hypr/gpu-env.conf"

if echo "$GPU_INFO" | grep -qi nvidia; then
    echo "  → NVIDIA detected"
    pacman -S --noconfirm --needed nvidia-open-dkms nvidia-utils lib32-nvidia-utils linux-headers
    cat > "$GPU_ENV_FILE" << 'EOF'
env = LIBVA_DRIVER_NAME,nvidia
env = XDG_SESSION_TYPE,wayland
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = GBM_BACKEND,nvidia-drm
env = WLR_NO_HARDWARE_CURSORS,1
env = QT_QPA_PLATFORM,wayland
cursor { no_hardware_cursors = true }
EOF
elif echo "$GPU_INFO" | grep -qi amd; then
    echo "  → AMD detected"
    pacman -S --noconfirm --needed xf86-video-amdgpu mesa vulkan-radeon lib32-vulkan-radeon
    cat > "$GPU_ENV_FILE" << 'EOF'
env = LIBVA_DRIVER_NAME,radeonsi
env = XDG_SESSION_TYPE,wayland
env = QT_QPA_PLATFORM,wayland
EOF
elif echo "$GPU_INFO" | grep -qi intel; then
    echo "  → Intel detected"
    pacman -S --noconfirm --needed mesa vulkan-intel lib32-vulkan-intel
    cat > "$GPU_ENV_FILE" << 'EOF'
env = LIBVA_DRIVER_NAME,iHD
env = XDG_SESSION_TYPE,wayland
env = QT_QPA_PLATFORM,wayland
EOF
else
    echo "  → Generic GPU"
    echo "env = XDG_SESSION_TYPE,wayland" > "$GPU_ENV_FILE"
fi

# --- 2. PACKAGE INSTALLATION ---
echo "  [2/8] Installing packages"
CORE=(hyprland waybar swww sddm xdg-desktop-portal-hyprland)
TERM=(kitty starship fastfetch)
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
echo "  [3/8] AUR packages"
if ! command -v yay &>/dev/null; then
    rm -rf /tmp/yay
    sudo -u "$USER_NAME" git clone https://aur.archlinux.org/yay.git /tmp/yay
    (cd /tmp/yay && sudo -u "$USER_NAME" makepkg -si --noconfirm)
    cd "$REPO_ROOT"  # reset working directory after yay subshell
    echo "  → yay installed"
else
    echo "  → yay already present"
fi

sudo -u "$USER_NAME" yay -S --noconfirm noctalia-shell
echo "  → noctalia-shell installed"

# --- 4. COLLOID ICON THEME ---
echo "  [4/8] Colloid icon theme"
COLLOID_SRC="$CONFIG_DIR/colloid-src"

# Pre-create with correct ownership so git clone doesn't hit permission issues
mkdir -p "$COLLOID_SRC"
chown "$USER_NAME:$USER_NAME" "$COLLOID_SRC"
mkdir -p "$ICON_DIR"
chown "$USER_NAME:$USER_NAME" "$ICON_DIR"

if [ ! -d "$COLLOID_SRC/.git" ]; then
    sudo -u "$USER_NAME" git clone --depth 1 \
        https://github.com/Saltyfunnel/colloid.git "$COLLOID_SRC"
fi

sudo -u "$USER_NAME" HOME="$USER_HOME" bash "$COLLOID_SRC/install.sh" \
    -d "$ICON_DIR" \
    -n Colloid-Dynamic \
    -s default
echo "  → Colloid-Dynamic icons installed"

# --- 5. GTK DARK THEME ---
echo "  [5/8] GTK theme"
mkdir -p "$CONFIG_DIR/gtk-3.0" "$CONFIG_DIR/gtk-4.0"

cat > "$CONFIG_DIR/gtk-3.0/settings.ini" << EOF
[Settings]
gtk-icon-theme-name=Colloid-Dynamic-Dark
gtk-theme-name=Adwaita-dark
gtk-application-prefer-dark-theme=1
EOF

cat > "$CONFIG_DIR/gtk-4.0/settings.ini" << EOF
[Settings]
gtk-icon-theme-name=Colloid-Dynamic-Dark
gtk-theme-name=Adwaita-dark
gtk-application-prefer-dark-theme=1
EOF
echo "  → GTK3 & GTK4 dark theme set"

# --- 6. QS SYMLINK ---
echo "  [6/8] Quickshell symlink"
if ! command -v qs &>/dev/null; then
    QS_BIN=$(pacman -Ql noctalia-shell 2>/dev/null | grep -E '/usr/bin/qs$' | awk '{print $2}' || true)
    if [[ -n "$QS_BIN" ]]; then
        ln -sf "$QS_BIN" /usr/bin/qs
        echo "  → qs symlinked"
    else
        echo "  → qs not found in package, skipping symlink"
    fi
else
    echo "  → qs already in PATH"
fi

# --- 7. DEPLOYMENT (CONFIGS & WALLPAPERS) ---
echo "  [7/8] Deploying configs & wallpapers"
if [[ -d "$REPO_ROOT/configs" ]]; then
    cp -rf "$REPO_ROOT/configs/"* "$CONFIG_DIR/"
    echo "  → configs deployed"
fi

if [[ -d "$REPO_ROOT/Pictures/Wallpapers" ]]; then
    mkdir -p "$WALL_DIR"
    cp -rf "$REPO_ROOT/Pictures/Wallpapers/"* "$WALL_DIR/"
    echo "  → wallpapers deployed"
fi

# --- 8. SERVICES & SHELL ---
echo "  [8/8] Services & shell"
systemctl enable NetworkManager.service sddm.service bluetooth.service
mkdir -p /etc/sddm.conf.d
printf "[General]\nDisplayServer=wayland\n" > /etc/sddm.conf.d/10-wayland.conf

chsh -s /bin/bash "$USER_NAME"
echo "  → default shell set to bash"

# --- OWNERSHIP FIX ---
chown -R "$USER_NAME:$USER_NAME" "$USER_HOME"

echo ""
echo "  DONE. Reboot and select Hyprland at SDDM."
