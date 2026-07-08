#!/usr/bin/env python3
"""Generate the pixel-art UI pack via the OpenAI image API (gpt-image-2).

Only interface chrome (buttons, panels, tabs, bars, icons, indicators,
banners) — card/hero/monster art is out of scope. Prompts follow
tools/pixel_asset_brief.md. gpt-image-2 is used because it natively outputs
transparent backgrounds, which every asset here needs.

Post-processing (PIL): the model draws FAKE pixel art (~10-16px blocks in a
1024px canvas). We detect that grid and collapse it so 1 block = 1 real pixel
(base ~64x64 for icons), then hard alpha, autocrop, palette quantization.
Raw 1024px originals are kept in tools/raw_ui/ so post-processing can be
iterated without new API calls (--post).

Reads OPENAI_API_KEY from .env at the project root. Idempotent: existing
files are skipped unless --force.

Usage: python tools/generate_ui_pack.py [--force] [--only substring] [--post]
"""

import base64
import json
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from io import BytesIO
from pathlib import Path

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites" / "ui" / "pixel"
RAW = ROOT / "tools" / "raw_ui"
URL = "https://api.openai.com/v1/images/generations"
MAX_RETRIES = 4

STYLE = ("palette limitée, aucun anti-aliasing, contours nets, style anime, "
         "aucun texte. Direction artistique dark fantasy : pierre anthracite "
         "très sombre, ornements en or antique, accents discrets. Pixel art "
         "authentique haute densité de sprite {w}x{h} comme un jeu SNES "
         "16-bit : exactement {w}x{h} pixels logiques, pixels FINS et "
         "nombreux (pas de gros blocs), beaucoup de détail, l'objet remplit "
         "presque toute la grille, posé sur un fond uni magenta pur "
         "(#FF00FF) sans dégradé ni ombre portée.")

# name: (subject prompt, target W, target H, canvas, fit)
#   canvas: gpt-image-1 generation size ; fit: "exact" (9-slice shapes) or
#   "box" (icons keep their aspect, fitted inside W x H)
WIDE, TALL, SQ = "1536x1024", "1024x1536", "1024x1024"
ASSETS = {
    # panneaux (9-slice)
    "panel_stone": ("un panneau d'interface rectangulaire en pierre anthracite presque noire, bordure dorée ornée avec coins travaillés, centre uni très sombre tuilable", 128, 128, SQ, "exact"),
    "panel_tooltip": ("un petit panneau d'info-bulle rectangulaire en pierre noire, très fine bordure dorée, centre uni presque noir", 128, 128, SQ, "exact"),
    # boutons (9-slice)
    "btn_primary": ("un bouton d'interface rectangulaire large en pierre anthracite presque noire, liseré doré fin avec petits ornements aux coins, centre uni sombre", 144, 56, WIDE, "exact"),
    "btn_secondary": ("un bouton d'interface rectangulaire large rouge bordeaux profond, liseré doré fin, centre uni rouge sombre", 144, 56, WIDE, "exact"),
    "btn_disabled": ("un bouton d'interface rectangulaire large gris anthracite terne et éteint (état désactivé), centre uni", 144, 56, WIDE, "exact"),
    # onglets d'en-tête
    "tab_player": ("une plaque d'en-tête horizontale en pierre presque noire avec liseré doré et une discrète lueur bleue (bandeau de titre du joueur)", 192, 64, WIDE, "exact"),
    "tab_opponent": ("une plaque d'en-tête horizontale en pierre presque noire avec liseré doré et une discrète lueur rouge (bandeau de titre de l'adversaire)", 192, 64, WIDE, "exact"),
    "tab_infos": ("une plaque d'en-tête horizontale en pierre presque noire avec liseré doré (bandeau de titre d'informations)", 192, 64, WIDE, "exact"),
    # bannières
    "banner_ribbon": ("un large ruban de bannière horizontal doré aux extrémités en pointe fendues, déployé, centre uni pour du texte", 256, 80, WIDE, "exact"),
    "banner_blue": ("une grande bannière de tissu bleue suspendue à une tringle de fer, pendante, bout en pointe", 96, 192, TALL, "exact"),
    "banner_red": ("une grande bannière de tissu rouge suspendue à une tringle de fer, pendante, bout en pointe", 96, 192, TALL, "exact"),
    "banner_blue_s": ("une petite bannière de tissu bleue suspendue, pendante, bout en pointe", 64, 128, TALL, "exact"),
    "banner_red_s": ("une petite bannière de tissu rouge suspendue, pendante, bout en pointe", 64, 128, TALL, "exact"),
    # jauges
    "bar_hp": ("une jauge horizontale rouge (barre de points de vie) pleine avec un cadre de métal sombre", 144, 28, WIDE, "exact"),
    "bar_crystal": ("une jauge horizontale bleu cristal (barre de mana) pleine avec un cadre de métal sombre", 144, 28, WIDE, "exact"),
    "bar_gold": ("une jauge horizontale dorée (barre d'or) pleine avec un cadre de métal sombre", 144, 28, WIDE, "exact"),
    "bar_action": ("une jauge horizontale verte (barre d'actions) pleine avec un cadre de métal sombre", 144, 28, WIDE, "exact"),
    # icônes de ressource / faction
    "res_heart": ("une icône de cœur rouge (points de vie), objet unique centré", 64, 64, SQ, "box"),
    "res_crystal": ("une icône de gemme de cristal bleu taillé (ressource pierre), objet unique centré", 64, 64, SQ, "box"),
    "res_gold": ("une icône de pièce d'or lisse et unie, sans aucun chiffre ni lettre ni symbole gravé, juste un simple bord en relief, objet unique centré", 64, 64, SQ, "box"),
    "res_light": ("une icône de petit soleil doré rayonnant (faction Lumière), objet unique centré", 64, 64, SQ, "box"),
    "res_nature": ("une icône de feuille verte (faction Sylve), objet unique centré", 64, 64, SQ, "box"),
    "res_shadow": ("une icône de crâne violet auréolé d'ombre (faction Ombre), objet unique centré", 64, 64, SQ, "box"),
    "res_flame": ("une icône de flamme orange vive (faction Flamme), objet unique centré", 64, 64, SQ, "box"),
    # icônes de stat
    "icon_stat_attack": ("une icône d'épée dressée (statistique d'attaque), objet unique centré", 64, 64, SQ, "box"),
    "icon_stat_shield": ("une icône de bouclier (statistique de défense), objet unique centré", 64, 64, SQ, "box"),
    "icon_stat_action": ("une icône de sablier (statistique d'action), objet unique centré", 64, 64, SQ, "box"),
    # icônes de menu
    "icon_menu_bag": ("une icône de bourse de cuir (boutique), objet unique centré", 64, 64, SQ, "box"),
    "icon_menu_book": ("une icône de livre fermé à reliure de cuir (guide), objet unique centré", 64, 64, SQ, "box"),
    "icon_menu_gear": ("une icône d'engrenage métallique (réglages), objet unique centré", 64, 64, SQ, "box"),
    "icon_menu_exit": ("une icône de porte en bois cloutée (quitter), objet unique centré", 64, 64, SQ, "box"),
    # icônes diverses
    "icon_check": ("une icône de coche de validation verte, symbole unique centré", 64, 64, SQ, "box"),
    "icon_cross": ("une icône de croix d'annulation rouge, symbole unique centré", 64, 64, SQ, "box"),
    # indicateurs de case
    "ind_select_gold": ("un cadre carré doré lumineux vide (surbrillance de case jouable), contour seul, centre vide", 96, 96, SQ, "exact"),
    "ind_select_blue": ("un cadre carré bleu lumineux vide (surbrillance de déplacement), contour seul, centre vide", 96, 96, SQ, "exact"),
    "ind_attack": ("une icône d'épées croisées rouges dans un halo (cible d'attaque), centrée", 96, 96, SQ, "box"),
    "ind_heal": ("une croix de soin verte lumineuse avec des étincelles, centrée", 96, 96, SQ, "box"),
    "ind_light": ("un halo doré rayonnant (effet de Lumière), centré", 96, 96, SQ, "box"),
    "ind_shadow": ("une aura violette d'ombre tourbillonnante (effet d'Ombre), centrée", 96, 96, SQ, "box"),
    # marqueurs de rangée
    "row_marker_0": ("une petite plaque de pierre ronde gravée du chiffre 0 lisible", 56, 56, SQ, "box"),
    "row_marker_1": ("une petite plaque de pierre ronde gravée du chiffre 1 lisible", 56, 56, SQ, "box"),
    "row_marker_2": ("une petite plaque de pierre ronde gravée du chiffre 2 lisible", 56, 56, SQ, "box"),
    "row_marker_3": ("une petite plaque de pierre ronde gravée du chiffre 3 lisible", 56, 56, SQ, "box"),
}


def read_api_key() -> str:
    env = ROOT / ".env"
    if env.exists():
        for line in env.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line.startswith("OPENAI_API_KEY="):
                return line.split("=", 1)[1].strip()
    print("ERROR: OPENAI_API_KEY introuvable dans .env", file=sys.stderr)
    sys.exit(2)


def generate(api_key: str, prompt: str, canvas: str) -> bytes:
    body = json.dumps({
        # gpt-image-2 ne supporte pas background=transparent : on demande un
        # fond magenta pur au prompt et on le détoure en post (chroma-key).
        "model": "gpt-image-2",
        "prompt": prompt,
        "size": canvas,
        "quality": "high",
        "n": 1,
    }).encode()
    last_err = None
    for attempt in range(MAX_RETRIES):
        req = urllib.request.Request(URL, data=body, headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        })
        try:
            with urllib.request.urlopen(req, timeout=300) as resp:
                data = json.load(resp)
            return base64.b64decode(data["data"][0]["b64_json"])
        except urllib.error.HTTPError as e:
            last_err = f"HTTP {e.code}: {e.read()[:300]!r}"
            if e.code not in (429, 500, 502, 503):
                break
        except Exception as e:  # noqa: BLE001 - retry on transient failures
            last_err = str(e)
        time.sleep(10 * (attempt + 1))
    raise RuntimeError(last_err)


def _axis_scores(profile: list[float]) -> dict[float, tuple[float, float]]:
    """For each candidate block size k (fractional: models upscale their fake
    grid non-integrally, e.g. 7.5px on a 1536 canvas): best (score, offset)."""
    n = len(profile)
    out = {}
    for k2 in range(10, 67):  # k = 5.0 .. 33.0 step 0.5
        k = k2 / 2
        best = (0.0, 0.0)
        for o2 in range(k2):
            off = o2 / 2
            pos = [int(off + m * k) for m in range(int((n - off) / k))]
            if not pos:
                continue
            s = sum(profile[p] for p in pos) / len(pos)
            if s > best[0]:
                best = (s, off)
        out[k] = best
    return out


def _best_offset(profile: list[float], k: float) -> float:
    """Grid offset (step 0.25) whose positions best align with the edges."""
    n = len(profile)
    best = (0.0, 0.0)
    o = 0.0
    while o < k:
        pos = [int(o + m * k) for m in range(int((n - o) / k))]
        if pos:
            s = sum(profile[p] for p in pos) / len(pos)
            if s > best[0]:
                best = (s, o)
        o += 0.25
    return best[1]


def _candidates(cols: list[float], rows: list[float]) -> list[float]:
    """Plausible block sizes: top alignment scores plus their sub-multiples
    (a flat center dilutes the true k's score, but its harmonics still rank;
    dividing them recovers the fundamental with sub-pixel precision)."""
    sx, sy = _axis_scores(cols), _axis_scores(rows)
    mx = max(v[0] for v in sx.values())
    my = max(v[0] for v in sy.values())
    top = sorted(sx, key=lambda k: -(sx[k][0] / mx + sy[k][0] / my))[:8]
    cands = set()
    for k in top:
        for div in (1, 2, 3, 4):
            if k / div >= 4.5:
                cands.add(round(k / div * 4) / 4)
    return sorted(cands)


def collapse_pixels(img: Image.Image) -> Image.Image:
    """Detect the fake-pixel grid and collapse it: 1 block -> 1 real pixel."""
    g = img.convert("L")
    w, h = g.size
    px = g.load()
    cols = [0.0] * (w - 1)
    rows = [0.0] * (h - 1)
    for y in range(0, h, 5):
        for x in range(w - 1):
            d = px[x, y] - px[x + 1, y]
            cols[x] += d * d
    for x in range(0, w, 5):
        for y in range(h - 1):
            d = px[x, y] - px[x, y + 1]
            rows[y] += d * d
    # The winning k is the LARGEST candidate that still reconstructs the
    # original almost losslessly (an over-collapse loses visible detail).
    best_img, best_err_sel = None, None
    errs = []
    for k in _candidates(cols, rows):
        ox, oy = _best_offset(cols, k), _best_offset(rows, k)
        small = _collapse_at(img, k, ox, oy)
        rw, rh = int(small.width * k), int(small.height * k)
        recon = small.resize((rw, rh), Image.NEAREST).convert("RGB")
        orig = img.crop((int(ox), int(oy), int(ox) + rw, int(oy) + rh)).convert("RGB")
        hist = ImageChops.difference(orig, recon).convert("L").histogram()
        err = sum(i * v for i, v in enumerate(hist)) / max(1, sum(hist))
        errs.append((err, k, small))
    emin = min(e[0] for e in errs)
    _, _, best_img = max((e for e in errs if e[0] <= emin * 1.15 + 1.0),
                         key=lambda e: e[1])
    return best_img


def _collapse_at(img: Image.Image, k: float, ox: float, oy: float) -> Image.Image:
    """Sample the CENTER of each block (no averaging: a keyed-out background
    never bleeds into edge pixels). Fractional grid -> float positions."""
    w, h = img.size
    nx, ny = int((w - ox) / k), int((h - oy) / k)
    out = Image.new("RGBA", (nx, ny))
    src, dst = img.load(), out.load()
    for j in range(ny):
        sy = min(h - 1, int(oy + (j + 0.5) * k))
        for i in range(nx):
            dst[i, j] = src[min(w - 1, int(ox + (i + 0.5) * k)), sy]
    return out


def chroma_key(img: Image.Image) -> Image.Image:
    """Pure-magenta background -> transparent (gpt-image-2 has no alpha)."""
    r, g, b, a = img.split()
    rm = r.point(lambda v: 255 if v > 180 else 0)
    gm = g.point(lambda v: 255 if v < 110 else 0)
    bm = b.point(lambda v: 255 if v > 180 else 0)
    key = ImageChops.multiply(ImageChops.multiply(rm, bm), gm)
    img.putalpha(ImageChops.subtract(a, key))
    return img


def _strip_fringe(img: Image.Image) -> Image.Image:
    """Drop pinkish leftover pixels touching transparency (magenta blends the
    key threshold missed). Tight test: gold/red/violet content is untouched."""
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a and r > 170 and b > 140 and r - g > 60 and b - g > 30:
                # Out-of-bounds counts as transparent: after autocrop the
                # silhouette sits on the image border.
                near_t = any(not (0 <= x + dx < w and 0 <= y + dy < h)
                             or px[x + dx, y + dy][3] == 0
                             for dx in (-1, 0, 1) for dy in (-1, 0, 1))
                if near_t:
                    px[x, y] = (r, g, b, 0)
    return img


def postprocess(raw: bytes, w: int, h: int, fit: str) -> Image.Image:
    img = collapse_pixels(chroma_key(Image.open(BytesIO(raw)).convert("RGBA")))
    img = chroma_key(img)  # remnants magenta sur la silhouette
    img = _strip_fringe(img)
    # Hard alpha (pixel art wants no soft edges), then crop to content.
    a = img.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
    img.putalpha(a)
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    # Collapsed pixels are already clean: only resample when clearly off
    # target (resampling true pixel art degrades it).
    ref = w if fit == "exact" else max(w, h)
    cur = img.width if fit == "exact" else max(img.width, img.height)
    if cur > 1.25 * ref:
        s = ref / cur
        img = img.resize((max(1, round(img.width * s)),
                          max(1, round(img.height * s))), Image.NEAREST)
    # Palette cleanup, alpha kept binary.
    alpha = img.getchannel("A")
    img = img.convert("RGB").quantize(colors=48).convert("RGBA")
    img.putalpha(alpha)
    return img


def run(name: str, api_key: str) -> str | None:
    subject, w, h, canvas, fit = ASSETS[name]
    raw_path = RAW / f"{name}.png"
    try:
        if raw_path.exists():
            raw = raw_path.read_bytes()
        else:
            prompt = f"Pixel art authentique de {subject}, {STYLE.format(w=w, h=h)}"
            raw = generate(api_key, prompt, canvas)
            raw_path.write_bytes(raw)
        img = postprocess(raw, w, h, fit)
        img.save(OUT / f"{name}.png")
        print(f"OK   {name}.png ({img.width}x{img.height})")
        return None
    except Exception as e:  # noqa: BLE001
        print(f"FAIL {name} — {e}", file=sys.stderr)
        return name


def main() -> int:
    force = "--force" in sys.argv
    post = "--post" in sys.argv  # re-postprocess from raws, no API call
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else ""
    api_key = read_api_key()
    OUT.mkdir(parents=True, exist_ok=True)
    RAW.mkdir(parents=True, exist_ok=True)
    if force:  # regenerate from the API: drop the cached raws too
        for n in ASSETS:
            if only in n:
                (RAW / f"{n}.png").unlink(missing_ok=True)
    todo = [n for n in ASSETS
            if only in n and (force or post or not (OUT / f"{n}.png").exists())]
    print(f"{len(ASSETS)} assets au pack, {len(todo)} à traiter.")
    with ThreadPoolExecutor(max_workers=4) as pool:
        failures = [f for f in pool.map(lambda n: run(n, api_key), todo) if f]
    if failures:
        print(f"\n{len(failures)} échec(s) : {', '.join(failures)}", file=sys.stderr)
        return 1
    print("\nPack UI complet.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
