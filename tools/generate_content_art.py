#!/usr/bin/env python3
"""Generate creature/portrait art for new cards & masters via gpt-image-2,
matching the existing 1024x1024 pixel-art-on-dungeon-background style
(assets/sprites/cards/*.png, assets/portraits/*.png). No transparency, no
pixel-collapse: build_cards.py crops these into the ornate card frames.

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
    "magma_brute": "un colosse de roche noire et de magma aux bras massifs et fissures incandescentes, debout et menaçant",
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
    "magma_brute": ("un colosse massif de roche noire et de magma, bras énormes, fissures incandescentes entre les plaques", "flame"),
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
