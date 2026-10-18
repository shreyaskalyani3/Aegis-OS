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
#    6. KDE Plasma panel applets and pinned taskbar launchers
#    7. every theme / icon name referenced anywhere is backed by a package we
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
note "=== 6. KDE Plasma desktop & panel consistency ============="
P=profile/airootfs/etc/skel/.config/plasma-org.kde.plasma.desktop-appletsrc
[[ -f "$P" ]] || bad "plasma-org.kde.plasma.desktop-appletsrc missing"
grep -q 'plugin=org.kde.plasma.kickoff' "$P" || bad "kickoff applet missing from plasma panel"
grep -q 'plugin=org.kde.plasma.icontasks' "$P" || bad "icontasks applet missing from plasma panel"
grep -q 'plugin=org.kde.plasma.systemtray' "$P" || bad "systemtray applet missing from plasma panel"
grep -q 'plugin=org.kde.plasma.digitalclock' "$P" || bad "digitalclock applet missing from plasma panel"
launchers="$(grep '^launchers=' "$P" | sed 's/^launchers=//' | tr ',' ' ')"
for l in $launchers; do
    app="$(echo "$l" | sed 's/^applications://')"
    if [[ "$app" == "aegis-"* ]]; then
        [[ -f "profile/airootfs/usr/share/applications/$app" ]] || bad "taskbar references missing $app"
    fi
done
note "  Plasma panel validated with applets and pinned taskbar launchers"

note ""
note "=== 7. Theme / icon names resolve to installed packages ====="
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

# --- KDE Plasma & KWin themes ---
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
