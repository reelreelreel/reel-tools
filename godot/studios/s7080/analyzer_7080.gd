class_name Analyzer7080
extends Node3D
## Module Analyse du studio 70/80 : magnéto à bandes posé sur le retour, avec un petit écran vert.
## On glisse un morceau ou une prod (WAV, MP3, AIFF…) : les bobines tournent pendant l'analyse, puis
## l'écran affiche le BPM (+ moitié / double) et la tonalité (+ autres possibilités).
##
## Repère local : avant vers +Z. Actions : "analyse:load", "analyse:play", "analyse:stop".

const W := .44
const D := .32

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


## Plateau arrière : deux bobines, guide-bande, têtes.
func _build_top() -> void:
	var plate_tex := Tex.canvas(1024, int(1024 * .2 / W), func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xa9a59e))
		Tex.brushed(ci, w, h, 66, .07, 3000)
		Tex.grime(ci, w, h, 67, 1.2)
		Tex.silk(ci, "REEL'S TOOLS  ·  RT-R2A  ANALYSEUR", w / 2.0, h * .92, 22, Color(.08, .08, .08, .8), "center"))
	var plate := Mk.mat(Color.WHITE, .5, .6, {"map": plate_tex})
	Mk.mi(Mk.rounded_box(Vector3(W, .004, .2), .001, [plate, plate, plate, plate, plate, plate], 1), null, Vector3(0, .087, -D / 2 + .1), self)
	var reel_tex := Tex.canvas(512, 512, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Color.BLACK)
		ci.draw_circle(Vector2(256, 256), 250, Mk.c(0xc9c5bd))
		for k in 3:
			var a := k * 2.094
			var cc := Vector2(256, 256) + Vector2(sin(a), -cos(a)) * 140.0
			var pts := PackedVector2Array()
			for s in 32:
				var th := s / 32.0 * TAU
				pts.append(cc + Vector2(cos(th) * 60.0, sin(th) * 80.0).rotated(a))
			ci.draw_colored_polygon(pts, Mk.c(0x1a1612))
		ci.draw_circle(Vector2(256, 256), 34, Color.BLACK))
	var reel_mat := Mk.mat(Color.WHITE, .45, .5, {"map": reel_tex})
	var tape := Mk.mat(Mk.c(0x2a1c12), .35, 0.0, {"clearcoat": .4})
	for s in [-1, 1]:
		var g := Node3D.new()
		g.position = Vector3(s * .11, .089, -D / 2 + .095)
		add_child(g)
		var r := .062 if s < 0 else .04
		Mk.mi(Mk.cyl(r, r, .009, 64), tape, Vector3(0, .006, 0), g)
		Mk.mi(Mk.disc(.085, 64), reel_mat, Vector3(0, .0115, 0), g)
		Mk.mi(Mk.cyl(.008, .008, .018, 16), Mk.chrome_mat(), Vector3(0, .009, 0), g)
		reels.append(g)
	# têtes + bande
	Mk.mi(Mk.rounded_box(Vector3(.07, .02, .025), .003, Mk.mat(Mk.c(0x2a2a2a), .4, .5)), null, Vector3(0, .099, -D / 2 + .17), self)
	Mk.mi(Mk.box(Vector3(.2, .008, .0015)), tape, Vector3(0, .1, -D / 2 + .158), self)
	for x in [-.05, .05]:
		Mk.mi(Mk.cyl(.005, .005, .02, 12), Mk.chrome_mat(), Vector3(x, .099, -D / 2 + .16), self)


## Pupitre avant en pente : petit écran vert, touches, voyant.
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
		Tex.brushed(ci, w, h, 70, .05, 2000)
		var ink := Color(.9, .88, .82, .7)
		Tex.silk(ci, "CHARGER", P.call(-.17), h * .86, 20, ink, "center")
		Tex.silk(ci, "LECTURE", P.call(-.125), h * .86, 20, ink, "center")
		Tex.silk(ci, "STOP", P.call(-.08), h * .86, 20, ink, "center")
		Tex.silk(ci, "GLISSE UN MORCEAU (WAV · MP3 · AIFF)", P.call(.07), h * .93, 16, Color(.9, .88, .82, .45), "center"))
	var fm := Mk.mat(Color.WHITE, .45, .5, {"map": ftex})
	Mk.mi(Mk.rounded_box(Vector3(W, .004, plen), .001, [fm, fm, fm, fm, fm, fm], 1), null, Vector3.ZERO, front)
	# écran vert
	screen = Tex.live(640, 320, _draw_screen)
	var win := Mk.screen_window(Mk.glow(Color.WHITE, 1.2, screen.texture), .2, .1, Mk.c(0x0b1a0e))
	win.position = Vector3(.07, .003, -.008)
	front.add_child(win)
	# touches de transport
	var acts := [[-.17, "analyse:load", Mk.c(0xd8d2c4)], [-.125, "analyse:play", Mk.c(0x3a8a4a)], [-.08, "analyse:stop", Mk.c(0x1a1a1a)]]
	for a in acts:
		var key := Mk.mi(Mk.rounded_box(Vector3(.034, .014, .034), .004, Mk.mat(a[2], .4, 0.0, {"clearcoat": .4}), 2), null, Vector3(a[0], .008, -.006), front)
		Mk.add_pick_later(key, a[1], .004)
	_rec_led = Mk.glow(Mk.c(0xff3d22), .1) as StandardMaterial3D
	Mk.mi(Mk.cyl(.003, .003, .003, 12), _rec_led, Vector3(-.03, .004, -.02), front)


func _draw_screen(ci: CanvasItem, w: float, h: float) -> void:
	ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x020a04))
	var g := Color(.49, 1, .61, .9)
	var dim := Color(.49, 1, .61, .45)
	var f := Tex.font("mono")
	match state:
		"idle":
			ci.draw_string(f, Vector2(24, 70), "RT-R2A  ANALYSEUR", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, g)
			ci.draw_string(f, Vector2(24, 140), "GLISSE UN MORCEAU", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, dim)
			ci.draw_string(f, Vector2(24, 185), "OU APPUIE SUR CHARGER", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, dim)
			if int(_t * 2.0) % 2 == 0:
				ci.draw_rect(Rect2(24, 215, 18, 30), g)
		"busy":
			ci.draw_string(f, Vector2(24, 70), "ANALYSE EN COURS", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, g)
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
			ci.draw_string(f, Vector2(330, 62), "ou " + " / ".join(alts), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, dim)
			ci.draw_string(f, Vector2(24, 150), "KEY", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, dim)
			ci.draw_string(f, Vector2(110, 154), k.best.short, HORIZONTAL_ALIGNMENT_LEFT, -1, 52, g)
			ci.draw_string(f, Vector2(250, 150), k.best.long.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, g)
			var ka := []
			for a in k.alts:
				ka.append(a.short)
			ci.draw_string(f, Vector2(24, 222), "AUTRES : " + "  ".join(ka), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, dim)
			ci.draw_string(f, Vector2(24, 268), "RELATIVE : " + k.best.relative, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, dim)
			ci.draw_string(f, Vector2(24, 306), file_name.left(34), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(.49, 1, .61, .3))
		"error":
			ci.draw_string(f, Vector2(24, 90), "ERREUR", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, g)
			ci.draw_string(f, Vector2(24, 150), str(result.get("err", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, dim)
			ci.draw_string(f, Vector2(24, 200), "ESSAIE UN AUTRE FICHIER", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, dim)
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
	if state == "busy" or state == "idle":
		if t - _last_draw > 1.0 / 20.0:
			_last_draw = t
			screen.redraw()
