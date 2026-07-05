# Refonte UI — Lot 1 : Fondations + Écran de bataille (pixel art)

Date : 2026-07-05
Branche : `pixel-art`
Statut : design validé, en attente de plan d'implémentation

## Contexte

Refonte complète de l'UI du jeu en **vrai pixel art**, plus propre et plus pro.
Le projet couvre 7+ écrans (menu, sélection de héros, deck builder, collection,
paramètres, profil, **bataille**) + sprites de jeu — trop gros pour un seul spec.
Il est **découpé en sous-projets**, chacun avec son propre cycle spec → plan →
implémentation. Ce document couvre **le premier lot : les fondations
transversales + l'écran de bataille** (le cœur du jeu et la principale dette).

Les lots suivants (menu, héros, deck builder, collection, paramètres, profil)
réutiliseront les fondations posées ici et feront l'objet de specs séparés.

## Décisions arrêtées

- **Style : vrai pixel art**, pas peint. Les mockups peints (`assets/mockup/`)
  et les assets actuels servent de **référence de layout et de contenu**, pas de
  style.
- **Assets dessinés directement en pixel art** via ChatGPT (navigateur), en
  redessinant la source. **Aucune conversion peint→pixel.**
- **`tools/pixelize.py` supprimé**, ainsi que les autres outils de
  génération/conversion devenus inutiles (`gen_pixel_assets.py`,
  `compose_battle_bg.py`, `generate_ui_assets.py`, et tout script dont l'unique
  rôle était la conversion). Vérifier avant suppression qu'aucun autre workflow
  vivant n'en dépend ; sinon les archiver plutôt que supprimer.
- **Résolution native fine** : cartes ~80×112, unités 48×64, icônes 32×32,
  panneaux en 9-slice. Sprites affichés à l'échelle entière (x3/x4) pour rester
  nets. Valeur ajustable au premier asset test.
- **Import Godot en filtre Nearest**, mipmaps désactivés, pour tout le pixel art.
- **Règles projet maintenues** : UI dans les scènes (Règle n°1), style dans le
  thème (Règle n°2), chemins d'assets stables (Règle n°3), flux bataille
  `Rules.apply → events → battle_fx` inchangé.

## Risque connu et mitigation

ChatGPT/DALL·E produit souvent du « faux pixel » (haute résolution imitant les
pixels, avec anti-aliasing et grille irrégulière). Choix utilisateur assumé de
générer quand même directement en pixel via le navigateur. Mitigation :
- Prompt explicite : « pixel art, basse résolution, palette limitée, pas
  d'anti-aliasing, fond transparent », dimensions cibles indiquées.
- Import Nearest côté Godot.
- Validation visuelle du **premier** asset avant de lancer la génération en série
  (garde-fou : si le rendu est du faux-pixel inexploitable, on s'arrête et on
  rediscute le pipeline plutôt que de générer 60 assets inutilisables).

## Composants

### 1. Pipeline d'assets pixel (ChatGPT navigateur)

**But** : produire des PNG pixel art propres, importés net dans Godot, de façon
traçable.

**Flux** :
1. Vérifier l'accès : piloter le navigateur vers ChatGPT et confirmer que la
   session utilisateur est connectée. Si non → signaler à l'utilisateur (pas de
   login/OAuth automatique) et attendre.
2. Pour chaque asset : prompt pixel art décrivant la source de référence +
   dimensions cibles → générer → télécharger le PNG → déposer dans le bon dossier
   `assets/sprites/...` (chemins Règle n°3) → régler le `.import` en Nearest.
3. Noter la provenance dans `tools/asset_manifest.json` : nom de fichier, prompt,
   date, référence source.

**Dépendances** : outil navigateur (Playwright MCP), session ChatGPT connectée.

**Suppression** : `tools/pixelize.py` et les outils de conversion listés
ci-dessus.

### 2. Fondations de style

- **`scripts/core/game_const.gd`** : ajouter `GUILD_COLORS` (Flamme, Sylve,
  Ombre, Lumière) et `RARITY_COLORS` (commune → légendaire). Source unique de
  vérité des couleurs, réutilisée par le thème et les widgets.
- **Police pixel/bitmap** avec support des accents français, sourcée (licence
  libre), remplaçant Cinzel dans le thème. Cinzel peut rester pour d'éventuels
  titres décoratifs si besoin, mais la police par défaut devient pixel.
- **`resources/ui_theme.tres`** : styleboxes et *theme type variations* câblées
  sur les panneaux pixel (9-slice), boutons `primary`/`secondary`/`disabled`,
  couleurs par défaut, tailles de police pixel, filtre Nearest. Zéro génération
  de StyleBox/Texture au runtime — `ui_theme.gd` ne crée aucun style.
- **Import** : dossier(s) pixel réglés sur filtre Nearest, mipmaps off.

### 3. Widgets réutilisables

- **`scenes/widgets/card_widget.tscn`** (+ `card_widget.gd`, logique seule) :
  structure déclarative — cadre selon la faction, gemme de coût, art de carte,
  nom, stats attaque/PV, bandeau de rareté, zone mots-clés. Expose des `%nodes`
  remplis par le script. **Remplace** `CardWidget.create(...)` construit en code.
- **`scenes/widgets/board_cell.tscn`** : existant, réutilisé et aligné sur le
  nouveau style.
- **`scenes/widgets/unit_token.tscn`** (si nécessaire) : pion d'unité sur le
  plateau (sprite + stats attaque/PV + indicateurs d'état).

### 4. Reconstruction de `scenes/battle.tscn` (déclaratif)

Layout dérivé du mockup UI kit (`assets/mockup/ChatGPT Image ... 12_23_49.png`),
adapté au vrai pixel art. Tous les éléments sont des nœuds nommés (`%Nom`)
déclarés dans la scène, avec textures en `ext_resource` — la scène doit
s'afficher intégralement dans l'éditeur Godot **sans lancer le jeu**.

Éléments :
- Panneau **Joueur** et panneau **Adversaire** : maître (portrait, nom), PV,
  pierres (x/12), taille de main, deck restant.
- Panneau **Infos** : numéro de tour, bouton **Fin du tour**, actions restantes,
  **journal** des dernières actions.
- **Plateau 3×4** avec marqueurs de rangée (row_marker_0..3), cases instanciées
  via `board_cell.tscn`.
- **Main** de cartes (instanciation `card_widget.tscn`).
- **Boutons** (primary/secondary/disabled), **info-bulle** (mots-clés),
  **compteurs** (attaque/défense/PV/temps), **menu/options**.
- **Fenêtres** : confirmation, détail de carte.

### 5. `scripts/ui/battle_scene.gd` → logique pure

Vider les ~48 opérations de construction UI en code (`.new()`, `add_child`,
`StyleBox…`, `CardWidget.create`). Le script ne fait plus que :
- brancher les signaux des nœuds existants,
- appeler `Rules.apply(...)`,
- rejouer la liste d'événements reçue en remplissant les `%nodes` et en
  instanciant `card_widget.tscn` / `board_cell.tscn` / `unit_token.tscn`,
- déléguer le rejeu visuel/animations à `battle_fx.gd`.

Objectif : passer de 1084 lignes à un contrôleur mince. **Aucune mutation d'état
depuis l'UI** — l'état ne change que via `Rules.apply`.

## Flux de données (inchangé)

UI (clic) → `Rules.apply(state, action)` → liste d'événements →
`battle_scene.gd` distribue → `battle_fx.gd` anime + `%nodes` mis à jour.
`scripts/core/` reste pur, sans dépendance UI, testable headless.

## Vérification

- **Règle n°1** : `scenes/battle.tscn` s'ouvre et s'affiche complètement dans
  l'éditeur Godot sans lancer le jeu.
- **Rendu** : `godot --path .` (exe 4.5.1), une bataille jouée, screenshot
  comparé au mockup de référence.
- **Core** : les tests headless de `scripts/core/` passent (aucune régression).
- **Premier asset** : valider visuellement le tout premier sprite pixel généré
  avant la génération en série.

## Découpage prévu du plan (writing-plans détaillera)

1. Pipeline d'assets + vérification de l'accès ChatGPT + suppression des tools de
   conversion.
2. Fondations de style (couleurs `game_const`, police pixel, `ui_theme.tres`,
   import Nearest).
3. Génération des assets pixel (UI kit, cartes/arts, unités, portraits) — après
   validation du premier asset.
4. Widgets réutilisables (`card_widget.tscn`, `unit_token.tscn`).
5. Reconstruction de `battle.tscn`.
6. `battle_scene.gd` en logique pure.
7. Vérification finale.

## Hors périmètre (lots ultérieurs)

Menu principal, sélection de héros, deck builder, collection, paramètres, profil,
campagne, dialogue, guide. Chacun réutilisera les fondations de ce lot.
