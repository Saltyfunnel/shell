<div align="center">

# 🐚 shell

**Arch Linux · Hyprland · Quickshell · Matugen**

*A modern, minimal Arch setup featuring automated TTY auto-login and dynamic wallpaper-driven color palettes.*

---

![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white)
![Hyprland](https://img.shields.io/badge/Hyprland-0055AA?style=for-the-badge&logo=hyprland&logoColor=white)
![Wayland](https://img.shields.io/badge/Wayland-CC2A41?style=for-the-badge&logo=wayland&logoColor=white)
![Fish](https://img.shields.io/badge/Fish_Shell-4E9A06?style=for-the-badge&logo=gnu-bash&logoColor=white)

</div>

---

### 🔥 Highlights

* **Dynamic Palette** — **Matugen** automatically generates system-wide colors (Kitty, Mako, GTK) from wallpapers.
* **Smart Installer** — Auto-detects GPU drivers (NVIDIA / AMD / Intel), sets environment vars, and logs everything to `/tmp`.
* **Sleek UI** — Powered by **Quickshell** and **Colloid-Dynamic** icons.

---

### 📦 Software Stack

| Component | Packages |
| :--- | :--- |
| **Desktop** | Hyprland, Quickshell, Hyprpaper, Mako, GTK 3/4 |
| **Terminal** | Kitty, Fish, Starship, Fastfetch, Btop |
| **Media & Audio** | Pipewire, Wireplumber, Playerctl, MPV, IMV, Cava |
| **Utilities** | Thunar, Firefox, Spotify, Zed, Gnome Disks |

---

### ⚡ Quick Start

Run directly on a fresh or existing **Arch Linux** installation:

```bash
git clone https://github.com/Saltyfunnel/shell
cd shell
chmod +x install.sh
sudo ./install.sh
