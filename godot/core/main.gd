extends Node3D
## REEL'S TOOLS — point d'entrée : monte le studio, la caméra, et gère clic / glisser / clavier.
##
## Modules : clic sur une machine = zoom ; ses commandes ont des actions « module:commande ».
## Raccourcis : Échap = plan large · ←/→ ou PageUp/PageDown = plan précédent/suivant · 1–6 = machines
## Cmd+K ou / = rechercher · Cmd+, = réglages · M = mode mini
## Tempo : Espace = tap, ↑/↓ = BPM (Maj = 0,1), N = note, C = copier les ms
## F ou Cmd+F = plein écran · T = garder la fenêtre au premier plan (à côté du DAW)
##
## Options de lancement (après « -- ») : --shot=tempo  --screenshot=chemin.png (ou dossier/ + --shots=a,b)  --frames=N

var engine: TempoEngine
var studio: Studio7080
var cam: Camera3D
var attrs: CameraAttributesPractical
var overlay: Overlay
var ui: AppUI
var hover_module := ""  # machine sous la souris (pour son étiquette)
const MAX_3D_HEIGHT := 1080.0  # au-delà, la 3D est rendue en 1080 puis agrandie (FSR)
var current := "overview"
var cam_pos := Vector3.ZERO
var cam_look := Vector3.ZERO
var pointer := Vector2.ZERO
var par := Vector2.ZERO
var swipe = null  # {pos, t, a, turned}
var yaw := 0.0       # cap visé de la vue 360° (le studio suit en douceur)
var pitch := -.12
var drag = null   # {mod}
var t := 0.0
var reduced := false
var ready_done := false
var _args := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	DisplayServer.window_set_title("REEL'S TOOLS")
	if _args.has("screenshot") or _args.has("selftest") or _args.has("perf"):
		# captures de dev (rendu logiciel, mémoire limitée) : ombres et anticrénelage allégés
		get_viewport().positional_shadow_atlas_size = (1024 if OS.has_environment("REEL_TINY") else 2048) if OS.has_environment("REEL_LOWMEM") else 4096
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	DisplayServer.window_set_min_size(Vector2i(480, 320))
	engine = TempoEngine.new()
	studio = Studio7080.new(engine)
	add_child(studio)
	if _args.has("tod"):  # dev : heure forcée (captures)
		studio.tod_override = float(_args.tod)
		studio._tod_shown = -1.0
	if _args.has("splitspdf"):
		studio.splits.demo()
		studio.splits.write_pdf(_args.splitspdf)
		get_tree().quit()
		return
	if _args.has("probe"):
		# dev : maillages dont la boîte touche une zone (x0,x1,y0,y1,z0,z1)
		var v: PackedFloat64Array = PackedFloat64Array(Array(_args.probe.split(",")).map(func(t): return float(t)))
		var zone := AABB(Vector3(v[0], v[2], v[4]), Vector3(v[1] - v[0], v[3] - v[2], v[5] - v[4]))
		for m in studio.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi.is_visible_in_tree() and mi.mesh:
				var bb: AABB = mi.global_transform * mi.get_aabb()
				if bb.intersects(zone):
					print("probe ", mi.get_path(), " ", bb)
		get_tree().quit()
		return
	if _args.has("overlaps"):
		_overlaps()
		get_tree().quit()
		return
	cam = Camera3D.new()
	cam.cull_mask = 0xFFFFF & ~(1 << 9)  # couche 10 = ce que l'on « porte » (le fauteuil où l'on est assis)
	cam.near = 0.02
	cam.far = 30.0
	attrs = CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = Studio7080.LOOK_FX
	attrs.dof_blur_near_enabled = Studio7080.LOOK_FX
	attrs.auto_exposure_enabled = false
	cam.attributes = attrs
	add_child(cam)
	cam.current = true
	overlay = Overlay.new()
	add_child(overlay)
	ui = AppUI.new(self)
	add_child(ui)
	Toast.ui = ui
	current = _args.get("shot", Store.get_v("shot", "overview"))
	if not studio.order.has(current):
		current = "overview"
	yaw = float(_args.get("yaw", Store.get_v("yaw", 0.0)))
	if _args.has("yaw"):
		yaw = deg_to_rad(float(_args.yaw))
	pitch = deg_to_rad(float(_args.get("pitch", "-7")))
	studio.look_yaw = yaw
	studio.look_pitch = pitch
	get_window().files_dropped.connect(_on_files_dropped)
	await Tex.flush()
	if _args.has("sample") and studio.modules.has("tuner"):
		studio.modules.tuner.load_sample(_args.sample)
	if _args.has("track") and studio.modules.has("analyse"):
		studio.modules.analyse.load_track(_args.track)
		studio.modules.analyse.wait_done()
	_update_fov()
	ui.route_audio(studio)
	ui.on_shot(current)
	var p := studio.shot_pose(current, cam, _aspect())
	cam_pos = p[0]
	cam_look = p[1]
	ready_done = true
	overlay.boot_done()
	if _args.has("selftest"):
		_selftest()
	if _args.has("perf"):
		_perf()
	elif _args.has("screenshot"):
		if _args.has("faxprint"):
			studio.fax.on_action("send")
			studio.fax.printed = Fax7080.PAGE_L - .0005
		if _args.get("ui", "") == "settings":
			ui.toggle_settings()
		elif _args.get("ui", "") == "search":
			ui.open_search()
			ui.search_edit.text = "bpm"
			ui._refresh_search()
		elif _args.get("ui", "").begins_with("hover="):
			hover_module = _args.ui.substr(6)
		elif _args.get("ui", "") == "splits_demo":
			studio.splits.demo()
		elif _args.get("ui", "") == "toast":
			Toast.say("Copié : 428,6 ms")
		_screenshot_and_quit()


func _aspect() -> float:
	var s := get_viewport().get_visible_rect().size
	return s.x / maxf(s.y, 1.0)


func _update_fov() -> void:
	studio.setup_camera(cam, _aspect())
	# image 3D plafonnée à 1080 lignes (ex. écran Retina) : nette mais légère ; l'interface reste en pleine définition
	var vp := get_viewport()
	var h := vp.get_visible_rect().size.y
	var sc := clampf(MAX_3D_HEIGHT / maxf(h, 1.0), .5, 1.0)
	if not is_equal_approx(vp.scaling_3d_scale, sc):
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if sc < 1.0 else Viewport.SCALING_3D_MODE_BILINEAR
		vp.fsr_sharpness = .3
		vp.scaling_3d_scale = sc


# ---------------------------------------------------------------- navigation
func go(shot: String) -> void:
	# en revenant à la vue d'ensemble, on regarde la machine qu'on vient de quitter
	if shot != "overview" and studio.modules.has(shot):
		yaw = _unwrap(studio.yaw_to(studio.modules[shot].global_position), yaw)
		Store.set_v("yaw", yaw)
	current = shot
	studio.on_shot(shot, cam, _aspect())
	Store.set_v("shot", shot)
	overlay.hide_hint()
	ui.on_shot(shot)


## Angle équivalent à a, le plus proche de ref (pour tourner par le plus court chemin).
func _unwrap(a: float, ref: float) -> float:
	return ref + wrapf(a - ref, -PI, PI)


func step(dir: int) -> void:
	var i := studio.order.find(current)
	go(studio.order[clampi(i + dir, 0, studio.order.size() - 1)])


func pick(screen_pos: Vector2) -> Dictionary:
	var from := cam.project_ray_origin(screen_pos)
	var to := from + cam.project_ray_normal(screen_pos) * 20.0
	var space := get_world_3d().direct_space_state
	for mask in [2, 1]:
		var q := PhysicsRayQueryParameters3D.create(from, to, mask)
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			return {"action": hit.collider.get_meta("action", ""), "collider": hit.collider}
	return {"action": ""}


# ---------------------------------------------------------------- entrées
func _unhandled_input(e: InputEvent) -> void:
	if not ready_done:
		return
	if e is InputEventMouseMotion:
		var vs := get_viewport().get_visible_rect().size
		pointer = e.position / vs - Vector2(.5, .5)
		if drag != null:
			drag.mod.on_drag(e.relative, e.shift_pressed)
			return
		# vue 360° : glisser dans la vue d'ensemble = tourner la tête
		if swipe != null and current == "overview" and (e.button_mask & MOUSE_BUTTON_MASK_LEFT):
			if swipe.turned or (e.position - swipe.pos).length() > 6.0:
				swipe.turned = true
				var k := deg_to_rad(cam.fov) / get_viewport().get_visible_rect().size.y
				yaw += e.relative.x * k
				pitch = clampf(pitch + e.relative.y * k, -.75, .6)
				return
		var hover: String = pick(e.position).action
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hover != "" else Input.CURSOR_ARROW)
		hover_module = hover.substr(2) if hover.begins_with("m:") else (hover.get_slice(":", 0) if hover.contains(":") else "")
	elif e is InputEventMouseButton:
		_mouse_button(e)
	elif e is InputEventKey and e.pressed:
		_key(e)


## Fichier glissé sur la fenêtre : au module affiché s'il prend des fichiers, sinon court = accordeur
## (sample de 808 / kick), long = analyseur (morceau, prod).
func _on_files_dropped(files: PackedStringArray) -> void:
	if files.is_empty():
		return
	var target := current
	if not (target == "tuner" or target == "analyse"):
		var big := FileAccess.get_file_as_bytes(files[0]).size() > 1500000 if FileAccess.file_exists(files[0]) else false
		target = "analyse" if big else "tuner"
	if studio.modules.has(target):
		studio.modules[target].on_files(files)
		go(target)


## « tempo:knob » -> [module, "knob"] si le module existe, sinon []
func _split(a: String) -> Array:
	var i := a.find(":")
	if i <= 0 or a.begins_with("m:"):
		return []
	var mod := a.substr(0, i)
	return [studio.modules[mod], a.substr(i + 1), mod] if studio.modules.has(mod) else []


func _mouse_button(e: InputEventMouseButton) -> void:
	if e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if e.pressed:
			var sp := _split(pick(e.position).action)
			if not sp.is_empty() and sp[2] == current:
				sp[0].on_wheel(sp[1], 1.0 if e.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0, e.shift_pressed)
		return
	if e.button_index != MOUSE_BUTTON_LEFT:
		return
	if e.pressed:
		var a: String = pick(e.position).action
		swipe = {"pos": e.position, "t": Time.get_ticks_msec(), "a": a, "turned": false}
		var sp := _split(a)
		if not sp.is_empty() and sp[2] == current:
			if sp[0].has_method("on_press"):
				sp[0].on_press(sp[1])
			if sp[0].on_drag_start(sp[1]):
				drag = {"mod": sp[0]}
		return
	var was_drag := drag != null
	if was_drag and drag.mod.has_method("on_drop"):
		drag.mod.on_drop(pick(e.position).action)
	drag = null
	if swipe == null:
		return
	var dpos: Vector2 = e.position - swipe.pos
	var dt: int = Time.get_ticks_msec() - swipe.t
	var a: String = swipe.a
	var turned: bool = swipe.turned
	swipe = null
	if was_drag:
		return
	if turned:
		Store.set_v("yaw", yaw)
		return
	var big := maxf(absf(dpos.x), absf(dpos.y))
	if big > 50 and dt < 700 and current != "overview":
		go("overview")  # balayer en gros plan = revenir dans la pièce
		return
	if big > 12:
		return
	if a.begins_with("deco:"):
		studio.on_deco(a.substr(5))
		return
	var sp := _split(a)
	if not sp.is_empty():
		if sp[2] == current:
			sp[0].on_action(sp[1])
		else:
			go(sp[2])
		return
	if a.begins_with("m:"):
		var m := a.substr(2)
		if current != m and studio.order.has(m):
			go(m)
		return
	if a == "" and current != "overview":
		go("overview")


func _key(e: InputEventKey) -> void:
	var k := e.keycode
	var cmd := e.meta_pressed or e.ctrl_pressed
	if cmd and k == KEY_K:
		ui.open_search()
		return
	if cmd and k == KEY_COMMA:
		ui.toggle_settings()
		return
	if k == KEY_ESCAPE and ui.is_open():
		ui.close_all()
		return
	# le module affiché passe en premier (saisie de texte, Hz, tap…)
	if studio.modules.has(current) and studio.modules[current].on_key(e):
		return
	if k == KEY_F:
		ui.set_fullscreen(DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if k == KEY_T and not cmd:
		var on := not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, on)
		Toast.say("Premier plan : " + ("oui" if on else "non"))
		return
	if k == KEY_M and not cmd:
		ui.mini_mode()
		return
	if k == KEY_SLASH:
		ui.open_search()
		return
	if k >= KEY_1 and k <= KEY_9 and not cmd:
		go(AppUI.SHOTS[k - KEY_1][0])
		return
	if k == KEY_ESCAPE:
		go("overview")
	if k == KEY_PAGEDOWN or k == KEY_PAGEUP:
		step(1 if k == KEY_PAGEDOWN else -1)
	if k == KEY_LEFT or k == KEY_RIGHT:
		if current != "overview":
			go("overview")
		yaw += (PI / 4) * (1 if k == KEY_LEFT else -1)
		Store.set_v("yaw", yaw)


# ---------------------------------------------------------------- boucle
func _process(delta: float) -> void:
	t += delta
	if not ready_done:
		return
	_update_fov()
	var ky := 1.0 if reduced else 1.0 - pow(1.0 - .18, delta * 60.0)
	studio.look_yaw = lerpf(studio.look_yaw, yaw, ky)
	studio.look_pitch = lerpf(studio.look_pitch, pitch, ky)
	var target := studio.shot_pose(current, cam, _aspect())
	if _args.has("cam"):  # caméra libre pour les vérifs : --cam=x,y,z --look=x,y,z
		target = [_vec(_args.cam), _vec(_args.get("look", "0,0,0"))]
		cam_pos = target[0]
		cam_look = target[1]
	var k := 1.0 if reduced else 1.0 - pow(1.0 - .06, delta * 60.0)
	cam_pos = cam_pos.lerp(target[0], k)
	cam_look = cam_look.lerp(target[1], k)
	par += (pointer - par) * (1.0 - pow(.95, delta * 60.0))
	var amp := 0.0 if current == "overview" else .015
	var dr := 0.0 if reduced else 1.0
	cam.position = cam_pos + Vector3(par.x * amp + sin(t * .31) * .006 * dr, -par.y * amp * .5 + sin(t * .23) * .004 * dr, 0)
	cam.look_at(cam_look, Vector3.UP)
	var focus := cam.position.distance_to(cam_look)
	var wide := current == "overview" or current.begins_with("v_")
	attrs.dof_blur_far_distance = focus * (1.12 if wide else 1.06)
	attrs.dof_blur_far_transition = focus * (.9 if wide else .5)
	attrs.dof_blur_near_distance = focus * (.55 if wide else .8)
	attrs.dof_blur_near_transition = focus * (.35 if wide else .3)
	attrs.dof_blur_amount = .06
	attrs.dof_blur_far_enabled = Studio7080.LOOK_FX and not wide
	attrs.dof_blur_near_enabled = false
	studio.animate(t, delta, reduced)


func _screenshot_and_quit() -> void:
	# --screenshot=dossier/ avec --shots=overview,tempo,... : une capture par plan
	var frames := int(_args.get("frames", "60"))
	var shots: Array = _args.get("shots", current).split(",")
	for s in shots:
		current = s
		studio.look_yaw = yaw
		studio.look_pitch = pitch
		var p := studio.shot_pose(current, cam, _aspect())
		cam_pos = p[0]
		cam_look = p[1]
		for i in frames:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path: String = _args.screenshot
		if path.ends_with("/"):
			path += s + ".png"
		img.save_png(path)
		print("screenshot: ", path)
	get_tree().quit()



func _vec(txt: String) -> Vector3:
	var p := txt.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))


## Vérif automatique des modules : clic depuis le plan large, puis chaque commande en gros plan.
## Depuis le fauteuil, tourne la tête vers un point puis vise-le (test de clic en vue d'ensemble).
func _wide_pick(p: Vector3) -> String:
	cam.position = Studio7080.EYE
	cam.look_at(p, Vector3.UP)
	return pick(cam.unproject_position(p)).action


func _selftest() -> void:
	for i in 3:
		await get_tree().process_frame
	var tp: Node3D = studio.tempo
	print("pick tempo (plan large) -> ", _wide_pick(tp.global_position + Vector3(0, .1, 0)))
	go("tempo")
	var p := studio.shot_pose("tempo", cam, _aspect())
	cam.position = p[0]
	cam.look_at(p[1])
	for i in 3:
		await get_tree().process_frame
	for n in ["TempoKnob", "NoteSelector", "TapPad"]:
		var node: Node3D = tp.deck.get_node(n)
		print("pick ", n, " -> ", pick(cam.unproject_position(node.global_position)).action)
	var b0 := engine.bpm
	tp.on_action("double")
	print("x2 : ", b0, " -> ", engine.bpm)
	tp.on_action("half")
	tp.on_drag(Vector2(0, -50), false)
	print("glisser +50 px : ", engine.bpm)
	engine.set_bpm(b0)
	tp.on_action("note")
	print("note : ", engine.note_label(), " = ", engine.note_ms(), " ms")
	tp.on_action("copy")
	print("presse-papiers : ", DisplayServer.clipboard_get())
	var tu: Node3D = studio.tuner
	print("pick accordeur (plan large) -> ", _wide_pick(tu.to_global(Vector3(0, .09, 0))))
	for f in ["g1", "c2_24bit_stereo_48k", "fs1_plus20c", "d2_minus30"]:
		tu.load_sample("/tmp/808/%s.wav" % f)
		print("accordeur ", f, " -> ", tu.result.note, tu.result.octave, " %.1f Hz %+.0f c" % [tu.result.hz, tu.result.cents])
	tu.on_files(PackedStringArray(["/tmp/x.mp3"]))
	print("mp3 absent -> ", tu.result)
	var fq: Node3D = studio.freq
	print("pick synthé (plan large) -> ", _wide_pick(fq.to_global(Vector3(0, .08, 0))))
	fq.on_action("key:9")
	print("touche A : ", NoteFreq.label(fq.midi), " ", "%.2f Hz" % fq.freq)
	fq._set_a4(432.0)
	print("diapason 432 : ", "%.2f Hz" % fq.freq)
	fq._set_a4(440.0)
	fq._set_freq(100.0)
	var dsc := NoteFreq.describe(100.0)
	print("100 Hz -> ", dsc.note, dsc.octave, " %+.0f c" % dsc.cents, "  (LED : ", NoteFreq.label(fq.midi), ")")
	var ex: Node3D = studio.export
	print("pick tableau (plan large) -> ", _wide_pick(ex.global_position))
	ex.history = []
	ex.order = Export7080.DEFAULT_ORDER.duplicate()
	ex.artist = "Artiste"
	ex.title = "Titre"
	ex.version = 2
	ex.on_action("field:artist")
	_type(ex, "Ninho")
	_type(ex, "\n")
	_type(ex, "Jefe")
	_type(ex, "\n")
	ex.on_action("v_up")
	ex.on_action("format")
	ex.on_action("copy:Mix")
	print("export Mix -> ", DisplayServer.clipboard_get(), " | coché : ", ex.done)
	ex.on_press("tag:5")
	ex.on_drop("export:tag:0")
	print("ordre (v en premier) -> ", ex.filename("Master"))
	ex.on_action("new")
	_type(ex, "SDM")
	_type(ex, "\n")
	_type(ex, "Bolide")
	_type(ex, "\n")
	ex.on_action("hist:3")
	print("archives : rouvre -> ", ex.artist, " - ", ex.title, " v", ex.version, " | archives = ", ex.history.map(func(h): return h.title))
	ex.order = Export7080.DEFAULT_ORDER.duplicate()
	ex._refresh()
	go("overview")
	var an: Node3D = studio.analyzer
	print("pick analyseur (plan large) -> ", _wide_pick(an.to_global(Vector3(0, .09, 0))))
	for f in ["house_128_Am.wav", "trap_140_Fsm.mp3", "boom_92_D.wav"]:
		an.load_track("/tmp/tracks/" + f)
		an.wait_done()
		print("analyse ", f, " -> ", an.result.bpm.bpm, " ", an.result.bpm.alts, " ", an.result.key.best.short, " ", an.result.key.best.long)
	# fax d'accords
	var fx: Fax7080 = studio.fax
	print("pick fax (plan large) -> ", _wide_pick(fx.to_global(Vector3(0, .07, 0))))
	go("fax")
	await get_tree().create_timer(.6).timeout
	for nm in ["Wheel", "Sound", "Send", "Sheet"]:
		var probe := {"Wheel": Vector3(fx._wheel_x(2), .07, .054), "Sound": Vector3(fx._key_x(3), .072, .11), "Send": Vector3(.175, .08, .143), "Sheet": Vector3(Fax7080.SHEET_X, .1, Fax7080.D / 2 - .01)}[nm] as Vector3
		print("pick fax ", nm, " -> ", pick(cam.unproject_position(fx.to_global(probe))).action)
	fx.on_action("send")
	print("fax : ", ChordEngine.summary(fx.prog), " | ", fx._wheel_text(0), " ", fx._wheel_text(2), " ", fx.bpm, " BPM")
	fx.on_press("wheel:2")
	fx.on_drop("")
	print("fax : tonalité +1 -> ", fx._wheel_text(2), " | ", ChordEngine.summary(fx.prog))
	fx.on_action("sound:3")
	fx.toggle_play()
	var t0 := Time.get_ticks_msec()
	while fx._render_job >= 0 and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().process_frame
	print("fax : écoute prête en ", Time.get_ticks_msec() - t0, " ms, lecture = ", fx.player.playing)
	fx._export_to("/tmp/fax_test.mid")
	print("fax : midi écrit = ", FileAccess.file_exists("/tmp/fax_test.mid"), " (", FileAccess.get_file_as_bytes("/tmp/fax_test.mid").size(), " octets)")
	fx.crumple()
	for i in 40:
		await get_tree().process_frame
	print("fax : froissée -> nouvelle grille ", ChordEngine.summary(fx.prog), " | boulettes = ", fx.balls.size())
	# boîtes à rythmes
	var bt: Beats7080 = studio.beats
	print("pick beats (plan large) -> ", _wide_pick(bt.to_global(Vector3(0, .1, 0))))
	go("beats")
	for i in 60:
		await get_tree().process_frame
	for nd in [bt.d_caps[4].get_parent(), bt.b_caps[3].get_parent(), bt.keys[4], bt.knobs.bpm]:
		var gp: Vector3 = (nd as Node3D).global_position + Vector3(0, .006, 0)
		print("pick beats -> ", pick(cam.unproject_position(gp)).action)
	var before: int = bt.drums[0][4]
	bt.on_action("dstep:4")
	print("beats : pas 5 kick ", before, " -> ", bt.drums[0][4])
	bt.on_action("bstep:3")
	bt.on_action("key:7")
	print("beats : 808 pas 4 = ", bt.bass[3], " sel ", bt.bass_sel)
	bt.instr = 2
	bt.on_wheel("dstep:6", 1.0, false)
	print("beats : hat pas 7 = ", bt.drums[2][6])
	bt.set_sync(true)
	print("beats : sync -> ", bt.bpm, " BPM, ", bt._bars(), " mesures | ", bt._led_lines())
	bt.toggle_play()
	for i in 90:
		await get_tree().process_frame
	print("beats : lecture, pas courant = ", bt.cur_step, " horloge = ", snappedf(bt.clock, .01))
	bt.toggle_play()
	bt._export_to("/tmp/beats_test.mid")
	print("beats : midi écrit = ", FileAccess.get_file_as_bytes("/tmp/beats_test.mid").size(), " octets")
	# carnet de splits
	var sl: Splits7080 = studio.splits
	print("pick splits (plan large) -> ", _wide_pick(sl.to_global(Vector3(-.1, .05, .02))))
	go("splits")
	await get_tree().create_timer(.6).timeout
	for nm in ["field:title", "row:0:a", "equal", "next"]:
		var probe := {"field:title": Vector3(-.11, .1, .02), "row:0:a": Vector3(.06, .08, .02), "equal": Vector3(.08, -.1, .02), "next": Vector3(.17, -.135, .02)}[nm] as Vector3
		print("pick splits ", nm, " -> ", pick(cam.unproject_position(sl.to_global(probe))).action)
	var saved: Array = sl.pages.duplicate(true)
	var saved_cur := sl.cur
	sl.pages = [sl._blank_page()]
	sl.cur = 0
	sl.on_action("field:title")
	_type(sl, "Bolide")
	_type(sl, "\n")
	_type(sl, "SDM")
	_type(sl, "\n")
	for nm in ["Maxime", "SDM", "Kore"]:
		sl.on_action("add")
		_type(sl, nm)
	sl.on_action("equal")
	print("splits SACEM 3 -> ", sl.pages[0].rows.map(func(r): return r.share), " ", sl.check())
	print("splits 24 parts -> ", Splits7080.equal_parts(24).slice(14, 18), " somme ", snappedf(Splits7080.equal_parts(24).reduce(func(a, b): return a + b, 0.0), .01))
	sl.on_action("row:1:a")
	sl._commit()
	sl.on_action("row:1:d")
	_type(sl, "40")
	_type(sl, "\n")
	print("splits part saisie -> ", sl.pages[0].rows[1].share, " ", sl.check())
	sl.on_action("mode:intl")
	sl.on_action("row:2:b")
	sl.on_action("equal")
	print("splits intl -> ", sl.pages[0].rows.map(func(r): return [r.role, r.share]), " ", sl.check())
	sl.on_action("copy")
	print("splits récap :\n", DisplayServer.clipboard_get())
	sl.write_pdf("/tmp/splits_test.pdf")
	var pdf := FileAccess.get_file_as_bytes("/tmp/splits_test.pdf")
	print("splits PDF = ", pdf.size(), " octets, en-tête ", pdf.slice(0, 8).get_string_from_ascii())
	sl.on_action("next")
	for i in 50:
		await get_tree().process_frame
	print("splits page suivante -> ", sl.cur + 1, "/", sl.pages.size(), " titre '", sl.pages[sl.cur].title, "'")
	sl.on_action("prev")
	for i in 50:
		await get_tree().process_frame
	print("splits retour -> ", sl.pages[sl.cur].title)
	sl.pages = saved
	sl.cur = saved_cur
	sl._refresh()
	go("overview")
	get_tree().quit()


## Contrôle de dev (--perf) : objets, appels de dessin et triangles par plan (moyenne sur quelques images).
func _perf() -> void:
	var n_mesh := 0
	var n_shadow := 0
	var stack: Array[Node] = [studio]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		if nd is MeshInstance3D and (nd as MeshInstance3D).visible:
			n_mesh += 1
			if (nd as MeshInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				n_shadow += 1
		stack.append_array(nd.get_children())
	print("perf : meshes = ", n_mesh, " | qui projettent une ombre = ", n_shadow)
	var per := {}
	for ch in studio.get_children():
		per[ch.name] = ch.find_children("*", "MeshInstance3D", true, false).filter(func(x): return x.visible).size()
	var keys := per.keys()
	keys.sort_custom(func(a, b): return per[a] > per[b])
	print("perf top : ", keys.slice(0, 14).map(func(k): return "%s=%d" % [k, per[k]]))
	for shot in ["overview", "beats", "splits"]:
		go(shot)
		for i in 40:
			await get_tree().process_frame
		var dc := 0
		var ob := 0
		var pr := 0
		for i in 10:
			await get_tree().process_frame
			dc += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			ob += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
			pr += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		print("perf ", shot, " : draw calls ", dc / 10, " | objets ", ob / 10, " | triangles ", pr / 10)
	get_tree().quit()


func _type(mod: Node, txt: String) -> void:
	if txt == "\n":
		var ent := InputEventKey.new()
		ent.keycode = KEY_ENTER
		mod.on_key(ent)
		return
	for ch in txt:
		var ev := InputEventKey.new()
		ev.unicode = ch.unicode_at(0)
		mod.on_key(ev)


## Contrôle de dev (--overlaps) : liste les objets de la pièce qui se rentrent dedans. Chaque objet
## = sa boîte orientée (meshes visibles, dans son propre repère) ; test des axes séparateurs ;
## on signale une pénétration de plus de 2 cm.
func _vis_aabb(root: Node3D) -> Variant:
	var out: Variant = null
	var inv := root.global_transform.affine_inverse()
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var m := n as MeshInstance3D
		if not m.is_visible_in_tree() or m.mesh == null:
			continue
		var bb: AABB = (inv * m.global_transform) * m.get_aabb()
		out = bb if out == null else (out as AABB).merge(bb)
	return out


func _obb_pen(a: Array, b: Array) -> float:
	# a, b = [centre, [axe0, axe1, axe2] (unitaires), demi-tailles]
	var axes := []
	for i in 3:
		axes.append(a[1][i])
		axes.append(b[1][i])
	for i in 3:
		for j in 3:
			var c: Vector3 = (a[1][i] as Vector3).cross(b[1][j])
			if c.length() > 1e-4:
				axes.append(c.normalized())
	var best := 1e9
	for ax in axes:
		var ra := 0.0
		var rb := 0.0
		for i in 3:
			ra += absf((a[1][i] as Vector3).dot(ax)) * a[2][i]
			rb += absf((b[1][i] as Vector3).dot(ax)) * b[2][i]
		var d := absf(((b[0] as Vector3) - (a[0] as Vector3)).dot(ax))
		best = minf(best, ra + rb - d)
		if best <= 0:
			return 0.0
	return best


func _overlaps() -> void:
	var items := []
	var parents: Array = [studio, studio.deco]
	for c in studio.get_children():
		if c.name == "Booth":
			parents.append(c)
	for par in parents:
		for c in par.get_children():
			if not (c is Node3D) or c is MeshInstance3D or c is Light3D or c is MultiMeshInstance3D or c is Camera3D:
				continue
			if String(c.name) in ["Booth", "Street", "Deco7080", "FrontWall", "RightWall", "LeftWall", "BackWall"]:
				continue
			var n := c as Node3D
			var bbv: Variant = _vis_aabb(n)
			if bbv == null:
				continue
			var bb: AABB = bbv
			if bb.size.x > 3.0 or bb.size.z > 3.0 or bb.size.y > 2.7:
				continue
			var gt := n.global_transform
			var axes := []
			var half := []
			for i in 3:
				var col: Vector3 = gt.basis[i]
				axes.append(col.normalized())
				half.append(bb.size[i] / 2 * col.length())
			items.append([n, [gt * bb.get_center(), axes, half]])
	var found := 0
	for i in items.size():
		for j in range(i + 1, items.size()):
			var pen := _obb_pen(items[i][1], items[j][1])
			if pen > .02:
				found += 1
				print("CHEVAUCHEMENT %.2f m  %s  <->  %s" % [pen, _nm(items[i][0]), _nm(items[j][0])])
	print("objets contrôlés : %d, chevauchements : %d" % [items.size(), found])


func _nm(n: Node) -> String:
	var s := String(n.name)
	var p := (n as Node3D).global_position.snapped(Vector3.ONE * .01)
	return "%s@(%.2f, %.2f, %.2f)" % [s.replace("@", "").left(18), p.x, p.y, p.z]
