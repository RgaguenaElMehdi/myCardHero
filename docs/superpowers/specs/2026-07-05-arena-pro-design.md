# Spec — Arène pro, animée, skinnable (2026-07-05)

## Objectif

Écran de bataille au niveau du mockup `assets/mockup/game exemple.png` : zéro chevauchement, décor vivant, architecture prête pour des thèmes d'arène futurs.

## Architecture

**Un thème d'arène = une scène Godot.** `scenes/arenas/arena_dungeon.tscn` (thème actuel), toutes les arènes portent `scripts/ui/arena.gd` :

- `cell_rect(row, col) -> Rect2` — la géométrie de grille vit dans l'arène (exports : y des séparateurs de rangées, bords gauche/droit du trapèze), plus de constantes `GRID_*` dans `battle_scene.gd`.
- Signaux `cell_hovered(row, col)` / `cell_clicked(row, col)`.
- Structure : `Environment` (décor flouté) → `BoardPlate` (plateau peint) → `Props/` (bannières + shader vent, torches = GPUParticles2D flamme + PointLight2D vacillante) → `Ambience/` (braises, poussière lumineuse) → `Grid/` (board_cell réactives).

Nouveau skin = dupliquer la scène, échanger textures, déplacer props dans l'éditeur, ajuster la géométrie exportée. Choix du thème = chemin de scène (plus tard par chapitre dans `campaign.json`).

## Animations — Godot natif

Flammes, braises, lumière, poussière : **GPUParticles2D + PointLight2D + shaders**, jamais de spritesheets IA (frames incohérentes). Bannière : shader de vent sur sprite. Recoloration par thème via exports.

## Assets — génération via Playwright + ChatGPT Pro

ChatGPT Pro (piloté au navigateur via Playwright MCP) génère uniquement les **couches statiques** : décor d'environnement, plateau, props, éléments d'UI (cadres de panneaux, boutons, bannières). Provenance notée dans `tools/asset_manifest.json`. Import + découpe via `tools/`.

## Corrections de chevauchement

- Z-order : décor < unités < panneaux latéraux < main < popups (aujourd'hui les unités passent au-dessus des panneaux).
- Unités mises à l'échelle pour tenir dans ~90 % de leur cellule.
- Bande réservée à la main en bas : la rangée 0 n'est plus recouverte.
- Panneau « Sève » intégré au panneau joueur.

## Cases réactives

`board_cell.tscn` : survol (bordure illuminée, tween), jouable (pulsation dorée douce), sélectionnée (pulse marqué). États dans la scène du widget, tweens dans son script.

## Étapes

1. Extraction `arena_dungeon.tscn` + géométrie déplacée dans `arena.gd` (iso-visuel).
2. Layout/z-order/tailles — fin des chevauchements. Assets UI manquants générés via ChatGPT.
3. Ambiance animée (torches, braises, lumière, bannière, poussière).
4. Cases réactives.

## Vérification

`--screenshot` avant/après chaque étape, smoke `--autoplay`, 40 tests headless verts (le core n'est pas touché).
