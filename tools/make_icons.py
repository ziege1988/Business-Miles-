#!/usr/bin/env python3
"""Erzeugt die App-Icons (iOS + macOS) aus derselben Geometrie wie LogoMark in LogoView.swift.

Aufruf:  python3 tools/make_icons.py
Benötigt: Pillow (pip install pillow)
"""
import json
import os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Resources", "Assets.xcassets", "AppIcon.appiconset")

ACCENT = (15, 139, 141)       # #0F8B8D
ACCENT_DEEP = (22, 95, 138)   # #165F8A
WHITE = (255, 255, 255)
SS = 4                        # Supersampling


def gradient(size):
    """Diagonaler Verlauf oben links → unten rechts."""
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            px[x, y] = tuple(int(a + (b - a) * t) for a, b in zip(ACCENT, ACCENT_DEEP))
    return img


def bezier(p0, p1, p2, p3, steps=400):
    pts = []
    for i in range(steps + 1):
        t = i / steps
        mt = 1 - t
        x = mt**3 * p0[0] + 3 * mt**2 * t * p1[0] + 3 * mt * t**2 * p2[0] + t**3 * p3[0]
        y = mt**3 * p0[1] + 3 * mt**2 * t * p1[1] + 3 * mt * t**2 * p2[1] + t**3 * p3[1]
        pts.append((x, y))
    return pts


def glyph(size):
    """Route, Startpunkt und Pin (weiß) auf transparentem Grund – Einheitskoordinaten wie in Swift."""
    s = size
    layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    P = lambda x, y: (x * s, y * s)

    # Route
    pts = bezier(P(0.26, 0.78), P(0.74, 0.80), P(0.24, 0.52), P(0.68, 0.52), steps=1500)
    r = 0.035 * s  # halbe Linienbreite (0.07)
    for x, y in pts:  # Kreise entlang der Kurve stempeln = saubere, runde Linie
        d.ellipse([x - r, y - r, x + r, y + r], fill=WHITE)

    # Startpunkt
    r = 0.065 * s
    cx, cy = P(0.26, 0.78)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=WHITE)

    # Pin
    pcx, pcy, pr = 0.68, 0.31, 0.13
    d.polygon([P(pcx - 0.809 * pr, pcy + 0.588 * pr),
               P(pcx + 0.809 * pr, pcy + 0.588 * pr),
               P(pcx, pcy + 1.75 * pr)], fill=WHITE)
    cx, cy = P(pcx, pcy)
    r = pr * s
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=WHITE)
    r = 0.05 * s
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=ACCENT_DEEP + (255,))
    return layer


def ios_icon(size=1024):
    """iOS: vollflächig, das System rundet die Ecken selbst."""
    big = size * SS
    base = gradient(big).convert("RGBA")
    base.alpha_composite(glyph(big))
    return base.resize((size, size), Image.LANCZOS).convert("RGB")


def mac_icon(size=1024):
    """macOS: abgerundetes Quadrat mit Rand und weichem Schatten (Apple-Raster 824/1024)."""
    big = size * SS
    canvas = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    inner = int(big * 824 / 1024)
    off = (big - inner) // 2
    radius = int(inner * 0.225)

    mask = Image.new("L", (inner, inner), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, inner - 1, inner - 1], radius=radius, fill=255)

    shadow = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    sm = Image.new("L", (big, big), 0)
    sm.paste(mask, (off, off + int(big * 0.012)))
    shadow.putalpha(sm.filter(ImageFilter.GaussianBlur(big * 0.012)).point(lambda v: int(v * 0.35)))
    canvas.alpha_composite(shadow)

    tile = gradient(inner).convert("RGBA")
    tile.alpha_composite(glyph(inner))
    tile.putalpha(mask)
    canvas.alpha_composite(tile, (off, off))
    return canvas.resize((size, size), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    images = []

    ios = ios_icon(1024)
    ios.save(os.path.join(OUT, "icon-ios-1024.png"))
    images.append({"filename": "icon-ios-1024.png", "idiom": "universal",
                   "platform": "ios", "size": "1024x1024"})

    mac_master = mac_icon(1024)
    for pt in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            px = pt * scale
            name = f"icon-mac-{pt}@{scale}x.png"
            mac_master.resize((px, px), Image.LANCZOS).save(os.path.join(OUT, name))
            images.append({"filename": name, "idiom": "mac",
                           "scale": f"{scale}x", "size": f"{pt}x{pt}"})

    with open(os.path.join(OUT, "Contents.json"), "w") as f:
        json.dump({"images": images, "info": {"author": "xcode", "version": 1}}, f, indent=2)

    # Vorschau für README
    preview = os.path.join(ROOT, "docs")
    os.makedirs(preview, exist_ok=True)
    mac_master.resize((256, 256), Image.LANCZOS).save(os.path.join(preview, "icon.png"))
    print("Icons erzeugt in", OUT)


if __name__ == "__main__":
    main()
