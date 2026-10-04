#!/usr/bin/env bash
# =============================================================================
#  scripts/wsl-build-launch.sh — start the ISO build as a systemd unit (WSL)
# =============================================================================
#  Idempotent: exits 0 without side effects if a build is already running.
#  Called from scripts/wsl-build-guard.ps1 or by hand:
#    MSYS_NO_PATHCONV=1 wsl -u root bash /mnt/f/AegisOS/scripts/wsl-build-launch.sh
#  The build then lives under systemd (aegis-build.service), writing to
#  /root/AegisOS/build.log, and survives Claude Code exiting. It does NOT
#  survive the WSL VM going down (WSL2 tears the whole VM down ~60s after the
#  last Windows-side wsl.exe client exits) — that is what the guard is for.
set -euo pipefail

REPO=/root/AegisOS
# Check BEFORE cd: with set -e a missing dir would otherwise die at cd with a
# bare bash error instead of this actionable message.
[[ -d "${REPO}" ]] || { echo "FATAL: ${REPO} missing — clone the repo into WSL first (git clone /mnt/f/AegisOS /root/AegisOS)"; exit 1; }
cd "${REPO}"

[[ -f scripts/build-iso.sh ]] || { echo "FATAL: ${REPO}/scripts/build-iso.sh missing"; exit 1; }
command -v systemd-run >/dev/null 2>&1 \
    || { echo "FATAL: systemd-run not available (enable systemd in /etc/wsl.conf)"; exit 1; }

# Never double-launch: check the systemd unit first, then any build a human
# started by hand in their own terminal. The [.] keeps pgrep from matching
# this very command line.
if [[ "$(systemctl is-active aegis-build 2>/dev/null || true)" == "active" ]] \
   || pgrep -f 'build-iso[.]sh' >/dev/null 2>&1; then
    echo "BUILD-ALREADY-RUNNING"
    exit 0
fi

systemctl stop aegis-build 2>/dev/null || true
systemctl reset-failed aegis-build 2>/dev/null || true
rm -f build.log

systemd-run --unit=aegis-build --collect \
    bash -c 'cd /root/AegisOS && exec bash scripts/build-iso.sh > /root/AegisOS/build.log 2>&1'

sleep 3

state="$(systemctl is-active aegis-build 2>/dev/null || true)"
echo "UNIT-STATE: ${state}"
if [[ "${state}" != "active" ]]; then
    echo "FATAL: build unit not active — log tail:"
    tail -20 build.log 2>/dev/null || true
    exit 1
fi
echo "BUILD-RUNNING"
