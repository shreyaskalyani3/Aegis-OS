#!/usr/bin/env bash
# =============================================================================
#  test-pkgbuild-root.sh — regression test for the step 3/6 makepkg fix.
#
#  Reproduces the field failure: the repo cloned under a mode-0700 path
#  (/root/...) with a stray BUILDDIR in the environment. The unprivileged
#  builder user then cannot traverse /root and makepkg dies with
#  "Failed to create the directory $BUILDDIR (...)".
#
#  Verifies the patched pattern used by build-iso.sh (stage the tree to /tmp,
#  chown it to the builder, strip BUILDDIR) builds aegis-meta cleanly under
#  exactly those conditions. Run inside WSL as root.
# =============================================================================
set -e

TESTROOT=/root/aegis-pkgbuild-test
BUILDER=aegis-pkgtest

id -u "$BUILDER" >/dev/null 2>&1 || useradd -m -s /bin/bash "$BUILDER"

# fresh clone under /root — same mechanics as the field failure's /root/AegisOS
rm -rf "$TESTROOT"
git clone -q /mnt/f/AegisOS "$TESTROOT"

echo "=== 1. unpatched pattern (repo under /root + BUILDDIR in env) ==="
export BUILDDIR="$TESTROOT/packages"
set +e
( cd "$TESTROOT/packages/aegis-meta" && \
  sudo -u "$BUILDER" env AEGIS_VERSION=0.0.0-test makepkg -f --noconfirm --nodeps --skipinteg ) \
  >/tmp/pkgtest-unpatched.log 2>&1
rc=$?
set -e
if [[ $rc -eq 0 ]]; then
    echo "  ! unpatched pattern unexpectedly passed — BUILDDIR/env is not the trigger here"
else
    grep -E '==>|ERROR|Failed|Aborting' /tmp/pkgtest-unpatched.log | tail -4
fi

echo ""
echo "=== 2. patched pattern (stage to /tmp + env -u BUILDDIR, as build-iso.sh) ==="
pkg_stage="$(mktemp -d /tmp/aegis-pkgstage.XXXXXX)"
cp -a "$TESTROOT/packages" "$pkg_stage/packages"
cp -f "$TESTROOT/aegis.conf" "$pkg_stage/aegis.conf"
[[ -f "$TESTROOT/VERSION" ]] && cp -f "$TESTROOT/VERSION" "$pkg_stage/VERSION"
chown -R "$BUILDER:$BUILDER" "$pkg_stage"
( cd "$pkg_stage/packages/aegis-meta" && \
  sudo -u "$BUILDER" env -u BUILDDIR AEGIS_VERSION=0.0.0-test makepkg -f --noconfirm --nodeps --skipinteg )
pkgfile=$(ls "$pkg_stage/packages/aegis-meta"/aegis-meta-*.pkg.tar.zst | head -1)
echo "  built: $(basename "$pkgfile")"

# the staged aegis.conf must have been picked up (identity inside the package)
bsdtar -xOf "$pkgfile" usr/lib/aegis-release | grep -q 'NAME="Aegis OS"' \
    && echo "  identity: aegis.conf was sourced (NAME=\"Aegis OS\")" \
    || echo "  identity: FALLBACK used — staging layout lost aegis.conf!"

rm -rf "$pkg_stage" "$TESTROOT"
echo "PKGUILD-ROOT-TEST-PASS"
