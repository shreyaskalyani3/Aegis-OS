#!/usr/bin/env bash
# =============================================================================
#  check-build-config.sh — portable build/profile configuration preflight.
#
#  Runs without Arch, Docker, root, pacman, or network access. It guards the
#  contracts shared by native, Docker, CI, and WSL builds so those failures are
#  reported before a long ISO build starts.
# =============================================================================
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}" || exit 1
FAIL=0

note() { printf '%s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; FAIL=1; }

note "=== central configuration ===================================="
if ( source scripts/lib/common.sh && validate_config ); then
    note "  central configuration validates"
else
    bad "central configuration failed common.sh validation"
fi

config_value() {
    local variable="$1"
    shift
    env -i PATH="${PATH:-/usr/bin:/bin}" HOME="${HOME:-/tmp}" "$@" \
        bash -c 'source "$1"; printf "%s" "${!2}"' \
        _ "${ROOT}/aegis.conf" "${variable}"
}

default_tool_set="$(config_value AEGIS_TOOL_SET)"
default_desktop="$(config_value AEGIS_DESKTOP)"
[[ "${default_tool_set}" == "lean" ]] \
    || bad "aegis.conf default AEGIS_TOOL_SET is '${default_tool_set}', expected lean"
[[ "${default_desktop}" == "hyprland" ]] \
    || bad "aegis.conf default AEGIS_DESKTOP is '${default_desktop}', expected hyprland"
[[ "$(config_value AEGIS_ENABLE_BLACKARCH AEGIS_ENABLE_BLACKARCH=0)" == "0" ]] \
    || bad "AEGIS_ENABLE_BLACKARCH=0 is not preserved when aegis.conf is sourced"
[[ "$(config_value AEGIS_ENABLE_CHAOTIC AEGIS_ENABLE_CHAOTIC=1)" == "1" ]] \
    || bad "AEGIS_ENABLE_CHAOTIC=1 is not preserved when aegis.conf is sourced"
[[ "$(config_value AEGIS_TOOL_SET AEGIS_TOOL_SET=broad)" == "broad" ]] \
    || bad "AEGIS_TOOL_SET=broad is not preserved when aegis.conf is sourced"

if grep -n 'AEGIS_TOOL_SET:-broad' scripts/build-iso.sh >/dev/null 2>&1; then
    bad "scripts/build-iso.sh still carries a broad fallback that can drift from aegis.conf"
fi
if grep -n 'AEGIS_TOOL_SET:-lean' scripts/build-docker.sh >/dev/null 2>&1; then
    bad "scripts/build-docker.sh still hardcodes a tool-set default"
fi
if grep -n 'default="broad"' services/builder-api/main.py >/dev/null 2>&1; then
    bad "services/builder-api/main.py still defaults API builds to broad"
fi
grep -q 'DEFAULT_TOOL_SET = os.getenv("AEGIS_TOOL_SET", "lean")' services/builder-api/main.py \
    || bad "builder API does not derive its default tool set from AEGIS_TOOL_SET"
grep -q 'DEFAULT_BLACKARCH = _DEFAULT_BLACKARCH == "1"' services/builder-api/main.py \
    || bad "builder API does not derive its BlackArch default from AEGIS_ENABLE_BLACKARCH"

note "=== profiledef / Calamares layout contract ==================="
if bash -n profile/profiledef.sh; then
    profile_values="$(env -i PATH="${PATH:-/usr/bin:/bin}" HOME="${HOME:-/tmp}" \
        bash -c 'source "$1"; printf "%s|%s|%s" "$install_dir" "$arch" "$airootfs_image_type"' \
        _ "${ROOT}/profile/profiledef.sh")"
    IFS='|' read -r install_dir profile_arch image_type <<< "${profile_values}"
    unpack_source="/run/archiso/bootmnt/${install_dir}/${profile_arch}/airootfs.sfs"
    grep -Fq "source: \"${unpack_source}\"" profile/airootfs/etc/calamares/modules/unpackfs.conf \
        || bad "unpackfs.conf source does not match profiledef.sh (${unpack_source})"
    grep -Fq "sourcefs: \"${image_type}\"" profile/airootfs/etc/calamares/modules/unpackfs.conf \
        || bad "unpackfs.conf sourcefs does not match profiledef.sh (${image_type})"
    note "  profiledef.sh and unpackfs.conf agree (${unpack_source}, ${image_type})"
else
    bad "profile/profiledef.sh has shell syntax errors"
fi

note "=== package-list hygiene ====================================="
mapfile -t package_entries < <(sed '/^[[:blank:]]*#.*/d;s/#.*//;/^[[:blank:]]*$/d' profile/packages.x86_64)
declare -A package_seen=()
for package in "${package_entries[@]}"; do
    if [[ -n "${package_seen[${package}]+yes}" ]]; then
        bad "duplicate package entry: ${package}"
    fi
    package_seen["${package}"]=1
done
note "  parsed ${#package_entries[@]} unique package entries"
if compgen -G 'packages/*/*.pkg.tar.*' >/dev/null 2>&1; then
    note "  note: ignored prebuilt package archives exist under packages/; build staging removes them before makepkg"
fi

note "=== metadata and wrapper contracts =========================="
for metadata in \
    profile/airootfs/etc/os-release \
    profile/airootfs/etc/calamares/branding/aegis/branding.desc \
    profile/airootfs/etc/systemd/system/aegis-credentials.service \
    profile/airootfs/etc/systemd/system/aegis-firstboot-cleanup.service \
    profile/airootfs/etc/systemd/system/aegis-live-setup.service \
    packages/aegis-meta/PKGBUILD; do
    [[ -f "${metadata}" ]] || { bad "missing metadata file: ${metadata}"; continue; }
    if grep -nF 'aegis-os.example' "${metadata}" >/dev/null 2>&1; then
        bad "placeholder URL remains in ${metadata}"
    fi
done
for token_file in \
    profile/airootfs/etc/os-release \
    profile/airootfs/etc/calamares/branding/aegis/branding.desc; do
    grep -q '__AEGIS_' "${token_file}" \
        || bad "${token_file} has no build-time central metadata token"
done
for wrapper in scripts/setup-wsl.sh scripts/wsl-build-launch.sh scripts/wsl-build-supervisor.sh; do
    [[ -f "${wrapper}" ]] || { bad "missing WSL wrapper: ${wrapper}"; continue; }
    grep -q 'build OWN OS' "${wrapper}" \
        && bad "stale placeholder path remains in ${wrapper}"
done
grep -q 'AEGIS_WSL_REPO' scripts/wsl-build-launch.sh \
    || bad "wsl-build-launch.sh has no configurable WSL repository path"
grep -q 'AEGIS_HOST_REPO' scripts/wsl-build-supervisor.sh \
    || bad "wsl-build-supervisor.sh has no configurable host repository path"

if [[ "${FAIL}" -eq 0 ]]; then
    note "ALL BUILD/CONFIG CHECKS PASSED"
else
    note "BUILD/CONFIG CHECKS FAILED"
fi
exit "${FAIL}"
