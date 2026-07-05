# Fondations UI pixel art — Plan d'implémentation (Lot 1a)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Poser le socle pixel art (nettoyage, couleurs, police, thème, import Nearest, pipeline ChatGPT vérifié) et le prouver de bout en bout avec une carte pixel qui s'affiche via un `card_widget.tscn` déclaratif.

**Architecture:** Style dans `ui_theme.tres` + couleurs dans `game_const` (source unique) ; UI dans les scènes ; assets pixel dessinés directement via ChatGPT (navigateur Playwright), importés en filtre Nearest ; aucune conversion peint→pixel. Le widget carte devient une scène réutilisable, tuant la construction en code de `card_widget.gd`.

**Tech Stack:** Godot 4.6 (projet), exécutable Godot 4.5.1 mono console pour le headless, GDScript, Playwright MCP (onglet ChatGPT Pro déjà dispo).

## Global Constraints

- **UI dans les scènes** (Règle n°1) : structure en `.tscn`, textures en `ext_resource`, scripts = logique seule. La scène doit s'afficher dans l'éditeur sans lancer le jeu.
- **Style dans le thème** (Règle n°2) : styleboxes/variations dans `resources/ui_theme.tres`. `ui_theme.gd` ne génère aucun StyleBox/Texture au runtime pour le nouveau code.
- **Chemins d'assets stables** (Règle n°3) : `assets/sprites/units/`, `assets/sprites/ui/pixel/`, `assets/portraits/`, `assets/sprites/cards/`. Nommage `snake_case.png`.
- **Pixel art** : filtre d'import **Nearest**, mipmaps off. Résolution native fine : cartes ~80×112, unités 48×64, icônes 32×32, panneaux 9-slice. Affichage à l'échelle entière.
- **Windows** : écrire les fichiers en **UTF-8 explicite**. Committer chaque `.png` avec son `.png.import`.
- **Texte du jeu en français.**
- **Exécutable Godot** : `C:/Users/rgagu/Downloads/Godot_v4.5.1-stable_mono_win64/Godot_v4.5.1-stable_mono_win64/Godot_v4.5.1-stable_mono_win64_console.exe` (référencé ci-après comme `GODOT`). Vérifier son existence avant la première commande ; sinon demander le chemin à l'utilisateur.
- **Tests** : framework maison. Un test étend `TestCase` (`tests/test_case.gd`), méthodes `test_*`, lancé par `GODOT --headless --path . -s res://tests/run_tests.gd`.

---

### Task 1: Vérifier l'accès ChatGPT (navigateur) — garde-fou pipeline

Aucun asset ne doit être planifié en série tant que la génération pixel n'est pas prouvée exploitable.

**Files:** aucun (vérification interactive).

- [ ] **Step 1: Confirmer l'exécutable Godot**

Run: `ls "C:/Users/rgagu/Downloads/Godot_v4.5.1-stable_mono_win64/Godot_v4.5.1-stable_mono_win64/Godot_v4.5.1-stable_mono_win64_console.exe"`
Expected: le fichier existe. Sinon, demander le chemin à l'utilisateur avant de continuer.

- [ ] **Step 2: Ouvrir ChatGPT dans le navigateur**

Utiliser l'outil Playwright : `browser_navigate` vers `https://chatgpt.com`.
Puis `browser_snapshot`.
Expected: la page de chat s'affiche connectée (pas d'écran de login). Si écran de login → **STOP** : signaler à l'utilisateur « connecte-toi à ChatGPT dans ce navigateur puis relance », ne pas tenter d'OAuth.

- [ ] **Step 3: Générer un asset test et valider visuellement**

Prompt (via l'UI ChatGPT, en montrant une image de référence de créature du jeu, ex. `assets/sprites/cards/forest_wolf.png`) :
> « Redessine ce loup en **pixel art authentique**, résolution native ~48×64 pixels, palette limitée (≤16 couleurs), **aucun anti-aliasing**, contours nets, fond **transparent**. Style dark-fantasy. Sortie PNG. »

Télécharger le PNG, l'ouvrir. **Gate de validation** :
- Si c'est du vrai pixel (blocs nets, pas de flou/AA, palette réduite) → OK, continuer le plan.
- Si c'est du « faux pixel » (haute résolution floue, AA, grille irrégulière) → **STOP** et remonter à l'utilisateur : le pipeline « dessin direct pixel via ChatGPT » ne tient pas, il faut rediscuter (downscale manuel ? autre outil ?). Ne pas générer d'autres assets.

- [ ] **Step 4: Commit (uniquement si un asset validé a été produit)**

Placer l'asset validé dans `assets/sprites/units/forest_wolf.png` (chemin cible pixel), régler son `.import` (voir Task 5 pour le preset Nearest), puis :
```bash
git add assets/sprites/units/forest_wolf.png assets/sprites/units/forest_wolf.png.import
git commit -m "feat(assets): 1er sprite unite pixel valide (garde-fou pipeline)"
```

---

### Task 2: Nettoyage — supprimer les outils de conversion peint→pixel

**Files:**
- Delete: `tools/pixelize.py`, `tools/gen_pixel_assets.py`, `tools/compose_battle_bg.py`, `tools/generate_ui_assets.py`
- Modify: `tools/asset_manifest.json`

**Interfaces:**
- Produces: rien de consommé par du code — outils offline uniquement.

- [ ] **Step 1: Vérifier qu'aucun code vivant n'en dépend**

Run (Grep): chercher `pixelize`, `gen_pixel_assets`, `compose_battle_bg`, `generate_ui_assets` dans `scripts/`, `scenes/`, `resources/`, et dans les autres fichiers de `tools/`.
Expected: aucune référence depuis le code du jeu. (Ce sont des scripts Python offline.) Si un autre tool encore utile les importe, l'archiver au lieu de le supprimer.

- [ ] **Step 2: Supprimer les fichiers**

```bash
git rm tools/pixelize.py tools/gen_pixel_assets.py tools/compose_battle_bg.py tools/generate_ui_assets.py
```

- [ ] **Step 3: Noter l'abandon de la conversion dans le manifest**

Ajouter dans `tools/asset_manifest.json` une note (champ `"note"` au niveau racine, ou entrée dédiée) : `"pipeline": "pixel art dessine directement via ChatGPT (navigateur) ; conversion peint->pixel abandonnee 2026-07-05"`. Écrire le fichier en UTF-8.

- [ ] **Step 4: Vérifier que le projet charge toujours**

Run: `GODOT --headless --path . --import`
Expected: import sans erreur (pas de dépendance cassée).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore(tools): supprime la conversion peint->pixel (pixelize & co)"
```

---

### Task 3: Couleurs de guilde dans `game_const` (source unique) + test

Déplace la palette de faction vers le core pur et fait déléguer `UiTheme` dessus, sans casser `board_cell.gd`/`deck_builder.gd`.

**Files:**
- Modify: `scripts/core/game_const.gd`
- Modify: `scripts/ui/ui_theme.gd:15-20` (GUILD_COLORS)
- Test: `tests/unit/test_const.gd` (create)

**Interfaces:**
- Produces:
  - `GameConst.GUILD_COLORS: Dictionary` — clé `GameConst.Guild.*` → `Color`.
  - `UiTheme.GUILD_COLORS` reste défini (délègue à `GameConst.GUILD_COLORS`), `UiTheme.guild_color(guild:int)->Color` inchangé pour les consommateurs existants.

- [ ] **Step 1: Écrire le test qui échoue**

Créer `tests/unit/test_const.gd` (UTF-8) :
```gdscript
extends TestCase
## Palette de guilde : source unique dans GameConst.

func test_guild_colors_present_for_every_guild() -> void:
	for g in [GameConst.Guild.FLAME, GameConst.Guild.SYLVAN,
			GameConst.Guild.SHADOW, GameConst.Guild.LIGHT]:
		ok(GameConst.GUILD_COLORS.has(g), "couleur manquante pour guilde %d" % g)

func test_uitheme_delegates_to_gameconst() -> void:
	eq(UiTheme.guild_color(GameConst.Guild.FLAME),
			GameConst.GUILD_COLORS[GameConst.Guild.FLAME],
			"UiTheme.guild_color doit refleter GameConst")
```

- [ ] **Step 2: Lancer le test pour le voir échouer**

Run: `GODOT --headless --path . -s res://tests/run_tests.gd`
Expected: `FAIL test_const.gd :: test_guild_colors_present_for_every_guild` (GameConst.GUILD_COLORS n'existe pas encore → erreur de compilation du test).

- [ ] **Step 3: Ajouter la palette à `game_const.gd`**

Ajouter à la fin de `scripts/core/game_const.gd` (après `GUILD_NAMES`) :
```gdscript
## Couleurs de faction — source unique de vérité (UI délègue ici).
const GUILD_COLORS := {
	Guild.FLAME: Color("e2603c"),
	Guild.SYLVAN: Color("5aa864"),
	Guild.SHADOW: Color("8b6bc7"),
	Guild.LIGHT: Color("e6c35a"),
}
```

- [ ] **Step 4: Faire déléguer `UiTheme`**

Dans `scripts/ui/ui_theme.gd`, remplacer le bloc `const GUILD_COLORS := { ... }` (lignes 15-20) par :
```gdscript
# Palette de faction : source unique dans GameConst (Règle des couleurs).
const GUILD_COLORS := GameConst.GUILD_COLORS
```
Laisser `guild_color()` (ligne 127-128) inchangé — il lit `GUILD_COLORS`.

- [ ] **Step 5: Lancer les tests (nouveau + non-régression)**

Run: `GODOT --headless --path . -s res://tests/run_tests.gd`
Expected: `ok test_const.gd :: ...` (les 2) et les ~40 tests existants toujours au vert.

- [ ] **Step 6: Commit**

```bash
git add scripts/core/game_const.gd scripts/ui/ui_theme.gd tests/unit/test_const.gd
git commit -m "refactor(const): palette de guilde source unique dans GameConst"
```

---

### Task 4: Police pixel avec accents FR, câblée dans le thème

**Files:**
- Create: `assets/fonts/PixelOperator.ttf` (+ `.import` généré)
- Modify: `resources/ui_theme.tres` (default_font)

**Interfaces:**
- Produces: `resources/ui_theme.tres` avec `default_font` = police pixel. Consommé par toutes les scènes utilisant le thème.

- [ ] **Step 1: Obtenir une police pixel libre couvrant le français**

Placer dans `assets/fonts/PixelOperator.ttf` une police pixel bitmap-style **avec Latin-1** (accents `é è à ç ù î ô ê`). Recommandé : **Pixel Operator** (domaine public, par Jayvee Enaguas) — couvre les accents. Si l'utilisateur préfère une autre police pixel, l'y déposer sous le même nom.
Vérifier la présence : `ls assets/fonts/PixelOperator.ttf`.

- [ ] **Step 2: Importer et régler le rendu net**

Run: `GODOT --headless --path . --import`
Puis, dans `assets/fonts/PixelOperator.ttf.import`, s'assurer que l'antialiasing est désactivé pour un rendu pixel net : `antialiasing=0` et `hinting=0` (section `[params]`). Réimporter si modifié.

- [ ] **Step 3: Câbler la police par défaut du thème**

Dans `resources/ui_theme.tres` : ajouter un `ext_resource type="FontFile" path="res://assets/fonts/PixelOperator.ttf"` et pointer `default_font` dessus. Ajuster `default_font_size` à une taille lisible pour cette police (ex. 16). Ne pas toucher aux couleurs existantes.

- [ ] **Step 4: Vérifier le rendu des accents**

Run: `GODOT --path . res://scenes/main_menu.tscn --resolution 1920x1080 -- --screenshot=%TEMP%/font_check.png`
Ouvrir le screenshot. Expected: le texte du menu s'affiche en police pixel, accents FR corrects (é, è, à, ç lisibles, pas de carrés `□`).
Si des accents manquent → changer de police pixel (retour Step 1).

- [ ] **Step 5: Commit**

```bash
git add assets/fonts/PixelOperator.ttf assets/fonts/PixelOperator.ttf.import resources/ui_theme.tres
git commit -m "feat(ui): police pixel (accents FR) par defaut dans le theme"
```

---

### Task 5: Preset d'import Nearest pour le pixel art + styleboxes pixel dans le thème

Câble le style « panneaux/boutons pixel » dans `ui_theme.tres` (via *theme type variations*), pour que les scènes s'y réfèrent sans passer par les helpers runtime de `ui_theme.gd`.

**Files:**
- Modify: `resources/ui_theme.tres`
- Modify: `.png.import` des assets de `assets/sprites/ui/pixel/` utilisés (filtre Nearest)

**Interfaces:**
- Produces: variations de thème `PanelPixel` (type `PanelContainer`) et `ButtonPixel` (type `Button`) dans `ui_theme.tres`, utilisables via la propriété `theme_type_variation` d'un nœud dans une scène.

- [ ] **Step 1: Forcer le filtre Nearest sur les assets pixel utilisés**

Pour chaque asset pixel employé par le thème/slice (`panel_stone.png`, `btn_primary.png`, `btn_secondary.png`, `btn_disabled.png`, `frame_flame.png`, `gem_cost_*.png`, `icon_stat_attack.png`, `res_heart.png`), ouvrir son `.png.import` et régler `[params]` : `filter=false` (Godot 4 : `filter` false = Nearest) — ou définir `default_texture_filter` du nœud à `TEXTURE_FILTER_NEAREST` dans la scène. Réimporter :
Run: `GODOT --headless --path . --import`
Expected: import OK.

- [ ] **Step 2: Ajouter la variation `PanelPixel` au thème**

Dans `resources/ui_theme.tres` : ajouter un `StyleBoxTexture` 9-slice basé sur `res://assets/sprites/ui/pixel/panel_stone.png` (marges `texture_margin_*` ≈ 6 % de la largeur, `content_margin_*` ≈ 14/18) enregistré sous le type de variation `PanelPixel/styles/panel`.

- [ ] **Step 3: Ajouter la variation `ButtonPixel` au thème**

Toujours dans `ui_theme.tres` : `StyleBoxTexture` sur `btn_primary.png` pour `ButtonPixel/styles/normal`, une variante teintée claire pour `hover`, teintée sombre pour `pressed`, et `btn_disabled.png` pour `disabled`. `focus` = `StyleBoxEmpty`.

- [ ] **Step 4: Vérifier dans l'éditeur**

Ouvrir `resources/ui_theme.tres` dans l'éditeur Godot (ou charger une scène de test). Expected: les variations `PanelPixel` et `ButtonPixel` existent et rendent net (pas de flou).
Smoke headless : `GODOT --headless --path . --import` sans erreur.

- [ ] **Step 5: Commit**

```bash
git add resources/ui_theme.tres assets/sprites/ui/pixel/*.import
git commit -m "feat(ui): filtre Nearest + variations PanelPixel/ButtonPixel dans le theme"
```

---

### Task 6: `card_widget.tscn` déclaratif (tue la construction en code)

Convertit le format « mini main » de `card_widget.gd` en scène réutilisable. La logique (remplir les données, survol, clic) reste en script ; la structure passe en `.tscn`.

**Files:**
- Create: `scenes/widgets/card_widget.tscn`
- Rewrite: `scripts/ui/card_widget.gd`
- Test: `tests/unit/test_card_widget.gd` (create)

**Interfaces:**
- Consumes: `CardDef` (via `Db`), variations de thème de Task 5, assets pixel (`frame_*`, `gem_cost_*`, art de carte).
- Produces:
  - `scenes/widgets/card_widget.tscn` avec `%Cost`, `%Name`, `%Art`, `%Atk`, `%Hp`, `%Keywords`, `%Frame`, `%Count` (nœuds nommés unique).
  - `CardWidget` (script racine) : `func setup(def: CardDef) -> void`, `func set_selected(on: bool) -> void`, `func set_count(n: int) -> void`, signals `pressed(widget)`, `inspect_requested(widget)`.
  - Fabrique de compat : `static func spawn(def: CardDef) -> CardWidget` (preload + instantiate + setup) pour remplacer les anciens `CardWidget.create*`.

- [ ] **Step 1: Écrire le test qui échoue**

Créer `tests/unit/test_card_widget.gd` (UTF-8) :
```gdscript
extends TestCase
## card_widget.tscn s'instancie et se remplit sans erreur.

func test_spawn_fills_named_nodes() -> void:
	var scene: PackedScene = load("res://scenes/widgets/card_widget.tscn")
	ok(scene != null, "card_widget.tscn introuvable")
	var db = Engine.get_main_loop().root.get_node_or_null("Db")
	ok(db != null, "autoload Db absent")
	var def = db.card(db.all_card_ids()[0]) if db != null else null
	ok(def != null, "aucune carte en base")
	var w = scene.instantiate()
	w.setup(def)
	eq(w.get_node("%Name").text, def.display_name, "nom rempli")
	w.free()
```
(Si `Db.all_card_ids()` n'existe pas, utiliser l'API réelle de `Db` pour récupérer un id — vérifier `scripts/autoload/db.gd` et adapter l'appel.)

- [ ] **Step 2: Lancer pour voir échouer**

Run: `GODOT --headless --path . -s res://tests/run_tests.gd`
Expected: `FAIL test_card_widget.gd :: test_spawn_fills_named_nodes` (scène absente).

- [ ] **Step 3: Créer `scenes/widgets/card_widget.tscn`**

Racine `PanelContainer` (script `card_widget.gd`, `theme_type_variation` non requis — le cadre porte l'image). Structure (tout en nœuds nommés, `unique_name_in_owner=true`) :
- `%Frame` `TextureRect` (cadre faction, `EXPAND_IGNORE_SIZE`)
- `VBox` :
  - `HBox` haut : `%Cost` `TextureRect` (gemme), `%Name` `Label`
  - `%Art` `TextureRect` (`STRETCH_KEEP_ASPECT_COVERED`)
  - `HBox` bas : `%Atk` `Label`, `%Hp` `Label`, `%Keywords` `Label`
- `%Count` `Label` (overlay bas-droite, `visible=false`)

Textures pixel en `ext_resource`. Filtre Nearest. La scène doit s'afficher dans l'éditeur.

- [ ] **Step 4: Réécrire `card_widget.gd` en logique seule**

Remplacer tout le contenu de `scripts/ui/card_widget.gd` par un script qui : garde `class_name CardWidget`, les signaux `pressed`/`inspect_requested`, expose `setup(def)` (remplit `%Cost` via `gem_cost_%d.png`, `%Frame` selon `def.guild`, `%Art` via `def.art`, `%Name`, `%Atk`/`%Hp` depuis `def.levels[0]` si monstre sinon masque la ligne stats et affiche l'effet, `%Keywords` via `GameText.keywords_line`), `set_selected`, `set_count`, `_gui_input` (clic gauche → `pressed`, droit → `inspect_requested`), et `static func spawn(def) -> CardWidget`. Aucune création de StyleBox en code.

- [ ] **Step 5: Lancer le test (vert) + non-régression**

Run: `GODOT --headless --path . -s res://tests/run_tests.gd`
Expected: `ok test_card_widget.gd :: test_spawn_fills_named_nodes` et suite existante au vert.
⚠️ Ce Step casse temporairement les appelants de `CardWidget.create*` (battle_scene, deck_builder…). Voir Step 6.

- [ ] **Step 6: Rétablir les appelants existants a minima**

Remplacer chaque `CardWidget.create(def, w)` / `CardWidget.create_mini(def, w)` dans `scripts/ui/battle_scene.gd`, `scripts/ui/deck_builder.gd` (et autres résultats du grep `CardWidget.create`) par `CardWidget.spawn(def)`. Le dimensionnement précis (largeurs) sera repris dans le plan Bataille ; ici on veut juste que ça compile et s'affiche.
Run: `GODOT --headless --path . --import` puis `-s res://tests/run_tests.gd`.
Expected: compile, tests au vert.

- [ ] **Step 7: Vérifier visuellement une carte**

Run: `GODOT --path . res://scenes/deck_builder.tscn --resolution 1920x1080 -- --screenshot=%TEMP%/card_check.png`
Ouvrir le screenshot. Expected: les cartes s'affichent en pixel net (cadre, gemme de coût, art, nom, stats) sans chevauchement.

- [ ] **Step 8: Commit**

```bash
git add scenes/widgets/card_widget.tscn scripts/ui/card_widget.gd tests/unit/test_card_widget.gd scripts/ui/battle_scene.gd scripts/ui/deck_builder.gd
git commit -m "refactor(ui): card_widget en scene declarative (tue la construction en code)"
```

---

### Task 7: Vérification finale du lot fondations

**Files:** aucun (vérification).

- [ ] **Step 1: Tests headless complets**

Run: `GODOT --headless --path . -s res://tests/run_tests.gd`
Expected: 100 % au vert (les ~40 existants + `test_const` + `test_card_widget`), sortie code 0.

- [ ] **Step 2: Règle n°1 — scènes ouvrables dans l'éditeur**

Ouvrir `scenes/widgets/card_widget.tscn` dans l'éditeur Godot. Expected: s'affiche complètement sans lancer le jeu.

- [ ] **Step 3: Capture de contrôle**

Run: `GODOT --path . res://scenes/deck_builder.tscn --resolution 1920x1080 -- --screenshot=%TEMP%/foundations_check.png`
Expected: cartes pixel nettes, police pixel avec accents corrects.

- [ ] **Step 4: Mémoire / graphe (workflow projet)**

Relancer `/graphify --update` (changement structurel : nouveau widget, thème modifié). Mettre à jour la mémoire `godot-verify-workflow` si l'exe a changé.

---

## Self-review (couverture du spec)

- Pipeline ChatGPT + garde-fou 1er asset → Task 1. ✅
- Suppression `pixelize.py` + tools de conversion → Task 2. ✅
- Couleurs faction dans `game_const` (source unique) → Task 3. ✅ (Rareté : **retirée** — absente du modèle de données, YAGNI.)
- Police pixel + thème → Task 4. ✅
- Import Nearest + styleboxes pixel dans le thème → Task 5. ✅
- `card_widget.tscn` déclaratif (tue la dette code) → Task 6. ✅
- Vérification (Règle n°1, headless, screenshot) → Task 7. ✅

## Hors de ce plan (→ Plan 2 : Bataille)

Génération en série des assets pixel (UI kit complet, arts de cartes, unités, portraits) ; reconstruction déclarative de `scenes/battle.tscn` ; réduction de `battle_scene.gd` à un contrôleur mince ; `unit_token.tscn`. Ces tâches consomment les fondations ci-dessus et seront planifiées une fois le socle validé.
