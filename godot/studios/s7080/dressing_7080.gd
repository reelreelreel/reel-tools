class_name Dressing7080
extends Node3D
## Habillage de la régie (construit après les machines) :
##   · usure et patine en décalques (moquette tassée, chemin depuis la porte, ronds de tasse, traces) ;
##   · détails techniques (prises et interrupteurs bakélite, grilles de clim, détecteur de fumée,
##     extincteur, panneau de sortie) ;
##   · bazar de fin de nuit de session (canettes, cendriers pleins, tasses, paroles, boulettes,
##     boîte à pizza, casque sur le canapé) ;
##   · ambiance (lampe à lave) ;
##   · étiquettes de scotch manuscrites sur les machines ;
##   · cadres qui affichent les images déposées dans res://assets/frames/.

var s: Studio7080
var _tex := {}


func _init(studio: Studio7080) -> void:
	name = "Dressing"
	s = studio


func build() -> void:
	_tech()
	_machine_details()
	_lava_lamp(Vector3(1.6, .968, -5.68))
	_frames()


static func _rot(n: Node3D, axis: String, v: float) -> Node3D:
	n.rotation[axis] = v
	return n


# ---------------------------------------------------------------- décalques
## Décalque projeté vers le bas (axe -Y local). size = (largeur, profondeur de projection, longueur).
func _decal(tex: Texture2D, at: Vector3, size: Vector3, yaw := 0.0, mix := 1.0, normal: Texture2D = null) -> Decal:
	var d := Decal.new()
	d.texture_albedo = tex
	if normal:
		d.texture_normal = normal
	d.size = size
	d.albedo_mix = mix
	d.position = at
	d.rotation.y = yaw
	d.upper_fade = .2
	d.lower_fade = .2
	d.cull_mask = 1
	add_child(d)
	return d


func _soft_blob(key: String, col: Color, rings := false) -> Texture2D:
	if _tex.has(key):
		return _tex[key]
	var t := Tex.canvas(256, 256, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0))
		var r := Tex.rng(key.hash())
		for i in 220:
			var p := Vector2(w / 2.0, h / 2.0) + Vector2(r.randfn(0, w * .16), r.randfn(0, h * .16))
			var c := col
			c.a = col.a * r.randf_range(.1, .35)
			ci.draw_circle(p, r.randf_range(8, 30), c)
		if rings:
			for k in 3:
				ci.draw_arc(Vector2(w / 2.0, h / 2.0), w * .3 + k * 3, 0, TAU, 64, Color(col.r, col.g, col.b, .35 - k * .1), 4.0), true)
	_tex[key] = t
	return t


func _ring_tex() -> Texture2D:
	if not _tex.has("ring"):
		_tex["ring"] = Tex.canvas(256, 256, func(ci, w, h):
			ci.draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0))
			var c := Vector2(w / 2.0, h / 2.0)
			ci.draw_arc(c, w * .36, 0, TAU, 96, Color(.18, .08, .02, .55), 7.0)
			ci.draw_arc(c, w * .33, .4, 4.8, 64, Color(.18, .08, .02, .3), 4.0)
			ci.draw_arc(c, w * .38, 2.0, 5.5, 64, Color(.12, .05, .01, .25), 3.0), true)
	return _tex["ring"]


func _scratch_tex() -> Texture2D:
	if not _tex.has("scratch"):
		_tex["scratch"] = Tex.canvas(512, 512, func(ci, w, h):
			ci.draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0))
			var r := Tex.rng(91)
			for i in 90:
				var p := Vector2(r.randf() * w, r.randf() * h)
				var a := r.randf() * TAU
				var l := r.randf_range(10, 90)
				ci.draw_line(p, p + Vector2(cos(a), sin(a)) * l, Color(1, .9, .8, r.randf_range(.08, .25)), r.randf_range(.8, 1.8))
			for i in 40:
				ci.draw_circle(Vector2(r.randf() * w, r.randf() * h), r.randf_range(3, 14), Color(.05, .03, .02, r.randf_range(.05, .15))), true)
	return _tex["scratch"]


func _wear() -> void:
	# moquette tassée sous le fauteuil (roulettes) et chemin depuis la porte
	var dark := Color(.08, .04, .02, .55)
	_decal(_soft_blob("seat", dark), Vector3(s.SEAT.x, .2, s.SEAT.z - .05), Vector3(1.5, .5, 1.3), 0.0, .9)
	var a := Vector3(Studio7080.DOOR.x, 0, -Studio7080.ROOM.z + .5)
	var b := Vector3(s.SEAT.x - .3, 0, s.SEAT.z - .7)
	for i in 6:
		var t := (i + .5) / 6.0
		var p := a.lerp(b, t)
		_decal(_soft_blob("path%d" % (i % 3), Color(.07, .035, .015, .4)), Vector3(p.x, .2, p.z), Vector3(.8, .5, .9), atan2(b.x - a.x, b.z - a.z), .8)
	# devant le canapé, sous le pouf, devant les machines
	_decal(_soft_blob("sofa", dark), Vector3(3.1, .2, -4.9), Vector3(2.2, .5, .9), 0.0, .7)
	_decal(_soft_blob("side", dark), Vector3(4.05, .2, -2.9), Vector3(.9, .5, 2.0), 0.0, .7)
	# éraflures et traces au sol près de la porte
	_decal(_scratch_tex(), Vector3(Studio7080.DOOR.x, .2, -Studio7080.ROOM.z + .45), Vector3(1.1, .5, .8), 0.0, 1.0)
	# ronds de tasse et rayures sur les plateaux en bois
	var top := Studio7080.DESK_TOP + .05
	for p in [Vector3(1.4, top, -1.2), Vector3(3.62, top, -1.25), Vector3(1.55, top, -1.15), Vector3(4.55, top, -2.48), Vector3(4.7, top, -3.75), Vector3(4.15, top, -1.05), Vector3(4.3, top, -1.45)]:
		_decal(_ring_tex(), p, Vector3(.09, .12, .09), randf() * TAU, 1.0)
	for p in [Vector3(2.5, top, -1.28), Vector3(4.6, top, -2.9), Vector3(.7, top, -1.6), Vector3(4.4, top, -1.6)]:
		_decal(_scratch_tex(), p, Vector3(.7, .12, .25), randf() * .3, 1.0)


# ---------------------------------------------------------------- détails techniques
func _bakelite() -> Material:
	if not _tex.has("bak"):
		_tex["bak"] = Mk.mat(Mk.c(0x3a2414), .35, 0.0, {"clearcoat": .6})
	return _tex["bak"]


## Prise de courant bakélite (face +Z, au mur). double = deux prises.
func _outlet(at: Vector3, yaw: float, double := true) -> void:
	var g := Node3D.new()
	g.position = at
	g.rotation.y = yaw
	add_child(g)
	var w := .16 if double else .085
	Mk.mi(Mk.rounded_box(Vector3(w, .085, .018), .01, _bakelite(), 3), null, Vector3(0, 0, .009), g)
	var n := 2 if double else 1
	for i in n:
		var x := (i - (n - 1) / 2.0) * .075
		_rot(Mk.mi(Mk.cyl(.026, .026, .01, 24), Mk.mat(Mk.c(0x2a1a10), .4), Vector3(x, 0, .02), g), "x", PI / 2)
		for sx in [-1, 1]:
			_rot(Mk.mi(Mk.cyl(.0035, .0035, .012, 8), Mk.mat(Mk.c(0x050403), 1.0), Vector3(x + sx * .0095, 0, .022), g), "x", PI / 2)
		_rot(Mk.mi(Mk.cyl(.0025, .0025, .004, 8), Mk.mat(Mk.c(0xc8c4bc), .3, 1.0), Vector3(x, .016, .026), g), "x", PI / 2)
	var sc := Mk.screw_head(.003)
	sc.rotation.x = PI / 2
	sc.position = Vector3(0, 0, .019)
	g.add_child(sc)


## Interrupteur à bascule bakélite.
func _switch(at: Vector3, yaw: float) -> void:
	var g := Node3D.new()
	g.position = at
	g.rotation.y = yaw
	add_child(g)
	Mk.mi(Mk.rounded_box(Vector3(.08, .12, .015), .01, _bakelite(), 3), null, Vector3(0, 0, .0075), g)
	var t := Mk.mi(Mk.rounded_box(Vector3(.022, .045, .016), .006, Mk.mat(Mk.c(0x2a1a10), .3, 0.0, {"clearcoat": .7}), 2), null, Vector3(0, 0, .02), g)
	t.rotation.x = .25
	for sy in [-1, 1]:
		var sc := Mk.screw_head(.0028)
		sc.rotation.x = PI / 2
		sc.position = Vector3(0, sy * .045, .016)
		g.add_child(sc)


func _vent(at: Vector3, w: float, d: float) -> void:
	var g := Node3D.new()
	g.position = at
	add_child(g)
	var alu := Mk.mat(Mk.c(0xc8c4b8), .4, .6)
	Mk.mi(Mk.rounded_box(Vector3(w + .04, .015, d + .04), .006, alu, 2), null, Vector3(0, -.0075, 0), g)
	Mk.mi(Mk.box(Vector3(w, .002, d)), Mk.mat(Mk.c(0x0a0a0a), 1.0), Vector3(0, -.016, 0), g)
	var n := int(w / .025)
	for i in n:
		var bl := Mk.mi(Mk.box(Vector3(.002, .03, d - .01)), alu, Vector3(-w / 2 + .0125 + i * .025, -.025, 0), g)
		bl.rotation.z = .5


func _tech() -> void:
	var R := Studio7080.ROOM
	# prises au ras de la plinthe
	for p in [[Vector3(.003, .3, -1.75), PI / 2], [Vector3(.003, .3, -5.0), PI / 2], [Vector3(R.x - .003, .3, -1.6), -PI / 2], [Vector3(R.x - .003, .3, -5.95 + .12), -PI / 2], [Vector3(2.0, .3, -R.z + .003), 0.0], [Vector3(4.15, .3, -R.z + .003), 0.0], [Vector3(.3, .3, -.003), PI]]:
		_outlet(p[0], p[1])
	# interrupteurs à côté de la porte et dans la cabine de prise (mur gauche avant)
	_switch(Vector3(.17, 1.1, -R.z + .003), 0.0)
	_switch(Vector3(.25, 1.1, -R.z + .003) + Vector3(-.08, 0, 0), 0.0)
	# plaque micro/casque au mur de droite (liaison cabine)
	var plate := Node3D.new()
	plate.position = Vector3(.003, .42, -2.45)
	plate.rotation.y = PI / 2
	add_child(plate)
	Mk.mi(Mk.rounded_box(Vector3(.12, .12, .012), .004, Mk.mat(Mk.c(0x9a968e), .4, .8), 1), null, Vector3(0, 0, .006), plate)
	for k in 2:
		_rot(Mk.mi(Mk.cyl(.018, .018, .012, 20), Mk.mat(Mk.c(0x1a1a1a), .5), Vector3(-.025 + k * .05, .015, .014), plate), "x", PI / 2)
		_rot(Mk.mi(Mk.cyl(.006, .006, .014, 10), Mk.mat(Mk.c(0x050505), 1.0), Vector3(-.025 + k * .05, -.03, .014), plate), "x", PI / 2)
	# grilles de soufflage au plafond (hors nuage) + détecteur de fumée
	_vent(Vector3(1.0, R.y, -4.6), .5, .18)
	_vent(Vector3(3.9, R.y, -4.0), .5, .18)
	_vent(Vector3(2.5, R.y, -.5), .7, .14)
	var det := Node3D.new()
	det.position = Vector3(2.0, R.y, -4.9)
	add_child(det)
	Mk.mi(Mk.cyl(.06, .065, .035, 32), Mk.mat(Mk.c(0xe8e4da), .5), Vector3(0, -.018, 0), det)
	Mk.mi(Mk.cyl(.035, .04, .012, 24), Mk.mat(Mk.c(0xd8d4ca), .5), Vector3(0, -.04, 0), det)
	Mk.mi(Mk.sphere(.004, 8, 4), Mk.glow(Mk.c(0xff2a18), 3.0), Vector3(.03, -.04, 0), det)
	# extincteur sur son support, mur de droite près de la porte
	var ext := Node3D.new()
	ext.position = Vector3(.12, .55, -5.75)
	add_child(ext)
	var red := Mk.mat(Mk.c(0xb0160e), .35, .2, {"clearcoat": .7})
	Mk.mi(Mk.cyl(.075, .075, .42, 32), red, Vector3(0, .21, 0), ext)
	Mk.mi(Mk.sphere(.075, 24, 12, true), red, Vector3(0, .42, 0), ext)
	Mk.mi(Mk.cyl(.02, .025, .06, 16), Mk.mat(Mk.c(0x1a1a1a), .5, .6), Vector3(0, .5, 0), ext)
	var lever := Mk.mi(Mk.box(Vector3(.12, .012, .03)), Mk.mat(Mk.c(0x2a2a2a), .4, .8), Vector3(.03, .54, 0), ext)
	lever.rotation.z = .3
	Mk.mi(Mk.tube([Vector3(.0, .5, .02), Vector3(-.06, .45, .07), Vector3(-.07, .2, .08), Vector3(-.05, .1, .07)], .008, 16, 8), Mk.mat(Mk.c(0x111111), .6), Vector3.ZERO, ext)
	var lab := Tex.canvas(128, 160, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xf0ead8))
		Tex.silk(ci, "WATER + FOAM", w / 2.0, 28, 16, Color(.1, .1, .1), "center", 800)
		Tex.silk(ci, "1.6 GAL", w / 2.0, 70, 40, Mk.c(0xb0160e), "center", 800)
		for k in 5:
			ci.draw_line(Vector2(14, 95 + k * 12), Vector2(w - 14, 95 + k * 12), Color(.2, .2, .2, .6), 2.0))
	var lq := Mk.mi(Mk.cyl(.0755, .0755, .14, 32, false), Mk.mat(Color.WHITE, .7, 0.0, {"map": lab}), Vector3(0, .22, 0), ext)
	lq.rotation.y = PI / 2
	Mk.mi(Mk.rounded_box(Vector3(.02, .1, .1), .004, Mk.mat(Mk.c(0x2a2a2a), .4, .8), 1), null, Vector3(-.09, .35, 0), ext)
	# panneau « SORTIE » lumineux vert
	var ex := Node3D.new()
	ex.position = Vector3(.004, 2.3, -5.55)
	ex.rotation.y = PI / 2
	add_child(ex)
	Mk.mi(Mk.rounded_box(Vector3(.36, .14, .05), .008, Mk.mat(Mk.c(0xe8e4dc), .5), 2), null, Vector3(0, 0, .025), ex)
	var st := Tex.canvas(360, 140, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x0e8a3a))
		Tex.silk(ci, "EXIT", w * .58, h * .68, 56, Color(1, 1, 1), "center", 800)
		ci.draw_rect(Rect2(18, 34, 40, 72), Color(1, 1, 1))
		ci.draw_rect(Rect2(26, 42, 24, 56), Mk.c(0x0e8a3a)))
	Mk.mi(Mk.quad(.33, .11), Mk.mat(Color.WHITE, .4, 0.0, {"map": st, "emission": Color.WHITE, "energy": .45, "emission_tex": st}), Vector3(0, 0, .0505), ex)


# ---------------------------------------------------------------- bazar de fin de session
var _can_mesh: Mesh
var _can_mats := []


func _can(at: Vector3, crushed := false, lying := false, k := 0) -> void:
	if _can_mesh == null:
		_can_mesh = Mk.lathe([[0, 0], [.028, 0], [.033, .01], [.033, .108], [.028, .118], [0, .118]], 24)
		for c in [0x1a3a8a, 0xb82a1a, 0xc8a030, 0x2a6a3a]:
			var tex := Tex.canvas(256, 128, func(ci, w, h):
				ci.draw_rect(Rect2(0, 0, w, h), Mk.c(c))
				ci.draw_rect(Rect2(0, h * .38, w, h * .3), Color(1, 1, 1, .85))
				Tex.silk(ci, "PILS", w * .25, h * .62, 30, Mk.c(c), "center", 800)
				Tex.silk(ci, "PILS", w * .75, h * .62, 30, Mk.c(c), "center", 800))
			_can_mats.append(Mk.mat(Color.WHITE, .3, .7, {"map": tex}))
	var n := Node3D.new()
	n.position = at
	n.rotation.y = randf() * TAU
	add_child(n)
	var body := Mk.mi(_can_mesh, Mk.mat(Mk.c(0xc8c8cc), .25, 1.0), Vector3.ZERO, n)
	var wrap := Mk.mi(Mk.cyl(.0335, .0335, .07, 24, false), _can_mats[k % _can_mats.size()], Vector3(0, .05, 0), n)
	if crushed:
		n.scale = Vector3(1.15, .55, .8)
		n.rotation.z = randf_range(-.2, .2)
	if lying:
		n.rotation.z = PI / 2
		n.position.y += .033
	body.name = "Can"
	wrap.name = "Label"


func _butts(at: Vector3, n: int, r: float) -> void:
	var paper := Mk.mat(Mk.c(0xf0ece4), .8)
	var filt := Mk.mat(Mk.c(0xd88a40), .8)
	var ash := Mk.mat(Mk.c(0x6a6660), 1.0)
	var rr := Tex.rng(int(at.x * 100 + at.z * 10))
	for i in n:
		var p := at + Vector3(rr.randf_range(-r, r), .006 + rr.randf() * .008, rr.randf_range(-r, r))
		var g := Node3D.new()
		g.position = p
		g.rotation = Vector3(PI / 2 + rr.randf_range(-.4, .4), rr.randf() * TAU, rr.randf_range(-.3, .3))
		add_child(g)
		Mk.mi(Mk.cyl(.0042, .0042, .02, 8), filt, Vector3(0, -.008, 0), g)
		Mk.mi(Mk.cyl(.004, .004, .014, 8), paper, Vector3(0, .009, 0), g)
		Mk.mi(Mk.cyl(.0041, .0041, .003, 8), ash, Vector3(0, .017, 0), g)
	var dust := Mk.mi(Mk.cyl(r * .9, r * .9, .004, 20), ash, at + Vector3(0, .003, 0), self)
	dust.name = "Ash"


func _sheet(at: Vector3, yaw: float, seed: int, tilt := 0.0) -> void:
	var key := "sheet%d" % (seed % 4)
	if not _tex.has(key):
		_tex[key] = Tex.canvas(256, 340, func(ci, w, h):
			ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xf2ead8))
			for l in 22:
				ci.draw_line(Vector2(0, 30 + l * 14), Vector2(w, 30 + l * 14), Color(.5, .6, .8, .35), 1.0)
			var r := Tex.rng(seed)
			for l in 14:
				var y := 40 + l * 21
				var x := 22.0
				while x < w - 30 and r.randf() > .08:
					var ww := r.randf_range(12, 40)
					ci.draw_line(Vector2(x, y), Vector2(x + ww, y + r.randf_range(-2, 2)), Color(.08, .08, .3, .8), 2.2)
					x += ww + 8
			for k in 3:
				var y2 := 60 + r.randi_range(0, 10) * 24
				ci.draw_line(Vector2(20, y2), Vector2(w - 30, y2 + 4), Color(.1, .1, .3, .7), 2.0)
			Tex.grime(ci, w, h, seed, 2))
	var q := Mk.mi(Mk.quad(.21, .28), Mk.mat(Color.WHITE, .9, 0.0, {"map": _tex[key], "cull_off": true}), at, self)
	q.rotation = Vector3(-PI / 2 + tilt, yaw, 0)


func _ball(at: Vector3) -> void:
	var b := Mk.mi(Mk.sphere(.035, 10, 6), Mk.mat(Mk.c(0xece4d0), .9, 0.0, {"normal": Mk.noise_tex(1.5, 64, 2), "normal_scale": 3.0}), at + Vector3(0, .03, 0), self)
	b.scale = Vector3(1, .85, 1.1)
	b.rotation = Vector3(randf(), randf(), randf())


func _cup(at: Vector3) -> void:
	var g := Node3D.new()
	g.position = at
	add_child(g)
	Mk.mi(Mk.lathe([[0, 0], [.035, 0], [.042, .085], [.04, .088], [.033, .006], [0, .006]], 24), Mk.mat(Mk.c(0xf0ece4), .3, 0.0, {"clearcoat": .6, "cull_off": true}), Vector3.ZERO, g)
	Mk.mi(Mk.disc(.036, 24), Mk.mat(Mk.c(0x1a0c06), .1), Vector3(0, .055, 0), g)
	var h := Mk.mi(Mk.torus_ring(.022, .005), Mk.mat(Mk.c(0xf0ece4), .3), Vector3(.045, .045, 0), g)
	h.rotation.x = PI / 2
	g.rotation.y = randf() * TAU


func _pizza_box(at: Vector3, yaw: float) -> void:
	var g := Node3D.new()
	g.position = at
	g.rotation.y = yaw
	add_child(g)
	var card := Mk.mat(Mk.c(0xc8a878), .9)
	var top_tex := Tex.canvas(256, 256, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xd0b080))
		ci.draw_circle(Vector2(w / 2.0, h / 2.0), w * .3, Mk.c(0xb02018))
		Tex.silk(ci, "PIZZA", w / 2.0, h * .54, 44, Mk.c(0xf2ead8), "center", 800)
		Tex.silk(ci, "NAPOLI", w / 2.0, h * .66, 22, Mk.c(0xf2ead8), "center", 700)
		for i in 5:
			ci.draw_circle(Vector2(Tex.rng(i).randf() * w, Tex.rng(i + 9).randf() * h), 12 + i * 3, Color(.4, .2, .05, .18)))
	Mk.mi(Mk.box(Vector3(.33, .035, .33)), card, Vector3(0, .0175, 0), g)
	var lid := Node3D.new()
	lid.position = Vector3(0, .035, -.165)
	lid.rotation.x = -1.9
	g.add_child(lid)
	Mk.mi(Mk.box(Vector3(.33, .004, .33)), Mk.mat(Color.WHITE, .9, 0.0, {"map": top_tex}), Vector3(0, 0, .165), lid)
	Mk.mi(Mk.cyl(.14, .14, .005, 32), Mk.mat(Mk.c(0xc89048), .8), Vector3(0, .038, 0), g)
	# deux parts restantes
	for k in 2:
		var sl := Mk.mi(Mk.prism(PackedVector2Array([Vector2(0, 0), Vector2(.13, -.05), Vector2(.13, .05)]), .012), Mk.mat(Mk.c(0xc84a20), .7), Vector3(0, .04, 0), g)
		sl.rotation = Vector3(-PI / 2, k * 1.2 + .3, 0)


func _mess() -> void:
	var top := Studio7080.DESK_TOP
	seed(42)
	# canettes : sur le meuble de console, le bureau producteur, le multipiste, au sol
	var cans := [
		[Vector3(1.32, top, -1.28), false, false], [Vector3(3.68, top, -1.3), true, false],
		[Vector3(4.12, top, -.98), false, false], [Vector3(4.72, top, -2.85), false, false],
		[Vector3(4.6, top, -2.98), true, false], [Vector3(2.4, 0, -4.05), false, true],
		[Vector3(2.9, 0, -4.45), true, false], [Vector3(3.6, 0, -4.7), false, false],
		[Vector3(1.6, 0, -3.3), false, true], [Vector3(.9, top, -1.75), false, false],
	]
	for i in cans.size():
		_can(cans[i][0], cans[i][1], cans[i][2], i)
	# cendrier plein (asset) au pied du canapé + mégots dans celui de l'aile gauche
	var ash := Props.place(self, "props70.glb", Vector3(2.75, 0, -4.6), .4, {"keep": ["Ashtray_02"], "scale": .7})
	ash.name = "FloorAshtray"
	_butts(Vector3(2.75, .03, -4.6), 14, .07)
	var wc := Vector3(4.35, top, -1.32)
	var wy := atan2(2.5 - wc.x, -2.15 - wc.z)
	_butts(wc + Basis(Vector3.UP, wy) * Vector3(.27, .02, -.22), 8, .035)
	# tasses de café
	for p in [Vector3(3.6, top, -1.2), Vector3(4.78, top, -3.95), Vector3(2.55, 0, -4.35)]:
		_cup(p)
	# feuilles de paroles : sur le meuble, au sol, sur le canapé
	_sheet(Vector3(1.75, top + .002, -1.3), .2, 1)
	_sheet(Vector3(1.95, top + .003, -1.27), -.3, 2)
	_sheet(Vector3(2.9, .004, -3.2), 1.1, 3)
	_sheet(Vector3(3.3, .005, -3.0), -.6, 4)
	_sheet(Vector3(3.6, .46, -5.25), .4, 5, .1)
	_sheet(Vector3(4.55, top + .002, -2.95), 1.5, 6)
	# boulettes de papier
	for p in [Vector3(1.9, 0, -2.9), Vector3(3.4, 0, -2.6), Vector3(4.1, 0, -3.3), Vector3(2.2, 0, -3.6), Vector3(3.9, 0, -1.9)]:
		_ball(p)
	# boîte à pizza au pied du canapé
	_pizza_box(Vector3(3.55, 0, -4.4), .3)
	# casque Sony abandonné sur le canapé
	Props.place(self, "sony_mdr7506.glb", Vector3(2.6, .47, -5.35), 1.2, {"tilt": -PI / 2})


# ---------------------------------------------------------------- ambiance
## Lampe à lave 70s : socle cône alu, globe de verre, cire orange en boules, lueur.
func _lava_lamp(at: Vector3) -> void:
	var g := Node3D.new()
	g.position = at
	add_child(g)
	var alu := Mk.mat(Mk.c(0xb8b4ac), .25, 1.0)
	Mk.mi(Mk.lathe([[0, 0], [.07, 0], [.045, .13], [0, .13]], 32), alu, Vector3.ZERO, g)
	Mk.mi(Mk.lathe([[.045, .13], [.055, .2], [.04, .33], [.03, .33]], 32), Mk.mat(Mk.c(0xffb050), .05, 0.0, {"alpha": .45, "emission": Mk.c(0xff7a20), "energy": .6, "cull_off": true}), Vector3.ZERO, g)
	Mk.mi(Mk.lathe([[.03, .33], [.034, .38], [0, .38]], 24), alu, Vector3.ZERO, g)
	var wax := Mk.mat(Mk.c(0xff4a10), .3, 0.0, {"emission": Mk.c(0xff5a18), "energy": 2.0})
	for p in [[Vector3(.0, .16, 0), .032], [Vector3(.01, .24, .005), .018], [Vector3(-.008, .29, 0), .013], [Vector3(.005, .205, -.01), .012]]:
		var b := Mk.mi(Mk.sphere(p[1], 16, 8), wax, p[0], g)
		b.scale = Vector3(1, 1.25, 1)
	var l := OmniLight3D.new()
	l.light_color = Mk.c(0xff7a30)
	l.light_energy = .8
	l.omni_range = 1.4
	l.position = Vector3(0, .25, 0)
	g.add_child(l)


# ---------------------------------------------------------------- étiquettes sur les machines
func _tape_label(txt: String) -> Texture2D:
	var key := "tape:" + txt
	if not _tex.has(key):
		_tex[key] = Tex.canvas(256, 64, func(ci, w, h):
			ci.draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0))
			var pts := PackedVector2Array([Vector2(4, 8), Vector2(w - 6, 4), Vector2(w - 2, h - 8), Vector2(2, h - 4)])
			ci.draw_colored_polygon(pts, Mk.c(0xe8dcb8))
			for k in 6:
				ci.draw_line(Vector2(4 + k * 2, 8), Vector2(2 + k * 2, h - 4), Color(.6, .5, .3, .2), 1.0)
			Tex.silk(ci, txt, w / 2.0, h * .66, 30, Color(.08, .08, .25, .9), "center", 600, "caveat"), true)
	return _tex[key]


func _machine_labels() -> void:
	var items := [[s.tempo, "TEMPO - OK", Vector3(0, .2, .32)], [s.analyzer, "NE PAS EFFACER !", Vector3(-.17, .25, -.13)], [s.tuner, "808 ACC.", Vector3(.0, .3, .0)], [s.fax, "GRILLES R&B", Vector3(.1, .2, .1)], [s.export, "", Vector3.ZERO]]
	for it in items:
		var m: Node3D = it[0]
		if it[1] == "":
			continue
		var d := Decal.new()
		d.texture_albedo = _tape_label(it[1])
		d.size = Vector3(.11, .5, .028)
		d.upper_fade = .05
		d.lower_fade = .05
		m.add_child(d)
		d.position = it[2]
		d.rotation.y = randf_range(-.15, .15)
	# empreintes et poussière sur les façades (décalques horizontaux sur le meuble et les racks)
	var grime := _soft_blob("finger", Color(.6, .55, .5, .25))
	for m in [s.tempo, s.analyzer, s.fax, s.tuner]:
		var d := Decal.new()
		d.texture_albedo = grime
		d.size = Vector3(.3, .4, .25)
		d.albedo_mix = .35
		(m as Node3D).add_child(d)
		d.position = Vector3(0, .25, .05)


# ---------------------------------------------------------------- affiches et certifications (images de Maxime)
## Images dans res://assets/frames/ (copiées depuis « REEL TOOLS/AFFICHE 70s » sur son Mac).
## Affiches : [image, position, cap, largeur]. Certifications : [image, position, cap, "or" | "platine"].
const POSTERS := [
	["1_bowie", Vector3(1.75, 1.8, -5.995), 0.0, .5],
	["2_floyd", Vector3(4.995, 1.82, -3.55), -PI / 2, .45],
	["5_kiss", Vector3(4.58, 1.8, -5.995), 0.0, .42],
	["3_wonder", Vector3(.005, 2.02, -1.95), PI / 2, .34],
]
const PLAQUES := [
	["4_ewf", Vector3(4.995, 1.58, -1.25), -PI / 2, "or"],
	["3_wonder", Vector3(4.995, 1.92, -4.6), -PI / 2, "platine"],
	["5_kiss", Vector3(4.995, 1.72, -5.3), -PI / 2, "or"],
	["4_ewf", Vector3(4.995, 2.02, -2.05), -PI / 2, "platine"],
]


func _img(name: String) -> Texture2D:
	for e in ["jpg", "png", "jpeg", "webp"]:
		var p := "res://assets/frames/%s.%s" % [name, e]
		if ResourceLoader.exists(p):
			return load(p)
	return null


func _frames() -> void:
	var black := Mk.mat(Mk.c(0x0b0908), .35, 0.0, {"clearcoat": .6})
	for it in POSTERS:
		var tex := _img(it[0])
		if tex == null:
			continue
		var w: float = it[3]
		var h := w * float(tex.get_height()) / tex.get_width()
		var g := Node3D.new()
		g.position = it[1]
		g.rotation.y = it[2]
		add_child(g)
		Mk.mi(Mk.rounded_box(Vector3(w + .06, h + .06, .03), .004, black, 2), null, Vector3(0, 0, .015), g)
		Mk.mi(Mk.quad(w + .02, h + .02), Mk.mat(Mk.c(0xf2ead8), .9), Vector3(0, 0, .031), g)
		Mk.mi(Mk.quad(w, h), Mk.mat(Color.WHITE, .6, 0.0, {"map": tex}), Vector3(0, 0, .032), g)
		Mk.mi(Mk.quad(w + .05, h + .05), Mk.mat(Color.WHITE, .03, 0.0, {"alpha": .08, "clearcoat": 1.0}), Vector3(0, 0, .036), g)
		_picture_light(g, w + .06, h + .06)
	for it in PLAQUES:
		var tex := _img(it[0])
		if tex == null:
			continue
		var g := _plaque(tex, it[3])
		g.position = it[1]
		g.rotation.y = it[2]
		add_child(g)


## Certification façon disque d'or / de platine : cadre noir laqué, fond de velours, disque métal
## gravé avec étiquette, pochette en réduction, plaque gravée en laiton, verre.
func _plaque(cover: Texture2D, kind: String) -> Node3D:
	var g := Node3D.new()
	var W := .44
	var H := .56
	var gold := kind == "or"
	var frame := Mk.mat(Mk.c(0x0b0908), .3, 0.0, {"clearcoat": .8})
	Mk.mi(Mk.rounded_box(Vector3(W, H, .035), .006, frame, 2), null, Vector3(0, 0, .0175), g)
	for sx in [-1, 1]:
		Mk.mi(Mk.box(Vector3(.02, H, .02)), frame, Vector3(sx * (W / 2 - .01), 0, .045), g)
	for sy in [-1, 1]:
		Mk.mi(Mk.box(Vector3(W, .02, .02)), frame, Vector3(0, sy * (H / 2 - .01), .045), g)
	Mk.mi(Mk.quad(W - .05, H - .05), Mk.mat(Mk.c(0x14100e), 1.0, 0.0, {"normal": Mk.noise_tex(2.0, 128, 1), "normal_scale": .5}), Vector3(0, 0, .036), g)
	# disque : sillons gravés (anneaux) + étiquette centrale
	if not _tex.has("grooves"):
		_tex["grooves"] = Tex.canvas(512, 512, func(ci, w, h):
			var c := Vector2(w / 2.0, h / 2.0)
			ci.draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0))
			ci.draw_circle(c, w * .5, Color(1, 1, 1))
			for k in 60:
				var r: float = w * (.17 + k * .0055)
				ci.draw_arc(c, r, 0, TAU, 128, Color(.55, .55, .55, .35 if k % 3 else .6), 1.2)
			ci.draw_arc(c, w * .5 - 2, 0, TAU, 128, Color(.7, .7, .7), 3.0)
			ci.draw_circle(c, w * .16, Color(.85, .85, .85))
			ci.draw_circle(c, w * .012, Color(.1, .1, .1)), true)
	var metal := Mk.mat(Mk.c(0xe8c060) if gold else Mk.c(0xe8eaec), .25, .75, {"map": _tex["grooves"], "emission": Mk.c(0x4a3a18) if gold else Mk.c(0x3a3a3c), "energy": .6})
	metal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	var disc := Mk.mi(Mk.quad(.27, .27), metal, Vector3(-.02, .07, .038), g)
	disc.name = "Record"
	# pochette en réduction qui chevauche le disque
	Mk.mi(Mk.box(Vector3(.14, .14 * float(cover.get_height()) / cover.get_width(), .004)), Mk.mat(Color.WHITE, .5, 0.0, {"map": cover}), Vector3(.12, -.04, .041), g)
	# plaque gravée
	var key := "plate" + kind
	if not _tex.has(key):
		_tex[key] = Tex.canvas(512, 128, func(ci, w, h):
			ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xc8a050) if gold else Mk.c(0xc8c8c8))
			Tex.brushed(ci, w, h, 5, .08)
			ci.draw_rect(Rect2(6, 6, w - 12, h - 12), Color(.1, .08, .05, .7), false, 2.0)
			Tex.silk(ci, "GOLD RECORD" if gold else "PLATINUM RECORD", w / 2.0, h * .45, 34, Color(.12, .09, .05), "center", 800)
			Tex.silk(ci, "presented to REEL'S TOOLS · recorded in this studio", w / 2.0, h * .78, 17, Color(.12, .09, .05, .85), "center", 600))
	Mk.mi(Mk.rounded_box(Vector3(.3, .075, .004), .002, Mk.mat(Color.WHITE, .3, 1.0, {"map": _tex[key]}), 1), null, Vector3(0, -.205, .039), g)
	Mk.mi(Mk.quad(W - .03, H - .03), Mk.mat(Color.WHITE, .03, 0.0, {"alpha": .08, "clearcoat": 1.0}), Vector3(0, 0, .05), g)
	_picture_light(g, W, H)
	return g


## Applique de tableau en laiton au-dessus d'un cadre (repère du cadre, face +Z).
func _picture_light(g: Node3D, w: float, h: float) -> void:
	var brass := Mk.mat(Mk.c(0xb8913e), .3, 1.0)
	Mk.mi(Mk.rounded_box(Vector3(.05, .03, .02), .005, brass, 2), null, Vector3(0, h / 2 + .05, .01), g)
	Mk.mi(Mk.tube([Vector3(0, h / 2 + .05, .02), Vector3(0, h / 2 + .09, .07), Vector3(0, h / 2 + .08, .13)], .005, 12, 6), brass, Vector3.ZERO, g)
	var bar := Mk.mi(Mk.cyl(.018, .018, w * .6, 20), brass, Vector3(0, h / 2 + .07, .14), g)
	bar.rotation.z = PI / 2
	var slot := Mk.mi(Mk.box(Vector3(w * .55, .004, .012)), Mk.glow(Mk.c(0xffd8a0), 3.0), Vector3(0, h / 2 + .052, .14), g)
	slot.name = "PictureLamp"
	var sp := SpotLight3D.new()
	sp.light_color = Mk.c(0xffd2a0)
	sp.light_energy = .9
	sp.spot_range = h + .4
	sp.spot_angle = 40.0
	sp.spot_angle_attenuation = 1.5
	sp.position = Vector3(0, h / 2 + .05, .14)
	sp.basis = Basis.looking_at(Vector3(0, -1, -.28), Vector3.BACK)
	g.add_child(sp)



# ---------------------------------------------------------------- détails des machines
## Vis de fixation (tête bombée cruciforme) aux points donnés, dans le repère de `parent`, tête
## tournée vers `normal` (+Z ou +Y local).
func _screws(parent: Node3D, pts: Array, up := false, r := .0032) -> void:
	for p in pts:
		var sc := Mk.screw_head(r)
		if not up:
			sc.rotation.x = PI / 2
		sc.rotation.y = randf() * TAU
		sc.position = p
		parent.add_child(sc)


## Grille d'aération (fentes) posée à plat (+Y) : plaque métal sombre percée.
func _vent_plate(parent: Node3D, at: Vector3, w: float, d: float) -> void:
	if not _tex.has("slots"):
		_tex["slots"] = Tex.canvas(512, 256, func(ci, ww, hh):
			ci.draw_rect(Rect2(0, 0, ww, hh), Mk.c(0x2a2a2a))
			Tex.brushed(ci, ww, hh, 31, .05)
			var x := 24.0
			while x < ww - 24:
				ci.draw_rect(Rect2(x, 30, 9, hh - 60), Color(0, 0, 0, .95))
				ci.draw_rect(Rect2(x + 9, 30, 1.5, hh - 60), Color(1, 1, 1, .12))
				x += 22)
	var q := Mk.mi(Mk.rounded_box(Vector3(w, .002, d), .001, Mk.mat(Color.WHITE, .5, .6, {"map": _tex["slots"]}), 1), null, at, parent)
	q.name = "Vent"
	var hw := w / 2 - .008
	var hd := d / 2 - .008
	_screws(parent, [at + Vector3(-hw, .0015, -hd), at + Vector3(hw, .0015, -hd), at + Vector3(-hw, .0015, hd), at + Vector3(hw, .0015, hd)], true, .0025)


## Plaque gravée en alu (nom + numéro de série) posée sur une face (+Z local de `parent`).
func _badge(parent: Node3D, at: Vector3, txt: String, sub: String, w := .07) -> void:
	var key := "badge:" + txt
	if not _tex.has(key):
		_tex[key] = Tex.canvas(512, 128, func(ci, ww, hh):
			ci.draw_rect(Rect2(0, 0, ww, hh), Mk.c(0xb8b4ac))
			Tex.brushed(ci, ww, hh, txt.hash(), .1)
			ci.draw_rect(Rect2(4, 4, ww - 8, hh - 8), Color(.1, .1, .1, .7), false, 2.0)
			Tex.silk(ci, txt, ww / 2.0, hh * .5, 44, Color(.08, .08, .08), "center", 800)
			Tex.silk(ci, sub, ww / 2.0, hh * .82, 20, Color(.08, .08, .08, .8), "center", 600))
	var b := Mk.mi(Mk.rounded_box(Vector3(w, w / 4, .0015), .001, Mk.mat(Color.WHITE, .3, .9, {"map": _tex[key]}), 1), null, at, parent)
	b.name = "Badge"
	_screws(parent, [at + Vector3(-w / 2 + .004, 0, .0012), at + Vector3(w / 2 - .004, 0, .0012)], false, .0016)


func _machine_details() -> void:
	seed(7)
	# Accordeur : vis de façade, grille d'aération sur le dessus, plaque de série
	var t := s.tuner
	var tw := Tuner7080.W / 2 - .012
	var th := Tuner7080.H / 2 - .012
	_screws(t.face, [Vector3(-tw, -th, .002), Vector3(tw, -th, .002), Vector3(-tw, th, .002), Vector3(tw, th, .002)])
	_vent_plate(t, Vector3(0, Tuner7080.H + .001, -Tuner7080.DEPTH / 2), Tuner7080.W - .06, Tuner7080.DEPTH - .05)
	# Analyse : vis aux coins de la platine, plaque de série
	var a := s.analyzer
	var ax := Analyzer7080.W / 2 - .012
	_screws(a, [Vector3(-ax, .0905, -Analyzer7080.D / 2 + .012), Vector3(ax, .0905, -Analyzer7080.D / 2 + .012), Vector3(-ax, .0905, -Analyzer7080.D / 2 + .218), Vector3(ax, .0905, -Analyzer7080.D / 2 + .218)], true)
	# Tempo : vis aux coins du panneau incliné
	var dk := s.tempo.deck
	var dx := Tempo7080.W / 2 - .01
	var dz := s.tempo.plen / 2 - .01
	_screws(dk, [Vector3(-dx, .0025, -dz), Vector3(dx, .0025, -dz), Vector3(-dx, .0025, dz), Vector3(dx, .0025, dz), Vector3(-dx, .0025, 0), Vector3(dx, .0025, 0)], true, .0026)
	# Fréquences : vis du capot, grille d'aération à l'arrière du dessus
	var f := s.freq
	var fx := Freq7080.L / 2 - .015
	var fz := Freq7080.D / 2 - .012
	_screws(f, [Vector3(-fx, Freq7080.H + .0008, -fz), Vector3(fx, Freq7080.H + .0008, -fz), Vector3(-fx, Freq7080.H + .0008, fz - .2), Vector3(fx, Freq7080.H + .0008, fz - .2)], true, .0028)
	# Export : vis de fixation du cadre au mur + plaque gravée
	var e := s.export
	var ex := Export7080.BW / 2 + .008
	var ey := Export7080.BH / 2 + .008
	_screws(e, [Vector3(-ex, -ey, .026), Vector3(ex, -ey, .026), Vector3(-ex, ey, .026), Vector3(ex, ey, .026)], false, .0035)
	_badge(e, Vector3(Export7080.BW / 2 - .06, -Export7080.BH / 2 - .012, .026), "SESSION BOARD", "STUDIO A", .09)
	# Fax : grille de haut-parleur sur le capot + vis du bandeau
	var fa := s.fax
	_vent_plate(fa, Vector3(.13, Fax7080.BASE_H + .0505, -Fax7080.D / 2 + .075), .14, .07)
	_screws(fa, [Vector3(-Fax7080.W / 2 + .015, .028, Fax7080.D / 2 + .004), Vector3(Fax7080.W / 2 - .015, .028, Fax7080.D / 2 + .004)], false, .0025)

