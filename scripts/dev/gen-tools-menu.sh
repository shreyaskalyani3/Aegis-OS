#!/usr/bin/env bash
# =============================================================================
#  gen-tools-menu.sh — regenerate the Aegis Tools menu.
#
#  Emits, from the TOOLS/CATEGORIES tables below:
#    profile/airootfs/usr/share/desktop-directories/aegis-NN-<slug>.directory
#    profile/airootfs/usr/share/applications/aegis-tool-<cmd>.desktop
#
#  Output is committed to the repo — the ISO ships static files and builds have
#  no dependency on this script. Run it after editing the tables, then run
#  scripts/dev/check-profile.sh.
#
#  To add a tool: add a TOOLS row. To add a category: add a CATEGORIES row, a
#  case in xdgcat(), an icon in gen-brand-icons.sh, and an <Include> branch in
#  profile/airootfs/etc/xdg/menus/xfce-applications-merged/aegis-tools.menu.
# =============================================================================
set -euo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

APPS="profile/airootfs/usr/share/applications"
DIRS="profile/airootfs/usr/share/desktop-directories"
mkdir -p "$APPS" "$DIRS"

# slug|NN|Display name|BlackArch group suggestion
CATEGORIES='
recon|01|Information Gathering|blackarch-recon
vuln|02|Vulnerability Analysis|blackarch-scanner
web|03|Web Application|blackarch-webapp
passwords|04|Password Attacks|blackarch-cracker
wireless|05|Wireless|blackarch-wireless
exploit|06|Exploitation|blackarch-exploitation
sniffing|07|Sniffing & MITM|blackarch-sniffer
forensics|08|Forensics|blackarch-forensic
reversing|09|Reverse Engineering|blackarch-reversing
maintenance|10|Anonymity & Maintenance|blackarch-defensive
'

# XDG category name per slug (used in Categories= and the .menu file)
xdgcat() {
    case "$1" in
        recon)       echo "X-Aegis-Recon" ;;
        vuln)        echo "X-Aegis-Vuln" ;;
        web)         echo "X-Aegis-Web" ;;
        passwords)   echo "X-Aegis-Passwords" ;;
        wireless)    echo "X-Aegis-Wireless" ;;
        exploit)     echo "X-Aegis-Exploit" ;;
        sniffing)    echo "X-Aegis-Sniffing" ;;
        forensics)   echo "X-Aegis-Forensics" ;;
        reversing)   echo "X-Aegis-Reversing" ;;
        maintenance) echo "X-Aegis-Maintenance" ;;
    esac
}

group_of() { printf '%s' "$CATEGORIES" | awk -F'|' -v s="$1" '$1==s {print $4}'; }

# --- .directory files ---------------------------------------------------------
printf '%s' "$CATEGORIES" | while IFS='|' read -r slug num name _group; do
    [[ -n "$slug" ]] || continue
    cat > "$DIRS/aegis-$num-$slug.directory" <<EOF
[Desktop Entry]
Type=Directory
Version=1.0
Name=$num · $name
Icon=aegis-cat-$slug
EOF
done

# --- tool launchers -----------------------------------------------------------
# cat_slug|command|Display Name|Description|package (blank = same as command)
TOOLS='
recon|nmap|Nmap|Network, port & service scanner|
recon|masscan|Masscan|Internet-scale port scanner|
recon|arp-scan|ARP Scan|Layer-2 host discovery on the local segment|
recon|dnsrecon|DNSRecon|DNS enumeration and zone-transfer checks|
recon|dnsenum|dnsenum|DNS records and subdomain enumeration|
recon|fierce|Fierce|DNS reconnaissance and IP-space scanner|
recon|theHarvester|theHarvester|OSINT e-mail, host and name gathering|theharvester
recon|sublist3r|Sublist3r|Subdomain enumeration via search engines|
recon|whatweb|WhatWeb|Web technology and CMS fingerprinting|
recon|enum4linux|enum4linux|SMB / Windows share and user enumeration|
recon|smbmap|SMBMap|SMB share enumeration and access checks|
recon|smbclient|smbclient|Interactive SMB/CIFS client|
recon|nxc|NetExec|Network & Active Directory protocol toolkit|netexec
recon|whois|whois|Domain and IP registration lookup|
recon|host|host|DNS lookup utility|bind
vuln|nikto|Nikto|Web server vulnerability scanner|
vuln|lynis|Lynis|Local system hardening audit|
vuln|wafw00f|wafw00f|Identify the web application firewall in front of a site|
vuln|sslscan|SSLScan|TLS/SSL cipher, protocol and certificate scanner|
vuln|yara|YARA|Pattern-matching engine for malware IOCs|
vuln|clamscan|ClamAV Scan|On-demand antivirus / malware file scan|clamav
web|sqlmap|sqlmap|Automatic SQL injection detection and exploitation|
web|dirb|dirb|Web content brute-forcer|
web|gobuster|Gobuster|Directory, DNS and vhost brute-forcer|
web|ffuf|ffuf|Fast web fuzzer|
web|wfuzz|Wfuzz|Web application fuzzer|
web|wpscan|WPScan|WordPress vulnerability scanner|
web|mitmproxy|mitmproxy|Interactive HTTPS intercepting proxy|
passwords|hashcat|Hashcat|GPU-accelerated password recovery|
passwords|john|John the Ripper|Offline password cracker|
passwords|hydra|Hydra|Parallel network login brute-forcer|
passwords|hash-identifier|Hash Identifier|Identify the type of a hash|
passwords|hashid|hashID|Identify hash types, including hashcat modes|
passwords|cewl|CeWL|Build a custom wordlist by spidering a site|
passwords|crunch|Crunch|Wordlist generator from a character set and pattern|
wireless|aircrack-ng|Aircrack-ng|WEP and WPA/WPA2-PSK key cracking|
wireless|airodump-ng|Airodump-ng|802.11 packet capture and AP discovery|aircrack-ng
wireless|wifite|Wifite|Automated wireless network auditor|
wireless|reaver|Reaver|WPS PIN recovery attack|
wireless|bully|Bully|WPS brute-force attack|
wireless|mdk4|MDK4|802.11 protocol stress testing|
wireless|hcxdumptool|hcxdumptool|Capture WPA PMKIDs and handshakes|
wireless|hcxpcapngtool|hcxpcapngtool|Convert Wi-Fi captures for hashcat|hcxtools
exploit|msfconsole|Metasploit Console|Exploitation and post-exploitation framework|metasploit
exploit|msfvenom|msfvenom|Payload generator and encoder|metasploit
exploit|searchsploit|SearchSploit|Offline Exploit-DB search|exploitdb
exploit|evil-winrm|Evil-WinRM|WinRM shell for Windows pentesting|
exploit|nc|Netcat|TCP/UDP swiss army knife|openbsd-netcat
exploit|socat|socat|Multipurpose socket relay and tunnel|
sniffing|tshark|TShark|Terminal packet analyser|wireshark-cli
sniffing|tcpdump|tcpdump|Command-line packet capture|
sniffing|bettercap|Bettercap|Network attack and monitoring framework|
sniffing|responder|Responder|LLMNR / NBT-NS / mDNS poisoner|
sniffing|dsniff|dsniff|Password and traffic sniffing suite|
sniffing|tcpreplay|tcpreplay|Replay captured network traffic|
sniffing|iftop|iftop|Live bandwidth usage by connection|
sniffing|nethogs|NetHogs|Live network usage grouped by process|
forensics|binwalk|Binwalk|Firmware image analysis and extraction|
forensics|fls|Sleuth Kit (fls)|List files and directories in a disk image|sleuthkit
forensics|exiftool|ExifTool|Read, write and strip file metadata|perl-image-exiftool
forensics|testdisk|TestDisk|Partition table and boot sector recovery|
forensics|photorec|PhotoRec|File carving and data recovery|testdisk
forensics|dmidecode|dmidecode|Dump hardware / DMI tables|
reversing|r2|Radare2|Reverse engineering and binary analysis framework|radare2
reversing|gdb|GDB|GNU debugger|
reversing|objdump|objdump|Disassembler and object file inspector|binutils
reversing|strace|strace|Trace system calls and signals|
reversing|ltrace|ltrace|Trace library calls|
reversing|nasm|NASM|x86 / x86-64 assembler|
maintenance|macchanger|MAC Changer|Change a network interface MAC address|
maintenance|proxychains4|ProxyChains|Force a program through a proxy chain|proxychains-ng
maintenance|torsocks|Torsocks|Route a single command through Tor|
maintenance|nmtui|Network Manager TUI|Text-mode network configuration|networkmanager
'

count=0
printf '%s' "$TOOLS" | while IFS='|' read -r slug cmd name desc pkg; do
    [[ -n "$slug" ]] || continue
    xcat="$(xdgcat "$slug")"
    grp="$(group_of "$slug")"
    pkgopt=""
    [[ -n "$pkg" ]] && pkgopt="--pkg $pkg "
    # Exec is a single xfce4-terminal invocation. Both --title and --command take
    # one argument each, so each is double-quoted as a whole (desktop-entry spec
    # quoting). Inside --command, --desc uses single quotes, which xfce4-terminal
    # resolves when it shell-splits the value -- so no description may contain an
    # apostrophe.
    cat > "$APPS/aegis-tool-$cmd.desktop" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=$name
GenericName=$desc
Comment=$desc
Exec=xfce4-terminal --title="$name" --command="aegis-run ${pkgopt}--group $grp --desc '$desc' $cmd"
Icon=aegis-cat-$slug
Terminal=false
StartupNotify=false
Categories=$xcat;
Keywords=security;aegis;$cmd;
EOF
    count=$((count+1))
done

echo "directories: $(ls -1 "$DIRS" | wc -l)"
echo "tool launchers: $(ls -1 "$APPS"/aegis-tool-*.desktop | wc -l)"
