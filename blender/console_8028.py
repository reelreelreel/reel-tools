"""Console 8028 (façon grande console anglaise des années 70) — modèle détaillé.
Origine : milieu du bas, avant vers -Y. Dimensions identiques à l'ancienne console du code
(L 2.20, D .74, 24 voies + section master), pour que tout le reste de la pièce reste en place.
Usage : python3 console_8028.py [--preview]
"""
import sys, math, random
sys.path.insert(0, __file__.rsplit("/", 1)[0])
import bpy, bmesh
from mathutils import Vector
import lib
from lib import mat, box, cyl, lathe, extrude_profile, tube, empty, bevel, smooth, planar_uv

L, D, N = 2.2, .74, 24
MASTER = .2
ZF, ZB = .045, .12            # hauteur du pupitre devant / derrière
SW = (L - .02 - MASTER) / N
SLOPE = math.atan2(ZB - ZF, D)
PLEN = math.hypot(D, ZB - ZF)
ROWS = 8
rnd = random.Random(31)

lib.reset()
root = empty("Console8028")

# ---------------------------------------------------------------- caisse et joues
body = extrude_profile("Body", [(-D / 2, 0), (D / 2, 0), (D / 2, ZB - .004), (-D / 2, ZF - .004)], L, "body", root, bev=.004)
# nez arrondi sous l'accoudoir
extrude_profile("Nose", [(-D / 2 - .015, 0), (-D / 2 + .01, 0), (-D / 2 + .01, .03), (-D / 2 - .015, .022)], L + .04, "walnut", root, bev=.006)
cheek = [(-.405, 0), (.39, 0), (.39, .262), (.372, .305), (.33, .318), (.29, .3), (.22, .2), (.0, .118), (-.33, .078), (-.385, .072), (-.405, .05)]
for sx in (-1, 1):
    extrude_profile("Cheek", cheek, .028, "walnut", root, loc=(sx * (L / 2 + .014), 0, 0), bev=.006, seg=4)
    # filet de laiton incrusté sur le dessus de la joue
    box("CheekInlay", (.004, .5, .0015), (sx * (L / 2 + .014), -.08, .101), "brass", root, rot=(math.atan2(.04, .33), 0, 0))

# ---------------------------------------------------------------- accoudoir cuir capitonné
ar = lib.obj_from_bm("Armrest", lib.armrest(L + .03), "leather", root, 60)
ar.location = (0, -D / 2 - .028, .055)
# passepoil (piping) le long des coutures haut-avant et haut-arrière
for yy, zz in ((-.026, .02), (.026, .02)):
    tube("Piping", [(-L / 2, -D / 2 - .028 + yy, .055 + zz), (0, -D / 2 - .028 + yy, .055 + zz + .0005), (L / 2, -D / 2 - .028 + yy, .055 + zz)], .0022, "leather", root, res=6, segs=8)

# ---------------------------------------------------------------- pupitre (face imprimée + modules)
deck = empty("Deck", (0, 0, (ZB + ZF) / 2), root)
deck.rotation_euler = (SLOPE, 0, 0)       # Y local = le long de la pente vers l'arrière, Z local = normale
w2, p2 = (L - .02) / 2, PLEN / 2
# modules de voie : une plaque par tranche (vrais joints entre les modules), plaque master à droite.
# Une seule texture imprimée pour tout le pupitre : les UV viennent de la position sur le pupitre.
bm = bmesh.new()
def plate(x0, x1, y0, y1, th=.0024):
    r = bmesh.ops.create_cube(bm, size=1.0)
    vs = r["verts"]
    bmesh.ops.scale(bm, vec=Vector((x1 - x0, y1 - y0, th)), verts=vs)
    bmesh.ops.translate(bm, vec=Vector(((x0 + x1) / 2, (y0 + y1) / 2, th / 2)), verts=vs)
gap = .0007
for i in range(N):
    x0 = -w2 + i * SW
    plate(x0 + gap, x0 + SW - gap, -p2 + .002, p2 - .002)
plate(-w2 + N * SW + gap, w2 - gap, -p2 + .002, p2 - .002)
face = lib.obj_from_bm("DeckFace", bm, "deck_print", deck)
bevel(face, .0007, 2, 40)
me = face.data
uvl = me.uv_layers.new()
for poly in me.polygons:
    for li in poly.loop_indices:
        co = me.vertices[me.loops[li].vertex_index].co
        uvl.data[li].uv = ((co.x + w2) / (2 * w2), (co.y + p2) / (2 * p2))
# fond sombre visible dans les joints
box("DeckBed", (L - .016, PLEN - .002, .001), (0, 0, .0004), "black", deck)
H0 = .0024  # dessus des plaques

def t_of(row):  # position le long de la pente (Y local), même rangées que l'ancienne console
    return -(-PLEN / 2 + .035 + row * .034)

# maillages partagés (instances) ----------------------------------------
def knob_mesh():
    bm = bmesh.new()
    segs = 40
    prof = [(0, 0), (.0094, 0), (.0094, .0010), (.0090, .0024), (.0064, .0028),     # jupe
            (.0063, .003), (.0063, .0105), (.0060, .0118), (.0054, .0124), (0, .0125)]  # corps moleté + dessus
    rings = []
    for j in range(segs):
        a = j / segs * math.tau
        knurl = .94 if j % 2 else 1.0
        ring = []
        for i, (r, z) in enumerate(prof):
            rr = r * (knurl if 5 <= i <= 6 else 1.0)
            ring.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a), z)))
        rings.append(ring)
    n = len(prof)
    for j in range(segs):
        A, B = rings[j], rings[(j + 1) % segs]
        for i in range(n - 1):
            try:
                bm.faces.new([A[i], B[i], B[i + 1], A[i + 1]])
            except ValueError:
                pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-7)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("knob")
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    me.set_sharp_from_angle(angle=math.radians(50))
    return me

KNOB = knob_mesh()
KNOB.materials.append(mat("knob_grey"))
def cap_mesh(name, matname):
    o = lathe("tmp", [(0, 0), (.0047, 0), (.0047, .0008), (.0042, .0016), (0, .0019)], matname, segs=28)
    me = o.data
    me.name = name
    bpy.data.objects.remove(o)
    return me
CAPS = {k: cap_mesh("cap_" + k, "cap_" + k) for k in ("red", "blue", "grey", "cream")}
ROW_CAPS = ["red", "blue", "grey", "grey", "blue", "cream", "cream", "cream"]
LINE = box("tmp", (.0011, .0042, .0006), (0, 0, 0), "cap_cream").data
bpy.data.objects.remove(bpy.data.objects["tmp"])
SCREW = lathe("tmp", [(0, 0), (.0024, 0), (.0022, .0008), (.0012, .0014), (0, .0015)], "alu", segs=16).data
bpy.data.objects.remove(bpy.data.objects["tmp"])

def inst(name, me, loc, parent, rot=(0, 0, 0)):
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.parent = parent
    o.location = loc
    o.rotation_euler = rot
    return o

FADER_CAP = extrude_profile("tmp", [(-.011, 0), (.011, 0), (.011, .010), (.0085, .0125), (.0, .0105), (-.0085, .0125), (-.011, .010)], .016, "fader_cap", bev=.0012, seg=2).data
bpy.data.objects.remove(bpy.data.objects["tmp"])
BTN = box("tmp", (.0068, .0068, .0045), (0, 0, 0), "btn", bev=.0012, seg=2).data
bpy.data.objects.remove(bpy.data.objects["tmp"])

for i in range(N):
    x = -L / 2 + .01 + SW * (i + .5)
    for k in range(ROWS):
        kn = inst("Knob", KNOB, (x, t_of(k), H0), deck, (0, 0, rnd.uniform(-2.4, 2.4)))
        inst("KnobCap", CAPS[ROW_CAPS[k]], (0, 0, .0124), kn)
        inst("KnobLine", LINE, (0, -.0035, .0145), kn)
    for zz in (-PLEN / 2 + .007, PLEN / 2 - .009):
        inst("Screw", SCREW, (x, -zz, H0), deck)
    # mute / solo
    mv = t_of(ROWS) + .004
    box("Mute", (.014, .01, .006), (x - .009, mv, H0 + .003), "mute_on" if rnd.random() < .25 else "mute_off", deck, bev=.0015, seg=2)
    box("Solo", (.014, .01, .006), (x + .009, mv, H0 + .003), "solo", deck, bev=.0015, seg=2)
    # boutons phase / filtre
    for bx in (-.0055, .0055):
        inst("Btn", BTN, (x + bx, -(-PLEN / 2 + .053), H0 + .0022), deck)
    # fente de fader + bouton de fader
    box("FaderSlot", (.0034, PLEN * .19, .002), (x, -(-PLEN / 2 + PLEN * .875), H0 - .0002), "slot", deck)
    fv = PLEN / 2 - .02 - rnd.random() * .085
    box("FaderStem", (.003, .003, .004), (x, -fv, H0 + .002), "black", deck)
    inst("FaderCap", FADER_CAP, (x, -fv, H0 + .0035), deck, (0, 0, math.pi / 2))
# section master
mx0 = L / 2 - .01 - MASTER
BIG = lathe("tmp", [(0, 0), (.0125, 0), (.0125, .002), (.0115, .004), (.0112, .014), (.0105, .0158), (0, .016)], "black", segs=40).data
bpy.data.objects.remove(bpy.data.objects["tmp"])
for k in range(3):
    inst("MasterKnob", BIG, (mx0 + MASTER * (.25 + k * .25), -(-PLEN / 2 + .07 + k * .06), H0), deck)
for k in range(2):
    box("MasterFader", (.022, .03, .016), (mx0 + MASTER * (.3 + k * .4), -(PLEN / 2 - .06), H0 + .008), "cap_red", deck, bev=.004)
    box("MasterSlot", (.006, PLEN * .23, .002), (mx0 + MASTER * (.3 + k * .4), -(-PLEN / 2 + PLEN * .855), H0 - .0002), "slot", deck)

# ---------------------------------------------------------------- pont de VU + baie de brassage
bridge = empty("Bridge", (0, D / 2 - .03, .18), root)
bridge.rotation_euler = (.25, 0, 0)
box("BridgeBody", (L, .05, .12), (0, 0, 0), "body", bridge, bev=.006, seg=3)
for sx in (-1, 1):
    box("BridgeEnd", (.028, .062, .135), (sx * (L / 2 + .014), .004, 0), "walnut", bridge, bev=.008, seg=3)
box("Visor", (L * .88, .03, .006), (-L * .036, -.038, .049), "body", bridge, bev=.002, seg=2)
VUX = [-L * .36 + k * L * .144 for k in range(6)]
for vx in VUX:
    # cadre : quatre montants arrondis (vrai creux pour le cadran)
    for sz in (-1, 1):
        box("VUBezel", (.115, .008, .007), (vx, -.026, .01 + sz * .0335), "black", bridge, bev=.0025, seg=2)
    for sx in (-1, 1):
        box("VUBezel", (.007, .008, .074), (vx + sx * .054, -.026, .01), "black", bridge, bev=.0025, seg=2)
    bm = bmesh.new()
    vs = [bm.verts.new(v) for v in ((-.05, 0, -.031), (.05, 0, -.031), (.05, 0, .031), (-.05, 0, .031))]
    bm.faces.new(vs)
    f = lib.obj_from_bm("VUFace", bm, "vu_face", bridge)
    f.location = (vx, -.0255, .01)
    planar_uv(f, "Y")
    box("VUGlass", (.104, .003, .066), (vx, -.031, .01), "glass", bridge, bev=.0015, seg=2)
    nd = box("VUNeedle", (.001, .001, .05), (vx - .008, -.027, .0), "black", bridge)
    nd.rotation_euler = (0, rnd.uniform(-.6, -.1), 0)
    cyl("VUPivot", .0035, .003, (vx - .008, -.027, -.02), "black", bridge, segs=16, axis="Y")
# échelles de LED
for col in range(2):
    for i in range(10):
        on = i < 6 + col
        m = ("led_green" if i < 7 else "led_amber" if i < 9 else "led_red") if on else "black"
        box("LED", (.008, .003, .004), (L * .43 - .012 + col * .024, -.026, -.03 + i * .007), m, bridge, bev=.0006, seg=1)
# baie de brassage sur le dessus du pont
patch = empty("Patch", (0, 0, .062), bridge)
patch.rotation_euler = (-math.pi / 2 + .25 + math.pi / 2, 0, 0)
box("PatchPlate", (L - .04, .04, .006), (0, 0, 0), "black_metal", patch, bev=.0015, seg=2)
JACK = lathe("tmp", [(0, 0), (.0034, 0), (.0034, .0012), (.0026, .0014), (.0016, .0012), (.0016, -.003), (0, -.003)], "chrome", segs=16).data
bpy.data.objects.remove(bpy.data.objects["tmp"])
nj = int((L - .08) / .03)
for row in range(2):
    for i in range(nj):
        inst("Jack", JACK, (-L / 2 + .04 + i * .03, -.009 + row * .018, .003), patch)
for i, cm in enumerate(("cord_red", "cord_yellow", "cord_blue", "cord_black")):
    a = Vector((-L / 2 + .04 + (3 + i * 5) * .03, -.009, .006))
    b = Vector((-L / 2 + .04 + (7 + i * 4) * .03, .009, .006))
    mid = (a + b) / 2 + Vector((0, -.02 - i * .006, .05 + i * .01))
    tube("Cord", [a, a + Vector((0, 0, .02)), mid, b + Vector((0, 0, .02)), b], .0022, cm, patch, res=6, segs=24)

# câbles qui partent derrière vers le sol
tube("Snake", [(.45, D / 2, .08), (.5, D / 2 + .08, .02), (.55, D / 2 + .12, -.3), (.62, D / 2 + .06, -.8)], .011, "cable", root, res=8, segs=24)
for i in range(5):
    x = -.3 + i * .14
    tube("Cable", [(x, D / 2, .1), (x + .02, D / 2 + .06, .06), (x * .5, D / 2 + .1, -.2), (x * .3, D / 2 + .05, -.8)], .005, "black", root, res=6, segs=20)

out = __file__.rsplit("/", 2)[0] + "/godot/assets/models/console_8028.glb"
lib.export(out)
if "--preview" in sys.argv:
    lib.preview("/tmp/console_preview.png", (.55, -.95, .55), (.25, 0, .1), lens=35, samples=20, light_energy=120)
