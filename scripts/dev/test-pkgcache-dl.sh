#!/usr/bin/env bash
# =============================================================================
#  test-pkgcache-dl.sh — regression test for the offline kernel cache download.
#
#  Since pacman 6.1, downloads run as an unprivileged user (DownloadUser,
#  default alpm). That user must be able to TRAVERSE the cache path — it
#  cannot when the cache sits under a mode-0700 path (/root/...), which is
#  the field failure:
#    error: could not open file .../download-XXXX/<pkg>.part: Permission denied
#    error: failed to setup a download payload for <pkg>
#
#  Verifies the patched pattern used by build-iso.sh (download to a /tmp dir
#  open to everyone, then copy the finished packages in as root) works under
#  exactly those conditions. Run inside WSL as root.
# =============================================================================
set -e

echo "=== 0. pacman download-user config (diagnostic) ==="
grep -i 'downloaduser' /etc/pacman.conf || echo "  (no DownloadUser line — default applies)"
id alpm 2>/dev/null || echo "  (no alpm user)"

echo ""
echo "=== 1. unpatched pattern (root-owned cache under /root) ==="
set +e
mkdir -p /root/aegis-dltest/cache
pacman -Sw --noconfirm --cachedir /root/aegis-dltest/cache linux >/tmp/pkgtest-dl.log 2>&1
rc=$?
set -e
if [[ $rc -eq 0 ]]; then
    echo "  ! unpatched pattern unexpectedly passed — downloads are running as root here"
else
    grep -E 'error:|failed' /tmp/pkgtest-dl.log | head -3
    echo "  unpatched pattern failed as expected (rc=$rc)"
fi

echo ""
echo "=== 2. patched pattern (download to /tmp, copy in as root) ==="
dl_tmp="$(mktemp -d /tmp/aegis-kerneldl.XXXXXX)"
chmod 0777 "$dl_tmp"
pacman -Sw --noconfirm --cachedir "$dl_tmp" linux intel-ucode amd-ucode grub
cp -a "$dl_tmp"/. /root/aegis-dltest/cache/
rm -rf "$dl_tmp"
for must in linux intel-ucode amd-ucode grub; do
    ls /root/aegis-dltest/cache/${must}-*.pkg.tar.zst >/dev/null 2>&1 \
        || { echo "  package '${must}' missing from the cache"; exit 1; }
done
echo "  cache: $(ls /root/aegis-dltest/cache | tr '\n' ' ')"
rm -rf /root/aegis-dltest
echo "PKGCACHE-DL-TEST-PASS"
