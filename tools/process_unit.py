"""Traite un brut ChatGPT (personnage sur fond magenta) en sprite d'unité :
chroma-key magenta -> transparent, effeuille le liséré, recadre sur le sujet,
redimensionne à h=320 (comme generate_content_art.run_unit).
  python tools/process_unit.py <raw.png> <id>
Écrit assets/sprites/units/<id>.png. Affiche un aperçu sur damier pour contrôle.
"""
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_ui_pack import chroma_key, _strip_fringe  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
UNITS = ROOT / "assets" / "sprites" / "units"


def process(raw_path: str, cid: str, preview: bool = False) -> tuple:
    img = _strip_fringe(chroma_key(Image.open(raw_path).convert("RGBA")))
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    scale = 320.0 / img.height
    img = img.resize((max(1, round(img.width * scale)), 320), Image.LANCZOS)
    UNITS.mkdir(parents=True, exist_ok=True)
    img.save(UNITS / f"{cid}.png")
    # taux de transparence (contrôle qualité du keying)
    alpha = img.getchannel("A")
    hist = alpha.histogram()
    transp = sum(hist[:16])
    total = img.width * img.height
    if preview:
        chk = Image.new("RGB", img.size, (40, 40, 40))
        for y in range(0, img.height, 16):
            for x in range(0, img.width, 16):
                if ((x // 16) + (y // 16)) % 2:
                    for yy in range(y, min(y + 16, img.height)):
                        for xx in range(x, min(x + 16, img.width)):
                            chk.putpixel((xx, yy), (70, 70, 70))
        chk.paste(img, (0, 0), img)
        chk.save(Path(preview))
    return img.size, round(100 * transp / total, 1)


if __name__ == "__main__":
    size, transp = process(sys.argv[1], sys.argv[2],
                           sys.argv[3] if len(sys.argv) > 3 else False)
    print(f"units/{sys.argv[2]}.png {size} — fond transparent {transp}%")
