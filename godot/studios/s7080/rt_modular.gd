class_name RtModular7080
extends Node3D
## Case modulaire en bois avec le module « 808 TUNER » (accordeur de 808 / kick).

const MW := 0.34
const MD := 0.2

var osc: TexLib.LiveCanvas
var osc_note := ""
const DEMO_NOTES := ["C 1", "C#1", "d 1", "E 1", "F 1", "G 1"]


func _init() -> void:
	name = "Modular808"
	Mk.mi(Mk.rounded_box(Vector3(MW, .03, MD), .006, Mk.mat(Mk.c(0x0b0b0b), .6), 3), null, Vector3(0, .015, 0), self)
	for s in [-1, 1]:
		Mk.mi(Mk.rounded_box(Vector3(.022, .05, MD + .02), .004, Mk.walnut_mat(), 3), null, Vector3(s * (MW / 2 + .011), .025, 0), self)
	var mod_w := [.07, .05, .09, .06, .06]
	var titles := ["LFO", "MIX", "808 TUNER", "ENV", "VCA"]
	var mxp := -MW / 2 + .005
	var jack_mesh := Mk.cyl(.0035, .0035, .003, 16)
	var jack_mat := Mk.mat(Mk.c(0x0a0a0a), .4, .6)
	var nut_mesh := TorusMesh.new()
	nut_mesh.inner_radius = .0042 - .0009
	nut_mesh.outer_radius = .0042 + .0009
	nut_mesh.rings = 18
	nut_mesh.ring_segments = 6
	for i in mod_w.size():
		var w: float = mod_w[i]
		var is_osc := i == 2
		var bg := Mk.c(0xc9c5bd) if is_osc else (Mk.c(0x1b1b1c) if i % 2 else Mk.c(0xa9a59d))
		var ink := Color(0.078, 0.078, 0.078, .9) if (is_osc or i % 2 == 0) else Color(0.9, 0.886, 0.855, .85)
		var p := Mk.panel(w - .002, MD - .01, func(ci, P, W, H):
			ci.draw_rect(Rect2(0, 0, W, H), bg)
			Tex.brushed(ci, W, H, 90 + i, .05, 800)
			Tex.grime(ci, W, H, 95 + i, .6)
			Tex.silk(ci, titles[i], W / 2.0, H * .06, 30, ink, "center")
			if is_osc:
				Tex.silk(ci, "RT-OSC  ·  NOTE / HZ", W / 2.0, H * .94, 22, ink, "center"),
			{"metal": .7, "rough": .45, "res": 512, "t": .003})
		p.position = Vector3(mxp + w / 2, .031, 0)
		add_child(p)
		var n := int(round(w / .022))
		for j in n:
			var jp := Vector3(mxp + .011 + j * .021, .034, MD / 2 - .03)
			Mk.mi(jack_mesh, jack_mat, jp, self)
			Mk.mi(nut_mesh, Mk.chrome_mat(), Vector3(jp.x, .0345, jp.z), self)
		if not is_osc:
			for j in 2:
				var k := Mk.knob(.006, .01, null if i % 2 else Mk.c(0xd43a26))
				k.position = Vector3(mxp + w / 2, .033, -.04 + j * .05)
				add_child(k)
		mxp += w
	# afficheur LED du module accordeur
	osc = Tex.live(512, 192, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x070101))
		Tex.seg7(ci, osc_note, 40, 22, 110, 148, 40, Mk.c(0xff3d22), Color(1, .2, .08, .06)))
	var osc_x := -MW / 2 + .005 + .07 + .05 + .045
	var win := Mk.screen_window(Mk.glow(Color.WHITE, 1.5, osc.texture), .062, .024, Mk.c(0x3a0705))
	win.position = Vector3(osc_x, .033, -.045)
	add_child(win)
	var big := Mk.alu_knob(.014, .016)
	big.position = Vector3(osc_x, .033, .012)
	add_child(big)
	# câbles de patch
	var cables := [
		[-MW / 2 + .02, MD / 2 - .03, osc_x - .02, MD / 2 - .03, Mk.c(0xd43a26)],
		[-MW / 2 + .09, MD / 2 - .03, osc_x + .04, MD / 2 - .03, Mk.c(0xf2c230)],
		[osc_x + .02, MD / 2 - .03, MW / 2 - .04, MD / 2 - .03, Mk.c(0x1e1e1e)],
	]
	for i in cables.size():
		var cb: Array = cables[i]
		var a := Vector3(cb[0], .036, cb[1])
		var b := Vector3(cb[2], .036, cb[3])
		var m := a.lerp(b, .5)
		m.y += .03 + i * .01
		m.z += .04 + i * .015
		var pts := [a, Vector3(a.x, .05, a.z), m, Vector3(b.x, .05, b.z), b]
		Mk.mi(Mk.tube(pts, .0022, 40, 8), Mk.mat(cb[4], .45, 0.0, {"clearcoat": .3}), Vector3.ZERO, self)
	set_note(DEMO_NOTES[0])


func set_note(s: String) -> void:
	osc_note = s
	osc.redraw()


func animate(t: float) -> void:
	var s: String = DEMO_NOTES[int(t / 2.0) % DEMO_NOTES.size()]
	if s != osc_note:
		set_note(s)
