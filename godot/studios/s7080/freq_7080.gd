class_name Freq7080
extends Node3D
## Module Fréquences du studio 70/80 : petit synthé polyphonique années 80 (façades noires à bandes
## de couleur, joues en bois) posé sur un support fixé au mur, avec du scotch sur les touches
## (notes en notation anglaise).
## - NOTE → HZ : on clique une touche (OCT −/+ pour l'octave) : note, fréquence, et la note est jouée.
## - HZ → NOTE : on tourne le potard FREQ (glisser / molette) ou on tape des chiffres + Entrée :
##   note la plus proche + écart en cents.
## - Diapason réglable (curseur LA4, 430–450 Hz). PLAY / Espace rejoue la note.
##
## Repère local : touches vers +Z, longueur sur X. Actions : "freq:key:<n>", "freq:oct_down",
## "freq:oct_up", "freq:mode_note", "freq:mode_hz", "freq:play", "freq:a4" (glisser), "freq:knob" (glisser).

const L := .74
const D := .28
const H := .07
const KEYS := 37          # do à do, 3 octaves
const KB_W := .64

var a4 := 440.0
var octave := 3           # octave de la première touche (C3)
var mode := "note"        # note | hz
var midi := 57            # A3
var freq := 220.0
var typed := ""
var key_meshes: Array[MeshInstance3D] = []
var key_lit: Array[bool] = []
var led_note: TexLib.LiveCanvas
var led_hz: TexLib.LiveCanvas
var led_cents: TexLib.LiveCanvas
var led_a4: TexLib.LiveCanvas
var mode_leds: Array[StandardMaterial3D] = []
var a4_cap: Node3D
var knob_spin: Node3D
var top: Node3D
var _white: StandardMaterial3D
var _black_key: StandardMaterial3D
var _lit_white: StandardMaterial3D
var _lit_black: StandardMaterial3D
var _gen: AudioStreamGeneratorPlayback
var _player: AudioStreamPlayer
var _phase := 0.0
var _env := 0.0


func _init(walnut: Material) -> void:
	name = "Freq7080"
	ready.connect(func():
		Mk.add_pick(self, "m:freq", 1)
		_player.play()
		_gen = _player.get_stream_playback(), CONNECT_ONE_SHOT)
	var body := Mk.mat(Mk.c(0x161616), .45, .3)
	Mk.mi(Mk.rounded_box(Vector3(L, H, D), .006, body, 3), null, Vector3(0, H / 2, 0), self)
	for sx in [-1, 1]:
		Mk.mi(Mk.rounded_box(Vector3(.028, H + .016, D + .006), .005, walnut, 3), null, Vector3(sx * (L / 2 + .014), (H + .016) / 2, 0), self)
	top = Node3D.new()
	top.position = Vector3(0, H + .001, -D / 2 + .085)
	add_child(top)
	_build_panel()
	_build_keys()
	_build_controls()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 44100.0
	gen.buffer_length = .12
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	_player.volume_db = -8.0
	add_child(_player)
	_select_key(midi - octave * 12 - 12, false)


# ---------------------------------------------------------------- façade
const ZP := .17   # profondeur du panneau (de l'arrière vers les touches)


func _build_panel() -> void:
	var tex := Tex.canvas(2048, int(2048 * ZP / L), func(ci, w, h):
		var P := func(m: float) -> float: return (m + L / 2) / L * w
		var V := func(m: float) -> float: return (m + ZP / 2) / ZP * h
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x161616))
		Tex.brushed(ci, w, h, 606, .03, 3000)
		# bandes de couleur des sections (façon synthé 80s)
		var cols := [Mk.c(0xe8742a), Mk.c(0xf2c230), Mk.c(0xd43a26), Mk.c(0x3a8ad0)]
		var secs := [[-.35, -.17, "NOTE → HZ"], [-.16, .06, "AFFICHAGE"], [.07, .2, "HZ → NOTE"], [.21, .35, "DIAPASON"]]
		for i in secs.size():
			var s: Array = secs[i]
			ci.draw_rect(Rect2(P.call(s[0]), V.call(-ZP / 2 + .012), P.call(s[1]) - P.call(s[0]), 10), cols[i])
			Tex.silk(ci, s[2], P.call(s[0]), V.call(-ZP / 2 + .028), 26, Color(.92, .9, .85, .85))
		var ink := Color(.92, .9, .85, .75)
		Tex.silk(ci, "OCT −", P.call(-.31), V.call(.035), 22, ink, "center")
		Tex.silk(ci, "OCT +", P.call(-.265), V.call(.035), 22, ink, "center")
		Tex.silk(ci, "PLAY", P.call(-.205), V.call(.035), 22, ink, "center")
		Tex.silk(ci, "NOTE", P.call(-.12), V.call(.036), 20, ink, "center")
		Tex.silk(ci, "HZ", P.call(-.02), V.call(.036), 20, ink, "center")
		Tex.silk(ci, "CENTS", P.call(.093), V.call(.036), 20, ink, "center")
		Tex.silk(ci, "MODE", P.call(.15), V.call(-.04), 20, ink, "center")
		Tex.silk(ci, "NOTE", P.call(.135), V.call(.035), 18, ink, "center")
		Tex.silk(ci, "HZ", P.call(.165), V.call(.035), 18, ink, "center")
		Tex.silk(ci, "FREQ", P.call(.19), V.call(.045), 20, ink, "center")
		Tex.silk(ci, "A4", P.call(.245), V.call(.045), 20, ink, "center")
		Tex.silk(ci, "450", P.call(.262), V.call(-.032), 16, ink, "left")
		Tex.silk(ci, "430", P.call(.262), V.call(.03), 16, ink, "left")
		ci.draw_rect(Rect2(P.call(.243), V.call(-.035), 8, V.call(.03) - V.call(-.035)), Color(0, 0, 0, .9))
		# curseurs décoratifs (esprit synthé)
		for i in 4:
			var x: float = P.call(.29 + i * .016)
			ci.draw_rect(Rect2(x, V.call(-.035), 6, V.call(.03) - V.call(-.035)), Color(0, 0, 0, .9))
		Tex.silk(ci, "REEL'S TOOLS  RT-F37  FREQUENCY SYNTHESIZER", P.call(.35), V.call(ZP / 2 - .01), 22, Color(.92, .9, .85, .6), "right")
		Tex.grime(ci, w, h, 607, 1.5))
	var m := Mk.mat(Color.WHITE, .5, .3, {"map": tex})
	Mk.mi(Mk.rounded_box(Vector3(L - .004, .003, ZP), .001, [m, m, m, m, m, m], 1), null, Vector3.ZERO, top)


func _led(w: int, h: int, fn: Callable, at: Vector2, size: Vector2) -> TexLib.LiveCanvas:
	var lc := Tex.live(w, h, fn)
	var win := Mk.screen_window(Mk.glow(Color.WHITE, 1.7, lc.texture), size.x, size.y, Mk.c(0x3a0705))
	win.position = Vector3(at.x, .002, at.y)
	top.add_child(win)
	return lc


func _build_controls() -> void:
	var on := Mk.c(0xff3d22)
	var off := Color(1, .2, .08, .06)
	led_note = _led(384, 160, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x070101))
		var nm: String = NoteFreq.NAMES[posmod(midi, 12)]
		var oct := str(floori(midi / 12.0) - 1)
		var s := nm.substr(0, 1) + ("#" if nm.length() > 1 else " ") + oct.right(1)
		Tex.seg7(ci, s, 26, 14, 92, 132, 28, on, off), Vector2(-.12, .0), Vector2(.07, .03))
	led_hz = _led(640, 160, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x070101))
		var txt := typed if typed != "" else ("%.2f" % freq if freq < 1000.0 else "%.1f" % freq)
		var dot := txt.find(".")
		var s := txt.replace(".", "").lpad(6).right(6)
		var dot_at := -1 if dot < 0 else 6 - (txt.length() - dot - 1)
		Tex.seg7(ci, s, 22, 14, 80, 132, 22, on, off, dot_at), Vector2(-.02, .0), Vector2(.11, .03))
	led_cents = _led(320, 160, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x070101))
		var c := 0
		if mode == "hz":
			c = int(round(NoteFreq.describe(freq, a4).cents))
		var s := ("%+d" % c if c != 0 else "0").replace("+", " ")
		if c < 0:
			s = "-" + str(absi(c))
		Tex.seg7(ci, s.lpad(3).right(3), 22, 14, 80, 132, 18, on, off), Vector2(.093, .0), Vector2(.055, .03))
	led_a4 = _led(320, 160, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x070101))
		Tex.seg7(ci, str(int(round(a4))).lpad(3).right(3), 22, 14, 80, 132, 18, on, off), Vector2(.3, -.06), Vector2(.05, .022))
	# boutons
	var btn_mesh := Mk.rounded_box(Vector3(.024, .01, .016), .003, null, 2)
	var btns := [[-.31, "freq:oct_down", 0x2a2a2a], [-.265, "freq:oct_up", 0x2a2a2a], [-.205, "freq:play", 0xe8742a],
		[.135, "freq:mode_note", 0xf2c230], [.165, "freq:mode_hz", 0xf2c230]]
	for b in btns:
		var bt := Mk.mi(btn_mesh, Mk.mat(Mk.c(b[2]), .4, 0.0, {"clearcoat": .4}), Vector3(b[0], .006, .016), top)
		Mk.add_pick_later(bt, b[1], .003)
	for x in [.135, .165]:
		var m := Mk.glow(Mk.c(0xff2a10), .1) as StandardMaterial3D
		mode_leds.append(m)
		Mk.mi(Mk.cyl(.0022, .0022, .002, 12), m, Vector3(x, .002, -.004), top)
	# potard FREQ
	var kn := Node3D.new()
	kn.position = Vector3(.19, .002, .002)
	top.add_child(kn)
	var k := Mk.knob(.012, .016)
	kn.add_child(k)
	knob_spin = k
	Mk.add_pick_later(kn, "freq:knob", .006)
	# curseur LA4 (diapason)
	var sl := Node3D.new()
	sl.position = Vector3(.245, .002, 0)
	top.add_child(sl)
	a4_cap = Mk.mi(Mk.rounded_box(Vector3(.014, .012, .01), .002, Mk.mat(Mk.c(0xe8e4da), .4)), null, Vector3.ZERO, sl)
	Mk.add_pick_later(sl, "freq:a4", .012)
	# curseurs décoratifs
	for i in 4:
		Mk.mi(Mk.rounded_box(Vector3(.01, .01, .008), .002, Mk.mat(Mk.c(0xe8e4da), .4)), null, Vector3(.29 + i * .016 + .0007, .006, -.01 + i * .008), top)


# ---------------------------------------------------------------- clavier avec scotch
func _build_keys() -> void:
	_white = Mk.mat(Mk.c(0xe8e2d4), .35, 0.0, {"clearcoat": .4})
	_black_key = Mk.mat(Mk.c(0x0e0e0e), .3, 0.0, {"clearcoat": .5})
	_lit_white = Mk.mat(Mk.c(0xffd9a8), .35, 0.0, {"emission": Mk.c(0xff8a2a), "energy": .6})
	_lit_black = Mk.mat(Mk.c(0x5a2a10), .35, 0.0, {"emission": Mk.c(0xff8a2a), "energy": .8})
	var n_white := 22
	var ww := KB_W / n_white
	var z0 := D / 2 - .055
	var wmesh := Mk.rounded_box(Vector3(ww - .0012, .012, .1), .0015, null, 2)
	var bmesh := Mk.rounded_box(Vector3(ww * .58, .012, .062), .0015, null, 2)
	var tape := Mk.mat(Mk.c(0xe8dcb8), .8)
	var white_steps := [0, 2, 4, 5, 7, 9, 11]
	var wi := 0
	for k in KEYS:
		var pc := k % 12
		var is_white := white_steps.has(pc)
		var mi: MeshInstance3D
		if is_white:
			var x := -KB_W / 2 + ww / 2 + wi * ww
			mi = Mk.mi(wmesh, _white, Vector3(x, H + .002, z0), self)
			wi += 1
		else:
			var x := -KB_W / 2 + wi * ww
			mi = Mk.mi(bmesh, _black_key, Vector3(x, H + .012, z0 - .019), self)
		key_meshes.append(mi)
		key_lit.append(false)
		# scotch avec le nom de la note
		var nm: String = NoteFreq.NAMES[pc]
		var lab := Mk.mi(Mk.plane(ww * (.8 if is_white else .5), .016), _tape_label(nm), Vector3(0, .0062, -.03 if is_white else -.015), mi)
		lab.rotation.y = randf_range(-.06, .06)
		Mk.add_pick_later(mi, "freq:key:%d" % k, .0)


var _tapes := {}


func _tape_label(nm: String) -> StandardMaterial3D:
	if _tapes.has(nm):
		return _tapes[nm]
	var t := Tex.canvas(96, 64, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xe8dcb8))
		Tex.grime(ci, w, h, nm.length() + 3, .3)
		Tex.silk(ci, nm, w / 2.0, h / 2.0, 44 if nm.length() == 1 else 34, Mk.c(0x14143a), "center", 600, "caveat"))
	var m := Mk.mat(Color.WHITE, .85, 0.0, {"map": t})
	_tapes[nm] = m
	return m


# ---------------------------------------------------------------- logique
func _select_key(k: int, play := true) -> void:
	k = clampi(k, 0, KEYS - 1)
	midi = (octave + 1) * 12 + k
	freq = NoteFreq.hz(midi, a4)
	mode = "note"
	typed = ""
	_light_key(k)
	_refresh()
	if play:
		_env = 1.0


func _light_key(k: int) -> void:
	for i in key_meshes.size():
		var white := [0, 2, 4, 5, 7, 9, 11].has(i % 12)
		key_meshes[i].material_override = (_lit_white if white else _lit_black) if i == k else (_white if white else _black_key)


func _set_freq(f: float, play := false) -> void:
	freq = clampf(f, 16.0, 12000.0)
	mode = "hz"
	var d := NoteFreq.describe(freq, a4)
	midi = d.midi
	var k: int = midi - (octave + 1) * 12
	_light_key(k if k >= 0 and k < KEYS else -1)
	_refresh()
	if play:
		_env = 1.0


func _refresh() -> void:
	for lc in [led_note, led_hz, led_cents, led_a4]:
		if lc:
			lc.redraw()
	if mode_leds.size() == 2:
		mode_leds[0].emission_energy_multiplier = 2.0 if mode == "note" else .08
		mode_leds[1].emission_energy_multiplier = 2.0 if mode == "hz" else .08


func on_action(a: String) -> void:
	if a.begins_with("key:"):
		_select_key(int(a.substr(4)))
		return
	match a:
		"oct_down", "oct_up":
			# même touche, une octave plus bas / plus haut
			var rel := clampi(midi - (octave + 1) * 12, 0, KEYS - 1)
			octave = clampi(octave + (-1 if a == "oct_down" else 1), 0, 6)
			_select_key(rel)
		"play":
			_env = 1.0
		"mode_note":
			_select_key(midi - (octave + 1) * 12, false)
		"mode_hz":
			_set_freq(freq)


func on_drag_start(a: String) -> bool:
	return a == "knob" or a == "a4"


var _drag_target := ""


func on_drag(rel: Vector2, fine: bool) -> void:
	# le dernier contrôle saisi est retrouvé par la position de la souris au moment du clic (cf. main) :
	# ici on applique au potard FREQ par défaut, au diapason si la souris était dessus
	if _drag_target == "a4":
		_set_a4(a4 + (-rel.y) * (.02 if fine else .1))
	else:
		_set_freq(freq * pow(2.0, (-rel.y + rel.x) * (.0015 if fine else .006)))


func on_press(a: String) -> void:
	_drag_target = a


func on_wheel(a: String, dir: float, fine: bool) -> void:
	if a == "a4":
		_set_a4(a4 + dir * (.1 if fine else 1.0))
	elif a == "knob":
		_set_freq(freq * pow(2.0, dir * (1.0 / 1200.0 if fine else 1.0 / 12.0)), true)


func _set_a4(v: float) -> void:
	a4 = clampf(v, 430.0, 450.0)
	if mode == "note":
		freq = NoteFreq.hz(midi, a4)
	_refresh()


func on_key(e: InputEventKey) -> bool:
	var u := e.unicode
	if (u >= 48 and u <= 57) or u == 46 or u == 44:
		typed += "." if u == 44 else char(u)
		typed = typed.left(7)
		mode = "hz"
		_refresh()
		return true
	match e.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			if typed != "":
				var f := typed.to_float()
				typed = ""
				if f > 0.0:
					_set_freq(f, true)
				else:
					_refresh()
		KEY_BACKSPACE:
			typed = typed.left(-1)
			_refresh()
		KEY_SPACE:
			_env = 1.0
		KEY_Z:
			on_action("oct_down")
		KEY_X:
			on_action("oct_up")
		_:
			return false
	return true


func animate(_t: float, dt: float, _reduced: bool) -> void:
	if a4_cap:
		a4_cap.position.z = lerpf(.03, -.035, (a4 - 430.0) / 20.0)
	if knob_spin:
		knob_spin.rotation.y = -log(freq / 20.0) / log(12000.0 / 20.0) * deg_to_rad(300.0) + deg_to_rad(150.0)
	# synthèse : sinus douce avec enveloppe (1,5 s)
	if _gen == null:
		return
	var n := _gen.get_frames_available()
	var inc := TAU * freq / 44100.0
	for i in n:
		_env = maxf(0.0, _env - 1.0 / (44100.0 * 1.5))
		var v := sin(_phase) * pow(_env, 2.0) * .5
		_phase = fmod(_phase + inc, TAU)
		_gen.push_frame(Vector2(v, v))
