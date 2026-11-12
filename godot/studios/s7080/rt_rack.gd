class_name RtRack7080
extends Node3D
## Rack incliné sur ses joues en noyer : RT-140 TEMPO COMPUTER (jouable) + RT-220 DUAL VU LOUDNESS.

const U := 0.04445
const RW := 0.483

var engine: TempoEngine
var tempo: Node3D
var loud: Node3D
var slope: Node3D
var enc: Node3D        # gros potard tempo (meta spin)
var sel_spin: Node3D   # sélecteur de note
var tap_btn: MeshInstance3D
var tap_led_mat: StandardMaterial3D
var jewel_mat: StandardMaterial3D
var vu_needles: Array[Node3D] = []
var led: TexLib.LiveCanvas
var vfd: TexLib.LiveCanvas
var vfd_msg: Array = []
var vfd_msg_until := 0.0
var flash := 0.0
var tap_press := 0.0
var _led_flash_state := false


static func ink(a: float) -> Color:
	return Color(0.078, 0.078, 0.078, a)


static func cream(a: float) -> Color:
	return Color(0.863, 0.847, 0.816, a)


func _init(e: TempoEngine) -> void:
	engine = e
	name = "RackTempoLoudness"
	slope = Node3D.new()
	slope.rotation.x = -PI / 2 + 0.62
	slope.position = Vector3(0, .115, -.02)
	add_child(slope)
	_build_tempo()
	_build_loud()
	var yc := 0.0
	for pair in [[tempo, 2], [loud, 2]]:
		yc -= pair[1] * U
		pair[0].position = Vector3(0, yc + pair[1] * U / 2.0, 0)
		slope.add_child(pair[0])
	# joues en noyer
	var shape := PackedVector2Array([Vector2(0, 0), Vector2(.26, 0), Vector2(.26, .07), Vector2(.02, .21), Vector2(0, .21)])
	var side_mesh := Mk.prism(shape, .02)
	for s in [-1, 1]:
		var side := Mk.mi(side_mesh, Mk.walnut_mat(), Vector3(s * (RW / 2 + .012) + (.02 if s > 0 else 0.0), 0, -.13), self)
		side.rotation.y = -PI / 2
		side.name = "Side%d" % s
	engine.changed.connect(func(): draw_led(); draw_vfd())


# ---------------------------------------------------------------- faceplate générique
func faceplate(units: int, base: Color, seed: int, draw: Callable, metal := 0.55, rough := 0.52) -> Node3D:
	var h := units * U - .0008
	var W := 2048
	var H := int(round(W * h / RW))
	var P := func(m: float) -> float: return m / RW * W
	var t := Tex.canvas(W, H, func(ci, ww, hh):
		ci.draw_rect(Rect2(0, 0, ww, hh), base)
		Tex.brushed(ci, ww, hh, seed, .06)
		Tex.grime(ci, ww, hh, seed + 3, 1.2)
		var sys := [hh / 2.0] if units == 1 else [P.call(.016), hh - P.call(.016)]
		for sxm in [.008, RW - .008]:
			for sy in sys:
				var cx: float = P.call(sxm)
				var rw: float = P.call(.005)
				var rh: float = P.call(.0033)
				ci.draw_rect(Rect2(cx - rw + rh, sy - rh, 2 * (rw - rh), 2 * rh), Color(0, 0, 0, .85))
				ci.draw_circle(Vector2(cx - rw + rh, sy), rh, Color(0, 0, 0, .85))
				ci.draw_circle(Vector2(cx + rw - rh, sy), rh, Color(0, 0, 0, .85))
		draw.call(ci, P, ww, hh))
	var face := Mk.mat(Color.WHITE, rough, metal, {"map": t, "normal": Mk.scratch_normal(), "normal_scale": 0.25})
	var edge := Mk.mat(base.darkened(0.3), 0.5, metal)
	var g := Node3D.new()
	Mk.mi(Mk.rounded_box(Vector3(RW, h, .003), .0008, [edge, edge, edge, edge, face, edge], 2), null, Vector3(0, 0, .0015), g)
	Mk.mi(Mk.box(Vector3(RW - .04, h - .004, .2)), Mk.mat(Mk.c(0x0b0b0b), 0.6, 0.5), Vector3(0, 0, -.1), g)
	var sys2 := [0.0] if units == 1 else [h / 2 - .016, -h / 2 + .016]
	for sxm in [-RW / 2 + .008, RW / 2 - .008]:
		for sy in sys2:
			var s := Mk.screw_head()
			s.rotation.x = PI / 2
			s.position = Vector3(sxm, sy, .0032)
			g.add_child(s)
	g.set_meta("h", h)
	return g


func at(unit: Node3D, mx: float, fy: float) -> Vector3:
	var h: float = unit.get_meta("h")
	return Vector3(-RW / 2 + mx, h / 2 - fy * h, .0031)


# ---------------------------------------------------------------- RT-140
func _build_tempo() -> void:
	var notes := TempoEngine.NOTES
	tempo = faceplate(2, Mk.c(0x9a958d), 21, func(ci, P, W, H):
		Tex.silk(ci, "REEL'S TOOLS", P.call(.03), H * .16, 30, ink(.92))
		Tex.silk(ci, "RT-140  TEMPO COMPUTER", P.call(.03), H * .84, 24, ink(.8))
		ci.draw_rect(Rect2(P.call(.03), H * .3, P.call(.055), 3), Color(0.647, 0.118, 0.078, .9))
		Tex.silk(ci, "BPM", P.call(.12), H * .14, 22, ink(.85))
		Tex.silk(ci, "NOTE  ·  MS", P.call(.235), H * .14, 22, ink(.85))
		Tex.silk(ci, "NOTE", P.call(.343), H * .14, 22, ink(.85), "center")
		Tex.silk(ci, "TEMPO", P.call(.405), H * .14, 22, ink(.85), "center")
		Tex.silk(ci, "TAP", P.call(.05), H * .64, 20, ink(.85), "center")
		Tex.silk(ci, "÷2", P.call(.074), H * .40, 20, ink(.85), "center")
		Tex.silk(ci, "×2", P.call(.09), H * .40, 20, ink(.85), "center")
		Tex.silk(ci, "BEAT", P.call(.302), H * .86, 18, ink(.85), "center")
		for i in notes.size():
			var a := deg_to_rad(-150.0 + i * (300.0 / (notes.size() - 1))) - PI / 2
			ci.draw_circle(Vector2(P.call(.343) + cos(a) * P.call(.0175), H * .55 + sin(a) * P.call(.0175)), 3.0, ink(.8))
		for i in 31:
			var a := deg_to_rad(-150.0 + i * 10.0) - PI / 2
			var r1: float = P.call(.024)
			var r2: float = P.call(.0265 if i % 5 else .028)
			var cc := Vector2(P.call(.405), H * .55)
			ci.draw_line(cc + Vector2(cos(a), sin(a)) * r1, cc + Vector2(cos(a), sin(a)) * r2, ink(.8), 3.0, true))
	tempo.name = "RT140"
	# afficheur LED 7 segments
	led = Tex.live(512, 192, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x070101))
		var s := ("%.1f" % engine.bpm).replace(".", "")
		s = s.lpad(4).right(4)
		Tex.seg7(ci, s, 26, 22, 96, 148, 22, Mk.c(0xffd0c0) if _led_flash_state else Mk.c(0xff3d22), Color(1, 0.2, 0.08, .06), 3))
	var led_win := Mk.face_window(Mk.glow(Color.WHITE, 1.6, led.texture), .07, .028, Mk.c(0x3a0705))
	led_win.position = at(tempo, .135, .5)
	tempo.add_child(led_win)
	# VFD à points
	vfd = Tex.live(96, 24, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Color.BLACK)
		var lines := _vfd_lines()
		var f := Tex.font("mono")
		ci.draw_string(f, Vector2(1, 9), lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
		ci.draw_string(f, Vector2(1, 21), lines[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE))
	var dm := ShaderMaterial.new()
	dm.shader = load("res://core/shaders/dotmatrix.gdshader")
	dm.set_shader_parameter("text_tex", vfd.texture)
	var vfd_win := Mk.face_window(dm, .096, .024, Mk.c(0x0a2a26))
	vfd_win.position = at(tempo, .235, .5)
	vfd_win.name = "VFD"
	tempo.add_child(vfd_win)
	# sélecteur de note
	var sel_holder := Node3D.new()
	sel_holder.rotation.x = PI / 2
	sel_holder.position = at(tempo, .343, .55)
	sel_holder.name = "NoteSelector"
	sel_spin = Mk.knob(.0085, .016)
	sel_holder.add_child(sel_spin)
	tempo.add_child(sel_holder)
	# gros potard tempo
	var enc_holder := Node3D.new()
	enc_holder.rotation.x = PI / 2
	enc_holder.position = at(tempo, .405, .55)
	enc_holder.name = "TempoKnob"
	enc = Mk.alu_knob(.0175, .022)
	enc_holder.add_child(enc)
	tempo.add_child(enc_holder)
	# pad TAP
	var pad_mat := Mk.mat(Mk.c(0x2b2b2d), 0.9, 0.0, {"rim": 0.3})
	tap_btn = Mk.mi(Mk.rounded_box(Vector3(.022, .022, .01), .003, pad_mat), null, at(tempo, .05, .36), tempo)
	tap_btn.position.z = .005
	tap_btn.name = "TapPad"
	tap_led_mat = Mk.glow(Mk.c(0xff2a10), .2) as StandardMaterial3D
	var tl := Mk.mi(Mk.cyl(.0018, .0018, .002, 16), tap_led_mat, at(tempo, .05, .13), tempo)
	tl.rotation.x = PI / 2
	for pair in [[.074, "Half"], [.09, "Double"]]:
		var b := Mk.mi(Mk.cyl(.0042, .0042, .005, 32), Mk.chrome_mat(), at(tempo, pair[0], .62), tempo)
		b.rotation.x = PI / 2
		b.name = pair[1]
	jewel_mat = Mk.mat(Mk.c(0x400404), 0.1, 0.0, {"emission": Mk.c(0xff2a10), "energy": .2, "clearcoat": 1.0})
	var jw := Mk.mi(Mk.sphere(.0035, 24, 12, true), jewel_mat, at(tempo, .302, .62), tempo)
	jw.rotation.x = PI / 2
	jw.scale = Vector3(1, .75, 1)
	draw_led()
	draw_vfd()


func _vfd_lines() -> Array:
	if not vfd_msg.is_empty():
		return vfd_msg
	var ms := engine.note_ms()
	var l2 := ("%.1f" % ms).lpad(6) + " ms "
	if not engine.note_is_decay():
		l2 += "%.2fHz" % (1000.0 / ms)
	return [engine.note_label(), l2]


func draw_led(flash_on := false) -> void:
	_led_flash_state = flash_on
	led.redraw()


func draw_vfd() -> void:
	vfd.redraw()


func message(a: String, b: String, secs := 1.1) -> void:
	vfd_msg = [a, b]
	vfd_msg_until = Time.get_ticks_msec() / 1000.0 + secs
	draw_vfd()


func on_tap() -> void:
	tap_press = 1.0
	flash = 1.0
	if not engine.tap():
		message("TAP...", "  keep tapping")


# ---------------------------------------------------------------- RT-220
func _build_loud() -> void:
	loud = faceplate(2, Mk.c(0x101011), 41, func(ci, P, W, H):
		Tex.silk(ci, "RT-220  LOUDNESS", P.call(.03), H * .84, 24, cream(.75))
		Tex.silk(ci, "REEL'S TOOLS", P.call(.03), H * .16, 24, cream(.85))
		Tex.silk(ci, "LUFS", P.call(.44), H * .84, 20, cream(.55), "right"), .6, .55)
	loud.name = "RT220"
	var vu_tex := Tex.canvas(512, 300, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xe9d9aa))
		for i in 30:
			ci.draw_arc(Vector2(256, 180), 300.0 - i * 10.0, 0, TAU, 64, Color(0.47, 0.31, 0.12, .35 * (1.0 - i / 30.0) * .35), 11.0)
		var dark := Mk.c(0x1a1a1a)
		var red := Mk.c(0xb3241a)
		ci.draw_arc(Vector2(256, 330), 230, -2.3, -.84, 64, dark, 3.0, true)
		ci.draw_arc(Vector2(256, 330), 236, -1.12, -.84, 32, red, 7.0, true)
		var vals := [-20, -10, -7, -5, -3, -2, -1, 0, 1, 2, 3]
		for i in vals.size():
			var a := -2.3 + (float(i) / (vals.size() - 1)) * 1.46
			var col := red if vals[i] > 0 else dark
			var dir := Vector2(cos(a), sin(a))
			ci.draw_line(Vector2(256, 330) + dir * 230, Vector2(256, 330) + dir * 252, col, 3.0, true)
			Tex.silk(ci, str(absi(vals[i])), 256 + dir.x * 272, 330 + dir.y * 272, 20, col, "center", 600)
		Tex.silk(ci, "VU", 256, 222, 46, dark, "center"))
	for s in [-1, 1]:
		var g := Node3D.new()
		Mk.mi(Mk.quad(.1, .058), Mk.mat(Mk.c(0x6e6658), .85, 0.0, {"map": vu_tex, "emission": Mk.c(0xffb060), "energy": .12, "emission_tex": vu_tex}), Vector3(0, 0, .0012), g)
		var pv := Node3D.new()
		pv.position = Vector3(0, -.034, .0022)
		Mk.mi(Mk.box(Vector3(.0007, .056, .0004)), Mk.mat(Mk.c(0x111111), 0.5), Vector3(0, .028, 0), pv)
		g.add_child(pv)
		vu_needles.append(pv)
		Mk.mi(Mk.quad(.1, .058), Mk.mat(Color.WHITE, .04, 0.0, {"alpha": .12, "clearcoat": 1.0}), Vector3(0, 0, .006), g)
		Mk.mi(Mk.rounded_box(Vector3(.108, .066, .004), .002, Mk.mat(Mk.c(0x0a0a0a), .3, 0.0, {"clearcoat": .6})), null, Vector3(0, 0, -.001), g)
		g.position = Vector3(s * .075 + .04, 0, .004)
		loud.add_child(g)


# ---------------------------------------------------------------- clic
func add_picks() -> void:
	Mk.add_pick(tempo, "m:tempo", 1)
	Mk.add_pick(loud, "m:loudness", 1)
	for side in [get_node("Side-1"), get_node("Side1")]:
		Mk.add_pick(side, "m:tempo", 1)
	Mk.add_pick(tempo.get_node("TempoKnob"), "tempo", 2, .004)
	Mk.add_pick(tempo.get_node("NoteSelector"), "note", 2, .004)
	Mk.add_pick(tap_btn, "tap", 2, .003)
	Mk.add_pick(tempo.get_node("Half"), "half", 2, .002)
	Mk.add_pick(tempo.get_node("Double"), "double", 2, .002)
	Mk.add_pick(tempo.get_node("VFD"), "copy", 2)


# ---------------------------------------------------------------- animation
func animate(t: float, dt: float, reduced: bool) -> void:
	var ph := engine.beat_phase(t)
	var pulse := 0.4 if reduced else exp(-ph * 8.0)
	jewel_mat.emission_energy_multiplier = .15 + pulse * 5.0
	tap_led_mat.emission_energy_multiplier = .15 + flash * 6.0 + pulse * .4
	var k := 1.0 - pow(0.75, dt * 60.0)
	var spin: Node3D = enc.get_meta("spin")
	spin.rotation.y += ((-(engine.bpm - 30.0) / 270.0 * PI * 1.66) - spin.rotation.y) * k
	var target_sel := -deg_to_rad(-150.0 + engine.note_ix * (300.0 / (TempoEngine.NOTES.size() - 1)))
	sel_spin.rotation.y += (target_sel - sel_spin.rotation.y) * (1.0 - pow(0.7, dt * 60.0))
	var decay := pow(0.8, dt * 60.0)
	tap_press *= decay
	flash *= pow(0.86, dt * 60.0)
	tap_btn.position.z = .005 - tap_press * .003
	if flash > .04:
		var on := flash > .5
		if on != _led_flash_state or flash > .04:
			draw_led(on)
	elif _led_flash_state:
		draw_led(false)
	if not vfd_msg.is_empty() and Time.get_ticks_msec() / 1000.0 > vfd_msg_until:
		vfd_msg = []
		draw_vfd()
	if not reduced:
		for i in vu_needles.size():
			var g := -.62 + pulse * .75 + sin(t * (2 + i)) * .06
			vu_needles[i].rotation.z += (-g - vu_needles[i].rotation.z) * (1.0 - pow(0.8, dt * 60.0))
