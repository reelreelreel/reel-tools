# REEL'S TOOLS — appli Godot (Mac)

Le studio 70/80 (régie pro) dans Godot 4, cadrage repris de la scène Blender `assets/reference_blender_vue.glb`.
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

**Module Tempo** (section accolée à droite de la console) : clic dessus pour zoomer, puis glisser ou
molette sur le gros potard (Maj = fin), ↑/↓, pad TAP ou Espace, sélecteur NOTE (clic, molette ou N),
÷2 / ×2, clic sur l'afficheur des ms (ou C) = copie de la valeur dans le presse-papiers.

**Accordeur 808** (petit boîtier sur le pont de la console) : glisse un WAV de 808 / kick sur la fenêtre
(ou clic sur CHARGER, ou L) : l'aiguille donne l'écart en cents, la lampe de la note s'allume, l'octave et la
fréquence s'affichent.

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
