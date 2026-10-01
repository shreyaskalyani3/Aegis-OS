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
    dosfstools erofs-utils grub mtools sudo curl imagemagick
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
chown -R "${BUILD_USER}:${BUILD_USER}" "${LOCALREPO}"

# makepkg runs as the unprivileged ${BUILD_USER}, so it must be able to reach
# the package tree — which it can't when the repo lives somewhere like /root
# (mode 0700; the field failure: "Failed to create the directory $BUILDDIR")
# or on an NTFS mount. Stage the tree to /tmp (always traversable) and build
# there. A stray inherited BUILDDIR is stripped so makepkg builds in its
# startdir instead of trying to create one it has no rights to.
pkg_stage="$(mktemp -d /tmp/aegis-pkgstage.XXXXXX)"
cp -a "${REPO_ROOT}/${AEGIS_PACKAGES_DIR}" "${pkg_stage}/packages"
# The PKGBUILDs read ../../aegis.conf (and VERSION) relative to their startdir
# — stage those beside packages/ so the relative lookup survives the move and
# version pinning doesn't silently fall back to the build date.
cp -f "${REPO_ROOT}/aegis.conf" "${pkg_stage}/aegis.conf"
[[ -f "${REPO_ROOT}/VERSION" ]] && cp -f "${REPO_ROOT}/VERSION" "${pkg_stage}/VERSION"
chown -R "${BUILD_USER}:${BUILD_USER}" "${pkg_stage}"

built_any=0
for pkgdir in "${pkg_stage}/packages"/*/; do
    [[ -f "${pkgdir}/PKGBUILD" ]] || continue
    name="$(basename "${pkgdir}")"
    log "makepkg: ${name}"
    ( cd "${pkgdir}" && sudo -u "${BUILD_USER}" env -u BUILDDIR AEGIS_VERSION="${VERSION}" \
        makepkg -f --noconfirm --nodeps --skipinteg )
    cp "${pkgdir}"/*.pkg.tar.* "${LOCALREPO}/"
    built_any=1
done

rm -rf "${pkg_stage}"

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

# Normalize CRLF out of the staged profile. The .gitattributes requests LF,
# but a working tree edited with a Windows tool or copied from a Windows
# checkout keeps CRLF (git compares normalized content and considers the file
# clean, so pulls never rewrite it) — and that breaks mkarchiso's exact-match
# boot-package validation ("The 'syslinux' package is missing from the
# package list!") and the live system's shell scripts ("bad interpreter:
# /bin/bash^M"). grep -I skips binaries, so theme PNGs/fonts are never touched.
grep -rIl $'\r$' "${STAGED_PROFILE}" 2>/dev/null | while read -r f; do
    sed -i 's/\r$//' "$f"
    log "normalized CRLF: ${f#"${STAGED_PROFILE}/"}"
done

# --- Oh My Zsh: vendor the zsh framework into the image ----------------------
# Cloned at build time so every Aegis user gets the full terminal — the custom
# aegis theme + AI-agent plugin live in oh-my-zsh-custom (also in the image).
# Shipped immutable: .git stripped, update prompts disabled in .zshrc. On a
# failed clone .zshrc falls back to the plain Aegis prompt, so this never
# breaks the build.
OHMYZSH="${STAGED_PROFILE}/airootfs/usr/share/oh-my-zsh"
if [[ ! -d "${OHMYZSH}" ]]; then
    if git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "${OHMYZSH}"; then
        rm -rf "${OHMYZSH}/.git" "${OHMYZSH}/.github"
        # compaudit-safe perms: oh-my-zsh refuses completions from world-writable
        # dirs, and the staged airootfs inherits whatever the build host gives it.
        chmod -R go-w "${OHMYZSH}" \
            "${STAGED_PROFILE}/airootfs/usr/share/oh-my-zsh-custom" 2>/dev/null || true
        log "vendored oh-my-zsh into the image (aegis theme + agent plugin)"
    else
        warn "oh-my-zsh clone failed — .zshrc falls back to the plain Aegis prompt"
        rm -rf "${OHMYZSH}"
    fi
else
    log "oh-my-zsh already vendored"
fi

# --- fastfetch: ship the config system-wide too ------------------------------
# /etc/fastfetch/config.jsonc is on fastfetch's config search path, so root's
# terminal gets the branded screen as well; per-user configs (from /etc/skel)
# take precedence. Single source: copied from the skel config at build time.
FF_SKEL="${STAGED_PROFILE}/airootfs/etc/skel/.config/fastfetch/config.jsonc"
FF_ETC="${STAGED_PROFILE}/airootfs/etc/fastfetch/config.jsonc"
if [[ -f "${FF_SKEL}" ]]; then
    mkdir -p "$(dirname "${FF_ETC}")"
    cp -f "${FF_SKEL}" "${FF_ETC}"
    log "fastfetch config shipped system-wide (/etc/fastfetch)"
fi

# --- HiTech-arch-animation: alternate plymouth boot animation ----------------
# Cloned at build time; the upstream 2560x1440 PNG frames are ~350MB, so they
# are downscaled to 1920x1080 and palette-quantized (~51MB, visually
# identical — verified, no banding on the neon glow). Ships alongside the
# aegis theme as an alternate: AEGIS_PLYMOUTH_THEME selects the boot default
# at build time (live + installed, via plymouthd.conf), and
# plymouth-set-default-theme -R <theme> switches it on an installed system.
HITECH_DIR="${STAGED_PROFILE}/airootfs/usr/share/plymouth/themes/hitech-arch-animation"
if [[ ! -d "${HITECH_DIR}" ]] && command -v magick >/dev/null 2>&1; then
    hitech_tmp="$(mktemp -d)"
    if git clone -q --depth=1 https://github.com/xDeFc0nx/HiTech-arch-animation.git "${hitech_tmp}"; then
        mkdir -p "${HITECH_DIR}"
        for frame in "${hitech_tmp}"/progress-*.png; do
            magick "${frame}" -resize 1920x1080 -colors 256 \
                "PNG8:${HITECH_DIR}/$(basename "${frame}")"
        done
        cp -f "${hitech_tmp}/animated-boot.script" \
              "${hitech_tmp}/hitech-arch-animation.plymouth" "${HITECH_DIR}/"
        install -Dm644 "${hitech_tmp}/LICENSE" \
            "${STAGED_PROFILE}/airootfs/usr/share/licenses/hitech-arch-animation/LICENSE"
        log "vendored hitech-arch-animation (148 frames, 1920x1080 PNG8)"
    else
        warn "hitech-arch-animation clone failed — shipping the aegis splash only"
    fi
    rm -rf "${hitech_tmp}"
fi

# plymouthd.conf: which theme the live + installed systems boot with (only
# applied when the selected theme actually shipped — a missing theme would
# leave plymouth with nothing to draw).
THEME_SEL="${AEGIS_PLYMOUTH_THEME:-aegis}"
if [[ -d "${STAGED_PROFILE}/airootfs/usr/share/plymouth/themes/${THEME_SEL}" ]]; then
    sed -i "s/^Theme=.*/Theme=${THEME_SEL}/" \
        "${STAGED_PROFILE}/airootfs/etc/plymouth/plymouthd.conf" 2>/dev/null || true
    log "plymouth boot theme: ${THEME_SEL}"
fi

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

# --- Boot branding: custom splash + animated boot splash params ---------------
# The BIOS boot menu (syslinux vesamenu) reads splash.png from its own dir on
# the ISO — replace Arch's with the Aegis one (generated by
# scripts/dev/gen-boot-images.py) and recolour the menu title from Arch purple
# to the Aegis red. The UEFI live menu is systemd-boot, which has no image
# support; the custom GRUB theme covers the installed system's menu instead
# (airootfs/etc/default/grub GRUB_THEME).
SPLASH="${STAGED_PROFILE}/airootfs/usr/share/aegis/splash-aegis.png"
if [[ -f "${SPLASH}" ]]; then
    cp -f "${SPLASH}" "${STAGED_PROFILE}/syslinux/splash.png"
    sed -i 's/#9033ccff/#90ff3355/' "${STAGED_PROFILE}/syslinux/"archiso_head.cfg 2>/dev/null || true
    log "installed custom boot splash (syslinux)"
fi
# `splash` turns on the animated plymouth splash (aegis theme, in the
# initramfs via the plymouth hook); the serial ignore keeps it sane on
# machines with serial consoles. Live kernel params live in the releng boot
# cfgs — add to the syslinux APPEND lines, the grub.cfg linux lines, AND the
# systemd-boot options lines (efiboot loader entries — without them a UEFI boot
# never hands `splash` to the kernel and plymouth never engages).
for f in "${STAGED_PROFILE}/syslinux/"archiso_sys-linux.cfg \
         "${STAGED_PROFILE}/syslinux/"archiso_pxe-linux.cfg \
         "${STAGED_PROFILE}/grub/"grub.cfg \
         "${STAGED_PROFILE}/efiboot/loader/entries/"0*.conf; do
    [[ -f "${f}" ]] || continue
    sed -i 's/^APPEND /APPEND quiet splash plymouth.ignore-serial-consoles /;
            s/^\([[:space:]]*linux[[:space:]].*\)$/& quiet splash plymouth.ignore-serial-consoles/;
            s/^\([[:space:]]*options[[:space:]].*\)$/& quiet splash plymouth.ignore-serial-consoles/' "${f}"
done
# plymouth must be in the LIVE initramfs HOOKS too: the conf.d/archiso.conf
# drop-in reassigns HOOKS wholesale and sources after our aegis.conf drop-in,
# so its list wins on the live medium. Inject after udev (idempotent).
ARCHISO_CONF="${STAGED_PROFILE}/airootfs/etc/mkinitcpio.conf.d/archiso.conf"
if [[ -f "${ARCHISO_CONF}" ]] && ! grep -q '^HOOKS=(base udev plymouth ' "${ARCHISO_CONF}"; then
    sed -i 's/^HOOKS=(base udev /HOOKS=(base udev plymouth /' "${ARCHISO_CONF}"
    log "injected plymouth into the live initramfs HOOKS"
fi
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

# --- Offline-install kernel cache (the EndeavourOS pattern) -------------------
# mkarchiso DELETES /boot (and the pacman cache) from the SquashFS, so a target
# cloned by unpackfs has no vmlinuz-linux and `mkinitcpio -P` in the installer
# dies with "-k /boot/vmlinuz-linux must be readable". Re-copying raw files
# only half-works (no pacman database, no preset ownership), so instead the
# real fix — same as every Calamares-on-archiso distro (EndeavourOS does
# exactly this): pre-download the kernel PACKAGES into a directory the
# mkarchiso cleanup never touches (/usr/share/aegis/packages), and have the
# installer `pacman -U` them into the target. That installs an authentic
# kernel package: vmlinuz in /boot, the standard linux.preset, proper file
# ownership, and an entry in the target's pacman database — everything a
# normal install has, fully OFFLINE.
#
# `linux` depends on the virtual `initramfs` provider (mkinitcpio etc.), so
# the download must run with pacman's dependency resolver (-Sw pulls the
# provider) — the cache therefore also contains mkinitcpio + mkinitcpio-busybox.
# The installer must install ALL of them: the target chroot has no sync
# databases, so `pacman -U linux` alone cannot resolve `initramfs` and aborts
# at "loading packages...". Installing every cached package together lets
# pacman satisfy the dependency from the same -U transaction.
PKG_CACHE="${STAGED_PROFILE}/airootfs/usr/share/aegis/packages"
install -d -m 0755 "${PKG_CACHE}"
KERNEL_PKGS="linux intel-ucode amd-ucode grub"
# Since pacman 6.1 the actual download runs as an unprivileged user
# (DownloadUser, default alpm) — it must be able to TRAVERSE the cache path,
# and dies with "failed to setup a download payload ... Permission denied"
# when the cache sits under /root (mode 0700) or a 0755 workspace. Download
# to a /tmp dir open to everyone, then copy the finished packages in as root.
dl_tmp="$(mktemp -d /tmp/aegis-kerneldl.XXXXXX)"
chmod 0777 "${dl_tmp}"
pacman -Sw --noconfirm --cachedir "${dl_tmp}" ${KERNEL_PKGS} \
    || { rm -rf "${dl_tmp}"; die "could not pre-download kernel packages for offline install"; }
cp -a "${dl_tmp}"/. "${PKG_CACHE}/"
rm -rf "${dl_tmp}"
# Signatures are deleted on purpose: LocalFileSigLevel=Optional means the
# target never verifies local packages, and a stray .sig would make the
# installer's glob match non-package files ("Unrecognized archive format")
# and force keyring checks the chroot cannot satisfy. The packages are
# authentic core/extra downloads, trusted by construction.
rm -f "${PKG_CACHE}"/*.sig
# Databases might be fetched too; the installer only wants package files.
rm -f "${PKG_CACHE}"/{core,extra,multilib,blackarch}.db*
# Pacman's download staging dirs (download-XXXX) must not ship in the ISO
rm -rf "${PKG_CACHE}"/download-*
# Verify every must-have package is present in the cache.
for must in linux intel-ucode amd-ucode grub; do
    ls "${PKG_CACHE}"/${must}-*.pkg.tar.zst >/dev/null 2>&1 \
        || die "package '${must}' missing from the offline cache at ${PKG_CACHE}"
done
ok "offline-install kernel cache: $(ls "${PKG_CACHE}")"
# /boot/vmlinuz-linux for the LIVE medium is still produced by the linux
# package inside the airootfs — mkarchiso moves it out of the SquashFS into
# the ISO's boot dir itself, so live boot is unaffected by this cache.

# Expand the appended BlackArch groups into individual package names, dropping
# any member whose dependencies the configured repos cannot satisfy. Upstream
# removes tools at any time (vagrant left the Arch repos, which stranded
# malboxes inside blackarch-malware), and one unresolvable name aborts the
# whole pacstrap: "unable to satisfy dependency 'vagrant' required by
# malboxes ==> ERROR: Failed to install packages to new root". pacstrap
# expands group names itself, so a dead member inside a group cannot be
# filtered out afterwards — the groups must be expanded here, before the build.
# pacman -Sp (print) runs the same transaction preparation pacstrap does and
# fails identically; its stdout carries the ":: unable to satisfy dependency
# 'X' required by Y" detail lines that name exactly what to drop.
_append_filtered_blackarch() {
    local pkgfile="$1"; shift
    local group members survivors drops out attempt verbatim
    local filter_db synced=0 contributed=0

    filter_db="$(mktemp -d /tmp/aegis-pkgfilter.XXXXXX)"
    # Refresh a private copy of the sync databases so the resolvability test
    # sees exactly what pacstrap will see (same config, fresh -Sy) without
    # touching the host's own database state. Retried, and fatal when all
    # retries fail: without the databases the dead-member filter is blind,
    # and silently appending unfiltered groups only moves the failure to
    # pacstrap ("unable to satisfy dependency 'vagrant' required by
    # malboxes") after the same network outage — with no explanation.
    synced=0
    for _try in 1 2 3 4 5; do
        # -Sy exits 0 even when an Include file is missing (warning only), so a
        # bare exit code cannot be trusted — require actual .db files on disk.
        if pacman --config "${STAGED_PROFILE}/pacman.conf" --dbpath "${filter_db}" -Sy >/dev/null 2>&1 \
           && ls "${filter_db}"/sync/*.db >/dev/null 2>&1; then
            synced=1
            break
        fi
        warn "database refresh failed (try ${_try}/5) — retrying in 10s"
        sleep 10
    done
    if [[ "${synced}" -eq 0 ]]; then
        die "the resolvability filter could not refresh the package databases (network?) — rerun the build on a working connection, or set AEGIS_TOOL_SET=lean to build without the BlackArch groups"
    fi

    for group in "$@"; do
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
            # stdout carries ":: unable to satisfy dependency 'D' required by M"
            # (M drags the dead dependency D in); stderr carries
            # "error: target not found: M" (M itself is gone).
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
            # Whole-line fixed-string match: a drop that is a substring of
            # another name (john vs john-jumbo) must not corrupt survivors.
            survivors="$(printf '%s\n' ${survivors} | grep -vxF -f <(printf '%s\n' ${drops}))"
            if [[ -z "${survivors//[[:space:]]/}" ]]; then
                warn "${group}: every member's dependencies are unresolvable — dropping the group"
                survivors=""
                break
            fi
        done

        if [[ "${verbatim}" -eq 1 ]]; then
            printf '%s\n' "${group}" >> "${pkgfile}"
            contributed=1
        elif [[ -n "${survivors//[[:space:]]/}" ]]; then
            printf '%s\n' ${survivors} >> "${pkgfile}"
            contributed=1
        fi
    done

    # Nothing contributed means the filter was blind (databases not covering
    # the configured groups) or every member is genuinely gone — either way
    # the ISO must not silently ship while claiming these tools. (The pkgfile
    # itself is never empty in a real build — the curated list is already
    # there — so this must check the helper's own contribution.)
    if [[ "${contributed}" -eq 0 ]]; then
        rm -rf "${filter_db}"
        die "no BlackArch packages survived the resolvability filter — rerun the build on a working connection, or set AEGIS_TOOL_SET=lean to build without the BlackArch groups"
    fi

    rm -rf "${filter_db}"
}

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
            printf '\n# --- AEGIS_TOOL_SET=broad: major BlackArch category groups ---\n' >> "${PKGS}"
            # shellcheck disable=SC2086  # intentional word-split: one group per arg
            _append_filtered_blackarch "${PKGS}" ${AEGIS_BLACKARCH_GROUPS}
            ok "tool set: broad — baking in groups: ${AEGIS_BLACKARCH_GROUPS}"
            ;;
        full)
            printf '\n# --- AEGIS_TOOL_SET=full: the entire BlackArch arsenal ---\n' >> "${PKGS}"
            _append_filtered_blackarch "${PKGS}" blackarch
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
