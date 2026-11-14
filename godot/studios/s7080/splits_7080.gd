class_name Splits7080
extends Node3D
## Carnet de splits : un carnet de cuir ouvert sur le pupitre. Une double page par titre
## (gauche : titre, artiste, date, mode, notes ; droite : ayants droit et parts).
## Deux modes : SACEM (A / C / AC / E, total 100 %) et international (writers et publishers,
## chacun à 100 %). Partage égal au centième (ex. 4,17 / 4,16), récap texte et PDF.
## Repère local : plan XY = pages, +Z = vers le lecteur (posé par le studio sur le pupitre).

const PW := .215            # une page
const PH := .295
const GUTTER := .006
const CW := 600             # toile d'une page (px)
const CH := 820
const MAX_ROWS := 8
const ROW_Y0 := 168.0
const ROW_H := 56.0
const ROLES := {"sacem": ["A", "C", "AC", "E"], "intl": ["Writer", "Publisher"]}
const ROLE_FR := {"A": "Auteur", "C": "Compositeur", "AC": "Auteur-compositeur", "E": "Éditeur"}
const INK := Color(.07, .1, .32, .95)
const PENCIL := Color(.25, .25, .28, .7)
const RED := Color(.72, .1, .08, .92)
const GREEN := Color(.1, .42, .2, .92)

var pages: Array = []       # [{title, artist, date, notes, mode, rows: [{name, role, share}]}]
var cur := 0
var active := ""            # "title" | "artist" | "date" | "notes" | "r3:name" | "r3:share"
var buf := ""               # saisie en cours d'une part
var left: TexLib.LiveCanvas
var right: TexLib.LiveCanvas
var dialog: FileDialog
var _left_pivot: Node3D
var _right_pivot: Node3D
var _leaf: Node3D
var _turn := 0.0            # 0 = rien ; >0 = page qui tourne (temps restant)
var _turn_dir := 1
var _turn_swapped := false
var _turn_target := 0
var _blink := -1
var _caret_on := false
var _pdf := PackedByteArray()


func _init(walnut: Material) -> void:
	name = "Splits7080"
	_load()
	ready.connect(func(): Mk.add_pick(self, "m:splits", 1), CONNECT_ONE_SHOT)
	_build_book(walnut)
	_build_zones()
	dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.filters = PackedStringArray(["*.pdf ; PDF"])
	dialog.title = "Enregistrer la feuille de splits (PDF)"
	dialog.file_selected.connect(write_pdf)
	add_child(dialog)
	_refresh()


# ---------------------------------------------------------------- construction
func _build_book(_walnut: Material) -> void:
	var leather: StandardMaterial3D = Mk.pbr("leather_brown", .2, {"wear": .7, "tint": Mk.c(0x5a3420), "rough": .8, "clearcoat": .25, "clearcoat_rough": .5, "normal_scale": 1.2})
	var edge := Mk.mat(Mk.c(0xe8dcc0), .9)
	# couverture ouverte : deux plats légèrement relevés vers l'extérieur + dos
	for s in [-1, 1]:
		var plat := Mk.mi(Mk.rounded_box(Vector3(PW + .012, PH + .014, .004), .003, leather, 2), null, Vector3(s * (PW / 2 + .004), 0, .002), self)
		plat.rotation.y = -s * .035
	Mk.mi(Mk.rounded_box(Vector3(.016, PH + .014, .004), .002, leather, 2), null, Vector3(0, 0, .0005), self)
	# coutures sur le bord des plats (petits points clairs)
	var stitch := Mk.mat(Mk.c(0xc9a878), .7)
	for s in [-1, 1]:
		var x0: float = s * (PW + .008)
		for i in 34:
			var y := -PH / 2 + .004 + i * (PH / 33.0)
			Mk.mi(Mk.box(Vector3(.0012, .0045, .0008)), stitch, Vector3(x0, y, .0045 + absf(x0) * .035), self)
	# blocs de pages (tranche crème) + pages vivantes, chacune sur un pivot au dos
	_left_pivot = _page_block(-1, edge)
	_right_pivot = _page_block(1, edge)
	left = Tex.live(CW, CH, _draw_left)
	right = Tex.live(CW, CH, _draw_right)
	_page_quad(left.texture, _left_pivot, -1)
	_page_quad(right.texture, _right_pivot, 1)
	# feuille qui tourne (cachée au repos)
	_leaf = Node3D.new()
	_leaf.position = Vector3(0, 0, .0125)
	_leaf.visible = false
	add_child(_leaf)
	var blank := Tex.canvas(300, 410, func(ci, w, h):
		_paper_bg(ci, w, h, 0.5))
	Mk.mi(Mk.quad(PW, PH), Mk.mat(Color.WHITE, .9, 0.0, {"map": blank, "cull_off": true}), Vector3(PW / 2 + GUTTER / 2, 0, 0), _leaf)
	# signet en ruban rouge qui dépasse en bas
	var ribbon := Mk.mat(Mk.c(0x8a1410), .55, 0.0, {"clearcoat": .3})
	var rb := Mk.mi(Mk.box(Vector3(.006, .06, .0008)), ribbon, Vector3(.012, -PH / 2 - .022, .011), self)
	rb.rotation.z = .12
	# stylo plume couché dans la pliure
	_pen()


func _page_block(s: int, edge: Material) -> Node3D:
	var p := Node3D.new()
	p.position = Vector3(s * GUTTER / 2, 0, .004)
	p.rotation.y = -s * .05   # les pages remontent vers l'extérieur (le livre « s'ouvre »)
	add_child(p)
	Mk.mi(Mk.box(Vector3(PW, PH, .008)), edge, Vector3(s * PW / 2, 0, .004), p)
	return p


func _page_quad(tex: Texture2D, pivot: Node3D, s: int) -> void:
	var sm := ShaderMaterial.new()
	sm.shader = load("res://core/shaders/paper.gdshader")
	sm.set_shader_parameter("paper_tex", tex)
	Mk.mi(Mk.quad(PW, PH), sm, Vector3(s * PW / 2, 0, .0083), pivot)


func _pen() -> void:
	var g := Node3D.new()
	g.position = Vector3(.004, .01, .016)
	g.rotation.z = .06
	add_child(g)
	var resin := Mk.mat(Mk.c(0x0c0c0e), .18, 0.0, {"clearcoat": 1.0, "clearcoat_rough": .1})
	var gold := Mk.mat(Mk.c(0xc9a050), .25, 1.0)
	var body := Mk.mi(Mk.cyl(.0055, .0048, .095, 24), resin, Vector3(0, -.02, 0), g)
	body.rotation.x = 0
	Mk.mi(Mk.cyl(.006, .006, .06, 24), resin, Vector3(0, .055, 0), g)           # capuchon
	Mk.mi(Mk.cyl(.0062, .0062, .004, 24), gold, Vector3(0, .026, 0), g)          # bague
	Mk.mi(Mk.cyl(.0063, .0063, .0025, 24), gold, Vector3(0, .08, 0), g)
	Mk.mi(Mk.sphere(.006, 16, 8), resin, Vector3(0, .085, 0), g)
	var clip := Mk.mi(Mk.box(Vector3(.0024, .048, .0015)), gold, Vector3(0, .058, .0065), g)
	clip.rotation.x = .03
	Mk.mi(Mk.cyl(.0045, .002, .016, 16), resin, Vector3(0, -.075, 0), g)          # section
	Mk.mi(Mk.cyl(.0018, .0002, .012, 12), gold, Vector3(0, -.089, 0), g)          # plume


## Zone cliquable en pixels d'une page (rect = x, y, w, h dans la toile CW×CH).
func _zone(s: int, r: Rect2, action: String) -> void:
	var pivot := _left_pivot if s < 0 else _right_pivot
	var z := Node3D.new()
	var cx := (r.position.x + r.size.x / 2) / CW * PW - PW / 2
	var cy := PH / 2 - (r.position.y + r.size.y / 2) / CH * PH
	z.position = Vector3(s * PW / 2 + cx, cy, .0095)
	pivot.add_child(z)
	var mi := Mk.mi(Mk.quad(r.size.x / CW * PW, r.size.y / CH * PH), Mk.mat(Color(0, 0, 0, 0), 1.0, 0.0, {"alpha": 0.0}), Vector3.ZERO, z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Mk.add_pick_later(z, "splits:" + action, .001)


func _build_zones() -> void:
	_zone(-1, Rect2(30, 112, 540, 54), "field:title")
	_zone(-1, Rect2(30, 172, 540, 54), "field:artist")
	_zone(-1, Rect2(30, 232, 540, 54), "field:date")
	_zone(-1, Rect2(150, 300, 190, 56), "mode:sacem")
	_zone(-1, Rect2(350, 300, 230, 56), "mode:intl")
	_zone(-1, Rect2(30, 400, 540, 340), "field:notes")
	_zone(-1, Rect2(20, 760, 200, 50), "prev")
	_zone(-1, Rect2(380, 760, 200, 50), "delete_page")
	for i in MAX_ROWS:
		var y := ROW_Y0 + i * ROW_H - 30
		# les colonnes changent selon le mode : on pose des zones fines et on les lit à l'action
		_zone(1, Rect2(20, y, 250, ROW_H), "row:%d:a" % i)
		_zone(1, Rect2(270, y, 95, ROW_H), "row:%d:b" % i)
		_zone(1, Rect2(365, y, 95, ROW_H), "row:%d:c" % i)
		_zone(1, Rect2(460, y, 100, ROW_H), "row:%d:d" % i)
		_zone(1, Rect2(560, y, 36, ROW_H), "del:%d" % i)
	_zone(1, Rect2(20, 655, 135, 60), "add")
	_zone(1, Rect2(162, 655, 135, 60), "equal")
	_zone(1, Rect2(304, 655, 135, 60), "copy")
	_zone(1, Rect2(446, 655, 135, 60), "pdf")
	_zone(1, Rect2(380, 760, 200, 50), "next")


# ---------------------------------------------------------------- dessin
func _paper_bg(ci: CanvasItem, w: float, h: float, k: float, y0 := 112.0, step := 52.0, y1 := 780.0) -> void:
	ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xf4e6c8))
	var r := Tex.rng(919)
	for i in int(900 * k):
		var c := Mk.c(0xd8c49c)
		c.a = .05 + r.randf() * .08
		ci.draw_circle(Vector2(r.randf() * w, r.randf() * h), 1.0 + r.randf() * 3.0, c)
	# lignes bleues et marge rouge
	var sy := h / CH
	for i in range(0, 20):
		var y := (y0 + i * step) * sy
		if y < y1 * sy:
			ci.draw_line(Vector2(0, y), Vector2(w, y), Color(.42, .58, .82, .32), 2.0 * sy)
	# jaunissement aux bords
	for i in 10:
		var a := .03 * (10 - i) / 10.0
		ci.draw_rect(Rect2(i * 3 * sy, i * 3 * sy, w - i * 6 * sy, h - i * 6 * sy), Color(.55, .4, .15, a), false, 3.0 * sy)


func _page() -> Dictionary:
	return pages[cur]


func _caret(key: String, txt: String) -> String:
	return txt + ("|" if active == key and _caret_on else "")


func _hl(ci: CanvasItem, key: String, r: Rect2) -> void:
	if active == key:
		ci.draw_rect(r, Color(1, .85, .25, .28))


func _draw_left(ci: CanvasItem, w: float, h: float) -> void:
	_paper_bg(ci, w, h, 1.0, 148.0, 60.0, 760.0)
	var p := _page()
	Tex.silk(ci, "SPLIT SHEET", 30, 70, 40, Color(.12, .1, .1, .85), "left", 800)
	Tex.silk(ci, "No. %d / %d" % [cur + 1, pages.size()], w - 30, 70, 24, PENCIL, "right", 600)
	var rows := [["Title", "title", 142.0], ["Artist", "artist", 202.0], ["Date", "date", 262.0]]
	for r in rows:
		var key: String = r[1]
		var y: float = r[2]
		_hl(ci, key, Rect2(26, y - 34, w - 52, 52))
		Tex.silk(ci, r[0] + " :", 34, y, 22, PENCIL, "left", 600)
		Tex.silk(ci, _caret(key, String(p[key])), 150, y + 4, 46, INK, "left", 600, "caveat")
	# mode
	Tex.silk(ci, "Split :", 34, 336, 22, PENCIL, "left", 600)
	for m in [["SACEM", "sacem", 245.0], ["INTERNATIONAL", "intl", 465.0]]:
		var on: bool = p.mode == m[1]
		Tex.silk(ci, m[0], m[2], 336, 24, INK if on else Color(.3, .3, .35, .45), "center", 700)
		if on:
			_circle(ci, Vector2(m[2], 328), 100.0 if m[1] == "intl" else 70.0, 26.0, RED)
	# notes
	_hl(ci, "notes", Rect2(26, 392, w - 52, 350))
	Tex.silk(ci, "Notes :", 34, 436, 22, PENCIL, "left", 600)
	var lines := _wrap(_caret("notes", String(p.notes)), 34)
	for i in mini(lines.size(), 5):
		Tex.silk(ci, lines[i], 40, 502 + i * 60, 38, INK, "left", 500, "caveat")
	if String(p.notes) == "" and active != "notes":
		Tex.silk(ci, "samples, features, deal memo…", 40, 502, 32, Color(.3, .3, .35, .35), "left", 500, "caveat")
	# pied
	if cur > 0:
		Tex.silk(ci, "‹ prev", 34, 795, 30, INK, "left", 600, "caveat")
	if pages.size() > 1:
		Tex.silk(ci, "tear out page", w - 34, 795, 26, Color(.55, .15, .1, .6), "right", 600, "caveat")


func _draw_right(ci: CanvasItem, w: float, h: float) -> void:
	_paper_bg(ci, w, h, 1.0, ROW_Y0 + 12.0, ROW_H, 590.0)
	var p := _page()
	Tex.silk(ci, "RIGHTS HOLDERS", 30, 70, 34, Color(.12, .1, .1, .85), "left", 800)
	var heads := ["Name", "Role", "", "Share"]
	var hx := [30.0, 278.0, 372.0, 556.0]
	for i in heads.size():
		Tex.silk(ci, heads[i], hx[i], 122, 20, PENCIL, "right" if i == 3 else "left", 700)
	ci.draw_line(Vector2(24, 132), Vector2(w - 24, 132), Color(.2, .2, .25, .5), 2.0)
	var rows: Array = p.rows
	for i in rows.size():
		var r: Dictionary = rows[i]
		var y := ROW_Y0 + i * ROW_H
		_hl(ci, "r%d:name" % i, Rect2(20, y - 30, 250, ROW_H))
		_hl(ci, "r%d:share" % i, Rect2(460, y - 30, 100, ROW_H))
		var nm := _caret("r%d:name" % i, String(r.name))
		Tex.silk(ci, _fit(nm, 18), 32, y + 6, 36, INK, "left", 600, "caveat")
		Tex.silk(ci, String(r.role), 284, y + 6, 34, INK, "left", 600, "caveat")
		var sh := buf if active == "r%d:share" % i else _pct(float(r.share))
		Tex.silk(ci, _caret("r%d:share" % i, sh) + " %", 556, y + 6, 36, INK, "right", 600, "caveat")
		Tex.silk(ci, "×", 578, y + 2, 26, Color(.5, .15, .1, .45), "center", 600)
	if rows.is_empty():
		Tex.silk(ci, "+ add a name below", 40, ROW_Y0 + 6, 32, Color(.3, .3, .35, .45), "left", 500, "caveat")
	# totaux
	var ty := 630.0
	ci.draw_line(Vector2(24, ty - 30), Vector2(w - 24, ty - 30), Color(.2, .2, .25, .5), 2.0)
	var chk := check()
	Tex.silk(ci, chk.label, 32, ty, 26, GREEN if chk.ok else RED, "left", 700)
	if chk.ok:
		ci.draw_polyline(PackedVector2Array([Vector2(520, ty - 14), Vector2(536, ty + 2), Vector2(566, ty - 30)]), GREEN, 7.0, true)
	# boutons tamponnés
	var btn := [["+ ADD", 87.0], ["= SPLIT", 229.0], ["COPY", 371.0], ["PDF", 513.0]]
	for b in btn:
		var r := Rect2(b[1] - 62, 662, 124, 46)
		ci.draw_rect(r, Color(.62, .1, .08, .08))
		ci.draw_rect(r, Color(.62, .1, .08, .7), false, 3.0)
		Tex.silk(ci, b[0], b[1], 694, 22, Color(.62, .1, .08, .85), "center", 800)
	Tex.silk(ci, "next ›" if cur < pages.size() - 1 else "new title ›", w - 34, 795, 30, INK, "right", 600, "caveat")


func _circle(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 41:
		var a := i / 40.0 * TAU * 1.05 - .4
		pts.append(c + Vector2(cos(a) * rx * (1 + .03 * sin(a * 3)), sin(a) * ry))
	ci.draw_polyline(pts, col, 3.0, true)


static func _fit(s: String, n: int) -> String:
	return s if s.length() <= n else s.left(n - 1) + "…"


static func _wrap(s: String, n: int) -> Array:
	var out := []
	for para in s.split("\n"):
		var line := ""
		for word in para.split(" "):
			if (line + " " + word).strip_edges().length() > n and line != "":
				out.append(line)
				line = word
			else:
				line = (line + " " + word).strip_edges()
		out.append(line)
	return out


static func _pct(v: float, comma := false) -> String:
	var s := "%.2f" % v
	if s.ends_with(".00"):
		s = s.left(-3)
	return s.replace(".", ",") if comma else s


# ---------------------------------------------------------------- calculs
## Partage égal au centième : 100 / n, le reste réparti d'un centième sur les premiers (24 → 4,17 / 4,16).
static func equal_parts(n: int, total := 100.0) -> Array:
	var out := []
	if n <= 0:
		return out
	var cents := int(round(total * 100.0))
	var base := cents / n
	var rem := cents - base * n
	for i in n:
		out.append((base + (1 if i < rem else 0)) / 100.0)
	return out


func _sum(rows: Array, roles: Array) -> float:
	var t := 0.0
	for r in rows:
		if roles.is_empty() or roles.has(r.role):
			t += float(r.share)
	return snappedf(t, .01)


## Contrôle des 100 % : SACEM = total des lignes ; international = writers 100 % (et publishers 100 % s'il y en a).
func check() -> Dictionary:
	var p := _page()
	var rows: Array = p.rows
	if rows.is_empty():
		return {"ok": false, "label": "Total : 0 %"}
	if p.mode == "sacem":
		var t := _sum(rows, [])
		return {"ok": is_equal_approx(t, 100.0), "label": "Total : %s %%" % _pct(t)}
	var wt := _sum(rows, ["Writer"])
	var has_pub := rows.any(func(r): return r.role == "Publisher")
	var pt := _sum(rows, ["Publisher"])
	var ok := is_equal_approx(wt, 100.0) and (not has_pub or is_equal_approx(pt, 100.0))
	var lab := "Writers %s %%" % _pct(wt)
	if has_pub:
		lab += "  ·  Publishers %s %%" % _pct(pt)
	return {"ok": ok, "label": lab}


func split_equal() -> void:
	var p := _page()
	var rows: Array = p.rows
	var groups := [[]] if p.mode == "sacem" else [["Writer"], ["Publisher"]]
	for g in groups:
		var idx := []
		for i in rows.size():
			if g.is_empty() or g.has(rows[i].role):
				idx.append(i)
		var parts := equal_parts(idx.size())
		for k in idx.size():
			rows[idx[k]].share = parts[k]


# ---------------------------------------------------------------- récap
func recap() -> String:
	var p := _page()
	var fr: bool = p.mode == "sacem"
	var t := []
	t.append(("FEUILLE DE SPLITS — " if fr else "SPLIT SHEET — ") + String(p.title))
	t.append(("Artiste : " if fr else "Artist: ") + String(p.artist))
	t.append("Date : " + String(p.date) if fr else "Date: " + String(p.date))
	t.append("Répartition : SACEM" if fr else "Split: International (writers / publishers)")
	t.append("")
	for r in p.rows:
		var role: String = ROLE_FR.get(r.role, r.role) if fr else String(r.role)
		var line := "- %s (%s) : %s %%" % [r.name, role, _pct(float(r.share), fr)]
		if not fr:
			line = "- %s (%s): %s %%" % [r.name, role, _pct(float(r.share))]
		t.append(line)
	t.append("")
	var chk := check()
	if fr:
		t.append(chk.label.replace(".", ",") + ("  ✓" if chk.ok else "  ✗ (le total doit faire 100 %)"))
	else:
		t.append(chk.label + ("  ✓" if chk.ok else "  ✗ (must total 100 %)"))
	if String(p.notes).strip_edges() != "":
		t.append("")
		t.append(("Notes : " if fr else "Notes: ") + String(p.notes))
	return "\n".join(t)


## PDF d'une page A4, écrit à la main (Helvetica, WinAnsi) : en-tête, tableau des ayants droit,
## contrôle du total, notes. Aucune dépendance.
func write_pdf(path: String) -> void:
	if not path.to_lower().ends_with(".pdf"):
		path += ".pdf"
	var p := _page()
	var fr: bool = p.mode == "sacem"
	_pdf = PackedByteArray()
	var T := func(x: float, y: float, size: float, txt: String, bold := false, grey := 0.0) -> void:
		_pdf.append_array(("BT /%s %.1f Tf %.3f g %.1f %.1f Td (" % ["F2" if bold else "F1", size, grey, x, y]).to_ascii_buffer())
		_pdf.append_array(_pdf_str(txt))
		_pdf.append_array(") Tj ET\n".to_ascii_buffer())
	var L := func(x0: float, y0: float, x1: float, y1: float, w := .6, red := false) -> void:
		_pdf.append_array(("%s %.2f w %.1f %.1f m %.1f %.1f l S\n" % ["0.62 0.1 0.08 RG" if red else "0.3 G", w, x0, y0, x1, y1]).to_ascii_buffer())
	# en-tête
	T.call(56, 780, 22, "FEUILLE DE SPLITS" if fr else "SPLIT SHEET", true)
	T.call(539 - 120, 784, 9, ("SACEM" if fr else "INTERNATIONAL"), true, .35)
	L.call(56, 768, 539, 768, 1.5, true)
	var y := 740.0
	for row in [["Titre" if fr else "Title", p.title], ["Artiste" if fr else "Artist", p.artist], ["Date", p.date]]:
		T.call(56, y, 10, String(row[0]).to_upper(), true, .45)
		T.call(150, y, 13, String(row[1]))
		y -= 22
	# tableau
	y -= 18
	var cols := [56.0, 330.0, 539.0]
	T.call(cols[0], y, 9, "NOM" if fr else "NAME", true, .45)
	T.call(cols[1], y, 9, "RÔLE" if fr else "ROLE", true, .45)
	T.call(cols[2] - 40, y, 9, "PART" if fr else "SHARE", true, .45)
	y -= 8
	L.call(56, y, 539, y, .8)
	for r in p.rows:
		y -= 20
		var role: String = ROLE_FR.get(r.role, r.role) if fr else String(r.role)
		var sh := _pct(float(r.share), fr) + " %"
		T.call(cols[0], y, 12, String(r.name))
		T.call(cols[1], y, 12, role)
		T.call(cols[2] - 6.2 * sh.length(), y, 12, sh)
		L.call(56, y - 7, 539, y - 7, .3)
	y -= 30
	var chk := check()
	var lab: String = chk.label.replace(".", ",") if fr else String(chk.label)
	T.call(56, y, 12, lab + ("   -   OK" if chk.ok else ("   -   le total doit faire 100 %" if fr else "   -   must total 100 %")), true, 0.0 if chk.ok else .55)
	# notes
	if String(p.notes).strip_edges() != "":
		y -= 40
		T.call(56, y, 10, "NOTES", true, .45)
		for line in _wrap(String(p.notes), 90):
			y -= 16
			T.call(56, y, 11, String(line))
	# signatures
	y = maxf(120.0, y - 70.0)
	T.call(56, y + 14, 9, "SIGNATURES", true, .45)
	var n: int = p.rows.size()
	for i in n:
		var cx := 56.0 + (i % 3) * 165.0
		var cy: float = y - 34.0 - floor(i / 3.0) * 46.0
		L.call(cx, cy, cx + 140, cy, .4)
		T.call(cx, cy - 11, 8, String(p.rows[i].name), false, .4)
	T.call(56, 36, 8, "REEL'S TOOLS  -  " + ("feuille de splits" if fr else "split sheet"), false, .5)
	var objs := [
		"<< /Type /Catalog /Pages 2 0 R >>".to_ascii_buffer(),
		"<< /Type /Pages /Kids [3 0 R] /Count 1 >>".to_ascii_buffer(),
		"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R /F2 6 0 R >> >> /Contents 5 0 R >>".to_ascii_buffer(),
		"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>".to_ascii_buffer(),
	]
	var stream := ("<< /Length %d >>\nstream\n" % _pdf.size()).to_ascii_buffer()
	stream.append_array(_pdf)
	stream.append_array("\nendstream".to_ascii_buffer())
	objs.append(stream)
	objs.append("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>".to_ascii_buffer())
	var out := "%PDF-1.4\n".to_ascii_buffer()
	var offs := []
	for i in objs.size():
		offs.append(out.size())
		out.append_array(("%d 0 obj\n" % (i + 1)).to_ascii_buffer())
		out.append_array(objs[i])
		out.append_array("\nendobj\n".to_ascii_buffer())
	var xref := out.size()
	var x := "xref\n0 %d\n0000000000 65535 f \n" % (objs.size() + 1)
	for o in offs:
		x += "%010d 00000 n \n" % o
	x += "trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % [objs.size() + 1, xref]
	out.append_array(x.to_ascii_buffer())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		Toast.say("PDF : impossible d'écrire ici")
		return
	f.store_buffer(out)
	f.close()
	Toast.say("PDF enregistré : " + path.get_file())


static func _pdf_str(s: String) -> PackedByteArray:
	var b := PackedByteArray()
	for ch in s:
		var c := ch.unicode_at(0)
		if c == 0x2026:
			b.append_array("...".to_ascii_buffer())
			continue
		if c == 0x2019:
			c = 0x27
		if c == 0x28 or c == 0x29 or c == 0x5c:
			b.append(0x5c)
		b.append(c if c < 256 else 0x3f)
	return b


# ---------------------------------------------------------------- données
## Page d'exemple (captures de dev et test du PDF).
func demo() -> void:
	pages = [{"title": "Midnight Drive", "artist": "SDM", "date": "11/14/2026", "mode": "sacem",
		"notes": "Sample: none. Feat. Kore on the 2nd verse. Session at Combo Studio, mix by REEL.",
		"rows": [{"name": "Maxime D. (REEL)", "role": "C", "share": 0.0}, {"name": "SDM", "role": "A", "share": 0.0},
			{"name": "Kore", "role": "AC", "share": 0.0}, {"name": "REEL Music", "role": "E", "share": 0.0}]}]
	cur = 0
	split_equal()
	_refresh()


func _blank_page() -> Dictionary:
	var d := Time.get_date_dict_from_system()
	return {"title": "", "artist": "", "date": "%02d/%02d/%d" % [d.month, d.day, d.year], "notes": "", "mode": "sacem", "rows": []}


func _load() -> void:
	var raw = Store.get_v("splits_pages", [])
	pages = raw if raw is Array else []
	if pages.is_empty():
		pages.append(_blank_page())
	for p in pages:
		for k in ["title", "artist", "date", "notes"]:
			if not p.has(k):
				p[k] = ""
		if not p.has("mode"):
			p.mode = "sacem"
		if not p.has("rows"):
			p.rows = []
	cur = clampi(int(Store.get_v("splits_cur", 0)), 0, pages.size() - 1)


func _save() -> void:
	Store.set_v("splits_pages", pages)
	Store.set_v("splits_cur", cur)


func _refresh() -> void:
	left.redraw()
	right.redraw()
	_save()


# ---------------------------------------------------------------- interactions
func _commit() -> void:
	if active.ends_with(":share"):
		var i := int(active.substr(1, active.find(":") - 1))
		var rows: Array = _page().rows
		if i < rows.size() and buf.strip_edges() != "":
			rows[i].share = clampf(buf.replace(",", ".").to_float(), 0.0, 100.0)
	active = ""
	buf = ""


func _start(key: String) -> void:
	_commit()
	active = key
	if key.ends_with(":share"):
		buf = ""


func on_action(a: String) -> void:
	var p := _page()
	var rows: Array = p.rows
	if a.begins_with("field:"):
		_start(a.substr(6))
	elif a.begins_with("mode:"):
		_commit()
		var m := a.substr(5)
		if m != p.mode:
			p.mode = m
			for r in rows:
				r.role = _convert_role(String(r.role), m)
	elif a.begins_with("row:"):
		var sp := a.split(":")
		var i := int(sp[1])
		if i >= rows.size():
			_commit()
			if i == rows.size() and rows.size() < MAX_ROWS:
				_add_row()
				_start("r%d:name" % i)
		else:
			match sp[2]:
				"a":
					_start("r%d:name" % i)
				"b":
					_commit()
					_cycle_role(i, 1)
				"c":
					_commit()
					_cycle_role(i, 1)
				"d":
					_start("r%d:share" % i)
	elif a.begins_with("del:"):
		_commit()
		var i := int(a.substr(4))
		if i < rows.size():
			rows.remove_at(i)
	elif a == "add":
		_commit()
		if rows.size() < MAX_ROWS:
			_add_row()
			_start("r%d:name" % (rows.size() - 1))
		else:
			Toast.say("Page pleine (8 ayants droit)")
	elif a == "equal":
		_commit()
		split_equal()
		Toast.say("Partage égal")
	elif a == "copy":
		_commit()
		DisplayServer.clipboard_set(recap())
		Toast.say("Récap copié")
	elif a == "pdf":
		_commit()
		dialog.current_file = _file_name()
		dialog.popup_centered()
	elif a == "next":
		_commit()
		if cur == pages.size() - 1:
			pages.append(_blank_page())
		_flip(cur + 1)
	elif a == "prev":
		_commit()
		if cur > 0:
			_flip(cur - 1)
	elif a == "delete_page":
		_commit()
		if pages.size() > 1:
			pages.remove_at(cur)
			cur = clampi(cur, 0, pages.size() - 1)
			Toast.say("Page arrachée")
	_refresh()


func _add_row() -> void:
	var p := _page()
	var role: String = ROLES[p.mode][0]
	p.rows.append({"name": "", "role": role, "share": 0.0})


func _cycle_role(i: int, d: int) -> void:
	var p := _page()
	var list: Array = ROLES[p.mode]
	var r: Dictionary = p.rows[i]
	r.role = list[posmod(list.find(r.role) + d, list.size())]


static func _convert_role(role: String, mode: String) -> String:
	if mode == "intl":
		return "Publisher" if role == "E" else "Writer"
	return "E" if role == "Publisher" else "AC"


func _file_name() -> String:
	var p := _page()
	var base := ("%s - %s - splits" % [p.artist, p.title]).strip_edges()
	base = base.replace("/", "-").replace(":", "-")
	return (base if String(p.title) != "" else "splits") + ".pdf"


## Tourne la page (animation de la feuille) ; le contenu change à mi-course.
func _flip(to: int) -> void:
	_turn_target = to
	_turn_dir = 1 if to > cur else -1
	_turn = .55
	_turn_swapped = false
	_leaf.visible = true
	if _turn_dir < 0:
		cur = to   # en reculant, la page de gauche se lève : on affiche tout de suite la cible dessous
		_turn_swapped = true


func on_wheel(a: String, dir: float, _fine: bool) -> void:
	var sp := a.split(":")
	if a.begins_with("row:") and sp.size() == 3:
		if sp[2] == "c":
			sp[2] = "b"
		var i := int(sp[1])
		var rows: Array = _page().rows
		if i >= rows.size():
			return
		if sp[2] == "d":
			rows[i].share = clampf(snappedf(float(rows[i].share) + dir, .01), 0.0, 100.0)
		elif sp[2] == "b":
			_cycle_role(i, int(dir))
		_refresh()
	elif a == "prev" or a == "next":
		on_action("next" if dir < 0 else "prev")


func on_drag_start(_a: String) -> bool:
	return false


func on_drag(_rel: Vector2, _fine: bool) -> void:
	pass


func on_shot_changed(shot: String) -> void:
	if shot != "splits" and active != "":
		_commit()
		_refresh()


func on_key(e: InputEventKey) -> bool:
	if active == "":
		return false
	var p := _page()
	match e.keycode:
		KEY_ESCAPE:
			_commit()
		KEY_ENTER, KEY_KP_ENTER, KEY_TAB:
			if active == "notes" and e.shift_pressed:
				p.notes = String(p.notes) + "\n"
			else:
				_next_field()
		KEY_BACKSPACE:
			_set_text(_get_text().left(-1))
		_:
			if e.unicode < 32:
				return true
			var ch := char(e.unicode)
			if active.ends_with(":share") and not "0123456789.,".contains(ch):
				return true
			_set_text(_get_text() + ch)
	_refresh()
	return true


func _get_text() -> String:
	if active.ends_with(":share"):
		return buf
	if active.begins_with("r"):
		var sp := active.split(":")
		return String(_page().rows[int(sp[0].substr(1))][sp[1]])
	return String(_page()[active])


func _set_text(v: String) -> void:
	if active.ends_with(":share"):
		buf = v.left(6)
		return
	if active.begins_with("r"):
		var sp := active.split(":")
		_page().rows[int(sp[0].substr(1))][sp[1]] = v.left(40)
		return
	_page()[active] = v.left(400 if active == "notes" else 60)


func _next_field() -> void:
	var order := ["title", "artist", "date"]
	var k := order.find(active)
	if k >= 0:
		_start(order[k + 1] if k < 2 else "")
		return
	if active.begins_with("r"):
		var sp := active.split(":")
		var i := int(sp[0].substr(1))
		var seq := ["name", "share"]
		var j := seq.find(sp[1])
		if j < seq.size() - 1:
			_start("r%d:%s" % [i, seq[j + 1]])
		elif i + 1 < _page().rows.size():
			_start("r%d:name" % (i + 1))
		else:
			_commit()
		return
	_commit()


func animate(t: float, dt: float, _reduced: bool) -> void:
	var b := int(t * 2.0)
	if active != "" and b != _blink:
		_blink = b
		_caret_on = b % 2 == 0
		_refresh_canvas_only()
	if _turn > 0.0:
		_turn = maxf(0.0, _turn - dt)
		var k := 1.0 - _turn / .55
		k = k * k * (3.0 - 2.0 * k)
		# feuille : de la page droite (0) vers la gauche (-PI) en avançant, l'inverse en reculant
		_leaf.rotation.y = -PI * (k if _turn_dir > 0 else 1.0 - k)
		_leaf.position.z = .0125 + sin(k * PI) * .004
		if not _turn_swapped and k > .5:
			cur = _turn_target
			_turn_swapped = true
			_refresh()
		if _turn <= 0.0:
			_leaf.visible = false
			_refresh()


func _refresh_canvas_only() -> void:
	left.redraw()
	right.redraw()
