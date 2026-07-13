#!/usr/bin/env python3
"""Pack "anime fantasy" du menu principal Stonebound (mockup v3, juillet 2026).

Génère via gpt-image-2 des images NEUVES (aucune réutilisation d'assets
existants, aucun découpage du mockup) :
  - l'illustration de fond (héros brandissant une carte + compagnons + cité
    fantasy), recadrée en 1920x1080 (desktop) et 2400x1080 (mobile 20:9),
    tiers gauche plus calme pour laisser respirer l'UI ;
  - l'emblème de cristal posé derrière le logo (transparent) ;
  - visuels bannière d'événement, actualités, avatar joueur, insigne de rang ;
  - icônes transparentes : navigation, monnaies, onglets secondaires.
Tout texte reste du vrai texte Godot — AUCUNE lettre dans les images.

Sorties :
  assets/backgrounds/menu_anime_1920.png / menu_anime_2400.png
  assets/sprites/ui/menu/*.png
Bruts : tools/raw_menu_anime/ (itérer la découpe sans rappeler l'API : --post)

Usage: python tools/generate_menu_anime.py [--force] [--only substr] [--post]
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

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites" / "ui" / "menu"
BG_OUT = ROOT / "assets" / "backgrounds"
RAW = ROOT / "tools" / "raw_menu_anime"
URL = "https://api.openai.com/v1/images/generations"
MAX_RETRIES = 4

# Direction artistique du mockup : anime fantasy moderne, lumineux, premium.
# Les images "détourées" sont générées sur fond VERT PUR puis chroma-keyées :
# l'option background=transparent de l'API rend un faux damier peint (vérifié),
# et le vert n'apparaît dans aucune icône (contrairement au noir/magenta).
CHROMA = (" L'objet est posé sur un FOND VERT PUR UNI #00FF00 (fond d'incrustation "
          "chroma key) : AUCUN damier, AUCUNE ombre portée sur le fond, AUCUN "
          "reflet vert sur l'objet.")
STYLE_ICON = (
    "Icône d'interface de jeu premium, style anime fantasy peint, moderne et "
    "lumineux : reflets dorés soignés, léger éclat magique, contour net et "
    "lisible en petite taille, rendu haute résolution. Aucun texte, aucune "
    "lettre, aucun cadre autour de l'icône." + CHROMA)

ASSETS = {
    # ---- illustration principale (recadrée ensuite en 1920/2400) ----
    "bg_main": dict(canvas="1536x1024", transparent=False, prompt=(
        "Illustration anime fantasy moderne de très haute qualité, plan "
        "large cinématographique : un jeune héros aux cheveux bruns en "
        "bataille et aux yeux bleus, manteau bleu nuit aux liserés d'or, "
        "tend vers le spectateur une carte à jouer au dos noir orné d'une "
        "étoile dorée rayonnante de magie ; autour de lui, légèrement en "
        "retrait : un duelliste roux souriant aux vêtements rouge et or "
        "entouré de braises, une archère elfe aux longs cheveux blonds "
        "vêtue de vert, une magicienne élégante aux longs cheveux violet "
        "pâle avec un sceptre de cristal, et une silhouette encapuchonnée "
        "sombre et mystérieuse. Derrière eux, une cité-château fantastique "
        "aux tours claires, bannières colorées, ciel bleu spectaculaire "
        "avec nuages lumineux au couchant, particules magiques dorées. "
        "Composition : le héros au centre-droit, le TIERS GAUCHE de "
        "l'image plus sombre et calme (ciel et tours lointaines) pour y "
        "poser une interface. Couleurs lumineuses et saturées, ambiance "
        "premium, style anime japonais peint soigné. AUCUN texte, AUCUN "
        "logo, AUCUN élément d'interface.")),
    # ---- pièces du logo / panneaux ----
    "emblem_crystal": dict(canvas="1024x1024", transparent=True, prompt=(
        "Grand cristal bleu lumineux facetté dressé à la verticale, serti "
        "d'ornements d'or effilés en couronne à sa base, éclats et "
        "particules de lumière bleue, style anime fantasy peint premium. "
        "Objet unique centré occupant 80% du cadre, aucun texte." + CHROMA)),
    "event_art": dict(canvas="1024x1024", transparent=False, prompt=(
        "Portrait anime fantasy peint : magicienne élégante aux longs "
        "cheveux violet pâle et yeux améthyste, tenue de festival sombre "
        "ornée d'or, sourire mystérieux, fond de fête nocturne violette "
        "avec lanternes et feux d'artifice magiques. Cadrage buste, "
        "couleurs riches, style anime japonais soigné. AUCUN texte.")),
    "news_art": dict(canvas="1024x1024", transparent=False, prompt=(
        "Éventail de trois cartes à jouer au dos bleu nuit orné d'or et "
        "serties de cristaux bleus lumineux, posées sur une table de bois "
        "sombre, éclat magique doré, style anime fantasy peint premium. "
        "AUCUN texte, AUCUNE lettre sur les cartes.")),
    "avatar_player": dict(canvas="1024x1024", transparent=False, prompt=(
        "Portrait carré d'avatar de jeu, style anime fantasy peint : jeune "
        "héros aux cheveux bruns en bataille et yeux bleus déterminés, "
        "manteau bleu nuit à liserés d'or, léger sourire confiant, fond "
        "simple bleu nuit avec halo doré. Visage et épaules centrés. "
        "AUCUN texte.")),
    "rank_badge": dict(canvas="1024x1024", transparent=True, prompt=(
        "Insigne de rang de jeu : écu bleu nuit serti d'un cristal bleu "
        "lumineux, bordure d'argent finement ouvragée, deux petites ailes "
        "d'argent stylisées, style anime fantasy peint premium. Objet "
        "unique centré occupant 78% du cadre, aucun texte." + CHROMA)),
    # ---- icônes de navigation principale ----
    "icon_campaign": dict(canvas="1024x1024", transparent=True, prompt=(
        "Bannière-étendard bleu roi frappée d'une étoile de boussole d'or, "
        "hampe dorée, flottant fièrement. " + STYLE_ICON)),
    "icon_free": dict(canvas="1024x1024", transparent=True, prompt=(
        "Deux épées dorées croisées aux gardes ouvragées, petit éclat "
        "d'étincelle au croisement. " + STYLE_ICON)),
    "icon_deck": dict(canvas="1024x1024", transparent=True, prompt=(
        "Éventail de trois cartes à jouer au dos sombre liseré d'or, la "
        "carte du dessus ornée d'une étoile dorée. " + STYLE_ICON)),
    "icon_collection": dict(canvas="1024x1024", transparent=True, prompt=(
        "Grand livre-grimoire ouvert à couverture bleu nuit et or, pages "
        "lumineuses, petit cristal serti sur la tranche. " + STYLE_ICON)),
    "icon_shop": dict(canvas="1024x1024", transparent=True, prompt=(
        "Échoppe de marché fantasy : auvent rayé rouge et or au-dessus "
        "d'un étal de bois. " + STYLE_ICON)),
    # ---- icônes de navigation secondaire ----
    "icon_quests": dict(canvas="1024x1024", transparent=True, prompt=(
        "Parchemin déroulé aux embouts d'or avec un sceau de cire rouge. "
        + STYLE_ICON)),
    "icon_pass": dict(canvas="1024x1024", transparent=True, prompt=(
        "Écu doré frappé d'une étoile, entouré d'un ruban bleu. "
        + STYLE_ICON)),
    "icon_ranking": dict(canvas="1024x1024", transparent=True, prompt=(
        "Trophée-bouclier d'or couronné de laurier avec une petite "
        "couronne au sommet. " + STYLE_ICON)),
    "icon_settings": dict(canvas="1024x1024", transparent=True, prompt=(
        "Roue dentée d'or au contour net et poli. " + STYLE_ICON)),
    "icon_quit": dict(canvas="1024x1024", transparent=True, prompt=(
        "Porte de bois cerclée d'or entrouverte avec une flèche dorée qui "
        "en sort. " + STYLE_ICON)),
    # ---- icônes barre supérieure ----
    "icon_mail": dict(canvas="1024x1024", transparent=True, prompt=(
        "Enveloppe de parchemin clair scellée de cire dorée. " + STYLE_ICON)),
    "icon_gift": dict(canvas="1024x1024", transparent=True, prompt=(
        "Coffret cadeau bleu nuit au ruban doré noué. " + STYLE_ICON)),
    "icon_social": dict(canvas="1024x1024", transparent=True, prompt=(
        "Deux silhouettes de bustes dorés côte à côte (amis). " + STYLE_ICON)),
    "icon_gold": dict(canvas="1024x1024", transparent=True, prompt=(
        "Pièce d'or brillante frappée d'une étoile à quatre branches. "
        + STYLE_ICON)),
    "icon_shard": dict(canvas="1024x1024", transparent=True, prompt=(
        "Cristal facetté VIOLET lumineux dressé, éclats d'améthyste. "
        + STYLE_ICON)),
    "icon_gem": dict(canvas="1024x1024", transparent=True, prompt=(
        "Cristal facetté BLEU lumineux dressé, éclats de saphir. "
        + STYLE_ICON)),
}

FULL_BLEED = {"bg_main", "event_art", "news_art", "avatar_player"}


def api_key() -> str:
    for line in (ROOT / ".env").read_text(encoding="utf-8").splitlines():
        if line.startswith("OPENAI_API_KEY="):
            return line.split("=", 1)[1].strip()
    print("ERROR: OPENAI_API_KEY introuvable dans .env", file=sys.stderr)
    sys.exit(1)


def generate(key: str, prompt: str, canvas: str) -> bytes:
    payload = {"model": "gpt-image-2", "prompt": prompt, "size": canvas,
               "quality": "high"}
    last_err = ""
    for attempt in range(MAX_RETRIES):
        req = urllib.request.Request(URL, data=json.dumps(payload).encode(),
                                     headers={
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


def key_green(img: Image.Image, hard: int = 70, soft: int = 24) -> Image.Image:
    """Fond vert pur -> transparent, avec falloff doux + suppression du halo
    vert (despill). Les ors/bleus/rouges des icônes ne sont pas touchés."""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            d = g - max(r, b)          # dominance du vert
            if d >= hard:
                px[x, y] = (r, g, b, 0)
            elif d > soft:
                alpha = int(255 * (1 - (d - soft) / (hard - soft)))
                px[x, y] = (r, max(r, b), b, min(a, alpha))
            elif d > 0:
                px[x, y] = (r, max(r, b), b, a)  # despill léger
    return img


def autocrop(img: Image.Image, pad: int = 10) -> Image.Image:
    if img.mode != "RGBA":
        return img
    box = img.getchannel("A").getbbox()
    if not box:
        return img
    box = (max(0, box[0] - pad), max(0, box[1] - pad),
           min(img.width, box[2] + pad), min(img.height, box[3] + pad))
    return img.crop(box)


def cover_crop(img: Image.Image, w: int, h: int, top_bias: float = 0.35) -> Image.Image:
    """Recadrage type "cover" : remplit w x h, coupe l'excédent (biais haut
    pour garder les visages)."""
    scale = max(w / img.width, h / img.height)
    scaled = img.resize((round(img.width * scale), round(img.height * scale)),
                        Image.LANCZOS)
    x = (scaled.width - w) // 2
    y = round((scaled.height - h) * top_bias)
    return scaled.crop((x, y, x + w, y + h))


def post() -> None:
    """Recompose les sorties depuis tools/raw_menu_anime/ sans appel API."""
    OUT.mkdir(parents=True, exist_ok=True)
    BG_OUT.mkdir(parents=True, exist_ok=True)
    for name in ASSETS:
        raw = RAW / f"{name}.png"
        if not raw.exists():
            print(f"  [skip] {name} (pas de brut)")
            continue
        img = Image.open(raw).convert("RGBA")
        if name == "bg_main":
            cover_crop(img, 1920, 1080).save(BG_OUT / "menu_anime_1920.png")
            cover_crop(img, 2400, 1080).save(BG_OUT / "menu_anime_2400.png")
            print("  [ok] menu_anime_1920/2400")
            continue
        if name not in FULL_BLEED:
            img = autocrop(key_green(img))
            # Les icônes s'affichent en ~40-70 px : on les livre déjà réduites
            # (net à l'écran même en filtre nearest, fichiers légers).
            limit = {"emblem_crystal": 512, "rank_badge": 256}.get(name, 192)
            img.thumbnail((limit, limit), Image.LANCZOS)
        img.save(OUT / f"{name}.png")
        print(f"  [ok] {name}")
    _manifest()


def _manifest() -> None:
    path = ROOT / "tools" / "asset_manifest.json"
    manifest = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
    manifest["menu_anime"] = {
        "generator": "tools/generate_menu_anime.py (gpt-image-2, juillet 2026)",
        "assets": {n: a["prompt"][:120] for n, a in ASSETS.items()},
    }
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2),
                    encoding="utf-8")


def main() -> None:
    force = "--force" in sys.argv
    only = ""
    for i, arg in enumerate(sys.argv):
        if arg == "--only" and i + 1 < len(sys.argv):
            only = sys.argv[i + 1]
    if "--post" in sys.argv:
        post()
        return
    key = api_key()
    RAW.mkdir(parents=True, exist_ok=True)
    todo = {n: a for n, a in ASSETS.items()
            if (only in n) and (force or not (RAW / f"{n}.png").exists())}
    print(f"Génération de {len(todo)} image(s)…")

    def one(item):
        name, asset = item
        try:
            data = generate(key, asset["prompt"], asset["canvas"])
            Image.open(BytesIO(data)).save(RAW / f"{name}.png")
            print(f"  [gen] {name}")
        except Exception as e:  # noqa: BLE001
            print(f"  [ERREUR] {name}: {e}", file=sys.stderr)

    with ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(one, todo.items()))
    post()


if __name__ == "__main__":
    main()
