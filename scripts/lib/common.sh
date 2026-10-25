#!/usr/bin/env bash
# =============================================================================
#  scripts/lib/common.sh — shared helpers for Aegis OS build scripts
# =============================================================================
# shellcheck disable=SC2034  # (some vars are consumed by sourcing scripts)

set -euo pipefail

# --- Locate repo root & load central config ----------------------------------
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${_LIB_DIR}/../.." && pwd)"

# shellcheck source=/dev/null
source "${REPO_ROOT}/aegis.conf"

# --- Pretty logging -----------------------------------------------------------
if [[ -t 1 ]]; then
    C_RESET=$'\e[0m'; C_BOLD=$'\e[1m'; C_BLUE=$'\e[34m'
    C_GREEN=$'\e[32m'; C_YELLOW=$'\e[33m'; C_RED=$'\e[31m'; C_CYAN=$'\e[36m'
else
    C_RESET=''; C_BOLD=''; C_BLUE=''; C_GREEN=''; C_YELLOW=''; C_RED=''; C_CYAN=''
fi

log()   { printf '%s\n' "${C_BLUE}${C_BOLD}::${C_RESET}${C_BOLD} $*${C_RESET}"; }
ok()    { printf '%s\n' "${C_GREEN}  ✓ $*${C_RESET}"; }
warn()  { printf '%s\n' "${C_YELLOW}  ! $*${C_RESET}" >&2; }
die()   { printf '%s\n' "${C_RED}${C_BOLD}✗ $*${C_RESET}" >&2; exit 1; }
step()  { printf '\n%s\n' "${C_CYAN}${C_BOLD}==> $*${C_RESET}"; }

# --- Guards -------------------------------------------------------------------
require_cmd() { command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"; }
require_root() { [[ "${EUID:-$(id -u)}" -eq 0 ]] || die "this must run as root (use sudo)"; }
is_arch() { [[ -f /etc/arch-release ]]; }

# Validate configuration before a build starts downloading packages or mutating
# the host's pacman state. Keep this here so native, Docker, and CI entrypoints
# use exactly the same rules.
validate_config() {
    local resolved_version url_name url group path_value
    local -a groups=()

    [[ "${AEGIS_ENABLE_BLACKARCH}" =~ ^[01]$ ]] \
        || die "AEGIS_ENABLE_BLACKARCH must be 0 or 1 (got '${AEGIS_ENABLE_BLACKARCH}')"
    [[ "${AEGIS_ENABLE_CHAOTIC}" =~ ^[01]$ ]] \
        || die "AEGIS_ENABLE_CHAOTIC must be 0 or 1 (got '${AEGIS_ENABLE_CHAOTIC}')"
    [[ "${AEGIS_TOOL_SET}" =~ ^(lean|broad|full)$ ]] \
        || die "AEGIS_TOOL_SET must be lean, broad, or full (got '${AEGIS_TOOL_SET}')"
    [[ "${AEGIS_NET_RETRIES}" =~ ^[1-9][0-9]*$ ]] \
        || die "AEGIS_NET_RETRIES must be a positive integer (got '${AEGIS_NET_RETRIES}')"
    [[ "${AEGIS_PLYMOUTH_THEME}" =~ ^(aegis|hitech-arch-animation)$ ]] \
        || die "AEGIS_PLYMOUTH_THEME must be aegis or hitech-arch-animation (got '${AEGIS_PLYMOUTH_THEME}')"
    [[ "${AEGIS_DESKTOP}" == "hyprland" ]] \
        || die "AEGIS_DESKTOP is '${AEGIS_DESKTOP}', but this profile supports only hyprland"

    [[ "${AEGIS_LIVE_USER}" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] \
        || die "AEGIS_LIVE_USER is not a valid Linux account name: '${AEGIS_LIVE_USER}'"
    [[ "${AEGIS_HOSTNAME}" =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,62}$ ]] \
        || die "AEGIS_HOSTNAME is not a valid single-label hostname: '${AEGIS_HOSTNAME}'"
    [[ -n "${AEGIS_LIVE_PASSWORD}" && -n "${AEGIS_ROOT_PASSWORD}" ]] \
        || die "AEGIS_LIVE_PASSWORD and AEGIS_ROOT_PASSWORD must not be empty"
    [[ "${AEGIS_LIVE_PASSWORD}" != *$'\n'* && "${AEGIS_LIVE_PASSWORD}" != *$'\r'* \
        && "${AEGIS_ROOT_PASSWORD}" != *$'\n'* && "${AEGIS_ROOT_PASSWORD}" != *$'\r'* ]] \
        || die "live/root passwords cannot contain newline characters"
    [[ "${AEGIS_DEFAULT_SHELL}" == /* && "${AEGIS_DEFAULT_SHELL}" != *[[:space:]]* ]] \
        || die "AEGIS_DEFAULT_SHELL must be an absolute path without whitespace"
    [[ "${AEGIS_TIMEZONE}" =~ ^[A-Za-z0-9._+-]+(/[A-Za-z0-9._+-]+)*$ ]] \
        || die "AEGIS_TIMEZONE is not a safe zoneinfo path: '${AEGIS_TIMEZONE}'"
    [[ "${AEGIS_LOCALE}" =~ ^[A-Za-z0-9_.@+-]+$ ]] \
        || die "AEGIS_LOCALE is not a safe locale name: '${AEGIS_LOCALE}'"
    [[ "${AEGIS_KEYMAP}" =~ ^[A-Za-z0-9_.+-]+$ ]] \
        || die "AEGIS_KEYMAP is not a safe keymap name: '${AEGIS_KEYMAP}'"

    resolved_version="$(resolve_version)"
    [[ "${resolved_version}" =~ ^[0-9]+([.][0-9]+)*$ ]] \
        || die "resolved Aegis version must contain only numeric dot-separated components: '${resolved_version}'"
    [[ "${AEGIS_LOCAL_REPO_NAME}" =~ ^[A-Za-z0-9][A-Za-z0-9_.+-]*$ ]] \
        || die "AEGIS_LOCAL_REPO_NAME is not a safe pacman repository name: '${AEGIS_LOCAL_REPO_NAME}'"

    for url_name in AEGIS_URL AEGIS_DOCS_URL AEGIS_SUPPORT_URL AEGIS_RELEASES_URL AEGIS_PRIVACY_URL AEGIS_BLACKARCH_STRAP_URL; do
        url="${!url_name}"
        [[ "${url}" =~ ^https://[^[:space:]\|\&\\]+$ ]] \
            || die "${url_name} must be an https URL without shell/sed metacharacters (got '${url}')"
    done

    if [[ "${AEGIS_TOOL_SET}" == "broad" && "${AEGIS_ENABLE_BLACKARCH}" -eq 1 ]]; then
        read -r -a groups <<< "${AEGIS_BLACKARCH_GROUPS}"
        ((${#groups[@]} > 0)) || die "AEGIS_BLACKARCH_GROUPS must not be empty for a broad BlackArch build"
        for group in "${groups[@]}"; do
            [[ "${group}" =~ ^[a-z0-9][a-z0-9_.+-]*$ ]] \
                || die "invalid BlackArch group name '${group}' in AEGIS_BLACKARCH_GROUPS"
        done
    fi

    for path_value in "${AEGIS_PROFILE_DIR}" "${AEGIS_PACKAGES_DIR}" "${AEGIS_OUT_DIR}" "${AEGIS_WORK_DIR}" "${AEGIS_REPO_OUT}"; do
        [[ "${path_value}" != /* && "${path_value}" != *..* ]] \
            || die "build layout paths must be relative and cannot contain '..' (got '${path_value}')"
    done
}

# --- Network retries ----------------------------------------------------------
# Field failures were all one-shot network calls that died on a transient blip
# (the deps install, the BlackArch sync, the kernel pre-download) — a retry
# window turns most of those into a successful build. Die with a clear remedy
# only when every attempt fails.
retry() {
    local tries="${AEGIS_NET_RETRIES:-5}" wait_secs=10 i=0
    local label="$1"; shift
    until "$@"; do
        i=$((i + 1))
        if [[ "${i}" -ge "${tries}" ]]; then
            die "${label}: failed after ${tries} attempts (network?) — rerun the build on a working connection"
        fi
        warn "${label}: attempt ${i}/${tries} failed — retrying in ${wait_secs}s"
        sleep "${wait_secs}"
    done
}

# --- Resolved values ----------------------------------------------------------
resolve_version() {
    if [[ -n "${AEGIS_VERSION}" ]]; then
        printf '%s' "${AEGIS_VERSION}"
    elif [[ -f "${REPO_ROOT}/VERSION" ]]; then
        tr -d '[:space:]' < "${REPO_ROOT}/VERSION"
    else
        date +%Y.%m.%d
    fi
}

export REPO_ROOT
