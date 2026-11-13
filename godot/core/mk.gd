class_name Mk
## Boîte à outils de modélisation : matériaux, formes générées par le code, petites pièces (potards, vis, écrans).

static var _cache := {}


# ---------------------------------------------------------------- couleurs & matériaux
static func c(hex: int, a := 1.0) -> Color:
	var col := Color.hex((hex << 8) | 0xff)
	col.a = a
	return col


## Matériau standard. opts : map, normal, normal_scale, clearcoat, clearcoat_rough, emission, energy,
## emission_tex, alpha, cull_off, rim, unshaded, fog_off, uv_scale
static func mat(color: Color, rough := 0.5, metal := 0.0, opts := {}) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	m.metallic_specular = 0.5
	if opts.has("map"):
		m.albedo_texture = opts.map
	if opts.has("normal") and opts.normal != null:
		m.normal_enabled = true
		m.normal_texture = opts.normal
		m.normal_scale = opts.get("normal_scale", 1.0)
	if opts.has("clearcoat"):
		m.clearcoat_enabled = true
		m.clearcoat = opts.clearcoat
		m.clearcoat_roughness = opts.get("clearcoat_rough", 0.3)
	if opts.has("emission"):
		m.emission_enabled = true
		m.emission = opts.emission
		m.emission_energy_multiplier = opts.get("energy", 1.0)
		if opts.has("emission_tex"):
			m.emission_texture = opts.emission_tex
	if opts.has("alpha"):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = opts.alpha
	if opts.get("cull_off", false):
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if opts.has("rim"):
		m.rim_enabled = true
		m.rim = opts.rim
		m.rim_tint = 0.4
	if opts.get("unshaded", false):
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if opts.get("fog_off", false):
		m.disable_fog = true
	if opts.has("uv_scale"):
		m.uv1_scale = opts.uv_scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## Écran / LED : noir, qui émet de la lumière (bloom). Avec une texture : shader d'écran.
static func glow(color: Color, energy := 1.4, tex: Texture2D = null) -> Material:
	if tex:
		var sm := ShaderMaterial.new()
		sm.shader = load("res://core/shaders/screen.gdshader")
		sm.set_shader_parameter("screen_tex", tex)
		sm.set_shader_parameter("energy", energy)
		return sm
	return mat(Color.BLACK, 0.4, 0.0, {"emission": color, "energy": energy})


static func scratch_normal() -> Texture2D:
	if not _cache.has("scratch"):
		_cache["scratch"] = load("res://assets/textures/Scratched_gold_01_1K_Normal.png")
	return _cache["scratch"]


static func black_knob_mat() -> StandardMaterial3D:
	if not _cache.has("bk"):
		_cache["bk"] = mat(c(0x0b0b0c), 0.38, 0.0, {"clearcoat": 0.5, "clearcoat_rough": 0.4})
	return _cache["bk"]


static func chrome_mat() -> StandardMaterial3D:
	if not _cache.has("chrome"):
		_cache["chrome"] = mat(c(0xd7d3cb), 0.28, 1.0)
	return _cache["chrome"]


static func walnut_mat() -> StandardMaterial3D:
	if not _cache.has("walnut"):
		var t := Tex.canvas(1024, 1024, func(ci, w, h): Tex.woodgrain(ci, 3, c(0x4a2c19), Color(0.1, 0.047, 0.02, 1), w, h))
		_cache["walnut_tex"] = t
		_cache["walnut"] = mat(Color.WHITE, 0.5, 0.0, {"map": t, "clearcoat": 0.5, "clearcoat_rough": 0.35})
	return _cache["walnut"]


static func walnut_tex() -> Texture2D:
	walnut_mat()
	return _cache["walnut_tex"]


# ---------------------------------------------------------------- transformations façon three.js
## Ordre XYZ de three.js : M = Rx * Ry * Rz
static func euler_xyz(x: float, y: float, z: float) -> Basis:
	return Basis(Vector3.RIGHT, x) * Basis(Vector3.UP, y) * Basis(Vector3.BACK, z)


## Ordre YXZ de three.js : M = Ry * Rx * Rz
static func euler_yxz(x: float, y: float, z := 0.0) -> Basis:
	return Basis(Vector3.UP, y) * Basis(Vector3.RIGHT, x) * Basis(Vector3.BACK, z)


static func mi(mesh: Mesh, material: Material = null, pos := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	if material:
		m.material_override = material
	m.position = pos
	if parent:
		parent.add_child(m)
	return m


# ---------------------------------------------------------------- primitives Godot
static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func cyl(r_top: float, r_bot: float, h: float, segs := 32, caps := true) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	cm.cap_top = caps
	cm.cap_bottom = caps
	return cm


static func sphere(r: float, segs := 24, rings := 12, hemi := false) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * (1.0 if hemi else 2.0)
	s.radial_segments = segs
	s.rings = rings
	s.is_hemisphere = hemi
	return s


static func quad(w: float, h: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	return q


static func plane(w: float, d: float) -> PlaneMesh:
	var p := PlaneMesh.new()
	p.size = Vector2(w, d)
	return p


# ---------------------------------------------------------------- formes générées
static func _tri(st: SurfaceTool, a: int, b: int, cc: int) -> void:
	st.add_index(a)
	st.add_index(b)
	st.add_index(cc)


## Boîte aux arêtes arrondies (comme RoundedBoxGeometry). 6 surfaces : +X, -X, +Y, -Y, +Z, -Z.
## mats : un matériau, ou un tableau de 6. UV de chaque face : image à l'endroit vue de l'extérieur
## (+Y : u vers +X, haut de l'image vers -Z ; +Z : u vers +X, haut vers +Y).
static func rounded_box(size: Vector3, r: float, mats = null, steps := 3) -> ArrayMesh:
	var h := size / 2.0
	r = clampf(r, 0.00001, minf(h.x, minf(h.y, h.z)) * 0.999)
	var inner := h - Vector3(r, r, r)
	var faces := [
		[Vector3.RIGHT, Vector3.FORWARD, Vector3.DOWN],
		[Vector3.LEFT, Vector3.BACK, Vector3.DOWN],
		[Vector3.UP, Vector3.RIGHT, Vector3.BACK],
		[Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD],
		[Vector3.BACK, Vector3.RIGHT, Vector3.DOWN],
		[Vector3.FORWARD, Vector3.LEFT, Vector3.DOWN],
	]
	var am := ArrayMesh.new()
	for fi in 6:
		var n: Vector3 = faces[fi][0]
		var ud: Vector3 = faces[fi][1]
		var vd: Vector3 = faces[fi][2]
		var hn := absf(h.dot(n))
		var hu := absf(h.dot(ud))
		var hv := absf(h.dot(vd))
		var cu := _edge_coords(hu, r, steps)
		var cv := _edge_coords(hv, r, steps)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for j in cv.size():
			for i in cu.size():
				var p: Vector3 = n * hn + ud * cu[i] + vd * cv[j]
				var cl := p.clamp(-inner, inner)
				var d := p - cl
				var nn := n if d.length() < 1e-7 else d.normalized()
				st.set_normal(nn)
				st.set_uv(Vector2((cu[i] + hu) / (2.0 * hu), (cv[j] + hv) / (2.0 * hv)))
				st.add_vertex(cl + nn * r)
		var cols := cu.size()
		# Godot : faces avant dans le sens horaire vues de dehors (produit vectoriel vers l'intérieur)
		var cw := ud.cross(vd).dot(n) < 0
		for j in cv.size() - 1:
			for i in cols - 1:
				var a := j * cols + i
				if cw:
					_tri(st, a, a + 1, a + cols)
					_tri(st, a + 1, a + cols + 1, a + cols)
				else:
					_tri(st, a, a + cols, a + 1)
					_tri(st, a + 1, a + cols, a + cols + 1)
		st.generate_tangents()
		st.commit(am)
		var m = mats[fi] if mats is Array else mats
		if m:
			am.surface_set_material(fi, m)
	return am


static func _edge_coords(hh: float, r: float, k: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for t in k + 1:
		out.append(-(hh - r) - r * cos(float(t) / k * PI / 2.0))
	if hh - r > 1e-6:
		for t in range(k, -1, -1):
			out.append((hh - r) + r * cos(float(t) / k * PI / 2.0))
	else:
		for t in range(k - 1, -1, -1):
			out.append((hh - r) + r * cos(float(t) / k * PI / 2.0))
	return out


## Tour (lathe) : profil [[rayon, y], ...] tourné autour de Y.
static func lathe(profile: Array, segs := 48) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var np := profile.size()
	for j in segs + 1:
		var th := float(j) / segs * TAU
		for i in np:
			var rr: float = profile[i][0]
			st.set_uv(Vector2(float(j) / segs, float(i) / (np - 1)))
			st.add_vertex(Vector3(rr * cos(th), profile[i][1], rr * sin(th)))
	for j in segs:
		for i in np - 1:
			var a := j * np + i
			_tri(st, a, a + np, a + 1)
			_tri(st, a + 1, a + np, a + np + 1)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## Tube le long d'une courbe Catmull-Rom passant par les points.
static func tube(points: Array, radius: float, tsegs := 48, rsegs := 8) -> ArrayMesh:
	var pts: Array[Vector3] = []
	for p in points:
		pts.append(p)
	var samples: Array[Vector3] = []
	var nseg := pts.size() - 1
	for s in tsegs + 1:
		var u := float(s) / tsegs * nseg
		var i := mini(int(u), nseg - 1)
		var t := u - i
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, nseg)]
		if i == 0:
			p0 = p1 * 2.0 - p2
		if i + 2 > nseg:
			p3 = p2 * 2.0 - p1
		samples.append(p1.cubic_interpolate(p2, p0, p3, t))
	return _sweep(samples, radius, rsegs)


static func _sweep(samples: Array[Vector3], radius: float, rsegs: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := samples.size()
	var t0 := (samples[1] - samples[0]).normalized()
	var nrm := t0.cross(Vector3.UP)
	if nrm.length() < 0.01:
		nrm = t0.cross(Vector3.RIGHT)
	nrm = nrm.normalized()
	for s in n:
		var tg := (samples[mini(s + 1, n - 1)] - samples[maxi(s - 1, 0)]).normalized()
		nrm = (nrm - tg * nrm.dot(tg)).normalized()
		var bn := tg.cross(nrm)
		for k in rsegs + 1:
			var th := float(k) / rsegs * TAU
			var off := nrm * cos(th) + bn * sin(th)
			st.set_normal(off)
			st.set_uv(Vector2(float(k) / rsegs, float(s) / (n - 1)))
			st.add_vertex(samples[s] + off * radius)
	var rc := rsegs + 1
	for s in n - 1:
		for k in rsegs:
			var a := s * rc + k
			_tri(st, a, a + rc, a + 1)
			_tri(st, a + 1, a + rc, a + rc + 1)
	return st.commit()


## Arc de tore (accoudoirs de la chaise) : rayon R, tube r, angle arc, dans le plan XY.
static func torus_arc(R: float, r: float, arc: float, segs := 24, rsegs := 8) -> ArrayMesh:
	var s: Array[Vector3] = []
	for i in segs + 1:
		var a := float(i) / segs * arc
		s.append(Vector3(cos(a) * R, sin(a) * R, 0))
	return _sweep(s, r, rsegs)


## Anneau (tore complet) à plat dans le plan XZ.
static func torus_ring(R: float, r: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = R - r
	t.outer_radius = R + r
	t.rings = 32
	t.ring_segments = 8
	return t


## Disque à plat face +Y, UV planaires (dessus de potard, étiquette de disque).
static func disc(r: float, segs := 64) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	st.set_uv(Vector2(0.5, 0.5))
	st.add_vertex(Vector3.ZERO)
	for j in segs + 1:
		var th := float(j) / segs * TAU
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.5 + cos(th) * 0.5, 0.5 + sin(th) * 0.5))
		st.add_vertex(Vector3(cos(th) * r, 0, sin(th) * r))
	for j in segs:
		_tri(st, 0, j + 1, j + 2)
	st.generate_tangents()
	return st.commit()


## Prisme : polygone (plan XY) extrudé de z = 0 à z = depth.
static func prism(poly: PackedVector2Array, depth: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx := Geometry2D.triangulate_polygon(poly)
	var cen := Vector2.ZERO
	for p in poly:
		cen += p
	cen /= poly.size()
	for cap in [[depth, Vector3.BACK], [0.0, Vector3.FORWARD]]:
		for t in range(0, idx.size(), 3):
			var tri := [poly[idx[t]], poly[idx[t + 1]], poly[idx[t + 2]]]
			_flat_tri(st, Vector3(tri[0].x, tri[0].y, cap[0]), Vector3(tri[1].x, tri[1].y, cap[0]), Vector3(tri[2].x, tri[2].y, cap[0]), cap[1])
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var e := b - a
		var nn := Vector3(e.y, -e.x, 0).normalized()
		var mid := (a + b) / 2.0
		if Vector2(nn.x, nn.y).dot(mid - cen) < 0:
			nn = -nn
		var A := Vector3(a.x, a.y, 0)
		var B := Vector3(b.x, b.y, 0)
		var A2 := Vector3(a.x, a.y, depth)
		var B2 := Vector3(b.x, b.y, depth)
		_flat_tri(st, A, B, B2, nn)
		_flat_tri(st, A, B2, A2, nn)
	st.generate_tangents()
	return st.commit()


static func _flat_tri(st: SurfaceTool, a: Vector3, b: Vector3, cc: Vector3, n_out: Vector3) -> void:
	if (b - a).cross(cc - a).dot(n_out) > 0:
		var t := b
		b = cc
		cc = t
	for v in [a, b, cc]:
		st.set_normal(n_out)
		var uv := Vector2(v.x, v.y) * 4.0 if absf(n_out.z) > 0.5 else Vector2(v.x + v.y, v.z) * 4.0
		st.set_uv(uv)
		st.add_vertex(v)


# ---------------------------------------------------------------- pièces
## Potard noir à jupe (lathe) avec trait blanc. Axe +Y. Renvoie un Node3D ; meta "spin" = nœud qui tourne.
static func knob(r: float, h: float, color = null) -> Node3D:
	var g := Node3D.new()
	var prof := [[0, 0], [r * 1.35, 0], [r * 1.35, h * .15], [r * 1.05, h * .22], [r, h * .9], [r * .9, h], [0, h]]
	var m := black_knob_mat() if color == null else mat(color, 0.35, 0.0, {"clearcoat": 0.6})
	mi(lathe(prof, 48), m, Vector3.ZERO, g)
	mi(box(Vector3(r * .14, .0006, r * .9)), mat(c(0xf2efe8), 0.6), Vector3(0, h + .0003, -r * .45), g)
	g.set_meta("spin", g)
	return g


## Gros potard alu moleté. Axe +Y.
static func alu_knob(r: float, h: float) -> Node3D:
	var g := Node3D.new()
	if not _cache.has("knurl"):
		var img := Image.create(1024, 32, false, Image.FORMAT_L8)
		for x in 1024:
			var v := 1.0 if (x % 6) < 3 else 0.2
			for y in 32:
				img.set_pixel(x, y, Color(v, v, v))
		_cache["knurl"] = Tex.normal_from_bump(img, 4.0)
		_cache["alu_top"] = Tex.canvas(512, 512, func(ci, w, hh):
			ci.draw_rect(Rect2(0, 0, w, hh), c(0x77746f))
			var rr := Tex.rng(2)
			for i in 3000:
				var a := rr.randf() * 7.0
				ci.draw_arc(Vector2(256, 256), rr.randf() * 256.0, a, a + .3 + rr.randf(), 8, Color(1, 1, 1, rr.randf() * .09), 1.0)
			for i in 12:
				ci.draw_circle(Vector2(256, 130), 44.0 - i * 3.5, Color(0, 0, 0, 0.035 * (i + 1) * 0.25)))
	var body := Node3D.new()
	g.add_child(body)
	var side := mat(c(0x75726d), 0.45, 1.0, {"normal": _cache["knurl"], "normal_scale": 1.0})
	mi(cyl(r, r * 1.02, h, 96, false), side, Vector3(0, h / 2, 0), body)
	mi(disc(r, 96), mat(Color.WHITE, 0.42, 1.0, {"map": _cache["alu_top"]}), Vector3(0, h, 0), body)
	mi(cyl(r * 1.25, r * 1.3, h * .12, 96), black_knob_mat(), Vector3(0, h * .06, 0), g)
	g.set_meta("spin", body)
	return g


static func screw_head(r := .004) -> MeshInstance3D:
	if not _cache.has("screw_mat"):
		_cache["screw_mat"] = mat(c(0x9a968f), 0.32, 1.0)
		_cache["screw_mesh"] = sphere(r, 20, 8, true)
	var s := mi(_cache["screw_mesh"], _cache["screw_mat"])
	s.scale = Vector3(1, .45, 1)
	return s


## Fenêtre d'écran à plat (+Y) : cadre noir, écran émissif, vitre teintée.
static func screen_window(screen_mat: Material, w: float, d: float, tint: Color) -> Node3D:
	var g := Node3D.new()
	mi(rounded_box(Vector3(w + .006, .003, d + .006), .001, mat(c(0x050505), 0.4)), null, Vector3.ZERO, g)
	mi(plane(w, d), screen_mat, Vector3(0, .0017, 0), g)
	mi(plane(w, d), mat(tint, 0.05, 0.0, {"alpha": .25, "clearcoat": 1.0}), Vector3(0, .0023, 0), g)
	return g


## Même chose, face +Z (façades de rack).
static func face_window(screen_mat: Material, w: float, h: float, tint: Color) -> Node3D:
	var g := Node3D.new()
	mi(rounded_box(Vector3(w + .006, h + .006, .003), .001, mat(c(0x050505), 0.4)), null, Vector3.ZERO, g)
	mi(quad(w, h), screen_mat, Vector3(0, 0, .0017), g)
	mi(quad(w, h), mat(tint, 0.05, 0.0, {"alpha": .25, "clearcoat": 1.0}), Vector3(0, 0, .0023), g)
	return g


## Panneau à plat dont la face du dessus porte un dessin (texture cuite).
## draw(ci, P, W, H) avec P(mètres) -> pixels.
static func panel(w: float, d: float, draw: Callable, o := {}) -> MeshInstance3D:
	var W: int = o.get("res", 2048)
	var H := int(round(W * d / w))
	var P := func(m: float) -> float: return m / w * W
	var t := Tex.canvas(W, H, func(ci, ww, hh): draw.call(ci, P, ww, hh))
	var top := mat(Color.WHITE, o.get("rough", 0.42), o.get("metal", 0.85), {"map": t})
	if o.get("scratch", true):
		top.normal_enabled = true
		top.normal_texture = scratch_normal()
		top.normal_scale = 0.25
	if o.has("clear"):
		top.clearcoat_enabled = true
		top.clearcoat = o.clear
	var side := mat(o.get("side", c(0x151515)), 0.5, 0.5)
	var th: float = o.get("t", 0.004)
	var mats := [side, side, top, side, side, side]
	return mi(rounded_box(Vector3(w, th, d), minf(.0015, th / 2.2), mats, 2))


## AABB de tous les meshes d'un nœud, dans le repère de ce nœud.
static func local_aabb(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var inv := root.global_transform.affine_inverse()
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var m := n as MeshInstance3D
		var bb: AABB = (inv * m.global_transform) * m.get_aabb()
		out = bb if first else out.merge(bb)
		first = false
	return out


## Zone cliquable (boîte) autour d'un nœud. layer 1 = machines, 2 = commandes.
static func add_pick(root: Node3D, action: String, layer := 1, grow := 0.0) -> StaticBody3D:
	var bb := local_aabb(root).grow(grow)
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.set_meta("action", action)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = bb.size.max(Vector3(.002, .002, .002))
	cs.shape = shape
	cs.position = bb.get_center()
	body.add_child(cs)
	root.add_child(body)
	return body


## Zone cliquable de commande (couche 2) posée dès que le nœud entre dans la scène.
static func add_pick_later(root: Node3D, action: String, grow := 0.0) -> void:
	root.ready.connect(func(): add_pick(root, action, 2, grow), CONNECT_ONE_SHOT)
