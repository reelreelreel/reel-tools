class_name AppUI
extends CanvasLayer
## Interface de l'appli : volontairement simple et neutre (police système, gris translucide),
## commune à tous les studios — la D.A reste dans les studios.
##   · petite étiquette au nom de la machine, posée dessus, qui n'apparaît qu'au survol de la souris
##     dans la vue d'ensemble (clic = y aller, chiffres 1–7 au clavier)
##   · deux petites icônes en haut à droite : recherche rapide (Cmd+K ou /) et réglages (Cmd+,)
##   · petites confirmations (toast), ex. « Copié »

const SHOTS := [
	["overview", "Vue d'ensemble"],
	["tempo", "Tempo"],
	["tuner", "Accordeur 808"],
	["analyse", "Analyse"],
	["freq", "Fréquences"],
	["export", "Export"],
	["fax", "Fax d'accords"],
	["beats", "Boîtes à rythmes"],
	["splits", "Carnet de splits"],
]
const STUDIOS := [
	["7080", "Années 70/80", true],
	["90", "Années 90", false],
	["2000", "Années 2000", false],
	["2020", "Années 2020", false],
	["cyber", "Futuriste", false],
	["postapo", "Post-apocalyptique", false],
	["nature", "Nature", false],
]
const LAMP_COLORS := [
	["Ambre", Color(1.0, .72, .44)],
	["Blanc chaud", Color(1.0, .88, .74)],
	["Rouge", Color(1.0, .3, .22)],
	["Vert", Color(.5, 1.0, .5)],
	["Bleu", Color(.45, .62, 1.0)],
]

var main: Node
var font: Font
var root: Control
var ui_scale := 1.0  # 2 sur un écran Retina : l'interface garde sa taille, la 3D est rendue en pleine définition
var tags := {}            # plan -> Button posé sur la machine
var _tag_anchor := {}     # plan -> point 3D (dessus de la machine)
var _tag_alpha := {}
var _shot := "overview"
var settings: PanelContainer
var search: PanelContainer
var search_edit: LineEdit
var search_list: VBoxContainer
var toast_label: Label
var _toast_tw: Tween
var _search_hits: Array = []
var _search_sel := 0


func _init(m: Node) -> void:
	main = m
	layer = 20
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray([".AppleSystemUIFont", "SF Pro Text", "Helvetica Neue", "Inter", "Segoe UI", "Roboto", "Arial", "sans-serif"])
	sf.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font = sf
	var th := _theme()
	ui_scale = maxf(1.0, DisplayServer.screen_get_scale())
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.scale = Vector2(ui_scale, ui_scale)
	root.theme = th
	add_child(root)
	_build_tags(root)
	_build_gear(root)
	_build_settings(root)
	_build_search(root)
	_build_toast(root)
	_setup_audio_buses()


# ---------------------------------------------------------------- thème neutre
func _box(bg: Color, radius := 10, pad := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	sb.anti_aliasing = true
	return sb


func _theme() -> Theme:
	var th := Theme.new()
	th.default_font = font
	th.default_font_size = 13
	var fg := Color(.93, .93, .93)
	var dim := Color(.93, .93, .93, .55)
	for t in ["Label", "Button", "CheckButton", "LineEdit"]:
		th.set_color("font_color", t, fg)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", dim)
	th.set_color("font_placeholder_color", "LineEdit", dim)
	th.set_stylebox("panel", "PanelContainer", _box(Color(.11, .11, .11, .82), 12, 12))
	th.set_stylebox("normal", "Button", _box(Color(1, 1, 1, 0), 7, 6))
	th.set_stylebox("hover", "Button", _box(Color(1, 1, 1, .09), 7, 6))
	th.set_stylebox("pressed", "Button", _box(Color(1, 1, 1, .16), 7, 6))
	th.set_stylebox("disabled", "Button", _box(Color(1, 1, 1, 0), 7, 6))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for s in ["normal", "focus", "read_only"]:
		var b := _box(Color(1, 1, 1, .07), 7, 8)
		if s == "focus":
			b.border_color = Color(1, 1, 1, .35)
			b.set_border_width_all(1)
		th.set_stylebox(s, "LineEdit", b)
	th.set_color("caret_color", "LineEdit", fg)
	th.set_color("selection_color", "LineEdit", Color(1, 1, 1, .25))
	th.set_stylebox("normal", "CheckButton", _box(Color(1, 1, 1, 0), 7, 6))
	th.set_stylebox("hover", "CheckButton", _box(Color(1, 1, 1, .06), 7, 6))
	th.set_stylebox("pressed", "CheckButton", _box(Color(1, 1, 1, 0), 7, 6))
	th.set_stylebox("hover_pressed", "CheckButton", _box(Color(1, 1, 1, .06), 7, 6))
	th.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())
	th.set_constant("separation", "VBoxContainer", 4)
	th.set_constant("separation", "HBoxContainer", 4)
	th.set_stylebox("separator", "HSeparator", _line())
	return th


func _line() -> StyleBoxLine:
	var l := StyleBoxLine.new()
	l.color = Color(1, 1, 1, .1)
	l.thickness = 1
	return l


func _label(txt: String, size := 13, alpha := 1.0) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.modulate.a = alpha
	return l


# ---------------------------------------------------------------- étiquettes des machines
func _build_tags(root: Control) -> void:
	for i in range(1, SHOTS.size()):
		var b := Button.new()
		b.text = SHOTS[i][1]
		b.tooltip_text = "%s  (touche %d)" % [SHOTS[i][1], i + 1]
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_size_override("font_size", 11)
		b.add_theme_stylebox_override("normal", _box(Color(.08, .08, .08, .55), 6, 0))
		b.add_theme_stylebox_override("hover", _box(Color(.08, .08, .08, .85), 6, 0))
		b.add_theme_stylebox_override("pressed", _box(Color(.2, .2, .2, .9), 6, 0))
		for sb in ["normal", "hover", "pressed"]:
			var st := b.get_theme_stylebox(sb) as StyleBoxFlat
			st.content_margin_left = 7
			st.content_margin_right = 7
			st.content_margin_top = 2
			st.content_margin_bottom = 3
		var shot: String = SHOTS[i][0]
		b.pressed.connect(func(): main.go(shot))
		b.modulate.a = 0.0
		root.add_child(b)
		tags[shot] = b


## Boîte englobante (repère local) de chaque machine, calculée une fois.
func _bounds(shot: String):
	if _tag_anchor.has(shot):
		return _tag_anchor[shot]
	var node: Node3D = main.studio.modules.get(shot)
	if node == null or not node.is_inside_tree():
		return null
	var bb := Mk.local_aabb(node)
	if shot == "export":  # le tableau seul (centré sur son origine)
		bb = AABB(Vector3(-Export7080.BW / 2, -Export7080.BH / 2, 0), Vector3(Export7080.BW, Export7080.BH, .03))
	_tag_anchor[shot] = [node, bb]
	return _tag_anchor[shot]


## Position écran de l'étiquette : centrée au-dessus de la machine telle qu'on la voit.
func _screen_anchor(cam: Camera3D, shot: String) -> Vector2:
	var info = _bounds(shot)
	if info == null:
		return Vector2.INF
	var node: Node3D = info[0]
	var bb: AABB = info[1]
	var xs := []
	var top := INF
	for i in 8:
		var c := node.to_global(bb.get_endpoint(i))
		if cam.is_position_behind(c):
			return Vector2.INF
		var sp := cam.unproject_position(c)
		xs.append(sp.x)
		top = minf(top, sp.y)
	# centre de la partie visible (une machine coupée par le bord garde son étiquette dessus)
	var w := get_viewport().get_visible_rect().size.x
	return Vector2((clampf(xs.min(), 0, w) + clampf(xs.max(), 0, w)) / 2.0, top)


## Appelé par main à chaque changement de plan.
func on_shot(shot: String) -> void:
	_shot = shot


func _process(delta: float) -> void:
	root.size = get_viewport().get_visible_rect().size / ui_scale
	if main == null or main.cam == null or not main.ready_done:
		return
	var cam: Camera3D = main.cam
	var vs := root.size
	var wide := _shot == "overview" and not search.visible
	for shot in tags:
		var b: Button = tags[shot]
		var want := 1.0 if wide and (main.hover_module == shot or b.is_hovered()) else 0.0
		var al: float = move_toward(_tag_alpha.get(shot, 0.0), want, delta * (6.0 if want > 0 else 4.0))
		_tag_alpha[shot] = al
		var sp := _screen_anchor(cam, shot) / ui_scale if al > .01 else Vector2.INF
		var vis := sp != Vector2.INF
		b.visible = vis
		if not vis:
			continue
		b.size = b.get_combined_minimum_size()
		var pos := sp - Vector2(b.size.x / 2, b.size.y + 6)
		pos.x = clampf(pos.x, 8, vs.x - b.size.x - 8)
		pos.y = clampf(pos.y, 52, vs.y - b.size.y - 8)
		b.position = pos.round()
		b.modulate.a = al


# ---------------------------------------------------------------- réglages
func _build_gear(root: Control) -> void:
	var specs := [["gear", "Réglages  (Cmd+,)", -14, toggle_settings], ["search", "Aller à une machine  (Cmd+K)", -52, open_search]]
	for sp in specs:
		var g := IconButton.new()
		g.kind = sp[0]
		g.tooltip_text = sp[1]
		g.custom_minimum_size = Vector2(30, 30)
		g.focus_mode = Control.FOCUS_NONE
		g.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		g.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		g.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		g.offset_right = sp[2]
		g.offset_top = 12
		g.pressed.connect(sp[3])
		root.add_child(g)


## Petit bouton rond avec une icône dessinée (loupe ou engrenage), très discret.
class IconButton extends Button:
	var kind := "gear"

	func _init() -> void:
		flat = true
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var hov := is_hovered()
		var c := size / 2
		draw_circle(c, 14.0, Color(.08, .08, .08, .7 if hov else .45))
		var ink := Color(1, 1, 1, .95 if hov else .7)
		if kind == "search":
			draw_arc(c + Vector2(-1.5, -1.5), 5.0, 0, TAU, 24, ink, 1.6, true)
			draw_line(c + Vector2(2.2, 2.2), c + Vector2(6, 6), ink, 1.8, true)
		else:
			for i in 8:
				var a := i * TAU / 8
				draw_line(c + Vector2(cos(a), sin(a)) * 4.5, c + Vector2(cos(a), sin(a)) * 7.5, ink, 2.4, true)
			draw_arc(c, 5.0, 0, TAU, 24, ink, 2.2, true)
			draw_circle(c, 1.8, ink)


func _section(v: VBoxContainer, title: String) -> void:
	if v.get_child_count() > 0:
		var sp := HSeparator.new()
		sp.add_theme_constant_override("separation", 14)
		v.add_child(sp)
	v.add_child(_label(title.to_upper(), 11, .55))


func _build_settings(root: Control) -> void:
	settings = PanelContainer.new()
	settings.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	settings.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	settings.offset_left = -300
	settings.offset_right = -14
	settings.offset_top = 50
	settings.offset_bottom = -14
	settings.visible = false
	root.add_child(settings)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	settings.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)

	# studio
	_section(v, "Studio")
	var cur: String = Store.get_v("studio", "7080")
	for st in STUDIOS:
		var b := Button.new()
		b.text = st[1] + ("" if st[2] else "  ·  bientôt")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not st[2]
		b.focus_mode = Control.FOCUS_NONE
		if st[0] == cur:
			b.add_theme_stylebox_override("normal", _box(Color(1, 1, 1, .14), 7, 6))
		v.add_child(b)

	# personnalisation
	_section(v, "Personnalisation")
	v.add_child(_label("Couleur de la lampe", 12, .8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var lamp_i: int = Store.get_v("lamp_color", 0)
	var swatches: Array[Button] = []
	for i in LAMP_COLORS.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(28, 28)
		b.tooltip_text = LAMP_COLORS[i][0]
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		swatches.append(b)
		row.add_child(b)
		var idx := i
		b.pressed.connect(func():
			Store.set_v("lamp_color", idx)
			_apply_lamp(idx)
			_paint_swatches(swatches, idx))
	_paint_swatches(swatches, lamp_i)
	_apply_lamp(lamp_i)

	# sons
	_section(v, "Sons")
	for bus in [["Machines", "Machines (synthé, lecture des fichiers)"], ["Ambiance", "Ambiance du studio"]]:
		var cb := CheckButton.new()
		cb.text = bus[1]
		cb.focus_mode = Control.FOCUS_NONE
		var on: bool = Store.get_v("snd_" + bus[0], true)
		cb.button_pressed = on
		_mute_bus(bus[0], not on)
		var bn: String = bus[0]
		cb.toggled.connect(func(p: bool):
			Store.set_v("snd_" + bn, p)
			_mute_bus(bn, not p))
		v.add_child(cb)

	# fenêtre
	_section(v, "Fenêtre")
	var fs := CheckButton.new()
	fs.text = "Plein écran  (F)"
	fs.focus_mode = Control.FOCUS_NONE
	fs.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fs.toggled.connect(func(p: bool): set_fullscreen(p))
	v.add_child(fs)
	var top := CheckButton.new()
	top.text = "Toujours au premier plan  (T)"
	top.focus_mode = Control.FOCUS_NONE
	top.button_pressed = DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP)
	top.toggled.connect(func(p: bool): DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, p))
	v.add_child(top)
	var mini := Button.new()
	mini.text = "Mode mini, à côté du DAW  (M)"
	mini.alignment = HORIZONTAL_ALIGNMENT_LEFT
	mini.focus_mode = Control.FOCUS_NONE
	mini.pressed.connect(func():
		mini_mode()
		top.button_pressed = true
		fs.button_pressed = false)
	v.add_child(mini)

	# raccourcis
	_section(v, "Raccourcis")
	for kv in [["1 – 8", "Aller à une machine"], ["← →", "Machine précédente / suivante"], ["Échap", "Vue d'ensemble"], ["Cmd+K", "Rechercher une machine"], ["F  ·  T  ·  M", "Plein écran · Premier plan · Mini"], ["Espace", "Tap tempo (Tempo)"], ["Glisser un fichier", "Accordeur ou Analyse"]]:
		var h := HBoxContainer.new()
		var k := _label(kv[0], 12, .9)
		k.custom_minimum_size.x = 110
		h.add_child(k)
		h.add_child(_label(kv[1], 12, .6))
		v.add_child(h)


func _paint_swatches(list: Array[Button], sel: int) -> void:
	for i in list.size():
		var sb := _box(LAMP_COLORS[i][1], 14, 0)
		if i == sel:
			sb.border_color = Color.WHITE
			sb.set_border_width_all(2)
		for st in ["normal", "hover", "pressed"]:
			list[i].add_theme_stylebox_override(st, sb)


func _apply_lamp(i: int) -> void:
	if main.studio and main.studio.deco:
		main.studio.deco.set_lamp_color(LAMP_COLORS[clampi(i, 0, LAMP_COLORS.size() - 1)][1])


func toggle_settings() -> void:
	settings.visible = not settings.visible
	if settings.visible:
		search.visible = false


func is_open() -> bool:
	return settings.visible or search.visible


func close_all() -> void:
	settings.visible = false
	search.visible = false


# ---------------------------------------------------------------- fenêtre
func set_fullscreen(on: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)


## Petite fenêtre 16:9 au premier plan, calée en bas à droite de l'écran (à côté du DAW).
func mini_mode() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	var sz := Vector2i(560, 315)
	DisplayServer.window_set_size(sz)
	var scr := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	DisplayServer.window_set_position(scr.position + scr.size - sz - Vector2i(24, 24))


# ---------------------------------------------------------------- sons
func _setup_audio_buses() -> void:
	for n in ["Machines", "Ambiance"]:
		if AudioServer.get_bus_index(n) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, n)
			AudioServer.set_bus_send(i, "Master")


## Range chaque lecteur audio du studio dans le bus « Machines ».
func route_audio(studio: Node) -> void:
	for p in studio.find_children("*", "AudioStreamPlayer", true, false):
		(p as AudioStreamPlayer).bus = "Machines"


func _mute_bus(n: String, mute: bool) -> void:
	var i := AudioServer.get_bus_index(n)
	if i >= 0:
		AudioServer.set_bus_mute(i, mute)


# ---------------------------------------------------------------- recherche rapide
func _build_search(root: Control) -> void:
	search = PanelContainer.new()
	search.set_anchors_preset(Control.PRESET_CENTER_TOP)
	search.grow_horizontal = Control.GROW_DIRECTION_BOTH
	search.offset_left = -190
	search.offset_right = 190
	search.offset_top = 80
	search.visible = false
	root.add_child(search)
	var v := VBoxContainer.new()
	search.add_child(v)
	search_edit = LineEdit.new()
	search_edit.placeholder_text = "Aller à…  (tempo, 808, bpm, nom de fichier…)"
	search_edit.text_changed.connect(func(_t): _refresh_search())
	search_edit.gui_input.connect(_search_key)
	v.add_child(search_edit)
	search_list = VBoxContainer.new()
	v.add_child(search_list)


const KEYWORDS := {
	"overview": "vue ensemble studio accueil",
	"tempo": "tempo bpm tap delay reverb ms pre-delay decay",
	"tuner": "accordeur 808 kick note sample accorder",
	"analyse": "analyse bpm tonalité tonalite key morceau prod fichier",
	"freq": "fréquences frequences hz note synthé synthe la 440",
	"export": "export nom fichier mix master version bounce",
	"fax": "fax accords grille progression midi compo rhodes",
	"splits": "split splits carnet répartition repartition sacem droits ayants auteur compositeur éditeur editeur publisher writer ipi pro pourcentage feuille",
	"beats": "boite rythme boîte batterie drum 808 beat pattern séquenceur sequenceur kick hat",
}


func open_search() -> void:
	settings.visible = false
	search.visible = true
	search_edit.text = ""
	_refresh_search()
	search_edit.grab_focus()


func _refresh_search() -> void:
	for c in search_list.get_children():
		c.queue_free()
	var q := search_edit.text.strip_edges().to_lower()
	_search_hits = []
	for s in SHOTS:
		var hay: String = (s[1] + " " + KEYWORDS.get(s[0], "")).to_lower()
		if q == "" or hay.contains(q):
			_search_hits.append(s)
	_search_sel = 0
	for i in _search_hits.size():
		var b := Button.new()
		b.text = _search_hits[i][1]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		var shot: String = _search_hits[i][0]
		b.pressed.connect(func(): _go_search(shot))
		search_list.add_child(b)
	_paint_search()


func _paint_search() -> void:
	var i := 0
	for c in search_list.get_children():
		(c as Button).add_theme_stylebox_override("normal", _box(Color(1, 1, 1, .14 if i == _search_sel else 0.0), 7, 6))
		i += 1


func _search_key(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed):
		return
	match e.keycode:
		KEY_DOWN:
			_search_sel = mini(_search_sel + 1, _search_hits.size() - 1)
			_paint_search()
			search_edit.accept_event()
		KEY_UP:
			_search_sel = maxi(_search_sel - 1, 0)
			_paint_search()
			search_edit.accept_event()
		KEY_ENTER, KEY_KP_ENTER:
			if not _search_hits.is_empty():
				_go_search(_search_hits[_search_sel][0])
			search_edit.accept_event()
		KEY_ESCAPE:
			search.visible = false
			search_edit.release_focus()
			search_edit.accept_event()


func _go_search(shot: String) -> void:
	search.visible = false
	search_edit.release_focus()
	main.go(shot)


# ---------------------------------------------------------------- confirmations
func _build_toast(root: Control) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(Color(.11, .11, .11, .85), 9, 9))
	p.set_anchors_preset(Control.PRESET_CENTER_TOP)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.offset_top = 18
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.modulate.a = 0.0
	root.add_child(p)
	toast_label = Label.new()
	p.add_child(toast_label)


## Petite confirmation en haut de l'écran, ex. toast("Copié : 428,6 ms").
func toast(txt: String) -> void:
	toast_label.text = txt
	var p := toast_label.get_parent() as Control
	if _toast_tw:
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_property(p, "modulate:a", 1.0, .15)
	_toast_tw.tween_interval(1.6)
	_toast_tw.tween_property(p, "modulate:a", 0.0, .5)
