#!/usr/bin/env python3
"""Pack "or baroque" du nouveau menu (mockup accueil fourni par l'utilisateur).

Génère via gpt-image-2 des pièces SANS texte (les labels restent du vrai texte
Godot) : ornement d'angle, emblème central, tuile de bouton vierge, 4 icônes
dorées. Puis compose les fonds d'écran (cadre complet) en 1920x1080 (desktop)
et 2400x1080 (mobile 20:9) — coins générés + liserés tracés en PIL, nets à
n'importe quelle résolution.

Sorties :
  assets/sprites/ui/gold/{corner,emblem,tile,icon_*}.png
  assets/backgrounds/menu_gold_1920.png / menu_gold_2400.png
Originaux bruts : tools/raw_gold/ (itérer la compo sans rappeler l'API: --post)

Usage: python tools/generate_menu_gold.py [--force] [--only substr] [--post]
"""

import base64
import json
import random
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from io import BytesIO
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites" / "ui" / "gold"
BG_OUT = ROOT / "assets" / "backgrounds"
RAW = ROOT / "tools" / "raw_gold"
URL = "https://api.openai.com/v1/images/generations"
MAX_RETRIES = 4

STYLE = ("orfèvrerie 3D en or poli luxueux sur fond NOIR charbon uni, reflets "
         "chauds, détails fins de filigrane baroque, rendu net et lisse haute "
         "résolution (PAS de pixel art), AUCUN texte, AUCUNE lettre. L'objet "
         "doré se détache sur un fond noir uni #0A0908 sans dégradé parasite.")

ASSETS = {
    # ornement d'angle (haut-gauche) — miroité en PIL pour les 4 coins
    "corner": dict(canvas="1024x1024", prompt=(
        "Ornement d'ANGLE décoratif haut-gauche pour cadre d'interface : "
        "volutes de filigrane d'or baroque partant du coin, une étoile à "
        "quatre branches en or sertie d'un éclat lumineux posée sur le coin, "
        "fines pointes effilées le long des deux bords (haut et gauche), "
        "composition strictement dans le quart haut-gauche de l'image, le "
        "reste noir uni. " + STYLE)),
    # emblème héraldique central
    "emblem": dict(canvas="1536x1024", prompt=(
        "Grand emblème héraldique centré : deux ailes d'or stylisées "
        "symétriques enveloppant un losange central serti d'un cristal doré "
        "rayonnant, pointes de lance vers le haut et le bas, derrière lui de "
        "très fines lignes de boussole circulaires en or pâle discret. " + STYLE)),
    # tuile de bouton carrée VIERGE
    "tile": dict(canvas="1024x1024", prompt=(
        "Panneau CARRÉ d'interface de jeu luxueux : cadre en double liseré "
        "d'or fin avec coins ornés de petites volutes et un petit fleuron en "
        "losange doré au milieu du bord supérieur, intérieur noir charbon "
        "légèrement texturé COMPLÈTEMENT VIDE (aucune icône, aucun motif "
        "central), le panneau carré occupe presque toute l'image. " + STYLE)),
    "icon_selection": dict(canvas="1024x1024", prompt=(
        "Icône : rose des vents en or formée de flèches croisées effilées "
        "(étoile de boussole à huit pointes), centrée, occupant 80% du "
        "cadre. " + STYLE)),
    "icon_deck": dict(canvas="1024x1024", prompt=(
        "Icône : éventail de trois cartes à jouer en or, la carte du dessus "
        "ornée d'une étoile à quatre branches, centré, occupant 80% du "
        "cadre. " + STYLE)),
    "icon_arena": dict(canvas="1024x1024", prompt=(
        "Icône : amphithéâtre romain (colisée) vu de face en or avec ses "
        "arches sur deux niveaux, centré, occupant 80% du cadre. " + STYLE)),
    "icon_params": dict(canvas="1024x1024", prompt=(
        "Icône : roue dentée mécanique en or au contour net, centrée, "
        "occupant 80% du cadre. " + STYLE)),
}


def api_key() -> str:
    for line in (ROOT / ".env").read_text(encoding="utf-8").splitlines():
        if line.startswith("OPENAI_API_KEY="):
            return line.split("=", 1)[1].strip()
    print("ERROR: OPENAI_API_KEY introuvable dans .env", file=sys.stderr)
    sys.exit(1)


def generate(key: str, prompt: str, canvas: str) -> bytes:
    body = json.dumps({
        "model": "gpt-image-2",
        "prompt": prompt,
        "size": canvas,
        "quality": "high",
    }).encode()
    last_err = ""
    for attempt in range(MAX_RETRIES):
        req = urllib.request.Request(URL, data=body, headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {key}",
        })
        try:
            with urllib.request.urlopen(req, timeout=300) as resp:
                data = json.load(resp)
            return base64.b64decode(data["data"][0]["b64_json"])
        except urllib.error.HTTPError as e:
            last_err = f"HTTP {e.code}: {e.read()[:300]!r}"
            if e.code not in (429, 500, 502, 503):
                break
        except Exception as e:  # noqa: BLE001
            last_err = str(e)
        time.sleep(10 * (attempt + 1))
    raise RuntimeError(last_err)


def key_black(img: Image.Image, thresh: int = 46, soft: int = 26) -> Image.Image:
    """Fond noir -> transparent, avec falloff doux (l'or reste opaque)."""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            lum = max(r, g, b)
            if lum <= thresh:
                px[x, y] = (r, g, b, 0)
            elif lum <= thresh + soft:
                px[x, y] = (r, g, b, int(255 * (lum - thresh) / soft))
    return img


def autocrop(img: Image.Image, pad: int = 6) -> Image.Image:
    box = img.getchannel("A").getbbox()
    if not box:
        return img
    box = (max(0, box[0] - pad), max(0, box[1] - pad),
           min(img.width, box[2] + pad), min(img.height, box[3] + pad))
    return img.crop(box)


GOLD = (185, 148, 74)
GOLD_DIM = (120, 95, 48)


def _noise_bg(w: int, h: int) -> Image.Image:
    """Fond noir charbon avec marbrures subtiles + vignette (comme le mockup)."""
    rng = random.Random(7)
    small = Image.new("L", (w // 8, h // 8))
    small.putdata([rng.randint(8, 22) for _ in range(small.width * small.height)])
    small = small.filter(ImageFilter.GaussianBlur(2))
    base = small.resize((w, h), Image.BILINEAR)
    img = Image.merge("RGB", (
        base.point(lambda v: v + 3), base.point(lambda v: v + 2), base))
    # vignette
    vig = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(vig)
    d.ellipse((-w // 3, -h // 3, w + w // 3, h + h // 3), fill=40)
    vig = vig.filter(ImageFilter.GaussianBlur(120))
    img = Image.composite(Image.new("RGB", (w, h), (26, 24, 20)), img, vig)
    return img.convert("RGBA")


def compose_bg(w: int, h: int, corner: Image.Image) -> Image.Image:
    """Fond + cadre : 4 coins miroités reliés par un double liseré d'or."""
    img = _noise_bg(w, h)
    d = ImageDraw.Draw(img)
    m, gap = 18, 8            # marge du liseré extérieur, écart avec l'intérieur
    for i, col in ((0, GOLD), (1, GOLD_DIM)):
        o = m + i * gap
        d.rectangle((o, o, w - 1 - o, h - 1 - o), outline=col, width=2)
    # losange décoratif au centre de chaque bord (comme le mockup)
    for cx, cy in ((w // 2, m), (w // 2, h - 1 - m), (m, h // 2), (w - 1 - m, h // 2)):
        r = 13
        d.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)],
                  fill=(14, 12, 10), outline=GOLD)
        d.polygon([(cx, cy - 6), (cx + 6, cy), (cx, cy + 6), (cx - 6, cy)],
                  fill=(236, 200, 120))
    # coins générés, miroités
    c = corner.resize((360, 360), Image.LANCZOS)
    img.alpha_composite(c, (0, 0))
    img.alpha_composite(c.transpose(Image.FLIP_LEFT_RIGHT), (w - 360, 0))
    img.alpha_composite(c.transpose(Image.FLIP_TOP_BOTTOM), (0, h - 360))
    img.alpha_composite(c.transpose(Image.ROTATE_180), (w - 360, h - 360))
    return img


def post() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name in ASSETS:
        raw = RAW / f"{name}.png"
        if not raw.exists():
            print(f"  [skip] {name} (pas de brut)")
            continue
        img = key_black(Image.open(raw))
        img = autocrop(img)
        if name.startswith("icon_"):
            img.thumbnail((512, 512), Image.LANCZOS)
        elif name == "corner":
            img.thumbnail((700, 700), Image.LANCZOS)
        img.save(OUT / f"{name}.png")
        print(f"  [ok] {OUT / (name + '.png')}  {img.size}")
    corner = Image.open(OUT / "corner.png")
    for w, h in ((1920, 1080), (2400, 1080)):
        p = BG_OUT / f"menu_gold_{w}.png"
        compose_bg(w, h, corner).convert("RGB").save(p)
        print(f"  [ok] {p}")


def main() -> int:
    only = ""
    for a in sys.argv[1:]:
        if a.startswith("--only"):
            only = a.split("=", 1)[1] if "=" in a else ""
    force = "--force" in sys.argv
    if "--post" not in sys.argv:
        key = api_key()
        RAW.mkdir(parents=True, exist_ok=True)
        todo = {n: s for n, s in ASSETS.items()
                if (force or not (RAW / f"{n}.png").exists()) and only in n}
        print(f"génération de {len(todo)} asset(s)…")

        def work(item):
            name, spec = item
            try:
                png = generate(key, spec["prompt"], spec["canvas"])
                (RAW / f"{name}.png").write_bytes(png)
                print(f"  [gen] {name}")
            except Exception as e:  # noqa: BLE001
                print(f"  [ERREUR] {name}: {e}", file=sys.stderr)

        with ThreadPoolExecutor(max_workers=4) as ex:
            list(ex.map(work, todo.items()))
    post()
    return 0


if __name__ == "__main__":
    sys.exit(main())
