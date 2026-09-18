#!/usr/bin/env python3
# =============================================================================
#  gen-boot-images.py — generate the Aegis OS boot branding images.
#
#  Outputs (all into the repo's airootfs, single source — no duplicated assets):
#    usr/share/aegis/splash-aegis.png            640x480  syslinux vesamenu bg
#                                                         (build-iso.sh copies it
#                                                          onto the ISO's boot dir)
#    usr/share/grub/themes/aegis/background.png  1920x1080 GRUB menu background
#    usr/share/plymouth/themes/aegis/shield.png  240x300  plymouth logo (text baked
#                                                         in: plymouth's script
#                                                         language has no text API)
#    usr/share/plymouth/themes/aegis/bar.png     220x4    progress bar (final size:
#                                                         the plymouth script API
#                                                         has no sprite scaling)
#
#  The shield is the canonical aegis.svg geometry (same path, beziers sampled),
#  so every boot screen matches the panel icon and the MOTD letterform.
#  Re-run after any rebrand:  python scripts/dev/gen-boot-images.py
# =============================================================================
from __future__ import annotations

import os
from PIL import Image, ImageDraw, ImageFont

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
AIROOTFS = os.path.join(REPO, "profile", "airootfs")

# Aegis palette (matches aegis.svg + the terminal cursor + the MOTD red fade)
BG_TOP = (17, 22, 31)       # #11161f
BG_BOT = (10, 14, 20)       # #0a0e14
RED = (255, 51, 85)         # #ff3355
RED_DEEP = (179, 18, 46)    # #b3122e
RED_RIM = (255, 92, 120)    # #ff5c78
WHITE = (255, 255, 255)
GREY = (139, 148, 158)      # #8b949e

FONT_CANDIDATES = [
    r"C:\Windows\Fonts\segoeuib.ttf",
    r"C:\Windows\Fonts\arialbd.ttf",
    "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",
]


def load_font(size: int):
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


# --- shield geometry (aegis.svg, 48x48 viewBox) -------------------------------
def bez(p0, p1, p2, p3, steps=24):
    return [
        (
            (1 - t) ** 3 * p0[0] + 3 * (1 - t) ** 2 * t * p1[0]
            + 3 * (1 - t) * t ** 2 * p2[0] + t ** 3 * p3[0],
            (1 - t) ** 3 * p0[1] + 3 * (1 - t) ** 2 * t * p1[1]
            + 3 * (1 - t) * t ** 2 * p2[1] + t ** 3 * p3[1],
        )
        for t in (i / steps for i in range(steps + 1))
    ]


def shield_points(scale: float) -> list[tuple[float, float]]:
    """The aegis.svg shield path: M24 1.25 L40 7 L40 25.5 C... Z, sampled."""
    pts = [(24.0, 1.25), (40.0, 7.0), (40.0, 25.5)]
    pts += bez((40, 25.5), (40, 36.5), (32.25, 43.25), (24, 46.75))
    pts += bez((24, 46.75), (15.75, 43.25), (8, 36.5), (8, 25.5))
    pts += [(8.0, 25.5), (8.0, 7.0), (24.0, 1.25)]
    return [(x * scale, y * scale) for x, y in pts]


def a_points(scale: float) -> tuple[list, list]:
    """The chunky 'A' outer shape and its counter (even-odd hole), sampled."""
    outer = [(24, 12), (35, 37), (28.6, 37), (26.4, 31), (21.6, 31), (19.4, 37), (13, 37)]
    counter = [(24, 20.5), (22.3, 26), (25.7, 26)]
    return (
        [(x * scale, y * scale) for x, y in outer],
        [(x * scale, y * scale) for x, y in counter],
    )


def draw_shield(size: int) -> Image.Image:
    """Transparent RGBA canvas with the gradient shield + white 'A'."""
    scale = size / 48.0
    pad = int(scale * 2)
    img = Image.new("RGBA", (size + pad * 2, size + pad * 2), (0, 0, 0, 0))
    pts = [(x + pad, y + pad) for x, y in shield_points(scale)]

    # vertical gradient (#ff3355 -> #b3122e) applied through the shield mask
    grad = Image.new("RGBA", img.size)
    top, bot = RED, RED_DEEP
    for y in range(img.height):
        t = y / max(1, img.height - 1)
        row = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)) + (255,)
        ImageDraw.Draw(grad).line([(0, y), (img.width, y)], fill=row)
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    img.paste(grad, (0, 0), mask)

    d = ImageDraw.Draw(img)
    # bright rim (aegis.svg stroke #ff5c78)
    d.line(pts + [pts[0]], fill=RED_RIM, width=max(1, int(scale * 0.55)), joint="curve")
    # chunky white 'A' with punched counter
    outer, counter = a_points(scale)
    outer = [(x + pad, y + pad) for x, y in outer]
    counter = [(x + pad, y + pad) for x, y in counter]
    d.polygon(outer, fill=WHITE)
    d.polygon(counter, fill=RED_DEEP)
    return img


def vgradient_bg(w: int, h: int, glow_center=None, glow_radius=0) -> Image.Image:
    img = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        d.line([(0, y), (w, y)], fill=tuple(int(BG_TOP[i] + (BG_BOT[i] - BG_TOP[i]) * t) for i in range(3)))
    if glow_center and glow_radius:
        # faint red aura behind the shield
        glow = Image.new("L", (w, h), 0)
        gd = ImageDraw.Draw(glow)
        for r in range(glow_radius, 0, -2):
            a = int(38 * (1 - r / glow_radius))
            gd.ellipse([glow_center[0] - r, glow_center[1] - r,
                        glow_center[0] + r, glow_center[1] + r], fill=a)
        red_layer = Image.new("RGB", (w, h), RED_DEEP)
        img.paste(red_layer, (0, 0), glow)
    return img


def wordmark(draw: ImageDraw.ImageDraw, xy, text: str, size: int, color=WHITE, tracking=6):
    font = load_font(size)
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=font, fill=color)
        x += draw.textlength(ch, font=font) + tracking
    return x


def subtitle(draw: ImageDraw.ImageDraw, xy, text: str, size: int, color=GREY, tracking=4):
    return wordmark(draw, xy, text, size, color, tracking)


def make_splash(w=640, h=480) -> Image.Image:
    img = vgradient_bg(w, h, glow_center=(int(w * 0.72), int(h * 0.40)), glow_radius=int(h * 0.34))
    d = ImageDraw.Draw(img)
    # shield on the right (vesamenu draws its menu box over the centre-left)
    sh = draw_shield(int(h * 0.32))
    img.paste(sh, (int(w * 0.72) - sh.width // 2, int(h * 0.40) - sh.height // 2), sh)
    # wordmark top-left
    wordmark(d, (28, 34), "AEGIS OS", 34)
    d.rectangle([28, 84, 28 + 150, 87], fill=RED)
    subtitle(d, (28, 100), "SENTINEL", 15)
    # footer
    subtitle(d, (28, h - 34), "OFFENSIVE & DEFENSIVE SECURITY - AGENT-NATIVE", 11)
    return img


def make_grub_bg(w=1920, h=1080) -> Image.Image:
    img = vgradient_bg(w, h, glow_center=(int(w * 0.76), int(h * 0.42)), glow_radius=int(h * 0.38))
    d = ImageDraw.Draw(img)
    sh = draw_shield(int(h * 0.30))
    img.paste(sh, (int(w * 0.76) - sh.width // 2, int(h * 0.42) - sh.height // 2), sh)
    wordmark(d, (64, 60), "AEGIS OS", 88)
    d.rectangle([64, 172, 64 + 420, 182], fill=RED)
    subtitle(d, (64, 204), "SENTINEL", 34)
    subtitle(d, (64, h - 70), "OFFENSIVE & DEFENSIVE SECURITY - AGENT-NATIVE", 24)
    return img


def make_plymouth_logo() -> Image.Image:
    """Shield + baked-in wordmark (plymouth script has no text API)."""
    sh = draw_shield(240)
    w, h = 420, sh.height + 96
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    img.paste(sh, (w // 2 - sh.width // 2, 0), sh)
    # bake the text as white shapes via a font render on a temp layer
    txt = Image.new("RGBA", (w, 64), (0, 0, 0, 0))
    td = ImageDraw.Draw(txt)
    font = load_font(40)
    tw = sum(td.textlength(c, font=font) + 8 for c in "AEGIS OS") - 8
    x = (w - tw) / 2
    for c in "AEGIS OS":
        td.text((x, 8), c, font=font, fill=WHITE)
        x += td.textlength(c, font=font) + 8
    img.paste(txt, (0, sh.height + 20), txt)
    return img


def make_bar() -> Image.Image:
    return Image.new("RGBA", (220, 4), RED + (255,))


def make_box() -> Image.Image:
    """LUKS password-dialog panel: dark, thin red top edge."""
    w, h = 360, 68
    img = Image.new("RGBA", (w, h), (18, 24, 34, 235))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, 2], fill=RED + (255,))
    return img


def make_entry() -> Image.Image:
    """LUKS password entry field: darker inset."""
    img = Image.new("RGBA", (230, 36), (8, 12, 18, 255))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 229, 35], outline=(60, 70, 82, 255), width=1)
    return img


def make_bullet() -> Image.Image:
    """LUKS password bullet dot."""
    img = Image.new("RGBA", (10, 10), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([1, 1, 8, 8], fill=RED + (255,))
    return img


def write(path: str, img: Image.Image):
    full = os.path.join(AIROOTFS, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    img.save(full)
    print(f"wrote {path}  {img.size[0]}x{img.size[1]}")


if __name__ == "__main__":
    write("usr/share/aegis/splash-aegis.png", make_splash())
    write("usr/share/grub/themes/aegis/background.png", make_grub_bg())
    write("usr/share/plymouth/themes/aegis/shield.png", make_plymouth_logo())
    write("usr/share/plymouth/themes/aegis/bar.png", make_bar())
    write("usr/share/plymouth/themes/aegis/box.png", make_box())
    write("usr/share/plymouth/themes/aegis/entry.png", make_entry())
    write("usr/share/plymouth/themes/aegis/bullet.png", make_bullet())
    print("done")
