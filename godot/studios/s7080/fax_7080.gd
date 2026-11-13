class_name Fax7080
extends Node3D
## Module Fax d'accords du studio 70/80 : télécopieur d'époque qui imprime une grille d'accords.
##   · 4 molettes : STYLE, BPM, TONALITÉ, MESURES (glisser, molette de la souris, ou clic = cran suivant)
##   · touches de son : RHODES, NAPPE, PAD, GUIT., PLUCK (écoute seulement)
##   · ENVOI : la feuille s'imprime avec la grille ; LECTURE : joue / met en pause la progression en boucle
##   · la feuille : glisser vers le bas = la froisser (boulette par terre + nouvelle grille),
##                  tirer vers le haut = la détacher → export du fichier MIDI (fenêtre d'enregistrement)
## Clavier : Entrée = envoi, Espace = lecture, N = nouvelle grille, E = export MIDI, 1–5 = son.
##
## Repère local : façade vers +Z (vers le fauteuil), posé sur y = 0. Corps entier : "m:fax".

const W := .48
const D := .36
const BASE_H := .065
const SHEET_W := .2
const PAGE_L := .3
const SHEET_X := -.11

var style := 2        # R&B
var bpm := 92
var key := 18         # Am
var bars := 4
var sound := 0
var prog: Array = []
var seed := 1

var printed := 0.0     # longueur de feuille sortie (m)
var printing := false
var sheet_on := false
var playing := false
var _render_job := -1
var _pending_stream: AudioStreamWAV
var _stream_dirty := true

var player: AudioStreamPlayer
var sheet: MeshInstance3D
var sheet_canvas: TexLib.LiveCanvas
var led: TexLib.LiveCanvas
var wheel_canvas: Array[TexLib.LiveCanvas] = []
var wheels: Array[Node3D] = []
var keys: Array[Node3D] = []
var key_leds: Array[StandardMaterial3D] = []
var play_led: StandardMaterial3D
var send_led: StandardMaterial3D
var roll: Node3D
var balls: Array[Node3D] = []
var dialog: FileDialog
var _drag_kind := ""
var _drag_acc := Vector2.ZERO
var _path: PackedVector3Array
var _path_len: PackedFloat32Array
var _anim := ""        # "", "tear", "crumple"
var _anim_t := 0.0
var _sheet_mat: ShaderMaterial
var _last_chord := -1

const BEIGE := 0xd9cdb4
const BROWN := 0x2a1d14


func _init(_walnut: Material) -> void:
	name = "Fax7080"
	ready.connect(func(): Mk.add_pick(self, "m:fax", 1), CONNECT_ONE_SHOT)
	style = int(Store.get_v("fax_style", style))
	bpm = int(Store.get_v("fax_bpm", bpm))
	key = int(Store.get_v("fax_key", key))
	bars = int(Store.get_v("fax_bars", bars))
	sound = int(Store.get_v("fax_sound", sound))
	seed = int(Store.get_v("fax_seed", 1))
	_build_body()
	_build_panel()
	_build_sheet()
	player = AudioStreamPlayer.new()
	player.name = "FaxPlayer"
	add_child(player)
	dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.filters = PackedStringArray(["*.mid ; Fichier MIDI"])
	dialog.title = "Enregistrer la grille d'accords (MIDI)"
	dialog.file_selected.connect(_export_to)
	add_child(dialog)
	_regen(false)


# ---------------------------------------------------------------- construction
func _build_body() -> void:
	var plastic := Mk.mat(Mk.c(BEIGE), .5, 0.0, {"clearcoat": .25, "clearcoat_rough": .5, "normal": Mk.noise_tex(.5, 128, 2), "normal_scale": .12})
	var dark := Mk.mat(Mk.c(BROWN), .55)
	# socle + bandeau brun en façade
	Mk.mi(Mk.rounded_box(Vector3(W, BASE_H, D), .012, plastic, 3), null, Vector3(0, BASE_H / 2, 0), self)
	Mk.mi(Mk.rounded_box(Vector3(W - .01, .022, .004), .002, dark, 1), null, Vector3(0, .028, D / 2 + .001), self)
	var plate := Tex.canvas(512, 32, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(BROWN))
		Tex.silk(ci, "REEL'S TOOLS  ·  TÉLÉCOPIEUR  RT-FX2  ·  GRILLES D'ACCORDS", w / 2.0, h * .72, 17, Color(.95, .88, .7, .8), "center"))
	Mk.mi(Mk.quad(W * .7, .014), Mk.mat(Color.WHITE, .5, 0.0, {"map": plate}), Vector3(0, .028, D / 2 + .0035), self)
	# capot arrière (rouleau de papier sous un couvercle fumé)
	var hump_z := -D / 2 + .075
	Mk.mi(Mk.rounded_box(Vector3(W, .055, .15), .014, plastic, 3), null, Vector3(0, BASE_H + .022, hump_z), self)
	var smoke := Mk.mat(Mk.c(0x1a120a), .08, 0.0, {"alpha": .55, "clearcoat": 1.0})
	Mk.mi(Mk.rounded_box(Vector3(.26, .006, .1), .004, smoke, 2), null, Vector3(SHEET_X, BASE_H + .05, hump_z), self)
	roll = Node3D.new()
	roll.position = Vector3(SHEET_X, BASE_H + .028, hump_z)
	add_child(roll)
	var r := Mk.mi(Mk.cyl(.032, .032, .22, 32), Mk.mat(Mk.c(0xf2eee2), .8), Vector3.ZERO, roll)
	r.rotation.z = PI / 2
	var core := Mk.mi(Mk.cyl(.012, .012, .225, 16), Mk.mat(Mk.c(0x8a6a4a), .8), Vector3.ZERO, roll)
	core.rotation.z = PI / 2
	# fente de sortie du papier
	Mk.mi(Mk.box(Vector3(SHEET_W + .02, .004, .012)), Mk.mat(Mk.c(0x050505), 1.0), Vector3(SHEET_X, BASE_H + .0005, -D / 2 + .158), self)
	Mk.mi(Mk.rounded_box(Vector3(SHEET_W + .04, .008, .02), .003, dark, 1), null, Vector3(SHEET_X, BASE_H + .003, -D / 2 + .17), self)
	# pieds caoutchouc + câble secteur
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			Mk.mi(Mk.cyl(.012, .012, .006, 12), Mk.mat(Mk.c(0x0a0a0a), .9), Vector3(sx * (W / 2 - .04), -.002, sz * (D / 2 - .04)), self)
	Mk.mi(Mk.tube([Vector3(.18, .03, -D / 2), Vector3(.2, .006, -D / 2 - .06), Vector3(.26, .006, -D / 2 - .1)], .0035, 12, 6), Mk.mat(Mk.c(0x161616), .6), Vector3.ZERO, self)


## Panneau de commande (à droite de la feuille) : afficheur, molettes, touches de son, lecture, envoi.
func _build_panel() -> void:
	var px0 := .015
	var px1 := W / 2 - .012
	var pz0 := -D / 2 + .16
	var pz1 := D / 2 - .012
	var pw := px1 - px0
	var pd := pz1 - pz0
	var cx := (px0 + px1) / 2
	var cz := (pz0 + pz1) / 2
	var tex := Tex.canvas(1024, int(1024 * pd / pw), func(ci, w, h):
		var P := func(x: float) -> float: return (x - px0) / pw * w
		var Z := func(z: float) -> float: return (z - pz0) / pd * h
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x1e1813))
		Tex.brushed(ci, w, h, 4040, .04, 2500)
		var ink := Color(.95, .88, .7, .75)
		var names := ["STYLE", "BPM", "TON.", "MES."]
		for i in 4:
			Tex.silk(ci, names[i], P.call(_wheel_x(i)), Z.call(.075), 24, ink, "center")
		for i in 5:
			Tex.silk(ci, FaxSynth.SOUNDS[i], P.call(_key_x(i)), Z.call(.091), 19, ink, "center")
		Tex.silk(ci, "LECTURE", P.call(.075), Z.call(.163), 20, ink, "center")
		Tex.silk(ci, "ENVOI", P.call(.175), Z.call(.163), 22, ink, "center")
		ci.draw_line(Vector2(P.call(px0 + .008), Z.call(.08)), Vector2(P.call(px1 - .008), Z.call(.08)), Color(.95, .88, .7, .15), 2.0)
		Tex.grime(ci, w, h, 4041, 1.0))
	Mk.mi(Mk.rounded_box(Vector3(pw, .004, pd), .003, Mk.mat(Color.WHITE, .5, .3, {"map": tex}), 2), null, Vector3(cx, BASE_H + .002, cz), self)
	# panneau incliné : on le fait monter un peu vers l'arrière ? (reste plat : plus lisible en gros plan)
	# afficheur LED (vert-bleu fluorescent, typique des fax) : grille / accord joué
	led = Tex.live(768, 112, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x020806))
		var txt := _led_text()
		Tex.silk(ci, txt, 18, h * .7, 52, Mk.c(0x6affd8), "left", 500, "mono"))
	var win := Mk.face_window(Mk.glow(Color.WHITE, 1.6, led.texture), .19, .028, Mk.c(0x0a3a30))
	win.position = Vector3(cx, BASE_H + .0045, -.003)
	win.rotation.x = -PI / 2
	add_child(win)
	# 4 molettes crantées (axe le long de x), avec fenêtre de valeur au-dessus
	for i in 4:
		var x := _wheel_x(i)
		var holder := Node3D.new()
		holder.position = Vector3(x, BASE_H + .004, .05)
		add_child(holder)
		var lc := Tex.live(160, 72, func(ci, w, h):
			ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x0c0b0a))
			Tex.silk(ci, _wheel_text(i), w / 2.0, h * .74, 40, Mk.c(0xf2ead6), "center", 600, "mono"))
		wheel_canvas.append(lc)
		var vw := Mk.mi(Mk.quad(.04, .016), Mk.glow(Color.WHITE, .8, lc.texture), Vector3(0, .0016, -.024), holder)
		vw.rotation.x = -PI / 2
		Mk.mi(Mk.box(Vector3(.044, .002, .02)), Mk.mat(Mk.c(0x050505), .6), Vector3(0, .0004, -.024), holder)
		# fente + molette striée
		Mk.mi(Mk.box(Vector3(.018, .002, .026)), Mk.mat(Mk.c(0x050505), 1.0), Vector3(0, .0004, .004), holder)
		var wh := Node3D.new()
		wh.position = Vector3(0, -.008, .004)
		holder.add_child(wh)
		var disc := Mk.mi(Mk.cyl(.017, .017, .012, 24), Mk.mat(Mk.c(0x2a2a2a), .45, .3), Vector3.ZERO, wh)
		disc.rotation.z = PI / 2
		for k in 24:
			var a := k * TAU / 24
			var rib := Mk.mi(Mk.box(Vector3(.0125, .0016, .002)), Mk.mat(Mk.c(0x161616), .5), Vector3(0, cos(a) * .0172, sin(a) * .0172), wh)
			rib.rotation.x = -a
		wheels.append(wh)
		Mk.add_pick_later(holder, "fax:wheel:%d" % i, .006)
	# touches de son (type clavier de télécopieur)
	for i in 5:
		var k := Node3D.new()
		k.position = Vector3(_key_x(i), BASE_H + .004, .11)
		add_child(k)
		Mk.mi(Mk.rounded_box(Vector3(.03, .01, .024), .003, Mk.mat(Mk.c(0xece4d2), .4, 0.0, {"clearcoat": .4}), 2), null, Vector3(0, .005, 0), k)
		var lm := Mk.mat(Mk.c(0x300805), .4, 0.0, {"emission": Mk.c(0xff3020), "energy": .05})
		key_leds.append(lm)
		Mk.mi(Mk.cyl(.0022, .0022, .003, 10), lm, Vector3(0, .0005, -.018), k)
		keys.append(k)
		Mk.add_pick_later(k, "fax:sound:%d" % i, .003)
	# LECTURE et ENVOI
	var bl := _button(Vector3(.075, BASE_H + .004, .143), Vector3(.05, .012, .026), Mk.c(0x3a3632), "fax:play")
	play_led = Mk.mat(Mk.c(0x082008), .4, 0.0, {"emission": Mk.c(0x40ff60), "energy": .05})
	Mk.mi(Mk.cyl(.0025, .0025, .003, 10), play_led, Vector3(-.032, .001, 0), bl)
	var bs := _button(Vector3(.175, BASE_H + .004, .143), Vector3(.07, .014, .028), Mk.c(0x3a7a4a), "fax:send")
	send_led = Mk.mat(Mk.c(0x201008), .4, 0.0, {"emission": Mk.c(0xffa020), "energy": .05})
	Mk.mi(Mk.cyl(.0025, .0025, .003, 10), send_led, Vector3(-.042, .001, 0), bs)
	_refresh_keys()


func _button(at: Vector3, size: Vector3, col: Color, action: String) -> Node3D:
	var b := Node3D.new()
	b.position = at
	add_child(b)
	Mk.mi(Mk.rounded_box(size + Vector3(.006, -.006, .006), .003, Mk.mat(Mk.c(0x0a0a0a), .6), 1), null, Vector3(0, .001, 0), b)
	var cap := Node3D.new()
	cap.name = "Cap"
	b.add_child(cap)
	Mk.mi(Mk.rounded_box(size, .004, Mk.mat(col, .35, 0.0, {"clearcoat": .5}), 2), null, Vector3(0, size.y / 2, 0), cap)
	Mk.add_pick_later(b, action, .003)
	return b


func _wheel_x(i: int) -> float:
	return .04 + i * .053


func _key_x(i: int) -> float:
	return .042 + i * .039


# ---------------------------------------------------------------- feuille
## Trajet de la feuille : sort de la fente, monte, s'enroule vers l'avant et retombe sur le bureau.
func _build_sheet() -> void:
	var pts := [Vector3(0, BASE_H, -D / 2 + .158), Vector3(0, BASE_H + .035, -D / 2 + .165), Vector3(0, BASE_H + .065, -D / 2 + .19),
		Vector3(0, BASE_H + .08, -D / 2 + .24), Vector3(0, BASE_H + .075, -D / 2 + .3), Vector3(0, BASE_H + .05, D / 2 - .01),
		Vector3(0, BASE_H + .005, D / 2 + .025), Vector3(0, .03, D / 2 + .05), Vector3(0, .004, D / 2 + .085), Vector3(0, .002, D / 2 + .2),
		Vector3(0, .002, D / 2 + .4)]
	var curve := Curve3D.new()
	for p in pts:
		curve.add_point(p)
	for i in range(1, curve.point_count - 1):
		var dir: Vector3 = (pts[i + 1] - pts[i - 1]) * .25
		curve.set_point_in(i, -dir)
		curve.set_point_out(i, dir)
	curve.bake_interval = .004
	_path = curve.get_baked_points()
	_path_len = PackedFloat32Array([0.0])
	for i in range(1, _path.size()):
		_path_len.append(_path_len[i - 1] + _path[i].distance_to(_path[i - 1]))
	sheet_canvas = Tex.live(512, 768, func(ci, w, h): _draw_sheet(ci, w, h))
	_sheet_mat = ShaderMaterial.new()
	_sheet_mat.shader = load("res://core/shaders/paper.gdshader")
	_sheet_mat.set_shader_parameter("paper_tex", sheet_canvas.texture)
	sheet = MeshInstance3D.new()
	sheet.name = "Sheet"
	sheet.material_override = _sheet_mat
	sheet.position.x = SHEET_X
	add_child(sheet)
	# zone cliquable de la feuille (sur l'avant de la machine et le bureau)
	var hit := Node3D.new()
	hit.position = Vector3(SHEET_X, BASE_H + .03, D / 2 - .02)
	add_child(hit)
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	body.set_meta("action", "fax:sheet")
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(SHEET_W, .12, .26)
	cs.shape = bs
	body.add_child(cs)
	hit.add_child(body)
	_sheet_hit = body


var _sheet_hit: StaticBody3D


func _point_at(s: float) -> Vector3:
	var i := _path_len.bsearch(s)
	i = clampi(i, 1, _path.size() - 1)
	var a := _path_len[i - 1]
	var b := _path_len[i]
	return _path[i - 1].lerp(_path[i], clampf((s - a) / maxf(b - a, 1e-6), 0, 1))


## Reconstruit le ruban de papier visible (longueur `printed`), légèrement ondulé.
func _rebuild_sheet() -> void:
	if printed < .004:
		sheet.mesh = null
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := maxi(2, int(printed / .006))
	for i in n + 1:
		var s := printed * i / n
		var p := _point_at(s)
		var wob := sin(s * 40.0) * .0015
		var v := 1.0 - (printed - s) / PAGE_L  # haut de page côté fente : la grille se lit depuis le fauteuil
		st.set_uv(Vector2(0, v))
		st.add_vertex(p + Vector3(-SHEET_W / 2, wob, 0))
		st.set_uv(Vector2(1, v))
		st.add_vertex(p + Vector3(SHEET_W / 2, -wob, 0))
	for i in n:
		var a := i * 2
		st.add_index(a)
		st.add_index(a + 1)
		st.add_index(a + 2)
		st.add_index(a + 1)
		st.add_index(a + 3)
		st.add_index(a + 2)
	st.generate_normals()
	sheet.mesh = st.commit()


## La feuille imprimée : en-tête, réglages, grille en cases (2 à 8 mesures), mode d'emploi en pied.
func _draw_sheet(ci: CanvasItem, w: float, h: float) -> void:
	ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xf3efe2))
	var r := Tex.rng(seed)
	for i in 900:  # grain du papier thermique
		ci.draw_rect(Rect2(r.randf() * w, r.randf() * h, 2, 2), Color(.5, .45, .35, .05))
	var ink := Color(.1, .1, .12, .9)
	var faint := Color(.1, .1, .12, .45)
	Tex.silk(ci, "REEL'S TOOLS  ·  FAX  RT-FX2", 24, 46, 24, ink, "left", 600, "mono")
	Tex.silk(ci, Time.get_datetime_string_from_system().replace("T", "  ").left(17), w - 24, 46, 18, faint, "right", 500, "mono")
	ci.draw_line(Vector2(24, 62), Vector2(w - 24, 62), faint, 2.0)
	# réglages + grille dans la partie bien visible de la feuille (la retombée devant la machine)
	var head := "%s   %s   %d BPM   %d MES." % [ChordEngine.STYLES[style], ChordEngine.key_name(key), bpm, bars]
	Tex.silk(ci, "SON D'ÉCOUTE : " + FaxSynth.SOUNDS[sound], 24, h * .3, 17, faint, "left", 500, "mono")
	Tex.silk(ci, head, 24, h * .36, 26, ink, "left", 700, "mono")
	var cols := 4
	var rows := (bars - 1) / cols + 1
	var cw := (w - 48) / cols
	var gap := 14.0
	var ch := minf(150.0, (h * .82 - h * .4 - gap * (rows - 1)) / rows)
	var y0 := h * .4
	var by_bar := {}
	for c in prog:
		var b: int = c.beat / 4
		by_bar[b] = by_bar.get(b, []) + [c.name]
	for b in bars:
		var row := b / cols
		var col := b % cols
		var x := 24 + col * cw
		var y := y0 + row * (ch + gap)
		ci.draw_rect(Rect2(x, y, cw - 6, ch), ink, false, 3.0)
		Tex.silk(ci, str(b + 1), x + 8, y + 20, 15, faint, "left", 500, "mono")
		var names: Array = by_bar.get(b, ["%"])
		if names.size() == 1:
			var nm := String(names[0])
			Tex.silk(ci, nm, x + (cw - 6) / 2, y + ch * .64, 38 if nm.length() < 5 else (30 if nm.length() < 7 else 24), ink, "center", 700, "mono")
		else:
			Tex.silk(ci, names[0], x + (cw - 6) / 2, y + ch * .42, 24, ink, "center", 700, "mono")
			ci.draw_line(Vector2(x + 12, y + ch - 12), Vector2(x + cw - 18, y + 12), faint, 1.5)
			Tex.silk(ci, names[1], x + (cw - 6) / 2, y + ch * .86, 24, ink, "center", 700, "mono")
	ci.draw_line(Vector2(24, h - 92), Vector2(w - 24, h - 92), faint, 1.5)
	Tex.silk(ci, "TIRER LA FEUILLE  →  EXPORT MIDI", 24, h - 60, 17, faint, "left", 500, "mono")
	Tex.silk(ci, "LA FROISSER  →  AUTRE GRILLE", 24, h - 32, 17, faint, "left", 500, "mono")


# ---------------------------------------------------------------- textes
func _wheel_text(i: int) -> String:
	match i:
		0:
			return ChordEngine.STYLES[style]
		1:
			return str(bpm)
		2:
			return ChordEngine.key_name(key)
		_:
			return str(bars)


func _led_text() -> String:
	if playing and _last_chord >= 0 and _last_chord < prog.size():
		return "▶ %-7s %d/%d" % [prog[_last_chord].name, _last_chord + 1, prog.size()]
	if printing:
		return "IMPRESSION…"
	if _render_job >= 0:
		return "PRÉPARATION…"
	return "%s %s %d" % [ChordEngine.STYLES[style], ChordEngine.key_name(key), bpm]


# ---------------------------------------------------------------- logique
## Nouvelle grille avec les réglages actuels. print = l'imprimer aussitôt.
func _regen(do_print := true) -> void:
	prog = ChordEngine.generate(ChordEngine.STYLES[style], key, bars, seed)
	Store.set_v("fax_seed", seed)
	_stream_dirty = true
	sheet_canvas.redraw()
	led.redraw()
	if do_print:
		_start_print()


func _start_print() -> void:
	_stop()
	_anim = ""
	sheet.visible = true
	sheet.position = Vector3(SHEET_X, 0, 0)
	sheet.rotation = Vector3.ZERO
	sheet.scale = Vector3.ONE
	printed = 0.0
	printing = true
	sheet_on = true
	sheet_canvas.redraw()
	led.redraw()
	_prepare_audio()


func _prepare_audio() -> void:
	if not _stream_dirty or _render_job >= 0:
		return
	_stream_dirty = false
	var p := prog.duplicate(true)
	var b := float(bpm)
	var s := sound
	_render_job = WorkerThreadPool.add_task(func():
		var w := FaxSynth.render(p, b, s)
		call_deferred("_audio_ready", w))


func _audio_ready(w: AudioStreamWAV) -> void:
	if _render_job >= 0:
		WorkerThreadPool.wait_for_task_completion(_render_job)
	_render_job = -1
	if _stream_dirty:  # les réglages ont changé pendant le rendu : on recommence
		_prepare_audio()
		return
	var was := playing
	player.stream = w
	if was:
		player.play()
	led.redraw()


func toggle_play() -> void:
	if playing:
		_stop()
		return
	if _stream_dirty or player.stream == null:
		_prepare_audio()
	playing = true
	if player.stream and _render_job < 0:
		player.play()
	play_led.emission_energy_multiplier = 1.4
	led.redraw()


func _stop() -> void:
	playing = false
	player.stop()
	play_led.emission_energy_multiplier = .05
	_last_chord = -1
	led.redraw()


func _changed() -> void:
	Store.set_v("fax_style", style)
	Store.set_v("fax_bpm", bpm)
	Store.set_v("fax_key", key)
	Store.set_v("fax_bars", bars)
	for c in wheel_canvas:
		c.redraw()
	led.redraw()


func _turn(i: int, steps: int) -> void:
	match i:
		0:
			style = posmod(style + steps, ChordEngine.STYLES.size())
		1:
			bpm = clampi(bpm + steps, 50, 200)
		2:
			key = posmod(key + steps, ChordEngine.key_count())
		3:
			var opts := [2, 4, 8]
			bars = opts[posmod(opts.find(bars) + steps, 3)]
	wheels[i].rotation.x -= steps * TAU / 24
	_changed()
	# BPM : la grille ne change pas, seul le tempo d'écoute ; le reste = nouvelle grille au prochain ENVOI
	_stream_dirty = true
	if i != 1:
		prog = ChordEngine.generate(ChordEngine.STYLES[style], key, bars, seed)
	if playing:
		_prepare_audio()


func _set_sound(i: int) -> void:
	sound = i
	Store.set_v("fax_sound", sound)
	_refresh_keys()
	_stream_dirty = true
	if playing:
		_prepare_audio()
	sheet_canvas.redraw()


func _refresh_keys() -> void:
	for i in keys.size():
		keys[i].position.y = BASE_H + (.0005 if i == sound else .004)
		key_leds[i].emission_energy_multiplier = 1.5 if i == sound else .05


func crumple() -> void:
	if not sheet_on:
		return
	_stop()
	_anim = "crumple"
	_anim_t = 0.0
	printing = false
	Toast.say("Froissée — nouvelle grille")


func tear() -> void:
	if not sheet_on or printing:
		return
	_anim = "tear"
	_anim_t = 0.0
	Toast.say("Feuille détachée — choisis où enregistrer le MIDI")
	dialog.current_file = _file_name()
	dialog.popup_centered()


func _file_name() -> String:
	return "REEL Fax - %s %s %d BPM - %s.mid" % [ChordEngine.STYLES[style].replace("&", "n"), ChordEngine.key_name(key), bpm, ChordEngine.summary(prog).replace(" | ", " ").left(40)]


func _export_to(path: String) -> void:
	if not path.to_lower().ends_with(".mid"):
		path += ".mid"
	var ok := MidiWriter.save(path, prog, bpm, "REEL Fax %s %s" % [ChordEngine.STYLES[style], ChordEngine.key_name(key)])
	Toast.say(("MIDI enregistré : " + path.get_file()) if ok else "Impossible d'écrire le fichier")


## Boulette de papier qui tombe du bureau (on en garde 6 par terre).
func _drop_ball() -> void:
	var b := Node3D.new()
	var mesh := Mk.ellipsoid(.032, .028, .03, 14, 8)
	var m := Mk.mat(Mk.c(0xeeeadc), .9, 0.0, {"normal": Mk.noise_tex(1.6, 128, 3), "normal_scale": 1.6})
	Mk.mi(mesh, m, Vector3.ZERO, b)
	get_parent().add_child(b)
	b.global_position = to_global(Vector3(SHEET_X, .08, D / 2))
	var land := to_global(Vector3(SHEET_X + randf_range(-.15, .15), 0, D / 2 + randf_range(.25, .5)))
	land.y = .028
	var tw := create_tween()
	tw.tween_property(b, "global_position", b.global_position + (land - b.global_position) * .5 + Vector3(0, .12, 0), .25).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "global_position", land, .35).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(b, "rotation", Vector3(randf() * 6, randf() * 6, randf() * 6), .6)
	balls.append(b)
	if balls.size() > 6:
		balls.pop_front().queue_free()


# ---------------------------------------------------------------- interface module
func on_action(a: String) -> void:
	if a == "send":
		_regen(true)
		_press_cap("send")
	elif a == "play":
		toggle_play()
	elif a.begins_with("sound:"):
		_set_sound(int(a.substr(6)))
	elif a.begins_with("wheel:"):
		_turn(int(a.substr(6)), 1)
	elif a == "sheet":
		pass


func _press_cap(_n: String) -> void:
	send_led.emission_energy_multiplier = 2.0


func on_press(a: String) -> void:
	_drag_kind = a
	_drag_acc = Vector2.ZERO


func on_drag_start(a: String) -> bool:
	return a == "sheet" or a.begins_with("wheel:")


func on_drag(rel: Vector2, fine: bool) -> void:
	_drag_acc += rel
	if _drag_kind.begins_with("wheel:"):
		var i := int(_drag_kind.substr(6))
		var step := 6.0 if (fine or i != 1) else 3.0
		if i != 1:
			step = 18.0
		while _drag_acc.y <= -step:
			_drag_acc.y += step
			_turn(i, 1)
		while _drag_acc.y >= step:
			_drag_acc.y -= step
			_turn(i, -1)


func on_drop(_target: String) -> void:
	if _drag_kind == "sheet":
		if _drag_acc.y < -40:
			tear()
		elif _drag_acc.y > 40:
			crumple()
	elif _drag_kind.begins_with("wheel:") and _drag_acc.length() < 4.0:
		_turn(int(_drag_kind.substr(6)), 1)
	_drag_kind = ""


func on_wheel(a: String, dir: float, fine: bool) -> void:
	if a.begins_with("wheel:"):
		var i := int(a.substr(6))
		_turn(i, int(dir) * (1 if fine or i != 1 else 2))


func on_key(e: InputEventKey) -> bool:
	match e.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			on_action("send")
		KEY_SPACE:
			toggle_play()
		KEY_N:
			if sheet_on:
				crumple()
			else:
				_regen(true)
		KEY_E:
			tear()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			_set_sound(e.keycode - KEY_1)
		_:
			return false
	return true


func animate(t: float, dt: float, reduced: bool) -> void:
	send_led.emission_energy_multiplier = move_toward(send_led.emission_energy_multiplier, 1.2 if printing else .05, dt * 4.0)
	if printing:
		printed = minf(PAGE_L, printed + dt * (.09 if not reduced else 1.0))
		roll.rotation.x -= dt * 2.8
		_rebuild_sheet()
		if printed >= PAGE_L:
			printing = false
			led.redraw()
	if _anim == "crumple":
		_anim_t += dt
		var k := minf(1.0, _anim_t / .35)
		sheet.scale = Vector3(1.0 - .85 * k, 1.0 - .6 * k, 1.0 - .85 * k)
		sheet.position = Vector3(SHEET_X, .05 * k, D / 2 * .6 * k)
		if k >= 1.0:
			sheet.visible = false
			sheet_on = false
			_anim = ""
			_drop_ball()
			seed += 1
			_regen(true)
	elif _anim == "tear":
		_anim_t += dt
		var k := minf(1.0, _anim_t / .5)
		sheet.position = Vector3(SHEET_X, .25 * k, .1 * k)
		sheet.rotation.x = -.6 * k
		if k >= 1.0:
			sheet.visible = false
			sheet_on = false
			_anim = ""
			printed = 0.0
	# accord en cours pendant la lecture
	if playing and player.playing and not prog.is_empty():
		var beat := player.get_playback_position() * bpm / 60.0
		var idx := 0
		for i in prog.size():
			if beat >= prog[i].beat:
				idx = i
		if idx != _last_chord:
			_last_chord = idx
			led.redraw()
