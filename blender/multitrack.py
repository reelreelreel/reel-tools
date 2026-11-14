"""Magnéto multipiste 2" 24 pistes sur pied (fin des années 70).
Caisse gris acier sur socle à roulettes, joues en noyer, platine inclinée (bobines NAB 14" à trois
fenêtres, galettes de bande, bras de tension, bloc de têtes effacement / enregistrement / lecture,
cabestan + galet presseur, chemin de bande, touches de transport, compteur), pont de 24 VU-mètres.
Faces imprimées (UV à plat) : mt_face, mt_plate, mt_counter, mt_vu — dessinées dans Godot.
Origine : milieu du sol ; l'avant regarde -Y.
"""
import sys, math
sys.path.insert(0, __file__.rsplit("/", 1)[0])
import bpy, bmesh
from mathutils import Vector
import lib
from lib import box, cyl, lathe, extrude_profile, tube, empty, planar_uv

OUT = __file__.rsplit("/", 2)[0] + "/godot/assets/models/"
for n, c in (("steel", ((.55, .54, .5), .6, .45)), ("mt_face", ((.55, .54, .5), .5, .5)), ("mt_plate", ((.7, .69, .65), .6, .4)),
             ("mt_counter", ((.3, .02, .02), 0, .3)), ("mt_vu", ((.9, .85, .7), 0, .5)), ("tape", ((.16, .1, .07), 0, .55)),
             ("key_dark", ((.04, .04, .04), 0, .35)), ("key_green", ((.1, .3, .1), 0, .35)), ("key_red", ((.6, .08, .05), 0, .35))):
    lib.PREVIEW[n] = c

W, D = 1.02, .72
lib.reset()
root = empty("Multitrack")


def quad(name, w, h, mat, parent, loc, axis="Y"):
    bm = bmesh.new()
    if axis == "Y":
        vs = [bm.verts.new(v) for v in ((-w / 2, 0, -h / 2), (w / 2, 0, -h / 2), (w / 2, 0, h / 2), (-w / 2, 0, h / 2))]
    else:
        vs = [bm.verts.new(v) for v in ((-w / 2, -h / 2, 0), (w / 2, -h / 2, 0), (w / 2, h / 2, 0), (-w / 2, h / 2, 0))]
    bm.faces.new(vs)
    o = lib.obj_from_bm(name, bm, mat, parent)
    o.location = loc
    planar_uv(o, axis if axis == "Y" else "Z")
    return o


# ---------------------------------------------------------------- socle à roulettes + caisse
box("Base", (W - .06, D - .06, .07), (0, 0, .085), "black", root, bev=.008)
for sx in (-1, 1):
    for sy in (-1, 1):
        c = empty("Caster", (sx * (W / 2 - .09), sy * (D / 2 - .09), 0), root)
        cyl("Plate", .03, .006, (0, 0, .047), "chrome", c, segs=20, bev=.001)
        for side in (-1, 1):
            box("Fork", (.004, .03, .035), (side * .014, 0, .03), "chrome", c, bev=.001)
        cyl("Wheel", .024, .02, (0, 0, .025), "rubber", c, segs=24, axis="X", bev=.004)
body = box("Body", (W - .06, D - .04, .7), (0, 0, .12 + .35), "steel", root, bev=.01, seg=3)
# façade : cadre en relief + panneau imprimé (ouïes) + vis
box("FaceFrame", (W - .08, .012, .66), (0, -D / 2 + .016, .47), "steel", root, bev=.006)
quad("Face", W - .14, .6, "mt_face", root, (0, -D / 2 + .0095, .47))
for sx in (-1, 1):
    for sz in (-1, 1):
        cyl("Screw", .005, .004, (sx * (W / 2 - .07), -D / 2 + .008, .47 + sz * .31), "chrome", root, segs=12, axis="Y", bev=.0012)
# joues en noyer, galbées en haut
cheek = [(-D / 2, 0), (D / 2, 0), (D / 2, .9), (D / 2 - .04, .94), (-D / 2 + .1, .86), (-D / 2 + .03, .82), (-D / 2, .78)]
for sx in (-1, 1):
    extrude_profile("Cheek", cheek, .03, "walnut", root, loc=(sx * (W / 2 - .015), 0, .06), bev=.008, seg=3)

# ---------------------------------------------------------------- platine inclinée
deck = empty("Deck", (0, -.02, .84), root)
deck.rotation_euler = (.22, 0, 0)
box("DeckBody", (W - .06, .66, .02), (0, 0, -.01), "black", deck, bev=.004)
quad("Plate", W - .07, .65, "mt_plate", deck, (0, 0, .0005), axis="Z")
cnt = quad("Counter", .13, .032, "mt_counter", deck, (.005, -.17, .0012), axis="Z")
box("CounterBezel", (.142, .044, .004), (.005, -.17, .0005), "black", deck, bev=.0015)


def flange(name, r, parent, z):
    f = cyl(name, r, .0022, (0, 0, z), "alu", parent, segs=96, bev=.0008, seg=1)
    cutters = []
    for k in range(3):
        a = k / 3 * math.tau + .3
        bm = bmesh.new()
        pts = []
        for t in range(9):
            aa = a - .62 + 1.24 * t / 8
            pts.append((math.cos(aa) * r * .86, math.sin(aa) * r * .86))
        for t in range(9):
            aa = a + .5 - 1.0 * t / 8
            pts.append((math.cos(aa) * r * .36, math.sin(aa) * r * .36))
        top = [bm.verts.new((x, y, .02)) for x, y in pts]
        bot = [bm.verts.new((x, y, -.02)) for x, y in pts]
        bm.faces.new(top)
        bm.faces.new(list(reversed(bot)))
        for i in range(len(pts)):
            j = (i + 1) % len(pts)
            bm.faces.new([bot[i], bot[j], top[j], top[i]])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        c = lib.obj_from_bm("cut", bm, "black")
        c.parent = parent
        c.location = (0, 0, z)
        cutters.append(c)
    lib.cut(f, cutters)
    return f


for sx in (-1, 1):
    reel = empty("Reel", (sx * .26, .08, .012), deck)
    cyl("Hub", .035, .03, (0, 0, .015), "chrome", reel, segs=32, bev=.002)
    cyl("HubCap", .02, .006, (0, 0, .033), "black", reel, segs=24, bev=.001)
    rr = .115 if sx < 0 else .085
    cyl("TapePack", rr, .051, (0, 0, .0325), "tape", reel, segs=64)
    for fz in (.006, .059):
        flange("Flange", .178, reel, fz)
    # bras de tension avec galet
    arm = box("TensionArm", (.012, .1, .01), (sx * .12, -.17, .015), "chrome", deck, bev=.002)
    arm.rotation_euler = (0, 0, -sx * .5)
    cyl("Roller", .012, .03, (sx * .15, -.21, .03), "chrome", deck, segs=24, bev=.002)
# bloc de têtes : capot + trois têtes galbées (entrefer sombre)
box("HeadBlock", (.22, .075, .05), (0, -.1, .025), "black", deck, bev=.006)
for i in range(3):
    h = lathe("Head", [(0, -.02), (.016, -.02), (.017, .0), (.015, .016), (0, .018)], "chrome", deck, segs=32)
    h.scale = (1.0, .75, 1.2)
    h.location = (-.06 + i * .06, -.135, .055)
    box("Gap", (.0006, .02, .03), (-.06 + i * .06, -.147, .06), "black", deck)
cyl("Capstan", .0055, .06, (.13, -.14, .04), "chrome", deck, segs=16)
cyl("PinchRoller", .022, .05, (.165, -.14, .04), "rubber", deck, segs=32, bev=.004)
# chemin de bande (ruban fin)
path = [(-.16, -.0, .045), (-.15, -.2, .045), (0, -.152, .045), (.15, -.2, .045), (.19, .03, .045)]
for i in range(len(path) - 1):
    a, b = Vector(path[i]), Vector(path[i + 1])
    m = (a + b) / 2
    seg = box("Tape", (.0015, (b - a).length, .05), m, "tape", deck)
    seg.rotation_euler = (0, 0, math.atan2(-(b.x - a.x), b.y - a.y))
# touches de transport
for i, km in enumerate(("key_dark", "key_dark", "key_dark", "key_green", "key_red")):
    box("Key", (.06, .035, .016), (-.21 + i * .093, -.27, .008), km, deck, bev=.004, seg=2)

# ---------------------------------------------------------------- pont de VU-mètres
br = empty("Bridge", (0, .28, .94), root)
br.rotation_euler = (.1, 0, 0)
box("BridgeBody", (W - .02, .14, .36), (0, 0, .18), "black", br, bev=.008)
box("BridgeCap", (W, .16, .03), (0, 0, .375), "walnut", br, bev=.008)
quad("VU", W - .08, .33, "mt_vu", br, (0, -.0705, .18))
box("VUGlass", (W - .08, .003, .33), (0, -.074, .18), "glass", br)
for sz in (-1, 1):
    box("VUBezel", (W - .06, .01, .012), (0, -.074, .18 + sz * .171), "steel", br, bev=.003)
for sx in (-1, 1):
    box("VUBezel", (.012, .01, .35), (sx * (W / 2 - .035), -.074, .18), "steel", br, bev=.003)

lib.export(OUT + "multitrack.glb")
if "--preview" in sys.argv:
    lib.preview("/tmp/mt_preview.png", (.9, -1.6, 1.35), (0, 0, .8), lens=35, samples=20, light_energy=150)
