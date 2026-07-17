# Plan de contenu v0.5 — passer à 40 cartes constructibles / faction

**But** : 92 → **160 constructibles** (40/faction, **+17 chacune**) + monter l'évolution de 2 → **6 évoluteurs/faction** (**+16 tokens**). Total jeu : 100 → **~184 cartes** (**+84 à créer** : 68 jouables + 16 formes évoluées).

Cible par faction : **26 monstres + 14 sorts = 40**. Courbe de coût saine + identité respectée + trous mesurés comblés.

Légende : `+N@coût` = N nouveaux monstres à ce coût. « évo » = slots qui gagnent une forme évoluée (token en plus).

---

## 🔥 FLAMME — agro / burn
Actuel : 15 monstres (1:3 2:3 3:3 4:4 5:1 6:1), 8 sorts. Évolue : flame_imp, phoenix.
Identité : rapide (haste), dégâts directs, échanges agressifs.

**Monstres +11** → cible 26 (1:5 2:6 3:5 4:4 5:3 6:3)
- +2 @1 (agresseurs haste 2/1), +3 @2, +2 @3, +2 @5 (menaces), +2 @6 (gros finishers dont 1 évo)

**Sorts +6** → cible 14 : +1 dégât simple, +1 AoE, +1 « brûlure » (dégâts + rien), +1 buff/haste, +2 utilitaire (pioche/pierre)

**Évoluteurs +4** (→6) : 2 petits (1-2) qui montent en 3-4, 2 mid (3-4) qui montent en finisher.

---

## 🌿 SYLVE — valeur / ramp / croissance
Actuel : 14 monstres (1:2 2:3 3:5 4:2 5:2), 9 sorts. Évolue : sprout, sylph.
Trous mesurés : présence tôt limitée, **quasi aucune interaction** (1 seul sort de dégât).
Identité : gros corps, regen, buffs, ramp (pierres), épines/racines = seul retrait.

**Monstres +12** → cible 26 (1:4 2:6 3:6 4:5 5:3 6:2)
- +2 @1 (blockers regen), +3 @2, +1 @3, +3 @4 (corps de valeur), +1 @5, +2 @6 (titans, 1 évo)

**Sorts +5** → cible 14 : **+2 dégâts « ronces/racines »** (le gros manque d'interaction), +1 ramp (pierres), +1 buff, +1 heal/pioche

**Évoluteurs +4** (→6) : thème « graine → arbre » — 2 @1-2 qui deviennent gros, 2 @3-4 → titans.

---

## 🌑 OMBRE — attrition / sacrifice / retrait
Actuel : 14 monstres (1:2 2:5 3:4 4:1 5:2), 9 sorts. Évolue : shade, bone_knight.
Trous mesurés : creux au milieu/haut (peu de corps 4, finishers récents).
Identité : sacrifice + pioche, drain, nuée → sacrifice, retrait.

**Monstres +12** → cible 26 (1:3 2:6 3:6 4:5 5:4 6:2)
- +1 @1 (jetons à sacrifier), +1 @2, +2 @3, +4 @4 (comble le creux), +2 @5, +2 @6 (1 évo)

**Sorts +5** → cible 14 : +1 dégât, +1 AoE, +1 drain (dégât + soin maître), +1 sacrifice-valeur, +1 pioche

**Évoluteurs +4** (→6) : thème « mort → renaissance » — monstres qui montent via kills/sacrifice.

---

## ✨ LUMIÈRE — protection / soin / sacré
Actuel : 15 monstres (1:1 2:4 3:3 4:4 5:1 6:2), 8 sorts. Évolue : squire, archangel.
Trous mesurés : **1 seul 1-drop**, **sur-dépendance au bouclier** (7 monstres à bouclier — à diversifier vers armure/soin), offense faible.
Identité : défensif, soin, dégâts « sacrés », résilience.

**Monstres +11** → cible 26 (1:4 2:6 3:6 4:5 5:3 6:2)
- +3 @1 (comble le trou early), +2 @2, +3 @3, +1 @4, +2 @5 — privilégier armure/regen plutôt que +bouclier

**Sorts +6** → cible 14 : **+3 dégâts « sacrés »** (single + AoE — offense manquante), +2 heal, +1 buff. Ne PAS rajouter de bouclier (déjà nerfé).

**Évoluteurs +4** (→6) : thème « écuyer → paladin → archange » — chaînes d'ascension.

---

## Récap des slots à créer

| Faction | Monstres | Sorts | Évoluteurs (tokens) |
|---|---|---|---|
| Flamme | +11 | +6 | +4 |
| Sylve | +12 | +5 | +4 |
| Ombre | +12 | +5 | +4 |
| Lumière | +11 | +6 | +4 |
| **Total** | **+46** | **+22** | **+16** |

→ **+68 constructibles + 16 tokens = 84 cartes à créer.**

## Garde-fous (déjà outillés)
- Pas de doublon de gameplay : `tests/unit/test_card_catalog.gd::test_expansion_has_no_gameplay_duplicates` (coût + effet + mots-clés). Choisir des signatures uniques.
- Équilibre gros grain : `tools/master_arena.gd` (mais biais IA sur boucliers — cf. note ci-dessous).
- Chaque carte : JSON dans `cards.json` → art via ChatGPT + `tools/build_cards.py --only <id>` → `card_art_framing.md` pour le cadrage.

## Ordre de travail conseillé
1. Remplir les **JSON** des 68 constructibles (stats/coût/effet) faction par faction, en visant les courbes ci-dessus et des signatures uniques.
2. Définir les **16 évolutions** (`evolves_to` + token, coût 0, `token: true`).
3. Passe d'**équilibrage** (arène) une fois les JSON posés.
4. **Générer les arts** en lot (le plus long) puis `build_cards`.
