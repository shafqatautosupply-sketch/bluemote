#!/usr/bin/env python3
"""Cuts the app icon out of tools/icon_source.jpg and writes the PNG sizes the app needs.

Usage:  python3 tools/export_icon.py [outdir] [--store]      (default outdir: Resources)
Writes: Icon.png 57, Icon@2x.png 114, Icon-Small.png 29, Icon-Small@2x.png 58.
        --store also writes iTunesArtwork.png 512 for a repo listing (keep it out of Resources: the app does not use it).
Needs:  pillow only.

The source is a 1024 x 1024 render of the icon on a dark margin. The icon's own edge is the 784 x 784 square at (120, 120);
its corner radius is about 150 px. The script crops to that square, makes everything outside the rounded corners transparent
and shrinks it with LANCZOS (premultiplied alpha, so the edges stay clean). If you replace icon_source.jpg with a different
render, change BOX and RADIUS below."""
import os, sys
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCE = os.path.join(HERE, "icon_source.jpg")
BOX = (120, 120, 904, 904)        # the icon's edge inside the source image
RADIUS = 150                      # corner radius in source pixels
SIZES = (("Icon.png", 57), ("Icon@2x.png", 114), ("Icon-Small.png", 29), ("Icon-Small@2x.png", 58))
STORE = ("iTunesArtwork.png", 512)

def main(outdir, store=False):
    crop = Image.open(SOURCE).convert("RGB").crop(BOX)
    w, ss = crop.size[0], 4
    mask = Image.new("L", (w * ss, w * ss), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0.5 * ss, 0.5 * ss, (w - 0.5) * ss - 1, (w - 0.5) * ss - 1], radius=RADIUS * ss, fill=255)
    master = crop.convert("RGBA")
    master.putalpha(mask.resize((w, w), Image.LANCZOS))      # 0.5 px inset hides the dark fringe of the source margin
    os.makedirs(outdir, exist_ok=True)
    for name, px in SIZES + ((STORE,) if store else ()):
        master.convert("RGBa").resize((px, px), Image.LANCZOS).convert("RGBA").save(os.path.join(outdir, name), optimize=True)
    print("icons written to", outdir)

if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    main(args[0] if args else os.path.join(HERE, "..", "Resources"), "--store" in sys.argv)
