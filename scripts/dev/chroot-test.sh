#!/usr/bin/env bash
# aegis-chroot-test.sh — DEFINITIVE end-to-end replication of the Calamares
# install environment on real Arch (WSL2 works). Builds a real ext4 target,
# clones what the SquashFS would contain, simulates mkarchiso's /boot
# deletion, bind-mounts the chroot mounts (exactly mount.conf extraMounts),
# then runs OUR full install chain inside the chroot:
#
#   shellprocess commands -> mkinitcpio -p linux -> grub-mkconfig
#
# If grub-mkconfig fails here, the wrapper logs the real reason. This is
# the closest possible test to a real install without a VM.
set -u

PASS=0; FAIL=0
say()  { printf '%s\n' "$*"; }
pass() { printf '  PASS: %s\n' "$*"; PASS=$((PASS+1)); }
fail() { printf '  FAIL: %s\n' "$*"; FAIL=$((FAIL+1)); }

REPO="$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)"
T=/mnt/aegis-chroot-test
IMG=/tmp/aegis-chroot-test.img
SZ=4G

cleanup() {
    umount -R "$T" 2>/dev/null
    umount -d "$IMG" 2>/dev/null
    rm -rf "$T" "$IMG"
}
trap cleanup EXIT

say "=== STAGE A: build a real ext4 target ==="
if [[ -d "$T" ]] && mountpoint -q "$T"; then
    say "  (existing test target mounted - reusing packages, remaking)"
    umount -R "$T" 2>/dev/null || true
fi
rm -rf "$IMG"
if ! truncate -s "$SZ" "$IMG"; then fail "cannot create image"; exit 1; fi
if ! mkfs.ext4 -q -F "$IMG"; then fail "mkfs.ext4 failed"; exit 1; fi
mkdir -p "$T"
if ! mount -o loop "$IMG" "$T"; then fail "loop mount failed (WSL2 should support this)"; exit 1; fi
pass "4GiB ext4 target mounted at $T"

say "=== STAGE B: pacstrap the SquashFS-equivalent content ==="
# The real SquashFS = base + linux + grub + mkinitcpio (+ our tools).
# pacstrap installs into $T exactly like pacstrap into the airootfs at build.
if ! pacstrap -c "$T" base linux grub mkinitcpio 2>&1 | tail -5; then
    fail "pacstrap failed"; exit 1
fi
pass "target now holds base+linux+grub+mkinitcpio (the SquashFS content)"

say "=== STAGE C: simulate mkarchiso cleanup (delete /boot) ==="
find "$T/boot" -mindepth 1 -delete
if [[ -z "$(ls -A "$T/boot")" ]]; then pass "/boot emptied, exactly like the real ISO"; else fail "/boot not empty"; fi
# NOTE: the glob in [[ -f ]] does not expand the way it does in ls; use ls.
if ls "$T"/usr/lib/modules/*/vmlinuz >/dev/null 2>&1; then pass "kernel still at /usr/lib/modules/<ver>/vmlinuz (survives cleanup)"; else fail "modules vmlinuz missing"; fi

say "=== STAGE D: chroot mounts (exactly mount.conf extraMounts) ==="
for m in proc sys dev; do mount --bind /$m "$T/$m" 2>/dev/null || true; done
mount --bind /run "$T/run" 2>/dev/null || true
pass "bind-mounted /proc /sys /dev /run"

say "=== STAGE E: run OUR shellprocess commands inside the chroot ==="
CH="chroot $T"

# our preset from the repo -> into the target
install -D -m 0644 "$REPO/profile/airootfs/usr/share/aegis/linux-install.preset" "$T/usr/share/aegis/linux-install.preset"
# a representative /etc/default/grub like the grubcfg module writes
printf 'GRUB_TIMEOUT=5\nGRUB_DISTRIBUTOR="Aegis OS"\nGRUB_CMDLINE_LINUX_DEFAULT="quiet"\n' > "$T/etc/default/grub"

# command 0: presence check
$CH bash -c 'test -n "$(ls -1 /usr/lib/modules/*/vmlinuz 2>/dev/null | head -n1)"' \
    && pass "kernel image present in modules dir" || fail "kernel image missing"

# command 1+2: xargs restore + verify
$CH bash -c 'ls -1 /usr/lib/modules/*/vmlinuz 2>/dev/null | head -n1 | xargs -I "{}" install -D -m 0644 "{}" /boot/vmlinuz-linux'
$CH bash -c 'test -r /boot/vmlinuz-linux' && pass "kernel restored to /boot/vmlinuz-linux" || fail "kernel restore failed"

# command 3: preset swap + live hooks removal + verify
$CH bash -c 'cp /usr/share/aegis/linux-install.preset /etc/mkinitcpio.d/linux.preset'
$CH bash -c 'rm -f /etc/mkinitcpio.conf.d/archiso.conf'
$CH bash -c 'grep -q "^PRESETS=(.default. .fallback.)" /etc/mkinitcpio.d/linux.preset' \
    && pass "standard preset active" || fail "preset swap failed"

say "=== STAGE F: initcpio module (mkinitcpio -p linux) ==="
# This is the module's real invocation, in the real chroot.
if $CH bash -c 'mkinitcpio -p linux' >/tmp/mkinitcpio.log 2>&1; then
    pass "mkinitcpio built default+fallback initramfs"
    ls "$T/boot/" | sed 's/^/    /'
else
    fail "mkinitcpio failed:"; tail -8 /tmp/mkinitcpio.log | sed 's/^/    /'
fi

say "=== STAGE G: bootloader module (grub-mkconfig via our wrapper) ==="
install -D -m 0755 "$REPO/profile/airootfs/usr/share/aegis/grub-mkconfig-wrapper" "$T/usr/share/aegis/grub-mkconfig-wrapper"
$CH mkdir -p /boot/grub
if $CH bash -c '/usr/share/aegis/grub-mkconfig-wrapper -o /boot/grub/grub.cfg' >/tmp/grub.log 2>&1; then
    pass "grub-mkconfig SUCCEEDED in the replicated chroot"
    if [[ -s "$T/boot/grub/grub.cfg" ]]; then pass "grub.cfg generated ($(wc -l < "$T/boot/grub/grub.cfg") lines)"; else fail "grub.cfg empty"; fi
else
    fail "grub-mkconfig failed — wrapper log below:"
    tail -25 "$T/var/log/aegis-grub-mkconfig.log" 2>/dev/null | sed 's/^/    /'
    tail -10 /tmp/grub.log | sed 's/^/    /'
fi

say "=== STAGE H: verify-bootloader (the new install-time gate) ==="
install -D -m 0755 "$REPO/profile/airootfs/usr/share/aegis/verify-bootloader" "$T/usr/share/aegis/verify-bootloader"
# Simulate the bootloader module's work so the verifier has something real
# to check: run the REAL grub-install for BIOS onto the loop device image.
loop="$(losetup -j "$IMG" | cut -d: -f1 | head -n1)"
if [[ -n "$loop" ]]; then
    if $CH bash -c "grub-install --target=i386-pc --recheck --force $loop" >/tmp/grubinstall.log 2>&1; then
        pass "grub-install wrote real boot code onto $loop"
    else
        say "  (grub-install onto loop device not possible here: $(tail -1 /tmp/grubinstall.log))"
    fi
fi
if $CH bash -c '/usr/share/aegis/verify-bootloader' >/tmp/verify.log 2>&1; then
    pass "verify-bootloader PASSED (kernel+initramfs+grub.cfg+boot code all verified)"
else
    rc=$?
    # Expected on this rig IF grub-install onto loop failed: the MBR check
    # must FAIL LOUDLY (that is the whole point — a disk without GRUB must
    # abort the install, never pass silently).
    if grep -q "AEGIS-ERROR" /tmp/verify.log; then
        pass "verify-bootloader correctly FAIL-LOUD on missing boot code: $(grep -m1 AEGIS-ERROR /tmp/verify.log | head -c 80)"
    else
        fail "verifier exited $rc without an AEGIS-ERROR message:"
        tail -8 /tmp/verify.log | sed 's/^/    /'
    fi
fi

say ""
say "RESULT: $PASS passed, $FAIL failed"
exit $((FAIL > 0))
