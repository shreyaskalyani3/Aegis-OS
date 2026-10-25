#!/usr/bin/env bash
# =============================================================================
#  test-shortcuts.sh — static validation for the shipped Hyprland/Aphotic
#  shortcut path. No Hyprland, Wayland session, Arch, or network is required.
#
#  Checks the contracts that can otherwise make every Super/Mod shortcut look
#  dead at once:
#    1. the active Lua entrypoint actually loads keybinds.lua;
#    2. Lua and legacy bind tables do not register the same combo twice;
#    3. modifier/key spellings are representable by Hyprland's parsers;
#    4. every executable used by the shipped shortcut set is packaged or
#       supplied by the profile overlay;
#    5. every Aphotic IPC target/method used by a bind exists in the shell.
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}" || exit 1

H="profile/airootfs/etc/skel/.config/hypr"
LUA="${H}/hyprland.lua"
KEYBINDS="${H}/keybinds.lua"
CUSTOM="${H}/custom.lua"
LEGACY="${H}/hyprland.conf"
STARTUP="${H}/startup.lua"
QS="profile/airootfs/etc/skel/.config/quickshell/aphotic"
PKGS="profile/packages.x86_64"
FAIL=0

note() { printf '%s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; FAIL=1; }

trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "${value}"
}

note "=== Hyprland entrypoint and startup ========================="
for file in "${LUA}" "${KEYBINDS}" "${CUSTOM}" "${LEGACY}" "${STARTUP}"; do
    [[ -f "${file}" ]] || bad "missing shortcut file: ${file}"
done
grep -Fq 'require("keybinds")' "${LUA}" \
    || bad "hyprland.lua does not load keybinds.lua"
grep -Fq 'require("custom")' "${LUA}" \
    || bad "hyprland.lua does not load custom.lua"
keybind_line="$(grep -nF 'require("keybinds")' "${LUA}" | cut -d: -f1 || true)"
custom_line="$(grep -nF 'require("custom")' "${LUA}" | cut -d: -f1 || true)"
if [[ -z "${keybind_line}" || -z "${custom_line}" || "${keybind_line}" -ge "${custom_line}" ]]; then
    bad "hyprland.lua must load keybinds.lua before custom.lua"
fi
grep -Fq 'hl.on("hyprland.start"' "${STARTUP}" \
    || bad "startup.lua has no hyprland.start handler"
grep -Fq 'aegis-session-start || qs -c aphotic' "${STARTUP}" \
    || bad "startup.lua has no ordered session helper/direct shell fallback"
grep -Fq 'exec-once = aegis-session-start || qs -c aphotic' "${LEGACY}" \
    || bad "legacy config has no ordered session helper/direct shell fallback"
if grep -q 'hyprpaper &' "${STARTUP}" "${LEGACY}"; then
    bad "Hyprpaper competes with the Aphotic/awww wallpaper service"
fi
if grep -Eq '^[[:space:]]*hl\.bind\(' "${CUSTOM}"; then
    bad "custom.lua still registers compositor binds; keybinds.lua must be the single Lua bind table"
fi
note "  Lua entrypoint, keybind module, custom-rule separation, and startup path checked"

note ""
note "=== Lua syntax ==============================================="
LUA_FILES=("${H}/"*.lua)
if command -v luac >/dev/null 2>&1; then
    for file in "${LUA_FILES[@]}"; do
        luac -p "${file}" || bad "Lua syntax error: ${file}"
    done
    note "  luac parsed ${#LUA_FILES[@]} Hyprland Lua files"
elif command -v lua >/dev/null 2>&1; then
    for file in "${LUA_FILES[@]}"; do
        # Passing a script after -e executes it too (and fails on the
        # compositor-only `hl` API). Load/parse it without executing the chunk.
        LUA_CHECK_FILE="${file}" lua -e 'assert(loadfile(os.getenv("LUA_CHECK_FILE")))' \
            || bad "Lua syntax error: ${file}"
    done
    note "  lua parsed ${#LUA_FILES[@]} Hyprland Lua files"
else
    note "  (lua/luac unavailable - syntax check deferred to the image runtime)"
fi

# Return a stable modmask|key identity for a Hyprland-style combo. This accepts
# the aliases the repository's Aphotic plugin parser accepts, while rejecting
# a typo that would create a bind with no matching physical modifier.
combo_key() {
    local combo="$1"
    local -a parts=()
    IFS='+' read -r -a parts <<< "${combo}"
    [[ "${#parts[@]}" -gt 0 ]] || return 1

    local key="${parts[$(( ${#parts[@]} - 1 ))]}"
    key="$(trim "${key}")"
    [[ "${key}" =~ ^[A-Za-z0-9_:.-]+$ ]] || return 1

    local mask=0 token mod
    local i
    for ((i = 0; i < ${#parts[@]} - 1; i++)); do
        token="$(trim "${parts[$i]}")"
        [[ -n "${token}" ]] || return 1
        mod="${token^^}"
        case "${mod}" in
            SHIFT) mask=$((mask | 1)) ;;
            CAPS)  mask=$((mask | 2)) ;;
            CTRL|CONTROL) mask=$((mask | 4)) ;;
            ALT|MOD1) mask=$((mask | 8)) ;;
            MOD2) mask=$((mask | 16)) ;;
            MOD3) mask=$((mask | 32)) ;;
            SUPER|WIN|LOGO|MOD4) mask=$((mask | 64)) ;;
            MOD5) mask=$((mask | 128)) ;;
            *) return 1 ;;
        esac
    done
    printf '%d|%s' "${mask}" "${key,,}"
}

note ""
note "=== Legacy bind table ========================================"
declare -A legacy_seen=()
legacy_count=0
while IFS= read -r line; do
    line="${line%%#*}"
    [[ -n "$(trim "${line}")" ]] || continue
    [[ "${line}" =~ ^[[:space:]]*(bind[a-z]*)[[:space:]]*= ]] || continue

    kind="${BASH_REMATCH[1]}"
    rhs="${line#*=}"
    mod_field="${rhs%%,*}"
    remainder="${rhs#*,}"
    key_field="${remainder%%,*}"
    mod_field="$(trim "${mod_field}")"
    key_field="$(trim "${key_field}")"
    mod_field="${mod_field//\$mainMod/SUPER}"
    combo=""
    read -r -a legacy_mods <<< "${mod_field}"
    for mod in "${legacy_mods[@]}"; do
        combo+="${combo:+ + }${mod}"
    done
    combo+="${combo:+ + }${key_field}"
    if ! identity="$(combo_key "${combo}")"; then
        bad "invalid ${kind} combo in ${LEGACY}: ${combo}"
        continue
    fi
    if [[ -n "${legacy_seen[${identity}]+yes}" ]]; then
        bad "duplicate legacy bind ${identity} in ${LEGACY}"
    else
        legacy_seen["${identity}"]="${kind}"
    fi
    legacy_count=$((legacy_count + 1))
done < <(grep -E '^[[:space:]]*bind[a-z]*[[:space:]]*=' "${LEGACY}" || true)
note "  checked ${legacy_count} legacy bind entries with no duplicate combo"

note ""
note "=== Lua bind table ============================================"
declare -A lua_seen=()
lua_count=0
while IFS= read -r line; do
    # Binds created by the switcher submap are intentionally dynamic and are
    # scoped to that submap; only literal top-level combos are checked here.
    [[ "${line}" == *".. key"* ]] && continue
    combo="$(sed -nE 's/.*hl\.bind\(mainMod[[:space:]]*\.\.[[:space:]]*" \+ ([^"]*)".*/SUPER + \1/p' <<< "${line}")"
    if [[ -z "${combo}" ]]; then
        combo="$(sed -nE 's/.*hl\.bind\("([^"]+)"[[:space:]]*,.*/\1/p' <<< "${line}")"
    fi
    [[ -n "${combo}" ]] || continue
    if ! identity="$(combo_key "${combo}")"; then
        bad "invalid Lua combo in ${KEYBINDS}: ${combo}"
        continue
    fi
    if [[ -n "${lua_seen[${identity}]+yes}" ]]; then
        bad "duplicate Lua bind ${identity} in ${KEYBINDS}"
    else
        lua_seen["${identity}"]=1
    fi
    lua_count=$((lua_count + 1))
done < <(grep -E '^[[:space:]]*hl\.bind\(' "${KEYBINDS}" || true)
note "  checked ${lua_count} literal Lua bind entries with no duplicate combo"

note ""
note "=== Shortcut command availability ============================="
pkg_installed() {
    sed '/^[[:space:]]*#/d;s/[[:space:]]*#.*//;/^[[:space:]]*$/d' "${PKGS}" \
        | grep -Fxq -- "$1"
}

profile_command() {
    local command="$1"
    [[ -f "profile/airootfs/usr/local/bin/${command}" \
        || -f "profile/airootfs/etc/skel/.local/bin/${command}" ]]
}

require_command() {
    local command="$1" package="$2"
    if profile_command "${command}" || pkg_installed "${package}"; then
        note "  ok   ${command} <- ${package} or profile overlay"
    else
        bad "shortcut command '${command}' is neither shipped by the overlay nor backed by package '${package}'"
    fi
}

while IFS='|' read -r command package; do
    require_command "${command}" "${package}"
done <<'EOF'
kitty|kitty
foot|foot
aegis-session-start|aegis-meta
aegis-lock|aegis-meta
qs|quickshell
wofi|wofi
thunar|thunar
aegis-clipboard|aegis-meta
aegis-cheatsheet|aegis-meta
grim|grim
slurp|slurp
swappy|swappy
mkdir|base
wf-recorder|wf-recorder
aphotic|aegis-meta
systemctl|base
firefox|firefox
nvim|neovim
aegis-ai|aegis-meta
aegis-tools|aegis-meta
aegis-install|aegis-meta
pkill|psmisc
notify-send|libnotify
pamixer|pamixer
brightnessctl|brightnessctl
playerctl|playerctl
EOF

note ""
note "=== Aphotic IPC targets ======================================"
assert_ipc() {
    local target="$1" method="$2" file="$3"
    [[ -f "${file}" ]] || { bad "IPC owner file is missing: ${file}"; return; }
    grep -Fq "target: \"${target}\"" "${file}" \
        || bad "Aphotic IPC target '${target}' is not declared in ${file}"
    grep -Eq "function[[:space:]]+${method}\\(" "${file}" \
        || bad "Aphotic IPC method '${target} ${method}' is not declared in ${file}"
}

while IFS='|' read -r target method file; do
    assert_ipc "${target}" "${method}" "${file}"
done <<'EOF'
aphotic|toggle|profile/airootfs/etc/skel/.config/quickshell/aphotic/shell.qml
launcher|toggle|profile/airootfs/etc/skel/.config/quickshell/aphotic/shell.qml
launcher|openWallpapers|profile/airootfs/etc/skel/.config/quickshell/aphotic/shell.qml
session|toggle|profile/airootfs/etc/skel/.config/quickshell/aphotic/shell.qml
dashboard|toggle|profile/airootfs/etc/skel/.config/quickshell/aphotic/shell.qml
settings|toggle|profile/airootfs/etc/skel/.config/quickshell/aphotic/shell.qml
notifs|clear|profile/airootfs/etc/skel/.config/quickshell/aphotic/services/Notifs.qml
notifications|toggle|profile/airootfs/etc/skel/.config/quickshell/aphotic/shell.qml
pkginstall|toggle|profile/airootfs/etc/skel/.config/quickshell/aphotic/shell.qml
dnd|toggle|profile/airootfs/etc/skel/.config/quickshell/aphotic/shell.qml
bar|cycleStyle|profile/airootfs/etc/skel/.config/quickshell/aphotic/services/Settings.qml
intelligence|toggle|profile/airootfs/etc/skel/.config/quickshell/aphotic/shell.qml
picker|open|profile/airootfs/etc/skel/.config/quickshell/aphotic/modules/areapicker/AreaPicker.qml
picker|openFreeze|profile/airootfs/etc/skel/.config/quickshell/aphotic/modules/areapicker/AreaPicker.qml
picker|openClip|profile/airootfs/etc/skel/.config/quickshell/aphotic/modules/areapicker/AreaPicker.qml
picker|openFreezeClip|profile/airootfs/etc/skel/.config/quickshell/aphotic/modules/areapicker/AreaPicker.qml
colorpicker|toggle|profile/airootfs/etc/skel/.config/quickshell/aphotic/modules/colorpicker/ColorPicker.qml
audio|cycleOutput|profile/airootfs/etc/skel/.config/quickshell/aphotic/services/Audio.qml
hypr|cycleSpecialWorkspace|profile/airootfs/etc/skel/.config/quickshell/aphotic/services/Hypr.qml
mpris|playPause|profile/airootfs/etc/skel/.config/quickshell/aphotic/services/Players.qml
mpris|next|profile/airootfs/etc/skel/.config/quickshell/aphotic/services/Players.qml
mpris|previous|profile/airootfs/etc/skel/.config/quickshell/aphotic/services/Players.qml
switcher|next|profile/airootfs/etc/skel/.config/quickshell/aphotic/services/Switcher.qml
switcher|prev|profile/airootfs/etc/skel/.config/quickshell/aphotic/services/Switcher.qml
switcher|move|profile/airootfs/etc/skel/.config/quickshell/aphotic/services/Switcher.qml
switcher|workspace|profile/airootfs/etc/skel/.config/quickshell/aphotic/services/Switcher.qml
switcher|window|profile/airootfs/etc/skel/.config/quickshell/aphotic/services/Switcher.qml
switcher|commit|profile/airootfs/etc/skel/.config/quickshell/aphotic/services/Switcher.qml
switcher|cancel|profile/airootfs/etc/skel/.config/quickshell/aphotic/services/Switcher.qml
lock|engage|profile/airootfs/etc/skel/.config/quickshell/aphotic/modules/lock/Lock.qml
EOF
note "  Aphotic bind IPC targets and methods checked"

if [[ "${FAIL}" -eq 0 ]]; then
    note "SHORTCUT-STATIC-CHECK-PASS"
else
    note "SHORTCUT-STATIC-CHECK-FAIL"
fi
exit "${FAIL}"
