class_name Cat7080
extends Node3D
## Le compagnon du studio 70/80 : un chat roux tigré couché en « sphinx » sur le tapis.
## Fourrure en coques (core/shaders/fur.gdshader), yeux à pupille fendue, collier + médaille avec son nom.
## Réactions :
## - au tempo : le bout de la queue bat la mesure ; il hoche la tête en rythme quand de la musique joue ;
## - aux clics : il tourne la tête vers la machine qu'on vient d'ouvrir ;
## - au son : il se réveille, dresse les oreilles, sursaute sur un son fort et soudain ; il s'endort au calme ;
## - quand on le clique : il ronronne (yeux plissés, tête qui penche, petit son de ronron).
## Son nom : en gros plan sur lui, on tape au clavier (Entrée pour finir). Il s'affiche sur la médaille et la gamelle.
##
## Repère local : le chat regarde vers +Z. Actions : "chat:pet".

const SHELLS := 16

var engine: TempoEngine
var cat_name := ""
var fur: ShaderMaterial
var head: Node3D
var head_rest := Basis()
var ears: Array[Node3D] = []
var eyes: Array[Node3D] = []
var tail_joints: Array[Node3D] = []
var body: Node3D
var medal: TexLib.LiveCanvas
var bowl_label: TexLib.LiveCanvas
var editing := false
var no_blink := false   # captures d'écran

# état
var look_target := Vector3.ZERO
var look_until := 0.0
var awake := 0.9          # 0 = dort, 1 = bien réveillé
var startle := 0.0
var purr := 0.0
var blink_t := 0.0
var next_blink := 3.0
var ear_flick := [0.0, 0.0]
var _level := 0.0
var _level_slow := -60.0
var _quiet := 0.0
var _purr_player: AudioStreamPlayer
var _purr_gen: AudioStreamGeneratorPlayback
var _purr_phase := 0.0
var _yaw := 0.0
var _pitch := 0.0
var _roll := 0.0


func _init(e: TempoEngine) -> void:
	engine = e
	name = "Cat7080"
	cat_name = Store.get_v("cat_name", "")
	fur = ShaderMaterial.new()
	fur.shader = load("res://core/shaders/fur.gdshader")
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	_build_body()
	_build_head()
	_build_tail()
	_build_collar()
	_build_bowl()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = .15
	_purr_player = AudioStreamPlayer.new()
	_purr_player.stream = gen
	_purr_player.volume_db = -14.0
	add_child(_purr_player)
	ready.connect(func():
		Mk.add_pick(body, "chat:pet", 2, .01)
		Mk.add_pick(self, "m:chat", 1)
		_purr_player.play()
		_purr_gen = _purr_player.get_stream_playback(), CONNECT_ONE_SHOT)


# ---------------------------------------------------------------- fourrure
## Partie en fourrure : la peau + SHELLS coques. opts : stripe_dir, stripe_freq, belly, white, len, seed
func furry(mesh: Mesh, pos: Vector3, parent: Node3D, opts := {}) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	parent.add_child(g)
	for s in SHELLS + 1:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = fur
		if s > 0:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_instance_shader_parameter("shell", float(s) / SHELLS)
		mi.set_instance_shader_parameter("stripe_dir", opts.get("stripe_dir", Vector3(0, 0, 1)))
		mi.set_instance_shader_parameter("stripe_freq", opts.get("stripe_freq", 9.0))
		mi.set_instance_shader_parameter("belly", opts.get("belly", 0.0))
		mi.set_instance_shader_parameter("white", opts.get("white", 0.0))
		mi.set_instance_shader_parameter("len_scale", opts.get("len", 1.0))
		mi.set_instance_shader_parameter("seed", opts.get("seed", randf() * 10.0))
		if opts.has("holes"):
			mi.set_instance_shader_parameter("hole_a", opts.holes[0])
			mi.set_instance_shader_parameter("hole_b", opts.holes[1])
		g.add_child(mi)
	return g


func _build_body() -> void:
	# tronc allongé, poitrail, hanches
	furry(Mk.ellipsoid(.088, .078, .19), Vector3(0, .08, -.02), body, {"belly": 1.0, "stripe_freq": 7.0, "seed": 1.0})
	furry(Mk.ellipsoid(.075, .085, .085), Vector3(0, .1, .12), body, {"belly": 1.0, "stripe_dir": Vector3(0, 1, .3), "stripe_freq": 6.0, "seed": 2.0})
	for sx in [-1, 1]:
		# cuisses arrière repliées
		furry(Mk.ellipsoid(.045, .062, .09), Vector3(sx * .065, .066, -.12), body, {"stripe_dir": Vector3(0, 1, .4), "stripe_freq": 8.0, "seed": 3.0 + sx})
		furry(Mk.ellipsoid(.024, .018, .055), Vector3(sx * .075, .018, -.05), body, {"white": 1.0, "len": .7, "seed": 5.0 + sx})
		# pattes avant allongées devant
		furry(Mk.ellipsoid(.022, .024, .08), Vector3(sx * .038, .026, .19), body, {"stripe_dir": Vector3(0, 0, 1), "stripe_freq": 14.0, "seed": 7.0 + sx})
		furry(Mk.ellipsoid(.024, .016, .034), Vector3(sx * .04, .016, .27), body, {"white": 1.0, "len": .6, "seed": 9.0 + sx})


func _build_head() -> void:
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, .175, .17)
	body.add_child(head)
	var eye_l := Vector3(-.021, .013, .047)
	var eye_r := Vector3(.021, .013, .047)
	furry(Mk.ellipsoid(.056, .05, .054), Vector3.ZERO, head, {"stripe_dir": Vector3(1, 0, 0), "stripe_freq": 11.0, "len": .55, "seed": 11.0,
		"holes": [Vector4(eye_l.x, eye_l.y, eye_l.z, .0118), Vector4(eye_r.x, eye_r.y, eye_r.z, .0118)]})
	for sx in [-1, 1]:
		furry(Mk.ellipsoid(.03, .022, .028), Vector3(sx * .03, -.026, .024), head, {"belly": 1.0, "stripe_dir": Vector3(0, 1, 0), "stripe_freq": 14.0, "len": .6, "seed": 12.0 + sx})
	furry(Mk.ellipsoid(.026, .019, .024), Vector3(0, -.022, .043), head, {"white": 1.0, "len": .5, "seed": 14.0})
	furry(Mk.ellipsoid(.018, .012, .018), Vector3(0, -.037, .034), head, {"white": 1.0, "len": .5, "seed": 15.0})
	# truffe rose + bouche
	var nose := Mk.mi(Mk.ellipsoid(.0075, .005, .005), Mk.mat(Mk.c(0xc87a78), .35, 0.0, {"clearcoat": .6}), Vector3(0, -.011, .064), head)
	nose.rotation.x = .3
	Mk.mi(Mk.box(Vector3(.001, .008, .001)), Mk.mat(Mk.c(0x5a3030), .6), Vector3(0, -.02, .066), head)
	# oreilles : cône en fourrure + intérieur rose
	for sx in [-1, 1]:
		var ear := Node3D.new()
		ear.position = Vector3(sx * .033, .038, -.004)
		ear.rotation = Vector3(-.15, 0, -sx * .32)
		head.add_child(ear)
		furry(Mk.cyl(0.0, .022, .042, 16), Vector3(0, .017, 0), ear, {"stripe_freq": 0.0, "len": .5, "seed": 16.0 + sx})
		var inner := Mk.mi(Mk.cyl(0.0, .016, .03, 12, false), Mk.mat(Mk.c(0xd8968a), .7, 0.0, {"cull_off": true}), Vector3(0, .014, .008), ear)
		inner.scale = Vector3(1, 1, .45)
		ears.append(ear)
	# yeux : globe avec iris ambré et pupille fendue (shader), cornée vernie
	var eye_m := ShaderMaterial.new()
	eye_m.shader = load("res://core/shaders/cat_eye.gdshader")
	for sx in [-1, 1]:
		var eye := Node3D.new()
		eye.position = Vector3(sx * .021, .013, .045)
		eye.rotation = Vector3(-.1, sx * .3, 0)
		head.add_child(eye)
		Mk.mi(Mk.sphere(.0112, 24, 12), eye_m, Vector3.ZERO, eye)
		eyes.append(eye)
	# moustaches
	var wm := Mk.mat(Mk.c(0xf4f0e8), .4)
	for sx in [-1, 1]:
		for k in 4:
			var wsk := Mk.mi(Mk.cyl(.0003, .0005, .065, 4), wm, Vector3(sx * .045, -.022 + k * .0035, .05), head)
			wsk.rotation = Vector3(.1 - k * .06, 0, sx * (PI / 2 - .15 + k * .06))
			wsk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	head_rest = head.basis


func _build_tail() -> void:
	# queue posée au sol, enroulée sur le côté ; 9 segments articulés
	var parent: Node3D = body
	var pos := Vector3(.045, .03, -.19)
	for i in 9:
		var j := Node3D.new()
		j.position = pos
		j.rotation.y = .55 if i == 0 else .32
		parent.add_child(j)
		var r := .016 - i * .0009
		furry(Mk.ellipsoid(r, r * .95, .026), Vector3(0, 0, -.02), j, {"stripe_dir": Vector3(0, 0, 1), "stripe_freq": 10.0 if i < 7 else 0.0, "len": 1.2, "seed": 20.0 + i})
		tail_joints.append(j)
		parent = j
		pos = Vector3(0, -.0012 if i < 3 else 0.0, -.04)


func _build_collar() -> void:
	var collar := Mk.mi(Mk.torus_ring(.04, .005), Mk.mat(Mk.c(0x8a1a12), .45, 0.0, {"clearcoat": .4}), Vector3(0, .145, .155), body)
	collar.rotation.x = 1.2
	collar.scale = Vector3(1.15, 1, .85)
	medal = Tex.live(256, 256, func(ci, w, h):
		ci.draw_circle(Vector2(128, 128), 126, Mk.c(0xc89a48))
		ci.draw_arc(Vector2(128, 128), 116, 0, TAU, 64, Mk.c(0x8a6420), 4.0, true)
		var txt := cat_name if cat_name != "" else "?"
		if editing and int(Time.get_ticks_msec() / 500) % 2 == 0:
			txt += "|"
		Tex.silk(ci, txt, 128, 132, 64 if txt.length() < 7 else 44, Mk.c(0x3a2410), "center", 700))
	var sm := ShaderMaterial.new()
	sm.shader = load("res://core/shaders/paper.gdshader")
	sm.set_shader_parameter("paper_tex", medal.texture)
	sm.set_shader_parameter("roughness_v", .3)
	var md := Mk.mi(Mk.disc(.014, 32), sm, Vector3(0, .112, .2), body)
	md.rotation.x = PI / 2 - .25
	var rim := Mk.mi(Mk.cyl(.0145, .0145, .002, 32), Mk.mat(Mk.c(0x8a6420), .3, 1.0), Vector3(0, .112, .199), body)
	rim.rotation.x = PI / 2 - .25


## Coussin sous le chat, avec son nom brodé sur le devant.
func _build_bowl() -> void:
	bowl_label = Tex.live(1024, 160, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x2a4a3a))
		var txt := cat_name if cat_name != "" else "tape son nom"
		Tex.silk(ci, txt, w / 2.0, h / 2.0, 96 if cat_name != "" else 64, Mk.c(0xe8c070), "center", 700, "caveat"))
	var fabric := Mk.mat(Mk.c(0x2a4a3a), .95, 0.0, {"normal": _weave(), "normal_scale": .6, "rim": .3})
	fabric.uv1_scale = Vector3(6, 6, 1)
	Mk.mi(Mk.rounded_box(Vector3(.3, .03, .5), .014, fabric, 4), null, Vector3(0, .012, .0), self)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://core/shaders/paper.gdshader")
	sm.set_shader_parameter("paper_tex", bowl_label.texture)
	sm.set_shader_parameter("roughness_v", .9)
	Mk.mi(Mk.quad(.2, .031), sm, Vector3(0, .014, .2505), self)
	body.position.y = .027


func _weave() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_L8)
	for y in 64:
		for x in 64:
			var v := .6 + .4 * sin(x * .8) * sin(y * .8)
			img.set_pixel(x, y, Color(v, v, v))
	return Tex.normal_from_bump(img, 2.0)


# ---------------------------------------------------------------- réactions
## Tourne la tête vers un point du monde (la machine qu'on vient d'ouvrir).
func look_at_point(p: Vector3) -> void:
	look_target = p
	look_until = Time.get_ticks_msec() / 1000.0 + 4.5
	awake = maxf(awake, .8)


func on_action(a: String) -> void:
	if a == "pet":
		purr = 1.0
		awake = 1.0


func on_drag_start(_a: String) -> bool:
	return false


func on_drag(_rel: Vector2, _fine: bool) -> void:
	pass


func on_wheel(_a: String, _dir: float, _fine: bool) -> void:
	pass


## En gros plan sur le chat : on tape son nom.
func on_key(e: InputEventKey) -> bool:
	match e.keycode:
		KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE:
			if editing:
				editing = false
				_save_name()
				return e.keycode != KEY_ESCAPE
			return false
		KEY_BACKSPACE:
			editing = true
			cat_name = cat_name.left(-1)
		_:
			if e.unicode < 32:
				return false
			if not editing:
				editing = true
				cat_name = ""
			cat_name = (cat_name + char(e.unicode)).left(12)
	_save_name()
	return true


## Nom donné depuis les réglages.
func set_cat_name(n: String) -> void:
	cat_name = n.strip_edges().left(12)
	editing = false
	_save_name()


func _save_name() -> void:
	Store.set_v("cat_name", cat_name)
	medal.redraw()
	bowl_label.redraw()


func on_shot_changed(shot: String) -> void:
	if shot != "chat" and editing:
		editing = false
		_save_name()


func animate(t: float, dt: float, _reduced: bool) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	# --- écoute : niveau de sortie du studio
	var db := maxf(AudioServer.get_bus_peak_volume_left_db(0, 0), AudioServer.get_bus_peak_volume_right_db(0, 0))
	var lvl := clampf((db + 60.0) / 60.0, 0.0, 1.0)
	_level = lvl
	var music := db > -38.0 and purr < .3
	if db > _level_slow + 14.0 and db > -30.0:
		startle = 1.0
		awake = 1.0
	_level_slow = lerpf(_level_slow, db, 1.0 - pow(.97, dt * 60.0))
	if music:
		_quiet = 0.0
		awake = minf(1.0, awake + dt * .8)
	else:
		_quiet += dt
		if _quiet > 25.0 and purr < .05:
			awake = maxf(0.0, awake - dt * .05)
	startle = maxf(0.0, startle - dt * 2.2)
	purr = maxf(0.0, purr - dt / 6.0)
	# --- respiration (plus rapide en ronronnant)
	var br := sin(t * (1.6 if purr < .1 else 2.6)) * .5 + .5
	body.scale = Vector3(1.0 + br * .012, 1.0 + br * .02, 1.0)
	body.position.y = .027 + startle * .012 * sin(t * 40.0) + (purr * .0015 * sin(t * 160.0))
	# --- tête : regarde la machine ouverte, hoche en rythme, penche en ronronnant, baisse en dormant
	var yaw := 0.0
	var pitch := lerpf(.32, 0.0, awake)
	var roll := 0.0
	if now < look_until:
		var lp: Vector3 = (head.get_parent() as Node3D).to_local(look_target) - head.position
		yaw = clampf(atan2(lp.x, lp.z), -1.0, 1.0)
		pitch = clampf(-atan2(lp.y, Vector2(lp.x, lp.z).length()), -.5, .4)
	var beat := engine.beat_phase(t)
	if music:
		pitch += exp(-beat * 6.0) * .08
	if purr > .05:
		roll = .25 * purr
		pitch += .05 * purr
	pitch -= startle * .25
	var k := 1.0 - pow(.9, dt * 60.0)
	_yaw = lerpf(_yaw, yaw, k)
	_pitch = lerpf(_pitch, pitch, k)
	_roll = lerpf(_roll, roll, k * .5)
	head.basis = head_rest * Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, _pitch) * Basis(Vector3.BACK, _roll)
	# --- oreilles : dressées au son, en arrière au sursaut, petits frémissements
	for i in ears.size():
		var sx := -1.0 if i == 0 else 1.0
		if randf() < dt * .15:
			ear_flick[i] = 1.0
		ear_flick[i] = maxf(0.0, ear_flick[i] - dt * 6.0)
		var back := startle * .7 - (.15 if music else 0.0) + (.2 * (1.0 - awake))
		ears[i].rotation = Vector3(-.15 - back, sx * ear_flick[i] * .4, -sx * (.32 + back * .5))
	# --- yeux : clignements, fermés en dormant / en ronronnant, grands ouverts au sursaut
	blink_t -= dt
	if blink_t <= 0.0 and now > next_blink and not no_blink:
		blink_t = .14
		next_blink = now + randf_range(2.5, 6.0)
	var open := clampf(awake * 1.1, .05, 1.0)
	if purr > .1:
		open = .15
	if blink_t > 0.0:
		open = .05
	open = maxf(open, startle)
	for e in eyes:
		e.scale.y = lerpf(e.scale.y, open, 1.0 - pow(.6, dt * 60.0))
	# --- queue : vague lente, le bout bat la mesure quand il y a de la musique
	var tempo_wave := sin(beat * TAU) if music else 0.0
	for i in tail_joints.size():
		var base := .55 if i == 0 else .32
		var amp := (.04 + .06 * awake) * (i / 9.0)
		var wave := sin(t * 1.3 - i * .5) * amp
		if i >= 6:
			wave += tempo_wave * .25 * (i - 5) / 3.0
		if purr > .1:
			wave += sin(t * 3.0 - i * .6) * .08 * purr
		tail_joints[i].rotation.y = base + wave
		tail_joints[i].rotation.x = -.15 * startle if i > 5 else 0.0
	# --- ronron (grave, pulsé)
	if _purr_gen:
		var n := _purr_gen.get_frames_available()
		for i in n:
			_purr_phase += 1.0 / 22050.0
			var pulse := pow(maxf(0.0, sin(_purr_phase * TAU * 24.0)), 3.0)
			var v := (randf() * 2.0 - 1.0) * pulse * .5 * clampf(purr * 1.5, 0.0, 1.0)
			_purr_gen.push_frame(Vector2(v, v))
	if editing and int(t * 2.0) != int((t - dt) * 2.0):
		medal.redraw()
