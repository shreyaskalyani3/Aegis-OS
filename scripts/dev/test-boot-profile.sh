#!/usr/bin/env bash
# =============================================================================
#  test-boot-profile.sh — shell-only regression check for live kernel options.
#
#  No Arch or archiso installation is required. The fixtures exercise the same
#  three command-line transforms used by build-iso.sh:
#    * BIOS syslinux APPEND lines
#    * GRUB linux lines
#    * UEFI systemd-boot options lines (never the linux kernel path)
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d /tmp/aegis-boot-profile.XXXXXX)"
trap 'rm -rf "${TMP}"' EXIT

mkdir -p "${TMP}/syslinux" "${TMP}/grub" "${TMP}/efiboot/loader/entries"
printf '%s\n' \
    'APPEND archisobasedir=aegis archisolabel=AEGIS_202610' \
    > "${TMP}/syslinux/archiso_sys-linux.cfg"
printf '%s\n' \
    'menuentry "Aegis OS" {' \
    '  linux /aegis/boot/x86_64/vmlinuz-linux archisobasedir=aegis' \
    '}' \
    > "${TMP}/grub/grub.cfg"
printf '%s\n' \
    'title Aegis OS' \
    'linux /aegis/boot/x86_64/vmlinuz-linux' \
    'options archisobasedir=aegis archisosearchuuid=%ARCHISO_UUID%' \
    > "${TMP}/efiboot/loader/entries/01-archiso-linux.conf"

# Keep these expressions in lockstep with scripts/build-iso.sh.
for f in "${TMP}/syslinux/"*.cfg; do
    sed -i -E 's/^([[:space:]]*APPEND[[:space:]]+)/\1quiet splash plymouth.ignore-serial-consoles /' "${f}"
    sed -i -E 's/(quiet splash plymouth\.ignore-serial-consoles[[:space:]]*)+/quiet splash plymouth.ignore-serial-consoles /g' "${f}"
done
for f in "${TMP}/grub/"grub.cfg; do
    sed -i -E 's/^([[:space:]]*linux[[:space:]]+.*)$/\1 quiet splash plymouth.ignore-serial-consoles/' "${f}"
    sed -i -E 's/(quiet splash plymouth\.ignore-serial-consoles[[:space:]]*)+/quiet splash plymouth.ignore-serial-consoles /g' "${f}"
done
for f in "${TMP}/efiboot/loader/entries/"*.conf; do
    sed -i -E 's/^([[:space:]]*options[[:space:]]+.*)$/\1 quiet splash plymouth.ignore-serial-consoles/' "${f}"
    sed -i -E 's/(quiet splash plymouth\.ignore-serial-consoles[[:space:]]*)+/quiet splash plymouth.ignore-serial-consoles /g' "${f}"
done

grep -q '^APPEND quiet splash plymouth.ignore-serial-consoles archisobasedir=aegis archisolabel=AEGIS_202610$' \
    "${TMP}/syslinux/archiso_sys-linux.cfg"
grep -q '^  linux /aegis/boot/x86_64/vmlinuz-linux archisobasedir=aegis quiet splash plymouth.ignore-serial-consoles[[:space:]]*$' \
    "${TMP}/grub/grub.cfg"
grep -q '^linux /aegis/boot/x86_64/vmlinuz-linux$' \
    "${TMP}/efiboot/loader/entries/01-archiso-linux.conf"
grep -q '^options archisobasedir=aegis archisosearchuuid=%ARCHISO_UUID% quiet splash plymouth.ignore-serial-consoles[[:space:]]*$' \
    "${TMP}/efiboot/loader/entries/01-archiso-linux.conf"

grep -q "'bios.syslinux'" "${ROOT}/profile/profiledef.sh"
grep -q "'uefi.systemd-boot'" "${ROOT}/profile/profiledef.sh"
printf '%s\n' 'BOOT-PROFILE-SMOKE-PASS'
