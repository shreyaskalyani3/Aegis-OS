#!/usr/bin/env bash
# =============================================================================
#  profile/profiledef.sh — Aegis OS ISO definition (consumed by mkarchiso)
# =============================================================================
# shellcheck disable=SC2034

iso_name="aegis"
iso_label="AEGIS_$(date +%Y%m)"
iso_publisher="Aegis OS Project <https://aegis-os.example>"
iso_application="Aegis OS — Security & Agent-native Live/Install"
iso_version="${AEGIS_VERSION:-$(date +%Y.%m.%d)}"
install_dir="aegis"
buildmodes=('iso')
# archiso >= 89 boot-mode names. The old split names ('bios.syslinux.mbr',
# 'bios.syslinux.eltorito', 'uefi-{ia32,x64}.systemd-boot.{esp,eltorito}')
# are deprecated aliases of these two and print a warning per build.
bootmodes=(
  'bios.syslinux'
  'uefi.systemd-boot'
)
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical')

# File ownership/permission overrides applied to the built airootfs.
# NOTE: these are applied when the CUSTOM overlay is copied in, i.e. BEFORE
# pacstrap — so they only work for files the overlay itself ships. Entries
# for pacstrap-provided files (/etc/shadow etc.) always warn "does not exist";
# the filesystem package ships shadow/gshadow as 0400 root:root already, so
# they are omitted here deliberately.
file_permissions=(
  ["/root"]="0:0:750"
  ["/etc/sudoers.d"]="0:0:750"
  ["/etc/sudoers.d/10-aegis"]="0:0:440"
  # Live passwords in plaintext — root-only. Regenerated from aegis.conf by
  # scripts/build-iso.sh and deleted by Calamares during install.
  ["/etc/aegis/credentials.conf"]="0:0:600"
  # NM connection profiles are IGNORED unless root-owned mode 600.
  ["/etc/NetworkManager/system-connections"]="0:0:700"
  ["/etc/NetworkManager/system-connections/Wired-connection.nmconnection"]="0:0:600"
  ["/usr/local/bin/aegis-setup"]="0:0:755"
  ["/usr/local/bin/aegis-ai"]="0:0:755"
  ["/usr/local/bin/aegis-tools"]="0:0:755"
  ["/usr/local/bin/aegis-run"]="0:0:755"
  ["/usr/local/bin/aegis-install"]="0:0:755"
  ["/usr/local/bin/aegis-ai-install"]="0:0:755"
  ["/usr/local/bin/aegis-motd"]="0:0:755"
  ["/usr/local/bin/aegis-welcome"]="0:0:755"
  ["/usr/local/bin/aegis-desktop-setup"]="0:0:755"
  ["/usr/local/bin/aegis-credentials"]="0:0:755"
  ["/usr/local/bin/aegis-live-setup"]="0:0:755"
  ["/etc/systemd/system/aegis-credentials.service"]="0:0:644"
  ["/etc/systemd/system/aegis-live-setup.service"]="0:0:644"
)
