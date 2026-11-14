class_name Booth7080
extends Node3D
## Cabine de prise derrière la grande vitre du mur avant (vue depuis la régie). Construite en
## coordonnées du studio : x .5..4.5, z (fond du mur avant)..Z1, sol y = 0.
## Contenu : micro chant à lampe + anti-pop + casque + pupitre, batterie 70s en bois naturel,
## piano droit en noyer, piano électrique 73 touches, Les Paul + Marshall, lampadaire et suspension.

const X0 := .5
const X1 := 4.5
const Z0 := .4          # derrière le mur avant (épaisseur de l'ouverture)
const Z1 := 2.9
const CEIL := 2.45

var _wood_nat: Material
var _walnut: Material
var _chrome: Material
var _black: Material
var _brass_cym: Material


func _init() -> void:
	name = "Booth"
	_wood_nat = Mk.pbr("fine_grained_wood", .45, {"wear": 0.45, "tint": Mk.c(0xe8b878), "rough": .5, "clearcoat": .8, "clearcoat_rough": .15})
	_walnut = Mk.pbr("dark_wood", .6, {"wear": 0.5, "tint": Mk.c(0x8a5a40), "rough": .55, "clearcoat": .9, "clearcoat_rough": .12})
	_chrome = Mk.chrome_mat()
	_black = Mk.mat(Mk.c(0x111111), .45, .4)
	_brass_cym = Mk.mat(Mk.c(0xc89a44), .28, 1.0, {"normal": Mk.noise_tex(.9, 256, 2), "normal_scale": .25})
	_room()
	_lights()
	var drums := _drum_kit()
	drums.position = Vector3(3.4, 0, 2.0)
	drums.rotation.y = PI + .1
	add_child(drums)
	var piano := _upright_piano()
	piano.position = Vector3(1.3, 0, Z1 - .34)
	piano.rotation.y = PI
	add_child(piano)
	var rhodes := _electric_piano()
	rhodes.position = Vector3(.85, 0, 1.12)
	rhodes.rotation.y = PI / 2
	add_child(rhodes)
	var mic := _vocal_mic()
	mic.position = Vector3(2.25, 0, 1.25)
	mic.rotation.y = PI - .15
	add_child(mic)
	var amp := Props.place(self, "lespaul_marshall.glb", Vector3(3.88, 0, .82), PI - .6)
	amp.name = "GuitarCorner"
	# tapis persan sous la batterie (tapis de Maxime)
	Props.place(self, "carpet.glb", Vector3(3.4, .003, 2.0), .1, {"scale": .0026, "keep": ["SM_Carpet_03"]})


# ---------------------------------------------------------------- pièce
func _room() -> void:
	var parquet := Mk.pbr("plank_flooring", 1.4, {"wear": 0.4, "tint": Mk.c(0xb08868), "clearcoat": .3, "clearcoat_rough": .4, "local": false})
	var cx := (X0 + X1) / 2
	var cz := (Z0 + Z1) / 2
	Mk.mi(Mk.plane(X1 - X0, Z1 - Z0), parquet, Vector3(cx, 0, cz), self)
	var ceil := Mk.mi(Mk.plane(X1 - X0, Z1 - Z0), Mk.mat(Mk.c(0x1a120c), .95, 0.0, {"cull_off": true}), Vector3(cx, CEIL, cz), self)
	ceil.rotation.x = PI
	# murs : lattes en bas, toile de jute au-dessus, panneaux acoustiques
	var jute: StandardMaterial3D = Mk.pbr("hessian_230", .45, {"tint": Mk.c(0xb87038), "rough": 1.0}).duplicate()
	var slat := Mk.pbr("wood_planks", .9, {"wear": 0.35, "tint": Mk.c(0xb08868), "rough": .8})
	var dark := Mk.mat(Mk.c(0x0a0705), .95)
	var walls := [  # [centre, cap, longueur]
		[Vector3(cx, 0, Z1), PI, X1 - X0],
		[Vector3(X0, 0, cz), PI / 2, Z1 - Z0],
		[Vector3(X1, 0, cz), -PI / 2, Z1 - Z0],
	]
	for w in walls:
		var g := Node3D.new()
		g.position = w[0]
		g.rotation.y = w[1]
		add_child(g)
		var L: float = w[2]
		Mk.mi(Mk.quad(L, 1.0), dark, Vector3(0, .5, 0), g)
		Mk.mi(Mk.quad(L, CEIL - 1.0), jute, Vector3(0, 1.0 + (CEIL - 1.0) / 2, 0), g)
		var n := int(L / .07)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = Mk.box(Vector3(.045, .9, .022))
		mm.instance_count = n
		for i in n:
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(-L / 2 + .035 + i * .07, .5, .011)))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = slat
		g.add_child(mmi)
		Mk.mi(Mk.rounded_box(Vector3(L, .06, .045), .008, _walnut, 2), null, Vector3(0, 1.0, .022), g)
	# panneaux acoustiques bombés sur le mur du fond
	for i in 3:
		if i == 0:
			continue
		var p := Node3D.new()
		p.position = Vector3(X1 - .01, 1.6, .5 + i * .85)
		p.rotation.y = -PI / 2
		add_child(p)
		Mk.mi(Mk.rounded_box(Vector3(.7, .85, .05), .006, _walnut, 2), null, Vector3(0, 0, .025), p)
		Mk.mi(Mk.rounded_box(Vector3(.66, .81, .08), .03, Mk.pbr("hessian_230", .3, {"tint": Mk.c([0xc87a40, 0xa85a2a, 0xd08a48][i])}), 3), null, Vector3(0, 0, .04), p)


func _lights() -> void:
	# lampadaire (abat-jour plissé) au fond : la source chaude principale de la cabine
	var lamp := Node3D.new()
	lamp.position = Vector3(2.28, 0, Z1 - .25)
	add_child(lamp)
	var brass := Mk.mat(Mk.c(0xb8913e), .3, 1.0)
	Mk.mi(Mk.cyl(.14, .15, .025, 32), brass, Vector3(0, .012, 0), lamp)
	Mk.mi(Mk.cyl(.011, .011, 1.45, 10), brass, Vector3(0, .74, 0), lamp)
	var shade := Mk.mi(Mk.lathe([[.14, 1.62], [.22, 1.38], [.215, 1.38], [.135, 1.62]], 40), Mk.mat(Mk.c(0xf2dcb0), .9, 0.0, {"emission": Mk.c(0xffa850), "energy": 2.2, "cull_off": true}), Vector3.ZERO, lamp)
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Mk.mi(Mk.sphere(.04, 16, 8), Mk.glow(Mk.c(0xffc070), 6.0), Vector3(0, 1.5, 0), lamp)
	var l := OmniLight3D.new()
	l.light_color = Mk.c(0xffa050)
	l.light_energy = 3.5
	l.omni_range = 4.5
	l.omni_attenuation = 1.1
	l.shadow_enabled = true
	l.position = Vector3(0, 1.5, 0)
	lamp.add_child(l)
	# suspension en verre ambré au-dessus du micro
	var pend := Node3D.new()
	pend.position = Vector3(2.0, CEIL, 1.45)
	add_child(pend)
	Mk.mi(Mk.cyl(.003, .003, .55, 6), _black, Vector3(0, -.275, 0), pend)
	Mk.mi(Mk.lathe([[.0, -.55], [.05, -.55], [.17, -.75], [.165, -.75], [.045, -.56]], 40), Mk.mat(Mk.c(0xb8641c), .2, 0.0, {"alpha": .75, "emission": Mk.c(0xff9a40), "energy": 1.2, "cull_off": true}), Vector3.ZERO, pend)
	var sp := SpotLight3D.new()
	sp.light_color = Mk.c(0xffb870)
	sp.light_energy = 3.0
	sp.spot_range = 3.0
	sp.spot_angle = 50.0
	sp.shadow_enabled = true
	sp.position = Vector3(0, -.65, 0)
	sp.rotation.x = -PI / 2
	pend.add_child(sp)
	var fill := OmniLight3D.new()
	fill.light_color = Mk.c(0xff9a50)
	fill.light_energy = 1.0
	fill.omni_range = 3.5
	fill.position = Vector3(1.4, 1.9, 1.9)
	add_child(fill)


# ---------------------------------------------------------------- outils
static func _rot(n: Node3D, axis: String, v: float) -> Node3D:
	n.rotation[axis] = v
	return n


## Tube droit de a à b (rayon r).
func _rod(parent: Node3D, a: Vector3, b: Vector3, r: float, m: Material) -> MeshInstance3D:
	var n := Mk.mi(Mk.cyl(r, r, a.distance_to(b), 10), m, (a + b) / 2, parent)
	var dir := (b - a).normalized()
	if absf(dir.dot(Vector3.UP)) < .999:
		n.basis = Basis(Quaternion(Vector3.UP, dir))
	return n


## Trépied de pied (batterie / micro) : 3 jambes en compas + colonne.
func _tripod(parent: Node3D, at: Vector3, spread: float, h: float, col_top: float) -> void:
	for k in 3:
		var a := k * TAU / 3 + .5
		var foot := at + Vector3(cos(a) * spread, .01, sin(a) * spread)
		_rod(parent, foot, at + Vector3(0, h, 0), .0065, _chrome)
		Mk.mi(Mk.sphere(.012, 10, 6), _black, foot, parent)
	_rod(parent, at + Vector3(0, h * .6, 0), at + Vector3(0, col_top, 0), .011, _chrome)
	Mk.mi(Mk.cyl(.016, .016, .05, 12), _chrome, at + Vector3(0, h + .02, 0), parent)


## Fût de tambour sur l'axe local Y (centré) : coque bois, cercles, peaux, tirants + coquilles.
func _drum(parent: Node3D, r: float, depth: float, lugs: int, front_logo := false, wood_hoops := false) -> Node3D:
	var g := Node3D.new()
	parent.add_child(g)
	Mk.mi(Mk.cyl(r, r, depth, 56, false), _wood_nat, Vector3.ZERO, g)
	var inside := Mk.mi(Mk.cyl(r - .004, r - .004, depth, 56, false), Mk.mat(Mk.c(0x8a6a48), .8, 0.0, {"cull_off": true}), Vector3.ZERO, g)
	inside.scale = Vector3(1, .999, 1)
	var hoop_m: Material = _wood_nat if wood_hoops else _chrome
	var batter := Mk.mat(Mk.c(0xf0ece2), .85, 0.0, {"normal": Mk.noise_tex(.8, 128, 2), "normal_scale": .2})
	for sy in [-1, 1]:
		var y: float = sy * depth / 2
		Mk.mi(Mk.lathe([[r - .004, -.012], [r + .01, -.012], [r + .012, .012], [r - .002, .014]], 56), hoop_m, Vector3(0, y + sy * .004, 0), g)
		var head := Mk.mi(Mk.disc(r - .003, 56), batter, Vector3(0, y + sy * .001, 0), g)
		if sy < 0:
			head.rotation.x = PI
	if front_logo:
		var logo := Tex.canvas(512, 512, func(ci, w, h):
			ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x141414))
			ci.draw_circle(Vector2(w * .5, h * .5), w * .5, Mk.c(0x1a1a1a))
			ci.draw_circle(Vector2(w * .66, h * .7), w * .09, Mk.c(0x050505))
			Tex.silk(ci, "REEL'S", w * .5, h * .42, 64, Mk.c(0xe8dcc0), "center", 800)
			Tex.silk(ci, "SESSION  DRUMS", w * .5, h * .5, 26, Mk.c(0xc8a050), "center", 600))
		var fh := Mk.mi(Mk.disc(r - .003, 56), Mk.mat(Color.WHITE, .4, 0.0, {"map": logo}), Vector3(0, depth / 2 + .0015, 0), g)
		fh.name = "FrontHead"
	# tirants + coquilles (une rangée par peau sur les fûts courts, deux sur la grosse caisse)
	for k in lugs:
		var a := k * TAU / lugs
		var dir := Vector3(cos(a), 0, sin(a))
		for sy in [-1, 1]:
			var lug := Mk.mi(Mk.rounded_box(Vector3(.016, depth * .22, .02), .006, _chrome, 2), null, dir * (r + .008) + Vector3(0, sy * depth * .2, 0), g)
			lug.rotation.y = -a
			_rod(g, dir * (r + .012) + Vector3(0, sy * depth * .32, 0), dir * (r + .012) + Vector3(0, sy * (depth / 2 + .01), 0), .0028, _chrome)
	return g


func _cymbal(parent: Node3D, at: Vector3, R: float, tilt: Vector3) -> Node3D:
	var c := Node3D.new()
	c.position = at
	c.rotation = tilt
	parent.add_child(c)
	var prof := [[0, .03], [.03, .028], [.045, .012], [R * .6, .004], [R, -.004], [R, -.006], [R * .6, .002], [.045, .01], [.03, .026], [0, .028]]
	var m := Mk.mi(Mk.lathe(prof, 64), _brass_cym, Vector3.ZERO, c)
	m.name = "Cymbal"
	Mk.mi(Mk.cyl(.015, .015, .02, 12), Mk.mat(Mk.c(0x2a1a10), .8), Vector3(0, .035, 0), c)
	Mk.mi(Mk.cyl(.012, .016, .018, 12), _chrome, Vector3(0, .052, 0), c)
	return c


# ---------------------------------------------------------------- batterie 70s
## Batterie 4 fûts en bois naturel verni (façade vers +Z, batteur côté -Z) : grosse caisse 22"
## avec peau de résonance logotée, tom 12" sur la grosse caisse, tom basse 16" sur pieds, caisse
## claire sur pied panier, charleston, ride, crash, pédale, siège.
func _drum_kit() -> Node3D:
	var k := Node3D.new()
	k.name = "DrumKit"
	# grosse caisse (axe Z)
	var kick_p := Node3D.new()
	kick_p.position = Vector3(0, .285, 0)
	kick_p.rotation.x = PI / 2
	k.add_child(kick_p)
	var kick := _drum(kick_p, .28, .38, 10, true, true)
	kick.rotation.x = PI  # peau logotée vers +Z
	for sx in [-1, 1]:
		_rod(k, Vector3(sx * .22, .2, .05), Vector3(sx * .36, .0, .2), .007, _chrome)
		Mk.mi(Mk.sphere(.012, 10, 6), _black, Vector3(sx * .36, .006, .2), k)
	# pédale
	_rot(Mk.mi(Mk.rounded_box(Vector3(.08, .012, .26), .004, Mk.mat(Mk.c(0x2a2a2a), .4, .8), 2), null, Vector3(0, .03, -.36), k), "x", .2)
	_rod(k, Vector3(0, .05, -.22), Vector3(0, .38, -.2), .005, _chrome)
	Mk.mi(Mk.sphere(.028, 14, 8), Mk.mat(Mk.c(0xe8e0cc), .9), Vector3(0, .36, -.2), k)
	# tom 12" sur support
	_rod(k, Vector3(0, .56, -.02), Vector3(-.05, .66, -.06), .011, _chrome)
	var tom_p := Node3D.new()
	tom_p.position = Vector3(-.14, .78, -.08)
	tom_p.rotation = Vector3(-.45, 0, .12)
	k.add_child(tom_p)
	_drum(tom_p, .155, .22, 6)
	# tom basse 16"
	var ft_p := Node3D.new()
	ft_p.position = Vector3(.45, .5, -.32)
	k.add_child(ft_p)
	_drum(ft_p, .205, .38, 8)
	for a in [.6, 2.6, 4.4]:
		_rod(k, Vector3(.45 + cos(a) * .24, .55, -.32 + sin(a) * .24), Vector3(.45 + cos(a) * .3, .0, -.32 + sin(a) * .3), .006, _chrome)
	# caisse claire sur pied panier
	_tripod(k, Vector3(-.3, 0, -.36), .22, .3, .58)
	var sn_p := Node3D.new()
	sn_p.position = Vector3(-.3, .66, -.36)
	sn_p.rotation = Vector3(.12, 0, -.08)
	k.add_child(sn_p)
	_drum(sn_p, .178, .14, 8)
	for i in 3:
		var a := i * TAU / 3
		_rod(k, Vector3(-.3, .58, -.36), Vector3(-.3 + cos(a) * .15, .6, -.36 + sin(a) * .15), .005, _chrome)
	# charleston
	var hh := Vector3(-.62, 0, -.22)
	_tripod(k, hh, .24, .35, .9)
	_rod(k, hh + Vector3(0, .9, 0), hh + Vector3(0, 1.0, 0), .005, _chrome)
	_cymbal(k, hh + Vector3(0, .88, 0), .18, Vector3.ZERO)
	_cymbal(k, hh + Vector3(0, .9, 0), .18, Vector3(PI, 0, 0))
	_rot(Mk.mi(Mk.rounded_box(Vector3(.09, .012, .3), .004, Mk.mat(Mk.c(0x2a2a2a), .4, .8), 2), null, hh + Vector3(0, .04, -.2), k), "x", .2)
	# ride + crash sur pieds perche
	var ride_at := Vector3(.68, 0, .08)
	_tripod(k, ride_at, .26, .38, .95)
	_rod(k, ride_at + Vector3(0, .95, 0), Vector3(.5, 1.06, -.12), .009, _chrome)
	_cymbal(k, Vector3(.5, 1.06, -.12), .26, Vector3(.25, 0, -.22))
	var crash_at := Vector3(-.5, 0, .25)
	_tripod(k, crash_at, .24, .38, 1.05)
	_rod(k, crash_at + Vector3(0, 1.05, 0), Vector3(-.38, 1.22, .02), .009, _chrome)
	_cymbal(k, Vector3(-.38, 1.22, .02), .21, Vector3(.35, 0, .2))
	# siège
	var th := Vector3(0, 0, -.72)
	_tripod(k, th, .25, .25, .46)
	Mk.mi(Mk.rounded_box(Vector3(.36, .09, .36), .04, Mk.pbr("leather_brown", .3, {"wear": 0.6, "tint": Mk.c(0x5a4a40)}), 4), null, th + Vector3(0, .5, 0), k)
	# baguettes posées sur le tom basse
	for i in 2:
		var st := _rod(k, Vector3(.33, .705 + i * .012, -.3 + i * .03), Vector3(.62, .705 + i * .012, -.2 + i * .03), .0065, _wood_nat)
		st.name = "Stick"
	return k


# ---------------------------------------------------------------- piano droit
## Piano droit en noyer verni (claviers vers +Z) : joues sculptées, consoles, clavier 88 touches,
## cylindre ouvert, pupitre avec partition, bougeoirs laiton, panneau inférieur, 3 pédales, banquette.
func _upright_piano() -> Node3D:
	var g := Node3D.new()
	g.name = "UprightPiano"
	var W := 1.5
	var H := 1.27
	var D := .6
	var wal := _walnut
	var back_z := -D / 2
	# caisse haute (derrière le clavier) et caisse basse
	Mk.mi(Mk.rounded_box(Vector3(W, H - .72, .32), .01, wal, 2), null, Vector3(0, .72 + (H - .72) / 2, back_z + .16), g)
	Mk.mi(Mk.rounded_box(Vector3(W - .12, .64, .3), .008, wal, 2), null, Vector3(0, .33, back_z + .15), g)
	# couvercle débordant + moulure
	Mk.mi(Mk.rounded_box(Vector3(W + .04, .03, .36), .01, wal, 3), null, Vector3(0, H + .015, back_z + .17), g)
	Mk.mi(Mk.rounded_box(Vector3(W + .02, .03, .34), .012, wal, 3), null, Vector3(0, H - .02, back_z + .17), g)
	# joues + consoles galbées (pieds avant)
	for sx in [-1, 1]:
		var cheek := PackedVector2Array([Vector2(back_z, 0), Vector2(back_z + .3, 0), Vector2(back_z + .3, .62), Vector2(.18, .66), Vector2(.2, .8), Vector2(back_z + .32, .82), Vector2(back_z + .32, H), Vector2(back_z, H)])
		var c := Mk.mi(Mk.prism(cheek, .05), wal, Vector3(sx * (W / 2 - .025) - .025, 0, 0), g)
		c.rotation.y = -PI / 2
		# console tournée
		var col := Mk.mi(Mk.lathe([[.035, 0], [.03, .05], [.022, .2], [.035, .35], [.03, .5], [.04, .62], [0, .62]], 24), wal, Vector3(sx * (W / 2 - .05), 0, .15), g)
		col.name = "Toe"
		Mk.mi(Mk.rounded_box(Vector3(.08, .04, .52), .008, wal, 2), null, Vector3(sx * (W / 2 - .05), .02, -.04), g)
	# lit de clavier + liteau
	Mk.mi(Mk.rounded_box(Vector3(W - .1, .05, .32), .004, wal, 2), null, Vector3(0, .68, .02), g)
	Mk.mi(Mk.rounded_box(Vector3(W - .1, .04, .02), .004, wal, 2), null, Vector3(0, .71, .185), g)
	# clavier : 52 touches blanches (MultiMesh) + 36 noires
	var kw := 1.23 / 52.0
	var ivory := Mk.mat(Mk.c(0xf0e6cc), .35, 0.0, {"clearcoat": .4})
	var ebony := Mk.mat(Mk.c(0x0c0a08), .3, 0.0, {"clearcoat": .6})
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Mk.rounded_box(Vector3(kw - .0012, .022, .15), .0015, null, 1)
	mm.instance_count = 52
	for i in 52:
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(-1.23 / 2 + kw * (i + .5), .727, .1)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = ivory
	g.add_child(mmi)
	var blacks := []
	var pattern := [1, 1, 0, 1, 1, 1, 0]  # noire après do, ré, (mi), fa, sol, la, (si) — on commence au la
	var start := 5  # la0
	for i in 51:
		if pattern[(start + i) % 7] == 1:
			blacks.append(-1.23 / 2 + kw * (i + 1))
	var bm := MultiMesh.new()
	bm.transform_format = MultiMesh.TRANSFORM_3D
	bm.mesh = Mk.rounded_box(Vector3(kw * .55, .02, .095), .002, null, 1)
	bm.instance_count = blacks.size()
	for i in blacks.size():
		bm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(blacks[i], .748, .07)))
	var bmi := MultiMeshInstance3D.new()
	bmi.multimesh = bm
	bmi.material_override = ebony
	g.add_child(bmi)
	# cylindre ouvert (rabattu) + barre au-dessus du clavier, pupitre et partition
	Mk.mi(Mk.rounded_box(Vector3(W - .12, .07, .02), .006, wal, 2), null, Vector3(0, .8, back_z + .33), g)
	var nb := Tex.canvas(512, 64, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0))
		Tex.silk(ci, "REEL  &  SONS", w / 2.0, h * .55, 34, Mk.c(0xd8b050), "center", 800)
		Tex.silk(ci, "NEW  YORK", w / 2.0, h * .92, 16, Mk.c(0xc8a048), "center", 600), true)
	var nbm := Mk.mat(Color.WHITE, .3, .9, {"map": nb})
	nbm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	Mk.mi(Mk.quad(.26, .033), nbm, Vector3(0, .8, back_z + .3405), g)
	var desk := Mk.mi(Mk.rounded_box(Vector3(W - .2, .3, .018), .006, wal, 2), null, Vector3(0, .99, back_z + .345), g)
	desk.rotation.x = -.18
	Mk.mi(Mk.rounded_box(Vector3(W - .2, .02, .05), .004, wal, 2), null, Vector3(0, .845, back_z + .37), g)
	var score := Tex.canvas(512, 360, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xf2ead6))
		for sys in 4:
			for l in 5:
				var y := 40 + sys * 80 + l * 8
				ci.draw_line(Vector2(20, y), Vector2(w / 2.0 - 10, y), Color(.1, .1, .1, .7), 1.0)
				ci.draw_line(Vector2(w / 2.0 + 10, y), Vector2(w - 20, y), Color(.1, .1, .1, .7), 1.0)
			var r := Tex.rng(sys + 3)
			for n in 16:
				var x := 30 + n * 28 + (20 if n >= 8 else 0)
				ci.draw_circle(Vector2(x, 40 + sys * 80 + r.randi_range(0, 8) * 4), 3.5, Color(.05, .05, .05))
		Tex.grime(ci, w, h, 9, 2))
	var sheet := Mk.mi(Mk.quad(.56, .36), Mk.mat(Color.WHITE, .9, 0.0, {"map": score, "cull_off": true}), Vector3(0, 1.02, back_z + .36), g)
	sheet.rotation.x = -.18
	# bougeoirs laiton
	var brass := Mk.mat(Mk.c(0xb8913e), .3, 1.0)
	for sx in [-1, 1]:
		var base := Vector3(sx * .55, 1.0, back_z + .33)
		_rot(Mk.mi(Mk.cyl(.025, .025, .006, 16), brass, base, g), "x", PI / 2)
		_rod(g, base, base + Vector3(sx * .06, .02, .12), .005, brass)
		Mk.mi(Mk.cyl(.022, .018, .015, 16), brass, base + Vector3(sx * .06, .03, .12), g)
		Mk.mi(Mk.cyl(.009, .009, .09, 12), Mk.mat(Mk.c(0xf2ead0), .7), base + Vector3(sx * .06, .08, .12), g)
	# panneau inférieur à moulure + pédales
	Mk.mi(Mk.rounded_box(Vector3(W - .3, .45, .015), .01, wal, 3), null, Vector3(0, .34, back_z + .305), g)
	for i in 3:
		var pd := Mk.mi(Mk.rounded_box(Vector3(.035, .012, .12), .004, brass, 2), null, Vector3(-.08 + i * .08, .06, back_z + .36), g)
		pd.rotation.x = -.1
	# métronome sur le couvercle
	var met := Mk.mi(Mk.prism(PackedVector2Array([Vector2(-.06, 0), Vector2(.06, 0), Vector2(.02, .2), Vector2(-.02, .2)]), .08), wal, Vector3(.45, H + .03, back_z + .1), g)
	met.name = "Metronome"
	# banquette
	var bench := Node3D.new()
	bench.position = Vector3(0, 0, .55)
	g.add_child(bench)
	Mk.mi(Mk.rounded_box(Vector3(.8, .07, .36), .02, Mk.pbr("leather_brown", .3, {"wear": 0.6, "tint": Mk.c(0x6a3a2a), "clearcoat": .2}), 3), null, Vector3(0, .5, 0), bench)
	Mk.mi(Mk.rounded_box(Vector3(.78, .04, .34), .01, wal, 2), null, Vector3(0, .45, 0), bench)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			Mk.mi(Mk.lathe([[.025, 0], [.018, .1], [.024, .2], [.02, .43], [0, .43]], 16), wal, Vector3(sx * .35, 0, sz * .14), bench)
	return g


# ---------------------------------------------------------------- piano électrique
## Piano électrique de scène 73 touches (claviers vers +Z) : caisse tolex noir, couvercle,
## coins chromés, réglette alu, plaque de nom, 2 potards, 4 pieds chromés + entretoise, pédale.
func _electric_piano() -> Node3D:
	var g := Node3D.new()
	g.name = "ElectricPiano"
	var W := 1.16
	var D := .52
	var tolex: StandardMaterial3D = Mk.pbr("leather_brown", .15, {"wear": 0.6, "tint": Mk.c(0x2a2828), "rough": .9}).duplicate()
	var y0 := .62
	Mk.mi(Mk.rounded_box(Vector3(W, .12, D), .02, tolex, 3), null, Vector3(0, y0 + .06, 0), g)
	# couvercle (harpe) bombé
	Mk.mi(Mk.rounded_box(Vector3(W - .02, .1, D - .2), .03, tolex, 4), null, Vector3(0, y0 + .17, -.09), g)
	var alu := Mk.mat(Mk.c(0xc0beb8), .3, 1.0, {"normal": Mk.scratch_normal(), "normal_scale": .2})
	var name_tex := Tex.canvas(1024, 64, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x1a1a1a))
		Tex.silk(ci, "STAGE 73", w * .5, h * .72, 24, Mk.c(0xd8d4cc), "center", 700))
	var nm := Mk.mi(Mk.quad(W - .1, .05), Mk.mat(Color.WHITE, .4, .5, {"map": name_tex}), Vector3(0, y0 + .2, .019), g)
	nm.rotation.x = -.6
	Mk.mi(Mk.rounded_box(Vector3(W - .04, .02, .03), .004, alu, 2), null, Vector3(0, y0 + .125, .045), g)
	# coins chromés
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			Mk.mi(Mk.sphere(.028, 12, 8), _chrome, Vector3(sx * (W / 2 - .01), y0 + .1, sz * (D / 2 - .01)), g).set_scale(Vector3(1, .7, 1))
	# clavier 73 touches (43 blanches)
	var kw := .95 / 43.0
	var ivory := Mk.mat(Mk.c(0xf2eee4), .4)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Mk.rounded_box(Vector3(kw - .0012, .02, .14), .0015, null, 1)
	mm.instance_count = 43
	for i in 43:
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(-.95 / 2 + kw * (i + .5) + .06, y0 + .125, .16)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = ivory
	g.add_child(mmi)
	var blacks := []
	var pattern := [1, 1, 0, 1, 1, 1, 0]  # mi grave : on commence au mi
	for i in 42:
		if pattern[(2 + i) % 7] == 1:
			blacks.append(-.95 / 2 + kw * (i + 1) + .06)
	var bm := MultiMesh.new()
	bm.transform_format = MultiMesh.TRANSFORM_3D
	bm.mesh = Mk.rounded_box(Vector3(kw * .55, .02, .09), .002, null, 1)
	bm.instance_count = blacks.size()
	for i in blacks.size():
		bm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(blacks[i], y0 + .145, .135)))
	var bmi := MultiMeshInstance3D.new()
	bmi.multimesh = bm
	bmi.material_override = Mk.mat(Mk.c(0x0c0c0c), .35)
	g.add_child(bmi)
	# potards à gauche
	for i in 2:
		var kn := Mk.knob(.012, .014)
		kn.position = Vector3(-W / 2 + .04 + i * .035, y0 + .13, .17)
		g.add_child(kn)
	# pieds chromés vissés + entretoise
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_rod(g, Vector3(sx * (W / 2 - .08), y0, sz * (D / 2 - .08)), Vector3(sx * (W / 2 - .02), 0.01, sz * (D / 2 - .03)), .012, _chrome)
			Mk.mi(Mk.cyl(.02, .02, .012, 12), _black, Vector3(sx * (W / 2 - .02), .006, sz * (D / 2 - .03)), g)
		_rod(g, Vector3(sx * (W / 2 - .05), .25, -(D / 2 - .05)), Vector3(sx * (W / 2 - .05), .25, D / 2 - .05), .006, _chrome)
	# pédale de sustain + câble
	Mk.mi(Mk.rounded_box(Vector3(.08, .03, .2), .01, _black, 2), null, Vector3(.15, .015, .45), g)
	Mk.mi(Mk.tube([Vector3(.15, .02, .35), Vector3(.2, .01, .2), Vector3(.25, .3, -.1), Vector3(.25, y0, -.2)], .003, 20, 6), _black, Vector3.ZERO, g)
	return g


# ---------------------------------------------------------------- micro chant
## Micro à lampe à large membrane sur perche (araignée élastique), anti-pop, casque fermé suspendu
## au pied, pupitre avec paroles, câble jusqu'au mur.
func _vocal_mic() -> Node3D:
	var g := Node3D.new()
	g.name = "VocalMic"
	_tripod(g, Vector3.ZERO, .3, .28, 1.42)
	var top := Vector3(0, 1.44, 0)
	Mk.mi(Mk.cyl(.016, .016, .04, 12), _black, top, g)
	var boom_end := Vector3(0, 1.5, .5)
	_rod(g, top + Vector3(0, 0, -.2), boom_end, .009, _black)
	Mk.mi(Mk.sphere(.04, 14, 8), _black, top + Vector3(0, -.01, -.24), g)  # contrepoids
	# araignée + micro
	var mic := Node3D.new()
	mic.position = boom_end + Vector3(0, -.12, .04)
	g.add_child(mic)
	var ring := Mk.mi(Mk.torus_ring(.06, .004), _chrome, Vector3(0, .02, 0), mic)
	ring.name = "Shockmount"
	for k in 4:
		var a := k * TAU / 4 + PI / 4
		_rod(mic, Vector3(cos(a) * .06, .02, sin(a) * .06), Vector3(cos(a) * .026, .05, sin(a) * .026), .0018, Mk.mat(Mk.c(0x111111), .8))
	var body := Mk.mat(Mk.c(0xb8b4aa), .3, 1.0, {"normal": Mk.scratch_normal(), "normal_scale": .2})
	Mk.mi(Mk.cyl(.028, .026, .16, 32), body, Vector3(0, .02, 0), mic)
	var grille := Mk.mat(Mk.c(0xc8c4bc), .35, 1.0, {"normal": Mk.noise_tex(1.0, 128, 1), "normal_scale": .6})
	Mk.mi(Mk.cyl(.03, .03, .1, 32), grille, Vector3(0, .15, 0), mic)
	Mk.mi(Mk.sphere(.03, 24, 12, true), grille, Vector3(0, .2, 0), mic)
	Mk.mi(Mk.torus_ring(.0305, .002), _chrome, Vector3(0, .1, 0), mic)
	# anti-pop sur col de cygne
	var pop_c := boom_end + Vector3(0, .02, .2)
	Mk.mi(Mk.tube([boom_end + Vector3(0, 0, -.05), boom_end + Vector3(0, .1, .05), pop_c + Vector3(0, -.09, 0)], .004, 16, 6), _black, Vector3.ZERO, g)
	var pr := Mk.mi(Mk.torus_ring(.08, .005), _black, pop_c, g)
	pr.rotation.x = PI / 2
	var pf := Mk.mi(Mk.disc(.079, 40), Mk.mat(Mk.c(0x050505), .9, 0.0, {"alpha": .55, "cull_off": true}), pop_c, g)
	pf.rotation.x = PI / 2
	# casque fermé accroché sur la colonne
	var hp := Node3D.new()
	hp.position = Vector3(0, 1.1, .02)
	g.add_child(hp)
	var band := Mk.mi(Mk.torus_arc(.09, .007, PI * 1.1, 24, 8), _black, Vector3.ZERO, hp)
	band.rotation.y = PI / 2
	for sx in [-1, 1]:
		var cup := Mk.mi(Mk.cyl(.045, .045, .03, 24), Mk.mat(Mk.c(0x1a1a1a), .5), Vector3(sx * .09, -.08, 0), hp)
		cup.rotation.z = PI / 2
		var cush := Mk.mi(Mk.torus_ring(.035, .012), Mk.pbr("leather_brown", .1, {"wear": 0.6, "tint": Mk.c(0x2a2020)}), Vector3(sx * .07, -.08, 0), hp)
		cush.rotation.z = PI / 2
	Mk.mi(Mk.tube([Vector3(.09, -.1, 0), Vector3(.1, -.4, .05), Vector3(.2, -1.0, .2), Vector3(.5, -1.09, .5)], .003, 24, 6), _black, Vector3.ZERO, hp)
	# câble XLR du micro jusqu'au mur avant
	Mk.mi(Mk.tube([mic.position + Vector3(0, -.06, 0), mic.position + Vector3(0, -.3, -.05), Vector3(0, .05, .3), Vector3(.1, .01, -.2), Vector3(.4, .006, -.6)], .0035, 30, 6), _black, Vector3.ZERO, g)
	# pupitre avec paroles
	var ms := Vector3(.42, 0, .55)
	_tripod(g, ms, .2, .2, 1.05)
	var desk := Mk.mi(Mk.rounded_box(Vector3(.48, .32, .008), .004, _black, 1), null, ms + Vector3(0, 1.15, 0), g)
	desk.rotation.x = .35
	var lyr := Tex.canvas(256, 340, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xf2ead8))
		for l in 14:
			var y := 30 + l * 21
			var ln := 120 + Tex.rng(l).randf() * 100
			ci.draw_line(Vector2(20, y), Vector2(20 + ln, y), Color(.1, .1, .25, .65), 2.0)
		Tex.grime(ci, w, h, 41, 2))
	var paper := Mk.mi(Mk.quad(.21, .28), Mk.mat(Color.WHITE, .9, 0.0, {"map": lyr, "cull_off": true}), ms + Vector3(0, 1.16, -.006), g)
	paper.rotation = Vector3(.35, PI, 0)
	return g
