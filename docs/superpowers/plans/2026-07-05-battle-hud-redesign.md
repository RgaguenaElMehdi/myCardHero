# Refonte HUD de bataille (style Runeterra) — Plan d'implémentation (Lot 2)

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Étapes visuelles → vérif par éditeur + `--screenshot` + `--autoplay` (pas de TDD unitaire pour du layout de scène).

**Goal:** Agrandir l'arène et réduire le HUD aux bords (LoR) : PV+pouvoir sur les jetons Maître, pierres en pips, deck/main par joueur, Fin du tour centre-droit, panneau info carte au clic gauche, journal en icônes.

**Architecture:** Réagencement de `scenes/battle.tscn` (structure déclarative) + adaptation de `scripts/ui/battle_scene.gd` (logique d'affichage), `battle_fx.gd` (anims), `board_cell.gd` (jeton Maître). Flux `Rules.apply → events → battle_fx` inchangé.

**Tech Stack:** Godot 4.6 (exe 4.5.1 mono console pour headless), GDScript.

## Global Constraints

- **Périmètre UI/HUD uniquement.** Ne pas toucher : police (Cinzel), filtre de texture, rendu de carte (`CardWidget.create`). Ces sujets ont été annulés — hors périmètre.
- **UI dans la scène** (Règle n°1) : structure dans `battle.tscn`, script = logique.
- Plateau **3×4**, **Maître = unité sur le plateau** (rangée arrière). Pierres max 12.
- **FR** ; fichiers **UTF-8** ; `GODOT` = `C:/Users/rgagu/Downloads/Godot_v4.5.1-stable_mono_win64/Godot_v4.5.1-stable_mono_win64/Godot_v4.5.1-stable_mono_win64_console.exe`.
- Vérif de non-régression : `GODOT --headless --path . res://scenes/battle.tscn -- --autoplay` doit finir une partie sans erreur ; `-s res://tests/run_tests.gd` reste vert.

---

### Task 1: Agrandir l'arène + retirer les gros panneaux

**Files:** `scenes/battle.tscn`, `scripts/ui/battle_scene.gd`

- [ ] **Step 1: Retirer `EnemyPanel`, `PlayerPanel`, `InfoPanel` de `battle.tscn`**
  Supprimer les nœuds `EnemyPanel` (l.167), `PlayerPanel` (l.335), `InfoPanel` (l.509) et leurs enfants. Conserver pour réemploi : `EndTurnBtn`, `TurnLabel`, `TurnInfo`, `PowerBtn` (les re-parenter sous `.` temporairement).

- [ ] **Step 2: Agrandir la zone arène**
  Dans la scène d'arène (`scenes/arenas/arena_dungeon.tscn` / `arena.gd`, méthode `cell_rect`), augmenter l'emprise de la grille pour occuper le centre élargi (les `BoardCell` se repositionnent automatiquement via `arena.cell_rect`). Recentrer `BoardArea` et `RowMarker*`.

- [ ] **Step 3: Nettoyer les références mortes dans `battle_scene.gd`**
  Retirer `@onready var enemy_panel`, `player_panel` ; retirer le bloc « Right-click a side panel = inspect master » (l.~213-220) ; retirer `portrait`/`hp_bar`/`name` des dicts `enemy_info`/`player_info` (ces infos passent sur le jeton Maître, Task 2). Garder `stones`, `hand`, `deck` (repositionnés aux Tasks 3-5).

- [ ] **Step 4: Vérifier**
  `GODOT --headless --path . --import` (pas d'erreur de scène) puis `GODOT --path . res://scenes/battle.tscn --resolution 1920x1080 -- --autoplay --screenshot=%TEMP%/b1.png`. Ouvrir `b1.png` : arène agrandie et centrée, plus de gros panneaux latéraux. Aucune `SCRIPT ERROR`.

- [ ] **Step 5: Commit** `feat(battle): arene agrandie, panneaux lateraux retires`

---

### Task 2: PV + pouvoir sur les jetons Maître

**Files:** `scripts/ui/board_cell.gd`, `scenes/widgets/board_cell.tscn`, `scripts/ui/battle_scene.gd`

- [ ] **Step 1: Mettre en valeur le Maître dans `board_cell`**
  Dans `board_cell.gd`/`board_cell.tscn` : quand l'occupant est un Maître, afficher les **PV en gros** (icône cœur + nombre, plus grand qu'une unité) et une **icône ✦ pouvoir**. Exposer une méthode `set_master_power(available: bool)` pour l'état actif/grisé.

- [ ] **Step 2: Brancher l'activation du pouvoir sur le jeton**
  Dans `battle_scene.gd`, `_on_cell_clicked` : si la case cliquée porte ton Maître et que le pouvoir est jouable, déclencher `_on_power_pressed()` (réutiliser la logique existante). Sinon comportement de sélection normal.

- [ ] **Step 3: Reposition/masquer `PowerBtn`**
  Le bouton pouvoir global devient contextuel : soit un mini-bouton près du jeton Maître sélectionné, soit masqué au profit du clic direct sur le jeton. Choisir le clic direct (plus simple) ; garder `PowerBtn` masqué en secours.

- [ ] **Step 4: Vérifier** capture `--autoplay` : PV bien visibles sur les deux Maîtres, icône pouvoir présente. Jouer un pouvoir (autoplay le fait) sans erreur.

- [ ] **Step 5: Commit** `feat(battle): PV et pouvoir portes par le jeton Maitre`

---

### Task 3: Pierres en pips (les deux joueurs)

**Files:** `scenes/battle.tscn`, `scripts/ui/battle_scene.gd`

- [ ] **Step 1: Créer l'affichage pips**
  Ajouter dans `battle.tscn` `PlayerStones` (bas-droite, près du deck) et `EnemyStones` (haut-droite) sous forme d'une rangée de gemmes : N gemmes pleines = pierres dispo, gemmes ternes = max restant. Réutiliser `res_crystal.png`.

- [ ] **Step 2: Remplir dans `_refresh_panels` (renommé `_refresh_sides`)**
  Mettre à jour les pips depuis `state.players[i].stones` / max. Total exact en `tooltip_text` au survol.

- [ ] **Step 3: Vérifier** capture : pips corrects en bas-droite (toi) et haut-droite (adv.), survol affiche le total.

- [ ] **Step 4: Commit** `feat(battle): pierres en pips de gemmes par joueur`

---

### Task 4: Deck par joueur + animation de pioche

**Files:** `scenes/battle.tscn`, `scripts/ui/battle_scene.gd`, `scripts/ui/battle_fx.gd`

- [ ] **Step 1: Placer les decks**
  `PlayerDeck` (pile de dos `card_back.png`, bas-droite près des pips) et `EnemyDeck` (haut-droite). Afficher le nombre de cartes restantes en petit.

- [ ] **Step 2: Animation de pioche**
  Dans `battle_fx.gd` (ou `_play_events` sur l'événement de pioche), faire « jaillir » une carte depuis la position du deck vers la main (tween position + scale). Côté adversaire, vers `EnemyHandRow`.

- [ ] **Step 3: Vérifier** `--autoplay` : à chaque pioche, une carte part du deck vers la main, compteur décrémenté, sans erreur.

- [ ] **Step 4: Commit** `feat(battle): decks places + animation de pioche`

---

### Task 5: Mains — la tienne (faces) / l'adversaire (dos)

**Files:** `scenes/battle.tscn`, `scripts/ui/battle_scene.gd`

- [ ] **Step 1: Ta main en bas-centre**
  `HandArea` centré en bas ; `_refresh_hand` inchangé (cartes via `CardWidget.create`), juste repositionné.

- [ ] **Step 2: Main adverse en dos, haut-centre**
  `EnemyHandRow` en haut-centre : afficher N dos de cartes (`card_back.png`) = `state.players[1].hand.size()`, jamais la face.

- [ ] **Step 3: Vérifier** capture : ta main lisible en bas, dos adverses en haut, nombres corrects.

- [ ] **Step 4: Commit** `feat(battle): mains repositionnees (faces joueur, dos adversaire)`

---

### Task 6: Fin du tour centre-droit + libellé de tour

**Files:** `scenes/battle.tscn`, `scripts/ui/battle_scene.gd`

- [ ] **Step 1: Placer `EndTurnBtn`** au centre-droit, grand et accessible. Placer `TurnLabel`/`TurnInfo` en petit près du bouton (tour courant, actions restantes).

- [ ] **Step 2: Vérifier** capture : bouton Fin du tour bien visible centre-droit ; libellé de tour lisible.

- [ ] **Step 3: Commit** `feat(battle): bouton Fin du tour centre-droit`

---

### Task 7: Panneau info carte/unité au clic gauche (bas-droite)

**Files:** `scenes/battle.tscn`, `scripts/ui/battle_scene.gd`

- [ ] **Step 1: Positionner `DetailHolder`** en bas-droite comme panneau info persistant (réutiliser `_show_detail_card`/`_show_detail_monster`/`_add_detail_text`/`_clear_detail` existants).

- [ ] **Step 2: Clic gauche → info**
  Sur clic gauche d'une carte de main (`_on_hand_card_pressed`) et d'une unité (`_on_cell_clicked`/`_on_cell_inspect`), remplir `DetailHolder`. Rester affiché jusqu'à désélection (`_clear_selection` → `_clear_detail`).

- [ ] **Step 3: Retirer la dépendance au clic droit**
  Le clic droit (`inspect_requested` → `CardPopup`) devient optionnel/secondaire (les cartes sont déjà lisibles). Ne pas casser `CardPopup` (utilisé ailleurs) ; juste ne plus l'exiger pour lire une carte en bataille.

- [ ] **Step 4: Vérifier** clic gauche sur carte puis sur unité → panneau bas-droite se remplit ; désélection le vide.

- [ ] **Step 5: Commit** `feat(battle): panneau info carte/unite au clic gauche`

---

### Task 8: Journal en barre d'icônes (gauche) + survol

**Files:** `scenes/battle.tscn`, `scripts/ui/battle_scene.gd`

- [ ] **Step 1: Convertir `LogPanel`** en fine colonne d'icônes à gauche : chaque action = une icône (⚔ attaque, ✦ sort, ❤ soin, ✚ invocation…) avec `tooltip_text` = le texte complet de l'action. ~5 dernières visibles.

- [ ] **Step 2: Adapter `_log(...)`** pour ajouter une icône (avec type déduit) au lieu d'une ligne de `RichTextLabel` ; garder le texte en tooltip.

- [ ] **Step 3: Vérifier** `--autoplay` : la colonne d'icônes se remplit, survol d'une icône montre le détail.

- [ ] **Step 4: Commit** `feat(battle): journal en icones avec survol`

---

### Task 9: Animation d'activation pouvoir/passif du Maître

**Files:** `scripts/ui/battle_fx.gd`, `scripts/ui/battle_scene.gd`

- [ ] **Step 1: Effet sur le jeton Maître**
  Quand un pouvoir/passif de Maître s'active (événement correspondant dans `_play_events`), jouer un halo/flash de la couleur de faction sur le jeton Maître (`GameConst.GUILD_COLORS`), via un tween dans `battle_fx.gd`.

- [ ] **Step 2: Vérifier** `--autoplay` : l'activation d'un pouvoir déclenche l'effet visuel sur le bon Maître.

- [ ] **Step 3: Commit** `feat(battle): animation d'activation pouvoir/passif Maitre`

---

### Task 10: Vérification finale

- [ ] **Step 1:** `GODOT --headless --path . -s res://tests/run_tests.gd` → tout vert (aucune régression cœur).
- [ ] **Step 2:** `battle.tscn` s'ouvre complètement dans l'éditeur (Règle n°1).
- [ ] **Step 3:** `--autoplay --screenshot` final comparé au layout cible : arène agrandie, HUD réduit aux bords, PV/pouvoir sur Maîtres, pips/deck/main par joueur, Fin du tour centre-droit, info-carte bas-droite, journal icônes.
- [ ] **Step 4:** `/graphify --update`.

## Self-review (couverture du spec)

Arène agrandie + panneaux retirés → T1 ✅ · PV/pouvoir sur Maître → T2, T9 ✅ · pierres pips → T3 ✅ · decks + pioche → T4 ✅ · mains faces/dos → T5 ✅ · Fin du tour → T6 ✅ · info-carte clic gauche, moins de clic droit → T7 ✅ · journal icônes → T8 ✅ · vérif → T10 ✅. Hors périmètre (police/filtre/card_widget) respecté.
