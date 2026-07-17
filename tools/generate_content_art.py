#!/usr/bin/env python3
"""Generate creature/portrait art for new cards & masters via gpt-image-2,
matching the existing pixel-art-on-dungeon-background style
(assets/sprites/cards/*.png, assets/portraits/*.png). No transparency, no
pixel-collapse: build_cards.py crops these into the ornate card frames.

CADRAGE — voir tools/card_art_framing.md (la fenêtre de carte est PAYSAGE
1.75:1, donc le format de l'art doit suivre la forme du sujet) :
  - humanoïde → portrait 1024x1536, PLAN TAILLE (tête en haut, jusqu'à la taille) ;
  - quadrupède / créature large → PAYSAGE 1536x1024, corps entier ;
  - sort → portrait 1024x1536, élément central dans la moitié haute.
Sans ça : têtes coupées (portrait trop serré) ou sujet minuscule.

Reuses the API call from generate_ui_pack. Idempotent (skips existing unless
--force). Usage: python tools/generate_content_art.py [--force] [--only <id>]
"""

import sys
from io import BytesIO
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_ui_pack import generate, read_api_key, chroma_key, _strip_fringe  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
CARDS = ROOT / "assets" / "sprites" / "cards"
PORTRAITS = ROOT / "assets" / "portraits"
UNITS = ROOT / "assets" / "sprites" / "units"

# Board sprites: full-body creature cutouts (transparent, ~h320). Generated on
# a pure-magenta field and chroma-keyed. Spells have no board unit.
UNIT_STYLE = ("Sprite de personnage plein pied isolé, pose de combat dynamique, "
              "vue de trois-quarts face, pixel art 16-bit très détaillé, contours "
              "nets, sur un fond uni magenta pur (#FF00FF) sans décor ni ombre "
              "colorée, 1024x1024, aucun texte.")
UNITS_ART = {
    "cinder_hound": "un molosse de braise, chien de feu aux flancs de cendre fumante et à la gueule rougeoyante, en position d'attaque",
    "flame_berserker": "un berserker de feu enragé, guerrier torse nu aux muscles marqués de runes ardentes, brandissant deux haches enflammées, charge furieuse",
    "spark_sprite": "un petit lutin vif fait d'étincelles électriques et de flammèches, flottant, espiègle",
    "bramble_colt": "un poulain sauvage fait de ronces, de bois et d'épines, cabré",
    "elder_stag": "un grand cerf majestueux aux immenses bois moussus, de face, port noble",
    "grave_hound": "un molosse squelettique des tombes, os terreux et lueur violette aux orbites, grognant",
    "night_stalker": "un rôdeur nocturne encapuchonné aux yeux violets luisants, arc sombre en main",
    "soul_leech": "une sangsue d'âme spectrale flottante, masse sombre translucide nimbée d'une aura violette",
    "dawn_squire": "un jeune écuyer en armure claire et cape blanche, bouclier orné lumineux levé, brave",
    "radiant_griffin": "un griffon radieux doré aux larges ailes déployées, serres en avant, en vol",
    "master_brand": "Brand, maître d'armes féroce au visage balafré en armure de braise, plein pied, arme au poing",
    "master_rowan": "Rowan, berger du bois serein en cape de feuilles tenant un bâton, plein pied",
    "master_vane": "Vane, nécromancienne pâle en robe sombre tenant un grimoire, aura violette, plein pied",
    "master_sol": "Sol, porte-lanterne du temple d'aube tenant une lanterne dorée, halo doux, plein pied",
    # Correctifs de cohérence (le sprite d'origine ne ressemblait pas à la carte).
    "temple_archer": "une archère elfe aux longs cheveux blancs en queue de cheval, oreilles pointues, robe blanche et or à motifs avec écharpe bleue, tenant un grand arc doré ouvragé avec une flèche encochée, pose de tir",
}


UNITS_ART.update({
    "ember_sentinel": "un gardien de forge en armure noire, marteau incandescent, plein pied, pose d?fensive",
    "lava_skirmisher": "un ?claireur agile glissant sur des plaques de lave, dague ardente, plein pied, pr?t ? bondir",
    "cinder_alchemist": "un alchimiste flamboyant tenant des fioles de braise, plein pied, posture concentr?e",
    "pyre_colossus": "un colosse de pierre et de flammes au torse volcanique, plein pied, masse titanesque",
    "smoke_duelist": "un duelliste masqu? envelopp? de fum?e rouge, sabre enflamm?, plein pied, garde basse",
    "mosswarden": "un gardien couvert de mousse et d'?corce, plein pied, cornes de racine, pose protectrice",
    "thorn_whisperer": "une magicienne sylvestre murmurant aux ronces, plein pied, capuche de feuilles, b?ton vivant",
    "canopy_hunter": "un chasseur agile de la canop?e, plein pied, arc de bois vivant, silhouette f?line",
    "root_titan": "un g?ant racinaire au corps de tronc massif, plein pied, longues racines ancr?es au sol",
    "bloom_vanguard": "une avant-garde florale en armure de feuilles, plein pied, bouclier de p?tales lev?",
    "void_hound": "un molosse du vide maigre et rapide, plein pied, yeux violets et crocs sombres",
    "umbra_knight": "un chevalier d'ombre aux plaques d'armure noires, plein pied, ?p?e courbe d?gain?e",
    "grave_sibyl": "une sibylle s?pulcrale tenant un cr?ne et des cartes fun?raires, plein pied, brume violette",
    "dusk_reaver": "un moissonneur cr?pusculaire avec grande faux noire et manteau d'ombres, plein pied",
    "sunward_lancer": "un lancier sacr? en armure claire avec lance et bouclier solaire, plein pied, posture d'assaut",
    "halo_medic": "une gu?risseuse aur?ol?e tenant un b?ton de lumi?re, plein pied, bandage flottant",
    "prism_archon": "un archonte prismatique en manteau de lumi?re portant un sceptre cristallin, plein pied",
    "dawn_paladin": "un paladin de l'aube en armure d'or blanc, plein pied, grande ?p?e lev?e",
    "temple_sentinel": "une sentinelle du temple avec ?norme bouclier grav? et cape ivoire, plein pied",
    "auric_phoenix": "un ph?nix d'or et d'ivoire ? l'aube, plein pied, ailes d?ploy?es, halo brillant",
})

# --- Extension v0.5 : 62 monstres (46 constructibles + 16 tokens) des 4 factions.
UNITS_ART.update({
    # Sylve
    "thistle_pup": "un petit chien-chardon épineux hérissé de piquants verts, plein pied",
    "spore_hopper": "un petit lutin-spore bondissant aux ailettes de feuille, vif, plein pied",
    "oak_squire": "un écuyer humanoïde en armure d'écorce de chêne avec un bouclier, plein pied",
    "vinelasher": "une créature-liane fouettante faite de lianes et de feuilles, plein pied",
    "fawn_guardian": "un jeune faon-gardien bipède couvert de pousses de mousse, doux, plein pied",
    "grovewatch_archer": "une archère elfe de la forêt en tenue de feuilles tenant un arc de bois, plein pied",
    "bramble_ogre": "un ogre massif couvert de ronces et d'épines, plein pied",
    "ancient_boar": "un grand sanglier sauvage massif au pelage brun, plein pied",
    "bloomcaller": "une mage sylvestre appel-floraison, robe de pétales, fleurs lumineuses, plein pied",
    "worldroot_wyrm": "un wyrm-dragon serpentin de racines massives et de lianes, plein pied",
    "elderwood_titan": "un titan-arbre ancestral colossal à la barbe de mousse, plein pied",
    "leaping_bramble": "une ronce bondissante agile, créature de lianes vive, plein pied",
    "great_stag_guard": "un grand cerf-gardien majestueux aux bois couverts de mousse, imposant, plein pied",
    "grove_sniper": "une franc-tireuse elfe d'élite du bosquet, arc doré ouvragé, plein pied",
    "elder_bloom": "un esprit floral géant rayonnant aux grands pétales ouverts, plein pied",
    # Flamme
    "ember_whelp": "un marmot de braise, petit diablotin de feu vif, plein pied",
    "cinder_imp": "un farfadet de cendre espiègle nimbé de fumée, plein pied",
    "ash_zealot": "un zélote des cendres torse nu marqué de runes ardentes, deux haches, plein pied",
    "flame_darter": "un archer de feu agile lançant des traits de flammes, plein pied",
    "molten_brute": "une brute en fusion trapue à la peau de roche incandescente, plein pied",
    "magma_hound": "un molosse de magma bondissant aux flancs de lave, plein pied",
    "flarewing": "un oiseau-esprit de flammèches ailé, plein pied",
    "searing_lancer": "un lancier ardent en armure sombre avec une lance de feu, plein pied",
    "cinder_wyrm": "un wyrm de cendre ailé crachant des braises, plein pied",
    "inferno_knight": "un chevalier d'enfer en armure noire craquelée de lave, épée flamboyante, plein pied",
    "pyre_dragon": "un grand dragon du bûcher ailé aux écailles incandescentes, plein pied",
    "blaze_zealot": "un zélote embrasé enflammé en fureur, aura de feu, plein pied",
    "skyfire_drake": "un drakéon de feu céleste ailé rayonnant, plein pied",
    "inferno_lord": "un seigneur d'enfer colossal en armure de magma, couronne de flammes, plein pied",
    "elder_pyre_dragon": "un dragon-bûcher ancestral titanesque aux ailes de feu, plein pied",
    # Ombre
    "grave_imp": "un petit diablotin des tombes maigre, chair à sacrifice, plein pied",
    "crypt_bat": "une chauve-souris des cryptes aux ailes membraneuses, plein pied",
    "soul_harvester": "un moissonneur d'âmes encapuchonné avec une faucille spectrale, plein pied",
    "gloom_stalker": "un traqueur des ombres furtif aux dagues sombres, plein pied",
    "wight": "un spectre-liche décharné en haillons, lueur froide, plein pied",
    "grave_golem": "un golem funéraire massif fait d'ossements et de pierres tombales, plein pied",
    "bone_colossus": "un colosse d'ossements géant assemblé d'os multiples, plein pied",
    "plague_bearer": "un porte-peste voûté exhalant un nuage toxique violet, plein pied",
    "dread_knight": "un chevalier d'effroi en armure noire épineuse, épée maudite, plein pied",
    "void_wraith": "un spectre du vide flottant, silhouette d'ombre aux yeux violets, plein pied",
    "nightmare_lord": "un seigneur cauchemar imposant aux cornes noires et cape d'ombre, plein pied",
    "abyssal_horror": "une horreur abyssale tentaculaire cuirassée, œil unique, plein pied",
    "soul_reaper": "un faucheur d'âmes spectral à la grande faux, aura violette, plein pied",
    "bone_leviathan": "un léviathan d'os titanesque serpentin, plein pied",
    "void_devourer": "un dévoreur du vide ailé, gueule d'ombre béante, plein pied",
    "dread_sovereign": "un souverain d'effroi colossal couronné, seigneur des ténèbres, plein pied",
    # Lumière
    "dawn_acolyte": "un jeune acolyte de l'aube en robe blanche priant, halo doux, plein pied",
    "lightwing": "un petit être ailé de lumière aux plumes lumineuses, plein pied",
    "temple_page": "un page du temple en tunique claire avec un petit bouclier, plein pied",
    "shield_maiden": "une vierge au bouclier en armure claire, grand pavois gravé, plein pied",
    "cleric_guard": "un garde-clerc en armure d'argent tenant un sceptre de lumière, plein pied",
    "sunpriest": "un prêtre solaire en robe blanc et or, mains rayonnantes, plein pied",
    "radiant_knight": "un chevalier radieux en armure dorée avec épée de lumière, plein pied",
    "gryphon_rider": "une chevaucheuse de griffon ailée sur sa monture léonine ailée, plein pied",
    "vanguard_paladin": "un paladin d'avant-garde en armure d'or blanc, grand bouclier, plein pied",
    "seraphim": "un séraphin gardien à plusieurs ailes lumineuses, armure céleste, plein pied",
    "solar_titan": "un titan solaire colossal de pierre claire rayonnant de soleil, plein pied",
    "high_sunpriest": "un grand prêtre solaire majestueux, halo radiant, sceptre d'or, plein pied",
    "radiant_champion": "un champion radieux en armure d'or éclatant, épée de lumière, plein pied",
    "high_paladin": "un grand paladin sacré en armure d'or blanc massive, aura dorée, plein pied",
    "archseraph": "un archséraphin aux multiples ailes éclatantes, forme divine, plein pied",
})

# Per-guild dungeon ambiance for the background (matches the existing set).
AMBIANCE = {
    "flame": "dans un donjon de pierre sombre veiné de lave, lueur orange et braises",
    "sylvan": "dans un donjon de pierre envahi de mousse verte et de feuillages, lumière tamisée",
    "shadow": "dans une crypte sombre teintée de violet et d'indigo, brume froide",
    "light": "dans un sanctuaire de pierre claire traversé de rais de lumière dorée",
}

STYLE = ("Pixel art fantasy 16-bit très détaillé, gros plan {frame} centré, {amb}, "
         "éclairage dramatique, vignette sombre sur les bords, palette riche, "
         "image opaque plein cadre 1024x1024, aucun texte, aucun cadre, aucune bordure.")

# id -> (subject, guild). kind is implicit (cards vs portraits table).
CARDS_ART = {
    "cinder_hound": ("un molosse de braise, chien de feu aux flancs de cendre fumante et à la gueule rougeoyante, posture agressive", "flame"),
    "flame_berserker": ("un berserker de feu enragé torse nu aux muscles marqués de runes ardentes, brandissant deux haches enflammées, en pleine charge", "flame"),
    "spark_sprite": ("un petit lutin vif fait d'étincelles électriques et de flammèches, créature lumineuse espiègle", "flame"),
    "meteor": ("un énorme météore enflammé fonçant vers le sol en laissant une traînée de feu et de fumée, aucun personnage", "flame"),
    "bramble_colt": ("un poulain sauvage fait de ronces, de bois et d'épines, crinière de feuilles, posture cabrée", "sylvan"),
    "elder_stag": ("un grand cerf majestueux aux immenses bois couverts de mousse et de jeunes feuilles, port noble", "sylvan"),
    "verdant_push": ("un jaillissement de pousses vertes, de lianes et de sève lumineuse fusant vers le haut, aucun personnage", "sylvan"),
    "grave_hound": ("un molosse squelettique des tombes, os terreux et lueur violette dans les orbites, gueule ouverte", "shadow"),
    "night_stalker": ("un rôdeur nocturne encapuchonné fondu dans l'ombre, archer furtif aux yeux violets luisants", "shadow"),
    "soul_leech": ("une sangsue d'âme spectrale flottante, masse sombre translucide drainant une lueur violette", "shadow"),
    "devouring_shadow": ("une ombre dévorante tourbillonnante violette formant une gueule affamée, aucun personnage", "shadow"),
    "dawn_squire": ("un jeune écuyer en armure claire et cape blanche tenant un bouclier orné lumineux, air brave", "light"),
    "radiant_griffin": ("un griffon radieux doré aux larges ailes déployées, plumes éclatantes, serres en avant", "light"),
    "sanctuary": ("un dôme de lumière dorée protecteur au-dessus d'un cercle runique sacré, aucun personnage", "light"),
}


CARDS_ART.update({
    "ember_sentinel": ("un gardien de forge en armure noire, marteau incandescent, devant un four volcanique", "flame"),
    "lava_skirmisher": ("un ?claireur agile glissant sur des plaques de lave, dague ardente, posture de charge", "flame"),
    "cinder_alchemist": ("un alchimiste flamboyant m?langeant des fioles de braise et de m?tal fondu", "flame"),
    "pyre_colossus": ("un colosse de pierre et de flammes avec un torse volcanique et des runes de four", "flame"),
    "smoke_duelist": ("un duelliste masqu? envelopp? de fum?e rouge, sabre enflamm? en garde", "flame"),
    "molten_surge": ("une vague de roche en fusion et d'?tincelles qui d?ferle vers l'avant", "flame"),
    "forge_rite": ("un rituel de forge autour d'enclumes, ?tincelles, cha?nes et sceaux de feu", "flame"),
    "wildfire_burst": ("une explosion de broussailles embras?es, tourbillon de flammes et de cendres", "flame"),
    "ember_reckoning": ("un pacte de braises sur un parchemin br?l?, pi?ces de pierre rouge et main spectrale", "flame"),
    "mosswarden": ("un gardien couvert de mousse et d'?corce, masse v?g?tale, cornes de racine", "sylvan"),
    "thorn_whisperer": ("une magicienne sylvestre murmurant aux ronces, capuche de feuilles, baguette vivante", "sylvan"),
    "canopy_hunter": ("un chasseur agile dans la canop?e, arc de bois vivant, silhouette de f?lin", "sylvan"),
    "root_titan": ("un g?ant racinaire au corps de tronc massif et de longues racines enserrant la terre", "sylvan"),
    "bloom_vanguard": ("une avant-garde florale en armure de feuilles, bouclier de p?tales, posture protectrice", "sylvan"),
    "seed_surge": ("une pluie de graines lumineuses et de jeunes pousses jaillissant d'une main ouverte", "sylvan"),
    "verdant_blessing": ("un faisceau de s?ve verte gu?rissant une blessure et faisant ?clore des fleurs", "sylvan"),
    "canopy_shield": ("un d?me de branches et de feuilles formant une barri?re protectrice", "sylvan"),
    "moonbloom": ("une fleur lunaire brillante qui s'ouvre sur une ros?e argent?e", "sylvan"),
    "living_grove": ("un bosquet miniature qui s'?veille, arbres et lianes sortant d'un cercle de runes", "sylvan"),
    "void_hound": ("un molosse du vide maigre et rapide, yeux violets, crocs sombres", "shadow"),
    "umbra_knight": ("un chevalier d'ombre aux plaques d'armure noires et ? l'?p?e courbe", "shadow"),
    "grave_sibyl": ("une sibylle s?pulcrale tenant un cr?ne et des cartes fun?raires, brume violette", "shadow"),
    "dusk_reaver": ("un moissonneur cr?pusculaire avec grande faux noire et manteau d'ombres", "shadow"),
    "sepulchral_mark": ("une marque fun?bre grav?e sur une pierre tombale, lueur violette et brume", "shadow"),
    "night_veil": ("un voile d'obscurit? et de poussi?re d'?toiles couvrant une silhouette", "shadow"),
    "black_tribute": ("un rituel de tribut noir avec main spectrale, bougie ?teinte et pi?ces d'obsidienne", "shadow"),
    "abyssal_hex": ("un sceau d'ab?me ouvert sous une fissure noire et des tentacules de brume", "shadow"),
    "grave_fog": ("un brouillard de tombe dense avec silhouettes fantomatiques et corbeaux", "shadow"),
    "sunward_lancer": ("un lancier sacr? en armure claire avec lance et bouclier solaire", "light"),
    "halo_medic": ("une gu?risseuse aur?ol?e tenant un b?ton de lumi?re et un bandage flottant", "light"),
    "prism_archon": ("un archonte prismatique en manteau de lumi?re portant un sceptre cristallin", "light"),
    "dawn_paladin": ("un paladin de l'aube en armure d'or blanc, grande ?p?e lev?e au lever du soleil", "light"),
    "temple_sentinel": ("une sentinelle du temple avec ?norme bouclier grav? et cape ivoire", "light"),
    "auric_phoenix": ("un ph?nix d'or et d'ivoire ? l'aube, ailes d?ploy?es, halo brillant", "light"),
    "blessing_ray": ("un rayon de b?n?diction descendant comme une colonne de lumi?re et de particules", "light"),
    "sanctified_aegis": ("un ?cu sacr? baign? d'or, runes de protection et halo radial", "light"),
    "sunrise_liturgy": ("une liturgie ? l'aube avec livre ouvert, lumi?re dor?e et pri?res en spirale", "light"),
    "radiant_pulse": ("une onde radieuse circulaire jaillissant d'un noyau solaire", "light"),
})

PORTRAITS_ART = {
    "brand": ("le portrait en buste de Brand, maître d'armes féroce au visage balafré, armure de braise, regard dur, face au joueur", "flame"),
    "rowan": ("le portrait en buste de Rowan, berger du bois serein, cape de feuilles, barbe mousseuse, bâton, face au joueur", "sylvan"),
    "vane": ("le portrait en buste de Vane, nécromancienne pâle en robe sombre tenant un grimoire, aura violette, face au joueur", "shadow"),
    "sol": ("le portrait en buste de Sol, porte-lanterne du temple d'aube, jeune homme serein tenant une lanterne dorée, halo doux, face au joueur", "light"),
}


def run(name: str, subject: str, guild: str, out_dir: Path, frame: str,
        api_key: str, force: bool) -> str | None:
    path = out_dir / f"{name}.png"
    if path.exists() and not force:
        return None
    prompt = "%s %s" % (subject.capitalize() + ",",
                        STYLE.format(frame=frame, amb=AMBIANCE[guild]))
    try:
        raw = generate(api_key, prompt, "1024x1024")
        img = Image.open(BytesIO(raw)).convert("RGB")
        if img.size != (1024, 1024):
            img = img.resize((1024, 1024), Image.LANCZOS)
        path.parent.mkdir(parents=True, exist_ok=True)
        img.save(path)
        print(f"OK   {out_dir.name}/{name}.png")
        return None
    except Exception as e:  # noqa: BLE001
        print(f"FAIL {name} — {e}", file=sys.stderr)
        return name


def run_unit(name: str, subject: str, api_key: str, force: bool) -> str | None:
    path = UNITS / f"{name}.png"
    if path.exists() and not force:
        return None
    prompt = "%s, %s" % (subject.capitalize(), UNIT_STYLE)
    try:
        raw = generate(api_key, prompt, "1024x1024")
        img = _strip_fringe(chroma_key(Image.open(BytesIO(raw)).convert("RGBA")))
        bbox = img.getbbox()
        if bbox:
            img = img.crop(bbox)
        scale = 320.0 / img.height
        img = img.resize((max(1, round(img.width * scale)), 320), Image.LANCZOS)
        path.parent.mkdir(parents=True, exist_ok=True)
        img.save(path)
        print(f"OK   units/{name}.png ({img.width}x{img.height})")
        return None
    except Exception as e:  # noqa: BLE001
        print(f"FAIL {name} — {e}", file=sys.stderr)
        return name


def main() -> int:
    force = "--force" in sys.argv
    units = "--units" in sys.argv
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else ""
    api_key = read_api_key()
    from concurrent.futures import ThreadPoolExecutor
    if units:
        jobs = [(n, s) for n, s in UNITS_ART.items() if only in n]
        print(f"{len(jobs)} sprite(s) d'unité à générer.")
        with ThreadPoolExecutor(max_workers=4) as pool:
            fails = [f for f in pool.map(
                lambda j: run_unit(j[0], j[1], api_key, force), jobs) if f]
        if fails:
            print(f"\n{len(fails)} échec(s) : {', '.join(fails)}", file=sys.stderr)
            return 1
        print("\nSprites d'unité complets.")
        return 0
    jobs = []
    for name, (subj, guild) in CARDS_ART.items():
        if only in name:
            jobs.append((name, subj, guild, CARDS, "d'une créature ou d'un effet"))
    for name, (subj, guild) in PORTRAITS_ART.items():
        if only in name:
            jobs.append((name, subj, guild, PORTRAITS, "d'un personnage"))
    print(f"{len(jobs)} illustration(s) à générer.")
    with ThreadPoolExecutor(max_workers=4) as pool:
        fails = [f for f in pool.map(
            lambda j: run(j[0], j[1], j[2], j[3], j[4], api_key, force), jobs) if f]
    if fails:
        print(f"\n{len(fails)} échec(s) : {', '.join(fails)}", file=sys.stderr)
        return 1
    print("\nArt de contenu complet.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
