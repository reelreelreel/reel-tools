class_name RtTurntable7080
extends Node3D
## RT-TT2 : platine vinyle sur socle en noyer (module Pitch de sample).

const TW := 0.45
const TD := 0.35

var platter: Node3D


func _init() -> void:
	name = "RT-TT2"
	Mk.mi(Mk.rounded_box(Vector3(TW, .06, TD), .008, Mk.walnut_mat(), 4), null, Vector3(0, .03, 0), self)
	var cream := Color(0.88, 0.863, 0.83, .8)
	var top := Mk.panel(TW - .02, TD - .02, func(ci, P, W, H):
		ci.draw_rect(Rect2(0, 0, W, H), Mk.c(0x18181a))
		Tex.brushed(ci, W, H, 55, .03)
		Tex.grime(ci, W, H, 56, 1)
		Tex.silk(ci, "RT-TT2  PITCH", P.call(.215), H * .94, 40, cream)
		Tex.silk(ci, "+8", P.call(.39), H * .38, 30, Color(0.88, 0.863, 0.83, .7), "center")
		Tex.silk(ci, "−8", P.call(.39), H * .86, 30, Color(0.88, 0.863, 0.83, .7), "center")
		ci.draw_rect(Rect2(P.call(.385), H * .42, P.call(.012), H * .4), Color.BLACK)
		for i in 17:
			ci.draw_rect(Rect2(P.call(.4), H * (.42 + i * .025), P.call(.006 if i % 4 else .012), 2), Color(0.88, 0.863, 0.83, .6)),
		{"metal": .4, "rough": .5})
	top.position.y = .061
	add_child(top)
	platter = Node3D.new()
	platter.position = Vector3(-.06, .064, 0)
	add_child(platter)
	Mk.mi(Mk.cyl(.152, .152, .012, 128), Mk.mat(Mk.c(0x6f6b64), .35, 1.0), Vector3(0, .006, 0), platter)
	var label := Tex.canvas(1024, 1024, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x070707))
		var r := Tex.rng(17)
		var rad := 140.0
		while rad < 500.0:
			ci.draw_arc(Vector2(512, 512), rad, 0, TAU, 128, Color(1, 1, 1, .015 + r.randf() * .03), 1.0)
			rad += 2.2
		ci.draw_circle(Vector2(512, 512), 130, Mk.c(0xb3241a))
		Tex.silk(ci, "REEL'S", 512, 470, 44, Mk.c(0xefe6d6), "center")
		Tex.silk(ci, "SIDE A · 33⅓", 512, 560, 28, Mk.c(0xefe6d6), "center"))
	Mk.mi(Mk.cyl(.15, .15, .0015, 128, false), Mk.mat(Mk.c(0x050505), .5), Vector3(0, .0128, 0), platter)
	Mk.mi(Mk.disc(.15, 128), Mk.mat(Color.WHITE, .45, 0.0, {"map": label, "clearcoat": .25, "clearcoat_rough": .5}), Vector3(0, .0136, 0), platter)
	Mk.mi(Mk.cyl(.0035, .0035, .014, 16), Mk.chrome_mat(), Vector3(0, .016, 0), platter)
	# bras
	var arm := Node3D.new()
	arm.position = Vector3(.13, .07, -.12)
	add_child(arm)
	Mk.mi(Mk.cyl(.022, .025, .02, 48), Mk.black_knob_mat(), Vector3.ZERO, arm)
	var tube := Mk.mi(Mk.cyl(.0035, .0035, .24, 16), Mk.chrome_mat(), Vector3(-.1, .016, .065), arm)
	tube.basis = Mk.euler_xyz(0, .62, PI / 2)
	var hs := Mk.mi(Mk.box(Vector3(.03, .006, .016)), Mk.mat(Mk.c(0x111111), .4), Vector3(-.198, .014, .13), arm)
	hs.rotation.y = .62
	var cw := Mk.mi(Mk.cyl(.012, .012, .025, 32), Mk.chrome_mat(), Vector3(.035, .016, -.022), arm)
	cw.basis = Mk.euler_xyz(0, .62, PI / 2)
	Mk.mi(Mk.rounded_box(Vector3(.03, .012, .016), .003, Mk.mat(Mk.c(0x1a1a1a), .4)), null, Vector3(TW / 2 - .02 - .055 + .012, .07, .05), self)
	Mk.mi(Mk.rounded_box(Vector3(.04, .006, .03), .002, Mk.mat(Mk.c(0xcfcac2), .3, .9)), null, Vector3(-TW / 2 + .045, .066, TD / 2 - .04), self)
	Mk.mi(Mk.cyl(.004, .004, .004, 16), Mk.glow(Mk.c(0xff3d22), 2.0), Vector3(-TW / 2 + .03, .064, -TD / 2 + .035), self)


func animate(dt: float) -> void:
	platter.rotation.y -= 0.0349 * 60.0 * dt
