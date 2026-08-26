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
#    6. xfce4-panel.xml plugin-ids <-> plugin definitions <-> launcher-N/ dirs
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
done < <(find profile/airootfs -name '*.desktop' | sort)
note "  checked $(find profile/airootfs -name '*.desktop' | wc -l) .desktop files"

while IFS= read -r f; do
    head -1 "$f" | grep -q '^\[Desktop Entry\]' || bad "$f missing header"
    grep -q '^Type=Directory' "$f" || bad "$f is not Type=Directory"
    grep -q '^Icon=' "$f" || bad "$f missing Icon="
done < <(find profile/airootfs -name '*.directory' | sort)
note "  checked $(find profile/airootfs -name '*.directory' | wc -l) .directory files"

note ""
note "=== 3. Category <-> .directory <-> .menu cross-reference ===="
# every X-Aegis-* used by a launcher must appear in the merge fragment
MENU=profile/airootfs/etc/xdg/menus/xfce-applications-merged/aegis-tools.menu
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
note "=== 6. Panel plugin-ids <-> plugins consistency ============="
P=profile/airootfs/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml
ids=$(grep -o '<value type="int" value="[0-9]*"/>' "$P" | grep -o '[0-9]*' | sort -n | uniq)
for i in $ids; do
    grep -q "name=\"plugin-${i}\"" "$P" || bad "panel references plugin-${i} with no definition"
done
# every launcher plugin must have its items dir shipped
for i in $(grep -B1 'value="launcher"' "$P" | grep -o 'plugin-[0-9]*' | grep -o '[0-9]*'); do
    [[ -d "profile/airootfs/etc/skel/.config/xfce4/panel/launcher-${i}" ]] \
        || bad "launcher plugin-${i} has no launcher-${i}/ directory"
done
for i in $(grep -o 'plugin-[0-9]*" type="string" value="launcher"' "$P" | grep -o '[0-9]*'); do
    [[ -d "profile/airootfs/etc/skel/.config/xfce4/panel/launcher-${i}" ]] \
        || bad "launcher plugin-${i} has no launcher-${i}/ directory"
done
# and every shipped launcher dir must be referenced
for d in profile/airootfs/etc/skel/.config/xfce4/panel/launcher-*; do
    i="${d##*-}"
    grep -q "plugin-${i}\" type=\"string\" value=\"launcher\"" "$P" || bad "launcher-${i}/ shipped but plugin-${i} is not a launcher"
    item="$(basename "$(ls "$d"/*.desktop 2>/dev/null | head -1)")"
    grep -q "value=\"${item}\"" "$P" || bad "launcher-${i}/${item} not referenced in panel items"
done
note "  plugin ids: $(printf '%s\n' $ids | wc -l)"

note ""
if [[ $FAIL -eq 0 ]]; then note "ALL CHECKS PASSED"; else note "THERE WERE FAILURES"; fi
exit $FAIL
