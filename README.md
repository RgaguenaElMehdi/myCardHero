# Stonebound

Un jeu de cartes tactique sur plateau inspiré de *Trade & Battle: Card Hero* (GBC, 2000), développé avec Godot 4.6.

- **Design** : [docs/superpowers/specs/2026-07-04-stonebound-design.md](docs/superpowers/specs/2026-07-04-stonebound-design.md)
- **Lancer le jeu** : ouvrir le projet dans Godot 4.6+ et lancer, ou `godot --path . `
- **Tests** : `godot --headless --path . -s res://tests/run_tests.gd`
- **Générer les assets** : `python tools/generate_assets.py` (nécessite `GEMINI_API_KEY` dans `.env`)

## Structure

```
scenes/      Scènes Godot (menus, bataille, deck builder, campagne)
scripts/     GDScript — core/ (règles pures), ai/, ui/, defs/ (Resources), autoload/
resources/   Données de jeu (.tres) : cartes, maîtres, chapitres
assets/      Sprites, portraits, fonds, polices, audio (générés — jamais dans le code)
tests/       Tests unitaires et d'intégration headless
tools/       Pipeline de génération d'assets (Gemini) et de SFX
```
