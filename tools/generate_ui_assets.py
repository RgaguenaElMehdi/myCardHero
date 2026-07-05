#!/usr/bin/env python3
"""HQ UI chrome via Gemini: card frame, panels, buttons, arena tiles, logo,
victory/defeat art. Elements needing transparency are generated on a pure
magenta background then chroma-keyed to alpha with Pillow.

Idempotent (skips existing). `--force NAME` regenerates one asset.
"""

import base64
import json
import sys
import time
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites" / "ui"
MODEL = "gemini-2.5-flash-image"
URL = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent"

MAGENTA_HINT = ("The entire background and every empty area MUST be solid pure magenta "
                "#FF00FF with hard edges, no gradients into the magenta, no shadows on it.")

# name -> (prompt, aspect, chroma_key)
ASSETS = {
    "card_frame": (
        "Ornate engraved golden fantasy trading-card frame border with subtle blue gem "
        "accents in the corners, elegant filigree, medium thickness border around the card "
        "edge only, completely empty center. Flat front view, perfectly symmetrical, "
        "video game asset. " + MAGENTA_HINT, "3:4", True),
    "portrait_ring": (
        "Round ornate golden frame ring for a character portrait, engraved laurel details, "
        "empty center, flat front view, perfectly circular, video game asset. "
        + MAGENTA_HINT, "1:1", True),
    "banner_ribbon": (
        "Wide ornate golden ribbon banner with elegant curled ends and a dark navy empty "
        "center strip, flat front view, symmetrical, fantasy game UI asset. "
        + MAGENTA_HINT, "16:9", True),
    "logo": (
        "Fantasy video game logo of the single word 'STONEBOUND' in carved stone capital "
        "letters with glowing blue runic cracks and a subtle golden trim, epic and clean, "
        "flat front view. " + MAGENTA_HINT, "16:9", True),
    "cell_tile": (
        "Seamless square dark slate stone floor tile with a very subtle carved rune circle "
        "in the center, top-down view, muted cool grey-blue tones, soft even lighting, "
        "video game board tile texture, fills the whole image edge to edge, no border.",
        "1:1", False),
    "panel_ornate": (
        "Dark fantasy game UI panel texture: deep navy leather with fine golden ornamental "
        "border trim running along all four edges and small corner flourishes, empty dark "
        "center, flat front view, fills the whole image edge to edge.", "1:1", False),
    "button_plate": (
        "Fantasy game UI button texture: brushed dark bronze metal plate with a thin golden "
        "beveled rim along all four edges, empty center, flat front view, fills the whole "
        "image edge to edge.", "3:2", False),
    "victory_bg": (
        "Triumphant fantasy scene: golden laurel wreath and radiant light rays over a "
        "celebrating arena at night, golden confetti and sparks, warm glorious palette, "
        "painterly, empty darker area in the middle for UI text, no text.", "16:9", False),
    "defeat_bg": (
        "Somber fantasy scene: a cracked stone shield and fading embers in a dark rainy "
        "arena, cold blue-grey palette, melancholic painterly mood, empty darker area in "
        "the middle for UI text, no text.", "16:9", False),
    # --- Additional HUD/UI assets (from sprite sheet reference) ---
    "panel_hud": (
        "Dark fantasy game UI HUD panel texture: dark steel plate with ornate riveted "
        "border, subtle golden inlay lines at edges, empty dark interior, flat front view, "
        "fills the whole image edge to edge.", "4:3", False),
    "bar_hp_frame": (
        "Fantasy game UI health bar frame texture: ornate dark metal frame with a small "
        "red heart gem on the left end, long rectangular slot in the center for a fill bar, "
        "golden trim, flat front view, fills the whole image edge to edge.", "6:1", False),
    "bar_hp_fill": (
        "Solid gradient fill texture for a health bar: deep red on the left fading to "
        "bright crimson on the right, slight glossy highlight on top half, clean edges, "
        "flat front view, fills the whole image edge to edge.", "6:1", False),
    "bar_mana_frame": (
        "Fantasy game UI mana bar frame texture: ornate dark metal frame with a small "
        "blue crystal gem on the left end, long rectangular slot in the center for a fill bar, "
        "golden trim, flat front view, fills the whole image edge to edge.", "6:1", False),
    "bar_mana_fill": (
        "Solid gradient fill texture for a mana bar: deep blue on the left fading to "
        "bright cyan on the right, slight glossy highlight on top half, clean edges, "
        "flat front view, fills the whole image edge to edge.", "6:1", False),
    "button_red": (
        "Fantasy game UI button texture: dark red brushed metal plate with thin golden "
        "beveled rim, darker center, flat front view, fills the whole image edge to edge.",
        "3:2", False),
    "button_blue": (
        "Fantasy game UI button texture: dark blue brushed metal plate with thin golden "
        "beveled rim, darker center, flat front view, fills the whole image edge to edge.",
        "3:2", False),
    "button_green": (
        "Fantasy game UI button texture: dark green brushed metal plate with thin golden "
        "beveled rim, darker center, flat front view, fills the whole image edge to edge.",
        "3:2", False),
    "panel_tooltip": (
        "Fantasy game UI tooltip panel: small dark parchment rectangle with thin golden "
        "border and a small pointed tab on the left edge, flat front view, "
        "fills the whole image edge to edge.", "3:2", False),
    "icon_flame": (
        "Stylized fantasy game icon of a flame faction emblem: a red-orange fire symbol, "
        "bold silhouette, centered on plain dark background, no text.",
        "1:1", True),
    "icon_sylvan": (
        "Stylized fantasy game icon of a nature faction emblem: a green leaf/vine symbol, "
        "bold silhouette, centered on plain dark background, no text.",
        "1:1", True),
    "icon_shadow": (
        "Stylized fantasy game icon of a shadow faction emblem: a purple crescent/skull symbol, "
        "bold silhouette, centered on plain dark background, no text.",
        "1:1", True),
    "icon_light": (
        "Stylized fantasy game icon of a light faction emblem: a golden sun/star symbol, "
        "bold silhouette, centered on plain dark background, no text.",
        "1:1", True),
    "torch_decoration": (
        "Small fantasy torch wall sconce with a flickering orange flame, dark iron bracket, "
        "flat front view, video game UI decoration element. " + MAGENTA_HINT,
        "1:2", True),
}


def read_api_key() -> str:
    for line in (ROOT / ".env").read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("GEMINI_API_KEY="):
            return line.strip().split("=", 1)[1]
    sys.exit("GEMINI_API_KEY introuvable dans .env")


def generate(api_key: str, prompt: str, aspect: str) -> bytes:
    body = json.dumps({
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"responseModalities": ["IMAGE"],
                             "imageConfig": {"aspectRatio": aspect}},
    }).encode()
    req = urllib.request.Request(f"{URL}?key={api_key}", data=body,
                                 headers={"Content-Type": "application/json"})
    last = None
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                data = json.load(resp)
            for part in data["candidates"][0]["content"].get("parts", []):
                blob = part.get("inlineData")
                if blob and blob.get("mimeType", "").startswith("image/"):
                    return base64.b64decode(blob["data"])
            last = "réponse sans image"
        except Exception as e:  # noqa: BLE001
            last = str(e)
        time.sleep(5 * (attempt + 1))
    raise RuntimeError(last)


def chroma_key(raw: bytes) -> Image.Image:
    """Magenta -> transparent, with soft edges and de-spill."""
    img = Image.open(__import__("io").BytesIO(raw)).convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            score = (r + b) / 2 - g  # high = magenta-ish
            if r > 120 and b > 120 and score > 110:
                px[x, y] = (r, g, b, 0)
            elif r > 100 and b > 100 and score > 55:
                alpha = int(255 * (1.0 - (score - 55) / 70.0))
                px[x, y] = (min(r, 255), max(g, min(r, b)), min(b, 255),
                            max(0, min(a, alpha)))
    return img


def main() -> int:
    force = sys.argv[sys.argv.index("--force") + 1] if "--force" in sys.argv else None
    api_key = read_api_key()
    OUT.mkdir(parents=True, exist_ok=True)
    failures = []
    for name, (prompt, aspect, keyed) in ASSETS.items():
        path = OUT / f"{name}.png"
        if path.exists() and force != name:
            continue
        try:
            raw = generate(api_key, prompt, aspect)
            if keyed:
                chroma_key(raw).save(path)
            else:
                path.write_bytes(raw)
            print(f"OK  {path.name}")
        except Exception as e:  # noqa: BLE001
            failures.append(name)
            print(f"FAIL {name}: {e}", file=sys.stderr)
        time.sleep(1)
    if failures:
        print(f"{len(failures)} échec(s): {failures}", file=sys.stderr)
        return 1
    print("Assets UI complets.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
