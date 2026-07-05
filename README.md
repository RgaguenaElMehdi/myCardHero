# Stonebound

Un jeu de cartes tactique sur plateau inspiré de *Trade & Battle: Card Hero* (GBC, 2000), développé avec Godot 4.6. Campagne scénarisée en 10 chapitres, 32 cartes + 8 évolutions, 4 Maîtres jouables, deck builder, IA à 3 niveaux — tous les graphismes générés par Gemini, tout l'audio synthétisé procéduralement.

- **Design** : [docs/superpowers/specs/2026-07-04-stonebound-design.md](docs/superpowers/specs/2026-07-04-stonebound-design.md)
- **Lancer le jeu** : ouvrir le projet dans Godot 4.6+ et lancer, ou `godot --path .`
- **Tests** (40) : `godot --headless --path . -s res://tests/run_tests.gd`
- **Smoke test UI** : `godot --headless --path . res://scenes/battle.tscn -- --autoplay`
- **Régénérer les assets** : `python tools/generate_assets.py` (illustrations, nécessite `GEMINI_API_KEY` dans `.env`), `python tools/build_cards.py` (cartes complètes composées — à relancer après tout changement d'équilibrage dans `cards.json`) et `python tools/gen_sfx.py` (audio). Le chrome UI passe désormais en pixel art dessiné directement (voir `tools/asset_manifest.json`) ; la conversion peint→pixel (`pixelize.py` & co) a été retirée.

## Comment jouer

- **But** : réduire à 0 les PV du Maître adverse (lui-même posé sur le plateau).
- Chaque tour : +2 pierres, pioche 1. Les pierres paient invocations, sorts, pouvoirs et évolutions.
- **Clic sur une carte** de la main → cases d'invocation (or) ou cibles de sort (rouge).
- **Clic sur un monstre** → déplacements (bleu) et attaques (rouge). Un monstre agit une fois par tour.
- **Clic sur votre Maître** → déplacement le long de la rangée arrière. Son pouvoir a un bouton dédié.
- Les monstres gagnent de l'XP en combattant, montent de niveau (soin complet) et certains **évoluent** (bouton doré sur le monstre sélectionné).
- Mêlée : frappe le premier monstre non-volant de sa colonne. Distance/Magie : n'importe quelle cible ; la Magie ignore Armure et Bouclier. Un Maître n'est attaquable que si sa colonne est exposée.
- Deck de **25 cartes** (max 2 exemplaires). Deck vide : chaque pioche manquée inflige une **fatigue croissante** au Maître (1, 2, 3…).
- **Clic droit sur une carte ou un Maître** : inspection en grand. Clic droit dans le vide / Échap : annuler la sélection. **F11** : plein écran.

## Structure

```
scenes/      Scènes Godot (menus, bataille, deck builder, campagne)
scripts/     GDScript — core/ (règles pures), ai/, ui/, defs/ (Resources), autoload/
resources/   Données de jeu (.tres) : cartes, maîtres, chapitres
assets/      Sprites, portraits, fonds, polices, audio (générés — jamais dans le code)
tests/       Tests unitaires et d'intégration headless
tools/       Pipeline de génération d'assets (Gemini) et de SFX
```
