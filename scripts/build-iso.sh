#!/usr/bin/env bash
# =============================================================================
#  scripts/build-iso.sh — build the Aegis OS ISO (runs on an Arch Linux host)
# =============================================================================
#  Intended to run as root inside an Arch environment: a GitHub Actions
#  `archlinux` container, a Docker container (see build-docker.sh), or WSL2 Arch.
#
#  Pipeline:
#    1. install build dependencies (archiso, base-devel, git, ...)
#    2. enable BlackArch (+ optional Chaotic-AUR) in the build environment
#    3. build the custom aegis-* packages into a local pacman repo
#    4. stage the profile and inject the local-repo path
#    5. run mkarchiso to produce the ISO
#    6. checksum the result
# =============================================================================

# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

BUILD_USER="${AEGIS_BUILD_USER:-builder}"
VERSION="$(resolve_version)"

# -----------------------------------------------------------------------------
step "Aegis OS ISO build — v${VERSION}"
require_root
is_arch || die "not an Arch Linux environment (expected /etc/arch-release). Use Docker/WSL — see docs/BUILDING.md"

WORK="${REPO_ROOT}/${AEGIS_WORK_DIR}"
OUT="${REPO_ROOT}/${AEGIS_OUT_DIR}"
LOCALREPO="${REPO_ROOT}/${AEGIS_REPO_OUT}"
STAGED_PROFILE="${WORK}/profile"
mkdir -p "${WORK}" "${OUT}" "${LOCALREPO}"

# -----------------------------------------------------------------------------
step "1/6 Installing build dependencies"
pacman -Sy --needed --noconfirm archlinux-keyring
pacman -S  --needed --noconfirm archiso base-devel git squashfs-tools libisoburn \
    dosfstools erofs-utils grub mtools sudo curl
ok "build dependencies present"

# Ensure an unprivileged build user exists (makepkg refuses to run as root).
if ! id -u "${BUILD_USER}" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "${BUILD_USER}"
    ok "created build user '${BUILD_USER}'"
fi
printf '%s ALL=(ALL) NOPASSWD: ALL\n' "${BUILD_USER}" > /etc/sudoers.d/aegis-builder
chmod 0440 /etc/sudoers.d/aegis-builder

# -----------------------------------------------------------------------------
step "2/6 Configuring repositories"
if [[ "${AEGIS_ENABLE_BLACKARCH}" -eq 1 ]]; then
    if ! grep -q '^\[blackarch\]' /etc/pacman.conf; then
        log "bootstrapping BlackArch via strap.sh"
        tmp_strap="$(mktemp)"
        curl -fsSL "${AEGIS_BLACKARCH_STRAP_URL}" -o "${tmp_strap}"
        chmod +x "${tmp_strap}"
        # strap.sh adds [blackarch], installs blackarch-keyring & blackarch-mirrorlist
        "${tmp_strap}"
        rm -f "${tmp_strap}"
        ok "BlackArch enabled in build environment"
    else
        ok "BlackArch already configured"
    fi
    pacman -Sy --noconfirm
else
    warn "BlackArch disabled (AEGIS_ENABLE_BLACKARCH=0) — blackarch-only tools will be stripped"
fi

if [[ "${AEGIS_ENABLE_CHAOTIC}" -eq 1 ]] && ! grep -q '^\[chaotic-aur\]' /etc/pacman.conf; then
    log "enabling Chaotic-AUR"
    pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    pacman-key --lsign-key 3056513887B78AEB
    pacman -U --noconfirm \
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' || \
        warn "Chaotic-AUR bootstrap failed — continuing without it"
    if ! grep -q '^\[chaotic-aur\]' /etc/pacman.conf; then
        printf '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n' >> /etc/pacman.conf
    fi
    pacman -Sy --noconfirm || true
fi

# -----------------------------------------------------------------------------
step "3/6 Building custom aegis-* packages"
rm -f "${LOCALREPO}"/*.pkg.tar.* "${LOCALREPO}"/${AEGIS_LOCAL_REPO_NAME}.* 2>/dev/null || true
chown -R "${BUILD_USER}:${BUILD_USER}" "${REPO_ROOT}/${AEGIS_PACKAGES_DIR}" "${LOCALREPO}"

built_any=0
for pkgdir in "${REPO_ROOT}/${AEGIS_PACKAGES_DIR}"/*/; do
    [[ -f "${pkgdir}/PKGBUILD" ]] || continue
    name="$(basename "${pkgdir}")"
    log "makepkg: ${name}"
    ( cd "${pkgdir}" && sudo -u "${BUILD_USER}" env AEGIS_VERSION="${VERSION}" \
        makepkg -f --noconfirm --nodeps --skipinteg )
    cp "${pkgdir}"/*.pkg.tar.* "${LOCALREPO}/"
    built_any=1
done

if [[ "${built_any}" -eq 1 ]]; then
    ( cd "${LOCALREPO}" && repo-add "${AEGIS_LOCAL_REPO_NAME}.db.tar.zst" ./*.pkg.tar.* )
    ok "local repo '${AEGIS_LOCAL_REPO_NAME}' built at ${LOCALREPO}"
else
    warn "no custom packages found in ${AEGIS_PACKAGES_DIR}/ — creating empty repo"
    ( cd "${LOCALREPO}" && repo-add "${AEGIS_LOCAL_REPO_NAME}.db.tar.zst" 2>/dev/null || true )
fi

# -----------------------------------------------------------------------------
step "4/6 Staging profile"
rm -rf "${STAGED_PROFILE}"
cp -a "${REPO_ROOT}/${AEGIS_PROFILE_DIR}" "${STAGED_PROFILE}"

# Boot menus (efiboot/syslinux/grub) are pulled from the upstream, known-good
# `releng` profile and rebranded — more robust than hand-maintaining bootloader
# configs. Ship your own dirs in profile/ to override this.

# airootfs of the STAGED profile (not the repo copy — the repo is authored on
# Windows and must never be mutated by a build).
AIROOTFS="${STAGED_PROFILE}/airootfs"

# Hide menu entries that are irrelevant on Aegis (upstream .desktop files we
# cannot edit). NoDisplay alone keeps them out of Whisker; Hidden=true is also
# set because some shells (XFCE Applications) only honour Hidden. Valid keys
# only — NoDisplay/Hidden are booleans, so a stray Name-only stub with made-up
# keys would itself fail desktop-file validation.
TOMBSTONE_DIR="${AIROOTFS}/usr/local/share/applications"
mkdir -p "${TOMBSTONE_DIR}"
TOMBSTONES=(
  assistant designer linguist qdbusviewer qt5ct qt6ct kvantummanager
  xfce4-web-browser xfce4-file-manager xfce4-terminal-emulator xfce4-mail-reader
  org.gnome.FileRoller htop btop vim nvim
  xfce4-about thunar-bulk-rename xfburn xfce4-dict gigolo xfdashboard
  xfce4-screensaver xfce4-screensaver-preferences parole blueman-adapters
  avahi-discover bssh bvnc lstopo cmake-gui qv4l2 qvidcap calamares
)
for t in "${TOMBSTONES[@]}"; do
  cat > "${TOMBSTONE_DIR}/${t}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${t}
NoDisplay=true
Hidden=true
EOF
done

RELENG="/usr/share/archiso/configs/releng"
[[ -d "${RELENG}" ]] || die "releng profile not found at ${RELENG} (is 'archiso' installed?)"
for bootdir in efiboot syslinux grub; do
    if [[ ! -d "${STAGED_PROFILE}/${bootdir}" ]]; then
        cp -a "${RELENG}/${bootdir}" "${STAGED_PROFILE}/${bootdir}"
        log "imported boot config: ${bootdir} (from releng)"
    fi
done
# Rebrand boot menu titles: "Arch Linux" -> "Aegis OS".
grep -rl 'Arch Linux' "${STAGED_PROFILE}/efiboot" "${STAGED_PROFILE}/syslinux" \
    "${STAGED_PROFILE}/grub" 2>/dev/null | while read -r f; do
    sed -i 's/Arch Linux/Aegis OS/g' "${f}"
done
# Safety net: ensure the live initramfs config exists (critical for booting).
# The archiso.conf drop-in carries the live HOOKS (archiso, loop mount, etc.);
# without it mkinitcpio builds an initramfs that cannot mount the live medium.
for critical in etc/mkinitcpio.conf etc/mkinitcpio.conf.d/archiso.conf etc/mkinitcpio.d/linux.preset; do
    if [[ ! -f "${STAGED_PROFILE}/airootfs/${critical}" && -f "${RELENG}/airootfs/${critical}" ]]; then
        mkdir -p "$(dirname "${STAGED_PROFILE}/airootfs/${critical}")"
        cp -a "${RELENG}/airootfs/${critical}" "${STAGED_PROFILE}/airootfs/${critical}"
        log "imported critical file: airootfs/${critical} (from releng)"
    fi
done

# Inject the absolute local-repo path into the [aegis] repo Server line.
sed -i "s|file://__AEGIS_LOCAL_REPO__|file://${LOCALREPO}|g" "${STAGED_PROFILE}/pacman.conf"

# Generate the live credentials file from aegis.conf. Until this existed,
# AEGIS_LIVE_PASSWORD / AEGIS_ROOT_PASSWORD were dead config: aegis.conf
# advertises itself as the single source of truth and even says "change for
# prod!", but the values were hardcoded in aegis-live-setup and never read, so
# editing them silently did nothing.
#
# printf %q emits shell-quoted literals, so any password — spaces, quotes, &, |,
# backslashes, $VAR, backticks — round-trips exactly when the script sources it.
# (An earlier sed-substitution approach mangled every one of those.)
install -d -m 0755 "${STAGED_PROFILE}/airootfs/etc/aegis"
{
    printf '# Generated by scripts/build-iso.sh from aegis.conf — do not edit by hand.\n'
    printf '# Live medium only; Calamares removes this during install.\n'
    printf 'AEGIS_LIVE_USER=%q\n'      "${AEGIS_LIVE_USER}"
    printf 'AEGIS_LIVE_PASSWORD=%q\n'  "${AEGIS_LIVE_PASSWORD}"
    printf 'AEGIS_ROOT_PASSWORD=%q\n'  "${AEGIS_ROOT_PASSWORD}"
    printf 'AEGIS_DEFAULT_SHELL=%q\n'  "${AEGIS_DEFAULT_SHELL}"
} > "${STAGED_PROFILE}/airootfs/etc/aegis/credentials.conf"
chmod 0600 "${STAGED_PROFILE}/airootfs/etc/aegis/credentials.conf"
# Prove it parses back to the configured values before shipping it, rather than
# discovering at boot that the only account in the image has no usable password.
# The vars are unset inside the subshell first, so inheriting them from aegis.conf
# cannot make a file that failed to write look correct.
_cred_want="$(printf '%s\n%s\n%s' "${AEGIS_LIVE_USER}" "${AEGIS_LIVE_PASSWORD}" "${AEGIS_ROOT_PASSWORD}")"
_cred_got="$( unset AEGIS_LIVE_USER AEGIS_LIVE_PASSWORD AEGIS_ROOT_PASSWORD
              source "${STAGED_PROFILE}/airootfs/etc/aegis/credentials.conf" 2>/dev/null
              printf '%s\n%s\n%s' "${AEGIS_LIVE_USER-}" "${AEGIS_LIVE_PASSWORD-}" "${AEGIS_ROOT_PASSWORD-}" )"
[[ "${_cred_got}" == "${_cred_want}" ]] \
    || die "generated credentials.conf does not round-trip — refusing to build an unloggable ISO"
ok "live credentials generated from aegis.conf (user: ${AEGIS_LIVE_USER})"

# Stamp the build version into os-release / boot menus (placeholder __AEGIS_VERSION__).
grep -rl '__AEGIS_VERSION__' "${STAGED_PROFILE}" 2>/dev/null | while read -r f; do
    sed -i "s|__AEGIS_VERSION__|${VERSION}|g" "${f}"
done

# If BlackArch is disabled, strip the repo (build + runtime) and the pkg block.
if [[ "${AEGIS_ENABLE_BLACKARCH}" -ne 1 ]]; then
    sed -i '/^\[blackarch\]/,/^Include = \/etc\/pacman.d\/blackarch-mirrorlist/d' "${STAGED_PROFILE}/pacman.conf"
    sed -i '/^\[blackarch\]/,/^Include = \/etc\/pacman.d\/blackarch-mirrorlist/d' "${STAGED_PROFILE}/airootfs/etc/pacman.conf" 2>/dev/null || true
    sed -i '/# >>> AEGIS_BLACKARCH_ONLY >>>/,/# <<< AEGIS_BLACKARCH_ONLY <<</d' "${STAGED_PROFILE}/packages.x86_64"
fi

# --- Bake in the requested breadth of the BlackArch arsenal ------------------
# AEGIS_TOOL_SET selects how much ships inside the ISO:
#   lean  = the curated always-on set only (already in packages.x86_64)
#   broad = curated + the major category groups from aegis.conf   (default)
#   full  = curated + the ENTIRE `blackarch` group (~2800 tools)
# Groups resolve from the [blackarch] repo, so this only applies when BlackArch
# is enabled. A group name in packages.x86_64 is expanded by pacstrap at build.
PKGS="${STAGED_PROFILE}/packages.x86_64"
if [[ "${AEGIS_ENABLE_BLACKARCH}" -eq 1 ]]; then
    case "${AEGIS_TOOL_SET:-broad}" in
        lean)
            ok "tool set: lean — curated baked-in set only"
            ;;
        broad)
            {
                printf '\n# --- AEGIS_TOOL_SET=broad: major BlackArch category groups ---\n'
                # shellcheck disable=SC2086  # intentional word-split: one group per line
                printf '%s\n' ${AEGIS_BLACKARCH_GROUPS}
            } >> "${PKGS}"
            ok "tool set: broad — baking in groups: ${AEGIS_BLACKARCH_GROUPS}"
            ;;
        full)
            printf '\n# --- AEGIS_TOOL_SET=full: the entire BlackArch arsenal ---\nblackarch\n' >> "${PKGS}"
            warn "tool set: full — baking in the ENTIRE blackarch group (~2800 pkgs)."
            warn "This needs a large-disk Linux host; GitHub Actions will likely run out of space."
            ;;
        *)
            die "unknown AEGIS_TOOL_SET='${AEGIS_TOOL_SET}' (expected lean|broad|full)"
            ;;
    esac
else
    [[ "${AEGIS_TOOL_SET:-broad}" != "lean" ]] && \
        warn "AEGIS_TOOL_SET='${AEGIS_TOOL_SET}' has no effect: BlackArch is disabled"
fi

# --- Enable systemd services in the image (mirrors `systemctl enable`) -------
# Modern archiso has no chroot/customize hook, and this profile is authored on
# a non-Linux host where committing symlinks is unreliable. So we materialize
# the exact enablement symlinks `systemctl enable` would create, directly in
# the staged airootfs. Targets point at in-image paths (dangling on the build
# host, valid inside the ISO — ln does not check existence).
SYSD="${STAGED_PROFILE}/airootfs/etc/systemd/system"
LIB="/usr/lib/systemd/system"
mkdir -p "${SYSD}/multi-user.target.wants" "${SYSD}/graphical.target.wants" \
         "${SYSD}/sysinit.target.wants" "${SYSD}/bluetooth.target.wants"

# Boot into the graphical target (LightDM greeter -> XFCE).
ln -sf "${LIB}/graphical.target" "${SYSD}/default.target"

# Display manager: LightDM. The generic display-manager.service alias is what
# other tooling references; the graphical.target.wants link guarantees start.
ln -sf "${LIB}/lightdm.service" "${SYSD}/display-manager.service"
ln -sf "${LIB}/lightdm.service" "${SYSD}/graphical.target.wants/lightdm.service"

# Networking (NetworkManager) + its D-Bus aliases.
ln -sf "${LIB}/NetworkManager.service"            "${SYSD}/multi-user.target.wants/NetworkManager.service"
ln -sf "${LIB}/NetworkManager.service"            "${SYSD}/dbus-org.freedesktop.NetworkManager.service"
ln -sf "${LIB}/NetworkManager-dispatcher.service" "${SYSD}/dbus-org.freedesktop.nm-dispatcher.service"

# Clock sync (WantedBy=sysinit.target) — important for TLS to pacman & AI APIs.
ln -sf "${LIB}/systemd-timesyncd.service" "${SYSD}/sysinit.target.wants/systemd-timesyncd.service"
ln -sf "${LIB}/systemd-timesyncd.service" "${SYSD}/dbus-org.freedesktop.timesync1.service"

# Bluetooth (D-Bus activated; enabled for completeness).
ln -sf "${LIB}/bluetooth.service" "${SYSD}/bluetooth.target.wants/bluetooth.service"
ln -sf "${LIB}/bluetooth.service" "${SYSD}/dbus-org.bluez.service"

# The Aegis credential oneshot creates the live user and sets the passwords. It
# is ordered before both aegis-live-setup and the display manager, and is the
# only thing in the image that produces a usable password, so it must be enabled.
ln -sf "/etc/systemd/system/aegis-credentials.service" \
       "${SYSD}/multi-user.target.wants/aegis-credentials.service"

# The Aegis live-setup oneshot configures the live desktop (locale, autologin,
# launcher trust, VM agents) after credentials are in place.
ln -sf "/etc/systemd/system/aegis-live-setup.service" \
       "${SYSD}/multi-user.target.wants/aegis-live-setup.service"
ok "systemd services enabled in staged airootfs"

ok "profile staged at ${STAGED_PROFILE}"

# -----------------------------------------------------------------------------
step "5/6 Running mkarchiso (this takes a while)"
AEGIS_VERSION="${VERSION}" mkarchiso -v -w "${WORK}/mkarchiso" -o "${OUT}" "${STAGED_PROFILE}"

# -----------------------------------------------------------------------------
step "6/6 Finalizing"
iso_file="$(find "${OUT}" -maxdepth 1 -name '*.iso' -newermt '-10 min' | head -n1 || true)"
[[ -z "${iso_file}" ]] && iso_file="$(find "${OUT}" -maxdepth 1 -name '*.iso' | head -n1 || true)"
[[ -n "${iso_file}" ]] || die "no ISO produced — check mkarchiso output above"

( cd "${OUT}" && sha256sum "$(basename "${iso_file}")" > "$(basename "${iso_file}").sha256" )

ok "ISO:      ${iso_file}"
ok "SHA256:   ${iso_file}.sha256"
printf '\n%s\n' "${C_GREEN}${C_BOLD}Aegis OS v${VERSION} build complete.${C_RESET}"
