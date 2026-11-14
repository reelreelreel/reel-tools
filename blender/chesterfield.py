"""Canapé Chesterfield en cuir cognac : dossier et accoudoirs capitonnés en losanges (boutons au fond
des creux, plis entre les boutons), accoudoirs roulés vers l'extérieur avec plaque avant cloutée,
trois coussins d'assise à passepoil, ceinture basse, rangées de clous en laiton, pieds boule tournés.
Origine : milieu du sol ; l'avant regarde -Y. W 2.10, D .92, H .84 (comme dans la scène).
"""
import sys, math
sys.path.insert(0, __file__.rsplit("/", 1)[0])
import bpy, bmesh
from mathutils import Vector
import lib
from lib import box, cyl, lathe, tube, empty

OUT = __file__.rsplit("/", 2)[0] + "/godot/assets/models/"
lib.PREVIEW["leather_dark"] = ((.2, .08, .03), 0, .55)
W, D, H = 2.1, .92, .84
ARM = .24
SEAT = .44
FEET = .09
BACK_D = .22
lib.reset()
root = empty("Chesterfield")


def tufted(name, w, h, depth, sx=.15, sy=.11, res=.008, mat="leather_cognac", parent=root):
    """Panneau capitonné (dans le plan XZ, face vers -Y) : coussins en losange, plis, boutons."""
    bm = bmesh.new()
    nx, nz = int(w / res), int(h / res)
    grid = []
    for j in range(nz + 1):
        row = []
        for i in range(nx + 1):
            x = -w / 2 + i * w / nx
            z = j * h / nz
            u = (x / sx + z / sy)
            v = (x / sx - z / sy)
            du = abs(u - round(u))
            dv = abs(v - round(v))
            pillow = min(du, dv) * 2.0                       # 0 sur les plis, 1 au centre du coussin
            puff = math.sin(min(1.0, pillow) * math.pi / 2) ** .7
            # bords du panneau : le rembourrage retombe
            edge = min(1.0, min(x + w / 2, w / 2 - x, z, h - z) / .03)
            y = -depth * puff * edge
            row.append(bm.verts.new((x, y, z)))
        grid.append(row)
    for j in range(nz):
        for i in range(nx):
            bm.faces.new([grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = lib.obj_from_bm(name, bm, mat, parent, 80)
    # boutons au fond des creux (croisement des plis)
    btn = []
    for a in range(-40, 41):
        for b in range(-40, 41):
            x = (a + b) * sx / 2
            z = (a - b) * sy / 2
            if -w / 2 + .05 < x < w / 2 - .05 and .05 < z < h - .05:
                btn.append((x, z))
    return o, btn


def buttons(pts, parent, loc, rot=(0, 0, 0)):
    g = empty("Buttons", loc, parent)
    g.rotation_euler = rot
    me = lathe("tmpb", [(0, 0), (.0085, 0), (.008, .004), (.004, .0065), (0, .007)], "leather_dark", segs=16).data
    bpy.data.objects.remove(bpy.data.objects["tmpb"])
    for x, z in pts:
        o = bpy.data.objects.new("Btn", me)
        bpy.context.collection.objects.link(o)
        o.parent = g
        o.location = (x, .0, z)
        o.rotation_euler = (math.pi / 2, 0, 0)


# ---------------------------------------------------------------- pieds + ceinture
for sx in (-1, 1):
    for sy in (-1, 1):
        lathe("Foot", [(0, 0), (.028, 0), (.046, .022), (.048, .045), (.034, .07), (.036, .085), (.03, FEET), (0, FEET)], "walnut", root, segs=32, loc=(sx * (W / 2 - .08), sy * (D / 2 - .08), 0))
belt = box("Base", (W, D, SEAT - .14 - FEET), (0, 0, FEET + (SEAT - .14 - FEET) / 2), "leather_dark", root, bev=.03, seg=4)

# ---------------------------------------------------------------- dossier
bz0 = SEAT - .14
box("BackCore", (W - .04, BACK_D - .04, H - bz0 - .06), (0, D / 2 - BACK_D / 2, bz0 + (H - bz0 - .06) / 2), "leather_dark", root, bev=.04, seg=4)
iw = W - 2 * ARM + .02
qh = H - .1 - SEAT
panel, bp = tufted("BackTufting", iw, qh, .035)
panel.location = (0, D / 2 - BACK_D + .005, SEAT)
buttons(bp, root, (0, D / 2 - BACK_D + .005 - .002, SEAT))
# boudin du haut du dossier
tube("BackRoll", [(-W / 2 + .05, D / 2 - BACK_D / 2, H - .05), (0, D / 2 - BACK_D / 2 - .003, H - .048), (W / 2 - .05, D / 2 - BACK_D / 2, H - .05)], .062, "leather_cognac", root, res=16, segs=8)
# ---------------------------------------------------------------- accoudoirs roulés
AH = H - .04
for sx in (-1, 1):
    ax = sx * (W / 2 - ARM / 2)
    box("ArmCore", (ARM - .06, D - .04, AH - bz0 - .08), (ax, 0, bz0 + (AH - bz0 - .08) / 2), "leather_dark", root, bev=.04, seg=4)
    # face intérieure capitonnée (tournée vers l'assise)
    ip, ib = tufted("ArmTufting", D - BACK_D - .02, AH - .09 - SEAT, .028)
    ip.rotation_euler = (0, 0, -sx * math.pi / 2)
    ip.location = (ax - sx * (ARM / 2 - .035), -BACK_D / 2 + .005, SEAT)
    # rouleau qui part vers l'extérieur
    tube("ArmRoll", [(ax - sx * .02, -D / 2 + .02, AH - .07), (ax + sx * .01, 0, AH - .068), (ax - sx * .02, D / 2 - .02, AH - .07)], .085, "leather_cognac", root, res=16, segs=8)
    # plaque avant du rouleau, ourlée + clous en rond
    lathe("ArmFront", [(0, 0), (.08, 0), (.085, .008), (.075, .014), (0, .016)], "leather_cognac", root, segs=40, loc=(ax + sx * .005, -D / 2 + .012, AH - .07)).rotation_euler = (math.pi / 2, 0, 0)
    for k in range(18):
        a = k / 18 * math.tau
        lib.lathe("Nail", [(0, 0), (.0055, 0), (.005, .003), (0, .0042)], "brass", root, segs=10, loc=(ax + sx * .005 + math.cos(a) * .068, -D / 2 + .005, AH - .07 + math.sin(a) * .068)).rotation_euler = (math.pi / 2, 0, 0)
    # clous le long du bas de l'accoudoir (côté extérieur)
    n = int((D - .08) / .024)
    for k in range(n):
        y = -D / 2 + .04 + k * (D - .08) / n
        lib.lathe("Nail", [(0, 0), (.0055, 0), (.005, .003), (0, .0042)], "brass", root, segs=10, loc=(sx * (W / 2 + .001), y, bz0 + .025)).rotation_euler = (0, sx * math.pi / 2, 0)
# ---------------------------------------------------------------- coussins d'assise à passepoil
cw = (W - 2 * ARM) / 3
cd = D - BACK_D - .02
for i in range(3):
    cx = -W / 2 + ARM + cw * (i + .5)
    c = box("Cushion", (cw - .008, cd, .13), (cx, -D / 2 + cd / 2 + .01, SEAT - .065 + .005), "leather_cognac", root, bev=.035, seg=5)
    # léger bombé sur le dessus
    for v in c.data.vertices:
        if v.co.z > .03:
            k = 1 - min(1, (abs(v.co.x) / (cw / 2)) ** 2) * .6 - min(1, (abs(v.co.y) / (cd / 2)) ** 2) * .4
            v.co.z += .012 * max(0, k)
    for z in (SEAT + .006, SEAT - .124):
        tube("Piping", lib.rounded_rect(cx - cw / 2 + .006, cx + cw / 2 - .006, -D / 2 + .012, -D / 2 + cd + .008, z, .035), .004, "leather_dark", root, res=6, poly=True)
# clous le long du devant de la ceinture
n = int((W - .1) / .024)
for k in range(n):
    x = -W / 2 + .05 + k * (W - .1) / n
    lib.lathe("Nail", [(0, 0), (.0055, 0), (.005, .003), (0, .0042)], "brass", root, segs=10, loc=(x, -D / 2 - .001, FEET + .03)).rotation_euler = (math.pi / 2, 0, 0)

lib.export(OUT + "chesterfield.glb")
if "--preview" in sys.argv:
    lib.preview("/tmp/chest_preview.png", (1.3, -2.3, 1.3), (0, 0, .45), lens=35, samples=20, light_energy=200)
