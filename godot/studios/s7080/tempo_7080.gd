class_name Tempo7080
extends Node3D
## Module Tempo du studio 70/80 : section « sidecar » accolée à la console de mix (même caisse, même
## pupitre incliné). Afficheur BPM LED rouge 7 segments, afficheur des ms (clic = copie), liste des
## valeurs de note avec LED + sélecteur, gros potard tempo, boutons ÷2 / ×2, pad TAP, lampe de battement.
##
## Repère local : comme la console (avant de la machine = +Z local, posée tournée vers l'ingé).
## Actions cliquables : "tempo:knob" (glisser / molette), "tempo:note", "tempo:half", "tempo:double",
## "tempo:tap", "tempo:copy". Corps entier : "m:tempo".

const W := .2       # largeur de la section
const D := .74      # profondeur (comme la console)
const H_BACK := .12
const H_FRONT := .045

var engine: TempoEngine
var deck: Node3D
var plen: float
var led_bpm: TexLib.LiveCanvas
var led_ms: TexLib.LiveCanvas
var knob_spin: Node3D
var sel_spin: Node3D
var tap_pad: MeshInstance3D
var tap_led: StandardMaterial3D
var beat_mat: StandardMaterial3D
var note_leds: Array[StandardMaterial3D] = []
var flash := 0.0
var tap_press := 0.0
var _flash_on := false
var _msg := ""
var _msg_until := 0.0

var _alu: StandardMaterial3D
var _black: StandardMaterial3D


func _init(e: TempoEngine, walnut: Material) -> void:
	engine = e
	name = "Tempo7080"
	ready.connect(func(): Mk.add_pick(self, "m:tempo", 1), CONNECT_ONE_SHOT)
	_black = Mk.mat(Mk.c(0x121212), .45, .1)
	var body := Mk.mat(Mk.c(0x2a2622), .5, .3)
	# caisse en biseau + joue extérieure en noyer
	var prof := PackedVector2Array([Vector2(-D / 2, 0), Vector2(D / 2, 0), Vector2(D / 2, H_FRONT), Vector2(-D / 2, H_BACK)])
	var box := Mk.mi(Mk.prism(prof, W), body, Vector3(W / 2, 0, 0), self)
	box.rotation.y = -PI / 2
	var cheek := Mk.mi(Mk.prism(PackedVector2Array([Vector2(-D / 2 - .01, 0), Vector2(D / 2 + .01, 0), Vector2(D / 2 + .01, .06), Vector2(-D / 2 - .01, .2), Vector2(-D / 2 + .05, .2)]), .025), walnut, Vector3(-W / 2, 0, 0), self)
	cheek.rotation.y = -PI / 2
	# pupitre incliné
	var slope := atan2(H_BACK - H_FRONT, D)
	plen = sqrt(D * D + pow(H_BACK - H_FRONT, 2))
	deck = Node3D.new()
	deck.name = "Deck"
	deck.position = Vector3(0, (H_BACK + H_FRONT) / 2 + .001, 0)
	deck.rotation.x = slope
	add_child(deck)
	_build_panel(body)
	_build_displays()
	_build_controls()
	engine.changed.connect(_refresh)
	_refresh()


# ---------------------------------------------------------------- repères sur le pupitre (mètres, origine au centre)
const Z_BPM := -.285
const Z_MS := -.2
const Z_NOTES := -.135        # première ligne de la liste des notes
const NOTE_STEP := .0165
const X_LIST := -.085         # LED de la liste
const SEL := Vector2(.058, -.035)
const KNOB := Vector2(.04, .165)
const BTN_HALF := Vector2(-.068, .13)
const BTN_DOUBLE := Vector2(-.068, .195)
const TAP := Vector2(0, .3)


func _build_panel(body: Material) -> void:
	var notes := TempoEngine.NOTES
	var tex := Tex.canvas(1024, int(1024 * plen / W), func(ci, w, h):
		var P := func(m: float) -> float: return (m + W / 2) / W * w
		var V := func(m: float) -> float: return (m + plen / 2) / plen * h
		var ink := Color(.08, .08, .08, .9)
		var red := Color(.65, .12, .08, .9)
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xa8a49c))
		Tex.brushed(ci, w, h, 141, .07, 5000)
		Tex.grime(ci, w, h, 142, 1.5)
		ci.draw_rect(Rect2(0, 0, 3, h), Color(0, 0, 0, .7))
		Tex.silk(ci, "REEL'S", P.call(-W / 2 + .012), V.call(-plen / 2 + .016), 30, ink, "left", 800)
		Tex.silk(ci, "RT-140", P.call(W / 2 - .012), V.call(-plen / 2 + .016), 30, ink, "right", 600)
		ci.draw_rect(Rect2(P.call(-W / 2 + .012), V.call(-plen / 2 + .03), P.call(.05) - P.call(0), 4), red)
		Tex.silk(ci, "BPM", P.call(-W / 2 + .012), V.call(Z_BPM - .036), 37, ink)
		Tex.silk(ci, "MS  ·  CLICK = COPY", P.call(-W / 2 + .012), V.call(Z_MS - .024), 30, ink)
		Tex.silk(ci, "BEAT", P.call(.072), V.call(Z_MS + .022), 27, ink, "center")
		# liste des valeurs de note
		for i in notes.size():
			Tex.silk(ci, notes[i][0], P.call(X_LIST + .012), V.call(Z_NOTES + i * NOTE_STEP), 28, ink, "left", 600)
		Tex.silk(ci, "NOTE", P.call(SEL.x), V.call(SEL.y - .043), 34, ink, "center")
		# graduations du potard tempo
		var c := Vector2(P.call(KNOB.x), V.call(KNOB.y))
		var r1: float = P.call(.036) - P.call(0)
		for i in 28:
			var a := deg_to_rad(-150.0 + i * (300.0 / 27.0)) - PI / 2
			var r2 := r1 + (14.0 if i % 9 == 0 else 7.0)
			ci.draw_line(c + Vector2(cos(a), sin(a)) * r1, c + Vector2(cos(a), sin(a)) * r2, ink, 3.0, true)
		Tex.silk(ci, "30", c.x - r1 - 4, c.y + r1 * .75, 27, ink, "right")
		Tex.silk(ci, "300", c.x + r1 + 4, c.y + r1 * .75, 27, ink, "left")
		Tex.silk(ci, "TEMPO", c.x, V.call(KNOB.y - .055), 37, ink, "center")
		Tex.silk(ci, "÷2", P.call(BTN_HALF.x + .03), V.call(BTN_HALF.y), 34, ink, "left")
		Tex.silk(ci, "×2", P.call(BTN_DOUBLE.x + .03), V.call(BTN_DOUBLE.y), 34, ink, "left")
		Tex.silk(ci, "TAP  ·  SPACE", P.call(0), V.call(TAP.y - .045), 34, ink, "center"))
	var face := Mk.mat(Color.WHITE, .5, .75, {"map": tex, "normal": Mk.scratch_normal(), "normal_scale": .2})
	Mk.mi(Mk.rounded_box(Vector3(W - .006, .004, plen), .001, [body, body, face, body, body, body], 1), null, Vector3.ZERO, deck)


func _build_displays() -> void:
	led_bpm = Tex.live(512, 176, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x070101))
		var s := ("%.1f" % engine.bpm).replace(".", "").lpad(4).right(4)
		Tex.seg7(ci, s, 30, 16, 96, 144, 22, Mk.c(0xffd0c0) if _flash_on else Mk.c(0xff3d22), Color(1, .2, .08, .06), 3))
	_window(led_bpm.texture, Vector2(0, Z_BPM), Vector2(.17, .058), 1.8)
	led_ms = Tex.live(512, 112, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x070101))
		var txt := _msg if _msg != "" else ("%.1f" % engine.note_ms())
		var s := txt.replace(".", "")
		var dot := txt.find(".")
		s = s.lpad(5).right(5)
		var dot_at := -1 if dot < 0 else 5 - (txt.length() - dot - 1)
		Tex.seg7(ci, s, 24, 14, 70, 84, 22, Mk.c(0xff3d22), Color(1, .2, .08, .06), dot_at))
	var ms_win := _window(led_ms.texture, Vector2(-.025, Z_MS), Vector2(.11, .026), 1.6)
	Mk.add_pick_later(ms_win, "tempo:copy")
	# lampe de battement
	beat_mat = Mk.mat(Mk.c(0x400404), .1, 0.0, {"emission": Mk.c(0xff2a10), "energy": .2, "clearcoat": 1.0})
	var jw := Mk.mi(Mk.sphere(.007, 20, 10, true), beat_mat, Vector3(.072, .002, Z_MS), deck)
	jw.scale = Vector3(1, .8, 1)
	Mk.mi(Mk.torus_ring(.009, .0015), Mk.chrome_mat(), Vector3(.072, .002, Z_MS), deck)
	# LED de la liste des notes
	var led_mesh := Mk.cyl(.0022, .0022, .002, 12)
	for i in TempoEngine.NOTES.size():
		var m := Mk.glow(Mk.c(0xff2a10), .05) as StandardMaterial3D
		note_leds.append(m)
		Mk.mi(led_mesh, m, Vector3(X_LIST, .003, Z_NOTES + i * NOTE_STEP), deck)


func _window(tex: Texture2D, at: Vector2, size: Vector2, energy: float) -> Node3D:
	var g := Mk.screen_window(Mk.glow(Color.WHITE, energy, tex), size.x, size.y, Mk.c(0x3a0705))
	g.position = Vector3(at.x, .002, at.y)
	deck.add_child(g)
	return g


func _build_controls() -> void:
	# sélecteur de note
	var sel := Node3D.new()
	sel.name = "NoteSelector"
	sel.position = Vector3(SEL.x, .002, SEL.y)
	deck.add_child(sel)
	sel_spin = Mk.knob(.013, .02)
	sel.add_child(sel_spin)
	Mk.add_pick_later(sel, "tempo:note", .006)
	# gros potard tempo alu
	var kn := Node3D.new()
	kn.name = "TempoKnob"
	kn.position = Vector3(KNOB.x, .002, KNOB.y)
	deck.add_child(kn)
	var alu := Mk.alu_knob(.027, .028)
	kn.add_child(alu)
	knob_spin = alu.get_meta("spin")
	Mk.add_pick_later(kn, "tempo:knob", .008)
	# ÷2 / ×2
	for b in [[BTN_HALF, "tempo:half"], [BTN_DOUBLE, "tempo:double"]]:
		var bt := Node3D.new()
		bt.position = Vector3(b[0].x, .002, b[0].y)
		deck.add_child(bt)
		Mk.mi(Mk.torus_ring(.011, .002), Mk.chrome_mat(), Vector3.ZERO, bt)
		Mk.mi(Mk.cyl(.009, .009, .008, 24), Mk.mat(Mk.c(0xd8d2c4), .35, 0.0, {"clearcoat": .6}), Vector3(0, .004, 0), bt)
		Mk.add_pick_later(bt, b[1], .006)
	# pad TAP en caoutchouc + LED
	var pad_mat := Mk.mat(Mk.c(0x2b2b2d), .9, 0.0, {"rim": .3})
	tap_pad = Mk.mi(Mk.rounded_box(Vector3(.15, .014, .07), .006, pad_mat, 3), null, Vector3(TAP.x, .009, TAP.y), deck)
	tap_pad.name = "TapPad"
	Mk.add_pick_later(tap_pad, "tempo:tap", .004)
	tap_led = Mk.glow(Mk.c(0xff2a10), .2) as StandardMaterial3D
	Mk.mi(Mk.cyl(.0035, .0035, .003, 16), tap_led, Vector3(.085, .003, TAP.y), deck)


# ---------------------------------------------------------------- logique
func _refresh() -> void:
	led_bpm.redraw()
	led_ms.redraw()
	for i in note_leds.size():
		note_leds[i].emission_energy_multiplier = 2.2 if i == engine.note_ix else .05


func message(txt: String, secs := 1.0) -> void:
	_msg = txt
	_msg_until = Time.get_ticks_msec() / 1000.0 + secs
	led_ms.redraw()


func on_action(a: String) -> void:
	match a:
		"tap":
			tap_press = 1.0
			flash = 1.0
			engine.tap()
		"note":
			engine.set_note(engine.note_ix + 1)
		"half":
			engine.set_bpm(engine.bpm / 2.0)
		"double":
			engine.set_bpm(engine.bpm * 2.0)
		"copy":
			var ms := ("%.1f" % engine.note_ms()).replace(".", ",")
			DisplayServer.clipboard_set(ms)
			Toast.say("Copié : %s ms" % ms)
			message("COPY")


## Glisser sur le gros potard : vers le haut / la droite = plus vite.
func on_drag_start(a: String) -> bool:
	return a == "knob"


func on_drag(rel: Vector2, fine: bool) -> void:
	engine.set_bpm(engine.bpm + (-rel.y + rel.x) * (.02 if fine else .2))


func on_wheel(a: String, dir: float, fine: bool) -> void:
	if a == "knob":
		engine.set_bpm(engine.bpm + dir * (.1 if fine else 1.0))
	elif a == "note":
		engine.set_note(engine.note_ix + int(dir))


func on_key(e: InputEventKey) -> bool:
	var fine := .1 if e.shift_pressed else 1.0
	match e.keycode:
		KEY_SPACE:
			on_action("tap")
		KEY_UP:
			engine.set_bpm(engine.bpm + fine)
		KEY_DOWN:
			engine.set_bpm(engine.bpm - fine)
		KEY_N:
			on_action("note")
		KEY_C:
			on_action("copy")
		_:
			return false
	return true


func animate(t: float, dt: float, reduced: bool) -> void:
	var pulse := .4 if reduced else exp(-engine.beat_phase(t) * 8.0)
	beat_mat.emission_energy_multiplier = .15 + pulse * 5.0
	tap_led.emission_energy_multiplier = .15 + flash * 6.0 + pulse * .4
	var k := 1.0 - pow(.75, dt * 60.0)
	knob_spin.rotation.y += ((-(engine.bpm - 30.0) / 270.0 * deg_to_rad(300.0) + deg_to_rad(150.0)) - knob_spin.rotation.y) * k
	var target_sel := -deg_to_rad(-150.0 + engine.note_ix * (300.0 / (TempoEngine.NOTES.size() - 1)))
	sel_spin.rotation.y += (target_sel - sel_spin.rotation.y) * (1.0 - pow(.7, dt * 60.0))
	tap_press *= pow(.8, dt * 60.0)
	flash *= pow(.86, dt * 60.0)
	tap_pad.position.y = .009 - tap_press * .004
	var on := flash > .5
	if on != _flash_on:
		_flash_on = on
		led_bpm.redraw()
	if _msg != "" and Time.get_ticks_msec() / 1000.0 > _msg_until:
		_msg = ""
		led_ms.redraw()
