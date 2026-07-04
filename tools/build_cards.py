#!/usr/bin/env python3
"""Compose complete, print-quality card images (like a real TCG card):
Gemini-generated frame templates + card art + data-driven text, assembled
offline with Pillow into assets/sprites/cards_full/<id>.png.

Usage:
  python tools/build_cards.py --templates   # generate the 2 frame templates
  python tools/build_cards.py               # compose every card
  python tools/build_cards.py --only <id>   # recompose one card
"""

import base64
import io
import json
import sys
import time
import urllib.request
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
UI = ROOT / "assets" / "sprites" / "ui"
ART = ROOT / "assets" / "sprites" / "cards"
OUT = ROOT / "assets" / "sprites" / "cards_full"
MODEL = "gemini-2.5-flash-image"
URL = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent"

TEMPLATES = {
    "card_tpl_monster": (
        "Complete ornate fantasy trading card game frame template, portrait orientation, "
        "flat front view, video game asset. Layout from top to bottom: a wide empty ornate "
        "title banner across the top; in the top-left corner a hexagonal gem socket that is "
        "EMPTY inside; below, a large rectangular art window filled with solid pure magenta "
        "#FF00FF covering the upper half; below the art window one horizontal row of four "
        "identical blank dark metal stat plates with thin gold trim, all completely empty; "
        "the bottom quarter is an empty aged parchment text box with a fine gold border; at "
        "the very bottom a slim empty ribbon. Rich dark gold and deep crimson engraved "
        "style, perfectly symmetrical, crisp edges. Absolutely no text, no letters, no "
        "numbers, no icons anywhere."),
    "card_tpl_spell": (
        "Complete ornate fantasy trading card game frame template, portrait orientation, "
        "flat front view, video game asset. Layout from top to bottom: a wide empty ornate "
        "title banner across the top; in the top-left corner a hexagonal gem socket that is "
        "EMPTY inside; below, a large rectangular art window filled with solid pure magenta "
        "#FF00FF covering the upper half; the remaining bottom third is a single large empty "
        "aged parchment text box with a fine gold border and a small arcane diamond ornament "
        "at its top; at the very bottom a slim empty ribbon. Rich dark gold and deep sapphire "
        "arcane engraved style, perfectly symmetrical, crisp edges. Absolutely no text, no "
        "letters, no numbers, no icons anywhere."),
}


def read_api_key() -> str:
    for line in (ROOT / ".env").read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("GEMINI_API_KEY="):
            return line.strip().split("=", 1)[1]
    sys.exit("GEMINI_API_KEY introuvable dans .env")


def generate(prompt: str) -> bytes:
    body = json.dumps({
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"responseModalities": ["IMAGE"],
                             "imageConfig": {"aspectRatio": "3:4"}},
    }).encode()
    req = urllib.request.Request(f"{URL}?key={read_api_key()}", data=body,
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


def make_templates() -> None:
    for name, prompt in TEMPLATES.items():
        path = UI / f"{name}.png"
        if path.exists():
            print(f"déjà là: {path.name}")
            continue
        path.write_bytes(generate(prompt))
        print(f"OK {path.name}")


def _is_magenta(rgb) -> bool:
    r, g, b = rgb
    return r > 140 and b > 125 and g < 130 and (r + b) / 2 - g > 55


def magenta_window(img: Image.Image) -> tuple[int, int, int, int]:
    """Bounding box of the LARGE magenta art window (ignores the small cost gem:
    rows/columns are scanned through the card's center, where only the window is)."""
    px = img.convert("RGB").load()
    w, h = img.size
    ys = [y for y in range(0, h, 3) if _is_magenta(px[w // 2, y])]
    if not ys:
        sys.exit("fenêtre magenta introuvable dans le gabarit")
    y_mid = (min(ys) + max(ys)) // 2
    xs = [x for x in range(0, w, 3) if _is_magenta(px[x, y_mid])]
    return (min(xs), min(ys), max(xs) + 3, max(ys) + 3)


def gem_region(img: Image.Image, window: tuple) -> tuple[set, tuple[int, int]]:
    """The cost gem socket interior: flood-filled from a magenta pixel located
    ABOVE the art window (the golden ring isolates it from the window even when
    the gem overlaps the window's corner). Returns (pixel set, centroid)."""
    px = img.convert("RGB").load()
    w, h = img.size
    wy0 = window[1]
    seed = None
    for y in range(0, wy0, 2):
        for x in range(0, w, 2):
            if _is_magenta(px[x, y]):
                seed = (x, y)
                break
        if seed:
            break
    if seed is None:
        return set(), (int(w * 0.11), int(w * 0.11))
    pts: set = set()
    stack = [seed]
    while stack:
        x, y = stack.pop()
        if (x, y) in pts or not (0 <= x < w and 0 <= y < h):
            continue
        if not _is_magenta(px[x, y]):
            continue
        pts.add((x, y))
        stack.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])
    cx = sum(p[0] for p in pts) // len(pts)
    cy = sum(p[1] for p in pts) // len(pts)
    return pts, (cx, cy)


# --- composition --------------------------------------------------------

GUILD_NAMES = {"flame": "Flamme", "sylvan": "Sylve", "shadow": "Ombre", "light": "Lumière"}
GUILD_COLORS = {"flame": (226, 96, 60), "sylvan": (90, 168, 100),
                "shadow": (160, 120, 220), "light": (230, 195, 90)}
ATTACK_NAMES = {"melee": "Mêlée", "ranged": "Distance", "magic": "Magie"}
KEYWORD_NAMES = {"haste": "Célérité", "flying": "Vol", "armor": "Armure",
                 "riposte": "Riposte", "regen": "Régénération", "shield": "Bouclier"}
TARGETS = {"ally_monster": "un monstre allié", "enemy_monster": "un monstre ennemi",
           "any_monster": "un monstre"}


def describe_effect(ops: list) -> str:
    parts = []
    for op in ops:
        kind = op.get("op", "")
        if kind == "damage":
            parts.append("Inflige %d dégâts à %s." % (op["amount"], TARGETS.get(op.get("target"), "une cible")))
        elif kind == "damage_all_enemies":
            parts.append("Inflige %d dégâts à tous les monstres ennemis." % op["amount"])
        elif kind == "heal":
            parts.append("Soigne %d PV à %s." % (op["amount"], TARGETS.get(op.get("target"), "une cible")))
        elif kind == "heal_master":
            parts.append("Soigne %d PV à votre Maître." % op["amount"])
        elif kind == "buff":
            bits = []
            if op.get("atk"):
                bits.append("%+d ATQ" % op["atk"])
            if op.get("hp"):
                bits.append("%+d PV" % op["hp"])
            parts.append("Donne %s à %s." % (" et ".join(bits), TARGETS.get(op.get("target"), "une cible")))
        elif kind == "shield":
            parts.append("Donne un Bouclier à %s." % TARGETS.get(op.get("target"), "une cible"))
        elif kind == "draw":
            parts.append("Piochez %d carte(s)." % op["count"])
        elif kind == "stones":
            parts.append("Gagnez %d pierre(s)." % op["amount"])
        elif kind == "sacrifice":
            parts.append("Sacrifiez %s." % TARGETS.get(op.get("target"), "un allié"))
    return " ".join(parts)


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size)


F_TITLE = str(ROOT / "assets/fonts/Cinzel.ttf")
F_BODY = "C:/Windows/Fonts/georgia.ttf"
F_BODY_B = "C:/Windows/Fonts/georgiab.ttf"


def fit_text(draw: ImageDraw.ImageDraw, text: str, font_path: str, max_w: int,
             start: int, minimum: int = 18) -> ImageFont.FreeTypeFont:
    size = start
    while size > minimum:
        f = font(font_path, size)
        if draw.textlength(text, font=f) <= max_w:
            return f
        size -= 2
    return font(font_path, minimum)


def wrap(draw: ImageDraw.ImageDraw, text: str, f: ImageFont.FreeTypeFont, max_w: int) -> list[str]:
    lines = []
    for para in text.split("\n"):
        cur = ""
        for word in para.split():
            probe = (cur + " " + word).strip()
            if draw.textlength(probe, font=f) <= max_w:
                cur = probe
            else:
                if cur:
                    lines.append(cur)
                cur = word
        if cur:
            lines.append(cur)
    return lines


def outlined(draw: ImageDraw.ImageDraw, pos, text, f, fill, outline=(10, 8, 4), width=3,
             anchor="la") -> None:
    draw.text(pos, text, font=f, fill=fill, anchor=anchor,
              stroke_width=width, stroke_fill=outline)


def compose_card(card: dict, tpl: Image.Image, box: tuple, gem: tuple) -> Image.Image:
    img = tpl.copy().convert("RGBA")
    W, H = img.size
    bx0, by0, bx1, by1 = box
    bw, bh = bx1 - bx0, by1 - by0
    gem_pts, gem_c = gem
    is_monster = card.get("kind") == "monster"
    guild = card.get("guild", "flame")
    gc = GUILD_COLORS[guild]
    # 1) snapshot the gem socket zone (it may overlap the art window corner)
    gem_patch = None
    gem_box = None
    if gem_pts:
        gxs = [p[0] for p in gem_pts]
        gys = [p[1] for p in gem_pts]
        m = 18  # include the golden ring around the socket
        gem_box = (max(0, min(gxs) - m), max(0, min(gys) - m),
                   min(W, max(gxs) + m), min(H, max(gys) + m))
        gem_patch = img.crop(gem_box)
    # 2) art into the magenta window (cover fit, barely under the gold border
    # so no anti-aliased magenta edge survives but the frame stays visible)
    pad = 3
    bx0, by0, bx1, by1 = bx0 - pad, by0 - pad, bx1 + pad, by1 + pad
    bw, bh = bx1 - bx0, by1 - by0
    art_path = ART / f"{card['id']}.png"
    if art_path.exists():
        art = Image.open(art_path).convert("RGBA")
        scale = max(bw / art.width, bh / art.height)
        art = art.resize((int(art.width * scale) + 1, int(art.height * scale) + 1),
                         Image.LANCZOS)
        ax = (art.width - bw) // 2
        ay = max(0, (art.height - bh) // 3)  # favour the upper part of the art
        art = art.crop((ax, ay, ax + bw, ay + bh))
        img.paste(art, (bx0, by0))
    # 2b) engraved golden frame around the art window: the monster template's
    # own window trim is too thin, which made the art look pasted on top of
    # the card. A drawn double gold fillet seats the art into the frame.
    if is_monster:
        d2 = ImageDraw.Draw(img)
        rect = (bx0, by0, bx1 - 1, by1 - 1)

        def _inset(r, k):
            return (r[0] + k, r[1] + k, r[2] - k, r[3] - k)

        d2.rectangle(rect, outline=(28, 20, 12), width=3)
        d2.rectangle(_inset(rect, 3), outline=(214, 182, 122), width=5)
        d2.rectangle(_inset(rect, 8), outline=(120, 92, 52), width=2)
        d2.rectangle(_inset(rect, 10), outline=(28, 20, 12), width=2)
    # 3) restore the gem zone above the art: everything from the template except
    # leftover window magenta, then tint the socket interior and draw the cost
    if gem_patch is not None:
        gpx = gem_patch.load()
        mask = Image.new("L", gem_patch.size, 255)
        mpx = mask.load()
        for yy in range(gem_patch.size[1]):
            for xx in range(gem_patch.size[0]):
                r, g, b, _a = gpx[xx, yy]
                if _is_magenta((r, g, b)) \
                        and (xx + gem_box[0], yy + gem_box[1]) not in gem_pts:
                    mpx[xx, yy] = 0  # window magenta: keep the pasted art
        img.paste(gem_patch, (gem_box[0], gem_box[1]), mask)
    px = img.load()
    gem_fill = (gc[0] // 3 + 15, gc[1] // 3 + 10, gc[2] // 3 + 15, 255)
    for gx, gy in gem_pts:
        px[gx, gy] = gem_fill
    draw = ImageDraw.Draw(img)
    gold = (235, 214, 160)
    outlined(draw, gem_c, str(card.get("cost", 0)),
             font(F_TITLE, int(W * 0.085)), (255, 255, 255), width=6, anchor="mm")
    # 3) name centered in the title banner (measured per template kind)
    name = card["name"]
    banner_y = int(H * (0.072 if is_monster else 0.092))
    name_font = fit_text(draw, name, F_TITLE, int(W * 0.44), int(W * 0.058))
    outlined(draw, (int(W * 0.51), banner_y), name, name_font, (70, 50, 25),
             outline=(240, 228, 200), width=2, anchor="mm")
    # 4) guild diamond at the right end of the banner
    pr = int(W * 0.018)
    pc = (int(W * 0.795), banner_y)
    draw.polygon([(pc[0], pc[1] - pr), (pc[0] + pr, pc[1]),
                  (pc[0], pc[1] + pr), (pc[0] - pr, pc[1])],
                 fill=gc, outline=(60, 45, 25))
    # 5) stat plates row (monsters) — measured on the template
    if is_monster:
        # One centered line per plate — the template plates (~60px tall, starting
        # right under the art window) cannot fit stacked label + value.
        levels = card["levels"]
        atk_type = ATTACK_NAMES.get(card.get("attack_type", "melee"), "?")
        values = ["ATQ %d" % levels[0]["atk"], "PV %d" % levels[0]["hp"],
                  atk_type, "Niv %d" % len(levels)]
        centers = [0.206, 0.408, 0.612, 0.812]
        for i in range(4):
            cx = int(W * centers[i])
            vf = font(F_TITLE, int(W * 0.032) if len(values[i]) <= 6 else int(W * 0.027))
            outlined(draw, (cx, int(H * 0.629)), values[i], vf,
                     (255, 250, 235), width=4, anchor="mm")
    # 6) rules text in the parchment box
    text_lines: list[str] = []
    if is_monster:
        kws = []
        for kw, val in card.get("keywords", {}).items():
            n = KEYWORD_NAMES.get(kw, kw)
            kws.append(n if val is True else "%s %d" % (n, val))
        if kws:
            text_lines.append("• " + ", ".join(kws) + ".")
        lv_bits = []
        for i, lv in enumerate(card["levels"][1:], start=2):
            lv_bits.append("Niv %d (%d XP) : %d/%d" % (i, lv["xp"], lv["atk"], lv["hp"]))
        if lv_bits:
            text_lines.append("• " + " — ".join(lv_bits) + ".")
        if card.get("evolves_to"):
            text_lines.append("• Évolue au niveau max (%d pierres)." % card.get("evolve_cost", 0))
    else:
        text_lines.append(describe_effect(card.get("effect", [])))
    if card.get("flavor"):
        text_lines.append("« %s »" % card["flavor"])
    box_top = int(H * (0.690 if is_monster else 0.655))
    box_bottom = int(H * (0.905 if is_monster else 0.880))
    max_w = int(W * 0.70)
    body_size = int(W * 0.036)
    f_body = font(F_BODY, body_size)
    lines: list[tuple[str, ImageFont.FreeTypeFont]] = []
    for i, seg in enumerate(text_lines):
        is_flavor = seg.startswith("«")
        f_seg = font(F_BODY, int(body_size * 0.9)) if is_flavor else f_body
        for ln in wrap(draw, seg, f_seg, max_w):
            lines.append((ln, f_seg))
    lh = int(body_size * 1.35)
    while len(lines) * lh > (box_bottom - box_top) and body_size > 20:
        body_size -= 2
        f_body = font(F_BODY, body_size)
        lh = int(body_size * 1.35)
        lines = []
        for seg in text_lines:
            is_flavor = seg.startswith("«")
            f_seg = font(F_BODY, int(body_size * 0.9)) if is_flavor else f_body
            for ln in wrap(draw, seg, f_seg, max_w):
                lines.append((ln, f_seg))
    y = box_top + ((box_bottom - box_top) - len(lines) * lh) // 2
    for ln, f_seg in lines:
        fill = (60, 45, 30) if f_seg.size == body_size else (95, 75, 55)
        draw.text((W // 2, y), ln, font=f_seg, fill=fill, anchor="ma")
        y += lh
    # 7) bottom ribbon
    draw.text((W // 2, int(H * (0.951 if is_monster else 0.945))), "STONEBOUND",
              font=font(F_TITLE, int(W * 0.026)), fill=(100, 80, 52), anchor="mm")
    return img


def auto_trim(img: Image.Image) -> Image.Image:
    """Crops away the bright background surrounding the card's dark border."""
    g = img.convert("L")
    px = g.load()
    w, h = g.size

    def col_bright(x: int) -> float:
        return sum(px[x, y] for y in range(4, h - 4, 8)) / len(range(4, h - 4, 8))

    def row_bright(y: int) -> float:
        return sum(px[x, y] for x in range(4, w - 4, 8)) / len(range(4, w - 4, 8))

    limit_x, limit_y = int(w * 0.10), int(h * 0.10)
    x0 = 0
    while x0 < limit_x and col_bright(x0) > 140:
        x0 += 1
    x1 = w - 1
    while x1 > w - limit_x and col_bright(x1) > 140:
        x1 -= 1
    y0 = 0
    while y0 < limit_y and row_bright(y0) > 140:
        y0 += 1
    y1 = h - 1
    while y1 > h - limit_y and row_bright(y1) > 140:
        y1 -= 1
    pad = 3  # eat the anti-aliased light fringe too
    return img.crop((x0 + pad, y0 + pad, x1 - pad + 1, y1 - pad + 1))


def main() -> int:
    if "--templates" in sys.argv:
        make_templates()
        return 0
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else None
    cards = json.loads((ROOT / "resources/data/cards.json").read_text(encoding="utf-8"))["cards"]
    OUT.mkdir(parents=True, exist_ok=True)
    tpls = {}
    for kind, name in [("monster", "card_tpl_monster"), ("spell", "card_tpl_spell")]:
        tpl = Image.open(UI / f"{name}.png")
        win = magenta_window(tpl)
        tpls[kind] = (tpl, win, gem_region(tpl, win))
    for card in cards:
        if only and card["id"] != only:
            continue
        tpl, box, gem = tpls[card.get("kind", "monster")]
        img = compose_card(card, tpl, box, gem)
        # trim the template's light outer surround, then round the corners in alpha
        img = auto_trim(img)
        img = img.resize((640, int(640 * img.height / img.width)), Image.LANCZOS)
        mask = Image.new("L", img.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            (0, 0, img.width - 1, img.height - 1), radius=int(img.width * 0.05), fill=255)
        img.putalpha(mask)
        img.save(OUT / f"{card['id']}.png")
        print(f"OK {card['id']}")
    print("Cartes composées.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
