# Refonte UI mobile dédiée — Stonebound

**Date** : 2026-07-12
**Statut** : approuvé (conception), implémentation en cours

## Problème

Le jeu est dessiné en **1920×1080 (16:9)** avec des fonds peints plein écran (menu = ville, combat = arène). Les téléphones cibles sont plus allongés (ex. **2400×1080, 20:9, 450 dpi**). Résultats des approches rejetées :

- `stretch/aspect="expand"` (état initial) : le contenu conçu pour 1920 reste collé à gauche, grosse bande vide à droite, fonds potentiellement étirés.
- `stretch/aspect="keep"` (rustine) : bandes noires (pillarbox). **Rejeté** — pas propre.

L'utilisateur veut une **refonte mobile dédiée** : layouts séparés PC/mobile par écran, remplissant l'écran, cibles tactiles correctes, sans hack ni positions px fixes.

## Principe d'architecture

**Layouts mobiles dédiés, logique partagée.** Chaque écran a une scène `<name>_mobile.tscn` avec sa propre disposition tactile qui **attache le même script** et expose les **mêmes `%NomsUniques`** que la version desktop. Aucune logique dupliquée. Respecte la Règle n°1 du projet (structure dans les `.tscn`, logique dans les scripts) et la Règle n°2 (style dans le thème).

## Composants

### 1. Mécanisme (fondation, posé une fois)

- **`Game.goto(name)`** : si `OS.has_feature("mobile")` **et** `res://scenes/<name>_mobile.tscn` existe → charge la variante mobile ; sinon la scène desktop existante. Un seul point de navigation. Desktop totalement inchangé.
- **Thème tactile** : `resources/ui_theme_mobile.tres`, basé sur `ui_theme.tres`, polices agrandies + `custom_minimum_size` des boutons relevés pour le doigt à 450 dpi. Appliqué par les scènes `_mobile.tscn`.
- **Fonds cover** : les `TextureRect` de fond passent en `expand_mode = IGNORE_SIZE` + `stretch_mode = KEEP_ASPECT_COVERED` → remplissent tout l'écran, sans déformation ni bande noire, sur n'importe quel ratio.
- **Retrait du hack** : `window/stretch/aspect` repasse de `keep` à `expand` (le canvas prend le vrai ratio écran ; les scènes mobiles ancrent leur UI aux vrais bords).

### 2. Écrans

| Écran | Scène mobile | Disposition mobile |
|---|---|---|
| **Menu** | `main_menu_mobile.tscn` | Fond cover ; boutons plus gros ancrés en colonne accessible au pouce ; bouton COMBATTRE proéminent. |
| **Deck builder** | `deck_builder_mobile.tscn` | **Onglets une colonne** (Collection / Maître / Deck) au lieu des 3 colonnes serrées ; grille de cartes plus grosses ; navigation par onglets tactile. |
| **Popups** (mode_select, matchmaking, inspecteur carte) | au cas par cas | Agrandissement tactile ; scène mobile seulement si la disposition change réellement, sinon thème tactile suffit. |
| **Combat** | `battle_mobile.tscn` | `arena.gd::cell_rect()` est **déjà paramétrique** (`board_pos`, `board_scale`, `grid_*` exportés) → l'arène est mise à l'échelle pour remplir l'écran mobile, `board_pos`/`board_scale` ajustés, et **les cellules suivent**. HUD (fin de tour, actions restantes), panneaux maîtres et main de cartes **ancrés aux vrais bords** et agrandis. Les `RowMarker*` (offsets fixes décoratifs) repositionnés ou dérivés de `cell_rect()`. |

### 3. Points d'appui existants (à réutiliser, ne pas réinventer)

- `arena.gd::cell_rect(cell)` : calcul pur de la géométrie, paramétré. Le combat mobile ajuste les exports de l'arène, pas le code du plateau.
- `card_widget.gd` / `board_cell.gd` : appui long tactile = inspecter (déjà en place).
- `project.godot` : orientation `landscape`, `emulate_mouse_from_touch=true` (déjà en place).

## Séquencement d'implémentation

1. **Fondation** : `Game.goto` variante mobile + `ui_theme_mobile.tres` + fonds cover + retrait `keep`.
2. **Menu** (`main_menu_mobile.tscn`) → valider la fondation sur l'appareil réel.
3. **Deck builder** (`deck_builder_mobile.tscn`, onglets).
4. **Popups**.
5. **Combat** (`battle_mobile.tscn`) — le plus gros morceau, éventuellement son propre plan détaillé.

Chaque étape est validée par une capture d'écran sur l'appareil (`adb exec-out screencap`) avant de passer à la suivante.

## Hors périmètre (YAGNI)

- Pas de duplication de logique (les scripts restent partagés).
- Pas de scène mobile pour un écran dont seul le dimensionnement change (thème tactile suffit).
- Pas de support portrait (le jeu est verrouillé paysage).
- Pas de refonte desktop (les scènes existantes restent la référence PC).

## Vérification

- Build APK via CLI (fondation Android déjà configurée : SDK, JDK, keystore, ETC2, `.gdignore` sur `android/build/`).
- `adb install -r` + `adb exec-out screencap -p` pour comparer chaque écran sur le vrai téléphone (R5CT344YM3V, 2400×1080, 450 dpi).
- Desktop non régressé : les scènes `.tscn` existantes ne sont pas touchées (sauf fonds cover, neutre en 16:9).
