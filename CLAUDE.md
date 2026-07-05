# CLAUDE.md — CardeHeroClone (Godot 4)

Jeu de cartes tactique (clone Card Hero) en Godot 4 / GDScript. UI cible : les mockups dans `assets/mockup/` (style dark-fantasy peint, référence Hearthstone). Les mockups sont la source de vérité visuelle.

## Règle n°1 — L'UI vit dans les scènes, PAS dans les scripts

C'est la faute historique de ce projet (battle_scene.gd = 1319 lignes qui construisent l'UI en code). Ne jamais recommencer.

- **Toute la structure UI est déclarée dans le `.tscn`** : panneaux, labels, boutons, conteneurs, marges, ancres, textures. L'éditeur Godot doit pouvoir afficher la scène complète sans lancer le jeu.
- **Les textures sont des `ext_resource` dans la scène** (assignées dans l'inspecteur), jamais des `load("res://...")` dans `_ready()`.
- **Les scripts ne font que la logique** : réagir aux signaux, remplir des données dans des nœuds existants (`%NomDuNoeud`), instancier des `PackedScene` réutilisables.
- **Un widget répété = une scène** (`card_widget.tscn`, `board_cell.tscn`), instanciée via `preload(...).instantiate()`. Jamais de `Panel.new()` + 40 lignes de styleboxes en code.
- Seule exception : contenu dynamique par nature (une ligne de journal de combat, une carte dans la main). Même là, on instancie une scène-widget, on ne construit pas des nœuds à la main.

## Règle n°2 — Le style vit dans le Theme

- Un seul `resources/ui_theme.tres` porte styleboxes, polices, couleurs par défaut. Les variations par type de nœud utilisent les **theme type variations**, pas du code.
- `ui_theme.gd` ne doit pas générer de StyleBox/Texture au runtime. S'il faut un style, il va dans le `.tres` ou dans la scène.
- Couleurs de faction / raretés : constantes dans `game_const.gd`, appliquées via la scène ou une variation de thème.

## Règle n°3 — Assets

- Chemins stables : `assets/sprites/units/`, `assets/sprites/ui/`, `assets/portraits/`, `assets/backgrounds/`, `assets/audio/`.
- Nommage : `snake_case.png`, une planche découpée = fichiers individuels (pas de découpage de spritesheet au runtime).
- Import pixel-art : filtre désactivé si style pixel ; les mockups actuels sont peints (pas pixel) → filtre linéaire par défaut.
- Générer/découper les assets avec les outils de `tools/` ; noter la provenance dans `tools/asset_manifest.json`.

## Architecture (ne pas casser)

- `scripts/core/` : règles pures, zéro dépendance UI/Godot-scene (Board, Combat, Effects, Rules, GameState). Testable sans scène.
- `scripts/defs/` : définitions typées chargées depuis `resources/data/*.json` par l'autoload `Db`.
- `scripts/autoload/` : `Db` (données), `Game` (profil, sauvegarde, navigation `Game.goto`), `Audio`.
- `scripts/ui/` : contrôleurs de scène (logique seulement, cf. Règle n°1).
- Flux bataille : l'UI appelle `Rules.apply(...)` → reçoit une liste d'événements → les rejoue en animations (`battle_fx.gd`). Ne jamais muter l'état depuis l'UI.
- Données de jeu déclaratives dans `resources/data/` (cards.json, masters.json, campaign.json). Équilibrage = éditer le JSON, pas le code.

## Workflow

- **Mémoire projet** : graphe de connaissance dans `graphify-out/` (`graphify query "..."` pour interroger). Après tout changement structurel (nouveau fichier, refactor), relancer `/graphify --update`.
- **Ponytail** : solution la plus simple qui marche. Pas d'abstraction spéculative, réutiliser l'existant avant d'écrire du neuf.
- Vérifier dans l'éditeur/le jeu avant de déclarer terminé : `godot --path .` (ou ouvrir la scène dans l'éditeur).
- Tests : `tests/` ; le core pur doit rester testable headless.

## Pièges connus

- Windows : écrire les fichiers en UTF-8 explicite (PowerShell 5.1 écrit UTF-16 par défaut).
- Les `.png.import` sont générés par Godot : les committer avec leur PNG.
- Texte du jeu en français (UI, cartes, dialogues).
