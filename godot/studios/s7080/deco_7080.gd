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
	_leather_brown = Mk.pbr("leather_brown", .45, {"tint": Mk.c(0xf0dcd0), "clearcoat": .1, "clearcoat_rough": .6})
	_walnut = Mk.pbr("fine_grained_wood", .7, {"tint": Mk.c(0xd8c0a8), "rough": .8, "clearcoat": .3, "clearcoat_rough": .3})
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


## Grandes enceintes de monitoring suspendues de chaque côté de la vitre, inclinées vers l'écoute,
## façon moniteur de régie fin 70s (type JBL 4430) : caisson noyer, baffle bleu nuit, pavillon
## bi-radial à fente, boomer 38 cm au dôme alu, évents, plaque, atténuateurs, étrier au plafond.
func _big_speakers() -> void:
	var baffle := Mk.pbr("blue_metal_plate", .6, {"tint": Mk.c(0x7890b0), "rough": 1.1, "normal_scale": .6})
	var cone := Mk.mat(Mk.c(0x232120), .95, 0.0, {"normal": Mk.noise_tex(.6, 256, 3), "normal_scale": .35, "cull_off": true})
	var surround := Mk.mat(Mk.c(0x161514), .55, 0.0, {"cull_off": true})
	var basket := Mk.mat(Mk.c(0x202224), .5, .6)
	var dome := Mk.mat(Mk.c(0xd0ccc4), .28, 1.0)
	var horn := Mk.mat(Mk.c(0x232425), .45, .3, {"cull_off": true})
	var bracket := Mk.mat(Mk.c(0x1a1a1a), .4, .7)
	for s in [[.27, PI - .3], [2.74, PI + .3]]:
		var root := Node3D.new()
		root.position = Vector3(s[0], 1.54, -.22)
		root.basis = Basis(Vector3.UP, s[1]) * Basis(Vector3.RIGHT, .2)
		add_child(root)
		# caisson ouvert devant (face avant invisible) + cadre noyer + fond noir : on voit dans les trous
		Mk.mi(Mk.rounded_box(Vector3(.44, .66, .3), .006, [_walnut, _walnut, _walnut, _walnut, _invisible(), _walnut], 3), null, Vector3(0, 0, -.15), root)
		_front_frame(root, .44, .66, .014, 0.0, _walnut)
		Mk.mi(Mk.quad(.41, .63), Mk.mat(Mk.c(0x050505), 1.0), Vector3(0, 0, -.2), root)
		# baffle en deux plaques percées (boomer en bas, pavillon en haut)
		Mk.mi(Mk.plate_with_hole(.412, .401, .012, Mk.circle_pts(.158, 96)), baffle, Vector3(0, -.1155, .008), root)
		Mk.mi(Mk.plate_with_hole(.412, .231, .012, _horn_mouth(.33, .135)), baffle, Vector3(0, .2005, .008), root)
		# boomer
		var w := Node3D.new()
		w.position = Vector3(0, -.1155, .008)
		root.add_child(w)
		_driver(w, .158, .07, cone, surround, basket, dome, .052)
		for i in 8:
			var a := i * TAU / 8 + PI / 8
			var sc := Mk.screw_head(.0045)
			sc.rotation.x = PI / 2
			sc.position = Vector3(cos(a) * .1645, sin(a) * .1645, .008)
			w.add_child(sc)
		# pavillon bi-radial : flasque + évasement + fente de gorge
		var hn := Node3D.new()
		hn.position = Vector3(0, .2005, .008)
		root.add_child(hn)
		Mk.mi(Mk.rounded_box(Vector3(.36, .16, .014), .006, horn, 2), null, Vector3(0, 0, 0), hn)
		Mk.mi(_horn_flare(.33, .135, .012, .07, .13), horn, Vector3(0, 0, .0072), hn)
		Mk.mi(Mk.box(Vector3(.006, .05, .004)), Mk.mat(Mk.c(0x050505), .9), Vector3(0, 0, -.121), hn)
		for sx in [-1, 1]:
			for sy in [-1, 1]:
				var sc := Mk.screw_head(.0035)
				sc.rotation.x = PI / 2
				sc.position = Vector3(sx * .168, sy * .066, .0075)
				hn.add_child(sc)
		# évents, plaque, atténuateurs
		for x in [-.165, .165]:
			var port := Mk.mi(Mk.cyl(.022, .022, .04, 24, false), Mk.mat(Mk.c(0x050505), .8, 0.0, {"cull_off": true}), Vector3(x, -.29, -.012), root)
			port.rotation.x = PI / 2
			var hole := Mk.mi(Mk.disc(.022, 32), Mk.mat(Mk.c(0x020202), 1.0), Vector3(x, -.29, .0085), root)
			hole.rotation.x = PI / 2
			var lip := Mk.mi(Mk.torus_ring(.023, .003), Mk.mat(Mk.c(0x0c0c0c), .6), Vector3(x, -.29, .009), root)
			lip.rotation.x = PI / 2
		Mk.mi(Mk.rounded_box(Vector3(.085, .022, .004), .002, Mk.mat(Mk.c(0xb8b6b0), .3, 1.0)), null, Vector3(0, -.29, .009), root)
		Mk.mi(Mk.quad(.078, .016), _badge_mat("REEL'S  4430", Mk.c(0xc8c6c0), Mk.c(0x111111)), Vector3(0, -.29, .0112), root)
		for k in 2:
			var kn := Mk.knob(.008, .008)
			kn.rotation.x = PI / 2
			kn.position = Vector3(.12 + k * .028, .095, .008)
			root.add_child(kn)
		var tape := Mk.mi(Mk.plane(.07, .04), _badge_mat("L" if s[0] < 1.5 else "R", Mk.c(0xe8e0c8), Mk.c(0x1a1a40), "caveat"), Vector3(-.1, .331, -.08), root)
		tape.rotation.y = .05
		# étrier : platine vissée sur le dessus + tige vers le plafond
		Mk.mi(Mk.rounded_box(Vector3(.16, .008, .12), .002, bracket, 1), null, Vector3(.06, .334, -.15), root)
		var rod := Mk.mi(Mk.cyl(.012, .012, .5, 10), bracket, Vector3(s[0], 1.85, -.2), self)
		rod.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Haut-parleur réaliste (face vers +Z du parent) : membrane papier évasée, suspension en demi-rouleau,
## joint plat de fixation, cache-noyau bombé. R = rayon extérieur de la suspension, depth = profondeur du cône.
func _driver(parent: Node3D, R: float, depth: float, cone: Material, roll: Material, gasket: Material, cap_mat: Material, cap_r: float) -> void:
	var hr := R * .07           # demi-largeur du rouleau
	var rc := R - hr            # rayon du bord de la membrane
	var prof := [[0.0, -depth]]
	for i in 13:
		var t := float(i) / 12.0
		# profil légèrement courbe (cône « NAWI ») : plus creux au centre
		var r := lerpf(cap_r * .9, rc - hr, t)
		prof.append([r, -depth * (1.0 - pow(t, .8))])
	prof.append([rc - hr, 0.0])
	var c1 := Mk.mi(Mk.lathe(prof, 72), cone, Vector3.ZERO, parent)
	c1.rotation.x = PI / 2
	# suspension : demi-tore bombé vers l'avant
	var sp := []
	for i in 11:
		var a := PI * i / 10.0
		sp.append([rc - hr * cos(a), hr * .9 * sin(a)])
	sp.append([R, -.002])
	sp.append([rc - hr, -.002])
	var r1 := Mk.mi(Mk.lathe(sp, 72), roll, Vector3.ZERO, parent)
	r1.rotation.x = PI / 2
	# joint / flasque du saladier
	var r2 := Mk.mi(Mk.lathe([[R, .0], [R * 1.09, .0], [R * 1.09, R * .035], [R, R * .035]], 72), gasket, Vector3.ZERO, parent)
	r2.rotation.x = PI / 2
	# cache-noyau
	var cap := Mk.mi(Mk.sphere(cap_r, 32, 12, true), cap_mat, Vector3(0, 0, -depth * .62), parent)
	cap.rotation.x = PI / 2
	cap.scale = Vector3(1, .55, 1)


var _invis: StandardMaterial3D


## Matériau invisible (face d'une boîte qu'on veut ouverte).
func _invisible() -> StandardMaterial3D:
	if _invis == null:
		_invis = Mk.mat(Color(0, 0, 0), 1.0, 0.0, {"alpha": 0.0})
	return _invis


## Cadre (4 lattes) sur la face avant d'un caisson ouvert : largeur b, en z = zf (local), centré en y = cy.
func _front_frame(root: Node3D, w: float, h: float, b: float, zf: float, m: Material, cy := 0.0) -> void:
	for sy in [-1, 1]:
		Mk.mi(Mk.box(Vector3(w, b, .006)), m, Vector3(0, cy + sy * (h / 2 - b / 2), zf - .003), root)
	for sx in [-1, 1]:
		Mk.mi(Mk.box(Vector3(b, h - 2 * b, .006)), m, Vector3(sx * (w / 2 - b / 2), cy, zf - .003), root)


## Contour de la bouche du pavillon (même super-ellipse que _horn_flare), sens trigo.
func _horn_mouth(w1: float, h1: float, n := 96) -> PackedVector2Array:
	var out := PackedVector2Array()
	for j in n:
		var a := float(j) / n * TAU
		var ca := cos(a)
		var sa := sin(a)
		out.append(Vector2(w1 / 2 * signf(ca) * pow(absf(ca), .35), h1 / 2 * signf(sa) * pow(absf(sa), .35)))
	return out


## Évasement de pavillon : bouche (w1 × h1) en z = 0, gorge (w0 × h0) en z = -depth, profil exponentiel.
func _horn_flare(w1: float, h1: float, w0: float, h0: float, depth: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 14
	var pts := 48
	for i in rings + 1:
		var t := float(i) / rings
		var k := pow(t, 2.2)
		var ww := lerpf(w0, w1, k) / 2
		var hh := lerpf(h0, h1, pow(t, 1.3)) / 2
		var z := -depth * (1.0 - t)
		for j in pts + 1:
			var a := float(j) / pts * TAU
			var ca := cos(a)
			var sa := sin(a)
			# super-ellipse : coins arrondis
			var x := ww * signf(ca) * pow(absf(ca), .35)
			var y := hh * signf(sa) * pow(absf(sa), .35)
			st.set_uv(Vector2(float(j) / pts, t))
			st.add_vertex(Vector3(x, y, z))
	for i in rings:
		for j in pts:
			var a := i * (pts + 1) + j
			var b := a + pts + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(a + 1)
			st.add_index(a + 1)
			st.add_index(b)
			st.add_index(b + 1)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## Membrane papier : nervures concentriques (carte de normales radiale).
func _cone_ribs() -> Texture2D:
	var img := Image.create(16, 256, false, Image.FORMAT_L8)
	for y in 256:
		var v := .5 + .5 * sin(float(y) / 256.0 * TAU * 7.0)
		for x in 16:
			img.set_pixel(x, y, Color(v, v, v))
	return Tex.normal_from_bump(img, 2.5)


## Enceintes de proximité sur le bureau : caisson noir, baffle en retrait, membrane blanche,
## vis, dôme d'aigu protégé, évent, plaque, bornier et câble à l'arrière.
func _nearfields() -> void:
	var listener := Vector3(1.7, 1.15, -1.6)
	var cone := Mk.mat(Mk.c(0xe8e4da), .75, 0.0, {"normal": _cone_ribs(), "normal_scale": .35, "cull_off": true})
	var cab := Mk.mat(Mk.c(0x141414), .4, 0.0, {"clearcoat": .3})
	for x in [1.08, 2.32]:
		var root := Node3D.new()
		var pos := Vector3(x, TOP + .245, -.2)
		var to := listener - pos
		root.position = pos
		root.rotation.y = atan2(to.x, to.z)
		add_child(root)
		Mk.mi(Mk.rounded_box(Vector3(.2, .33, .2), .008, [cab, cab, cab, cab, _invisible(), cab], 3), null, Vector3(0, .165, 0), root)
		_front_frame(root, .2, .33, .01, .1, cab, .165)
		Mk.mi(Mk.quad(.18, .31), Mk.mat(Mk.c(0x050505), 1.0), Vector3(0, .165, .04), root)
		var fb := Mk.mat(Mk.c(0x0c0c0c), .6)
		Mk.mi(Mk.plate_with_hole(.18, .2, .01, Mk.circle_pts(.078, 72)), fb, Vector3(0, .11, .104), root)
		Mk.mi(Mk.rounded_box(Vector3(.18, .11, .01), .002, fb, 1), null, Vector3(0, .265, .099), root)
		var w := Node3D.new()
		w.position = Vector3(0, .11, .104)
		root.add_child(w)
		_driver(w, .078, .03, cone, Mk.mat(Mk.c(0x161616), .6, 0.0, {"cull_off": true}), Mk.mat(Mk.c(0x1a1a1a), .5, .5), Mk.mat(Mk.c(0xd8d2c6), .6), .02)
		for i in 4:
			var a := PI / 4 + i * PI / 2
			var sc := Mk.screw_head(.0035)
			sc.rotation.x = PI / 2
			sc.position = Vector3(cos(a) * .082, sin(a) * .082, .003)
			w.add_child(sc)
		var tw := Node3D.new()
		tw.position = Vector3(0, .255, .104)
		root.add_child(tw)
		var dome := Mk.mi(Mk.sphere(.013, 16, 8, true), Mk.mat(Mk.c(0x2a2a2a), .3, .2), Vector3.ZERO, tw)
		dome.rotation.x = PI / 2
		dome.scale = Vector3(1, .6, 1)
		var guard := Mk.mi(Mk.torus_ring(.022, .003), _chrome, Vector3(0, 0, .002), tw)
		guard.rotation.x = PI / 2
		var port := Mk.mi(Mk.cyl(.012, .012, .02, 16, false), Mk.mat(Mk.c(0x050505), .8, 0.0, {"cull_off": true}), Vector3(.055, .03, .1), root)
		port.rotation.x = PI / 2
		Mk.mi(Mk.quad(.05, .012), _badge_mat("REEL'S", Mk.c(0xb8b4ac), Mk.c(0x141414)), Vector3(-.05, .03, .1035), root)
		# papier mouchoir scotché devant le tweeter (astuce de studio)
		var tissue := Mk.mi(Mk.quad(.07, .06), Mk.mat(Mk.c(0xf4f2ec), .95, 0.0, {"alpha": .82, "cull_off": true}), Vector3(.004, .257, .106), root)
		tissue.rotation.z = .06
		Mk.mi(Mk.quad(.015, .03), Mk.mat(Mk.c(0xd8c890), .6, 0.0, {"alpha": .7}), Vector3(-.03, .285, .107), root)
		var tape := Mk.mi(Mk.plane(.05, .03), _badge_mat("L" if x > 1.5 else "R", Mk.c(0xe8e0c8), Mk.c(0x1a1a40), "caveat"), Vector3(0, .331, -.03), root)
		tape.rotation.y = -.08
		Mk.mi(Mk.rounded_box(Vector3(.05, .03, .006), .002, _black), null, Vector3(0, .07, -.102), root)
		var back := pos + root.basis * Vector3(0, .07, -.1)
		Mk.mi(Mk.tube([back, back + Vector3(0, -.03, .06), Vector3(back.x, TOP + .1, -.03), Vector3(back.x + .05, .4, -.04)], .004, 24, 6), _black, Vector3.ZERO, self)

var _badges := {}


## Grain du cuir (petites bosses irrégulières).
func _grain() -> Texture2D:
	var nt := NoiseTexture2D.new()
	nt.width = 512
	nt.height = 512
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = 3.0
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_CELLULAR
	fn.frequency = .09
	nt.noise = fn
	return nt


## Petite plaque ou étiquette avec du texte.
func _badge_mat(txt: String, bg: Color, ink: Color, fam := "archivo") -> StandardMaterial3D:
	var key := txt + str(bg) + fam
	if _badges.has(key):
		return _badges[key]
	var tex := Tex.canvas(256, 64, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), bg)
		Tex.silk(ci, txt, w / 2.0, h / 2.0, 40 if fam == "caveat" else 30, ink, "center", 700, fam)
		Tex.grime(ci, w, h, txt.length(), .4))
	var m := Mk.mat(Color.WHITE, .4, .6 if fam != "caveat" and bg.v > .5 else 0.0, {"map": tex})
	_badges[key] = m
	return m


## Fauteuil de direction de l'époque, type « Soft Pad » : coussins de cuir piqués en boudins
## sur montants en alu poli, accoudoirs alu + manchettes cuir, mécanisme basculant, vérin,
## piètement 5 branches en alu et roulettes doubles. Reculé et tourné (session en cours).
func _chair() -> void:
	var c := Node3D.new()
	c.name = "Chair"
	_put(c, Vector3(1.85, 0, -1.55), .45)
	var alu := Mk.mat(Mk.c(0xc8c6c2), .22, 1.0, {"normal": Mk.scratch_normal(), "normal_scale": .15})
	var plastic := Mk.mat(Mk.c(0x161514), .55, 0.0)
	var pad := _leather_brown
	var piping := Mk.pbr("leather_brown", .45, {"tint": Mk.c(0x9a8478), "clearcoat": .1, "clearcoat_rough": .6})
	# piètement : 5 branches profilées (plus épaisses au moyeu), roulettes doubles
	var leg_prof := PackedVector2Array([Vector2(.03, .065), Vector2(.335, .045), Vector2(.345, .055), Vector2(.335, .072), Vector2(.03, .118)])
	var leg_mesh := Mk.prism(leg_prof, .034)
	for i in 5:
		var a := i * TAU / 5 + .3
		var h := Node3D.new()
		h.rotation.y = a - PI / 2
		c.add_child(h)
		Mk.mi(leg_mesh, alu, Vector3(0, 0, -.017), h)
		Mk.mi(Mk.rounded_box(Vector3(.036, .03, .046), .01, plastic, 2), null, Vector3(.33, .046, 0), h)
		var stem := Mk.mi(Mk.cyl(.006, .006, .02, 8), alu, Vector3(.33, .058, 0), h)
		stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for sz in [-1, 1]:
			var wh := Mk.mi(Mk.cyl(.024, .024, .011, 20), plastic, Vector3(.315, .024, sz * .0135), h)
			wh.rotation.x = PI / 2
			var hubcap := Mk.mi(Mk.cyl(.009, .009, .012, 12), alu, Vector3(.315, .024, sz * .0135), h)
			hubcap.rotation.x = PI / 2
	Mk.mi(Mk.lathe([[0, .06], [.05, .06], [.055, .09], [.045, .125], [0, .125]], 32), alu, Vector3.ZERO, c)
	# vérin : soufflet / fourreau plastique + tige chromée
	Mk.mi(Mk.cyl(.028, .032, .2, 24), plastic, Vector3(0, .225, 0), c)
	for k in 6:
		Mk.mi(Mk.torus_ring(.031, .003), plastic, Vector3(0, .14 + k * .028, 0), c)
	Mk.mi(Mk.cyl(.019, .019, .08, 20), _chrome, Vector3(0, .36, 0), c)
	# mécanisme basculant + manette
	Mk.mi(Mk.rounded_box(Vector3(.2, .045, .24), .01, Mk.mat(Mk.c(0x1c1c1c), .45, .6), 2), null, Vector3(0, .41, .0), c)
	Mk.mi(Mk.tube([Vector3(.09, .405, .06), Vector3(.17, .4, .09), Vector3(.24, .395, .1)], .005, 12, 6), _chrome, Vector3.ZERO, c)
	Mk.mi(Mk.ellipsoid(.018, .014, .014), plastic, Vector3(.25, .395, .1), c)
	# assise : 3 boudins de cuir posés entre deux longerons alu
	var seat := Node3D.new()
	seat.position = Vector3(0, .455, .02)
	seat.rotation.x = -.06
	c.add_child(seat)
	for sx in [-1, 1]:
		Mk.mi(Mk.rounded_box(Vector3(.024, .034, .5), .01, alu, 2), null, Vector3(sx * .258, 0, 0), seat)
	Mk.mi(Mk.rounded_box(Vector3(.5, .018, .48), .008, plastic, 1), null, Vector3(0, -.01, 0), seat)
	for k in 3:
		var cz := -.165 + k * .165
		Mk.mi(Mk.rounded_box(Vector3(.49, .085 - k * .004, .168), .038, pad, 5), null, Vector3(0, .036, cz), seat)
		if k < 2:
			Mk.mi(Mk.tube([Vector3(-.235, .062, cz + .0825), Vector3(0, .066, cz + .0825), Vector3(.235, .062, cz + .0825)], .0042, 16, 6), piping, Vector3.ZERO, seat)
	# dossier haut : 5 boudins sur une courbe, montants alu qui descendent rejoindre l'assise
	var back := Node3D.new()
	back.position = Vector3(0, .5, -.24)
	back.rotation.x = -.2
	c.add_child(back)
	var rail_l := []
	var rail_r := []
	for k in 6:
		var y := .02 + k * .145
		var z := -.025 * sin(k / 5.0 * PI) - .01
		rail_l.append(Vector3(-.248, y, z - .02))
		rail_r.append(Vector3(.248, y, z - .02))
		if k < 5:
			var cy := y + .0725
			var cz2 := -.025 * sin((k + .5) / 5.0 * PI)
			var cush := Mk.mi(Mk.rounded_box(Vector3(.47, .148, .085), .038, pad, 5), null, Vector3(0, cy, cz2 + .02), back)
			cush.rotation.x = .05 * (k - 2)
			if k > 0:
				Mk.mi(Mk.tube([Vector3(-.225, y, cz2 + .056), Vector3(0, y, cz2 + .062), Vector3(.225, y, cz2 + .056)], .0042, 16, 6), piping, Vector3.ZERO, back)
	# coque arrière du dossier (cuir sur l'arrière, comme les vrais)
	Mk.mi(Mk.rounded_box(Vector3(.47, .72, .035), .015, pad, 3), null, Vector3(0, .385, -.045), back)
	rail_l.insert(0, Vector3(-.258, -.08, .08))
	rail_r.insert(0, Vector3(.258, -.08, .08))
	for rr in [rail_l, rail_r]:
		Mk.mi(Mk.tube(rr, .013, 40, 10), alu, Vector3.ZERO, back)
	# accoudoirs : arceau alu + manchette cuir
	for sx in [-1, 1]:
		var x: float = sx * .27
		Mk.mi(Mk.tube([Vector3(sx * .258, .46, .19), Vector3(x, .56, .2), Vector3(x, .645, .1), Vector3(x, .65, -.12), Vector3(sx * .255, .62, -.25)], .011, 40, 10), alu, Vector3.ZERO, c)
		Mk.mi(Mk.rounded_box(Vector3(.062, .036, .32), .016, pad, 3), null, Vector3(x, .675, -.02), c)
		for ez in [-.18, .14]:
			Mk.mi(Mk.rounded_box(Vector3(.05, .018, .02), .006, alu, 2), null, Vector3(x, .652, ez), c)


## Positions des boutons d'un capitonnage en losanges (rangées décalées).
func _diamond_points(cols: int, rows: int, dx: float, dy: float) -> Array:
	var out := []
	for j in rows:
		var n := cols if j % 2 == 0 else cols - 1
		for i in n:
			var x := (i - (n - 1) / 2.0) * dx
			out.append(Vector2(x, (j - (rows - 1) / 2.0) * dy))
	return out


## Cuir capitonné : creux en losanges (carte de normales) + plis.
func _tufted_leather() -> StandardMaterial3D:
	var img := Image.create(256, 256, false, Image.FORMAT_L8)
	var centers := [Vector2(0, 0), Vector2(256, 0), Vector2(0, 256), Vector2(256, 256), Vector2(128, 128)]
	for y in 256:
		for x in 256:
			var v := 1.0
			for cc in centers:
				var d := Vector2(x, y).distance_to(cc)
				v -= .55 * exp(-d * d / 900.0)
			# plis en diagonale entre les boutons
			var dg := minf(absf(fmod(x + y, 256.0) - 128.0), absf(fmod(x - y + 512.0, 256.0) - 128.0))
			v -= .12 * exp(-pow(128.0 - dg, 2) / 30.0)
			img.set_pixel(x, y, Color(v, v, v))
	var m := Mk.mat(Mk.c(0x6a3820), .55, 0.0, {"normal": Tex.normal_from_bump(img, 5.0), "normal_scale": 1.0, "clearcoat": .22, "clearcoat_rough": .5})
	m.roughness_texture = Mk.noise_tex(.03)
	m.uv1_scale = Vector3(2, 2, 1)
	return m

# ---------------------------------------------------------------- lampes
## Lampe d'architecte posée sur le retour, tête au-dessus du bureau.
func _architect_lamp() -> void:
	var g := Node3D.new()
	g.name = "ArchitectLamp"
	arch_lamp = g
	_put(g, Vector3(.08, TOP, -1.62), -2.0)
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
	sp.light_energy = .6
	sp.spot_range = 1.4
	sp.spot_angle = 45.0
	sp.shadow_enabled = true
	sp.position = Vector3(0, .44, .36)
	sp.basis = Basis.looking_at(Vector3(0, -1, .35), Vector3.FORWARD)
	g.add_child(sp)


var _lamp_light: OmniLight3D
var _lamp_shade: StandardMaterial3D


## Couleur du lampadaire (réglage de personnalisation).
func set_lamp_color(c: Color) -> void:
	if _lamp_light:
		_lamp_light.light_color = c
		_lamp_shade.emission = c.lerp(Color(1, .69, .38), .25)


## Lampadaire à abat-jour en tissu dans le coin, contre le mur en liège.
func _floor_lamp() -> void:
	var g := Node3D.new()
	g.name = "FloorLamp"
	_put(g, Vector3(.3, 0, -2.75))
	Mk.mi(Mk.cyl(.15, .16, .03, 32), _brass, Vector3(0, .015, 0), g)
	Mk.mi(Mk.cyl(.012, .012, 1.4, 10), _brass, Vector3(0, .72, 0), g)
	_lamp_shade = Mk.mat(Mk.c(0xe8d2a8), .9, 0.0, {"emission": Mk.c(0xffb060), "energy": 1.8, "cull_off": true})
	var shade := Mk.mi(Mk.cyl(.16, .23, .3, 40, false), _lamp_shade, Vector3(0, 1.48, 0), g)
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l := OmniLight3D.new()
	l.light_color = Mk.c(0xffb870)
	_lamp_light = l
	l.light_energy = .7
	l.omni_range = 2.6
	l.shadow_enabled = true
	l.position = Vector3(0, 1.42, 0)
	g.add_child(l)


# ---------------------------------------------------------------- objets sur le bureau
func _desk_objects() -> void:
	# grande console sur le bureau principal, face à l'ingé (avant vers -Z)
	_console(Vector3(1.7, TOP, -.57), PI, 1.6, .74, 20)
	# (le module Tempo est accolé à droite de la console : voir Tempo7080)
	# l'angle et le retour restent libres pour les modules : objets en bout de bureau et au fond du retour
	_phone(Vector3(.31, TOP, -1.68), .5)
	_notepad(Vector3(2.62, TOP, -.85), .25)
	_mug(Vector3(.42, TOP, -.3), .8)
	_ashtray(Vector3(2.6, TOP, -.45))
	_tape_stack(Vector3(2.6, TOP, -.1), 3)
	_tape_stack(Vector3(.22, TOP, -.2), 2)
	# casque posé sur l'assise du fauteuil
	_headphones(Vector3(1.85, .535, -1.52), .8)


## Console de mixage posée sur le retour, tournée vers la pièce (+X) : 10 tranches + section master,
## pupitre incliné sérigraphié, potards EQ/aux/pan, boutons mute/solo éclairés, faders, scribble,
## pont de VU + baie de patch avec cordons, câbles qui partent derrière.
func _console(at: Vector3, rot: float, L: float, D: float, n: int) -> void:
	var g := Node3D.new()
	g.name = "MixConsole"
	_put(g, at, rot)  # avant de la console = +Z local
	var body := Mk.mat(Mk.c(0x2a2622), .5, .3)
	# caisse en biseau (plus haute à l'arrière), joues en noyer
	var prof := PackedVector2Array([Vector2(-D / 2, 0), Vector2(D / 2, 0), Vector2(D / 2, .045), Vector2(-D / 2, .12)])
	var box := Mk.mi(Mk.prism(prof, L), body, Vector3(L / 2, 0, 0), g)
	box.rotation.y = -PI / 2
	for sx in [-1, 1]:
		var cheek := Mk.mi(Mk.prism(PackedVector2Array([Vector2(-D / 2 - .01, 0), Vector2(D / 2 + .01, 0), Vector2(D / 2 + .01, .06), Vector2(-D / 2 - .01, .2), Vector2(-D / 2 + .05, .2)]), .025), _walnut, Vector3(sx * (L / 2 + .0125) + .0125, 0, 0), g)
		cheek.rotation.y = -PI / 2
	# pupitre incliné
	var master_w := .2     # section master à droite
	var sw := (L - .02 - master_w) / n
	var slope := atan2(.12 - .045, D)
	var plen := sqrt(D * D + pow(.12 - .045, 2))
	var deck := Node3D.new()
	deck.position = Vector3(0, (.12 + .045) / 2 + .001, 0)
	deck.rotation.x = slope
	g.add_child(deck)
	var rows := ["GAIN", "HI", "HI-MID", "LO-MID", "LO", "AUX 1", "AUX 2", "PAN"]
	var row_v := func(k: int) -> float: return -plen / 2 + .035 + k * .034
	var tex := Tex.canvas(2048, int(2048 * plen / L), func(ci, w, h):
		var P := func(m: float) -> float: return m / L * w
		var V := func(m: float) -> float: return (m + plen / 2) / plen * h
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x3a3632))
		Tex.brushed(ci, w, h, 12, .04, 2500)
		var x_start: float = P.call(.01)
		var pw: float = P.call(sw)
		# bandes de couleur par section EQ
		ci.draw_rect(Rect2(x_start, V.call(row_v.call(1)) - 18, pw * n, V.call(row_v.call(4)) - V.call(row_v.call(1)) + 36), Color(.2, .3, .45, .25))
		ci.draw_rect(Rect2(x_start, V.call(row_v.call(5)) - 18, pw * n, V.call(row_v.call(6)) - V.call(row_v.call(5)) + 36), Color(.45, .3, .15, .25))
		for i in n:
			var x0: float = x_start + i * pw
			ci.draw_rect(Rect2(x0, 0, 2, h), Color(0, 0, 0, .6))
			Tex.silk(ci, str(i + 1), x0 + pw / 2, 18, 20, Color(.9, .88, .82, .85), "center", 700)
			for k in rows.size():
				Tex.silk(ci, rows[k], x0 + pw / 2, V.call(row_v.call(k)) + 26, 10, Color(.9, .88, .82, .55), "center", 600)
			# bande de scribble avec le nom de la piste
			var names := ["KICK", "SNARE", "HH", "TOMS", "OH L", "OH R", "BASS", "GTR 1", "GTR 2", "KEYS", "PIANO", "ORGAN", "VOX", "VOX 2", "CHOEURS", "CUIVRES", "PERC", "FX", "VERB", "DELAY"]
			ci.draw_rect(Rect2(x0 + pw * .08, h * .70, pw * .84, h * .045), Mk.c(0xe8e0c8))
			Tex.silk(ci, names[i % names.size()], x0 + pw / 2, h * .722, 18, Color(.1, .1, .3, .85), "center", 600, "caveat")
			# rainure de fader + graduations
			ci.draw_rect(Rect2(x0 + pw / 2 - 3, h * .78, 6, h * .19), Color(0, 0, 0, .85))
			for k in 9:
				ci.draw_rect(Rect2(x0 + pw / 2 + 9, h * (.785 + k * .022), 7 if k % 2 else 12, 2), Color(.9, .88, .82, .6))
		# section master
		var mx: float = x_start + pw * n
		ci.draw_rect(Rect2(mx, 0, P.call(master_w), h), Mk.c(0x2a2826))
		Tex.silk(ci, "MASTER", mx + P.call(master_w) / 2, 18, 20, Color(.95, .8, .5, .9), "center")
		for k in 2:
			ci.draw_rect(Rect2(mx + P.call(master_w) * (.3 + k * .4) - 3, h * .74, 6, h * .23), Color(0, 0, 0, .85))
		Tex.silk(ci, "L", mx + P.call(master_w) * .3, h * .72, 16, Color(.9, .88, .82, .7), "center")
		Tex.silk(ci, "R", mx + P.call(master_w) * .7, h * .72, 16, Color(.9, .88, .82, .7), "center")
		Tex.grime(ci, w, h, 13, 2))
	Mk.mi(Mk.rounded_box(Vector3(L - .02, .004, plen), .001, [body, body, Mk.mat(Color.WHITE, .5, .4, {"map": tex}), body, body, body], 1), null, Vector3.ZERO, deck)
	var knob_mesh := Mk.cyl(.0058, .0068, .011, 16)
	var skirt_mesh := Mk.cyl(.0088, .0092, .0028, 20)
	var slot_mat := Mk.mat(Mk.c(0x030303), 1.0)
	var btn_mat := Mk.mat(Mk.c(0xb8b4aa), .45)
	var fader_mesh := Mk.prism(PackedVector2Array([Vector2(-.008, 0), Vector2(.008, 0), Vector2(.008, .011), Vector2(.0062, .0128), Vector2(0, .0108), Vector2(-.0062, .0128), Vector2(-.008, .011)]), .022)
	var skirt := Mk.mat(Mk.c(0x2c2c2e), .35, .2)
	var screw_mesh := Mk.sphere(.0022, 10, 4, true)
	var screw_mat := Mk.mat(Mk.c(0x9a968f), .32, 1.0)
	var cap_mesh := Mk.cyl(.0045, .0045, .003, 14)
	var big_knob := Mk.cyl(.011, .012, .014, 20)
	var row_caps := [0xd43a26, 0x2a6ab0, 0x3a8a4a, 0x3a8a4a, 0x2a6ab0, 0xe8742a, 0xe8742a, 0xd8d2c4]
	var cap_mats := []
	for cc in row_caps:
		cap_mats.append(Mk.mat(Mk.c(cc), .4, 0.0, {"clearcoat": .5}))
	var line := Mk.mat(Mk.c(0xf2efe8), .6)
	var fader_cap := Mk.mat(Mk.c(0xd8d2c4), .4)
	var mute_on := Mk.mat(Mk.c(0x400808), .3, 0.0, {"emission": Mk.c(0xff3020), "energy": 2.0})
	var mute_off := Mk.mat(Mk.c(0x5a1a14), .4)
	var solo := Mk.mat(Mk.c(0x6a5a14), .4)
	var r := Tex.rng(31)
	for i in n:
		var x := -L / 2 + .01 + sw * (i + .5)
		for k in rows.size():
			var v: float = row_v.call(k)
			var holder := Node3D.new()
			holder.position = Vector3(x, 0, v)
			holder.rotation.y = r.randf_range(-2.4, 2.4)
			deck.add_child(holder)
			Mk.mi(skirt_mesh, skirt, Vector3(0, .0016, 0), holder)
			Mk.mi(knob_mesh, _black, Vector3(0, .0075, 0), holder)
			Mk.mi(cap_mesh, cap_mats[k], Vector3(0, .0142, 0), holder)
			Mk.mi(Mk.box(Vector3(.001, .0005, .004)), line, Vector3(0, .0158, -.002), holder)
		# vis de fixation du module (haut et bas de chaque tranche)
		for zz in [-plen / 2 + .009, plen / 2 - .007]:
			Mk.mi(screw_mesh, screw_mat, Vector3(x, .002, zz), deck)
		# mute / solo
		var mv: float = row_v.call(rows.size()) - .004
		Mk.mi(Mk.rounded_box(Vector3(.014, .006, .01), .002, mute_on if r.randf() < .25 else mute_off, 1), null, Vector3(x - .009, .004, mv), deck)
		Mk.mi(Mk.rounded_box(Vector3(.014, .006, .01), .002, solo, 1), null, Vector3(x + .009, .004, mv), deck)
		# fente de fader + capuchon concave (forme de vrai bouton de fader) + tige
		Mk.mi(Mk.box(Vector3(.0032, .0012, plen * .19)), slot_mat, Vector3(x, .0019, -plen / 2 + plen * .875), deck)
		var fv := plen / 2 - .02 - r.randf() * .085
		Mk.mi(Mk.box(Vector3(.003, .004, .003)), _black, Vector3(x, .003, fv), deck)
		Mk.mi(fader_mesh, fader_cap, Vector3(x, .0045, fv - .011), deck)
		Mk.mi(Mk.box(Vector3(.0142, .0006, .0012)), line, Vector3(x, .0045 + .0112, fv), deck)
		# boutons poussoirs (phase, filtre) sous le gain
		for bx in [-.0055, .0055]:
			Mk.mi(Mk.rounded_box(Vector3(.0068, .0045, .0068), .0012, btn_mat, 1), null, Vector3(x + bx, .0035, -plen / 2 + .053), deck)
	# master : gros potards + deux faders
	var mx0 := L / 2 - .01 - master_w
	for k in 3:
		Mk.mi(big_knob, _black, Vector3(mx0 + master_w * (.25 + k * .25), .008, -plen / 2 + .07 + k * .06), deck)
	for k in 2:
		Mk.mi(Mk.rounded_box(Vector3(.022, .016, .03), .004, Mk.mat(Mk.c(0xb3241a), .4), 2), null, Vector3(mx0 + master_w * (.3 + k * .4), .01, plen / 2 - .06), deck)
	# accoudoir rembourré sur l'avant (cuir noir, boudin) + nez en noyer
	var roll := Mk.mat(Mk.c(0x0e0c0b), .45, 0.0, {"clearcoat": .3, "clearcoat_rough": .5, "normal": _grain(), "normal_scale": .15})
	Mk.mi(Mk.rounded_box(Vector3(L + .05, .016, .06), .004, _walnut, 2), null, Vector3(0, .008, D / 2 + .028), g)
	Mk.mi(Mk.rounded_box(Vector3(L + .03, .046, .058), .021, roll, 4), null, Vector3(0, .039, D / 2 + .028), g)
	# pont de VU + baie de patch à l'arrière
	var bridge := Node3D.new()
	bridge.position = Vector3(0, .18, -D / 2 + .03)
	bridge.rotation.x = -.25
	g.add_child(bridge)
	Mk.mi(Mk.rounded_box(Vector3(L, .12, .05), .006, body, 2), null, Vector3.ZERO, bridge)
	for sx in [-1, 1]:
		Mk.mi(Mk.rounded_box(Vector3(.028, .135, .062), .008, _walnut, 2), null, Vector3(sx * (L / 2 + .014), 0, -.004), bridge)
	# visière au-dessus des VU
	Mk.mi(Mk.rounded_box(Vector3(L * .88, .006, .03), .002, body, 1), null, Vector3(-L * .036, .049, .038), bridge)
	var vu := Tex.canvas(256, 160, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xe9d9aa))
		ci.draw_arc(Vector2(128, 190), 150, -2.3, -.84, 32, Mk.c(0x1a1a1a), 2.0, true)
		ci.draw_arc(Vector2(128, 190), 154, -1.12, -.84, 16, Mk.c(0xb3241a), 4.0, true)
		for k in 11:
			var a := -2.3 + k * .146
			ci.draw_line(Vector2(128, 190) + Vector2(cos(a), sin(a)) * 150, Vector2(128, 190) + Vector2(cos(a), sin(a)) * 162, Mk.c(0xb3241a) if k > 7 else Mk.c(0x1a1a1a), 2.0, true)
		Tex.silk(ci, "VU", 128, 120, 26, Mk.c(0x1a1a1a), "center"))
	var vu_mat := Mk.mat(Color.WHITE, .8, 0.0, {"map": vu, "emission": Mk.c(0xffb060), "energy": .35, "emission_tex": vu})
	var vu_glass := Mk.mat(Color(.9, .95, 1.0), .04, 0.0, {"alpha": .1, "clearcoat": 1.0, "clearcoat_rough": .02})
	var vus := []
	for k in 6:
		vus.append(-L * .36 + k * L * .144)
	for vx in vus:
		Mk.mi(Mk.rounded_box(Vector3(.115, .075, .008), .003, _black, 1), null, Vector3(vx, .01, .024), bridge)
		Mk.mi(Mk.quad(.1, .062), vu_mat, Vector3(vx, .01, .0285), bridge)
		# vitre bombée devant le cadran + vis de pivot de l'aiguille
		Mk.mi(Mk.rounded_box(Vector3(.104, .066, .004), .0019, vu_glass, 2), null, Vector3(vx, .01, .0312), bridge)
		var piv := Mk.mi(Mk.sphere(.0035, 12, 6, true), _black, Vector3(vx - .008, -.02, .029), bridge)
		piv.rotation.x = PI / 2
		var nd := Mk.mi(Mk.box(Vector3(.001, .05, .001)), _black, Vector3(vx - .008, .0, .029), bridge)
		nd.rotation.z = r.randf_range(.1, .6)
	# échelles de LED entre les VU
	for col in 2:
		for i in 10:
			var on := i < 6 + col
			var m := Mk.glow(Mk.c(0x40ff60) if i < 7 else (Mk.c(0xffc020) if i < 9 else Mk.c(0xff3020)), 1.6 if on else .08)
			Mk.mi(Mk.box(Vector3(.008, .004, .003)), m, Vector3(L * .43 - .012 + col * .024, -.03 + i * .007, .026), bridge)
	# baie de patch sur le dessus du pont
	var patch := Node3D.new()
	patch.position = Vector3(0, .062, .0)
	patch.rotation.x = -PI / 2 + .25
	bridge.add_child(patch)
	Mk.mi(Mk.rounded_box(Vector3(L - .04, .04, .006), .002, Mk.mat(Mk.c(0x1a1a1a), .5, .5), 1), null, Vector3.ZERO, patch)
	var jack := Mk.cyl(.0032, .0032, .004, 10)
	var jm := Mk.mat(Mk.c(0x050505), .6)
	for row in 2:
		for i in int((L - .08) / .03):
			var j := Mk.mi(jack, jm, Vector3(-L / 2 + .04 + i * .03, -.009 + row * .018, .003), patch)
			j.rotation.x = PI / 2
	# cordons de patch
	var cord_cols := [0xd43a26, 0xf2c230, 0x2a6ab0, 0x1e1e1e]
	for i in cord_cols.size():
		var a := Vector3(-L / 2 + .04 + (3 + i * 5) * .03, -.009, .006)
		var b := Vector3(-L / 2 + .04 + (7 + i * 4) * .03, .009, .006)
		var mid := (a + b) / 2 + Vector3(0, -.02 - i * .006, .05 + i * .01)
		Mk.mi(Mk.tube([a, a + Vector3(0, 0, .02), mid, b + Vector3(0, 0, .02), b], .0022, 24, 6), Mk.mat(Mk.c(cord_cols[i]), .45, 0.0, {"clearcoat": .3}), Vector3.ZERO, patch)
	# multipaire gris (le « snake ») qui part derrière vers la cabine
	Mk.mi(Mk.tube([Vector3(.45, .08, -D / 2), Vector3(.5, .02, -D / 2 - .08), Vector3(.55, -.3, -D / 2 - .12), Vector3(.62, -.8, -D / 2 - .06)], .011, 24, 10), Mk.mat(Mk.c(0x4a4a4c), .55), Vector3.ZERO, g)
	# faisceau de câbles qui part derrière la console vers le sol
	for i in 5:
		var x := -.3 + i * .14
		Mk.mi(Mk.tube([Vector3(x, .1, -D / 2), Vector3(x + .02, .06, -D / 2 - .06), Vector3(x * .5, -.2, -D / 2 - .1), Vector3(x * .3, -.8, -D / 2 - .05)], .005, 20, 6), _black, Vector3.ZERO, g)


## Téléphone à cadran 70s : socle, cadran à disque perforé chromé + butée, combiné sur fourche,
## cordon spiralé jusqu'au combiné.
func _phone(at: Vector3, rot: float) -> void:
	var g := Node3D.new()
	_put(g, at, rot)
	var body := Mk.mat(Mk.c(0x0e0e0e), .3, 0.0, {"clearcoat": .8})
	var chrome := Mk.mat(Mk.c(0xd0ccc6), .15, 1.0)
	Mk.mi(Mk.rounded_box(Vector3(.2, .03, .22), .01, body, 2), null, Vector3(0, .015, 0), g)
	var shell := Mk.mi(Mk.prism(PackedVector2Array([Vector2(-.105, 0), Vector2(.105, 0), Vector2(.07, .085), Vector2(-.04, .07)]), .18), body, Vector3(-.09, .02, 0), g)
	shell.rotation.y = PI / 2
	# cadran incliné
	var dial := Node3D.new()
	dial.position = Vector3(0, .087, .045)
	dial.rotation.x = .42
	g.add_child(dial)
	var face := Mk.mi(Mk.disc(.055, 40), Mk.mat(Mk.c(0xe8e0cc), .5), Vector3(0, .001, 0), dial)
	face.name = "DialFace"
	var wheel := Mk.mi(Mk.cyl(.052, .052, .004, 40), Mk.mat(Mk.c(0xcfd4d6), .08, 0.0, {"alpha": .55, "clearcoat": 1.0}), Vector3(0, .004, 0), dial)
	wheel.name = "FingerWheel"
	for i in 10:
		var a := -2.6 + i * .5
		var h := Mk.mi(Mk.torus_ring(.0072, .0012), chrome, Vector3(cos(a) * .039, .0065, sin(a) * .039), dial)
		Mk.mi(Mk.disc(.0068, 16), Mk.mat(Mk.c(0x1a1a1a), .6), Vector3(cos(a) * .039, .0021, sin(a) * .039), dial)
		h.name = "Hole%d" % i
	Mk.mi(Mk.cyl(.016, .016, .003, 24), Mk.mat(Mk.c(0xf2ecdc), .5), Vector3(0, .0065, 0), dial)
	var stop := Mk.mi(Mk.tube([Vector3(.03, .007, .038), Vector3(.045, .008, .045), Vector3(.054, .007, .04)], .0016, 8, 6), chrome, Vector3.ZERO, dial)
	stop.name = "FingerStop"
	# fourche + combiné
	for sx in [-1, 1]:
		Mk.mi(Mk.rounded_box(Vector3(.022, .03, .028), .006, body, 2), null, Vector3(sx * .07, .095, -.035), g)
	var hs := Node3D.new()
	hs.position = Vector3(0, .118, -.035)
	g.add_child(hs)
	var bar := Mk.mi(Mk.cyl(.015, .013, .17, 16), body, Vector3.ZERO, hs)
	bar.rotation.z = PI / 2
	for sx in [-1, 1]:
		var ear := Mk.mi(Mk.cyl(.028, .024, .03, 24), body, Vector3(sx * .095, -.012, 0), hs)
		ear.rotation.z = sx * .25
	# cordon spiralé (combiné -> socle, côté gauche)
	var pts := []
	var p0 := Vector3(-.11, .1, -.035)
	var p1 := Vector3(-.11, .02, .11)
	var turns := 22
	for i in turns * 8 + 1:
		var t := float(i) / (turns * 8)
		var c0 := p0.lerp(p1, t) + Vector3(-.03 * sin(t * PI), -.05 * sin(t * PI), 0)
		var a := t * turns * TAU
		pts.append(c0 + Vector3(cos(a) * .006, sin(a) * .006, 0) + Vector3(0, 0, sin(a) * .002))
	Mk.mi(Mk.tube(pts, .0014, turns * 16, 5), body, Vector3.ZERO, g)


## Mug émaillé (liseré bleu), café, auréole sur le bureau.
func _mug(at: Vector3, rot: float) -> void:
	var g := Node3D.new()
	_put(g, at, rot)
	var m := Mk.mat(Mk.c(0xe6dccb), .25, 0.0, {"clearcoat": .7})
	Mk.mi(Mk.lathe([[0, 0], [.036, 0], [.04, .004], [.042, .095], [.039, .095], [.036, .008], [0, .008]], 48), m, Vector3.ZERO, g)
	var rim := Mk.mi(Mk.torus_ring(.0405, .0018), Mk.mat(Mk.c(0x1a2a5a), .3, 0.0, {"clearcoat": .7}), Vector3(0, .095, 0), g)
	rim.name = "Rim"
	Mk.mi(Mk.disc(.037, 32), Mk.mat(Mk.c(0x1a0d05), .08, 0.0, {"clearcoat": 1.0}), Vector3(0, .07, 0), g)
	Mk.mi(Mk.torus_ring(.0372, .0012), Mk.mat(Mk.c(0x5a3a20), .4), Vector3(0, .0715, 0), g)
	var h := Mk.mi(Mk.torus_arc(.024, .0055, PI * 1.15, 16, 8), m, Vector3(.04, .05, 0), g)
	h.rotation.z = -PI / 2 - .08
	# auréole de café sur le bois
	var ring := Mk.mi(Mk.torus_ring(.043, .0025), Mk.mat(Mk.c(0x2a1608, .55), .5, 0.0, {"alpha": .45}), Vector3(.03, .0004, .05), g)
	ring.scale = Vector3(1, .05, 1)


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


## Casque de studio fermé : arceau acier + coussin, curseurs, étriers, coques, oreillettes en
## similicuir, câble spiralé avec jack.
func _headphones(at: Vector3, rot: float) -> void:
	var g := Node3D.new()
	_put(g, at, rot)
	var shell := Mk.mat(Mk.c(0x1a1a1c), .35, .1, {"clearcoat": .3})
	var steel := Mk.mat(Mk.c(0xb0aca6), .25, 1.0)
	var vinyl := Mk.mat(Mk.c(0x161412), .55, 0.0, {"normal": _grain(), "normal_scale": .2})
	# posé à plat : arceau couché vers -Z
	var arc := Node3D.new()
	arc.rotation.x = -PI / 2 + .12
	arc.position = Vector3(0, .035, 0)
	g.add_child(arc)
	Mk.mi(Mk.torus_arc(.088, .0035, PI, 24, 6), steel, Vector3.ZERO, arc)
	var cush := Mk.mi(Mk.torus_arc(.084, .009, PI * .6, 20, 10), vinyl, Vector3.ZERO, arc)
	cush.rotation.z = PI * .2
	for sx in [-1, 1]:
		# curseur + étrier
		Mk.mi(Mk.box(Vector3(.006, .03, .006)), steel, Vector3(sx * .088, -.012, 0), arc)
		var yoke := Mk.mi(Mk.torus_arc(.04, .003, PI, 14, 6), steel, Vector3(sx * .088, -.03, 0), arc)
		yoke.rotation = Vector3(PI / 2, 0, PI)
		# coque + oreillette
		var cup := Node3D.new()
		cup.position = Vector3(sx * .086, -.068, 0)
		cup.rotation.z = PI / 2
		arc.add_child(cup)
		Mk.mi(Mk.lathe([[0, -.018 * sx], [.04, -.016 * sx], [.045, 0], [.045, .006 * sx], [0, .006 * sx]], 32), shell, Vector3.ZERO, cup)
		var pad := Mk.mi(Mk.torus_ring(.033, .011), vinyl, Vector3(0, .016 * sx, 0), cup)
		pad.scale = Vector3(1, .8, 1)
	# câble spiralé qui pend du fauteuil
	var pts := []
	var p0 := Vector3(-.09, .02, .02)
	var p1 := Vector3(.12, -.02, .22)
	for i in 161:
		var t := float(i) / 160
		var a := t * 20 * TAU
		pts.append(p0.lerp(p1, t) + Vector3(0, cos(a) * .005, sin(a) * .005))
	Mk.mi(Mk.tube(pts, .0016, 320, 5), _black, Vector3.ZERO, g)
	Mk.mi(Mk.tube([p1, p1 + Vector3(.08, -.02, .05), Vector3(.24, -.3, .2), Vector3(.28, -.52, .24)], .002, 24, 5), _black, Vector3.ZERO, g)
	var jack := Mk.mi(Mk.cyl(.005, .005, .04, 12), steel, Vector3(.28, -.53, .24), g)
	jack.name = "Jack"


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
	_nab_reel(at + Vector3(.01, .025 * n + .004, -.01), .5)


## Bobine de bande 1/4" sur flasque alu NAB (ajours) avec la galette brune.
func _nab_reel(at: Vector3, rot: float) -> void:
	var g := Node3D.new()
	_put(g, at, rot)
	var alu := Mk.mat(Mk.c(0xc4c0b8), .3, 1.0)
	for yy in [.0, .014]:
		Mk.mi(Mk.cyl(.088, .088, .0015, 48), alu, Vector3(0, yy, 0), g)
	Mk.mi(Mk.cyl(.064, .064, .0125, 48), Mk.mat(Mk.c(0x3a2414), .6), Vector3(0, .007, 0), g)
	Mk.mi(Mk.cyl(.024, .024, .016, 24), alu, Vector3(0, .007, 0), g)
	for i in 3:
		var a := i * TAU / 3
		Mk.mi(Mk.cyl(.016, .016, .0018, 16), Mk.mat(Mk.c(0x1a120c), .7), Vector3(cos(a) * .052, .0152, sin(a) * .052), g)
	var lab := Mk.mi(Mk.quad(.03, .012), _badge_mat("MIX 3", Mk.c(0xe8e0c8), Mk.c(0x1a1a40), "caveat"), Vector3(-.03, .0158, -.065), g)
	lab.rotation.x = -PI / 2


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
	_pouf()
	_toolbox()


## Pouf rond 70s capitonné en jacquard gris à motifs, à côté du fauteuil.
func _pouf() -> void:
	var g := Node3D.new()
	g.name = "Pouf"
	_put(g, Vector3(2.62, 0, -2.05), .4)
	var fab := Mk.pbr("floral_jacquard", .35, {"tint": Mk.c(0xb8b0c0)})
	var prof := [[0.0, .02]]
	for i in 13:
		var a := -PI / 2 + PI * i / 12.0
		prof.append([.2 + .05 * cos(a), .19 + .17 * sin(a)])
	prof.append([0.0, .37])
	var body := Mk.mi(Mk.lathe(prof, 48), fab, Vector3.ZERO, g)
	Mk.mi(Mk.sphere(.018, 16, 8), Mk.mat(Mk.c(0x2a2a30), .6), Vector3(0, .365, 0), g)
	Mk.mi(Mk.torus_ring(.2, .012), Mk.mat(Mk.c(0x3a3640), .7), Vector3(0, .05, 0), g)
	for i in 4:
		var a := i * TAU / 4 + PI / 4
		Mk.mi(Mk.cyl(.012, .009, .03, 10), _walnut, Vector3(cos(a) * .15, .015, sin(a) * .15), g)


## Vieille caisse à outils en tôle verte écaillée (câbles, adaptateurs) posée au sol contre le bureau.
func _toolbox() -> void:
	var g := Node3D.new()
	g.name = "Toolbox"
	_put(g, Vector3(2.78, 0, -1.62), -.35)
	var tole := Mk.pbr("green_metal_rust", .5, {"metal": .55, "rough": .9})
	var steel := Mk.mat(Mk.c(0x8a8680), .4, 1.0)
	Mk.mi(Mk.rounded_box(Vector3(.46, .17, .22), .008, tole, 2), null, Vector3(0, .09, 0), g)
	# couvercle en bâtière + charnière
	var lid := Mk.mi(Mk.prism(PackedVector2Array([Vector2(-.11, 0), Vector2(.11, 0), Vector2(.07, .06), Vector2(-.07, .06)]), .46), tole, Vector3(.23, .176, 0), g)
	lid.rotation.y = -PI / 2
	Mk.mi(Mk.box(Vector3(.47, .004, .225)), Mk.mat(Mk.c(0x0a0a08), .8), Vector3(0, .175, 0), g)
	# poignée + loquets
	var h := Mk.mi(Mk.torus_arc(.07, .006, PI, 16, 8), steel, Vector3(0, .236, 0), g)
	for sx in [-1, 1]:
		Mk.mi(Mk.rounded_box(Vector3(.035, .045, .01), .003, steel, 1), null, Vector3(sx * .15, .16, .114), g)
	# câble qui dépasse
	Mk.mi(Mk.tube([Vector3(-.12, .2, .05), Vector3(-.2, .22, .14), Vector3(-.3, .02, .2), Vector3(-.45, .006, .1)], .0045, 24, 6), _black, Vector3.ZERO, g)


var plant: Node3D
var arch_lamp: Node3D


func _plant() -> void:
	var g := Node3D.new()
	plant = g
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
	var items := [[-2.75, 1.48, Mk.c(0xd4a838)], [-3.45, 1.42, Mk.c(0xc8c8cc)]]
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
