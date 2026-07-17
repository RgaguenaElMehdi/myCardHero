"""Propose les 17 nouvelles cartes Sylve (+4 tokens) pour la v0.5.
Écrit docs/proposals/sylvan_v05_cards.json et vérifie que chaque signature de
gameplay est UNIQUE vs cards.json (le test anti-doublon). NE touche PAS cards.json.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
existing = json.loads((ROOT / "resources/data/cards.json").read_text(encoding="utf-8"))["cards"]


def M(id, name, cost, atk_hp, kw=None, atype="melee", rarity="commune",
      evolves_to=None, evolve_cost=0, on_summon=None, flavor="", token=False):
    """Monstre. atk_hp = liste de (atk,hp) par niveau ; xp: 0,3,6..."""
    levels = []
    for i, (a, h) in enumerate(atk_hp):
        levels.append({"xp": [0, 3, 6][i] if i < 3 else 9, "atk": a, "hp": h})
    c = {"id": id, "name": name, "guild": "sylvan", "kind": "monster",
         "rarity": rarity, "cost": cost, "attack_type": atype, "levels": levels}
    if kw:
        c["keywords"] = kw
    if on_summon:
        c["on_summon"] = on_summon
    if evolves_to:
        c["evolves_to"] = evolves_to
        c["evolve_cost"] = evolve_cost
    if token:
        c["token"] = True
        c.pop("rarity", None)
    if flavor:
        c["flavor"] = flavor
    return c


def S(id, name, cost, effect, rarity="commune", flavor=""):
    c = {"id": id, "name": name, "guild": "sylvan", "kind": "spell",
         "rarity": rarity, "cost": cost, "effect": effect}
    if flavor:
        c["flavor"] = flavor
    return c


new = [
    # --- Monstres (12) : courbe 1:+2 2:+3 3:+1 4:+3 5:+1 6:+2 ---
    M("thistle_pup", "Chardonneau", 1, [(1, 3), (2, 4)], kw={"riposte": 1},
      flavor="Petit, piquant, tenace."),
    M("spore_hopper", "Sauteur à spores", 1, [(1, 2), (2, 3), (3, 4)], kw={"haste": True},
      rarity="rare", evolves_to="leaping_bramble", evolve_cost=2,
      flavor="Il bondit avant même d'avoir poussé."),
    M("oak_squire", "Écuyer de chêne", 2, [(2, 3), (3, 4)], kw={"armor": 1},
      flavor="L'écorce fait l'armure."),
    M("vinelasher", "Fouet-liane", 2, [(2, 2), (3, 3)], atype="ranged",
      flavor="La forêt frappe à distance."),
    M("fawn_guardian", "Gardien faon", 2, [(1, 4), (2, 5), (3, 6)], kw={"regen": 1},
      rarity="rare", evolves_to="great_stag_guard", evolve_cost=2,
      flavor="Il grandira. Patiemment."),
    M("grovewatch_archer", "Archère du bosquet", 3, [(3, 3), (4, 4)], atype="ranged",
      rarity="rare", evolves_to="grove_sniper", evolve_cost=2,
      flavor="Rien ne bouge sous la canopée sans qu'elle le sache."),
    M("bramble_ogre", "Ogre de ronces", 4, [(4, 5), (5, 6)], kw={"riposte": 1},
      flavor="Le toucher, c'est saigner."),
    M("ancient_boar", "Sanglier ancien", 4, [(5, 4), (6, 5)],
      flavor="Il laboure tout ce qui gêne."),
    M("bloomcaller", "Appel-floraison", 4, [(3, 5), (4, 6)], atype="magic", rarity="rare",
      on_summon=[{"op": "buff", "target": "ally_monster", "hp": 1}],
      evolves_to="elder_bloom", evolve_cost=2,
      flavor="Un chant, et le bois répond."),
    M("verdant_colossus", "Colosse verdoyant", 5, [(5, 7), (6, 8)], kw={"regen": 1},
      rarity="epique", flavor="La mousse a fini par marcher."),
    M("worldroot_wyrm", "Wyrm des racines-monde", 6, [(6, 8), (7, 9)], kw={"armor": 1},
      rarity="epique", flavor="Ses anneaux courent sous des royaumes entiers."),
    M("elderwood_titan", "Titan sylve-ancienne", 6, [(7, 9)], rarity="legendaire",
      flavor="Aussi vieux que la première graine."),
    # --- Tokens (4 formes évoluées) ---
    M("leaping_bramble", "Ronce bondissante", 0, [(4, 4)], kw={"haste": True}, token=True,
      flavor="Elle a pris goût au saut."),
    M("great_stag_guard", "Grand cerf-gardien", 0, [(4, 7)], kw={"regen": 1}, token=True,
      flavor="Les bois du faon sont devenus un rempart."),
    M("grove_sniper", "Franc-tireuse du bosquet", 0, [(5, 5)], atype="ranged", token=True,
      flavor="Une flèche, une cible."),
    M("elder_bloom", "Floraison ancienne", 0, [(5, 8)], atype="magic", token=True,
      flavor="La fleur qui ne fane jamais."),
    # --- Sorts (5) : +2 dégâts (interaction), +1 ramp, +1 buff, +1 heal/pioche ---
    S("thorn_dart", "Dard d'épine", 1, [{"op": "damage", "amount": 1, "target": "enemy_monster"}],
      flavor="Petite pointe, grande gêne."),
    S("root_snare", "Piège de racines", 4,
      [{"op": "damage", "amount": 4, "target": "enemy_monster"}], rarity="rare",
      flavor="Les racines saisissent, puis serrent."),
    S("verdant_tithe", "Sève abondante", 2, [{"op": "stones", "amount": 2}],
      flavor="La forêt paie ses dettes en énergie."),
    S("feral_might", "Fureur sauvage", 2,
      [{"op": "buff", "atk": 2, "hp": 1, "target": "ally_monster"}],
      flavor="L'instinct par-dessus la raison."),
    S("restful_glade", "Clairière paisible", 2,
      [{"op": "heal", "amount": 2, "target": "ally_monster"}, {"op": "draw", "count": 1}],
      rarity="rare", flavor="On y reprend souffle et cartes."),
]


def sig(c):
    keys = ["kind", "cost", "attack_type", "levels", "keywords", "effect",
            "on_summon", "on_attack", "on_death", "evolves_to", "evolve_cost", "token"]
    defaults = {"levels": [], "keywords": {}, "effect": [], "on_summon": [],
                "on_attack": [], "on_death": [], "token": False}
    return json.dumps({k: c.get(k, defaults.get(k)) for k in keys},
                      sort_keys=True, ensure_ascii=False)


ex_sigs = {sig(c): c["id"] for c in existing}
ex_ids = {c["id"] for c in existing}
ex_names = {c.get("name") for c in existing}
seen = {}
collisions = []
for c in new:
    if c["id"] in ex_ids:
        collisions.append(f"ID déjà pris : {c['id']}")
    if c.get("name") in ex_names:
        collisions.append(f"NOM déjà pris : {c['name']}")
    s = sig(c)
    if s in ex_sigs:
        collisions.append(f"DOUBLON gameplay : {c['id']} == {ex_sigs[s]} (existant)")
    if s in seen:
        collisions.append(f"DOUBLON gameplay : {c['id']} == {seen[s]} (nouveau)")
    seen[s] = c["id"]

out_dir = ROOT / "docs/proposals"
out_dir.mkdir(parents=True, exist_ok=True)
out = out_dir / "sylvan_v05_cards.json"
out.write_bytes((json.dumps({"cards": new}, ensure_ascii=False, indent="\t") + "\n").encode("utf-8"))

mon = [c for c in new if c["kind"] == "monster" and not c.get("token")]
tok = [c for c in new if c.get("token")]
sp = [c for c in new if c["kind"] == "spell"]
print(f"Proposition écrite : docs/proposals/sylvan_v05_cards.json")
print(f"  {len(mon)} monstres, {len(sp)} sorts, {len(tok)} tokens, "
      f"{len([c for c in mon if c.get('evolves_to')])} évoluteurs")
print("COLLISIONS :", "AUCUNE" if not collisions else "")
for x in collisions:
    print("  ✗", x)
if collisions:
    raise SystemExit(1)
