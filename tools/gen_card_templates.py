#!/usr/bin/env python3
"""Generate the v2 card frame templates (reference-quality layout):
one master per kind (monster/spell) in the Flame style, then 3 faction
recolors each via Gemini image editing (layout stays identical, so the
compositor's anchors work for all factions).

Usage:
  python tools/gen_card_templates.py master     # the 2 flame masters
  python tools/gen_card_templates.py variants   # 6 faction recolors
  python tools/gen_card_templates.py all
"""

import base64
import json
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites" / "ui"
MODEL = "gemini-2.5-flash-image"
URL = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent"

LAYOUT_MONSTER = (
    "Complete ornate fantasy trading-card game frame TEMPLATE, portrait orientation, flat "
    "front view, video game asset, premium engraved style like a AAA card game. Deep "
    "crimson and antique gold frame with dragon-scale texture. Exact layout, top to "
    "bottom: in the TOP-LEFT corner, an octagonal antique-gold socket holding a large "
    "faceted gem whose flat front face is solid pure magenta #FF00FF; across the top, a "
    "dark leather NAME BANNER, completely empty; directly below the banner, a slim dark "
    "SUBTITLE plate with gold trim, completely empty; in the TOP-RIGHT corner, a dark "
    "hexagonal medallion with gold rim containing a stylized red-and-gold FLAME emblem; "
    "below, a big rectangular ART WINDOW filled with solid pure magenta #FF00FF, framed "
    "by a thin gold fillet; under the art window, a horizontal STAT BAND made of four "
    "tall dark metal plates separated by small gold pillars — each plate shows one small "
    "engraved label in pale gold capitals in its TOP half ('ATQ' with a tiny pale steel "
    "sword icon, then 'PORTÉE', then 'NIVEAU MAX', then 'PV' with a tiny DARK RED shield "
    "icon — the shield must be dark red, never pink) while the BOTTOM half of every plate "
    "is completely empty dark metal, reserved for a value; below the stat band, a "
    "large aged PARCHMENT rules box with a fine double gold border, completely empty; "
    "overlapping the parchment's bottom edge, a small dark RARITY banner with gold trim, "
    "empty; at the very bottom, the word 'STONEBOUND' in small elegant gold capitals. "
    "No other text, letters or numbers anywhere.")

LAYOUT_SPELL = LAYOUT_MONSTER.replace(
    "under the art window, a horizontal STAT BAND made of four "
    "dark metal plates separated by small gold pillars — the first plate contains a small "
    "pale steel SWORD icon above the engraved label 'ATQ', the second plate the engraved "
    "label 'PORTÉE', the third plate the engraved label 'NIVEAU MAX', the fourth plate a "
    "small RED SHIELD icon above the engraved label 'PV' — the labels are small pale gold "
    "capitals and leave empty space under each label for a value; below the stat band, ",
    "under the art window, ").replace(
    "a stylized red-and-gold FLAME emblem",
    "a stylized red-and-gold FLAME emblem; the art window is slightly taller")

FACTIONS = {
    "sylvan": ("deep forest green and antique gold, with leafy vine engravings",
               "a stylized green LEAF emblem"),
    "shadow": ("deep violet and dark silver, with mystic crescent engravings",
               "a stylized pale CRESCENT MOON emblem"),
    "light": ("ivory, warm white and radiant gold, with sun-ray engravings",
              "a stylized golden SUN emblem"),
}


def read_api_key() -> str:
    for line in (ROOT / ".env").read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("GEMINI_API_KEY="):
            return line.strip().split("=", 1)[1]
    sys.exit("GEMINI_API_KEY introuvable dans .env")


def _call(parts: list) -> bytes:
    body = json.dumps({
        "contents": [{"parts": parts}],
        "generationConfig": {"responseModalities": ["IMAGE"],
                             "imageConfig": {"aspectRatio": "3:4"}},
    }).encode()
    req = urllib.request.Request(f"{URL}?key={read_api_key()}", data=body,
                                 headers={"Content-Type": "application/json"})
    last = None
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=180) as resp:
                data = json.load(resp)
            for part in data["candidates"][0]["content"].get("parts", []):
                blob = part.get("inlineData")
                if blob and blob.get("mimeType", "").startswith("image/"):
                    return base64.b64decode(blob["data"])
            last = "réponse sans image"
        except Exception as e:  # noqa: BLE001
            last = str(e)
        time.sleep(6 * (attempt + 1))
    raise RuntimeError(last)


def generate(prompt: str) -> bytes:
    return _call([{"text": prompt}])


def edit(prompt: str, image: bytes) -> bytes:
    return _call([
        {"inlineData": {"mimeType": "image/png",
                        "data": base64.b64encode(image).decode()}},
        {"text": prompt},
    ])


def make_masters() -> None:
    for name, prompt in [("card_v2_monster_flame", LAYOUT_MONSTER),
                         ("card_v2_spell_flame", LAYOUT_SPELL)]:
        path = OUT / f"{name}.png"
        if path.exists():
            print(f"déjà là: {path.name}")
            continue
        path.write_bytes(generate(prompt))
        print(f"OK {path.name}")
        time.sleep(1)


def make_variants() -> None:
    for kind in ["monster", "spell"]:
        master = (OUT / f"card_v2_{kind}_flame.png").read_bytes()
        for fac, (palette, emblem) in FACTIONS.items():
            path = OUT / f"card_v2_{kind}_{fac}.png"
            if path.exists():
                print(f"déjà là: {path.name}")
                continue
            prompt = (
                "Recolor this trading card frame template to a %s color scheme. Replace "
                "the flame emblem inside the top-right hexagonal medallion with %s. Keep "
                "EVERYTHING else strictly identical: same exact layout, same positions "
                "and sizes of every element, keep the magenta #FF00FF areas exactly as "
                "they are (same shape and position), keep the engraved labels and the "
                "bottom word unchanged." % (palette, emblem))
            path.write_bytes(edit(prompt, master))
            print(f"OK {path.name}")
            time.sleep(1)


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else "all"
    if mode in ("master", "all"):
        make_masters()
    if mode in ("variants", "all"):
        make_variants()
    return 0


if __name__ == "__main__":
    sys.exit(main())
