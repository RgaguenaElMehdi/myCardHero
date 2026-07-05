# Refonte HUD de bataille — style Legend of Runeterra (Lot 2)

Date : 2026-07-05
Branche : `pixel-art`
Statut : design validé, en attente de plan d'implémentation

## Contexte & objectif

Le HUD de bataille actuel occupe trop d'espace (gros panneaux Joueur/Adversaire, panneau Infos, journal texte). Objectif : **agrandir l'arène** et **réduire le HUD au strict minimum posé sur les bords**, dans l'esprit de *Legend of Runeterra* — l'arène est la star, le chrome s'efface.

Ce lot est **UI/HUD uniquement** : réagencement de `scenes/battle.tscn` et de sa logique d'affichage. Il ne touche **pas** à la police (Cinzel), au filtre de texture, ni au système de rendu des cartes (`CardWidget.create`) — ces sujets sont hors périmètre (annulés précédemment).

## Rappel de règles du jeu (contraintes)

- Plateau **3 colonnes × 4 rangées**. Le **Maître est une unité posée sur le plateau** (sur sa rangée arrière, il s'y déplace). But du jeu : réduire à 0 les PV du Maître adverse **sur le plateau**.
- Ressource = **pierres** (start 3, +2/tour, max 12).
- Flux inchangé : l'UI appelle `Rules.apply(...)` → liste d'événements → rejeu en animations (`battle_fx.gd`). L'UI ne mute jamais l'état.

## Layout cible

```
 ADVERSAIRE        main adv. (dos)                     pierres ◆◆◇◇   deck adv.
 ┌────┐  ┌──────────────────────────────────────────┐
 │jour│  │  [  ] [ MAÎTRE ADV ❤20 ✦] [  ]  rangée arrière adv.
 │ ⚔  │  │  [  ] [ unité ]          [  ]              │
 │ ✦  │  │  [  ] [  ]              [  ]              │   ┌────────┐
 │ ❤  │  │  [  ] [ MAÎTRE TOI ❤20 ✦] [  ]  ta rangée │   │  FIN   │
 │hover  └──────────────────────────────────────────┘   │ DU TOUR│
 └────┘     ta main [carte][carte][carte]   ◆◆◆◇ deck   └────────┘
                                     ┌── info carte (sélection) ──┐
                                     └────────────────────────────┘
```

### Éléments et emplacements

1. **Arène agrandie, centrée** — occupe la majeure partie de l'écran. Plus de panneaux Joueur/Adversaire ni de panneau Infos.

2. **Maîtres sur le plateau** (pas de panneau séparé) :
   - **PV** affichés en valeur sur le jeton Maître (cœur + nombre, plus grand que sur une unité normale).
   - **Pouvoir** = icône **✦** sur le jeton ; clic sur ton Maître → active le pouvoir si assez de pierres (mini-bouton contextuel près du jeton).
   - **Passif qui s'active** → animation/effet joué **sur le jeton Maître** (halo/flash de faction), via `battle_fx`.

3. **Pierres** — pips de gemmes `◆◆◆◇◇` (rempli = disponible) plutôt qu'un texte `x/12` ; total exact au survol. **Les tiennes en bas-droite** (près du deck / sous Fin du tour), **celles de l'adversaire en haut-droite**.

4. **Deck** — pile de dos de cartes dans un coin par joueur : **le tien en bas-droite**, **l'adversaire en haut-droite**. À la pioche, une carte « jaillit » du deck vers la main (animation de tir).

5. **Mains** :
   - **La tienne** en bas-centre, faces visibles. Les cartes sont **assez lisibles** (coût / ATQ / PV / effet dessus) → **plus de dépendance au clic droit**.
   - **Celle de l'adversaire** en haut-centre, en **dos de cartes** (nombre visible, jamais la face).

6. **Fin du tour** — gros bouton au **centre-droit**, bien accessible.

7. **Panneau info carte** — en **bas-droite**, apparaît au **clic gauche** sur une carte de la main **ou** une unité du plateau (même panneau réutilisé) ; reste affiché jusqu'à désélection. Contient le détail (règles, mots-clés, définitions).

8. **Journal (dernières actions)** — fine **barre latérale d'icônes** à gauche (⚔ attaque, ✦ sort, ❤ soin, ✚ invocation…). **Survol = détail** de la ligne. ~5 dernières actions visibles, le reste au scroll/survol.

## Périmètre technique

- **Réagencer `scenes/battle.tscn`** : supprimer les panneaux Joueur/Adversaire/Infos, agrandir la zone arène, repositionner main/deck/pierres/Fin du tour/journal/info-carte selon le layout. Structure déclarée dans la scène (Règle n°1) autant que possible.
- **Adapter `scripts/ui/battle_scene.gd`** : brancher les nouveaux nœuds ; afficher PV/pouvoir sur les jetons Maître ; gérer sélection carte/unité → panneau info bas-droite ; journal en icônes + survol. Pas de refonte du rendu de carte (on garde `CardWidget.create`).
- **`scripts/ui/battle_fx.gd`** : animation de pioche (carte qui jaillit du deck vers la main) ; effet d'activation de passif/pouvoir sur le jeton Maître.
- **`scripts/ui/board_cell.gd`** : mise en valeur du jeton Maître (PV plus gros, icône pouvoir).

## Hors périmètre

Police, filtre de texture, `card_widget.tscn` déclaratif (annulés). Génération des assets pixel (briefs séparés). Autres écrans (menu, deck builder, etc.).

## Vérification

- `scenes/battle.tscn` s'ouvre dans l'éditeur sans lancer le jeu (Règle n°1).
- `godot --headless --path . res://scenes/battle.tscn -- --autoplay` : partie complète sans erreur.
- Capture `--screenshot` comparée au layout cible : arène agrandie, HUD réduit aux bords, PV/pouvoir sur les Maîtres, main/deck/pierres/journal/info-carte bien placés.
- Tests `scripts/core/` intacts (aucune régression logique).

## Points confirmés

- Adversaire symétrique (Maître en haut avec PV + pouvoir grisé, main en dos, deck + pierres en haut-droite).
- Panneau info bas-droite réutilisé pour cartes **et** unités, au clic gauche, jusqu'à désélection.
- Journal : ~5 actions visibles en icônes, détail au survol.
