class_name Studio7080
extends Node3D
## Studio 70/80, régie pro — vraie control room de 5 x 6 m, 2,6 m sous plafond. On est assis dans le
## fauteuil au centre et on tourne la tête à 360° (glisser). Repère : on regarde +Z vers la console ;
## +X est à gauche, x = 0 à droite.
##   · devant (mur z = 0)        : grand meuble de console en bois (racks encastrés, ailes inclinées)
##                                 avec Tempo et Analyse ; fenêtre sur la rue (la nuit), grosses enceintes
##   · gauche (mur x = 5)        : coin composition : bureau producteur à racks (accordeur 808, fax),
##                                 synthé Fréquences au mur, tour de racks des boîtes à rythmes
##   · derrière (mur z = -6)     : magnéto multipiste, canapé cuir sous le diffuseur à lattes, télé,
##                                 Les Paul + Marshall, magnéto à bandes
##   · droite (mur x = 0)        : tableau Export, vitre de la cabine de prise, pupitre (futur carnet Splits)
##
## Ambiance : lambris de noyer, moquette orange à poils longs, bois chaud, lumière tungstène tamisée.

const ROOM := Vector3(5.0, 2.6, 6.0)         # x 0..5, y 0..2,6, z -6..0
const WIN := {"z0": -4.35, "z1": -2.75, "y0": 1.0, "y1": 1.85}       # fenêtre sur rue (mur droit)
const BWIN := {"x0": 1.35, "x1": 3.65, "y0": 1.02, "y1": 1.98}        # vitre de la cabine (mur avant)
const DOOR := {"x": .82, "w": .92, "h": 2.08}                          # porte capitonnée (mur du fond)
const SOFFITS := [.72, 4.28]                                           # enceintes encastrées (x)
const DESK_TOP := .818
const DESK_T := .06
const MAIN_DESK := [1.22, 3.78, -1.35, -.06]   # [x0, x1, z0, z1] meuble de console
const SIDE_DESK := [4.35, 4.97, -3.95, -1.97]  # bureau producteur contre le mur de gauche
const CONSOLE_X := 2.5                       # console de mixage posée sur le meuble
const CONSOLE_Z := -.85
const CONSOLE_L := 2.2
const WINGS := {-1: Vector3(.65, 0, -1.32), 1: Vector3(4.35, 0, -1.32)}  # ailes inclinées du meuble
const WING_W := .85
const WING_D := .8
const WAINSCOT := 1.0                        # hauteur des lattes
## Tête de l'ingé assis dans le fauteuil : pivot de la caméra 360°
const SEAT := Vector3(2.5, 0, -2.15)
const EYE := Vector3(2.5, 1.17, -2.25)
const CAM_YFOV := 1.0                         # radians (≈ 57°), image 16:9

## Cabine (construite dans son repère d'origine, puis tournée derrière la vitre du mur droit)
const BOOTH := {"x0": -2.6, "x1": 1.4, "z0": -1.14, "z1": -3.4, "ceil": 2.3}
const BOOTH_ORIGIN := Vector3(.74, .78, -3.6)
const B_FLOOR := -0.78
const B_WOOD_TOP := 0.44

## Plans : la vue 360° depuis le fauteuil, puis un gros plan par module.
var order: Array = ["overview", "tempo", "tuner", "analyse", "freq", "export", "fax", "beats", "splits"]
## Modules jouables : nom -> nœud (on_action, on_drag_start, on_drag, on_wheel, on_key, animate)
var modules := {}
var tempo: Tempo7080
var tuner: Tuner7080
var analyzer: Analyzer7080
var freq: Freq7080
var export: Export7080
var splits: Splits7080
var fax: Fax7080
var beats: Beats7080
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
	_wood = Mk.pbr("dark_wood", .9, {"wear": 0.5, "tint": Mk.c(0xc8a090), "rough": .85, "clearcoat": .35, "clearcoat_rough": .35})
	_build_floor_ceiling()
	_build_front_wall()
	_build_right_wall()
	_build_left_wall()
	_build_back_wall()
	_build_window(Vector3.ZERO, 0.0, BWIN.x0, BWIN.x1, BWIN.y0, BWIN.y1, true)
	_build_window(Vector3.ZERO, -PI / 2, WIN.z0, WIN.z1, WIN.y0, WIN.y1, false)
	add_child(Booth7080.new())
	_build_street()
	_build_soffits()
	_build_door()
	_build_control_desk()
	_build_side_desk()
	_build_back_units()
	_build_lectern()
	_build_ceiling_cloud()
	_build_lights()
	deco = Deco7080.new()
	add_child(deco)
	var walnut := Mk.pbr("dark_wood", .45, {"wear": .5, "tint": Mk.c(0xb07858), "rough": .6, "clearcoat": .45, "clearcoat_rough": .3})
	# --- devant, aile gauche du meuble : Tempo, tourné vers le fauteuil
	tempo = Tempo7080.new(engine, walnut)
	tempo.position = Vector3(CONSOLE_X + CONSOLE_L / 2 + .025 + Tempo7080.W / 2, DESK_TOP, CONSOLE_Z)
	tempo.rotation.y = PI
	add_child(tempo)
	modules["tempo"] = tempo
	# --- devant, aile droite : Analyse (magnéto + écran vert)
	analyzer = Analyzer7080.new(walnut)
	analyzer.position = wing_top(-1)
	analyzer.rotation.y = wing_yaw(-1)
	add_child(analyzer)
	modules["analyse"] = analyzer
	# --- gauche : Accordeur 808 sur le bureau producteur, incliné vers le fauteuil
	tuner = Tuner7080.new(walnut)
	tuner.position = Vector3(4.66, DESK_TOP, -2.2)
	tuner.basis = Basis(Vector3.UP, face_seat(tuner.position)) * Basis(Vector3.RIGHT, -.12)
	add_child(tuner)
	modules["tuner"] = tuner
	# --- gauche : synthé Fréquences sur son support mural au-dessus du bureau producteur
	var steel := Mk.mat(Mk.c(0x2a2a2a), .4, .7)
	for z in [-2.5, -3.0]:
		var arm := Mk.mi(Mk.rounded_box(Vector3(.3, .025, .025), .004, steel, 2), null, Vector3(ROOM.x - .15, 1.3, z), self)
		arm.rotation.z = -.4
		Mk.mi(Mk.rounded_box(Vector3(.02, .16, .04), .004, steel, 2), null, Vector3(ROOM.x - .01, 1.3, z), self)
	freq = Freq7080.new(walnut)
	freq.position = Vector3(ROOM.x - .16, 1.335, -2.75)
	freq.basis = Basis(Vector3.UP, -PI / 2) * Basis(Vector3.RIGHT, .4)
	add_child(freq)
	modules["freq"] = freq
	# --- droite : tableau Export en liège, au mur droit avant la vitre de la cabine
	export = Export7080.new(walnut)
	export.position = Vector3(.034, 1.45, -1.05)  # posé sur les couvre-joints du mur
	export.rotation.y = PI / 2
	add_child(export)
	modules["export"] = export
	# --- gauche : Fax d'accords au bout du bureau producteur, façade (et feuille) vers le fauteuil
	fax = Fax7080.new(walnut)
	fax.position = Vector3(4.64, DESK_TOP, -3.35)
	fax.rotation.y = face_seat(fax.position)
	add_child(fax)
	modules["fax"] = fax
	# --- gauche, au fond : tour de racks sur roulettes avec les boîtes à rythmes
	beats = Beats7080.new(fax)
	beats.position = Vector3(4.62, 0, -4.45)
	beats.rotation.y = face_seat(beats.position)
	add_child(beats)
	modules["beats"] = beats


## Cap qui tourne la façade (+Z local) d'un objet posé en p vers le fauteuil.
func face_seat(p: Vector3) -> float:
	return atan2(SEAT.x - p.x, SEAT.z - p.z)


func _ready() -> void:
	_module_cables()
	var dr := Dressing7080.new(self)
	add_child(dr)
	dr.build()
	_build_module_spots()
	_build_daylight()
	if not OS.has_environment("REEL_NOTUNE"):
		_tune_render.call_deferred()


## Fluidité (sans changement visible) : les toutes petites pièces (vis, coutures, LED, clous…) ne
## projettent plus d'ombre et s'effacent en fondu quand on est loin (elles font moins d'un pixel) ;
## les zones cliquables invisibles ne sont plus dessinées (leurs boîtes de clic restent).
func _tune_render() -> void:
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		stack.append_array(nd.get_children())
		if not nd is MeshInstance3D:
			continue
		var m := nd as MeshInstance3D
		if m.mesh == null:
			continue
		if _invisible_zone(m):
			m.visible = false
			continue
		var bb: AABB = m.global_transform * m.get_aabb()
		var ext := maxf(bb.size.x, maxf(bb.size.y, bb.size.z))
		if ext < .022:
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if ext < .008:
			m.visibility_range_end = 4.6
			m.visibility_range_end_margin = .5
			m.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	# fusion des ensembles fixes (tout sauf les machines et la voiture qui passe dans la rue)
	var skip: Array = modules.values()
	if street_car:
		skip.append(street_car)
	var before := 0
	var after := 0
	for ch in get_children():
		if OS.has_environment("REEL_NOBAKE"):
			break   # captures de dev en rendu logiciel : la fusion + SDFGI dépasse la mémoire du conteneur
		if ch is Node3D and not skip.has(ch):
			var r := Mk.bake(ch, skip)
			before += r.x
			after += r.y
	if OS.has_environment("REEL_LOWMEM"):
		print("[bake] %d pièces -> %d maillages" % [before, after])


static func _invisible_zone(m: MeshInstance3D) -> bool:
	var mat := m.material_override if m.material_override else m.get_surface_override_material(0)
	if mat == null and m.mesh.get_surface_count() > 0:
		mat = m.mesh.surface_get_material(0)
	if mat is StandardMaterial3D:
		var sm := mat as StandardMaterial3D
		return sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and sm.albedo_color.a <= .001
	return false


# ---------------------------------------------------------------- spots sur les machines
## Rails noirs au plafond, un par zone (devant, gauche, droite, fond), avec des spots alignés. Chaque
## machine a son spot sur le rail de sa zone, braqué sur elle : discret au repos, il monte quand la
## souris passe sur la machine et reste un peu plus fort sur la machine ouverte. D'autres spots du
## rail, très doux, éclairent le décor.
const SPOT_IDLE := .4
const SPOT_HOVER := 8.0
const SPOT_OPEN := 2.5
const RAILS := {  # zone -> [début, fin] (au plafond)
	"front": [Vector3(.45, 0, -.8), Vector3(4.55, 0, -.8)],
	"left": [Vector3(4.15, 0, -1.6), Vector3(4.15, 0, -5.3)],
	"right": [Vector3(.75, 0, -1.4), Vector3(.75, 0, -5.4)],
	"back": [Vector3(.8, 0, -5.2), Vector3(3.8, 0, -5.2)],
}
var module_spots := {}  # module -> {light, lens, level}
var _black_mat: Material


## Zone d'une machine d'après sa position (pour choisir son rail).
func zone_of(p: Vector3) -> String:
	if p.x > 4.2:
		return "left"
	if p.x < .3:
		return "right"
	if p.z < -5.0:
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
const LOOK_FX := true


func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Mk.c(0x0a0604)
	# ciel invisible qui ne sert qu'aux reflets (comme une pièce avec quelques sources chaudes)
	var sky := Sky.new()
	var pano := PanoramaSkyMaterial.new()
	_sky_pano = pano
	pano.panorama = ImageTexture.create_from_image(_reflection_room())
	pano.energy_multiplier = 0.12
	sky.sky_material = pano
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Mk.c(0x403a34)
	env.ambient_light_energy = 0.16
	# éclairage indirect : la lumière rebondit sur les murs, le bois, le tapis (rendu Forward+)
	env.sdfgi_enabled = not OS.has_environment("NOSDFGI")
	env.sdfgi_use_occlusion = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.05
	env.sdfgi_bounce_feedback = 0.6
	env.sdfgi_energy = 1.1
	env.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_100_PERCENT
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.15
	env.tonemap_white = 12.0
	env.ssao_enabled = true
	env.ssao_radius = 0.45
	env.ssao_intensity = 1.2
	env.ssao_detail = 0.8
	env.ssil_enabled = LOOK_FX
	env.ssil_radius = 1.5
	env.ssr_enabled = false
	env.glow_enabled = true  # seulement les LED / écrans (seuil haut), sans voile
	env.glow_intensity = 0.6 if LOOK_FX else 0.35
	env.glow_strength = 1.0
	env.glow_bloom = 0.008 if LOOK_FX else 0.0
	env.glow_hdr_threshold = 1.0 if LOOK_FX else 1.3
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.6)
	env.set_glow_level(4, 0.4)
	env.fog_enabled = LOOK_FX
	env.fog_light_color = Mk.c(0x100c09)
	env.fog_density = 0.015
	env.fog_sky_affect = 0.0
	env.volumetric_fog_enabled = LOOK_FX
	env.volumetric_fog_density = 0.006
	env.volumetric_fog_albedo = Mk.c(0xffe2c4)
	env.volumetric_fog_length = 6.0
	env.volumetric_fog_ambient_inject = 0.0
	env.adjustment_enabled = LOOK_FX
	env.adjustment_saturation = 0.93
	env.adjustment_contrast = 1.07
	if OS.has_environment("REEL_LOWMEM"):
		# captures de dev (rendu logiciel) : moins de mémoire
		env.volumetric_fog_enabled = false
		env.sdfgi_cascades = 1
		env.sdfgi_min_cell_size = 0.07
		env.ssil_enabled = false
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
	return Mk.pbr("wood_planks", 1.4, {"wear": 0.35, "tint": Mk.c(0xa87c60), "rough": .9, "local": false})


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


## Moquette orange à poils longs (shag 70s) : mèches torsadées claires / sombres, relief marqué.
func _carpet_mat() -> StandardMaterial3D:
	var tex := Tex.canvas(1024, 1024, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x8a3410))
		var r := Tex.rng(91)
		for i in 26000:
			var p := Vector2(r.randf() * w, r.randf() * h)
			var k := r.randf()
			var c := Mk.c(0xd8682a).lerp(Mk.c(0x5a1e08), k * k)
			c.a = .55 + r.randf() * .4
			var d := Vector2.from_angle(r.randf() * TAU) * (3.0 + r.randf() * 6.0)
			ci.draw_line(p - d, p + d, c, 2.2 + r.randf() * 2.4, true)
			if r.randf() < .15:
				ci.draw_circle(p + d, 1.6, Mk.c(0xf08a40) * Color(1, 1, 1, .5)))
	var nt := NoiseTexture2D.new()
	nt.width = 1024
	nt.height = 1024
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = 14.0
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_CELLULAR
	fn.frequency = .09
	fn.fractal_octaves = 2
	nt.noise = fn
	var m := Mk.mat(Color.WHITE, 1.0, 0.0, {"map": tex, "normal": nt, "normal_scale": 1.6})
	m.uv1_scale = Vector3(7, 8, 1)
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m


# ---------------------------------------------------------------- pièce
func _build_floor_ceiling() -> void:
	var cx := ROOM.x / 2
	var cz := -ROOM.z / 2
	# moquette murale brun chaud, épaisse (années 70)
	var fl := Mk.mi(Mk.plane(ROOM.x + .1, ROOM.z + .1), _carpet_mat(), Vector3(cx, 0, cz), self)
	fl.name = "Floor"
	# tapis persan sous le fauteuil (tapis de Maxime)
	Props.place(self, "carpet.glb", Vector3(SEAT.x, .004, SEAT.z - .1), PI / 2 + .04, {"scale": .0032, "keep": ["SM_Carpet_01"]})
	# plafond en dalles acoustiques dans une grille
	var ceil := Mk.mi(Mk.plane(ROOM.x + .1, ROOM.z + .1), _ceiling_tiles(), Vector3(cx, ROOM.y, cz), self)
	ceil.rotation.x = PI
	ceil.name = "Ceiling"
	# plinthes sombres au pied des quatre murs
	var base := Mk.mat(Mk.c(0x1a100a), .6)
	Mk.mi(Mk.box(Vector3(.02, .08, ROOM.z)), base, Vector3(.01, .04, cz), self)
	Mk.mi(Mk.box(Vector3(.02, .08, ROOM.z)), base, Vector3(ROOM.x - .01, .04, cz), self)
	Mk.mi(Mk.box(Vector3(ROOM.x, .08, .02)), base, Vector3(cx, .04, -.01), self)
	Mk.mi(Mk.box(Vector3(ROOM.x, .08, .02)), base, Vector3(cx, .04, -ROOM.z + .01), self)


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


## Mur avant (z = 0, face vers -Z) : percé de la fenêtre sur la rue.
func _build_front_wall() -> void:
	var w := Node3D.new()
	w.name = "FrontWall"
	w.rotation.y = PI  # repère local : x = -x monde, normale +Z = -Z monde
	add_child(w)
	_studio_wall(w, -ROOM.x, 0, [-BWIN.x1, -BWIN.x0, BWIN.y0, BWIN.y1], 1)


## Habillage acoustique de régie 70s (repère du mur : x le long du mur, face +Z) :
##   · en bas, lattes de bois verticales sur fond noir (on voit les ombres entre les lattes) ;
##   · lisse en bois ;
##   · au-dessus, toile de jute tendue brun-orangé, coupée par des couvre-joints en bois tous les ~1,2 m ;
##   · corniche. Trou optionnel [a0, a1, y0, y1].
## Mur en lambris de noyer (années 70) : planches verticales de 15 à 20 cm séparées par une rainure
## sombre (vraie géométrie, donc de vraies ombres dans les joints), teinte qui varie un peu d'une planche
## à l'autre. `hole` = [x0, x1, y0, y1] (vitre, fenêtre, porte).
func _studio_wall(w: Node3D, a0: float, a1: float, hole := [], seed := 0) -> void:
	var dark := Mk.mat(Mk.c(0x0a0604), .95)
	var back := []
	if hole.is_empty():
		back = [[a0, 0, a1, ROOM.y]]
	else:
		back = [[a0, 0, hole[0], ROOM.y], [hole[1], 0, a1, ROOM.y], [hole[0], 0, hole[1], hole[2]], [hole[0], hole[3], hole[1], ROOM.y]]
	Mk.mi(_wall_mesh(back), dark, Vector3.ZERO, w)
	var y_lo := .085
	var y_hi := ROOM.y - .09
	# zones à couvrir : [x0, x1, y0, y1]
	var zones := []
	if hole.is_empty():
		zones = [[a0, a1, y_lo, y_hi]]
	else:
		zones = [[a0, hole[0], y_lo, y_hi], [hole[1], a1, y_lo, y_hi]]
		if hole[2] > y_lo + .05:
			zones.append([hole[0], hole[1], y_lo, hole[2]])
		if hole[3] < y_hi - .05:
			zones.append([hole[0], hole[1], hole[3], y_hi])
	var xf := []
	var rr := Tex.rng(700 + seed)
	for zn in zones:
		var L: float = zn[1] - zn[0]
		if L < .02:
			continue
		var n := maxi(1, int(round(L / .18)))
		var bw := L / n
		for k in n:
			var cx: float = zn[0] + bw * (k + .5)
			var h: float = zn[3] - zn[2]
			var t := Transform3D(Basis.from_scale(Vector3(bw - .007, h, .014)), Vector3(cx, zn[2] + h / 2, .007 + rr.randf() * .0015))
			xf.append([t, Color(rr.randf(), rr.randf(), rr.randf(), 0)])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = Mk.box(Vector3.ONE)
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i][0])
		mm.set_instance_custom_data(i, xf[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Panelling"
	mmi.multimesh = mm
	mmi.material_override = _panel_mat()
	w.add_child(mmi)
	_cornice(w, a0, a1)


var _panel: ShaderMaterial


func _panel_mat() -> ShaderMaterial:
	if _panel == null:
		_panel = ShaderMaterial.new()
		_panel.shader = load("res://core/shaders/panel.gdshader")
		var base := "res://assets/textures/ph/fine_grained_wood"
		_panel.set_shader_parameter("albedo_tex", load(base + "_diff.jpg"))
		_panel.set_shader_parameter("normal_tex", load(base + "_nor.jpg"))
		_panel.set_shader_parameter("rough_tex", load(base + "_rough.jpg"))
		_panel.set_shader_parameter("wear_tex", Mk.wear_tex(.4))
		_panel.set_shader_parameter("tint", Mk.c(0xe0a070))
		_panel.set_shader_parameter("scale", 1.3)
	return _panel


var _slat: Material
var _jutes := {}


func _slat_mat() -> Material:
	if _slat == null:
		_slat = Mk.pbr("wood_planks", .9, {"wear": 0.35, "tint": Mk.c(0xb08868), "rough": .8, "clearcoat": .15})
	return _slat


## Toile de jute tendue (Poly Haven hessian), teinte brun-orangé un peu variable d'un mur à l'autre.
func _jute_mat(seed: int) -> Material:
	if not _jutes.has(seed):
		var tints := [0xc87a40, 0xb86a34, 0xc8803c, 0xa86034]
		var m: StandardMaterial3D = Mk.pbr("hessian_230", .5, {"tint": Mk.c(tints[seed % 4]), "rough": 1.0}).duplicate()
		m.normal_scale = 1.4
		_jutes[seed] = m
	return _jutes[seed]


func _cornice(w: Node3D, a0: float, a1: float) -> void:
	Mk.mi(Mk.rounded_box(Vector3(absf(a1 - a0), .09, .06), .006, _wood, 2), null, Vector3((a0 + a1) / 2, ROOM.y - .045, .03), w)


## Mur droit (x = 0, face vers +X) : percé de la vitre de la cabine.
func _build_right_wall() -> void:
	var w := Node3D.new()
	w.name = "RightWall"
	w.rotation.y = PI / 2  # local x = -z monde
	add_child(w)
	_studio_wall(w, 0, ROOM.z, [-WIN.z1, -WIN.z0, WIN.y0, WIN.y1], 2)


## Mur gauche (x = 5, face vers -X) : coin composition.
func _build_left_wall() -> void:
	var w := Node3D.new()
	w.name = "LeftWall"
	w.position = Vector3(ROOM.x, 0, 0)
	w.rotation.y = -PI / 2  # local x = z monde
	add_child(w)
	_studio_wall(w, -ROOM.z, 0, [], 3)


## Mur du fond (z = -6, face vers +Z) : habillage + grand diffuseur à lattes au-dessus du canapé.
func _build_back_wall() -> void:
	var w := Node3D.new()
	w.name = "BackWall"
	w.position = Vector3(0, 0, -ROOM.z)
	add_child(w)
	_studio_wall(w, 0, ROOM.x, [DOOR.x - DOOR.w / 2, DOOR.x + DOOR.w / 2, 0.0, DOOR.h], 0)
	# diffuseur à puits (lattes de profondeurs variées, façon QRD), cadre en bois
	var dx0 := 2.3
	var dx1 := 4.15
	var dy0 := 1.05
	var dy1 := 2.4
	var frame := _wood
	Mk.mi(Mk.box(Vector3(dx1 - dx0, dy1 - dy0, .02)), Mk.mat(Mk.c(0x0a0705), .95), Vector3((dx0 + dx1) / 2, (dy0 + dy1) / 2, .03), w)
	var seq := [0, 1, 4, 9, 5, 3, 3, 5, 9, 4, 1]  # résidus quadratiques (N = 11)
	var n := 26
	var ww := (dx1 - dx0) / n
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Mk.box(Vector3(1, 1, 1))
	mm.instance_count = n
	for i in n:
		var d: float = .04 + seq[i % seq.size()] * .022
		var xf := Transform3D(Basis.from_scale(Vector3(ww - .006, dy1 - dy0 - .02, d)), Vector3(dx0 + ww * (i + .5), (dy0 + dy1) / 2, .04 + d / 2))
		mm.set_instance_transform(i, xf)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _slat_mat()
	w.add_child(mmi)
	for sx in [dx0 - .03, dx1 + .03]:
		Mk.mi(Mk.rounded_box(Vector3(.06, dy1 - dy0 + .06, .28), .008, frame, 2), null, Vector3(sx, (dy0 + dy1) / 2, .14), w)
	for sy in [dy0 - .03, dy1 + .03]:
		Mk.mi(Mk.rounded_box(Vector3(dx1 - dx0 + .12, .06, .28), .008, frame, 2), null, Vector3((dx0 + dx1) / 2, sy, .14), w)


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


## Grand meuble de console façon régie 70s : plateau en noyer massif, rebord rembourré en cuir,
## baies 19" encastrées sous le plateau (pas de tiroirs), ailes inclinées vers l'ingé de chaque côté.
func _build_control_desk() -> void:
	var x0: float = MAIN_DESK[0]
	var x1: float = MAIN_DESK[1]
	var z0: float = MAIN_DESK[2]
	var z1: float = MAIN_DESK[3]
	var h := DESK_TOP - DESK_T
	var top := Mk.mi(Mk.rounded_box(Vector3(x1 - x0, DESK_T, z1 - z0), .01, _wood, 3), null, Vector3((x0 + x1) / 2, DESK_TOP - DESK_T / 2, (z0 + z1) / 2), self)
	top.name = "ConsoleDesk"
	# chant en alu brossé + rebord cuir devant
	var alu := Mk.mat(Mk.c(0xa8a49c), .3, 1.0, {"normal": Mk.scratch_normal(), "normal_scale": .2})
	Mk.mi(Mk.box(Vector3(x1 - x0, .012, .004)), alu, Vector3((x0 + x1) / 2, DESK_TOP - .03, z0 - .002), self)
	Mk.mi(Mk.rounded_box(Vector3(x1 - x0 - .1, .07, .12), .033, _leather(x1 - x0), 4), null, Vector3((x0 + x1) / 2, DESK_TOP - .04, z0 - .055), self)
	# baies 19" à gauche et à droite sous le plateau, espace pour les jambes au milieu
	_place(_cabinet(.66, h, z1 - z0 - .04, "rack"), Vector3(x0 + .35, 0, z0 + .02), PI)
	_place(_cabinet(.66, h, z1 - z0 - .04, "rack"), Vector3(x1 - .35, 0, z0 + .02), PI)
	var kx0 := x0 + .68
	var kx1 := x1 - .68
	Mk.mi(Mk.box(Vector3(kx1 - kx0, h, .02)), _wood, Vector3((kx0 + kx1) / 2, h / 2, z1 - .02), self)
	Mk.mi(Mk.box(Vector3(kx1 - kx0, .03, z1 - z0 - .05)), Mk.mat(Mk.c(0x0c0806), .9), Vector3((kx0 + kx1) / 2, h - .015, (z0 + z1) / 2), self)
	# repose-pieds en laiton
	var brass := Mk.mat(Mk.c(0xb08840), .3, 1.0)
	var fr := Mk.mi(Mk.cyl(.012, .012, kx1 - kx0, 16), brass, Vector3((kx0 + kx1) / 2, .14, z0 + .25), self)
	fr.rotation.z = PI / 2
	# ailes
	for side in [-1, 1]:
		var c: Vector3 = WINGS[side]
		var yaw := wing_yaw(side)
		var b := Basis(Vector3.UP, yaw)
		var fwd := b * Vector3(0, 0, 1)
		var wt := Mk.mi(Mk.rounded_box(Vector3(WING_W, DESK_T, WING_D), .01, _wood, 3), null, Vector3(c.x, DESK_TOP - DESK_T / 2, c.z), self)
		wt.rotation.y = yaw
		var arm := Mk.mi(Mk.rounded_box(Vector3(WING_W - .08, .07, .12), .033, _leather(WING_W), 4), null, Vector3(c.x, DESK_TOP - .04, c.z) + fwd * (WING_D / 2 + .055), self)
		arm.rotation.y = yaw
		_place(_cabinet(WING_W - .02, h, WING_D - .04, "rack"), c + fwd * (WING_D / 2 - .02), yaw)


## Cap d'une aile (façade vers le fauteuil).
func wing_yaw(side: int) -> float:
	return face_seat(WINGS[side])


## Dessus d'une aile (centre, au niveau du plateau).
func wing_top(side: int) -> Vector3:
	var c: Vector3 = WINGS[side]
	return Vector3(c.x, DESK_TOP, c.z) - Basis(Vector3.UP, wing_yaw(side)) * Vector3(0, 0, .05)


## Bureau producteur du coin compo (mur de gauche) : plateau noyer + deux baies 19" dessous.
func _build_side_desk() -> void:
	var x0: float = SIDE_DESK[0]
	var x1: float = SIDE_DESK[1]
	var z0: float = SIDE_DESK[2]
	var z1: float = SIDE_DESK[3]
	var h := DESK_TOP - DESK_T
	Mk.mi(Mk.rounded_box(Vector3(x1 - x0, DESK_T, z1 - z0), .01, _wood, 3), null, Vector3((x0 + x1) / 2, DESK_TOP - DESK_T / 2, (z0 + z1) / 2), self)
	var arm := Mk.mi(Mk.rounded_box(Vector3(z1 - z0 - .1, .07, .12), .033, _leather(z1 - z0), 4), null, Vector3(x0 - .05, DESK_TOP - .04, (z0 + z1) / 2), self)
	arm.rotation.y = PI / 2
	var L := z1 - z0
	_place(_cabinet(L / 2 - .01, h, x1 - x0 - .04, "rack"), Vector3(x0 + .02, 0, z1 - L / 4), -PI / 2)
	_place(_cabinet(L / 2 - .01, h, x1 - x0 - .04, "rack"), Vector3(x0 + .02, 0, z0 + L / 4), -PI / 2)


## Nuage acoustique en lattes de bois suspendu au-dessus de la console et du fauteuil.
func _build_ceiling_cloud() -> void:
	var y := ROOM.y - .2
	var cx0 := 1.2
	var cx1 := 3.8
	var cz0 := -3.1
	var cz1 := -1.05
	var n := 30
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Mk.box(Vector3(cx1 - cx0, .05, .045))
	mm.instance_count = n
	for i in n:
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3((cx0 + cx1) / 2, y, cz0 + (cz1 - cz0) * (i + .5) / n)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _slat_mat()
	mmi.name = "CeilingCloud"
	add_child(mmi)
	Mk.mi(Mk.box(Vector3(cx1 - cx0, .01, cz1 - cz0)), Mk.mat(Mk.c(0x0a0705), .95), Vector3((cx0 + cx1) / 2, y + .035, (cz0 + cz1) / 2), self)
	for sx in [cx0, cx1]:
		Mk.mi(Mk.rounded_box(Vector3(.05, .1, cz1 - cz0 + .05), .006, _wood, 2), null, Vector3(sx, y + .01, (cz0 + cz1) / 2), self)
	var steel := Mk.mat(Mk.c(0x2a2a2a), .4, .8)
	for p in [Vector2(cx0 + .1, cz0 + .1), Vector2(cx1 - .1, cz0 + .1), Vector2(cx0 + .1, cz1 - .1), Vector2(cx1 - .1, cz1 - .1)]:
		Mk.mi(Mk.cyl(.004, .004, .16, 6), steel, Vector3(p.x, ROOM.y - .08, p.y), self)
	# petites gamelles encastrées dans le nuage
	var can_mat := Mk.glow(Mk.c(0xffc68a), 3.0)
	for p in [Vector2(1.9, -1.6), Vector2(3.1, -1.6), Vector2(1.9, -2.6), Vector2(3.1, -2.6)]:
		Mk.mi(Mk.cyl(.045, .045, .03, 20), Mk.mat(Mk.c(0x1a1612), .4, .6), Vector3(p.x, y - .03, p.y), self)
		var bulb := Mk.mi(Mk.disc(.03, 20), can_mat, Vector3(p.x, y - .046, p.y), self)
		bulb.rotation.x = PI
		var sp := SpotLight3D.new()
		sp.light_color = Mk.c(0xffd2a8)
		sp.light_energy = 1.0
		sp.spot_range = 3.0
		sp.spot_angle = 42.0
		sp.spot_angle_attenuation = 1.6
		sp.shadow_enabled = true
		_aim(sp, Vector3(p.x, y - .06, p.y), Vector3(p.x, 0, p.y + .3))
		add_child(sp)


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
				if u[1] != "vent":
					_rack_unit_hardware(g, yy - uh / 2, uh, u[0], bw)
				yy -= uh + .001
	return g


var _rk := {}


## Potards, LED et poignées en relief sur une façade de rack (positions calées sur la sérigraphie).
func _rack_unit_hardware(g: Node3D, cy: float, uh: float, units: int, bw: float) -> void:
	if _rk.is_empty():
		_rk.knob = Mk.cyl(.0075, .0085, .012, 18)
		_rk.skirt = Mk.cyl(.0105, .011, .002, 20)
		_rk.line = Mk.box(Vector3(.0012, .0006, .006))
		_rk.kmat = Mk.mat(Mk.c(0x161616), .35, .2, {"clearcoat": .5})
		_rk.smat = Mk.mat(Mk.c(0x9a968e), .3, 1.0)
		_rk.wmat = Mk.mat(Mk.c(0xf0ece4), .5)
		_rk.handle = Mk.chrome_mat()
		_rk.led = Mk.glow(Mk.c(0xff3020), 2.2)
	var ky := cy - uh * .05
	for i in 6:
		var x := (((320.0 + i * 95.0) / 1024.0) - .5) * bw
		var kn := Node3D.new()
		kn.position = Vector3(x, ky, .02)
		kn.rotation = Vector3(PI / 2, 0, randf_range(-2.3, 2.3))
		g.add_child(kn)
		Mk.mi(_rk.skirt, _rk.smat, Vector3(0, .001, 0), kn)
		Mk.mi(_rk.knob, _rk.kmat, Vector3(0, .008, 0), kn)
		Mk.mi(_rk.line, _rk.wmat, Vector3(0, .0142, -.003), kn)
	var led := Mk.mi(Mk.sphere(.0035, 10, 6, true), _rk.led, Vector3(((900.0 / 1024.0) - .5) * bw, cy, .02), g)
	led.rotation.x = PI / 2
	if units >= 2:
		for sx in [-1, 1]:
			var x: float = sx * (bw / 2 - .024)
			var t := Vector3(x, cy + uh / 2 - .012, .02)
			var b := Vector3(x, cy - uh / 2 + .012, .02)
			Mk.mi(Mk.tube([t, t + Vector3(0, -.003, .022), b + Vector3(0, .003, .022), b], .0038, 16, 8), _rk.handle, Vector3.ZERO, g)


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
	var key := "leather%.2f" % length
	if _rack_mats.has(key):
		return _rack_mats[key]
	var m: StandardMaterial3D = Mk.pbr("leather_brown", .25, {"wear": 0.6, "tint": Mk.c(0x4a3228), "rough": .85, "clearcoat": .3, "clearcoat_rough": .45, "normal_scale": 1.3}).duplicate()
	_rack_mats[key] = m
	return m


# ---------------------------------------------------------------- intégration : câbles
## Chaque machine est vraiment branchée : câbles qui partent de l'arrière et descendent derrière le
## meuble (vers la baie de patch), un peu de mou sur le plateau.
func _module_cables() -> void:
	var black := Mk.mat(Mk.c(0x0e0e0e), .5)
	var grey := Mk.mat(Mk.c(0x3a3a3c), .55)
	var y := DESK_TOP + .006
	# accordeur 808 et fax -> derrière le bureau producteur, le long du mur
	for m in [tuner, fax]:
		var a: Vector3 = m.to_global(Vector3(0, .04, -.14))
		Mk.mi(Mk.tube([a, Vector3(a.x + .1, y, a.z), Vector3(ROOM.x - .05, y, a.z + .05), Vector3(ROOM.x - .04, .4, a.z + .1), Vector3(ROOM.x - .05, .01, a.z + .2)], .004, 30, 6), black, Vector3.ZERO, self)
	# analyseur -> derrière l'aile droite
	var b: Vector3 = analyzer.to_global(Vector3(0, .05, -.16))
	Mk.mi(Mk.tube([b, b + Vector3(-.15, -.05, .1), Vector3(.35, y, -.55), Vector3(.2, .4, -.4), Vector3(.15, .01, -.3)], .004, 24, 6), black, Vector3.ZERO, self)
	Mk.mi(Mk.tube([b + Vector3(.03, 0, 0), Vector3(1.0, y, -.45), Vector3(1.25, y, -.35), Vector3(1.4, y + .04, -.4)], .003, 24, 6), grey, Vector3.ZERO, self)
	# synthé mural : câble qui descend le long du mur jusqu'au bureau producteur
	Mk.mi(Mk.tube([freq.to_global(Vector3(.3, -.02, -.05)), Vector3(ROOM.x - .03, 1.1, -3.0), Vector3(ROOM.x - .02, y + .02, -3.05), Vector3(4.9, y, -2.95), Vector3(4.86, y, -2.75)], .004, 30, 6), black, Vector3.ZERO, self)
	# rouleau de gaffer et étiquettes de scotch sur le rebord
	var gaff := Mk.mat(Mk.c(0x1a1a1a), .7)
	var roll := Mk.mi(Mk.torus_ring(.045, .022), gaff, Vector3(4.88, y + .02, -2.88), self)
	roll.scale = Vector3(1, .9, 1)


# ---------------------------------------------------------------- fond de la pièce : matériel
## De droite à gauche (vu du fauteuil retourné) : Les Paul + Marshall, magnéto à bandes sur son
## chariot, lampadaire, canapé cuir sous le diffuseur, télé + magnétoscope, magnéto multipiste.
func _build_back_units() -> void:
	var zb := -ROOM.z
	# canapé cuir (asset) contre le mur du fond, sous le diffuseur
	sofa = Items7080.chesterfield(2.1)
	sofa.position = Vector3(3.12, 0, zb + .5)
	add_child(sofa)
	# applique chaude qui lèche le canapé et le diffuseur
	var sl := SpotLight3D.new()
	sl.light_color = Mk.c(0xffc890)
	sl.light_energy = 2.2
	sl.spot_range = 3.2
	sl.spot_angle = 38.0
	sl.spot_angle_attenuation = 1.4
	sl.shadow_enabled = true
	_aim(sl, Vector3(3.1, ROOM.y - .05, -4.6), Vector3(3.12, .45, zb + .5))
	add_child(sl)
	# multipiste 24 pistes contre le mur gauche, au fond
	var mt := _multitrack()
	mt.position = Vector3(4.6, 0, zb + .68)
	mt.rotation.y = -PI / 2
	add_child(mt)
	# frigo vitré à bières à côté de la porte
	var fr := Items7080.beer_fridge()
	fr.position = Vector3(1.66, 0, zb + .3)
	add_child(fr)
	# magnéto à bandes (asset) sur son chariot, sous la fenêtre sur rue
	var rt := Node3D.new()
	rt.position = Vector3(.4, 0, (WIN.z0 + WIN.z1) / 2)
	rt.rotation.y = PI / 2
	add_child(rt)
	_cart(rt, Vector3(.72, .66, .46))
	Props.place(rt, "reel_to_reel.glb", Vector3(0, .66, 0), 0.0)
	var r := Tex.rng(17)
	var x := -.32
	while x < .3:
		var bw := .03 + r.randf() * .02
		var box := Mk.mi(Mk.box(Vector3(bw, .19, .19)), _tape_box_mat(int(r.randi() % 4)), Vector3(x + bw / 2, .155, 0), rt)
		box.rotation.y = r.randf_range(-.05, .05)
		x += bw + .004
	# stores vénitiens à moitié baissés devant la fenêtre
	var bl := Items7080.blinds(WIN.z1 - WIN.z0 - .04, WIN.y1 - WIN.y0, .3, .55)
	bl.position = Vector3(.13, (WIN.y0 + WIN.y1) / 2, (WIN.z0 + WIN.z1) / 2)
	bl.rotation.y = PI / 2
	add_child(bl)
	# cible de fléchettes sur le mur droit, au fond
	Props.place(self, "dartboard.glb", Vector3(.1, 1.45, -5.3), PI / 2)


## Porte capitonnée au fond à droite + voyant ON AIR au-dessus + couloir sombre derrière.
var on_air_mat: StandardMaterial3D
var sofa: Node3D


func _build_door() -> void:
	var d := Items7080.door(DOOR.w, DOOR.h)
	d.position = Vector3(DOOR.x, 0, -ROOM.z + .005)
	add_child(d)
	Mk.mi(Mk.box(Vector3(DOOR.w + .1, DOOR.h + .1, .05)), Mk.mat(Mk.c(0x050403), 1.0), Vector3(DOOR.x, DOOR.h / 2, -ROOM.z - .2), self)
	var oa := Items7080.on_air()
	(oa[0] as Node3D).position = Vector3(DOOR.x, DOOR.h + .27, -ROOM.z + .01)
	add_child(oa[0])
	on_air_mat = oa[1]


## Enceintes principales encastrées de chaque côté de la vitre (soffits) : caisson habillé de jute
## qui avance du mur, baffle incliné vers l'écoute, Pioneer CS-780 en grand (assets de Maxime).
func _build_soffits() -> void:
	var listener := EYE
	for i in 2:
		var cx: float = SOFFITS[i]
		var g := Node3D.new()
		g.name = "Soffit"
		var c := Vector3(cx, 0, -.21)
		g.position = c
		var to := listener - Vector3(cx, 1.7, -.24)
		g.rotation.y = atan2(to.x, to.z) * .55 + (PI if false else 0.0)
		add_child(g)
		var W := .98
		var H := ROOM.y - .85
		var D := .42
		var pm := _panel_mat()
		var black := Mk.mat(Mk.c(0x0a0806), .9)
		Mk.mi(Mk.rounded_box(Vector3(W, H, D), .01, [pm, pm, _wood, pm, black, pm], 2), null, Vector3(0, .85 + H / 2, 0), g)
		# socle sous le soffit (lambris comme le mur) + tablette
		Mk.mi(Mk.rounded_box(Vector3(W, .85, D - .04), .008, [pm, pm, _wood, pm, pm, pm], 2), null, Vector3(0, .425, -.02), g)
		Mk.mi(Mk.rounded_box(Vector3(W + .02, .05, D + .02), .008, _wood, 2), null, Vector3(0, .85, 0), g)
		_main_monitor(g, Vector3(0, .85, D / 2), W, H)


## Grande écoute encastrée façon 1977 : façade en noyer sombre à cadre mouluré, deux boomers 15"
## côte à côte, pavillon multicellulaire au-dessus, évents en bas, toile acoustique en haut.
## `at` = milieu bas de la face avant du soffit.
func _main_monitor(g: Node3D, at: Vector3, W: float, H: float) -> void:
	var walnut: StandardMaterial3D = Mk.pbr("dark_wood", .5, {"wear": .35, "tint": Mk.c(0x6a4028), "rough": .55, "clearcoat": .35})
	var baffle := Mk.mat(Mk.c(0x0b0a09), .85)
	var frame := Mk.mat(Mk.c(0x2a2826), .45, .75)
	var paper := Mk.mat(Mk.c(0x161412), 1.0, 0.0, {"cull_off": true})
	var roll := Mk.mat(Mk.c(0x0c0b0a), .9, 0.0, {"cull_off": true})
	var cap := Mk.mat(Mk.c(0x1e1c1a), .7, 0.0, {"cull_off": true})
	var z := at.z
	# cadre de façade en noyer (montants + traverses), baffle noir en retrait
	var y0 := at.y + .38
	var y1 := at.y + H - .28
	var bw := W - .16
	Mk.mi(Mk.box(Vector3(bw, y1 - y0, .02)), baffle, Vector3(0, (y0 + y1) / 2, z - .012), g)
	for sx in [-1, 1]:
		Mk.mi(Mk.rounded_box(Vector3(.08, H, .035), .01, walnut, 2), null, Vector3(sx * (W / 2 - .04), at.y + H / 2, z + .004), g)
	for yy in [y0 - .02, y1 + .02]:
		Mk.mi(Mk.rounded_box(Vector3(W, .04, .035), .008, walnut, 2), null, Vector3(0, yy, z + .004), g)
	# panneau bas : noyer + deux évents horizontaux
	Mk.mi(Mk.box(Vector3(bw, .34, .02)), walnut, Vector3(0, at.y + .2, z - .006), g)
	for sx in [-1, 1]:
		Mk.mi(Mk.rounded_box(Vector3(.26, .05, .03), .02, baffle, 2), null, Vector3(sx * .2, at.y + .2, z + .002), g)
	# toile acoustique en haut
	Mk.mi(Mk.box(Vector3(bw, H - (y1 - at.y) - .06, .01)), Mk.pbr("hessian_230", .15, {"tint": Mk.c(0x2a1a10)}), Vector3(0, (y1 + at.y + H) / 2 + .01, z - .004), g)
	# boomers 15" (profil tourné : saladier, suspension, cône, cache-noyau)
	var r := minf(.19, bw / 4 - .01)
	var wy := y0 + .26
	for sx in [-1, 1]:
		var cx: float = sx * (r + .015)
		var ring := Mk.mi(Mk.lathe([[r, -.002], [r, .006], [r * .93, .008], [r * .9, .002]], 64), frame, Vector3(cx, wy, z), g)
		ring.rotation.x = PI / 2
		var sur := Mk.mi(Mk.lathe([[r * .9, .002], [r * .86, .014], [r * .8, .002]], 64), roll, Vector3(cx, wy, z), g)
		sur.rotation.x = PI / 2
		var cone := Mk.mi(Mk.lathe([[r * .8, .002], [r * .6, -.03], [r * .4, -.055], [r * .27, -.07]], 64), paper, Vector3(cx, wy, z), g)
		cone.rotation.x = PI / 2
		var dc := Mk.mi(Mk.lathe([[r * .27, -.07], [r * .22, -.052], [r * .12, -.043], [0.0, -.04]], 48), cap, Vector3(cx, wy, z), g)
		dc.rotation.x = PI / 2
		for k in 8:
			var an := k / 8.0 * TAU + .2
			var sc := Mk.mi(Mk.cyl(.005, .005, .004, 10), frame, Vector3(cx + cos(an) * r * .965, wy + sin(an) * r * .965, z + .009), g)
			sc.rotation.x = PI / 2
	# pavillon multicellulaire : bouche évasée noire, cellules verticales en alu, gorge au fond
	var hy := y1 - .17
	var hw := bw * .62
	var hh := .2
	var horn := Node3D.new()
	horn.position = Vector3(0, hy, z)
	g.add_child(horn)
	var hm := Mk.mat(Mk.c(0x111010), .5, .3)
	for side in [-1, 1]:
		var wall := Mk.mi(Mk.box(Vector3(.008, hh, .16)), hm, Vector3(side * hw / 2 * .82, 0, -.07), horn)
		wall.rotation.y = side * .32
		var lid := Mk.mi(Mk.box(Vector3(hw, .008, .16)), hm, Vector3(0, side * hh / 2 * .8, -.07), horn)
		lid.rotation.x = -side * .3
	Mk.mi(Mk.box(Vector3(hw * .5, hh * .5, .01)), Mk.mat(Mk.c(0x050505), 1.0), Vector3(0, 0, -.14), horn)
	var alu := Mk.mat(Mk.c(0x9a9a96), .35, .9)
	for k in 7:
		var fx := (k - 3) / 3.0
		var fin := Mk.mi(Mk.box(Vector3(.004, hh * .8, .13)), alu, Vector3(fx * hw * .34, 0, -.075), horn)
		fin.rotation.y = fx * .3
	# petite plaque de marque gravée sous les boomers
	var badge := Tex.canvas(256, 48, func(ci, w2, h2):
		ci.draw_rect(Rect2(0, 0, w2, h2), Mk.c(0x2a2a28))
		Tex.silk(ci, "REEL  MONITOR  77", w2 / 2, h2 * .68, 20, Mk.c(0xc8c0a8), "center", 700))
	Mk.mi(Mk.quad(.12, .022), Mk.mat(Color.WHITE, .4, .8, {"map": badge}), Vector3(0, y0 + .015, z + .001), g)


## Petit chariot / meuble bas en noyer sur roulettes, plateau + tablette basse. size = (l, h, p).
func _cart(g: Node3D, size: Vector3) -> void:
	var w := size.x
	var h := size.y
	var d := size.z
	Mk.mi(Mk.rounded_box(Vector3(w, .03, d), .006, _wood, 2), null, Vector3(0, h - .015, 0), g)
	Mk.mi(Mk.rounded_box(Vector3(w - .04, .02, d - .04), .004, _wood, 2), null, Vector3(0, .1, 0), g)
	var steel := Mk.mat(Mk.c(0x1c1c1c), .4, .7)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			Mk.mi(Mk.box(Vector3(.025, h - .07, .025)), steel, Vector3(sx * (w / 2 - .02), (h - .07) / 2 + .055, sz * (d / 2 - .02)), g)
			var wheel := Mk.mi(Mk.cyl(.022, .022, .018, 16), Mk.mat(Mk.c(0x0a0a0a), .6), Vector3(sx * (w / 2 - .02), .024, sz * (d / 2 - .02)), g)
			wheel.rotation.z = PI / 2


## Magnéto multipiste 2" 24 pistes sur pied (façon fin 70s) : caisse grise à joues noyer, platine
## inclinée avec deux bobines NAB 14", bloc têtes, cabestan, galet, bras de tension, touches de
## transport, compteur LED ; pont de 24 VU-mètres à l'arrière.
func _multitrack() -> Node3D:
	var g := Node3D.new()
	g.name = "Multitrack"
	var grey := Mk.mat(Mk.c(0x9a968c), .45, .6, {"normal": Mk.scratch_normal(), "normal_scale": .15})
	var dark := Mk.mat(Mk.c(0x1a1a1a), .5, .3)
	var walnut := Mk.mat(Mk.c(0x6a4028), .55, 0.0, {"map": Mk.walnut_tex(), "clearcoat": .3})
	var chrome := Mk.chrome_mat()
	var W := 1.02
	var D := .72
	# socle + caisse
	Mk.mi(Mk.box(Vector3(W - .06, .08, D - .06)), dark, Vector3(0, .04, 0), g)
	var face := Tex.canvas(1024, 640, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x8e8a80))
		Tex.brushed(ci, w, h, 41, .05)
		for row in 3:
			var y0 := 60 + row * 190
			for k in 30:
				ci.draw_rect(Rect2(90 + k * 28, y0, 14, 120), Color(0, 0, 0, .75))
		Tex.silk(ci, "RT-24  MASTER RECORDER", 60, h - 30, 26, Color(.1, .1, .1, .85))
		Tex.grime(ci, w, h, 42, 1.2))
	Mk.mi(Mk.rounded_box(Vector3(W - .06, .7, D - .04), .006, [grey, grey, grey, grey, Mk.mat(Color.WHITE, .5, .5, {"map": face}), grey], 2), null, Vector3(0, .08 + .35, 0), g)
	for sx in [-1, 1]:
		Mk.mi(Mk.rounded_box(Vector3(.03, .92, D), .008, walnut, 2), null, Vector3(sx * (W / 2 - .015), .46, 0), g)
	# platine inclinée
	var deck := Node3D.new()
	deck.position = Vector3(0, .84, .02)
	deck.rotation.x = .22
	g.add_child(deck)
	var plate := Tex.canvas(1024, 700, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xb4b0a6))
		Tex.brushed(ci, w, h, 43, .06)
		var ink := Color(.1, .1, .1, .85)
		var labels := ["REW", "F FWD", "STOP", "PLAY", "REC"]
		for i in 5:
			Tex.silk(ci, labels[i], 300 + i * 95, h - 40, 18, ink, "center", 600)
		Tex.silk(ci, "SPEED 15 / 30 IPS", 80, h - 40, 16, ink, "left", 500)
		Tex.silk(ci, "EDIT", 860, h - 40, 16, ink, "center", 600)
		ci.draw_rect(Rect2(380, 455, 270, 60), Color(.03, .01, .01))
		Tex.grime(ci, w, h, 44, 1.5))
	var pm := Mk.mat(Color.WHITE, .4, .6, {"map": plate})
	Mk.mi(Mk.rounded_box(Vector3(W - .06, .02, .66), .005, [dark, dark, pm, dark, dark, dark], 2), null, Vector3.ZERO, deck)
	# compteur LED
	var led := Tex.canvas(256, 64, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Color(.03, .0, .0))
		Tex.silk(ci, "00:12:34", w / 2, h * .78, 46, Mk.c(0xff3020), "center", 600, "mono"))
	var cnt := Mk.mi(Mk.plane(.13, .032), Mk.glow(Color.WHITE, 1.6, led), Vector3(.005, .0105, .17), deck)
	# bobines NAB 14" + galettes de bande
	var tape_m := Mk.mat(Mk.c(0x2a1a12), .55)
	for sx in [-1, 1]:
		var rp := Vector3(sx * .26, .012, -.08)
		var reel := Node3D.new()
		reel.position = rp
		deck.add_child(reel)
		Mk.mi(Mk.cyl(.035, .035, .03, 24), chrome, Vector3(0, .015, 0), reel)
		Mk.mi(Mk.cyl(.115 if sx < 0 else .085, .115 if sx < 0 else .085, .052, 48), tape_m, Vector3(0, .032, 0), reel)
		for fy in [.004, .06]:
			var fl := _reel_flange(.178)
			fl.position = Vector3(0, fy, 0)
			reel.add_child(fl)
		reel.set_meta("dir", sx)
		mt_reels.append(reel)
		# bras de tension
		var arm := Mk.mi(Mk.box(Vector3(.012, .01, .1)), chrome, rp + Vector3(sx * .12, .015, .17), deck)
		arm.rotation.y = sx * .5
		Mk.mi(Mk.cyl(.012, .012, .03, 16), chrome, rp + Vector3(sx * .15, .03, .21), deck)
	# bloc têtes, cabestan, galet presseur
	Mk.mi(Mk.rounded_box(Vector3(.2, .05, .07), .004, dark, 1), null, Vector3(0, .035, .1), deck)
	for i in 3:
		Mk.mi(Mk.rounded_box(Vector3(.035, .04, .025), .006, chrome, 2), null, Vector3(-.06 + i * .06, .06, .135), deck)
	Mk.mi(Mk.cyl(.006, .006, .06, 12), chrome, Vector3(.13, .04, .14), deck)
	Mk.mi(Mk.cyl(.022, .022, .052, 20), Mk.mat(Mk.c(0x0c0c0c), .7), Vector3(.165, .04, .14), deck)
	# bande : de la bobine gauche aux guides, devant les têtes, vers la bobine droite
	var tape_path := [Vector3(-.26 + .1, .045, .0), Vector3(-.15, .045, .2), Vector3(0, .045, .15), Vector3(.15, .045, .2), Vector3(.26 - .07, .045, -.03)]
	for i in tape_path.size() - 1:
		var a: Vector3 = tape_path[i]
		var b: Vector3 = tape_path[i + 1]
		var seg := Mk.mi(Mk.box(Vector3(.0015, .05, a.distance_to(b))), tape_m, (a + b) / 2, deck)
		seg.rotation.y = atan2(b.x - a.x, b.z - a.z)
	# touches de transport
	var key_cols := [0x2a2a2a, 0x2a2a2a, 0x2a2a2a, 0x2a5a2a, 0xb02018]
	for i in 5:
		Mk.mi(Mk.rounded_box(Vector3(.06, .016, .035), .004, Mk.mat(Mk.c(key_cols[i]), .35, .1, {"clearcoat": .5}), 2), null, Vector3(-.21 + i * .093, .018, .27), deck)
	# pont de VU-mètres
	var bridge := Node3D.new()
	bridge.position = Vector3(0, .94, -.28)
	bridge.rotation.x = -.1
	g.add_child(bridge)
	Mk.mi(Mk.rounded_box(Vector3(W - .02, .36, .14), .006, dark, 2), null, Vector3(0, .18, 0), bridge)
	Mk.mi(Mk.rounded_box(Vector3(W, .03, .16), .008, walnut, 2), null, Vector3(0, .375, 0), bridge)
	var vu := Tex.canvas(1024, 330, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x141414))
		for row in 2:
			for k in 12:
				var cx := 42.0 + k * 82.0
				var cy := 18.0 + row * 158.0
				ci.draw_rect(Rect2(cx - 36, cy, 72, 110), Mk.c(0xe8dcb4))
				for t in 9:
					var a := deg_to_rad(-45 + t * 11.25)
					var o := Vector2(cx, cy + 100)
					ci.draw_line(o + Vector2(sin(a), -cos(a)) * 62, o + Vector2(sin(a), -cos(a)) * 72, Color(.85, .1, .05) if t > 6 else Color(.1, .1, .1), 2.0)
				var na := deg_to_rad(-30 + Tex.rng(row * 12 + k).randf() * 40)
				var o2 := Vector2(cx, cy + 100)
				ci.draw_line(o2, o2 + Vector2(sin(na), -cos(na)) * 70, Color(.05, .05, .05), 2.0)
				Tex.silk(ci, str(row * 12 + k + 1), cx, cy + 135, 18, Color(.85, .82, .76, .9), "center", 600)
		Tex.grime(ci, w, h, 45, 1.0))
	var vm := Mk.glow(Color(1, .92, .78), .55, vu)
	Mk.mi(Mk.quad(W - .08, .33), vm, Vector3(0, .18, .0705), bridge)
	Mk.mi(Mk.quad(W - .08, .33), Mk.mat(Mk.c(0x101010), .05, 0.0, {"alpha": .12, "clearcoat": 1.0}), Vector3(0, .18, .073), bridge)
	return g


var mt_reels: Array[Node3D] = []


## Flasque de bobine NAB : disque alu avec trois grandes fenêtres (découpées par la texture).
func _reel_flange(r: float) -> MeshInstance3D:
	if not _rack_mats.has("flange"):
		var tex := Tex.canvas(512, 512, func(ci, w, h):
			ci.draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0))
			var c := Vector2(w / 2.0, h / 2.0)
			var al := Color(.85, .84, .8, 1)
			ci.draw_circle(c, w * .19, al)
			ci.draw_arc(c, w * .455, 0, TAU, 128, al, w * .08)
			for k in 3:
				var a := k * TAU / 3 + .3
				var dir := Vector2(cos(a), sin(a))
				ci.draw_line(c + dir * w * .15, c + dir * w * .44, al, w * .13)
			ci.draw_circle(c, w * .04, Color(.2, .2, .2, 1))
			ci.draw_arc(c, w * .46, 0, TAU, 96, Color(.6, .6, .58, 1), 4.0), true)
		var m := Mk.mat(Color.WHITE, .3, 1.0, {"map": tex, "cull_off": true})
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		_rack_mats["flange"] = m
	var d := Mk.mi(Mk.plane(r * 2, r * 2), _rack_mats["flange"])
	return d


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
	g.position = Vector3(.5, 0, -2.15)
	g.rotation.y = PI / 2 - .1  # plateau tourné vers le fauteuil (+X)
	add_child(g)
	Mk.mi(Mk.rounded_box(Vector3(.36, .03, .3), .008, _wood, 2), null, Vector3(0, .015, 0), g)
	Mk.mi(Mk.rounded_box(Vector3(.07, .98, .07), .01, _wood, 2), null, Vector3(0, .5, -.02), g)
	var top := Mk.mi(Mk.rounded_box(Vector3(.48, .025, .36), .006, _wood, 2), null, Vector3(0, 1.02, .02), g)
	top.rotation.x = .35
	var lip := Mk.mi(Mk.rounded_box(Vector3(.46, .03, .02), .004, _wood, 2), null, Vector3(0, .97, .19), g)
	lip.rotation.x = .35
	# carnet de splits ouvert sur le plateau (pages dans le plan XY local, +Z = vers le lecteur)
	splits = Splits7080.new(_wood)
	var b := Basis(Vector3.RIGHT, .35) * Basis(Vector3.RIGHT, -PI / 2)
	splits.transform = Transform3D(b, Vector3(0, 1.02, .02) + Basis(Vector3.RIGHT, .35) * Vector3(0, .0125, 0))
	g.add_child(splits)
	modules["splits"] = splits


# ---------------------------------------------------------------- dehors : rue la nuit (années 70)
## Vue par la fenêtre : trottoir, chaussée mouillée, voitures garées, réverbères au sodium (orange),
## immeuble en face avec fenêtres éclairées et enseigne au néon. Une voiture passe de temps en temps.
var street_car: Node3D
var street: Street7080


func _build_street() -> void:
	street = Street7080.new()
	street.rotation.y = -PI / 2  # la rue est derrière le mur droit
	street.position = Vector3(0, 0, (WIN.z0 + WIN.z1) / 2 - 1.5)
	add_child(street)
	street_car = street.car


# ---------------------------------------------------------------- heure du jour
## Quatre ambiances selon l'heure du Mac (ou une heure forcée dans les réglages) : matin frais, journée
## claire, coucher de soleil orangé, nuit de session. Fondus entre elles. Le soleil entre par la fenêtre
## (à travers les stores), la rue s'allume la nuit, il pleut le soir.
const TOD_KEYS := [  # heure, [nuit, matin, jour, coucher]
	[0.0, [1, 0, 0, 0]], [5.5, [1, 0, 0, 0]], [7.0, [0, 1, 0, 0]], [9.5, [0, 0, 1, 0]],
	[16.5, [0, 0, 1, 0]], [18.5, [0, 0, 0, 1]], [20.5, [1, 0, 0, 0]], [24.0, [1, 0, 0, 0]],
]
#            soleil couleur,         énergie, élév., ciel,                        ambiance,              énergie amb., lampes, pluie, expo
const TOD_LOOK := [
	[Color(0, 0, 0), 0.0, 6.0, Color(.035, .05, .1), Color(.25, .23, .2), .16, 1.0, 1.0, 1.15],      # nuit
	[Color(1.0, .84, .66), 1.8, 12.0, Color(.6, .7, .82), Color(.55, .6, .68), .7, .75, 0.0, 1.0],    # matin
	[Color(1.0, .97, .92), 2.4, 38.0, Color(.55, .7, .92), Color(.62, .64, .66), .95, .6, 0.0, 1.0],  # jour
	[Color(1.0, .5, .22), 2.0, 5.0, Color(.95, .5, .28), Color(.6, .42, .32), .55, .9, .25, 1.05],    # coucher
]
var sun: DirectionalLight3D
var tod_override := -1.0      # < 0 : heure du Mac
var _tod_shown := -1.0        # heure affichée (glisse vers la cible)
var _tod_tick := 0.0
var _room_lights: Array = []  # [lumière, énergie de base]
var _sky_pano: PanoramaSkyMaterial
var _window_fill: SpotLight3D
var _day_bounce: OmniLight3D


func _build_daylight() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 30.0
	sun.shadow_blur = 1.5
	sun.light_angular_distance = .6
	add_child(sun)
	tod_override = float(Store.get_v("tod_override", -1.0))
	# lumière du ciel qui entre par la fenêtre (remplissage doux, plus fort le jour)
	_window_fill = SpotLight3D.new()
	_window_fill.name = "WindowFill"
	_window_fill.spot_range = 7.0
	_window_fill.spot_angle = 75.0
	_window_fill.spot_angle_attenuation = .6
	_window_fill.shadow_enabled = false
	# lumière du jour renvoyée par la pièce (remplissage doux, sans ombre)
	_day_bounce = OmniLight3D.new()
	_day_bounce.name = "DayBounce"
	_day_bounce.omni_range = 7.5
	_day_bounce.omni_attenuation = .7
	_day_bounce.position = Vector3(2.0, 2.2, -3.2)
	add_child(_day_bounce)
	_aim(_window_fill, Vector3(.15, (WIN.y0 + WIN.y1) / 2, (WIN.z0 + WIN.z1) / 2), Vector3(3.5, .6, (WIN.z0 + WIN.z1) / 2 + .3))
	add_child(_window_fill)
	# les murs, le sol et le plafond bloquent le soleil des deux côtés (sinon il traverse les murs)
	for n in find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh is ArrayMesh or mi.name in ["Floor", "Ceiling"]:
			if mi.get_parent().name.ends_with("Wall") or mi.name in ["Floor", "Ceiling"]:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	for l in find_children("*", "Light3D", true, false):
		if l == sun or l == _window_fill or l == _day_bounce or street.is_ancestor_of(l):
			continue
		_room_lights.append([l, (l as Light3D).light_energy])
	_apply_tod(tod_hour(), true)


func tod_hour() -> float:
	if tod_override >= 0.0:
		return tod_override
	var t := Time.get_time_dict_from_system()
	return t.hour + t.minute / 60.0


func set_tod_override(h: float) -> void:
	tod_override = h
	Store.set_v("tod_override", h)


static func tod_weights(h: float) -> Array:
	h = fposmod(h, 24.0)
	for i in TOD_KEYS.size() - 1:
		var a: Array = TOD_KEYS[i]
		var b: Array = TOD_KEYS[i + 1]
		if h >= a[0] and h <= b[0]:
			var k: float = (h - a[0]) / maxf(.001, b[0] - a[0])
			k = k * k * (3.0 - 2.0 * k)
			var out := []
			for j in 4:
				out.append(lerpf(float(a[1][j]), float(b[1][j]), k))
			return out
	return [1.0, 0.0, 0.0, 0.0]


static func tod_name(h: float) -> String:
	var w := tod_weights(h)
	var best := 0
	for j in 4:
		if w[j] > w[best]:
			best = j
	return ["Nuit", "Matin", "Journée", "Coucher de soleil"][best]


func _apply_tod(h: float, _instant := false) -> void:
	var w := tod_weights(h)
	var look := []
	for k in 9:
		var v: Variant = null
		for j in 4:
			var x: Variant = TOD_LOOK[j][k]
			if v == null:
				v = x * float(w[j])
			else:
				v = v + x * float(w[j])
		look.append(v)
	var sun_col: Color = look[0]
	sun.light_color = Color(sun_col.r, sun_col.g, sun_col.b).clamp() if sun_col.v > .01 else Color.WHITE
	sun.light_energy = look[1]
	sun.visible = look[1] > .02
	# le soleil arrive de la rue (côté -X), un peu de biais ; il monte dans la journée
	var elev := deg_to_rad(float(look[2]))
	# le matin il entre par la fenêtre ; l'après-midi il passe derrière le studio et éclaire les façades d'en face
	var az := deg_to_rad(lerpf(25.0, 160.0, clampf((fposmod(h, 24.0) - 6.5) / 12.5, 0.0, 1.0)))
	var dir := Vector3(cos(elev) * cos(az), -sin(elev), cos(elev) * sin(az))   # direction de la lumière (vers +X)
	sun.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), Vector3(-5, 6, -3.5))
	var day := 1.0 - float(w[0])
	var sky_c: Color = look[3]
	_window_fill.light_color = sky_c.lerp(Color.WHITE, .5)
	_window_fill.light_energy = day * 2.2
	_window_fill.visible = day > .02
	_day_bounce.light_color = sky_c.lerp(Mk.c(0xffe8d0), .6)
	_day_bounce.light_energy = day * 1.1
	_day_bounce.visible = day > .02
	env.ambient_light_color = look[4]
	env.ambient_light_energy = look[5]
	env.tonemap_exposure = look[8]
	if _sky_pano:
		_sky_pano.energy_multiplier = lerpf(.12, .45, 1.0 - float(w[0]))
	var lamps: float = look[6]
	for e in _room_lights:
		var l: Light3D = e[0]
		if not module_spot_light(l):
			l.light_energy = float(e[1]) * lamps
	var night: float = float(w[0]) + float(w[3]) * .55 + float(w[1]) * .15
	street.set_time(clampf(night, 0.0, 1.0), look[3], look[7])


func module_spot_light(l: Light3D) -> bool:
	for s in module_spots.values():
		if s.light == l:
			return true
	return false


func _animate_tod(dt: float) -> void:
	_tod_tick -= dt
	var target := tod_hour()
	if _tod_shown < 0.0:
		_tod_shown = target
	var diff := wrapf(target - _tod_shown, -12.0, 12.0)
	if absf(diff) < .01 and _tod_tick > 0.0:
		return
	_tod_tick = 1.0
	# fondu : quand on change l'heure à la main, on traverse les ambiances en ~2 s
	_tod_shown = fposmod(_tod_shown + clampf(diff, -dt * 8.0, dt * 8.0) if absf(diff) > .01 else target, 24.0)
	_apply_tod(_tod_shown)


# ---------------------------------------------------------------- lumières
## Ambiance tamisée : quelques encastrés au plafond, rasants doux sur le liège, remplissage faible.
## Les machines sont mises en avant par les spots des rails (voir _build_module_spots).
func _build_lights() -> void:
	var can_mat := Mk.glow(Mk.c(0xffc68a), 4.0)
	var trim := Mk.mat(Mk.c(0x2a2420), .4, .6)
	for p in [Vector3(1.4, 0, -4.2), Vector3(3.6, 0, -4.2), Vector3(2.5, 0, -5.2), Vector3(.7, 0, -3.3), Vector3(4.3, 0, -3.0)]:
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
	for w in [[.4, -1.0, 0.0], [ROOM.x - .4, -1.5, ROOM.x], [ROOM.x - .4, -3.3, ROOM.x], [.4, -5.2, 0.0], [ROOM.x - .4, -5.0, ROOM.x]]:
		var ww := SpotLight3D.new()
		ww.light_color = Mk.c(0xffcfa0)
		ww.light_energy = .7
		ww.spot_range = 2.6
		ww.spot_angle = 45.0
		_aim(ww, Vector3(w[0], ROOM.y - .05, w[1]), Vector3(w[2], 1.2, w[1]))
		add_child(ww)
	# remplissage doux au centre
	var fill := OmniLight3D.new()
	fill.light_color = Mk.c(0xffe0c8)
	fill.light_energy = .38
	fill.omni_range = 6.5
	fill.position = Vector3(2.5, 2.2, -3.2)
	add_child(fill)


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
	if shot == "v_street":  # dev : le nez à la fenêtre
		return [Vector3(.75, 1.42, (WIN.z0 + WIN.z1) / 2), Vector3(-6, 1.9, (WIN.z0 + WIN.z1) / 2 + .4)]
	if shot == "splits":
		return _via(splits, Vector3(0, 0, .012), Vector3(0, 0, 1), Splits7080.PW + .012, Splits7080.PH / 2 + .01, cam, aspect, 1.1)
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
	if shot == "beats":
		return _via(beats, Beats7080.FOCUS, Vector3(0, .12, 1), Beats7080.W / 2 + .02, Beats7080.FOCUS_H, cam, aspect, 1.06)
	if shot == "tempo":
		return _via(tempo.deck, Vector3(0, 0, .0), Vector3(0, 1, .55), Tempo7080.W / 2, tempo.plen / 2, cam, aspect, 1.08)
	if shot == "v_sofa_close":
		return [Vector3(3.0, 1.15, -4.2), sofa.global_position + Vector3(0, .5, 0)]
	for k in [["v_sofa", sofa], ["v_fax", fax], ["v_beats", beats], ["v_tempo", tempo], ["v_analyse", analyzer]]:
		if shot == k[0]:
			var tgt: Vector3 = (k[1] as Node3D).global_position + Vector3(0, .25, 0)
			return [EYE, EYE + (tgt - EYE).normalized() * 2.5]
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
	"v_back_left": [PI * .78, -.1],
	"v_booth": [0.0, .02],
	"v_back_right": [-PI * .78, -.1],
	"v_front_left": [PI * .25, -.15],
	"v_front_right": [-PI * .25, -.15],
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
	_animate_tod(dt)
	street.animate(t)
	# voyant ON AIR : allumé quand une machine joue
	if on_air_mat:
		var live: bool = beats.playing or (fax.player != null and fax.player.playing)
		on_air_mat.emission_energy_multiplier = move_toward(on_air_mat.emission_energy_multiplier, 3.0 if live else .08, dt * 12.0)
	# une voiture passe dans la rue toutes les ~25 s
	if street_car and not reduced:
		var cyc := fmod(t, 25.0) / 25.0
		street_car.position.x = lerpf(-22.0, 26.0, cyc * 1.6) if cyc < .62 else 40.0
	# les enceintes de proximité restent visibles autour de l'accordeur
	for m in modules.values():
		m.animate(t, dt, reduced)
