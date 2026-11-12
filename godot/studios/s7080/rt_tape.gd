class_name RtTape7080
extends Node3D
## RT-R2R : magnéto à bandes (module Export).

const PW := 0.42
const PD := 0.32

var reels: Array[Node3D] = []
var rec_led: StandardMaterial3D


func _init() -> void:
	name = "RT-R2R"
	Mk.mi(Mk.rounded_box(Vector3(PW, .07, PD), .008, Mk.mat(Mk.c(0x1a1a1b), .45, 0.0, {"clearcoat": .3}), 4), null, Vector3(0, .035, 0), self)
	var ink := Color(0.078, 0.078, 0.078, .85)
	var top := Mk.panel(PW - .02, PD - .02, func(ci, P, W, H):
		ci.draw_rect(Rect2(0, 0, W, H), Mk.c(0xa9a59e))
		Tex.brushed(ci, W, H, 66, .07)
		Tex.grime(ci, W, H, 67, 1.2)
		Tex.silk(ci, "RT-R2R  EXPORT RECORDER", P.call(.02), H * .95, 34, ink)
		var labels := ["REW", "PLAY", "FF", "STOP", "REC"]
		for i in 5:
			Tex.silk(ci, labels[i], P.call(.12 + i * .045), H * .76, 22, Color(0.078, 0.078, 0.078, .8), "center")
		ci.draw_rect(Rect2(P.call(.16), H * .42, P.call(.08), H * .1), ink)
		Tex.silk(ci, "HEADS", P.call(.2), H * .38, 20, Color(0.078, 0.078, 0.078, .7), "center"),
		{"metal": .45, "rough": .55})
	top.position.y = .071
	add_child(top)
	var reel_tex := Tex.canvas(512, 512, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Color.BLACK)
		ci.draw_circle(Vector2(256, 256), 250, Mk.c(0xc9c5bd))
		for k in 3:
			var a := k * 2.094
			var cc := Vector2(256, 256) + Vector2(sin(a), -cos(a)) * 140.0
			var pts := PackedVector2Array()
			for s in 32:
				var th := s / 32.0 * TAU
				var e := Vector2(cos(th) * 60.0, sin(th) * 80.0)
				pts.append(cc + e.rotated(a))
			ci.draw_colored_polygon(pts, Color.BLACK)
		ci.draw_circle(Vector2(256, 256), 34, Color.BLACK))
	var reel_mat := Mk.mat(Color.WHITE, .45, .5, {"map": reel_tex})
	for s in [-1, 1]:
		var g := Node3D.new()
		g.position = Vector3(s * .1, .075, -.04)
		var r := .075 if s < 0 else .05
		Mk.mi(Mk.cyl(r, r, .011, 96), Mk.mat(Mk.c(0x2a1c12), .35, 0.0, {"clearcoat": .4}), Vector3(0, .008, 0), g)
		Mk.mi(Mk.disc(.09, 96), reel_mat, Vector3(0, .0155, 0), g)
		Mk.mi(Mk.cyl(.012, .012, .02, 24), Mk.chrome_mat(), Vector3(0, .01, 0), g)
		add_child(g)
		reels.append(g)
	Mk.mi(Mk.box(Vector3(.2, .009, .002)), Mk.mat(Mk.c(0x2a1c12), .4), Vector3(0, .082, .03), self)
	for i in 5:
		Mk.mi(Mk.rounded_box(Vector3(.03, .012, .022), .003, Mk.mat(Mk.c(0xb3241a) if i == 4 else Mk.c(0x1a1a1a), .4)), null,
			Vector3(-PW / 2 + .01 + .12 + i * .045, .078, PD / 2 - .01 - .09), self)
	rec_led = Mk.glow(Mk.c(0xff3d22), .3) as StandardMaterial3D
	Mk.mi(Mk.cyl(.003, .003, .003, 16), rec_led, Vector3(PW / 2 - .05, .073, PD / 2 - .07), self)


func animate(t: float, dt: float) -> void:
	for r in reels:
		r.rotation.y -= .02 * 60.0 * dt
	rec_led.emission_energy_multiplier = 2.0 if sin(t * 3.0) > 0 else .2
