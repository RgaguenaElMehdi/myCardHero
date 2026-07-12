# Plan multijoueur en ligne — Stonebound

Cible : **Desktop (PC)**, ambition **compétitif** (comptes + classement).

## Pourquoi c'est faisable sans réécrire le jeu

`scripts/core/` est **pur et déterministe** : `Rules.setup(cards, masters, decks, seed)`,
`Rules.legal_actions(state)`, `Rules.apply(state, action) → { ok, error, events }`.
L'UI **envoie une action et rejoue les events** (`battle_fx`) — elle ne mute jamais
l'état. C'est déjà le modèle réseau d'un jeu de cartes. Le multi remplace
« appliquer en local » par « envoyer l'action / recevoir les events ».

## Modèle : serveur autoritaire (jamais du P2P lockstep)

Un jeu de cartes a de l'**information cachée** (main, ordre du deck). En P2P chaque
client aurait tout l'état → triche triviale. Il faut un **arbitre** qui détient
l'état + le RNG :

```
Client A ──action──▶  SERVEUR (Godot headless, réutilise scripts/core)  ◀──action── Client B
                      ├─ Rules.legal_actions  (valide, anti-triche)
                      ├─ Rules.apply          (calcule les events)
                      └─ events REDACTÉS par joueur
Client A ◀── events vus par A            events vus par B ──▶ Client B
```

Le seed vit **uniquement côté serveur** → ordre du deck et pioches cachés.

## Stack recommandée

- **Serveur de match** : Godot **headless autoritaire** (ENet), réutilise `scripts/core/` tel quel.
- **Backend méta** : **Nakama** (open-source, SDK Godot) pour auth/comptes, amis,
  **stockage collection & decks**, **matchmaking**, **classement** (Glicko-2/Elo), saisons.
  Nakama apparie puis **passe la main** à une instance de serveur de match Godot.
- **Client** : ENet vers le serveur de match + client Nakama pour le méta.

> Pas « tout Nakama » : sa logique autoritaire serait en Go/Lua → duplication des
> règles et dérive. L'autorité gameplay reste dans Godot ; Nakama = méta seulement.

## Implications sur le code existant

1. **Collection & decks server-authoritative** (obligatoire en compétitif). Aujourd'hui
   `Game.profile` (collection, decks, masters, progression) est un `user://profile.json`
   local. Il migre vers le **stockage serveur** (Nakama). La **validation de deck**
   (`Rules.validate_deck` + ownership) tourne **au serveur** au début du match.
   Le refactor deck `{ name, master, cards }` est déjà le bon format à sérialiser.
2. **Redaction de l'information cachée** : couche autour du core qui filtre
   `res.events` par destinataire (« J1 pioche *Phénix* » pour J1, « J1 pioche une
   carte » pour J2). Ne touche pas au core.
3. **Snapshot d'état par joueur** (`serialize_state_for(player)`) pour la
   **reconnexion**. Le core est data-oriented → sérialisable.
4. **Déterminisme** : `Rules.setup(seed)` + `shuffle` reproductibles, seed côté serveur.

## Points de branchement dans le code

- `battle_scene.gd` — `_setup_match()` (`Rules.setup`) et **toutes** les `Rules.apply`
  (`_submit`, `_ai_turn`, mulligan, watchdog) : c'est là qu'on insère le
  **`MatchController`** (local vs réseau). Le reste de l'UI ne bouge pas.
- `Rules.setup` prend les 2 decks → échangés au **lobby**.
- `AiPlayer` reste pour le solo / le remplissage.

## Phases (chacune apporte de la valeur, à faire dans l'ordre)

| #  | Phase | Débloque | Infra |
|----|-------|----------|-------|
| **0** | **`MatchController`** (local vs distant) devant `Rules.apply` | Solo intact, couture réseau en place | aucune |
| 1  | **Match autoritaire ENet** : serveur Godot headless, 2 clients par IP + redaction | Gameplay-réseau prouvé | 0 (LAN) |
| 2  | **Nakama méta** : login, profil/collection/decks **côté serveur** | Comptes, sync, base anti-triche | Nakama |
| 3  | **Matchmaking + hand-off** vers serveur de match dédié | Trouver une partie en ligne | fleet/hébergement |
| 4  | **Ranked** : MMR Glicko-2, file classée, saisons | Cœur compétitif | leaderboards Nakama |
| 5  | **Durcissement** : redaction complète, validation deck serveur, replays, reconnexion | Intégrité compétitive | — |

Réalité : les phases 2→5 = plusieurs mois + hébergement et ops continus.

## Phase 0 — `MatchController` (en cours)

Objectif : **découpler l'UI des règles derrière une seule interface**, sans changer
le comportement (le solo reste identique et testé).

- `scripts/core/match_controller.gd` : détient `state`, expose
  `setup(cards, masters, decks, seed) → GameState` et
  `apply(action) → { ok, error, events }`. En local, forward direct vers `Rules`
  (cette classe EST l'autorité).
- `battle_scene.gd` route **toutes** ses actions via `_match.apply(...)` au lieu de
  `Rules.apply(state, ...)`, et son setup via `_match.setup(...)`.

Phase 1 ajoutera un `NetworkMatchController` (sous-classe) qui, au lieu de forward,
envoie l'action au serveur et reçoit les events poussés (dont ceux de l'adversaire)
via un signal `remote_events`.

---

## État d'avancement

### Fait + **testé** (71+ tests, dont l'E2E réseau)
- **Sérialisation d'état complet** — `to_dict`/`from_dict` sur GameState/PlayerState/
  Board/MonsterInst (`scripts/core/*`). Test round-trip.
- **Redaction par joueur** — `NetRedact.snapshot_for(state, viewer)` : ordre des decks
  et main adverse masqués (comptes préservés), board/défausse/masters publics, RNG
  jamais envoyé. Découverte clé : **le flux d'events ne porte aucune info cachée**
  (`draw` = count only ; summon/cast/death publics) → seuls les snapshots sont rédigés.
- **Ranking Glicko-2** — `Ranking` (`scripts/net/ranking.gd`), validé contre l'exemple
  de référence de Glickman.
- **Logique serveur autoritaire** — `NetServerLogic` : valide (`Rules.legal_actions`),
  applique, produit un snapshot rédigé par joueur ; **anti-triche** (agir hors de son
  tour est refusé). Testé.
- **Transport ENet** — `Net` (autoload) + `NetworkMatchController`. **Prouvé E2E** par
  un smoke-test 2 process : connexion, échange de deck, setup autoritaire, indices
  joueur (host=0, join=1), snapshots rédigés, handshake mulligan complet jusqu'à la
  phase MAIN, anti-triche, déconnexion propre.
- **Backend méta** — interface `MetaBackend` + `LocalBackend` (offline, ranked réel).

### Deux topologies (même logique autoritaire `NetServerLogic`)
- **Listen-server** : un joueur héberge ET joue (lobby → « Héberger »). Il est
  joueur 0 ; l'autre rejoint par IP (joueur 1).
- **Serveur dédié** : une instance headless arbitre sans jouer. Les **deux** joueurs
  rejoignent par IP ; le serveur les assigne joueur 0 / 1 par ordre de connexion.
  ```
  GODOT --headless --path . -- --serve            # serveur dédié (VPS/LAN), port 8790
  GODOT --headless --path . -- --serve=9000       # port personnalisé
  ```
  Puis dans le jeu, chaque joueur fait « Multijoueur → Rejoindre par IP » vers
  l'adresse du serveur. Pour la prod : exporter un build **headless** et lancer
  `--serve` sur le VPS (ouvrir le port UDP ENet).

### Smoke-test réseau (headless)
```
# listen-server (2 process)
GODOT --headless --path . -- --nettest=host
GODOT --headless --path . -- --nettest=join=127.0.0.1

# serveur dédié (3 process : 1 serveur + 2 clients)
GODOT --headless --path . -- --serve
GODOT --headless --path . -- --nettest=join=127.0.0.1
GODOT --headless --path . -- --nettest=join=127.0.0.1
```
Chaque client loggue `[nettest] …` : `MATCH prêt` puis `OK — phase principale
atteinte via le réseau`. Les deux topologies sont vérifiées E2E.

### Dernier kilomètre (UI, à itérer en 2 fenêtres réelles)
1. **Lobby** : écran héberger/rejoindre par IP → `Net.host(deck)` / `Net.join(ip, deck)` ;
   sur `Net.match_ready(my_player)` → `Game.battle_config = {mode:"online", my_player}` →
   `Game.goto("battle")`.
2. **`battle_scene` en mode online** :
   - `_match = Net.controller` ; connecter `controller.remote_events` → rejouer les events ;
     **pas d'IA** (`_ai_turn` désactivé) ; `_submit` envoie l'action et attend le push.
   - **Perspective** : le client suppose « joueur 0 = moi » (main en bas). Pour le joiner
     (player 1) il faut **normaliser la vue** — soit rendre `battle_scene` conscient de
     `my_player`, soit (recommandé) normaliser côté serveur dans le snapshot pour que
     **chaque client se voie toujours en joueur 0** : réordonner `players`, retourner le
     plateau `cell → Vector2i(2-col, 3-row)` et les indices `owner/player` des events
     (involution → testable par flip∘flip = identité). C'est le seul vrai morceau restant.
3. **Fin de partie ranked** → `MetaBackend.report_result(score, opp_rating)`.

## Déploiement (compétitif hébergé) — étapes d'ops (hors dépôt)

1. **Serveur de match** : exporter un build **dédié headless** de Godot (`--headless`),
   le lancer sur un VPS, ouvrir le port ENet (8790). Une instance = une partie (ou
   plusieurs via un gestionnaire de fleet type Agones).
2. **Nakama** : déployer Nakama (Docker) + PostgreSQL. Activer email/social auth,
   storage (collection & decks), **matchmaker** (par MMR), **leaderboards** (Glicko-2).
   Écrire `NakamaBackend extends MetaBackend` (SDK Godot Nakama) — la seule nouvelle
   glue ; le reste du jeu ne bouge pas.
3. **Hand-off** : le matchmaker Nakama apparie → réserve/assigne une instance de serveur
   de match → renvoie IP/port aux 2 clients → ils `Net.join(...)`.
4. **Anti-triche** : la collection & les decks sont validés **au serveur** au setup
   (`Rules.validate_deck` + ownership depuis le storage Nakama). Le serveur autoritaire +
   la redaction couvrent déjà l'info cachée et les coups illégaux.
