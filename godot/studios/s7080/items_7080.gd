class_name Items7080
## Objets de la régie 70s modélisés en détail (repère local : façade vers +Z, posé sur y = 0) :
## porte capitonnée cuir, voyant ON AIR, frigo vitré à bières, enceintes de proximité façon NS-10,
## stores vénitiens, caisson d'enceinte encastrée (soffit).

static var _m := {}


static func _mat(key: String, make: Callable) -> Material:
	if not _m.has(key):
		_m[key] = make.call()
	return _m[key]


static func _rot(n: Node3D, axis: String, v: float) -> Node3D:
	n.rotation[axis] = v
	return n


static func brass() -> Material:
	return _mat("brass", func(): return Mk.mat(Mk.c(0xb8913e), .3, 1.0, {"normal": Mk.scratch_normal(), "normal_scale": .15}))


static func chrome() -> Material:
	return _mat("chrome", func(): return Mk.chrome_mat())


static func black_metal() -> Material:
	return _mat("blackm", func(): return Mk.mat(Mk.c(0x141414), .45, .6, {"normal": Mk.scratch_normal(), "normal_scale": .12}))


static func walnut() -> Material:
	return _mat("walnut", func(): return Mk.pbr("dark_wood", .7, {"tint": Mk.c(0xc89878), "rough": .8, "clearcoat": .4, "clearcoat_rough": .35}))


# ---------------------------------------------------------------- porte capitonnée
## Porte de studio capitonnée en cuir brun-rouge, boutons en losanges, double rangée de clous dorés,
## hublot rond, béquille laiton, plaque de propreté, paumelles, ferme-porte, chambranle noyer.
## Repère : la porte est dans le plan z = 0, face côté pièce vers +Z ; bas à y = 0, centrée en x.
static func door(W := .92, H := 2.08) -> Node3D:
	var g := Node3D.new()
	g.name = "StudioDoor"
	var wal := walnut()
	var cuir := Mk.pbr("leather_brown", .35, {"tint": Mk.c(0x9a4a3a), "clearcoat": .3, "clearcoat_rough": .5, "normal_scale": 1.2})
	var t := .07
	# chambranle (moulure en deux pas)
	for sx in [-1, 1]:
		Mk.mi(Mk.rounded_box(Vector3(t, H + t, .05), .008, wal, 2), null, Vector3(sx * (W / 2 + t / 2), (H + t) / 2, .025), g)
		Mk.mi(Mk.rounded_box(Vector3(.02, H + t - .02, .065), .004, wal, 2), null, Vector3(sx * (W / 2 + t - .01), (H + t) / 2, .032), g)
	Mk.mi(Mk.rounded_box(Vector3(W + 2 * t + .04, t + .02, .06), .008, wal, 2), null, Vector3(0, H + t / 2 + .01, .03), g)
	Mk.mi(Mk.rounded_box(Vector3(W + 2 * t + .08, .025, .075), .006, wal, 2), null, Vector3(0, H + t + .03, .035), g)
	# ébrasement sombre et seuil
	Mk.mi(Mk.box(Vector3(W, .02, .12)), brass(), Vector3(0, .01, .02), g)
	# vantail : âme + capitonnage bombé
	var leaf := Node3D.new()
	leaf.position = Vector3(0, 0, -.01)
	g.add_child(leaf)
	Mk.mi(Mk.box(Vector3(W - .01, H - .02, .045)), Mk.mat(Mk.c(0x1a0e0a), .7), Vector3(0, H / 2, 0), leaf)
	var pad := Mk.mi(Mk.rounded_box(Vector3(W - .06, H - .1, .05), .022, cuir, 4), null, Vector3(0, H / 2 + .015, .03), leaf)
	pad.name = "LeatherPad"
	# boutons de capitonnage en losanges (MultiMesh)
	var pts := []
	var px := .15
	var py := .17
	var yy := .2
	var row := 0
	while yy < H - .15:
		var off := px / 2 if row % 2 == 1 else 0.0
		var xx := -W / 2 + .1 + off
		while xx < W / 2 - .08:
			# on évite le hublot
			if Vector2(xx, yy - 1.55).length() > .19:
				pts.append(Vector3(xx, yy, .056))
			xx += px
		yy += py / 2
		row += 1
	var bm := MultiMesh.new()
	bm.transform_format = MultiMesh.TRANSFORM_3D
	bm.mesh = Mk.sphere(.011, 12, 6, true)
	bm.instance_count = pts.size()
	for i in pts.size():
		bm.set_instance_transform(i, Transform3D(Basis(Vector3.RIGHT, PI / 2).scaled(Vector3(1, .5, 1)), pts[i]))
	var bmi := MultiMeshInstance3D.new()
	bmi.multimesh = bm
	bmi.material_override = Mk.pbr("leather_brown", .2, {"tint": Mk.c(0x7a3a2e), "clearcoat": .4})
	leaf.add_child(bmi)
	# plis entre les boutons : petites rainures en diagonale
	var crease := Mk.mat(Mk.c(0x2a100c), .8)
	var cm := MultiMesh.new()
	cm.transform_format = MultiMesh.TRANSFORM_3D
	cm.mesh = Mk.box(Vector3(.004, .11, .004))
	var cr := []
	for p in pts:
		for a in [.72, -.72]:
			var q: Vector3 = p + Vector3(sign(a) * px * .25, py * .25, -.004)
			if absf(q.x) < W / 2 - .06 and q.y < H - .12:
				cr.append(Transform3D(Basis(Vector3.BACK, a), q))
	cm.instance_count = cr.size()
	for i in cr.size():
		cm.set_instance_transform(i, cr[i])
	var cmi := MultiMeshInstance3D.new()
	cmi.multimesh = cm
	cmi.material_override = crease
	leaf.add_child(cmi)
	# double rangée de clous dorés tout autour
	var nails := []
	for inset in [.035, .06]:
		var w2: float = W / 2 - inset
		var y0: float = .06 + inset
		var y1: float = H - .03 - inset
		var step := .032
		var x := -w2
		while x <= w2:
			nails.append(Vector3(x, y0, .057))
			nails.append(Vector3(x, y1, .057))
			x += step
		var y := y0 + step
		while y < y1:
			nails.append(Vector3(-w2, y, .057))
			nails.append(Vector3(w2, y, .057))
			y += step
	# clous autour du hublot
	for k in 32:
		var a := k * TAU / 32
		nails.append(Vector3(cos(a) * .17, 1.55 + sin(a) * .17, .057))
	var nm := MultiMesh.new()
	nm.transform_format = MultiMesh.TRANSFORM_3D
	nm.mesh = Mk.sphere(.0065, 10, 5, true)
	nm.instance_count = nails.size()
	for i in nails.size():
		nm.set_instance_transform(i, Transform3D(Basis(Vector3.RIGHT, PI / 2).scaled(Vector3(1, .6, 1)), nails[i]))
	var nmi := MultiMeshInstance3D.new()
	nmi.multimesh = nm
	nmi.material_override = brass()
	leaf.add_child(nmi)
	# hublot : bague chromée épaisse + vitre (on devine un couloir sombre)
	var ring := Mk.mi(Mk.torus_ring(.135, .018), chrome(), Vector3(0, 1.55, .06), leaf)
	ring.rotation.x = PI / 2
	var hole := Mk.mi(Mk.cyl(.12, .12, .08, 40, false), Mk.mat(Mk.c(0x0a0a0a), .6, 0.0, {"cull_off": true}), Vector3(0, 1.55, .02), leaf)
	hole.rotation.x = PI / 2
	var corridor := Mk.mi(Mk.disc(.12, 40), Mk.mat(Mk.c(0x1c140c), .9, 0.0, {"emission": Mk.c(0x3a2814), "energy": .4}), Vector3(0, 1.55, -.015), leaf)
	corridor.rotation.x = PI / 2
	var glass := Mk.mi(Mk.disc(.122, 40), Mk.mat(Mk.c(0x101010), .03, 0.0, {"alpha": .12, "clearcoat": 1.0}), Vector3(0, 1.55, .055), leaf)
	glass.rotation.x = PI / 2
	for k in 8:
		var a := k * TAU / 8 + .2
		var sc := Mk.screw_head(.004)
		sc.rotation.x = PI / 2
		sc.position = Vector3(cos(a) * .135, 1.55 + sin(a) * .135, .077)
		leaf.add_child(sc)
	# béquille + rosace + serrure
	var hx := W / 2 - .09
	var rose := Mk.mi(Mk.rounded_box(Vector3(.05, .22, .01), .008, brass(), 2), null, Vector3(hx, 1.02, .062), leaf)
	rose.name = "HandlePlate"
	var lever := Mk.mi(Mk.rounded_box(Vector3(.14, .022, .022), .01, brass(), 3), null, Vector3(hx - .06, 1.06, .09), leaf)
	lever.rotation.z = -.05
	_rot(Mk.mi(Mk.cyl(.012, .012, .03, 16), brass(), Vector3(hx, 1.06, .075), leaf), "x", PI / 2)
	var key_hole := Mk.mi(Mk.box(Vector3(.006, .018, .002)), Mk.mat(Mk.c(0x050403), 1.0), Vector3(hx, .97, .068), leaf)
	key_hole.name = "KeyHole"
	# plaque de propreté en laiton en bas, usée
	Mk.mi(Mk.rounded_box(Vector3(W - .08, .22, .004), .002, Mk.mat(Mk.c(0xa8823c), .45, 1.0, {"normal": Mk.scratch_normal(), "normal_scale": .5}), 1), null, Vector3(0, .15, .062), leaf)
	# paumelles + ferme-porte en haut
	for hy in [.25, 1.05, 1.85]:
		Mk.mi(Mk.cyl(.009, .009, .11, 12), brass(), Vector3(-W / 2 + .005, hy, .03), g)
	var closer := Mk.mi(Mk.rounded_box(Vector3(.28, .06, .05), .01, black_metal(), 2), null, Vector3(-W / 2 + .22, H - .06, .07), g)
	closer.name = "DoorCloser"
	var arm1 := Mk.mi(Mk.box(Vector3(.2, .012, .02)), black_metal(), Vector3(-W / 2 + .3, H + .03, .1), g)
	arm1.rotation.y = .35
	return g


# ---------------------------------------------------------------- voyant ON AIR
## Boîtier lumineux rouge « ON AIR » en métal noir, plexi dépoli. Renvoie [nœud, matériau du plexi].
static func on_air() -> Array:
	var g := Node3D.new()
	g.name = "OnAir"
	Mk.mi(Mk.rounded_box(Vector3(.42, .14, .09), .012, black_metal(), 2), null, Vector3(0, 0, .045), g)
	var tex := Tex.canvas(512, 160, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1))
		Tex.silk(ci, "ON  AIR", w / 2.0, h * .74, 96, Color(.08, .0, .0), "center", 800), false)
	var m := Mk.mat(Mk.c(0x3a0606), .3, 0.0, {"emission": Mk.c(0xff2414), "energy": .08, "emission_tex": tex, "clearcoat": .8})
	m.albedo_texture = tex
	Mk.mi(Mk.quad(.37, .1), m, Vector3(0, 0, .0915), g)
	Mk.mi(Mk.rounded_box(Vector3(.38, .11, .004), .003, chrome(), 1), null, Vector3(0, 0, .089), g)
	for sx in [-1, 1]:
		var sc := Mk.screw_head(.0035)
		sc.rotation.x = PI / 2
		sc.position = Vector3(sx * .195, 0, .092)
		g.add_child(sc)
	# câble qui remonte au plafond
	Mk.mi(Mk.tube([Vector3(.15, .07, .02), Vector3(.17, .2, .015), Vector3(.18, .6, .01)], .004, 12, 6), black_metal(), Vector3.ZERO, g)
	return [g, m]


# ---------------------------------------------------------------- frigo vitré à bières
## Petit frigo vitré de bar : caisse laquée crème, porte vitrée à cadre alu, joint, poignée chrome,
## clayettes en fil, bouteilles brunes / vertes / canettes, éclairage intérieur, fronton lumineux.
static func beer_fridge() -> Node3D:
	var g := Node3D.new()
	g.name = "BeerFridge"
	var W := .56
	var H := .9
	var D := .55
	var body := Mk.mat(Mk.c(0xd8c8a8), .35, .1, {"clearcoat": .6, "normal": Mk.scratch_normal(), "normal_scale": .2})
	var dark := Mk.mat(Mk.c(0x101010), .7)
	# pieds + socle grille de ventilation
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			Mk.mi(Mk.cyl(.015, .018, .04, 12), black_metal(), Vector3(sx * (W / 2 - .04), .02, sz * (D / 2 - .05)), g)
	var vent := Tex.canvas(256, 64, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x1a1a1a))
		for k in 18:
			ci.draw_rect(Rect2(10 + k * 13.5, 12, 7, h - 24), Color(0, 0, 0)))
	Mk.mi(Mk.rounded_box(Vector3(W, .08, D), .006, [body, body, body, body, Mk.mat(Color.WHITE, .6, .4, {"map": vent}), body], 1), null, Vector3(0, .08, 0), g)
	# caisse (parois, dessus, fond) — intérieur blanc
	var inner := Mk.mat(Mk.c(0xe8ecee), .5)
	var t := .035
	for sx in [-1, 1]:
		Mk.mi(Mk.rounded_box(Vector3(t, H - .12, D), .008, body, 2), null, Vector3(sx * (W / 2 - t / 2), .12 + (H - .12) / 2, 0), g)
	Mk.mi(Mk.rounded_box(Vector3(W, t + .1, D), .01, body, 2), null, Vector3(0, H - .05 + .05, 0), g)
	Mk.mi(Mk.box(Vector3(W - 2 * t, H - .17, .01)), inner, Vector3(0, .12 + (H - .17) / 2, -D / 2 + .02), g)
	Mk.mi(Mk.box(Vector3(W - 2 * t, .01, D - .04)), inner, Vector3(0, .125, 0), g)
	for sx in [-1, 1]:
		Mk.mi(Mk.box(Vector3(.005, H - .17, D - .05)), inner, Vector3(sx * (W / 2 - t - .003), .12 + (H - .17) / 2, 0), g)
	# fronton lumineux
	var sign_tex := Tex.canvas(512, 96, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xb02018))
		ci.draw_rect(Rect2(6, 6, w - 12, h - 12), Mk.c(0xe8d8b0), false, 4.0)
		Tex.silk(ci, "BIÈRE  FRAÎCHE", w / 2.0, h * .7, 50, Mk.c(0xf4ead0), "center", 800))
	Mk.mi(Mk.quad(W - .06, .075), Mk.mat(Color.WHITE, .4, 0.0, {"map": sign_tex, "emission": Color.WHITE, "energy": .6, "emission_tex": sign_tex}), Vector3(0, H + .0, D / 2 + .001), g)
	# clayettes en fil + bouteilles
	var wire := Mk.mat(Mk.c(0xc8c8c4), .35, .9)
	var shelf_y := [.14, .38, .6]
	for sy in shelf_y:
		for k in 9:
			_rot(Mk.mi(Mk.cyl(.003, .003, D - .08, 6), wire, Vector3(-W / 2 + t + .03 + k * (W - 2 * t - .06) / 8, sy, 0), g), "x", PI / 2)
		_rot(Mk.mi(Mk.cyl(.003, .003, W - 2 * t - .02, 6), wire, Vector3(0, sy, D / 2 - .05), g), "z", PI / 2)
	var brown := Mk.mat(Mk.c(0x3a1a06), .08, 0.0, {"alpha": .9, "clearcoat": 1.0})
	var green := Mk.mat(Mk.c(0x0c3a12), .08, 0.0, {"alpha": .9, "clearcoat": 1.0})
	var cap := Mk.mat(Mk.c(0xc8a040), .3, 1.0)
	var label := Mk.mat(Mk.c(0xe8dcc0), .6)
	var red_label := Mk.mat(Mk.c(0xb82a1a), .6)
	var bottle := Mk.lathe([[0, 0], [.03, 0], [.031, .005], [.031, .13], [.028, .155], [.013, .19], [.012, .225], [.013, .23], [0, .23]], 24)
	var can := Mk.lathe([[0, 0], [.028, 0], [.033, .01], [.033, .108], [.028, .118], [0, .118]], 24)
	var r := Tex.rng(55)
	for si in 2:
		var y0: float = shelf_y[si] + .004
		for k in 6:
			var x := -W / 2 + t + .05 + k * .078
			for zz in [.12, .04]:
				var p := Vector3(x + r.randf_range(-.005, .005), y0, zz)
				var is_green := r.randf() < .35
				Mk.mi(bottle, green if is_green else brown, p, g)
				Mk.mi(Mk.cyl(.0315, .0315, .055, 24, false), red_label if is_green else label, p + Vector3(0, .07, 0), g)
				Mk.mi(Mk.cyl(.014, .014, .01, 12), cap, p + Vector3(0, .232, 0), g)
	var can_m := Mk.mat(Mk.c(0xc8c8cc), .25, 1.0)
	var can_paint := Mk.mat(Mk.c(0x1a3a8a), .4, .5)
	for k in 6:
		var p := Vector3(-W / 2 + t + .05 + k * .078, shelf_y[2] + .004, .1)
		Mk.mi(can, can_m, p, g)
		Mk.mi(Mk.cyl(.0333, .0333, .06, 24, false), can_paint, p + Vector3(0, .03, 0), g)
	# porte vitrée : cadre alu, joint noir, vitre, poignée verticale
	var alu := Mk.mat(Mk.c(0xb8b6b0), .3, 1.0, {"normal": Mk.scratch_normal(), "normal_scale": .2})
	var dz := D / 2 + .012
	var fw := .035
	var dh := H - .17
	var cy := .12 + dh / 2
	for sx in [-1, 1]:
		Mk.mi(Mk.rounded_box(Vector3(fw, dh, .025), .004, alu, 2), null, Vector3(sx * (W / 2 - fw / 2), cy, dz), g)
	for sy in [-1, 1]:
		Mk.mi(Mk.rounded_box(Vector3(W, fw, .025), .004, alu, 2), null, Vector3(0, cy + sy * (dh / 2 - fw / 2), dz), g)
	Mk.mi(Mk.quad(W - 2 * fw, dh - 2 * fw), Mk.mat(Mk.c(0x8a9aa0), .03, 0.0, {"alpha": .14, "clearcoat": 1.0, "cull_off": true}), Vector3(0, cy, dz + .002), g)
	Mk.mi(Mk.box(Vector3(W - .01, .006, .006)), dark, Vector3(0, .12 + .003, dz - .014), g)
	var hd := Mk.mi(Mk.cyl(.009, .009, .34, 16), chrome(), Vector3(W / 2 - .06, cy + .05, dz + .04), g)
	for hy in [-.15, .15]:
		Mk.mi(Mk.box(Vector3(.012, .012, .03)), chrome(), Vector3(W / 2 - .06, cy + .05 + hy, dz + .022), g)
	hd.name = "Handle"
	# éclairage intérieur froid
	Mk.mi(Mk.box(Vector3(W - .1, .012, .02)), Mk.glow(Mk.c(0xeaf4ff), 3.0), Vector3(0, H - .13, D / 2 - .06), g)
	var l := OmniLight3D.new()
	l.light_color = Mk.c(0xd8ecff)
	l.light_energy = .5
	l.omni_range = .9
	l.position = Vector3(0, H - .2, .05)
	g.add_child(l)
	return g


# ---------------------------------------------------------------- NS-10
## Enceinte de proximité façon NS-10 : caisson en frêne noir, cône de grave blanc à nervures
## concentriques, suspension, cache-noyau, tweeter dôme dans sa cuvette, vis, plaquette, bornier.
static func ns10() -> Node3D:
	var g := Node3D.new()
	g.name = "NS10"
	var W := .215
	var H := .38
	var D := .2
	var ash := Mk.pbr("dark_wood", .4, {"tint": Mk.c(0x2a2624), "rough": .7, "clearcoat": .15})
	var baffle := Mk.mat(Mk.c(0x111111), .6)
	Mk.mi(Mk.rounded_box(Vector3(W, H, D), .004, [ash, ash, ash, ash, baffle, ash], 2), null, Vector3(0, H / 2, 0), g)
	# cône : profil de révolution (suspension en bourrelet, cône, cache)
	var cone_tex := Tex.canvas(256, 256, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xf2eee4))
		for k in 22:
			var y: float = k * h / 22.0
			ci.draw_rect(Rect2(0, y, w, 2), Color(.55, .52, .46, .45))
		Tex.grime(ci, w, h, 77, 1.5))
	var cone := Mk.mat(Color.WHITE, .85, 0.0, {"map": cone_tex, "cull_off": true})
	var woofer := Node3D.new()
	woofer.position = Vector3(0, .14, D / 2 + .001)
	woofer.rotation.x = PI / 2
	g.add_child(woofer)
	Mk.mi(Mk.lathe([[.088, 0], [.083, -.004], [.078, 0], [.07, -.004], [.03, -.03], [.022, -.032], [0, -.032]], 48), cone, Vector3.ZERO, woofer)
	Mk.mi(Mk.torus_ring(.084, .005), Mk.mat(Mk.c(0xd8d4ca), .7), Vector3(0, -.001, 0), woofer)
	Mk.mi(Mk.sphere(.022, 24, 10, true), Mk.mat(Mk.c(0xece8de), .8), Vector3(0, -.03, 0), woofer)
	Mk.mi(Mk.torus_ring(.094, .006), Mk.mat(Mk.c(0x0a0a0a), .5), Vector3(0, .002, 0), woofer)
	for k in 4:
		var a := k * TAU / 4 + PI / 4
		var sc := Mk.screw_head(.0035)
		sc.position = Vector3(cos(a) * .098, .004, sin(a) * .098)
		woofer.add_child(sc)
	# tweeter
	var tw := Node3D.new()
	tw.position = Vector3(0, .31, D / 2 + .001)
	tw.rotation.x = PI / 2
	g.add_child(tw)
	Mk.mi(Mk.lathe([[.032, 0], [.03, -.006], [.02, -.01], [0, -.01]], 32), Mk.mat(Mk.c(0x161616), .4), Vector3.ZERO, tw)
	Mk.mi(Mk.sphere(.012, 20, 10, true), Mk.mat(Mk.c(0xf0ece4), .6), Vector3(0, -.01, 0), tw)
	Mk.mi(Mk.torus_ring(.033, .003), Mk.mat(Mk.c(0x2a2a2a), .4, .5), Vector3(0, .001, 0), tw)
	# plaquette alu en bas
	var badge := Tex.canvas(256, 48, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xb8b6b0))
		Tex.silk(ci, "REEL'S  NS-10", w / 2.0, h * .72, 26, Mk.c(0x111111), "center", 800))
	Mk.mi(Mk.quad(.07, .013), Mk.mat(Color.WHITE, .3, .8, {"map": badge}), Vector3(0, .028, D / 2 + .002), g)
	# bornier + câble à l'arrière
	Mk.mi(Mk.rounded_box(Vector3(.05, .04, .01), .003, Mk.mat(Mk.c(0x1a1a1a), .5)), null, Vector3(0, .07, -D / 2 - .005), g)
	for sx in [-1, 1]:
		_rot(Mk.mi(Mk.cyl(.006, .006, .015, 12), Mk.mat(Mk.c(0xb82a1a) if sx > 0 else Mk.c(0x111111), .4), Vector3(sx * .013, .07, -D / 2 - .012), g), "x", PI / 2)
	return g


## Petit pied incliné en bois sombre (sous une NS-10), haut. 15 cm.
static func wedge_stand(w: float, d: float, h: float) -> Node3D:
	var g := Node3D.new()
	var wal := walnut()
	for sx in [-1, 1]:
		Mk.mi(Mk.rounded_box(Vector3(.03, h, d), .005, wal, 2), null, Vector3(sx * (w / 2 - .015), h / 2, 0), g)
	Mk.mi(Mk.rounded_box(Vector3(w, .02, d), .004, wal, 2), null, Vector3(0, h - .01, 0), g)
	Mk.mi(Mk.box(Vector3(w - .06, .012, d - .02)), Mk.mat(Mk.c(0x0e0e0e), .9), Vector3(0, h + .006, 0), g)
	return g


# ---------------------------------------------------------------- stores vénitiens
## Store vénitien alu (lames de 25 mm) devant une baie de largeur w et hauteur h. down = fraction
## descendue (depuis le haut), tilt = inclinaison des lames. Repère : plan du store z = 0, centré.
static func blinds(w: float, h: float, down := .55, tilt := .9) -> Node3D:
	var g := Node3D.new()
	g.name = "Blinds"
	var slat := Mk.mat(Mk.c(0xd8d0bc), .45, .4, {"cull_off": true})
	var head := Mk.mat(Mk.c(0xc8c0ac), .4, .5)
	Mk.mi(Mk.rounded_box(Vector3(w + .04, .045, .05), .006, head, 2), null, Vector3(0, h / 2 + .02, 0), g)
	var n := int(h * down / .022)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Mk.box(Vector3(w, .0015, .025))
	mm.instance_count = n
	for i in n:
		var y := h / 2 - .02 - i * .022
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.RIGHT, tilt), Vector3(0, y, 0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = slat
	g.add_child(mmi)
	var bottom_y := h / 2 - .02 - n * .022
	Mk.mi(Mk.rounded_box(Vector3(w, .012, .03), .004, head, 1), null, Vector3(0, bottom_y, 0), g)
	# échelles de ficelle + cordons
	var cord := Mk.mat(Mk.c(0xe8e0d0), .9)
	for x in [-w * .35, 0.0, w * .35]:
		Mk.mi(Mk.box(Vector3(.002, h / 2 - bottom_y, .002)), cord, Vector3(x, (h / 2 + bottom_y) / 2, .013), g)
		Mk.mi(Mk.box(Vector3(.002, h / 2 - bottom_y, .002)), cord, Vector3(x, (h / 2 + bottom_y) / 2, -.013), g)
	Mk.mi(Mk.box(Vector3(.003, h * .7, .003)), cord, Vector3(w / 2 - .03, h / 2 - h * .35, .03), g)
	Mk.mi(Mk.cyl(.006, .004, .03, 10), head, Vector3(w / 2 - .03, h / 2 - h * .7, .03), g)
	Mk.mi(Mk.cyl(.003, .003, h * .55, 8), Mk.mat(Mk.c(0xe8e4dc), .3, 0.0, {"alpha": .6}), Vector3(w / 2 - .06, h / 2 - h * .275, .03), g)
	return g


# ---------------------------------------------------------------- canapé Chesterfield
## Chesterfield 3 places en cuir cognac patiné (façade vers +Z) : dossier et accoudoirs roulés à la
## même hauteur, capitonnage en losanges (boutons + plis), accoudoirs enroulés avec volute, trois
## coussins d'assise bombés, ceinture avec rangée de clous laiton, pieds boules en noyer.
static func chesterfield(W := 2.15, D := .92, H := .84) -> Node3D:
	var g := Node3D.new()
	g.name = "Chesterfield"
	var cuir := Mk.pbr("leather_brown", .14, {"tint": Mk.c(0xf0a868), "rough": .85, "clearcoat": .18, "clearcoat_rough": .5, "normal_scale": 2.2})
	var cuir_dark := Mk.pbr("leather_brown", .12, {"tint": Mk.c(0xb87048), "rough": .85, "clearcoat": .15, "normal_scale": 2.0})
	var crease := Mk.mat(Mk.c(0x2a140a), .85)
	var arm_w := .24
	var seat_h := .44
	var back_d := .22
	var feet_h := .09
	# pieds boules + plinthe
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			Mk.mi(Mk.lathe([[0, 0], [.03, 0], [.045, .025], [.045, .05], [.03, .075], [.035, .09], [0, .09]], 20), walnut(), Vector3(sx * (W / 2 - .08), 0, sz * (D / 2 - .08)), g)
	# caisse basse (ceinture)
	Mk.mi(Mk.rounded_box(Vector3(W, seat_h - .14 - feet_h, D), .03, cuir_dark, 3), null, Vector3(0, feet_h + (seat_h - .14 - feet_h) / 2, 0), g)
	# dossier capitonné
	var bz := -D / 2 + back_d / 2
	var by0 := seat_h - .14
	var back := Mk.mi(Mk.rounded_box(Vector3(W - .02, H - by0, back_d), .07, cuir, 5), null, Vector3(0, by0 + (H - by0) / 2, bz), g)
	back.name = "Back"
	var inner_w0 := W - 2 * arm_w
	var qh := H - .12 - (seat_h + .02)
	var quilt := Mk.mi(quilt_mesh(inner_w0 + .02, qh, .15, .11, .028), cuir, Vector3(0, seat_h + .02 + qh / 2, bz + back_d / 2 + .004), g)
	quilt.name = "Tufting"
	# rouleau du dossier
	var roll := Mk.mi(Mk.cyl(.085, .085, W - .02, 32), cuir, Vector3(0, H - .055, bz + .01), g)
	roll.rotation.z = PI / 2
	# accoudoirs roulés
	for sx in [-1, 1]:
		var ax: float = sx * (W / 2 - arm_w / 2)
		Mk.mi(Mk.rounded_box(Vector3(arm_w, H - by0 - .06, D - .02), .06, cuir, 5), null, Vector3(ax, by0 + (H - by0 - .06) / 2, .01), g)
		var ar := Mk.mi(Mk.cyl(.11, .11, D - .02, 32), cuir, Vector3(ax + sx * .035, H - .07, .01), g)
		ar.rotation.x = PI / 2
		# volute en façade
		var vol := Mk.mi(Mk.cyl(.115, .115, .025, 32), cuir_dark, Vector3(ax + sx * .035, H - .07, D / 2 + .002), g)
		vol.rotation.x = PI / 2
		Mk.mi(Mk.rounded_box(Vector3(arm_w - .02, H - by0 - .15, .03), .01, cuir_dark, 2), null, Vector3(ax, by0 + (H - by0 - .15) / 2, D / 2), g)
		# plis rayonnants de la volute
		for k in 10:
			var a := k * TAU / 10
			var pl := Mk.mi(Mk.box(Vector3(.004, .08, .004)), crease, Vector3(ax + sx * .035 + cos(a) * .06, H - .07 + sin(a) * .06, D / 2 + .016), g)
			pl.rotation.z = a + PI / 2
	# coussins d'assise
	var inner_w := W - 2 * arm_w
	for i in 3:
		var cw := inner_w / 3
		var cx := -inner_w / 2 + cw * (i + .5)
		var cu := Mk.mi(Mk.rounded_box(Vector3(cw - .008, .15, D - back_d - .02), .05, cuir, 5), null, Vector3(cx, seat_h - .065, bz + back_d / 2 + (D - back_d - .02) / 2), g)
		cu.name = "Cushion"
		var cd := D - back_d - .02
		var cz := bz + back_d / 2 + cd / 2
		var pip := [Vector3(cx - cw / 2 + .03, seat_h + .008, cz + cd / 2 - .002), Vector3(cx + cw / 2 - .03, seat_h + .008, cz + cd / 2 - .002)]
		Mk.mi(Mk.tube(pip, .006, 8, 6), cuir_dark, Vector3.ZERO, g)
		cu.rotation.z = (i - 1) * .004
	# capitonnage du dossier et de l'intérieur des accoudoirs : boutons + plis en losanges
	var pts := []
	var px := .15
	var py := .11
	var row := 0
	var yy := seat_h + .1
	while yy < H - .1:
		var off := px / 2 if row % 2 == 1 else 0.0
		var xx := -inner_w / 2 + .08 + off
		while xx < inner_w / 2 - .06:
			pts.append(Vector3(xx, yy, bz + back_d / 2 + .008))
			xx += px
		yy += py / 2
		row += 1
	var tufts := []
	for p in pts:
		tufts.append(Transform3D(Basis(Vector3.RIGHT, PI / 2).scaled(Vector3(1, .45, 1)), p))
	for sx in [-1, 1]:
		var ix: float = sx * (W / 2 - arm_w) + sx * -.002
		var r2 := 0
		var y2 := seat_h + .05
		while y2 < H - .14:
			var z2 := -D / 2 + back_d + .08 + (.08 if r2 % 2 else 0.0)
			while z2 < D / 2 - .08:
				tufts.append(Transform3D(Basis(Vector3.BACK, -sx * PI / 2).scaled(Vector3(1, .45, 1)), Vector3(ix, y2, z2)))
				z2 += .16
			y2 += .065
			r2 += 1
	var bm := MultiMesh.new()
	bm.transform_format = MultiMesh.TRANSFORM_3D
	bm.mesh = Mk.sphere(.016, 12, 6, true)
	bm.instance_count = tufts.size()
	for i in tufts.size():
		bm.set_instance_transform(i, tufts[i])
	var bmi := MultiMeshInstance3D.new()
	bmi.multimesh = bm
	bmi.material_override = cuir_dark
	g.add_child(bmi)
	var cr := []
	for p in pts:
		for a in [.75, -.75, PI / 2 + .75, PI / 2 - .75]:
			var dir := Vector3(cos(a), sin(a), 0)
			var q: Vector3 = p + dir * .045 + Vector3(0, 0, -.003)
			if q.y < H - .09 and q.y > seat_h and absf(q.x) < inner_w / 2 - .03:
				cr.append(Transform3D(Basis(Vector3.BACK, a), q))
	var cm := MultiMesh.new()
	cm.transform_format = MultiMesh.TRANSFORM_3D
	cm.mesh = Mk.box(Vector3(.065, .007, .01))
	cm.instance_count = cr.size()
	for i in cr.size():
		cm.set_instance_transform(i, cr[i])
	var cmi := MultiMeshInstance3D.new()
	cmi.multimesh = cm
	cmi.material_override = crease
	g.add_child(cmi)
	# rangée de clous laiton sur la ceinture et le bas des accoudoirs
	var nails := []
	var x := -W / 2 + .03
	while x < W / 2 - .03:
		nails.append(Vector3(x, feet_h + .03, D / 2 + .004))
		x += .028
	for sx in [-1, 1]:
		var z := -D / 2 + .03
		while z < D / 2 - .03:
			nails.append(Vector3(sx * (W / 2 + .004), feet_h + .03, z))
			z += .028
	var nm := MultiMesh.new()
	nm.transform_format = MultiMesh.TRANSFORM_3D
	nm.mesh = Mk.sphere(.0065, 10, 5, true)
	nm.instance_count = nails.size()
	for i in nails.size():
		var p: Vector3 = nails[i]
		var bas := Basis(Vector3.RIGHT, PI / 2) if absf(p.z) > D / 2 else Basis(Vector3.BACK, -signf(p.x) * PI / 2)
		nm.set_instance_transform(i, Transform3D(bas.scaled(Vector3(1, .6, 1)), p))
	var nmi := MultiMeshInstance3D.new()
	nmi.multimesh = nm
	nmi.material_override = brass()
	g.add_child(nmi)
	# coussin en toile
	var cush := Mk.mi(Mk.rounded_box(Vector3(.42, .38, .12), .06, Mk.pbr("hessian_230", .2, {"tint": Mk.c(0xc86a2a)}), 5), null, Vector3(-W / 2 + .45, seat_h + .19, bz + back_d / 2 + .08), g)
	cush.rotation = Vector3(-.25, .2, .12)
	return g



## Panneau capitonné en vrai relief (plan XY, face +Z, centré) : coussins en losanges entre des
## creux disposés en quinconce (pas px x py), profondeur `depth`.
static func quilt_mesh(w: float, h: float, px: float, py: float, depth: float, res := 0.012) -> ArrayMesh:
	var nx := int(w / res) + 1
	var ny := int(h / res) + 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hf := func(x: float, y: float) -> float:
		# distance « losange » au creux le plus proche (réseau en quinconce)
		var gx := (x + w / 2) / px
		var gy := (y + h / 2) / (py / 2)
		var best := 9.0
		var ry := floori(gy)
		for r in [ry - 1, ry, ry + 1, ry + 2]:
			var off: float = .5 if posmod(r, 2) == 1 else 0.0
			var cx: float = round(gx - off) + off
			for c in [cx - 1.0, cx, cx + 1.0]:
				var d: float = absf(gx - c) + absf(gy - r) * .5
				best = minf(best, d)
		var t := clampf(best / .5, 0.0, 1.0)
		var edge := minf(minf(x + w / 2, w / 2 - x), minf(y + h / 2, h / 2 - y))
		var fall := clampf(edge / .03, 0.0, 1.0)
		return depth * pow(t, .55) * fall
	for j in ny:
		for i in nx:
			var x := -w / 2 + w * i / (nx - 1)
			var y := -h / 2 + h * j / (ny - 1)
			var z: float = hf.call(x, y)
			var e := .004
			var dx: float = (hf.call(x + e, y) - hf.call(x - e, y)) / (2 * e)
			var dy: float = (hf.call(x, y + e) - hf.call(x, y - e)) / (2 * e)
			st.set_normal(Vector3(-dx, -dy, 1).normalized())
			st.set_uv(Vector2(x / .3, -y / .3))
			st.add_vertex(Vector3(x, y, z))
	for j in ny - 1:
		for i in nx - 1:
			var a := j * nx + i
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + nx)
			st.add_index(a + 1)
			st.add_index(a + nx + 1)
			st.add_index(a + nx)
	st.generate_tangents()
	return st.commit()
