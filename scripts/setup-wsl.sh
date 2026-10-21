#!/usr/bin/env bash
# =============================================================================
#  scripts/setup-wsl.sh — bootstrap an Arch Linux WSL2 environment for building
# =============================================================================
#  Run this from Windows (Git Bash / MSYS) to prepare WSL2 + Arch. It is a
#  convenience wrapper around `wsl.exe`; it does not build the ISO itself.
#  After it completes, follow the printed instructions to run the build.
# =============================================================================

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

step "Aegis OS — WSL2 + Arch setup helper"
validate_config

command -v wsl.exe >/dev/null 2>&1 || die "wsl.exe not found. Enable WSL: run in an ADMIN PowerShell:  wsl --install"

# Convert the actual checkout path to the path visible inside WSL. Git Bash
# provides `pwd -W`; the /f-style fallback also keeps this working in MSYS-like
# shells where wslpath is not installed as a native command.
wsl_repo_path() {
    local windows_repo wsl_repo drive rest
    windows_repo="$(pwd -W 2>/dev/null || true)"
    if [[ -n "${windows_repo}" ]]; then
        wsl_repo="$(wsl.exe wslpath -u "${windows_repo}" 2>/dev/null | tr -d '\r')"
        [[ -n "${wsl_repo}" ]] && { printf '%s' "${wsl_repo}"; return; }
    fi
    if [[ "${REPO_ROOT}" =~ ^/([[:alpha:]])/(.*)$ ]]; then
        drive="${BASH_REMATCH[1],,}"
        rest="${BASH_REMATCH[2]}"
        printf '/mnt/%s/%s' "${drive}" "${rest}"
    else
        printf '%s' "${REPO_ROOT}"
    fi
}
WSL_REPO_ROOT="$(wsl_repo_path)"

log "Ensuring WSL2 is the default version"
wsl.exe --set-default-version 2 || warn "could not set WSL2 default (may already be set)"

DISTRO="${AEGIS_WSL_DISTRO:-archlinux}"
[[ "${DISTRO}" =~ ^[A-Za-z0-9._-]+$ ]] || die "invalid WSL distro name: ${DISTRO}"

if wsl.exe --list --quiet 2>/dev/null | tr -d '\r\0' | grep -qi "^${DISTRO}$"; then
    ok "WSL distro '${DISTRO}' already installed"
else
    log "Installing WSL distro '${DISTRO}' (this opens a new window; set a UNIX user/password if prompted)"
    if ! wsl.exe --install -d "${DISTRO}"; then
        cat <<EOF

${C_YELLOW}Automatic install of '${DISTRO}' failed.${C_RESET}
Arch may not be offered by 'wsl --install' on your Windows build. Install it manually:

  1. List available distros:      wsl --list --online
  2. If 'archlinux' is listed:    wsl --install -d archlinux
  3. Otherwise use ArchWSL:       https://github.com/yuk7/ArchWSL
     - download Arch.zip, extract, run Arch.exe once to register the distro.

Then re-run this script, or continue with the build steps below.
EOF
        die "WSL distro not installed"
    fi
fi

cat <<EOF

${C_GREEN}${C_BOLD}WSL Arch is ready.${C_RESET} Now build the ISO inside it:

  1. Open the Arch shell:            ${C_CYAN}wsl -d ${DISTRO}${C_RESET}
  2. Initialize pacman keys (first time):
        ${C_CYAN}sudo pacman-key --init && sudo pacman-key --populate archlinux${C_RESET}
        ${C_CYAN}sudo pacman -Syu --noconfirm${C_RESET}
  3. Go to this repo (the checkout is visible inside WSL at):
        ${C_CYAN}cd "${WSL_REPO_ROOT}"${C_RESET}
     ${C_YELLOW}NOTE:${C_RESET} building on /mnt (DrvFs) can be slow and may reject some
     permissions. For a reliable build, copy the repo into the Linux filesystem first:
        ${C_CYAN}cp -a "${WSL_REPO_ROOT}" ~/aegis-os && cd ~/aegis-os${C_RESET}
  4. Build:
        ${C_CYAN}sudo bash scripts/build-iso.sh${C_RESET}

The finished ISO will be in ./out/ (copy it back to the Windows checkout if needed).
EOF
