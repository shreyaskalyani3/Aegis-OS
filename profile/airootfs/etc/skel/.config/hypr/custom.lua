-- Aegis OS — Custom Hyprland & Aphotic rules and keybindings

local mainMod = "SUPER"

-- 1. Hardware Cursor & VM Environment Tweaks
hl.env("WLR_NO_HARDWARE_CURSORS", "1")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- 2. Aegis OS Specific Keybindings
hl.bind(mainMod .. " + ALT + A", hl.dsp.exec_cmd("konsole --profile Aegis -p tabtitle=\"Aegis AI\" -e aegis-ai"), { description = "Open Aegis AI Agent" })
hl.bind(mainMod .. " + ALT + T", hl.dsp.exec_cmd("konsole --profile Aegis -p tabtitle=\"Aegis Tools\" -e aegis-tools"), { description = "Open Aegis Tools Arsenal" })
hl.bind(mainMod .. " + ALT + I", hl.dsp.exec_cmd("aegis-install"), { description = "Launch Aegis OS Installer" })

-- 3. Aegis Window Rules & Opacity
hl.window_rule({ name = "float-calamares", match = { class = "^(calamares)$" }, float = true })
hl.window_rule({ name = "center-calamares", match = { class = "^(calamares)$" }, move = "50% 50%" })
hl.window_rule({ name = "opacity-konsole", match = { class = "^(konsole|org.kde.konsole)$" }, opacity = "0.90 0.90" })
hl.window_rule({ name = "opacity-dolphin", match = { class = "^(dolphin|org.kde.dolphin)$" }, opacity = "0.85 0.85" })
