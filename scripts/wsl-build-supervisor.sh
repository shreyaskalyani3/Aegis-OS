#!/usr/bin/env bash
# =============================================================================
#  scripts/wsl-build-supervisor.sh — keep the ISO build alive until it's done
# =============================================================================
#  ONE long-lived wsl.exe client does everything: poll the build, hold the VM
#  open while it runs, relaunch it when it dies, and stop when the ISO exists.
#  Previous designs failed because separate short wsl.exe calls each closed a
#  login session — and WSL2 tears the whole VM down ~60s after the LAST client
#  disconnects, killing even the systemd-run build unit.
#
#  Runs INSIDE WSL, started from Windows detached:
#    powershell Start-Process wsl.exe '-u','root','--','bash','-c','exec bash /mnt/f/AegisOS/scripts/wsl-build-supervisor.sh'
#  Never run it twice in parallel: it would double-launch builds.
#
#  Log: F:/AegisOS/work/supervisor.log (WSL side: /mnt/f/AegisOS/work/...)
set -u

SLOG=/mnt/f/AegisOS/work/supervisor.log
mkdir -p "$(dirname "${SLOG}")"
log() { printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "${SLOG}"; }

log "supervisor started (pid $$, parent cmdline: $(ps -o comm= -p $PPID 2>/dev/null))"

fail_streak=0

while true; do
    # 1. Done? (ISO exists → exit; the build script itself writes it.)
    if ls /root/AegisOS/out/*.iso >/dev/null 2>&1; then
        log "ISO present — supervisor done"
        break
    fi

    # 2. Build running? (unit, or a human-started build in their own terminal)
    #    [.] stops pgrep matching its own command line.
    if systemctl is-active aegis-build >/dev/null 2>&1 \
       || pgrep -f 'build-iso[.]sh' >/dev/null 2>&1; then
        sleep 30
        continue
    fi

    # 3. Nothing running: relaunch (backoff on repeated quick deaths).
    if [ "${fail_streak}" -ge 8 ]; then
        log "GIVING UP after ${fail_streak} quick failures — fix scripts/build-iso.sh, delete work/BUILD-GAVE-UP, rerun"
        : > /mnt/f/AegisOS/work/BUILD-GAVE-UP
        break
    fi
    if [ "${fail_streak}" -gt 0 ]; then
        wait_secs=$(( fail_streak * 60 ))
        log "backing off ${wait_secs}s (streak ${fail_streak})"
        sleep "${wait_secs}"
    fi

    log "launching build (scripts/wsl-build-launch.sh)"
    bash /mnt/f/AegisOS/scripts/wsl-build-launch.sh >> "${SLOG}" 2>&1
    sleep 45

    # Did that launch stick for at least ~2 min? If the build survives past
    # step 3/6 the streak resets.
    if systemctl is-active aegis-build >/dev/null 2>&1; then
        t0=$(date +%s)
        while systemctl is-active aegis-build >/dev/null 2>&1; do
            sleep 30
        done
        ran=$(( $(date +%s) - t0 ))
        if [ "${ran}" -lt 300 ]; then
            fail_streak=$(( fail_streak + 1 ))
        else
            fail_streak=0
        fi
        log "build ended after ${ran}s (streak ${fail_streak})"
    else
        fail_streak=$(( fail_streak + 1 ))
        log "launch did not stick (streak ${fail_streak})"
    fi
done

log "supervisor exited"
