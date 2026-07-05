#!/usr/bin/env python3
"""Environment layer for arena scenes (1920x1080, no board).

Same recipe as compose_battle_bg.py's backdrop step, without pasting the
sharp arena: the board is now a separate BoardPlate node in
scenes/arenas/*.tscn, positioned freely per theme. Blur + darken a
cover-scaled copy of the arena art so the surroundings share its palette.

Usage: python tools/make_arena_env.py [src] [out]
Default: pixel/board_arena.png -> assets/backgrounds/battle_env_dungeon.png
"""

import sys
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "sprites" / "ui" / "pixel" / "board_arena.png"
OUT = ROOT / "assets" / "backgrounds" / "battle_env_dungeon.png"

W, H = 1920, 1080


def main():
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else SRC
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else OUT
    arena = Image.open(src).convert("RGB")
    cover_scale = max(W / arena.width, H / arena.height) * 1.15
    cover = arena.resize((round(arena.width * cover_scale),
                          round(arena.height * cover_scale)), Image.LANCZOS)
    cx = (cover.width - W) // 2
    cy = (cover.height - H) // 2
    bg = cover.crop((cx, cy, cx + W, cy + H))
    bg = bg.filter(ImageFilter.GaussianBlur(14))
    bg = ImageEnhance.Brightness(bg).enhance(0.42)
    bg.save(out)
    print(f"env: {bg.size} -> {out}")


if __name__ == "__main__":
    main()
