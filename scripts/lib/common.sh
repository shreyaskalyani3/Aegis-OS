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
