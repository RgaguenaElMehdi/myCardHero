#!/usr/bin/env python3
"""Compose complete, print-quality card images (reference-grade TCG layout):
Gemini-generated faction frame templates (v2) + card art + data-driven text,
assembled offline with Pillow into assets/sprites/cards_full/<id>.png.

Templates come from tools/gen_card_templates.py:
  assets/sprites/ui/card_v2_{monster|spell}_{flame|sylvan|shadow|light}.png

Usage:
  python tools/build_cards.py               # compose every card
  python tools/build_cards.py --only <id>   # recompose one card
"""

import json
import sys
from pathlib import Path  # noqa: F401 — used for _art overrides

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
UI = ROOT / "assets" / "sprites" / "ui"
ART = ROOT / "assets" / "sprites" / "cards"
OUT = ROOT / "assets" / "sprites" / "cards_full"

GUILD_NAMES = {"flame": "Flamme", "sylvan": "Sylve", "shadow": "Ombre", "light": "Lumière"}
GUILD_COLORS = {"flame": (226, 96, 60), "sylvan": (90, 168, 100),
                "shadow": (160, 120, 220), "light": (230, 195, 90)}
ATTACK_NAMES = {"melee": "Mêlée", "ranged": "Distance", "magic": "Magie"}
KEYWORD_NAMES = {"haste": "Célérité", "flying": "Vol", "armor": "Armure",
                 "riposte": "Riposte", "regen": "Régénération", "shield": "Bouclier"}
TARGETS = {"ally_monster": "un monstre allié", "enemy_monster": "un monstre ennemi",
           "any_monster": "un monstre"}

F_TITLE = str(ROOT / "assets/fonts/Cinzel.ttf")
F_BODY = "C:/Windows/Fonts/georgia.ttf"

# Text anchors as (x, y) fractions of the template size, measured once on the
# masters (faction variants keep the same layout by construction).
ANCHORS = {
    "monster": {
        "name": (0.50, 0.093), "name_w": 0.44,
        "subtitle": (0.50, 0.169),
        "stat_xs": [0.199, 0.401, 0.604, 0.800], "stat_y": 0.583,
        "text_top": 0.660, "text_bottom": 0.880,
        "rarity": (0.50, 0.920),
    },
    "spell": {
        "name": (0.49, 0.091), "name_w": 0.44,
        "subtitle": (0.50, 0.150),
        "text_top": 0.690, "text_bottom": 0.880,
        "rarity": (0.50, 0.921),
    },
}


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


def rarity_of(card: dict) -> str:
    if card.get("token"):
        return "ASCENDANT"
    cost = card.get("cost", 0)
    if cost <= 2:
        return "COMMUNE"
    if cost <= 4:
        return "RARE"
    return "ÉPIQUE"


# --- template analysis ---------------------------------------------------


def _is_magenta(rgb) -> bool:
    """Pink-family detector, tolerant to the hue drift the Gemini image edits
    introduce in the faction variants. Excludes violet (b >> r), crimson
    (low b), gold and ivory (low r-g)."""
    r, g, b = rgb
    return r > 120 and r - g > 45 and b - g > 20 and r >= b - 15


def magenta_window(img: Image.Image) -> tuple:
    """Bounding box of the LARGE art window (scanned through the card center)."""
    px = img.convert("RGB").load()
    w, h = img.size
    ys = [y for y in range(0, h, 3) if _is_magenta(px[w // 2, y])]
    if not ys:
        sys.exit("fenêtre magenta introuvable dans le gabarit")
    y_mid = (min(ys) + max(ys)) // 2
    xs = [x for x in range(0, w, 3) if _is_magenta(px[x, y_mid])]
    return (min(xs), min(ys), max(xs) + 3, max(ys) + 3)


def gem_region(img: Image.Image, window: tuple) -> tuple:
    """Flood-fills the cost gem's magenta face (seeded above the art window)."""
    px = img.convert("RGB").load()
    w, h = img.size
    wy0 = window[1]
    seed = None
    for y in range(0, wy0, 2):
        for x in range(0, w // 2, 2):
            if _is_magenta(px[x, y]):
                seed = (x, y)
                break
        if seed:
            break
    if seed is None:
        return set(), (int(w * 0.14), int(w * 0.12))
    pts = set()
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


# --- drawing helpers -----------------------------------------------------


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size)


def fit_text(draw, text, font_path, max_w, start, minimum=18):
    size = start
    while size > minimum:
        f = font(font_path, size)
        if draw.textlength(text, font=f) <= max_w:
            return f
        size -= 2
    return font(font_path, minimum)


def wrap(draw, text, f, max_w):
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


def outlined(draw, pos, text, f, fill, outline=(20, 14, 8), width=3, anchor="mm"):
    draw.text(pos, text, font=f, fill=fill, anchor=anchor,
              stroke_width=width, stroke_fill=outline)


def ornament_divider(draw, cx, y, half_w, color=(150, 120, 70)):
    draw.line((cx - half_w, y, cx - 14, y), fill=color, width=2)
    draw.line((cx + 14, y, cx + half_w, y), fill=color, width=2)
    r = 7
    draw.polygon([(cx, y - r), (cx + r, y), (cx, y + r), (cx - r, y)],
                 fill=color, outline=(90, 68, 38))


def auto_trim(img: Image.Image) -> Image.Image:
    g = img.convert("L")
    px = g.load()
    w, h = g.size

    def col_bright(x):
        return sum(px[x, y] for y in range(4, h - 4, 8)) / len(range(4, h - 4, 8))

    def row_bright(y):
        return sum(px[x, y] for x in range(4, w - 4, 8)) / len(range(4, w - 4, 8))

    lx, ly = int(w * 0.10), int(h * 0.10)
    x0 = 0
    while x0 < lx and col_bright(x0) > 140:
        x0 += 1
    x1 = w - 1
    while x1 > w - lx and col_bright(x1) > 140:
        x1 -= 1
    y0 = 0
    while y0 < ly and row_bright(y0) > 140:
        y0 += 1
    y1 = h - 1
    while y1 > h - ly and row_bright(y1) > 140:
        y1 -= 1
    pad = 3
    return img.crop((x0 + pad, y0 + pad, x1 - pad + 1, y1 - pad + 1))


# --- composition ----------------------------------------------------------


def compose_card(card: dict, tpl: Image.Image, box: tuple, gem: tuple) -> Image.Image:
    img = tpl.copy().convert("RGBA")
    W, H = img.size
    kind = "monster" if card.get("kind") == "monster" else "spell"
    a = ANCHORS[kind]
    guild = card.get("guild", "flame")
    gc = GUILD_COLORS[guild]
    gem_pts, gem_c = gem
    bx0, by0, bx1, by1 = box

    # 1) snapshot the gem zone (it may overlap the window corner)
    gem_patch = None
    gem_box = None
    if gem_pts:
        gxs = [p[0] for p in gem_pts]
        gys = [p[1] for p in gem_pts]
        m = 20
        gem_box = (max(0, min(gxs) - m), max(0, min(gys) - m),
                   min(W, max(gxs) + m), min(H, max(gys) + m))
        gem_patch = img.crop(gem_box)

    # 2) art into the window (cover fit, tiny overlap under the gold fillet)
    pad = 3
    ax0, ay0, ax1, ay1 = bx0 - pad, by0 - pad, bx1 + pad, by1 + pad
    bw, bh = ax1 - ax0, ay1 - ay0
    art_path = Path(card["_art"]) if "_art" in card else ART / f"{card['id']}.png"
    if art_path.exists():
        art = Image.open(art_path).convert("RGBA")
        scale = max(bw / art.width, bh / art.height)
        art = art.resize((int(art.width * scale) + 1, int(art.height * scale) + 1),
                         Image.LANCZOS)
        cx = (art.width - bw) // 2
        cy = max(0, (art.height - bh) // 3)
        art = art.crop((cx, cy, cx + bw, cy + bh))
        img.paste(art, (ax0, ay0))

    # 3) restore the gem zone, tint its face, draw the cost
    if gem_patch is not None:
        gpx = gem_patch.load()
        mask = Image.new("L", gem_patch.size, 255)
        mpx = mask.load()
        for yy in range(gem_patch.size[1]):
            for xx in range(gem_patch.size[0]):
                r, g, b, _a2 = gpx[xx, yy]
                if _is_magenta((r, g, b)) \
                        and (xx + gem_box[0], yy + gem_box[1]) not in gem_pts:
                    mpx[xx, yy] = 0
        img.paste(gem_patch, (gem_box[0], gem_box[1]), mask)
    px = img.load()
    for gx, gy in gem_pts:
        r, g, b, _a3 = px[gx, gy]
        # keep the gem's facet shading: modulate luminance into the guild color
        lum = (r + b) / 510.0
        px[gx, gy] = (int(gc[0] * (0.35 + 0.55 * lum)),
                      int(gc[1] * (0.35 + 0.55 * lum)),
                      int(gc[2] * (0.35 + 0.55 * lum)), 255)
    draw = ImageDraw.Draw(img)
    gem_text = card.get("_gem", str(card.get("cost", 0)))
    gem_size = int(W * 0.088) if len(gem_text) <= 1 else int(W * 0.066)
    outlined(draw, gem_c, gem_text, font(F_TITLE, gem_size), (255, 255, 255), width=6)
    if card.get("_gem_label"):
        outlined(draw, (gem_c[0], gem_c[1] + int(W * 0.055)), card["_gem_label"],
                 font(F_TITLE, int(W * 0.022)), (255, 245, 225), width=3)

    # 4) leftover template magenta (safety): recolor to dark neutral — but never
    # touch the pasted art, whose own pinks are legitimate
    w2, h2 = img.size
    for yy in range(0, h2, 1):
        for xx in range(0, w2, 1):
            if ax0 <= xx < ax1 and ay0 <= yy < ay1:
                continue
            if gem_box is not None and gem_box[0] <= xx < gem_box[2] \
                    and gem_box[1] <= yy < gem_box[3]:
                continue
            r, g, b, a4 = px[xx, yy]
            if _is_magenta((r, g, b)):
                px[xx, yy] = (70, 30, 34, a4)

    # 5) name + subtitle
    name_font = fit_text(draw, card["name"], F_TITLE, int(W * a["name_w"]),
                         int(W * 0.056))
    outlined(draw, (int(W * a["name"][0]), int(H * a["name"][1])), card["name"],
             name_font, (238, 226, 200), width=4)
    is_monster = kind == "monster"
    sub_kind = "Sort"
    if is_monster:
        sub_kind = "Ascendant" if card.get("token") else "Écho"
    subtitle = card.get("_subtitle", "%s — %s" % (sub_kind, GUILD_NAMES.get(guild, "")))
    outlined(draw, (int(W * a["subtitle"][0]), int(H * a["subtitle"][1])), subtitle,
             font(F_TITLE, int(W * 0.0245)), (218, 200, 165), width=2)

    # 6) stat values inside the plate bodies (color adapts to plate brightness,
    # e.g. the Light faction's ivory plates need dark text)
    if is_monster:
        levels = card["levels"]
        niv = str(len(levels)) if len(levels) > 1 else "—"
        values = [str(levels[0]["atk"]),
                  ATTACK_NAMES.get(card.get("attack_type", "melee"), "?"),
                  niv, str(levels[0]["hp"])]
        for i, val in enumerate(values):
            sx, sy = int(W * a["stat_xs"][i]), int(H * a["stat_y"])
            sr, sg, sb, _sa = px[sx, sy]
            bright = (sr + sg + sb) / 3 > 150
            fill = (62, 44, 24) if bright else (250, 244, 226)
            edge = (240, 230, 205) if bright else (20, 14, 8)
            vf = font(F_TITLE, int(W * 0.044) if len(val) <= 2 else int(W * 0.028))
            outlined(draw, (sx, sy), val, vf, fill, outline=edge, width=3)

    # 7) rules text with an ornamental divider between sections
    sections = []
    if "_sections" in card:
        sections = [list(b) for b in card["_sections"]]
    elif is_monster:
        block = []
        kws = []
        for kw, val in card.get("keywords", {}).items():
            n = KEYWORD_NAMES.get(kw, kw)
            kws.append(n if val is True else "%s %d" % (n, val))
        if kws:
            block.append(", ".join(kws) + ".")
        if block:
            sections.append(block)
        block2 = []
        lv_bits = []
        for i, lv in enumerate(card["levels"][1:], start=2):
            lv_bits.append("Niveau %d (%d XP) : %d/%d" % (i, lv["xp"], lv["atk"], lv["hp"]))
        if lv_bits:
            block2.append(" — ".join(lv_bits) + ".")
        if card.get("evolves_to"):
            block2.append("Évolue au niveau max (%d pierres)." % card.get("evolve_cost", 0))
        if block2:
            sections.append(block2)
    elif not sections:
        sections.append([describe_effect(card.get("effect", []))])
    if card.get("flavor"):
        sections.append(["« %s »" % card["flavor"]])

    box_top = int(H * a["text_top"])
    box_bottom = int(H * a["text_bottom"])
    max_w = int(W * 0.72)
    body_size = int(W * 0.037)
    while body_size > 20:
        f_body = font(F_BODY, body_size)
        f_flavor = font(F_BODY, int(body_size * 0.88))
        lh = int(body_size * 1.38)
        rendered = []  # (kind, payload)
        for si, block in enumerate(sections):
            if si > 0:
                rendered.append(("div", None))
            for seg in block:
                is_flavor = seg.startswith("«")
                for ln in wrap(draw, seg, f_flavor if is_flavor else f_body, max_w):
                    rendered.append(("flavor" if is_flavor else "text", ln))
        total = sum(lh if r[0] != "div" else int(lh * 0.9) for r in rendered)
        if total <= box_bottom - box_top:
            break
        body_size -= 2
    y = box_top + ((box_bottom - box_top) - total) // 2
    for kind2, payload in rendered:
        if kind2 == "div":
            ornament_divider(draw, W // 2, y + int(lh * 0.38), int(W * 0.26))
            y += int(lh * 0.9)
            continue
        f_seg = f_flavor if kind2 == "flavor" else f_body
        fill = (110, 88, 62) if kind2 == "flavor" else (58, 42, 26)
        draw.text((W // 2, y), payload, font=f_seg, fill=fill, anchor="ma")
        y += lh

    # 8) rarity banner
    outlined(draw, (int(W * a["rarity"][0]), int(H * a["rarity"][1])),
             card.get("_rarity", rarity_of(card)),
             font(F_TITLE, int(W * 0.026)), (232, 216, 180), width=3)
    return img


def main() -> int:
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else None
    cards = json.loads((ROOT / "resources/data/cards.json").read_text(encoding="utf-8"))["cards"]
    OUT.mkdir(parents=True, exist_ok=True)
    tpls = {}
    for kind in ["monster", "spell"]:
        for fac in GUILD_NAMES:
            path = UI / f"card_v2_{kind}_{fac}.png"
            if not path.exists():
                sys.exit("gabarit manquant : %s" % path.name)
            tpl = Image.open(path)
            win = magenta_window(tpl)
            tpls[(kind, fac)] = (tpl, win, gem_region(tpl, win))
    # The four Masters get their own cards on the spell frame of their faction.
    masters = json.loads((ROOT / "resources/data/masters.json").read_text(encoding="utf-8"))["masters"]
    for m in masters:
        cards.append({
            "id": "master_%s" % m["id"], "name": m["name"], "guild": m["guild"],
            "kind": "spell", "cost": 0,
            "_art": str(ROOT / "assets" / "portraits" / ("%s.png" % m["id"])),
            "_gem": str(m["hp"]), "_gem_label": "PV",
            "_subtitle": "Maître — %s" % GUILD_NAMES.get(m["guild"], ""),
            "_sections": [
                ["Passif : %s" % m["passive_desc"]],
                ["Pouvoir — %s (%d pierres, 1 fois par tour) : %s"
                 % (m["power_name"], m["power_cost"], m["power_desc"])],
            ],
            "_rarity": "MAÎTRE",
            "flavor": m.get("lore", ""),
        })
    for card in cards:
        if only and card["id"] != only:
            continue
        kind = "monster" if card.get("kind") == "monster" else "spell"
        tpl, box, gem = tpls[(kind, card.get("guild", "flame"))]
        img = compose_card(card, tpl, box, gem)
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
