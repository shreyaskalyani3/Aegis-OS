<div align="center">

# 🛡️ Aegis OS

**An Arch Linux–based, agent-native operating system for offensive & defensive security.**

*Codename: Sentinel*

Live + installable ISO · BlackArch arsenal · XFCE · Claude Code · OpenCode · Aider · Codex

<br>

<img src="docs/images/desktop-preview.svg" alt="Aegis OS desktop — XFCE with the Aegis MOTD terminal and the aegis-ai agent launcher" width="92%">

<sub>XFCE 4 · adw-gtk3-dark + Papirus · the <code>aegis</code> MOTD banner · the <code>aegis-ai</code> launcher · a live <code>nmap -sV</code> scan</sub>

</div>

---

Aegis OS is a **real, bootable operating system** in the tradition of Kali Linux, BlackArch,
and Parrot OS — built on the rolling-release Arch base, preloaded with a large security
toolset via the **BlackArch** repositories, and — unlike any of them — shipping **AI coding
agents as first-class citizens** of the platform (Claude Code, OpenCode, Aider, and Codex),
wired together behind a single `aegis-ai` launcher and a first-boot setup wizard.

This repository is the **source of the distribution**. It contains an
[`archiso`](https://gitlab.archlinux.org/archlinux/archiso) profile, the custom packages,
the branding, and the build tooling that compile into a distributable `.iso`.

> ⚠️ **You are on Windows with no local Linux build environment.** Building an Arch ISO
> requires Linux. The **recommended path is GitHub Actions** (cloud build, zero local setup) —
> see [Quick start](#-quick-start). Local Docker and WSL2 paths are also provided.

---

## ✨ What's inside

| Layer | Details |
|-------|---------|
| **Base** | Arch Linux (rolling), current `linux` kernel, `mkinitcpio`-generated live image |
| **Tools** | BlackArch (2800+ tools) — **all major categories baked in** by default, the rest on demand via `aegis-tools`. Tune with `AEGIS_TOOL_SET` (`lean`/`broad`/`full`) |
| **Desktop** | XFCE 4 with a dark "Aegis" theme (adw-gtk3-dark + Papirus-Dark), custom wallpaper, autologin live user |
| **AI agents** | Claude Code, OpenCode (native Arch pkg), Aider, Codex — unified `aegis-ai` launcher + `aegis-setup` wizard |
| **Runtimes** | Node.js 22, Python + `pipx` + `uv`, Go, Rust, Git, ripgrep — so agents & tools work out of the box |
| **Installer** | Calamares graphical installer — Aegis is **installable to disk**, not just a live CD |
| **Shell** | Zsh + a security-focused prompt, sensible aliases, tmux |

See [`docs/TOOLS.md`](docs/TOOLS.md) for the full toolset and [`docs/AI-AGENTS.md`](docs/AI-AGENTS.md)
for how the agents are integrated.

---

## 🖼️ Look & feel

<div align="center">

<img src="docs/images/login-preview.svg" alt="Aegis OS LightDM greeter — shield avatar, aegis user, Xfce session" width="64%">

<sub>The LightDM greeter (adw-gtk3-dark): shield avatar, the <code>aegis</code> user, Xfce session.</sub>

</div>

Aegis ships **four** SVG wallpapers in `/usr/share/backgrounds/aegis/` (they render because
`librsvg` is installed); the red **Sentinel** design is the default for both the desktop
([`aegis-desktop-setup`](profile/airootfs/usr/local/bin/aegis-desktop-setup)) and the greeter
([`lightdm-gtk-greeter.conf`](profile/airootfs/etc/lightdm/lightdm-gtk-greeter.conf)):

| Wallpaper | File | Vibe |
|-----------|------|------|
| **Sentinel** (default) | `aegis-wallpaper.svg` | Red shield emblem, centered wordmark |
| **Matrix** | `aegis-wallpaper-matrix.svg` | Green, faint falling-code columns |
| **Blue Team** | `aegis-wallpaper-blueteam.svg` | Cyan defensive palette |
| **Minimal** | `aegis-wallpaper-minimal.svg` | Small lower-left emblem, lots of negative space |

Switch the desktop from **Settings → Desktop** (or point `WALL=` in `aegis-desktop-setup` at
another file); switch the greeter by editing `background =` in `lightdm-gtk-greeter.conf`.

> The images above are hand-drawn SVG mockups of the configured theme, not photos of a running
> system — the real look is produced by the same colors, fonts, and layout the profile ships.

---

## 🚀 Quick start

### Option A — GitHub Actions (recommended, no local Linux needed)

1. Create a new GitHub repository and push this project to it:
   ```bash
   git init && git add . && git commit -m "Aegis OS initial"
   git branch -M main
   git remote add origin https://github.com/<you>/aegis-os.git
   git push -u origin main
   ```
2. In the repo, open the **Actions** tab and run the **Build Aegis OS ISO** workflow
   (it also runs automatically on every push to `main` and on tags like `v2026.08.23`).
3. When it finishes (~20–40 min), download the ISO from the workflow **Artifacts**,
   or — if you pushed a tag — from the auto-created **Release**.

That's it. No Docker, no WSL, nothing installed locally.

### Option B — Local build with Docker Desktop

Install [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/), then:

```bash
bash scripts/build-docker.sh
```

The ISO lands in `out/`. (Runs an `archlinux` container that does the whole build.)

### Option C — Local build in WSL2 + Arch

```bash
bash scripts/setup-wsl.sh      # one-time: bootstrap an Arch environment in WSL2
# then, inside the Arch WSL shell, from the repo root:
sudo bash scripts/build-iso.sh
```

Full details, prerequisites, and troubleshooting are in [`docs/BUILDING.md`](docs/BUILDING.md).

---

## 💽 Booting / installing the ISO

- **Try it live:** write the ISO to a USB stick ([Rufus](https://rufus.ie/),
  [balenaEtcher](https://etcher.balena.io/), or `dd`) and boot it. Autologins to the
  `aegis` live user. Default creds: `aegis` / `aegis`.
- **Install to disk:** launch **Install Aegis OS** from the desktop (Calamares).
- **First boot:** run `aegis-setup` (or it opens automatically) to install/authenticate
  the AI agents and pull tool groups.

---

## 🗂️ Repository layout

```
aegis.conf                 # ← single source of truth (name, version, user, repos)
build.sh                   # top-level build dispatcher (auto / docker / native)
scripts/                   # build-iso.sh, build-docker.sh, setup-wsl.sh, lib/
docker/Dockerfile          # Arch build image for local Docker builds
.github/workflows/         # GitHub Actions ISO build + release
profile/                   # the archiso profile
  ├─ profiledef.sh         # ISO metadata & boot modes
  ├─ pacman.conf           # BUILD-time repos (core/extra/blackarch/local aegis)
  ├─ packages.x86_64       # everything installed into the image
  └─ airootfs/             # the live filesystem overlay (branding, services, scripts)
packages/                  # custom aegis-* packages (PKGBUILDs → local repo)
branding/                  # logos, wallpaper, plymouth splash
docs/                      # BUILDING, AI-AGENTS, TOOLS, ETHICS
```

---

## ⚖️ Authorized use only

Aegis OS is a security-testing platform. The tools it ships can cause real harm if
misused. **Only use them against systems you own or have explicit written authorization
to test.** See [`docs/ETHICS.md`](docs/ETHICS.md). Using this software, you accept full
responsibility for your actions and agree to comply with all applicable laws.

---

## 📄 License

Build tooling and Aegis-authored components: **GPL-3.0** (see [`LICENSE`](LICENSE)).
Bundled third-party tools and AI agents retain their own respective licenses.
