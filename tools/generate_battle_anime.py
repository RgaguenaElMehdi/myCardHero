#!/usr/bin/env python3
"""Pack "anime fantasy" du plateau de bataille (mockup battle v3).

Pipeline habituel (voir generate_menu_anime.py) : gpt-image-2, fond vert pur
-> chroma key pour les pièces détourées, AUCUN texte dans les images.

Sorties :
  assets/backgrounds/arena_ruins_1920.png / arena_ruins_2400.png
  assets/sprites/ui/battle/*.png
Usage: python tools/generate_battle_anime.py [--force] [--only substr] [--post]
"""

import json
import sys
from concurrent.futures import ThreadPoolExecutor
from io import BytesIO
from pathlib import Path

from PIL import Image

from generate_menu_anime import CHROMA, STYLE_ICON, api_key, autocrop, cover_crop, generate, key_green

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites" / "ui" / "battle"
BG_OUT = ROOT / "assets" / "backgrounds"
RAW = ROOT / "tools" / "raw_battle_anime"

ASSETS = {
    # Décor d'arène : esplanade VIDE au centre (la grille est posée par le jeu).
    "arena_bg": dict(canvas="1536x1024", keyed=False, prompt=(
        "Vue de DESSUS en forte plongée d'une vaste esplanade rectangulaire "
        "de dalles de pierre lisses et claires, VIDE (aucune grille marquée, "
        "aucun personnage) : l'esplanade occupe le CENTRE de l'image, "
        "environ 55% de la largeur et 75% de la hauteur, ses quatre bords "
        "visibles. Tout autour, une étroite bordure de ruines antiques "
        "élégantes envahies de végétation luxuriante et de piliers ouvragés ; "
        "tout en haut de l'image, un aperçu d'une cité fantastique lumineuse "
        "avec chutes d'eau. De grands CRISTAUX ROUGES lumineux sur les "
        "piliers des coins SUPÉRIEURS, de grands CRISTAUX BLEUS lumineux "
        "sur les piliers des coins INFÉRIEURS. Lumière chaude dorée, "
        "couleurs riches, style anime fantasy peint AAA. AUCUN texte, "
        "AUCUN élément d'interface.")),
    # Arène nocturne (mockup battle v4) : plateau 3x4 PEINT dans le décor,
    # la grille du jeu est calée dessus via les exports d'arena.gd.
    "arena_night": dict(canvas="1536x1024", keyed=False, prompt=(
        "AAA anime fantasy game environment concept art, night scene, ONLY "
        "scenery, NO interface, NO characters, NO text, NO icons. An ancient "
        "magical battle arena built on a floating island of carved stone, "
        "seen in 3/4 slightly top-down perspective, perfectly symmetrical. "
        "In the center, ONE tactical game board carved into the flat stone "
        "floor: EXACTLY 3 columns and 4 rows of large rectangular cells (12 "
        "cells total, never more), cells cleanly separated by engraved gold "
        "lines and runes, slight bevel, elegant ornaments. The TOP TWO rows "
        "glow with soft RED magical energy, the BOTTOM TWO rows glow with "
        "BLUE magical energy. The board is a slight trapeze (narrower at the "
        "top) and occupies about 55% of the image width, centered, with "
        "generous empty stone margins around it. Around the arena: ancient "
        "columns with RED crystals and red fantasy banners at the far "
        "corners, BLUE magical crystals near the bottom corners, stone "
        "lanterns, golden ornaments, magic braziers — everything OUTSIDE the "
        "board. Background: a huge fantasy kingdom on floating islands, "
        "massive waterfalls, bridges, a gigantic castle, mountains, cloud "
        "ocean, moonlight, Milky Way, volumetric fog, god rays. Blue ambient "
        "light with warm golden highlights, cinematic, ultra detailed, hand "
        "painted, Legends of Runeterra / Genshin Impact quality.")),
    # Arène VUE DE DESSUS (mockup battle v4b) : cases uniformes, pas de
    # perspective — la grille du jeu se cale au pixel sans trapèze.
    "arena_top": dict(canvas="1536x1024", keyed=False, prompt=(
        "AAA anime fantasy game environment concept art, night scene, ONLY "
        "scenery, NO interface, NO characters, NO text. STRICT TOP-DOWN "
        "bird's-eye view (90 degrees, no perspective, orthographic look) of "
        "an ancient magical battle arena on a floating island of carved "
        "stone. In the center, ONE tactical board engraved in the flat "
        "stone floor: EXACTLY 3 columns and 4 rows of large IDENTICAL "
        "rectangular cells (12 cells total, never more), all cells the SAME "
        "size, perfectly aligned like a chessboard, separated by clean "
        "engraved gold lines and runes, elegant ornaments. The TOP TWO rows "
        "of cells glow with soft RED magical energy, the BOTTOM TWO rows "
        "glow with BLUE magical energy. The board is perfectly rectangular "
        "(seen exactly from above), centered, occupying about 45% of the "
        "image width, with generous stone margins around it. Around the "
        "esplanade, seen from above: ornate pillar tops with RED crystals "
        "near the top corners and BLUE crystals near the bottom corners, "
        "red banners, stone lanterns, golden ornaments, magic braziers — "
        "everything OUTSIDE the board. Beyond the island edges: the void "
        "with moonlit clouds far below, hints of waterfalls falling off the "
        "island, blue magical atmosphere. Blue ambient light with warm "
        "golden highlights, cinematic, ultra detailed, hand painted, "
        "Legends of Runeterra / Genshin Impact quality.")),
    # Arène finale (reco TCG AAA) : caméra 3/4 LÉGÈRE (~20-25°), esplanade
    # VIDE — les 12 cases sont dessinées par Godot (arena_iso.tscn).
    "arena_iso": dict(canvas="1536x1024", keyed=False, prompt=(
        "AAA anime fantasy game environment concept art, night scene, ONLY "
        "scenery, NO interface, NO characters, NO text, NO icons. A grand "
        "magical battle arena built on a floating stone island, seen from a "
        "VERY SLIGHT 3/4 angle: camera tilted only about 20 degrees from "
        "vertical, facing straight ahead (no rotation), like premium "
        "digital card games. The center of the image is a large EMPTY "
        "esplanade of grey ancient stone, PERFECTLY FLAT, rectangular "
        "with a very slight perspective taper, centered, occupying about "
        "60% of the image width. CARVED INTO the stone floor: EXACTLY 12 "
        "identical rectangular card slots, 3 columns and 4 rows, "
        "perfectly aligned — each slot is a shallow RECESSED housing "
        "sunk into the stone (soft inner shadow, real depth), bordered "
        "by finely sculpted stone with thin GOLD inlays and small "
        "engraved runes, discreet ornamental corners, DEEPLY recessed "
        "as if the arena had been built to hold magical summons. The "
        "stone stays GREY: absolutely no colored fill — the ONLY color "
        "is a subtle RED light seeping out of the rune grooves of the 6 "
        "UPPER slots, and a subtle BLUE light seeping from the 6 LOWER "
        "slots, like Legends of Runeterra. The terrain tells a story: "
        "the upper ENEMY half is built of slightly darker, colder stone; "
        "the lower PLAYER half of slightly warmer, lighter stone; and "
        "between the two halves, a clearly WIDER front line marked by a "
        "MONUMENTAL ANCIENT RUNE CIRCLE engraved across the full width "
        "of the esplanade, faintly glowing with magical energy along a "
        "central line. Wide ceremonial STAIRS descend at the top and "
        "bottom edges of the esplanade. Generous empty stone margins "
        "remain around the 12 slots. The esplanade is a TRUE ARENA: a "
        "monumental SCULPTED stone base with SEVERAL LEVELS — wide "
        "foundation, cornices, a raised outer LEDGE with a carved "
        "PARAPET all around, and visible steps on the sides — so the "
        "arena clearly FLOATS. Around the esplanade WITHOUT touching "
        "the slots: ancient statues, weathered ruins overgrown with "
        "vegetation and ivy, elegant columns and ornate pillars, stone "
        "torches with warm flames, decorative chains, large "
        "RED magical crystals on the pillars near the two TOP corners, "
        "large BLUE magical crystals near the two BOTTOM corners, red "
        "fantasy banners, decorative golden chains between pillars, stone "
        "lanterns and magic braziers with warm flames — all OUTSIDE the "
        "empty central esplanade, a few elements slightly overlapping its "
        "outer edge. Background at the top: a gigantic luminous fantasy "
        "castle on floating islands, waterfalls, bridges, moon and Milky "
        "Way. Below and around: floating cliffs falling into a moonlit "
        "cloud ocean. Blue ambient light, warm golden highlights, "
        "cinematic, ultra detailed, hand painted, Legends of Runeterra / "
        "Genshin Impact quality.")),
    # Fond de l'écran « Partie libre » (choix adversaire + difficulté) :
    # parvis nocturne, centre sombre et dégagé pour les panneaux UI.
    "freeplay_bg": dict(canvas="1536x1024", keyed=False, prompt=(
        "AAA anime fantasy game background concept art, night scene, ONLY "
        "scenery, NO interface, NO characters, NO text, NO icons. A wide "
        "ceremonial stone plaza at night seen from eye level: ancient "
        "paved ground engraved with a huge faint rune circle, elegant "
        "stone balustrades and staircases on both sides, tall glowing "
        "BLUE magical crystals on carved pedestals, warm stone lanterns "
        "and candles, ancient statues overgrown with ivy, decorative "
        "night-blue banners with golden compass stars. Sky: deep blue "
        "night, bright full moon, and a gigantic luminous fantasy castle "
        "with tall spires on the horizon, floating islands, subtle "
        "Milky Way. The CENTER of the image stays darker, empty and "
        "uncluttered (large interface panels will be displayed over it); "
        "all the detailed scenery lives on the edges. Blue ambient light "
        "with warm golden highlights, cinematic, ultra detailed, hand "
        "painted, Legends of Runeterra / Genshin Impact quality.")),
    # Orbe FIN DU TOUR : disque de cristal bleu cerclé d'or.
    "orb_endturn": dict(canvas="1024x1024", keyed=True, prompt=(
        "Grand bouton rond de jeu : disque de CRISTAL BLEU profond lumineux "
        "aux reflets magiques, serti dans un anneau d'OR antique finement "
        "gravé avec petits ornements. Face avant vue de face, intérieur du "
        "disque assez sombre et UNI pour rester lisible derrière un texte. "
        + STYLE_ICON)),
    # Ruban de bannière de tour ("À vous de jouer !", texte réel par-dessus).
    "banner_ribbon": dict(canvas="1536x1024", keyed=True, prompt=(
        "Large bannière-ruban horizontale déployée, en tissu bleu nuit "
        "profond bordé d'OR antique finement ouvragé, extrémités en pointes "
        "élégantes repliées, centre UNI et sombre (le texte sera affiché "
        "par-dessus), légers reflets dorés. Très allongée et basse, centrée. "
        + STYLE_ICON)),
    # Icônes de la barre latérale des Paramètres (style orfèvrerie dorée).
    "icon_audio": dict(canvas="1024x1024", keyed=True, prompt=(
        "Icône : haut-parleur doré ouvragé avec petites ondes sonores, style "
        "orfèvrerie fantasy. " + STYLE_ICON)),
    "icon_display": dict(canvas="1024x1024", keyed=True, prompt=(
        "Icône : écran/moniteur doré au contour finement gravé, style "
        "orfèvrerie fantasy. " + STYLE_ICON)),
    "icon_account": dict(canvas="1024x1024", keyed=True, prompt=(
        "Icône : buste de personnage (profil utilisateur) doré au trait "
        "ouvragé, style orfèvrerie fantasy. " + STYLE_ICON)),
    "icon_menu": dict(canvas="1024x1024", keyed=True, prompt=(
        "Icône : trois lignes horizontales dorées ouvragées (menu), style "
        "orfèvrerie. " + STYLE_ICON)),
    "icon_emotes": dict(canvas="1024x1024", keyed=True, prompt=(
        "Icône : bulle de dialogue dorée au contour ouvragé avec un petit "
        "sourire gravé. " + STYLE_ICON)),
    # Blason des points de vie (le nombre reste du vrai texte par-dessus).
    "hp_shield": dict(canvas="1024x1024", keyed=True, prompt=(
        "Écu héraldique ROUGE profond serti d'une bordure d'or antique "
        "finement gravée, centre UNI et sombre (aucun motif central, le "
        "chiffre sera affiché par-dessus). " + STYLE_ICON)),
    # Dos de cartes (pioche, main adverse).
    "back_blue": dict(canvas="1024x1536", keyed=False, prompt=(
        "Dos de carte à jouer plein cadre, format portrait : fond BLEU NUIT "
        "profond richement orné, grande étoile-boussole dorée rayonnante au "
        "centre, fine bordure d'or aux coins ouvragés, style anime fantasy "
        "peint AAA luxueux. La carte occupe TOUTE l'image. AUCUN texte.")),
    "back_red": dict(canvas="1024x1536", keyed=False, prompt=(
        "Dos de carte à jouer plein cadre, format portrait : fond ROUGE "
        "sombre profond richement orné, grande étoile-boussole dorée "
        "rayonnante au centre, fine bordure d'or aux coins ouvragés, style "
        "anime fantasy peint AAA luxueux. La carte occupe TOUTE l'image. "
        "AUCUN texte.")),
    # Cases du plateau : bordure GRAVÉE dans la pierre, incrustation d'or,
    # lueur de camp très légère. Intérieur transparent (chroma), NinePatch.
    "cell_red": dict(canvas="1536x1024", keyed=True, prompt=(
        "Bordure de case de plateau de jeu RECTANGULAIRE horizontale, "
        "coins à peine arrondis, GRAVÉE EN CREUX dans de la pierre "
        "ancienne : un fin sillon sculpté avec une mince INCRUSTATION "
        "D'OR et quelques runes minuscules, très discret et élégant, "
        "l'aspect d'une gravure dans le sol (léger relief, ombre du "
        "creux), au fond du sillon une TRÈS LÉGÈRE lueur ROUGE douce. "
        "AUCUN gros cadre, AUCUN ornement massif, épaisseur constante et "
        "fine. L'INTÉRIEUR est entièrement FOND VERT PUR (vide), la "
        "bordure occupe presque toute l'image. " + STYLE_ICON)),
    "cell_blue": dict(canvas="1536x1024", keyed=True, prompt=(
        "Bordure de case de plateau de jeu RECTANGULAIRE horizontale, "
        "coins à peine arrondis, GRAVÉE EN CREUX dans de la pierre "
        "ancienne : un fin sillon sculpté avec une mince INCRUSTATION "
        "D'OR et quelques runes minuscules, très discret et élégant, "
        "l'aspect d'une gravure dans le sol (léger relief, ombre du "
        "creux), au fond du sillon une TRÈS LÉGÈRE lueur BLEUE douce. "
        "AUCUN gros cadre, AUCUN ornement massif, épaisseur constante et "
        "fine. L'INTÉRIEUR est entièrement FOND VERT PUR (vide), la "
        "bordure occupe presque toute l'image. " + STYLE_ICON)),
    # Attache murale des panneaux UI : les panneaux font partie de l'arène.
    "panel_mount": dict(canvas="1024x1024", keyed=True, prompt=(
        "Ferrure d'attache en métal doré forgé pour fixer un panneau : "
        "petit support ornemental avec rivets, d'où part vers le HAUT un "
        "court segment de CHAÎNE dorée à trois maillons, style fantasy "
        "élégant, vu de face. " + STYLE_ICON)),
    # Piédestal des maîtres : dais de pierre circulaire, suit la colonne du
    # maître (widget board_cell), teinté rouge/bleu par camp via modulate.
    "dais_master": dict(canvas="1536x1024", keyed=True, prompt=(
        "Piédestal bas de pierre sculptée vu de dessus en très légère "
        "plongée : disque elliptique horizontal à deux gradins, cerclé "
        "d'un anneau d'OR gravé de runes discrètes, centre de pierre UNIE "
        "légèrement sombre (un personnage sera affiché par-dessus), "
        "élégant, ancien, sobre. FOND VERT PUR tout autour du piédestal. "
        + STYLE_ICON)),
}

SIZES = { "orb_endturn": 320, "icon_menu": 96, "icon_emotes": 96,
          "hp_shield": 192, "cell_red": 384, "cell_blue": 384,
          "dais_master": 320, "panel_mount": 128, "banner_ribbon": 1024 }


def post() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, asset in ASSETS.items():
        raw = RAW / f"{name}.png"
        if not raw.exists():
            print(f"  [skip] {name} (pas de brut)")
            continue
        img = Image.open(raw).convert("RGBA")
        if name == "arena_bg":
            cover_crop(img, 1920, 1080).save(BG_OUT / "arena_ruins_1920.png")
            cover_crop(img, 2400, 1080).save(BG_OUT / "arena_ruins_2400.png")
            print("  [ok] arena_ruins_1920/2400")
            continue
        if name == "freeplay_bg":
            cover_crop(img, 1920, 1080).save(BG_OUT / "freeplay_1920.png")
            cover_crop(img, 2400, 1080).save(BG_OUT / "freeplay_2400.png")
            print("  [ok] freeplay_1920/2400")
            continue
        if name == "arena_iso":
            # biais bas : la rangée 4 doit finir au-dessus de la main (y=842)
            cover_crop(img, 1920, 1080, top_bias=1.0).save(
                BG_OUT / "arena_iso_1920.png")
            cover_crop(img, 2400, 1080, top_bias=0.9).save(
                BG_OUT / "arena_iso_2400.png")
            print("  [ok] arena_iso_1920/2400")
            continue
        if name == "arena_top":
            # biais bas : le plateau doit finir au-dessus de la main (y=842)
            cover_crop(img, 1920, 1080, top_bias=1.0).save(
                BG_OUT / "arena_top_1920.png")
            cover_crop(img, 2400, 1080, top_bias=0.655).save(
                BG_OUT / "arena_top_2400.png")
            print("  [ok] arena_top_1920/2400")
            continue
        if name == "arena_night":
            # biais bas : le plateau 3x4 peint doit finir AU-DESSUS de la main
            # (HandArea y=842) ; géométrie recalée dans scenes/arenas/arena_night*.
            cover_crop(img, 1920, 1080, top_bias=0.875).save(
                BG_OUT / "arena_night_1920.png")
            cover_crop(img, 2400, 1080, top_bias=0.84).save(
                BG_OUT / "arena_night_2400.png")
            print("  [ok] arena_night_1920/2400")
            continue
        if asset["keyed"]:
            img = autocrop(key_green(img), pad=2)
            limit = SIZES.get(name, 192)
            img.thumbnail((limit, limit), Image.LANCZOS)
        else:
            img.thumbnail((512, 768), Image.LANCZOS)
        img.save(OUT / f"{name}.png")
        print(f"  [ok] {name} {img.size}")
    manifest_path = ROOT / "tools" / "asset_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {}
    manifest["battle_anime"] = {
        "generator": "tools/generate_battle_anime.py (gpt-image-2, juillet 2026)",
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
