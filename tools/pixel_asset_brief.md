# Prompts pixel art prêts à copier-coller

Un prompt autonome par image (le style est déjà intégré). Génère, télécharge le PNG, renomme **exactement** comme le titre, dépose dans le **dossier indiqué**. Import Nearest et branchement gérés par Claude.

- **Polices** : rien à générer (Pixel Operator déjà installé).
- **Fond transparent** demandé partout sauf : panneaux, boutons, onglets, plateau, fond d'arène (éléments pleins).

**⭐ Valide d'abord ce petit lot** (HUD : `panel_stone`, `btn_primary`, `res_heart`, `ind_select_gold`, `board_arena` — Cartes : `forest_wolf`, `flame_imp`, `wraith`, `paladin`, `fireball`) et envoie-les avant de tout générer.

---

# A. UI / HUD → dossier `assets/sprites/ui/pixel/`

## Panneaux (9-slice : bordure nette + centre uni, bords extérieurs transparents)

**panel_stone.png**
```
Pixel art authentique d'un panneau d'interface en pierre sombre avec une bordure de bronze ornée et un centre uni tuilable, format carré ~64x64 pixels, palette limitée (<=20 couleurs), aucun anti-aliasing, contours nets, style anime styledonjon, coins extérieurs transparents, aucun texte. PNG.
```

**panel_tooltip.png**
```
Pixel art authentique d'un petit panneau d'info-bulle en pierre très sombre avec une fine bordure dorée et un centre uni, format carré ~64x64 pixels, palette limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, coins extérieurs transparents, aucun texte. PNG.
```

## Boutons (9-slice, ~72x28)

**btn_primary.png**
```
Pixel art authentique d'un bouton d'interface en pierre bleutée avec un liseré doré et un centre uni, forme rectangulaire ~72x28 pixels, palette limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, coins extérieurs transparents, aucun texte. PNG.
```

**btn_secondary.png**
```
Pixel art authentique d'un bouton d'interface en bronze rougeâtre avec un liseré clair et un centre uni, forme rectangulaire ~72x28 pixels, palette limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, coins extérieurs transparents, aucun texte. PNG.
```

**btn_disabled.png**
```
Pixel art authentique d'un bouton d'interface gris terne et éteint (état désactivé) avec un centre uni, forme rectangulaire ~72x28 pixels, palette limitée (<=12 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, coins extérieurs transparents, aucun texte. PNG.
```

## Onglets d'en-tête (plaque ~96x32, sans texte)

**tab_player.png**
```
Pixel art authentique d'une plaque d'en-tête bleue en pierre et métal (bandeau de titre de joueur), forme rectangulaire ~96x32 pixels, palette limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, coins extérieurs transparents, aucun texte. PNG.
```

**tab_opponent.png**
```
Pixel art authentique d'une plaque d'en-tête rouge en pierre et métal (bandeau de titre d'adversaire), forme rectangulaire ~96x32 pixels, palette limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, coins extérieurs transparents, aucun texte. PNG.
```

**tab_infos.png**
```
Pixel art authentique d'une plaque d'en-tête en pierre neutre grise avec liseré de bronze (bandeau de titre d'informations), forme rectangulaire ~96x32 pixels, palette limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, coins extérieurs transparents, aucun texte. PNG.
```

## Bannières suspendues (fond transparent)

**banner_blue.png**
```
Pixel art authentique d'une grande bannière de tissu bleue suspendue à une tringle de fer, pendante, ~48x96 pixels, palette limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte. PNG.
```

**banner_red.png**
```
Pixel art authentique d'une grande bannière de tissu rouge suspendue à une tringle de fer, pendante, ~48x96 pixels, palette limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte. PNG.
```

**banner_blue_s.png**
```
Pixel art authentique d'une petite bannière de tissu bleue suspendue, ~32x64 pixels, palette limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte. PNG.
```

**banner_red_s.png**
```
Pixel art authentique d'une petite bannière de tissu rouge suspendue, ~32x64 pixels, palette limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte. PNG.
```

## Jauges (barre horizontale pleine, fond transparent, ~72x14)

**bar_hp.png**
```
Pixel art authentique d'une jauge horizontale rouge (barre de points de vie) pleine, ~72x14 pixels, palette limitée (<=12 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte. PNG.
```

**bar_crystal.png**
```
Pixel art authentique d'une jauge horizontale bleu cristal (barre de pierres/mana) pleine, ~72x14 pixels, palette limitée (<=12 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte. PNG.
```

**bar_gold.png**
```
Pixel art authentique d'une jauge horizontale dorée (barre d'or) pleine, ~72x14 pixels, palette limitée (<=12 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte. PNG.
```

**bar_action.png**
```
Pixel art authentique d'une jauge horizontale verte (barre d'actions/énergie) pleine, ~72x14 pixels, palette limitée (<=12 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte. PNG.
```

## Icônes de ressource (32x32, fond transparent)

**res_heart.png**
```
Pixel art authentique d'une icône de cœur rouge (points de vie), objet unique centré, ~32x32 pixels, palette limitée (<=12 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte. PNG.
```

**res_crystal.png**
```
Pixel art authentique d'une icône de gemme/cristal bleu taillé (ressource "pierre"), objet unique centré, ~32x32 pixels, palette limitée (<=12 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte. PNG.
```

**res_gold.png**
```
Pixel art authentique d'une icône de pièce d'or (ressource monnaie), objet unique centré, ~32x32 pixels, palette limitée (<=12 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte. PNG.
```

**res_light.png**
```
Pixel art authentique d'une icône de petit soleil doré rayonnant (faction Lumière), objet unique centré, ~32x32 pixels, palette limitée (<=12 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte. PNG.
```

**res_nature.png**
```
Pixel art authentique d'une icône de feuille verte (faction Sylve), objet unique centré, ~32x32 pixels, palette limitée (<=12 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte. PNG.
```

**res_shadow.png**
```
Pixel art authentique d'une icône de crâne violet auréolé d'ombre (faction Ombre), objet unique centré, ~32x32 pixels, palette limitée (<=12 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte. PNG.
```

## Icônes de stat (32x32, fond transparent)

**icon_stat_attack.png**
```
Pixel art authentique d'une icône d'épée (statistique d'attaque), objet unique centré, ~32x32 pixels, palette limitée (<=12 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte. PNG.
```

**icon_stat_shield.png**
```
Pixel art authentique d'une icône de bouclier (statistique de défense), objet unique centré, ~32x32 pixels, palette limitée (<=12 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte. PNG.
```

**icon_stat_action.png**
```
Pixel art authentique d'une icône de sablier (statistique d'action/tour), objet unique centré, ~32x32 pixels, palette limitée (<=12 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte. PNG.
```

## Icônes de menu (32x32, fond transparent)

**icon_menu_bag.png**
```
Pixel art authentique d'une icône de bourse/sac de cuir (boutique), objet unique centré, ~32x32 pixels, palette limitée (<=12 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte. PNG.
```

**icon_menu_book.png**
```
Pixel art authentique d'une icône de livre fermé à reliure de cuir (journal/guide), objet unique centré, ~32x32 pixels, palette limitée (<=12 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte. PNG.
```

**icon_menu_gear.png**
```
Pixel art authentique d'une icône d'engrenage métallique (options/réglages), objet unique centré, ~32x32 pixels, palette limitée (<=12 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte. PNG.
```

**icon_menu_exit.png**
```
Pixel art authentique d'une icône de porte en bois cloutée (quitter/sortie), objet unique centré, ~32x32 pixels, palette limitée (<=12 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte. PNG.
```

## Icônes diverses (32x32, fond transparent)

**icon_check.png**
```
Pixel art authentique d'une icône de coche (validation) verte, symbole unique centré, ~32x32 pixels, palette limitée (<=8 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent. PNG.
```

**icon_cross.png**
```
Pixel art authentique d'une icône de croix (annulation) rouge, symbole unique centré, ~32x32 pixels, palette limitée (<=8 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent. PNG.
```

## Indicateurs de case (overlay carré 48x48, fond transparent)

**ind_select_gold.png**
```
Pixel art authentique d'un contour/halo doré carré (surbrillance de case jouable), cadre lumineux seul au centre, ~48x48 pixels, palette limitée (<=10 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte. PNG.
```

**ind_select_blue.png**
```
Pixel art authentique d'un contour/halo bleu carré (surbrillance de déplacement), cadre lumineux seul au centre, ~48x48 pixels, palette limitée (<=10 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte. PNG.
```

**ind_attack.png**
```
Pixel art authentique d'une icône d'épées croisées rouges dans un halo (cible d'attaque), centrée, ~48x48 pixels, palette limitée (<=10 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte. PNG.
```

**ind_heal.png**
```
Pixel art authentique d'une croix de soin verte lumineuse (soin), centrée, ~48x48 pixels, palette limitée (<=10 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte. PNG.
```

**ind_light.png**
```
Pixel art authentique d'un halo doré rayonnant (effet de Lumière), centré, ~48x48 pixels, palette limitée (<=10 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte. PNG.
```

**ind_shadow.png**
```
Pixel art authentique d'une aura violette d'ombre tourbillonnante (effet d'Ombre), centrée, ~48x48 pixels, palette limitée (<=10 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte. PNG.
```

## Plateau (élément plein, bords extérieurs transparents)

**board_arena.png**
```
Pixel art authentique d'un plateau de jeu 3 colonnes x 4 rangées en dalles de pierre de donjon, vue légèrement plongeante, cases nettement délimitées, ambiance sobre et sombre, ~320x256 pixels, palette limitée (<=24 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, coins extérieurs transparents, aucun texte. PNG.
```

**board_mini.png**
```
Pixel art authentique d'une version miniature d'un plateau 3x4 en dalles de pierre de donjon vu de dessus, ~96x80 pixels, palette limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, coins extérieurs transparents, aucun texte. PNG.
```

## Marqueurs de rangée (28x28, fond transparent — chiffre autorisé)

**row_marker_0.png**
```
Pixel art authentique d'une petite plaque de pierre ronde gravée du chiffre "0", ~28x28 pixels, palette limitée (<=10 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent. PNG.
```

**row_marker_1.png**
```
Pixel art authentique d'une petite plaque de pierre ronde gravée du chiffre "1", ~28x28 pixels, palette limitée (<=10 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent. PNG.
```

**row_marker_2.png**
```
Pixel art authentique d'une petite plaque de pierre ronde gravée du chiffre "2", ~28x28 pixels, palette limitée (<=10 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent. PNG.
```

**row_marker_3.png**
```
Pixel art authentique d'une petite plaque de pierre ronde gravée du chiffre "3", ~28x28 pixels, palette limitée (<=10 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent. PNG.
```

## Décor

**torch_wall.png**
```
Pixel art authentique d'une torche murale allumée à flamme orangée sur applique de fer, ~32x64 pixels, palette limitée (<=14 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte. PNG.
```

**rocks.png**
```
Pixel art authentique d'un petit tas de rochers de donjon gris, ~48x32 pixels, palette limitée (<=12 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte. PNG.
```

**battle_bg.png**
```
Pixel art authentique d'un fond d'arène de donjon en plein écran : murs de pierre, pénombre, lueurs de torches, sol dallé, sans personnage, format 16:9 ~480x270 pixels, palette limitée (<=32 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, image pleine (opaque), aucun texte. PNG.
```

---

# B. Cartes — créatures → dossier `assets/sprites/cards/<id>.png`

*(64x64, créature seule centrée, fond transparent, palette de la faction)*

## Flamme (rouges/oranges/braises)

**flame_imp.png**
```
Pixel art authentique d'un petit diablotin de feu espiègle avec de petites cornes et un sourire édenté, jonglant avec une flamme, créature seule centrée, ~64x64 pixels, palette chaude limitée (<=16 couleurs, rouges/oranges/braises), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**flame_fiend.png**
```
Pixel art authentique d'un démon de braise massif à la peau de magma craquelée et aux yeux ardents, surgissant de la fumée, créature seule centrée, ~64x64 pixels, palette chaude limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**ember_fox.png**
```
Pixel art authentique d'un renard élancé fait de cendres et de flammes en pleine course, traînée d'étincelles, créature seule centrée, ~64x64 pixels, palette chaude limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**fire_archer.png**
```
Pixel art authentique d'une archère féroce à l'arc embrasé, flèche de feu encochée, personnage seul centré, ~64x64 pixels, palette chaude limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**salamander.png**
```
Pixel art authentique d'une salamandre de feu trapue aux épines rougeoyantes, posture défensive sur des roches brûlantes, créature seule centrée, ~64x64 pixels, palette chaude limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**lava_golem.png**
```
Pixel art authentique d'un golem massif de roche noire avec de la lave rougeoyant entre ses plaques, créature seule centrée, ~64x64 pixels, palette chaude limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**phoenix.png**
```
Pixel art authentique d'un phénix majestueux déployant des ailes enflammées, plumes traînant des braises, créature seule centrée, ~64x64 pixels, palette chaude limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**solar_phoenix.png**
```
Pixel art authentique d'un immense phénix radieux tel un petit soleil, flammes blanc-or, en ascension, créature seule centrée, ~64x64 pixels, palette chaude et dorée limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

## Sylve (verts/mousse/lumière dorée)

**sprout.png**
```
Pixel art authentique d'une mignonne petite créature-plante avec des bras de feuilles et un visage curieux, sortant de la terre, créature seule centrée, ~64x64 pixels, palette verte limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**thorn_beast.png**
```
Pixel art authentique d'une bête hérissée de lianes et de longues épines, posture agressive basse, créature seule centrée, ~64x64 pixels, palette verte limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**forest_wolf.png**
```
Pixel art authentique d'un loup élancé gris-vert avec des feuilles dans la fourrure, babines retroussées, pénombre de forêt, créature seule centrée, ~64x64 pixels, palette verte limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**moss_turtle.png**
```
Pixel art authentique d'une tortue ancienne portant une colline de mousse et de petits arbres sur sa carapace, créature seule centrée, ~64x64 pixels, palette verte limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**druid.png**
```
Pixel art authentique d'une druidesse calme avec un diadème de bois de cerf canalisant une lumière verte entre ses mains, personnage seul centré, ~64x64 pixels, palette verte limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**sylph.png**
```
Pixel art authentique d'un gracieux esprit de l'air ailé fait de pétales et de vent, en lévitation, créature seule centrée, ~64x64 pixels, palette verte et claire limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**gale_spirit.png**
```
Pixel art authentique d'un puissant esprit de tempête fait de lames de vent tourbillonnantes et de feuilles arrachées, créature seule centrée, ~64x64 pixels, palette verte limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**treant.png**
```
Pixel art authentique d'un immense géant-arbre sage avec une barbe de mousse et d'énormes mains douces, créature seule centrée, ~64x64 pixels, palette verte limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

## Ombre (violets/indigo/clair de lune)

**shade.png**
```
Pixel art authentique d'une petite créature d'ombre rampante avec deux yeux brillants, glissant le long d'un mur, créature seule centrée, ~64x64 pixels, palette violette/indigo limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**nightmare.png**
```
Pixel art authentique d'un destrier d'ombre ailé à la crinière fumante et aux yeux violets ardents, créature seule centrée, ~64x64 pixels, palette violette/indigo limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**gloom_rat.png**
```
Pixel art authentique d'un rat noir décharné aux yeux violets luisants, filant sur des pavés, créature seule centrée, ~64x64 pixels, palette violette/indigo limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**bat_swarm.png**
```
Pixel art authentique d'un essaim de chauves-souris tourbillonnant en une forme de nuage menaçante avec de multiples yeux, créature seule centrée, ~64x64 pixels, palette violette/indigo limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**cultist.png**
```
Pixel art authentique d'un cultiste encapuchonné tenant un orbe crépitant d'énergie sombre, personnage seul centré, ~64x64 pixels, palette violette/indigo limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**wraith.png**
```
Pixel art authentique d'une silhouette spectrale flottante en robe en lambeaux, brume froide, visage de crâne à peine visible, créature seule centrée, ~64x64 pixels, palette violette/indigo limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**bone_knight.png**
```
Pixel art authentique d'un chevalier squelette en armure avec une épée ébréchée et un lourd bouclier, personnage seul centré, ~64x64 pixels, palette violette/indigo et os limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**dread_lord.png**
```
Pixel art authentique d'un seigneur de guerre mort-vivant royal sur un trône d'ossements, couronné, irradiant un pouvoir sombre, personnage seul centré, ~64x64 pixels, palette violette/indigo limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

## Lumière (or/ivoire/bleu ciel doux)

**squire.png**
```
Pixel art authentique d'un jeune écuyer plein d'espoir avec un bouclier surdimensionné et une épée de bois, brave, personnage seul centré, ~64x64 pixels, palette or/ivoire limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**paladin.png**
```
Pixel art authentique d'une paladine étincelante en armure blanc-or, épée levée, éclat de soleil derrière elle, personnage seul centré, ~64x64 pixels, palette or/ivoire limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**lantern_sprite.png**
```
Pixel art authentique d'une minuscule fée lumineuse portant une lanterne plus grande qu'elle, air nocturne, créature seule centrée, ~64x64 pixels, palette or/ivoire limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**temple_archer.png**
```
Pixel art authentique d'un archer discipliné en robe de temple blanche bandant un arc long doré, personnage seul centré, ~64x64 pixels, palette or/ivoire limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**shield_bearer.png**
```
Pixel art authentique d'un soldat stoïque presque caché derrière un immense bouclier-tour gravé d'un soleil, personnage seul centré, ~64x64 pixels, palette or/ivoire limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**cleric.png**
```
Pixel art authentique d'un clerc bienveillant avec un bâton de soin et un doux halo de lumière dorée, personnage seul centré, ~64x64 pixels, palette or/ivoire limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**archangel.png**
```
Pixel art authentique d'un puissant archange aux larges ailes blanches et à l'épée à deux mains enflammée, personnage seul centré, ~64x64 pixels, palette or/ivoire limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**seraph.png**
```
Pixel art authentique d'un séraphin à six ailes de pure lumière, sans visage et serein, éclat aveuglant, créature seule centrée, ~64x64 pixels, palette or/ivoire limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

---

# C. Cartes — sorts → dossier `assets/sprites/cards/<id>.png`

*(64x64, un effet/objet magique, pas de personnage, fond transparent)*

**fireball.png**
```
Pixel art authentique d'une boule de feu rugissante fonçant en avant, laissant une spirale de fumée, effet seul centré, ~64x64 pixels, palette chaude limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**inferno.png**
```
Pixel art authentique d'un mur de flammes engloutissant un champ de bataille, silhouettes de braises, effet seul centré, ~64x64 pixels, palette chaude limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**rejuvenate.png**
```
Pixel art authentique de sève verte lumineuse et de fleurs tourbillonnant autour d'une lumière de soin, effet seul centré, ~64x64 pixels, palette verte limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**wild_growth.png**
```
Pixel art authentique de lianes et de fleurs jaillissant vers le haut, débordant de vie, effet seul centré, ~64x64 pixels, palette verte limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**dark_pact.png**
```
Pixel art authentique d'une main d'ombre et d'une main mortelle se serrant au-dessus d'une bougie noire (pacte), effet seul centré, ~64x64 pixels, palette violette/indigo limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**life_drain.png**
```
Pixel art authentique d'un flux d'essence vitale cramoisie s'écoulant d'une fleur fanée vers un orbe sombre, effet seul centré, ~64x64 pixels, palette violette et rouge limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**blessing.png**
```
Pixel art authentique d'un rayon de lumière chaude descendant en un dôme-bouclier translucide (bénédiction), effet seul centré, ~64x64 pixels, palette or/ivoire limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

**holy_charge.png**
```
Pixel art authentique d'une bannière radieuse chargeant en avant avec des traînées de lumière dorée, effet seul centré, ~64x64 pixels, palette or/ivoire limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte ni cadre. PNG.
```

---

# D. Portraits de maîtres → dossier `assets/portraits/<id>.png`

*(cadrage buste, regard vers le joueur, ~64x80, fond transparent)*

**aria.png**
```
Pixel art authentique d'un portrait en buste d'Aria, héroïne paladine blonde à l'auréole dorée, armure blanc-or, visage doux et brave, regard vers le joueur, ~64x80 pixels, palette or/ivoire limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte. PNG.
```

**kiran.png**
```
Pixel art authentique d'un portrait en buste de Kiran, mage de feu aux cheveux roux, yeux éclairés de braises, sourire confiant, regard vers le joueur, ~64x80 pixels, palette chaude limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte. PNG.
```

**grim.png**
```
Pixel art authentique d'un portrait en buste de Grim, nécromancien encapuchonné au visage pâle, lueur violette, regard froid, regard vers le joueur, ~64x80 pixels, palette violette/indigo limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte. PNG.
```

**willow.png**
```
Pixel art authentique d'un portrait en buste de Willow, druidesse sereine vêtue de vert, feuilles et bois de cerf, expression calme et sage, regard vers le joueur, ~64x80 pixels, palette verte limitée (<=16 couleurs), aucun anti-aliasing, contours nets, dark-fantasy, fond transparent, aucun texte. PNG.
```
