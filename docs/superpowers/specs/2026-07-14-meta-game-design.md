# Stonebound — Méta-game (boucle de progression)

Validé le 2026-07-14. Objectif : donner au joueur une raison de revenir, structure
inspirée de Runeterra / Master Duel / Snap, adaptée au PvP-first de Stonebound.

## Décisions

- **3 monnaies, pas plus** — mapping des monnaies existantes du profil :
  `gold` = **Or** (gagné en jouant, boosters de base), `gems` = **Cristaux**
  (premium : passe, skins, cosmétiques), `shards` = **Essence** (recyclage →
  fabrication de cartes). Migration transparente, les clés du profil ne changent pas.
- **JOUER** = partie rapide via le matchmaking existant (repli IA déguisé),
  comme Snap. Les modes précis vivent dans les tuiles.
- **Classement / social sans serveur** : version locale (historique, taux de
  victoire, parties) en attendant le backend Nakama. Pas de faux joueurs.
- **Architecture** : contenu déclaratif dans `resources/data/*.json`
  (quests.json, achievements.json, season_pass.json, shop.json, codex.json…),
  logique dans les autoloads existants (`Game` pour profil/économie), un écran
  = une scène + script léger (règle n°1 du projet). L'enrichissement saisonnier
  ne demande aucune refonte.

## Écrans cibles

Hub (JOUER central + tuiles : Campagne, Arène, Défis, Événements, Collection,
Deck Builder, Boutique, Passe de saison, Classement, Profil ; quêtes du jour,
actualités, offres), Classement (rang, historique, taux de victoire, parties),
Profil (avatar, cadre, titre, niveau/XP, maître favori, stats, badges, date
d'inscription), Boutique (à la une, boosters, packs, cristaux, cosmétiques,
offres limitées), Collection (filtres élément/rareté/coût/type/possédées +
recherche), Défis PvE (contraintes de règles, boss, hebdo), Quêtes
(quotidiennes + hebdomadaires), Succès (jalons), Passe de saison (100 niveaux),
Événements (data-driven), Codex (maîtres, factions, gardiens, royaumes, Pierres
de Lien — le lore consultable, jamais imposé), Social (bloqué serveur).

## Phasage (chaque phase = jouable et propre)

1. **Hub v4** — JOUER central, grille de tuiles, 3 monnaies unifiées, quêtes du
   jour, actus, offres placeholder. Défis → free_setup (le PvE actuel) en attendant.
2. **Profil** — vraies données du profil, badges.
3. **Collection + possession** — modèle d'ownership (starter + gains de
   campagne), filtres, deck builder branché dessus. Prérequis de l'économie.
4. **Économie** — boosters, boutique Or/Essence (recyclage) ; Cristaux quand il
   y aura des cosmétiques.
5. **Quêtes** quotidiennes/hebdo persistées + **Succès**.
6. **Défis PvE** — modificateurs de règles sur le core `Rules`.
7. **Passe de saison** — 100 niveaux, XP par partie.
8. **Événements** jouables (data-driven).
9. **Codex** — depuis les JSON existants (masters.json, campaign.json lore).
10. **Social + classement en ligne** — quand le serveur sera là.

Écart assumé vs la feuille de route utilisateur : Collection avant Boutique
(vendre des boosters sans notion de possession n'a pas de sens).
