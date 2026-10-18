-- Aegis OS — Custom Hyprland & Aphotic rules and keybindings

local mainMod = "SUPER"

-- 1. Hardware Cursor, GPU & VM Environment Tweaks
hl.env("WLR_NO_HARDWARE_CURSORS", "1")
hl.env("WLR_RENDERER_ALLOW_SOFTWARE", "1")
hl.env("AQ_NO_MODIFIERS", "1")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("MOZ_ENABLE_WAYLAND", "1")

-- 2. Core Desktop Keybindings
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("kitty || konsole"), { description = "Open Terminal (Kitty/Konsole)" })
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("thunar || dolphin"), { description = "Open File Manager" })
hl.bind(mainMod .. " + space", hl.dsp.exec_cmd("qs -c aphotic ipc call launcher toggle || wofi --show drun"), { description = "Toggle App Launcher" })

-- 3. Aegis OS Specific Keybindings
hl.bind(mainMod .. " + ALT + A", hl.dsp.exec_cmd("konsole --profile Aegis -p tabtitle=\"Aegis AI\" -e aegis-ai"), { description = "Open Aegis AI Agent" })
hl.bind(mainMod .. " + ALT + T", hl.dsp.exec_cmd("konsole --profile Aegis -p tabtitle=\"Aegis Tools\" -e aegis-tools"), { description = "Open Aegis Tools Arsenal" })
hl.bind(mainMod .. " + ALT + I", hl.dsp.exec_cmd("aegis-install"), { description = "Launch Aegis OS Installer" })

-- 4. Aegis Window Rules & Opacity
hl.window_rule({ name = "float-calamares", match = { class = "^(calamares)$" }, float = true })
hl.window_rule({ name = "center-calamares", match = { class = "^(calamares)$" }, move = "50% 50%" })
hl.window_rule({ name = "opacity-kitty", match = { class = "^(kitty)$" }, opacity = "0.92 0.92" })
hl.window_rule({ name = "opacity-konsole", match = { class = "^(konsole|org.kde.konsole)$" }, opacity = "0.90 0.90" })
hl.window_rule({ name = "opacity-thunar", match = { class = "^(thunar|Thunar)$" }, opacity = "0.90 0.90" })
hl.window_rule({ name = "opacity-dolphin", match = { class = "^(dolphin|org.kde.dolphin)$" }, opacity = "0.85 0.85" })
