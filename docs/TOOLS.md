# The Aegis OS Security Arsenal

Aegis draws on the official Arch repositories plus
[BlackArch](https://blackarch.org) (2800+ tools). To keep the ISO a sane size,
the image ships a **curated always-on set** and lets you pull the rest **on
demand** with `aegis-tools`.

---

## How much is baked into the ISO

`AEGIS_TOOL_SET` (in [`aegis.conf`](../aegis.conf)) chooses how much of the
arsenal ships **inside** the image. Whatever isn't baked in stays one command
away with `aegis-tools`.

| Tier | What's baked in | Approx. ISO |
|---|---|---|
| `lean` | Curated always-on core only | ~4 GB |
| **`broad`** (default) | Curated core **+ all major BlackArch category groups** | ~8–16 GB |
| `full` | The entire `blackarch` group (~2800 tools) | ~15–25 GB\* |

> \* `full` will **not** build on GitHub Actions (out of disk/time) — build it on
> a local Linux host or VM with ~120 GB free disk. `lean`/`broad` build in CI.

### The always-on core (present in every tier)

A hand-picked set covering the common phases of an engagement:

- **Recon / scanning:** `nmap`, `masscan`, `arp-scan`, `whois`, `bind` (dig)
- **Web:** `sqlmap`, `mitmproxy`
- **Network / MITM:** `wireshark`, `tcpdump`, `socat`, `netcat`, `tcpreplay`, `iftop`, `nethogs`
- **Wireless:** `aircrack-ng`, `hcxtools`, `hcxdumptool`
- **Credentials:** `hashcat`, `john`, `hydra`
- **Exploitation:** `metasploit`
- **Reversing / forensics:** `radare2`, `gdb`, `binwalk`, `sleuthkit`, `yara`, `exiftool`
- **Defensive:** `lynis`, `clamav`
- **Anonymity:** `tor`, `torsocks`, `proxychains-ng`, `macchanger`

Plus a curated slice of popular BlackArch tools (`nikto`, `gobuster`, `ffuf`,
`wpscan`, `netexec`, `impacket`, `responder`, `bettercap`, `seclists`, …) when
BlackArch is enabled.

### The `broad` default — major categories baked in

With the default `broad` tier, `build-iso.sh` also bakes in these whole BlackArch
category groups (from `AEGIS_BLACKARCH_GROUPS` in `aegis.conf`):

`blackarch-scanner` · `blackarch-recon` · `blackarch-webapp` · `blackarch-fuzzer` ·
`blackarch-exploitation` · `blackarch-cracker` · `blackarch-wireless` ·
`blackarch-sniffer` · `blackarch-proxy` · `blackarch-forensic` ·
`blackarch-reversing` · `blackarch-crypto` · `blackarch-windows` ·
`blackarch-defensive` · `blackarch-malware` · `blackarch-mobile` · `blackarch-social`

Edit that list to add still more (e.g. `blackarch-networking`, `blackarch-database`,
`blackarch-voip`) or trim it for a smaller image. DoS and self-propagating
"backdoor" groups are deliberately left out of the default — still installable
post-boot for authorized use.

The exact package list is [`profile/packages.x86_64`](../profile/packages.x86_64);
its guarded `AEGIS_BLACKARCH_ONLY` block and the appended groups are present only
when built with `AEGIS_ENABLE_BLACKARCH=1` (the default).

---

## Installing more with `aegis-tools`

`tools` is an alias for `aegis-tools`.

```bash
tools categories            # curated categories you can install
tools install <group...>    # install one or more groups
tools groups                # list ALL BlackArch groups
tools info <group>          # show the packages in a group
tools search <keyword>      # search every repo for a tool
tools count                 # how many BlackArch tools are available
tools full                  # install the ENTIRE arsenal (asks for confirmation)
```

Examples:

```bash
tools install blackarch-scanner blackarch-webapp
tools install blackarch-wireless
tools search burp
tools info blackarch-exploitation
```

### Curated categories

| Group | Focus |
|---|---|
| `blackarch-scanner` | Network & vulnerability scanners |
| `blackarch-recon` | Reconnaissance & OSINT |
| `blackarch-webapp` | Web application testing |
| `blackarch-fuzzer` | Fuzzers |
| `blackarch-exploitation` | Exploitation frameworks & helpers |
| `blackarch-cracker` | Password & hash cracking |
| `blackarch-wireless` | Wi-Fi / Bluetooth / RF |
| `blackarch-sniffer` | Sniffers & MITM |
| `blackarch-proxy` | Intercepting proxies & tunnelers |
| `blackarch-forensic` | DFIR |
| `blackarch-reversing` | Reverse engineering |
| `blackarch-crypto` | Cryptography & steganography |
| `blackarch-malware` | Malware analysis |
| `blackarch-mobile` | Mobile assessment |
| `blackarch-social` | Social engineering |
| `blackarch-windows` | Windows / Active Directory |
| `blackarch-defensive` | Blue-team utilities |

> `aegis-tools` deliberately omits denial-of-service and self-propagating
> "backdoor" categories from the curated menu. They remain installable via raw
> `pacman -S <group>` for legitimate, authorized testing — the omission is about
> not steering users toward disruptive tooling by default, not about blocking it.

---

## Persistence

Tools installed in the **live** session live in RAM/overlay and vanish on
reboot. Install Aegis to disk (see [BUILDING.md](BUILDING.md#installing-to-disk))
for a persistent workstation, then `tools install …` sticks.

---

## Keeping current

```bash
update          # sudo pacman -Syu   (updates the system + installed tools)
```

BlackArch is a rolling repo layered on Arch; keep the whole system updated
together to avoid partial-upgrade breakage.
