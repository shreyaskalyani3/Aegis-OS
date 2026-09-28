#!/usr/bin/env bash
# =============================================================================
#  test-hitech-frames.sh — size/quality test for the HiTech frame downscale.
#
#  Clones the upstream theme, downscales sample frames to 1920x1080 with
#  palette quantization (the pipeline build-iso.sh will use), and reports
#  per-frame + extrapolated sizes. Run inside WSL as root.
# =============================================================================
set -e

command -v magick >/dev/null 2>&1 || pacman -S --needed --noconfirm imagemagick >/dev/null
command -v git    >/dev/null 2>&1 || pacman -S --needed --noconfirm git >/dev/null

rm -rf /tmp/hitech
git clone -q --depth=1 https://github.com/xDeFc0nx/HiTech-arch-animation.git /tmp/hitech
cd /tmp/hitech

orig_total=$(du -sb . | cut -f1)
count=0
q_total=0
for f in progress-*.png; do
    count=$((count + 1))
    # sample only every 10th frame for the size estimate, full set in the real build
    case "$count" in
        1|10|20|30|40|50|60|70|60|80|90|100|110|110|120|130|140|140|148)
            magick "$f" -resize 1920x1080 -colors 256 "PNG8:/tmp/hq-${f}"
            sz=$(stat -c %s "/tmp/hq-${f}")
            q_total=$((q_total + sz))
            printf '%-20s %8d bytes\n' "$f" "$sz"
            ;;
    esac
done

sampled=$(( (count + 9) / 10 ))
avg=$((q_total / sampled))
echo "---"
echo "sampled: ${sampled} frames, avg ${avg} bytes"
echo "upstream total: ${orig_total} bytes (~$((orig_total / 1024 / 1024)) MB)"
echo "extrapolated 1920x1080 PNG8 total: $((avg * count)) bytes (~$((avg * count / 1024 / 1024)) MB)"
