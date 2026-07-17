"""Découpe une PLANCHE ChatGPT (N personnages alignés sur fond magenta) en N
sprites d'unité. Chroma-key -> segmentation par colonnes vides -> crop -> h320.
  python tools/process_unit_sheet.py <raw.png> <id1> <id2> ... [--preview <png>]
Le nombre d'ids doit égaler le nombre de silhouettes détectées, sinon ERREUR
(on ne devine pas). Écrit assets/sprites/units/<id>.png pour chacun.
"""
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_ui_pack import chroma_key, _strip_fringe  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
UNITS = ROOT / "assets" / "sprites" / "units"


def segments(img: Image.Image, gap: int = 14, min_w: int = 40, body_frac: float = 0.12):
    """Bornes [x0,x1) des colonnes de CORPS contiguës. Une colonne compte comme
    corps si son opacité dépasse `body_frac` de la hauteur — ainsi un élément fin
    (arc, queue, liane, bâton) qui franchit l'espace entre deux persos ne les
    fusionne pas."""
    alpha = img.getchannel("A")
    w, h = img.size
    px = alpha.load()
    thresh = h * body_frac
    col_has = []
    for x in range(w):
        s = 0
        for y in range(h):
            if px[x, y] > 40:
                s += 1
        col_has.append(s > thresh)
    segs = []
    x = 0
    while x < w:
        if col_has[x]:
            x0 = x
            run_empty = 0
            while x < w and (col_has[x] or run_empty < gap):
                run_empty = 0 if col_has[x] else run_empty + 1
                x += 1
            x1 = x - run_empty
            if x1 - x0 >= min_w:
                segs.append((x0, x1))
        else:
            x += 1
    return segs


def process(raw_path: str, ids: list, preview: str = "") -> int:
    img = _strip_fringe(chroma_key(Image.open(raw_path).convert("RGBA")))
    segs = segments(img)
    if preview:
        from PIL import ImageDraw
        chk = Image.new("RGB", img.size, (45, 45, 45))
        chk.paste(img, (0, 0), img)
        d = ImageDraw.Draw(chk)
        for (x0, x1) in segs:
            d.rectangle((x0, 0, x1, img.height - 1), outline=(255, 0, 0), width=3)
        chk.save(preview)
    if len(segs) != len(ids):
        print(f"ERREUR: {len(segs)} silhouettes détectées mais {len(ids)} ids "
              f"fournis. Segments={segs}", file=sys.stderr)
        return 1
    UNITS.mkdir(parents=True, exist_ok=True)
    for (x0, x1), cid in zip(segs, ids):
        cell = img.crop((x0, 0, x1, img.height))
        bb = cell.getbbox()
        if bb:
            cell = cell.crop(bb)
        scale = 320.0 / cell.height
        cell = cell.resize((max(1, round(cell.width * scale)), 320), Image.LANCZOS)
        cell.save(UNITS / f"{cid}.png")
        print(f"  units/{cid}.png {cell.size}")
    return 0


if __name__ == "__main__":
    args = sys.argv[1:]
    preview = ""
    if "--preview" in args:
        i = args.index("--preview")
        preview = args[i + 1]
        args = args[:i] + args[i + 2:]
    raw = args[0]
    ids = args[1:]
    sys.exit(process(raw, ids, preview))
