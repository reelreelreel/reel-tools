class_name RtSynth7080
extends Node3D
## RT-SY8 : synthé polyphonique 80s à joues en noyer (module Gammes & accords).

const SW := 0.74
const SD := 0.3

var keys: Array = []  # {m, white, idx}


func _init() -> void:
	name = "RT-SY8"
	Mk.mi(Mk.rounded_box(Vector3(SW, .06, SD), .008, Mk.mat(Mk.c(0x141416), .5, 0.0, {"clearcoat": .2}), 4), null, Vector3(0, .03, 0), self)
	var cols := [Mk.c(0xe8742a), Mk.c(0xf2c230), Mk.c(0xe8742a), Mk.c(0xd43a26), Mk.c(0xf2c230), Mk.c(0xe8742a)]
	var pnl := Mk.panel(SW - .06, .14, func(ci, P, W, H):
		ci.draw_rect(Rect2(0, 0, W, H), Mk.c(0x1c1c1e))
		Tex.brushed(ci, W, H, 77, .03)
		Tex.grime(ci, W, H, 78, 1)
		Tex.silk(ci, "RT-SY8", P.call(.02), H * .2, 60, Color(0.92, 0.906, 0.87, .9))
		Tex.silk(ci, "POLYPHONIC SCALE SYNTHESIZER", P.call(.12), H * .2, 30, Color(0.92, 0.906, 0.87, .6))
		var labels := ["ROOT", "SCALE", "CHORD", "PROG", "OCT", "HZ"]
		for i in 6:
			ci.draw_rect(Rect2(P.call(.03 + i * .055), H * .45, P.call(.04), H * .12), cols[i])
			Tex.silk(ci, labels[i], P.call(.05 + i * .055), H * .72, 24, Color(0.92, 0.906, 0.87, .7), "center")
		var sl := ["ATK", "DEC", "SUS", "REL", "CUT", "RES"]
		for i in 6:
			ci.draw_rect(Rect2(P.call(.4 + i * .04), H * .3, P.call(.006), H * .55), Mk.c(0x0a0a0a))
			Tex.silk(ci, sl[i], P.call(.403 + i * .04), H * .9, 20, Color(0.92, 0.906, 0.87, .6), "center"),
		{"metal": .3, "rough": .5, "side": Mk.c(0x141416)})
	pnl.position = Vector3(0, .061, -.07)
	add_child(pnl)
	var fcols := [Mk.c(0xe8742a), Mk.c(0xf2c230), Mk.c(0xd43a26)]
	for i in 6:
		Mk.mi(Mk.rounded_box(Vector3(.012, .012, .008), .002, Mk.mat(fcols[i % 3], .4)), null,
			Vector3(-(SW - .06) / 2 + .403 + i * .04, .068, -.07 - .14 / 2 + .14 * (.35 + (i % 3) * .12)), self)
	for i in 4:
		var k := Mk.knob(.008, .012)
		k.position = Vector3(-SW / 2 + .63 + (i % 2) * .04, .063, -.12 + floorf(i / 2.0) * .05)
		add_child(k)
	# clavier : 22 blanches + noires
	var white_mat := Mk.mat(Mk.c(0xcfc9bb), .4, 0.0, {"clearcoat": .3})
	var black_mat := Mk.mat(Mk.c(0x0d0d0e), .3, 0.0, {"clearcoat": .5})
	var lit_mat := Mk.mat(Mk.c(0xffd9a8), .35, 0.0, {"emission": Mk.c(0xff8a2a), "energy": .35})
	var kb_w := .62
	var n_white := 22
	var ww := kb_w / n_white
	var wmesh := Mk.rounded_box(Vector3(ww - .0012, .012, .11), .0015, null, 2)
	var bmesh := Mk.rounded_box(Vector3(ww * .55, .012, .07), .0015, null, 2)
	for i in n_white:
		var k := Mk.mi(wmesh, white_mat, Vector3(-kb_w / 2 + ww / 2 + i * ww, .062, .075), self)
		keys.append({"m": k, "white": true, "idx": i})
	var pattern := [1, 1, 0, 1, 1, 1, 0]
	for i in n_white - 1:
		if pattern[i % 7] == 0:
			continue
		Mk.mi(bmesh, black_mat, Vector3(-kb_w / 2 + (i + 1) * ww, .072, .055), self)
	for s in [-1, 1]:
		Mk.mi(Mk.rounded_box(Vector3(.03, .075, SD + .004), .004, Mk.walnut_mat(), 3), null, Vector3(s * (SW / 2 + .012), .036, 0), self)
	# gamme de do mineur allumée sur les blanches (do, ré, fa, sol)
	for k in keys:
		if k.white and [0, 1, 3, 4].has(k.idx % 7):
			k.m.material_override = lit_mat
