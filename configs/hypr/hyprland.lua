-- hyprland.lua 2026
-- saltyfunnel/hypr · noctalia edition

--------------------------------------------------------------------------------
-- gpu environment
--------------------------------------------------------------------------------

local gpu_env = dofile(os.getenv("HOME") .. "/.config/hypr/gpu-env.lua")
for k, v in pairs(gpu_env) do
    hl.env(k, v)
end

--------------------------------------------------------------------------------
-- monitor
--------------------------------------------------------------------------------

hl.monitor({
  output   = "",
  mode     = "2560x1440@165",
  position = "auto",
  scale    = "1",
})

--------------------------------------------------------------------------------
-- autostart
--------------------------------------------------------------------------------

hl.on("hyprland.start", function()
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
  hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
  hl.exec_cmd("qs -c noctalia-shell")
  hl.exec_cmd("udiskie")
end)

--------------------------------------------------------------------------------
-- input
--------------------------------------------------------------------------------

hl.config({
  input = {
    kb_layout    = "gb",
    follow_mouse = 1,
    sensitivity  = 0,
    touchpad = {
      natural_scroll = false,
    },
  }
})

--------------------------------------------------------------------------------
-- noctalia colors
--------------------------------------------------------------------------------

local noc_colors = os.getenv("HOME") .. "/.config/hypr/noctalia/noctalia-colors.conf"
if io.open(noc_colors, "r") then
  hl.source(noc_colors)
end

local color2 = "rgba(87d1eaee)"
local color4 = "rgba(e1b8f5ee)"
local color8 = "rgba(3f484caa)"

--------------------------------------------------------------------------------
-- look & feel
--------------------------------------------------------------------------------

hl.config({
  general = {
    gaps_in          = 5,
    gaps_out         = 10,
    border_size      = 3,
    resize_on_border = true,
    allow_tearing    = false,
    layout           = "dwindle",
    col = {
      active_border   = { colors = { color4, color2 }, angle = 45 },
      inactive_border = color8,
    },
  },

  decoration = {
    rounding       = 20,
    rounding_power = 2,
    active_opacity   = 1.0,
    inactive_opacity = 1.0,
    shadow = {
      enabled      = true,
      range        = 4,
      render_power = 3,
      color        = "rgba(1a1a1aee)",
    },
    blur = {
      enabled   = true,
      size      = 3,
      passes    = 2,
      vibrancy  = 0.1696,
    },
  },

  misc = {
    force_default_wallpaper  = 0,
    disable_hyprland_logo    = true,
    disable_splash_rendering = true,
    vrr                      = 0,
  },

  cursor = {
    no_hardware_cursors = false,
  },

  animations = {
    enabled = true,
  },
})

--------------------------------------------------------------------------------
-- animations
--------------------------------------------------------------------------------

hl.curve("wind",   { type = "bezier", points = { { 0.05, 0.9  }, { 0.1, 1.05 } } })
hl.curve("winIn",  { type = "bezier", points = { { 0.1,  1.1  }, { 0.1, 1.1  } } })
hl.curve("winOut", { type = "bezier", points = { { 0.3,  -0.3 }, { 0,   1    } } })
hl.curve("liner",  { type = "bezier", points = { { 1,    1    }, { 1,   1    } } })

hl.animation({ leaf = "windows",     enabled = true, speed = 6,  bezier = "wind",   style = "slide" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 6,  bezier = "winIn",  style = "slide" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 5,  bezier = "winOut", style = "slide" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 5,  bezier = "wind",   style = "slide" })
hl.animation({ leaf = "border",      enabled = true, speed = 1,  bezier = "liner"                   })
hl.animation({ leaf = "borderangle", enabled = true, speed = 30, bezier = "liner",  style = "loop"  })
hl.animation({ leaf = "fade",        enabled = true, speed = 10, bezier = "default"                 })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 5,  bezier = "wind"                    })

--------------------------------------------------------------------------------
-- window rules
--------------------------------------------------------------------------------

hl.window_rule({ match = { class = "pavucontrol"        }, float  = true })
hl.window_rule({ match = { class = "blueman-manager"    }, float  = true })

hl.window_rule({ match = { class = "firefox"            }, opacity = "0.90 0.90" })
hl.window_rule({ match = { class = "dev.zed.Zed"        }, opacity = "0.90 0.90" })
hl.window_rule({ match = { class = "spotify"            }, opacity = "0.80 0.80" })
hl.window_rule({ match = { class = "kitty"              }, opacity = "0.80 0.80" })
hl.window_rule({ match = { class = "org.gnome.Nautilus" }, opacity = "0.80 0.80" })

--------------------------------------------------------------------------------
-- keybinds
--------------------------------------------------------------------------------

local mod = "SUPER"
local ipc = "qs -c noctalia-shell ipc call"

local term = "kitty"
local ed   = "zeditor"
local br   = "firefox"
local fm   = "nautilus"

-- core
hl.bind(mod .. " + Return", hl.dsp.exec_cmd(term))
hl.bind(mod .. " + Escape", hl.dsp.exit())
hl.bind(mod .. " + Q",      hl.dsp.window.close())
hl.bind(mod .. " + V",      hl.dsp.window.float({ action = "toggle" }))

-- apps
hl.bind(mod .. " + F", hl.dsp.exec_cmd(fm))
hl.bind(mod .. " + C", hl.dsp.exec_cmd(ed))
hl.bind(mod .. " + B", hl.dsp.exec_cmd(br))
hl.bind(mod .. " + I", hl.dsp.exec_cmd(term .. " -e btop"))
hl.bind(mod .. " + S", hl.dsp.exec_cmd("spotify"))

-- noctalia ipc
hl.bind(mod .. " + D", hl.dsp.exec_cmd(ipc .. " launcher toggle"))
hl.bind(mod .. " + W", hl.dsp.exec_cmd(ipc .. " wallpaper toggle"))
hl.bind(mod .. " + I", hl.dsp.exec_cmd(ipc .. " settings toggle"))

-- trash
hl.bind(mod .. " + ALT + E", hl.dsp.exec_cmd(
  "sh -c \"trash-empty -f; notify-send -i user-trash-full 'Trash Service' 'Wastebasket has been cleared across all drives.'\""
))

-- media
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd(ipc .. " volume increase"),    { repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd(ipc .. " volume decrease"),    { repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd(ipc .. " volume muteOutput"))
hl.bind("XF86AudioPlay",         hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind("XF86AudioNext",         hl.dsp.exec_cmd("playerctl next"))
hl.bind("XF86AudioPrev",         hl.dsp.exec_cmd("playerctl previous"))
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(ipc .. " brightness increase"), { repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(ipc .. " brightness decrease"), { repeating = true })

-- focus
hl.bind(mod .. " + H", hl.dsp.focus({ direction = "left"  }))
hl.bind(mod .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + K", hl.dsp.focus({ direction = "up"    }))
hl.bind(mod .. " + J", hl.dsp.focus({ direction = "down"  }))

-- workspaces
for i = 1, 5 do
  hl.bind(mod .. " + " .. i,         hl.dsp.focus({ workspace = i }))
  hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

-- scroll workspaces
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- move/resize with mouse
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
