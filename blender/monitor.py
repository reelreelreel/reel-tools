"""Grande écoute encastrée façon 1977 (dans les soffits de part et d'autre de la vitre).
Façade en noyer à cadre mouluré, baffle noir, deux boomers 15" (saladier en fonte avec boulons,
suspension en demi-tore, cône en papier nervuré, cache-noyau en feutre), pavillon multicellulaire
évasé (cloisons en alu, bride vissée), deux évents à bords arrondis, toile acoustique en haut,
petite plaque de marque. Origine : milieu du bas de la façade ; la façade regarde -Y.
"""
import sys, math
sys.path.insert(0, __file__.rsplit("/", 1)[0])
import bpy, bmesh
from mathutils import Vector
import lib
from lib import box, cyl, lathe, extrude_profile, empty, planar_uv

W, H = .98, 1.75
OUT = __file__.rsplit("/", 2)[0] + "/godot/assets/models/"
for n, c in (("frame_metal", ((.04, .04, .045), .8, .45)), ("surround", ((.03, .03, .03), 0, .85)), ("cone", ((.05, .045, .04), 0, .9)),
             ("dustcap", ((.03, .03, .03), 0, 1.0)), ("horn", ((.02, .02, .02), .3, .5)), ("badge", ((.6, .6, .55), .8, .35))):
    lib.PREVIEW[n] = c

lib.reset()
root = empty("MainMonitor")
y0, y1 = .38, H - .28            # baffle (bas, haut)
bw = W - .16

# cadre mouluré en noyer : montants + traverses avec un profil en doucine
def moulding(length, name, loc, rot):
    prof = [(0, 0), (0, .05)] + [(-.035 * (t / 10), .05 - .015 * math.sin(t / 10 * math.pi)) for t in range(1, 11)] + [(-.04, .03), (-.04, 0)]
    # profil (y = vers l'avant, z = dans le plan du cadre) -> extrudé le long de X
    o = extrude_profile(name, list(reversed(prof)), length, "walnut", root, bev=.002, seg=2)
    o.location = loc
    o.rotation_euler = rot
    return o

for sx in (-1, 1):
    m = moulding(H + .01, "Stile", (sx * (W / 2 - .025), .0, H / 2), (0, math.pi / 2 * sx, 0))
for zz, rx in ((y0 - .03, 0), (y1 + .03, math.pi)):
    moulding(W - .1, "Rail", (0, .0, zz), (rx, 0, 0))
baffle = box("Baffle", (bw, .02, y1 - y0), (0, .012, (y0 + y1) / 2), "black", root, bev=.003)
lower = box("LowerPanel", (bw, .02, y0 - .05), (0, .006, (y0 + .02) / 2), "walnut", root, bev=.004)
box("Cloth", (bw, .012, H - y1 - .08), (0, .01, (y1 + .05 + H - .03) / 2), "fabric", root, bev=.002)

# ---------------------------------------------------------------- boomers 15"
R = .19
WY = y0 + .26
def woofer(cx):
    g = empty("Woofer", (cx, 0, WY), root)
    g.rotation_euler = (math.pi / 2, 0, 0)      # Z local -> -Y (vers l'auditeur)
    lathe("Basket", [(R, -.004), (R, .007), (R - .004, .009), (R - .014, .009), (R - .016, .004), (R - .016, -.01)], "frame_metal", g, segs=96)
    # suspension en demi-tore
    sur = [(R - .016 - .022 * (1 - math.cos(t / 12 * math.pi)) / 2, .004 + .012 * math.sin(t / 12 * math.pi)) for t in range(13)]
    lathe("Surround", sur, "surround", g, segs=96)
    # cône nervuré (légères ondulations concentriques)
    rc0, rc1 = R - .038, .062
    cone = []
    for t in range(25):
        k = t / 24
        r = rc0 + (rc1 - rc0) * k
        z = .004 - .078 * (k ** .85) + .0012 * math.sin(k * math.pi * 10) * (1 - k)
        cone.append((r, z))
    lathe("Cone", cone, "cone", g, segs=96)
    cap = [(rc1 * math.cos(t / 10 * math.pi / 2), -.074 + .028 * math.sin(t / 10 * math.pi / 2)) for t in range(11)]
    lathe("DustCap", cap, "dustcap", g, segs=64)
    # boulons de fixation
    for k in range(8):
        a = k / 8 * math.tau + .2
        b = cyl("Bolt", .0055, .004, (math.cos(a) * (R - .007), math.sin(a) * (R - .007), .011), "chrome", g, segs=6, bev=.0008, seg=1)
    return g

for sx in (-1, 1):
    woofer(sx * (R + .012))

# ---------------------------------------------------------------- pavillon multicellulaire
HY = y1 - .16
mw, mh = bw * .64, .2
tw, th = .07, .035
depth = .17
bm = bmesh.new()
rings = []
steps = 14
for i in range(steps + 1):
    t = i / steps
    k = t ** 2.2                       # évasement exponentiel vers la bouche
    w2 = (tw + (mw - tw) * k) / 2
    h2 = (th + (mh - th) * k) / 2
    y = depth * (1 - t)
    rings.append([bm.verts.new(p) for p in ((-w2, y, -h2), (w2, y, -h2), (w2, y, h2), (-w2, y, h2))])
for i in range(steps):
    for j in range(4):
        a, b = rings[i], rings[i + 1]
        bm.faces.new([a[j], a[(j + 1) % 4], b[(j + 1) % 4], b[j]])
bm.faces.new(list(reversed(rings[0])))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
horn = lib.obj_from_bm("Horn", bm, "horn", root, 70)
horn.location = (0, .002, HY)
# cloisons des cellules (5 lames d'alu qui suivent l'évasement)
for c in range(1, 6):
    f = (c / 6) * 2 - 1
    bm = bmesh.new()
    vs = []
    for i in range(steps + 1):
        t = i / steps
        k = t ** 2.2
        x = f * (tw + (mw - tw) * k) / 2
        h2 = (th + (mh - th) * k) / 2
        y = depth * (1 - t)
        vs.append((bm.verts.new((x, y, -h2)), bm.verts.new((x, y, h2))))
    for i in range(steps):
        bm.faces.new([vs[i][0], vs[i + 1][0], vs[i + 1][1], vs[i][1]])
    o = lib.obj_from_bm("Fin", bm, "alu", root, 70)
    o.location = (0, .002, HY)
    sol = o.modifiers.new("s", "SOLIDIFY")
    sol.thickness = .002
    lib.apply_mods(o)
# bride vissée autour de la bouche
for sz in (-1, 1):
    box("HornFlange", (mw + .03, .008, .014), (0, -.004, HY + sz * (mh / 2 + .007)), "frame_metal", root, bev=.002)
for sx in (-1, 1):
    box("HornFlange", (.014, .008, mh + .03), (sx * (mw / 2 + .007), -.004, HY), "frame_metal", root, bev=.002)
for sx in (-1, 0, 1):
    for sz in (-1, 1):
        cyl("FlangeScrew", .003, .003, (sx * mw * .45, -.009, HY + sz * (mh / 2 + .007)), "chrome", root, segs=8, axis="Y")

# ---------------------------------------------------------------- évents
for sx in (-1, 1):
    g = empty("Port", (sx * .2, 0, .2), root)
    st = []
    for t in range(16):
        a = t / 16 * math.tau
        st.append((.11 * math.cos(a) * (1 + .5 * abs(math.cos(a)) ** 6), .022 * math.sin(a)))
    # contour en stade, bord arrondi (anneau) + intérieur noir
    o = extrude_profile("PortRim", [(x, z) for x, z in st], .012, "black", g, bev=.004, seg=3)
    o.rotation_euler = (0, 0, math.pi / 2)
    box("PortHole", (.2, .01, .03), (0, .004, 0), "slot", g)

# trous dans le baffle (boomers, bouche du pavillon) et dans le panneau bas (évents)
cutters = []
for sx in (-1, 1):
    c = cyl("cutW", R - .015, .1, (sx * (R + .012), .0, WY), "black", segs=96, axis="Y")
    cutters.append(c)
cutters.append(box("cutH", (mw - .004, .1, mh - .004), (0, 0, HY), "black"))
lib.cut(baffle, cutters)
lib.cut(lower, [box("cutP", (.21, .1, .034), (sx * .2, 0, .2), "black") for sx in (-1, 1)])
# fond noir derrière les trous
box("BackBox", (bw, .01, y1 - y0), (0, .2, (y0 + y1) / 2), "black", root)

# plaque de marque (texte dessiné dans Godot)
bm = bmesh.new()
vs = [bm.verts.new(v) for v in ((-.06, 0, -.011), (.06, 0, -.011), (.06, 0, .011), (-.06, 0, .011))]
bm.faces.new(vs)
b = lib.obj_from_bm("Badge", bm, "badge", root)
b.location = (0, -.0005, y0 + .018)
planar_uv(b, "Y")

lib.export(OUT + "main_monitor.glb")
if "--preview" in sys.argv:
    lib.preview("/tmp/mon_preview.png", (.6, -1.6, 1.3), (0, 0, 1.0), lens=35, samples=20, light_energy=150)
