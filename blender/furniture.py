"""Mobilier d'appoint de styles variés (le studio s'est équipé au fil des années) :
- lounge_chair.glb : fauteuil mid-century en teck, pieds fuseau écartés, coussins en velours côtelé
- coffee_table.glb : table basse plateau formica, chant teck, pieds compas avec bagues laiton
- mushroom_lamp.glb : lampe champignon space age en laque orange
- tulip_stool.glb : tabouret tulipe laqué blanc, galette en skaï rouge
- steel_cart.glb : chariot de studio indus (cornières acier, flancs en tôle perforée, roulettes)
- flight_case.glb : flight case (tolex, profilés alu, coins boule, fermetures papillon, poignées)
Origine : milieu du sol, avant vers -Y.
"""
import sys, math
sys.path.insert(0, __file__.rsplit("/", 1)[0])
import bpy, bmesh
from mathutils import Vector
import lib
from lib import box, cyl, lathe, extrude_profile, tube, empty

OUT = __file__.rsplit("/", 2)[0] + "/godot/assets/models/"
for n, c in (("teak", ((.45, .22, .08), 0, .5)), ("corduroy", ((.55, .35, .08), 0, .9)), ("formica", ((.85, .8, .65), 0, .3)),
             ("lacquer_orange", ((.9, .3, .05), 0, .15)), ("lacquer_white", ((.9, .88, .84), 0, .15)), ("vinyl_red", ((.55, .05, .04), 0, .35)),
             ("lamp_glow", ((1, .8, .5), 0, .5)), ("steel", ((.4, .4, .4), .9, .35)), ("perforated", ((.35, .35, .35), .8, .45)),
             ("tolex", ((.03, .03, .03), 0, .7))):
    lib.PREVIEW[n] = c


def splayed_leg(name, top, bottom, r_top, r_bot, mat, parent):
    """Pied fuseau incliné (cône) entre deux points."""
    a, b = Vector(top), Vector(bottom)
    d = b - a
    o = cyl(name, r_top, d.length, (a + b) / 2, mat, parent, segs=20, r2=r_bot)
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector((0, 0, -1)).rotation_difference(d.normalized())
    return o


# ---------------------------------------------------------------- fauteuil mid-century
def lounge_chair():
    lib.reset()
    root = empty("LoungeChair")
    W, D, SH = .74, .78, .38
    # piétement : 4 pieds fuseau écartés + ceinture
    for sx in (-1, 1):
        for sy in (-1, 1):
            splayed_leg("Leg", (sx * .26, sy * .26, SH - .06), (sx * .33, sy * .34, 0), .02, .011, "teak", root)
    for sx in (-1, 1):
        box("Rail", (.03, D - .12, .05), (sx * .27, 0, SH - .06), "teak", root, bev=.008)
    # accoudoirs en teck, sculptés (plats, arrondis devant)
    for sx in (-1, 1):
        arm = box("Arm", (.07, D - .06, .028), (sx * (W / 2 - .035), -.02, .6), "teak", root, bev=.012, seg=4)
        splayed_leg("ArmPost", (sx * (W / 2 - .035), -D / 2 + .08, .6), (sx * .27, -D / 2 + .12, SH - .06), .014, .016, "teak", root)
        splayed_leg("ArmPost", (sx * (W / 2 - .035), D / 2 - .08, .6), (sx * .27, D / 2 - .12, SH - .06), .014, .016, "teak", root)
    # assise et dossier : coque + coussins en velours côtelé (galbés)
    seat = box("Seat", (W - .16, D - .16, .11), (0, -.03, SH + .02), "corduroy", root, bev=.045, seg=6)
    back = box("Back", (W - .16, .12, .5), (0, D / 2 - .14, SH + .3), "corduroy", root, bev=.05, seg=6)
    back.rotation_euler = (math.radians(-14), 0, 0)
    # coutures / passepoil
    for z in (SH + .075, SH - .035):
        tube("Piping", lib.rounded_rect(-(W - .16) / 2 + .005, (W - .16) / 2 - .005, -.03 - (D - .16) / 2 + .005, -.03 + (D - .16) / 2 - .005, z, .045), .003, "corduroy", root, res=6, poly=True)
    box("BackFrame", (W - .12, .03, .06), (0, D / 2 - .06, SH + .55), "teak", root, bev=.012)
    lib.export(OUT + "lounge_chair.glb")


# ---------------------------------------------------------------- table basse
def coffee_table():
    lib.reset()
    root = empty("CoffeeTable")
    W, D, H = 1.1, .55, .4
    # plateau en forme de surf (rectangle aux bouts arrondis), formica + chant teck
    pts = []
    for k in range(48):
        a = k / 48 * math.tau
        c, s = math.cos(a), math.sin(a)
        r = 1.0 / ((abs(c) ** 4 + abs(s) ** 4) ** .25)
        pts.append((c * r * W / 2, s * r * D / 2))
    bm = bmesh.new()
    top = [bm.verts.new((x, y, H)) for x, y in pts]
    bot = [bm.verts.new((x, y, H - .022)) for x, y in pts]
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    for i in range(len(pts)):
        j = (i + 1) % len(pts)
        bm.faces.new([bot[i], bot[j], top[j], top[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    slab = lib.obj_from_bm("Top", bm, "teak", root)
    lib.bevel(slab, .006, 3, 30)
    # placage formica sur le dessus (légèrement en retrait du chant)
    bm = bmesh.new()
    ins = [bm.verts.new((x * .985, y * .97, H + .0008)) for x, y in pts]
    bm.faces.new(ins)
    f = lib.obj_from_bm("Formica", bm, "formica", root)
    lib.planar_uv(f, "Z")
    # tablette basse en canne / teck
    box("Shelf", (W * .7, D * .55, .015), (0, 0, .14), "teak", root, bev=.004)
    for sx in (-1, 1):
        for sy in (-1, 1):
            splayed_leg("Leg", (sx * W * .32, sy * D * .25, H - .022), (sx * W * .42, sy * D * .4, 0), .018, .01, "teak", root)
            # bague laiton au pied
            cyl("Ferrule", .0115, .04, (sx * W * .418, sy * D * .395, .02), "brass", root, segs=16)
    lib.export(OUT + "coffee_table.glb")


# ---------------------------------------------------------------- lampe champignon
def mushroom_lamp():
    lib.reset()
    root = empty("MushroomLamp")
    lathe("Base", [(0, 0), (.11, 0), (.11, .006), (.095, .02), (.03, .03), (0, .03)], "lacquer_orange", root, segs=64)
    lathe("Stem", [(.03, .03), (.022, .1), (.019, .2), (.024, .26), (0, .26)], "lacquer_orange", root, segs=48)
    shade = [(.0, .37)] + [(.2 * math.sin(t / 16 * math.pi / 2), .37 - .1 * (1 - math.cos(t / 16 * math.pi / 2)) ** .8) for t in range(1, 17)] + [(.2, .262), (.19, .262)]
    lathe("Shade", shade, "lacquer_orange", root, segs=72)
    lathe("Glow", [(0, .265), (.18, .265), (.17, .275), (0, .3)], "lamp_glow", root, segs=48)
    lib.export(OUT + "mushroom_lamp.glb")


# ---------------------------------------------------------------- tabouret tulipe
def tulip_stool():
    lib.reset()
    root = empty("TulipStool")
    prof = [(0, 0), (.2, 0), (.2, .008), (.17, .02)]
    for t in range(1, 12):
        k = t / 11
        prof.append((.17 - .13 * math.sin(k * math.pi / 2) ** .6, .02 + .27 * k))
    prof += [(.05, .33), (.17, .38), (.18, .4), (0, .4)]
    lathe("Tulip", prof, "lacquer_white", root, segs=64)
    cush = lathe("Cushion", [(0, .4), (.17, .4), (.185, .41), (.19, .43), (.18, .455), (.15, .465), (0, .468)], "vinyl_red", root, segs=64)
    tube("Piping", [(math.cos(a) * .188, math.sin(a) * .188, .432) for a in [k / 48 * math.tau for k in range(49)]], .004, "vinyl_red", root, res=6, poly=True)
    lib.export(OUT + "tulip_stool.glb")


# ---------------------------------------------------------------- chariot indus
def steel_cart(W=.72, H=.66, D=.46):
    lib.reset()
    root = empty("SteelCart")
    for sx in (-1, 1):
        for sy in (-1, 1):
            box("Post", (.025, .025, H - .07), (sx * (W / 2 - .0125), sy * (D / 2 - .0125), .07 + (H - .07) / 2), "steel", root, bev=.002)
            c = empty("Caster", (sx * (W / 2 - .04), sy * (D / 2 - .04), 0), root)
            cyl("Plate", .025, .005, (0, 0, .062), "steel", c, segs=16)
            for side in (-1, 1):
                box("Fork", (.004, .026, .03), (side * .012, 0, .04), "steel", c, bev=.001)
            cyl("Wheel", .022, .018, (0, 0, .024), "rubber", c, segs=24, axis="X", bev=.004)
    for z in (.1, H - .012):
        box("Shelf", (W, D, .024), (0, 0, z), "steel", root, bev=.003)
        box("Lip", (W, .004, .03), (0, -D / 2, z + .015), "steel", root)
    for sx in (-1, 1):
        box("SidePanel", (.004, D - .03, H - .2), (sx * (W / 2 - .002), 0, .12 + (H - .2) / 2), "perforated", root)
    box("BackPanel", (W - .03, .004, H - .2), (0, D / 2 - .002, .12 + (H - .2) / 2), "perforated", root)
    tube("Handle", [(-W / 2 + .03, -D / 2 - .002, H - .03), (-W / 2 + .03, -D / 2 - .05, H - .03), (W / 2 - .03, -D / 2 - .05, H - .03), (W / 2 - .03, -D / 2 - .002, H - .03)], .009, "chrome", root, res=8, poly=True)
    lib.export(OUT + "steel_cart.glb")


# ---------------------------------------------------------------- flight case
def flight_case(W=.62, D=.46, H=.52):
    lib.reset()
    root = empty("FlightCase")
    box("Body", (W, D, H), (0, 0, H / 2), "tolex", root, bev=.006)
    e = .022
    for sx in (-1, 1):
        for sy in (-1, 1):
            box("EdgeV", (e, e, H), (sx * (W / 2 - e / 2 + .002), sy * (D / 2 - e / 2 + .002), H / 2), "alu", root, bev=.002)
        for z in (.0 + e / 2, H - e / 2, H * .62):
            box("EdgeH", (e, D, e), (sx * (W / 2 - e / 2 + .002), 0, z), "alu", root, bev=.002)
    for sy in (-1, 1):
        for z in (e / 2, H - e / 2, H * .62):
            box("EdgeW", (W, e, e), (0, sy * (D / 2 - e / 2 + .002), z), "alu", root, bev=.002)
    for sx in (-1, 1):
        for sy in (-1, 1):
            for z in (.006, H - .006):
                lathe("Corner", [(0, -.03), (.03, -.03), (.034, 0), (.03, .03), (0, .034)], "chrome", root, segs=20, loc=(sx * (W / 2 - .01), sy * (D / 2 - .01), z))
    # fermetures papillon + poignées encastrées
    for sx in (-.3, .3):
        g = empty("Latch", (sx * W, -D / 2 - .004, H * .62), root)
        box("Dish", (.07, .006, .05), (0, 0, 0), "chrome", g, bev=.004)
        box("Wing", (.05, .01, .012), (0, -.006, .006), "chrome", g, bev=.003)
    for sx in (-1, 1):
        g = empty("Handle", (sx * (W / 2 + .003), 0, H * .4), root)
        box("Dish", (.006, .14, .07), (0, 0, 0), "chrome", g, bev=.004)
        box("Grip", (.012, .11, .016), (sx * .006, 0, .012), "rubber", g, bev=.006)
    # pochoir blanc (le texte vient de Godot)
    bm = bmesh.new()
    vs = [bm.verts.new(v) for v in ((-.15, 0, -.035), (.15, 0, -.035), (.15, 0, .035), (-.15, 0, .035))]
    bm.faces.new(vs)
    s = lib.obj_from_bm("Stencil", bm, "stencil", root)
    s.location = (0, -D / 2 - .001, H * .3)
    lib.planar_uv(s, "Y")
    lib.export(OUT + "flight_case.glb")


lounge_chair(); coffee_table(); mushroom_lamp(); tulip_stool(); steel_cart(); flight_case()
if "--preview" in sys.argv:
    lib.reset()
    for f, x in (("lounge_chair", -1.6), ("coffee_table", -.4), ("mushroom_lamp", .2), ("tulip_stool", .9), ("steel_cart", 1.7), ("flight_case", 2.6)):
        bpy.ops.import_scene.gltf(filepath=OUT + f + ".glb")
        for o in bpy.context.selected_objects:
            if o.parent is None:
                o.location.x += x
    lib.preview("/tmp/furn_preview.png", (.5, -3.4, 1.4), (.5, 0, .35), lens=32, samples=16, light_energy=250)
