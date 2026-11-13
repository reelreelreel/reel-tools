class_name Beats7080
extends Node3D
## Module Boîtes à rythmes du studio 70/80 : deux boîtes assorties empilées (bois + alu).
##   · en haut, la BATTERIE : 16 pas lumineux, 5 instruments (KICK, CLAP, HAT, OPEN, PERC), potards
##     STYLE / BPM / SWING, GÉNÉRER, SYNC FAX (se caler sur la grille et le tempo du fax), EXPORT MIDI,
##     LECTURE. Molette sur un pas de hi-hat = roulement (x2, x3, x4).
##   · en bas, la 808 : 16 pas + petit clavier d'une octave (clic sur un pas = le choisir / l'allumer,
##     clic sur une touche = sa note). La 808 suit la fondamentale des accords du fax.
## Clavier : Espace = lecture, G = générer, S = sync fax, E = export, 1–5 = instrument.
##
## Repère local : façade vers +Z (vers le fauteuil), posé sur y = 0. Corps entier : "m:beats".

const W := .44
const D := .36
const LOW_H := .05            # boîte 808
const TOP_D := .2             # boîte batterie, posée sur l'arrière de la 808
const TOP_H0 := .045          # hauteur avant de la boîte batterie
const TOP_H1 := .09           # hauteur arrière
const STEP_COLS := [0xc8382a, 0xe0782a, 0xe8c040, 0xece4d2]  # 4 groupes de 4 pas, façon boîte des années 80

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
var dpanel: Node3D
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
	_build_low()
	_build_top()
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
func _x_step(i: int) -> float:
	return -.18 + i * .024


func _build_low() -> void:
	var walnut := Mk.pbr("fine_grained_wood", .5, {"tint": Mk.c(0xd8c0a8), "rough": .8, "clearcoat": .3})
	var dark := Mk.mat(Mk.c(0x141414), .5)
	# caisse + joues en bois
	Mk.mi(Mk.rounded_box(Vector3(W - .04, LOW_H - .004, D), .004, dark, 2), null, Vector3(0, (LOW_H - .004) / 2, 0), self)
	for sx in [-1, 1]:
		Mk.mi(Mk.rounded_box(Vector3(.02, LOW_H + .004, D), .004, walnut, 2), null, Vector3(sx * (W / 2 - .01), (LOW_H + .004) / 2, 0), self)
	var front_d := D - TOP_D
	var pz := -D / 2 + TOP_D + front_d / 2
	var panel := Mk.panel(W - .04, front_d, func(ci, P, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xb8b6b0))
		Tex.brushed(ci, w, h, 808, .06)
		var ink := Color(.08, .08, .09, .9)
		var Zf := func(z: float) -> float: return (z - (pz - front_d / 2)) / front_d * h
		var Xf := func(x: float) -> float: return P.call(x + (W - .04) / 2)
		Tex.silk(ci, "RT-808  BASSE", Xf.call(.1), Zf.call(pz + .045), 30, ink, "left", 700)
		Tex.silk(ci, "CLIC SUR UN PAS : LE CHOISIR · TOUCHE : SA NOTE", Xf.call(.1), Zf.call(pz + .065), 15, Color(.08, .08, .09, .6), "left", 500)
		for i in 16:
			Tex.silk(ci, str(i + 1), Xf.call(_x_step(i)), Zf.call(pz - .052), 15, Color(.08, .08, .09, .7), "center", 600)
		for g in 4:
			var x0: float = Xf.call(_x_step(g * 4) - .011)
			var x1: float = Xf.call(_x_step(g * 4 + 3) + .011)
			ci.draw_rect(Rect2(x0, Zf.call(pz - .046), x1 - x0, 3), Mk.c(STEP_COLS[g]))
		Tex.grime(ci, w, h, 809, 1.0), {"res": 1536, "rough": .45})
	panel.position = Vector3(0, LOW_H, pz)
	add_child(panel)
	# 16 pas de la 808
	for i in 16:
		var cap := _step_button(Vector3(_x_step(i), LOW_H, pz - .025), STEP_COLS[i / 4], "beats:bstep:%d" % i, b_leds)
		b_caps.append(cap)
	# clavier d'une octave (C à C)
	var white := [0, 2, 4, 5, 7, 9, 11, 12]
	var kw := .026
	var kx0 := -.19
	var kz := pz + .045
	for j in white.size():
		_key(white[j], Vector3(kx0 + j * kw + kw / 2, LOW_H, kz), Vector3(kw - .002, .008, .05), Mk.c(0xf2eee4))
	var black := {1: 0, 3: 1, 6: 3, 8: 4, 10: 5}
	for semi in black:
		var j: int = black[semi]
		_key(semi, Vector3(kx0 + (j + 1) * kw, LOW_H + .006, kz - .01), Vector3(.015, .01, .03), Mk.c(0x161616))


func _key(semi: int, at: Vector3, size: Vector3, col: Color) -> void:
	var k := Node3D.new()
	k.position = at
	add_child(k)
	var m := Mk.mat(col, .4, 0.0, {"clearcoat": .4, "emission": Mk.c(0xff3020), "energy": 0.0})
	Mk.mi(Mk.rounded_box(size, .002, m, 1), null, Vector3(0, size.y / 2, 0), k)
	k.set_meta("semi", semi)
	keys.append(k)
	key_mats.append(m)
	Mk.add_pick_later(k, "beats:key:%d" % semi, .002)


## Bouton de pas : capuchon coloré + LED rouge juste derrière.
func _step_button(at: Vector3, col: int, action: String, leds: Array[StandardMaterial3D], parent: Node3D = null) -> Node3D:
	var p: Node3D = self if parent == null else parent
	var b := Node3D.new()
	b.position = at
	p.add_child(b)
	Mk.mi(Mk.rounded_box(Vector3(.02, .004, .02), .002, Mk.mat(Mk.c(0x0a0a0a), .6), 1), null, Vector3(0, .001, 0), b)
	var cap := Node3D.new()
	b.add_child(cap)
	Mk.mi(Mk.rounded_box(Vector3(.017, .008, .017), .003, Mk.mat(Mk.c(col), .4, 0.0, {"clearcoat": .4}), 2), null, Vector3(0, .004, 0), cap)
	var lm := Mk.mat(Mk.c(0x300805), .4, 0.0, {"emission": Mk.c(0xff2a18), "energy": .05})
	Mk.mi(Mk.cyl(.0025, .0025, .003, 10), lm, Vector3(0, .0015, -.016), b)
	leds.append(lm)
	Mk.add_pick_later(b, action, .002)
	return cap


func _build_top() -> void:
	var walnut := Mk.pbr("fine_grained_wood", .5, {"tint": Mk.c(0xd8c0a8), "rough": .8, "clearcoat": .3})
	var dark := Mk.mat(Mk.c(0x141414), .5)
	var z0 := -D / 2
	var zc := z0 + TOP_D / 2
	# caisse en biseau (profil extrudé le long de x) + joues en bois
	var prof := PackedVector2Array([Vector2(-TOP_D / 2, 0), Vector2(TOP_D / 2, 0), Vector2(TOP_D / 2, TOP_H0), Vector2(-TOP_D / 2, TOP_H1)])
	var body := Mk.mi(Mk.prism(prof, W - .04), dark, Vector3((W - .04) / 2, LOW_H, zc), self)
	body.rotation.y = -PI / 2
	for sx in [-1, 1]:
		var ch := Mk.mi(Mk.prism(PackedVector2Array([Vector2(-TOP_D / 2, 0), Vector2(TOP_D / 2, 0), Vector2(TOP_D / 2, TOP_H0 + .006), Vector2(-TOP_D / 2, TOP_H1 + .006)]), .02), walnut, Vector3(sx * (W / 2 - .01) + .01, LOW_H, zc), self)
		ch.rotation.y = -PI / 2
	# panneau incliné
	var slope := atan((TOP_H1 - TOP_H0) / TOP_D)
	dpanel = Node3D.new()
	dpanel.position = Vector3(0, LOW_H + (TOP_H0 + TOP_H1) / 2 + .001, zc)
	dpanel.rotation.x = slope
	add_child(dpanel)
	var pd := TOP_D / cos(slope)
	var panel := Mk.panel(W - .04, pd, func(ci, P, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xc4c2bc))
		Tex.brushed(ci, w, h, 707, .06)
		var ink := Color(.08, .08, .09, .9)
		var Zf := func(z: float) -> float: return (z + pd / 2) / pd * h
		var Xf := func(x: float) -> float: return P.call(x + (W - .04) / 2)
		Tex.silk(ci, "RT-707  BATTERIE", Xf.call(-.19), Zf.call(-.083), 28, ink, "left", 700)
		for i in BeatEngine.INSTR.size():
			Tex.silk(ci, BeatEngine.INSTR[i], Xf.call(_x_instr(i)), Zf.call(-.002), 15, ink, "center", 600)
		var lab := {"GÉNÉRER": .015, "SYNC FAX": .07, "EXPORT": .125, "LECTURE": .178}
		for k in lab:
			Tex.silk(ci, k, Xf.call(lab[k]), Zf.call(-.002), 14, ink, "center", 600)
		var kl := {"STYLE": .03, "BPM": .095, "SWING": .16}
		for k in kl:
			Tex.silk(ci, k, Xf.call(kl[k]), Zf.call(-.04), 14, ink, "center", 600)
		for i in 16:
			Tex.silk(ci, str(i + 1), Xf.call(_x_step(i)), Zf.call(.087), 14, Color(.08, .08, .09, .7), "center", 600)
		for g in 4:
			var x0: float = Xf.call(_x_step(g * 4) - .011)
			var x1: float = Xf.call(_x_step(g * 4 + 3) + .011)
			ci.draw_rect(Rect2(x0, Zf.call(.078), x1 - x0, 3), Mk.c(STEP_COLS[g]))
		Tex.silk(ci, "MOLETTE SUR UN PAS DE HI-HAT = ROULEMENT", Xf.call(.19), Zf.call(.097), 12, Color(.08, .08, .09, .55), "right", 500)
		Tex.grime(ci, w, h, 708, 1.0), {"res": 1536, "rough": .45})
	dpanel.add_child(panel)
	# afficheur LED rouge (2 lignes)
	led = Tex.live(512, 128, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x0a0202))
		var lines := _led_lines()
		Tex.silk(ci, lines[0], 14, h * .42, 40, Mk.c(0xff3a22), "left", 600, "mono")
		Tex.silk(ci, lines[1], 14, h * .86, 30, Mk.c(0xff3a22).darkened(.25), "left", 500, "mono"))
	var win := Mk.face_window(Mk.glow(Color.WHITE, 1.4, led.texture), .15, .036, Mk.c(0x2a0606))
	win.position = Vector3(-.1, .003, -.05)
	win.rotation.x = -PI / 2
	dpanel.add_child(win)
	# potards STYLE / BPM / SWING
	for k in [["style", .03], ["bpm", .095], ["swing", .16]]:
		var kn := Mk.knob(.011, .014)
		kn.position = Vector3(k[1], .002, -.058)
		dpanel.add_child(kn)
		knobs[k[0]] = kn
		Mk.add_pick_later(kn, "beats:knob:" + k[0], .003)
	# sélection d'instrument + boutons de fonction
	for i in BeatEngine.INSTR.size():
		var b := _small_button(Vector3(_x_instr(i), .002, -.018), Mk.c(0x3a3632), "beats:instr:%d" % i)
		var lm := Mk.mat(Mk.c(0x300805), .4, 0.0, {"emission": Mk.c(0xff2a18), "energy": .05})
		Mk.mi(Mk.cyl(.0022, .0022, .003, 10), lm, Vector3(.012, .002, 0), b)
		i_leds.append(lm)
	_small_button(Vector3(.015, .002, -.018), Mk.c(0x8a7a5a), "beats:gen")
	var bs := _small_button(Vector3(.07, .002, -.018), Mk.c(0x3a3632), "beats:sync")
	sync_led = Mk.mat(Mk.c(0x082008), .4, 0.0, {"emission": Mk.c(0x40ff60), "energy": .05})
	Mk.mi(Mk.cyl(.0022, .0022, .003, 10), sync_led, Vector3(.013, .002, 0), bs)
	_small_button(Vector3(.125, .002, -.018), Mk.c(0x3a3632), "beats:export")
	var bp := _small_button(Vector3(.178, .002, -.018), Mk.c(0x3a7a4a), "beats:play")
	play_led = Mk.mat(Mk.c(0x082008), .4, 0.0, {"emission": Mk.c(0x40ff60), "energy": .05})
	Mk.mi(Mk.cyl(.0022, .0022, .003, 10), play_led, Vector3(.013, .002, 0), bp)
	# 16 pas de la batterie
	for i in 16:
		var cap := _step_button(Vector3(_x_step(i), .002, .055), STEP_COLS[i / 4], "beats:dstep:%d" % i, d_leds, dpanel)
		d_caps.append(cap)
	# câble de synchro vers la 808 + secteur
	var cable := Mk.mat(Mk.c(0x161616), .6)
	Mk.mi(Mk.tube([Vector3(.16, LOW_H + .04, -D / 2), Vector3(.18, LOW_H + .01, -D / 2 - .03), Vector3(.17, .02, -D / 2 - .02), Vector3(.15, .025, -D / 2)], .003, 16, 6), cable, Vector3.ZERO, self)


func _x_instr(i: int) -> float:
	return -.185 + i * .034


func _small_button(at: Vector3, col: Color, action: String) -> Node3D:
	var b := Node3D.new()
	b.position = at
	dpanel.add_child(b)
	Mk.mi(Mk.rounded_box(Vector3(.024, .004, .016), .002, Mk.mat(Mk.c(0x0a0a0a), .6), 1), null, Vector3(0, .001, 0), b)
	Mk.mi(Mk.rounded_box(Vector3(.02, .007, .012), .003, Mk.mat(col, .35, 0.0, {"clearcoat": .5}), 2), null, Vector3(0, .0045, 0), b)
	Mk.add_pick_later(b, action, .002)
	return b


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
		d_caps[i].position.y = -.002 if v > 0 else 0.0
		b_leds[i].emission_energy_multiplier = (1.6 if bass[i] >= 0 else .05) + (2.0 if i == cur_step else 0.0) + (.8 if i == bass_sel else 0.0)
		b_caps[i].position.y = -.002 if bass[i] >= 0 else 0.0
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
