class_name Deco7080
extends Node3D
## Déco de la régie 70/80, « session en cours » : enceintes (grandes suspendues + petites sur le bureau),
## fauteuil cuir capitonné, lampes, téléphone à cadran, tasses, cendrier, bandes, casque, disques, plante…
## Le centre du bureau devant la vitre reste libre pour les futures machines.

const TOP := 0.818  # dessus du bureau

var _leather_brown: StandardMaterial3D
var _walnut: StandardMaterial3D
var _black: StandardMaterial3D
var _chrome: StandardMaterial3D
var _brass: StandardMaterial3D


func _init() -> void:
	name = "Deco7080"
	_leather_brown = Mk.mat(Mk.c(0x6e3a1e), .45, 0.0, {"clearcoat": .4, "clearcoat_rough": .35})
	_walnut = Mk.mat(Mk.c(0x6a4028), .55, 0.0, {"map": Mk.walnut_tex(), "clearcoat": .3})
	_black = Mk.mat(Mk.c(0x121212), .45, .1)
	_chrome = Mk.chrome_mat()
	_brass = Mk.mat(Mk.c(0xc89a48), .3, 1.0)
	_big_speakers()
	_nearfields()
	_chair()
	_architect_lamp()
	_floor_lamp()
	_desk_objects()
	_floor_objects()
	_plant()
	_wall_frames()


func _put(n: Node3D, pos: Vector3, rot_y := 0.0, parent: Node3D = null) -> Node3D:
	n.position = pos
	n.rotation.y = rot_y
	(parent if parent else self).add_child(n)
	return n


# ---------------------------------------------------------------- enceintes
func _grille_tex(drivers: Array) -> Texture2D:
	return Tex.canvas(256, 384, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x6a5e52))
		for d in drivers:
			for k in 6:
				ci.draw_circle(Vector2(d[0] * w, d[1] * h), d[2] * w * (1.0 - k * .04), Mk.c(0x4a4038).lerp(Mk.c(0x2a2420), k / 6.0))
		var r := Tex.rng(4)
		for i in 4000:
			ci.draw_rect(Rect2(r.randf() * w, r.randf() * h, 1, 1), Color(1, 1, 1, .05) if r.randf() > .5 else Color(0, 0, 0, .1))
		ci.draw_rect(Rect2(w * .38, h * .9, w * .24, h * .035), Mk.c(0xc8a050)))


## Grandes enceintes de monitoring suspendues de chaque côté de la vitre, inclinées vers l'écoute.
func _big_speakers() -> void:
	var grille := Mk.mat(Color.WHITE, .95, 0.0, {"map": _grille_tex([[.5, .64, .38], [.5, .22, .16]])})
	for s in [[.27, PI - .3], [2.74, PI + .3]]:
		var root := Node3D.new()
		root.position = Vector3(s[0], 1.56, -.22)
		root.basis = Basis(Vector3.UP, s[1]) * Basis(Vector3.RIGHT, .22)
		add_child(root)
		Mk.mi(Mk.rounded_box(Vector3(.42, .6, .32), .01, _walnut, 3), null, Vector3(0, 0, -.16), root)
		Mk.mi(Mk.quad(.36, .54), grille, Vector3(0, 0, .002), root)
		Mk.mi(Mk.rounded_box(Vector3(.42, .6, .015), .006, _walnut, 2), null, Vector3(0, 0, -.006), root)
		# patte de fixation au plafond
		var rod := Mk.mi(Mk.cyl(.012, .012, .5, 8), _black, Vector3(s[0], 1.85, -.2), self)
		rod.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Petites enceintes de proximité posées sur le bureau, noires à membrane blanche.
func _nearfields() -> void:
	var listener := Vector3(1.6, 1.15, -1.7)
	var cone := Mk.mat(Mk.c(0xe8e4da), .7)
	for x in [.85, 2.3]:
		var root := Node3D.new()
		var pos := Vector3(x, TOP, -.28)
		var to := listener - pos
		root.position = pos
		root.rotation.y = atan2(to.x, to.z)
		add_child(root)
		Mk.mi(Mk.rounded_box(Vector3(.2, .33, .2), .006, Mk.mat(Mk.c(0x141414), .4, 0.0, {"clearcoat": .3}), 3), null, Vector3(0, .165, 0), root)
		var w := Mk.mi(Mk.lathe([[0, -.012], [.025, -.01], [.07, .0], [.074, .003], [.074, .005], [0, .005]], 40), cone, Vector3(0, .1, .1), root)
		w.rotation.x = PI / 2
		var surround := Mk.mi(Mk.torus_ring(.075, .004), _black, Vector3(0, .1, .103), root)
		surround.rotation.x = PI / 2
		var tw := Mk.mi(Mk.sphere(.014, 16, 8, true), Mk.mat(Mk.c(0x2a2a2a), .3, .2), Vector3(0, .25, .1), root)
		tw.rotation.x = PI / 2
		tw.scale = Vector3(1, .6, 1)
		# câble qui descend derrière le bureau
		var back := pos + root.basis * Vector3(0, .05, -.1)
		Mk.mi(Mk.tube([back, back + Vector3(0, -.02, .08), Vector3(back.x, TOP + .005, -.02), Vector3(back.x + .05, .4, -.04)], .004, 24, 6), _black, Vector3.ZERO, self)


# ---------------------------------------------------------------- fauteuil
## Fauteuil de bureau en cuir brun capitonné, reculé et tourné (session en cours).
func _chair() -> void:
	var c := Node3D.new()
	c.name = "Chair"
	_put(c, Vector3(1.0, 0, -1.6), 2.75)
	var btn := Mk.mat(Mk.c(0x4a2412), .5)
	for i in 5:
		var a := i * TAU / 5
		var leg := Mk.mi(Mk.rounded_box(Vector3(.05, .04, .32), .012, _chrome, 2), null, Vector3(sin(a) * .15, .07, cos(a) * .15), c)
		leg.rotation.y = a
		Mk.mi(Mk.sphere(.026, 12, 6), _black, Vector3(sin(a) * .3, .026, cos(a) * .3), c)
	Mk.mi(Mk.cyl(.03, .03, .32, 16), _chrome, Vector3(0, .24, 0), c)
	Mk.mi(Mk.cyl(.05, .06, .06, 16), _black, Vector3(0, .38, 0), c)
	# assise
	Mk.mi(Mk.rounded_box(Vector3(.56, .13, .52), .055, _leather_brown, 4), null, Vector3(0, .47, .02), c)
	for ix in [-1, 0, 1]:
		for iz in [-1, 0, 1]:
			Mk.mi(Mk.sphere(.008, 8, 4), btn, Vector3(ix * .15, .535, .02 + iz * .14), c)
	# dossier
	var back := Node3D.new()
	back.position = Vector3(0, .82, -.25)
	back.rotation.x = -.14
	c.add_child(back)
	Mk.mi(Mk.rounded_box(Vector3(.54, .66, .13), .06, _leather_brown, 4), null, Vector3.ZERO, back)
	for ix in [-1, 0, 1]:
		for iy in [-1, 0, 1]:
			Mk.mi(Mk.sphere(.009, 8, 4), btn, Vector3(ix * .15, iy * .18, .065), back)
	Mk.mi(Mk.rounded_box(Vector3(.12, .5, .04), .01, _chrome, 2), null, Vector3(0, -.3, -.08), back)
	# accoudoirs
	for sx in [-1, 1]:
		Mk.mi(Mk.rounded_box(Vector3(.07, .05, .36), .02, _leather_brown, 3), null, Vector3(sx * .31, .66, .02), c)
		Mk.mi(Mk.rounded_box(Vector3(.03, .16, .04), .01, _chrome, 2), null, Vector3(sx * .31, .57, -.04), c)


# ---------------------------------------------------------------- lampes
## Lampe d'architecte posée sur le retour, tête au-dessus du bureau.
func _architect_lamp() -> void:
	var g := Node3D.new()
	g.name = "ArchitectLamp"
	_put(g, Vector3(.22, TOP, -.75), -2.2)
	Mk.mi(Mk.cyl(.07, .08, .025, 32), _black, Vector3(0, .012, 0), g)
	var a1 := Mk.mi(Mk.cyl(.007, .007, .5, 10), _chrome, Vector3(0, .26, 0), g)
	a1.rotation.x = .12
	var a2 := Mk.mi(Mk.cyl(.007, .007, .36, 10), _chrome, Vector3(0, .5, .16), g)
	a2.rotation.x = 1.25
	var shade := Mk.mi(Mk.cyl(0.0, .07, .12, 32, false), Mk.mat(Mk.c(0x1a3020), .35, .2, {"cull_off": true}), Vector3(0, .48, .34), g)
	shade.rotation.x = -.5
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Mk.mi(Mk.sphere(.022, 16, 8), Mk.glow(Mk.c(0xffc27a), 3.0), Vector3(0, .45, .35), g)
	var sp := SpotLight3D.new()
	sp.light_color = Mk.c(0xffc890)
	sp.light_energy = 1.6
	sp.spot_range = 1.6
	sp.spot_angle = 45.0
	sp.shadow_enabled = true
	sp.position = Vector3(0, .44, .36)
	sp.basis = Basis.looking_at(Vector3(0, -1, .35), Vector3.FORWARD)
	g.add_child(sp)


## Lampadaire à abat-jour en tissu dans le coin, contre le mur en liège.
func _floor_lamp() -> void:
	var g := Node3D.new()
	g.name = "FloorLamp"
	_put(g, Vector3(.3, 0, -2.75))
	Mk.mi(Mk.cyl(.15, .16, .03, 32), _brass, Vector3(0, .015, 0), g)
	Mk.mi(Mk.cyl(.012, .012, 1.4, 10), _brass, Vector3(0, .72, 0), g)
	var shade := Mk.mi(Mk.cyl(.16, .23, .3, 40, false), Mk.mat(Mk.c(0xe8d2a8), .9, 0.0, {"emission": Mk.c(0xffb060), "energy": 1.8, "cull_off": true}), Vector3(0, 1.48, 0), g)
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l := OmniLight3D.new()
	l.light_color = Mk.c(0xffb870)
	l.light_energy = 1.4
	l.omni_range = 2.6
	l.shadow_enabled = true
	l.position = Vector3(0, 1.42, 0)
	g.add_child(l)


# ---------------------------------------------------------------- objets sur le bureau
func _desk_objects() -> void:
	_phone(Vector3(.27, TOP, -1.5), .5)
	_mug(Vector3(2.47, TOP, -.86), .8)
	_mug(Vector3(.36, TOP, -1.18), 2.4)
	_ashtray(Vector3(2.15, TOP, -.8))
	_notepad(Vector3(1.85, TOP, -.8), .25)
	_headphones(Vector3(1.22, TOP, -.78), -.4)
	_tape_stack(Vector3(.24, TOP, -.25), 3)
	_tape_stack(Vector3(2.55, TOP, -.35), 2)
	# feuilles de session éparpillées
	var paper := Mk.mat(Mk.c(0xe8e2d0), .9)
	for p in [[1.55, -.72, .1], [1.62, -.68, -.15], [.3, -.95, .4]]:
		var q := Mk.mi(Mk.plane(.21, .29), paper, Vector3(p[0], TOP + .002, p[1]), self)
		q.rotation.y = p[2]


func _phone(at: Vector3, rot: float) -> void:
	var g := Node3D.new()
	_put(g, at, rot)
	var body := Mk.mat(Mk.c(0x0e0e0e), .3, 0.0, {"clearcoat": .8})
	Mk.mi(Mk.rounded_box(Vector3(.2, .08, .22), .03, body, 4), null, Vector3(0, .04, 0), g)
	var dial := Mk.mi(Mk.disc(.055, 32), Mk.mat(Mk.c(0xd8d2c4), .5), Vector3(0, .081, .04), g)
	dial.rotation.x = -.35
	for i in 10:
		var a := -2.4 + i * .52
		Mk.mi(Mk.cyl(.007, .007, .004, 10), body, Vector3(cos(a) * .04, .083, .04 + sin(a) * .036), g)
	var hs := Node3D.new()
	hs.position = Vector3(0, .1, -.03)
	hs.rotation.y = PI / 2
	g.add_child(hs)
	var bar := Mk.mi(Mk.cyl(.016, .016, .2, 16), body, Vector3.ZERO, hs)
	bar.rotation.z = PI / 2
	for sx in [-1, 1]:
		var ear := Mk.mi(Mk.sphere(.03, 16, 8), body, Vector3(sx * .1, -.01, 0), hs)
		ear.scale = Vector3(1, .8, 1.1)
	Mk.mi(Mk.tube([Vector3(-.1, .03, .1), Vector3(-.16, .01, .2), Vector3(-.1, .005, .3), Vector3(-.2, .005, .35)], .004, 24, 6), body, Vector3.ZERO, g)


func _mug(at: Vector3, rot: float) -> void:
	var g := Node3D.new()
	_put(g, at, rot)
	var m := Mk.mat(Mk.c(0xe6dccb), .3, 0.0, {"clearcoat": .7})
	Mk.mi(Mk.lathe([[0, 0], [.038, 0], [.04, .004], [.042, .095], [.039, .095], [.036, .008], [0, .008]], 40), m, Vector3.ZERO, g)
	Mk.mi(Mk.disc(.037, 32), Mk.mat(Mk.c(0x1a0d05), .1, 0.0, {"clearcoat": 1.0}), Vector3(0, .07, 0), g)
	var h := Mk.mi(Mk.torus_arc(.025, .006, PI, 12, 6), m, Vector3(.042, .05, 0), g)
	h.rotation.z = -PI / 2


func _ashtray(at: Vector3) -> void:
	var g := Node3D.new()
	_put(g, at, .3)
	Mk.mi(Mk.lathe([[0, 0], [.06, 0], [.065, .03], [.055, .03], [.045, .01], [0, .01]], 40), Mk.mat(Mk.c(0x8a4a10), .05, 0.0, {"alpha": .75, "clearcoat": 1.0}), Vector3.ZERO, g)
	var cig := Mk.mi(Mk.cyl(.004, .004, .07, 8), Mk.mat(Mk.c(0xeeeae0), .8), Vector3(.03, .028, 0), g)
	cig.rotation.z = PI / 2 + .25
	Mk.mi(Mk.sphere(.0042, 8, 4), Mk.glow(Mk.c(0xff5010), 3.0), Vector3(.066, .037, 0), g)
	for i in 3:
		var b := Mk.mi(Mk.cyl(.004, .004, .02, 6), Mk.mat(Mk.c(0xd8b070), .8), Vector3(-.02 + i * .012, .014, .015 * i - .01), g)
		b.rotation = Vector3(PI / 2, i * .8, 0)


func _notepad(at: Vector3, rot: float) -> void:
	var g := Node3D.new()
	_put(g, at, rot)
	var lines := Tex.canvas(256, 360, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xf2e48a))
		for y in range(40, 360, 14):
			ci.draw_line(Vector2(0, y), Vector2(w, y), Color(.3, .45, .7, .5), 1.0)
		ci.draw_line(Vector2(36, 0), Vector2(36, h), Color(.8, .2, .2, .6), 1.0)
		var r := Tex.rng(9)
		for row in 9:
			var x := 44.0
			var y := 52.0 + row * 28.0
			while x < w - 30 and r.randf() > .08:
				var wl := 10.0 + r.randf() * 30.0
				ci.draw_line(Vector2(x, y), Vector2(x + wl, y - 2 + r.randf() * 4), Color(.1, .1, .25, .8), 1.6, true)
				x += wl + 8)
	var edge := Mk.mat(Mk.c(0xe8e0c0), .9)
	Mk.mi(Mk.rounded_box(Vector3(.21, .012, .3), .002, [edge, edge, Mk.mat(Color.WHITE, .9, 0.0, {"map": lines}), edge, edge, edge], 1), null, Vector3(0, .006, 0), g)
	var pen := Mk.mi(Mk.cyl(.004, .004, .14, 12), Mk.mat(Mk.c(0x1a2a6a), .3, 0.0, {"clearcoat": 1.0}), Vector3(.13, .016, .02), g)
	pen.basis = Mk.euler_xyz(0, .3, PI / 2)


func _headphones(at: Vector3, rot: float) -> void:
	var g := Node3D.new()
	_put(g, at, rot)
	var band := Mk.mi(Mk.torus_arc(.09, .008, PI, 20, 8), _black, Vector3(0, .02, 0), g)
	band.rotation.x = -PI / 2
	for sx in [-1, 1]:
		var cup := Mk.mi(Mk.cyl(.045, .05, .035, 24), _black, Vector3(sx * .09, .03, 0), g)
		cup.rotation.z = PI / 2 + sx * .3
		var pad := Mk.mi(Mk.torus_ring(.035, .012), Mk.mat(Mk.c(0x2a1a12), .8), Vector3(sx * .07, .03, 0), g)
		pad.rotation.z = PI / 2
	Mk.mi(Mk.tube([Vector3(-.09, .02, .02), Vector3(-.12, .005, .15), Vector3(.05, .005, .25), Vector3(.2, .005, .2), Vector3(.3, .005, .3)], .003, 32, 6), _black, Vector3.ZERO, g)


var _tape_mat: StandardMaterial3D


func _tape_stack(at: Vector3, n: int) -> void:
	if _tape_mat == null:
		var t := Tex.canvas(256, 256, func(ci, w, h):
			ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xe0d8c4))
			ci.draw_rect(Rect2(0, 0, w, 40), Mk.c(0xb3241a))
			Tex.silk(ci, "MASTER", 128, 20, 26, Mk.c(0xf2ece0), "center")
			var r := Tex.rng(5)
			for row in 6:
				var y := 70.0 + row * 28
				ci.draw_line(Vector2(20, y), Vector2(40 + r.randf() * 180, y + r.randf() * 3), Color(.1, .1, .2, .8), 2.0, true)
			Tex.grime(ci, w, h, 6, 2))
		_tape_mat = Mk.mat(Color.WHITE, .7, 0.0, {"map": t})
	var side := Mk.mat(Mk.c(0xd8d0bc), .8)
	for i in n:
		var b := Mk.mi(Mk.rounded_box(Vector3(.19, .024, .19), .002, [side, side, _tape_mat, side, side, side], 1), null, at + Vector3(0, .012 + i * .025, 0), self)
		b.rotation.y = i * .23 - .2


# ---------------------------------------------------------------- objets au sol
func _floor_objects() -> void:
	# câble XLR enroulé
	for i in 4:
		var r := Mk.mi(Mk.torus_ring(.17 + i * .006, .005), _black, Vector3(2.35 + i * .01, .006 + i * .004, -1.25 + i * .008), self)
		r.rotation = Vector3(0.04 * i, 0, .03)
	# caisse de disques
	var crate := Node3D.new()
	_put(crate, Vector3(2.88, 0, -1.25), .1)
	var wood := Mk.mat(Mk.c(0x8a6038), .7)
	Mk.mi(Mk.box(Vector3(.34, .02, .34)), wood, Vector3(0, .01, 0), crate)
	for sx in [-1, 1]:
		Mk.mi(Mk.box(Vector3(.02, .3, .34)), wood, Vector3(sx * .16, .15, 0), crate)
	Mk.mi(Mk.box(Vector3(.34, .3, .02)), wood, Vector3(0, .15, -.16), crate)
	var cols := [0x2a4a7a, 0xd8a030, 0x1a1a1a, 0xb3241a, 0xe8e0d0, 0x3a6a3a, 0x8a3a6a]
	for i in cols.size():
		var sl := Mk.mi(Mk.box(Vector3(.31, .31, .004)), Mk.mat(Mk.c(cols[i]), .7), Vector3(0, .17, -.13 + i * .035), crate)
		sl.rotation.x = -.25
	# bandes posées par terre contre le meuble
	_tape_stack(Vector3(2.85, 0, -.75), 3)


func _plant() -> void:
	var g := Node3D.new()
	g.name = "Plant"
	_put(g, Vector3(2.86, 0, -.15))
	Mk.mi(Mk.lathe([[0, 0], [.12, 0], [.16, .3], [.17, .3], [.17, .32], [0, .32]], 32), Mk.mat(Mk.c(0xa8522a), .8), Vector3.ZERO, g)
	Mk.mi(Mk.disc(.16, 24), Mk.mat(Mk.c(0x2a1a10), 1.0), Vector3(0, .3, 0), g)
	var leaf := Mk.mat(Mk.c(0x2e4a1e), .5, 0.0, {"clearcoat": .4, "cull_off": true})
	var stem := Mk.mat(Mk.c(0x3a3a1a), .7)
	var r := Tex.rng(21)
	for i in 22:
		var a := r.randf() * TAU
		var hgt := .5 + r.randf() * .55
		var lean := .1 + r.randf() * .2
		var tip := Vector3(cos(a) * lean, .3 + hgt, sin(a) * lean)
		Mk.mi(Mk.tube([Vector3(0, .3, 0), Vector3(cos(a) * lean * .3, .3 + hgt * .5, sin(a) * lean * .3), tip], .005, 12, 5), stem, Vector3.ZERO, g)
		var l := Mk.mi(Mk.sphere(.14, 14, 7), leaf, tip + Vector3(cos(a) * .08, .02, sin(a) * .08), g)
		l.scale = Vector3(.55, .05, 1.0)
		l.rotation = Vector3(-.3 + r.randf() * .6, -a + PI / 2, r.randf() * .4)


# ---------------------------------------------------------------- cadres sur le mur en liège
func _wall_frames() -> void:
	var items := [[-2.35, 1.48, Mk.c(0xd4a838)], [-3.2, 1.42, Mk.c(0xc8c8cc)]]
	for it in items:
		var g := Node3D.new()
		g.position = Vector3(.03, it[1], it[0])
		g.rotation.y = PI / 2
		add_child(g)
		Mk.mi(Mk.rounded_box(Vector3(.4, .5, .03), .004, Mk.mat(Mk.c(0x0b0908), .35, 0.0, {"clearcoat": .6})), null, Vector3.ZERO, g)
		Mk.mi(Mk.quad(.36, .46), Mk.mat(Mk.c(0x1a1512), .9), Vector3(0, 0, .0155), g)
		var disc := Mk.mi(Mk.cyl(.13, .13, .003, 64), Mk.mat(it[2], .2, 1.0), Vector3(0, .04, .018), g)
		disc.rotation.x = PI / 2
		var lab := Mk.mi(Mk.cyl(.045, .045, .0034, 32), Mk.mat(Mk.c(0xb3241a), .6), Vector3(0, .04, .0182), g)
		lab.rotation.x = PI / 2
		Mk.mi(Mk.quad(.16, .04), Mk.mat(Mk.c(0xc9b27a), .35, .9), Vector3(0, -.17, .017), g)
		Mk.mi(Mk.quad(.36, .46), Mk.mat(Color.WHITE, .03, 0.0, {"alpha": .1, "clearcoat": 1.0}), Vector3(0, 0, .03), g)
