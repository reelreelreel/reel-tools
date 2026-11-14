class_name Analyzer7080
extends Node3D
## Module Analyse du studio 70/80 : magnéto à bandes posé sur le retour, avec un petit écran vert.
## On glisse un morceau ou une prod (WAV, MP3, AIFF…) : les bobines tournent pendant l'analyse, puis
## l'écran affiche le BPM (+ moitié / double) et la tonalité (+ autres possibilités).
##
## Repère local : avant vers +Z. Actions : "analyse:load", "analyse:play", "analyse:stop".

const W := .44
const D := .34

var screen: TexLib.LiveCanvas
var reels: Array[Node3D] = []
var dialog: FileDialog
var player: AudioStreamPlayer
var result := {}
var state := "idle"        # idle | busy | done | error
var file_name := ""
var _task := -1
var _task_result := {}
var _t := 0.0
var _last_draw := -1.0
var _rec_led: StandardMaterial3D
var vu_needles: Array[Node3D] = []
var _vu := [0.0, 0.0]


func _init(walnut: Material) -> void:
	name = "Analyzer7080"
	ready.connect(func(): Mk.add_pick(self, "m:analyse", 1), CONNECT_ONE_SHOT)
	var black := Mk.mat(Mk.c(0x141414), .45, .2)
	# caisse : arrière plat (bobines), avant en pente (écran + touches)
	var prof := PackedVector2Array([Vector2(-D / 2, 0), Vector2(D / 2, 0), Vector2(D / 2, .05), Vector2(D / 2 - .12, .085), Vector2(-D / 2, .085)])
	var body := Mk.mi(Mk.prism(prof, W), Mk.mat(Mk.c(0x1c1a18), .5, .3), Vector3(W / 2, 0, 0), self)
	body.rotation.y = -PI / 2
	for sx in [-1, 1]:
		var cheek := Mk.mi(Mk.prism(PackedVector2Array([Vector2(-D / 2 - .005, 0), Vector2(D / 2 + .005, 0), Vector2(D / 2 + .005, .055), Vector2(D / 2 - .12, .092), Vector2(-D / 2 - .005, .092)]), .018), walnut, Vector3(sx * (W / 2 + .009) + .009, 0, 0), self)
		cheek.rotation.y = -PI / 2
	_build_top()
	_build_front(black)
	dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.filters = PackedStringArray(["*.wav, *.wave, *.mp3, *.aif, *.aiff, *.m4a, *.flac ; Morceaux audio"])
	dialog.title = "Choisis un morceau ou une prod"
	dialog.file_selected.connect(load_track)
	add_child(dialog)
	player = AudioStreamPlayer.new()
	add_child(player)


## Plateau arrière : deux bobines métal (NAB) avec la bande visible, chemin de bande complet
## (guides, bras de tension, têtes, cabestan, galet presseur), compteur, sélecteur de vitesse, vis.
func _build_top() -> void:
	var py := .087
	var pz := -D / 2 + .115   # centre du plateau
	var plate_tex := Tex.canvas(1024, int(1024 * .23 / W), func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xa9a59e))
		Tex.brushed(ci, w, h, 66, .07, 4000)
		Tex.grime(ci, w, h, 67, 2.5)
		var r := Tex.rng(68)
		for i in 60:  # usure autour des bobines et des têtes
			ci.draw_circle(Vector2(w * (.5 + r.randf_range(-.35, .35)), h * r.randf_range(.1, .9)), r.randf_range(4, 30), Color(.2, .15, .1, .04))
		Tex.silk(ci, "REEL'S TOOLS  ·  RT-R2A  TRACK ANALYZER", w / 2.0, h * .93, 20, Color(.08, .08, .08, .8), "center")
		Tex.silk(ci, "7½", w * .86, h * .77, 16, Color(.08, .08, .08, .7), "center")
		Tex.silk(ci, "15 IPS", w * .93, h * .77, 16, Color(.08, .08, .08, .7), "center"))
	var plate := Mk.mat(Color.WHITE, .5, .6, {"map": plate_tex, "normal": Mk.scratch_normal(), "normal_scale": .2})
	Mk.mi(Mk.rounded_box(Vector3(W, .004, .23), .001, [plate, plate, plate, plate, plate, plate], 1), null, Vector3(0, py, pz), self)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var sc := Mk.screw_head(.0035)
			sc.position = Vector3(sx * (W / 2 - .012), py + .002, pz + sz * (.115 - .01))
			add_child(sc)
	# bobines : deux flasques alu ajourées, galette de bande marron entre les deux, moyeu
	var flange_tex := Tex.canvas(512, 512, func(ci, w, h):
		# on ne dessine que la matière (le reste reste transparent) : jante, 3 rayons, moyeu
		var c := Vector2(256, 256)
		var alu := Mk.c(0xb8b4ac)
		ci.draw_arc(c, 236, 0, TAU, 128, alu, 34.0, true)
		ci.draw_arc(c, 60, 0, TAU, 64, alu, 44.0, true)
		for k in 3:
			var a0 := k * TAU / 3.0 - PI / 2 + .62
			var a1 := a0 + TAU / 3.0 - 1.24
			var pts := PackedVector2Array()
			for s in 12:
				var th := lerpf(a1, a0 + TAU / 3.0, s / 11.0)
				pts.append(c + Vector2(cos(th), sin(th)) * 222)
			for s in 12:
				var th := lerpf(a0 + TAU / 3.0 - .12, a1 + .12, s / 11.0)
				pts.append(c + Vector2(cos(th), sin(th)) * 78)
			ci.draw_colored_polygon(pts, alu)
		for i in 30:
			ci.draw_arc(c, 90 + i * 4.4, 0, TAU, 96, Color(1, 1, 1, .04 if i % 2 else 0.0), 2.0)
		ci.draw_circle(c, 40, Mk.c(0x8a8680))
		ci.draw_rect(Rect2(150, 400, 210, 40), Mk.c(0xe8e0c8))
		Tex.silk(ci, "MIX 3  ·  MASTER", 255, 420, 24, Color(.1, .1, .3, .85), "center", 600, "caveat"), true)
	var flange := Mk.mat(Color.WHITE, .3, .85, {"map": flange_tex})
	flange.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	flange.alpha_scissor_threshold = .5
	flange.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tape := Mk.mat(Mk.c(0x3a2414), .3, 0.0, {"clearcoat": .6, "clearcoat_rough": .2})
	var tape_edge := Mk.mat(Mk.c(0x5a3a22), .25, .2)
	for s in [-1, 1]:
		var g := Node3D.new()
		g.position = Vector3(s * .112, py + .002, pz - .02)
		add_child(g)
		var r := .068 if s < 0 else .042
		Mk.mi(Mk.cyl(r, r, .012, 72), tape, Vector3(0, .009, 0), g)
		Mk.mi(Mk.disc(r - .001, 72), tape_edge, Vector3(0, .0152, 0), g)
		Mk.mi(Mk.disc(.088, 72), flange, Vector3(0, .0025, 0), g)
		Mk.mi(Mk.disc(.088, 72), flange, Vector3(0, .0165, 0), g)
		Mk.mi(Mk.cyl(.02, .02, .016, 24), Mk.mat(Mk.c(0x8a8680), .35, .8), Vector3(0, .009, 0), g)
		Mk.mi(Mk.cyl(.007, .007, .026, 12), Mk.chrome_mat(), Vector3(0, .013, 0), g)
		reels.append(g)
	# chemin de bande : galette gauche -> guide -> bras -> têtes -> cabestan -> bras -> galette droite
	var ty := py + .013
	var path := [Vector3(-.112 + .03, ty, pz + .02), Vector3(-.075, ty, pz + .058), Vector3(-.04, ty, pz + .066),
		Vector3(.04, ty, pz + .066), Vector3(.06, ty, pz + .063), Vector3(.075, ty, pz + .058), Vector3(.112 - .02, ty, pz + .01)]
	for i in path.size() - 1:
		var a: Vector3 = path[i]
		var b: Vector3 = path[i + 1]
		var seg := Mk.mi(Mk.box(Vector3(a.distance_to(b), .0075, .0012)), tape, (a + b) / 2, self)
		seg.rotation.y = -atan2(b.z - a.z, b.x - a.x)
	for p in [path[1], path[5]]:
		Mk.mi(Mk.cyl(.006, .006, .022, 16), Mk.chrome_mat(), Vector3(p.x, py + .011, p.z), self)
	# bras de tension
	for sx in [-1, 1]:
		var arm := Mk.mi(Mk.box(Vector3(.05, .004, .006)), Mk.chrome_mat(), Vector3(sx * .09, py + .006, pz + .07), self)
		arm.rotation.y = sx * .5
	# bloc têtes (effacement, enregistrement, lecture) sous capot
	Mk.mi(Mk.rounded_box(Vector3(.07, .02, .024), .004, Mk.mat(Mk.c(0x2a2a2a), .35, .6)), null, Vector3(0, py + .01, pz + .08), self)
	for x in [-.025, 0.0, .025]:
		Mk.mi(Mk.rounded_box(Vector3(.012, .014, .008), .002, Mk.mat(Mk.c(0x8a8680), .25, .9)), null, Vector3(x, py + .01, pz + .07), self)
	# cabestan + galet presseur
	Mk.mi(Mk.cyl(.0035, .0035, .025, 12), Mk.chrome_mat(), Vector3(.058, py + .012, pz + .067), self)
	Mk.mi(Mk.cyl(.011, .011, .014, 24), Mk.mat(Mk.c(0x111111), .7), Vector3(.058, py + .009, pz + .079), self)
	# sélecteur de vitesse
	var sel := Mk.knob(.009, .012)
	sel.position = Vector3(.19, py + .002, pz + .065)
	add_child(sel)


## Pupitre avant en pente : touches de transport, compteur, deux VU, écran vert agrandi.
func _build_front(black: Material) -> void:
	var slope := atan2(.085 - .05, .12)
	var front := Node3D.new()
	front.position = Vector3(0, (.085 + .05) / 2 + .001, D / 2 - .06)
	front.rotation.x = slope
	add_child(front)
	var plen := sqrt(.12 * .12 + .035 * .035)
	var ftex := Tex.canvas(1024, int(1024 * plen / W), func(ci, w, h):
		var P := func(m: float) -> float: return (m + W / 2) / W * w
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x1c1b1a))
		Tex.brushed(ci, w, h, 70, .05, 2500)
		Tex.grime(ci, w, h, 71, 1.5)
		var ink := Color(.9, .88, .82, .7)
		for b in [[-.19, "LOAD"], [-.155, "PLAY"], [-.12, "STOP"]]:
			Tex.silk(ci, b[1], P.call(b[0]), h * .88, 15, ink, "center")
		Tex.silk(ci, "L", P.call(-.072), h * .9, 14, ink, "center")
		Tex.silk(ci, "R", P.call(-.027), h * .9, 14, ink, "center")
		Tex.silk(ci, "COUNTER", P.call(-.155), h * .1, 13, Color(.9, .88, .82, .5), "center")
		Tex.silk(ci, "DROP A TRACK  ·  WAV  MP3  AIFF", P.call(.105), h * .95, 14, Color(.9, .88, .82, .45), "center"))
	var fm := Mk.mat(Color.WHITE, .45, .5, {"map": ftex})
	Mk.mi(Mk.rounded_box(Vector3(W, .004, plen), .001, [fm, fm, fm, fm, fm, fm], 1), null, Vector3.ZERO, front)
	# écran vert (plus grand)
	screen = Tex.live(640, 320, _draw_screen)
	var win := Mk.screen_window(Mk.glow(Color.WHITE, 1.25, screen.texture), .2, .1, Mk.c(0x0b1a0e))
	win.position = Vector3(.105, .003, -.006)
	front.add_child(win)
	# touches de transport
	var acts := [[-.19, "analyse:load", Mk.c(0xd8d2c4)], [-.155, "analyse:play", Mk.c(0x3a8a4a)], [-.12, "analyse:stop", Mk.c(0x1a1a1a)]]
	for a in acts:
		var key := Mk.mi(Mk.rounded_box(Vector3(.028, .013, .03), .004, Mk.mat(a[2], .4, 0.0, {"clearcoat": .4}), 2), null, Vector3(a[0], .008, .006), front)
		Mk.add_pick_later(key, a[1], .004)
	# compteur mécanique
	var counter := Tex.canvas(256, 96, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x0c0c0c))
		for i in 4:
			ci.draw_rect(Rect2(8 + i * 61, 8, 54, 80), Mk.c(0xe8e4da))
			Tex.silk(ci, "0412"[i], 35 + i * 61, 48, 56, Mk.c(0x111111), "center", 600, "mono"))
	Mk.mi(Mk.plane(.05, .019), Mk.mat(Color.WHITE, .5, 0.0, {"map": counter}), Vector3(-.155, .0025, -.032), front)
	# deux VU-mètres qui suivent le son en lecture
	var vu := Tex.canvas(256, 160, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xe9d9aa))
		ci.draw_arc(Vector2(128, 190), 150, -2.3, -.84, 32, Mk.c(0x1a1a1a), 2.0, true)
		ci.draw_arc(Vector2(128, 190), 154, -1.12, -.84, 16, Mk.c(0xb3241a), 4.0, true)
		Tex.silk(ci, "VU", 128, 118, 28, Mk.c(0x1a1a1a), "center"))
	var vu_mat := Mk.mat(Mk.c(0xb8b0a0), .8, 0.0, {"map": vu, "emission": Mk.c(0xffb060), "energy": .08, "emission_tex": vu})
	for i in 2:
		var x := -.072 + i * .045
		var box := Node3D.new()
		box.position = Vector3(x, .003, -.004)
		front.add_child(box)
		Mk.mi(Mk.rounded_box(Vector3(.042, .004, .03), .002, Mk.mat(Mk.c(0x0a0a0a), .4)), null, Vector3.ZERO, box)
		Mk.mi(Mk.plane(.038, .025), vu_mat, Vector3(0, .0025, 0), box)
		var pv := Node3D.new()
		pv.position = Vector3(0, .003, .013)
		box.add_child(pv)
		Mk.mi(Mk.box(Vector3(.0006, .0004, .022)), Mk.mat(Mk.c(0x111111), .5), Vector3(0, 0, -.011), pv)
		vu_needles.append(pv)
	_rec_led = Mk.glow(Mk.c(0xff3d22), .1) as StandardMaterial3D
	Mk.mi(Mk.cyl(.0028, .0028, .003, 12), _rec_led, Vector3(-.19, .004, -.03), front)


func _draw_screen(ci: CanvasItem, w: float, h: float) -> void:
	ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x020a04))
	var g := Color(.49, 1, .61, .9)
	var dim := Color(.49, 1, .61, .45)
	var f := Tex.font("mono")
	match state:
		"idle":
			ci.draw_string(f, Vector2(24, 70), "RT-R2A  ANALYZER", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, g)
			ci.draw_string(f, Vector2(24, 140), "DROP A TRACK", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, dim)
			ci.draw_string(f, Vector2(24, 185), "OR PRESS LOAD", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, dim)
			if int(_t * 2.0) % 2 == 0:
				ci.draw_rect(Rect2(24, 215, 18, 30), g)
		"busy":
			ci.draw_string(f, Vector2(24, 70), "ANALYZING...", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, g)
			ci.draw_string(f, Vector2(24, 115), file_name.left(26), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, dim)
			var pts := PackedVector2Array()
			for x in range(0, int(w), 6):
				pts.append(Vector2(x, 220 + sin(x * .05 + _t * 9.0) * 40.0 * sin(x * .013 + _t * 2.0)))
			ci.draw_polyline(pts, Color(.36, 1, .5, .3), 8.0, true)
			ci.draw_polyline(pts, g, 2.5, true)
		"done":
			var b: Dictionary = result.bpm
			var k: Dictionary = result.key
			ci.draw_string(f, Vector2(24, 62), "BPM", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, dim)
			ci.draw_string(f, Vector2(110, 66), _fmt_bpm(b.bpm), HORIZONTAL_ALIGNMENT_LEFT, -1, 52, g)
			var alts := []
			for a in b.alts:
				alts.append(_fmt_bpm(a))
			ci.draw_string(f, Vector2(330, 62), "or " + " / ".join(alts), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, dim)
			ci.draw_string(f, Vector2(24, 150), "KEY", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, dim)
			ci.draw_string(f, Vector2(110, 154), k.best.short, HORIZONTAL_ALIGNMENT_LEFT, -1, 52, g)
			ci.draw_string(f, Vector2(250, 150), k.best.long.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, g)
			var ka := []
			for a in k.alts:
				ka.append(a.short)
			ci.draw_string(f, Vector2(24, 222), "ALSO : " + "  ".join(ka), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, dim)
			ci.draw_string(f, Vector2(24, 268), "RELATIVE : " + k.best.relative, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, dim)
			ci.draw_string(f, Vector2(24, 306), file_name.left(34), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(.49, 1, .61, .3))
		"error":
			ci.draw_string(f, Vector2(24, 90), "ERROR", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, g)
			ci.draw_string(f, Vector2(24, 150), str(result.get("err", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, dim)
			ci.draw_string(f, Vector2(24, 200), "TRY ANOTHER FILE", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, dim)
	# lignes de balayage
	for y in range(0, int(h), 4):
		ci.draw_rect(Rect2(0, y, w, 1), Color(0, 0, 0, .25))


static func _fmt_bpm(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v


# ---------------------------------------------------------------- logique
func load_track(path: String) -> void:
	if state == "busy":
		return
	file_name = path.get_file()
	state = "busy"
	player.stop()
	_task_result = {}
	_task = WorkerThreadPool.add_task(func(): _task_result = TrackAnalyzer.analyze_file(path))
	# pour l'écoute : le fichier d'origine quand Godot sait le lire, sinon la version décodée
	var ext := path.get_extension().to_lower()
	if ext == "mp3":
		player.stream = AudioStreamMP3.load_from_file(path)
	elif ext == "wav" or ext == "wave":
		player.stream = AudioStreamWAV.load_from_file(path)
	else:
		var dec := AudioDecode.to_wav(path)
		player.stream = AudioStreamWAV.load_from_file(dec.path) if dec.ok else null
	screen.redraw()


func on_files(paths: PackedStringArray) -> void:
	if not paths.is_empty():
		load_track(paths[0])


func on_action(a: String) -> void:
	match a:
		"load":
			dialog.popup_centered()
		"play":
			if player.stream:
				if player.playing:
					player.stream_paused = not player.stream_paused
				else:
					player.play()
		"stop":
			player.stop()


func on_drag_start(_a: String) -> bool:
	return false


func on_drag(_rel: Vector2, _fine: bool) -> void:
	pass


func on_wheel(_a: String, _dir: float, _fine: bool) -> void:
	pass


func on_key(e: InputEventKey) -> bool:
	match e.keycode:
		KEY_L, KEY_O:
			on_action("load")
		KEY_SPACE, KEY_P:
			on_action("play")
		KEY_S:
			on_action("stop")
		_:
			return false
	return true


## Attente bloquante de l'analyse en cours (tests).
func wait_done() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_finish()


func _finish() -> void:
	result = _task_result
	state = "done" if result.get("ok", false) else "error"
	screen.redraw()


func animate(t: float, dt: float, _reduced: bool) -> void:
	_t = t
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_finish()
	var speed := 0.0
	if state == "busy":
		speed = 14.0
	elif player.playing and not player.stream_paused:
		speed = 2.2
	for i in reels.size():
		reels[i].rotation.y -= speed * dt * (1.0 if i == 0 else 1.4)
	_rec_led.emission_energy_multiplier = (2.0 if sin(t * 8.0) > 0 else .2) if state == "busy" else (1.2 if player.playing else .1)
	# VU : niveau de sortie réel pendant la lecture
	for i in 2:
		var db := AudioServer.get_bus_peak_volume_left_db(0, 0) if i == 0 else AudioServer.get_bus_peak_volume_right_db(0, 0)
		var lvl := clampf((db + 30.0) / 33.0, 0.0, 1.0) if player.playing and not player.stream_paused else 0.0
		_vu[i] += (lvl - _vu[i]) * (1.0 - pow(.82, dt * 60.0))
		vu_needles[i].rotation.y = .7 - _vu[i] * 1.4
	if state == "busy" or state == "idle":
		if t - _last_draw > 1.0 / 20.0:
			_last_draw = t
			screen.redraw()
