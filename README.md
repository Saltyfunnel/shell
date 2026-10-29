# my-shell

My own Hyprland shell, built from scratch with Quickshell (QML) on Arch.
A clean floating bar whose modules open into small, informative cards.
Colours come from the wallpaper (matugen), so everything matches.

## Install

```
git clone <this repo> && cd my-shell
sudo bash install.sh
```

`configs/hypr/hyprland.lua` already starts Quickshell and restores your last wallpaper at login.
Window border colours follow the wallpaper too (matugen writes `~/.config/hypr/colors.lua`).

## What's here

```
install.sh                 installs packages, copies configs, themes from a wallpaper
scripts/setwall.sh         set wallpaper + recolour everything   (--random, --restore, or a path)
scripts/recolor-icons.sh   recolours the Colloid folder icons to the wallpaper accent (called by setwall.sh)
configs/
  hypr/hyprland.lua        Hyprland config (colours from matugen, starts Quickshell)
  waybar/                  optional: old Waybar config as a safety-net bar
  quickshell/              THE SHELL (all the learning happens here)
    shell.qml              the bar layout + "only one card open" rule
    Colors.qml             fallback colours (matugen overwrites it)
    Workspaces.qml  WindowTitle.qml  Clock.qml
    Volume.qml             template for any module that has a card
  matugen/                 config.toml + one template per app being themed
  kitty/  fish/  mako/     terminal, shell, notifications
```

## Working on the bar

- Run `quickshell` in a terminal. Errors print there with line numbers.
- Save a `.qml` file and the bar updates instantly (hot reload).
- Colours are `Colors.surface`, `.card`, `.text`, `.subtext`, `.accent`, `.track`.
  Never type a hex colour into a module, always use `Colors.*`.

## Adding a module

1. Copy `Volume.qml` to `Battery.qml` (or whatever), change `popupName` and the contents.
2. Add one line to the right-hand `Row` in `shell.qml`:
   `Battery { openPopup: root.openPopup; onToggle: name => root.toggle(name) }`
3. A module with no card (like Clock) is still a finished module. Cards are optional.

## Roadmap (finish each step before starting the next)

- [ ] v1: workspaces, window title, clock + date
- [ ] v2: volume card (done as the template), battery, CPU/RAM drawer
- [ ] v3: media (MPRIS) card, weather
- [ ] later: calendar card on the clock, network, Bluetooth, updates, screenshot/record
- [ ] much later: launcher, notifications, lock screen

## Theming more apps

Add a template to `configs/matugen/templates/`, then add a `[templates.name]` block
to `configs/matugen/config.toml`. Colour names are Material roles:
`primary`, `surface`, `surface_container`, `on_surface`, `outline_variant`, ...

## Known rough edges

- Thunar/GTK apps pick up new colours when reopened (`thunar -q` fully quits it first).
- Folder icons: only the large scalable ones are coloured; the small sidebar icons stay neutral grey.
  After reinstalling the icon theme, delete `~/.cache/folder_accent` (the installer does this for you).
- Wallpapers with several equally strong colours need `--prefer saturation`, already set in the scripts.
- `setwall.sh` talks to hyprpaper with `hyprctl hyprpaper wallpaper`. If your hyprpaper version
  uses different IPC syntax, that is the one line to change.
- `Super+W` now picks a random wallpaper with `setwall.sh`; the old `wall.py` picker still uses pywal, so it is parked (commented out in hyprland.lua).
- `hyprctl reload` runs after each theme change so borders update; it may flicker briefly.
- Workspace clicks use the Hyprland 0.55+ Lua dispatch syntax (see comment in Workspaces.qml).
