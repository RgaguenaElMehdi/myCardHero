#!/usr/bin/env python3
"""Pack "anime fantasy" du deck builder (mockup deck_builder_v3.png).

Réutilise le pipeline de generate_menu_anime.py (gpt-image-2, fond vert pur +
chroma key pour les objets détourés — l'option background=transparent de l'API
peint un faux damier). Nouvelles images uniquement, AUCUN découpage du mockup,
AUCUN texte dans les images (labels = vrai texte Godot).

Sorties : assets/sprites/ui/deck/*.png — bruts : tools/raw_deck_anime/
Usage: python tools/generate_deck_anime.py [--force] [--only substr] [--post]
"""

import json
import sys
from concurrent.futures import ThreadPoolExecutor
from io import BytesIO
from pathlib import Path

from PIL import Image

from generate_menu_anime import CHROMA, STYLE_ICON, api_key, autocrop, generate, key_green

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites" / "ui" / "deck"
RAW = ROOT / "tools" / "raw_deck_anime"

ASSETS = {
    # Illustration du panneau droit : héros brandissant une carte, ciel nocturne.
    "hero_deck": dict(canvas="1024x1536", keyed=False, prompt=(
        "Illustration anime fantasy moderne de haute qualité, format portrait "
        "vertical : un jeune héros aux cheveux bruns en bataille et aux yeux "
        "bleus, manteau bleu nuit aux liserés d'or, regard déterminé, brandit "
        "à hauteur de son visage une carte à jouer au dos noir orné d'une "
        "étoile dorée rayonnante d'étincelles magiques. Fond : ciel nocturne "
        "bleu profond avec silhouettes de tours de château et lueurs dorées "
        "discrètes, partie basse de l'image sombre et calme. Couleurs "
        "lumineuses, ambiance premium, style anime japonais peint soigné. "
        "AUCUN texte, AUCUN élément d'interface.")),
    # Emplacement vide de carte du deck (dos discret).
    "slot_empty": dict(canvas="1024x1536", keyed=False, prompt=(
        "Emplacement vide de carte à jouer, format portrait 2:3 plein cadre : "
        "fond bleu nuit très sombre légèrement texturé, très fine bordure "
        "dorée discrète aux coins ornés, au centre un blason en filigrane "
        "doré à peine visible (étoile à quatre branches dans un cercle, très "
        "sombre, opacité faible). Sobre et discret, la carte occupe TOUTE "
        "l'image. Style anime fantasy premium, AUCUN texte.")),
    # Icônes détourées (fond vert -> alpha).
    "icon_back": dict(canvas="1024x1024", keyed=True, prompt=(
        "Flèche de retour pointant vers la GAUCHE, dorée et ouvragée, pointe "
        "nette. " + STYLE_ICON)),
    "icon_help": dict(canvas="1024x1024", keyed=True, prompt=(
        "Point d'interrogation doré ouvragé, forme épaisse et lisible. "
        + STYLE_ICON)),
    "icon_save": dict(canvas="1024x1024", keyed=True, prompt=(
        "Parchemin roulé scellé d'un cachet de cire dorée frappé d'une "
        "étoile. " + STYLE_ICON)),
    "icon_search": dict(canvas="1024x1024", keyed=True, prompt=(
        "Loupe dorée au manche ouvragé, verre bleuté brillant. " + STYLE_ICON)),
    "icon_funnel": dict(canvas="1024x1024", keyed=True, prompt=(
        "Entonnoir de filtre doré au contour net. " + STYLE_ICON)),
    "icon_sort": dict(canvas="1024x1024", keyed=True, prompt=(
        "Deux flèches verticales dorées côte à côte, une vers le haut et une "
        "vers le bas. " + STYLE_ICON)),
    "icon_plus": dict(canvas="1024x1024", keyed=True, prompt=(
        "Signe PLUS doré épais aux extrémités ornées. " + STYLE_ICON)),
    "icon_minus": dict(canvas="1024x1024", keyed=True, prompt=(
        "Signe MOINS doré épais aux extrémités ornées (barre horizontale "
        "unique). " + STYLE_ICON)),
    # Emblèmes de guilde (petites puces de filtre + identité du deck).
    "guild_flame": dict(canvas="1024x1024", keyed=True, prompt=(
        "Flamme stylisée orange et or, vive et lumineuse. " + STYLE_ICON)),
    "guild_sylvan": dict(canvas="1024x1024", keyed=True, prompt=(
        "Feuille stylisée vert émeraude nervurée d'or. " + STYLE_ICON)),
    "guild_shadow": dict(canvas="1024x1024", keyed=True, prompt=(
        "Crâne stylisé violet améthyste cerclé d'or, aura sombre. "
        + STYLE_ICON)),
    "guild_light": dict(canvas="1024x1024", keyed=True, prompt=(
        "Soleil rayonnant doré éclatant. " + STYLE_ICON)),
}


def post() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, asset in ASSETS.items():
        raw = RAW / f"{name}.png"
        if not raw.exists():
            print(f"  [skip] {name} (pas de brut)")
            continue
        img = Image.open(raw).convert("RGBA")
        if asset["keyed"]:
            img = autocrop(key_green(img))
            # Icônes consommées telles quelles par des Button (pas de mise à
            # l'échelle par le contrôle) : livrer à la taille d'usage.
            limit = 36 if name == "icon_search" \
                    else 44 if name.startswith("guild_") else 192
            img.thumbnail((limit, limit), Image.LANCZOS)
        elif name == "slot_empty":
            img.thumbnail((512, 768), Image.LANCZOS)
        img.save(OUT / f"{name}.png")
        print(f"  [ok] {name}")
    manifest_path = ROOT / "tools" / "asset_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {}
    manifest["deck_anime"] = {
        "generator": "tools/generate_deck_anime.py (gpt-image-2, juillet 2026)",
        "assets": {n: a["prompt"][:120] for n, a in ASSETS.items()},
    }
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2),
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
