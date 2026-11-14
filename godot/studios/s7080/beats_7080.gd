class_name Beats7080
extends Node3D
## Module Boîtes à rythmes du studio 70/80 : deux appareils rackables noirs (façon Waves / Slate) dans
## une tour de racks en noyer sur roulettes.
##   · en haut, la BATTERIE : 16 pas lumineux, 5 instruments (KICK, CLAP, HAT, OPEN, PERC), potards
##     STYLE / BPM / SWING, GÉNÉRER, SYNC FAX (se caler sur la grille et le tempo du fax), EXPORT MIDI,
##     LECTURE. Molette sur un pas de hi-hat = roulement (x2, x3, x4).
##   · en bas, la 808 : 16 pas + petit clavier d'une octave (clic sur un pas = le choisir / l'allumer,
##     clic sur une touche = sa note). La 808 suit la fondamentale des accords du fax.
## Clavier : Espace = lecture, G = générer, S = sync fax, E = export, 1–5 = instrument.
##
## Repère local : façade vers +Z (vers le fauteuil), tour posée sur y = 0. Corps entier : "m:beats".

const W := .483
const TOP_H0 := .045          # hauteur avant de la boîte batterie
const TOP_H1 := .09           # hauteur arrière

var fax: Fax7080
var style := 1
var bpm := 140
var swing := .5
var synced := false
var drums: Array = []
var bass := PackedInt32Array()
var instr := 0
var bass_sel := 0
var seed := 1
var playing := false
var clock := 0.0
var cur_step := -1

var player: AudioStreamPlayer
var pb: AudioStreamPlaybackPolyphonic
var _bass_voice := -1
var _open_voice := -1
var dialog: FileDialog
var led: TexLib.LiveCanvas
var d_leds: Array[StandardMaterial3D] = []
var b_leds: Array[StandardMaterial3D] = []
var d_caps: Array[Node3D] = []
var b_caps: Array[Node3D] = []
var i_leds: Array[StandardMaterial3D] = []
var keys: Array[Node3D] = []
var key_mats: Array[StandardMaterial3D] = []
var knobs := {}
var play_led: StandardMaterial3D
var sync_led: StandardMaterial3D
var _drag_kind := ""
var _drag_acc := Vector2.ZERO
var _info := ""
var _info_t := 0.0


func _init(fax_ref: Fax7080) -> void:
	name = "Beats7080"
	fax = fax_ref
	ready.connect(func():
		Mk.add_pick(self, "m:beats", 1)
		player.stream = AudioStreamPolyphonic.new()
		(player.stream as AudioStreamPolyphonic).polyphony = 48
		player.play()
		pb = player.get_stream_playback() as AudioStreamPlaybackPolyphonic, CONNECT_ONE_SHOT)
	style = int(Store.get_v("beats_style", style))
	bpm = int(Store.get_v("beats_bpm", bpm))
	swing = float(Store.get_v("beats_swing", swing))
	seed = int(Store.get_v("beats_seed", 1))
	_load_pattern()
	_build_tower()
	_build_drum_unit()
	_build_bass_unit()
	player = AudioStreamPlayer.new()
	player.name = "BeatsPlayer"
	add_child(player)
	dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.filters = PackedStringArray(["*.mid ; Fichier MIDI"])
	dialog.title = "Enregistrer le rythme (MIDI)"
	dialog.file_selected.connect(_export_to)
	add_child(dialog)
	_refresh()


func _load_pattern() -> void:
	var sd = Store.get_v("beats_drums", [])
	var sb = Store.get_v("beats_bass", [])
	if sd is Array and sd.size() == 5 and sb is PackedInt32Array and sb.size() == 16:
		drums = []
		for row in sd:
			drums.append(PackedInt32Array(row))
		bass = sb
	else:
		_generate()


func _save_pattern() -> void:
	Store.set_v("beats_drums", drums)
	Store.set_v("beats_bass", bass)


# ---------------------------------------------------------------- construction
## Tour de racks 19" en noyer sur roulettes. Les deux machines sont des appareils rackables noirs
## façon plugins Waves / Slate (aluminium anodisé noir, sérigraphie blanche, LED rouges, poignées).
const RACK_W := .483
const U := .04445
const TOWER_W := .58
const TOWER_D := .52
const TOWER_H := 1.34
const DRUM_Y := 1.14          # centre de la façade batterie (3U)
const BASS_Y := DRUM_Y - 1.5 * U - .001 - U - .001  # centre de la façade 808 (2U), juste dessous
const FOCUS := Vector3(0, (DRUM_Y + BASS_Y) / 2 - .005, TOWER_D / 2 - .02)
const FOCUS_H := .16

var _black_al: StandardMaterial3D
var _ink := Color(.92, .9, .86, .92)
var _ink_dim := Color(.92, .9, .86, .55)


func _x_step(i: int) -> float:
	return -.1875 + i * .025


func _build_tower() -> void:
	var walnut := Mk.pbr("fine_grained_wood", .5, {"wear": 0.45, "tint": Mk.c(0xc8a890), "rough": .75, "clearcoat": .35})
	var dark := Mk.mat(Mk.c(0x0a0a0a), .7)
	_black_al = Mk.mat(Mk.c(0x161618), .32, .85, {"normal": Mk.scratch_normal(), "normal_scale": .12})
	var t := .028
	# caisse : joues, dessus, fond, socle à roulettes
	for sx in [-1, 1]:
		Mk.mi(Mk.rounded_box(Vector3(t, TOWER_H - .06, TOWER_D), .006, walnut, 2), null, Vector3(sx * (TOWER_W / 2 - t / 2), .06 + (TOWER_H - .06) / 2, 0), self)
	Mk.mi(Mk.rounded_box(Vector3(TOWER_W + .01, t, TOWER_D + .01), .008, walnut, 2), null, Vector3(0, TOWER_H - t / 2, 0), self)
	Mk.mi(Mk.rounded_box(Vector3(TOWER_W, .03, TOWER_D), .004, walnut, 2), null, Vector3(0, .075, 0), self)
	Mk.mi(Mk.box(Vector3(TOWER_W - 2 * t, TOWER_H - .1, .01)), dark, Vector3(0, TOWER_H / 2 + .03, -TOWER_D / 2 + .01), self)
	var steel := Mk.mat(Mk.c(0x1a1a1a), .4, .7)
	var rubber := Mk.mat(Mk.c(0x0a0a0a), .7)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var c := Vector3(sx * (TOWER_W / 2 - .05), 0, sz * (TOWER_D / 2 - .05))
			Mk.mi(Mk.box(Vector3(.05, .012, .05)), steel, c + Vector3(0, .056, 0), self)
			Mk.mi(Mk.box(Vector3(.008, .03, .03)), steel, c + Vector3(0, .04, 0), self)
			var wh := Mk.mi(Mk.cyl(.026, .026, .02, 18), rubber, c + Vector3(0, .027, .01), self)
			wh.rotation.z = PI / 2
	# rails 19"
	var rail := Mk.mat(Mk.c(0x202020), .45, .8)
	for sx in [-1, 1]:
		Mk.mi(Mk.box(Vector3(.02, TOWER_H - .14, .008)), rail, Vector3(sx * (RACK_W / 2 - .006), TOWER_H / 2 + .02, TOWER_D / 2 - .03), self)
	# lampe de rack à col de cygne sur le dessus : éclaire les façades
	var lb := Vector3(-.2, TOWER_H, TOWER_D / 2 - .06)
	Mk.mi(Mk.cyl(.03, .035, .02, 20), steel, lb + Vector3(0, .01, 0), self)
	var neck := [lb + Vector3(0, .02, 0), lb + Vector3(0, .16, .02), lb + Vector3(.06, .24, .1), lb + Vector3(.12, .22, .17)]
	Mk.mi(Mk.tube(neck, .006, 24, 8), steel, Vector3.ZERO, self)
	var head := Node3D.new()
	head.position = neck[3]
	add_child(head)
	head.basis = Basis.looking_at(Vector3(.05, -1, .25), Vector3.UP)
	var shade := Mk.mi(Mk.cyl(.022, .03, .06, 20, false), Mk.mat(Mk.c(0x1a1a1a), .4, .6, {"cull_off": true}), Vector3(0, 0, -.02), head)
	shade.rotation.x = PI / 2
	var bulb := Mk.mi(Mk.disc(.026, 20), Mk.glow(Mk.c(0xffd8a8), 4.0), Vector3(0, 0, -.05), head)
	bulb.rotation.x = -PI / 2
	var rl := SpotLight3D.new()
	rl.light_color = Mk.c(0xffd8b0)
	rl.light_energy = 2.2
	rl.spot_range = 1.2
	rl.spot_angle = 48.0
	rl.spot_angle_attenuation = 1.2
	rl.shadow_enabled = true
	rl.position = Vector3(0, 0, -.06)
	head.add_child(rl)
	# appareils de remplissage : patchbay en haut, puis sous la 808 : blanc, compresseur, ventil, alim
	var y := TOWER_H - t - .004
	_filler(y - U / 2, 1, "patch")
	var fill := [[1, "vent"], [2, "comp"], [1, "blank"], [2, "eq"], [1, "vent"], [1, "power"], [2, "blank"], [1, "vent"]]
	var yy := BASS_Y - U - .001
	for f in fill:
		var h: float = f[0] * U
		if yy - h < .1:
			break
		_filler(yy - h / 2, f[0], f[1])
		yy -= h + .001


## Façade d'un appareil rackable (vue de face, +Z). draw(ci, X, Y, w, h) avec X(m) et Y(m) -> pixels.
func _face(units: int, cy: float, draw: Callable, res := 1536) -> Node3D:
	var h := units * U - .001
	var pw := res
	var ph := int(round(res * h / W))
	var tex := Tex.canvas(pw, ph, func(ci, w, hh):
		ci.draw_rect(Rect2(0, 0, w, hh), Mk.c(0x141416))
		Tex.brushed(ci, w, hh, 900 + units, .035, 1200)
		var X := func(x: float) -> float: return (x + W / 2) / W * w
		var Y := func(y: float) -> float: return (h / 2 - y) / h * hh
		# oreilles de rack : trous oblongs
		for sx in [-1, 1]:
			for k in units:
				var ey: float = h / 2 - U / 2 - k * U
				var ex: float = sx * (W / 2 - .008)
				ci.draw_rect(Rect2(X.call(ex) - 7, Y.call(ey) - 4, 14, 8), Color(0, 0, 0, .9))
		draw.call(ci, X, Y, w, hh)
		Tex.grime(ci, w, hh, 910 + units, .5))
	var holder := Node3D.new()
	holder.position = Vector3(0, cy, TOWER_D / 2 - .022)
	add_child(holder)
	var fm := Mk.mat(Color.WHITE, .34, .8, {"map": tex, "normal": Mk.scratch_normal(), "normal_scale": .1})
	Mk.mi(Mk.rounded_box(Vector3(W, h, .006), .0015, [_black_al, _black_al, _black_al, _black_al, fm, _black_al], 1), null, Vector3.ZERO, holder)
	# corps de l'appareil dans la tour
	Mk.mi(Mk.box(Vector3(W - .04, h - .004, TOWER_D - .1)), _black_al, Vector3(0, 0, -(TOWER_D - .1) / 2 - .003), holder)
	# vis d'oreilles
	for sx in [-1, 1]:
		for k in units:
			var sc := Mk.screw_head(.0032)
			sc.rotation.x = PI / 2
			sc.position = Vector3(sx * (W / 2 - .008), h / 2 - U / 2 - k * U, .0035)
			holder.add_child(sc)
	return holder


## Poignées chromées façon Slate / API sur les oreilles.
func _handles(holder: Node3D, h: float) -> void:
	var chrome := Mk.chrome_mat()
	for sx in [-1, 1]:
		var x: float = sx * (RACK_W / 2 - .019)
		var top := Vector3(x, h / 2 - .012, .003)
		var bot := Vector3(x, -h / 2 + .012, .003)
		Mk.mi(Mk.tube([top, top + Vector3(0, -.004, .022), bot + Vector3(0, .004, .022), bot], .0042, 20, 8), chrome, Vector3.ZERO, holder)


func _filler(cy: float, units: int, kind: String) -> void:
	var holder := _face(units, cy, func(ci, X, Y, w, h): _draw_filler(ci, X, Y, w, h, kind))
	match kind:
		"comp", "eq":
			for k in 6:
				_knob(holder, Vector3(-.12 + k * .055, -.0045 * units, .003), .0085, "")
			_handles(holder, units * U - .001)
			Mk.mi(Mk.quad(.05, .035), Mk.glow(Mk.c(0xffd8a0), .9), Vector3(.19, 0, .0035), holder)
		"power":
			var lm := Mk.mat(Mk.c(0x300805), .4, 0.0, {"emission": Mk.c(0xff2a18), "energy": 1.4})
			var pl := Mk.mi(Mk.cyl(.003, .003, .004, 10), lm, Vector3(.18, 0, .004), holder)
			pl.rotation.x = PI / 2


func _draw_filler(ci: CanvasItem, X: Callable, Y: Callable, w: float, h: float, kind: String) -> void:
	match kind:
		"patch":
			for row in 2:
				for k in 24:
					var px: float = X.call(-.2 + k * .0174)
					var py: float = h * (.3 + row * .42)
					ci.draw_circle(Vector2(px, py), 6, Color(.6, .6, .58))
					ci.draw_circle(Vector2(px, py), 3.5, Color(0, 0, 0))
			Tex.silk(ci, "PATCH", X.call(.205), h * .55, 14, _ink_dim, "right", 600)
		"vent":
			var x0: float = X.call(-.19)
			while x0 < X.call(.19):
				ci.draw_rect(Rect2(x0, h * .3, 9, h * .4), Color(0, 0, 0, .95))
				x0 += 18
		"comp", "eq":
			Tex.silk(ci, "RT-C76  COMPRESSOR" if kind == "comp" else "RT-Q5  EQUALIZER", X.call(-.2), h * .3, 20, _ink, "left", 700)
			for k in 6:
				var c := Vector2(X.call(-.12 + k * .055), h * .62)
				ci.draw_circle(c, h * .2, Color(0, 0, 0, .7))
				for tk in 11:
					var a := deg_to_rad(-135 + tk * 27)
					ci.draw_line(c + Vector2(sin(a), -cos(a)) * h * .25, c + Vector2(sin(a), -cos(a)) * h * .29, _ink_dim, 2.0)
		"power":
			Tex.silk(ci, "RT-PWR  POWER CONDITIONER", X.call(-.2), h * .62, 16, _ink, "left", 600)
		_:
			pass


## Petit potard noir (axe vers +Z). Renvoie le nœud qui tourne (rotation.y = valeur).
func _knob(holder: Node3D, at: Vector3, r: float, action: String) -> Node3D:
	var base := Node3D.new()
	base.position = at
	base.rotation.x = PI / 2
	holder.add_child(base)
	var kn := Mk.knob(r, r * 1.3)
	base.add_child(kn)
	if action != "":
		Mk.add_pick_later(base, action, .004)
	return kn


## Bouton de pas : capuchon carré en caoutchouc + LED rouge au-dessus (face +Z).
func _step_button(holder: Node3D, at: Vector3, action: String, leds: Array[StandardMaterial3D], caps: Array[Node3D], col := 0x2a2a2c) -> void:
	var b := Node3D.new()
	b.position = at
	holder.add_child(b)
	Mk.mi(Mk.rounded_box(Vector3(.019, .017, .004), .002, Mk.mat(Mk.c(0x050505), .6), 1), null, Vector3(0, 0, .002), b)
	var cap := Node3D.new()
	b.add_child(cap)
	Mk.mi(Mk.rounded_box(Vector3(.016, .014, .008), .003, Mk.mat(Mk.c(col), .55, 0.0, {"clearcoat": .2}), 2), null, Vector3(0, 0, .006), cap)
	var lm := Mk.mat(Mk.c(0x300805), .4, 0.0, {"emission": Mk.c(0xff2a18), "energy": .05})
	var led_n := Mk.mi(Mk.cyl(.0022, .0022, .003, 10), lm, Vector3(0, .0125, .0045), b)
	led_n.rotation.x = PI / 2
	leds.append(lm)
	caps.append(cap)
	Mk.add_pick_later(b, action, .003)


func _small_button(holder: Node3D, at: Vector3, col: Color, action: String, led_col := Color(0, 0, 0, 0)) -> StandardMaterial3D:
	var b := Node3D.new()
	b.position = at
	holder.add_child(b)
	Mk.mi(Mk.rounded_box(Vector3(.022, .013, .004), .002, Mk.mat(Mk.c(0x050505), .6), 1), null, Vector3(0, 0, .002), b)
	Mk.mi(Mk.rounded_box(Vector3(.019, .01, .008), .003, Mk.mat(col, .4, .1, {"clearcoat": .4}), 2), null, Vector3(0, 0, .006), b)
	Mk.add_pick_later(b, action, .003)
	if led_col.a > 0:
		var lm := Mk.mat(led_col.darkened(.85), .4, 0.0, {"emission": led_col, "energy": .05})
		var l := Mk.mi(Mk.cyl(.0022, .0022, .003, 10), lm, Vector3(0, .011, .0045), b)
		l.rotation.x = PI / 2
		return lm
	return null


func _x_instr(i: int) -> float:
	return -.075 + i * .028


const FN_X := {"gen": .08, "sync": .108, "export": .136, "play": .19}


func _build_drum_unit() -> void:
	var h := 3 * U - .001
	var holder := _face(3, DRUM_Y, func(ci, X, Y, w, hh):
		Tex.silk(ci, "RT-707", X.call(-.205), Y.call(.052), 30, _ink, "left", 800)
		Tex.silk(ci, "RHYTHM COMPOSER", X.call(-.205), Y.call(.04), 13, _ink_dim, "left", 600)
		for i in BeatEngine.INSTR.size():
			Tex.silk(ci, BeatEngine.INSTR[i], X.call(_x_instr(i)), Y.call(.04), 12, _ink, "center", 600)
		var lab := {"GÉNÉRER": FN_X.gen, "SYNC": FN_X.sync, "MIDI": FN_X.export, "LECTURE": FN_X.play}
		for k in lab:
			Tex.silk(ci, k, X.call(lab[k]), Y.call(.04), 11, _ink, "center", 600)
		for k in [["STYLE", -.185], ["BPM", -.15], ["SWING", -.115]]:
			Tex.silk(ci, k[0], X.call(k[1]), Y.call(-.016), 10, _ink_dim, "center", 600)
		for i in 16:
			Tex.silk(ci, str(i + 1), X.call(_x_step(i)), Y.call(-.054), 10, _ink_dim, "center", 600)
		for g in 4:
			ci.draw_rect(Rect2(X.call(_x_step(g * 4) - .01), Y.call(-.05), X.call(_x_step(g * 4 + 3) + .01) - X.call(_x_step(g * 4) - .01), 2), Color(.85, .12, .08, .8) if g % 2 == 0 else _ink_dim)
		Tex.silk(ci, "MOLETTE SUR UN PAS DE HAT = ROULEMENT", X.call(.205), Y.call(-.016), 9, _ink_dim, "right", 500))
	_handles(holder, h)
	# afficheur rouge à points
	led = Tex.live(512, 128, func(ci, w, hh):
		ci.draw_rect(Rect2(0, 0, w, hh), Mk.c(0x0a0202))
		var lines := _led_lines()
		Tex.silk(ci, lines[0], 14, hh * .42, 40, Mk.c(0xff3a22), "left", 600, "mono")
		Tex.silk(ci, lines[1], 14, hh * .86, 30, Mk.c(0xff3a22).darkened(.25), "left", 500, "mono"))
	var win := Mk.face_window(Mk.glow(Color.WHITE, 1.4, led.texture), .1, .026, Mk.c(0x2a0606))
	win.position = Vector3(-.145, .022, .004)
	holder.add_child(win)
	# potards STYLE / BPM / SWING
	for k in [["style", -.185], ["bpm", -.15], ["swing", -.115]]:
		knobs[k[0]] = _knob(holder, Vector3(k[1], -.002, .003), .008, "beats:knob:" + k[0])
	# instruments + fonctions
	for i in BeatEngine.INSTR.size():
		i_leds.append(_small_button(holder, Vector3(_x_instr(i), .022, .003), Mk.c(0x2a2a2c), "beats:instr:%d" % i, Mk.c(0xff2a18)))
	_small_button(holder, Vector3(FN_X.gen, .022, .003), Mk.c(0x6a6a6e), "beats:gen")
	sync_led = _small_button(holder, Vector3(FN_X.sync, .022, .003), Mk.c(0x2a2a2c), "beats:sync", Mk.c(0x40ff60))
	_small_button(holder, Vector3(FN_X.export, .022, .003), Mk.c(0x2a2a2c), "beats:export")
	play_led = _small_button(holder, Vector3(FN_X.play, .022, .003), Mk.c(0xb02018), "beats:play", Mk.c(0x40ff60))
	# 16 pas
	for i in 16:
		_step_button(holder, Vector3(_x_step(i), -.034, .003), "beats:dstep:%d" % i, d_leds, d_caps)


func _build_bass_unit() -> void:
	var h := 2 * U - .001
	var holder := _face(2, BASS_Y, func(ci, X, Y, w, hh):
		Tex.silk(ci, "RT-808  SUB BASS", X.call(.205), Y.call(-.03), 20, _ink, "right", 800)
		Tex.silk(ci, "PAS : CHOISIR  ·  TOUCHE : NOTE", X.call(.205), Y.call(-.039), 9, _ink_dim, "right", 500)
		for i in 16:
			Tex.silk(ci, str(i + 1), X.call(_x_step(i)), Y.call(.037), 9, _ink_dim, "center", 600)
		ci.draw_rect(Rect2(X.call(-.2), Y.call(-.014), X.call(.0) - X.call(-.2), 2), _ink_dim))
	_handles(holder, h)
	for i in 16:
		_step_button(holder, Vector3(_x_step(i), .016, .003), "beats:bstep:%d" % i, b_leds, b_caps)
	# petit clavier d'une octave (13 touches) en bas à gauche
	var white := [0, 2, 4, 5, 7, 9, 11, 12]
	var kw := .022
	var kx0 := -.19
	for j in white.size():
		_key(holder, white[j], Vector3(kx0 + j * kw + kw / 2, -.024, .004), Vector3(kw - .002, .03, .006), Mk.c(0xe8e4da))
	var black := {1: 0, 3: 1, 6: 3, 8: 4, 10: 5}
	for semi in black:
		var j: int = black[semi]
		_key(holder, semi, Vector3(kx0 + (j + 1) * kw, -.016, .009), Vector3(.013, .018, .007), Mk.c(0x121212))


func _key(holder: Node3D, semi: int, at: Vector3, size: Vector3, col: Color) -> void:
	var k := Node3D.new()
	k.position = at
	holder.add_child(k)
	var m := Mk.mat(col, .4, 0.0, {"clearcoat": .4, "emission": Mk.c(0xff3020), "energy": 0.0})
	Mk.mi(Mk.rounded_box(size, .0015, m, 1), null, Vector3.ZERO, k)
	k.set_meta("semi", semi)
	keys.append(k)
	key_mats.append(m)
	Mk.add_pick_later(k, "beats:key:%d" % semi, .001)


# ---------------------------------------------------------------- état → visuels
func _led_lines() -> Array:
	var l1 := "%-5s %3d BPM SW%2d%%" % [ChordEngine.STYLES[style], bpm, int(round(swing * 100))]
	var l2 := ""
	if _info_t > 0.0:
		l2 = _info
	elif synced and fax and not fax.prog.is_empty():
		l2 = "SYNC " + ChordEngine.summary(fax.prog).replace(" | ", " ")
	else:
		l2 = "TON. %s  %s" % [ChordEngine.key_name(fax.key) if fax else "-", BeatEngine.INSTR[instr]]
	return [l1, l2.left(22)]


func _say(txt: String) -> void:
	_info = txt
	_info_t = 2.0
	led.redraw()


func _refresh() -> void:
	for i in 16:
		var v: int = drums[instr][i]
		d_leds[i].emission_energy_multiplier = (1.6 if v > 0 else .05) + (.0 if i != cur_step else 2.0)
		d_caps[i].position.z = -.003 if v > 0 else 0.0
		b_leds[i].emission_energy_multiplier = (1.6 if bass[i] >= 0 else .05) + (2.0 if i == cur_step else 0.0) + (.8 if i == bass_sel else 0.0)
		b_caps[i].position.z = -.003 if bass[i] >= 0 else 0.0
	for i in i_leds.size():
		i_leds[i].emission_energy_multiplier = 1.6 if i == instr else .05
	var semi := bass[bass_sel]
	for k in keys.size():
		key_mats[k].emission_energy_multiplier = .5 if int(keys[k].get_meta("semi")) == semi else 0.0
	sync_led.emission_energy_multiplier = 1.4 if synced else .05
	play_led.emission_energy_multiplier = 1.4 if playing else .05
	knobs.style.rotation.y = -(style / 5.0 - .5) * 4.0
	knobs.bpm.rotation.y = -((bpm - 60) / 120.0 - .5) * 4.5
	knobs.swing.rotation.y = -((swing - .5) / .25 - .5) * 4.5
	led.redraw()


# ---------------------------------------------------------------- logique
func _generate() -> void:
	var st: String = ChordEngine.STYLES[style]
	drums = BeatEngine.generate_drums(st, seed)
	bass = BeatEngine.generate_bass(drums, st, seed)
	bass_sel = 0
	_save_pattern()
	Store.set_v("beats_seed", seed)


func _bars() -> int:
	return fax.bars if synced and fax else 1


func _root_at(bar: int) -> int:
	var tonic: int = ChordEngine.key_tonic(fax.key) if fax else 9
	return BeatEngine.root_at(bar, tonic, fax.prog if synced and fax else [])


func toggle_play() -> void:
	playing = not playing
	clock = 0.0
	cur_step = -1
	if not playing:
		_choke()
	_refresh()


func _choke() -> void:
	if pb and _bass_voice >= 0:
		pb.stop_stream(_bass_voice)
	_bass_voice = -1


func set_sync(on: bool) -> void:
	synced = on
	if synced and fax:
		bpm = fax.bpm
		Store.set_v("beats_bpm", bpm)
		_say("CALÉ SUR LE FAX")
	_refresh()


func _hit(i: int, vel := 1.0) -> void:
	if pb == null:
		return
	if i == 2 and _open_voice >= 0:  # le hat ferme l'open hat
		pb.stop_stream(_open_voice)
		_open_voice = -1
	var id := pb.play_stream(BeatSounds.drum(i), 0.0, linear_to_db(vel), 1.0)
	if i == 3:
		_open_voice = id


func _bass_hit(note: int) -> void:
	if pb == null:
		return
	_choke()
	_bass_voice = pb.play_stream(BeatSounds.bass(note), 0.0, -2.0, 1.0)


## Avance l'horloge et déclenche les coups dont l'heure tombe entre l'image précédente et celle-ci.
func _sequence(dt: float) -> void:
	var sd := 60.0 / bpm / 4.0
	var total := 16 * _bars()
	var loop := total * sd
	var t0 := clock
	clock += dt
	var g0 := int(floor(t0 / sd)) - 1
	var g1 := int(floor(clock / sd)) + 1
	for g in range(g0, g1 + 1):
		if g < 0:
			continue
		var s := g % 16
		var bar := (g % total) / 16
		var base := g * sd + ((swing - .5) * 2.0 * sd if s % 2 == 1 else 0.0)
		for i in 5:
			var v: int = drums[i][s]
			for k in v:
				var tt := base + k * sd / v
				if tt >= t0 and tt < clock:
					_hit(i, 1.0 if k == 0 else .6 + .1 * k)
		if bass[s] >= 0 and base >= t0 and base < clock:
			_bass_hit(BeatEngine.bass_note(_root_at(bar), bass[s]))
		if base >= t0 and base < clock and s != cur_step:
			cur_step = s
			_refresh()
	if clock >= loop:
		clock -= loop


func _export_to(path: String) -> void:
	if not path.to_lower().ends_with(".mid"):
		path += ".mid"
	var bars: int = fax.bars if synced and fax else 4
	var tonic: int = ChordEngine.key_tonic(fax.key) if fax else 9
	var data := BeatEngine.to_midi(drums, bass, bpm, swing, bars, tonic, fax.prog if synced and fax else [])
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		Toast.say("Impossible d'écrire le fichier")
		return
	f.store_buffer(data)
	f.close()
	Toast.say("MIDI enregistré : " + path.get_file())


func export_midi() -> void:
	dialog.current_file = "REEL Beat - %s %d BPM%s.mid" % [ChordEngine.STYLES[style].replace("&", "n"), bpm, (" - sync " + ChordEngine.key_name(fax.key)) if synced else ""]
	dialog.popup_centered()


# ---------------------------------------------------------------- interface module
func on_action(a: String) -> void:
	if a == "play":
		toggle_play()
	elif a == "gen":
		seed += 1
		_generate()
		_say("NOUVEAU RYTHME")
		_refresh()
	elif a == "sync":
		set_sync(not synced)
	elif a == "export":
		export_midi()
	elif a.begins_with("instr:"):
		instr = int(a.substr(6))
		_hit(instr)
		_refresh()
	elif a.begins_with("dstep:"):
		var i := int(a.substr(6))
		drums[instr][i] = 0 if drums[instr][i] > 0 else 1
		if drums[instr][i] > 0 and not playing:
			_hit(instr)
		_save_pattern()
		_refresh()
	elif a.begins_with("bstep:"):
		var i := int(a.substr(6))
		if bass_sel == i or bass[i] < 0:
			bass[i] = 0 if bass[i] < 0 else -1
		bass_sel = i
		if bass[i] >= 0 and not playing:
			_bass_hit(BeatEngine.bass_note(_root_at(0), bass[i]))
		_save_pattern()
		_refresh()
	elif a.begins_with("key:"):
		var semi := int(a.substr(4))
		bass[bass_sel] = semi
		_bass_hit(BeatEngine.bass_note(_root_at(0), semi))
		_say("PAS %d : +%d DEMI-TONS" % [bass_sel + 1, semi])
		_save_pattern()
		_refresh()
	elif a.begins_with("knob:"):
		_turn(a.substr(5), 1)


func _turn(k: String, steps: int) -> void:
	match k:
		"style":
			style = posmod(style + steps, ChordEngine.STYLES.size())
			Store.set_v("beats_style", style)
			_say("GÉNÉRER POUR CE STYLE")
		"bpm":
			bpm = clampi(bpm + steps, 60, 180)
			Store.set_v("beats_bpm", bpm)
		"swing":
			swing = clampf(swing + steps * .01, .5, .75)
			Store.set_v("beats_swing", swing)
	_refresh()


func on_press(a: String) -> void:
	_drag_kind = a
	_drag_acc = Vector2.ZERO


func on_drag_start(a: String) -> bool:
	return a.begins_with("knob:")


func on_drag(rel: Vector2, fine: bool) -> void:
	_drag_acc += rel
	if _drag_kind.begins_with("knob:"):
		var k := _drag_kind.substr(5)
		var step := 14.0 if k == "style" else (6.0 if fine else 3.0)
		while _drag_acc.y <= -step:
			_drag_acc.y += step
			_turn(k, 1)
		while _drag_acc.y >= step:
			_drag_acc.y -= step
			_turn(k, -1)


func on_drop(_target: String) -> void:
	if _drag_kind.begins_with("knob:") and _drag_acc.length() < 4.0:
		_turn(_drag_kind.substr(5), 1)
	_drag_kind = ""


func on_wheel(a: String, dir: float, fine: bool) -> void:
	if a.begins_with("knob:"):
		_turn(a.substr(5), int(dir) * (1 if fine or a != "knob:bpm" else 2))
	elif a.begins_with("dstep:") and instr in [2, 3]:
		var i := int(a.substr(6))
		var v: int = drums[instr][i]
		v = posmod(v + int(dir), 5)
		drums[instr][i] = v
		_say("PAS %d : %s" % [i + 1, ["SILENCE", "1 COUP", "ROULEMENT x2", "ROULEMENT x3", "ROULEMENT x4"][v]])
		_save_pattern()
		_refresh()


func on_key(e: InputEventKey) -> bool:
	match e.keycode:
		KEY_SPACE:
			toggle_play()
		KEY_G:
			on_action("gen")
		KEY_S:
			on_action("sync")
		KEY_E:
			export_midi()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			on_action("instr:%d" % (e.keycode - KEY_1))
		_:
			return false
	return true


func animate(_t: float, dt: float, _reduced: bool) -> void:
	if _info_t > 0.0:
		_info_t -= dt
		if _info_t <= 0.0:
			led.redraw()
	if playing:
		_sequence(dt)
		if synced and fax and bpm != fax.bpm:
			bpm = fax.bpm
			_refresh()
