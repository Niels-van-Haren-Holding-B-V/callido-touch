#!/usr/bin/env python3
"""Draw the Callido Touch logo (dev tool, needs Pillow; AppIcon.icns also needs macOS iconutil).

The artwork is generated, not traced: a Callido gradient tile (violet to coral to amber) with a white
touch panel, a tap with ripple rings and a pen. Everything is drawn at 4x and scaled down.

Writes assets/logo.png (the tile, 512 px, transparent corners), assets/logo-1024.png and
assets/AppIcon.icns (tile at 824/1024 on a transparent canvas with a soft shadow, all macOS sizes).
Usage: python3 scripts/make_logo.py
"""
import math, os, shutil, subprocess, sys, tempfile
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")
S = 4096                       # working canvas for the tile (drawn at 4x of 1024)

# Callido palette (matches Callido Restore): deep violet -> plum -> coral -> amber
STOPS = [(0.00, (58, 30, 140)), (0.38, (122, 52, 150)), (0.70, (232, 98, 104)), (1.00, (248, 160, 72))]


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(size):
    """Diagonal gradient from top-left to bottom-right through STOPS."""
    small = 256
    img = Image.new("RGB", (small, small))
    px = img.load()
    for y in range(small):
        for x in range(small):
            t = (x + y) / (2 * (small - 1))
            for (t0, c0), (t1, c1) in zip(STOPS, STOPS[1:]):
                if t <= t1:
                    px[x, y] = lerp(c0, c1, (t - t0) / (t1 - t0))
                    break
    return img.resize((size, size), Image.BICUBIC)


def rounded_mask(size, radius):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size - 1, size - 1), radius, fill=255)
    return m


def glyph(size):
    """White artwork on a transparent layer: touch panel, tap with ripples, pen."""
    g = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(g)
    u = size / 1024                                         # design units are 1024 per side

    def U(*v):
        return [round(x * u) for x in v]

    # touch panel: rounded frame, slightly translucent face
    d.rounded_rectangle(U(196, 250, 828, 690), round(54 * u), fill=56)
    d.rounded_rectangle(U(196, 250, 828, 690), round(54 * u), outline=255, width=round(34 * u))

    # tap point with two ripple rings
    cx, cy = 420, 455
    d.ellipse(U(cx - 44, cy - 44, cx + 44, cy + 44), fill=255)
    for r, w, a in ((98, 22, 210), (152, 18, 130)):
        d.arc(U(cx - r, cy - r, cx + r, cy + r), 200, 340, fill=a, width=round(w * u))
        d.arc(U(cx - r, cy - r, cx + r, cy + r), 20, 160, fill=a, width=round(w * u))
    return g


def pen_layer(size):
    """The pen, drawn separately so it can sit over the panel frame with a cut-out gap."""
    u = size / 1024
    L = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(L)
    ang = math.radians(42)                                  # the pen comes in from the bottom right
    tip = (650 * u, 545 * u)
    length, half = 370 * u, 34 * u
    ux, uy = math.cos(ang), math.sin(ang)                   # from tip towards the cap
    nx, ny = -uy, ux

    def P(t, s):
        return (tip[0] + ux * t + nx * s, tip[1] + uy * t + ny * s)

    nib = 92 * u

    def outline(m):                                         # pen outline grown by m on every side
        return [P(-m * 1.6, 0), P(nib, -half - m), P(length, -half - m), P(length + 18 * u + m, -half * 0.6 - m),
                P(length + 18 * u + m, half * 0.6 + m), P(length, half + m), P(nib, half + m)]

    gap = Image.new("L", (size, size), 0)
    ImageDraw.Draw(gap).polygon(outline(26 * u), fill=255)
    d.polygon(outline(0), fill=255)
    # ferrule line between nib and body
    d.line([P(nib + 4 * u, -half), P(nib + 4 * u, half)], fill=0, width=round(12 * u))
    return L, gap


def tile(size):
    base = gradient(size).convert("RGBA")
    # soft light from the top-left, like the other Callido icons
    glow = Image.new("L", (size, size), 0)
    ImageDraw.Draw(glow).ellipse((-size * 0.35, -size * 0.45, size * 0.75, size * 0.55), fill=46)
    glow = glow.filter(ImageFilter.GaussianBlur(size * 0.08))
    base = Image.composite(Image.new("RGBA", (size, size), (255, 255, 255, 255)), base, glow)

    art = glyph(size)
    pen, pen_gap = pen_layer(size)
    art = ImageChops.subtract(art, pen_gap)                 # clear space around the pen
    art = ImageChops.lighter(art, pen)

    shadow = art.filter(ImageFilter.GaussianBlur(size * 0.012))
    shadow = ImageChops.offset(shadow, 0, round(size * 0.010))
    base = Image.composite(Image.new("RGBA", (size, size), (40, 12, 70, 255)), base,
                           shadow.point(lambda v: v * 0.35))
    base = Image.composite(Image.new("RGBA", (size, size), (255, 255, 255, 255)), base, art)
    base.putalpha(rounded_mask(size, round(size * 0.225)))
    return base


def icon_canvas(t, size):
    """macOS icon grid: the tile is 824/1024 of the canvas, centred, with a soft drop shadow."""
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    side = round(size * 824 / 1024)
    off = (size - side) // 2
    small = t.resize((side, side), Image.LANCZOS)
    sh = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    a = Image.new("L", (size, size), 0)
    a.paste(small.getchannel("A"), (off, off + round(size * 0.012)))
    sh.putalpha(a.filter(ImageFilter.GaussianBlur(size * 0.014)).point(lambda v: v * 0.45))
    canvas = Image.alpha_composite(canvas, sh)
    canvas.alpha_composite(small, (off, off))
    return canvas


def main():
    os.makedirs(ASSETS, exist_ok=True)
    t = tile(S)
    t.resize((512, 512), Image.LANCZOS).save(os.path.join(ASSETS, "logo.png"), optimize=True)
    big = icon_canvas(t, 1024)
    big.save(os.path.join(ASSETS, "logo-1024.png"), optimize=True)
    if not shutil.which("iconutil"):
        print("iconutil not found: skipped AppIcon.icns", file=sys.stderr)
        return
    with tempfile.TemporaryDirectory() as tmp:
        iconset = os.path.join(tmp, "AppIcon.iconset")
        os.mkdir(iconset)
        for pt in (16, 32, 128, 256, 512):
            for scale in (1, 2):
                px = pt * scale
                name = f"icon_{pt}x{pt}{'@2x' if scale == 2 else ''}.png"
                icon_canvas(t, px).save(os.path.join(iconset, name))
        subprocess.run(["iconutil", "-c", "icns", iconset, "-o", os.path.join(ASSETS, "AppIcon.icns")], check=True)
    print("wrote assets/logo.png, assets/logo-1024.png, assets/AppIcon.icns")


if __name__ == "__main__":
    main()
