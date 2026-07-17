# Refonte des niveaux d'IA — Novice / Adepte / Maître

**Date** : 2026-07-17 · **Statut** : validé

## Problème

Les 3 niveaux d'`AiPlayer` ne diffèrent que par un bruit aléatoire sur le score
(±3 / ±1 / ±0.2) et un oubli d'options pour le Novice. Même heuristique, même
comportement : la difficulté ne se ressent pas, le Maître n'est pas challengeant.

## Décisions (validées)

1. **Approche** : heuristiques riches + mini-anticipation 1 coup (pas de vraie
   recherche en profondeur — perf en jeu et simplicité).
2. **Re-tier des 3 niveaux** : chaque niveau a une personnalité distincte.
3. **Skill pur** : même deck, mêmes ressources que le joueur. Le Maître gagne
   uniquement en jouant mieux. Aucun changement aux règles (`scripts/core/` intact).

## Architecture (tout dans `scripts/ai/ai_player.gd`)

*(Mise à jour post-implémentation : l'approche « effets estimés sur snapshot du
plateau » testée en premier ne battait pas le Novice — trop d'approximations.
L'implémentation finale simule chaque action pour de vrai, ce qui reste de
l'anticipation à 1 coup, sans récursion.)*

### 1. Maître = glouton d'évaluation sur simulation réelle (`_choose_master`)

Pour chaque action légale : cloner l'état (`GameState.from_dict(state.to_dict())`
— la sérialisation réseau existante sert de clone), jouer l'action avec les
**vraies règles** (`Rules.apply` : kills, XP, montées de niveau, récompenses en
pierres, effets de mort), noter la position résultante avec `_evaluate`, garder
la meilleure. `end_turn` sert de référence (−0,01 pour préférer agir à valeur
égale). Coût : ~10-30 ms par choix d'action — invisible derrière les animations.

### 2. Fonction d'évaluation `_evaluate(state, me) -> float`

- **PV maîtres** : différentiel ×3.
- **Matériel ajusté au danger** (le facteur décisif mesuré) : Σ valeur des
  monstres, mais un monstre **tuable au prochain tour adverse** (`_doomed` :
  portées réelles — distance/magie touchent tout, mêlée sa colonne écrans
  compris) ne vaut que la **moitié**. Le glouton apprend ainsi à ne pas nourrir
  l'ennemi et à préférer les échanges où les siens survivent — dans les deux sens.
- **Menaces sur les maîtres** : dégâts encaissables par mon maître au prochain
  tour (−1,2/pt, −300 si létal) ; dégâts que je menace sur le sien (+0,8/pt).
- **Position** : mêlée dans une colonne « vivante » (ennemi présent ou colonne
  du maître adverse), mêlée devant / tireur derrière.
- **Tempo** : pierres, cartes en main, XP proche du niveau.

### 3. Personnalités

| Niveau | Comportement |
|---|---|
| **Novice** | Scoring heuristique immédiat seul, aveugle à la défense (pas de couverture, pas de riposte), bruit fort (±3), oublie évolution/pouvoir 50 % du temps, ne bouge jamais son maître, garde toute main au mulligan. Fonce. |
| **Adepte** | Heuristiques complètes (couverture, riposte, tempo, mulligan), bruit ±1. L'ancienne IA, correcte. |
| **Maître** | Simulation réelle 1 coup + `_evaluate` (ci-dessus), bruit ±0,1. |

### 4. Résultats mesurés (`tools/ai_arena.gd`, 40 duels miroirs seedés, sièges alternés)

- Maître vs Novice : **31/40 (77,5 %)** — Maître vs Adepte : **31/40 (77,5 %)**
- Adepte vs Novice : 20/40 (les différencie le style, pas la force)
- Campagne (test_campaign_sim) : toujours gagnable, chapitres tardifs (IA niv 2)
  nettement plus durs qu'avant (2-7/10 pour un joueur simulé Maître).

## Tests (`tests/unit/test_ai.gd`, headless)

- `test_ai_master_beats_novice` : ~40 parties seedées, decks miroir → Maître ≥ 70 %.
- `test_ai_master_beats_adept` : Maître ≥ 58 %.
- Test ciblé : le Maître ne laisse pas son maître exposé à un létal évitable.
- Les tests existants restent verts : légalité, terminaison, prise de létal, mulligan.
- `test_campaign_sim.gd` doit rester vert (campagne toujours gagnable).

## Hors périmètre

- Changement de règles, avantages de ressources, vraie recherche multi-coups,
  UI de sélection de difficulté (existe déjà).
