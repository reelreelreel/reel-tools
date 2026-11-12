# REEL'S TOOLS — appli Godot (Mac)

Le studio 70/80 reconstruit dans Godot 4 d'après le prototype three.js (`prototypes/studio-face/`).
Tout est généré par le code : modèles 3D, textures sérigraphiées, écrans. Seules deux textures CC0
(bois de l'établi, rayures) et trois polices libres (OFL) sont des fichiers.

## Ouvrir le projet
1. Godot 4.7 (Forward+) — le projet a été testé avec cette version.
2. Godot > Importer > choisir `godot/project.godot` > Importer et éditer.
3. Lancer avec ▶ (F5). Le premier lancement prend quelques secondes (cuisson des textures).

## Commandes
| | |
|---|---|
| Clic sur une machine | zoom sur la machine |
| Clic dans le vide / Échap | plan large |
| Glisser, ← → ou PageUp / PageDown | machine précédente / suivante |
| F (ou Cmd+F) | plein écran |
| T | garder la fenêtre au premier plan (à côté du DAW) |

**RT-140 (Tempo)**, une fois zoomé : glisser ou molette sur le gros potard (Maj = 0,1 BPM), ↑/↓,
Espace ou pad TAP pour taper le tempo, sélecteur NOTE (ou touche N), ÷2 / ×2,
clic sur l'afficheur vert = copie la valeur en ms dans le presse-papiers.

Le BPM, la note et le dernier plan sont gardés en local (`user://reel_tools.cfg`).

## Organisation
```
core/            commun à tous les studios
  main.gd          caméra, navigation, clic/clavier
  tempo_engine.gd  logique du module Tempo (BPM, tap, ms)
  mk.gd            modélisation par le code (boîtes arrondies, tours, tubes, potards, écrans…)
  tex.gd           textures dessinées par le code (sérigraphie, bois, LED 7 segments)
  overlay.gd       grain, vignettage, écran de démarrage
  shaders/         écran VFD à points, écrans émissifs, grain
studios/s7080/   le studio 70/80 (un dossier par studio-skin)
  studio_7080.gd   pièce, lumières, post-traitement, disposition, plans caméra
  rt_*.gd          une machine par fichier
```
Les 6 autres studios (90, 2000, 2020, cyberpunk, post-apo, nature) suivront le même modèle :
mêmes emplacements (`L`) et mêmes plans, style différent.

## Captures sans écran (pour les vérifs)
```
godot --path godot -- --screenshot=/tmp/shots/ --shots=overview,tempo,synth --frames=30
godot --path godot -- --selftest
```
