#!/usr/bin/env python3
"""Pixel-art asset regeneration (pixel-art branch) via OpenAI gpt-image-2.

Overwrites the same asset paths as the gouache pipeline, so the game code is
untouched: card illustrations, portraits, backgrounds, UI chrome and the card
frame templates all switch to a cohesive chibi pixel-art style.

Usage:
  python tools/gen_pixel_assets.py test          # 3 style samples in scratch
  python tools/gen_pixel_assets.py cards|portraits|backgrounds|ui|templates|all
"""

import base64
import json
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UI = ROOT / "assets" / "sprites" / "ui"
MODEL = "gpt-image-2"
URL_GEN = "https://api.openai.com/v1/images/generations"

# --- style ---------------------------------------------------------------

PX = ("Detailed high-quality fantasy PIXEL ART, 16-bit SNES-era style upscaled, "
      "crisp 1px dark outlines, rich dithered shading, vibrant saturated palette, "
      "chibi proportions, charming and readable silhouette. No text, no watermark.")

PX_SCENE = ("Detailed high-quality fantasy PIXEL ART environment, 16-bit SNES-era "
            "style upscaled, crisp dark outlines, rich dithered shading, moody "
            "lighting, vibrant palette. No characters, no text, no watermark.")

PX_UI = ("High-quality fantasy game UI PIXEL ART asset, 16-bit style upscaled, "
         "crisp 1px dark outlines, gold trim, clean readable shapes. No text.")

GUILD_HINT = {
    "flame": "warm palette of reds, oranges and embers",
    "sylvan": "fresh palette of greens, moss and golden light",
    "shadow": "moody palette of violets, indigo and pale moonlight",
    "light": "radiant palette of gold, ivory and soft sky blue",
}


def read_key() -> str:
    for line in (ROOT / ".env").read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("OPENAI_API_KEY="):
            return line.strip().split("=", 1)[1]
    sys.exit("OPENAI_API_KEY introuvable dans .env")


def chroma_key(raw: bytes) -> bytes:
    """gpt-image-2 has no transparent background: key out pure magenta instead."""
    import io

    from PIL import Image
    img = Image.open(io.BytesIO(raw)).convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            score = (r + b) / 2 - g
            if r > 150 and b > 120 and score > 90:
                px[x, y] = (r, g, b, 0)
            elif r > 130 and b > 100 and score > 45:
                px[x, y] = (r, max(g, min(r, b)), b,
                            min(a, int(255 * (1.0 - (score - 45) / 60.0))))
    buf = io.BytesIO()
    img.save(buf, "PNG")
    return buf.getvalue()


def generate(prompt: str, size: str = "1024x1024", quality: str = "medium",
             transparent: bool = False) -> bytes:
    if transparent:
        prompt += (" The entire background must be solid pure magenta #FF00FF with "
                   "hard edges, nothing else on it.")
    body = {
        "model": MODEL, "prompt": prompt, "size": size, "quality": quality,
        "n": 1, "output_format": "png",
    }
    req = urllib.request.Request(
        URL_GEN, data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json",
                 "Authorization": "Bearer %s" % read_key()})
    last = None
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=300) as resp:
                data = json.load(resp)
            raw = base64.b64decode(data["data"][0]["b64_json"])
            return chroma_key(raw) if transparent else raw
        except urllib.error.HTTPError as e:
            last = "HTTP %d: %s" % (e.code, e.read()[:300])
            if e.code in (429, 500, 502, 503):
                time.sleep(15 * (attempt + 1))
                continue
        except Exception as e:  # noqa: BLE001
            last = str(e)
        time.sleep(8 * (attempt + 1))
    raise RuntimeError(last)


def out(path: Path, raw: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(raw)
    print("OK %s (%d ko)" % (path.relative_to(ROOT), len(raw) // 1024))


def manifest() -> dict:
    return json.loads((ROOT / "tools" / "asset_manifest.json").read_text(encoding="utf-8"))


def cards_data() -> list:
    return json.loads((ROOT / "resources/data/cards.json").read_text(encoding="utf-8"))["cards"]


# --- groups ----------------------------------------------------------------


def gen_cards(only: str | None = None) -> None:
    man = manifest()
    guild_of = {c["id"]: c["guild"] for c in cards_data()}
    for cid, subject in man["cards"].items():
        if only and cid != only:
            continue
        path = ROOT / "assets/sprites/cards" / f"{cid}.png"
        prompt = ("%s Subject: a single creature sprite — %s. Color mood: %s. "
                  "Centered on a simple dark dungeon-stone backdrop with a soft "
                  "vignette.") % (PX, subject, GUILD_HINT.get(guild_of.get(cid, ""), ""))
        out(path, generate(prompt, "1024x1024", "medium"))
        time.sleep(1)


def gen_units(only: str | None = None) -> None:
    """Detoured full-body battle sprites placed directly on board tiles."""
    man = manifest()
    guild_of = {c["id"]: c["guild"] for c in cards_data()}
    monsters = [c["id"] for c in cards_data() if c["kind"] == "monster"]
    jobs = [(mid, man["cards"][mid], GUILD_HINT.get(guild_of.get(mid, ""), ""))
            for mid in monsters]
    jobs += [(f"master_{pid}", man["portraits"][pid],
              "regal palette with gold accents") for pid in
             ("kiran", "willow", "grim", "aria")]
    for uid, subject, mood in jobs:
        if only and uid != only:
            continue
        path = ROOT / "assets/sprites/units" / f"{uid}.png"
        if path.exists():
            print("déjà là:", path.name)
            continue
        prompt = ("%s Subject: ONE single full-body creature battle sprite seen "
                  "from a slight three-quarter top-down angle, standing pose "
                  "facing the viewer, feet at the bottom — %s. Color mood: %s. "
                  "Soft shadow ellipse under the feet.") % (PX, subject, mood)
        out(path, generate(prompt, "1024x1024", "medium", transparent=True))
        time.sleep(1)


def gen_portraits() -> None:
    man = manifest()
    for pid, subject in man["portraits"].items():
        path = ROOT / "assets/portraits" / f"{pid}.png"
        prompt = ("%s Subject: a character portrait bust, facing slightly toward "
                  "the viewer — %s. Plain dark parchment backdrop.") % (PX, subject)
        out(path, generate(prompt, "1024x1024", "medium"))
        time.sleep(1)


def gen_backgrounds() -> None:
    man = manifest()
    for bid, subject in man["backgrounds"].items():
        path = ROOT / "assets/backgrounds" / f"{bid}.png"
        quality = "high" if bid in ("main_menu", "arena_day", "arena_night") else "medium"
        subject2 = subject
        if bid == "battle_table":
            subject2 = ("a top-down cobblestone and packed-earth arena ground with "
                        "grass tufts, torches and small props at the edges, like a "
                        "tactical RPG battlefield seen from above")
        out(path, generate("%s Scene: %s." % (PX_SCENE, subject2), "1536x1024", quality))
        time.sleep(1)


def gen_ui() -> None:
    jobs = [
        ("icon_stone", "a glowing blue faceted hexagonal mana crystal", True, "1024x1024", "medium"),
        ("icon_atk", "two crossed steel swords icon", True, "1024x1024", "medium"),
        ("icon_hp", "a bold red heart icon with a small glint", True, "1024x1024", "medium"),
        ("icon_xp", "a golden four-pointed star sparkle icon", True, "1024x1024", "medium"),
        ("icon_shield", "a round sturdy shield icon with blue sheen", True, "1024x1024", "medium"),
        ("app_icon", "a circular badge: a glowing blue rune stone crossed with a sword", True, "1024x1024", "high"),
        ("card_back", "an ornate trading card back with a central glowing blue rune stone and symmetrical dark blue filigree", False, "1024x1536", "high"),
        ("portrait_ring", "a round ornate golden frame ring, empty center, for a character portrait", True, "1024x1024", "high"),
        ("banner_ribbon", "a wide ornate golden ribbon banner with curled ends and an empty dark navy center strip", True, "1536x1024", "high"),
        ("cell_tile", "a single square arena floor plate of packed earth and dirt with a chiseled dark stone rim along all four edges, seen top-down, warm brown tones with small pebbles and grass wisps in the corners, fills the whole image edge to edge", False, "1024x1024", "medium"),
        ("panel_ornate", "a dark navy leather game UI panel with fine golden ornamental border along all four edges and corner flourishes, empty center, fills the whole image", False, "1024x1024", "high"),
        ("button_plate", "a dark bronze metal game UI button plate with a thin golden beveled rim along the edges, empty center, fills the whole image", False, "1536x1024", "high"),
        ("victory_bg", "triumphant golden laurel wreath and radiant rays over a cheering pixel-art arena crowd at night, golden confetti, warm glorious palette, darker empty area in the middle for UI text", False, "1536x1024", "high"),
        ("defeat_bg", "a cracked stone shield and fading embers in a dark rainy arena, cold blue-grey palette, melancholic, darker empty middle area", False, "1536x1024", "high"),
    ]
    for name, subject, transparent, size, quality in jobs:
        out(UI / f"{name}.png", generate("%s %s." % (PX_UI, subject), size, quality, transparent))
        time.sleep(1)
    # logo (texte voulu : exception au no-text)
    logo_prompt = ("High-quality fantasy game logo in PIXEL ART, 16-bit style upscaled: "
                   "the single word 'STONEBOUND' in bold carved stone capital letters "
                   "with glowing blue runic cracks and gold trim, epic, clean. "
                   "Exactly this word, spelled S-T-O-N-E-B-O-U-N-D.")
    out(UI / "logo.png", generate(logo_prompt, "1536x1024", "high", True))


TPL_MONSTER = (
    "Complete ornate fantasy trading-card frame TEMPLATE in high-quality PIXEL ART, "
    "16-bit style upscaled, crisp dark outlines, portrait orientation, flat front "
    "view, video game asset. Deep crimson and antique gold frame. Exact layout top "
    "to bottom: TOP-LEFT corner an octagonal gold socket holding a faceted gem whose "
    "flat face is solid pure magenta #FF00FF; across the top a dark NAME BANNER, "
    "empty; below it a slim dark SUBTITLE plate, empty; TOP-RIGHT corner a dark "
    "hexagonal medallion with a red-gold FLAME emblem; below, a large rectangular "
    "ART WINDOW filled with solid pure magenta #FF00FF with a thin gold fillet; "
    "under it a STAT BAND of four tall dark plates separated by gold pillars, each "
    "with a small engraved pale-gold label in its TOP half ('ATQ', 'PORTÉE', "
    "'NIVEAU MAX', 'PV') and a completely empty BOTTOM half; below, a large aged "
    "PARCHMENT rules box with gold border, empty; overlapping its bottom edge a "
    "small dark RARITY banner, empty; at the very bottom the word 'STONEBOUND' in "
    "small gold capitals. No other text anywhere.")


def gen_templates() -> None:
    if not (UI / "card_v2_monster_flame.png").exists():
        out(UI / "card_v2_monster_flame.png",
            generate(TPL_MONSTER, "1024x1536", "high"))
        time.sleep(1)
    if not (UI / "card_v2_spell_flame.png").exists():
        spell = TPL_MONSTER.replace(
            "under it a STAT BAND of four tall dark plates separated by gold pillars, each "
            "with a small engraved pale-gold label in its TOP half ('ATQ', 'PORTÉE', "
            "'NIVEAU MAX', 'PV') and a completely empty BOTTOM half; below, ", "below, ")
        out(UI / "card_v2_spell_flame.png", generate(spell, "1024x1536", "high"))


def gen_test() -> None:
    scratch = ROOT / "assets" / "px_test"
    man = manifest()
    out(scratch / "test_card.png", generate(
        "%s Subject: a single creature sprite — %s. Color mood: %s. Centered on a "
        "simple dark dungeon-stone backdrop with a soft vignette."
        % (PX, man["cards"]["flame_imp"], GUILD_HINT["flame"]), "1024x1024", "medium"))
    out(scratch / "test_arena.png", generate(
        "%s Scene: a top-down cobblestone and packed-earth arena ground with grass "
        "tufts, torches and small props at the edges, like a tactical RPG "
        "battlefield seen from above." % PX_SCENE, "1536x1024", "high"))
    out(scratch / "test_template.png", generate(TPL_MONSTER, "1024x1536", "high"))


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else "test"
    only = sys.argv[2] if len(sys.argv) > 2 else None
    if mode == "test":
        gen_test()
    if mode in ("cards", "all"):
        gen_cards(only)
    if mode == "units":
        gen_units(only)
    if mode in ("portraits", "all"):
        gen_portraits()
    if mode in ("backgrounds", "all"):
        gen_backgrounds()
    if mode in ("ui", "all"):
        gen_ui()
    if mode in ("templates", "all"):
        gen_templates()
    print("Terminé.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
