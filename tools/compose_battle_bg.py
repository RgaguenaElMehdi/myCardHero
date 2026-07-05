#!/usr/bin/env python3
"""Compose the full-screen battle background (1920x1080) from the arena art.

The mockup reference (assets/mockup/game exemple.png) shows the arena embedded
in its environment, not floating over an unrelated backdrop. Recipe: blurred +
darkened cover of the arena fills the screen, the sharp arena is pasted at
ARENA_POS/ARENA_SCALE (constants mirrored in scripts/ui/battle_scene.gd).
"""

from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "sprites" / "ui" / "mockup" / "board_arena.png"
OUT = ROOT / "assets" / "sprites" / "ui" / "mockup" / "battle_bg.png"

W, H = 1920, 1080
ARENA_H = 950          # arena height on screen -> scale = 950/1050
ARENA_Y = 60           # below the title bar


def main():
    arena = Image.open(SRC).convert("RGB")
    scale = ARENA_H / arena.height
    aw = round(arena.width * scale)
    ax = (W - aw) // 2

    # Backdrop: the arena itself, cover-scaled, blurred and darkened, so the
    # surroundings share the same palette and read as out-of-focus battlefield.
    cover_scale = max(W / arena.width, H / arena.height) * 1.15
    cover = arena.resize((round(arena.width * cover_scale),
                          round(arena.height * cover_scale)), Image.LANCZOS)
    cx = (cover.width - W) // 2
    cy = (cover.height - H) // 2
    bg = cover.crop((cx, cy, cx + W, cy + H))
    bg = bg.filter(ImageFilter.GaussianBlur(14))
    bg = ImageEnhance.Brightness(bg).enhance(0.42)

    sharp = arena.resize((aw, ARENA_H), Image.LANCZOS)
    # Soft edge: paste with a feathered mask so the arena melts into the backdrop.
    mask = Image.new("L", (aw, ARENA_H), 255)
    feather = 26
    px = mask.load()
    for y in range(ARENA_H):
        for x in range(aw):
            d = min(x, y, aw - 1 - x, ARENA_H - 1 - y)
            if d < feather:
                px[x, y] = int(255 * d / feather)
    bg.paste(sharp, (ax, ARENA_Y), mask)
    bg.save(OUT)

    print(f"battle_bg: {bg.size} -> {OUT.name}")
    print(f"ARENA_POS = Vector2({ax}, {ARENA_Y})  ARENA_SCALE = {ARENA_H}/{arena.height} = {scale:.6f}")


if __name__ == "__main__":
    main()
