#!/usr/bin/env bash
# =============================================================================
#  check-profile.sh — static checks on the airootfs overlay, runnable anywhere
#  (no Arch, no Docker, no root). Catches the failures that would otherwise only
#  show up after a ~2h ISO build and a boot:
#
#    1. malformed XML / .menu / SVG
#    2. .desktop and .directory entries missing required keys
#    3. Categories <-> .directory <-> .menu cross-references
#    3b. Icon= names that resolve to nothing we ship
#    4. shell syntax of every script in the image
#    5. every /usr/local/bin script has a profiledef.sh file_permissions entry
#       -- the repo is authored on Windows so everything is mode 0644 in git;
#       a missing entry means the script silently is not executable in the ISO
#    6. Hyprland session, autologin, and Aphotic startup consistency
#    7. live boot/systemd enablement, VM guest integration, and first login
#    8. every theme / icon name referenced anywhere is backed by a package we
#       install -- so names with no package behind them are caught before build
#       time rather than falling back silently at runtime
# =============================================================================
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)" || exit 1
FAIL=0
note(){ printf '%s\n' "$*"; }
bad(){ printf 'FAIL: %s\n' "$*"; FAIL=1; }

note "=== 1. XML / menu well-formedness ==========================="
py=""
for c in python python3 py; do command -v "$c" >/dev/null 2>&1 && { py="$c"; break; }; done
if [[ -z "$py" ]]; then
    note "  (no python found - skipping, will rely on the build)"
else
    while IFS= read -r f; do
        if "$py" -c "import sys,xml.etree.ElementTree as E; E.parse(sys.argv[1])" "$f" 2>/dev/null; then
            note "  ok   $f"
        else
            bad "malformed XML: $f"
            "$py" -c "import sys,xml.etree.ElementTree as E; E.parse(sys.argv[1])" "$f"
        fi
    done < <(find profile/airootfs -name '*.xml' -o -name '*.menu' -o -name '*.svg' | sort)
fi

note ""
note "=== 2. Desktop-entry required keys =========================="
while IFS= read -r f; do
    for k in Type Name Exec Icon; do
        grep -q "^${k}=" "$f" || bad "$f missing ${k}="
    done
    head -1 "$f" | grep -q '^\[Desktop Entry\]' || bad "$f missing [Desktop Entry] header"
done < <(find profile/airootfs -name '*.desktop' ! -path '*/sddm/themes/*' | sort)
note "  checked $(find profile/airootfs -name '*.desktop' ! -path '*/sddm/themes/*' | wc -l) .desktop files"

while IFS= read -r f; do
    head -1 "$f" | grep -q '^\[Desktop Entry\]' || bad "$f missing header"
    grep -q '^Type=Directory' "$f" || bad "$f is not Type=Directory"
    grep -q '^Icon=' "$f" || bad "$f missing Icon="
done < <(find profile/airootfs -name '*.directory' | sort)
note "  checked $(find profile/airootfs -name '*.directory' | wc -l) .directory files"

note ""
note "=== 3. Category <-> .directory <-> .menu cross-reference ===="
# every X-Aegis-* used by a launcher must appear in the merge fragment
MENU=profile/airootfs/etc/xdg/menus/applications-merged/aegis-tools.menu
for cat in $(grep -ho 'X-Aegis-[A-Za-z]*' profile/airootfs/usr/share/applications/*.desktop | sort -u); do
    grep -q "<Category>${cat}</Category>" "$MENU" || bad "category ${cat} used but not in the .menu"
done
# every <Directory> referenced by the menu must exist
for d in $(grep -o '<Directory>[^<]*</Directory>' "$MENU" | sed 's/<[^>]*>//g'); do
    [[ -f "profile/airootfs/usr/share/desktop-directories/$d" ]] || bad "menu references missing $d"
done
note "  categories: $(grep -ho 'X-Aegis-[A-Za-z]*' profile/airootfs/usr/share/applications/*.desktop | sort -u | wc -l), directories: $(grep -c '<Directory>' "$MENU")"

note ""
note "=== 3b. Every Icon= resolves to an icon we ship ============="
# Stock names we rely on from Papirus / hicolor (present via installed packages).
STOCK="utilities-terminal system-file-manager firefox preferences-system system-software-install dialog-password preferences-desktop-wallpaper"
for icon in $(grep -rh '^Icon=' profile/airootfs --include='*.desktop' --include='*.directory' | sed 's/^Icon=//' | sort -u); do
    if [[ -f "profile/airootfs/usr/share/icons/hicolor/scalable/apps/${icon}.svg" ]]; then
        note "  ours  ${icon}"
    elif printf '%s ' $STOCK | grep -qw -- "${icon}"; then
        note "  stock ${icon}"
    else
        bad "Icon=${icon} resolves to nothing we ship and is not a declared stock name"
    fi
done

note ""
note "=== 4. bash -n on every shipped script ====================="
while IFS= read -r f; do
    if bash -n "$f" 2>/dev/null; then note "  ok   $f"; else bad "syntax error: $f"; bash -n "$f"; fi
done < <(find profile/airootfs/usr/local/bin -type f | sort)
bash -n profile/profiledef.sh && note "  ok   profile/profiledef.sh" || bad "profiledef.sh syntax"

note ""
note "=== 5. file_permissions covers every /usr/local/bin script =="
for f in profile/airootfs/usr/local/bin/*; do
    b="$(basename "$f")"
    grep -q "\[\"/usr/local/bin/${b}\"\]" profile/profiledef.sh \
        || bad "/usr/local/bin/${b} has NO file_permissions entry (will not be executable in the ISO)"
done
note "  scripts: $(ls -1 profile/airootfs/usr/local/bin | wc -l), entries: $(grep -c '/usr/local/bin/' profile/profiledef.sh)"

note ""
note "=== 6. Hyprland session & Aphotic startup consistency ==="
H=profile/airootfs/etc/skel/.config/hypr
[[ -f "$H/hyprland.conf" ]] || bad "Hyprland config missing"
[[ -f "$H/hyprland.lua" ]] || bad "Aphotic Hyprland Lua entrypoint missing"
[[ -f "$H/xdg-portal-hyprland" ]] || bad "XDG portal launcher missing"
grep -q '^exec-once = bash ~/.config/hypr/xdg-portal-hyprland$' "$H/hyprland.conf" \
    || bad "Hyprland config does not invoke the XDG portal launcher through bash"
grep -q '^exec-once = waybar &' "$H/hyprland.conf" || bad "Waybar autostart missing"
grep -q '^exec-once = mako &' "$H/hyprland.conf" || bad "Mako autostart missing"
grep -q '^Session=hyprland\.desktop$' profile/airootfs/etc/sddm.conf.d/autologin.conf \
    || bad "SDDM autologin does not select Hyprland"
grep -q 'desktopFile: "hyprland"' profile/airootfs/etc/calamares/modules/displaymanager.conf \
    || bad "Calamares default desktop is not Hyprland"
grep -qx 'hyprland' profile/packages.x86_64 || bad "hyprland is missing from packages.x86_64"
grep -qx 'quickshell' profile/packages.x86_64 || bad "quickshell is missing from packages.x86_64"
grep -qx 'waybar' profile/packages.x86_64 || bad "waybar is missing from packages.x86_64"
grep -qx 'mako' profile/packages.x86_64 || bad "mako is missing from packages.x86_64"
note "  Hyprland, SDDM autologin, Calamares session, and Aphotic startup validated"

note ""
note "=== 7. Live boot/systemd/VM/first-login consistency ========"
BUILD=scripts/build-iso.sh
SYSTEMD=profile/airootfs/etc/systemd/system

for unit in aegis-credentials.service aegis-live-setup.service \
            aegis-firstboot-cleanup.service aegis-vm-guest.service; do
    [[ -f "${SYSTEMD}/${unit}" ]] || bad "missing live/system unit ${unit}"
    grep -Fq "ln -sf \"/etc/systemd/system/${unit}\"" "${BUILD}" \
        || bad "${unit} is shipped but build-iso.sh does not enable it"
done
grep -Fq 'ln -sf "/dev/null" "${SYSD}/systemd-firstboot.service"' "${BUILD}" \
    || bad "systemd-firstboot is not masked in the live image"
grep -Fq 'ln -sf "${LIB}/sddm.service" "${SYSD}/graphical.target.wants/sddm.service"' "${BUILD}" \
    || bad "SDDM is not pulled in by graphical.target"
grep -Fq 'ln -sf "${LIB}/NetworkManager.service"            "${SYSD}/multi-user.target.wants/NetworkManager.service"' "${BUILD}" \
    || bad "NetworkManager is not enabled in the staged image"
[[ -f scripts/dev/test-boot-profile.sh ]] || bad "boot profile smoke test is missing"
grep -Fq 'options[[:space:]]+.*' "${BUILD}" \
    || bad "UEFI systemd-boot options injection is missing"
grep -Fq 'APPEND[[:space:]]+)' "${BUILD}" \
    || bad "BIOS syslinux APPEND injection is missing"
grep -Fq 'linux[[:space:]]+.*' "${BUILD}" \
    || bad "GRUB linux-line injection is missing"

grep -q '^Before=.*display-manager\.service' "${SYSTEMD}/aegis-credentials.service" \
    || bad "credentials service is not ordered before the display manager"
grep -q '^Before=.*display-manager\.service' "${SYSTEMD}/aegis-live-setup.service" \
    || bad "live setup is not ordered before the display manager"
grep -q '^ConditionVirtualization=oracle$' "${SYSTEMD}/aegis-vbox-drm.service" \
    || bad "VirtualBox DRM helper is not restricted to VirtualBox"
grep -q '^ConditionPathExists=/usr/bin/VBoxDRMClient$' "${SYSTEMD}/aegis-vbox-drm.service" \
    || bad "VirtualBox DRM helper does not guard the package-provided binary"
grep -q '^ExecStart=/usr/local/bin/aegis-firstboot-cleanup$' \
    profile/airootfs/etc/systemd/system/aegis-firstboot-cleanup.service \
    || bad "first-boot cleanup unit does not invoke its cleanup script"
if grep -q 'aegis-firstboot-cleanup\.service\|aegis-vm-guest\.service' \
    profile/airootfs/etc/calamares/modules/shellprocess.conf; then
    bad "Calamares cleanup removes the persistent first-boot/VM integration units"
fi
autologin_write="$(grep -n 'cat > /etc/sddm\.conf\.d/autologin\.conf' profile/airootfs/usr/local/bin/aegis-live-setup | cut -d: -f1)"
locale_work="$(grep -n 'locale -a' profile/airootfs/usr/local/bin/aegis-live-setup | cut -d: -f1)"
[[ -n "${autologin_write}" && -n "${locale_work}" && "${autologin_write}" -lt "${locale_work}" ]] \
    || bad "live setup writes SDDM autologin only after optional locale work"

for pkg in virtualbox-guest-utils open-vm-tools xf86-input-vmmouse gtkmm3 \
           qemu-guest-agent spice-vdagent hyperv; do
    grep -qx "${pkg}" profile/packages.x86_64 \
        || bad "VM package ${pkg} is missing from packages.x86_64"
done
VM_SETUP=profile/airootfs/usr/local/bin/aegis-vm-guest-setup
for token in 'oracle)' 'vmware)' 'kvm|qemu)' 'microsoft)' \
             'vboxservice.service' 'vmtoolsd.service' 'qemu-guest-agent.service' \
             'spice-vdagentd.service' 'hv_kvp_daemon.service' 'hv_vss_daemon.service'; do
    grep -Fq "${token}" "${VM_SETUP}" || bad "VM guest setup is missing ${token}"
done
grep -Fq 'systemctl cat "${unit}"' "${VM_SETUP}" \
    || bad "VM guest setup does not guard optional service units"
grep -Fq 'systemctl start --no-block "${unit}"' "${VM_SETUP}" \
    || bad "VM guest setup does not queue guest services asynchronously"

FIRST_LOGIN=profile/airootfs/etc/skel/.config/systemd/user/aegis-first-login.service
SESSION_DROPIN=profile/airootfs/etc/skel/.config/systemd/user/graphical-session.target.d/aegis-session-services.conf
VBOX_SESSION=profile/airootfs/etc/skel/.config/systemd/user/aegis-vbox-session.service
[[ -f "${FIRST_LOGIN}" ]] || bad "first-login user service missing"
[[ -f "${SESSION_DROPIN}" ]] || bad "graphical-session target drop-in missing"
[[ -f "${VBOX_SESSION}" ]] || bad "VirtualBox user-session helper missing"
grep -q '^ExecStartPre=/usr/local/bin/aegis-desktop-setup$' "${FIRST_LOGIN}" \
    || bad "first-login service does not run desktop setup"
grep -q '^ExecStart=/usr/local/bin/aegis-welcome$' "${FIRST_LOGIN}" \
    || bad "first-login service does not launch the setup wizard"
grep -q '^Wants=aegis-first-login\.service aegis-vbox-session\.service$' "${SESSION_DROPIN}" \
    || bad "graphical-session target does not pull in first-login/VM session helpers"
grep -q 'systemctl --user start graphical-session\.target' \
    profile/airootfs/etc/skel/.config/hypr/hyprland.conf \
    || bad "Hyprland does not start the user graphical-session target"
note "  live units, SDDM ordering, guest mappings, and Hyprland first-login path validated"

note ""
note "=== 8. Theme / icon names resolve to installed packages ====="
PKGS=profile/packages.x86_64
SKEL=profile/airootfs/etc/skel

# Which package provides /usr/share/themes/<name> or /usr/share/icons/<name>.
# Add a line when you introduce a new name. An unmapped name FAILS on purpose:
# an unverified theme name is precisely the bug this check exists to stop.
theme_pkg() {
    case "$1" in
        Breeze|BreezeDark|breeze|breeze-dark|Breeze_Snow)           echo breeze ;;
        adw-gtk3|adw-gtk3-dark)                                     echo adw-gtk-theme ;;
        Materia|Materia-dark|Materia-compact|Materia-dark-compact)   echo materia-gtk-theme ;;
        Papirus|Papirus-Dark|Papirus-Light)                          echo papirus-icon-theme ;;
        Adwaita|Adwaita-dark|HighContrast)                           echo gnome-themes-extra ;;
        hicolor)                                                     echo '(hicolor built-in)' ;;
        sugar-candy)                                                 echo '(sugar-candy shipped in overlay)' ;;
        *)                                                           echo '' ;;
    esac
}

# Exact-line lookup, tolerant of the CRLF this repo can pick up on Windows.
pkg_installed(){ tr -d '\r' < "$PKGS" | grep -qx -- "$1"; }

check_theme() {  # $1 = where, $2 = name
    local where="$1" name="$2" pkg
    [[ -n "$name" ]] || return 0
    pkg="$(theme_pkg "$name")"
    if [[ -z "$pkg" ]]; then
        bad "$where names theme/icon '$name' which is not in check-profile.sh's package map — add it there, or fix the name"
    elif [[ "$pkg" == \(* ]]; then
        note "  builtin  $name  $pkg  ($where)"
    elif pkg_installed "$pkg"; then
        note "  ok       $name  <- $pkg  ($where)"
    else
        bad "$where names '$name' but its package '$pkg' is NOT in packages.x86_64"
    fi
}

ini_key(){  [[ -f "$1" ]] || return 0; grep -m1 "^$2[[:space:]]*=" "$1" | sed 's/^[^=]*=[[:space:]]*//; s/^"//; s/"[[:space:]]*$//' | tr -d '\r'; }

# --- Qt, GTK, and SDDM theme assets ---
check_theme "kdeglobals (ColorScheme)"  "$(ini_key "$SKEL/.config/kdeglobals" ColorScheme)"
check_theme "kdeglobals (Icon Theme)"   "$(ini_key "$SKEL/.config/kdeglobals" Theme)"
check_theme "kdeglobals (widgetStyle)"  "$(ini_key "$SKEL/.config/kdeglobals" widgetStyle)"
check_theme "plasmarc (Theme)"          "$(ini_key "$SKEL/.config/plasmarc" name)"
check_theme "kwinrc (Theme)"            "$(ini_key "$SKEL/.config/kwinrc" Theme)"
check_theme "kcminputrc (cursorTheme)"  "$(ini_key "$SKEL/.config/kcminputrc" cursorTheme)"

SDDM_CONF=profile/airootfs/etc/sddm.conf.d/kde_settings.conf
check_theme "sddm (Current theme)"      "$(ini_key "$SDDM_CONF" Current)"
check_theme "sddm (CursorTheme)"        "$(ini_key "$SDDM_CONF" CursorTheme)"

for g in 3 4; do
    check_theme "gtk-$g.0/settings.ini" "$(ini_key "$SKEL/.config/gtk-$g.0/settings.ini" gtk-theme-name)"
    check_theme "gtk-$g.0/settings.ini" "$(ini_key "$SKEL/.config/gtk-$g.0/settings.ini" gtk-icon-theme-name)"
done
check_theme ".gtkrc-2.0"        "$(ini_key "$SKEL/.gtkrc-2.0" gtk-theme-name)"
check_theme ".gtkrc-2.0"        "$(ini_key "$SKEL/.gtkrc-2.0" gtk-icon-theme-name)"

# GTK2 has no dark default at all, and adw-gtk-theme ships no gtk-2.0/, so the
# GTK2 name must come from somewhere that does or legacy tools render light grey.
G2="$(ini_key "$SKEL/.gtkrc-2.0" gtk-theme-name)"
case "$G2" in
    Materia*) : ;;
    '')       bad ".gtkrc-2.0 sets no gtk-theme-name, so GTK2 apps render in stock light grey" ;;
    *)        note "  note     .gtkrc-2.0 uses '$G2' — confirm it ships a gtk-2.0/ directory" ;;
esac

note ""
if [[ $FAIL -eq 0 ]]; then note "ALL CHECKS PASSED"; else note "THERE WERE FAILURES"; fi
exit $FAIL
