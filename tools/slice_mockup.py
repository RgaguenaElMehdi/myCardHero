#!/usr/bin/env python3
"""Slice individual UI assets out of the mockup sheets (assets/mockup/*.png).

Generous crop boxes per element, then auto-trim against the dark checker
background and flood-fill alpha from the crop edges (and center for hollow
card frames). Deterministic: same sheets in, same assets out.
"""

from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SHEET2 = ROOT / "assets" / "mockup" / "assets2.png"
OUT = ROOT / "assets" / "sprites" / "ui" / "mockup"

# ponytail: hand-read coordinates from a 64px grid overlay; auto-trim absorbs the +/-8px slop.
# name: (box, mode)  mode: "alpha" = flood-fill bg, "frame" = alpha + hollow center, "opaque" = trim only
CROPS = {
    # 01 ressources
    "res_heart":    ((15, 45, 95, 130), "alpha"),
    "res_crystal":  ((90, 45, 165, 130), "alpha"),
    "res_gold":     ((160, 45, 232, 130), "alpha"),
    "res_shadow":   ((228, 45, 300, 130), "alpha"),
    "res_nature":   ((295, 45, 362, 130), "alpha"),
    "res_light":    ((358, 45, 435, 130), "alpha"),
    # 02 couts
    "gem_cost_0":   ((458, 42, 516, 105), "alpha"),
    "gem_cost_1":   ((521, 42, 579, 105), "alpha"),
    "gem_cost_2":   ((583, 42, 641, 105), "alpha"),
    "gem_cost_3":   ((646, 42, 704, 105), "alpha"),
    "gem_cost_4":   ((708, 42, 768, 105), "alpha"),
    "gem_cost_5":   ((521, 103, 579, 168), "alpha"),
    "gem_cost_6":   ((583, 103, 641, 168), "alpha"),
    "gem_cost_7":   ((646, 103, 706, 168), "alpha"),
    # 03 raretes
    "rarity_common":    ((796, 55, 852, 125), "alpha"),
    "rarity_uncommon":  ((858, 55, 916, 125), "alpha"),
    "rarity_rare":      ((921, 55, 979, 125), "alpha"),
    "rarity_epic":      ((986, 55, 1044, 125), "alpha"),
    "rarity_legendary": ((1051, 55, 1112, 125), "alpha"),
    # 04 compteurs -> icones seules (les chiffres seront des Labels dans Godot)
    "icon_stat_attack": ((1174, 68, 1208, 118), "alpha"),
    "icon_stat_shield": ((1268, 66, 1304, 118), "alpha"),
    "icon_stat_action": ((1450, 64, 1482, 121), "alpha"),
    # 05 boutons (opaque: l'interieur sombre serait mange par le flood-fill)
    "btn_primary":   ((28, 220, 204, 276), "opaque"),
    "btn_secondary": ((206, 220, 382, 276), "opaque"),
    "btn_disabled":  ((30, 290, 206, 348), "opaque"),
    # 06 info-bulle
    "panel_tooltip": ((425, 202, 660, 405), "alpha"),
    # 07 icones menu
    "icon_menu_bag":  ((702, 238, 772, 320), "alpha"),
    "icon_menu_book": ((786, 238, 856, 320), "alpha"),
    "icon_menu_gear": ((870, 238, 940, 320), "alpha"),
    "icon_menu_exit": ((954, 238, 1026, 320), "alpha"),
    # 08 indicateurs
    "ind_select_blue": ((1068, 248, 1142, 325), "frame"),
    "ind_select_gold": ((1142, 248, 1216, 325), "frame"),
    "ind_attack":      ((1216, 248, 1288, 325), "alpha"),
    "ind_heal":        ((1294, 248, 1360, 325), "alpha"),
    "ind_shadow":      ((1368, 248, 1432, 325), "alpha"),
    "ind_light":       ((1442, 248, 1508, 325), "alpha"),
    # 09 cadres de cartes
    "frame_sylvan": ((16, 428, 138, 618), "frame"),
    "frame_flame":  ((144, 428, 266, 618), "frame"),
    "frame_light":  ((272, 428, 394, 618), "frame"),
    "frame_shadow": ((398, 428, 512, 618), "frame"),
    "frame_bone":   ((526, 428, 650, 618), "frame"),
    # 10 dos de carte
    "card_back": ((668, 432, 792, 618), "opaque"),
    # 12 plateau / arene elements
    "board_mini":    ((14, 668, 204, 815), "alpha"),
    "banner_red_s":  ((206, 672, 262, 775), "alpha"),
    "banner_blue_s": ((262, 672, 318, 775), "alpha"),
    "torch_wall":    ((316, 665, 364, 805), "alpha"),
    "rocks":         ((362, 685, 470, 795), "alpha"),
    "row_marker_3":  ((630, 668, 676, 705), "alpha"),
    "row_marker_2":  ((630, 705, 676, 742), "alpha"),
    "row_marker_1":  ((630, 742, 676, 779), "alpha"),
    "row_marker_0":  ((630, 779, 676, 818), "alpha"),
    # 13 bannieres grandes
    "banner_red":  ((708, 668, 822, 805), "alpha"),
    "banner_blue": ((826, 668, 944, 805), "alpha"),
    # 14 barres
    "bar_hp":      ((984, 688, 1196, 742), "alpha"),
    "bar_crystal": ((1212, 688, 1452, 742), "alpha"),
    "bar_action":  ((984, 750, 1126, 805), "alpha"),
    "bar_gold":    ((1212, 748, 1416, 805), "alpha"),
    # 15 decorations (coches de confirmation)
    "icon_check": ((484, 940, 532, 1004), "alpha"),
    "icon_cross": ((541, 933, 593, 982), "alpha"),
    # 16 onglets
    "tab_player":   ((702, 900, 834, 960), "alpha"),
    "tab_opponent": ((836, 900, 988, 960), "alpha"),
}

# depuis assets.png (meme layout general, onglet INFOS en haut)
CROPS_SHEET1 = {
    "tab_infos": ((348, 22, 506, 70), "alpha"),
    # fenetre vide (bas droite) -> 9-patch de tous les panneaux du jeu
    "panel_stone": ((1213, 762, 1348, 908), "opaque"),
}

# ponytail: pas d'inpainting des chiffres incrustes - les compteurs sont composes
# dans Godot (plaque theme + icone + Label). On ne decoupe que les icones.

# Les boutons du mockup ont leur libelle peint ("BOUTON PRINCIPAL"...) : on
# efface la zone de texte par remplissage ligne a ligne (le centre des plaques
# metal est horizontalement uniforme, l'echantillon hors-zone est fiable).
BLANK_ZONES = {
    "btn_primary":   (0.10, 0.20, 0.90, 0.82),
    "btn_secondary": (0.10, 0.20, 0.90, 0.82),
    "btn_disabled":  (0.10, 0.20, 0.90, 0.82),
}


def blank_zone(img, region):
    px = img.load()
    w, h = img.size
    fx0, fy0, fx1, fy1 = region
    mx0, my0, mx1, my1 = int(w*fx0), int(h*fy0), int(w*fx1), int(h*fy1)
    for y in range(my0, my1):
        s = []
        for xx in list(range(max(0, mx0-6), mx0)) + list(range(mx1, min(w, mx1+6))):
            c = px[xx, y]
            if c[3] > 0:
                s.append(c)
        if not s:
            continue
        s.sort(key=lambda c: sum(c[:3]))
        base = s[len(s) // 2]
        for x in range(mx0, mx1):
            if px[x, y][3] > 0:
                n = (x * 7 + y * 13) % 7 - 3  # grain leger
                px[x, y] = (max(0, min(255, base[0] + n)),
                            max(0, min(255, base[1] + n)),
                            max(0, min(255, base[2] + n)), px[x, y][3])
    return img

CHECKER_LUM = 48   # checker background is darker than this
CHECKER_SAT = 32   # and nearly grey


def is_bg(px):
    r, g, b = px[:3]
    return max(r, g, b) < CHECKER_LUM and (max(r, g, b) - min(r, g, b)) < CHECKER_SAT


def flood_alpha(img, seeds):
    """Set alpha=0 on bg-like pixels reachable from seed points."""
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    seen = set()
    q = deque(s for s in seeds if 0 <= s[0] < w and 0 <= s[1] < h)
    while q:
        x, y = q.popleft()
        if (x, y) in seen:
            continue
        seen.add((x, y))
        if not is_bg(px[x, y]):
            continue
        px[x, y] = (0, 0, 0, 0)
        for nx, ny in ((x+1, y), (x-1, y), (x, y+1), (x, y-1)):
            if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen:
                q.append((nx, ny))
    return img


def content_bbox(img):
    """Bounding box of non-background pixels."""
    w, h = img.size
    px = img.convert("RGB").load()
    x0, y0, x1, y1 = w, h, 0, 0
    for y in range(h):
        for x in range(w):
            if not is_bg(px[x, y]):
                x0, y0 = min(x0, x), min(y0, y)
                x1, y1 = max(x1, x), max(y1, y)
    if x0 > x1:
        return None
    return (x0, y0, x1 + 1, y1 + 1)


def slice_sheet(sheet, crops):
    for name, (box, mode) in crops.items():
        crop = sheet.crop(box)
        bbox = content_bbox(crop)
        if bbox:
            pad = 1
            bbox = (max(0, bbox[0]-pad), max(0, bbox[1]-pad),
                    min(crop.width, bbox[2]+pad), min(crop.height, bbox[3]+pad))
            crop = crop.crop(bbox)
        w, h = crop.size
        edge_seeds = [(x, 0) for x in range(w)] + [(x, h-1) for x in range(w)] + \
                     [(0, y) for y in range(h)] + [(w-1, y) for y in range(h)]
        if mode == "frame":
            out = flood_alpha(crop, edge_seeds + [(w // 2, h // 2)])
        elif mode == "alpha":
            out = flood_alpha(crop, edge_seeds)
        else:
            out = crop.convert("RGBA")
        if name in BLANK_ZONES:
            out = blank_zone(out, BLANK_ZONES[name])
        out.save(OUT / f"{name}.png")
        print(f"{name}: {out.size}")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    slice_sheet(Image.open(SHEET2).convert("RGB"), CROPS)
    slice_sheet(Image.open(SHEET2.parent / "assets.png").convert("RGB"), CROPS_SHEET1)
    print(f"\n{len(CROPS) + len(CROPS_SHEET1)} assets -> {OUT}")


if __name__ == "__main__":
    main()
