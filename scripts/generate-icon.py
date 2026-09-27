#!/usr/bin/env python3
"""Regenerate the simple Lid Awake app icon. Requires Pillow."""
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parent.parent
out = root / "Resources/Assets.xcassets/AppIcon.appiconset"
scale = 4
size = 1024 * scale
im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
draw = ImageDraw.Draw(im)

def box(coords, radius, fill, width=0):
    pts = tuple(round(n * scale) for n in coords)
    draw.rounded_rectangle(pts, radius=round(radius * scale), fill=fill, width=round(width * scale))

box((50, 50, 974, 974), 210, (29, 44, 74, 255))
box((177, 254, 847, 712), 48, (242, 248, 255, 255))
box((219, 296, 805, 671), 25, (56, 83, 119, 255))
box((130, 700, 894, 773), 35, (242, 248, 255, 255))
box((438, 700, 586, 721), 11, (114, 139, 166, 255))
draw.ellipse((711 * scale, 192 * scale, 869 * scale, 350 * scale), fill=(255, 166, 64, 255))

im = im.resize((1024, 1024), Image.Resampling.LANCZOS)
for px in (16, 32, 64, 128, 256, 512, 1024):
    im.resize((px, px), Image.Resampling.LANCZOS).save(out / f"icon-{px}.png")
