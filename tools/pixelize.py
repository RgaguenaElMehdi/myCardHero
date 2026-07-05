#!/usr/bin/env python3
"""Convert the mockup-derived UI kit to real pixel art.

Classic pixelization: downscale (box), quantize to a small adaptive palette,
upscale back with nearest — hard edges, binarized alpha. Output mirrors
assets/sprites/ui/mockup/ into assets/sprites/ui/pixel/.
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "sprites" / "ui" / "mockup"
OUT = ROOT / "assets" / "sprites" / "ui" / "pixel"

FACTOR = 4          # pixel block size for UI elements
FACTOR_LARGE = 5    # for the full-screen background
COLORS = 40


def pixelize(img: Image.Image, factor: int, colors: int = COLORS) -> Image.Image:
    img = img.convert("RGBA")
    w, h = img.size
    sw, sh = max(1, w // factor), max(1, h // factor)
    small = img.resize((sw, sh), Image.BOX)
    alpha = small.getchannel("A").point(lambda a: 255 if a >= 112 else 0)
    rgb = small.convert("RGB").quantize(colors=colors, method=Image.MEDIANCUT,
                                        dither=Image.Dither.NONE).convert("RGB")
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out.resize((sw * factor, sh * factor), Image.NEAREST)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for src in sorted(SRC.glob("*.png")):
        img = Image.open(src)
        factor = FACTOR_LARGE if max(img.size) > 1400 else FACTOR
        colors = 80 if max(img.size) > 1400 else COLORS
        pixelize(img, factor, colors).save(OUT / src.name)
        print(f"{src.name}: {img.size} /{factor}")
    print(f"\n-> {OUT}")


if __name__ == "__main__":
    main()
