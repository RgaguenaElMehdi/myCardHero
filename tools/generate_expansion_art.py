#!/usr/bin/env python3
"""Generate local art assets for the 100-card expansion.

This script creates:
- monster unit sprites in assets/sprites/units/<id>.png
- card art in assets/sprites/cards/<id>.png

The assets are generated procedurally with Pillow so the repo stays usable even
without an external image API key.
"""

from __future__ import annotations

import hashlib
import json
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parent.parent
CARDS_JSON = ROOT / "resources" / "data" / "cards.json"
CARDS_DIR = ROOT / "assets" / "sprites" / "cards"
UNITS_DIR = ROOT / "assets" / "sprites" / "units"

TARGET_IDS = {
    "ember_sentinel", "lava_skirmisher", "cinder_alchemist", "pyre_colossus", "smoke_duelist",
    "molten_surge", "forge_rite", "wildfire_burst", "ember_reckoning",
    "mosswarden", "thorn_whisperer", "canopy_hunter", "root_titan", "bloom_vanguard",
    "seed_surge", "verdant_blessing", "canopy_shield", "moonbloom", "living_grove",
    "void_hound", "umbra_knight", "grave_sibyl", "dusk_reaver",
    "sepulchral_mark", "night_veil", "black_tribute", "abyssal_hex", "grave_fog",
    "sunward_lancer", "halo_medic", "prism_archon", "dawn_paladin", "temple_sentinel", "auric_phoenix",
    "blessing_ray", "sanctified_aegis", "sunrise_liturgy", "radiant_pulse",
}

MONSTER_PROFILES = {
    "ember_sentinel": ("humanoid", "hammer"),
    "lava_skirmisher": ("runner", "dagger"),
    "cinder_alchemist": ("mage", "vials"),
    "pyre_colossus": ("golem", "fists"),
    "smoke_duelist": ("duelist", "sword"),
    "mosswarden": ("tree", "roots"),
    "thorn_whisperer": ("mage", "staff"),
    "canopy_hunter": ("beast", "bow"),
    "root_titan": ("tree", "roots"),
    "bloom_vanguard": ("knight", "shield"),
    "void_hound": ("beast", "fangs"),
    "umbra_knight": ("knight", "sword"),
    "grave_sibyl": ("mage", "orb"),
    "dusk_reaver": ("reaper", "scythe"),
    "sunward_lancer": ("knight", "lance"),
    "halo_medic": ("healer", "staff"),
    "prism_archon": ("mage", "prism"),
    "dawn_paladin": ("paladin", "blade"),
    "temple_sentinel": ("guardian", "tower_shield"),
    "auric_phoenix": ("phoenix", "wings"),
}

GUILDS = {
    "flame": {
        "base": (90, 28, 18, 255),
        "mid": (202, 84, 36, 255),
        "hi": (255, 178, 60, 255),
        "dark": (32, 8, 8, 255),
        "spark": (255, 236, 172, 255),
    },
    "sylvan": {
        "base": (28, 78, 36, 255),
        "mid": (84, 156, 78, 255),
        "hi": (164, 220, 128, 255),
        "dark": (8, 28, 14, 255),
        "spark": (230, 250, 194, 255),
    },
    "shadow": {
        "base": (34, 18, 56, 255),
        "mid": (108, 72, 168, 255),
        "hi": (196, 144, 250, 255),
        "dark": (10, 6, 18, 255),
        "spark": (236, 220, 255, 255),
    },
    "light": {
        "base": (118, 96, 34, 255),
        "mid": (206, 168, 74, 255),
        "hi": (250, 234, 164, 255),
        "dark": (20, 18, 8, 255),
        "spark": (255, 252, 238, 255),
    },
}


def seed_for(text: str) -> int:
    return int(hashlib.sha1(text.encode("utf-8")).hexdigest()[:8], 16)


def guild_palette(guild: str):
    return GUILDS[guild]


def new_canvas(size, transparent=True):
    return Image.new("RGBA", size, (0, 0, 0, 0) if transparent else (0, 0, 0, 255))


def lerp(a, b, t):
    return int(a + (b - a) * t)


def blend(c1, c2, t):
    return tuple(lerp(c1[i], c2[i], t) for i in range(4))


def draw_radial_gradient(img: Image.Image, center, inner, outer):
    px = img.load()
    w, h = img.size
    cx, cy = center
    max_d = math.hypot(max(cx, w - cx), max(cy, h - cy))
    for y in range(h):
        for x in range(w):
            d = math.hypot(x - cx, y - cy) / max_d
            t = min(1.0, max(0.0, d))
            px[x, y] = blend(inner, outer, t)


def add_noise(img: Image.Image, rng: random.Random, amount: int = 120):
    draw = ImageDraw.Draw(img)
    w, h = img.size
    for _ in range(amount):
        x = rng.randrange(w)
        y = rng.randrange(h)
        r = rng.randrange(1, 4)
        alpha = rng.randrange(25, 90)
        c = (255, 255, 255, alpha)
        draw.ellipse((x - r, y - r, x + r, y + r), fill=c)


def add_vignette(img: Image.Image, strength: int = 110):
    w, h = img.size
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    px = overlay.load()
    for y in range(h):
        for x in range(w):
            dx = abs(x - w / 2) / (w / 2)
            dy = abs(y - h / 2) / (h / 2)
            t = min(1.0, max(dx, dy))
            a = int(strength * t * t)
            px[x, y] = (0, 0, 0, a)
    return Image.alpha_composite(img, overlay)


def upscale_pixel_art(img: Image.Image, size):
    return img.resize(size, Image.Resampling.NEAREST)


def shadow_blob(size, center, radius, alpha):
    blob = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(blob)
    x, y = center
    d.ellipse((x - radius, y - radius // 2, x + radius, y + radius // 2), fill=(0, 0, 0, alpha))
    return blob.filter(ImageFilter.GaussianBlur(radius=radius // 6 or 1))


def outline_shape(draw, points, fill, outline, width=1):
    draw.polygon(points, fill=outline)
    if width <= 1:
        draw.polygon(points, fill=fill)
        return
    inset = []
    for x, y in points:
        inset.append((x + (1 if x < sum(p[0] for p in points) / len(points) else -1),
                      y + (1 if y < sum(p[1] for p in points) / len(points) else -1)))
    draw.polygon(inset, fill=fill)


def draw_unit_sprite(card):
    cid = card["id"]
    guild = card["guild"]
    seed = seed_for(cid)
    rng = random.Random(seed)
    shape, prop = MONSTER_PROFILES[cid]
    pal = guild_palette(guild)

    low = new_canvas((64, 80))
    d = ImageDraw.Draw(low)

    # Base shadow.
    d.ellipse((14, 60, 50, 75), fill=(0, 0, 0, 80))

    body = pal["mid"]
    dark = pal["dark"]
    hi = pal["hi"]
    spark = pal["spark"]

    def body_outline():
        return (10, 10, 12, 255)

    if shape in {"humanoid", "knight", "paladin", "guardian", "duelist", "healer", "mage"}:
        cx = 32
        head_y = 15 + rng.randrange(-1, 2)
        torso_top = 24
        torso_bot = 48 if shape != "healer" else 50
        # Head
        d.ellipse((24, head_y, 40, head_y + 16), fill=body_outline())
        d.ellipse((26, head_y + 2, 38, head_y + 14), fill=hi if shape in {"paladin", "healer"} else body)
        # Hair / helm / hood accents
        if shape in {"knight", "paladin", "guardian"}:
            d.rectangle((24, head_y + 3, 40, head_y + 8), fill=hi)
            d.rectangle((28, head_y + 6, 36, head_y + 13), fill=dark)
        elif shape == "mage":
            d.polygon([(24, head_y + 3), (32, head_y - 4), (40, head_y + 3), (38, head_y + 14), (26, head_y + 14)], fill=dark)
        elif shape == "healer":
            d.ellipse((23, head_y, 41, head_y + 18), fill=hi)
        elif shape == "duelist":
            d.rectangle((25, head_y + 4, 39, head_y + 13), fill=dark)
            d.line((26, head_y + 8, 38, head_y + 8), fill=hi, width=1)
        else:
            d.rectangle((27, head_y + 2, 37, head_y + 14), fill=body)
        # Body/robe/armor
        if shape in {"mage", "healer"}:
            d.polygon([(22, torso_top), (42, torso_top), (46, torso_bot), (18, torso_bot)], fill=body)
            d.polygon([(24, torso_top + 3), (40, torso_top + 3), (44, torso_bot), (20, torso_bot)], fill=dark)
        else:
            d.rectangle((22, torso_top, 42, torso_bot), fill=body)
            d.rectangle((24, torso_top + 3, 40, torso_bot - 2), fill=dark if shape not in {"paladin"} else hi)
        # Legs
        leg_offset = rng.choice([-2, 0, 2])
        d.rectangle((23 + leg_offset, 47, 29 + leg_offset, 63), fill=dark)
        d.rectangle((35 + leg_offset, 47, 41 + leg_offset, 63), fill=dark)
        d.rectangle((24 + leg_offset, 46, 28 + leg_offset, 58), fill=body)
        d.rectangle((36 + leg_offset, 46, 40 + leg_offset, 58), fill=body)
        # Arms and weapon.
        if prop == "hammer":
            d.line((20, 30, 14, 42), fill=dark, width=3)
            d.rectangle((8, 18, 18, 26), fill=hi)
            d.rectangle((6, 16, 10, 28), fill=dark)
        elif prop == "dagger":
            d.line((44, 32, 53, 38), fill=dark, width=2)
            d.polygon([(52, 37), (59, 35), (54, 42)], fill=hi)
        elif prop == "vials":
            d.line((20, 32, 14, 38), fill=dark, width=2)
            d.ellipse((8, 28, 14, 34), fill=hi)
            d.ellipse((52, 28, 58, 34), fill=spark)
        elif prop == "fists":
            d.line((18, 34, 10, 40), fill=dark, width=4)
            d.line((46, 34, 54, 40), fill=dark, width=4)
        elif prop == "sword":
            d.line((46, 31, 57, 43), fill=dark, width=2)
            d.polygon([(56, 40), (61, 39), (57, 47)], fill=hi)
        elif prop == "roots":
            d.polygon([(18, 50), (14, 66), (20, 66), (24, 52)], fill=dark)
            d.polygon([(46, 50), (50, 66), (44, 66), (40, 52)], fill=dark)
        elif prop == "staff":
            d.line((50, 18, 50, 60), fill=dark, width=3)
            d.ellipse((45, 12, 55, 22), fill=spark)
        elif prop == "bow":
            d.arc((45, 18, 60, 58), 250, 110, fill=hi, width=2)
            d.line((48, 18, 48, 58), fill=dark, width=1)
        elif prop == "orb":
            d.ellipse((45, 20, 54, 29), fill=hi)
            d.line((40, 30, 47, 35), fill=dark, width=2)
        elif prop == "scythe":
            d.line((45, 18, 54, 60), fill=dark, width=2)
            d.arc((39, 8, 58, 26), 180, 350, fill=hi, width=2)
        elif prop == "lance":
            d.line((46, 12, 58, 58), fill=dark, width=2)
            d.polygon([(56, 10), (62, 14), (54, 18)], fill=hi)
        elif prop == "blade":
            d.line((46, 18, 56, 56), fill=dark, width=3)
            d.rectangle((51, 10, 55, 18), fill=hi)
        elif prop == "tower_shield":
            d.polygon([(42, 20), (54, 24), (54, 52), (42, 58), (36, 40)], fill=hi)
            d.polygon([(44, 24), (50, 26), (50, 48), (44, 52), (40, 38)], fill=dark)
        elif prop == "wings":
            d.polygon([(18, 28), (6, 20), (8, 36)], fill=hi)
            d.polygon([(46, 28), (58, 20), (56, 36)], fill=hi)
        elif prop == "shield":
            d.polygon([(44, 24), (56, 28), (54, 52), (42, 56), (38, 38)], fill=hi)
            d.polygon([(46, 28), (52, 30), (50, 48), (42, 50), (40, 38)], fill=dark)
        else:
            d.line((20, 30, 14, 42), fill=dark, width=3)
            d.line((44, 30, 54, 42), fill=dark, width=3)
    elif shape == "runner":
        d.ellipse((24, 14, 40, 30), fill=body_outline())
        d.ellipse((26, 16, 38, 28), fill=body)
        d.polygon([(22, 28), (42, 28), (46, 42), (20, 40)], fill=dark)
        d.line((24, 32, 15, 44), fill=dark, width=3)
        d.line((40, 32, 53, 42), fill=dark, width=3)
        d.line((26, 42, 20, 60), fill=dark, width=3)
        d.line((38, 40, 46, 62), fill=dark, width=3)
        d.line((42, 30, 58, 24), fill=dark, width=2)
        d.line((18, 30, 10, 24), fill=dark, width=2)
        if prop == "dagger":
            d.polygon([(56, 23), (61, 22), (58, 28)], fill=hi)
        else:
            d.line((52, 26, 60, 20), fill=hi, width=2)
    elif shape == "beast":
        d.ellipse((18, 24, 46, 50), fill=body_outline())
        d.ellipse((20, 26, 44, 48), fill=body)
        d.ellipse((40, 20, 54, 34), fill=body_outline())
        d.ellipse((42, 22, 52, 32), fill=body)
        d.line((16, 38, 10, 48), fill=dark, width=3)
        d.line((22, 44, 20, 62), fill=dark, width=3)
        d.line((36, 44, 38, 62), fill=dark, width=3)
        d.line((46, 30, 58, 26), fill=dark, width=2)
        if prop == "fangs":
            d.polygon([(52, 32), (58, 36), (54, 38)], fill=hi)
            d.polygon([(48, 32), (46, 38), (50, 38)], fill=hi)
        elif prop == "bow":
            d.line((54, 22, 60, 18), fill=hi, width=2)
        else:
            d.line((50, 28, 60, 24), fill=hi, width=2)
    elif shape == "golem":
        d.rectangle((18, 16, 46, 54), fill=body_outline())
        d.rectangle((20, 18, 44, 52), fill=body)
        d.rectangle((22, 20, 42, 48), fill=dark)
        d.rectangle((10, 24, 18, 40), fill=body)
        d.rectangle((46, 24, 54, 40), fill=body)
        d.rectangle((18, 52, 26, 68), fill=dark)
        d.rectangle((36, 52, 46, 68), fill=dark)
        d.line((26, 20, 24, 12), fill=hi, width=2)
        d.line((38, 20, 40, 12), fill=hi, width=2)
    elif shape == "tree":
        d.rectangle((24, 12, 40, 54), fill=body_outline())
        d.rectangle((26, 14, 38, 52), fill=body)
        d.polygon([(20, 20), (26, 18), (24, 32), (16, 34)], fill=body)
        d.polygon([(42, 20), (38, 18), (40, 32), (48, 34)], fill=body)
        d.polygon([(22, 52), (30, 52), (24, 70), (18, 66)], fill=dark)
        d.polygon([(34, 52), (42, 52), (46, 66), (38, 70)], fill=dark)
        d.ellipse((20, 6, 30, 16), fill=hi)
        d.ellipse((34, 4, 44, 14), fill=hi)
    elif shape == "reaper":
        d.polygon([(24, 12), (40, 12), (48, 32), (44, 58), (20, 58), (16, 32)], fill=body_outline())
        d.polygon([(26, 14), (38, 14), (44, 32), (42, 56), (22, 56), (18, 32)], fill=dark)
        d.ellipse((26, 8, 38, 20), fill=body)
        d.line((44, 20, 56, 54), fill=dark, width=2)
        d.arc((36, 4, 58, 24), 175, 350, fill=hi, width=2)
    elif shape == "phoenix":
        d.ellipse((26, 20, 38, 34), fill=body_outline())
        d.ellipse((28, 22, 36, 32), fill=body)
        d.polygon([(16, 28), (8, 20), (12, 36), (22, 34)], fill=hi)
        d.polygon([(48, 28), (56, 20), (52, 36), (42, 34)], fill=hi)
        d.polygon([(28, 32), (36, 32), (42, 46), (32, 58), (22, 46)], fill=dark)
        d.polygon([(30, 48), (34, 48), (38, 62), (32, 72), (26, 62)], fill=hi)

    # Extra glyphs and eyes.
    d.ellipse((28, 18, 30, 20), fill=spark)
    d.ellipse((34, 18, 36, 20), fill=spark)
    if prop in {"hammer", "sword", "blade", "lance"}:
        d.line((30, 48, 30, 64), fill=hi, width=1)

    # Upscale the sprite and crop to a tall silhouette.
    sprite = upscale_pixel_art(low, (256, 320))
    sprite = sprite.filter(ImageFilter.SMOOTH_MORE)
    return sprite


def guild_background(size, guild, seed):
    pal = guild_palette(guild)
    rng = random.Random(seed)
    img = Image.new("RGBA", size, pal["dark"])
    draw_radial_gradient(img, (size[0] // 2, size[1] // 2), pal["hi"], pal["base"])
    px = img.load()
    w, h = size
    for y in range(h):
        t = y / max(1, h - 1)
        for x in range(w):
            mix = 0.18 + 0.72 * (1.0 - abs(0.5 - t) * 1.6)
            px[x, y] = blend(pal["dark"], pal["base"], max(0, min(1, mix)))
    draw = ImageDraw.Draw(img)
    # subtle environment details
    if guild == "flame":
        for i in range(10):
            x = rng.randrange(40, size[0] - 40)
            y = rng.randrange(size[1] // 3, size[1] - 30)
            draw.polygon([(x, y), (x - 8, y + 22), (x + 8, y + 22)], fill=pal["mid"])
        for i in range(16):
            x = rng.randrange(size[0])
            y = rng.randrange(size[1])
            r = rng.randrange(2, 5)
            draw.ellipse((x - r, y - r, x + r, y + r), fill=pal["spark"])
    elif guild == "sylvan":
        for i in range(15):
            x = rng.randrange(size[0])
            y = rng.randrange(size[1] // 4, size[1])
            draw.ellipse((x - 5, y - 3, x + 7, y + 5), fill=pal["mid"])
        for i in range(12):
            x = rng.randrange(size[0])
            y = rng.randrange(size[1])
            draw.line((x, y, x + rng.randrange(-14, 14), y + rng.randrange(-14, 14)), fill=pal["hi"], width=2)
    elif guild == "shadow":
        for i in range(5):
            cx = rng.randrange(30, size[0] - 30)
            cy = rng.randrange(40, size[1] - 40)
            draw.ellipse((cx - 20, cy - 20, cx + 20, cy + 20), outline=pal["mid"], width=3)
        for i in range(30):
            x = rng.randrange(size[0])
            y = rng.randrange(size[1])
            r = rng.randrange(1, 4)
            draw.ellipse((x - r, y - r, x + r, y + r), fill=pal["spark"])
    elif guild == "light":
        for i in range(12):
            cx = rng.randrange(30, size[0] - 30)
            cy = rng.randrange(25, size[1] - 25)
            draw.line((cx - 18, cy, cx + 18, cy), fill=pal["hi"], width=2)
            draw.line((cx, cy - 18, cx, cy + 18), fill=pal["hi"], width=2)
    return add_vignette(add_noise(img, rng, 90), 100)


def spell_symbol(card, size, rng):
    effect_ops = card.get("effect", [])
    kinds = {op.get("op") for op in effect_ops}
    guild = card["guild"]
    pal = guild_palette(guild)
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = size[0] // 2, size[1] // 2

    def glow_circle(r, fill, outline=None):
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=fill, outline=outline)

    # generic motif per guild
    if guild == "flame":
        d.polygon([(cx, cy - 60), (cx - 28, cy + 8), (cx, cy + 52), (cx + 28, cy + 8)], fill=pal["hi"])
        d.polygon([(cx, cy - 42), (cx - 20, cy + 10), (cx, cy + 38), (cx + 20, cy + 10)], fill=pal["mid"])
    elif guild == "sylvan":
        d.ellipse((cx - 42, cy - 30, cx + 42, cy + 34), fill=pal["mid"])
        for ang in range(0, 360, 36):
            rad = math.radians(ang)
            x1 = cx + int(math.cos(rad) * 18)
            y1 = cy + int(math.sin(rad) * 18)
            x2 = cx + int(math.cos(rad) * 52)
            y2 = cy + int(math.sin(rad) * 52)
            d.line((x1, y1, x2, y2), fill=pal["hi"], width=4)
    elif guild == "shadow":
        glow_circle(52, pal["base"], pal["mid"])
        d.arc((cx - 46, cy - 46, cx + 46, cy + 46), 20, 330, fill=pal["hi"], width=4)
        d.arc((cx - 30, cy - 30, cx + 30, cy + 30), 200, 120, fill=pal["spark"], width=3)
    elif guild == "light":
        glow_circle(48, pal["mid"], pal["hi"])
        for ang in range(0, 360, 18):
            rad = math.radians(ang)
            x1 = cx + int(math.cos(rad) * 24)
            y1 = cy + int(math.sin(rad) * 24)
            x2 = cx + int(math.cos(rad) * 62)
            y2 = cy + int(math.sin(rad) * 62)
            d.line((x1, y1, x2, y2), fill=pal["hi"], width=3)

    # effect-specific overlays
    if "damage_all_enemies" in kinds or "damage" in kinds:
        for ang in range(0, 360, 45):
            rad = math.radians(ang)
            x1 = cx + int(math.cos(rad) * 10)
            y1 = cy + int(math.sin(rad) * 10)
            x2 = cx + int(math.cos(rad) * 78)
            y2 = cy + int(math.sin(rad) * 78)
            d.line((x1, y1, x2, y2), fill=pal["spark"], width=4)
    if "heal" in kinds or "heal_master" in kinds:
        d.ellipse((cx - 18, cy - 38, cx + 18, cy + 38), outline=pal["spark"], width=6)
        d.line((cx - 10, cy, cx + 10, cy), fill=pal["spark"], width=6)
        d.line((cx, cy - 10, cx, cy + 10), fill=pal["spark"], width=6)
    if "shield" in kinds:
        d.polygon([(cx, cy - 56), (cx + 34, cy - 26), (cx + 26, cy + 36), (cx, cy + 56), (cx - 26, cy + 36), (cx - 34, cy - 26)], outline=pal["hi"], fill=(0, 0, 0, 0), width=6)
    if "draw" in kinds:
        for i in range(3):
            off = i * 8 - 8
            d.rectangle((cx - 20 + off, cy - 24 - off, cx + 14 + off, cy + 6 - off), outline=pal["spark"], width=3)
    if "stones" in kinds:
        for i in range(4):
            x = cx - 30 + i * 18
            d.polygon([(x, cy + 26), (x - 8, cy + 10), (x, cy - 6), (x + 8, cy + 10)], fill=pal["spark"])
    if "sacrifice" in kinds:
        d.polygon([(cx - 18, cy + 30), (cx + 18, cy + 30), (cx + 28, cy + 44), (cx - 28, cy + 44)], fill=pal["dark"])
        d.line((cx, cy - 16, cx, cy + 22), fill=pal["spark"], width=4)
    if "buff" in kinds:
        d.line((cx, cy + 36, cx, cy - 28), fill=pal["hi"], width=4)
        d.polygon([(cx, cy - 36), (cx - 10, cy - 20), (cx + 10, cy - 20)], fill=pal["spark"])

    # seed the composition with small particles and runes.
    for i in range(10):
        ang = rng.random() * math.tau
        dist = 30 + rng.random() * 60
        x = cx + int(math.cos(ang) * dist)
        y = cy + int(math.sin(ang) * dist * 0.7)
        r = rng.randrange(1, 4)
        d.ellipse((x - r, y - r, x + r, y + r), fill=pal["spark"])
    return layer.filter(ImageFilter.GaussianBlur(1))


def card_scene(card):
    cid = card["id"]
    guild = card["guild"]
    kind = card["kind"]
    seed = seed_for(cid)
    rng = random.Random(seed)
    pal = guild_palette(guild)
    base = Image.new("RGBA", (256, 256), pal["dark"])
    draw_radial_gradient(base, (128, 112), pal["hi"], pal["base"])
    base = add_vignette(base, 120)
    d = ImageDraw.Draw(base)

    # horizon / atmosphere
    if guild == "flame":
        for y in range(160, 250, 6):
            d.line((0, y, 255, y - rng.randrange(-3, 4)), fill=pal["mid"], width=2)
        for i in range(18):
            x = rng.randrange(256)
            y = rng.randrange(110, 256)
            d.ellipse((x - 2, y - 2, x + 2, y + 2), fill=pal["spark"])
    elif guild == "sylvan":
        for i in range(15):
            x = rng.randrange(256)
            y = rng.randrange(120, 256)
            d.ellipse((x - 3, y - 2, x + 5, y + 4), fill=pal["mid"])
    elif guild == "shadow":
        for i in range(6):
            x = rng.randrange(20, 236)
            y = rng.randrange(30, 180)
            d.arc((x - 18, y - 18, x + 18, y + 18), 20, 330, fill=pal["hi"], width=3)
        d.ellipse((84, 22, 172, 110), outline=pal["mid"], width=4)
    elif guild == "light":
        for i in range(14):
            x = rng.randrange(256)
            d.line((x, 0, x + rng.randrange(-20, 20), 160), fill=pal["hi"], width=2)
        d.ellipse((82, 18, 174, 110), outline=pal["hi"], width=4)

    if kind == "monster":
        sprite = draw_unit_sprite(card)
        # shrink slightly and place on the card scene.
        sprite = sprite.resize((176, 220), Image.Resampling.LANCZOS)
        shadow = shadow_blob((256, 256), (128, 220), 42, 120)
        base = Image.alpha_composite(base, shadow)
        base.alpha_composite(sprite, (40, 24))
    else:
        icon = spell_symbol(card, (256, 256), rng)
        base = Image.alpha_composite(base, icon)
        # give each spell a distinct focal object.
        if any(op.get("op") == "draw" for op in card.get("effect", [])):
            d.rectangle((96, 128, 160, 168), outline=pal["spark"], width=4)
        if any(op.get("op") == "sacrifice" for op in card.get("effect", [])):
            d.polygon([(128, 168), (108, 210), (148, 210)], fill=pal["dark"])

    # Final polish.
    base = base.filter(ImageFilter.SMOOTH_MORE)
    return upscale_pixel_art(base, (1024, 1024))


def ensure_dir(path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)


def main() -> int:
    force = "--force" in sys.argv
    cards = json.loads(CARDS_JSON.read_text(encoding="utf-8"))["cards"]
    by_id = {card["id"]: card for card in cards}
    for cid in sorted(TARGET_IDS):
        card = by_id[cid]
        if card["kind"] == "monster":
            unit_path = UNITS_DIR / f"{cid}.png"
            card_path = CARDS_DIR / f"{cid}.png"
            if force or not unit_path.exists():
                ensure_dir(unit_path)
                sprite = draw_unit_sprite(card)
                sprite.save(unit_path)
            if force or not card_path.exists():
                ensure_dir(card_path)
                scene = card_scene(card)
                scene.save(card_path)
        else:
            card_path = CARDS_DIR / f"{cid}.png"
            if force or not card_path.exists():
                ensure_dir(card_path)
                scene = card_scene(card)
                scene.save(card_path)
        print(f"OK {cid}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
