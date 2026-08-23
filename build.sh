#!/usr/bin/env bash
# =============================================================================
#  build.sh — top-level Aegis OS build dispatcher
# =============================================================================
#  Detects the best available build method and runs it:
#    - already on Arch Linux (root) -> native build-iso.sh
#    - Docker available             -> containerized build
#    - WSL available                -> point user at setup-wsl.sh
#    - otherwise                    -> recommend GitHub Actions
#
#  Force a method:   ./build.sh [auto|native|docker|wsl]
# =============================================================================

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/lib/common.sh"

METHOD="${1:-auto}"

banner() {
cat <<'EOF'
   _____                  _        ____   _____
  / ____|     /\         (_)      / __ \ / ____|
 | |  __     /  \    ___  _  ___ | |  | | (___
 | | |_ |   / /\ \  / _ \| |/ __|| |  | |\___ \
 | |__| |  / ____ \|  __/| |\__ \| |__| |____) |
  \_____| /_/    \_\\___||_||___/ \____/|_____/
        Arch-based · Security · Agent-native
EOF
}
banner

case "${METHOD}" in
    native)
        exec bash "${REPO_ROOT}/scripts/build-iso.sh"
        ;;
    docker)
        exec bash "${REPO_ROOT}/scripts/build-docker.sh"
        ;;
    wsl)
        exec bash "${REPO_ROOT}/scripts/setup-wsl.sh"
        ;;
    auto)
        if is_arch && [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
            log "Detected Arch Linux as root → native build"
            exec bash "${REPO_ROOT}/scripts/build-iso.sh"
        elif is_arch; then
            die "On Arch but not root. Re-run: sudo bash scripts/build-iso.sh"
        elif command -v docker >/dev/null 2>&1; then
            log "Detected Docker → containerized build"
            exec bash "${REPO_ROOT}/scripts/build-docker.sh"
        elif command -v wsl.exe >/dev/null 2>&1; then
            warn "No Arch/Docker, but WSL is present."
            echo "Run:  bash scripts/setup-wsl.sh   (then build inside WSL)"
            exit 1
        else
            cat <<EOF

${C_YELLOW}No local Linux build environment detected.${C_RESET}

Recommended: build in the cloud with GitHub Actions (no local setup):
  1. Push this repo to GitHub.
  2. Actions tab → run "Build Aegis OS ISO", or push a tag: git tag v$(resolve_version) && git push --tags
  3. Download the ISO from the workflow Artifacts / Release.

Or install Docker Desktop, then: bash scripts/build-docker.sh
See docs/BUILDING.md for all options.
EOF
            exit 1
        fi
        ;;
    *)
        die "unknown method '${METHOD}' (use: auto|native|docker|wsl)"
        ;;
esac
