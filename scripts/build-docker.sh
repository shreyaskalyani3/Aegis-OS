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
require_cmd docker

IMAGE="aegis-os-builder:latest"

step "Building the builder image"
docker build -t "${IMAGE}" -f "${REPO_ROOT}/docker/Dockerfile" "${REPO_ROOT}"

step "Running the ISO build inside the container"
# Mount the repo at /aegis. Privileged is required for mkarchiso.
docker run --rm -it \
    --privileged \
    -v "${REPO_ROOT}:/aegis" \
    -w /aegis \
    -e AEGIS_VERSION="${AEGIS_VERSION:-}" \
    -e AEGIS_TOOL_SET="${AEGIS_TOOL_SET:-}" \
    "${IMAGE}" \
    bash scripts/build-iso.sh

ok "Done. ISO is in ${REPO_ROOT}/${AEGIS_OUT_DIR}/"
