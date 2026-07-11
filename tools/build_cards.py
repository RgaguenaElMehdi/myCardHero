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
# Measured on the pixel-art masters (1024x1536).
ANCHORS = {
    "monster": {
        "name": (0.500, 0.065), "name_w": 0.42,
        "subtitle": (0.500, 0.125),
        "stat_xs": [0.166, 0.390, 0.605, 0.832], "stat_y": 0.612,
        "text_top": 0.695, "text_bottom": 0.855,
        "rarity": (0.500, 0.901),
    },
    "spell": {
        "name": (0.500, 0.068), "name_w": 0.44,
        "subtitle": (0.500, 0.133),
        "text_top": 0.618, "text_bottom": 0.845,
        "rarity": (0.500, 0.906),
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


RARITY_LABELS = {"commune": "COMMUNE", "rare": "RARE", "epique": "ÉPIQUE",
                 "legendaire": "LÉGENDAIRE", "ascendant": "ASCENDANT"}

# Rarity color, used ONLY on the bottom plaque (label + flanking gems). Kept
# local so it never fights the guild frame's own metal/color.
RARITY_METAL = {
    "COMMUNE":    (168, 158, 138),
    "RARE":       (120, 170, 225),
    "ÉPIQUE":     (190, 120, 240),
    "LÉGENDAIRE": (245, 198, 82),
    "ASCENDANT":  (92, 226, 206),
    "MAÎTRE":     (224, 229, 238),
}


def rarity_of(card: dict) -> str:
    if card.get("token"):
        return "ASCENDANT"
    return RARITY_LABELS.get(card.get("rarity", "commune"), "COMMUNE")


# --- template analysis ---------------------------------------------------


def _is_magenta(rgb) -> bool:
    """Pink-family detector, tolerant to the hue drift the Gemini image edits
    introduce in the faction variants. Excludes violet (b >> r), crimson
    (low b), gold and ivory (low r-g)."""
    r, g, b = rgb
    return r > 120 and r - g > 45 and b - g > 20 and r >= b - 15


def _longest_run(values: list, step: int) -> tuple:
    """Longest contiguous run in a sorted list sampled every `step`."""
    best = (values[0], values[0])
    start = prev = values[0]
    for v in values[1:]:
        if v - prev > step:
            if prev - start > best[1] - best[0]:
                best = (start, prev)
            start = v
        prev = v
    if prev - start > best[1] - best[0]:
        best = (start, prev)
    return best


def magenta_window(img: Image.Image) -> tuple:
    """Bounding box of the LARGE art window: longest contiguous magenta run on
    the center column/row (robust against stray pink elements elsewhere)."""
    px = img.convert("RGB").load()
    w, h = img.size
    ys = [y for y in range(0, h, 3) if _is_magenta(px[w // 2, y])]
    if not ys:
        sys.exit("fenêtre magenta introuvable dans le gabarit")
    y0, y1 = _longest_run(ys, 3)
    y_mid = (y0 + y1) // 2
    xs = [x for x in range(0, w, 3) if _is_magenta(px[x, y_mid])]
    x0, x1 = _longest_run(xs, 3)
    return (x0, y0, x1 + 3, y1 + 3)


def gem_region(img: Image.Image, window: tuple) -> tuple:
    """Flood-fills the cost gem's magenta face. The gem is the LARGEST magenta
    blob above the art window — picking the largest (not the first seed) keeps it
    robust against small magenta-ish flecks from the rarity corner gemstones
    (amethyst highlights read as pink)."""
    px = img.convert("RGB").load()
    w, h = img.size
    wy0 = window[1]

    def flood(seed: tuple, seen: set) -> set:
        # Barrier at the art window's top edge: the cost gem lives strictly above
        # it, so never let the fill leak down into the (much larger) art window.
        comp = set()
        stack = [seed]
        while stack:
            x, y = stack.pop()
            if (x, y) in comp or not (0 <= x < w and 0 <= y < wy0):
                continue
            if not _is_magenta(px[x, y]):
                continue
            comp.add((x, y))
            stack.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])
        seen |= comp
        return comp

    seen = set()
    best = set()
    for y in range(0, wy0, 2):
        for x in range(0, w, 2):
            if (x, y) in seen or not _is_magenta(px[x, y]):
                continue
            comp = flood((x, y), seen)
            if len(comp) > len(best):
                best = comp
    if not best:
        return set(), (int(w * 0.14), int(w * 0.12))
    cx = sum(p[0] for p in best) // len(best)
    cy = sum(p[1] for p in best) // len(best)
    return best, (cx, cy)


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


def vcentered(draw, x, cy, text, f, fill, outline=(20, 14, 8), width=3):
    """Draw `text` horizontally centered at x and vertically centered on cy by its
    ACTUAL ink box — all-caps titles have no descenders, so the plain "mm" anchor
    (which reserves descender space) makes them sit too high. Correct for that."""
    bb = draw.textbbox((0, 0), text, font=f, anchor="mm", stroke_width=width)
    y = int(cy - (bb[1] + bb[3]) / 2)
    outlined(draw, (int(x), y), text, f, fill, outline=outline, width=width)


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


def plate_center_x(img: Image.Image, yfrac: float, yspan: float = 0.045,
                   default: float = 0.5) -> float:
    """Horizontal center (as a fraction of width) of the dark plate at `yfrac`.
    Scans OUTWARD from the middle to the first bright (gold) edge on each side —
    robust because it starts inside the empty plate and stops at its border, so
    distant foliage/ornaments never fool it. Detect on the pristine template
    (empty plates) before any text is drawn."""
    px = img.load()
    w, h = img.size

    def lum(x, y):
        p = px[x, y]
        return max(p[0], p[1], p[2])

    cands = []
    lo, hi = int(w * 0.12), int(w * 0.88)
    for y in range(max(0, int(h * (yfrac - yspan))), min(h, int(h * (yfrac + yspan)))):
        if lum(w // 2, y) >= 75:          # middle must sit inside the dark plate
            continue
        left = w // 2
        while left > lo and lum(left, y) <= 110:
            left -= 1
        right = w // 2
        while right < hi and lum(right, y) <= 110:
            right += 1
        if right - left > w * 0.15:
            cands.append((left + right) / 2)
    if not cands:
        return default
    cands.sort()
    return cands[len(cands) // 2] / w


def plate_center_y(img: Image.Image, cxfrac: float, yfrac: float,
                   yspan: float = 0.055, default: float = None) -> float:
    """Vertical center (fraction of height) of the dark plate that contains the
    point (cxfrac, yfrac). Scans up/down from that point (inside the plate) to the
    first bright edge. Detect on the pristine template."""
    px = img.load()
    w, h = img.size
    x = int(w * cxfrac)

    def lum(y):
        p = px[x, min(h - 1, max(0, y))]
        return max(p[0], p[1], p[2])

    y0 = int(h * yfrac)
    if lum(y0) >= 75:                      # nudge onto the dark plate if just off
        step = None
        for dy in range(1, int(h * yspan)):
            if lum(y0 - dy) < 75:
                step = y0 - dy
                break
            if lum(y0 + dy) < 75:
                step = y0 + dy
                break
        if step is None:
            return default if default is not None else yfrac
        y0 = step
    top = y0
    while top > int(h * (yfrac - yspan)) and lum(top) < 110:
        top -= 1
    bot = y0
    while bot < int(h * (yfrac + yspan)) and lum(bot) < 110:
        bot += 1
    if bot - top < h * 0.008:
        return default if default is not None else yfrac
    return (top + bot) / 2 / h


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

    # Per-frame centering: detect each dark plate's true center on the pristine
    # template so short labels (subtitle, rarity) sit dead-center whatever tiny
    # shift the img2img rarity variants introduced. Falls back to the anchor.
    name_cx = plate_center_x(img, a["name"][1], default=a["name"][0])
    sub_cx = plate_center_x(img, a["subtitle"][1], default=a["subtitle"][0])
    rar_cx = plate_center_x(img, a["rarity"][1], default=a["rarity"][0])
    name_cy = plate_center_y(img, name_cx, a["name"][1], default=a["name"][1])
    sub_cy = plate_center_y(img, sub_cx, a["subtitle"][1], default=a["subtitle"][1])
    rar_cy = plate_center_y(img, rar_cx, a["rarity"][1], default=a["rarity"][1])

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

    # 2) art into the window (cover fit, overlap under the gold fillet — a bit
    #    generous so ornate frames never leave a magenta sliver at the window edge)
    pad = 7
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
    gem_text = card.get("_gem", str(int(card.get("cost", 0))))
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
                px[xx, yy] = (gc[0] // 4 + 12, gc[1] // 4 + 8, gc[2] // 4 + 12, a4)
    # 4b) magenta-dominant final pass over the WHOLE image (art region included):
    # an ornate frame's window edge can leave a thin magenta strip — even blended
    # with the frame's turquoise glow (antialiasing) — that the art did not cover.
    # No card art is pink/magenta-dominant (Shadow's violet has R<150), so keying
    # on "R and B high, clearly above G" is safe everywhere.
    for yy in range(0, h2):
        for xx in range(0, w2):
            r, g, b, a4 = px[xx, yy]
            if r > 150 and b > 150 and r - g > 40 and b - g > 15:
                px[xx, yy] = (gc[0] // 4 + 12, gc[1] // 4 + 8, gc[2] // 4 + 12, a4)

    # 5) name + subtitle (colors adapt to the banner's brightness — the Light
    # faction has pale plates)
    def _adaptive(pos) -> tuple:
        sr, sg, sb2, _sa2 = px[pos[0], pos[1]]
        if (sr + sg + sb2) / 3 > 150:
            return (62, 44, 24), (242, 232, 208)
        return (238, 226, 200), (20, 14, 8)

    name_cy_px = int(H * name_cy)
    name_fill, name_edge = _adaptive((int(W * name_cx), name_cy_px))
    name_font = fit_text(draw, card["name"], F_TITLE, int(W * a["name_w"]),
                         int(W * 0.056))
    vcentered(draw, W * name_cx, name_cy_px, card["name"], name_font, name_fill,
              outline=name_edge, width=4)
    is_monster = kind == "monster"
    sub_kind = "Sort"
    if is_monster:
        sub_kind = "Ascendant" if card.get("token") else "Écho"
    subtitle = card.get("_subtitle", "%s — %s" % (sub_kind, GUILD_NAMES.get(guild, "")))
    sub_cy_px = int(H * sub_cy)
    sub_fill, sub_edge = _adaptive((int(W * sub_cx), sub_cy_px))
    vcentered(draw, W * sub_cx, sub_cy_px, subtitle, font(F_TITLE, int(W * 0.0245)),
              sub_fill, outline=sub_edge, width=2)

    # 6) stat values inside the plate bodies (color adapts to plate brightness,
    # e.g. the Light faction's ivory plates need dark text)
    if is_monster:
        levels = card["levels"]
        niv = str(len(levels)) if len(levels) > 1 else "—"
        values = [str(int(levels[0]["atk"])),
                  ATTACK_NAMES.get(card.get("attack_type", "melee"), "?"),
                  niv, str(int(levels[0]["hp"]))]
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

    # 8) rarity marker in the frame's own bottom plaque (drawn in template space
    #    so it lands on the plaque). Colored label + two flanking gems — the
    #    rarity color stays local, never wrapping/clashing with the guild frame.
    rar_text = card.get("_rarity", rarity_of(card))
    metal = RARITY_METAL.get(rar_text, RARITY_METAL["COMMUNE"])
    rar_cx_px, rar_cy_px = int(W * rar_cx), int(H * rar_cy)
    rf = font(F_TITLE, int(W * 0.030))
    label_fill = tuple(min(255, c + 30) for c in metal)
    vcentered(draw, rar_cx_px, rar_cy_px, rar_text, rf, label_fill,
              outline=(14, 9, 6), width=3)
    if rar_text != "COMMUNE":
        tw = draw.textlength(rar_text, font=rf)
        gy = rar_cy_px
        gr = int(W * 0.011)
        dark = tuple(int(c * 0.5) for c in metal)
        light = tuple(min(255, c + 70) for c in metal)
        for gx in (rar_cx_px - int(tw / 2) - int(W * 0.032),
                   rar_cx_px + int(tw / 2) + int(W * 0.032)):
            draw.ellipse((gx - gr, gy - gr, gx + gr, gy + gr), fill=dark,
                         outline=(16, 11, 8), width=2)
            ir = int(gr * 0.6)
            draw.ellipse((gx - ir, gy - ir, gx + ir, gy + ir), fill=metal)
            hr = max(1, int(gr * 0.3))
            draw.ellipse((gx - hr - 1, gy - hr - 1, gx + hr - 1, gy + hr - 1), fill=light)
    return img


def main() -> int:
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else None
    cards = json.loads((ROOT / "resources/data/cards.json").read_text(encoding="utf-8"))["cards"]
    OUT.mkdir(parents=True, exist_ok=True)
    tpl_cache = {}

    def get_template(kind: str, guild: str, rarity: str):
        # Prefer a rarity-specific frame (card_v2_<kind>_<guild>_<rarity>.png) when
        # it exists; otherwise fall back to the guild base, then flame. This lets
        # rarity frames be generated incrementally without breaking any card.
        cand = [UI / f"card_v2_{kind}_{guild}_{rarity}.png"] if rarity else []
        cand += [UI / f"card_v2_{kind}_{guild}.png", UI / f"card_v2_{kind}_flame.png"]
        path = next(p for p in cand if p.exists())
        if path not in tpl_cache:
            tpl = Image.open(path)
            win = magenta_window(tpl)
            tpl_cache[path] = (tpl, win, gem_region(tpl, win))
        return tpl_cache[path]
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
        # rarity frame per tier; evolved tokens use the dedicated "ascendant" frame
        rarity = "ascendant" if card.get("token") else card.get("rarity", "")
        tpl, box, gem = get_template(kind, card.get("guild", "flame"), rarity)
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
