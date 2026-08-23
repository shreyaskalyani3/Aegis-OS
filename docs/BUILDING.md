# Building Aegis OS

Aegis OS is an Arch-based live/installable ISO produced with
[`archiso`](https://gitlab.archlinux.org/archlinux/archiso). An Arch ISO can
**only be built on Linux** (`mkarchiso` needs a real Linux kernel, loop
devices, and root). This repo is authored on Windows, so the recommended path
builds in the cloud or in a Linux container.

Everything is driven by one script — [`scripts/build-iso.sh`](../scripts/build-iso.sh)
— and configured from one file — [`aegis.conf`](../aegis.conf).

---

## Path A — GitHub Actions (recommended, no local Linux needed)

The included workflow builds the ISO in a privileged Arch container on an
Ubuntu runner and uploads the result.

1. Push this repository to GitHub (public or private).
2. Go to **Actions** → enable workflows if prompted.
3. Trigger a build:
   - **Manually:** Actions → *Build Aegis OS ISO* → **Run workflow**, or
   - **By tag:** push a tag like `v2026.08.23`:
     ```bash
     git tag v2026.08.23
     git push origin v2026.08.23
     ```
4. When it finishes, download the ISO from the run's **Artifacts**
   (tag builds also attach it to a **Release**, size permitting).

The workflow lives in [`.github/workflows/build-iso.yml`](../.github/workflows/build-iso.yml).
It frees disk space, then runs the same `build-iso.sh` you'd run locally.

> Build time is roughly 20–45 min depending on how many tools are baked in and
> BlackArch mirror speed.

---

## Path B — Docker Desktop (Windows/macOS/Linux)

Requires Docker with Linux containers and privileged mode.

```bash
bash build.sh docker
```

This builds `docker/Dockerfile` and runs the build inside a privileged
`archlinux` container with the repo bind-mounted. The ISO lands in `./out/`.

Under the hood: `docker run --rm --privileged -v "$PWD:/aegis" -w /aegis <img> bash scripts/build-iso.sh`.

---

## Path C — WSL2 with Arch (Windows)

```bash
bash scripts/setup-wsl.sh      # installs WSL2 + Arch (one time), then follow the printed steps
```

Then, **inside the Arch WSL distro**, from a copy of this repo on the Linux
filesystem (not `/mnt/c`, which lacks Linux permissions):

```bash
sudo bash scripts/build-iso.sh
```

---

## Path D — Native Arch Linux

On any Arch (or Arch-in-a-VM) host:

```bash
sudo bash scripts/build-iso.sh
```

The script installs its own build dependencies (`archiso`, `base-devel`, …),
enables BlackArch in the *build environment*, builds the custom `aegis-*`
packages, stages the profile, and runs `mkarchiso`.

---

## What the build does

1. **Install deps** — archiso toolchain + `base-devel`, create an unprivileged
   `builder` user (makepkg refuses to run as root).
2. **Configure repos** — bootstrap BlackArch via `strap.sh` (and optionally
   Chaotic-AUR) so the arsenal is resolvable at ISO-assembly time.
3. **Build custom packages** — every `packages/*/PKGBUILD` is built with
   `makepkg` and published into a local `[aegis]` pacman repo.
4. **Stage the profile** — copy `profile/`, import & rebrand the known-good
   `releng` boot configs (`efiboot`/`syslinux`/`grub`) and the critical
   `mkinitcpio` files, inject the local-repo path, stamp the version, append the
   `AEGIS_TOOL_SET` tool groups, enable systemd services, and (if BlackArch is
   off) strip BlackArch-only entries.
5. **`mkarchiso`** — assemble the SquashFS + bootloaders into a hybrid ISO.
6. **Checksum** — write a `.sha256` next to the ISO.

Output: `out/aegis-*.iso` and `out/aegis-*.iso.sha256`.

---

## Configuration knobs (`aegis.conf`)

| Variable | Meaning |
|---|---|
| `AEGIS_VERSION` | ISO version (default: build date `YYYY.MM.DD`) |
| `AEGIS_ENABLE_BLACKARCH` | `1` bakes BlackArch tools in; `0` strips them (much smaller/faster) |
| `AEGIS_TOOL_SET` | how much arsenal is baked in: `lean` / `broad` (default) / `full` |
| `AEGIS_BLACKARCH_GROUPS` | the category groups baked in when `AEGIS_TOOL_SET=broad` |
| `AEGIS_ENABLE_CHAOTIC` | `1` adds Chaotic-AUR to the build environment |
| `AEGIS_AI_AGENTS` | which agents the tooling knows about |
| `AEGIS_LIVE_USER` / `_PASSWORD` | live-session credentials (default `aegis`/`aegis`) |
| `AEGIS_DESKTOP` | desktop environment (wired for `xfce`) |

Set them in `aegis.conf`, or override per-build via the environment, e.g.:

```bash
AEGIS_TOOL_SET=lean  sudo -E bash scripts/build-iso.sh   # curated core only, ~4 GB
AEGIS_TOOL_SET=broad sudo -E bash scripts/build-iso.sh   # all major categories (default)
AEGIS_TOOL_SET=full  sudo -E bash scripts/build-iso.sh   # ENTIRE arsenal — big-disk host only
AEGIS_ENABLE_BLACKARCH=0 sudo -E bash scripts/build-iso.sh   # no BlackArch at all
```

(`-E` preserves the environment across `sudo` so the overrides reach the script.)

---

## Testing the ISO

**QEMU (UEFI):**
```bash
qemu-system-x86_64 -enable-kvm -m 4096 -smp 2 \
  -bios /usr/share/edk2/x64/OVMF.4m.fd \
  -cdrom out/aegis-*.iso
```

**QEMU (BIOS):**
```bash
qemu-system-x86_64 -enable-kvm -m 4096 -smp 2 -cdrom out/aegis-*.iso
```

Or attach the ISO to a new VirtualBox/VMware VM (≥4 GB RAM), or write it to a
USB stick with `dd`/Rufus/Etcher and boot bare metal. The live session
autologins to XFCE as `aegis`.

---

## Installing to disk

The live desktop has **Install Aegis OS** (Calamares), which clones the live
system to disk and configures a bootloader and your user account. A terminal
fallback is always available:

```bash
sudo archinstall        # official Arch guided installer
```

> The Calamares configuration in `profile/airootfs/etc/calamares/` targets this
> profile's layout (SquashFS at `/run/archiso/bootmnt/aegis/x86_64/airootfs.sfs`,
> GRUB, LightDM/XFCE). If you change `install_dir`, `iso_name`, or the image
> type in `profiledef.sh`, update `modules/unpackfs.conf` to match. Validate a
> disk install in a VM before relying on it. `archinstall` is unaffected by
> profile changes and is the safe fallback.

---

## Troubleshooting

- **`not an Arch Linux environment`** — you ran the script off Arch. Use Path A/B/C.
- **`releng profile not found`** — the `archiso` package isn't installed; the
  script installs it, so this only appears if that step was skipped.
- **A package name fails to resolve** — a BlackArch tool was renamed. Remove it
  from `profile/packages.x86_64` (or move it out of the always-on list); the
  full arsenal is installable at runtime with `aegis-tools` regardless.
- **Out of disk in CI** — the workflow frees disk and puts the heavy build dirs
  (`work/` + the pacman cache) on the runner's large `/mnt` disk. If a `broad`
  build still overflows, dial `AEGIS_TOOL_SET=lean` — Actions → *Run workflow*
  lets you pick the tier per run.
- **`broad` build fails on one package** — the rolling arsenal occasionally
  ships a broken or conflicting package that aborts the whole `mkarchiso`
  install; the log names it. Drop that package/group from `AEGIS_BLACKARCH_GROUPS`
  (or `profile/packages.x86_64`), or fall back to `AEGIS_TOOL_SET=lean`.
- **`full` won't build in CI** — expected: ~2800 tools overflow a GitHub runner's
  disk and time budget. Build `full` locally (Path B/C/D) on a host with ~120 GB
  free, or stay on `broad` and top up with `aegis-tools install <group>` post-boot.
