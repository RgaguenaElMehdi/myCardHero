# Stonebound — Design Document

**Date** : 2026-07-04 · **Moteur** : Godot 4.6.1 (GDScript) · **Cible** : Windows desktop, 2D, 1920×1080

Clone spirituel de *Trade & Battle: Card Hero* (GBC, 2000) — un jeu de cartes **tactique sur plateau** — modernisé et rendu plus nerveux. Session autonome : les décisions ci-dessous sont prises et documentées sans validation interactive.

---

## 1. Vision

- **Le cœur de Card Hero** : monstres posés sur une grille, positionnement décisif, économie de pierres, montée en niveau / évolution des monstres en cours de partie, le Maître est une pièce vulnérable sur le plateau.
- **« En mieux, plus fun »** : parties plus courtes (decks de 20), Maîtres avec pouvoirs actifs/passifs, mots-clés lisibles, drag & drop, feedback juteux (animations, particules, SFX), IA à 3 niveaux, campagne scénarisée avec déblocage de cartes et deck builder.

## 2. Règles du jeu (spec exacte)

### 2.1 Plateau
- Grille **3 colonnes × 4 rangées**. Rangées 0–1 = Joueur A (0 = arrière, 1 = avant) ; rangées 2–3 = Joueur B (2 = avant, 3 = arrière).
- Le **Maître** occupe une case de SA rangée arrière (choix au setup). Les monstres se posent sur les cases vides de ses 2 rangées (jamais sur la case du Maître).

### 2.2 Ressources & pioche
- **Pierres** : départ 3, **+2 par tour** (début de tour), plafond **12**. Tuer un monstre ennemi rapporte des pierres = **niveau de la victime** (passif de Maître peut modifier).
- **Deck 20 cartes**, max 2 exemplaires par carte. Main max **7** (si pleine : pas de pioche). Pioche 1/tour ; le premier joueur ne pioche pas au tour 1. **Deck vide au moment de piocher = défaite**.
- **Mulligan** : une fois au départ, rejouer sa main de 5.

### 2.3 Tour de jeu
1. **Début** : +2 pierres, pioche 1.
2. **Phase principale** (actions libres dans n'importe quel ordre) :
   - **Invoquer** : payer le coût, poser sur case vide alliée. Mal d'invocation (n'agit pas ce tour) sauf mot-clé *Célérité*.
   - **Sort** : payer, résoudre, défausser.
   - **Action de monstre** : chaque monstre a **1 action/tour : bouger** (1 case orthogonale, dans ses 2 rangées) **ou attaquer**.
   - **Déplacer le Maître** : 1 fois/tour, gratuit, case adjacente de la rangée arrière.
   - **Pouvoir du Maître** : actif unique, coût en pierres, 1 fois/tour.
3. **Fin de tour**.

### 2.4 Combat
- **Mêlée** : cible le monstre ennemi **le plus proche dans sa colonne** (scan vers l'arrière ennemi). Un monstre en rangée arrière est **bloqué** si un allié occupe la case avant de sa colonne. Peut frapper le **Maître** seulement si la colonne du Maître est vide de monstres ennemis (côté défenseur) et que l'attaquant est en rangée avant.
- **Distance** : cible **n'importe quel monstre ennemi**. Maître ciblable seulement si **exposé** (aucun monstre défenseur dans la colonne du Maître).
- **Magie** (type d'attaque) : comme Distance, mais **ignore Armure et Bouclier**.
- **Dégâts** = ATK attaquant − Armure cible (min 0). Pas de contre-attaque, sauf mot-clé *Riposte*.
- **XP** : +1 XP quand un monstre blesse un monstre ennemi, +2 XP pour un kill. Paliers par carte (ex. 2 XP → niv 2, 5 XP → niv 3). Montée de niveau = gains de stats définis par la carte, **soin complet**.
- **Évolution** : au niveau max, si la carte définit une évolution, le propriétaire peut payer le coût d'évo (action gratuite, 1×) → transformation en la carte évoluée, PV max, garde sa position ; compte comme monstre de son niveau 1.

### 2.5 Mots-clés (6)
| Mot-clé | Effet |
|---|---|
| **Célérité** | Peut agir le tour d'invocation |
| **Vol** | Ciblable uniquement par Distance/Magie ; sa mêlée ignore le blocage de colonne |
| **Armure X** | Réduit les dégâts subis de X (sauf Magie) |
| **Riposte X** | Renvoie X dégâts à l'attaquant en mêlée |
| **Régénération X** | Soigne X PV au début du tour de son propriétaire |
| **Bouclier** | Annule la première source de dégâts subie (sauf Magie), puis se brise |

### 2.6 Maîtres (20 PV, pas d'attaque de base)
| Maître | Guilde | Passif | Actif (1×/tour) |
|---|---|---|---|
| **Kiran** | Flamme | Ses sorts de dégâts +1 | *Boule de feu* (3🪨) : 2 dégâts à un monstre |
| **Willow** | Sylve | Ses monstres +1 PV max à l'invocation | *Sève* (2🪨) : soigne 3 PV à un monstre allié |
| **Grim** | Ombre | Récompense de kill +1 pierre | *Pacte* (1🪨) : sacrifie un allié, pioche 2 |
| **Aria** | Lumière | Subit −1 dégât des attaques Distance | *Égide* (2🪨) : donne Bouclier à un allié |

### 2.7 Victoire / défaite
PV du Maître adverse ≤ 0 → victoire. Deck-out → défaite. Abandon possible.

## 3. Contenu v1
- **32 cartes constructibles** : 24 monstres (6 par guilde : Flamme, Sylve, Ombre, Lumière) + 8 sorts (2 par guilde). En plus : **8 formes évoluées** (non constructibles, atteintes en jeu).
- Coûts : monstres 1–6 🪨, sorts 1–4 🪨. Courbe : chaque guilde a 2 petits (1–2), 2 moyens (3–4), 2 gros (5–6) monstres.
- **4 Maîtres**, débloqués via la campagne (Kiran de départ).

## 4. Campagne « Le Circuit de Petraheim » (10 chapitres)
Village de **Petraheim**, où se tient le tournoi annuel de Stonebound. Héros silencieux (le joueur), coaché par **Maro**, vieux champion retiré. Rival : **Jasper**, arrogant mais loyal. Champion masqué : **Nox**, qui joue des cartes interdites. Twist (ch. 8) : Nox est **Sera**, l'ancienne partenaire de Maro, disparue après avoir été accusée d'avoir triché — elle veut prouver que le « jeu parfait » n'existe pas. Finale : la battre à la loyale, réhabilitation, le héros devient champion.

| Ch. | Contenu | Adversaire (IA) | Récompense |
|---|---|---|---|
| 1 | Tutoriel + dialogue | Maro (Novice, deck bridé) | cartes de base |
| 2 | 1er tour du tournoi | Pip (Novice) | 2 cartes Sylve |
| 3 | Rivalité | Jasper (Novice+) | 2 cartes Flamme, Maître Willow |
| 4 | Quart de finale | Bruna (Adepte) | 2 cartes Ombre |
| 5 | Interlude : Nox humilie Jasper | Sbire de Nox (Adepte) | 2 cartes Lumière, Maître Grim |
| 6 | Demi-finale | Edda (Adepte) | 2 cartes au choix |
| 7 | Revanche amicale | Jasper (Maître) | Maître Aria |
| 8 | Révélation Nox/Sera | Maro (Maître) — entraînement final | 2 cartes |
| 9 | Finale, manche 1 | Nox (Maître) | — |
| 10 | Finale, manche 2 + épilogue | Nox (Maître, deck amélioré) | titre + mode libre |

Hors campagne : **Partie libre** (vs IA, tout niveau) et **deck builder** avec la collection débloquée.

## 5. Architecture technique

### 5.1 Principe : cœur de règles pur, données déclaratives, assets externes
- `scripts/core/` : **logique pure sans nœuds de scène** (RefCounted). Déterministe, RNG seedé. Testable en headless.
- Cartes/Maîtres/Campagne = **Resources `.tres`** (`CardDef`, `MasterDef`, `ChapterDef`) dans `resources/` — zéro donnée de gameplay codée en dur dans les scripts.
- Tous les visuels/sons dans `assets/` (générés par Gemini / procéduraux), référencés par les Resources.

### 5.2 Arborescence
```
res://
├── project.godot
├── scenes/            # main_menu, battle, deck_builder, campaign, dialogue, settings
├── scripts/
│   ├── core/          # game_state, board, monster, rules (validation+application des actions), combat, keywords
│   ├── ai/            # action_enumerator, evaluator, ai_player (3 difficultés)
│   ├── ui/            # scripts des scènes
│   ├── defs/          # card_def.gd, master_def.gd, chapter_def.gd (Resources)
│   └── autoload/      # Db (chargement resources), Game (profil/sauvegarde), EventBus, Audio
├── resources/         # cards/*.tres, masters/*.tres, campaign/*.tres
├── assets/            # sprites/cards, sprites/ui, portraits, backgrounds, fonts, audio
├── tests/             # runner headless + unit + integration (soak IA vs IA)
└── tools/             # generate_assets.py (Gemini), gen_sfx.py
```

### 5.3 Flux du moteur de règles
- `GameState` = état complet sérialisable. Les intentions du joueur/IA sont des **Actions** (dictionnaires typés : SUMMON, MOVE, ATTACK, CAST, MASTER_MOVE, MASTER_POWER, EVOLVE, END_TURN).
- `Rules.legal_actions(state, player)` énumère ; `Rules.apply(state, action)` valide puis mute + émet une liste d'**événements** (pour l'UI : dégâts, mort, level-up…). L'UI et l'IA passent par la même API — jamais de logique de règles dans l'UI.

### 5.4 IA
Énumère les actions légales, joue au coup-par-coup avec une évaluation heuristique (valeur matérielle, menace sur les Maîtres, exposition, tempo pierres). Novice = choix bruité, Adepte = glouton, Maître = glouton + anticipation des menaces à 1 coup.

### 5.5 Sauvegarde
`user://profile.json` : progression campagne, collection, decks, options. Versionné (`save_version`).

### 5.6 Pipeline d'assets (Gemini)
`tools/generate_assets.py` lit `GEMINI_API_KEY` dans `.env` (jamais commité), génère via `gemini-2.5-flash-image` : illustrations de cartes (style unifié « gouache fantasy lumineuse, cadrage buste »), portraits de personnages, fonds de scène, icônes UI. Manifeste JSON → ne régénère que le manquant. Post-traitement : recadrage/redimensionnement aux tailles cibles.
SFX : synthèse procédurale (`gen_sfx.py`, WAV). Musique : boucles simples procédurales.

### 5.7 Tests
- **Unitaires** : mini-framework maison (`tests/test_runner.gd`, exécuté via `godot --headless -s`), couvre combat, blocage, XP/évolution, pierres, mots-clés, conditions de victoire, chaque sort et pouvoir de Maître.
- **Intégration** : soak **IA vs IA** (100+ parties seedées) : aucune erreur, aucune action illégale, terminaison < 200 tours.
- **Visuel/manuel** : lancement fenêtré instrumenté + captures d'écran automatisées aux étapes clés.

## 6. Approches écartées
- **Reproduction 1:1 de Card Hero** (règles Junior/Senior/Pro, 30 cartes/deck) : plus fidèle mais plus lent et moins lisible ; contraire au « en mieux, plus fun ».
- **Données en JSON pur** : portable, mais les Resources Godot typées donnent validation, inspecteur et chargement natif — mieux pour la maintenabilité.
- **GUT comme framework de test** : standard mais dépendance externe ; un runner maison de ~100 lignes suffit et reste sous contrôle en headless.

## 7. Critères de fin (Definition of Done)
1. Campagne 10 chapitres jouable de bout en bout, dialogues et récompenses inclus.
2. Partie libre + deck builder fonctionnels.
3. Tous les tests unitaires et le soak IA vs IA passent sans erreur console.
4. Tous les assets générés présents (aucun placeholder), audio inclus.
5. Aucune erreur/warning bloquant au lancement ; partie complète vérifiée manuellement via instrumentation.
