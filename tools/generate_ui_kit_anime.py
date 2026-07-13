#!/usr/bin/env python3
"""Kit UI premium "Stonebound" : plaques de boutons et panneau 9-slice.

Brief utilisateur (2026-07-13) : AAA fantasy anime (Runeterra/Genshin),
palette bleu nuit #101827/#182235 + or antique #C89A45, boutons en plaques
ouvragées (dégradé, bordure gravée, ornements d'angle), panneaux au cadre d'or
fin. Pipeline habituel : gpt-image-2, fond vert pur -> chroma key, AUCUN texte.

Sorties : assets/sprites/ui/kit/*.png (grande + petite taille par plaque,
pour 9-slice de boutons larges et de petites puces/boutons icône).
Usage: python tools/generate_ui_kit_anime.py [--force] [--only substr] [--post]
"""

import json
import sys
from concurrent.futures import ThreadPoolExecutor
from io import BytesIO
from pathlib import Path

from PIL import Image

from generate_menu_anime import CHROMA, api_key, autocrop, generate, key_green

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites" / "ui" / "kit"
RAW = ROOT / "tools" / "raw_ui_kit"

STYLE_PLATE = (
    " Rendu peint AAA luxueux de jeu de cartes fantasy premium, orfèvrerie "
    "fine, léger reflet métallique brossé, coins arrondis. L'INTÉRIEUR reste "
    "UNI et VIDE (aucun motif central, aucune icône), les bords droits sont "
    "LISSES et réguliers pour un étirement 9-slice. La plaque occupe presque "
    "toute l'image. AUCUN texte, AUCUNE lettre." + CHROMA)

ASSETS = {
    "btn_primary": dict(canvas="1536x1024", prompt=(
        "Plaque de bouton d'interface rectangulaire très allongée : OR "
        "antique (#C89A45) en léger dégradé vertical (or lumineux en haut, "
        "or profond en bas), fine bordure sombre GRAVÉE, minuscules "
        "ornements de filigrane aux quatre coins." + STYLE_PLATE)),
    "btn_secondary": dict(canvas="1536x1024", prompt=(
        "Plaque de bouton d'interface rectangulaire très allongée : BLEU "
        "NUIT profond (#182235) en léger dégradé vertical, très fine "
        "bordure d'or antique gravée, minuscules ornements d'angle dorés "
        "discrets." + STYLE_PLATE)),
    "btn_danger": dict(canvas="1536x1024", prompt=(
        "Plaque de bouton d'interface rectangulaire très allongée : ROUGE "
        "sombre profond en léger dégradé vertical, fine bordure de BRONZE "
        "gravée, minuscules ornements d'angle en bronze." + STYLE_PLATE)),
    "panel_night": dict(canvas="1536x1024", prompt=(
        "Grand panneau d'interface rectangulaire : fond BLEU NUIT profond "
        "(#101827) quasi uni avec très léger dégradé vertical et discrète "
        "texture de pierre polie, cadre TRÈS FIN en or antique, SOBRE et "
        "ÉPURÉ : AUCUN ornement, AUCUN filigrane, AUCUN motif dans les "
        "coins, juste le liseré d'or régulier aux coins arrondis." + STYLE_PLATE)),
}

# (largeur grande, largeur petite) — la petite sert aux puces/boutons icône.
SIZES = { "btn_primary": (560, 192), "btn_secondary": (560, 192),
          "btn_danger": (560, 192), "panel_night": (720, 0) }


def post() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name in ASSETS:
        raw = RAW / f"{name}.png"
        if not raw.exists():
            print(f"  [skip] {name} (pas de brut)")
            continue
        img = autocrop(key_green(Image.open(raw).convert("RGBA")), pad=2)
        big_w, small_w = SIZES[name]
        big = img.copy()
        big.thumbnail((big_w, big_w), Image.LANCZOS)
        big.save(OUT / f"{name}.png")
        print(f"  [ok] {name} {big.size}")
        if small_w:
            small = img.copy()
            small.thumbnail((small_w, small_w), Image.LANCZOS)
            small.save(OUT / f"{name}_sm.png")
            print(f"  [ok] {name}_sm {small.size}")
    manifest_path = ROOT / "tools" / "asset_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {}
    manifest["ui_kit_anime"] = {
        "generator": "tools/generate_ui_kit_anime.py (gpt-image-2, juillet 2026)",
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
