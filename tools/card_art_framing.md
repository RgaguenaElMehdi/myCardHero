# Cadrage des illustrations de carte (cards/*.png)

La fenêtre d'art de la carte composée est **paysage** : ~906×519 px (ratio **1.75:1**).
`build_cards.py` fait un **cover-fit** puis crop en gardant une bande depuis le haut
(`cy = (hauteur - fenêtre) // 6`, cf. `compose_card`). Selon le format source :

- **Source portrait 1024×1536** → seule la bande **~10 %–48 %** de la hauteur reste visible.
- **Source paysage 1536×1024** → **~2 %–88 %** reste visible (quasi tout).

Donc **le format de l'art doit suivre la forme du sujet**, sinon on coupe ou on zoome trop :

| Type de sujet | Format à générer | Cadrage |
|---|---|---|
| **Humanoïde** (perso, mage, chevalier…) | Portrait **1024×1536** | **Plan taille / trois-quarts** : tête tout en HAUT du cadre, torse + bras jusqu'à la taille. **Pas de gros plan visage** (sinon la carte ne montre que la tête). |
| **Quadrupède / créature large** (loup, golem, dragon…) | Paysage **1536×1024** | Corps **entier** de profil/trois-quarts, remplit le cadre horizontal. Rentre pile dans la fenêtre. |
| **Sort / effet** (pas de personnage) | Portrait **1024×1536** | Élément central bien **centré**, placé dans la **moitié supérieure** du cadre. |

Règles communes à chaque prompt : pixel art anime 16-bit détaillé, contours nets,
éclairage dramatique, **plein cadre**, **AUCUN texte, AUCUN cadre de carte, AUCUNE bordure,
aucun filigrane**.

Après génération : déposer dans `assets/sprites/cards/<id>.png` puis
`python tools/build_cards.py --only <id>` pour recomposer `cards_full/<id>.png`.
