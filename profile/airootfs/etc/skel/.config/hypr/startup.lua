-- Autostart — see https://wiki.hypr.land/Configuring/Basics/Autostart/

hl.on("hyprland.start", function()
    hl.exec_cmd("~/.config/hypr/xdg-portal-hyprland")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE")
    hl.exec_cmd("sh -c 'test -x /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 && /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 || /usr/lib/polkit-kde-authentication-agent-1 &'")
    hl.exec_cmd("systemctl --user start graphical-session.target 2>/dev/null || true")
    hl.exec_cmd("mako &")
    hl.exec_cmd("waybar &")
    hl.exec_cmd("hyprpaper &")
    hl.exec_cmd("sh -c 'wl-paste --type text --watch cliphist store & wl-paste --type image --watch cliphist store &'")
    hl.exec_cmd("hypridle &")
    hl.exec_cmd("sh -c 'systemctl --user start aphotic-shell.service || (pgrep -x qs || pgrep -x quickshell || qs -c aphotic &)'")
    hl.exec_cmd("blueman-applet &")
    hl.exec_cmd("nm-applet --indicator &")
    hl.exec_cmd("sh -c 'if [ ! -f ~/.config/awww/current-wallpaper ]; then mkdir -p ~/.config/awww && cp /usr/share/backgrounds/aegis/aegis-wallpaper.svg ~/.config/awww/current-wallpaper 2>/dev/null || true; fi'")
    hl.exec_cmd("~/.local/bin/aphotic theme ensure-default || true")
    -- Connects only if Settings.vpnAutoConnect is true (checked inside
    -- the command itself, see cmd_vpn.sh's `autostart` subcommand) --
    -- warns and no-ops without passwordless sudo, same as everything
    -- else in commands/README.md's sudoers section.
    hl.exec_cmd("~/.local/bin/aphotic vpn autostart")
    -- No-op unless the installed version changed since the last time this
    -- ran (see cmd_whatsnew.sh) -- catches "git pull without a fresh
    -- install.sh run" as well as the normal post-install case, which
    -- already triggers this same command directly from install.sh.
    hl.exec_cmd("~/.local/bin/aphotic whatsnew")

    -- Cursor theme/size, icon theme, and gtk-theme used to be hardcoded
    -- here, but that meant every reboot silently overwrote whatever was
    -- picked in Settings' Personalization pane (or, for gtk-theme, drifted
    -- and just stayed drifted -- nothing reasserted it between Hyprland
    -- restarts). services/Settings.qml now applies all three itself
    -- (hyprctl setcursor + gsettings) right after loading its persisted
    -- state, whether that's a user choice or the same defaults that used
    -- to live here -- single source of truth instead of two places
    -- fighting over it. See Settings.qml's `gtkTheme` property/
    -- `_applyGtkTheme()` for why adw-gtk3-dark specifically.
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'")

    hl.exec_cmd("gsettings set org.gnome.desktop.interface font-name 'Inter 10'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface document-font-name 'Inter 10'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font Mono 9'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface font-antialiasing 'rgba'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface font-hinting 'full'")
end)
