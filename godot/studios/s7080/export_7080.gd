class_name Export7080
extends Node3D
## Module Export du studio 70/80 : tableau en liège accroché au mur, avec des fiches punaisées.
## - Fiche SESSION : artiste, titre, version, fréquence d'échantillonnage. On clique une ligne puis on
##   tape au clavier (Entrée / Tab = ligne suivante). Version : v− / v+. Fréquence : clic = valeur suivante.
## - Post-it MIX et MASTER : le nom de fichier prêt à coller, au format « Artiste - Titre [Mix] 48kHz v3 ».
##   Clic = copie dans le presse-papiers + coche « exporté ». Changer de version décoche tout.
##
## Repère local : face du tableau vers +Z. Actions : "export:field:<artist|title>", "export:rate",
## "export:v_down", "export:v_up", "export:copy:<Mix|Master>".

const BW := .62
const BH := .56
const RATES := [44.1, 48.0, 88.2, 96.0]
const TYPES := ["Mix", "Master"]

var artist := "Artiste"
var title := "Titre"
var version := 1
var rate_ix := 1
var done := {"Mix": false, "Master": false}
var active := ""          # champ en cours de saisie
var session: TexLib.LiveCanvas
var notes := {}           # type -> LiveCanvas
var _caret := 0.0


func _init(walnut: Material) -> void:
	name = "Export7080"
	artist = Store.get_v("exp_artist", artist)
	title = Store.get_v("exp_title", title)
	version = int(Store.get_v("exp_version", version))
	rate_ix = int(Store.get_v("exp_rate", rate_ix))
	ready.connect(func(): Mk.add_pick(self, "m:export", 1), CONNECT_ONE_SHOT)
	# cadre bois + fond en liège clair
	Mk.mi(Mk.rounded_box(Vector3(BW + .04, BH + .04, .025), .006, walnut, 2), null, Vector3(0, 0, .0125), self)
	var cork := Tex.canvas(512, 460, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xb88a58))
		var r := Tex.rng(404)
		for i in 7000:
			var c := Mk.c(0xd8a870) if r.randf() > .5 else Mk.c(0x7a5430)
			c.a = .35 + r.randf() * .4
			ci.draw_circle(Vector2(r.randf() * w, r.randf() * h), .8 + r.randf() * 2.4, c)
		for i in 25:  # trous de punaises
			ci.draw_circle(Vector2(r.randf() * w, r.randf() * h), 1.6, Color(0, 0, 0, .5))
		Tex.grime(ci, w, h, 405, 1.5))
	Mk.mi(Mk.quad(BW, BH), Mk.mat(Color.WHITE, .95, 0.0, {"map": cork}), Vector3(0, 0, .0255), self)
	# fiche SESSION (bristol ligné)
	session = Tex.live(512, 380, _draw_session)
	_card(session.texture, Vector2(-.12, .1), Vector2(.3, .22), -.03, Mk.c(0xd43a26))
	# lignes cliquables (positions des lignes dessinées sur la fiche)
	for f in [[.159, "export:field:artist"], [.13, "export:field:title"], [.072, "export:rate"]]:
		_zone(Vector2(-.12, f[0]), Vector2(.28, .028), f[1])
	# v− / v+ : deux petites pastilles
	for b in [[-.02, "export:v_down", "v−", Mk.c(0x3a8ad0)], [.03, "export:v_up", "v+", Mk.c(0x3a8a4a)]]:
		var t := Tex.canvas(128, 128, func(ci, w, h):
			ci.draw_circle(Vector2(64, 64), 62, b[3])
			Tex.silk(ci, b[2], 64, 64, 54, Color(1, 1, 1, .95), "center", 700, "caveat"), true)
		var m := Mk.mat(Color.WHITE, .6, 0.0, {"map": t})
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		var dot := Mk.mi(Mk.quad(.045, .045), m, Vector3(b[0], -.07, .03), self)
		Mk.add_pick_later(dot, b[1], .004)
	# post-it MIX (jaune) et MASTER (orange)
	var cols := {"Mix": Mk.c(0xf2dc5a), "Master": Mk.c(0xf2a35a)}
	var pos := {"Mix": Vector2(.17, .1), "Master": Vector2(.17, -.13)}
	for tp in TYPES:
		var lc := Tex.live(384, 384, func(ci, w, h): _draw_note(ci, w, h, tp, cols[tp]))
		notes[tp] = lc
		var n := _card(lc.texture, pos[tp], Vector2(.22, .22), .04 if tp == "Mix" else -.05, Mk.c(0x2a6ab0) if tp == "Mix" else Mk.c(0xf2c230))
		Mk.add_pick_later(n, "export:copy:" + tp, .0)
	# décor : petite photo polaroid et ficelle
	var pol := Tex.canvas(160, 190, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xf2eee4))
		ci.draw_rect(Rect2(10, 10, 140, 140), Mk.c(0x3a2414))
		ci.draw_circle(Vector2(80, 70), 30, Mk.c(0x8a5a2a))
		ci.draw_rect(Rect2(40, 100, 80, 50), Mk.c(0x6a3a1a))
		Tex.silk(ci, "session 74", 80, 170, 22, Mk.c(0x1a1a3a), "center", 600, "caveat"))
	var p := Mk.mi(Mk.quad(.08, .095), Mk.mat(Color.WHITE, .4, 0.0, {"map": pol}), Vector3(-.2, -.17, .028), self)
	p.rotation.z = .12
	_pin(Vector3(-.2, -.13, .03), Mk.c(0x3a8a4a))
	_refresh()


## Carte en papier vivant, punaisée en haut. Renvoie le nœud de la carte.
func _card(tex: Texture2D, at: Vector2, size: Vector2, rot: float, pin_col: Color) -> MeshInstance3D:
	var sm := ShaderMaterial.new()
	sm.shader = load("res://core/shaders/paper.gdshader")
	sm.set_shader_parameter("paper_tex", tex)
	var c := Mk.mi(Mk.quad(size.x, size.y), sm, Vector3(at.x, at.y, .028), self)
	c.rotation.z = rot
	var pin_at := Vector2(-size.x / 2 + .02, size.y / 2 - .015).rotated(rot) if size.x > .25 else Vector2(0, size.y / 2 - .015).rotated(rot)
	_pin(Vector3(at.x + pin_at.x, at.y + pin_at.y, .03), pin_col)
	return c


func _pin(at: Vector3, col: Color) -> void:
	var h := Mk.mi(Mk.sphere(.007, 12, 6), Mk.mat(col, .3, 0.0, {"clearcoat": .8}), at + Vector3(0, 0, .004), self)
	h.scale = Vector3(1, 1, .7)


## Zone cliquable invisible (ligne de la fiche).
func _zone(at: Vector2, size: Vector2, action: String) -> void:
	var z := Node3D.new()
	z.position = Vector3(at.x, at.y, .03)
	add_child(z)
	var mi := Mk.mi(Mk.quad(size.x, size.y), Mk.mat(Color(0, 0, 0, 0), 1.0, 0.0, {"alpha": 0.0}), Vector3.ZERO, z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Mk.add_pick_later(z, action, .003)


# ---------------------------------------------------------------- dessin des fiches
func _draw_session(ci: CanvasItem, w: float, h: float) -> void:
	ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xf4f0e6))
	ci.draw_rect(Rect2(0, 0, w, 54), Mk.c(0xd8c8b0))
	for y in range(70, int(h), 50):
		ci.draw_line(Vector2(10, y + 30), Vector2(w - 10, y + 30), Color(.35, .5, .75, .45), 2.0)
	Tex.silk(ci, "SESSION · EXPORT", w / 2.0, 28, 30, Color(.1, .1, .1, .8), "center", 700)
	var ink := Color(.08, .1, .35, .95)
	var rows := [["Artiste", artist, "artist"], ["Titre", title, "title"], ["Version", "v%d" % version, ""], ["Fréquence", _rate_txt(), "rate"]]
	for i in rows.size():
		var y := 88.0 + i * 50.0
		Tex.silk(ci, rows[i][0] + " :", 18, y, 26, Color(.3, .3, .3, .8), "left", 600)
		var val: String = rows[i][1]
		if active == rows[i][2] and active != "" and int(_caret * 2.0) % 2 == 0:
			val += "|"
		Tex.silk(ci, val, 150, y, 40, ink, "left", 600, "caveat")
		if active == rows[i][2] and active != "":
			ci.draw_rect(Rect2(8, y - 22, w - 16, 46), Color(1, .85, .2, .25))
	Tex.silk(ci, "clic sur une ligne puis tape  ·  Entrée = suivant", w / 2.0, h - 18, 18, Color(.3, .3, .3, .6), "center", 500)


func _draw_note(ci: CanvasItem, w: float, h: float, tp: String, col: Color) -> void:
	ci.draw_rect(Rect2(0, 0, w, h), col)
	ci.draw_rect(Rect2(0, 0, w, 30), col.darkened(.08))
	var ink := Color(.08, .1, .3, .95)
	Tex.silk(ci, tp.to_upper(), 24, 62, 52, ink, "left", 700, "caveat")
	# nom de fichier sur plusieurs lignes
	var name := filename(tp)
	var lines := _wrap(name, 22)
	for i in lines.size():
		Tex.silk(ci, lines[i], 24, 130 + i * 44, 36, ink, "left", 600, "caveat")
	if done[tp]:
		ci.draw_polyline(PackedVector2Array([Vector2(250, 300), Vector2(290, 345), Vector2(365, 250)]), Color(.75, .1, .08, .9), 12.0, true)
		Tex.silk(ci, "exporté", 220, 360, 30, Color(.75, .1, .08, .9), "right", 700, "caveat")
	else:
		Tex.silk(ci, "clic = copier", 24, h - 26, 26, Color(.08, .1, .3, .55), "left", 600, "caveat")


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


func _rate_txt() -> String:
	var r: float = RATES[rate_ix]
	return ("%skHz" % str(r)).replace(".0kHz", "kHz")


## Nom de fichier prêt à l'emploi : « Artiste - Titre [Mix] 48kHz v3 ».
func filename(tp: String) -> String:
	var bad := ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]
	var a := artist.strip_edges()
	var t := title.strip_edges()
	for c in bad:
		a = a.replace(c, "")
		t = t.replace(c, "")
	return "%s - %s [%s] %s v%d" % [a, t, tp, _rate_txt(), version]


func _refresh() -> void:
	session.redraw()
	for lc in notes.values():
		lc.redraw()
	Store.set_v("exp_artist", artist)
	Store.set_v("exp_title", title)
	Store.set_v("exp_version", version)
	Store.set_v("exp_rate", rate_ix)


# ---------------------------------------------------------------- interactions
func on_action(a: String) -> void:
	if a.begins_with("field:"):
		active = a.substr(6)
		# un champ encore au texte d'exemple se vide au premier clic
		if active == "artist" and artist == "Artiste":
			artist = ""
		elif active == "title" and title == "Titre":
			title = ""
	elif a == "rate":
		rate_ix = (rate_ix + 1) % RATES.size()
		active = ""
	elif a == "v_down" or a == "v_up":
		version = clampi(version + (1 if a == "v_up" else -1), 1, 99)
		done = {"Mix": false, "Master": false}
		active = ""
	elif a.begins_with("copy:"):
		var tp := a.substr(5)
		DisplayServer.clipboard_set(filename(tp))
		done[tp] = true
		active = ""
	_refresh()


func on_drag_start(_a: String) -> bool:
	return false


func on_drag(_rel: Vector2, _fine: bool) -> void:
	pass


func on_wheel(a: String, dir: float, _fine: bool) -> void:
	if a == "rate":
		rate_ix = posmod(rate_ix + int(dir), RATES.size())
		_refresh()


func on_key(e: InputEventKey) -> bool:
	if active == "":
		return false
	var cur: String = artist if active == "artist" else title
	match e.keycode:
		KEY_ENTER, KEY_KP_ENTER, KEY_TAB:
			active = "title" if active == "artist" else ""
			if active == "title" and title == "Titre":
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
	done = {"Mix": false, "Master": false}


var _blink := -1


func animate(t: float, _dt: float, _reduced: bool) -> void:
	var b := int(t * 2.0)
	if active != "" and b != _blink:
		_blink = b
		_caret = t
		session.redraw()
