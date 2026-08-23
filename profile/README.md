# Aegis OS — archiso profile

This directory is a standard [`archiso`](https://gitlab.archlinux.org/archlinux/archiso)
profile consumed by `mkarchiso`. It defines what the ISO contains and how it boots.

## Files

| Path | Purpose |
|------|---------|
| `profiledef.sh` | ISO metadata: name, label, version, boot modes, image type, file permissions. |
| `pacman.conf` | **Build-time** repositories (core/extra/multilib + BlackArch + local `aegis` repo). Rewritten by `scripts/build-iso.sh` to point the local repo at the freshly built packages. |
| `packages.x86_64` | Every package installed into the image. High-confidence tools are always on; a guarded block of BlackArch-only tools is stripped when `AEGIS_ENABLE_BLACKARCH=0`. |
| `bootstrap_packages.x86_64` | Packages for the (unused-by-default) bootstrap tarball build mode. |
| `airootfs/` | Overlay copied onto the live root filesystem: branding, services, skel, and the `aegis-*` command-line tools. |

## Boot configuration is injected at build time

You will **not** find `efiboot/`, `syslinux/`, or `grub/` directories here. On
purpose. `scripts/build-iso.sh` copies those boot menus from the upstream,
Arch-maintained `releng` profile (`/usr/share/archiso/configs/releng`) into the
staged profile and rebrands the titles to *Aegis OS*.

Why: bootloader configs (especially the BIOS `syslinux` color/menu files) are
fiddly and version-sensitive. Reusing the known-good upstream files guarantees a
bootable ISO and keeps us current with archiso changes automatically.

**To customize boot menus**, create the corresponding directory here
(`profile/efiboot/`, `profile/syslinux/`, or `profile/grub/`) and it takes
precedence — the build script only imports a boot dir that is missing.

## The live initramfs

`/etc/mkinitcpio.conf` and `/etc/mkinitcpio.d/linux.preset` are **critical for
booting** — they include the `archiso` hook that mounts the SquashFS root at
boot. To stay correct across archiso versions, the build script imports these
from the upstream `releng` profile if they are not present under `airootfs/`.
Ship your own to override.
