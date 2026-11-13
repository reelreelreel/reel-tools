class_name Studio7080
extends Node3D
## Studio 70/80, régie pro — disposition et cadrage repris de la scène Blender de Maxime
## (fichier_3D_perspective.glb) : pièce de 3 x 5 m, 2 m sous plafond, bureau en L contre le mur
## à vitre (z = 0) et le mur de droite (x = 0), caméra fixe placée dans Blender. Le côté x = 3 est
## ouvert (la caméra est derrière, comme sur un plateau de tournage).
##
## Ambiance (photos de référence) : bois chaud, liège / tissu texturé, lumière tungstène, moquette.

const ROOM := Vector3(3.0, 2.0, 5.0)        # x 0..3, y 0..2, z -5..0
const WIN := {"x0": .545, "x1": 2.455, "y0": .909, "y1": 1.727}
const DESK_TOP := .818
const DESK_T := .091
const DESKS := [  # [x0, x1, z0, z1]
	[.591, 2.727, -1.0, 0.0],   # bureau principal contre la vitre
	[.009, .545, -1.8, 0.0],    # retour contre le mur de droite
]
const WAINSCOT := 1.05                       # hauteur du lambris sur le mur de droite
## Caméra de la scène Blender
const CAM_POS := Vector3(3.67889142036438, 1.4983093738555908, -3.7742085456848145)
const CAM_QUAT := Quaternion(-0.02288774773478508, 0.9423389434814453, 0.065894715487957, 0.32730957865715027)
const CAM_YFOV := 0.5342188949841372         # radians, image 16:9
const CAM_FOCUS := 3.4                       # distance de mise au point (le bureau)

## Cabine (repère d'origine, retourné derrière la vitre)
const BOOTH := {"x0": -2.6, "x1": 1.4, "z0": -1.14, "z1": -3.4, "ceil": 1.9}
const BOOTH_ORIGIN := Vector3(1.05, .78, -.74)
const B_FLOOR := -0.78
const B_WOOD_TOP := 0.44

## Plans caméra (glisser / flèches) : la vue fixe de Blender puis un plan par module.
var order: Array = ["overview", "tempo", "tuner", "analyse", "freq", "export", "chat"]
## Modules jouables : nom -> nœud (on_action, on_drag_start, on_drag, on_wheel, on_key, animate)
var modules := {}
var tempo: Tempo7080
var tuner: Tuner7080
var analyzer: Analyzer7080
var freq: Freq7080
var export: Export7080
var cat: Cat7080
var deco: Deco7080

var engine: TempoEngine
var env: Environment
var _weave_n: Texture2D
var _boards_tex: Texture2D
var _wood: Material


func _init(e: TempoEngine) -> void:
	engine = e
	name = "Studio7080"
	_build_environment()
	var wood_n := Mk.normal_from_texture("res://assets/textures/hardwood2_diffuse.jpg", 2.5)
	_wood = Mk.pbr("dark_wood", .9, {"tint": Mk.c(0xc8a090), "rough": .85, "clearcoat": .35, "clearcoat_rough": .35})
	_build_floor_ceiling()
	_build_window_wall()
	_build_right_wall()
	_build_back_wall()
	_build_window()
	_build_booth(Mk.mat(Mk.c(0x6a4a34), .7, 0.0, {"map": Mk.walnut_tex()}))
	_build_desks()
	_build_lights()
	deco = Deco7080.new()
	add_child(deco)
	# module Tempo : section accolée à la console (bout droit du bureau principal)
	tempo = Tempo7080.new(engine, Mk.mat(Mk.c(0x6a4028), .55, 0.0, {"map": Mk.walnut_tex(), "clearcoat": .3}))
	tempo.position = Vector3(1.7 + 1.6 / 2 + .025 + Tempo7080.W / 2, DESK_TOP, -.57)
	tempo.rotation.y = PI
	add_child(tempo)
	modules["tempo"] = tempo
	# module Accordeur 808 : petit boîtier posé sur le pont de la console, côté gauche de l'image
	tuner = Tuner7080.new(Mk.mat(Mk.c(0x6a4028), .55, 0.0, {"map": Mk.walnut_tex(), "clearcoat": .3}))
	tuner.position = Vector3(2.0, DESK_TOP + .245, -.25)
	tuner.basis = (Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, -.15)).scaled(Vector3.ONE * .85)
	add_child(tuner)
	modules["tuner"] = tuner
	# module Analyse : magnéto + écran vert posé sur le retour, face à la pièce
	analyzer = Analyzer7080.new(Mk.mat(Mk.c(0x6a4028), .55, 0.0, {"map": Mk.walnut_tex(), "clearcoat": .3}))
	analyzer.position = Vector3(.27, DESK_TOP, -.75)
	analyzer.rotation.y = PI / 2
	add_child(analyzer)
	modules["analyse"] = analyzer
	# module Fréquences : petit synthé sur un support fixé au mur en liège, au-dessus du retour
	var steel := Mk.mat(Mk.c(0x2a2a2a), .4, .7)
	for z in [-.6, -1.1]:
		var arm := Mk.mi(Mk.rounded_box(Vector3(.3, .025, .025), .004, steel, 2), null, Vector3(.15, 1.2, z), self)
		arm.rotation.z = .4
		Mk.mi(Mk.rounded_box(Vector3(.02, .16, .04), .004, steel, 2), null, Vector3(.01, 1.2, z), self)
	freq = Freq7080.new(Mk.mat(Mk.c(0x6a4028), .55, 0.0, {"map": Mk.walnut_tex(), "clearcoat": .3}))
	freq.position = Vector3(.16, 1.235, -.85)
	freq.basis = Basis(Vector3.UP, PI / 2) * Basis(Vector3.RIGHT, .4)
	add_child(freq)
	modules["freq"] = freq
	# module Export : tableau en liège accroché au mur de droite, après le synthé
	export = Export7080.new(Mk.mat(Mk.c(0x6a4028), .55, 0.0, {"map": Mk.walnut_tex(), "clearcoat": .3}))
	export.position = Vector3(.002, 1.5, -1.9)
	export.rotation.y = PI / 2
	add_child(export)
	modules["export"] = export
	# le compagnon : chat roux couché sur son coussin, sur le retour du bureau
	cat = Cat7080.new(engine)
	cat.position = Vector3(.27, DESK_TOP, -1.3)
	cat.rotation.y = 1.85
	add_child(cat)
	modules["chat"] = cat
	# petite applique douce au-dessus du tableau
	var lamp := SpotLight3D.new()
	lamp.light_color = Mk.c(0xffd2a8)
	lamp.light_energy = .7
	lamp.spot_range = 1.4
	lamp.spot_angle = 45.0
	lamp.spot_angle_attenuation = 1.6
	_aim(lamp, Vector3(.45, 1.95, -1.9), Vector3(0, 1.45, -1.9))
	add_child(lamp)


func _ready() -> void:
	pass



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
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Mk.c(0x403a34)
	env.ambient_light_energy = 0.25
	# éclairage indirect : la lumière rebondit sur les murs, le bois, le tapis (rendu Forward+)
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.05
	env.sdfgi_bounce_feedback = 0.6
	env.sdfgi_energy = 1.4
	env.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_100_PERCENT
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.25
	env.tonemap_white = 12.0
	env.ssao_enabled = true
	env.ssao_radius = 0.45
	env.ssao_intensity = 1.2
	env.ssao_detail = 0.8
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
	env.fog_light_color = Mk.c(0x100c09)
	env.fog_density = 0.05
	env.fog_sky_affect = 0.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Mk.c(0xffe2c4)
	env.volumetric_fog_length = 6.0
	env.volumetric_fog_ambient_inject = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.86
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


## Lambris : planches Poly Haven (wood_planks), teintées plus sombre et chaud.
func _wall_boards() -> StandardMaterial3D:
	return Mk.pbr("wood_planks", 1.4, {"tint": Mk.c(0xa87c60), "rough": .9, "local": false})


func _boards() -> Texture2D:
	if _boards_tex == null:
		_boards_tex = Tex.canvas(2048, 1024, func(ci, w, h):
			ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x3a2414))
			var r := Tex.rng(81)
			for i in 40:
				var x0 := i * 51.2
				ci.draw_rect(Rect2(x0, 0, 49, h), Color((125 + r.randf() * 40) / 255.0, (72 + r.randf() * 24) / 255.0, (40 + r.randf() * 16) / 255.0, .85))
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
	var m: StandardMaterial3D = Mk.pbr("hessian_230", .35, {"tint": base.lightened(.25)}).duplicate()
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



# ---------------------------------------------------------------- textures de la pièce
func _cork_mat() -> StandardMaterial3D:
	var tex := Tex.canvas(1024, 1024, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x8a5c34))
		var r := Tex.rng(77)
		for i in 9000:
			var c := Mk.c(0xb07a44) if r.randf() > .45 else Mk.c(0x5a3a1e)
			c.a = .25 + r.randf() * .5
			ci.draw_circle(Vector2(r.randf() * w, r.randf() * h), 1.5 + r.randf() * 5.0, c)
		Tex.grime(ci, w, h, 78, 2))
	var nt := NoiseTexture2D.new()
	nt.width = 512
	nt.height = 512
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = 6.0
	var fn := FastNoiseLite.new()
	fn.frequency = .08
	fn.fractal_octaves = 3
	nt.noise = fn
	var m := Mk.mat(Color.WHITE, .95, 0.0, {"map": tex, "normal": nt, "normal_scale": .8})
	return m


func _carpet_mat() -> StandardMaterial3D:
	var tex := Tex.canvas(1024, 1024, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x4a2a16))
		var r := Tex.rng(91)
		for i in 20000:
			var c := Mk.c(0x6e4020) if r.randf() > .5 else Mk.c(0x2e1a0e)
			c.a = .4
			ci.draw_rect(Rect2(r.randf() * w, r.randf() * h, 2, 2), c)
		Tex.grime(ci, w, h, 92, 3))
	var nt := NoiseTexture2D.new()
	nt.width = 512
	nt.height = 512
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = 4.0
	var fn := FastNoiseLite.new()
	fn.frequency = .25
	nt.noise = fn
	var m := Mk.mat(Color.WHITE, 1.0, 0.0, {"map": tex, "normal": nt, "normal_scale": .6})
	m.uv1_scale = Vector3(3, 3, 1)
	return m


# ---------------------------------------------------------------- pièce
func _build_floor_ceiling() -> void:
	# parquet
	var parquet := Mk.pbr("plank_flooring", 1.6, {"tint": Mk.c(0xc0a088), "clearcoat": .25, "clearcoat_rough": .45, "local": false})
	var fl := Mk.mi(Mk.plane(5.0, 6.5), parquet, Vector3(2.0, 0, -2.6), self)
	fl.name = "Floor"
	# grand tapis persan sous le bureau
	var rug := Mk.mi(Mk.rounded_box(Vector3(2.6, .012, 2.0), .005, [null, null, _persian_rug(), null, null, null], 2), null, Vector3(1.75, .006, -2.3), self)
	rug.rotation.y = .03
	var edge := Mk.mat(Mk.c(0x3a1410), 1.0)
	for i in [0, 1, 3, 4, 5]:
		rug.mesh.surface_set_material(i, edge)
	# plafond en dalles acoustiques dans une grille
	var ceil := Mk.mi(Mk.plane(5.0, 6.5), _ceiling_tiles(), Vector3(2.0, ROOM.y, -2.6), self)
	ceil.rotation.x = PI
	ceil.name = "Ceiling"
	# plinthe sombre au pied des murs
	Mk.mi(Mk.box(Vector3(.02, .1, ROOM.z)), Mk.mat(Mk.c(0x1a100a), .6), Vector3(.01, .05, -ROOM.z / 2), self)
	Mk.mi(Mk.box(Vector3(ROOM.x, .1, .02)), Mk.mat(Mk.c(0x1a100a), .6), Vector3(ROOM.x / 2, .05, -.01), self)


## Dalle de 60 cm : fond crème perforé + profilé de la grille. La texture = une dalle, répétée.
func _ceiling_tiles() -> StandardMaterial3D:
	var tex := Tex.canvas(512, 512, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xcfc4b0))
		var r := Tex.rng(33)
		for i in 2600:
			ci.draw_circle(Vector2(r.randf() * w, r.randf() * h), .8 + r.randf() * 1.6, Color(.25, .2, .15, .35 + r.randf() * .3))
		Tex.grime(ci, w, h, 34, 1.5)
		ci.draw_rect(Rect2(0, 0, w, 7), Mk.c(0x8a857c))
		ci.draw_rect(Rect2(0, 0, 7, h), Mk.c(0x8a857c))
		ci.draw_rect(Rect2(0, 7, w, 2), Color(0, 0, 0, .35))
		ci.draw_rect(Rect2(7, 0, 2, h), Color(0, 0, 0, .35)))
	var m := Mk.mat(Color.WHITE, .92, 0.0, {"map": tex})
	m.uv1_scale = Vector3(5.0 / .6, 6.5 / .6, 1)
	return m


## Tapis persan : fond rouge profond, bordures, médaillon central, motifs répétés.
func _persian_rug() -> StandardMaterial3D:
	var tex := Tex.canvas(1024, 780, func(ci, w, h):
		var red := Mk.c(0x7a1c16)
		var navy := Mk.c(0x1c2440)
		var cream := Mk.c(0xd8c49a)
		var gold := Mk.c(0xb07a30)
		ci.draw_rect(Rect2(0, 0, w, h), navy)
		ci.draw_rect(Rect2(14, 14, w - 28, h - 28), cream)
		ci.draw_rect(Rect2(22, 22, w - 44, h - 44), red.darkened(.2))
		# frise de bordure
		var r := Tex.rng(7)
		var x := 40.0
		while x < w - 40:
			for yy in [40.0, h - 40.0]:
				ci.draw_colored_polygon(PackedVector2Array([Vector2(x, yy - 12), Vector2(x + 12, yy), Vector2(x, yy + 12), Vector2(x - 12, yy)]), gold if int(x / 30) % 2 else cream)
			x += 30
		var y := 70.0
		while y < h - 40:
			for xx in [40.0, w - 40.0]:
				ci.draw_colored_polygon(PackedVector2Array([Vector2(xx, y - 12), Vector2(xx + 12, y), Vector2(xx, y + 12), Vector2(xx - 12, y)]), gold if int(y / 30) % 2 else cream)
			y += 30
		ci.draw_rect(Rect2(62, 62, w - 124, h - 124), navy)
		ci.draw_rect(Rect2(70, 70, w - 140, h - 140), red)
		# semis de petits motifs
		for i in 260:
			var p := Vector2(90 + r.randf() * (w - 180), 90 + r.randf() * (h - 180))
			var s := 4.0 + r.randf() * 7.0
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s, 0), p + Vector2(0, s), p + Vector2(-s, 0)]), [navy, cream, gold][r.randi() % 3].lerp(red, .35))
		# médaillon central
		var c := Vector2(w / 2.0, h / 2.0)
		for k in 5:
			var sx := 260.0 - k * 46
			var sy := 190.0 - k * 34
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -sy), c + Vector2(sx, 0), c + Vector2(0, sy), c + Vector2(-sx, 0)]), [navy, cream, red.lightened(.1), gold, navy][k])
		# coins
		for cc in [Vector2(70, 70), Vector2(w - 70, 70), Vector2(70, h - 70), Vector2(w - 70, h - 70)]:
			ci.draw_circle(cc, 70, navy)
			ci.draw_circle(cc, 50, gold.darkened(.2))
		ci.draw_rect(Rect2(62, 62, w - 124, h - 124), navy, false, 3.0)
		# usure
		for i in 30000:
			ci.draw_rect(Rect2(r.randf() * w, r.randf() * h, 1.5, 1.5), Color(0, 0, 0, .12) if r.randf() > .4 else Color(1, .9, .8, .06))
		Tex.grime(ci, w, h, 8, 3))
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = 3.0
	var fn := FastNoiseLite.new()
	fn.frequency = .4
	nt.noise = fn
	var m := Mk.mat(Color.WHITE, 1.0, 0.0, {"map": tex, "normal": nt, "normal_scale": .4})
	return m


## Mur à vitre (z = 0, face vers -Z) : lambris de bois vertical sur toute la hauteur.
func _build_window_wall() -> void:
	var boards := _wall_boards()
	var w := Node3D.new()
	w.name = "WindowWall"
	w.rotation.y = PI  # repère local : x = -x monde, normale +Z = -Z monde
	add_child(w)
	var X0 := -ROOM.x
	var hx0: float = -WIN.x1
	var hx1: float = -WIN.x0
	var rects := [[X0, 0, hx0, ROOM.y], [hx1, 0, 0, ROOM.y], [hx0, 0, hx1, WIN.y0], [hx0, WIN.y1, hx1, ROOM.y]]
	Mk.mi(_wall_mesh(rects, 3.0, 2.0), boards, Vector3.ZERO, w)


## Mur de droite (x = 0, face vers +X) : lambris en bas, liège / tissu texturé au-dessus.
func _build_right_wall() -> void:
	var w := Node3D.new()
	w.name = "RightWall"
	w.rotation.y = PI / 2  # local x = -z monde
	add_child(w)
	var boards := _wall_boards()
	Mk.mi(_wall_mesh([[0, 0, ROOM.z, WAINSCOT]], 3.0, 2.0), boards, Vector3.ZERO, w)
	var cork := _cork_mat()
	cork.uv1_scale = Vector3(2.5, 1, 1)
	Mk.mi(_wall_mesh([[0, WAINSCOT, ROOM.z, ROOM.y]], ROOM.z, ROOM.y - WAINSCOT), cork, Vector3.ZERO, w)
	# lisse en bois entre lambris et liège
	Mk.mi(Mk.rounded_box(Vector3(ROOM.z, .05, .035), .006, _wood, 2), null, Vector3(ROOM.z / 2, WAINSCOT, .017), w)
	# corniche en bois sous le plafond
	Mk.mi(Mk.rounded_box(Vector3(ROOM.z, .07, .05), .006, _wood, 2), null, Vector3(ROOM.z / 2, ROOM.y - .035, .025), w)


func _build_back_wall() -> void:
	var w := Node3D.new()
	w.name = "BackWall"
	w.position = Vector3(0, 0, -ROOM.z)
	add_child(w)
	Mk.mi(_wall_mesh([[0, 0, ROOM.x + 1.0, ROOM.y]], 3.0, 2.0), _wall_boards(), Vector3.ZERO, w)


## Vitre : tableau épais en bois, double vitrage (vitre côté régie inclinée), appui.
func _build_window() -> void:
	var d := .4
	var cx: float = (WIN.x0 + WIN.x1) / 2
	var cy: float = (WIN.y0 + WIN.y1) / 2
	var ww: float = WIN.x1 - WIN.x0
	var wh: float = WIN.y1 - WIN.y0
	var frame := Mk.mat(Mk.c(0x5a3a22), .6, 0.0, {"map": Mk.walnut_tex()})
	# tableau (épaisseur du mur double)
	Mk.mi(Mk.box(Vector3(ww, .02, d)), frame, Vector3(cx, WIN.y1 + .01, d / 2), self)
	Mk.mi(Mk.box(Vector3(ww, .02, d)), frame, Vector3(cx, WIN.y0 - .01, d / 2), self)
	for x in [WIN.x0 - .01, WIN.x1 + .01]:
		Mk.mi(Mk.box(Vector3(.02, wh, d)), frame, Vector3(x, cy, d / 2), self)
	# encadrement côté régie
	var t := .07
	Mk.mi(Mk.rounded_box(Vector3(ww + 2 * t, t, .04), .008, frame, 2), null, Vector3(cx, WIN.y1 + t / 2, -.02), self)
	Mk.mi(Mk.rounded_box(Vector3(ww + 2 * t, t, .04), .008, frame, 2), null, Vector3(cx, WIN.y0 - t / 2 + .02, -.02), self)
	for x in [WIN.x0 - t / 2, WIN.x1 + t / 2]:
		Mk.mi(Mk.rounded_box(Vector3(t, wh + 2 * t, .04), .008, frame, 2), null, Vector3(x, cy, -.02), self)
	var glass := Mk.mat(Mk.c(0x0c0c0c), .04, 0.0, {"alpha": .12, "clearcoat": 1.0, "cull_off": true})
	var g1 := Mk.mi(Mk.quad(ww, wh), glass, Vector3(cx, cy, .06), self)
	g1.rotation.x = .09
	Mk.mi(Mk.quad(ww, wh), glass, Vector3(cx, cy, d - .03), self)


## Bureau en L façon meuble de régie : plateau teck, rebord cuir (console), caissons à tiroirs,
## baie rack 19" intégrée, portes à boutons laiton, joues profilées.
func _build_desks() -> void:
	for dsk in DESKS:
		var x0: float = dsk[0]
		var x1: float = dsk[1]
		var z0: float = dsk[2]
		var z1: float = dsk[3]
		var top := Mk.mi(Mk.rounded_box(Vector3(x1 - x0, DESK_T, z1 - z0), .012, _wood, 3), null, Vector3((x0 + x1) / 2, DESK_TOP - DESK_T / 2, (z0 + z1) / 2), self)
		top.name = "Desk"
	var h := DESK_TOP - DESK_T
	# rebord rembourré en cuir noir (façon console) sur l'avant du bureau
	var arm_y := DESK_TOP - .03
	Mk.mi(Mk.rounded_box(Vector3(2.727 - .55, .075, .11), .035, _leather(2.18), 4), null, Vector3((2.727 + .55) / 2, arm_y, -1.03), self)
	var ret := Mk.mi(Mk.rounded_box(Vector3(.8, .075, .11), .035, _leather(.8), 4), null, Vector3(.57, arm_y, -1.4), self)
	ret.rotation.y = PI / 2
	# caissons sous le bureau principal (façades tournées vers -Z)
	_place(_cabinet(.52, h, .9, "drawers"), Vector3(.89, 0, -.97), PI)
	_place(_cabinet(.54, h, .9, "rack"), Vector3(2.42, 0, -.97), PI)
	# fond de l'espace pour les jambes
	Mk.mi(Mk.box(Vector3(1.0, h, .02)), _wood, Vector3(1.65, h / 2, -.05), self)
	# meuble sous le retour (façade tournée vers +X)
	_place(_cabinet(.74, h, .5, "doors"), Vector3(.53, 0, -1.39), PI / 2)
	# joues profilées façon console
	var side := PackedVector2Array([Vector2(0, 0), Vector2(.93, 0), Vector2(.93, .1), Vector2(1.0, h - .02), Vector2(1.0, h), Vector2(0, h)])
	var cheek := Mk.mi(Mk.prism(side, .04), _wood, Vector3(2.70, 0, 0), self)
	cheek.rotation.y = PI / 2
	var side2 := PackedVector2Array([Vector2(0, 0), Vector2(.5, 0), Vector2(.5, .1), Vector2(.56, h - .02), Vector2(.56, h), Vector2(0, h)])
	Mk.mi(Mk.prism(side2, .04), _wood, Vector3(0, 0, -1.82), self)


func _place(n: Node3D, pos: Vector3, rot_y: float) -> void:
	n.position = pos
	n.rotation.y = rot_y
	add_child(n)


## Caisson en bois, façade sur z = 0 (local, vers +Z), fond vers -Z. kind : drawers | rack | doors
func _cabinet(w: float, h: float, d: float, kind: String) -> Node3D:
	var g := Node3D.new()
	g.name = "Cabinet_" + kind
	var kick := .07
	var dark := Mk.mat(Mk.c(0x120c08), .7)
	Mk.mi(Mk.box(Vector3(w - .04, kick, d - .06)), dark, Vector3(0, kick / 2, -d / 2 - .03), g)
	Mk.mi(Mk.rounded_box(Vector3(w, h - kick, d), .004, _wood, 2), null, Vector3(0, kick + (h - kick) / 2, -d / 2), g)
	var brass := Mk.mat(Mk.c(0xc89a48), .28, 1.0)
	var fh := h - kick
	# cadre de façade (montants + traverse haute), les tiroirs / portes sont encastrés dedans
	var fw := .024
	for sx in [-1, 1]:
		Mk.mi(Mk.rounded_box(Vector3(fw, fh, .014), .003, _wood, 2), null, Vector3(sx * (w / 2 - fw / 2), kick + fh / 2, .007), g)
	Mk.mi(Mk.rounded_box(Vector3(w - 2 * fw, .03, .014), .003, _wood, 2), null, Vector3(0, h - .015, .007), g)
	var iw := w - 2 * fw
	match kind:
		"drawers":
			var n := 3
			var gap := .006
			var dh := (fh - .03 - gap * (n + 1)) / n
			for i in n:
				var cy := kick + gap + dh / 2 + i * (dh + gap)
				var front := Mk.mi(Mk.rounded_box(Vector3(iw - 2 * gap, dh, .02), .004, _wood, 2), null, Vector3(0, cy, .01), g)
				front.name = "Drawer"
				# panneau en relief chanfreiné
				Mk.mi(Mk.rounded_box(Vector3(iw - 2 * gap - .07, dh - .06, .008), .006, _wood, 3), null, Vector3(0, cy, .022), g)
				_pull(g, brass, Vector3(0, cy + dh * .12, .028), .12)
		"doors":
			var gap := .006
			var dw := (iw - 3 * gap) / 2
			for i in 2:
				var cx := -iw / 2 + gap + dw / 2 + i * (dw + gap)
				Mk.mi(Mk.rounded_box(Vector3(dw, fh - .03 - 2 * gap, .022), .004, _wood, 2), null, Vector3(cx, kick + (fh - .03) / 2, .011), g)
				# moulure de porte
				Mk.mi(Mk.rounded_box(Vector3(dw - .08, fh - .13, .008), .006, _wood, 3), null, Vector3(cx, kick + (fh - .03) / 2, .025), g)
				var knob := Mk.mi(Mk.sphere(.012, 16, 8), brass, Vector3(cx + (dw / 2 - .04) * (1 if i == 0 else -1), kick + fh * .62, .034), g)
				knob.scale = Vector3(1, 1, .8)
		"rack":
			# baie 19" : ouverture sombre, rails, appareils et façades de remplissage
			var bw := .483
			var by := kick + .03
			var bh := fh - .06
			Mk.mi(Mk.box(Vector3(bw - .01, bh, .02)), dark, Vector3(0, by + bh / 2, .002), g)
			var rail := Mk.mat(Mk.c(0x1a1a1a), .5, .7)
			for sx in [-1, 1]:
				Mk.mi(Mk.box(Vector3(.016, bh, .006)), rail, Vector3(sx * (bw / 2 - .008), by + bh / 2, .014), g)
			var U := .04445
			var units := [[2, "blank"], [1, "vent"], [3, "blank"], [1, "vent"], [2, "blank"], [1, "vent"], [3, "blank"]]
			var yy := by + bh - .004
			for u in units:
				var uh: float = u[0] * U - .001
				if yy - uh < by:
					break
				var pm := _rack_panel_mat(u[1], u[0])
				Mk.mi(Mk.rounded_box(Vector3(bw, uh, .004), .001, [rail, rail, rail, rail, pm, rail], 1), null, Vector3(0, yy - uh / 2, .018), g)
				for sx in [-1, 1]:
					for sy in ([0.0] if u[0] == 1 else [uh / 2 - .01, -uh / 2 + .01]):
						var sc := Mk.screw_head(.003)
						sc.rotation.x = PI / 2
						sc.position = Vector3(sx * (bw / 2 - .008), yy - uh / 2 + sy, .0205)
						g.add_child(sc)
				yy -= uh + .001
	return g


func _pull(g: Node3D, m: Material, at: Vector3, w: float) -> void:
	var bar := Mk.mi(Mk.cyl(.006, .006, w, 12), m, at + Vector3(0, 0, .01), g)
	bar.rotation.z = PI / 2
	for sx in [-1, 1]:
		var post := Mk.mi(Mk.cyl(.005, .005, .02, 8), m, at + Vector3(sx * (w / 2 - .01), 0, 0), g)
		post.rotation.x = PI / 2


var _rack_mats := {}


func _rack_panel_mat(kind: String, units: int) -> Material:
	var key := "%s%d" % [kind, units]
	if _rack_mats.has(key):
		return _rack_mats[key]
	var silver := units == 2
	var tex := Tex.canvas(1024, int(1024 * units * .04445 / .483), func(ci, w, h):
		var base := Mk.c(0x8e8a84) if silver and kind != "vent" else Mk.c(0x1a1a1a)
		ci.draw_rect(Rect2(0, 0, w, h), base)
		Tex.brushed(ci, w, h, 60 + units, .06, 1500)
		var ink := Color(.08, .08, .08, .85) if silver else Color(.85, .82, .76, .75)
		if kind == "vent":
			var x := 120.0
			while x < w - 120:
				ci.draw_rect(Rect2(x, h * .25, 10, h * .5), Color(0, 0, 0, .9))
				x += 22
		else:
			# appareil : nom, potards, LED, interrupteur
			Tex.silk(ci, ["RT-C2  COMPRESSOR", "RT-EQ3  PARAMETRIC", "RT-D7  DELAY"][units % 3], 70, h * .25, 22, ink)
			for i in 6:
				var c := Vector2(320 + i * 95, h * .55)
				ci.draw_circle(c, h * .2, Color(0, 0, 0, .5))
				for k in 11:
					var a := deg_to_rad(-135 + k * 27)
					ci.draw_line(c + Vector2(sin(a), -cos(a)) * h * .24, c + Vector2(sin(a), -cos(a)) * h * .28, ink, 2.0)
			ci.draw_circle(Vector2(900, h * .5), 7, Color(1, .2, .1, .9))
			ci.draw_rect(Rect2(60, h * .5, 60, h * .3), Color(0, 0, 0, .7))
		Tex.grime(ci, w, h, 61 + units, .8))
	var m := Mk.weather(Mk.mat(Color.WHITE, .4, .7, {"map": tex}), Mk.scratch_normal(), .2, .15)
	_rack_mats[key] = m
	return m


## Cuir noir capitonné en boudins (côtes verticales tous les ~9 cm).
func _leather(length: float) -> StandardMaterial3D:
	var img := Image.create(256, 16, false, Image.FORMAT_L8)
	for x in 256:
		var v := sin(float(x) / 256.0 * PI)
		for y in 16:
			img.set_pixel(x, y, Color(v, v, v))
	var m := Mk.mat(Mk.c(0x0e0c0b), .42, 0.0, {"normal": Tex.normal_from_bump(img, 6.0), "normal_scale": 1.0, "clearcoat": .35, "clearcoat_rough": .45})
	m.uv1_scale = Vector3(length / .09, 1, 1)
	return m


# ---------------------------------------------------------------- lumières
func _build_lights() -> void:
	# spots encastrés au plafond (lumière tungstène)
	var can_mat := Mk.glow(Mk.c(0xffc68a), 5.0)
	var trim := Mk.mat(Mk.c(0x2a2420), .4, .6)
	for p in [Vector3(1.0, 0, -.55), Vector3(2.1, 0, -.55), Vector3(.3, 0, -1.2), Vector3(1.6, 0, -2.4), Vector3(.5, 0, -3.4)]:
		var ring := Mk.mi(Mk.cyl(.05, .05, .01, 24), trim, Vector3(p.x, ROOM.y - .005, p.z), self)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var bulb := Mk.mi(Mk.disc(.035, 24), can_mat, Vector3(p.x, ROOM.y - .011, p.z), self)
		bulb.rotation.x = PI
		var sp := SpotLight3D.new()
		sp.light_color = Mk.c(0xffdcb8)
		sp.light_energy = 3.2
		sp.spot_range = 3.0
		sp.spot_angle = 34.0
		sp.spot_angle_attenuation = 1.4
		sp.shadow_enabled = true
		sp.light_volumetric_fog_energy = .6
		_aim(sp, Vector3(p.x, ROOM.y - .02, p.z), Vector3(p.x - .05, 0, p.z + .05))
		add_child(sp)
	# rampe de spots orientables au plafond, le long de la vitre
	var black := Mk.mat(Mk.c(0x141414), .45, .4)
	var rail_z := -.5
	Mk.mi(Mk.box(Vector3(2.6, .025, .035)), black, Vector3(1.55, ROOM.y - .0125, rail_z), self)
	for x in [.55, 1.15, 1.85, 2.5]:
		var head := Node3D.new()
		head.position = Vector3(x, ROOM.y - .025, rail_z)
		add_child(head)
		Mk.mi(Mk.cyl(.008, .008, .05, 8), black, Vector3(0, -.025, 0), head)
		var can := Node3D.new()
		can.position = Vector3(0, -.06, 0)
		head.add_child(can)
		var target := Vector3(x + (1.55 - x) * .15, DESK_TOP, -.55)
		can.basis = Basis.looking_at(target - head.position - can.position, Vector3.UP)
		var body := Mk.mi(Mk.cyl(.032, .038, .1, 24, false), Mk.mat(Mk.c(0x1a1a1a), .35, .6, {"cull_off": true}), Vector3(0, 0, -.02), can)
		body.rotation.x = PI / 2
		var lens := Mk.mi(Mk.disc(.03, 24), Mk.glow(Mk.c(0xffd2a0), 6.0), Vector3(0, 0, -.068), can)
		lens.rotation.x = -PI / 2
		var ts := SpotLight3D.new()
		ts.light_color = Mk.c(0xffd8b0)
		ts.light_energy = 1.1
		ts.spot_range = 2.6
		ts.spot_angle = 22.0
		ts.spot_angle_attenuation = 1.2
		ts.shadow_enabled = true
		ts.light_volumetric_fog_energy = 1.0
		ts.position = Vector3(0, 0, -.08)
		can.add_child(ts)
	# rasants sur le liège du mur de droite
	for z in [-2.95, -3.7]:
		var ww := SpotLight3D.new()
		ww.light_color = Mk.c(0xffcfa0)
		ww.light_energy = 1.4
		ww.spot_range = 2.0
		ww.spot_angle = 40.0
		_aim(ww, Vector3(.35, ROOM.y - .05, z), Vector3(0, 1.2, z))
		add_child(ww)
	# rasants sur le lambris de part et d'autre de la vitre
	for x in [.25, 2.75]:
		var lw := SpotLight3D.new()
		lw.light_color = Mk.c(0xffd2a8)
		lw.light_energy = 1.6
		lw.spot_range = 2.4
		lw.spot_angle = 38.0
		_aim(lw, Vector3(x, ROOM.y - .05, -.35), Vector3(x, .9, 0))
		add_child(lw)
	# remplissage doux côté caméra
	var fill := OmniLight3D.new()
	fill.light_color = Mk.c(0xffe0c8)
	fill.light_energy = 1.0
	fill.omni_range = 6.0
	fill.position = Vector3(2.6, 1.6, -3.2)
	add_child(fill)


# ---------------------------------------------------------------- cabine de prise (vue floue à travers la vitre)
func _build_booth(dark_wood: Material) -> void:
	var b := Node3D.new()
	b.name = "Booth"
	# la cabine est construite dans son propre repère puis retournée derrière la vitre (côté +Z)
	b.transform = Transform3D(Basis(Vector3.UP, PI), BOOTH_ORIGIN)
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
	Mk.mi(Mk.plane(w, dz), Mk.mat(Mk.c(0x6a4a30), .7, 0.0, {"map": wood, "uv_scale": Vector3(2, 1, 1)}), Vector3(cx, B_FLOOR, (z0 + z1) / 2), b)
	var rug := Tex.canvas(512, 384, func(ci, rw, rh):
		ci.draw_rect(Rect2(0, 0, rw, rh), Mk.c(0x5a1612))
		ci.draw_rect(Rect2(18, 18, rw - 36, rh - 36), Mk.c(0x2a0d0a))
		ci.draw_rect(Rect2(34, 34, rw - 68, rh - 68), Mk.c(0x6e1d15))
		var r := Tex.rng(12)
		for i in 60:
			var p := Vector2(60 + r.randf() * (rw - 120), 60 + r.randf() * (rh - 120))
			ci.draw_circle(p, 4 + r.randf() * 10, Color(.85, .6, .3, .25))
		Tex.grime(ci, rw, rh, 13, 2))
	Mk.mi(Mk.rounded_box(Vector3(1.8, .01, 1.3), .004, Mk.mat(Color.WHITE, .98, 0.0, {"map": rug})), null, Vector3(-.5, B_FLOOR + .005, -2.25), b)
	# murs : lambris + tissu chaud
	var boards := Mk.mat(Color.WHITE, .8, 0.0, {"map": _boards()})
	var back := Mk.mi(_wall_mesh([[-w / 2, B_FLOOR, w / 2, cy]], 6.0, 3.4), Mk.mat(Mk.c(0x1a0f08), .95), Vector3(cx, 0, z1), b)
	back.name = "BoothBack"
	Mk.mi(_wall_mesh([[-w / 2, B_FLOOR, w / 2, B_WOOD_TOP - .1]]), boards, Vector3(cx, 0, z1 + .005), b)
	for side in [[x0, PI / 2], [x1, -PI / 2]]:
		var sw := Mk.mi(_wall_mesh([[-dz / 2, B_FLOOR, dz / 2, cy]]), Mk.mat(Mk.c(0x1a0f08), .95), Vector3(side[0], 0, (z0 + z1) / 2), b)
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
	mic.position = Vector3(-.45, B_FLOOR, -2.05)
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
	stool.position = Vector3(.15, B_FLOOR, -2.55)
	b.add_child(stool)
	Mk.mi(Mk.cyl(.18, .17, .05, 32), Mk.mat(Mk.c(0x2a1a12), .6), Vector3(0, .72, 0), stool)
	for i in 4:
		var a := i * PI / 2 + .4
		var leg := Mk.mi(Mk.cyl(.012, .016, .74, 8), dark_wood, Vector3(cos(a) * .12, .36, sin(a) * .12), stool)
		leg.rotation = Vector3(sin(a) * .12, 0, -cos(a) * .12)
	# ampli guitare
	var amp := Node3D.new()
	amp.position = Vector3(.85, B_FLOOR, -3.0)
	amp.rotation.y = -.35
	b.add_child(amp)
	Mk.mi(Mk.rounded_box(Vector3(.55, .45, .26), .015, Mk.mat(Mk.c(0x161412), .7)), null, Vector3(0, .225, 0), amp)
	Mk.mi(Mk.quad(.48, .3), Mk.mat(Mk.c(0xb8a27a), .9), Vector3(0, .19, .131), amp)
	Mk.mi(Mk.quad(.48, .06), Mk.mat(Mk.c(0x9a968f), .4, .8), Vector3(0, .39, .131), amp)
	# lampadaire chaud : la vraie source de lumière de la cabine
	var lampe := Node3D.new()
	lampe.position = Vector3(-1.95, B_FLOOR, -2.95)
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
	_aim(sp, Vector3(-.45, cy - .05, -2.0), Vector3(-.45, B_FLOOR, -2.1))
	b.add_child(sp)


## Oriente une lumière (le studio est à l'origine : repère local = monde).
func _aim(n: Node3D, from: Vector3, to: Vector3) -> void:
	n.transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), from)



# ---------------------------------------------------------------- caméra
## Renvoie [position, point visé, orientation] : la caméra fixe de la scène Blender.
func shot_pose(shot: String, cam: Camera3D, aspect: float) -> Array:
	if shot == "chat":
		return [cat.to_global(Vector3(.16, .3, .62)), cat.to_global(Vector3(0, .13, .06))]
	if shot == "export":
		return _via(export, Vector3(0, 0, .03), Vector3(0, 0, 1), Export7080.BW / 2, Export7080.BH / 2, cam, aspect, 1.12)
	if shot == "freq":
		return _via(freq, Vector3(0, Freq7080.H, 0), Vector3(0, 1, .7), Freq7080.L / 2, Freq7080.D / 2, cam, aspect, 1.12)
	if shot == "analyse":
		return _via(analyzer, Vector3(0, .08, .02), Vector3(0, 1, .9), Analyzer7080.W / 2, Analyzer7080.D / 2, cam, aspect, 1.15)
	if shot == "tuner":
		return _via(tuner, Vector3(0, Tuner7080.H / 2, 0), Vector3(0, .25, 1), Tuner7080.W / 2 * .85, Tuner7080.H / 2 * .85, cam, aspect, 1.25)
	if shot == "tempo":
		return _via(tempo.deck, Vector3(0, 0, .0), Vector3(0, 1, .55), Tempo7080.W / 2, tempo.plen / 2, cam, aspect, 1.08)
	if DEBUG_SHOTS.has(shot):
		return DEBUG_SHOTS[shot]
	var b := Basis(CAM_QUAT)
	return [CAM_POS, CAM_POS - b.z * CAM_FOCUS, b]


## Plans de contrôle (captures de dev uniquement, pas dans `order`).
const DEBUG_SHOTS := {
	"x_chair": [Vector3(2.75, 1.05, -2.5), Vector3(1.85, .5, -1.5)],
	"x_console": [Vector3(1.7, 1.55, -1.55), Vector3(1.7, .85, -.5)],
	"x_spk": [Vector3(1.25, 1.3, -1.35), Vector3(.45, 1.2, -.3)],
	"x_desk": [Vector3(1.4, .75, -2.6), Vector3(1.0, .45, -.6)],
}


func _fit(cam: Camera3D, aspect: float, half_w: float, half_h: float) -> float:
	var v := tan(deg_to_rad(cam.fov) / 2.0)
	if cam.keep_aspect == Camera3D.KEEP_WIDTH:
		v = tan(deg_to_rad(cam.fov) / 2.0) / aspect
	return maxf(half_h / v, half_w / (v * aspect))


## Plan rapproché sur un nœud : centre local + normale locale, cadré sur une demi-largeur / demi-hauteur.
func _via(obj: Node3D, local: Vector3, n: Vector3, hw: float, hh: float, cam: Camera3D, aspect: float, m := 1.12) -> Array:
	var c := obj.to_global(local)
	var nn := (obj.global_basis * n).normalized()
	return [c + nn * _fit(cam, aspect, hw * m, hh * m), c]


## Réglage d'objectif : on garde le champ horizontal de Blender quand la fenêtre est plus étroite que 16:9.
func setup_camera(cam: Camera3D, aspect: float) -> void:
	if aspect >= 16.0 / 9.0:
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		cam.fov = rad_to_deg(CAM_YFOV)
	else:
		cam.keep_aspect = Camera3D.KEEP_WIDTH
		cam.fov = rad_to_deg(2.0 * atan(tan(CAM_YFOV / 2.0) * 16.0 / 9.0))


## Appelé quand on change de plan : le chat regarde la machine, les modules sont prévenus.
func on_shot(shot: String, cam: Camera3D, aspect: float) -> void:
	if shot != "overview" and shot != "chat":
		cat.look_at_point(shot_pose(shot, cam, aspect)[1])
	for m in modules.values():
		if m.has_method("on_shot_changed"):
			m.on_shot_changed(shot)


func animate(t: float, dt: float, reduced: bool) -> void:
	# habillage par plan (comme au cinéma) : la plante gêne le gros plan sur le Tempo
	deco.plant.visible = get_parent().current != "tempo"
	deco.arch_lamp.visible = get_parent().current != "export"
	# les enceintes de proximité restent visibles autour de l'accordeur
	for m in modules.values():
		m.animate(t, dt, reduced)
