class_name RtScope7080
extends Node3D
## RT-SC1 : analyseur portable, plastique beige, écran à phosphore vert (module Analyse).

var screen: TexLib.LiveCanvas
var t_draw := 0.0


func _init() -> void:
	name = "RT-SC1"
	var beige := Mk.c(0x8c8578)
	Mk.mi(Mk.rounded_box(Vector3(.24, .045, .3), .012, Mk.mat(beige, .55, 0.0, {"clearcoat": .2}), 4), null, Vector3(0, .0225, 0), self)
	screen = Tex.live(512, 400, _draw_screen)
	var win := Mk.screen_window(Mk.glow(Color.WHITE, 1.1, screen.texture), .19, .148, Mk.c(0x0b1a0e))
	win.position = Vector3(0, .046, -.055)
	add_child(win)
	var top := Mk.panel(.22, .1, func(ci, P, W, H):
		ci.draw_rect(Rect2(0, 0, W, H), beige)
		Tex.grime(ci, W, H, 44, 1)
		Tex.silk(ci, "RT-SC1  ANALYSE", P.call(.012), H * .14, 54, Color(0.12, 0.12, 0.12, .85))
		var labels := ["TIME", "VOLT", "TRIG", "FFT"]
		for i in 4:
			Tex.silk(ci, labels[i], P.call(.03 + i * .052), H * .9, 34, Color(0.12, 0.12, 0.12, .75), "center"),
		{"metal": 0.0, "rough": .6, "scratch": false, "side": beige})
	top.position = Vector3(0, .0455, .095)
	add_child(top)
	for i in 4:
		var k := Mk.knob(.008, .012)
		k.position = Vector3(-.11 + .03 + i * .052, .047, .1)
		add_child(k)
	var glow_l := OmniLight3D.new()
	glow_l.light_color = Mk.c(0x5dff80)
	glow_l.light_energy = .15
	glow_l.omni_range = .35
	glow_l.position = Vector3(0, .12, -.05)
	add_child(glow_l)


func _draw_screen(ci: CanvasItem, w: float, h: float) -> void:
	var t := t_draw
	ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x020a04))
	var grid := Color(0.35, 1, 0.55, .12)
	for i in range(1, 10):
		ci.draw_line(Vector2(i * 51.2, 0), Vector2(i * 51.2, h), grid, 1.0)
	for i in range(1, 8):
		ci.draw_line(Vector2(0, i * 50), Vector2(w, i * 50), grid, 1.0)
	var pts := PackedVector2Array()
	var x := 0
	while x <= 512:
		pts.append(Vector2(x, 200 + sin(x * .045 + t * 4) * 60 * sin(t * .7 + x * .004) + sin(x * .17 + t * 9) * 14))
		x += 4
	ci.draw_polyline(pts, Color(0.36, 1, 0.5, .12), 14.0, true)
	ci.draw_polyline(pts, Color(0.4, 1, 0.55, .25), 7.0, true)
	ci.draw_polyline(pts, Mk.c(0x7dff9c), 3.0, true)
	var f := Tex.font("mono")
	ci.draw_string(f, Vector2(18, 36), "DROP AUDIO FILE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.49, 1, 0.61, .8))
	ci.draw_string(f, Vector2(18, 386), "BPM  ---   KEY  ---", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.49, 1, 0.61, .8))


func animate(t: float) -> void:
	t_draw = t
	screen.redraw()
