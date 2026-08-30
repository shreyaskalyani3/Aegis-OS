!<div align="center">

# 🛡️ Aegis OS

**An Arch Linux–based, agent-native operating system for offensive & defensive security.**

*Codename: Sentinel*

Live + installable ISO · BlackArch arsenal · XFCE · Claude Code · OpenCode · Aider · Codex

<br>

<img src="docs/images/desktop-preview.svg" alt="Aegis OS desktop — XFCE with the Aegis MOTD terminal and the aegis-ai agent launcher" width="92%">

<sub>XFCE 4 · adw-gtk3-dark + Materia decorations + Papirus · the <code>aegis</code> MOTD banner · the <code>aegis-ai</code> launcher · a live <code>nmap -sV</code> scan</sub>

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
| **Desktop** | XFCE 4, dark "Aegis" theme (adw-gtk3-dark GTK + Materia-dark-compact decorations + Papirus-Dark icons), Aegis wallpaper, branded top panel, a **10-category Aegis Tools menu**, an **Install Aegis OS** desktop icon, autologin live user |
| **AI agents** | Claude Code, OpenCode (native Arch pkg), Aider, Codex — unified `aegis-ai` launcher + `aegis-setup` wizard |
| **Runtimes** | Node.js 22, Python + `pipx` + `uv`, Go, Rust, Git, ripgrep — so agents & tools work out of the box |
| **Installer** | Calamares graphical installer — Aegis is **installable to disk**, not just a live CD |
| **Shell** | Zsh + a security-focused prompt, sensible aliases, tmux |

See [`docs/TOOLS.md`](docs/TOOLS.md) for the full toolset and [`docs/AI-AGENTS.md`](docs/AI-AGENTS.md)
for how the agents are integrated.

---

## 🖼️ Look & feel

### The greeter

<div align="center">

<img src="docs/images/login-preview.svg" alt="Aegis OS LightDM greeter — shield avatar, aegis user, Xfce session" width="64%">

<sub>The LightDM greeter (adw-gtk3-dark): shield avatar, the <code>aegis</code> user, Xfce session.</sub>

</div>

### The desktop

The XFCE session is configured **statically**, via xfconf XML shipped in
[`etc/skel/.config/xfce4/`](profile/airootfs/etc/skel/.config/xfce4/). `useradd -m` copies
`/etc/skel` before the first login, so the config is already in place when `xfdesktop` and
`xfce4-panel` first read their channels — the Aegis desktop is what you see on the first frame,
with no flash of stock XFCE and no first-run "Default or Empty panel?" dialog.

| Piece | Ships as | What you get |
|-------|----------|--------------|
| **Top panel** | [`xfce4-panel.xml`](profile/airootfs/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml) | Whisker "Aegis" menu button, launchers for Terminal / Files / Firefox / Aegis Tools / Aegis AI / Install, window buttons, workspace pager, tray, clock, session actions |
| **Aegis Tools menu** | [`aegis-tools.menu`](profile/airootfs/etc/xdg/menus/xfce-applications-merged/aegis-tools.menu) + 10 category files + 73 launchers | Kali-style numbered categories: Information Gathering → Anonymity & Maintenance |
| **Wallpaper** | [`xfce4-desktop.xml`](profile/airootfs/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml) | Sentinel wallpaper, seeded across every common monitor name |
| **Window borders** | [`xfwm4.xml`](profile/airootfs/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml) | `Materia-dark-compact` dark decorations — the only dark xfwm4 theme in the image (see below) |
| **GTK / Qt theming** | [`gtk-3.0/settings.ini`](profile/airootfs/etc/skel/.config/gtk-3.0/settings.ini), [`.gtkrc-2.0`](profile/airootfs/etc/skel/.gtkrc-2.0), [`/etc/environment`](profile/airootfs/etc/environment) | GTK 2/3/4 read the theme directly instead of waiting on `xfsettingsd`; `QT_QPA_PLATFORMTHEME=gtk3` pulls Qt apps (Calamares included) into the same dark theme |
| **Terminal** | [`terminalrc`](profile/airootfs/etc/skel/.config/xfce4/terminal/terminalrc) | GitHub-dark palette, JetBrainsMono Nerd Font, red cursor |
| **Install icon** | [`etc/skel/Desktop/`](profile/airootfs/etc/skel/Desktop/) | **Install Aegis OS** on the desktop, marked trusted by `aegis-live-setup` so XFCE does not warn |
| **Brand icons** | [`hicolor/scalable/apps/`](profile/airootfs/usr/share/icons/hicolor/scalable/apps/) | 14 self-hosted SVGs — every `Icon=` in the profile resolves |

Every menu entry runs through
[`aegis-run`](profile/airootfs/usr/local/bin/aegis-run), which holds the terminal open on exit —
and, when the tool is not in this build's `AEGIS_TOOL_SET`, explains what it is and offers to
install it instead of failing silently. So the menu stays useful on a `lean` image.

### Why the theming is spread across four files

Worth knowing before you change a theme name, because getting this wrong is invisible until you
boot: **XFCE delivers theming over two unrelated channels.** `xfwm4`, `xfce4-panel` and
`xfdesktop` read their xfconf channels directly. GTK does not — it gets its theme over
**XSETTINGS**, broadcast by `xfsettingsd`, so anything starting outside a healthy XFCE session (a
polkit agent, a root GUI, an app launched from a VT) never hears it and renders in stock light
Adwaita. That is why the GTK settings files above are shipped as well as `xsettings.xml`.

Two consequences that are easy to trip over:

- **A GTK theme is not a window-decoration theme.** `adw-gtk-theme` ships `gtk-3.0/` and
  `gtk-4.0/` and **no `xfwm4/` directory at all**, and none of the six themes xfwm4 ships itself
  is dark (`Daloa` is the *blue* one). `materia-gtk-theme` is therefore a hard requirement, not
  a nicety — it is the only source of dark decorations, and of GTK 2, in the image.
- **xfconf accepts any string.** Point it at a theme no package provides and it stores the name
  happily while XFCE falls back to stock light, with nothing logged.

Both are now checked rather than trusted: **check 7** of
[`scripts/dev/check-profile.sh`](scripts/dev/check-profile.sh) fails the lint if any theme or
icon name — in the xfconf XML, the GTK settings files, or the greeter config — has no package
behind it in `packages.x86_64`, or if the xfwm4 theme is one that ships no `xfwm4/` directory.
At runtime, [`aegis-desktop-setup`](profile/airootfs/usr/local/bin/aegis-desktop-setup) re-checks
the same names at login and falls back to the best installed alternative, logging what it did.

### Wallpapers

Aegis ships **four** SVG wallpapers in `/usr/share/backgrounds/aegis/` (they render because
`librsvg` is installed); the red **Sentinel** design is the default for both the desktop and the
greeter ([`lightdm-gtk-greeter.conf`](profile/airootfs/etc/lightdm/lightdm-gtk-greeter.conf)):

| Wallpaper | File | Vibe |
|-----------|------|------|
| **Sentinel** (default) | `aegis-wallpaper.svg` | Red shield emblem, centered wordmark |
| **Matrix** | `aegis-wallpaper-matrix.svg` | Green, faint falling-code columns |
| **Blue Team** | `aegis-wallpaper-blueteam.svg` | Cyan defensive palette |
| **Minimal** | `aegis-wallpaper-minimal.svg` | Small lower-left emblem, lots of negative space |

Switch the desktop from **Settings → Desktop** (or edit the `last-image` values in
`xfce4-desktop.xml`); switch the greeter by editing `background =` in
`lightdm-gtk-greeter.conf`. Multi-head and hotplugged outputs that the static file cannot
predict are caught after login by
[`aegis-desktop-setup`](profile/airootfs/usr/local/bin/aegis-desktop-setup), which only fills in
monitors that are missing or wrong.

> The two images above are hand-drawn SVGs of the shipped design, rendered from the same colors,
> fonts, and layout the profile configures.

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
   (it also runs automatically when you push a tag like `v2026.08.23` — but *not* on a
   plain push to `main`, so ordinary commits never burn a 40-minute build).
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
  `aegis` live user. **Login `aegis` / password `aegis`, and the same password for `root`** —
  see [Live credentials](#-live-credentials) to change them or to debug a login that fails.
- **Install to disk:** double-click **Install Aegis OS** on the desktop, or use the shield
  launcher in the panel. Both run [`aegis-install`](profile/airootfs/usr/local/bin/aegis-install),
  which starts Calamares **with no password prompt** — see [Installing to disk](#-installing-to-disk).
- **Find the tools:** the **Aegis** menu button in the panel → **Aegis Tools** → 10 numbered
  categories. Anything not baked into this build offers to install itself when you launch it.
- **First boot:** run `aegis-setup` (or it opens automatically) to install/authenticate
  the AI agents and pull tool groups.

---

## 💿 Installing to disk

Double-click **Install Aegis OS**. That is the whole procedure — **no password prompt**.

It used to ask for one. The launchers ran `pkexec calamares`, which makes polkit demand an
administrator password before a live ISO will do the one thing a live ISO exists to do. Both
launchers now run [`aegis-install`](profile/airootfs/usr/local/bin/aegis-install) instead, which
fixes two separate problems with that:

| Problem | Fix |
|---|---|
| polkit demanded a password | Escalate through the passwordless `sudo` the live session already has. Belt and braces, `aegis-credentials` also drops a polkit rule granting `wheel` a silent `YES`, so the `pkexec` path — including the stock `calamares.desktop` in the applications menu — stops prompting too. |
| **`pkexec` cannot start X11 programs at all** | `man pkexec` is explicit: it builds a minimal environment and so does not set `$DISPLAY` or `$XAUTHORITY`. A Qt GUI like Calamares has no way to reach the display. `aegis-install` passes both through on every escalation path. |
| Calamares rendered light grey on a dark desktop | `QT_QPA_PLATFORMTHEME=gtk3` in [`/etc/environment`](profile/airootfs/etc/environment) makes Qt follow the GTK theme. |

The polkit rule is **generated at boot, never shipped.** `aegis-credentials` exits at its
`/run/archiso` guard on an installed system, so `/etc/polkit-1/rules.d/49-aegis-live.rules`
physically cannot exist off the live medium — and Calamares deletes it during install anyway
([`shellprocess.conf`](profile/airootfs/etc/calamares/modules/shellprocess.conf)), along with the
live sudoers drop-in and the plaintext credentials file. **An installed Aegis OS authenticates
normally.** If the rule ever fails to write, polkitd ignores the file and you get the prompt back
— it fails safe, not open.

If the installer does not appear, that means `aegis-credentials` did not finish:

```bash
journalctl -u aegis-credentials
```

---

## 🔑 Live credentials

The live medium ships with **`aegis` / `aegis`** for both the `aegis` user and `root`.

Nothing in the SquashFS contains a password — a pacstrapped `/etc/shadow` ships `root`
**locked**, and the profile overlay deliberately carries no `shadow`, `passwd`, or PAM files.
Every credential is created at boot by one small oneshot:

| Piece | Role |
|-------|------|
| [`aegis-credentials`](profile/airootfs/usr/local/bin/aegis-credentials) | Creates the live user, sets both passwords, adds `wheel` + `autologin`, writes passwordless sudo and the live polkit rule. The **only** thing in the image that produces a usable password. |
| [`aegis-credentials.service`](profile/airootfs/etc/systemd/system/aegis-credentials.service) | Ordered `Before=` the greeter, the ttys, and `aegis-live-setup`, with a hard 45 s cap. Does no network I/O, no `locale-gen`, no `systemctl start` — so it has nothing to block on. |
| `/etc/aegis/credentials.conf` | Generated from `aegis.conf` by `scripts/build-iso.sh` (mode `0600`), sourced by the script. Calamares deletes it during install. |

**To change them,** edit `AEGIS_LIVE_PASSWORD` / `AEGIS_ROOT_PASSWORD` in
[`aegis.conf`](aegis.conf) and rebuild — the build refuses to produce an ISO whose
credentials file does not parse back to those exact values, so a password that would have
locked you out fails the build instead of the boot. Any characters work; the file is written
with `printf %q`, so quotes, spaces, `$`, `&`, and backslashes all round-trip.

**If a login ever fails,** switch to a VT (`Ctrl`+`Alt`+`F2`) or open a terminal and read:

```bash
journalctl -u aegis-credentials
```

Every account is verified against `/etc/shadow` after being set and the result is logged, so
that output names the account that failed rather than leaving you guessing. Passwords on the
**installed** system are separate — Calamares sets them, and it removes the live credentials
file, the live sudoers drop-in, the live polkit rule, and both live oneshots on the way out.

---

## 🗂️ Repository layout

```
aegis.conf                 # ← single source of truth (name, version, user, repos)
build.sh                   # top-level build dispatcher (auto / docker / native)
scripts/                   # build-iso.sh, build-docker.sh, setup-wsl.sh, lib/
scripts/dev/               # check-profile.sh (static profile lint), menu/icon generators
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

**Before you spend two hours on a build,** lint the profile — it runs on Windows, needs no Arch,
no Docker and no root, and catches the failures that otherwise only surface after a boot
(malformed XML, `.desktop` files missing keys, `Icon=` names that resolve to nothing, scripts
with no `file_permissions` entry — which would silently ship non-executable):

```bash
bash scripts/dev/check-profile.sh
```

The Aegis Tools menu is generated: the tables at the top of
[`scripts/dev/gen-tools-menu.sh`](scripts/dev/gen-tools-menu.sh) are the single source of truth
for all 73 tool launchers and the 10 category files. Edit the tables, re-run it, then re-run the
linter. Its output is committed, so builds have no dependency on the generator.

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
