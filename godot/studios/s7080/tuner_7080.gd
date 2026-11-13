class_name Tuner7080
extends Node3D
## Module Accordeur 808 du studio 70/80 : petit boîtier posé sur le pont de la console.
## On glisse un sample (WAV) sur la fenêtre, ou on clique CHARGER : l'aiguille montre l'écart en cents,
## la lampe de la note s'allume, l'octave et la fréquence s'affichent en LED rouges.
##
## Repère local : façade vers +Z. Actions : "tuner:load". Corps entier : "m:tuner".

const W := .28
const H := .17
const DEPTH := .13

var result := {}
var face: Node3D
var needle: Node3D
var needle_angle := -.9
var needle_vel := 0.0
var lamps: Array[StandardMaterial3D] = []
var led_hz: TexLib.LiveCanvas
var led_oct: TexLib.LiveCanvas
var dialog: FileDialog
var file_name := ""

const REST := -.9        # aiguille au repos (calée à gauche)
const SWING := .75       # angle pour ±50 cents


func _init(walnut: Material) -> void:
	name = "Tuner7080"
	ready.connect(func(): Mk.add_pick(self, "m:tuner", 1), CONNECT_ONE_SHOT)
	# caisson en noyer
	Mk.mi(Mk.rounded_box(Vector3(W, H, DEPTH), .01, walnut, 3), null, Vector3(0, H / 2, -DEPTH / 2), self)
	face = Node3D.new()
	face.name = "Face"
	face.position = Vector3(0, H / 2, .001)
	add_child(face)
	_build_face()
	_build_meter()
	_build_lamps()
	_build_leds()
	_build_button()
	dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.filters = PackedStringArray(["*.wav ; Sample WAV"])
	dialog.title = "Choisis un sample de 808 / kick"
	dialog.file_selected.connect(load_sample)
	add_child(dialog)


func _build_face() -> void:
	var tex := Tex.canvas(1024, int(1024 * (H - .012) / (W - .012)), func(ci, w, h):
		var P := func(m: float) -> float: return (m + (W - .012) / 2) / (W - .012) * w
		var V := func(m: float) -> float: return ((H - .012) / 2 - m) / (H - .012) * h
		var ink := Color(.9, .88, .82, .85)
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x1c1b1a))
		Tex.brushed(ci, w, h, 808, .05, 3000)
		Tex.grime(ci, w, h, 809, 1.2)
		Tex.silk(ci, "OCT", P.call(-.025), V.call(-.048), 20, Color(.9, .88, .82, .6), "center")
		Tex.silk(ci, "HZ", P.call(.118), V.call(-.065), 22, Color(.9, .88, .82, .6), "center")
		Tex.silk(ci, "CHARGER", P.call(-.1), V.call(-.048), 20, Color(.9, .88, .82, .6), "center")
		Tex.silk(ci, "OU GLISSE", P.call(-.083), V.call(-.06), 15, Color(.9, .88, .82, .45), "left")
		Tex.silk(ci, "UN WAV", P.call(-.083), V.call(-.07), 15, Color(.9, .88, .82, .45), "left"))
	var m := Mk.mat(Color.WHITE, .45, .6, {"map": tex, "normal": Mk.scratch_normal(), "normal_scale": .15})
	Mk.mi(Mk.quad(W - .012, H - .012), m, Vector3.ZERO, face)


## Cadran à aiguille : écart en cents, zone verte au centre.
func _build_meter() -> void:
	var tex := Tex.canvas(640, 260, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xece0bc))
		for i in 30:
			ci.draw_arc(Vector2(w / 2.0, 140), 360.0 - i * 12.0, 0, TAU, 64, Color(.47, .31, .12, .03 * (1.0 - i / 30.0)), 13.0)
		var c := Vector2(w / 2.0, 330)
		var dark := Mk.c(0x1a1a1a)
		ci.draw_arc(c, 250, -PI / 2 - SWING, -PI / 2 + SWING, 64, dark, 3.0, true)
		ci.draw_arc(c, 256, -PI / 2 - .08, -PI / 2 + .08, 16, Mk.c(0x2a8a3a), 10.0, true)
		ci.draw_arc(c, 256, -PI / 2 - SWING, -PI / 2 - .5, 16, Mk.c(0xb3241a), 6.0, true)
		ci.draw_arc(c, 256, -PI / 2 + .5, -PI / 2 + SWING, 16, Mk.c(0xb3241a), 6.0, true)
		for k in 11:
			var cents := -50 + k * 10
			var a := -PI / 2 + cents / 50.0 * SWING
			var dir := Vector2(cos(a), sin(a))
			ci.draw_line(c + dir * 250, c + dir * (272 if k % 5 == 0 else 262), dark, 3.0 if k % 5 == 0 else 2.0, true)
			if k % 5 == 0:
				Tex.silk(ci, ("%+d" % cents) if cents != 0 else "0", c.x + dir.x * 292, c.y + dir.y * 292, 24, dark, "center")
		Tex.silk(ci, "CENTS", w / 2.0, 196, 26, dark, "center")
		Tex.silk(ci, "REEL'S TOOLS  ·  RT-808 KICK TUNER", w / 2.0, 236, 18, Color(.1, .1, .1, .7), "center")
		Tex.silk(ci, "♭", 60, 200, 40, dark, "center", 400)
		Tex.silk(ci, "♯", w - 60.0, 200, 40, dark, "center", 400))
	var win := Node3D.new()
	win.position = Vector3(0, .028, .002)
	face.add_child(win)
	Mk.mi(Mk.rounded_box(Vector3(.228, .094, .006), .004, Mk.mat(Mk.c(0x0a0a0a), .4, 0.0, {"clearcoat": .6}), 2), null, Vector3(0, 0, -.002), win)
	Mk.mi(Mk.quad(.216, .084), Mk.mat(Color.WHITE, .8, 0.0, {"map": tex, "emission": Mk.c(0xffc070), "energy": .45, "emission_tex": tex}), Vector3(0, 0, .0015), win)
	# aiguille (pivot sous le cadran, comme sur un VU-mètre)
	needle = Node3D.new()
	needle.position = Vector3(0, -.088, .003)
	win.add_child(needle)
	var nm := Mk.mat(Mk.c(0x111111), .5)
	Mk.mi(Mk.box(Vector3(.0011, .11, .0006)), nm, Vector3(0, .012 + .055, 0), needle)
	Mk.mi(Mk.box(Vector3(.0022, .01, .0008)), Mk.mat(Mk.c(0xb3241a), .5), Vector3(0, .116, 0), needle)
	# vitre
	Mk.mi(Mk.quad(.216, .084), Mk.mat(Color.WHITE, .04, 0.0, {"alpha": .1, "clearcoat": 1.0}), Vector3(0, 0, .006), win)


## Rangée de 12 lampes : la note trouvée s'allume.
func _build_lamps() -> void:
	var step := .0185
	for i in 12:
		var nm: String = PitchDetect.NAMES[i]
		var t := Tex.canvas(64, 64, func(ci, w, h):
			ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x2a1a0c))
			Tex.silk(ci, nm, w / 2.0, h / 2.0, 30 if nm.length() == 1 else 24, Mk.c(0xffe0b0), "center"))
		var m := Mk.mat(Mk.c(0x3a2a1a), .4, 0.0, {"map": t, "emission": Mk.c(0xffa040), "energy": .03, "emission_tex": t})
		lamps.append(m)
		Mk.mi(Mk.rounded_box(Vector3(.016, .016, .005), .002, [m, m, m, m, m, m], 1), null, Vector3(-11 * step / 2 + i * step, -.03, .003), face)


func _build_leds() -> void:
	led_hz = Tex.live(512, 120, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x070101))
		var txt: String = "----" if result.is_empty() or not result.ok else ("%.1f" % result.hz)
		var dot := txt.find(".")
		var s := txt.replace(".", "").lpad(4).right(4)
		var dot_at := -1 if dot < 0 else 4 - (txt.length() - dot - 1)
		Tex.seg7(ci, s, 40, 14, 86, 92, 26, Mk.c(0xff3d22), Color(1, .2, .08, .06), dot_at))
	_led_window(led_hz.texture, Vector2(.062, -.065), Vector2(.075, .02))
	led_oct = Tex.live(128, 160, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x070101))
		var s := "-" if result.is_empty() or not result.ok else str(result.octave)
		Tex.seg7(ci, s.right(1), 22, 14, 84, 132, 0, Mk.c(0xff3d22), Color(1, .2, .08, .06)))
	_led_window(led_oct.texture, Vector2(-.025, -.068), Vector2(.014, .02))


func _led_window(tex: Texture2D, at: Vector2, size: Vector2) -> void:
	var g := Mk.face_window(Mk.glow(Color.WHITE, 1.7, tex), size.x, size.y, Mk.c(0x3a0705))
	g.position = Vector3(at.x, at.y, .003)
	face.add_child(g)


func _build_button() -> void:
	var bt := Node3D.new()
	bt.name = "LoadButton"
	bt.position = Vector3(-.1, -.064, .003)
	face.add_child(bt)
	var ring := Mk.mi(Mk.torus_ring(.011, .002), Mk.chrome_mat(), Vector3.ZERO, bt)
	ring.rotation.x = PI / 2
	var cap := Mk.mi(Mk.cyl(.009, .009, .008, 24), Mk.mat(Mk.c(0xd8d2c4), .35, 0.0, {"clearcoat": .6}), Vector3(0, 0, .004), bt)
	cap.rotation.x = PI / 2
	Mk.add_pick_later(bt, "tuner:load", .006)


# ---------------------------------------------------------------- logique
func load_sample(path: String) -> void:
	file_name = path.get_file()
	result = PitchDetect.analyze_file(path)
	for i in 12:
		lamps[i].emission_energy_multiplier = 1.3 if result.ok and PitchDetect.NAMES[i] == result.note else .03
	led_hz.redraw()
	led_oct.redraw()
	needle_vel += .02  # petit coup pour la mise en mouvement


func on_files(paths: PackedStringArray) -> void:
	for p in paths:
		if p.get_extension().to_lower() == "wav":
			load_sample(p)
			return
	result = {"ok": false, "err": "PAS UN WAV"}
	load_sample_failed()


func load_sample_failed() -> void:
	for m in lamps:
		m.emission_energy_multiplier = .03
	led_hz.redraw()
	led_oct.redraw()


func on_action(a: String) -> void:
	if a == "load":
		dialog.popup_centered()


func on_drag_start(_a: String) -> bool:
	return false


func on_drag(_rel: Vector2, _fine: bool) -> void:
	pass


func on_wheel(_a: String, _dir: float, _fine: bool) -> void:
	pass


func on_key(e: InputEventKey) -> bool:
	if e.keycode == KEY_L or e.keycode == KEY_O:
		on_action("load")
		return true
	return false


## Aiguille amortie comme un vrai galvanomètre (léger dépassement).
func animate(_t: float, dt: float, _reduced: bool) -> void:
	var target := REST
	if not result.is_empty() and result.ok:
		target = clampf(result.cents / 50.0, -1.15, 1.15) * SWING
	var steps := maxi(1, int(dt / .004))
	var h := dt / steps
	for i in steps:
		var acc := (target - needle_angle) * 220.0 - needle_vel * 18.0
		needle_vel += acc * h
		needle_angle += needle_vel * h
	needle.rotation.z = -needle_angle
