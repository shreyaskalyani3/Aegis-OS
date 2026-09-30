#!/usr/bin/env bash
# =============================================================================
#  test-crlf-normalize.sh — regression test for build-iso.sh's CRLF staging fix.
#
#  A working tree with CRLF (Windows edits / copied checkouts) breaks
#  mkarchiso's exact-match package validation and the live system's scripts.
#  Poison a staged profile with CRLF, run build-iso.sh's normalize pattern,
#  and verify: text files are CRLF-free, mkarchiso's parse + membership check
#  passes, and binary theme files survive byte-identical. Run in WSL as root.
# =============================================================================
set -e

STAGE=/root/aegis-crlf-stage
mkdir -p "$STAGE"
rm -rf "$STAGE/profile"
cp -a /root/AegisOS/profile "$STAGE/profile"

# --- poison: CRLF every file a Windows tool would produce ---------------------
find "$STAGE/profile" -type f -exec sed -i 's/$/\r/' {} +
echo "poisoned: $(grep -rIl $'\r$' "$STAGE/profile" | wc -l) files with CRLF"

# snapshot the poisoned binaries — the normalize must leave them untouched
# (the poison itself mangles PNGs; that is expected, not what is tested)
find "$STAGE/profile" -name '*.png' -exec sha256sum {} + > "$STAGE/png-before.txt"

# --- the normalize pattern from build-iso.sh ----------------------------------
grep -rIl $'\r$' "$STAGE/profile" 2>/dev/null | while read -r f; do
    sed -i 's/\r$//' "$f"
done

leftover=$(grep -rIl $'\r$' "$STAGE/profile" 2>/dev/null | wc -l)
echo "after normalize: ${leftover} files with CRLF"
[[ "$leftover" -eq 0 ]] || { echo "FAIL: CRLF survived the normalize"; exit 1; }

# --- mkarchiso's exact parse + membership check now passes --------------------
cd "$STAGE/profile"
mapfile -t pkgs < <(sed '/^[[:blank:]]*#.*/d;s/#.*//;/^[[:blank:]]*$/d' packages.x86_64)
for want in syslinux memtest86+ edk2-shell memtest86+-efi grub; do
    [[ " ${pkgs[*]} " =~ " $want " ]] || { echo "FAIL: $want not in the parsed list"; exit 1; }
done
echo "mkarchiso membership check: all boot packages present"

# --- binaries untouched by the normalize (vs the post-poison snapshot) --------
find "$STAGE/profile" -name '*.png' -exec sha256sum {} + > "$STAGE/png-after.txt"
diff -q "$STAGE/png-before.txt" "$STAGE/png-after.txt" >/dev/null \
    || { echo "FAIL: the normalize touched binary files"; exit 1; }
echo "theme binaries: untouched by the normalize"

rm -rf "$STAGE"
echo "CRLF-NORMALIZE-TEST-PASS"
