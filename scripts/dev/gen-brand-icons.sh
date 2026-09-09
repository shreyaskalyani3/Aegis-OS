#!/usr/bin/env bash
# =============================================================================
#  gen-brand-icons.sh — regenerate the Aegis category icons.
#
#  Output is committed to the repo; run this only when changing the brand art.
#  The emblem geometry and palette come from
#  profile/airootfs/usr/share/backgrounds/aegis/aegis-wallpaper.svg, so icons and
#  wallpaper stay visually consistent.
#
#  The four app icons (aegis, aegis-tools, aegis-ai, aegis-install) are
#  hand-authored, not generated here.
# =============================================================================
set -euo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="profile/airootfs/usr/share/icons/hicolor/scalable/apps"
mkdir -p "$OUT"

emit() {  # $1 = slug, $2 = comment, $3 = glyph svg
    cat > "$OUT/aegis-cat-$1.svg" <<SVG
<?xml version="1.0" encoding="UTF-8"?>
<!-- Aegis OS — $2 category icon. -->
<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
  <defs>
    <linearGradient id="a" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#ff3355"/><stop offset="100%" stop-color="#b3122e"/>
    </linearGradient>
  </defs>
  <rect x="3" y="3" width="42" height="42" rx="10" fill="#131a24" stroke="#2a3542" stroke-width="1.5"/>
  <rect x="3" y="3" width="42" height="42" rx="10" fill="url(#a)" opacity="0.10"/>
$3
</svg>
SVG
}

emit recon "Information Gathering (magnifier over a scanned grid)" '  <g fill="none" stroke="#8b98a5" stroke-width="1.2" opacity="0.55">
    <path d="M12 14h24M12 20h24M12 26h24M12 32h24"/>
  </g>
  <circle cx="21" cy="21" r="8.5" fill="#0d1117" fill-opacity="0.85" stroke="#f0f6fc" stroke-width="2.6"/>
  <path d="M27.5 27.5 L36 36" stroke="#ff2e4d" stroke-width="3.6" stroke-linecap="round"/>'

emit vuln "Vulnerability Analysis (breached shield)" '  <path d="M24 8 L37 13 V25 C37 33 31 38 24 41 C17 38 11 33 11 25 V13 Z"
        fill="none" stroke="#f0f6fc" stroke-width="2.6" stroke-linejoin="round"/>
  <path d="M24 8 V19 L19 23 L27 27 L22 41" fill="none" stroke="#ff2e4d" stroke-width="2.8"
        stroke-linecap="round" stroke-linejoin="round"/>'

emit web "Web Application (globe in angle brackets)" '  <circle cx="24" cy="24" r="11" fill="none" stroke="#f0f6fc" stroke-width="2.4"/>
  <path d="M13 24h22M24 13c4 5 4 17 0 22M24 13c-4 5-4 17 0 22" fill="none" stroke="#8b98a5" stroke-width="1.6"/>
  <path d="M11 15 L6 24 L11 33 M37 15 L42 24 L37 33" fill="none" stroke="#ff2e4d" stroke-width="2.6"
        stroke-linecap="round" stroke-linejoin="round"/>'

emit passwords "Password Attacks (key)" '  <circle cx="18" cy="18" r="8" fill="none" stroke="#ff2e4d" stroke-width="3.2"/>
  <path d="M23.5 23.5 L37 37" stroke="#f0f6fc" stroke-width="3.4" stroke-linecap="round"/>
  <path d="M31 31 L27 35 M35 27 L31 31" stroke="#f0f6fc" stroke-width="3.4" stroke-linecap="round"/>'

emit wireless "Wireless (broadcast arcs)" '  <g fill="none" stroke="#f0f6fc" stroke-width="2.8" stroke-linecap="round">
    <path d="M13 27 a14 14 0 0 1 22 0"/>
    <path d="M18 32 a8.5 8.5 0 0 1 12 0"/>
  </g>
  <circle cx="24" cy="37" r="3.6" fill="#ff2e4d"/>'

emit exploit "Exploitation (detonation burst)" '  <circle cx="22" cy="28" r="9" fill="none" stroke="#f0f6fc" stroke-width="2.6"/>
  <path d="M28 22 L34 16" stroke="#f0f6fc" stroke-width="2.6" stroke-linecap="round"/>
  <g stroke="#ff2e4d" stroke-width="2.4" stroke-linecap="round">
    <path d="M34 16 L38 12"/><path d="M36 20 L41 19"/><path d="M30 11 L31 6"/>
  </g>
  <circle cx="38" cy="12" r="3" fill="#ff2e4d"/>'

emit sniffing "Sniffing and MITM (intercepted signal)" '  <path d="M6 24 L12 24 L15 14 L19 34 L23 18 L27 30 L30 24 L42 24"
        fill="none" stroke="#f0f6fc" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="24" cy="24" r="5.5" fill="#131a24" stroke="#ff2e4d" stroke-width="2.6"/>'

emit forensics "Forensics (fingerprint)" '  <g fill="none" stroke="#f0f6fc" stroke-width="2.2" stroke-linecap="round">
    <path d="M24 10 a13 13 0 0 1 13 13 v4"/>
    <path d="M24 10 a13 13 0 0 0 -13 13 v4"/>
    <path d="M24 16 a7.5 7.5 0 0 1 7.5 7.5 v8"/>
    <path d="M24 16 a7.5 7.5 0 0 0 -7.5 7.5 v8"/>
  </g>
  <path d="M24 22 v14" stroke="#ff2e4d" stroke-width="2.8" stroke-linecap="round"/>'

emit reversing "Reverse Engineering (chip)" '  <rect x="15" y="15" width="18" height="18" rx="3" fill="none" stroke="#f0f6fc" stroke-width="2.4"/>
  <rect x="21" y="21" width="6" height="6" fill="#ff2e4d"/>
  <g stroke="#8b98a5" stroke-width="2" stroke-linecap="round">
    <path d="M20 15 V9 M28 15 V9 M20 33 V39 M28 33 V39"/>
    <path d="M15 20 H9 M15 28 H9 M33 20 H39 M33 28 H39"/>
  </g>'

emit maintenance "Anonymity and Maintenance (mask over gear teeth)" '  <path d="M11 20 h26 a0 0 0 0 1 0 0 c0 9 -6 14 -13 14 c-7 0 -13 -5 -13 -14 z"
        fill="none" stroke="#f0f6fc" stroke-width="2.4" stroke-linejoin="round"/>
  <path d="M11 20 c4 -6 22 -6 26 0" fill="none" stroke="#f0f6fc" stroke-width="2.4"/>
  <circle cx="18" cy="24" r="2.6" fill="#ff2e4d"/><circle cx="30" cy="24" r="2.6" fill="#ff2e4d"/>
  <path d="M19 30 c3 2 7 2 10 0" fill="none" stroke="#8b98a5" stroke-width="2" stroke-linecap="round"/>'

ls -1 "$OUT"
