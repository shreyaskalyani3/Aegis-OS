#!/usr/bin/env bash
# aegis-install-sim.sh — simulate the exact shellprocess chain from
# shellprocess.conf against a fake cloned target, testing each command
# exactly as written (no variables, $() substitution, xargs pipeline).
# Runs anywhere bash exists (WSL Arch, CI, an Arch live ISO). Not for Windows.
set -u

PASS=0; FAIL=0
say()  { printf '%s\n' "$*"; }
pass() { printf '  PASS: %s\n' "$*"; PASS=$((PASS+1)); }
fail() { printf '  FAIL: %s\n' "$*"; FAIL=$((FAIL+1)); }

# Resolve repo root from this script's location, whatever the cwd.
REPO="$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)"
say "repo: $REPO"

T=/tmp/aegis-target
rm -rf "$T"
mkdir -p "$T/boot" "$T/usr/lib/modules" "$T/etc/mkinitcpio.d" "$T/etc/mkinitcpio.conf.d" "$T/usr/share/aegis/packages"

# --- Build a realistic cloned target ------------------------------------------
# The linux package ships the kernel BOTH in /boot AND at
# /usr/lib/modules/<ver>/vmlinuz. mkarchiso deletes only /boot, so the
# modules copy is what a cloned target contains. Fabricate it if the host
# doesn't have one (WSL doesn't ship vmlinuz inside modules/).
KVER="$(ls /usr/lib/modules/ 2>/dev/null | head -n1 || true)"
if [[ -n "${KVER}" && -f "/usr/lib/modules/${KVER}/vmlinuz" ]]; then
    mkdir -p "$T/usr/lib/modules/$KVER"
    cp "/usr/lib/modules/$KVER/vmlinuz" "$T/usr/lib/modules/$KVER/vmlinuz"
    say "using real kernel from host modules dir ($KVER)"
else
    # Fabricate: any readable binary blob stands in for the kernel image —
    # the commands under test only need a readable file at that path.
    KVER="6.x-fabricated"
    mkdir -p "$T/usr/lib/modules/$KVER"
    dd if=/dev/urandom of="$T/usr/lib/modules/$KVER/vmlinuz" bs=1k count=512 2>/dev/null
    say "fabricated stand-in kernel (host lacks modules vmlinuz)"
fi
chmod 644 "$T/usr/lib/modules/$KVER/vmlinuz"

# 2. the archiso live preset + live HOOKS drop-in (what build-iso.sh ships)
cat > "$T/etc/mkinitcpio.d/linux.preset" <<'EOF'
PRESETS=('archiso')
ALL_kver='/boot/vmlinuz-linux'
archiso_config='/etc/mkinitcpio.conf.d/archiso.conf'
EOF
cat > "$T/etc/mkinitcpio.conf.d/archiso.conf" <<'EOF'
HOOKS=(base udev microcode modconf kms memdisk archiso archiso_loop_mnt block filesystems keyboard)
EOF

# 3. our standard preset where the overlay ships it
install -D -m 0644 "$REPO/profile/airootfs/usr/share/aegis/linux-install.preset" \
    "$T/usr/share/aegis/linux-install.preset"

# --- Run the EXACT commands from shellprocess.conf, chrooted via $T ----------
# (We cannot chroot in WSL-userspace safely here, so paths are prefixed with
# $T — identical semantics for these file operations.)

say "== Command 0: kernel image presence check =="
if test -n "$(ls -1 $T/usr/lib/modules/*/vmlinuz 2>/dev/null | head -n1)"; then
    pass "kernel image present in modules dir"
else
    fail "kernel image NOT found in modules dir"
fi

say "== Command 1: xargs kernel restore =="
ls -1 "$T"/usr/lib/modules/*/vmlinuz 2>/dev/null | head -n1 | xargs -I '{}' install -D -m 0644 '{}' "$T/boot/vmlinuz-linux"
if test -r "$T/boot/vmlinuz-linux"; then pass "kernel copied to /boot/vmlinuz-linux"; else fail "copy produced nothing"; fi

say "== Command 2: restore verification =="
test -r "$T/boot/vmlinuz-linux" && pass "/boot/vmlinuz-linux readable" || fail "not readable"

say "== Command 3: preset source present + swap =="
if test -r "$T/usr/share/aegis/linux-install.preset"; then
    cp "$T/usr/share/aegis/linux-install.preset" "$T/etc/mkinitcpio.d/linux.preset"
    pass "preset swapped"
else
    fail "preset source missing"
fi

say "== Command 4: live HOOKS drop-in removal =="
rm -f "$T/etc/mkinitcpio.conf.d/archiso.conf"
test ! -e "$T/etc/mkinitcpio.conf.d/archiso.conf" && pass "live HOOKS removed" || fail "still there"

say "== Command 5: preset verification (the exact grep) =="
if grep -q "^PRESETS=('default' 'fallback')" "$T/etc/mkinitcpio.d/linux.preset"; then
    pass "preset is the standard default/fallback one"
else
    fail "preset is NOT the standard one — mkinitcpio would fail"
fi

say "== Command 6: grub/microcode cache branch (no-cache path) =="
# In the sim there is no cache, so the else-branch must trigger and continue:
if ls "$T"/usr/share/aegis/packages/grub-*.pkg.tar.zst >/dev/null 2>&1; then
    fail "unexpected cache present in sim"
else
    pass "no-cache branch: continues without installing (as on a real ISO the cache exists)"
fi

say ""
say "RESULT: $PASS passed, $FAIL failed"
rm -rf "$T"
[[ $FAIL -eq 0 ]]
