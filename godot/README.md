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
| Glisser dans la pièce | tourner la tête à 360° depuis le fauteuil |
| ← → | tourner d'un huitième de tour |
| Clic sur une machine (ou touches 1–6) | zoom sur la machine |
| Clic dans le vide / balayer / Échap | revenir dans la pièce |
| PageUp / PageDown | machine précédente / suivante |
| Cmd+K ou / · Cmd+, | rechercher une machine · réglages |
| F (ou Cmd+F) | plein écran |
| T | garder la fenêtre au premier plan (à côté du DAW) |

**Module Tempo** (section accolée à droite de la console) : clic dessus pour zoomer, puis glisser ou
molette sur le gros potard (Maj = fin), ↑/↓, pad TAP ou Espace, sélecteur NOTE (clic, molette ou N),
÷2 / ×2, clic sur l'afficheur des ms (ou C) = copie de la valeur dans le presse-papiers.

**Accordeur 808** (petit boîtier sur le pont de la console, à gauche) : glisse un sample de 808 / kick
(WAV, MP3, AIFF…) sur la fenêtre, ou CHARGER / L ; ÉCOUTE / Espace le rejoue : l'aiguille donne l'écart en cents, la lampe de la note s'allume, l'octave et la
fréquence s'affichent.

**Analyse** (magnéto + écran vert sur le retour) : glisse un morceau ou une prod (ou CHARGER / L) : les
bobines tournent pendant l'analyse, puis l'écran donne le BPM (+ moitié / double) et la tonalité (+ autres
possibilités et relative). LECTURE / Espace pour écouter, STOP / S. Les fichiers longs glissés n'importe où
vont à l'analyse, les courts à l'accordeur. Les MP3 / AIFF sont convertis avec `afconvert` (fourni avec macOS).

**Fréquences** (petit synthé sur un support au mur, au-dessus du retour) : clic sur une touche = note +
fréquence (et la note est jouée) ; OCT − / + (ou Z / X) ; mode HZ → NOTE : potard FREQ (glisser / molette) ou
taper des chiffres + Entrée → note la plus proche + cents ; curseur LA4 = diapason 430–450 Hz ; PLAY / Espace.

**Export** (tableau en liège au mur de droite) :
- fiche SESSION : clic sur Artiste / Titre puis taper (Entrée = ligne suivante) ; clic ou molette sur Version,
  Fréquence (44.1 / 48 / 88.2 / 96 kHz) et Format (WAV 16 / 24 / 32f, AIFF 24, MP3 320) ; pastilles v− / v+ ;
- étiquettes ORDRE DU NOM : glisser une étiquette sur une autre pour changer l'ordre des éléments du nom ;
- post-it MIX et MASTER : nom prêt à coller (« Artiste - Titre [Mix] 48kHz 24bit v3 » par défaut) ; clic = copié
  dans le presse-papiers + coché « exporté » ;
- ARCHIVES : pastille « + » = nouvelle session (l'ancienne part dans la pile) ; clic sur une fiche de la pile = la rouvrir.

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
