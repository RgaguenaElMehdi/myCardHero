import sys
from io import BytesIO
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from PIL import Image
sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_ui_pack import generate, read_api_key
ROOT=Path(__file__).resolve().parent.parent; CARDS=ROOT/"assets"/"sprites"/"cards"
AMB={"flame":"donjon de pierre veiné de lave, lueur orange","sylvan":"forêt profonde envahie de mousse verte, lumière tamisée",
     "shadow":"crypte violette et indigo, brume froide","light":"sanctuaire de pierre claire traversé de rais dorés"}
STYLE=("Illustration pixel art anime fantasy 16-bit très détaillée, %s, dans un %s, cadré buste/plan-taille "
       "centré, éclairage dramatique, image opaque plein cadre 1024x1536, aucun texte, aucun cadre, aucune bordure.")
JOBS={
 "ember_whelp":("un marmot de braise, petit diablotin de feu vif aux flammes ardentes","flame"),
 "skyfire_drake":("un drakéon de feu céleste ailé rayonnant aux plumes de flammes","flame"),
 "elderwood_titan":("un titan-arbre ancestral colossal à la barbe de mousse et aux membres de tronc","sylvan"),
 "thorn_whisperer":("une magicienne sylvestre à capuche de feuilles murmurant aux ronces, bâton vivant","sylvan"),
 "grove_sniper":("une franc-tireuse elfe d'élite du bosquet en tenue de feuilles tenant un arc doré ouvragé","sylvan"),
 "void_wraith":("un spectre du vide ailé flottant, silhouette d'ombre aux yeux violets luisants","shadow"),
 "void_devourer":("un dévoreur du vide ailé à la gueule d'ombre béante, énergie violette","shadow"),
 "soul_leech":("une sangsue d'âme spectrale, spectre violet translucide drainant une lueur d'âme","shadow"),
}
def run(it):
    cid,(subj,g)=it
    try:
        raw=generate(read_api_key(),STYLE%(subj,AMB[g]),"1024x1536")
        img=Image.open(BytesIO(raw)).convert("RGB")
        if img.size!=(1024,1536): img=img.resize((1024,1536),Image.LANCZOS)
        img.save(CARDS/f"{cid}.png"); return f"OK {cid}"
    except Exception as e: return f"FAIL {cid} — {e}"
with ThreadPoolExecutor(max_workers=4) as p:
    for r in p.map(run,JOBS.items()): print(r)
