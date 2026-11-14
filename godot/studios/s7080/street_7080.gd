class_name Street7080
extends Node3D
## La rue derrière la fenêtre : un carrefour new-yorkais des années 70.
## En face : cinq immeubles (briques, pierre, escaliers de secours, château d'eau, corniches), vitrines,
## enseignes au néon et marquise de cinéma à ampoules (noms inventés) ; au loin, des tours.
## Côté studio : trottoir, réverbères, bouche d'incendie, boîte à journaux, poubelle.
## Chaussée mouillée, vapeur qui sort d'une plaque d'égout, pluie le soir et la nuit, taxis jaunes.
## Repère local : x le long de la rue, +z = vers l'immeuble d'en face (façades à z = FACE), sol à GY.
## `set_time(night, sky, rain)` est appelé par le cycle jour / nuit du studio.

const GY := -.35
const FACE := 14.1
const SIGN_RED := Color(1.0, .18, .22)
const SIGN_BLUE := Color(.35, .6, 1.0)
const SIGN_AMBER := Color(1.0, .55, .15)
const SIGN_GREEN := Color(.3, 1.0, .5)

var car: Node3D                     # taxi qui passe (animé par le studio)
var _night_mats: Array = []         # [matériau, couleur de base, énergie de nuit, énergie de jour]
var _night_lights: Array = []       # [lumière, énergie de nuit, énergie de jour]
var _sky_mat: StandardMaterial3D
var _road_mat: StandardMaterial3D
var _rain: GPUParticles3D
var _bulbs: Array = []              # ampoules de la marquise (chenillard)
var _night := 1.0


func _init() -> void:
	name = "Street"
	_ground()
	_buildings()
	_skyline()
	_near_side()
	_vehicles()
	_steam(Vector3(4.2, GY, 7.4))
	_rain_fx()
	# la rue ne projette pas d'ombre (sinon les immeubles d'en face cachent le soleil du matin)
	for n in find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ---------------------------------------------------------------- helpers
func _lit(col: Color, night_e: float, day_e := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col * night_e
	_night_mats.append([m, col, night_e, day_e])
	return m


func _light(l: Light3D, night_e: float, day_e := 0.0) -> void:
	l.light_energy = night_e
	_night_lights.append([l, night_e, day_e])


func _face(q: MeshInstance3D) -> MeshInstance3D:
	q.rotation.y = PI   # les façades regardent vers la fenêtre (-z)
	return q


# ---------------------------------------------------------------- sol
func _ground() -> void:
	_road_mat = Mk.mat(Mk.c(0x161618), .18, 0.0, {"normal": Mk.noise_tex(.35, 256, 3), "normal_scale": .35})
	_road_mat.albedo_texture = _asphalt_tex()
	Mk.mi(Mk.plane(70, 9), _road_mat, Vector3(2, GY, 7.0), self)
	var curb := Mk.mat(Mk.c(0x5a5650), .8, 0.0, {"map": _slabs_tex()})
	curb.uv1_scale = Vector3(30, 1.2, 1)
	Mk.mi(Mk.box(Vector3(70, .15, 2.3)), curb, Vector3(2, GY + .075, 1.6), self)
	Mk.mi(Mk.box(Vector3(70, .15, 2.6)), curb, Vector3(2, GY + .075, 12.8), self)
	# bordure de trottoir en granit
	var granite := Mk.mat(Mk.c(0x6a6862), .6)
	Mk.mi(Mk.box(Vector3(70, .16, .14)), granite, Vector3(2, GY + .08, 2.75), self)
	Mk.mi(Mk.box(Vector3(70, .16, .14)), granite, Vector3(2, GY + .08, 11.5), self)
	# plaque d'égout (la vapeur en sort)
	var iron := Mk.mat(Mk.c(0x1c1a18), .5, .6)
	Mk.mi(Mk.cyl(.34, .34, .01, 24), iron, Vector3(4.2, GY + .004, 7.4), self)
	# passage piéton usé
	var paint := Mk.mat(Mk.c(0xb8b4a8), .6)
	for k in 7:
		Mk.mi(Mk.box(Vector3(.45, .004, 2.6)), paint, Vector3(-7.5 + k * .9, GY + .002, 7.0), self)


func _asphalt_tex() -> Texture2D:
	return Tex.canvas(512, 512, func(ci: CanvasItem, w: float, h: float):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x2a2a2c))
		var r := Tex.rng(441)
		for i in 9000:
			var c := Color(1, 1, 1, .04) if r.randf() > .5 else Color(0, 0, 0, .12)
			ci.draw_rect(Rect2(r.randf() * w, r.randf() * h, 2, 2), c)
		# raccords de bitume et flaques (plus sombres = plus lisses à l'œil)
		for i in 14:
			var p := Vector2(r.randf() * w, r.randf() * h)
			ci.draw_circle(p, 18 + r.randf() * 40, Color(0, 0, 0, .25))
		for i in 6:
			var y := r.randf() * h
			ci.draw_line(Vector2(0, y), Vector2(w, y + r.randf_range(-30, 30)), Color(0, 0, 0, .3), 3.0))


func _slabs_tex() -> Texture2D:
	return Tex.canvas(256, 256, func(ci: CanvasItem, w: float, h: float):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x8a867e))
		var r := Tex.rng(442)
		for i in 1600:
			ci.draw_rect(Rect2(r.randf() * w, r.randf() * h, 2, 2), Color(0, 0, 0, .08))
		ci.draw_line(Vector2(0, 0), Vector2(0, h), Color(0, 0, 0, .45), 3.0)
		ci.draw_line(Vector2(0, h / 2), Vector2(w, h / 2), Color(0, 0, 0, .3), 2.0))


# ---------------------------------------------------------------- immeubles d'en face
func _buildings() -> void:
	# [x0, x1, hauteur, couleur de façade, type de brique, rez-de-chaussée]
	var specs := [
		[-16.0, -7.0, 18.0, 0x7a3a2a, "brick", "pawn"],
		[-7.0, -1.0, 12.0, 0xb8a888, "stone", "deli"],
		[-1.0, 6.5, 15.0, 0x5a3426, "brick", "theater"],
		[6.5, 12.5, 22.0, 0x6a4a36, "brick", "hotel"],
		[12.5, 21.0, 13.0, 0x8a8478, "stone", "bar"],
	]
	var r := Tex.rng(1970)
	for s in specs:
		_building(s[0], s[1], s[2], Mk.c(s[3]), s[4], s[5], r)
	# château d'eau sur le toit du premier immeuble
	_water_tower(Vector3(-11.0, GY + 18.0, FACE + 4.0))
	# escaliers de secours (fonte noire) sur les façades en brique
	_fire_escape(-11.5, 4, 3.2)
	_fire_escape(9.5, 6, 3.2)


func _building(x0: float, x1: float, h: float, col: Color, kind: String, shop: String, r: RandomNumberGenerator) -> void:
	var w := x1 - x0
	var cx := (x0 + x1) / 2
	var floors := int((h - 4.0) / 3.1)
	var cols := int(w / 1.9)
	var seed := int(absf(x0) * 13)
	var tex := _facade_tex(col, kind, cols, floors, seed)
	var m := Mk.mat(Color.WHITE, .9, 0.0, {"map": tex})
	# masse du bâtiment (on voit un peu les côtés en biais)
	Mk.mi(Mk.box(Vector3(w - .05, h, 8.0)), Mk.mat(col * .6, .95), Vector3(cx, GY + h / 2, FACE + 4.0), self)
	_face(Mk.mi(Mk.quad(w, h - 4.0), m, Vector3(cx, GY + 4.0 + (h - 4.0) / 2, FACE - .01), self))
	# fenêtres allumées la nuit (calque émissif aux mêmes cases que la texture)
	var draw_lit := func(ci: CanvasItem, tw: float, th: float) -> void:
		ci.draw_rect(Rect2(0, 0, tw, th), Color(0, 0, 0, 0))
		var rr := Tex.rng(seed + 7)
		for fy in floors:
			for fx in cols:
				if rr.randf() < .32:
					var c := Color(1.0, .72, .38).lerp(Color(.75, .85, 1.0), rr.randf() * .4) * (.6 + rr.randf() * .5)
					var cell := _win_rect(fx, fy, cols, floors, tw, th)
					ci.draw_rect(cell, c)
					if rr.randf() < .5:
						ci.draw_rect(Rect2(cell.position, Vector2(cell.size.x * .45, cell.size.y)), c * Color(.5, .45, .4, 1))
	var lit := Tex.canvas(512, 512, draw_lit, true)
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	lm.albedo_texture = lit
	_night_mats.append([lm, Color(1, 1, 1), 1.0, 0.0])
	_face(Mk.mi(Mk.quad(w, h - 4.0), lm, Vector3(cx, GY + 4.0 + (h - 4.0) / 2, FACE - .02), self))
	# corniche + appuis de fenêtres en relief
	var trim := Mk.mat(col.lerp(Color(.85, .8, .7), .5) * .9, .8)
	Mk.mi(Mk.box(Vector3(w, .5, .6)), trim, Vector3(cx, GY + h - .25, FACE - .3), self)
	Mk.mi(Mk.box(Vector3(w, .18, .9)), trim, Vector3(cx, GY + h - .6, FACE - .45), self)
	for fy in floors:
		var y := GY + 4.0 + (h - 4.0) * (1.0 - (fy + .82) / floors)
		Mk.mi(Mk.box(Vector3(w - .3, .07, .12)), trim, Vector3(cx, y, FACE - .06), self)
	# bandeau au-dessus du rez-de-chaussée
	Mk.mi(Mk.box(Vector3(w, .35, .3)), trim, Vector3(cx, GY + 3.85, FACE - .15), self)
	_storefront(x0, x1, shop, r)


func _win_rect(fx: int, fy: int, cols: int, floors: int, tw: float, th: float) -> Rect2:
	var cw := tw / cols
	var ch := th / floors
	return Rect2(fx * cw + cw * .22, fy * ch + ch * .18, cw * .56, ch * .6)


func _facade_tex(col: Color, kind: String, cols: int, floors: int, seed: int) -> Texture2D:
	var draw := func(ci: CanvasItem, w: float, h: float) -> void:
		ci.draw_rect(Rect2(0, 0, w, h), col)
		var r := Tex.rng(seed)
		if kind == "brick":
			var bh := 6.0
			var bw := 16.0
			var row := 0
			var y := 0.0
			while y < h:
				var off := (bw / 2) if row % 2 == 1 else 0.0
				var x := -off
				while x < w:
					var c := col * (0.82 + r.randf() * .3)
					c.a = 1.0
					ci.draw_rect(Rect2(x + .6, y + .6, bw - 1.2, bh - 1.2), c)
					x += bw
				y += bh
				row += 1
		else:
			for i in 60:
				var y := i * (h / 60.0)
				ci.draw_line(Vector2(0, y), Vector2(w, y), Color(0, 0, 0, .12), 1.0)
		# coulures et suie (léger, c'est la rue)
		for i in 30:
			var x := r.randf() * w
			ci.draw_rect(Rect2(x, r.randf() * h * .2, 3 + r.randf() * 5, h * (.2 + r.randf() * .5)), Color(0, 0, 0, .05))
		# fenêtres : encadrement clair, vitre sombre qui reflète un peu le ciel, croisillon
		for fy in floors:
			for fx in cols:
				var cell := _win_rect(fx, fy, cols, floors, w, h)
				ci.draw_rect(cell.grow(3), col.lerp(Color(.9, .86, .78), .55))
				ci.draw_rect(cell, Color(.07, .08, .1))
				ci.draw_rect(Rect2(cell.position.x, cell.position.y, cell.size.x, cell.size.y * .4), Color(.16, .18, .22))
				ci.draw_line(Vector2(cell.position.x, cell.get_center().y), Vector2(cell.end.x, cell.get_center().y), col * .5, 2.0)
				if r.randf() < .35:  # store baissé
					ci.draw_rect(Rect2(cell.position, Vector2(cell.size.x, cell.size.y * r.randf_range(.2, .7))), Color(.75, .7, .6))
	return Tex.canvas(512, 512, draw)


## Rez-de-chaussée : vitrine éclairée + enseigne selon le commerce (noms inventés).
func _storefront(x0: float, x1: float, shop: String, r: RandomNumberGenerator) -> void:
	var w := x1 - x0
	var cx := (x0 + x1) / 2
	var dark := Mk.mat(Mk.c(0x141210), .6, .3)
	Mk.mi(Mk.box(Vector3(w - .4, 3.2, .2)), dark, Vector3(cx, GY + 1.75, FACE - .05), self)
	var glass_col := Color(1.0, .78, .5) if shop != "theater" else Color(1.0, .85, .6)
	var shop_m := _lit(glass_col, .75, .12)
	shop_m.albedo_texture = _shop_tex(int(absf(x0) * 7))
	_face(Mk.mi(Mk.quad(w - 1.2, 2.2), shop_m, Vector3(cx, GY + 1.45, FACE - .16), self))
	# porte
	_face(Mk.mi(Mk.quad(1.0, 2.3), Mk.mat(Mk.c(0x0a0908), .4), Vector3(cx + w * .3, GY + 1.3, FACE - .17), self))
	match shop:
		"deli":
			_neon_text("DELI", Vector3(cx - 1.2, GY + 3.0, FACE - .3), 1.0, SIGN_RED)
			_neon_text("OPEN 24 HRS", Vector3(cx + 1.4, GY + 2.95, FACE - .3), .45, SIGN_BLUE)
			_awning(cx, w - .6, Mk.c(0x1e4a2a))
		"theater":
			_marquee(cx, w)
		"hotel":
			_blade_sign("HOTEL", Vector3(cx - w * .32, GY + 7.5, FACE - .9), SIGN_RED)
			_neon_text("NORTH STAR", Vector3(cx, GY + 3.05, FACE - .3), .55, SIGN_AMBER)
		"bar":
			_neon_text("BAR & GRILL", Vector3(cx - .6, GY + 3.0, FACE - .3), .6, SIGN_GREEN)
			_neon_text("COCKTAILS", Vector3(cx + 2.4, GY + 2.2, FACE - .2), .32, SIGN_RED)
			_awning(cx, w - .6, Mk.c(0x5a1414))
		"pawn":
			_neon_text("PAWN · LOANS", Vector3(cx, GY + 3.0, FACE - .3), .55, SIGN_AMBER)


## Intérieur de vitrine vu de loin : lumière chaude en dégradé, étagères, quelques silhouettes, reflets.
func _shop_tex(seed: int) -> Texture2D:
	var draw := func(ci: CanvasItem, w: float, h: float) -> void:
		var r := Tex.rng(seed)
		for y in int(h):
			var k := float(y) / h
			ci.draw_rect(Rect2(0, y, w, 1), Color(1, 1, 1).lerp(Color(.45, .32, .22), k * .9))
		for i in 4:
			var y := h * (.15 + i * .18)
			ci.draw_rect(Rect2(0, y, w, 3), Color(.25, .18, .12, .8))
			var x := 0.0
			while x < w:
				var bw := 4.0 + r.randf() * 9.0
				ci.draw_rect(Rect2(x, y - 6 - r.randf() * 10, bw - 1, 16), Color(r.randf(), r.randf() * .7, r.randf() * .5, .5))
				x += bw
		for i in 3:
			var px := r.randf() * w
			ci.draw_rect(Rect2(px, h * .45, 14, h * .55), Color(.08, .06, .05, .85))
			ci.draw_circle(Vector2(px + 7, h * .42), 8, Color(.08, .06, .05, .85))
		for i in 5:
			var x0 := r.randf() * w
			ci.draw_line(Vector2(x0, 0), Vector2(x0 + 40, h), Color(1, 1, 1, .08), 10.0)
	return Tex.canvas(256, 128, draw)


func _neon_text(txt: String, at: Vector3, h: float, col: Color) -> void:
	var tw := 128 + txt.length() * 74
	var tex := Tex.canvas(tw, 160, func(ci: CanvasItem, w: float, hh: float):
		ci.draw_rect(Rect2(0, 0, w, hh), Color(0, 0, 0, 0))
		Tex.silk(ci, txt, w / 2, hh * .72, 112, Color.WHITE, "center", 600), true)
	var m := _lit(col * 2.2, 1.0, .25)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.albedo_texture = tex
	_face(Mk.mi(Mk.quad(h * tw / 160.0, h), m, at, self))
	var l := OmniLight3D.new()
	l.light_color = col
	l.omni_range = 4.0 + h * 3.0
	l.position = at + Vector3(0, -.2, -.8)
	add_child(l)
	_light(l, .9 * h + .3, 0.0)


func _blade_sign(txt: String, at: Vector3, col: Color) -> void:
	var g := Node3D.new()
	g.position = at
	add_child(g)
	var box := Mk.mat(Mk.c(0x1a1614), .5, .4)
	Mk.mi(Mk.box(Vector3(.25, 4.6, 1.2)), box, Vector3.ZERO, g)
	for sx in [-1, 1]:
		var tex := Tex.canvas(160, 640, func(ci: CanvasItem, w: float, h: float):
			ci.draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0))
			for i in txt.length():
				Tex.silk(ci, txt[i], w / 2, 110 + i * 118, 112, Color.WHITE, "center", 700), true)
		var m := _lit(col * 2.4, 1.0, .2)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.albedo_texture = tex
		var q := Mk.mi(Mk.quad(1.0, 4.0), m, Vector3(sx * .13, 0, 0), g)
		q.rotation.y = sx * PI / 2
	var l := OmniLight3D.new()
	l.light_color = col
	l.omni_range = 7.0
	l.position = Vector3(0, -1.0, -1.2)
	g.add_child(l)
	_light(l, 1.6, 0.0)


## Marquise de cinéma : caisson saillant, bandeau de lettres noires sur fond lumineux, ampoules en chenillard.
func _marquee(cx: float, w: float) -> void:
	var g := Node3D.new()
	g.position = Vector3(cx, GY + 3.3, FACE - 1.3)
	add_child(g)
	var body := Mk.mat(Mk.c(0x8a2a1a), .5, .3)
	Mk.mi(Mk.box(Vector3(w - .8, 1.3, 2.4)), body, Vector3.ZERO, g)
	var board := Tex.canvas(1024, 256, func(ci: CanvasItem, tw: float, th: float):
		ci.draw_rect(Rect2(0, 0, tw, th), Color(1, .96, .85))
		Tex.silk(ci, "TONIGHT", tw / 2, 70, 44, Color(.1, .05, .05), "center", 800)
		Tex.silk(ci, "THE MIDNIGHT REVUE", tw / 2, 150, 66, Color(.1, .05, .05), "center", 800)
		Tex.silk(ci, "8 PM · 10 PM", tw / 2, 222, 44, Color(.6, .05, .05), "center", 700))
	var bm := _lit(Color(1, 1, 1), 1.0, .85)
	bm.albedo_texture = board
	_face(Mk.mi(Mk.quad(w - 1.4, .95), bm, Vector3(0, 0, -1.21), g))
	var title := Tex.canvas(512, 128, func(ci: CanvasItem, tw: float, th: float):
		ci.draw_rect(Rect2(0, 0, tw, th), Color(0, 0, 0, 0))
		Tex.silk(ci, "STARLITE", tw / 2, th * .78, 104, Color.WHITE, "center", 800), true)
	var tm := _lit(SIGN_AMBER * 2.4, 1.0, .3)
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	tm.albedo_texture = title
	_face(Mk.mi(Mk.quad(3.6, .9), tm, Vector3(0, 1.15, -1.0), g))
	# ampoules sur le pourtour
	var n := int((w - .8) / .22)
	for i in n:
		for yy in [-.62, .62]:
			var bmat := _lit(Color(1.6, 1.15, .6), 1.0, .3)
			Mk.mi(Mk.sphere(.035, 8, 6), bmat, Vector3(-(w - .8) / 2 + .11 + i * .22, yy, -1.22), g)
			_bulbs.append(bmat)
	var l := OmniLight3D.new()
	l.light_color = Color(1, .75, .45)
	l.omni_range = 9.0
	l.position = Vector3(0, -1.0, -2.0)
	g.add_child(l)
	_light(l, 2.2, 0.0)


func _awning(cx: float, w: float, col: Color) -> void:
	var a := Mk.mi(Mk.box(Vector3(w, .04, 1.4)), Mk.mat(col, .9), Vector3(cx, GY + 3.1, FACE - .75), self)
	a.rotation.x = -.35
	Mk.mi(Mk.box(Vector3(w, .3, .02)), Mk.mat(col * .9, .9), Vector3(cx, GY + 2.72, FACE - 1.42), self)


func _water_tower(at: Vector3) -> void:
	var wood := Mk.mat(Mk.c(0x5a4232), .95)
	var steel := Mk.mat(Mk.c(0x2a2826), .7, .5)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			Mk.mi(Mk.cyl(.08, .08, 3.0, 8), steel, at + Vector3(sx * 1.2, 1.5, sz * 1.2), self)
	Mk.mi(Mk.cyl(1.7, 1.75, 3.6, 24), wood, at + Vector3(0, 4.8, 0), self)
	Mk.mi(Mk.cyl(.05, 1.85, 1.2, 24), Mk.mat(Mk.c(0x2a2420), .8), at + Vector3(0, 7.2, 0), self)
	for k in 4:
		Mk.mi(Mk.cyl(1.76, 1.76, .06, 24), steel, at + Vector3(0, 3.4 + k * .9, 0), self)


func _fire_escape(x: float, levels: int, w: float) -> void:
	var iron := Mk.mat(Mk.c(0x0e0e0e), .6, .5)
	for k in levels:
		var y := GY + 4.0 + 1.2 + k * 3.1
		Mk.mi(Mk.box(Vector3(w, .05, 1.0)), iron, Vector3(x, y, FACE - .55), self)
		Mk.mi(Mk.box(Vector3(w, .04, .04)), iron, Vector3(x, y + .9, FACE - 1.05), self)
		for i in 9:
			Mk.mi(Mk.box(Vector3(.02, .9, .02)), iron, Vector3(x - w / 2 + i * w / 8, y + .45, FACE - 1.05), self)
		if k < levels - 1:
			# escalier en diagonale jusqu'au palier du dessus
			var sgn := 1.0 if k % 2 == 0 else -1.0
			var stair := Mk.mi(Mk.box(Vector3(3.4, .05, .5)), iron, Vector3(x, y + 1.55, FACE - .75), self)
			stair.rotation.z = sgn * .72


func _skyline() -> void:
	var r := Tex.rng(77)
	for i in 9:
		var hgt := 35.0 + r.randf() * 60.0
		var wid := 10.0 + r.randf() * 14.0
		var x := -40.0 + i * 11.0 + r.randf() * 4.0
		var seed := i * 31
		var draw := func(ci: CanvasItem, w: float, h: float) -> void:
			ci.draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0))
			var rr := Tex.rng(seed)
			for fy in 40:
				for fx in 12:
					if rr.randf() < .25:
						ci.draw_rect(Rect2(4 + fx * 10, 4 + fy * 6.3, 6, 3.5), Color(1, .8, .5) * (.5 + rr.randf() * .5))
		var tex := Tex.canvas(128, 256, draw, true)
		Mk.mi(Mk.box(Vector3(wid, hgt, 6)), Mk.mat(Mk.c(0x3a3c42), .9), Vector3(x, GY + hgt / 2, 60 + r.randf() * 30), self)
		var lm := _lit(Color(1, 1, 1), .9, 0.0)
		lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		lm.albedo_texture = tex
		_face(Mk.mi(Mk.quad(wid, hgt), lm, Vector3(x, GY + hgt / 2, 56.9), self))
	_sky_mat = Mk.mat(Mk.c(0x0a0f1e), 1.0, 0.0, {"unshaded": true, "fog_off": true})
	_face(Mk.mi(Mk.quad(260, 120), _sky_mat, Vector3(2, 50, 120), self))


# ---------------------------------------------------------------- côté studio
func _near_side() -> void:
	for p in [Vector3(-3.4, GY + .15, 2.4), Vector3(6.2, GY + .15, 2.4)]:
		_street_lamp(p, false)
	_street_lamp(Vector3(1.8, GY + .15, 11.9), true)
	var red := Mk.mat(Mk.c(0x9a1a12), .5, .3)
	# bouche d'incendie
	var hy := Vector3(4.6, GY + .15, 2.2)
	Mk.mi(Mk.cyl(.13, .15, .55, 16), red, hy + Vector3(0, .28, 0), self)
	Mk.mi(Mk.sphere(.14, 16, 8), red, hy + Vector3(0, .58, 0), self)
	for sx in [-1, 1]:
		var noz := Mk.mi(Mk.cyl(.06, .06, .16, 12), red, hy + Vector3(sx * .15, .4, 0), self)
		noz.rotation.z = PI / 2
	# boîte à journaux + poubelle grillagée
	var blue := Mk.mat(Mk.c(0x1a3a6a), .5, .3)
	Mk.mi(Mk.rounded_box(Vector3(.45, 1.0, .4), .03, blue, 2), null, Vector3(-.8, GY + .65, 2.2), self)
	var wire := Mk.mat(Mk.c(0x3a3c38), .6, .6)
	Mk.mi(Mk.cyl(.3, .26, .8, 16, false), wire, Vector3(-1.6, GY + .55, 2.4), self)


func _street_lamp(at: Vector3, far: bool) -> void:
	var g := Node3D.new()
	g.position = at
	if far:
		g.rotation.y = PI
	add_child(g)
	var pole := Mk.mat(Mk.c(0x2a3a30), .55, .5)
	Mk.mi(Mk.cyl(.07, .12, 6.0, 12), pole, Vector3(0, 3.0, 0), g)
	Mk.mi(Mk.tube([Vector3(0, 5.9, 0), Vector3(0, 6.3, .5), Vector3(0, 6.25, 1.5)], .055, 12, 8), pole, Vector3.ZERO, g)
	Mk.mi(Mk.rounded_box(Vector3(.36, .14, .65), .05, pole, 2), null, Vector3(0, 6.2, 1.6), g)
	var bulb := _lit(Color(2.4, 1.05, .25), 1.0, .05)
	Mk.mi(Mk.box(Vector3(.28, .03, .5)), bulb, Vector3(0, 6.12, 1.6), g)
	var l := SpotLight3D.new()
	l.light_color = Color(1.0, .55, .18)
	l.spot_range = 10.0
	l.spot_angle = 62.0
	l.spot_angle_attenuation = .8
	l.position = Vector3(0, 6.0, 1.6)
	l.rotation.x = -PI / 2
	g.add_child(l)
	_light(l, 2.0, 0.0)


# ---------------------------------------------------------------- véhicules
func _vehicles() -> void:
	_car(Vector3(-1.6, GY, 3.5), 0.0, Mk.c(0x2e3a28))
	_car(Vector3(3.6, GY, 3.5), 0.0, Mk.c(0xe0b020), false, true)
	_car(Vector3(9.0, GY, 3.5), 0.0, Mk.c(0x6a4a2a))
	_car(Vector3(0.0, GY, 10.7), PI, Mk.c(0xc8b890))
	_car(Vector3(6.4, GY, 10.7), PI, Mk.c(0x5a1a14))
	car = _car(Vector3(-24, GY, 6.0), 0.0, Mk.c(0xe8b818), true, true)


## Berline 70s (avant vers +X) ; `taxi` = jaune avec lanterne de toit et damier.
func _car(at: Vector3, rot: float, col: Color, moving := false, taxi := false) -> Node3D:
	var g := Node3D.new()
	g.position = at
	g.rotation.y = rot
	add_child(g)
	var paint := Mk.mat(col, .3, .2, {"clearcoat": 1.0, "clearcoat_rough": .1})
	var glass := Mk.mat(Mk.c(0x0a0c10), .05, 0.0, {"clearcoat": 1.0})
	var chrome := Mk.chrome_mat()
	var tyre := Mk.mat(Mk.c(0x0c0c0c), .8)
	Mk.mi(Mk.rounded_box(Vector3(5.0, .52, 1.95), .1, paint, 3), null, Vector3(0, .56, 0), g)
	Mk.mi(Mk.rounded_box(Vector3(2.5, .5, 1.75), .12, paint, 3), null, Vector3(-.2, 1.05, 0), g)
	for sz in [-1, 1]:
		Mk.mi(Mk.box(Vector3(2.3, .36, .01)), glass, Vector3(-.2, 1.07, sz * .88), g)
	for sx in [-1, 1]:
		var ws := Mk.mi(Mk.box(Vector3(.01, .38, 1.6)), glass, Vector3(-.2 + sx * 1.26, 1.06, 0), g)
		ws.rotation.z = sx * -.5
		Mk.mi(Mk.rounded_box(Vector3(.12, .14, 2.0), .05, chrome, 2), null, Vector3(sx * 2.52, .42, 0), g)
	for wx in [-1.55, 1.55]:
		for sz in [-1, 1]:
			var w := Mk.mi(Mk.cyl(.34, .34, .24, 20), tyre, Vector3(wx, .34, sz * .86), g)
			w.rotation.x = PI / 2
			var hub := Mk.mi(Mk.cyl(.17, .17, .25, 16), chrome, Vector3(wx, .34, sz * .86), g)
			hub.rotation.x = PI / 2
	if taxi:
		var lamp := _lit(Color(1.4, 1.2, .7), 1.0, .3) if moving else Mk.mat(Mk.c(0xe8e0c8), .4)
		Mk.mi(Mk.rounded_box(Vector3(.5, .16, .22), .03, lamp, 2), null, Vector3(-.2, 1.38, 0), g)
		var check := Tex.canvas(256, 32, func(ci: CanvasItem, w2: float, h2: float):
			for i in 16:
				for j in 2:
					ci.draw_rect(Rect2(i * 16, j * 16, 16, 16), Color.BLACK if (i + j) % 2 == 0 else Color.WHITE))
		for sz in [-1, 1]:
			var band := Mk.mi(Mk.quad(4.4, .08), Mk.mat(Color.WHITE, .5, 0.0, {"map": check}), Vector3(0, .72, sz * .985), g)
			band.rotation.y = 0.0 if sz > 0 else PI
	var head := StandardMaterial3D.new()
	head.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	head.albedo_color = Color(3.0, 2.6, 1.8) if moving else Color(.5, .45, .35)
	var tail := StandardMaterial3D.new()
	tail.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tail.albedo_color = Color(3.0, .2, .1) if moving else Color(.25, .02, .02)
	for sz in [-1, 1]:
		var hl := Mk.mi(Mk.cyl(.09, .09, .03, 16), head, Vector3(2.52, .64, sz * .66), g)
		hl.rotation.z = PI / 2
		Mk.mi(Mk.box(Vector3(.03, .12, .3)), tail, Vector3(-2.52, .64, sz * .64), g)
	if moving:
		var l := SpotLight3D.new()
		l.light_color = Color(1, .9, .7)
		l.spot_range = 16.0
		l.spot_angle = 30.0
		l.position = Vector3(2.6, .6, 0)
		l.rotation.y = -PI / 2
		g.add_child(l)
		_light(l, 2.5, .4)
	return g


# ---------------------------------------------------------------- effets
func _steam(at: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = 36
	p.lifetime = 4.0
	p.preprocess = 4.0
	p.position = at
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = .5
	pm.initial_velocity_max = .9
	pm.gravity = Vector3(.12, .05, 0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = .25
	pm.scale_min = .8
	pm.scale_max = 1.3
	var curve := Curve.new()
	curve.add_point(Vector2(0, .3))
	curve.add_point(Vector2(1, 1.0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, .35))
	grad.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 1.6)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = _puff_tex()
	m.albedo_color = Color(.85, .82, .8)
	q.material = m
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 8, 6))
	add_child(p)


func _puff_tex() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(.5, .5)
	t.fill_to = Vector2(1, .5)
	t.width = 64
	t.height = 64
	return t


func _rain_fx() -> void:
	_rain = GPUParticles3D.new()
	_rain.amount = 1800
	_rain.lifetime = .9
	_rain.preprocess = 1.0
	_rain.position = Vector3(2, GY + 9, 7.4)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(16, .5, 6.2)
	pm.direction = Vector3(.05, -1, 0)
	pm.spread = 2.0
	pm.initial_velocity_min = 11.0
	pm.initial_velocity_max = 13.0
	pm.gravity = Vector3(0, -2, 0)
	pm.particle_flag_align_y = true
	_rain.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(.012, .45)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(.8, .85, .95, .28)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.billboard_keep_scale = true
	q.material = m
	_rain.draw_pass_1 = q
	_rain.visibility_aabb = AABB(Vector3(-18, -12, -8), Vector3(36, 14, 16))
	add_child(_rain)


# ---------------------------------------------------------------- jour / nuit
## night : 0 = plein jour, 1 = nuit noire. sky : couleur du ciel. rain : 0..1.
func set_time(night: float, sky: Color, rain: float) -> void:
	_night = night
	for e in _night_mats:
		var m: StandardMaterial3D = e[0]
		var c: Color = e[1]
		var k: float = lerpf(e[3], e[2], night)
		m.albedo_color = Color(c.r * k, c.g * k, c.b * k, m.albedo_color.a)
	for e in _night_lights:
		var l: Light3D = e[0]
		l.light_energy = lerpf(e[2], e[1], night)
		l.visible = l.light_energy > .02
	_sky_mat.albedo_color = sky
	# chaussée : brillante et mouillée sous la pluie, plus mate au sec
	_road_mat.roughness = lerpf(.6, .12, rain)
	_rain.emitting = rain > .05
	_rain.amount_ratio = clampf(rain, .05, 1.0)


func animate(t: float) -> void:
	# chenillard des ampoules de la marquise (seulement quand il fait sombre)
	if _bulbs.is_empty():
		return
	var step := int(t * 6.0)
	var k := lerpf(.3, 1.0, _night)
	for i in _bulbs.size():
		var on := (i + step) % 3 != 0
		var m: StandardMaterial3D = _bulbs[i]
		m.albedo_color = Color(1.6, 1.15, .6) * (k if on else k * .25)
