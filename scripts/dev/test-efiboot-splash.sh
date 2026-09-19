#!/usr/bin/env bash
# =============================================================================
#  test-efiboot-splash.sh — regression test for the UEFI splash injection.
#
#  The UEFI live menu (systemd-boot) passes its `options` lines to the kernel
#  verbatim; without `splash` on those lines plymouth never engages on a UEFI
#  boot. Applies the same sed expressions build-iso.sh uses to a copy of the
#  releng efiboot entries and asserts the result. Run inside WSL/archlinux.
# =============================================================================
set -e

ENTRIES_SRC=/usr/share/archiso/configs/releng/efiboot/loader/entries
[[ -d "${ENTRIES_SRC}" ]] || { echo "SKIP: releng efiboot not found (is archiso installed?)"; exit 0; }

rm -rf /tmp/efiboot-test && cp -a "${ENTRIES_SRC}" /tmp/efiboot-test
for f in /tmp/efiboot-test/0*.conf; do
    sed -i 's/^APPEND /APPEND quiet splash plymouth.ignore-serial-consoles /;
            s/^\([[:space:]]*linux[[:space:]].*\)$/& quiet splash plymouth.ignore-serial-consoles/;
            s/^\([[:space:]]*options[[:space:]].*\)$/& quiet splash plymouth.ignore-serial-consoles/' "${f}"
done

echo "=== 01-archiso (UEFI live entry) ==="
cat /tmp/efiboot-test/01-archiso-linux.conf
echo "=== 03-memtest (no options line — must be untouched) ==="
cat /tmp/efiboot-test/03-archiso-memtest86+x64.conf

grep -q 'archisosearchuuid=%ARCHISO_UUID% quiet splash plymouth.ignore-serial-consoles$' \
    /tmp/efiboot-test/01-archiso-linux.conf \
    || { echo "FAIL: 01 options line missing splash params"; exit 1; }
if grep -q 'splash' /tmp/efiboot-test/03-archiso-memtest86+x64.conf; then
    echo "FAIL: memtest entry was touched (it has no options line)"; exit 1
fi
echo "EFIBOOT-SPLASH-TEST-PASS"
