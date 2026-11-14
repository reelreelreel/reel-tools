"""Meuble de console (plateau central + ailes) — modèle détaillé.
Plateau en noyer à chant mouluré (doucine), accoudoir cuir capitonné avec passepoil, repose-pieds en
laiton sur équerres, panneau de fond. Les baies 19" restent construites dans Godot (avec le matériel).
Deux fichiers : desk_main.glb (2.56 x 1.29) et desk_wing.glb (.85 x .8). Origine : milieu du sol,
avant vers -Y, dessus du plateau à .818.
"""
import sys, math
sys.path.insert(0, __file__.rsplit("/", 1)[0])
import bpy, bmesh
from mathutils import Vector
import lib
from lib import box, extrude_profile, tube, empty, cyl

TOP, T = .818, .06
OUT = __file__.rsplit("/", 2)[0] + "/godot/assets/models/"


def ogee(h):
    """Chant avant mouluré (doucine) : profil (y, z), y < 0 vers l'avant."""
    pts = [(0.0, 0.0), (0.0, h)]
    for i in range(13):
        t = i / 12
        y = -.022 * (math.sin(t * math.pi / 2) ** 1.4)
        z = h - .004 - (h * .55) * t + .006 * math.sin(t * math.pi)
        pts.append((y, z))
    pts += [(-.022, h * .38), (-.016, h * .22), (-.016, .0)]
    out = []
    for p in pts:
        if not out or (abs(out[-1][0] - p[0]) > 1e-5 or abs(out[-1][1] - p[1]) > 1e-5):
            out.append(p)
    return out


def desk(name, W, D, footrest=True, kneehole=0.0):
    lib.reset()
    root = empty(name)
    # plateau : âme + chant avant mouluré + chants latéraux arrondis
    box("Top", (W, D - .02, T), (0, .01, TOP - T / 2), "walnut", root, bev=.006, seg=3)
    prof = [(y, z + TOP - T) for y, z in ogee(T)]
    extrude_profile("Edge", list(reversed(prof)), W, "walnut", root, loc=(0, -D / 2 + .02, 0), bev=.0015, seg=2)
    # filet de laiton sous le chant
    box("Inlay", (W - .01, .003, .004), (0, -D / 2 + .003, TOP - T + .004), "brass", root)
    # accoudoir capitonné (cuir) devant, sur une lisse en noyer
    ar = lib.obj_from_bm("Armrest", lib.armrest(W - .08, w=.12, h=.07, pleat=.14), "leather_cognac", root, 60)
    ar.location = (0, -D / 2 - .055, TOP - .04)
    for yy, zz in ((-.058, .022), (.058, .022)):
        tube("Piping", [(-(W - .08) / 2 + .02, -D / 2 - .055 + yy, TOP - .04 + zz), (0, -D / 2 - .055 + yy, TOP - .04 + zz + .001), ((W - .08) / 2 - .02, -D / 2 - .055 + yy, TOP - .04 + zz)], .003, "leather_cognac", root, res=6, segs=8)
    box("ArmRail", (W - .06, .1, .018), (0, -D / 2 - .05, TOP - .085), "walnut", root, bev=.005)
    # boutons de capitonnage (petits clous gainés) entre les boudins
    n = int((W - .08) / .14)
    for i in range(1, n):
        x = -(W - .08) / 2 + i * (W - .08) / n
        cyl("Button", .006, .004, (x, -D / 2 - .055, TOP - .04 + .036), "leather_cognac", root, segs=12, bev=.0015)
    if kneehole > 0:
        # panneau de fond du passage des jambes + repose-pieds en laiton sur deux équerres
        box("KneePanel", (kneehole, .02, TOP - T), (0, D / 2 - .03, (TOP - T) / 2), "walnut", root, bev=.004)
        box("KneeTop", (kneehole, D - .05, .03), (0, 0, TOP - T - .015), "black", root)
        if footrest:
            for sx in (-1, 1):
                x = sx * (kneehole / 2 - .05)
                tube("FootBracket", [(x, D / 2 - .03, .1), (x, D / 2 - .2, .1), (x, -D / 2 + .35, .14)], .007, "brass", root, res=6, segs=16)
            cyl("FootRail", .013, kneehole - .06, (0, -D / 2 + .35, .14), "brass", root, segs=24, axis="X", bev=.002)
            for sx in (-1, 1):
                cyl("FootCap", .016, .012, (sx * (kneehole / 2 - .03), -D / 2 + .35, .14), "brass", root, segs=24, axis="X", bev=.003)
    return root


desk("DeskMain", 2.56, 1.29, kneehole=2.56 - 1.36)
lib.export(OUT + "desk_main.glb")
if "--preview" in sys.argv:
    lib.preview("/tmp/desk_preview.png", (.9, -2.0, 1.15), (0, -.4, .6), lens=35, samples=20, light_energy=150)
desk("DeskWing", .85, .8, footrest=False)
lib.export(OUT + "desk_wing.glb")
desk("DeskSide", 1.98, .62, footrest=False)
lib.export(OUT + "desk_side.glb")
