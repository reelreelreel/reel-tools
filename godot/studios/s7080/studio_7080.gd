class_name Studio7080
extends Node3D
## Studio 70/80, régie pro — pièce fermée de 3,6 x 4,2 m, 2,3 m sous plafond. On est assis dans le
## fauteuil au centre et on tourne la tête à 360° (glisser). Repère : on regarde +Z vers la console ;
## +X est à gauche, x = 0 à droite.
##   · devant (mur z = 0)        : bureau + console, Tempo, Analyse ; fenêtre sur la rue (la nuit)
##   · gauche (mur x = 3,6)      : coin composition (retour du bureau) : accordeur 808, synthé Fréquences,
##                                 places pour le fax, les boîtes à rythmes, le synthé Gammes
##   · derrière (mur z = -4,2)   : mur de racks et d'étagères (disques, bandes, futures machines de labo)
##   · droite (mur x = 0)        : tableau Export, vitre de la cabine de prise, pupitre (futur carnet Splits)
##
## Ambiance (photos de référence) : bois chaud, liège / tissu texturé, lumière tungstène tamisée.

const ROOM := Vector3(3.6, 2.3, 4.2)         # x 0..3,6, y 0..2,3, z -4,2..0
const WIN := {"x0": .545, "x1": 2.455, "y0": .909, "y1": 1.727}          # fenêtre sur rue (mur avant)
const BWIN := {"z0": -3.45, "z1": -1.65, "y0": .86, "y1": 1.74}         # vitre de la cabine (mur droit)
const DESK_TOP := .818
const DESK_T := .091
const DESKS := [  # [x0, x1, z0, z1]
	[.05, 3.05, -1.0, 0.0],     # bureau principal contre le mur avant
	[3.05, 3.59, -2.35, 0.0],   # retour contre le mur de gauche (coin composition)
]
const WAINSCOT := 1.05                       # hauteur du lambris
## Tête de l'ingé assis dans le fauteuil : pivot de la caméra 360°
const SEAT := Vector3(1.75, 0, -1.62)
const EYE := Vector3(1.75, 1.17, -1.72)
const CAM_YFOV := 1.0                         # radians (≈ 57°), image 16:9

## Cabine (construite dans son repère d'origine, puis tournée derrière la vitre du mur droit)
const BOOTH := {"x0": -2.6, "x1": 1.4, "z0": -1.14, "z1": -3.4, "ceil": 2.1}
const BOOTH_ORIGIN := Vector3(.74, .78, -2.95)
const B_FLOOR := -0.78
const B_WOOD_TOP := 0.44

## Plans : la vue 360° depuis le fauteuil, puis un gros plan par module.
var order: Array = ["overview", "tempo", "tuner", "analyse", "freq", "export", "fax"]
## Modules jouables : nom -> nœud (on_action, on_drag_start, on_drag, on_wheel, on_key, animate)
var modules := {}
var tempo: Tempo7080
var tuner: Tuner7080
var analyzer: Analyzer7080
var freq: Freq7080
var export: Export7080
var fax: Fax7080
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
	_wood = Mk.pbr("dark_wood", .9, {"tint": Mk.c(0xc8a090), "rough": .85, "clearcoat": .35, "clearcoat_rough": .35})
	_build_floor_ceiling()
	_build_front_wall()
	_build_right_wall()
	_build_left_wall()
	_build_back_wall()
	_build_window(Vector3.ZERO, 0.0, WIN.x0, WIN.x1, WIN.y0, WIN.y1, false)
	_build_window(Vector3.ZERO, -PI / 2, BWIN.z0, BWIN.z1, BWIN.y0, BWIN.y1, true)
	_build_booth(Mk.mat(Mk.c(0x6a4a34), .7, 0.0, {"map": Mk.walnut_tex()}))
	_build_street()
	_build_desks()
	_build_back_units()
	_build_lectern()
	_build_lights()
	deco = Deco7080.new()
	add_child(deco)
	var walnut := Mk.mat(Mk.c(0x6a4028), .55, 0.0, {"map": Mk.walnut_tex(), "clearcoat": .3})
	# --- devant : Tempo accolé à droite (côté +X) de la console
	tempo = Tempo7080.new(engine, walnut)
	tempo.position = Vector3(1.7 + 1.6 / 2 + .025 + Tempo7080.W / 2, DESK_TOP, -.57)
	tempo.rotation.y = PI
	add_child(tempo)
	modules["tempo"] = tempo
	# --- devant : Analyse (magnéto + écran vert) au bout droit du bureau, tourné vers le fauteuil
	analyzer = Analyzer7080.new(walnut)
	analyzer.position = Vector3(.36, DESK_TOP, -.5)
	analyzer.rotation.y = PI - .35
	add_child(analyzer)
	modules["analyse"] = analyzer
	# --- gauche : Accordeur 808 sur le retour, incliné vers le fauteuil
	tuner = Tuner7080.new(walnut)
	tuner.position = Vector3(3.3, DESK_TOP, -.55)
	tuner.basis = Basis(Vector3.UP, -PI / 2 - .5) * Basis(Vector3.RIGHT, -.12)
	add_child(tuner)
	modules["tuner"] = tuner
	# --- gauche : synthé Fréquences sur son support mural au-dessus du retour
	var steel := Mk.mat(Mk.c(0x2a2a2a), .4, .7)
	for z in [-1.0, -1.5]:
		var arm := Mk.mi(Mk.rounded_box(Vector3(.3, .025, .025), .004, steel, 2), null, Vector3(ROOM.x - .15, 1.2, z), self)
		arm.rotation.z = -.4
		Mk.mi(Mk.rounded_box(Vector3(.02, .16, .04), .004, steel, 2), null, Vector3(ROOM.x - .01, 1.2, z), self)
	freq = Freq7080.new(walnut)
	freq.position = Vector3(ROOM.x - .16, 1.235, -1.25)
	freq.basis = Basis(Vector3.UP, -PI / 2) * Basis(Vector3.RIGHT, .4)
	add_child(freq)
	modules["freq"] = freq
	# --- droite : tableau Export en liège, au mur droit avant la vitre de la cabine
	export = Export7080.new(walnut)
	export.position = Vector3(.002, 1.45, -.98)
	export.rotation.y = PI / 2
	add_child(export)
	modules["export"] = export
	# --- gauche : Fax d'accords sur le retour, façade (et feuille) vers le fauteuil
	fax = Fax7080.new(walnut)
	fax.position = Vector3(3.31, DESK_TOP, -1.47)
	fax.rotation.y = -PI / 2
	add_child(fax)
	modules["fax"] = fax


func _ready() -> void:
	_module_cables()
	_build_module_spots()


# ---------------------------------------------------------------- spots sur les machines
## Rails noirs au plafond, un par zone (devant, gauche, droite, fond), avec des spots alignés. Chaque
## machine a son spot sur le rail de sa zone, braqué sur elle : discret au repos, il monte quand la
## souris passe sur la machine et reste un peu plus fort sur la machine ouverte. D'autres spots du
## rail, très doux, éclairent le décor.
const SPOT_IDLE := .4
const SPOT_HOVER := 8.0
const SPOT_OPEN := 2.5
const RAILS := {  # zone -> [début, fin] (au plafond)
	"front": [Vector3(.35, 0, -.55), Vector3(3.15, 0, -.55)],
	"left": [Vector3(2.95, 0, -.9), Vector3(2.95, 0, -3.6)],
	"right": [Vector3(.6, 0, -.6), Vector3(.6, 0, -3.6)],
	"back": [Vector3(.5, 0, -3.55), Vector3(2.65, 0, -3.55)],
}
var module_spots := {}  # module -> {light, lens, level}
var _black_mat: Material


## Zone d'une machine d'après sa position (pour choisir son rail).
func zone_of(p: Vector3) -> String:
	if p.x > 3.0:
		return "left"
	if p.x < .25:
		return "right"
	if p.z < -3.0:
		return "back"
	return "front"


func _build_module_spots() -> void:
	_black_mat = Mk.mat(Mk.c(0x141414), .45, .4)
	var y := ROOM.y
	for k in RAILS:
		var a: Vector3 = RAILS[k][0]
		var b: Vector3 = RAILS[k][1]
		var mid := (a + b) / 2
		var L := a.distance_to(b)
		var rail := Mk.mi(Mk.box(Vector3(L, .025, .035)), _black_mat, Vector3(mid.x, y - .0125, mid.z), self)
		rail.rotation.y = -atan2(b.z - a.z, b.x - a.x)
		rail.name = "Rail_" + k
	var used := {}  # positions déjà prises sur les rails
	for k in modules:
		var node: Node3D = modules[k]
		var bb := Mk.local_aabb(node)
		var target := node.to_global(bb.get_center())
		var radius := (node.global_basis * (bb.size / 2)).length() * .75
		var z := zone_of(target)
		var a: Vector3 = RAILS[z][0]
		var b: Vector3 = RAILS[z][1]
		var ab := b - a
		var tt := clampf((Vector3(target.x, 0, target.z) - a).dot(ab) / ab.length_squared(), 0, 1)
		var from := a + ab * tt + Vector3(0, y - .03, 0)
		var s := _rail_spot(from, target, true)
		s.light.spot_angle = clampf(rad_to_deg(atan(radius / from.distance_to(target))) + 3.0, 8.0, 40.0)
		module_spots[k] = s
		used[z] = used.get(z, []) + [tt]
	# spots d'ambiance sur les rails (très doux), entre ceux des machines
	for k in RAILS:
		var a: Vector3 = RAILS[k][0]
		var b: Vector3 = RAILS[k][1]
		for tt in [.12, .5, .88]:
			var free := true
			for u in used.get(k, []):
				if absf(u - tt) < .2:
					free = false
			if not free:
				continue
			var from: Vector3 = a + (b - a) * tt + Vector3(0, y - .03, 0)
			var aim := {"front": Vector3(0, -1, .6), "back": Vector3(0, -1, -.7), "left": Vector3(.7, -1, 0), "right": Vector3(-.7, -1, 0)}[k] as Vector3
			var s := _rail_spot(from, from + aim, false)
			s.light.light_energy = .35
			s.light.spot_angle = 30.0


## Un projecteur sur rail : adaptateur, corps cylindrique orientable, lentille, lumière.
func _rail_spot(from: Vector3, target: Vector3, shadow: bool) -> Dictionary:
	var head := Node3D.new()
	head.position = from
	add_child(head)
	Mk.mi(Mk.box(Vector3(.03, .02, .045)), _black_mat, Vector3(0, .01, 0), head)
	Mk.mi(Mk.cyl(.006, .006, .05, 8), _black_mat, Vector3(0, -.025, 0), head)
	var can := Node3D.new()
	can.position = Vector3(0, -.06, 0)
	head.add_child(can)
	can.basis = Basis.looking_at(target - from - can.position, Vector3.UP if absf((target - from).normalized().y) < .99 else Vector3.FORWARD)
	var body := Mk.mi(Mk.cyl(.026, .032, .085, 20, false), Mk.mat(Mk.c(0x161616), .35, .6, {"cull_off": true}), Vector3(0, 0, -.02), can)
	body.rotation.x = PI / 2
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lens_mat := StandardMaterial3D.new()
	lens_mat.albedo_color = Color(.05, .04, .03)
	lens_mat.emission_enabled = true
	lens_mat.emission = Mk.c(0xffd2a0)
	lens_mat.emission_energy_multiplier = .5
	var lens := Mk.mi(Mk.disc(.024, 20), lens_mat, Vector3(0, 0, -.061), can)
	lens.rotation.x = -PI / 2
	var sp := SpotLight3D.new()
	sp.light_color = Mk.c(0xffd6aa)
	sp.light_energy = SPOT_IDLE
	sp.spot_range = from.distance_to(target) + 1.2
	sp.spot_angle_attenuation = 2.0
	sp.shadow_enabled = shadow
	sp.position = Vector3(0, 0, -.07)
	can.add_child(sp)
	return {"light": sp, "lens": lens_mat, "level": SPOT_IDLE}


func _animate_spots(dt: float) -> void:
	var main := get_parent()
	var cur: String = main.current
	var hov: String = main.hover_module if cur == "overview" else ""
	for k in module_spots:
		var s: Dictionary = module_spots[k]
		var want := SPOT_HOVER if k == hov else (SPOT_OPEN if k == cur else SPOT_IDLE)
		s.level = move_toward(s.level, want, dt * (9.0 if want > s.level else 4.0))
		s.light.light_energy = s.level
		s.lens.emission_energy_multiplier = .4 + s.level * .8



# ---------------------------------------------------------------- environnement & post-traitement
## Effets d'image « de finition » (brume volumétrique, halos, profondeur de champ, grain, étalonnage).
## Coupés pour l'instant à la demande de Maxime : ambiance simple, on les remettra à la fin.
const LOOK_FX := false


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
	env.ambient_light_energy = 0.16
	# éclairage indirect : la lumière rebondit sur les murs, le bois, le tapis (rendu Forward+)
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.05
	env.sdfgi_bounce_feedback = 0.6
	env.sdfgi_energy = 1.1
	env.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_100_PERCENT
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.tonemap_white = 12.0
	env.ssao_enabled = true
	env.ssao_radius = 0.45
	env.ssao_intensity = 1.2
	env.ssao_detail = 0.8
	env.ssil_enabled = LOOK_FX
	env.ssil_radius = 1.5
	env.ssr_enabled = false
	env.glow_enabled = true  # seulement les LED / écrans (seuil haut), sans voile
	env.glow_intensity = 0.7 if LOOK_FX else 0.35
	env.glow_strength = 1.0
	env.glow_bloom = 0.02 if LOOK_FX else 0.0
	env.glow_hdr_threshold = 0.9 if LOOK_FX else 1.3
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.6)
	env.set_glow_level(4, 0.4)
	env.fog_enabled = LOOK_FX
	env.fog_light_color = Mk.c(0x100c09)
	env.fog_density = 0.05
	env.fog_sky_affect = 0.0
	env.volumetric_fog_enabled = LOOK_FX
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Mk.c(0xffe2c4)
	env.volumetric_fog_length = 6.0
	env.volumetric_fog_ambient_inject = 0.0
	env.adjustment_enabled = LOOK_FX
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
	var cx := ROOM.x / 2
	var cz := -ROOM.z / 2
	# parquet
	var parquet := Mk.pbr("plank_flooring", 1.6, {"tint": Mk.c(0xc0a088), "clearcoat": .25, "clearcoat_rough": .45, "local": false})
	var fl := Mk.mi(Mk.plane(ROOM.x + .1, ROOM.z + .1), parquet, Vector3(cx, 0, cz), self)
	fl.name = "Floor"
	# grand tapis persan sous le fauteuil
	var rug := Mk.mi(Mk.rounded_box(Vector3(2.5, .012, 1.9), .005, [null, null, _persian_rug(), null, null, null], 2), null, Vector3(1.75, .006, -2.05), self)
	rug.rotation.y = .03
	var edge := Mk.mat(Mk.c(0x3a1410), 1.0)
	for i in [0, 1, 3, 4, 5]:
		rug.mesh.surface_set_material(i, edge)
	# plafond en dalles acoustiques dans une grille
	var ceil := Mk.mi(Mk.plane(ROOM.x + .1, ROOM.z + .1), _ceiling_tiles(), Vector3(cx, ROOM.y, cz), self)
	ceil.rotation.x = PI
	ceil.name = "Ceiling"
	# plinthes sombres au pied des quatre murs
	var base := Mk.mat(Mk.c(0x1a100a), .6)
	Mk.mi(Mk.box(Vector3(.02, .1, ROOM.z)), base, Vector3(.01, .05, cz), self)
	Mk.mi(Mk.box(Vector3(.02, .1, ROOM.z)), base, Vector3(ROOM.x - .01, .05, cz), self)
	Mk.mi(Mk.box(Vector3(ROOM.x, .1, .02)), base, Vector3(cx, .05, -.01), self)
	Mk.mi(Mk.box(Vector3(ROOM.x, .1, .02)), base, Vector3(cx, .05, -ROOM.z + .01), self)


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
	m.uv1_scale = Vector3((ROOM.x + .1) / .6, (ROOM.z + .1) / .6, 1)
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


## Mur avant (z = 0, face vers -Z) : lambris de bois, percé de la fenêtre sur la rue.
func _build_front_wall() -> void:
	var w := Node3D.new()
	w.name = "FrontWall"
	w.rotation.y = PI  # repère local : x = -x monde, normale +Z = -Z monde
	add_child(w)
	var X0 := -ROOM.x
	var hx0: float = -WIN.x1
	var hx1: float = -WIN.x0
	var rects := [[X0, 0, hx0, ROOM.y], [hx1, 0, 0, ROOM.y], [hx0, 0, hx1, WIN.y0], [hx0, WIN.y1, hx1, ROOM.y]]
	Mk.mi(_wall_mesh(rects), _wall_boards(), Vector3.ZERO, w)
	_cornice(w, X0, 0)


## Lambris en bas, liège / tissu texturé au-dessus, lisse et corniche en bois. Trou optionnel [a0, a1, y0, y1]
## en coordonnées locales du mur (repère : x le long du mur, face +Z).
func _cork_wall(w: Node3D, a0: float, a1: float, hole := []) -> void:
	var boards := _wall_boards()
	var cork := _cork_mat()
	cork.uv1_scale = Vector3(2.5, 1, 1)
	var low := []
	var high := []
	if hole.is_empty():
		low = [[a0, 0, a1, WAINSCOT]]
		high = [[a0, WAINSCOT, a1, ROOM.y]]
	else:
		var h0: float = hole[0]
		var h1: float = hole[1]
		low = [[a0, 0, h0, WAINSCOT], [h1, 0, a1, WAINSCOT], [h0, 0, h1, hole[2]]]
		high = [[a0, WAINSCOT, h0, ROOM.y], [h1, WAINSCOT, a1, ROOM.y], [h0, hole[3], h1, ROOM.y]]
	Mk.mi(_wall_mesh(low), boards, Vector3.ZERO, w)
	Mk.mi(_wall_mesh(high), cork, Vector3.ZERO, w)
	# lisse en bois entre lambris et liège (coupée par l'ouverture)
	var spans := [[a0, a1]] if hole.is_empty() else [[a0, hole[0]], [hole[1], a1]]
	for sp in spans:
		var L: float = sp[1] - sp[0]
		Mk.mi(Mk.rounded_box(Vector3(L, .05, .035), .006, _wood, 2), null, Vector3((sp[0] + sp[1]) / 2, WAINSCOT, .017), w)
	_cornice(w, a0, a1)


func _cornice(w: Node3D, a0: float, a1: float) -> void:
	Mk.mi(Mk.rounded_box(Vector3(absf(a1 - a0), .07, .05), .006, _wood, 2), null, Vector3((a0 + a1) / 2, ROOM.y - .035, .025), w)


## Mur droit (x = 0, face vers +X) : percé de la vitre de la cabine.
func _build_right_wall() -> void:
	var w := Node3D.new()
	w.name = "RightWall"
	w.rotation.y = PI / 2  # local x = -z monde
	add_child(w)
	_cork_wall(w, 0, ROOM.z, [-BWIN.z1, -BWIN.z0, BWIN.y0, BWIN.y1])


## Mur gauche (x = 3,6, face vers -X) : coin composition.
func _build_left_wall() -> void:
	var w := Node3D.new()
	w.name = "LeftWall"
	w.position = Vector3(ROOM.x, 0, 0)
	w.rotation.y = -PI / 2  # local x = z monde
	add_child(w)
	_cork_wall(w, -ROOM.z, 0)


## Mur du fond (z = -4,2, face vers +Z) : lambris (couvert par les racks et étagères).
func _build_back_wall() -> void:
	var w := Node3D.new()
	w.name = "BackWall"
	w.position = Vector3(0, 0, -ROOM.z)
	add_child(w)
	Mk.mi(_wall_mesh([[0, 0, ROOM.x, ROOM.y]]), _wall_boards(), Vector3.ZERO, w)
	_cornice(w, 0, ROOM.x)


## Ouverture dans un mur : tableau épais en bois, encadrement, vitre. Repère local : la fenêtre est dans
## le plan z = 0, la pièce côté -Z, l'épaisseur du mur vers +Z. a0..a1 = étendue le long du mur.
## double = vitre de cabine (double vitrage, vitre côté régie inclinée) ; sinon fenêtre à petits bois.
func _build_window(origin: Vector3, rot_y: float, a0: float, a1: float, y0: float, y1: float, double: bool) -> void:
	var g := Node3D.new()
	g.position = origin
	g.rotation.y = rot_y
	add_child(g)
	var d := .4
	var cx := (a0 + a1) / 2
	var cy := (y0 + y1) / 2
	var ww := a1 - a0
	var wh := y1 - y0
	var frame := Mk.mat(Mk.c(0x5a3a22), .6, 0.0, {"map": Mk.walnut_tex()})
	# tableau (épaisseur du mur)
	Mk.mi(Mk.box(Vector3(ww, .02, d)), frame, Vector3(cx, y1 + .01, d / 2), g)
	Mk.mi(Mk.box(Vector3(ww, .02, d)), frame, Vector3(cx, y0 - .01, d / 2), g)
	for x in [a0 - .01, a1 + .01]:
		Mk.mi(Mk.box(Vector3(.02, wh, d)), frame, Vector3(x, cy, d / 2), g)
	# encadrement côté régie
	var t := .07
	Mk.mi(Mk.rounded_box(Vector3(ww + 2 * t, t, .04), .008, frame, 2), null, Vector3(cx, y1 + t / 2, -.02), g)
	Mk.mi(Mk.rounded_box(Vector3(ww + 2 * t, t, .04), .008, frame, 2), null, Vector3(cx, y0 - t / 2 + .02, -.02), g)
	for x in [a0 - t / 2, a1 + t / 2]:
		Mk.mi(Mk.rounded_box(Vector3(t, wh + 2 * t, .04), .008, frame, 2), null, Vector3(x, cy, -.02), g)
	var glass := Mk.mat(Mk.c(0x0c0c0c), .04, 0.0, {"alpha": .1, "clearcoat": 1.0, "cull_off": true})
	if double:
		var g1 := Mk.mi(Mk.quad(ww, wh), glass, Vector3(cx, cy, .06), g)
		g1.rotation.x = .09
		Mk.mi(Mk.quad(ww, wh), glass, Vector3(cx, cy, d - .03), g)
	else:
		# fenêtre à guillotine à petits bois, côté rue + appui intérieur
		var sash := Mk.mat(Mk.c(0x3a2818), .55)
		var gz := d - .08
		Mk.mi(Mk.quad(ww, wh), glass, Vector3(cx, cy, gz), g)
		Mk.mi(Mk.box(Vector3(ww, .05, .05)), sash, Vector3(cx, cy, gz), g)
		for k in [1, 2]:
			Mk.mi(Mk.box(Vector3(.025, wh, .03)), sash, Vector3(a0 + ww * k / 3.0, cy, gz), g)
		Mk.mi(Mk.box(Vector3(ww, .022, .03)), sash, Vector3(cx, y0 + wh * .25, gz), g)
		Mk.mi(Mk.box(Vector3(ww, .022, .03)), sash, Vector3(cx, y0 + wh * .75, gz), g)
		Mk.mi(Mk.rounded_box(Vector3(ww + .2, .03, .16), .006, frame, 2), null, Vector3(cx, y0 - .015, -.05), g)


## Bureau en L façon meuble de régie : plateau, rebord cuir devant la console, caissons à tiroirs,
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
	# rebord rembourré en cuir noir (façon console) devant la console
	var arm_y := DESK_TOP - .03
	Mk.mi(Mk.rounded_box(Vector3(1.9, .075, .11), .035, _leather(1.9), 4), null, Vector3(1.72, arm_y, -1.03), self)
	# caissons sous le bureau principal (façades tournées vers -Z, vers le fauteuil)
	_place(_cabinet(.52, h, .9, "drawers"), Vector3(.33, 0, -.97), PI)
	_place(_cabinet(.5, h, .9, "doors"), Vector3(.85, 0, -.97), PI)
	_place(_cabinet(.54, h, .9, "rack"), Vector3(2.45, 0, -.97), PI)
	_place(_cabinet(.34, h, .9, "drawers"), Vector3(2.89, 0, -.97), PI)
	# fond de l'espace pour les jambes
	Mk.mi(Mk.box(Vector3(1.08, h, .02)), _wood, Vector3(1.64, h / 2, -.05), self)
	# meubles sous le retour (façades tournées vers -X, vers le fauteuil)
	_place(_cabinet(.8, h, .5, "doors"), Vector3(3.07, 0, -1.42), -PI / 2)
	_place(_cabinet(.5, h, .5, "drawers"), Vector3(3.07, 0, -2.07), -PI / 2)
	# joues profilées façon console
	var side := PackedVector2Array([Vector2(0, 0), Vector2(.93, 0), Vector2(.93, .1), Vector2(1.0, h - .02), Vector2(1.0, h), Vector2(0, h)])
	var cheek := Mk.mi(Mk.prism(side, .04), _wood, Vector3(.07, 0, 0), self)
	cheek.rotation.y = PI / 2
	var side2 := PackedVector2Array([Vector2(0, 0), Vector2(.5, 0), Vector2(.5, .1), Vector2(.56, h - .02), Vector2(.56, h), Vector2(0, h)])
	var c2 := Mk.mi(Mk.prism(side2, .04), _wood, Vector3(ROOM.x - .01, 0, -2.37), self)
	c2.rotation.y = PI


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
	# moulure basse (quart-de-rond) au-dessus de la plinthe en retrait
	var mold := Mk.mi(Mk.prism(PackedVector2Array([Vector2(0, 0), Vector2(.016, 0), Vector2(.014, .008), Vector2(.008, .014), Vector2(0, .016)]), w), _wood, Vector3(w / 2, kick - .004, 0), g)
	mold.rotation.y = -PI / 2
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
				if i == n - 1:
					_keyhole(g, brass, Vector3(0, cy - dh * .2, .0265))
		"doors":
			var gap := .006
			var dw := (iw - 3 * gap) / 2
			for i in 2:
				var cx := -iw / 2 + gap + dw / 2 + i * (dw + gap)
				Mk.mi(Mk.rounded_box(Vector3(dw, fh - .03 - 2 * gap, .022), .004, _wood, 2), null, Vector3(cx, kick + (fh - .03) / 2, .011), g)
				# moulure de porte
				Mk.mi(Mk.rounded_box(Vector3(dw - .08, fh - .13, .008), .006, _wood, 3), null, Vector3(cx, kick + (fh - .03) / 2, .025), g)
				var side := 1 if i == 0 else -1
				var knob := Mk.mi(Mk.sphere(.012, 16, 8), brass, Vector3(cx + (dw / 2 - .04) * side, kick + fh * .62, .034), g)
				knob.scale = Vector3(1, 1, .8)
				var rose := Mk.mi(Mk.cyl(.012, .012, .002, 16), brass, Vector3(cx + (dw / 2 - .04) * side, kick + fh * .62, .0235), g)
				rose.rotation.x = PI / 2
				# charnières (côté opposé à la poignée)
				for hy in [kick + .07, kick + fh - .1]:
					Mk.mi(Mk.cyl(.0045, .0045, .045, 10), brass, Vector3(cx - (dw / 2 + .002) * side, hy, .024), g)
				if i == 0:
					_keyhole(g, brass, Vector3(cx + (dw / 2 - .04) * side, kick + fh * .52, .0235))
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
			for ui in 64:  # on reprend la liste en boucle jusqu'en bas de la baie
				var u: Array = units[ui % units.size()]
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


## Entrée de serrure en laiton (rosace + trou de clé).
func _keyhole(g: Node3D, m: Material, at: Vector3) -> void:
	var r := Mk.mi(Mk.rounded_box(Vector3(.022, .032, .002), .006, m, 2), null, at, g)
	r.name = "Keyhole"
	var hole := Mk.mi(Mk.cyl(.0028, .0028, .001, 10), Mk.mat(Mk.c(0x050403), 1.0), at + Vector3(0, .004, .0012), g)
	hole.rotation.x = PI / 2
	Mk.mi(Mk.box(Vector3(.0018, .007, .001)), Mk.mat(Mk.c(0x050403), 1.0), at + Vector3(0, -.001, .0012), g)


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


# ---------------------------------------------------------------- intégration : câbles
## Chaque machine est vraiment branchée : câbles qui partent de l'arrière et descendent derrière le
## bureau (vers la baie de patch de la console), un peu de mou sur le plateau.
func _module_cables() -> void:
	var black := Mk.mat(Mk.c(0x0e0e0e), .5)
	var grey := Mk.mat(Mk.c(0x3a3a3c), .55)
	var y := DESK_TOP + .006
	# accordeur 808 -> derrière le retour
	Mk.mi(Mk.tube([tuner.to_global(Vector3(0, .05, -.1)), Vector3(3.45, y, -.4), Vector3(3.56, y, -.2), Vector3(3.58, .5, -.15)], .004, 24, 6), black, Vector3.ZERO, self)
	Mk.mi(Mk.tube([tuner.to_global(Vector3(.06, .04, -.1)), Vector3(3.4, y, -.3), Vector3(3.2, y, -.08), Vector3(2.95, y, -.05), Vector3(2.6, y + .05, -.04)], .003, 30, 6), grey, Vector3.ZERO, self)
	# analyseur -> vers la console
	Mk.mi(Mk.tube([analyzer.to_global(Vector3(0, .05, -.16)), Vector3(.3, y, -.12), Vector3(.6, y, -.06), Vector3(.88, y + .03, -.1)], .004, 24, 6), black, Vector3.ZERO, self)
	# synthé mural : câble qui descend le long du mur jusqu'au retour
	Mk.mi(Mk.tube([freq.to_global(Vector3(.3, -.02, -.05)), Vector3(ROOM.x - .03, 1.05, -1.5), Vector3(ROOM.x - .02, y + .02, -1.62), Vector3(3.48, y, -1.7), Vector3(3.4, y, -1.9)], .004, 30, 6), black, Vector3.ZERO, self)
	# rouleau de gaffer et étiquettes de scotch sur le bord du bureau
	var gaff := Mk.mat(Mk.c(0x1a1a1a), .7)
	var roll := Mk.mi(Mk.torus_ring(.045, .022), gaff, Vector3(3.36, y + .02, -1.1), self)
	roll.scale = Vector3(1, .9, 1)
	var tape := Mk.mat(Mk.c(0xe8e0c8), .8)
	for i in 5:
		Mk.mi(Mk.box(Vector3(.06, .001, .018)), tape, Vector3(.95 + i * .36, DESK_TOP + .001, -.985), self)


# ---------------------------------------------------------------- mur du fond : racks et étagères
## De droite à gauche (vu du fauteuil retourné) : étagère à disques, comptoir avec étagères à bandes
## (place des futures machines de labo : détecteur d'accords, machine vidéo), tour de rack 19".
func _build_back_units() -> void:
	var zb := -ROOM.z
	# étagère à disques : 2 x 4 cases, vinyles vus par la tranche
	var shelf := Node3D.new()
	shelf.name = "RecordShelf"
	shelf.position = Vector3(1.05, 0, zb + .2)
	add_child(shelf)
	var sw := .98
	var sh := 1.86
	var sd := .38
	var t := .025
	for sx in [-1, 1]:
		Mk.mi(Mk.box(Vector3(t, sh, sd)), _wood, Vector3(sx * (sw / 2 - t / 2), sh / 2, 0), shelf)
	Mk.mi(Mk.box(Vector3(t, sh - .06, sd - .01)), _wood, Vector3(0, sh / 2, 0), shelf)
	for k in 5:
		var y := .06 + k * (sh - .06 - t) / 4.0
		Mk.mi(Mk.box(Vector3(sw, t, sd)), _wood, Vector3(0, y + t / 2, 0), shelf)
	Mk.mi(Mk.box(Vector3(sw - .02, .06, .02)), Mk.mat(Mk.c(0x120c08), .7), Vector3(0, .03, sd / 2 - .03), shelf)
	var cell_h := (sh - .06 - t) / 4.0 - t
	for row in 4:
		for col in 2:
			var cxx := (col - .5) * (sw / 2 - t / 2)
			var y0 := .06 + t + row * (cell_h + t)
			var fill := .55 + Tex.rng(row * 7 + col).randf() * .43
			var cw := (sw / 2 - t * 1.5) * fill
			var recs := Mk.mi(Mk.box(Vector3(cw, .315, .31)), _record_spines(row * 2 + col), Vector3(cxx - (sw / 2 - t * 1.5 - cw) / 2, y0 + .158, .02), shelf)
			recs.name = "Records"
			if fill < .8:  # quelques disques penchés au bout de la rangée
				var lean := Mk.mi(Mk.box(Vector3(.006, .315, .31)), Mk.mat(Mk.c([0xd8a030, 0x2a4a7a, 0xb3241a][row % 3]), .7), Vector3(cxx - (sw / 2 - t * 1.5 - cw) / 2 + cw / 2 + .04, y0 + .15, .02), shelf)
				lean.rotation.z = -.28
	# comptoir central (dessus libre pour les futures machines) + étagères à bandes au-dessus
	var counter := _cabinet(1.0, .86, .5, "doors")
	_place(counter, Vector3(2.12, 0, zb + .5), 0.0)
	Mk.mi(Mk.rounded_box(Vector3(1.04, .035, .54), .008, _wood, 2), null, Vector3(2.12, .86 + .017, zb + .27), self)
	var brk := Mk.mat(Mk.c(0x2a2a2a), .4, .7)
	for y in [1.42, 1.78]:
		Mk.mi(Mk.rounded_box(Vector3(1.0, .025, .26), .004, _wood, 2), null, Vector3(2.12, y, zb + .13), self)
		for x in [1.72, 2.52]:
			Mk.mi(Mk.box(Vector3(.015, .12, .2)), brk, Vector3(x, y - .07, zb + .11), self)
		var r := Tex.rng(int(y * 10))
		var x := 1.66
		while x < 2.55:
			var bw := .03 + r.randf() * .03
			var box := Mk.mi(Mk.box(Vector3(bw, .19, .19)), _tape_box_mat(int(r.randi() % 4)), Vector3(x + bw / 2, y + .0125 + .095, zb + .12), self)
			box.rotation.y = r.randf_range(-.04, .04)
			x += bw + .004 + (0.08 if r.randf() < .12 else 0.0)
	# tour de rack 19" pleine hauteur
	_place(_cabinet(.6, 1.74, .5, "rack"), Vector3(3.08, 0, zb + .5), 0.0)
	Mk.mi(Mk.rounded_box(Vector3(.62, .03, .52), .006, _wood, 2), null, Vector3(3.08, 1.755, zb + .25), self)


## Tranches de vinyles serrés : bandes de couleurs et de largeurs variées.
func _record_spines(seed: int) -> StandardMaterial3D:
	var tex := Tex.canvas(512, 256, func(ci, w, h):
		var r := Tex.rng(500 + seed)
		var pal := [0x1a1a1a, 0xe8e0d0, 0xb3241a, 0x2a4a7a, 0xd8a030, 0x3a6a3a, 0x8a3a6a, 0xc86a2a, 0x5a5a5a, 0xf0d070]
		var x := 0.0
		while x < w:
			var bw := 3.0 + r.randf() * 9.0
			var c := Mk.c(pal[r.randi() % pal.size()]).darkened(r.randf() * .35)
			ci.draw_rect(Rect2(x, 0, bw, h), c)
			ci.draw_rect(Rect2(x + bw - 1, 0, 1, h), Color(0, 0, 0, .55))
			if r.randf() < .3:
				ci.draw_rect(Rect2(x + 1, h * r.randf_range(.2, .6), bw - 2, h * .12), Color(1, 1, 1, .5))
			x += bw
		Tex.grime(ci, w, h, 501 + seed, 1.5))
	return Mk.mat(Color.WHITE, .75, 0.0, {"map": tex})


var _tape_mats := {}


## Boîte de bande (tranche) : carton beige, orange ou rouge avec étiquette manuscrite.
func _tape_box_mat(k: int) -> StandardMaterial3D:
	if _tape_mats.has(k):
		return _tape_mats[k]
	var cols := [0xd8c8a0, 0xc86a2a, 0x8a2a1a, 0xe8e0c8]
	var tex := Tex.canvas(128, 256, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(cols[k]))
		ci.draw_rect(Rect2(w * .15, h * .3, w * .7, h * .35), Mk.c(0xf2ead8))
		for i in 3:
			ci.draw_line(Vector2(w * .22, h * (.38 + i * .09)), Vector2(w * (.5 + .25 * ((k + i) % 2)), h * (.38 + i * .09)), Color(.1, .1, .3, .7), 2.0)
		Tex.grime(ci, w, h, 600 + k, 2))
	var m := Mk.mat(Color.WHITE, .85, 0.0, {"map": tex})
	_tape_mats[k] = m
	return m


# ---------------------------------------------------------------- mur droit : pupitre près de la vitre
## Pupitre en bois à plateau incliné, tourné vers le fauteuil : la place du futur carnet de Splits.
func _build_lectern() -> void:
	var g := Node3D.new()
	g.name = "Lectern"
	g.position = Vector3(.42, 0, -2.25)
	g.rotation.y = PI / 2 - .25  # plateau tourné vers le fauteuil (+X)
	add_child(g)
	Mk.mi(Mk.rounded_box(Vector3(.36, .03, .3), .008, _wood, 2), null, Vector3(0, .015, 0), g)
	Mk.mi(Mk.rounded_box(Vector3(.07, .98, .07), .01, _wood, 2), null, Vector3(0, .5, -.02), g)
	var top := Mk.mi(Mk.rounded_box(Vector3(.48, .025, .36), .006, _wood, 2), null, Vector3(0, 1.02, .02), g)
	top.rotation.x = .35
	var lip := Mk.mi(Mk.rounded_box(Vector3(.46, .03, .02), .004, _wood, 2), null, Vector3(0, .97, .19), g)
	lip.rotation.x = .35


# ---------------------------------------------------------------- dehors : rue la nuit (années 70)
## Vue par la fenêtre : trottoir, chaussée mouillée, voitures garées, réverbères au sodium (orange),
## immeuble en face avec fenêtres éclairées et enseigne au néon. Une voiture passe de temps en temps.
var street_car: Node3D


func _build_street() -> void:
	var st := Node3D.new()
	st.name = "Street"
	add_child(st)
	var gy := -.35  # le studio est un peu surélevé (rez-de-chaussée sur cave)
	# chaussée mouillée + trottoirs
	var asphalt := Mk.mat(Mk.c(0x141416), .22, 0.0, {"normal": Mk.noise_tex(.4, 256, 2), "normal_scale": .3})
	Mk.mi(Mk.plane(60, 9), asphalt, Vector3(1.5, gy, 7.0), st)
	var curb := Mk.mat(Mk.c(0x2a2826), .85)
	Mk.mi(Mk.box(Vector3(60, .14, 2.3)), curb, Vector3(1.5, gy + .07, 1.6), st)
	Mk.mi(Mk.box(Vector3(60, .14, 2.6)), curb, Vector3(1.5, gy + .07, 12.8), st)
	# immeuble d'en face
	var fac := _facade_mat()
	var front := Mk.mi(Mk.quad(40, 16), fac, Vector3(1.5, gy + 8, 14.1), st)
	front.rotation.y = PI
	_facade_lights(st, gy)
	# ciel de nuit au-dessus
	var sky := Mk.mi(Mk.quad(120, 50), Mk.mat(Mk.c(0x0a0f1e), 1.0, 0.0, {"unshaded": true}), Vector3(1.5, 20, 40), st)
	sky.rotation.y = PI
	# enseigne au néon (rouge) au rez-de-chaussée en face
	var neon := Tex.canvas(512, 128, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0))
		Tex.silk(ci, "HÔTEL  DU  NORD", w * .5 - 210, h * .68, 56, Color(1, 1, 1)), true)
	var nm := StandardMaterial3D.new()
	nm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	nm.albedo_texture = neon
	nm.albedo_color = Color(2.6, .35, .45)
	var sign := Mk.mi(Mk.quad(4.2, 1.05), nm, Vector3(2.4, gy + 3.4, 14.0), st)
	sign.rotation.y = PI
	var nl := OmniLight3D.new()
	nl.light_color = Color(1, .25, .35)
	nl.light_energy = 1.2
	nl.omni_range = 6.0
	nl.position = Vector3(2.4, gy + 3.2, 13.2)
	st.add_child(nl)
	# réverbères au sodium (orange) des deux côtés
	for p in [Vector3(-1.2, gy + .14, 2.3), Vector3(5.6, gy + .14, 2.3), Vector3(2.2, gy + .14, 12.0)]:
		_street_lamp(st, p, p.z > 6)
	# voitures garées (berlines 70s)
	_car(st, Vector3(-.6, gy, 3.4), 0.0, Mk.c(0x2e3a28))
	_car(st, Vector3(4.4, gy, 3.4), 0.0, Mk.c(0x6a4a2a))
	_car(st, Vector3(1.0, gy, 11.3), PI, Mk.c(0xc8b890))
	street_car = _car(st, Vector3(-20, gy, 6.2), 0.0, Mk.c(0x7a1a14), true)


func _street_lamp(parent: Node3D, at: Vector3, far: bool) -> void:
	var g := Node3D.new()
	g.position = at
	if far:
		g.rotation.y = PI
	parent.add_child(g)
	var pole := Mk.mat(Mk.c(0x2a2c2a), .5, .6)
	Mk.mi(Mk.cyl(.07, .1, 5.0, 12), pole, Vector3(0, 2.5, 0), g)
	Mk.mi(Mk.tube([Vector3(0, 4.9, 0), Vector3(0, 5.25, .4), Vector3(0, 5.2, 1.2)], .05, 12, 8), pole, Vector3.ZERO, g)
	Mk.mi(Mk.rounded_box(Vector3(.3, .12, .55), .04, pole, 2), null, Vector3(0, 5.16, 1.3), g)
	var bulb := StandardMaterial3D.new()
	bulb.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bulb.albedo_color = Color(2.4, 1.05, .25)
	Mk.mi(Mk.box(Vector3(.24, .03, .45)), bulb, Vector3(0, 5.09, 1.3), g)
	var l := SpotLight3D.new()
	l.light_color = Color(1.0, .55, .18)
	l.light_energy = 1.4
	l.spot_range = 8.0
	l.spot_angle = 60.0
	l.spot_angle_attenuation = .8
	l.position = Vector3(0, 5.0, 1.3)
	l.rotation.x = -PI / 2
	g.add_child(l)


## Berline 70s : caisse longue, pavillon, vitres sombres, chromes, phares, roues. Repère : avant vers +X.
func _car(parent: Node3D, at: Vector3, rot: float, col: Color, moving := false) -> Node3D:
	var g := Node3D.new()
	g.position = at
	g.rotation.y = rot
	parent.add_child(g)
	var paint := Mk.mat(col, .3, .2, {"clearcoat": 1.0, "clearcoat_rough": .1})
	var glass := Mk.mat(Mk.c(0x0a0c10), .05, 0.0, {"clearcoat": 1.0})
	var chrome := Mk.chrome_mat()
	var tyre := Mk.mat(Mk.c(0x0c0c0c), .8)
	Mk.mi(Mk.rounded_box(Vector3(4.7, .5, 1.8), .09, paint, 3), null, Vector3(0, .55, 0), g)
	Mk.mi(Mk.rounded_box(Vector3(2.3, .48, 1.62), .1, paint, 3), null, Vector3(-.25, 1.02, 0), g)
	for sz in [-1, 1]:
		Mk.mi(Mk.box(Vector3(2.1, .34, .01)), glass, Vector3(-.25, 1.04, sz * .815), g)
	for sx in [-1, 1]:
		var ws := Mk.mi(Mk.box(Vector3(.01, .36, 1.48)), glass, Vector3(-.25 + sx * 1.16, 1.03, 0), g)
		ws.rotation.z = sx * -.5
		Mk.mi(Mk.rounded_box(Vector3(.1, .12, 1.86), .04, chrome, 2), null, Vector3(sx * 2.36, .42, 0), g)
	for wx in [-1.45, 1.45]:
		for sz in [-1, 1]:
			var w := Mk.mi(Mk.cyl(.33, .33, .22, 20), tyre, Vector3(wx, .33, sz * .8), g)
			w.rotation.x = PI / 2
			var hub := Mk.mi(Mk.cyl(.16, .16, .23, 16), chrome, Vector3(wx, .33, sz * .8), g)
			hub.rotation.x = PI / 2
	var head := StandardMaterial3D.new()
	head.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	head.albedo_color = Color(3.0, 2.6, 1.8) if moving else Color(.5, .45, .35)
	var tail := StandardMaterial3D.new()
	tail.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tail.albedo_color = Color(3.0, .2, .1) if moving else Color(.25, .02, .02)
	for sz in [-1, 1]:
		var hl := Mk.mi(Mk.cyl(.09, .09, .03, 16), head, Vector3(2.36, .62, sz * .62), g)
		hl.rotation.z = PI / 2
		Mk.mi(Mk.box(Vector3(.03, .1, .28)), tail, Vector3(-2.36, .62, sz * .6), g)
	if moving:
		var l := SpotLight3D.new()
		l.light_color = Color(1, .9, .7)
		l.light_energy = 2.5
		l.spot_range = 14.0
		l.spot_angle = 30.0
		l.position = Vector3(2.4, .6, 0)
		l.rotation.y = -PI / 2
		g.add_child(l)
	return g


## Immeuble d'en face : enduit sombre à peine visible, fenêtres sombres ; les fenêtres éclairées et la
## vitrine du bar sont des petits panneaux lumineux posés devant (voir _facade_lights).
func _facade_mat() -> StandardMaterial3D:
	var alb := Tex.canvas(1024, 512, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x2a221e))
		var r := Tex.rng(910)
		for i in 2500:
			ci.draw_rect(Rect2(r.randf() * w, r.randf() * h, 3, 3), Color(0, 0, 0, .15) if r.randf() > .5 else Color(1, .9, .8, .04))
		for row in 5:
			for col in 14:
				var x: float = 30.0 + col * (w - 60) / 14.0
				var y := 40.0 + row * 90.0
				ci.draw_rect(Rect2(x, y, 44, 62), Color(.03, .035, .045))
				ci.draw_rect(Rect2(x - 3, y + 62, 50, 5), Mk.c(0x3a302a)))
	var m := Mk.mat(Color.WHITE, .9, 0.0, {"map": alb})
	m.emission_enabled = true
	m.emission = Mk.c(0x2a2420)
	m.emission_energy_multiplier = .25
	return m


## Fenêtres allumées et vitrine du bar : panneaux lumineux devant la façade (mêmes cases que la texture).
func _facade_lights(parent: Node3D, gy: float) -> void:
	var r := Tex.rng(911)
	var fw := 40.0
	var fh := 16.0
	for row in 5:
		for col in 14:
			if r.randf() > .3:
				continue
			var warm := Color(1.0, .7, .36).lerp(Color(.7, .8, 1.0), r.randf() * .35)
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = warm * (.55 + r.randf() * .5)
			# coordonnées texture (1024 x 512) -> mètres sur la façade (vue de la rue, x inversé)
			var px := 30.0 + col * (1024 - 60) / 14.0 + 22
			var py := 40.0 + row * 90.0 + 31
			var x: float = 1.5 + fw / 2 - px / 1024.0 * fw
			var y: float = gy + fh - py / 512.0 * fh
			var q := Mk.mi(Mk.quad(44.0 / 1024.0 * fw, 62.0 / 512.0 * fh), m, Vector3(x, y, 14.05), parent)
			q.rotation.y = PI
			if r.randf() < .5:  # rideau à moitié tiré
				var cm := StandardMaterial3D.new()
				cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				cm.albedo_color = m.albedo_color * .45
				var c := Mk.mi(Mk.quad(.7, 62.0 / 512.0 * fh), cm, Vector3(x + .5, y, 14.04), parent)
				c.rotation.y = PI
	# vitrine du bar sous l'enseigne
	var vm := StandardMaterial3D.new()
	vm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vm.albedo_color = Color(1.2, .6, .28)
	var v := Mk.mi(Mk.quad(6.0, 1.8), vm, Vector3(2.4, gy + 1.2, 14.05), parent)
	v.rotation.y = PI


# ---------------------------------------------------------------- lumières
## Ambiance tamisée : quelques encastrés au plafond, rasants doux sur le liège, remplissage faible.
## Les machines sont mises en avant par les spots des rails (voir _build_module_spots).
func _build_lights() -> void:
	var can_mat := Mk.glow(Mk.c(0xffc68a), 4.0)
	var trim := Mk.mat(Mk.c(0x2a2420), .4, .6)
	for p in [Vector3(1.0, 0, -2.0), Vector3(2.6, 0, -2.0), Vector3(1.8, 0, -3.4)]:
		var ring := Mk.mi(Mk.cyl(.05, .05, .01, 24), trim, Vector3(p.x, ROOM.y - .005, p.z), self)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var bulb := Mk.mi(Mk.disc(.035, 24), can_mat, Vector3(p.x, ROOM.y - .011, p.z), self)
		bulb.rotation.x = PI
		var sp := SpotLight3D.new()
		sp.light_color = Mk.c(0xffdcb8)
		sp.light_energy = 1.1
		sp.spot_range = 3.2
		sp.spot_angle = 38.0
		sp.spot_angle_attenuation = 1.4
		sp.shadow_enabled = true
		_aim(sp, Vector3(p.x, ROOM.y - .02, p.z), Vector3(p.x - .05, 0, p.z + .05))
		add_child(sp)
	# rasants doux sur le liège des murs latéraux
	for w in [[.4, -1.0, 0.0], [ROOM.x - .4, -2.9, ROOM.x]]:
		var ww := SpotLight3D.new()
		ww.light_color = Mk.c(0xffcfa0)
		ww.light_energy = .45
		ww.spot_range = 2.2
		ww.spot_angle = 45.0
		_aim(ww, Vector3(w[0], ROOM.y - .05, w[1]), Vector3(w[2], 1.2, w[1]))
		add_child(ww)
	# remplissage doux au centre
	var fill := OmniLight3D.new()
	fill.light_color = Mk.c(0xffe0c8)
	fill.light_energy = .35
	fill.omni_range = 5.0
	fill.position = Vector3(1.8, 2.0, -2.1)
	add_child(fill)


# ---------------------------------------------------------------- cabine de prise (vue floue à travers la vitre)
func _build_booth(dark_wood: Material) -> void:
	var b := Node3D.new()
	b.name = "Booth"
	# la cabine est construite dans son propre repère puis tournée derrière la vitre du mur droit (côté -X)
	b.transform = Transform3D(Basis(Vector3.UP, PI / 2), BOOTH_ORIGIN)
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
## Vue d'ensemble = la tête de l'ingé dans le fauteuil : on tourne à 360° (look_yaw, look_pitch,
## pilotés par main.gd). yaw 0 = on regarde la console (+Z) ; +PI/2 = le coin compo (+X).
var look_yaw := 0.0
var look_pitch := -.12


func look_dir(yaw: float, pitch: float) -> Vector3:
	return Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))


## Cap (yaw) pour regarder un point depuis le fauteuil.
func yaw_to(p: Vector3) -> float:
	return atan2(p.x - EYE.x, p.z - EYE.z)


## Renvoie [position, point visé] : vue depuis le fauteuil, ou gros plan sur un module.
func shot_pose(shot: String, cam: Camera3D, aspect: float) -> Array:
	if shot == "export":
		return _via(export, Vector3(0, 0, .03), Vector3(0, 0, 1), Export7080.BW / 2, Export7080.BH / 2, cam, aspect, 1.12)
	if shot == "freq":
		return _via(freq, Vector3(0, Freq7080.H, 0), Vector3(0, 1, .7), Freq7080.L / 2, Freq7080.D / 2, cam, aspect, 1.12)
	if shot == "analyse":
		return _via(analyzer, Vector3(0, .08, .02), Vector3(0, 1, .9), Analyzer7080.W / 2, Analyzer7080.D / 2, cam, aspect, 1.15)
	if shot == "tuner":
		return _via(tuner, Vector3(0, Tuner7080.H / 2, 0), Vector3(0, .25, 1), Tuner7080.W / 2, Tuner7080.H / 2, cam, aspect, 1.25)
	if shot == "fax":
		return _via(fax, Vector3(0, Fax7080.BASE_H, .06), Vector3(0, 1, .85), Fax7080.W / 2 + .02, Fax7080.D / 2 + .08, cam, aspect, 1.1)
	if shot == "tempo":
		return _via(tempo.deck, Vector3(0, 0, .0), Vector3(0, 1, .55), Tempo7080.W / 2, tempo.plen / 2, cam, aspect, 1.08)
	if DEBUG_SHOTS.has(shot):
		var v: Array = DEBUG_SHOTS[shot]
		return [EYE, EYE + look_dir(v[0], v[1]) * 2.5]
	return [EYE, EYE + look_dir(look_yaw, look_pitch) * 2.5]


## Plans de contrôle (captures de dev) : [yaw, pitch] depuis le fauteuil.
const DEBUG_SHOTS := {
	"v_front": [0.0, -.15],
	"v_left": [PI / 2, -.12],
	"v_back": [PI, -.08],
	"v_right": [-PI / 2, -.08],
	"v_up": [.6, .55],
	"v_window": [.05, .05],
	"v_fax": [1.25, -.45],
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


## Objectif : champ vertical fixe en 16:9 ; on garde le champ horizontal quand la fenêtre est plus étroite.
func setup_camera(cam: Camera3D, aspect: float) -> void:
	if aspect >= 16.0 / 9.0:
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		cam.fov = rad_to_deg(CAM_YFOV)
	else:
		cam.keep_aspect = Camera3D.KEEP_WIDTH
		cam.fov = rad_to_deg(2.0 * atan(tan(CAM_YFOV / 2.0) * 16.0 / 9.0))


## Appelé quand on change de plan : les modules sont prévenus.
func on_shot(shot: String, _cam: Camera3D, _aspect: float) -> void:
	for m in modules.values():
		if m.has_method("on_shot_changed"):
			m.on_shot_changed(shot)


func animate(t: float, dt: float, reduced: bool) -> void:
	_animate_spots(dt)
	# une voiture passe dans la rue toutes les ~25 s
	if street_car and not reduced:
		var cyc := fmod(t, 25.0) / 25.0
		street_car.position.x = lerpf(-22.0, 26.0, cyc * 1.6) if cyc < .62 else 40.0
	# les enceintes de proximité restent visibles autour de l'accordeur
	for m in modules.values():
		m.animate(t, dt, reduced)
