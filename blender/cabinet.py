"""Caissons de baie 19" sous les plateaux (meuble de console, ailes, bureau producteur).
Caisse en noyer : côtés à panneau en relief (cadre + panneau chanfreiné), cadre de façade mouluré,
corniche sous le plateau, plinthe en retrait avec quart-de-rond. L'ouverture, les rails et le
matériel restent faits dans Godot. Origine : bas de la façade, au milieu ; la caisse va vers +Y
(l'avant regarde -Y). Fichiers : cab_<largeur>x<profondeur>.glb
"""
import sys, math
sys.path.insert(0, __file__.rsplit("/", 1)[0])
import bpy
import lib
from lib import box, extrude_profile, empty

H = .758
KICK = .07
OUT = __file__.rsplit("/", 2)[0] + "/godot/assets/models/"


def cabinet(w, d):
    lib.reset()
    root = empty("RackCabinet")
    fh = H - KICK
    # plinthe en retrait (sombre)
    box("Plinth", (w - .04, d - .06, KICK), (0, d / 2 + .03, KICK / 2), "black", root)
    # caisse : dessus + fond + côtés à panneau en relief
    box("Back", (w - .03, .015, fh), (0, d - .0075, KICK + fh / 2), "walnut", root, bev=.002)
    box("Top", (w, d, .02), (0, d / 2, H - .01), "walnut", root, bev=.004)
    for sx in (-1, 1):
        x = sx * (w / 2 - .009)
        box("SideCore", (.018, d - .01, fh - .02), (x, d / 2 + .005, KICK + fh / 2 - .01), "walnut", root, bev=.002)
        # cadre du côté (montants + traverses) et panneau chanfreiné en relief
        xo = sx * (w / 2 + .001)
        for yy in (.03, d - .03):
            box("SideStile", (.012, .06, fh - .02), (xo, yy, KICK + fh / 2 - .01), "walnut", root, bev=.003)
        for zz in (KICK + .03, H - .05):
            box("SideRail", (.012, d - .06, .06), (xo, d / 2, zz), "walnut", root, bev=.003)
        pan = box("SidePanel", (.012, d - .16, fh - .2), (sx * (w / 2 + .0035), d / 2, KICK + fh / 2 - .01), "walnut", root)
        lib.bevel(pan, .012, 2, 60)
    # cadre de façade : montants, traverse haute, traverse basse
    fw = .03
    for sx in (-1, 1):
        box("FaceStile", (fw, .02, fh), (sx * (w / 2 - fw / 2), -.006, KICK + fh / 2), "walnut", root, bev=.004, seg=3)
    # joues de remplissage entre le cadre et l'ouverture 19" (482,6 mm)
    half = .483 / 2 + .002
    fill = (w - 2 * fw) / 2 - half
    if fill > .004:
        for sx in (-1, 1):
            box("FaceFill", (fill + .004, .016, fh - .02), (sx * (half + fill / 2), -.004, KICK + fh / 2), "walnut", root, bev=.003, seg=2)
    box("FaceTop", (w - 2 * fw, .02, .035), (0, -.006, H - .0175), "walnut", root, bev=.004, seg=3)
    box("FaceBottom", (w - 2 * fw, .02, .025), (0, -.006, KICK + .0125), "walnut", root, bev=.004, seg=3)
    # moulure de corniche sous le plateau + quart-de-rond au-dessus de la plinthe
    cove = [(0, 0), (-.018, 0), (-.018, .004)] + [(-.018 + .014 * (1 - math.cos(t / 8 * math.pi / 2)), .004 + .014 * math.sin(t / 8 * math.pi / 2)) for t in range(1, 9)] + [(0, .018)]
    extrude_profile("Cornice", cove, w + .01, "walnut", root, loc=(0, -.01, H - .036), bev=.001, seg=1)
    qr = [(0, 0), (-.016, 0)] + [(-.016 * math.cos(t / 8 * math.pi / 2), .016 * math.sin(t / 8 * math.pi / 2)) for t in range(1, 8)] + [(0, .016)]
    extrude_profile("BaseMould", qr, w + .006, "walnut", root, loc=(0, -.012, KICK - .004), bev=.0008, seg=1)
    lib.export(OUT + "cab_%dx%d.glb" % (round(w * 100), round(d * 100)))


SIZES = [(.66, 1.25), (.83, .76), (.98, .58)]
for w, d in SIZES:
    cabinet(w, d)
if "--preview" in sys.argv:
    cabinet(.83, .76)
    lib.preview("/tmp/cab_preview.png", (.9, -1.2, .9), (0, .3, .4), lens=35, samples=20, light_energy=120)
