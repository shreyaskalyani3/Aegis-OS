# 🛡️ Aegis OS — Official Operator & Field Manual
*Codename: Sentinel*

Welcome to the official documentation and field manual for **Aegis OS**. This manual provides comprehensive operational guidance for security analysts, penetration testers, red/blue teams, and security researchers operating on Aegis OS.

---

## 📑 Table of Contents

1. [Introduction & System Architecture](#1-introduction--system-architecture)
   - [Core Philosophy](#core-philosophy)
   - [Comparison: Aegis OS vs. Kali vs. Parrot vs. BlackArch](#comparison-aegis-os-vs-kali-vs-parrot-vs-blackarch)
   - [System Specs & Layered Architecture](#system-specs--layered-architecture)
2. [Getting Started & Installation](#2-getting-started--installation)
   - [Live Boot & USB Flashing](#live-boot--usb-flashing)
   - [Live Credentials](#live-credentials)
   - [Installing to Disk with Calamares](#installing-to-disk-with-calamares)
   - [Offline Kernel Cache Architecture](#offline-kernel-cache-architecture)
3. [Desktop Environment & Interface](#3-desktop-environment--interface)
   - [XFCE 4 "Sentinel" Customization](#xfce-4-sentinel-customization)
   - [Theming Stack (GTK 2/3/4, XFWM4, Papirus)](#theming-stack)
   - [Terminal Experience & Fastfetch](#terminal-experience--fastfetch)
   - [The Aegis Tools Menu](#the-aegis-tools-menu)
   - [The `aegis-run` Dynamic Launcher](#the-aegis-run-dynamic-launcher)
4. [The Security Arsenal](#4-the-security-arsenal)
   - [10 Categorized Tool Groups](#10-categorized-tool-groups)
   - [Managing Tools with `aegis-tools`](#managing-tools-with-aegis-tools)
   - [BlackArch Repository Management](#blackarch-repository-management)
   - [Tiered Deployment (`lean` / `broad` / `full`)](#tiered-deployment-lean--broad--full)
5. [Agent-Native AI Integration](#5-agent-native-ai-integration)
   - [Why Agent-Native?](#why-agent-native)
   - [Supported AI Coding Agents](#supported-ai-coding-agents)
   - [First-Boot Setup (`aegis-setup`)](#first-boot-setup-aegis-setup)
   - [Unified Launcher (`aegis-ai`)](#unified-launcher-aegis-ai)
   - [API Key Security & Sudo Pass-Through](#api-key-security--sudo-pass-through)
   - [Practical Security Workflows with AI](#practical-security-workflows-with-ai)
6. [Networking, OPSEC & Anonymity](#6-networking-opsec--anonymity)
   - [Network Configuration](#network-configuration)
   - [Anonymity Stack (Tor, Proxychains, Macchanger)](#anonymity-stack)
   - [Packet Sniffing & MITM Safety](#packet-sniffing--mitm-safety)
7. [Virtualization & Hardware Optimization](#7-virtualization--hardware-optimization)
   - [VMware (open-vm-tools)](#vmware)
   - [VirtualBox (guest-utils)](#virtualbox)
   - [KVM / QEMU (spice-vdagent)](#kvm--qemu)
   - [Hyper-V](#hyper-v)
8. [Customization & ISO Compilation](#8-customization--iso-compilation)
   - [Central Config (`aegis.conf`)](#central-config-aegisconf)
   - [Creating Custom Metapackages (`packages/`)](#creating-custom-metapackages)
   - [Filesystem Overlays (`profile/airootfs/`)](#filesystem-overlays)
   - [Profile Linter (`check-profile.sh`)](#profile-linter-check-profilesh)
   - [Build Methods (GitHub Actions, Docker, WSL2, Native)](#build-methods)
9. [Ethics, Legal Scope & Rules of Engagement](#9-ethics-legal-scope--rules-of-engagement)

---

## 1. Introduction & System Architecture

### Core Philosophy
Aegis OS is an **Arch Linux–based rolling-release operating system** built for offensive and defensive security operations. It bridges the gap between traditional security distributions and the modern era of **Agentic AI**.

Traditional security distributions provide hundreds of disconnected tools leaving the operator to manually glue them together with bash scripts. Aegis OS natively integrates **autonomous AI coding agents** as standard system utilities, allowing operators to script exploits, parse telemetry, generate proof-of-concept exploits, and triage vulnerabilities at machine speed.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Aegis OS System Stack                           │
├────────────────────────────────────────────────────────────────────────┤
│ Application:  Aegis Tools (2,800+ BlackArch) · AI Agents (Claude/Codex)│
│ Desktop:      XFCE 4 · Adw-GTK3-Dark · Materia-Dark-Compact · Papirus │
│ Display:      Xorg Server · LightDM Greeter · PipeWire Audio           │
│ Kernel:       Arch Linux Kernel · mkinitcpio initramfs · systemd       │
│ Base:         Arch Linux (Rolling Release) · Pacman Package Manager    │
└────────────────────────────────────────────────────────────────────────┘
```

---

### Comparison: Aegis OS vs. Kali vs. Parrot vs. BlackArch

| Feature | Kali Linux | Parrot Security | BlackArch Linux | **Aegis OS** |
| :--- | :--- | :--- | :--- | :--- |
| **Base Distro** | Debian Testing | Debian Testing | Arch Linux | **Arch Linux (Rolling)** |
| **Package Engine** | `apt` | `apt` | `pacman` | **`pacman` + Local `[aegis]` repo** |
| **Release Model** | Point releases | Rolling/Hybrid | True Rolling | **True Rolling Release** |
| **Security Arsenal** | ~600 curated tools | ~600 curated tools | 2,800+ tools | **Curated core + 2,800+ BlackArch** |
| **AI Integration** | None | None | None | **Native (`aegis-ai`, `aegis-setup`)** |
| **Tool Delivery** | Monolithic sets | Home vs. Security | Monolithic (20GB+) | **Tiered (`lean` / `broad` / `full`)** |
| **Dynamic Runner** | Standard exec | Standard exec | Standard exec | **`aegis-run` (auto-install + output pause)** |
| **Installer** | Calamares / Debian | Calamares | Custom CLI | **Calamares (passwordless, offline kernel)**|

---

### System Specs & Layered Architecture

- **Kernel**: Standard mainline `linux` with `linux-firmware` and `linux-headers`.
- **Init System**: `systemd` with customized initialization targets.
- **Audio Stack**: `pipewire`, `wireplumber`, and `pavucontrol`.
- **Guest Additions**: Universal support for VMware, VirtualBox, QEMU/KVM, and Hyper-V.
- **Development Toolchains**: Pre-baked Node.js 22, Python 3, `pipx`, `uv`, Go, Rust (`rustup`), Git, and build essentials.

---

## 2. Getting Started & Installation

### Live Boot & USB Flashing

Aegis OS generates a standard hybrid ISO that boots on both **UEFI (GPT)** and **Legacy BIOS (MBR)** systems.

1. **Verify Integrity**:
   Verify the SHA256 checksum of your downloaded ISO:
   ```bash
   sha256sum -c aegis-*.iso.sha256
   ```

2. **Flashing Media**:
   - **Linux / macOS**:
     ```bash
     sudo dd if=aegis-2026.XX.YY-x86_64.iso of=/dev/sdX bs=4M status=progress oflag=sync
     ```
   - **Windows**: Use [Rufus](https://rufus.ie/) (in *DD Image* mode) or [balenaEtcher](https://etcher.balena.io/).

---

### Live Credentials

The live environment automatically logs into the desktop. If prompted or switching to virtual terminals (`Ctrl + Alt + F2`):

| Account | Default Username | Default Password | Privileges |
| :--- | :--- | :--- | :--- |
| **Live User** | `aegis` | `aegis` | Sudo (passwordless in live), `wheel`, `autologin` |
| **Root User** | `root` | `aegis` | Full administrative root |

> [!NOTE]
> Passwords in the live system are dynamically generated at boot time by `aegis-credentials` from [aegis.conf](../aegis.conf). They are removed when Aegis is installed to disk.

---

### Installing to Disk with Calamares

To permanently install Aegis OS to your hard drive or SSD:

1. Double-click the **Install Aegis OS** icon on the desktop, or click the shield icon in the top panel.
2. The launcher calls `aegis-install`:
   - Bypasses password prompts automatically via live privilege escalation.
   - Forwards `$DISPLAY` and `$XAUTHORITY` so Qt/Calamares renders seamlessly.
   - Sets `QT_QPA_PLATFORMTHEME=gtk3` so the installer matches the dark desktop theme.
3. Follow the graphical Calamares wizard:
   - Select timezone, keyboard layout, and disk partitioning (Erase disk or manual partition).
   - Enter your personal username and password for the installed machine.
4. Click **Install**. Reboot when finished and remove the USB drive.

---

### Offline Kernel Cache Architecture

Traditional `archiso` live builds delete `/boot/vmlinuz-linux` during SquashFS compression, causing offline Calamares installations to fail with missing kernel errors.

Aegis OS implements the **offline kernel cache pattern**:
- Kernel packages (`linux`, `intel-ucode`, `amd-ucode`, `grub`, `mkinitcpio`) are pre-cached in `/usr/share/aegis/packages`.
- During installation, Calamares executes `pacman -U` locally inside the target chroot.
- Result: **Aegis OS installs completely offline without requiring an internet connection.**

---

## 3. Desktop Environment & Interface

### XFCE 4 "Sentinel" Customization

Aegis OS runs a low-latency, highly customized **XFCE 4** desktop configured statically via xfconf XML in `/etc/skel/.config/xfce4/`.

- **First-Frame Consistency**: Configuration is copied by `useradd -m` before session start. No "Empty or Default panel" prompts ever appear.
- **Top Panel**:
  - **Aegis Whisker Menu**: Fast searchable launcher.
  - **Quick Launchers**: Terminal, File Manager (Thunar), Web Browser (Firefox), Aegis Tools, Aegis AI, Install to Disk.
  - **Workspace Switcher & System Tray**: NetworkManager applet, audio control, power management, clock.

---

### Theming Stack

| Component | Theme / Resource | Why Selected |
| :--- | :--- | :--- |
| **GTK 3 & GTK 4** | `adw-gtk3-dark` | Modern Libadwaita dark look for modern apps |
| **Window Borders (xfwm4)** | `Materia-dark-compact` | Provides clean dark titlebars that Adwaita lacks |
| **GTK 2 Apps** | `Materia-dark-compact` | Seamless dark styling for legacy tools |
| **Icon Theme** | `Papirus-Dark` | Clear, high-contrast monochrome and colored icons |
| **Qt Apps** | `QT_QPA_PLATFORMTHEME=gtk3` | Forces Calamares, Wireshark, etc. to adhere to dark theme |
| **Monospace Font** | `JetBrainsMono Nerd Font` | Optimized for code legibility and CLI glyphs |

---

### Terminal Experience & Fastfetch

Opening the terminal launches a styled **Alacritty** or **XFCE Terminal** session:
- **Font**: JetBrainsMono Nerd Font (11pt).
- **Color Palette**: GitHub Dark with high-contrast red cursor.
- **Shell**: `zsh` with Oh My Zsh pre-vendored into `/usr/share/oh-my-zsh`.
- **MOTD**: Dynamic `aegis-motd` displaying system stats, IP addresses, active interfaces, and ASCII Sentinel shield.
- **Fastfetch**: Custom Aegis OS configuration displaying hardware, kernel, memory, and desktop stats.

---

### The Aegis Tools Menu

The application menu features a categorized Kali-style structure accessible via **Whisker Menu → Aegis Tools**:

```
Aegis Tools
├── 01. Information Gathering
├── 02. Vulnerability Analysis
├── 03. Web Application Analysis
├── 04. Password & Credential Attacks
├── 05. Wireless Attacks
├── 06. Exploitation Frameworks
├── 07. Sniffing & Spoofing
├── 08. Digital Forensics & Incident Response
├── 09. Reverse Engineering & Malware Analysis
└── 10. Maintaining Access & Anonymity
```

---

### The `aegis-run` Dynamic Launcher

Every menu entry is wrapped by [`aegis-run`](../profile/airootfs/usr/local/bin/aegis-run):
1. **Output Preservation**: Standard terminals close the moment a CLI command exits. `aegis-run` displays a clean header and pauses with `── press any key to close ──`, preventing lost output.
2. **Dynamic Installation**: If a tool was omitted from the current ISO tier (e.g. `lean`), clicking the menu entry will not fail silently. Instead, `aegis-run` explains what the tool is and offers to install it via `pacman`:
   ```text
   🛡  nikto  Web vulnerability scanner
   ────────────────────────────────────────────────────────
   nikto is not installed in this image.
   Aegis bakes in a subset of the arsenal (AEGIS_TOOL_SET); the rest
   installs on demand from the Arch and BlackArch repositories.

     package: nikto   group: blackarch-webapp

   Install it now with pacman? [Y/n]
   ```

---

## 4. The Security Arsenal

### 10 Categorized Tool Groups

The Aegis OS arsenal spans the entire offensive and defensive security lifecycle:

#### 1. Information Gathering & OSINT
- `nmap`, `masscan`, `arp-scan`, `theHarvester`, `sublist3r`, `dnsrecon`, `dnsenum`, `fierce`, `whois`, `bind` (dig).

#### 2. Vulnerability Analysis
- `nikto`, `lynis`, `sslscan`, `nxc` (NetExec), `enum4linux`, `yara`.

#### 3. Web Application Analysis
- `sqlmap`, `gobuster`, `ffuf`, `wfuzz`, `wpscan`, `whatweb`, `wafw00f`, `mitmproxy`.

#### 4. Password & Credential Recovery
- `hashcat`, `john` (John the Ripper), `hydra`, `seclists`, `crunch`, `cewl`, `hash-identifier`, `hashid`.

#### 5. Wireless & Radio Frequency
- `aircrack-ng`, `wifite`, `hcxtools`, `hcxdumptool`, `reaver`, `bully`, `mdk4`.

#### 6. Exploitation Frameworks
- `metasploit` (`msfconsole`, `msfvenom`), `searchsploit` (`exploitdb`), `impacket`, `responder`, `evil-winrm`.

#### 7. Sniffing & Man-in-the-Middle
- `wireshark` (GUI & CLI), `tshark`, `tcpdump`, `bettercap`, `dsniff`, `tcpreplay`, `iftop`, `nethogs`.

#### 8. Digital Forensics & Incident Response (DFIR)
- `sleuthkit`, `binwalk`, `photorec`, `testdisk`, `exiftool`, `clamav`.

#### 9. Reverse Engineering & Binary Analysis
- `radare2`, `gdb`, `nasm`, `objdump`, `strace`, `ltrace`.

#### 10. Maintaining Access, Anonymity & Defense
- `tor`, `torsocks`, `proxychains-ng`, `macchanger`, `socat`, `openbsd-netcat`, `nftables`.

---

### Managing Tools with `aegis-tools`

The CLI tool [`aegis-tools`](../profile/airootfs/usr/local/bin/aegis-tools) (alias: `tools`) enables instant exploration and management of the BlackArch repository:

```bash
# View curated categories with descriptions
tools categories

# Install an entire tool category
tools install blackarch-webapp blackarch-scanner

# Search across all Arch and BlackArch repositories
tools search burp

# Inspect what packages exist in a category
tools info blackarch-forensic

# Count total available security tools
tools count

# Install the entire 2,800+ tool collection (confirms first)
tools full
```

---

### Tiered Deployment (`lean` / `broad` / `full`)

Configured via `AEGIS_TOOL_SET` in [aegis.conf](../aegis.conf):

- **`lean` (~4 GB ISO)**:
  Contains the curated always-on toolset. Best for fast USB boots, constrained environments, or CI/CD pipelines.
- **`broad` (~8–16 GB ISO, Default)**:
  Curated core **+ 17 full BlackArch category groups**. Covers 99% of pentesting engagements out of the box.
- **`full` (~15–25 GB ISO)**:
  Downloads and bakes the entire BlackArch arsenal (~2,800 packages) into the ISO. Requires a local Linux machine with >120 GB free space.

---

## 5. Agent-Native AI Integration

### Why Agent-Native?
In modern security testing, rapid analysis of unstructured data is critical. Aegis OS treats AI coding assistants as first-class CLI utilities, allowing operators to:
- Generate target-specific Python exploit scripts.
- Parse complex Nmap XML or Masscan JSON files into actionable targets.
- Disassemble unfamiliar binary formats with Radare2 and explain assembly instructions.
- Automate remediation reports directly into Markdown.

---

### Supported AI Coding Agents

| Agent | Command | Primary Strength | Model Backend |
| :--- | :--- | :--- | :--- |
| **Claude Code** | `claude` | Deep reasoning, codebase-wide refactoring, complex exploit PoCs | Anthropic Claude 3.5 Sonnet / Opus |
| **OpenCode** | `opencode` | Open-source multi-model client, local/custom endpoints | Multi-provider (OpenAI, Anthropic, Ollama, OpenRouter) |
| **Aider** | `aider` | Git-native pair programming in the terminal | Anthropic, OpenAI, DeepSeek, OpenRouter |
| **Codex CLI** | `codex` | Rapid code completion and shell scripting | OpenAI GPT-4o / Codex |

---

### First-Boot Setup (`aegis-setup`)

On first login, launch the guided wizard (alias: `setup`):
```bash
setup
```

The wizard handles:
1. **Authorized Use Agreement**: Confirms adherence to ethical guidelines.
2. **Network Verification**: Checks Internet and DNS connectivity.
3. **Agent Installation**: Installs Claude Code, Aider, OpenCode, and Codex CLI to `~/.local/bin/`.
4. **Credential Vault**: Securely captures API keys (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, etc.) and writes them to `~/.config/aegis/env` (mode `0600`).
5. **Interactive Login**: Initiates browser-based OAuth logins for Claude Code or Codex.

---

### Unified Launcher (`aegis-ai`)

Use `aegis-ai` (alias: `ai`) to manage and launch agents:

```bash
# Launch interactive picker
ai

# Run a specific agent directly
ai claude
ai opencode
ai aider
ai codex

# Check installation and auth status of all agents
ai list

# Install all supported agents at once
ai install all
```

---

### API Key Security & Sudo Pass-Through

- API keys stored in `~/.config/aegis/env` are automatically sourced by both Bash and Zsh.
- Sudo operations drop user environment variables by default. To allow agents to run privileged network commands when needed, `/etc/sudoers.d/10-aegis` includes `env_keep`:
  ```sudoers
  Defaults env_keep += "ANTHROPIC_API_KEY OPENAI_API_KEY OPENROUTER_API_KEY GEMINI_API_KEY"
  ```

---

### Practical Security Workflows with AI

#### Example 1: Parsing Nmap Scans
```bash
nmap -sV -sC -oX scan.xml 192.168.1.0/24
ai claude -p "Analyze scan.xml, identify the top 3 vulnerable services, and write a Python script to verify if they are exploitable."
```

#### Example 2: Reverse Engineering with Radare2
```bash
r2 -qc "aaa; pdf @main" ./target_binary > main.asm
ai aider --message "Explain the control flow in main.asm and identify where the buffer overflow occurs."
```

---

## 6. Networking, OPSEC & Anonymity

### Network Configuration
- **NetworkManager**: Manages Ethernet, Wi-Fi, and cellular interfaces. Includes tray applet `nm-applet` and terminal UI `nmtui`.
- **DHCP**: Handled entirely through NetworkManager's internal client. Redundant DHCP daemons (`dhcpcd`) are omitted to eliminate IP allocation race conditions.

---

### Anonymity Stack

#### MAC Address Spoofing (`macchanger`)
Randomize your physical network interface before connecting to untrusted networks:
```bash
sudo ip link set wlan0 down
sudo macchanger -r wlan0
sudo ip link set wlan0 up
```

#### Tor & Torsocks
Start the Tor daemon and route individual CLI tools through the Onion network:
```bash
sudo systemctl start tor
torsocks curl https://check.torproject.org/api/ip
torsocks nmap -sT -PN -p 80,443 example.com
```

#### Proxychains-NG
Chain multiple SOCKS4, SOCKS5, or HTTP proxies configured in `/etc/proxychains.conf`:
```bash
proxychains4 nmap -sT -PN 10.10.10.10
```

---

## 7. Virtualization & Hardware Optimization

Aegis OS detects hypervisors at boot time and enables corresponding background daemons:

### VMware
- **Packages**: `open-vm-tools`
- **Features**: Automatic screen resizing, bidirectional clipboard sharing, host-guest folder mounting.
- **Service**: `vmtoolsd.service`

### VirtualBox
- **Packages**: `virtualbox-guest-utils`
- **Features**: Shared clipboard, seamless window mode, auto-mounting shared folders.
- **Service**: `vboxservice.service`

### KVM / QEMU
- **Packages**: `qemu-guest-agent`, `spice-vdagent`
- **Features**: Dynamic resolution switching in Virt-Manager, copy-paste across host and guest.

### Hyper-V
- **Packages**: `hyperv`
- **Features**: Hyper-V VMBus integration, synthetic network adapter support.

---

## 8. Customization & ISO Compilation

### Central Config (`aegis.conf`)

[aegis.conf](../aegis.conf) is the single source of truth for all build parameters:
```bash
AEGIS_NAME="Aegis OS"
AEGIS_CODENAME="Sentinel"
AEGIS_LIVE_USER="aegis"
AEGIS_LIVE_PASSWORD="your-custom-password"
AEGIS_TOOL_SET="broad"           # lean | broad | full
AEGIS_ENABLE_BLACKARCH=1
```

---

### Profile Linter (`check-profile.sh`)

Before initiating a 30+ minute ISO build, validate the entire codebase:
```bash
bash scripts/dev/check-profile.sh
```
Checks performed:
1. XML & SVG well-formedness (xfconf, panels, icons).
2. Desktop launcher syntax and mandatory keys (`Type`, `Name`, `Exec`, `Icon`).
3. Category cross-referencing between menus and `.desktop` files.
4. Shell script syntax validation (`bash -n`).
5. File permissions in `profiledef.sh` (ensures scripts are executable).
6. Theme and icon package resolution.

---

### Build Methods

#### Option A: GitHub Actions (Recommended)
1. Push repository to GitHub.
2. Go to **Actions** → **Build Aegis OS ISO** → **Run workflow**.
3. Download the resulting `.iso` from the workflow artifacts.

#### Option B: Docker Desktop
```bash
bash scripts/build-docker.sh
```

#### Option C: WSL2 + Arch
```bash
bash scripts/setup-wsl.sh
# Inside Arch WSL:
sudo bash scripts/build-iso.sh
```

---

## 9. Ethics, Legal Scope & Rules of Engagement

> [!CAUTION]
> Aegis OS bundles security testing tools capable of network disruption, credential extraction, and system penetration.

- **Explicit Written Authorization**: Never perform scans, penetration tests, or vulnerability assessments against systems without written permission from the system owner.
- **Scope Adherence**: Always respect agreed-upon boundaries, testing windows, and IP exclusions.
- **Confidentiality**: Protect client vulnerability data and never paste proprietary target data into third-party AI models without explicit authorization.

For full guidelines, see [docs/ETHICS.md](ETHICS.md).
