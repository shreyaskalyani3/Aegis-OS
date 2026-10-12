#!/usr/bin/env bash
# =============================================================================
#  Aegis OS — ISO Recombination Script (Linux / macOS)
#  Recombines multi-part ISO downloads (.part00, .part01, ...) into one ISO file.
# =============================================================================
set -euo pipefail

cd "$(dirname "$0")"

PART_FILE=$(ls -1 *.iso.part00 2>/dev/null | head -n1 || true)
if [[ -z "$PART_FILE" ]]; then
    PART_FILE=$(ls -1 *.iso.part* 2>/dev/null | head -n1 || true)
fi

if [[ -z "$PART_FILE" ]]; then
    echo "!! Error: No *.iso.part* files found in this directory." >&2
    exit 1
fi

ISO_NAME="${PART_FILE%.part*}"

echo ":: Recombining parts into ${ISO_NAME}..."
cat "${ISO_NAME}.part"* > "${ISO_NAME}"

echo ":: Recombination complete."
if [[ -f "${ISO_NAME}.sha256" ]]; then
    echo ":: Verifying SHA256 checksum..."
    sha256sum -c "${ISO_NAME}.sha256"
else
    echo ":: (No ${ISO_NAME}.sha256 file found for verification)"
fi

echo ":: Success: ${ISO_NAME} is ready to use!"
