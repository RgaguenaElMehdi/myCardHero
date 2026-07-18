import sys
from io import BytesIO
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from PIL import Image
sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_ui_pack import generate, read_api_key

ROOT = Path(__file__).resolve().parent.parent
CARDS = ROOT / "assets" / "sprites" / "cards"
AMB = {"flame":"donjon de pierre veiné de lave, lueur orange",
       "sylvan":"forêt profonde envahie de mousse verte, lumière tamisée",
       "shadow":"crypte violette et indigo, brume froide",
       "light":"sanctuaire de pierre claire traversé de rais dorés"}
STYLE=("Illustration pixel art anime fantasy 16-bit très détaillée, %s, dans un %s, "
       "cadré buste/plan-taille centré, éclairage dramatique, image opaque plein cadre "
       "1024x1536, aucun texte, aucun cadre, aucune bordure.")
JOBS={
 "ember_elemental":("un élémentaire de braise, créature de feu vivant, corps de flammes et de charbons ardents","flame"),
 "kindlemaw":("une bête de braise trapue à la gueule incandescente pleine de crocs de feu, féroce","flame"),
 "canopy_watcher":("une guetteuse elfe de la canopée en tenue de feuilles tenant un arc de bois vivant","sylvan"),
 "thornmother":("une gardienne-mère de ronces, grande dame de bois et d'épines couronnée de roses","sylvan"),
 "shadow_wolf":("un loup des ténèbres spectral au pelage d'ombre et aux yeux blancs luisants, menaçant","shadow"),
 "mourning_witch":("une sorcière du deuil pâle en robe sombre à l'aura violette tenant un grimoire","shadow"),
 "dawn_cantor":("un jeune chantre de l'aube en robe blanche et or, chantant, notes de lumière dorée","light"),
 "celestial_guard":("un gardien céleste ailé en armure d'argent et d'or, lance de lumière, halo radieux","light"),
}
def run(item):
    cid,(subj,guild)=item
    try:
        raw=generate(read_api_key(), STYLE%(subj,AMB[guild]), "1024x1536")
        img=Image.open(BytesIO(raw)).convert("RGB")
        if img.size!=(1024,1536): img=img.resize((1024,1536),Image.LANCZOS)
        img.save(CARDS/f"{cid}.png"); return f"OK {cid}"
    except Exception as e: return f"FAIL {cid} — {e}"
with ThreadPoolExecutor(max_workers=4) as p:
    for r in p.map(run, JOBS.items()): print(r)
