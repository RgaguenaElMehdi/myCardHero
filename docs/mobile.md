# Version mobile (Android) — Stonebound

Le jeu (tour-par-tour, UI qui s'adapte, `gl_compatibility`) est un bon candidat
mobile. Le multijoueur en ligne marche aussi sur mobile (ENet/UDP) — un joueur
Android peut être apparié avec un joueur PC (cross-play, même serveur).

## Déjà configuré dans le dépôt
- **Mise à l'échelle** : `stretch/mode = canvas_items`, `aspect = expand` → l'UI
  1920×1080 s'adapte à n'importe quel écran.
- **Orientation** : `handheld/orientation = landscape` (paysage).
- **Tactile** : `emulate_mouse_from_touch = true` → les taps agissent comme des clics.
- **Appui long = inspecter** : maintenir ~0.5 s une carte (main) ou une unité
  (plateau) ouvre sa fiche — l'équivalent tactile du clic droit. (Toucher = jouer/
  sélectionner ; maintenir = inspecter.) Voir `card_widget.gd` / `board_cell.gd`.
- **Rendu** `gl_compatibility` (OpenGL ES 3) : compatibilité maximale des appareils.
- Icône d'app présente (`assets/sprites/ui/app_icon.png`).

## Prérequis (depuis Windows — gratuit)
1. **JDK 17** (Temurin/Adoptium).
2. **Android SDK** : le plus simple = installer **Android Studio**, puis via le SDK
   Manager : *SDK Platform* récent + *Android SDK Build-Tools* + *Platform-Tools* +
   *NDK* + *Command-line Tools*.
3. Dans Godot : **Éditeur → Gérer les modèles d'export** → installer les *Export
   Templates* de la version (4.6.1).
4. **Godot Android Build Template** : *Projet → Installer le modèle de build Android*.
5. **Clés (keystore)** :
   - Debug (tests) : Godot peut en générer une automatiquement.
   - Release (Play Store) : `keytool -genkey -v -keystore stonebound.keystore
     -alias stonebound -keyalg RSA -keysize 2048 -validity 10000` (garde-la hors du dépôt).

## Configurer l'export
Dans **Éditeur → Paramètres de l'éditeur → Export → Android** : renseigner le
chemin du **SDK Android** (et JDK). Puis **Projet → Exporter → Ajouter → Android** :
- **Unique Name** : ex. `com.tonstudio.stonebound`.
- **Renderer** : Compatibility (déjà le cas).
- **Keystore Debug/Release** : pointer les clés.
- Architectures : `arm64-v8a` (téléphones récents) — désactiver x86 si inutile.

## Builder / tester
- **Sur un téléphone en USB** (débogage USB activé) : bouton **« Run on remote
  Android device »** (l'icône Android dans la barre de l'éditeur) → build + déploie +
  lance en un clic.
- **APK/AAB** : *Exporter le projet* → `.apk` (test/side-load) ou `.aab` (Play Store).

## Points à surveiller après le 1er build
- **Taille des cibles tactiles** : le design paysage scalé sur petit écran peut
  rendre certains boutons/cartes petits (deck builder surtout). Si gênant : agrandir
  les zones ou passer à un layout adaptatif (travail par écran).
- **Zones sûres / encoche** : décaler les boutons de coin si masqués par le notch
  (`DisplayServer.get_display_safe_area()`).
- **Mémoire textures** : si besoin, activer la compression VRAM (ETC2/ASTC) dans les
  réglages d'import des gros PNG.

## iOS
Nécessite un **Mac** + Xcode + compte développeur Apple (99 $/an). Le code est prêt
(même moteur), mais l'export/signature ne se fait pas depuis Windows.
