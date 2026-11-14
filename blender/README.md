# Modèles Blender de REEL'S TOOLS

Les meubles et machines détaillés sont modélisés par script avec Blender (module Python `bpy`,
`pip install bpy`), puis exportés en `.glb` dans `godot/assets/models/`.

- `lib.py` : outils (boîtes arrondies, profils extrudés ou tournés, tubes, accoudoir capitonné, UV
  à plat, export glTF, aperçu Cycles).
- `console_8028.py` : la console 24 voies (modules de voie séparés, potards moletés, faders, pont de
  VU, baie de brassage, joues en noyer, accoudoir cuir).
- `desk.py` : le meuble de console (plateau à chant mouluré, accoudoir capitonné, repose-pieds) et les
  ailes.

Lancer : `python3 blender/console_8028.py --preview` (l'aperçu va dans /tmp).

Chaque matériau porte un nom (`walnut`, `leather`, `body`, `deck_print`…) : dans Godot,
`Props.model(fichier, {nom: matériau})` le remplace par le vrai matériau de la scène.
Avant de la console : -Y dans Blender = +Z dans Godot.
