class_name SplitsBook7080
extends Node3D
## Carnet d'artiste « SPLITS » + stylo (module Splits).

func _init() -> void:
	name = "SplitsBook"
	var cover_tex := Tex.canvas(512, 720, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x151311))
		Tex.grime(ci, w, h, 61, 2)
		ci.draw_set_transform(Vector2(110, 300), -.06)
		ci.draw_rect(Rect2(0, 0, 300, 90), Mk.c(0xe8dcc0))
		ci.draw_set_transform(Vector2(260, 352), -.06)
		Tex.silk(ci, "SPLITS", 0, 0, 64, Color(0.1, 0.1, 0.1, .9), "center", 600, "caveat")
		ci.draw_set_transform(Vector2.ZERO, 0))
	var page := Mk.mat(Mk.c(0xa9a294), .95)
	var cover := Mk.mat(Color.WHITE, .75, 0.0, {"map": cover_tex, "rim": .3})
	var back := Mk.mat(Mk.c(0x151311), .7)
	Mk.mi(Mk.rounded_box(Vector3(.15, .014, .21), .004, [page, page, cover, back, page, page], 3), null, Vector3(0, .007, 0), self)
	Mk.mi(Mk.box(Vector3(.004, .0152, .212)), Mk.mat(Mk.c(0x0a0a0a), .5), Vector3(.055, .007, 0), self)
	var pen := Mk.mi(Mk.cyl(.0045, .0045, .14, 24), Mk.mat(Mk.c(0x0d0d0d), .25, 0.0, {"clearcoat": 1.0}), Vector3(.02, .018, .14), self)
	pen.basis = Mk.euler_xyz(0, .5, PI / 2)
