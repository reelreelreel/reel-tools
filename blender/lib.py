"""Petite boîte à outils Blender (bpy) pour modéliser les meubles et machines de REEL'S TOOLS.

Repère Blender : Z en haut, l'avant des objets regarde vers -Y (à l'export glTF, -Y devient +Z,
c'est-à-dire l'avant dans Godot). Unités : mètres. Chaque matériau porte un nom : dans Godot, ce nom
est remplacé par le vrai matériau de la scène (bois PBR, cuir, alu…), donc ici les couleurs ne
servent qu'aux rendus d'aperçu.
"""
import bpy, bmesh, math, os
from mathutils import Vector, Matrix

PREVIEW = {
    "walnut": ((.32, .17, .09), 0.0, .45),
    "walnut_dark": ((.16, .08, .04), 0.0, .4),
    "leather": ((.04, .035, .03), 0.0, .55),
    "leather_cognac": ((.35, .14, .05), 0.0, .5),
    "brass": ((.8, .6, .3), 1.0, .3),
    "alu": ((.7, .7, .68), 1.0, .3),
    "chrome": ((.9, .9, .9), 1.0, .08),
    "black": ((.02, .02, .02), 0.0, .4),
    "black_metal": ((.03, .03, .03), .8, .4),
    "body": ((.2, .27, .33), .4, .45),
    "panel": ((.27, .33, .4), .4, .45),
    "knob_grey": ((.45, .46, .47), 0.0, .35),
    "cap_red": ((.6, .08, .05), 0.0, .4),
    "cap_blue": ((.12, .25, .45), 0.0, .4),
    "cap_grey": ((.5, .5, .5), 0.0, .4),
    "cap_cream": ((.75, .72, .65), 0.0, .4),
    "fader_cap": ((.75, .72, .65), 0.0, .4),
    "btn": ((.6, .58, .55), 0.0, .45),
    "mute_on": ((1, .1, .05), 0.0, .3),
    "mute_off": ((.3, .06, .04), 0.0, .4),
    "solo": ((.4, .33, .08), 0.0, .4),
    "slot": ((0, 0, 0), 0.0, 1.0),
    "glass": ((.9, .95, 1), 0.0, .02),
    "vu_face": ((.92, .85, .62), 0.0, .7),
    "deck_print": ((.27, .33, .4), .3, .5),
    "rubber": ((.02, .02, .02), 0.0, .8),
    "fabric": ((.08, .05, .03), 0.0, 1.0),
    "led_green": ((.1, 1, .2), 0.0, .3),
    "led_amber": ((1, .7, .1), 0.0, .3),
    "led_red": ((1, .1, .05), 0.0, .3),
    "cord_red": ((.6, .1, .05), 0.0, .4),
    "cord_yellow": ((.8, .6, .1), 0.0, .4),
    "cord_blue": ((.1, .25, .6), 0.0, .4),
    "cord_black": ((.02, .02, .02), 0.0, .4),
    "cable": ((.15, .15, .16), 0.0, .5),
    "sel_on": ((1, .7, .2), 0.0, .3),
    "talk_red": ((.7, .06, .04), 0.0, .3),
    "grille": ((.05, .05, .05), .8, .5),
}


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    col, metal, rough = PREVIEW.get(name, ((.5, .5, .5), 0.0, .5))
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*col, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if name.startswith("led_") or name in ("mute_on", "sel_on"):
        b.inputs["Emission Color"].default_value = (*col, 1)
        b.inputs["Emission Strength"].default_value = 4.0
    if name == "glass":
        b.inputs["Alpha"].default_value = .15
    return m


def obj_from_bm(name, bm, material, parent=None, smooth_angle=35.0):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    if material:
        o.data.materials.append(mat(material) if isinstance(material, str) else material)
    if parent:
        o.parent = parent
    smooth(o, smooth_angle)
    return o


def smooth(o, angle=35.0):
    me = o.data
    for p in me.polygons:
        p.use_smooth = True
    try:
        me.set_sharp_from_angle(angle=math.radians(angle))
    except Exception:
        pass


def bevel(o, width, segments=3, limit_angle=50.0, harden=True):
    """Arrondit les arêtes (modificateur Bevel appliqué)."""
    if width <= 0:
        return o
    m = o.modifiers.new("bevel", "BEVEL")
    m.width = width
    m.segments = segments
    m.limit_method = "ANGLE"
    m.angle_limit = math.radians(limit_angle)
    m.harden_normals = harden
    m.miter_outer = "MITER_ARC"
    apply_mods(o)
    return o


def subsurf(o, levels=2):
    m = o.modifiers.new("sub", "SUBSURF")
    m.levels = levels
    m.render_levels = levels
    apply_mods(o)
    return o


def apply_mods(o):
    bpy.context.view_layer.objects.active = o
    for m in list(o.modifiers):
        with bpy.context.temp_override(object=o, active_object=o):
            bpy.ops.object.modifier_apply(modifier=m.name)


def box(name, size, loc, material, parent=None, bev=0.0, seg=3, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    o = obj_from_bm(name, bm, material, parent)
    o.location = loc
    o.rotation_euler = rot
    if bev:
        bevel(o, bev, seg)
    return o


def cyl(name, r, h, loc, material, parent=None, segs=32, bev=0.0, seg=2, axis="Z", r2=None):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r, radius2=r if r2 is None else r2, depth=h)
    o = obj_from_bm(name, bm, material, parent, 40)
    o.location = loc
    if axis == "X":
        o.rotation_euler = (0, math.pi / 2, 0)
    elif axis == "Y":
        o.rotation_euler = (math.pi / 2, 0, 0)
    if bev:
        bevel(o, bev, seg, 30)
    return o


def lathe(name, profile, material, parent=None, segs=48, loc=(0, 0, 0)):
    """Profil [(rayon, z), …] tourné autour de Z."""
    bm = bmesh.new()
    rings = []
    for j in range(segs):
        a = j / segs * math.tau
        rings.append([bm.verts.new((r * math.cos(a), r * math.sin(a), z)) for r, z in profile])
    n = len(profile)
    for j in range(segs):
        A = rings[j]
        B = rings[(j + 1) % segs]
        for i in range(n - 1):
            vs = [A[i], B[i], B[i + 1], A[i + 1]]
            if len(set(vs)) == 4:
                try:
                    bm.faces.new(vs)
                except ValueError:
                    pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = obj_from_bm(name, bm, material, parent, 40)
    o.location = loc
    return o


def extrude_profile(name, pts, length, material, parent=None, loc=(0, 0, 0), bev=0.0, seg=3, axis="X"):
    """Profil 2D [(y, z), …] (polygone fermé, sens trigo) extrudé le long de X, centré."""
    bm = bmesh.new()
    a = [bm.verts.new((-length / 2, y, z)) for y, z in pts]
    b = [bm.verts.new((length / 2, y, z)) for y, z in pts]
    bm.faces.new(list(reversed(a)))
    bm.faces.new(b)
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([a[i], a[j], b[j], b[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = obj_from_bm(name, bm, material, parent)
    o.location = loc
    if axis == "Y":
        o.rotation_euler = (0, 0, math.pi / 2)
    if bev:
        bevel(o, bev, seg)
    return o


def tube(name, points, r, material, parent=None, res=8, segs=48):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = r
    cu.bevel_resolution = res // 2
    cu.resolution_u = max(2, segs // max(1, len(points) - 1))
    sp = cu.splines.new("NURBS")
    sp.points.add(len(points) - 1)
    for i, p in enumerate(points):
        sp.points[i].co = (*p, 1)
    sp.use_endpoint_u = True
    sp.order_u = min(4, len(points))
    o = bpy.data.objects.new(name, cu)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat(material))
    if parent:
        o.parent = parent
    bpy.context.view_layer.objects.active = o
    with bpy.context.temp_override(object=o, active_object=o, selected_objects=[o], selected_editable_objects=[o]):
        bpy.ops.object.convert(target="MESH")
    o = bpy.data.objects[name]
    smooth(o, 60)
    return o


def empty(name, loc=(0, 0, 0), parent=None):
    e = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(e)
    e.location = loc
    if parent:
        e.parent = parent
    return e


def planar_uv(o, axis="Z"):
    """UV 0..1 sur la boîte englobante (pour les faces imprimées : pupitre, cadrans)."""
    me = o.data
    if not me.uv_layers:
        me.uv_layers.new()
    uv = me.uv_layers.active.data
    xs = [v.co.x for v in me.vertices]
    ys = [v.co.y for v in me.vertices]
    zs = [v.co.z for v in me.vertices]
    for poly in me.polygons:
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            if axis == "Z":
                u = (co.x - min(xs)) / max(1e-6, max(xs) - min(xs))
                v = (co.y - min(ys)) / max(1e-6, max(ys) - min(ys))
            else:  # face avant (-Y) : x -> u, z -> v
                u = (co.x - min(xs)) / max(1e-6, max(xs) - min(xs))
                v = (co.z - min(zs)) / max(1e-6, max(zs) - min(zs))
            uv[li].uv = (u, v)


def export(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True, export_yup=True,
                              export_materials="EXPORT", export_texcoords=True, export_normals=True,
                              export_extras=True)
    print("exporté :", path)


def preview(path, cam_loc, target, lens=40, samples=24, res=(1280, 720), light_energy=300):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.filepath = path
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (.08, .07, .06, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = .6
    sc.world = world
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    cam.location = cam_loc
    d = Vector(target) - Vector(cam_loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens
    sc.camera = cam
    for i, (p, e) in enumerate([((cam_loc[0] + 1.5, cam_loc[1] - .5, 2.6), light_energy), ((cam_loc[0] - 2, cam_loc[1] + 1, 2.2), light_energy * .5)]):
        l = bpy.data.objects.new("l%d" % i, bpy.data.lights.new("l%d" % i, "AREA"))
        l.data.energy = e
        l.data.size = 1.2
        l.data.color = (1, .85, .7)
        sc.collection.objects.link(l)
        l.location = p
        l.rotation_euler = (Vector(target) - Vector(p)).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.render.render(write_still=True)
    print("aperçu :", path)


def armrest(length, w=.062, h=.05, pleat=.11):
    """Accoudoir de cuir rembourré : boudin en super-ellipse, pincé tous les `pleat` m, bouts arrondis."""
    bm = bmesh.new()
    nx = int(length / .004)
    na = 28
    rows = []
    for i in range(nx + 1):
        x = -length / 2 + i * length / nx
        # boudins : léger pincement tous les `pleat` m, extrémités arrondies
        ph = abs(math.sin(math.pi * (x + length / 2) / pleat))
        pinch = 1.0 - .12 * (1 - ph) ** 6
        end = min(1.0, (length / 2 - abs(x)) / .03)
        endk = math.sqrt(max(0.0, 1 - (1 - end) ** 2))
        ring = []
        for j in range(na):
            a = j / na * math.tau
            c, s = math.cos(a), math.sin(a)
            # super-ellipse (coussin un peu carré)
            r = 1.0 / ((abs(c) ** 3 + abs(s) ** 3) ** (1 / 3))
            y = c * r * w / 2 * pinch * (.25 + .75 * endk)
            z = s * r * h / 2 * pinch * (.25 + .75 * endk)
            if z < -h / 2 * .7:
                z = -h / 2 * .7
            ring.append(bm.verts.new((x, y, z)))
        rows.append(ring)
    for i in range(nx):
        for j in range(na):
            k = (j + 1) % na
            bm.faces.new([rows[i][j], rows[i][k], rows[i + 1][k], rows[i + 1][j]])
    bm.faces.new(list(reversed(rows[0])))
    bm.faces.new(rows[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm

