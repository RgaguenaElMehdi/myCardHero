# Brief de génération — assets pixel art (ChatGPT)

But : générer les illustrations en **vrai pixel art** pour les intégrer directement dans Godot (import Nearest). Chaque fichier doit porter **exactement** le nom indiqué et aller dans le **dossier** indiqué — il se branche alors tout seul (le jeu résout l'art par `res://assets/sprites/cards/<id>.png` et les portraits par `res://assets/portraits/<id>.png`).

## Règles techniques (à mettre dans CHAQUE prompt)

Préfixe de style à coller devant chaque description :

> **Pixel art authentique**, gros pixels nets façon rendu natif ~64×64, **palette limitée (≤ 24 couleurs)**, **aucun anti-aliasing**, contours nets, **fond entièrement transparent** (PNG alpha), sujet centré, **aucun texte / lettre / cadre / bordure**, style dark-fantasy cohérent. Un seul sujet.

- **Format de sortie** : PNG avec **transparence**. Carré.
- **Pas de texte, pas de cadre** : le cadre et les stats sont ajoutés par le jeu.
- Un seul sujet centré, marge autour.

## Palette par faction (à ajouter selon la guilde)

| Guilde | Indication couleur |
|--------|--------------------|
| **flame** | rouges chauds, oranges, braises |
| **sylvan** | verts, mousse, lumière dorée |
| **shadow** | violets, indigo, clair de lune pâle |
| **light** | or, ivoire, bleu ciel doux |

## Où mettre les fichiers

- **Créatures + sorts** (les 40 ci-dessous) → `assets/sprites/cards/<id>.png`
- **Portraits de maîtres** (aria, grim, kiran, willow) → `assets/portraits/<id>.png`

⚠️ Écrase les fichiers peints existants du même nom (c'est voulu : on passe en pixel).

## ⭐ Lot de validation d'abord (5 images)

Génère **ces 5 en premier** et envoie-les moi : je valide que le rendu est du vrai pixel exploitable **avant** que tu fasses les 40. Si c'est du « faux pixel » flou, on ajuste le prompt.

- `forest_wolf` (sylvan) · `flame_imp` (flame) · `wraith` (shadow) · `paladin` (light) · `fireball` (sort flame)

---

## Créatures (32) → `assets/sprites/cards/<id>.png`

### Flamme
- `flame_imp` — a tiny mischievous fire imp with small horns and a toothy grin, juggling a flame in its palm
- `flame_fiend` — a hulking ember demon with cracked magma skin and burning eyes, rising from smoke
- `ember_fox` — a sleek fox made of cinders and flame, mid-dash, trailing sparks
- `fire_archer` — a fierce archer woman with a blazing bow, arrow of pure fire nocked
- `salamander` — a stout fire salamander with glowing spines, defensive stance on hot rocks
- `lava_golem` — a massive golem of black rock with lava glowing between its plates
- `phoenix` — a majestic phoenix spreading burning wings, feathers trailing embers
- `solar_phoenix` — an immense radiant phoenix like a small sun, white-gold flames, ascending

### Sylve (sylvan)
- `sprout` — a cute tiny plant creature with leaf arms and a curious face, sprouting from soil
- `thorn_beast` — a bristling beast of vines and long thorns, low aggressive stance
- `forest_wolf` — a lean grey-green wolf with leaves in its fur, baring teeth, forest gloom
- `moss_turtle` — an ancient turtle with a hill of moss and tiny trees on its shell
- `druid` — a calm druidess with antler circlet channeling green light between her hands
- `sylph` — a graceful winged air spirit of petals and wind, hovering
- `gale_spirit` — a powerful storm spirit of swirling wind blades and torn leaves
- `treant` — a towering wise tree giant with a mossy beard and huge gentle hands

### Ombre (shadow)
- `shade` — a small creeping shadow creature with two bright eyes, sliding along a wall
- `nightmare` — a winged shadow steed with smoking mane and burning violet eyes
- `gloom_rat` — a scrawny black rat with glowing purple eyes, scurrying over cobblestones
- `bat_swarm` — a swirling swarm of bats forming a menacing cloud shape with many eyes
- `cultist` — a hooded cultist holding a crackling orb of dark energy
- `wraith` — a floating spectral figure in tattered robes, cold mist, faint skull face
- `bone_knight` — an armored skeleton knight with a chipped sword and heavy shield
- `dread_lord` — a regal undead warlord on a throne of bones, crowned, radiating dark power

### Lumière (light)
- `squire` — a young hopeful squire with an oversized shield and a wooden sword, brave
- `paladin` — a shining paladin woman in white-gold armor, sword raised, sunburst behind
- `lantern_sprite` — a tiny glowing fairy carrying a lantern bigger than herself, night air
- `temple_archer` — a disciplined archer in white temple robes drawing a golden longbow
- `shield_bearer` — a stoic soldier almost hidden behind a tower shield engraved with a sun
- `cleric` — a kind cleric with a healing staff, soft golden halo of light
- `archangel` — a mighty archangel with broad white wings and a flaming greatsword
- `seraph` — a six-winged seraph of pure light, faceless and serene, blinding radiance

## Sorts (8) → `assets/sprites/cards/<id>.png`
*(un effet/objet, pas de personnage)*

- `fireball` (flame) — a roaring fireball hurtling forward leaving a spiral of smoke
- `inferno` (flame) — a wall of flames engulfing a battlefield, silhouettes of embers
- `rejuvenate` (sylvan) — glowing green sap and blossoms swirling around a healing light
- `wild_growth` (sylvan) — vines and flowers erupting upward, bursting with life
- `dark_pact` (shadow) — a shadowy hand and a mortal hand shaking over a black candle contract
- `life_drain` (shadow) — a stream of crimson life essence flowing from a wilting flower to a dark orb
- `blessing` (light) — a beam of warm light descending as a translucent shield dome
- `holy_charge` (light) — a radiant banner charging forward with streaks of golden light

## Portraits de maîtres (4) → `assets/portraits/<id>.png`
*(cadrage buste, regard vers le joueur)*

- `aria` (light) — a radiant blonde paladin heroine, halo, white-gold armor, gentle brave face
- `kiran` (flame) — a fierce red-haired fire mage, ember-lit eyes, confident smirk
- `grim` (shadow) — a grim hooded necromancer, pale face, violet glow, cold stare
- `willow` (sylvan) — a serene green-clad druid, leaves and antlers, calm wise expression

---

Quand un lot est prêt, dépose les PNG aux bons endroits et dis-le moi : je règle l'import Nearest et je les branche.
