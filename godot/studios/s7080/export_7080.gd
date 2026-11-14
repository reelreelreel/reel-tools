class_name Export7080
extends Node3D
## Module Export du studio 70/80 : tableau en liège accroché au mur, avec des fiches punaisées.
## - Fiche SESSION : artiste, titre (clic + clavier, Entrée = suivant), version (v− / v+), fréquence
##   d'échantillonnage et format (clic ou molette pour changer).
## - Étiquettes « ORDRE DU NOM » : on les glisse les unes sur les autres pour choisir l'ordre des éléments.
## - Post-it MIX et MASTER : le nom de fichier prêt à coller ; clic = copie + coche « exporté ».
## - Archives : pile de fiches des sessions précédentes ; clic = la rouvrir (la session en cours est archivée).
##   Pastille « + » = nouvelle session.
##
## Repère local : face du tableau vers +Z (+X = vers la droite quand on le regarde).

const BW := .9
const BH := .62
const RATES := [44.1, 48.0, 88.2, 96.0]
const FORMATS := ["WAV 16", "WAV 24", "WAV 32f", "AIFF 24", "MP3 320"]
const TYPES := ["Mix", "Master"]
const ELEMENTS := {"artist": "Artist", "title": "Title", "type": "Type", "rate": "kHz", "format": "Format", "version": "v"}
const DEFAULT_ORDER := ["artist", "title", "type", "rate", "format", "version"]
const MAX_HISTORY := 8

var artist := "Artist"
var title := "Title"
var version := 1
var rate_ix := 1
var fmt_ix := 1
var order: Array = DEFAULT_ORDER.duplicate()
var history: Array = []    # [{artist, title, version, rate_ix, fmt_ix}]
var done := {"Mix": false, "Master": false}
var active := ""           # champ en cours de saisie
var session: TexLib.LiveCanvas
var notes := {}            # type -> LiveCanvas
var tags_canvas: Array = []   # LiveCanvas par emplacement
var tag_nodes: Array[Node3D] = []
var hist_canvas: Array = []
var _drag_tag := -1
var _blink := -1
var _caret_on := false

# disposition (mètres, repère du tableau)
const SESSION_AT := Vector2(-.25, .13)
const SESSION_SIZE := Vector2(.34, .3)
const TAG_Y := -.09
const TAG_X0 := -.4
const TAG_STEP := .068
const HIST_AT := Vector2(-.3, -.225)


func _init(walnut: Material) -> void:
	name = "Export7080"
	_load()
	ready.connect(func(): Mk.add_pick(self, "m:export", 1), CONNECT_ONE_SHOT)
	Mk.mi(Mk.rounded_box(Vector3(BW + .04, BH + .04, .025), .006, walnut, 2), null, Vector3(0, 0, .0125), self)
	var cork := Tex.canvas(768, 530, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xb88a58))
		var r := Tex.rng(404)
		for i in 11000:
			var c := Mk.c(0xd8a870) if r.randf() > .5 else Mk.c(0x7a5430)
			c.a = .35 + r.randf() * .4
			ci.draw_circle(Vector2(r.randf() * w, r.randf() * h), .8 + r.randf() * 2.4, c)
		for i in 40:
			ci.draw_circle(Vector2(r.randf() * w, r.randf() * h), 1.6, Color(0, 0, 0, .5))
		Tex.grime(ci, w, h, 405, 2))
	Mk.mi(Mk.quad(BW, BH), Mk.mat(Color.WHITE, .95, 0.0, {"map": cork}), Vector3(0, 0, .0255), self)
	_build_session()
	_build_tags()
	_build_notes()
	_build_history()
	_build_buttons()
	_refresh()


# ---------------------------------------------------------------- construction
func _paper(tex: Texture2D, at: Vector2, size: Vector2, rot: float, z := .028) -> MeshInstance3D:
	var sm := ShaderMaterial.new()
	sm.shader = load("res://core/shaders/paper.gdshader")
	sm.set_shader_parameter("paper_tex", tex)
	var c := Mk.mi(Mk.quad(size.x, size.y), sm, Vector3(at.x, at.y, z), self)
	c.rotation.z = rot
	return c


func _pin(at: Vector3, col: Color, parent: Node3D = null) -> void:
	var h := Mk.mi(Mk.sphere(.007, 12, 6), Mk.mat(col, .3, 0.0, {"clearcoat": .8}), at + Vector3(0, 0, .004), parent if parent else self)
	h.scale = Vector3(1, 1, .7)


func _zone(at: Vector2, size: Vector2, action: String) -> void:
	var z := Node3D.new()
	z.position = Vector3(at.x, at.y, .03)
	add_child(z)
	var mi := Mk.mi(Mk.quad(size.x, size.y), Mk.mat(Color(0, 0, 0, 0), 1.0, 0.0, {"alpha": 0.0}), Vector3.ZERO, z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Mk.add_pick_later(z, action, .003)


func _build_session() -> void:
	session = Tex.live(512, 452, _draw_session)
	_paper(session.texture, SESSION_AT, SESSION_SIZE, -.02)
	_pin(Vector3(SESSION_AT.x - SESSION_SIZE.x / 2 + .02, SESSION_AT.y + SESSION_SIZE.y / 2 - .015, .03), Mk.c(0xd43a26))
	var rows := ["field:artist", "field:title", "version", "rate", "format"]
	for i in rows.size():
		var y_px := 88.0 + i * 50.0
		var y := SESSION_AT.y + SESSION_SIZE.y / 2 - y_px / 452.0 * SESSION_SIZE.y
		_zone(Vector2(SESSION_AT.x, y), Vector2(SESSION_SIZE.x - .02, .03), "export:" + rows[i])


func _build_tags() -> void:
	var strip := Tex.canvas(768, 64, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xece4d2))
		Tex.silk(ci, "NAME ORDER  ·  drag a tag onto another", 16, h / 2.0, 26, Color(.25, .25, .25, .85), "left", 600))
	_paper(strip, Vector2(TAG_X0 + TAG_STEP * 2.5, TAG_Y + .045), Vector2(.42, .035), 0.0, .027)
	var pin_cols := [Mk.c(0x2a6ab0), Mk.c(0xd43a26), Mk.c(0xf2c230), Mk.c(0x3a8a4a)]
	var rots := [.04, -.03, .02, -.05, .03, -.02]
	for i in ELEMENTS.size():
		var idx := i
		var lc := Tex.live(160, 96, func(ci, w, h): _draw_tag(ci, w, h, idx))
		tags_canvas.append(lc)
		var holder := Node3D.new()
		holder.position = Vector3(TAG_X0 + i * TAG_STEP, TAG_Y, .029)
		add_child(holder)
		var sm := ShaderMaterial.new()
		sm.shader = load("res://core/shaders/paper.gdshader")
		sm.set_shader_parameter("paper_tex", lc.texture)
		var card := Mk.mi(Mk.quad(.06, .036), sm, Vector3.ZERO, holder)
		card.rotation.z = rots[i]
		_pin(Vector3(0, .012, .001), pin_cols[i % 4], holder)
		tag_nodes.append(holder)
		Mk.add_pick_later(holder, "export:tag:%d" % i, .004)


func _build_notes() -> void:
	var cols := {"Mix": Mk.c(0xf2dc5a), "Master": Mk.c(0xf2a35a)}
	var pos := {"Mix": Vector2(.3, .15), "Master": Vector2(.3, -.13)}
	for tp in TYPES:
		var lc := Tex.live(384, 384, func(ci, w, h): _draw_note(ci, w, h, tp, cols[tp]))
		notes[tp] = lc
		var rot := .035 if tp == "Mix" else -.04
		var n := _paper(lc.texture, pos[tp], Vector2(.24, .24), rot)
		_pin(Vector3(pos[tp].x, pos[tp].y + .105, .03), Mk.c(0x2a6ab0) if tp == "Mix" else Mk.c(0xf2c230))
		Mk.add_pick_later(n, "export:copy:" + tp, .0)


func _build_history() -> void:
	var lab := Tex.canvas(256, 48, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xece4d2))
		Tex.silk(ci, "ARCHIVES", w / 2.0, h / 2.0, 30, Color(.25, .25, .25, .85), "center", 700))
	_paper(lab, HIST_AT + Vector2(-.03, .068), Vector2(.12, .022), -.03, .027)
	for i in 4:
		var idx := i
		var lc := Tex.live(320, 200, func(ci, w, h): _draw_hist(ci, w, h, idx))
		hist_canvas.append(lc)
		var holder := Node3D.new()
		holder.position = Vector3(HIST_AT.x + i * .045, HIST_AT.y - i * .008, .028 + i * .0012)
		holder.rotation.z = -.12 + i * .08
		add_child(holder)
		var sm := ShaderMaterial.new()
		sm.shader = load("res://core/shaders/paper.gdshader")
		sm.set_shader_parameter("paper_tex", lc.texture)
		Mk.mi(Mk.quad(.15, .094), sm, Vector3.ZERO, holder)
		Mk.add_pick_later(holder, "export:hist:%d" % i, .0)
	_pin(Vector3(HIST_AT.x + .07, HIST_AT.y + .04, .034), Mk.c(0x3a8a4a))


func _build_buttons() -> void:
	var btns := [[Vector2(-.035, .19), "export:new", "+", Mk.c(0xd43a26)], [Vector2(-.035, .11), "export:v_up", "v+", Mk.c(0x3a8a4a)],
		[Vector2(-.035, .05), "export:v_down", "v−", Mk.c(0x3a8ad0)]]
	for b in btns:
		var t := Tex.canvas(128, 128, func(ci, w, h):
			ci.draw_circle(Vector2(64, 64), 62, b[3])
			Tex.silk(ci, b[2], 64, 62, 60 if b[2] == "+" else 52, Color(1, 1, 1, .95), "center", 700, "caveat"), true)
		var m := Mk.mat(Color.WHITE, .6, 0.0, {"map": t})
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		var dot := Mk.mi(Mk.quad(.042, .042), m, Vector3(b[0].x, b[0].y, .03), self)
		Mk.add_pick_later(dot, b[1], .004)
	var hint := Tex.canvas(256, 64, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xf4f0e6))
		Tex.silk(ci, "new session", w / 2.0, h / 2.0, 34, Color(.08, .1, .3, .9), "center", 600, "caveat"))
	_paper(hint, Vector2(-.035, .235), Vector2(.075, .019), .05, .027)
	var pol := Tex.canvas(160, 190, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xf2eee4))
		ci.draw_rect(Rect2(10, 10, 140, 140), Mk.c(0x3a2414))
		ci.draw_circle(Vector2(80, 70), 30, Mk.c(0x8a5a2a))
		ci.draw_rect(Rect2(40, 100, 80, 50), Mk.c(0x6a3a1a))
		Tex.silk(ci, "session 74", 80, 170, 22, Mk.c(0x1a1a3a), "center", 600, "caveat"))
	var p := Mk.mi(Mk.quad(.075, .09), Mk.mat(Color.WHITE, .4, 0.0, {"map": pol}), Vector3(.05, -.2, .028), self)
	p.rotation.z = .12
	_pin(Vector3(.05, -.162, .03), Mk.c(0x3a8a4a))


# ---------------------------------------------------------------- dessins
func _draw_session(ci: CanvasItem, w: float, h: float) -> void:
	ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xf4f0e6))
	ci.draw_rect(Rect2(0, 0, w, 54), Mk.c(0xd8c8b0))
	for i in 6:
		var y := 88.0 + i * 50.0 + 24.0
		ci.draw_line(Vector2(10, y), Vector2(w - 10, y), Color(.35, .5, .75, .45), 2.0)
	Tex.silk(ci, "SESSION · EXPORT", w / 2.0, 28, 30, Color(.1, .1, .1, .8), "center", 700)
	var ink := Color(.08, .1, .35, .95)
	var rows := [["Artist", artist, "artist"], ["Title", title, "title"], ["Version", "v%d" % version, ""],
		["Sample rate", _rate_txt(), ""], ["Format", FORMATS[fmt_ix], ""]]
	for i in rows.size():
		var y := 88.0 + i * 50.0
		if active == rows[i][2] and active != "":
			ci.draw_rect(Rect2(8, y - 22, w - 16, 46), Color(1, .85, .2, .3))
		Tex.silk(ci, rows[i][0] + " :", 18, y, 26, Color(.3, .3, .3, .8), "left", 600)
		var val: String = rows[i][1]
		if active == rows[i][2] and active != "" and _caret_on:
			val += "|"
		Tex.silk(ci, val, 160, y, 40, ink, "left", 600, "caveat")
	Tex.silk(ci, "click a line  ·  Enter = next", w / 2.0, h - 20, 18, Color(.3, .3, .3, .6), "center", 500)


func _draw_tag(ci: CanvasItem, w: float, h: float, slot: int) -> void:
	var key: String = order[slot]
	var lifted := slot == _drag_tag
	ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xffe9a0) if lifted else Mk.c(0xf4f0e6))
	ci.draw_rect(Rect2(0, 0, w, h), Color(.4, .3, .2, .5), false, 3.0)
	Tex.silk(ci, ELEMENTS[key], w / 2.0, h / 2.0 + 6, 40, Color(.08, .1, .35, .95), "center", 600, "caveat")


func _draw_note(ci: CanvasItem, w: float, h: float, tp: String, col: Color) -> void:
	ci.draw_rect(Rect2(0, 0, w, h), col)
	ci.draw_rect(Rect2(0, 0, w, 30), col.darkened(.08))
	var ink := Color(.08, .1, .3, .95)
	Tex.silk(ci, tp.to_upper(), 24, 62, 52, ink, "left", 700, "caveat")
	var lines := _wrap(filename(tp), 22)
	for i in mini(lines.size(), 5):
		Tex.silk(ci, lines[i], 24, 125 + i * 40, 34, ink, "left", 600, "caveat")
	if done[tp]:
		ci.draw_polyline(PackedVector2Array([Vector2(260, 310), Vector2(295, 350), Vector2(365, 265)]), Color(.75, .1, .08, .9), 12.0, true)
		Tex.silk(ci, "bounced", 235, 362, 30, Color(.75, .1, .08, .9), "right", 700, "caveat")
	else:
		Tex.silk(ci, "click = copy", 24, h - 26, 26, Color(.08, .1, .3, .55), "left", 600, "caveat")


func _draw_hist(ci: CanvasItem, w: float, h: float, i: int) -> void:
	# la fiche du dessus (indice 3) est la plus récente
	var k := history.size() - 4 + i
	var has := k >= 0 and k < history.size()
	ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xe8e2d2) if has else Mk.c(0xd8d0bc))
	for y in range(40, int(h), 32):
		ci.draw_line(Vector2(6, y), Vector2(w - 6, y), Color(.35, .5, .75, .3), 1.5)
	if has:
		var s: Dictionary = history[k]
		Tex.silk(ci, s.artist, 14, 30, 34, Color(.08, .1, .35, .95), "left", 600, "caveat")
		Tex.silk(ci, s.title, 14, 76, 34, Color(.08, .1, .35, .95), "left", 600, "caveat")
		Tex.silk(ci, "v%d" % s.version, w - 14, h - 28, 34, Color(.75, .1, .08, .85), "right", 600, "caveat")
	else:
		Tex.silk(ci, "—", w / 2.0, h / 2.0, 30, Color(.4, .4, .4, .5), "center")


static func _wrap(s: String, n: int) -> Array:
	var out := []
	var cur := ""
	for word in s.split(" "):
		if (cur + " " + word).strip_edges().length() > n and cur != "":
			out.append(cur)
			cur = word
		else:
			cur = (cur + " " + word).strip_edges()
	if cur != "":
		out.append(cur)
	return out


# ---------------------------------------------------------------- nom de fichier
func _rate_txt() -> String:
	var r: float = RATES[rate_ix]
	return ("%skHz" % str(r)).replace(".0kHz", "kHz")


func _format_token() -> String:
	return ["16bit", "24bit", "32f", "AIFF 24bit", "MP3 320"][fmt_ix]


## Nom de fichier dans l'ordre des étiquettes. « Artiste - Titre » quand les deux se suivent.
func filename(tp: String) -> String:
	var bad := ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]
	var a := artist.strip_edges()
	var t := title.strip_edges()
	for c in bad:
		a = a.replace(c, "")
		t = t.replace(c, "")
	var tok := {"artist": a, "title": t, "type": "[%s]" % tp, "rate": _rate_txt(), "format": _format_token(), "version": "v%d" % version}
	var out := ""
	var prev := ""
	for key in order:
		var v: String = tok[key]
		if v == "":
			continue
		if out != "":
			out += " - " if (prev == "artist" and key == "title") or (prev == "title" and key == "artist") else " "
		out += v
		prev = key
	return out


# ---------------------------------------------------------------- état
func _snapshot() -> Dictionary:
	return {"artist": artist, "title": title, "version": version, "rate_ix": rate_ix, "fmt_ix": fmt_ix}


func _restore(s: Dictionary) -> void:
	artist = s.artist
	title = s.title
	version = int(s.version)
	rate_ix = int(s.rate_ix)
	fmt_ix = int(s.get("fmt_ix", 1))


func _is_blank() -> bool:
	return (artist == "Artist" or artist == "") and (title == "Title" or title == "")


func _load() -> void:
	artist = Store.get_v("exp_artist", artist)
	title = Store.get_v("exp_title", title)
	version = int(Store.get_v("exp_version", version))
	rate_ix = int(Store.get_v("exp_rate", rate_ix))
	fmt_ix = int(Store.get_v("exp_format", fmt_ix))
	order = Store.get_v("exp_order", DEFAULT_ORDER.duplicate())
	if order.size() != DEFAULT_ORDER.size():
		order = DEFAULT_ORDER.duplicate()
	history = Store.get_v("exp_history", [])


func _save() -> void:
	Store.set_v("exp_artist", artist)
	Store.set_v("exp_title", title)
	Store.set_v("exp_version", version)
	Store.set_v("exp_rate", rate_ix)
	Store.set_v("exp_format", fmt_ix)
	Store.set_v("exp_order", order)
	Store.set_v("exp_history", history)


func _refresh() -> void:
	session.redraw()
	for lc in notes.values():
		lc.redraw()
	for lc in tags_canvas:
		lc.redraw()
	for lc in hist_canvas:
		lc.redraw()
	_save()


func _undone() -> void:
	done = {"Mix": false, "Master": false}


# ---------------------------------------------------------------- interactions
func on_action(a: String) -> void:
	if a.begins_with("field:"):
		active = a.substr(6)
		if active == "artist" and artist == "Artist":
			artist = ""
		elif active == "title" and title == "Title":
			title = ""
	elif a == "rate":
		rate_ix = (rate_ix + 1) % RATES.size()
		active = ""
		_undone()
	elif a == "format":
		fmt_ix = (fmt_ix + 1) % FORMATS.size()
		active = ""
		_undone()
	elif a == "version" or a == "v_up" or a == "v_down":
		version = clampi(version + (-1 if a == "v_down" else 1), 1, 99)
		active = ""
		_undone()
	elif a.begins_with("copy:"):
		var tp := a.substr(5)
		DisplayServer.clipboard_set(filename(tp))
		Toast.say("Copié : " + filename(tp))
		done[tp] = true
		active = ""
	elif a == "new":
		if not _is_blank():
			_archive(_snapshot())
		artist = ""
		title = "Title"
		version = 1
		active = "artist"
		_undone()
	elif a.begins_with("hist:"):
		var k := history.size() - 4 + int(a.substr(5))
		if k >= 0 and k < history.size():
			var picked: Dictionary = history[k]
			history.remove_at(k)
			if not _is_blank():
				_archive(_snapshot())
			_restore(picked)
			active = ""
			_undone()
	elif a.begins_with("tag:"):
		_drag_tag = -1  # simple clic sur une étiquette : rien
	_refresh()


func _archive(s: Dictionary) -> void:
	for i in range(history.size() - 1, -1, -1):
		if history[i].artist == s.artist and history[i].title == s.title:
			history.remove_at(i)
	history.append(s)
	while history.size() > MAX_HISTORY:
		history.pop_front()


func on_press(a: String) -> void:
	_drag_tag = int(a.substr(4)) if a.begins_with("tag:") else -1
	if _drag_tag >= 0:
		tags_canvas[_drag_tag].redraw()


func on_drag_start(a: String) -> bool:
	return a.begins_with("tag:")


func on_drag(_rel: Vector2, _fine: bool) -> void:
	if _drag_tag >= 0:
		tag_nodes[_drag_tag].position.z = .04


## Étiquette lâchée sur une autre : elle prend sa place (les autres se décalent).
func on_drop(target: String) -> void:
	var from := _drag_tag
	_drag_tag = -1
	if from < 0:
		return
	tag_nodes[from].position.z = .029
	if target.begins_with("export:tag:"):
		var to := int(target.substr(11))
		if to != from:
			var key: String = order[from]
			order.remove_at(from)
			order.insert(to, key)
			_undone()
	_refresh()


func on_wheel(a: String, dir: float, _fine: bool) -> void:
	if a == "rate":
		rate_ix = posmod(rate_ix + int(dir), RATES.size())
	elif a == "format":
		fmt_ix = posmod(fmt_ix + int(dir), FORMATS.size())
	elif a == "version":
		version = clampi(version + int(dir), 1, 99)
	else:
		return
	_undone()
	_refresh()


func on_key(e: InputEventKey) -> bool:
	if active == "":
		return false
	var cur: String = artist if active == "artist" else title
	match e.keycode:
		KEY_ENTER, KEY_KP_ENTER, KEY_TAB:
			active = "title" if active == "artist" else ""
			if active == "title" and title == "Title":
				title = ""
		KEY_ESCAPE:
			active = ""
		KEY_BACKSPACE:
			_edit(cur.left(-1))
		_:
			if e.unicode < 32:
				return true
			_edit(cur + char(e.unicode))
	_refresh()
	return true


func _edit(v: String) -> void:
	if active == "artist":
		artist = v.left(40)
	elif active == "title":
		title = v.left(60)
	_undone()


func animate(t: float, _dt: float, _reduced: bool) -> void:
	var b := int(t * 2.0)
	if active != "" and b != _blink:
		_blink = b
		_caret_on = b % 2 == 0
		session.redraw()
