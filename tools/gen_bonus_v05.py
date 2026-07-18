import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
existing=json.loads((ROOT/"resources/data/cards.json").read_text(encoding="utf-8"))["cards"]

def M(id,name,guild,cost,atk_hp,kw=None,atype="melee",rarity="commune",on_summon=None,on_death=None,flavor="",orphan_unit=None):
    levels=[{"xp":[0,3,6][i],"atk":a,"hp":h} for i,(a,h) in enumerate(atk_hp)]
    c={"id":id,"name":name,"guild":guild,"kind":"monster","rarity":rarity,"cost":cost,"attack_type":atype,"levels":levels}
    if kw:c["keywords"]=kw
    if on_summon:c["on_summon"]=on_summon
    if on_death:c["on_death"]=on_death
    if flavor:c["flavor"]=flavor
    c["_orphan_unit"]=orphan_unit  # meta: unité déjà dispo (récupérée) ou None (à générer)
    return c

new=[
 # FLAMME
 M("ember_elemental","Élémentaire de braise","flame",3,[(3,4),(4,5)],atype="magic",rarity="rare",
   on_death=[{"op":"damage","amount":1,"target":"enemy_monster"}],flavor="Né d'un feu qui a oublié sa forme.",orphan_unit="ember_fox"),
 M("kindlemaw","Gueule-braise","flame",4,[(5,4),(6,5)],kw={"haste":True},flavor="Elle mord la mèche."),
 # SYLVE
 M("canopy_watcher","Guetteuse de la canopée","sylvan",3,[(4,3),(5,4)],atype="ranged",rarity="rare",flavor="Perchée, patiente, précise.",orphan_unit="canopy_hunter"),
 M("thornmother","Ronce-mère","sylvan",5,[(4,8),(5,9)],kw={"armor":1},rarity="epique",flavor="Toutes les ronces sont ses filles."),
 # OMBRE
 M("shadow_wolf","Loup des ténèbres","shadow",3,[(5,3),(6,4)],kw={"haste":True},flavor="Il chasse ce qui a peur du noir.",orphan_unit="shade"),
 M("mourning_witch","Sorcière du deuil","shadow",4,[(3,4),(4,5)],atype="magic",rarity="rare",
   on_summon=[{"op":"draw","count":1}],flavor="Chaque nom qu'elle oublie devient un sort.",orphan_unit="grave_sibyl"),
 # LUMIÈRE
 M("dawn_cantor","Chantre de l'aube","light",2,[(2,3),(3,4)],atype="magic",
   on_summon=[{"op":"heal","amount":2,"target":"ally_monster"}],flavor="Son chant recoud les blessures."),
 M("celestial_guard","Gardien céleste","light",5,[(5,6),(6,7)],kw={"flying":True},rarity="epique",flavor="Il veille au sommet des nuées."),
]

def sig(c):
    k=["kind","cost","attack_type","levels","keywords","effect","on_summon","on_attack","on_death","evolves_to","evolve_cost","token"]
    return json.dumps({x:c.get(x) for x in k},sort_keys=True,ensure_ascii=False)
exs={sig(c):c["id"] for c in existing}; exid={c["id"] for c in existing}; exn={c.get("name") for c in existing}
seen={}; bad=[]
for c in new:
    cc={k:v for k,v in c.items() if not k.startswith("_")}
    if c["id"] in exid: bad.append("ID pris: "+c["id"])
    if c["name"] in exn: bad.append("NOM pris: "+c["name"])
    s=sig(cc)
    if s in exs: bad.append("DUP: %s == %s"%(c["id"],exs[s]))
    if s in seen: bad.append("DUP interne: %s == %s"%(c["id"],seen[s]))
    seen[s]=c["id"]
(ROOT/"docs/proposals").mkdir(parents=True,exist_ok=True)
clean=[{k:v for k,v in c.items() if not k.startswith("_")} for c in new]
(ROOT/"docs/proposals/bonus_v05_cards.json").write_text(json.dumps({"cards":clean},ensure_ascii=False,indent="\t")+"\n",encoding="utf-8")
print("COLLISIONS:", "AUCUNE" if not bad else bad)
for c in new:
    lv=c["levels"][0]; src="unité récupérée: "+c["_orphan_unit"] if c["_orphan_unit"] else "NEUVE (art+unité à générer)"
    print("  %-16s %-24s %-7s c%d %d/%d %-6s %s | %s"%(c["id"],c["name"],c["guild"],c["cost"],lv["atk"],lv["hp"],c["attack_type"],c.get("rarity",""),src))
