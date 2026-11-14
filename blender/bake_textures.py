"""Textures « cuites » dans Blender à partir de matériaux procéduraux (bois, tissus, skaï).
Pour chaque matière : _diff.jpg (couleur), _nor.jpg (relief, normal map), _rough.jpg (rugosité),
1024 px, raccordables (on travaille sur un tore de coordonnées 4D : pas de couture).
Sortie : godot/assets/textures/ph/<nom>_*.jpg (même convention que les textures Poly Haven).
Usage : python3 bake_textures.py [nom ...]
"""
import sys, math, os
sys.path.insert(0, __file__.rsplit("/", 1)[0])
import bpy
import lib

OUT = __file__.rsplit("/", 2)[0] + "/godot/assets/textures/ph/"
RES = 1024


def setup():
    lib.reset()
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 4
    sc.cycles.device = "CPU"
    bpy.ops.mesh.primitive_plane_add(size=2)
    plane = bpy.context.active_object
    return plane


def nodes_for(mat):
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    return nt, nt.nodes, nt.links


def tile_coords(nt, scale=(1, 1)):
    """Coordonnées sans couture : (u, v) du plan -> point sur un tore 4D (cos/sin), pour les textures 4D."""
    N, Lk = nt.nodes, nt.links
    tc = N.new("ShaderNodeTexCoord")
    sep = N.new("ShaderNodeSeparateXYZ")
    Lk.new(tc.outputs["UV"], sep.inputs[0])
    outs = []
    for i, ax in enumerate(("X", "Y")):
        mul = N.new("ShaderNodeMath"); mul.operation = "MULTIPLY"; mul.inputs[1].default_value = math.tau
        Lk.new(sep.outputs[ax], mul.inputs[0])
        c = N.new("ShaderNodeMath"); c.operation = "COSINE"; Lk.new(mul.outputs[0], c.inputs[0])
        s = N.new("ShaderNodeMath"); s.operation = "SINE"; Lk.new(mul.outputs[0], s.inputs[0])
        rad = scale[i] / math.tau
        cm = N.new("ShaderNodeMath"); cm.operation = "MULTIPLY"; cm.inputs[1].default_value = rad; Lk.new(c.outputs[0], cm.inputs[0])
        sm = N.new("ShaderNodeMath"); sm.operation = "MULTIPLY"; sm.inputs[1].default_value = rad; Lk.new(s.outputs[0], sm.inputs[0])
        outs += [cm, sm]
    comb = N.new("ShaderNodeCombineXYZ")
    Lk.new(outs[0].outputs[0], comb.inputs[0]); Lk.new(outs[1].outputs[0], comb.inputs[1]); Lk.new(outs[2].outputs[0], comb.inputs[2])
    return comb.outputs[0], outs[3].outputs[0]   # vecteur 3D + 4e dimension (w)


def noise(nt, vec, w, scale, detail=4, rough=.6, dist=0.0):
    n = nt.nodes.new("ShaderNodeTexNoise")
    n.noise_dimensions = "4D"
    n.inputs["Scale"].default_value = scale
    n.inputs["Detail"].default_value = detail
    n.inputs["Roughness"].default_value = rough
    n.inputs["Distortion"].default_value = dist
    nt.links.new(vec, n.inputs["Vector"]); nt.links.new(w, n.inputs["W"])
    return n.outputs["Fac"]


def ramp(nt, fac, stops):
    r = nt.nodes.new("ShaderNodeValToRGB")
    cr = r.color_ramp
    cr.elements[0].position, cr.elements[0].color = stops[0][0], (*stops[0][1], 1)
    cr.elements[1].position, cr.elements[1].color = stops[-1][0], (*stops[-1][1], 1)
    for p, c in stops[1:-1]:
        e = cr.elements.new(p); e.color = (*c, 1)
    nt.links.new(fac, r.inputs["Fac"])
    return r.outputs["Color"]


def math_node(nt, op, a, b=None, v=None):
    m = nt.nodes.new("ShaderNodeMath"); m.operation = op
    nt.links.new(a, m.inputs[0])
    if b is not None:
        nt.links.new(b, m.inputs[1])
    elif v is not None:
        m.inputs[1].default_value = v
    return m.outputs[0]


def wood(nt, base_stops, grain_scale=60.0, figure=2.5, pores=0.0, rays=0.0):
    """Fil du bois le long de U : veines fines (bandes déformées) + grandes flammes (cathédrales) + pores."""
    vec, w = tile_coords(nt, (1, 8))           # étiré : les veines suivent U
    warp = noise(nt, vec, w, 1.6, 3, .55)
    # veines : sinus sur V déformé par le bruit
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ"); nt.links.new(tc.outputs["UV"], sep.inputs[0])
    vv = math_node(nt, "ADD", sep.outputs["Y"], math_node(nt, "MULTIPLY", warp, v=figure / grain_scale * 6))
    lines = math_node(nt, "SINE", math_node(nt, "MULTIPLY", vv, v=grain_scale * math.tau))
    lines = math_node(nt, "MULTIPLY_ADD", lines, v=.5) if False else math_node(nt, "ADD", math_node(nt, "MULTIPLY", lines, v=.5), v=.5)
    big = noise(nt, vec, w, 3.0, 6, .62, .4)
    fac = math_node(nt, "ADD", math_node(nt, "MULTIPLY", lines, v=.45), math_node(nt, "MULTIPLY", big, v=.55))
    col = ramp(nt, fac, base_stops)
    height = fac
    if pores > 0:
        p = noise(nt, vec, w, 140.0, 2, .5)
        pm = math_node(nt, "GREATER_THAN", p, v=.62)
        col_mix = nt.nodes.new("ShaderNodeMix"); col_mix.data_type = "RGBA"; col_mix.blend_type = "MULTIPLY"
        nt.links.new(math_node(nt, "MULTIPLY", pm, v=pores), col_mix.inputs["Factor"])
        nt.links.new(col, col_mix.inputs["A"]); col_mix.inputs["B"].default_value = (.35, .3, .25, 1)
        col = col_mix.outputs["Result"]
        height = math_node(nt, "SUBTRACT", height, math_node(nt, "MULTIPLY", pm, v=.4))
    if rays > 0:
        r = noise(nt, vec, w, 22.0, 1, .5)
        rm = math_node(nt, "GREATER_THAN", r, v=.68)
        mx = nt.nodes.new("ShaderNodeMix"); mx.data_type = "RGBA"; mx.blend_type = "SCREEN"
        nt.links.new(math_node(nt, "MULTIPLY", rm, v=rays), mx.inputs["Factor"])
        nt.links.new(col, mx.inputs["A"]); mx.inputs["B"].default_value = (.9, .8, .6, 1)
        col = mx.outputs["Result"]
    rough = math_node(nt, "ADD", math_node(nt, "MULTIPLY", fac, v=.25), v=.45)
    return col, height, rough


def fabric(nt, kind):
    vec, w = tile_coords(nt, (1, 1))
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ"); nt.links.new(tc.outputs["UV"], sep.inputs[0])
    n = noise(nt, vec, w, 25.0, 6, .7)
    if kind == "corduroy":
        rib = math_node(nt, "SINE", math_node(nt, "MULTIPLY", sep.outputs["X"], v=48 * math.tau))
        rib = math_node(nt, "POWER", math_node(nt, "ADD", math_node(nt, "MULTIPLY", rib, v=.5), v=.5), v=.6)
        height = math_node(nt, "ADD", rib, math_node(nt, "MULTIPLY", n, v=.15))
        col = ramp(nt, height, [(0, (.55, .55, .55)), (1, (.95, .95, .95))])
        rough = math_node(nt, "ADD", math_node(nt, "MULTIPLY", rib, v=-.2), v=.95)
    elif kind == "velvet":
        crush = noise(nt, vec, w, 4.0, 5, .65, 1.2)
        height = math_node(nt, "ADD", math_node(nt, "MULTIPLY", n, v=.25), math_node(nt, "MULTIPLY", crush, v=.5))
        col = ramp(nt, crush, [(0, (.6, .6, .6)), (.5, (.85, .85, .85)), (1, (1, 1, 1))])
        rough = math_node(nt, "ADD", math_node(nt, "MULTIPLY", crush, v=.2), v=.7)
    else:  # skaï : grain de cuir synthétique (cellules)
        vo = nt.nodes.new("ShaderNodeTexVoronoi"); vo.voronoi_dimensions = "4D"; vo.feature = "DISTANCE_TO_EDGE"
        vo.inputs["Scale"].default_value = 90.0
        nt.links.new(vec, vo.inputs["Vector"]); nt.links.new(w, vo.inputs["W"])
        edge = math_node(nt, "MINIMUM", math_node(nt, "MULTIPLY", vo.outputs["Distance"], v=8.0), None, None) if False else math_node(nt, "MULTIPLY", vo.outputs["Distance"], v=8.0)
        edge = math_node(nt, "MINIMUM", edge, v=1.0)
        height = math_node(nt, "ADD", edge, math_node(nt, "MULTIPLY", n, v=.2))
        col = ramp(nt, n, [(0, (.88, .88, .88)), (1, (1, 1, 1))])
        rough = math_node(nt, "ADD", math_node(nt, "MULTIPLY", edge, v=-.25), v=.55)
    return col, height, rough


def bake_set(name, builder, bump=.6):
    plane = setup()
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    plane.data.materials.append(mat)
    nt, N, Lk = nodes_for(mat)
    col, height, rough = builder(nt)
    out = N.new("ShaderNodeOutputMaterial")
    bsdf = N.new("ShaderNodeBsdfPrincipled")
    bp = N.new("ShaderNodeBump"); bp.inputs["Strength"].default_value = bump; bp.inputs["Distance"].default_value = .01
    Lk.new(height, bp.inputs["Height"]); Lk.new(bp.outputs["Normal"], bsdf.inputs["Normal"])
    emit = N.new("ShaderNodeEmission")
    img_node = N.new("ShaderNodeTexImage")
    N.active = img_node
    for suffix, src in (("diff", col), ("rough", rough), ("nor", None)):
        img = bpy.data.images.new("%s_%s" % (name, suffix), RES, RES, alpha=False, float_buffer=False)
        img.colorspace_settings.name = "sRGB" if suffix == "diff" else "Non-Color"
        img_node.image = img
        plane.select_set(True)
        bpy.context.view_layer.objects.active = plane
        if suffix == "nor":
            Lk.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
            bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", margin=0)
        else:
            Lk.new(src, emit.inputs["Color"])
            Lk.new(emit.outputs["Emission"], out.inputs["Surface"])
            bpy.ops.object.bake(type="EMIT", margin=0)
        img.filepath_raw = OUT + "%s_%s.jpg" % (name, suffix)
        img.file_format = "JPEG"
        img.save()
        try:  # Godot refuse les JPEG avec profil ICC : on réenregistre sans
            from PIL import Image as _I
            _I.open(img.filepath_raw).convert("RGB").save(img.filepath_raw, quality=92)
        except ImportError:
            pass
        print("cuit :", img.filepath_raw)


SETS = {
    "teak_wood": lambda nt: wood(nt, [(0, (.30, .13, .05)), (.45, (.55, .27, .1)), (.7, (.66, .36, .15)), (1, (.78, .47, .22))], 70, 2.0, pores=.35),
    "rosewood": lambda nt: wood(nt, [(0, (.03, .01, .005)), (.35, (.12, .04, .02)), (.6, (.26, .09, .04)), (1, (.42, .17, .07))], 45, 4.0, pores=.25),
    "light_oak": lambda nt: wood(nt, [(0, (.48, .36, .22)), (.5, (.68, .53, .34)), (1, (.82, .69, .48))], 55, 1.6, pores=.6, rays=.35),
    "corduroy": lambda nt: fabric(nt, "corduroy"),
    "velvet": lambda nt: fabric(nt, "velvet"),
    "vinyl": lambda nt: fabric(nt, "vinyl"),
}
wanted = [a for a in sys.argv[1:] if not a.startswith("-")] or list(SETS)
for nm in wanted:
    bake_set(nm, SETS[nm], .35 if nm in ("velvet",) else .7)
