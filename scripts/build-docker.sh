#!/usr/bin/env bash
# =============================================================================
#  scripts/build-docker.sh — build the ISO locally via Docker Desktop (Windows)
# =============================================================================
#  Requires Docker Desktop for Windows (with the drive containing this repo
#  shared in Docker Desktop → Settings → Resources → File sharing).
#
#  Runs an Arch container that executes scripts/build-iso.sh. The container is
#  --privileged because mkarchiso needs loop devices and mount.
# =============================================================================

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

step "Aegis OS — Docker build"
validate_config
require_cmd docker

IMAGE="aegis-os-builder:latest"

step "Building the builder image"
export DOCKER_BUILDKIT=1
docker build -t "${IMAGE}" -f "${REPO_ROOT}/docker/Dockerfile" "${REPO_ROOT}"

step "Running the ISO build inside the container"
# Mount the repo at /aegis. Privileged is required for mkarchiso. Pass the
# resolved central build knobs explicitly so a host override is not lost when
# the container sources its own copy of aegis.conf.
DOCKER_TTY=()
if [[ -t 0 && -t 1 ]]; then
    DOCKER_TTY=(-t)
fi
DOCKER_BUILD_ENV=(
    -e "AEGIS_VERSION=${AEGIS_VERSION}"
    -e "AEGIS_URL=${AEGIS_URL}"
    -e "AEGIS_DOCS_URL=${AEGIS_DOCS_URL}"
    -e "AEGIS_SUPPORT_URL=${AEGIS_SUPPORT_URL}"
    -e "AEGIS_RELEASES_URL=${AEGIS_RELEASES_URL}"
    -e "AEGIS_PRIVACY_URL=${AEGIS_PRIVACY_URL}"
    -e "AEGIS_ENABLE_BLACKARCH=${AEGIS_ENABLE_BLACKARCH}"
    -e "AEGIS_ENABLE_CHAOTIC=${AEGIS_ENABLE_CHAOTIC}"
    -e "AEGIS_BLACKARCH_STRAP_URL=${AEGIS_BLACKARCH_STRAP_URL}"
    -e "AEGIS_BLACKARCH_GROUPS=${AEGIS_BLACKARCH_GROUPS}"
    -e "AEGIS_TOOL_SET=${AEGIS_TOOL_SET}"
    -e "AEGIS_PLYMOUTH_THEME=${AEGIS_PLYMOUTH_THEME}"
    -e "AEGIS_NET_RETRIES=${AEGIS_NET_RETRIES}"
)
docker run --rm -i "${DOCKER_TTY[@]}" \
    --privileged \
    -v "${REPO_ROOT}:/aegis" \
    -w /aegis \
    "${DOCKER_BUILD_ENV[@]}" \
    "${IMAGE}" \
    bash scripts/build-iso.sh

ok "Done. ISO is in ${REPO_ROOT}/${AEGIS_OUT_DIR}/"
