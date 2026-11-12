class_name Studio7080
extends Node3D
## Studio 70/80 : long établi en bois usé, mur en lames de bois avec grande fenêtre sur une pièce floue
## et chaude, spots au plafond, lampe d'architecte, TV cathodique orange. Vue de trois-quarts face.

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
	Mk.mi(Mk.plane(14, 14), Mk.mat(Mk.c(0x1a120c), .95), Vector3(0, -.78, 0), self)
	_build_wall(dark_wood)
	_build_window(dark_wood)
	_build_ceiling()
	_build_frames()
	_build_tower()
	_build_risers(dark_wood)
	_build_tv()
	_build_lamp()
	_build_chair()
	_build_cables()


func _build_wall(_dark: Material) -> void:
	var tex := Tex.canvas(2048, 1024, func(ci, w, h):
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
	var wall_mat := Mk.mat(Color.WHITE, .8, 0.0, {"map": tex})
	# mur 6 x 3,4 m centré en (0, .7) avec une ouverture pour la fenêtre
	var hx0: float = WIN.x - WIN.w / 2
	var hx1: float = WIN.x + WIN.w / 2
	var hy0: float = WIN.y - .7 - WIN.h / 2
	var hy1: float = WIN.y - .7 + WIN.h / 2
	var rects := [[-3.0, -1.7, hx0, 1.7], [hx1, -1.7, 3.0, 1.7], [hx0, -1.7, hx1, hy0], [hx0, hy1, hx1, 1.7]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var i0 := 0
	for rc in rects:
		var corners := [Vector2(rc[0], rc[1]), Vector2(rc[2], rc[1]), Vector2(rc[2], rc[3]), Vector2(rc[0], rc[3])]
		for p in corners:
			st.set_normal(Vector3.BACK)
			st.set_uv(Vector2(p.x / 6.0 + .5, .5 - p.y / 3.4))
			st.add_vertex(Vector3(p.x, p.y, 0))
		# sens horaire vu de face (+Z)
		for ix in [0, 2, 1, 0, 3, 2]:
			st.add_index(i0 + ix)
		i0 += 4
	st.generate_tangents()
	var wall := Mk.mi(st.commit(), wall_mat, Vector3(0, .7, WALL_Z - .02), self)
	wall.name = "Wall"


func _build_window(dark_wood: Material) -> void:
	# pièce de prise de son, floue et chaude, derrière la vitre
	var live := Tex.canvas(256, 128, func(ci, w, h):
		for y in h:
			ci.draw_rect(Rect2(0, y, w, 1), Mk.c(0x1a0f08).lerp(Mk.c(0x070403), float(y) / h))
		var r := Tex.rng(91)
		ci.draw_rect(Rect2(0, 82, w, 46), Color(0.35, 0.22, 0.12, .8))
		for i in 9:
			var bw := (60 + r.randf() * 140) / 4.0
			var bh := (80 + r.randf() * 200) / 4.0
			ci.draw_rect(Rect2(r.randf() * 250, 125 - bh, bw, bh), Color((20 + r.randf() * 30) / 255.0, (14 + r.randf() * 20) / 255.0, (10 + r.randf() * 10) / 255.0, .95))
		for i in 34:
			var cc := Vector2(r.randf() * 256, 10 + r.randf() * 75)
			var rad := 2.0 + r.randf() * 11.0
			var col := Color((220 + r.randf() * 35) / 255.0, (140 + r.randf() * 60) / 255.0, (60 + r.randf() * 40) / 255.0, .15 + r.randf() * .35)
			for k in 4:
				ci.draw_circle(cc, rad * (1.0 + k * .45), Color(col, col.a * (0.55 - k * .12)))
		ci.draw_rect(Rect2(175, 57, 23, 35), Color(1, .67, .35, .35))
		ci.draw_rect(Rect2(20, 65, 65, 63), Color(0, 0, 0, .6)))
	var live_mat := Mk.mat(Mk.c(0xd0c0b0), 1.0, 0.0, {"map": live, "unshaded": true, "fog_off": true})
	Mk.mi(Mk.quad(WIN.w, WIN.h), live_mat, Vector3(WIN.x, WIN.y, WALL_Z - .25), self)
	Mk.mi(Mk.quad(WIN.w, WIN.h), Mk.mat(Mk.c(0x0a0a0a), .05, 0.0, {"alpha": .28, "clearcoat": 1.0}), Vector3(WIN.x, WIN.y, WALL_Z), self)
	for b in [[WIN.x, WIN.y + WIN.h / 2 + .04, WIN.w + .16, .08], [WIN.x, WIN.y - WIN.h / 2 - .03, WIN.w + .16, .06]]:
		Mk.mi(Mk.box(Vector3(b[2], b[3], .3)), dark_wood, Vector3(b[0], b[1], WALL_Z - .12), self)
	for x in [WIN.x - WIN.w / 2 - .04, WIN.x + WIN.w / 2 + .04]:
		Mk.mi(Mk.box(Vector3(.08, WIN.h + .14, .3)), dark_wood, Vector3(x, WIN.y, WALL_Z - .12), self)


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


func _build_frames() -> void:
	var frames := [[1.25, 1.05, .32, .4], [1.68, 1.12, .26, .32], [1.3, .55, .36, .26]]
	var tints := [Mk.c(0x3a2414), Mk.c(0x2a1c12), Mk.c(0x4a2a14)]
	for i in frames.size():
		var f: Array = frames[i]
		Mk.mi(Mk.box(Vector3(f[2], f[3], .025)), Mk.mat(Mk.c(0x0d0a08), .5), Vector3(f[0], f[1], WALL_Z + .015), self)
		var tint: Color = tints[i]
		var pic := Tex.canvas(256, 256, func(ci, w, h):
			for y in 64:
				ci.draw_rect(Rect2(0, y * 4, w, 4), tint.lerp(Mk.c(0x0b0705), y / 64.0))
			ci.draw_circle(Vector2(128, 110), 50, Color(.9, .78, .59, .25))
			ci.draw_rect(Rect2(70, 160, 116, 96), Color(.9, .78, .59, .25)))
		Mk.mi(Mk.quad(f[2] - .05, f[3] - .05), Mk.mat(Color.WHITE, .1, 0.0, {"map": pic, "clearcoat": 1.0}), Vector3(f[0], f[1], WALL_Z + .029), self)


func _build_tower() -> void:
	var tower := Node3D.new()
	tower.name = "AmpTower"
	Mk.mi(Mk.rounded_box(Vector3(.5, .34, .42), .008, Mk.mat(Mk.c(0x141414), .5, 0.0, {"clearcoat": .2}), 3), null, Vector3(0, .17, 0), tower)
	var face := Tex.canvas(1024, 680, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x9d988f))
		Tex.brushed(ci, w, h, 71, .07)
		Tex.grime(ci, w, h, 72, 1.4)
		ci.draw_rect(Rect2(0, 330, w, 8), Mk.c(0x0b0b0b))
		ci.draw_rect(Rect2(80, 120, 360, 80), Mk.c(0x0b0b0b))
		ci.draw_rect(Rect2(90, 135, 200, 50), Color(1, .54, .16, .9))
		Tex.silk(ci, "RT-R2R   LINE AMP", 60, 60, 34, Color(.078, .078, .078, .85))
		for i in 6:
			ci.draw_circle(Vector2(560 + i * 70, 160), 22, Mk.c(0x1a1a1a))
		ci.draw_rect(Rect2(60, 420, 900, 200), Mk.c(0x2a2a2a))
		for i in 26:
			ci.draw_rect(Rect2(80 + i * 34, 440, 26, 70), Mk.c(0xcfcac0))
			ci.draw_rect(Rect2(80 + i * 34, 530, 26, 70), Mk.c(0xcfcac0)))
	Mk.mi(Mk.quad(.48, .32), Mk.mat(Color.WHITE, .5, .5, {"map": face}), Vector3(0, .17, .2105), tower)
	tower.position = Vector3(-1.12, 0, -.2)
	tower.rotation.y = .28
	add_child(tower)


func _build_risers(dark_wood: Material) -> void:
	var riser := Mk.mi(Mk.rounded_box(Vector3(.3, .1, .26), .006, Mk.mat(Mk.c(0x1a1a1a), .5), 2), null, Vector3(-.42, .05, -.32), self)
	riser.rotation.y = .12
	var rr := Mk.mi(Mk.rounded_box(Vector3(.6, .16, .4), .01, dark_wood, 2), null, Vector3(1.08, .08, -.25), self)
	rr.rotation.y = -.42


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


func _build_cables() -> void:
	var black := Mk.mat(Mk.c(0x0b0b0b), .55)
	var gold := Mk.mat(Mk.c(0xc9a040), .5)
	var curves := [
		[Vector3(-.9, .01, -.15), Vector3(-.75, .005, .05), Vector3(-.62, .005, .12)],
		[Vector3(-.35, .1, -.42), Vector3(-.1, .005, -.2), Vector3(.05, .005, -.1), Vector3(.3, .005, -.25)],
		[Vector3(.75, .16, -.3), Vector3(.6, .005, .1), Vector3(.75, .005, .3)],
	]
	for i in curves.size():
		Mk.mi(Mk.tube(curves[i], .005, 48, 8), gold if i == 2 else black, Vector3.ZERO, self)


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
