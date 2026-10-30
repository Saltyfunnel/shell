#!/bin/bash
################################################################################
# my-shell installer — Arch Linux + Hyprland + Quickshell + matugen theming
# Run from the repo folder:   sudo bash install.sh
################################################################################

set -Eeuo pipefail

################################################################################
# LOOK & FEEL (colours, progress bar, spinner)
################################################################################

RST="\e[0m"; BLD="\e[1m"; DIM="\e[2m"
WHT="\e[37m"; BBLK="\e[90m"; BRED="\e[91m"; BGRN="\e[92m"
BYLW="\e[93m"; BBLU="\e[94m"; BCYN="\e[96m"; BWHT="\e[97m"

STEP=0
TOTAL_STEPS=10
LOG_DIR="/tmp/my-shell-install-logs"
mkdir -p "$LOG_DIR"

_cols() { tput cols 2>/dev/null || echo 80; }

repeat() {  # repeat <char> <count>
    local out="" i
    for (( i = 0; i < $2; i++ )); do out+="$1"; done
    printf '%s' "$out"
}

hr() { echo -e "${BBLK}$(repeat '─' "$(_cols)")${RST}"; }

spinner() {
    local pid=$1 msg="$2" i=0
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    tput civis 2>/dev/null || true
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r    ${BCYN}${frames[$i]}${RST}  ${DIM}${msg}${RST}  "
        i=$(( (i + 1) % ${#frames[@]} ))
        sleep 0.07
    done
    tput cnorm 2>/dev/null || true
    printf "\r"
}

print_phase() {
    STEP=$((STEP + 1))
    local pct=$(( STEP * 100 / TOTAL_STEPS )); [[ $pct -gt 100 ]] && pct=100
    local done_blocks=$(( STEP * 20 / TOTAL_STEPS )); [[ $done_blocks -gt 20 ]] && done_blocks=20
    local bar="${BCYN}$(repeat '▪' "$done_blocks")${RST}${BBLK}$(repeat '▫' $(( 20 - done_blocks )))${RST}"
    echo ""
    echo -e "  ${bar}  ${BLD}${BWHT}$1${RST}  ${BBLK}${pct}%${RST}"
    echo ""
}

print_ok()   { echo -e "    ${BGRN}✓${RST}  $1"; }
print_warn() { echo -e "    ${BYLW}!${RST}  $1"; }
print_info() { echo -e "    ${BBLK}↳${RST}  ${DIM}$1${RST}"; }
print_err()  { echo -e "\n    ${BRED}✗  ${BLD}$1${RST}\n" >&2; exit 1; }

# Run a command as your normal user (not root), with your HOME set.
as_user() { sudo -u "$USER_NAME" -H "$@"; }

# Run a command with a spinner. If it fails, show the end of its log and stop.
run_command() {
    local cmd="$1" desc="$2"
    local slug; slug=$(echo "$desc" | tr -c 'a-zA-Z0-9\n' '_' | cut -c1-60)
    local log="$LOG_DIR/${slug}.log"

    print_info "$desc"
    eval "$cmd" > "$log" 2>&1 &
    local pid=$!
    spinner "$pid" "$desc"
    if ! wait "$pid"; then
        echo -e "\n    ${BRED}Last lines of log:${RST}" >&2
        tail -n 15 "$log" | sed 's/^/      /' >&2
        print_err "Failed: $desc  →  $log"
    fi
    print_ok "$desc"
}

# Copy a folder or a file from the repo into ~/.config if it exists.
deploy() {  # deploy <repo path> <destination> <label>
    local src="$1" dest="$2" label="$3"
    if [[ -d "$src" ]]; then
        as_user mkdir -p "$dest"
        run_command "as_user cp -rf '$src/.' '$dest/'" "$label"
    elif [[ -f "$src" ]]; then
        as_user mkdir -p "$(dirname "$dest")"
        run_command "as_user cp -f '$src' '$dest'" "$label"
    else
        print_info "skipped $label (not found in repo)"
    fi
}

cleanup() { tput cnorm 2>/dev/null || true; echo ""; }
trap cleanup EXIT
trap 'echo -e "\n    ${BRED}✗  Error on line $LINENO${RST}" >&2' ERR

################################################################################
# PRE-FLIGHT CHECKS
################################################################################

[[ "$EUID" -eq 0 ]] || { echo "Run as root  →  sudo bash $0" >&2; exit 1; }
[[ -f /etc/arch-release ]] || { echo "This installer is for Arch Linux only." >&2; exit 1; }

USER_NAME="${SUDO_USER:-}"
if [[ -z "$USER_NAME" || "$USER_NAME" == "root" ]]; then
    echo "Run with sudo from your normal user account (not a root login)." >&2
    exit 1
fi
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
[[ -d "$USER_HOME" ]] || { echo "Home directory for $USER_NAME not found." >&2; exit 1; }

CONFIG_DIR="$USER_HOME/.config"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS_SRC="$REPO_ROOT/configs"
SCRIPTS_SRC="$REPO_ROOT/scripts"
WALLPAPERS_REPO="https://github.com/Saltyfunnel/Wallpapers.git"
CARGO_PATH="/usr/local/bin:/usr/bin:/bin:$USER_HOME/.cargo/bin"

clear
echo ""
echo -e "    ${BLD}${BCYN}my-shell${RST}${BLD}${BBLK} · hyprland · quickshell · matugen${RST}"
echo ""
echo -e "    ${BBLK}user${RST}    ${WHT}${USER_NAME}${RST}"
echo -e "    ${BBLK}repo${RST}    ${WHT}${REPO_ROOT}${RST}"
echo -e "    ${BBLK}logs${RST}    ${WHT}${LOG_DIR}${RST}"
echo ""
hr

curl -fsS --max-time 10 -o /dev/null https://archlinux.org || print_err "No network connection"
print_ok "Network reachable"

################################################################################
# 1. PACMAN CONFIG
################################################################################

print_phase "Configuring pacman"

sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf
if grep -q "^#ILoveCandy" /etc/pacman.conf; then
    sed -i 's/^#ILoveCandy/ILoveCandy/' /etc/pacman.conf
elif ! grep -q "^ILoveCandy" /etc/pacman.conf; then
    sed -i '/^\[options\]/a ILoveCandy' /etc/pacman.conf
fi
# multilib is needed for Steam
sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
grep -q '^\[multilib\]' /etc/pacman.conf || print_err "Could not enable [multilib] in /etc/pacman.conf"
print_ok "pacman.conf updated (multilib, Color, ParallelDownloads)"

################################################################################
# 2. SYSTEM UPDATE & GPU DRIVERS
################################################################################

print_phase "System update & graphics drivers"

run_command "pacman -Syu --noconfirm" "Updating the system"

GPU_INFO=$(lspci | grep -Ei "VGA|3D" || true)

if echo "$GPU_INFO" | grep -qi nvidia; then
    print_info "NVIDIA GPU detected"
    run_command "pacman -S --noconfirm --needed nvidia-open-dkms nvidia-utils lib32-nvidia-utils linux-headers" \
        "Installing NVIDIA drivers"
elif echo "$GPU_INFO" | grep -qi amd; then
    print_info "AMD GPU detected"
    run_command "pacman -S --noconfirm --needed mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon" \
        "Installing AMD drivers"
elif echo "$GPU_INFO" | grep -qi intel; then
    print_info "Intel GPU detected"
    run_command "pacman -S --noconfirm --needed mesa lib32-mesa vulkan-intel lib32-vulkan-intel" \
        "Installing Intel drivers"
else
    print_warn "No known GPU found, skipping drivers"
fi

################################################################################
# 3. PACKAGES
################################################################################

print_phase "Installing packages"

CORE=(hyprland hyprpaper xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
      polkit-kde-agent sddm qt6-5compat qt6-declarative qt6-svg qt5-wayland qt6-wayland
      mako)
AUDIO=(pipewire pipewire-pulse pipewire-alsa wireplumber playerctl pavucontrol)
TERMINAL=(kitty fish starship fastfetch btop)
UTILITY=(grim slurp wl-clipboard brightnessctl pacman-contrib
         bluez bluez-utils blueman networkmanager udisks2 udiskie gvfs)
FILES=(thunar thunar-volman thunar-archive-plugin tumbler ffmpegthumbnailer file-roller trash-cli)
MEDIA=(mpv imv ffmpeg yt-dlp cava)
SETTINGS=(dconf gsettings-desktop-schemas)
APPS=(firefox spotify-launcher qbittorrent gnome-disk-utility zed)
GAMING=(steam gamemode lib32-gamemode mangohud lib32-mangohud)
DEV=(git base-devel curl wget nano jq rust)
FONTS=(ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji)
DISK=(ntfs-3g dosfstools unzip p7zip unrar)

ALL_PACKAGES=("${CORE[@]}" "${AUDIO[@]}" "${TERMINAL[@]}" "${UTILITY[@]}" "${FILES[@]}"
              "${MEDIA[@]}" "${SETTINGS[@]}" "${APPS[@]}" "${GAMING[@]}" "${DEV[@]}" "${FONTS[@]}" "${DISK[@]}")

run_command "pacman -S --noconfirm --needed ${ALL_PACKAGES[*]}" \
    "Installing ${#ALL_PACKAGES[@]} packages"

################################################################################
# 4. QUICKSHELL + MATUGEN
################################################################################

print_phase "Quickshell & matugen"

if pacman -Si quickshell >/dev/null 2>&1; then
    run_command "pacman -S --noconfirm --needed quickshell" "Installing Quickshell"
else
    print_warn "quickshell is not in the official repos. After this script finishes run:  yay -S quickshell"
fi

if pacman -Si matugen >/dev/null 2>&1; then
    run_command "pacman -S --noconfirm --needed matugen" "Installing matugen"
else
    print_info "matugen not in the repos, building with cargo (takes a few minutes)"
    run_command "as_user env PATH='$CARGO_PATH' cargo install matugen --locked" "Building matugen"
fi

################################################################################
# 5. FOLDERS
################################################################################

print_phase "Creating folders"

for d in hypr kitty fish mako scripts quickshell matugen/templates gtk-3.0 gtk-4.0 Thunar starship fastfetch; do
    as_user mkdir -p "$CONFIG_DIR/$d"
done
as_user mkdir -p "$USER_HOME/Pictures/Wallpapers" "$USER_HOME/.local/share/icons" "$USER_HOME/.cache"
print_ok "Folders created"

################################################################################
# 6. CONFIG FILES (copied from this repo)
################################################################################

print_phase "Deploying config files"

deploy "$CONFIGS_SRC/hypr"        "$CONFIG_DIR/hypr"        "Hyprland config"
deploy "$CONFIGS_SRC/quickshell"  "$CONFIG_DIR/quickshell"  "Quickshell bar"
deploy "$CONFIGS_SRC/matugen"     "$CONFIG_DIR/matugen"     "matugen config & templates"
deploy "$CONFIGS_SRC/kitty"       "$CONFIG_DIR/kitty"       "Kitty config"
deploy "$CONFIGS_SRC/fish"        "$CONFIG_DIR/fish"        "Fish config"
deploy "$CONFIGS_SRC/mako"        "$CONFIG_DIR/mako"        "Mako config"
deploy "$CONFIGS_SRC/fastfetch"   "$CONFIG_DIR/fastfetch"   "Fastfetch config"
deploy "$CONFIGS_SRC/starship"    "$CONFIG_DIR"             "Starship config"
deploy "$CONFIGS_SRC/gtk-3.0"     "$CONFIG_DIR/gtk-3.0"     "GTK 3 config"
deploy "$CONFIGS_SRC/gtk-4.0"     "$CONFIG_DIR/gtk-4.0"     "GTK 4 config"
deploy "$CONFIGS_SRC/Thunar"      "$CONFIG_DIR/Thunar"      "Thunar config"
deploy "$SCRIPTS_SRC"             "$CONFIG_DIR/scripts"     "User scripts"
as_user find "$CONFIG_DIR/scripts" -type f -exec chmod +x {} + 2>/dev/null || true

# GPU environment file (hyprland.lua loads this at startup, so it must exist)
GPU_ENV_FILE="$CONFIG_DIR/hypr/gpu-env.lua"
if echo "$GPU_INFO" | grep -qi nvidia; then
    cat > "$GPU_ENV_FILE" << 'EOF'
-- GPU environment, auto-generated by install.sh
return {
  LIBVA_DRIVER_NAME         = "nvidia",
  XDG_SESSION_TYPE          = "wayland",
  __GLX_VENDOR_LIBRARY_NAME = "nvidia",
  GBM_BACKEND               = "nvidia-drm",
  WLR_NO_HARDWARE_CURSORS   = "1",
  __GL_GSYNC_ALLOWED        = "1",
  __GL_VRR_ALLOWED          = "1",
  QT_QPA_PLATFORM           = "wayland",
}
EOF
elif echo "$GPU_INFO" | grep -qi amd; then
    cat > "$GPU_ENV_FILE" << 'EOF'
-- GPU environment, auto-generated by install.sh
return {
  LIBVA_DRIVER_NAME = "radeonsi",
  XDG_SESSION_TYPE  = "wayland",
  QT_QPA_PLATFORM   = "wayland",
}
EOF
elif echo "$GPU_INFO" | grep -qi intel; then
    cat > "$GPU_ENV_FILE" << 'EOF'
-- GPU environment, auto-generated by install.sh
return {
  LIBVA_DRIVER_NAME = "iHD",
  XDG_SESSION_TYPE  = "wayland",
  QT_QPA_PLATFORM   = "wayland",
}
EOF
else
    cat > "$GPU_ENV_FILE" << 'EOF'
-- GPU environment, auto-generated by install.sh
return {
  XDG_SESSION_TYPE = "wayland",
  QT_QPA_PLATFORM  = "wayland",
}
EOF
fi
print_ok "GPU environment written  →  hypr/gpu-env.lua"

################################################################################
# 7. WALLPAPERS & DEFAULT SHELL
################################################################################

print_phase "Wallpapers & fish shell"

WALLPAPER_TMP="/tmp/wallpapers-src"
rm -rf "$WALLPAPER_TMP"
run_command "as_user git clone --depth 1 '$WALLPAPERS_REPO' '$WALLPAPER_TMP'" "Cloning wallpapers"
run_command "as_user cp -rf '$WALLPAPER_TMP/.' '$USER_HOME/Pictures/Wallpapers/' && rm -rf '$USER_HOME/Pictures/Wallpapers/.git'" \
    "Copying wallpapers to ~/Pictures/Wallpapers"
rm -rf "$WALLPAPER_TMP"

if chsh -s /usr/bin/fish "$USER_NAME"; then
    print_ok "fish set as your default shell"
else
    print_warn "Could not change shell. Run later:  chsh -s /usr/bin/fish"
fi

################################################################################
# 8. ICONS
################################################################################

print_phase "Colloid icon theme"

COLLOID_SRC="$CONFIG_DIR/colloid-src"
if [[ ! -d "$COLLOID_SRC" ]]; then
    run_command "as_user git clone --depth 1 https://github.com/Saltyfunnel/colloid.git '$COLLOID_SRC'" \
        "Cloning Colloid icon theme"
fi
run_command "cd '$COLLOID_SRC' && as_user ./install.sh -d '$USER_HOME/.local/share/icons' -n Colloid-Dynamic -s default" \
    "Installing Colloid-Dynamic icons"
rm -f "$USER_HOME/.cache/folder_accent"

as_user dbus-run-session -- gsettings set org.gnome.desktop.interface icon-theme 'Colloid-Dynamic-Dark' \
    > "$LOG_DIR/gsettings.log" 2>&1 \
    && print_ok "Icon theme set for GTK apps" \
    || print_warn "Could not set icon theme now (hyprland.lua sets it at login)"

################################################################################
# 9. SERVICES
################################################################################

print_phase "Services"

for svc in sddm bluetooth NetworkManager; do
    if systemctl enable "${svc}.service" > "$LOG_DIR/enable-${svc}.log" 2>&1; then
        print_ok "${svc} enabled"
    else
        print_warn "Could not enable ${svc}  →  $LOG_DIR/enable-${svc}.log"
    fi
done

################################################################################
# 10. WRAP UP
################################################################################

print_phase "Finalizing installation"

# Hand ownership of your files back to you
for p in "$CONFIG_DIR" "$USER_HOME/.cache" "$USER_HOME/Pictures" "$USER_HOME/.local"; do
    [[ -e "$p" ]] && chown -R "$USER_NAME:$USER_NAME" "$p"
done
print_ok "Ownership set"

################################################################################
# DONE
################################################################################

echo ""
hr
echo -e "\n    ${BLD}${BGRN}Install complete.${RST}\n"
echo -e "    ${BWHT}Before you reboot, add two startup lines to your Hyprland config:${RST}"
echo -e "      ${DIM}quickshell${RST}"
echo -e "      ${DIM}~/.config/scripts/setwall.sh --restore${RST}"
echo -e "    ${DIM}(use whatever autostart syntax your config already uses)${RST}"
echo ""
echo -e "    ${DIM}logs: ${LOG_DIR}${RST}"
hr
echo ""

read -r -p "    $(echo -e "${BCYN}reboot now? [Y/n]:${RST} ")" REBOOT_CHOICE
REBOOT_CHOICE=${REBOOT_CHOICE:-Y}
if [[ "$REBOOT_CHOICE" =~ ^[Yy]$ ]]; then
    reboot
fi