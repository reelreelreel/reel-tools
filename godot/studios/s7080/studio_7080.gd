class_name Studio7080
extends Node3D
## Studio 70/80, régie pro : long établi en bois usé, lambris + panneaux acoustiques en tissu, double vitre
## sur la cabine de prise (floue, lumière chaude), spots au plafond, lampe d'architecte, TV cathodique orange. Vue de trois-quarts face.

const DESK_W := 3.1
const DESK_D := 0.95
const WALL_Z := -0.72
const WIN := {"x": -.45, "y": .92, "w": 2.1, "h": .8}

## Emplacements réservés aux futures machines : [x, z, rotY, y, inclinaison X]
## (repris du prototype ; les machines seront redessinées et remises une par une)
const EMPLACEMENTS := {
	"tape": [-1.12, -.2, .28, .34 + .155, 1.2],
	"scope": [-.42, -.32, .12, .1 + .13, 1.05],
	"synth": [-.1, .2, .04, 0, .08],
	"modular": [-.78, .25, .3, 0, .3],
	"rack": [1.08, -.25, -.42, .16, 0],
	"tt": [.95, .2, -.25, 0, 0],
	"book": [.38, .3, -.3, 0, 0],
}
## Plans caméra disponibles (glisser / flèches). Pour l'instant : le plan large du décor.
var order: Array = ["overview"]

var engine: TempoEngine
var lamp_g: Node3D
var lamp: SpotLight3D
var tv: TexLib.LiveCanvas
var tv_t := 0.0
var env: Environment
var _last_screen := -1.0


func _init(e: TempoEngine) -> void:
	engine = e
	name = "Studio7080"
	_build_environment()
	_build_room()
	var cup := _build_cup()
	cup.position = Vector3(.64, 0, .36)
	add_child(cup)
	_build_lights()


func _ready() -> void:
	_aim(lamp, lamp_g.to_global(Vector3(0, .44, .36)), Vector3(-.45, 0, .2))


# ---------------------------------------------------------------- environnement & post-traitement
func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Mk.c(0x0a0604)
	# ciel invisible qui ne sert qu'aux reflets (comme une pièce avec quelques sources chaudes)
	var sky := Sky.new()
	var pano := PanoramaSkyMaterial.new()
	pano.panorama = ImageTexture.create_from_image(_reflection_room())
	pano.energy_multiplier = 0.12
	sky.sky_material = pano
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.2
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 0.6
	env.ssao_intensity = 1.6
	env.ssil_enabled = true
	env.ssil_radius = 1.5
	env.ssr_enabled = false
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.6)
	env.set_glow_level(4, 0.4)
	env.fog_enabled = true
	env.fog_light_color = Mk.c(0x120a05)
	env.fog_density = 0.05
	env.fog_sky_affect = 0.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Mk.c(0xffe2c4)
	env.volumetric_fog_length = 6.0
	env.volumetric_fog_ambient_inject = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.05
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _reflection_room() -> Image:
	var w := 512
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBF)
	# fond sombre chaud, sources douces : bandeau de spots, fenêtre chaude, lampe
	var blobs := [
		[Vector2(.25, .18), Vector2(.3, .09), Color(2.0, 1.35, .8)],
		[Vector2(.75, .18), Vector2(.3, .09), Color(2.0, 1.35, .8)],
		[Vector2(.5, .42), Vector2(.18, .08), Color(1.4, .8, .4)],
		[Vector2(.08, .3), Vector2(.05, .05), Color(2.2, 1.3, .6)],
		[Vector2(.62, .45), Vector2(.08, .06), Color(.4, .5, .7)],
	]
	for y in h:
		for x in w:
			var u := float(x) / w
			var v := float(y) / h
			var col := Color(.035, .022, .014) * (1.2 - v)
			for b in blobs:
				var d: Vector2 = (Vector2(u, v) - b[0]) / b[1]
				var k := exp(-d.length_squared() * 2.0)
				col += b[2] * k
			img.set_pixel(x, y, col)
	return img


# ---------------------------------------------------------------- la pièce
func _build_room() -> void:
	# établi : planches miel usées
	var wood: Texture2D = load("res://assets/textures/hardwood2_diffuse.jpg")
	var desk_mat := Mk.mat(Mk.c(0x95663f), .7, 0.0, {"map": wood, "clearcoat": .15, "clearcoat_rough": .6, "uv_scale": Vector3(2.2, .7, 1)})
	var dark_wood := Mk.mat(Mk.c(0x6a4a34), .7, 0.0, {"map": Mk.walnut_tex()})
	var desk := Mk.mi(Mk.rounded_box(Vector3(DESK_W, .06, DESK_D), .01, desk_mat, 3), null, Vector3(0, -.03, -.05), self)
	desk.name = "Desk"
	Mk.mi(Mk.box(Vector3(DESK_W - .1, .12, .03)), dark_wood, Vector3(0, -.12, DESK_D / 2 - .1), self)
	for sx in [-1, 1]:
		Mk.mi(Mk.box(Vector3(.07, .72, .07)), dark_wood, Vector3(sx * (DESK_W / 2 - .1), -.42, .3), self)
	Mk.mi(Mk.plane(ROOM_X * 2, 6), Mk.mat(Mk.c(0x1c130d), .95), Vector3(0, FLOOR_Y, 1.8), self)
	_build_wall(dark_wood)
	_build_window(dark_wood)
	_build_booth(dark_wood)
	_build_side_walls(dark_wood)
	_build_ceiling()
	_build_frames()
	_build_wall_washers()
	_build_tv()
	_build_lamp()
	_build_chair()


## Lambris jusqu'à cette hauteur (monde), panneaux acoustiques en tissu au-dessus.
const WOOD_TOP := 0.44
const ROOM_X := 3.0
const CEIL_Y := 2.4
## Cabine de prise derrière la vitre
const BOOTH := {"x0": -2.6, "x1": 1.4, "z0": -1.14, "z1": -3.4, "ceil": 1.9}
const FLOOR_Y := -0.78

var _weave_n: Texture2D
var _boards_tex: Texture2D


func _boards() -> Texture2D:
	if _boards_tex == null:
		_boards_tex = Tex.canvas(2048, 1024, func(ci, w, h):
			ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x2a1a10))
			var r := Tex.rng(81)
			for i in 40:
				var x0 := i * 51.2
				ci.draw_rect(Rect2(x0, 0, 49, h), Color((60 + r.randf() * 30) / 255.0, (36 + r.randf() * 18) / 255.0, (20 + r.randf() * 10) / 255.0, .55))
				ci.draw_rect(Rect2(x0 + 49, 0, 2.2, h), Color(0, 0, 0, .6))
				for k in 30:
					var gx := x0 + r.randf() * 49.0
					var pts := PackedVector2Array()
					var o1 := r.randf() * 6 - 3
					for s in 9:
						var tt := s / 8.0
						pts.append(Vector2(gx + sin(tt * PI) * o1, tt * h))
					ci.draw_polyline(pts, Color(0, 0, 0, r.randf() * .25), 1.0 + r.randf() * 2.0)
			Tex.grime(ci, w, h, 82, 2))
	return _boards_tex


## Mur plat fait de rectangles (repère local du mur, face +Z), UV en mètres / échelle.
func _wall_mesh(rects: Array, uv_w := 6.0, uv_h := 3.4) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var i0 := 0
	for rc in rects:
		var corners := [Vector2(rc[0], rc[1]), Vector2(rc[2], rc[1]), Vector2(rc[2], rc[3]), Vector2(rc[0], rc[3])]
		for p in corners:
			st.set_normal(Vector3.BACK)
			st.set_uv(Vector2(p.x / uv_w + .5, .5 - p.y / uv_h))
			st.add_vertex(Vector3(p.x, p.y, 0))
		for ix in [0, 2, 1, 0, 3, 2]:
			st.add_index(i0 + ix)
		i0 += 4
	st.generate_tangents()
	return st.commit()


func _fabric_mat(base: Color, seed: int, w: float, h: float) -> StandardMaterial3D:
	if _weave_n == null:
		var img := Image.create(256, 256, false, Image.FORMAT_L8)
		var r := Tex.rng(5)
		for y in 256:
			for x in 256:
				var warp := ((x / 2) % 2 == 0) != ((y / 2) % 2 == 0)
				var v := (0.75 if warp else 0.35) + r.randf() * 0.15
				img.set_pixel(x, y, Color(v, v, v))
		_weave_n = Tex.normal_from_bump(img, 3.0)
	var tex := Tex.canvas(256, 256, func(ci, cw, ch):
		ci.draw_rect(Rect2(0, 0, cw, ch), base)
		var r := Tex.rng(seed)
		for i in 1800:
			var c := base.lightened(.12) if r.randf() > .5 else base.darkened(.25)
			c.a = .35
			ci.draw_rect(Rect2(r.randf() * cw, r.randf() * ch, 1.5, 1.5), c)
		for i in 5:
			var x: float = r.randf() * cw
			ci.draw_rect(Rect2(x, 0, 6 + r.randf() * 14, ch), Color(0, 0, 0, .05))
		Tex.grime(ci, cw, ch, seed + 1, .3))
	var m := Mk.mat(Color.WHITE, .95, 0.0, {"map": tex, "normal": _weave_n, "normal_scale": .5})
	m.uv1_scale = Vector3(maxf(1.0, w * 3.0), maxf(1.0, h * 3.0), 1)
	m.rim_enabled = true
	m.rim = .25
	m.rim_tint = .6
	return m


## Panneau acoustique : cadre bois + coussin de tissu bombé. Face +Z, centré.
func _acoustic_panel(w: float, h: float, fabric: Color, seed: int, frame_mat: Material) -> Node3D:
	var g := Node3D.new()
	Mk.mi(Mk.rounded_box(Vector3(w, h, .05), .004, frame_mat, 2), null, Vector3(0, 0, .025), g)
	Mk.mi(Mk.rounded_box(Vector3(w - .035, h - .035, .075), .02, _fabric_mat(fabric, seed, w, h), 3), null, Vector3(0, 0, .035), g)
	return g


const FABRICS := [0x7a4528, 0x5a3420, 0x8a4a24, 0x6b3f22]


func _build_wall(dark_wood: Material) -> void:
	var z := WALL_Z - .02
	var boards := Mk.mat(Color.WHITE, .8, 0.0, {"map": _boards()})
	var backing := Mk.mat(Mk.c(0x140c07), .95)
	# lambris en bas, sur toute la largeur (local du mur : y = monde - .7)
	var wood := Mk.mi(_wall_mesh([[-ROOM_X, FLOOR_Y - .7, ROOM_X, WOOD_TOP - .7]]), boards, Vector3(0, .7, z), self)
	wood.name = "WallWood"
	# fond sombre au-dessus, avec l'ouverture de la vitre
	var hx0: float = WIN.x - WIN.w / 2
	var hx1: float = WIN.x + WIN.w / 2
	var hy0: float = WIN.y - .7 - WIN.h / 2
	var hy1: float = WIN.y - .7 + WIN.h / 2
	var y0 := WOOD_TOP - .7
	var y1 := CEIL_Y - .7
	Mk.mi(_wall_mesh([[-ROOM_X, y0, hx0, y1], [hx1, y0, ROOM_X, y1], [hx0, y0, hx1, hy0], [hx0, hy1, hx1, y1]]), backing, Vector3(0, .7, z), self)
	# lisse en bois entre lambris et tissu
	Mk.mi(Mk.rounded_box(Vector3(ROOM_X * 2, .045, .05), .006, dark_wood, 2), null, Vector3(0, WOOD_TOP, z + .025), self)
	# panneaux acoustiques de part et d'autre de la vitre
	var cols_l := [-2.66, -1.96]
	var cols_r := [1.07, 1.83, 2.59]
	var rows := [.72, 1.15]
	var n := 0
	for cx in cols_l + cols_r:
		var w := .66 if cols_l.has(cx) else .72
		for cy in rows:
			var p := _acoustic_panel(w, .4, Mk.c(FABRICS[n % FABRICS.size()]), 300 + n, dark_wood)
			p.position = Vector3(cx, cy, z)
			add_child(p)
			n += 1


func _build_window(dark_wood: Material) -> void:
	var depth := BOOTH.z0 - WALL_Z  # négatif : épaisseur du mur double
	var d := absf(depth)
	var zc := WALL_Z - d / 2.0
	# tableau (épaisseur du mur double) en bois
	for b in [[WIN.x, WIN.y + WIN.h / 2 + .04, WIN.w + .16, .08], [WIN.x, WIN.y - WIN.h / 2 - .04, WIN.w + .16, .08]]:
		Mk.mi(Mk.box(Vector3(b[2], b[3], d)), dark_wood, Vector3(b[0], b[1], zc), self)
	for x in [WIN.x - WIN.w / 2 - .04, WIN.x + WIN.w / 2 + .04]:
		Mk.mi(Mk.box(Vector3(.08, WIN.h + .16, d)), dark_wood, Vector3(x, WIN.y, zc), self)
	# appui de fenêtre qui dépasse côté régie
	Mk.mi(Mk.rounded_box(Vector3(WIN.w + .3, .035, .16), .008, dark_wood, 2), null, Vector3(WIN.x, WIN.y - WIN.h / 2 - .08, WALL_Z + .06), self)
	# double vitrage : vitre côté régie inclinée (anti-reflets), vitre côté cabine droite
	var glass := Mk.mat(Mk.c(0x0c0c0c), .04, 0.0, {"alpha": .14, "clearcoat": 1.0})
	var g1 := Mk.mi(Mk.quad(WIN.w, WIN.h), glass, Vector3(WIN.x, WIN.y, WALL_Z - .06), self)
	g1.rotation.x = -.09
	Mk.mi(Mk.quad(WIN.w, WIN.h), glass, Vector3(WIN.x, WIN.y, BOOTH.z0 + .04), self)


# ---------------------------------------------------------------- cabine de prise (vue floue à travers la vitre)
func _build_booth(dark_wood: Material) -> void:
	var b := Node3D.new()
	b.name = "Booth"
	add_child(b)
	var x0: float = BOOTH.x0
	var x1: float = BOOTH.x1
	var z0: float = BOOTH.z0
	var z1: float = BOOTH.z1
	var cy: float = BOOTH.ceil
	var w := x1 - x0
	var dz := z0 - z1
	var cx := (x0 + x1) / 2.0
	# parquet + tapis
	var wood: Texture2D = load("res://assets/textures/hardwood2_diffuse.jpg")
	Mk.mi(Mk.plane(w, dz), Mk.mat(Mk.c(0x6a4a30), .7, 0.0, {"map": wood, "uv_scale": Vector3(2, 1, 1)}), Vector3(cx, FLOOR_Y, (z0 + z1) / 2), b)
	var rug := Tex.canvas(512, 384, func(ci, rw, rh):
		ci.draw_rect(Rect2(0, 0, rw, rh), Mk.c(0x5a1612))
		ci.draw_rect(Rect2(18, 18, rw - 36, rh - 36), Mk.c(0x2a0d0a))
		ci.draw_rect(Rect2(34, 34, rw - 68, rh - 68), Mk.c(0x6e1d15))
		var r := Tex.rng(12)
		for i in 60:
			var p := Vector2(60 + r.randf() * (rw - 120), 60 + r.randf() * (rh - 120))
			ci.draw_circle(p, 4 + r.randf() * 10, Color(.85, .6, .3, .25))
		Tex.grime(ci, rw, rh, 13, 2))
	Mk.mi(Mk.rounded_box(Vector3(1.8, .01, 1.3), .004, Mk.mat(Color.WHITE, .98, 0.0, {"map": rug})), null, Vector3(-.5, FLOOR_Y + .005, -2.25), b)
	# murs : lambris + tissu chaud
	var boards := Mk.mat(Color.WHITE, .8, 0.0, {"map": _boards()})
	var back := Mk.mi(_wall_mesh([[-w / 2, FLOOR_Y, w / 2, cy]], 6.0, 3.4), Mk.mat(Mk.c(0x1a0f08), .95), Vector3(cx, 0, z1), b)
	back.name = "BoothBack"
	Mk.mi(_wall_mesh([[-w / 2, FLOOR_Y, w / 2, WOOD_TOP - .1]]), boards, Vector3(cx, 0, z1 + .005), b)
	for side in [[x0, PI / 2], [x1, -PI / 2]]:
		var sw := Mk.mi(_wall_mesh([[-dz / 2, FLOOR_Y, dz / 2, cy]]), Mk.mat(Mk.c(0x1a0f08), .95), Vector3(side[0], 0, (z0 + z1) / 2), b)
		sw.rotation.y = side[1]
	Mk.mi(Mk.plane(w, dz), Mk.mat(Mk.c(0x0d0805), .95, 0.0, {"cull_off": true}), Vector3(cx, cy, (z0 + z1) / 2), b)
	var warm := [0x8a5a2a, 0x6b3a1f, 0x9a6a30]
	for i in 4:
		var p := _acoustic_panel(.7, .9, Mk.c(warm[i % 3]), 400 + i, dark_wood)
		p.position = Vector3(x0 + .55 + i * .95, .95, z1 + .01)
		b.add_child(p)
	# pied de micro + micro à large membrane + anti-pop
	var chrome := Mk.chrome_mat()
	var black := Mk.mat(Mk.c(0x111111), .4, .3)
	var mic := Node3D.new()
	mic.position = Vector3(-.45, FLOOR_Y, -2.05)
	b.add_child(mic)
	Mk.mi(Mk.cyl(.13, .14, .02, 32), black, Vector3(0, .01, 0), mic)
	Mk.mi(Mk.cyl(.011, .011, 1.42, 12), black, Vector3(0, .72, 0), mic)
	var boom := Mk.mi(Mk.cyl(.009, .009, .5, 12), black, Vector3(0, 1.4, .2), mic)
	boom.rotation.x = PI / 2 - .25
	Mk.mi(Mk.cyl(.032, .028, .17, 32), chrome, Vector3(0, 1.38, .44), mic)
	Mk.mi(Mk.sphere(.033, 24, 12, true), Mk.mat(Mk.c(0x8a8680), .5, 1.0), Vector3(0, 1.465, .44), mic)
	var pop := Mk.mi(Mk.torus_ring(.075, .005), black, Vector3(0, 1.42, .58), mic)
	pop.rotation.x = PI / 2
	var popf := Mk.mi(Mk.disc(.074, 32), Mk.mat(Mk.c(0x050505), .9, 0.0, {"alpha": .55, "cull_off": true}), Vector3(0, 1.42, .58), mic)
	popf.rotation.x = PI / 2
	# casque posé sur le pied
	var hp := Mk.mi(Mk.torus_arc(.085, .008, PI, 16, 6), black, Vector3(0, 1.0, .02), mic)
	hp.rotation.y = PI / 2
	# tabouret
	var stool := Node3D.new()
	stool.position = Vector3(.15, FLOOR_Y, -2.55)
	b.add_child(stool)
	Mk.mi(Mk.cyl(.18, .17, .05, 32), Mk.mat(Mk.c(0x2a1a12), .6), Vector3(0, .72, 0), stool)
	for i in 4:
		var a := i * PI / 2 + .4
		var leg := Mk.mi(Mk.cyl(.012, .016, .74, 8), dark_wood, Vector3(cos(a) * .12, .36, sin(a) * .12), stool)
		leg.rotation = Vector3(sin(a) * .12, 0, -cos(a) * .12)
	# ampli guitare
	var amp := Node3D.new()
	amp.position = Vector3(.85, FLOOR_Y, -3.0)
	amp.rotation.y = -.35
	b.add_child(amp)
	Mk.mi(Mk.rounded_box(Vector3(.55, .45, .26), .015, Mk.mat(Mk.c(0x161412), .7)), null, Vector3(0, .225, 0), amp)
	Mk.mi(Mk.quad(.48, .3), Mk.mat(Mk.c(0xb8a27a), .9), Vector3(0, .19, .131), amp)
	Mk.mi(Mk.quad(.48, .06), Mk.mat(Mk.c(0x9a968f), .4, .8), Vector3(0, .39, .131), amp)
	# lampadaire chaud : la vraie source de lumière de la cabine
	var lampe := Node3D.new()
	lampe.position = Vector3(-1.95, FLOOR_Y, -2.95)
	b.add_child(lampe)
	Mk.mi(Mk.cyl(.12, .13, .02, 24), black, Vector3(0, .01, 0), lampe)
	Mk.mi(Mk.cyl(.01, .01, 1.5, 8), Mk.mat(Mk.c(0x8a6a3a), .35, 1.0), Vector3(0, .76, 0), lampe)
	var shade := Mk.mi(Mk.cyl(.13, .2, .26, 32, false), Mk.mat(Mk.c(0xf2dcb0), .9, 0.0, {"emission": Mk.c(0xffb060), "energy": 2.5, "cull_off": true}), Vector3(0, 1.55, 0), lampe)
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bl := OmniLight3D.new()
	bl.light_color = Mk.c(0xffa050)
	bl.light_energy = 3.0
	bl.omni_range = 4.0
	bl.omni_attenuation = 1.2
	bl.shadow_enabled = true
	bl.position = Vector3(0, 1.5, 0)
	lampe.add_child(bl)
	# lumière d'ambiance de la cabine (douce, sans ombre)
	var fill := OmniLight3D.new()
	fill.light_color = Mk.c(0xff9a50)
	fill.light_energy = 1.4
	fill.omni_range = 3.5
	fill.position = Vector3(cx, cy - .3, (z0 + z1) / 2)
	b.add_child(fill)
	# petit spot au plafond de la cabine, sur le micro
	var sp := SpotLight3D.new()
	sp.light_color = Mk.c(0xffc080)
	sp.light_energy = 2.0
	sp.spot_range = 3.0
	sp.spot_angle = 28.0
	sp.spot_angle_attenuation = 1.5
	_aim(sp, Vector3(-.45, cy - .05, -2.0), Vector3(-.45, FLOOR_Y, -2.1))
	b.add_child(sp)


# ---------------------------------------------------------------- murs latéraux et plafond de la régie
func _build_side_walls(dark_wood: Material) -> void:
	var boards := Mk.mat(Color.WHITE, .8, 0.0, {"map": _boards()})
	var backing := Mk.mat(Mk.c(0x140c07), .95)
	var z0 := WALL_Z - .02
	var z1 := 4.5
	var wl := z1 - z0
	for s in [-1, 1]:
		var wall := Node3D.new()
		wall.position = Vector3(s * ROOM_X, 0, (z0 + z1) / 2)
		wall.rotation.y = -s * PI / 2
		add_child(wall)
		Mk.mi(_wall_mesh([[-wl / 2, FLOOR_Y, wl / 2, WOOD_TOP]]), boards, Vector3.ZERO, wall)
		Mk.mi(_wall_mesh([[-wl / 2, WOOD_TOP, wl / 2, CEIL_Y]]), backing, Vector3.ZERO, wall)
		Mk.mi(Mk.rounded_box(Vector3(wl, .045, .05), .006, dark_wood, 2), null, Vector3(0, WOOD_TOP, .025), wall)
		for i in 5:
			# u le long du mur : depuis le fond (côté mur du fond) vers l'avant
			var u := -wl / 2 + .5 + i * .8
			var lx := u if s > 0 else -u
			for cy in [.8, 1.5]:
				var p := _acoustic_panel(.72, .62, Mk.c(FABRICS[(i + int(cy * 2)) % FABRICS.size()]), 500 + i * 3 + int(cy * 10), dark_wood)
				p.position = Vector3(lx, cy, 0)
				wall.add_child(p)
	Mk.mi(Mk.plane(ROOM_X * 2, z1 - z0), Mk.mat(Mk.c(0x0e0906), .95, 0.0, {"cull_off": true}), Vector3(0, CEIL_Y, (z0 + z1) / 2), self)


# ---------------------------------------------------------------- disques d'or encadrés
## Spots rasants sur les panneaux du mur du fond (éclairage d'ambiance de la régie).
func _build_wall_washers() -> void:
	for x in [-2.3, 1.45, 2.25]:
		var sp := SpotLight3D.new()
		sp.light_color = Mk.c(0xffa860)
		sp.light_energy = 1.6
		sp.spot_range = 2.2
		sp.spot_angle = 35.0
		sp.spot_angle_attenuation = 1.3
		sp.light_volumetric_fog_energy = 0.4
		_aim(sp, Vector3(x, 1.36, WALL_Z + .45), Vector3(x, .55, WALL_Z))
		add_child(sp)


func _build_frames() -> void:
	var discs := [[1.45, .935, Mk.c(0xd4a838)], [2.21, .935, Mk.c(0xc8c8cc)]]
	for d in discs:
		var g := Node3D.new()
		g.position = Vector3(d[0], d[1], WALL_Z + .1)
		add_child(g)
		Mk.mi(Mk.rounded_box(Vector3(.36, .44, .03), .004, Mk.mat(Mk.c(0x0b0908), .35, 0.0, {"clearcoat": .6})), null, Vector3.ZERO, g)
		Mk.mi(Mk.quad(.32, .4), Mk.mat(Mk.c(0x1a1512), .9), Vector3(0, 0, .0155), g)
		var disc := Mk.mi(Mk.cyl(.12, .12, .003, 64), Mk.mat(d[2], .22, 1.0), Vector3(0, .04, .018), g)
		disc.rotation.x = PI / 2
		var lab := Mk.mi(Mk.cyl(.04, .04, .0034, 32), Mk.mat(Mk.c(0xb3241a), .6), Vector3(0, .04, .0182), g)
		lab.rotation.x = PI / 2
		Mk.mi(Mk.quad(.14, .035), Mk.mat(Mk.c(0xc9b27a), .35, .9), Vector3(0, -.15, .017), g)
		Mk.mi(Mk.quad(.32, .4), Mk.mat(Color.WHITE, .03, 0.0, {"alpha": .1, "clearcoat": 1.0}), Vector3(0, 0, .03), g)


func _build_ceiling() -> void:
	Mk.mi(Mk.box(Vector3(4.2, .12, .5)), Mk.mat(Mk.c(0x1b120b), .8), Vector3(.1, 1.4, -.48), self)
	var bulb_mesh := Mk.disc(.025, 24)
	var bulb_mat := Mk.glow(Mk.c(0xffc68a), 6.0)
	for x in [-1.35, -.65, .05, .75, 1.45]:
		var b := Mk.mi(bulb_mesh, bulb_mat, Vector3(x, 1.338, -.3), self)
		b.rotation.x = PI
		var sp := SpotLight3D.new()
		sp.light_color = Mk.c(0xffb36b)
		sp.light_energy = 2.2
		sp.spot_range = 3.2
		sp.spot_angle = rad_to_deg(.55)
		sp.spot_angle_attenuation = 1.6
		sp.spot_attenuation = 1.2
		sp.shadow_enabled = absf(x) < 1.0
		sp.light_volumetric_fog_energy = 1.0
		_aim(sp, Vector3(x, 1.32, -.3), Vector3(x * .9, 0, .05))
		add_child(sp)


func _build_tv() -> void:
	var g := Node3D.new()
	g.name = "TV"
	Mk.mi(Mk.rounded_box(Vector3(.52, .42, .44), .03, Mk.mat(Mk.c(0xc8742a), .45, 0.0, {"clearcoat": .5, "clearcoat_rough": .3}), 5), null, Vector3(0, .21, 0), g)
	Mk.mi(Mk.rounded_box(Vector3(.4, .32, .02), .01, Mk.mat(Mk.c(0x9a9690), .4, .6), 4), null, Vector3(-.04, .21, .215), g)
	tv = Tex.live(512, 400, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x06121a))
		var t := tv_t
		var y := 0
		while y < 400:
			var a := .25 + .2 * sin(y * .07 + t * 3) + (.5 if absf(fmod(y + t * 60.0, 400.0) - 200.0) < 18.0 else 0.0)
			ci.draw_rect(Rect2(30 + sin(y * .3 + t) * 4, y, 450, 1.6), Color(.59, .86, 1, a * .55))
			y += 3)
	Mk.mi(Mk.quad(.35, .27), Mk.glow(Color.WHITE, 1.8, tv.texture), Vector3(-.04, .21, .2265), g)
	for i in 3:
		var holder := Node3D.new()
		holder.rotation.x = PI / 2
		holder.position = Vector3(.205, .32 - i * .06, .22)
		holder.add_child(Mk.knob(.012, .012))
		g.add_child(holder)
	g.position = Vector3(.22, 0, -.35)
	g.rotation.y = -.12
	add_child(g)
	var glow_tv := OmniLight3D.new()
	glow_tv.light_color = Mk.c(0x9fd8ff)
	glow_tv.light_energy = .5
	glow_tv.omni_range = 1.2
	glow_tv.position = Vector3(.2, .25, -.05)
	add_child(glow_tv)
	var kbd := Mk.mi(Mk.rounded_box(Vector3(.42, .018, .14), .004, Mk.mat(Mk.c(0xd8d2c4), .5), 2), null, Vector3(.42, .009, .05), self)
	kbd.rotation.y = -.1


func _build_lamp() -> void:
	lamp_g = Node3D.new()
	lamp_g.name = "Lamp"
	var lm := Mk.mat(Mk.c(0x1a1a1a), .4, 0.0, {"clearcoat": .4})
	Mk.mi(Mk.cyl(.07, .08, .025, 40), lm, Vector3(0, .012, 0), lamp_g)
	var a1 := Mk.mi(Mk.cyl(.007, .007, .5, 12), Mk.chrome_mat(), Vector3(0, .26, 0), lamp_g)
	a1.rotation.x = .12
	var a2 := Mk.mi(Mk.cyl(.007, .007, .36, 12), Mk.chrome_mat(), Vector3(0, .5, .16), lamp_g)
	a2.rotation.x = 1.25
	var shade := Mk.mi(Mk.cyl(0.0, .07, .12, 40, false), Mk.mat(Mk.c(0x151515), .35, 0.0, {"cull_off": true}), Vector3(0, .48, .34), lamp_g)
	shade.rotation.x = -.5
	Mk.mi(Mk.sphere(.025, 20, 12), Mk.glow(Mk.c(0xffc27a), 2.2), Vector3(0, .45, .35), lamp_g)
	lamp_g.position = Vector3(-.72, 0, -.42)
	lamp_g.rotation.y = .25
	add_child(lamp_g)


func _build_chair() -> void:
	var chair := Node3D.new()
	chair.name = "Chair"
	var seat_m := Mk.mat(Mk.c(0x1c1813), .88)
	Mk.mi(Mk.rounded_box(Vector3(.5, .08, .48), .03, seat_m, 4), null, Vector3(0, -.27, 0), chair)
	var back := Mk.mi(Mk.rounded_box(Vector3(.48, .55, .07), .03, seat_m, 4), null, Vector3(0, -.02, .27), chair)
	back.rotation.x = -.12
	var arm_mesh := Mk.torus_arc(.14, .012, PI, 24, 8)
	for s in [-1, 1]:
		var arm := Mk.mi(arm_mesh, Mk.chrome_mat(), Vector3(s * .26, -.2, .05), chair)
		arm.rotation.y = PI / 2
	Mk.mi(Mk.cyl(.025, .025, .4, 16), Mk.chrome_mat(), Vector3(0, -.5, 0), chair)
	var lm := Mk.mat(Mk.c(0x1a1a1a), .4, 0.0, {"clearcoat": .4})
	for i in 5:
		var a := i * 1.2566
		var leg := Mk.mi(Mk.box(Vector3(.04, .03, .32)), lm, Vector3(sin(a) * .16, -.72, cos(a) * .16), chair)
		leg.rotation.y = a
	chair.position = Vector3(1.72, 0, .82)
	chair.rotation.y = -.9
	add_child(chair)


func _build_cup() -> Node3D:
	var cup := Node3D.new()
	cup.name = "Cup"
	var prof := [[0, 0], [.034, 0], [.038, .005], [.04, .09], [.037, .09], [.035, .008], [0, .008]]
	Mk.mi(Mk.lathe(prof, 64), Mk.mat(Mk.c(0x1b1b1d), .25, 0.0, {"clearcoat": .9}), Vector3.ZERO, cup)
	var coffee := Mk.mi(Mk.disc(.035, 48), Mk.mat(Mk.c(0x1a0d05), .1, 0.0, {"clearcoat": 1.0}), Vector3(0, .075, 0), cup)
	coffee.name = "Coffee"
	return cup


# ---------------------------------------------------------------- lumières
func _build_lights() -> void:
	lamp = SpotLight3D.new()
	lamp.name = "LampLight"
	lamp.light_color = Mk.c(0xffa456)
	lamp.light_energy = 1.2
	lamp.spot_range = 3.0
	lamp.spot_angle = rad_to_deg(.9)
	lamp.spot_angle_attenuation = 1.4
	lamp.spot_attenuation = 1.0
	lamp.shadow_enabled = true
	lamp.shadow_blur = 1.5
	lamp.light_size = 0.04
	add_child(lamp)
	var warm := OmniLight3D.new()
	warm.light_color = Mk.c(0xffa060)
	warm.light_energy = .8
	warm.omni_range = 6.0
	warm.omni_attenuation = 1.6
	warm.position = Vector3(.2, 1.1, 1.4)
	add_child(warm)
	var cold := SpotLight3D.new()
	cold.light_color = Mk.c(0x8a9cc0)
	cold.light_energy = 1.2
	cold.spot_range = 4.0
	cold.spot_angle = rad_to_deg(.9)
	_aim(cold, Vector3(-.4, 1.1, -1.2), Vector3(0, 0, .3))
	add_child(cold)



## Oriente une lumière (le studio est à l'origine : repère local = monde).
func _aim(n: Node3D, from: Vector3, to: Vector3) -> void:
	n.transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), from)


# ---------------------------------------------------------------- plans caméra
## Renvoie [position, point visé] pour un plan.
func shot_pose(_shot: String, cam: Camera3D, aspect: float) -> Array:
	var tall := aspect < .85
	var look := Vector3(-.05, .55 if tall else .45, -.25)
	var dir := Vector3(-.15 if tall else -.3, .4 if tall else .3, 1).normalized()
	var d := _fit(cam, aspect, 1.4 if tall else 1.75, 1.0 if tall else .95) * 1.04
	return [look + dir * d, look]


func _fit(cam: Camera3D, aspect: float, half_w: float, half_h: float) -> float:
	var v := tan(deg_to_rad(cam.fov) / 2.0)
	return maxf(half_h / v, half_w / (v * aspect))


func _via(obj: Node3D, local: Vector3, n: Vector3, hw: float, hh: float, cam: Camera3D, aspect: float, m := 1.12) -> Array:
	var c := obj.to_global(local)
	var nn := (obj.global_basis * n).normalized()
	return [c + nn * _fit(cam, aspect, hw * m, hh * m), c]


# ---------------------------------------------------------------- animation
func animate(t: float, _dt: float, reduced: bool) -> void:
	if reduced:
		return
	if t - _last_screen > 1.0 / 30.0:
		_last_screen = t
		tv_t = t
		tv.redraw()
