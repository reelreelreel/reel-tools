extends Node
class_name TexLib
## Textures procédurales : on dessine avec l'API 2D de Godot (draw_*) dans des SubViewports.
## - canvas() : texture fixe, cuite une fois (avec mipmaps) au démarrage par flush().
## - live()   : texture vivante (écrans LED, VFD, oscillo, TV) qu'on redessine à la demande.

const FONT_FILES := {
	"archivo": "res://assets/fonts/ArchivoNarrow-Variable.ttf",
	"mono": "res://assets/fonts/IBMPlexMono-SemiBold.ttf",
	"caveat": "res://assets/fonts/Caveat-Variable.ttf",
}

var _fonts := {}
var _jobs: Array = []  # [SubViewport, ImageTexture]


class Painter extends Node2D:
	var fn: Callable
	var w: int
	var h: int
	func _draw() -> void:
		fn.call(self, w, h)


class LiveCanvas extends RefCounted:
	var vp: SubViewport
	var painter: Painter
	var texture: Texture2D
	func redraw() -> void:
		painter.queue_redraw()
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE


# ---------------------------------------------------------------- fonts
func font(fam: String, weight := 700) -> Font:
	var key := "%s%d" % [fam, weight]
	if _fonts.has(key):
		return _fonts[key]
	var f := FontVariation.new()
	f.base_font = load(FONT_FILES[fam])
	if fam != "mono":
		var ts := TextServerManager.get_primary_interface()
		f.variation_opentype = {ts.name_to_tag("wght"): weight}
	_fonts[key] = f
	return f


# ---------------------------------------------------------------- canvases
func _viewport(w: int, h: int, fn: Callable, transparent := false) -> Array:
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.disable_3d = true
	vp.transparent_bg = transparent
	vp.msaa_2d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var p := Painter.new()
	p.fn = fn
	p.w = w
	p.h = h
	vp.add_child(p)
	add_child(vp)
	return [vp, p]


## Texture fixe : renvoie tout de suite une texture (vide), remplie par flush().
func canvas(w: int, h: int, fn: Callable, transparent := false) -> ImageTexture:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.3, 0.3, 0.3, 0.0 if transparent else 1.0))
	var tex := ImageTexture.create_from_image(img)
	var vp_p := _viewport(w, h, fn, transparent)
	_jobs.append([vp_p[0], tex])
	return tex


## Texture vivante : appeler .redraw() quand le contenu change.
func live(w: int, h: int, fn: Callable) -> LiveCanvas:
	var vp_p := _viewport(w, h, fn)
	var lc := LiveCanvas.new()
	lc.vp = vp_p[0]
	lc.painter = vp_p[1]
	lc.texture = lc.vp.get_texture()
	return lc


## Cuit toutes les textures fixes en attente (mipmaps), puis libère leurs viewports.
func flush() -> void:
	if _jobs.is_empty():
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	for j in _jobs:
		var vp: SubViewport = j[0]
		var img := vp.get_texture().get_image()
		if img:
			img.convert(Image.FORMAT_RGBA8)
			img.generate_mipmaps()
			(j[1] as ImageTexture).set_image(img)
		vp.queue_free()
	_jobs.clear()


## Image -> carte de normales (pour le moletage des potards, etc.)
func normal_from_bump(img: Image, strength := 2.0) -> ImageTexture:
	var n := img.duplicate()
	n.convert(Image.FORMAT_RGBA8)
	n.bump_map_to_normal_map(strength)
	n.generate_mipmaps()
	return ImageTexture.create_from_image(n)


# ---------------------------------------------------------------- drawing helpers (appelés dans un fn de canvas)
static func rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r


static func brushed(ci: CanvasItem, w: float, h: float, seed: int, a: float, n := 6000) -> void:
	var r := rng(seed)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for i in n:
		var y := r.randf() * h
		var px := r.randf() * w
		pts.append(Vector2(px, y))
		pts.append(Vector2(px + 40.0 + r.randf() * 300.0, y))
		var al := r.randf() * a
		cols.append(Color(1, 1, 1, al) if r.randf() > 0.5 else Color(0, 0, 0, al))
	ci.draw_multiline_colors(pts, cols, 1.0)


static func grime(ci: CanvasItem, w: float, h: float, seed: int, k := 1.0) -> void:
	var r := rng(seed)
	for i in int(900 * k):
		ci.draw_circle(Vector2(r.randf() * w, r.randf() * h), r.randf() * 2.5 + 0.3, Color(0, 0, 0, r.randf() * 0.06))
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for i in int(40 * k):
		var p := Vector2(r.randf() * w, r.randf() * h)
		var l := 8.0 + r.randf() * 90.0
		var ang := r.randf() * 7.0
		pts.append(p)
		pts.append(p + Vector2(cos(ang), sin(ang)) * l)
		cols.append(Color(1, 1, 1, 0.04 + r.randf() * 0.12))
	ci.draw_multiline_colors(pts, cols, 0.8)


## Texte « sérigraphié ». y = milieu du texte (comme textBaseline = middle).
func silk(ci: CanvasItem, txt: String, x: float, y: float, size: float, color := Color(0.925, 0.91, 0.878, 0.9), align := "left", weight := 700, fam := "archivo") -> void:
	var f := font(fam, weight)
	var s := int(round(size))
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
	var px := x
	if align == "center":
		px = x - tw / 2.0
	elif align == "right":
		px = x - tw
	var base := y + (f.get_ascent(s) - f.get_descent(s)) / 2.0
	ci.draw_string(f, Vector2(px, base), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, s, color)


static func woodgrain(ci: CanvasItem, seed: int, base: Color, dark: Color, w: float, h: float, rings := 0) -> void:
	var r := rng(seed)
	ci.draw_rect(Rect2(0, 0, w, h), base)
	for i in 300:
		var y0 := r.randf() * h
		var amp := 3.0 + r.randf() * 16.0
		var f := 0.003 + r.randf() * 0.008
		var ph := r.randf() * 6.0
		var c := dark if r.randf() > 0.45 else Color(1, 0.78, 0.59, 0.05)
		c.a *= 0.12 + r.randf() * 0.35
		var lw := 0.6 + r.randf() * 2.2
		var pts := PackedVector2Array()
		var px := 0.0
		while px <= w:
			pts.append(Vector2(px, y0 + sin(px * f + ph) * amp + sin(px * f * 3.1) * amp * 0.25))
			px += 8.0
		ci.draw_polyline(pts, c, lw, true)
	for i in rings:
		var cc := Vector2(r.randf() * w, r.randf() * h)
		var a0 := r.randf() * 6.0
		ci.draw_arc(cc, 40.0 + r.randf() * 10.0, a0, a0 + 4.0 + r.randf() * 2.0, 32, Color(0.08, 0.04, 0.015, 0.25 + r.randf() * 0.2), 3.0 + r.randf() * 4.0, true)
	grime(ci, w, h, seed + 9, 2.5)


# ---------------------------------------------------------------- 7 segments
const SEG := {
	"a": [[.14, 0], [.86, 0], [.76, .08], [.24, .08]],
	"b": [[.9, .04], [.9, .47], [.81, .43], [.81, .11]],
	"c": [[.9, .53], [.9, .96], [.81, .89], [.81, .57]],
	"d": [[.14, 1], [.86, 1], [.76, .92], [.24, .92]],
	"e": [[.1, .53], [.1, .96], [.19, .89], [.19, .57]],
	"f": [[.1, .04], [.1, .47], [.19, .43], [.19, .11]],
	"g": [[.15, .5], [.25, .455], [.75, .455], [.85, .5], [.75, .545], [.25, .545]],
}
const DIG := {
	"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd", "6": "afgedc",
	"7": "abc", "8": "abcdefg", "9": "abcfgd", " ": "", "-": "g", "A": "abcefg", "b": "cdefg",
	"C": "adef", "d": "bcdeg", "E": "adefg", "F": "aefg", "G": "acdef", "#": "bcefg",
}


static func seg7(ci: CanvasItem, s: String, ox: float, oy: float, cw: float, chh: float, gap: float, on: Color, off: Color, dot_at := -1) -> void:
	for i in s.length():
		var segs: String = DIG.get(s[i], "")
		var bx := ox + i * (cw + gap)
		for k in SEG:
			var poly := PackedVector2Array()
			for uv in SEG[k]:
				poly.append(Vector2(bx + uv[0] * cw - uv[1] * cw * 0.1, oy + uv[1] * chh))
			ci.draw_colored_polygon(poly, on if segs.contains(k) else off)
	if dot_at >= 0:
		ci.draw_circle(Vector2(ox + dot_at * (cw + gap) - gap / 2.0, oy + chh - 4.0), 7.0, on)
