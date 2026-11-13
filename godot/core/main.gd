extends Node3D
## REEL'S TOOLS — point d'entrée : monte le studio, la caméra, et gère clic / glisser / clavier.
##
## Modules : clic sur une machine = zoom ; ses commandes ont des actions « module:commande ».
## Raccourcis : Échap = plan large · ←/→ ou PageUp/PageDown = plan précédent/suivant
## Tempo : Espace = tap, ↑/↓ = BPM (Maj = 0,1), N = note, C = copier les ms
## F ou Cmd+F = plein écran · T = garder la fenêtre au premier plan (à côté du DAW)
##
## Options de lancement (après « -- ») : --shot=tempo  --screenshot=chemin.png (ou dossier/ + --shots=a,b)  --frames=N

var engine: TempoEngine
var studio: Studio7080
var cam: Camera3D
var attrs: CameraAttributesPractical
var overlay: Overlay
var current := "overview"
var cam_pos := Vector3.ZERO
var cam_look := Vector3.ZERO
var pointer := Vector2.ZERO
var par := Vector2.ZERO
var swipe = null  # {pos, t, a}
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
	DisplayServer.window_set_min_size(Vector2i(480, 320))
	engine = TempoEngine.new()
	studio = Studio7080.new(engine)
	add_child(studio)
	cam = Camera3D.new()
	cam.near = 0.02
	cam.far = 30.0
	attrs = CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_near_enabled = true
	attrs.auto_exposure_enabled = false
	cam.attributes = attrs
	add_child(cam)
	cam.current = true
	overlay = Overlay.new()
	add_child(overlay)
	current = _args.get("shot", Store.get_v("shot", "overview"))
	if not studio.order.has(current):
		current = "overview"
	get_window().files_dropped.connect(_on_files_dropped)
	await Tex.flush()
	if _args.has("sample") and studio.modules.has("tuner"):
		studio.modules.tuner.load_sample(_args.sample)
	if _args.has("track") and studio.modules.has("analyse"):
		studio.modules.analyse.load_track(_args.track)
		studio.modules.analyse.wait_done()
	_update_fov()
	var p := studio.shot_pose(current, cam, _aspect())
	cam_pos = p[0]
	cam_look = p[1]
	ready_done = true
	overlay.boot_done()
	if _args.has("selftest"):
		_selftest()
	elif _args.has("screenshot"):
		_screenshot_and_quit()


func _aspect() -> float:
	var s := get_viewport().get_visible_rect().size
	return s.x / maxf(s.y, 1.0)


func _update_fov() -> void:
	studio.setup_camera(cam, _aspect())


# ---------------------------------------------------------------- navigation
func go(shot: String) -> void:
	current = shot
	Store.set_v("shot", shot)
	overlay.hide_hint()


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
		var hover: String = pick(e.position).action
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hover != "" else Input.CURSOR_ARROW)
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
		swipe = {"pos": e.position, "t": Time.get_ticks_msec(), "a": a}
		var sp := _split(a)
		if not sp.is_empty() and sp[2] == current and sp[0].on_drag_start(sp[1]):
			drag = {"mod": sp[0]}
		return
	var was_drag := drag != null
	drag = null
	if swipe == null:
		return
	var dpos: Vector2 = e.position - swipe.pos
	var dt: int = Time.get_ticks_msec() - swipe.t
	var a: String = swipe.a
	swipe = null
	if was_drag:
		return
	var big := maxf(absf(dpos.x), absf(dpos.y))
	if big > 50 and dt < 700:
		var v := -dpos.y if absf(dpos.y) > absf(dpos.x) else -dpos.x
		step(1 if v > 0 else -1)
		return
	if big > 12:
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
	if k == KEY_F:
		var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if k == KEY_T:
		var on := not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, on)
		return
	if studio.modules.has(current) and studio.modules[current].on_key(e):
		return
	if k == KEY_ESCAPE:
		go("overview")
	if k == KEY_PAGEDOWN or k == KEY_RIGHT:
		step(1)
	if k == KEY_PAGEUP or k == KEY_LEFT:
		step(-1)


# ---------------------------------------------------------------- boucle
func _process(delta: float) -> void:
	t += delta
	if not ready_done:
		return
	_update_fov()
	var target := studio.shot_pose(current, cam, _aspect())
	if _args.has("cam"):  # caméra libre pour les vérifs : --cam=x,y,z --look=x,y,z
		target = [_vec(_args.cam), _vec(_args.get("look", "0,0,0"))]
		cam_pos = target[0]
		cam_look = target[1]
	var k := 1.0 if reduced else 1.0 - pow(1.0 - .06, delta * 60.0)
	cam_pos = cam_pos.lerp(target[0], k)
	cam_look = cam_look.lerp(target[1], k)
	par += (pointer - par) * (1.0 - pow(.95, delta * 60.0))
	var amp := .05 if current == "overview" else .015
	var dr := 0.0 if reduced else 1.0
	cam.position = cam_pos + Vector3(par.x * amp + sin(t * .31) * .006 * dr, -par.y * amp * .5 + sin(t * .23) * .004 * dr, 0)
	if target.size() > 2 and not _args.has("cam"):
		cam.basis = target[2]  # orientation exacte de la caméra Blender
	else:
		cam.look_at(cam_look, Vector3.UP)
	var focus := cam.position.distance_to(cam_look)
	var wide := current == "overview"
	attrs.dof_blur_far_distance = focus * (1.12 if wide else 1.06)
	attrs.dof_blur_far_transition = focus * (.9 if wide else .5)
	attrs.dof_blur_near_distance = focus * (.55 if wide else .8)
	attrs.dof_blur_near_transition = focus * (.35 if wide else .3)
	attrs.dof_blur_amount = .06 if wide else .1
	studio.animate(t, delta, reduced)


func _screenshot_and_quit() -> void:
	# --screenshot=dossier/ avec --shots=overview,tempo,... : une capture par plan
	var frames := int(_args.get("frames", "60"))
	var shots: Array = _args.get("shots", current).split(",")
	for s in shots:
		current = s
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
func _selftest() -> void:
	for i in 3:
		await get_tree().process_frame
	var tp: Node3D = studio.tempo
	print("pick tempo (plan large) -> ", pick(cam.unproject_position(tp.global_position + Vector3(0, .1, 0))).action)
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
	print("pick accordeur (plan large) -> ", pick(cam.unproject_position(tu.to_global(Vector3(0, .09, 0)))).action)
	for f in ["g1", "c2_24bit_stereo_48k", "fs1_plus20c", "d2_minus30"]:
		tu.load_sample("/tmp/808/%s.wav" % f)
		print("accordeur ", f, " -> ", tu.result.note, tu.result.octave, " %.1f Hz %+.0f c" % [tu.result.hz, tu.result.cents])
	tu.on_files(PackedStringArray(["/tmp/x.mp3"]))
	print("mp3 absent -> ", tu.result)
	var an: Node3D = studio.analyzer
	print("pick analyseur (plan large) -> ", pick(cam.unproject_position(an.to_global(Vector3(0, .09, 0)))).action)
	for f in ["house_128_Am.wav", "trap_140_Fsm.mp3", "boom_92_D.wav"]:
		an.load_track("/tmp/tracks/" + f)
		an.wait_done()
		print("analyse ", f, " -> ", an.result.bpm.bpm, " ", an.result.bpm.alts, " ", an.result.key.best.short, " ", an.result.key.best.long)
	go("overview")
	get_tree().quit()
