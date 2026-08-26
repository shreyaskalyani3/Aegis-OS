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
bootmodes=(
  'bios.syslinux.mbr'
  'bios.syslinux.eltorito'
  'uefi-ia32.systemd-boot.esp'
  'uefi-x64.systemd-boot.esp'
  'uefi-ia32.systemd-boot.eltorito'
  'uefi-x64.systemd-boot.eltorito'
)
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical')

# File ownership/permission overrides applied to the built airootfs.
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/etc/sudoers.d"]="0:0:750"
  ["/etc/sudoers.d/10-aegis"]="0:0:440"
  ["/usr/local/bin/aegis-setup"]="0:0:755"
  ["/usr/local/bin/aegis-ai"]="0:0:755"
  ["/usr/local/bin/aegis-tools"]="0:0:755"
  ["/usr/local/bin/aegis-run"]="0:0:755"
  ["/usr/local/bin/aegis-ai-install"]="0:0:755"
  ["/usr/local/bin/aegis-motd"]="0:0:755"
  ["/usr/local/bin/aegis-welcome"]="0:0:755"
  ["/usr/local/bin/aegis-desktop-setup"]="0:0:755"
  ["/usr/local/bin/aegis-live-setup"]="0:0:755"
  ["/etc/systemd/system/aegis-live-setup.service"]="0:0:644"
)
