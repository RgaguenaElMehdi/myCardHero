"""Propose les nouvelles cartes v0.5 pour Flamme, Ombre, Lumière (+ tokens).
Écrit docs/proposals/<guilde>_v05_cards.json. Vérifie l'unicité des signatures
gameplay contre cards.json ET contre toutes les propositions (dont sylvan déjà
écrite). NE touche PAS cards.json.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
existing = json.loads((ROOT / "resources/data/cards.json").read_text(encoding="utf-8"))["cards"]


def M(id, name, guild, cost, atk_hp, kw=None, atype="melee", rarity="commune",
      evolves_to=None, evolve_cost=0, on_summon=None, on_death=None, flavor="", token=False):
    levels = [{"xp": ([0, 3, 6] + [9])[i], "atk": a, "hp": h} for i, (a, h) in enumerate(atk_hp)]
    c = {"id": id, "name": name, "guild": guild, "kind": "monster",
         "rarity": rarity, "cost": cost, "attack_type": atype, "levels": levels}
    if kw: c["keywords"] = kw
    if on_summon: c["on_summon"] = on_summon
    if on_death: c["on_death"] = on_death
    if evolves_to: c["evolves_to"] = evolves_to; c["evolve_cost"] = evolve_cost
    if token: c["token"] = True; c.pop("rarity", None)
    if flavor: c["flavor"] = flavor
    return c


def S(id, name, guild, cost, effect, rarity="commune", flavor=""):
    c = {"id": id, "name": name, "guild": guild, "kind": "spell",
         "rarity": rarity, "cost": cost, "effect": effect}
    if flavor: c["flavor"] = flavor
    return c


flame = [
    M("ember_whelp", "Marmot de braise", "flame", 1, [(2, 1), (3, 2)], kw={"haste": True}),
    M("cinder_imp", "Farfadet de cendre", "flame", 1, [(1, 2), (2, 3)],
      on_death=[{"op": "damage_all_enemies", "amount": 1}], flavor="Il explose en partant."),
    M("ash_zealot", "Zélote des cendres", "flame", 2, [(2, 2), (3, 3), (4, 4)], kw={"haste": True},
      rarity="rare", evolves_to="blaze_zealot", evolve_cost=2),
    M("flame_darter", "Dardeur de flammes", "flame", 2, [(3, 1), (4, 2)], atype="ranged"),
    M("molten_brute", "Brute en fusion", "flame", 2, [(2, 4), (3, 5)], kw={"armor": 1}),
    M("magma_hound", "Molosse de magma", "flame", 3, [(4, 2), (5, 3)], kw={"haste": True}),
    M("flarewing", "Aile-flammèche", "flame", 3, [(3, 3), (4, 4)], atype="ranged", kw={"flying": True},
      rarity="rare", evolves_to="skyfire_drake", evolve_cost=2),
    M("searing_lancer", "Lancier ardent", "flame", 6, [(8, 5), (9, 6)], rarity="epique",
      flavor="Sa charge ouvre la voie au brasier final."),
    M("cinder_wyrm", "Wyrm de cendre", "flame", 5, [(6, 4), (7, 5)], kw={"flying": True}, rarity="rare"),
    M("inferno_knight", "Chevalier d'enfer", "flame", 5, [(5, 6), (6, 7)], rarity="epique",
      evolves_to="inferno_lord", evolve_cost=2),
    M("pyre_dragon", "Dragon du bûcher", "flame", 6, [(7, 7), (8, 8)], atype="ranged",
      kw={"flying": True}, rarity="legendaire", evolves_to="elder_pyre_dragon", evolve_cost=2),
    # tokens
    M("blaze_zealot", "Zélote embrasé", "flame", 0, [(5, 5)], kw={"haste": True}, token=True),
    M("skyfire_drake", "Drakéon de feu céleste", "flame", 0, [(6, 5)], atype="ranged", kw={"flying": True}, token=True),
    M("inferno_lord", "Seigneur d'enfer", "flame", 0, [(7, 8)], token=True),
    M("elder_pyre_dragon", "Dragon-bûcher ancestral", "flame", 0, [(9, 9)], atype="ranged", kw={"flying": True}, token=True),
    S("ember_toss", "Jet de braise", "flame", 1, [{"op": "damage", "amount": 2, "target": "enemy_monster"}]),
    S("searing_wave", "Onde brûlante", "flame", 3, [{"op": "damage_all_enemies", "amount": 2}], rarity="rare"),
    S("immolate", "Immolation", "flame", 4, [{"op": "damage", "amount": 5, "target": "enemy_monster"}], rarity="rare"),
    S("battle_fury", "Furie guerrière", "flame", 2, [{"op": "buff", "atk": 3, "hp": 0, "target": "ally_monster"}]),
    S("ember_pact", "Pacte de braise", "flame", 2, [{"op": "stones", "amount": 2}, {"op": "damage", "amount": 1, "target": "enemy_monster"}]),
    S("kindle", "Attiser", "flame", 2, [{"op": "draw", "count": 2}]),
]

shadow = [
    M("grave_imp", "Diablotin des tombes", "shadow", 1, [(1, 1), (2, 2)], flavor="Chair à sacrifice."),
    M("crypt_bat", "Chauve-souris des cryptes", "shadow", 2, [(2, 2), (3, 3)], kw={"flying": True}),
    M("soul_harvester", "Moissonneur d'âmes", "shadow", 3, [(3, 3), (4, 4)],
      on_death=[{"op": "draw", "count": 1}], rarity="rare",
      evolves_to="soul_reaper", evolve_cost=2),
    M("gloom_stalker", "Traqueur des ombres", "shadow", 3, [(4, 3), (5, 4)], kw={"haste": True}),
    M("wight", "Spectre-liche", "shadow", 4, [(4, 4), (5, 5)]),
    M("grave_golem", "Golem funéraire", "shadow", 4, [(3, 6), (4, 7)], kw={"armor": 1}),
    M("bone_colossus", "Colosse d'ossements", "shadow", 4, [(5, 5), (6, 6)], rarity="epique",
      evolves_to="bone_leviathan", evolve_cost=2),
    M("plague_bearer", "Porte-peste", "shadow", 4, [(3, 4), (4, 5)], atype="magic",
      on_death=[{"op": "damage_all_enemies", "amount": 1}]),
    M("dread_knight", "Chevalier d'effroi", "shadow", 5, [(5, 6), (6, 7)], kw={"riposte": 1}, rarity="rare"),
    M("void_wraith", "Spectre du vide", "shadow", 5, [(6, 4), (7, 5)], atype="ranged", kw={"flying": True},
      rarity="epique", evolves_to="void_devourer", evolve_cost=2),
    M("nightmare_lord", "Seigneur cauchemar", "shadow", 6, [(7, 7), (8, 8)], rarity="legendaire",
      evolves_to="dread_sovereign", evolve_cost=2),
    M("abyssal_horror", "Horreur abyssale", "shadow", 6, [(6, 9)], kw={"armor": 1}, rarity="epique"),
    M("soul_reaper", "Faucheur d'âmes", "shadow", 0, [(5, 5)], on_death=[{"op": "draw", "count": 1}], token=True),
    M("bone_leviathan", "Léviathan d'os", "shadow", 0, [(7, 9)], token=True),
    M("void_devourer", "Dévoreur du vide", "shadow", 0, [(8, 6)], atype="ranged", kw={"flying": True}, token=True),
    M("dread_sovereign", "Souverain d'effroi", "shadow", 0, [(9, 9)], token=True),
    S("dark_bolt", "Trait ténébreux", "shadow", 2, [{"op": "damage", "amount": 2, "target": "enemy_monster"}, {"op": "draw", "count": 1}]),
    S("oblivion", "Oubli", "shadow", 5, [{"op": "damage_all_enemies", "amount": 3}], rarity="epique"),
    S("soul_siphon", "Siphon d'âme", "shadow", 4, [{"op": "damage", "amount": 3, "target": "enemy_monster"}, {"op": "heal_master", "amount": 2}], rarity="rare"),
    S("black_market", "Marché noir", "shadow", 2, [{"op": "sacrifice", "target": "ally_monster"}, {"op": "stones", "amount": 2}]),
    S("grim_tutor", "Tuteur funeste", "shadow", 3, [{"op": "draw", "count": 3}], rarity="rare"),
]

light = [
    M("dawn_acolyte", "Acolyte de l'aube", "light", 1, [(2, 2), (3, 3)], on_summon=[{"op": "heal_master", "amount": 1}]),
    M("lightwing", "Aile-lumière", "light", 1, [(2, 1), (3, 2)], kw={"flying": True}),
    M("temple_page", "Page du temple", "light", 1, [(2, 2), (3, 3)],
      flavor="Même les novices portent l'aube au front."),
    M("shield_maiden", "Vierge au bouclier", "light", 2, [(1, 4), (2, 5)], kw={"armor": 1}),
    M("cleric_guard", "Garde-clerc", "light", 2, [(3, 4), (4, 5)], kw={"regen": 1}),
    M("sunpriest", "Prêtre solaire", "light", 3, [(2, 4), (3, 5)], atype="magic",
      on_summon=[{"op": "heal", "amount": 2, "target": "ally_monster"}], rarity="rare",
      evolves_to="high_sunpriest", evolve_cost=2),
    M("radiant_knight", "Chevalier radieux", "light", 3, [(3, 4), (4, 5)], rarity="rare",
      evolves_to="radiant_champion", evolve_cost=2),
    M("gryphon_rider", "Chevaucheuse de griffon", "light", 3, [(4, 3), (5, 4)], kw={"flying": True}),
    M("vanguard_paladin", "Paladin d'avant-garde", "light", 4, [(4, 6), (5, 7)], kw={"armor": 1},
      rarity="epique", evolves_to="high_paladin", evolve_cost=2),
    M("seraphim", "Séraphin gardien", "light", 5, [(5, 5), (6, 6)], kw={"flying": True}, rarity="epique",
      evolves_to="archseraph", evolve_cost=2),
    M("solar_titan", "Titan solaire", "light", 5, [(6, 7), (7, 8)], kw={"regen": 1}, rarity="epique"),
    M("high_sunpriest", "Grand prêtre solaire", "light", 0, [(4, 6)], atype="magic",
      on_summon=[{"op": "heal", "amount": 2, "target": "ally_monster"}], token=True),
    M("radiant_champion", "Champion radieux", "light", 0, [(6, 6)], token=True),
    M("high_paladin", "Grand paladin", "light", 0, [(6, 9)], kw={"armor": 1}, token=True),
    M("archseraph", "Archséraphin", "light", 0, [(7, 7)], kw={"flying": True}, token=True),
    S("smite", "Châtiment", "light", 2, [{"op": "damage", "amount": 2, "target": "enemy_monster"}, {"op": "heal_master", "amount": 1}]),
    S("searing_light", "Lumière incendiaire", "light", 4, [{"op": "damage", "amount": 3, "target": "enemy_monster"}], rarity="rare"),
    S("dawns_wrath", "Courroux de l'aube", "light", 5, [{"op": "damage_all_enemies", "amount": 2}], rarity="epique"),
    S("mend_light", "Baume de lumière", "light", 1, [{"op": "heal", "amount": 2, "target": "ally_monster"}]),
    S("consecrate", "Consécration", "light", 3, [{"op": "heal", "amount": 3, "target": "ally_monster"}, {"op": "buff", "hp": 1, "target": "ally_monster"}]),
    S("crusade", "Croisade", "light", 3, [{"op": "buff", "atk": 2, "hp": 2, "target": "ally_monster"}], rarity="rare"),
]


def sig(c):
    keys = ["kind", "cost", "attack_type", "levels", "keywords", "effect",
            "on_summon", "on_attack", "on_death", "evolves_to", "evolve_cost", "token"]
    defaults = {"levels": [], "keywords": {}, "effect": [], "on_summon": [],
                "on_attack": [], "on_death": [], "token": False}
    return json.dumps({k: c.get(k, defaults.get(k)) for k in keys},
                      sort_keys=True, ensure_ascii=False)


# rassembler tout (existant + sylvan déjà proposé + les 3 nouvelles) pour la vérif
pools = {"flame": flame, "shadow": shadow, "light": light}
syl_path = ROOT / "docs/proposals/sylvan_v05_cards.json"
sylvan = json.loads(syl_path.read_text(encoding="utf-8"))["cards"] if syl_path.exists() else []

seen = {}
ids = set()
names = set()
for c in existing + sylvan:
    seen[sig(c)] = c["id"]
    ids.add(c["id"])
    names.add(c.get("name"))

bad = []
for guild, lst in pools.items():
    for c in lst:
        if c["id"] in ids: bad.append(f"ID pris: {c['id']}")
        if c.get("name") in names: bad.append(f"NOM pris: {c['name']}")
        s = sig(c)
        if s in seen: bad.append(f"DUP gameplay: {c['id']} == {seen[s]}")
        seen[s] = c["id"]; ids.add(c["id"]); names.add(c.get("name"))

for guild, lst in pools.items():
    out = ROOT / f"docs/proposals/{guild}_v05_cards.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps({"cards": lst}, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")
    mon = [c for c in lst if c["kind"] == "monster" and not c.get("token")]
    sp = [c for c in lst if c["kind"] == "spell"]
    tok = [c for c in lst if c.get("token")]
    print(f"{guild}: {len(mon)} monstres, {len(sp)} sorts, {len(tok)} tokens, "
          f"{len([c for c in mon if c.get('evolves_to')])} evoluteurs -> {guild}_v05_cards.json")
print("COLLISIONS:", "AUCUNE" if not bad else str(len(bad)))
for b in bad:
    print("  x", b)
if bad:
    raise SystemExit(1)
