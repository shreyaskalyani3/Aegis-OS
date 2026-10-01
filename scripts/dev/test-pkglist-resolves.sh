#!/usr/bin/env bash
# Regression test: a BlackArch group member whose dependencies have vanished
# from the repos used to abort the whole build (pacstrap: "unable to satisfy
# dependency 'vagrant' required by malboxes" — vagrant left the Arch repos,
# stranding malboxes inside blackarch-malware). build-iso.sh now expands each
# group to its members and drops the ones whose dependencies cannot be
# resolved, so pacstrap only ever sees resolvable names.
#
# Verifies, against a copy of the real profile:
#   1. the field failure exists (pacman -Sp fails like pacstrap did)
#   2. after the filter: boot packages untouched, no bare group lines remain,
#      the dead member is gone, and every group's survivors resolve
#   3. the fail-open path: an un-syncable environment appends groups verbatim
#
# Run inside WSL as root.
set -u

FAILURES=0
note() { printf '%s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*"; FAILURES=$((FAILURES + 1)); }

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
T="$(mktemp -d /tmp/aegis-pkglist-test.XXXXXX)"

# --- 0. prereqs ---------------------------------------------------------------
if [[ ! -f "/etc/pacman.d/blackarch-mirrorlist" ]]; then
    fail "blackarch mirrorlist missing — bootstrap BlackArch in this environment first (scripts/strap.sh or one build)"
    printf 'PKGLIST-RESOLVES-TEST: FAIL\n'
    exit 1
fi
if [[ ! -f "${REPO_ROOT}/profile/pacman.conf" || ! -f "${REPO_ROOT}/profile/packages.x86_64" ]]; then
    fail "profile/pacman.conf or profile/packages.x86_64 missing under ${REPO_ROOT}"
    printf 'PKGLIST-RESOLVES-TEST: FAIL\n'
    exit 1
fi

# The staged conf's [aegis] Server placeholder would break -Sy outside a real
# build (no localrepo exists yet) — the test conf strips that repo; the filter
# logic is repo-agnostic.
STAGED_PROFILE="${T}/profile"
mkdir -p "${STAGED_PROFILE}" "${T}/fdb"
sed '/^\[aegis\]/,/^$/d' "${REPO_ROOT}/profile/pacman.conf" > "${STAGED_PROFILE}/pacman.conf"

# Extract the group list with bash's own parser: the conf line is
# AEGIS_BLACKARCH_GROUPS="${AEGIS_BLACKARCH_GROUPS:-...}", so a plain sed of
# the value leaves the "${...:-" wrapper behind and the first/last group names
# come out corrupted (the throwaway subshell swallows any unset-var warnings).
GROUP_LIST="$(bash -c '. "$1" && printf "%s" "${AEGIS_BLACKARCH_GROUPS-}"' bash "${REPO_ROOT}/aegis.conf")"
if [[ -z "${GROUP_LIST}" ]]; then
    fail "could not read AEGIS_BLACKARCH_GROUPS from aegis.conf"
    printf 'PKGLIST-RESOLVES-TEST: FAIL\n'
    exit 1
fi

if ! pacman --config "${STAGED_PROFILE}/pacman.conf" --dbpath "${T}/fdb" -Sy >/dev/null 2>&1; then
    fail "could not refresh the sync databases (network?)"
    printf 'PKGLIST-RESOLVES-TEST: FAIL\n'
    exit 1
fi
note "databases refreshed (private dbpath, profile config)"

# --- 1. reproduce the field failure -------------------------------------------
# pacman -Sp (print) runs the same transaction preparation pacstrap does and
# fails identically; its stdout carries the ":: unable to satisfy dependency
# 'vagrant' required by malboxes" detail line.
MALWARE_FAILED=0
sp_err="$(pacman --config "${STAGED_PROFILE}/pacman.conf" --dbpath "${T}/fdb" -Sp --noconfirm blackarch-malware 2>&1 >/dev/null)"
if [[ -n "${sp_err}" ]]; then
    MALWARE_FAILED=1
    if printf '%s\n' "${sp_err}" | grep -q "required by malboxes"; then
        note "reproduced the field failure: vagrant dependency unsatisfiable"
    else
        note "blackarch-malware failed for another (possibly newer) reason: ${sp_err}"
    fi
else
    note "blackarch-malware resolves cleanly now (vagrant must be back upstream) — testing the filter's no-drop path"
fi

# --- 2. the filter, on a copy of the real package list ------------------------
# Replicated from build-iso.sh's _append_filtered_blackarch — keep in sync.
_append_filtered_blackarch() {
    local pkgfile="$1"; shift
    local group members survivors drops out attempt verbatim
    local filter_db synced=0

    filter_db="$(mktemp -d /tmp/aegis-pkgfilter.XXXXXX)"
    if pacman --config "${STAGED_PROFILE}/pacman.conf" --dbpath "${filter_db}" -Sy >/dev/null 2>&1; then
        synced=1
    else
        warn "could not refresh the package databases — appending groups verbatim (build may fail; please report)"
    fi

    for group in "$@"; do
        if [[ "${synced}" -eq 0 ]]; then
            printf '%s\n' "${group}" >> "${pkgfile}"
            continue
        fi
        members="$(pacman --config "${STAGED_PROFILE}/pacman.conf" --dbpath "${filter_db}" -Sg "${group}" 2>/dev/null | awk '{print $2}')"
        if [[ -z "${members}" ]]; then
            warn "${group}: not found upstream — dropping the group"
            continue
        fi

        survivors="${members}"
        verbatim=0
        attempt=0
        while :; do
            attempt=$((attempt + 1))
            # shellcheck disable=SC2086  # intentional word-split: one member per arg
            if out="$(pacman --config "${STAGED_PROFILE}/pacman.conf" --dbpath "${filter_db}" -Sp --noconfirm ${survivors} 2>&1)"; then
                break
            fi
            drops="$(printf '%s\n' "${out}" | grep -oE "required by [a-z0-9@._+-]+" | awk '{print $3}' | sort -u)"
            if [[ -z "${drops}" ]]; then
                drops="$(printf '%s\n' "${out}" | grep -oE "target not found: [a-z0-9@._+-]+" | awk '{print $4}' | sort -u)"
            fi
            if [[ -z "${drops}" || "${attempt}" -ge 20 ]]; then
                warn "${group}: could not fully verify resolvability — leaving the group as-is (build may fail; please report)"
                survivors=""
                verbatim=1
                break
            fi
            survivors="$(printf '%s\n' ${survivors} | grep -vxF -f <(printf '%s\n' ${drops}))"
            if [[ -z "${survivors//[[:space:]]/}" ]]; then
                warn "${group}: every member's dependencies are unresolvable — dropping the group"
                survivors=""
                break
            fi
        done

        if [[ "${verbatim}" -eq 1 ]]; then
            printf '%s\n' "${group}" >> "${pkgfile}"
        elif [[ -n "${survivors//[[:space:]]/}" ]]; then
            printf '%s\n' ${survivors} >> "${pkgfile}"
        fi
    done

    rm -rf "${filter_db}"
}
warn() { printf 'WARN: %s\n' "$*" | tee -a "${T}/filter.log"; }

cp "${REPO_ROOT}/profile/packages.x86_64" "${T}/packages.x86_64"
# Replicate the build's staging normalize (fix 4729fb3): a Windows checkout of
# the working tree can keep CRLF, and that breaks the mkarchiso parse below.
if grep -q $'\r$' "${T}/packages.x86_64"; then
    sed -i 's/\r$//' "${T}/packages.x86_64"
    note "normalized CRLF in the copied package list"
fi
printf '\n# --- AEGIS_TOOL_SET=broad: major BlackArch category groups ---\n' >> "${T}/packages.x86_64"
# shellcheck disable=SC2086  # intentional word-split: one group per arg
_append_filtered_blackarch "${T}/packages.x86_64" ${GROUP_LIST}

# mkarchiso's exact parse of the resulting file
sed '/^[[:blank:]]*#.*/d;s/#.*//;/^[[:blank:]]*$/d' "${T}/packages.x86_64" > "${T}/pkglist.parsed"
mapfile -t pkg_list < "${T}/pkglist.parsed"
joined=" ${pkg_list[*]} "
note "parsed package count after the filter: ${#pkg_list[@]} (was: $(sed '/^[[:blank:]]*#.*/d;s/#.*//;/^[[:blank:]]*$/d' "${REPO_ROOT}/profile/packages.x86_64" | wc -l))"

# 2a. boot packages from the curated list must be untouched
for want in syslinux grub efibootmgr edk2-shell memtest86+ memtest86+-efi; do
    if [[ ! "${joined}" =~ " ${want} " ]]; then
        fail "boot package '${want}' lost by the filter (mkarchiso would reject the profile)"
    fi
done

# 2b. no bare group lines may survive — every group must be expanded
for g in ${GROUP_LIST}; do
    if [[ "${joined}" =~ " ${g} " ]]; then
        fail "group '${g}' was not expanded (still a bare line in packages.x86_64)"
    fi
done

# 2c. the dead member must be gone / intact members must stay (upstream-proof)
if grep -qxF malboxes "${T}/pkglist.parsed"; then
    if [[ "${MALWARE_FAILED}" -eq 1 ]]; then
        fail "malboxes survived the filter although its dependencies are unresolvable"
    fi
else
    if [[ "${MALWARE_FAILED}" -eq 0 ]]; then
        fail "malboxes was dropped although blackarch-malware resolves cleanly"
    fi
fi

# 2d. every group's surviving members must resolve as a transaction
for g in ${GROUP_LIST}; do
    inter=""
    for m in $(pacman --config "${STAGED_PROFILE}/pacman.conf" --dbpath "${T}/fdb" -Sg "$g" 2>/dev/null | awk '{print $2}'); do
        grep -qxF "$m" "${T}/pkglist.parsed" && inter+="${m}"$'\n'
    done
    if [[ -z "${inter}" ]]; then
        if grep -q "${g}:" "${T}/filter.log" 2>/dev/null; then
            note "  ${g}: dropped by the filter (warn logged)"
        else
            fail "  ${g}: no members left in the list and no drop was logged"
        fi
        continue
    fi
    if ! printf '%s' "${inter}" | xargs pacman --config "${STAGED_PROFILE}/pacman.conf" --dbpath "${T}/fdb" -Sp --noconfirm >/dev/null 2>&1; then
        fail "survivors of ${g} still do not resolve as a transaction"
    fi
done
note "per-group survivor transactions checked"

# --- 3. fail-open: an un-syncable environment falls back to verbatim groups ---
STAGED_PROFILE="${T}/profile2"
mkdir -p "${STAGED_PROFILE}"
printf '[options]\nArchitecture = auto\n[core]\nInclude = /nonexistent/mirrorlist\n' > "${STAGED_PROFILE}/pacman.conf"
: > "${T}/fallback.x86_64"
_append_filtered_blackarch "${T}/fallback.x86_64" ${GROUP_LIST}
if grep -qxF blackarch-malware "${T}/fallback.x86_64"; then
    note "fail-open fallback OK (un-syncable env appends groups verbatim)"
else
    fail "fail-open fallback broken — an un-syncable env must append groups verbatim"
fi

rm -rf "${T}"
if [[ "${FAILURES}" -eq 0 ]]; then
    printf 'PKGLIST-RESOLVES-TEST: PASS\n'
else
    printf 'PKGLIST-RESOLVES-TEST: FAIL (%s failure(s))\n' "${FAILURES}"
fi
exit "${FAILURES}"
