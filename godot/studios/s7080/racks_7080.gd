class_name Racks7080
## Matériel de rack d'époque (années 70) : des machines du même type que celles de l'époque, avec leur
## allure (gros VU rétroéclairés, potards bakélite « tête de poulet », boutons de ratio blancs…), mais des
## marques et des façades inventées. Chaque appareil = une texture de façade (sérigraphie, petit nom dans
## un coin) + les reliefs en 3D (potards, VU sous verre, boutons, inverseurs, voyants).
##
## Spécification d'un appareil : {u, face, ink, brand, model, knobs, vus, buttons, toggles, lamps, leds, display}
## Positions en fraction de la façade (x : 0 = gauche, 1 = droite ; y : 0 = haut, 1 = bas).

const U := .04445

static var _mats := {}
static var _meshes := {}


## Les modèles (inventés) : type d'appareil, couleur de façade, implantation.
static func catalog() -> Dictionary:
	return {
		"opto": {"u": 3, "face": Color(.62, .62, .6), "ink": Color(.08, .08, .08), "brand": "TELEFORM", "model": "LV-2  LEVELING AMPLIFIER",
			"vus": [[.5, .48, .2, .62]], "knobs": [[.18, .55, "big", 1.0], [.82, .55, "big", 1.0]],
			"toggles": [[.32, .62], [.68, .62]], "lamps": [[.32, .3, Color(1, .25, .1)]]},
		"fet": {"u": 2, "face": Color(.1, .1, .11), "ink": Color(.85, .84, .8), "brand": "HALCYON", "model": "1078  LIMITING AMPLIFIER",
			"vus": [[.84, .5, .17, .78]], "knobs": [[.13, .52, "big", .9], [.3, .52, "big", .9], [.46, .45, "small", .8], [.46, .78, "small", .8]],
			"buttons": [[.58, .32, Color(.92, .9, .86)], [.63, .32, Color(.92, .9, .86)], [.58, .68, Color(.92, .9, .86)], [.63, .68, Color(.92, .9, .86)]],
			"toggles": [[.72, .5]]},
		"tube_eq": {"u": 3, "face": Color(.24, .34, .42), "ink": Color(.88, .86, .8), "brand": "PULSAR", "model": "EQ-1P  PROGRAM EQUALIZER",
			"knobs": [[.1, .4, "chicken", 1.0], [.22, .4, "chicken", 1.0], [.34, .4, "chicken", 1.0], [.5, .4, "chicken", 1.0], [.64, .4, "chicken", 1.0], [.78, .4, "chicken", 1.0], [.22, .78, "small", .8], [.5, .78, "small", .8]],
			"lamps": [[.9, .4, Color(1, .2, .1)]], "toggles": [[.9, .75]]},
		"vca": {"u": 1, "face": Color(.08, .08, .09), "ink": Color(.86, .84, .8), "brand": "DYNATONE", "model": "160  COMPRESSOR/LIMITER",
			"vus": [[.62, .5, .13, .78]], "knobs": [[.12, .5, "small", .8], [.26, .5, "small", .8], [.4, .5, "small", .8]],
			"buttons": [[.8, .5, Color(.25, .25, .25)], [.85, .5, Color(.25, .25, .25)]], "leds": [[.5, .3, Color(1, .2, .1)], [.5, .7, Color(.2, 1, .3)]]},
		"gate": {"u": 1, "face": Color(.18, .2, .22), "ink": Color(.86, .84, .8), "brand": "KESTREL", "model": "GK-2  NOISE GATE",
			"knobs": [[.1, .5, "small", .7], [.18, .5, "small", .7], [.26, .5, "small", .7], [.34, .5, "small", .7], [.58, .5, "small", .7], [.66, .5, "small", .7], [.74, .5, "small", .7], [.82, .5, "small", .7]],
			"leds": [[.42, .5, Color(1, .2, .1)], [.9, .5, Color(1, .2, .1)]]},
		"nr": {"u": 1, "face": Color(.55, .55, .53), "ink": Color(.1, .1, .1), "brand": "SILENCER", "model": "NR-361  NOISE REDUCTION",
			"leds": [[.7, .5, Color(.2, 1, .3)], [.76, .5, Color(1, .7, .1)]], "toggles": [[.85, .5]], "buttons": [[.15, .5, Color(.85, .85, .8)]]},
		"echo": {"u": 2, "face": Color(.12, .1, .09), "ink": Color(.9, .8, .6), "brand": "ORBITONE", "model": "TE-201  TAPE ECHO",
			"vus": [[.12, .5, .12, .7]], "knobs": [[.3, .5, "silver", .9], [.42, .5, "silver", .9], [.54, .5, "silver", .9], [.66, .5, "silver", .9], [.78, .5, "silver", .9]],
			"toggles": [[.9, .5]]},
		"harmonizer": {"u": 2, "face": Color(.1, .1, .11), "ink": Color(.82, .8, .76), "brand": "VENTURA", "model": "H-919  HARMONIZER",
			"display": [.18, .5, .18, .5], "knobs": [[.42, .5, "big", .8], [.56, .5, "small", .8], [.66, .5, "small", .8]],
			"buttons": [[.78, .35, Color(.85, .2, .15)], [.83, .35, Color(.9, .9, .85)], [.78, .68, Color(.9, .9, .85)], [.83, .68, Color(.9, .9, .85)]]},
		"amp": {"u": 3, "face": Color(.12, .12, .13), "ink": Color(.85, .84, .8), "brand": "CROWNLINE", "model": "DC-300  POWER AMPLIFIER",
			"vus": [[.35, .45, .16, .55], [.62, .45, .16, .55]], "knobs": [[.18, .55, "small", .9], [.8, .55, "small", .9]], "toggles": [[.9, .7]],
			"lamps": [[.9, .3, Color(1, .6, .1)]]},
		"patch": {"u": 2, "face": Color(.08, .08, .08), "ink": Color(.9, .9, .9), "brand": "", "model": "", "patch": true},
	}


## Remplit une baie de `count` unités : liste de noms d'appareils, variée selon `seed`.
static func layout(seed: int, count: int) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var pool := ["opto", "fet", "tube_eq", "vca", "gate", "nr", "echo", "harmonizer", "amp", "fet", "tube_eq", "opto", "echo", "harmonizer"]
	var out := []
	var used := 0
	var first := true
	while used < count:
		var name: String = "patch" if first and seed % 3 == 0 else pool[r.randi() % pool.size()]
		first = false
		var u: int = catalog()[name].u
		if used + u > count:
			out.append("blank%d" % (count - used))
			break
		out.append(name)
		used += u
		if r.randf() < .18 and used < count:
			out.append("vent")
			used += 1
	return out


static func panel_mat(name: String) -> Material:
	if _mats.has(name):
		return _mats[name]
	var spec: Dictionary = catalog().get(name, {})
	var units := int(spec.get("u", 1))
	if name.begins_with("blank"):
		units = int(name.substr(5))
	elif name == "vent":
		units = 1
	var face: Color = spec.get("face", Color(.1, .1, .1))
	var ink: Color = spec.get("ink", Color(.8, .8, .8))
	var draw := func(ci: CanvasItem, w: float, h: float) -> void:
		ci.draw_rect(Rect2(0, 0, w, h), face)
		Tex.brushed(ci, w, h, name.length() * 7 + units, .025, 1500)
		# oreilles de rack (plus sombres) + trous oblongs
		for sx in [0.0, w - 34.0]:
			ci.draw_rect(Rect2(sx, 0, 34, h), Color(0, 0, 0, .12))
		if name == "vent":
			var x := 100.0
			while x < w - 100:
				ci.draw_rect(Rect2(x, h * .25, 9, h * .5), Color(0, 0, 0, .9))
				x += 20
			return
		if name.begins_with("blank"):
			return
		if spec.get("patch", false):
			# baie de brassage : deux rangées de jacks + bandeaux d'étiquettes
			for row in 2:
				var y := h * (.32 + row * .42)
				ci.draw_rect(Rect2(60, y - h * .2, w - 120, h * .08), Color(.92, .9, .84))
				for k in 24:
					var x := 70.0 + k * ((w - 140) / 24.0) + 8
					ci.draw_circle(Vector2(x, y + h * .03), 6.5, Color(.02, .02, .02))
					ci.draw_circle(Vector2(x, y + h * .03), 9, Color(.5, .5, .5, .5))
			return
		# petit nom dans un coin (comme le vrai matériel) + modèle encore plus petit
		var big := units >= 2
		Tex.silk(ci, spec.brand, 48, h * (.2 if big else .36), 22 if big else 15, ink, "left", 800)
		Tex.silk(ci, spec.model, 48, h * (.2 if big else .36) + (20 if big else 13), 11 if big else 9, Color(ink.r, ink.g, ink.b, .7), "left", 600)
		# graduations autour des potards
		for k in spec.get("knobs", []):
			var c := Vector2(float(k[0]) * w, float(k[1]) * h)
			var rad := h * (.26 if k[2] == "big" or k[2] == "chicken" else .18) * float(k[3]) * (1.0 if units > 1 else 1.6)
			for i in 11:
				var a := deg_to_rad(-140 + i * 28)
				ci.draw_line(c + Vector2(sin(a), -cos(a)) * rad * 1.05, c + Vector2(sin(a), -cos(a)) * rad * 1.25, Color(ink.r, ink.g, ink.b, .8), 2.0)
		# fonds de VU : cadran crème avec échelle, zone rouge, mention VU
		for v in spec.get("vus", []):
			var rc := Rect2((float(v[0]) - float(v[2]) / 2) * w, (float(v[1]) - float(v[3]) / 2) * h, float(v[2]) * w, float(v[3]) * h)
			ci.draw_rect(rc.grow(5), Color(.05, .05, .05))
			ci.draw_rect(rc, Color(.98, .82, .5))
			var pc := Vector2(rc.get_center().x, rc.end.y + rc.size.y * .35)
			var rr := rc.size.y * 1.05
			ci.draw_arc(pc, rr * .82, deg_to_rad(-130), deg_to_rad(-50), 40, Color(.1, .08, .05), 2.0)
			ci.draw_arc(pc, rr * .82, deg_to_rad(-62), deg_to_rad(-50), 10, Color(.8, .1, .05), 4.0)
			for i in 9:
				var a := deg_to_rad(-130 + i * 10)
				ci.draw_line(pc + Vector2(cos(a), sin(a)) * rr * .82, pc + Vector2(cos(a), sin(a)) * rr * .9, Color(.1, .08, .05), 2.0)
			Tex.silk(ci, "VU", rc.get_center().x, rc.position.y + rc.size.y * .72, 14, Color(.1, .08, .05), "center", 700)
			var na := deg_to_rad(-112)
			ci.draw_line(pc, pc + Vector2(cos(na), sin(na)) * rr * .92, Color(.08, .06, .04), 2.5)
		if spec.has("display"):
			var d: Array = spec.display
			var rc := Rect2((float(d[0]) - float(d[2]) / 2) * w, (float(d[1]) - float(d[3]) / 2) * h, float(d[2]) * w, float(d[3]) * h)
			ci.draw_rect(rc, Color(.08, .01, .01))
			Tex.silk(ci, "1.500", rc.get_center().x, rc.get_center().y + rc.size.y * .25, int(rc.size.y * .7), Color(1, .15, .1), "center", 700)
	var tex := Tex.canvas(1024, int(1024 * units * U / .483), draw)
	var m := Mk.mat(Color.WHITE, .45, .5, {"map": tex})
	_mats[name] = m
	return m


## Reliefs 3D d'un appareil (repère de la baie : façade à z = 0, vers +Z ; cy = milieu vertical).
static func hardware(g: Node3D, name: String, cy: float, uh: float, bw: float) -> void:
	var spec: Dictionary = catalog().get(name, {})
	if spec.is_empty():
		return
	_init_meshes()
	var units: int = spec.u
	var px := func(fx: float) -> float: return (fx - .5) * bw
	var py := func(fy: float) -> float: return cy + uh / 2 - fy * uh
	for k in spec.get("knobs", []):
		var s: float = float(k[3]) * (1.0 if units > 1 else .9)
		var mount := Node3D.new()
		mount.position = Vector3(px.call(float(k[0])), py.call(float(k[1])), .002)
		mount.rotation.x = PI / 2
		mount.scale = Vector3.ONE * s
		g.add_child(mount)
		var kn := Node3D.new()   # le potard tourne sur son axe
		kn.rotation.y = randf_range(-2.2, 2.2)
		mount.add_child(kn)
		match String(k[2]):
			"big":
				Mk.mi(_meshes.skirt_big, _mats_k().alu, Vector3(0, .001, 0), kn)
				Mk.mi(_meshes.knob_big, _mats_k().black, Vector3(0, .011, 0), kn)
				Mk.mi(_meshes.line, _mats_k().white, Vector3(0, .0215, -.008), kn)
			"chicken":
				Mk.mi(_meshes.chicken_base, _mats_k().bakelite, Vector3(0, .006, 0), kn)
				var ptr := Mk.mi(_meshes.chicken_ptr, _mats_k().bakelite, Vector3(0, .012, -.006), kn)
				ptr.rotation.y = 0.0
				Mk.mi(_meshes.line, _mats_k().white, Vector3(0, .0172, -.012), kn)
			"silver":
				Mk.mi(_meshes.knob_small, _mats_k().alu, Vector3(0, .007, 0), kn)
				Mk.mi(_meshes.line, _mats_k().black, Vector3(0, .0142, -.004), kn)
			_:
				Mk.mi(_meshes.skirt_small, _mats_k().alu, Vector3(0, .001, 0), kn)
				Mk.mi(_meshes.knob_small, _mats_k().black, Vector3(0, .007, 0), kn)
				Mk.mi(_meshes.line, _mats_k().white, Vector3(0, .0142, -.004), kn)
	for v in spec.get("vus", []):
		# verre bombé + cadre noir + rétroéclairage ambré
		var w: float = float(v[2]) * bw
		var h: float = float(v[3]) * uh
		var at := Vector3(px.call(float(v[0])), py.call(float(v[1])), .002)
		for sy in [-1, 1]:
			Mk.mi(Mk.box(Vector3(w + .008, .004, .006)), _mats_k().black, at + Vector3(0, sy * (h / 2 + .002), .003), g)
		for sx in [-1, 1]:
			Mk.mi(Mk.box(Vector3(.004, h + .008, .006)), _mats_k().black, at + Vector3(sx * (w / 2 + .002), 0, .003), g)
		Mk.mi(Mk.quad(w, h), _mats_k().vu_glow, at + Vector3(0, 0, .0045), g)
		Mk.mi(Mk.quad(w, h), _mats_k().glass, at + Vector3(0, 0, .0062), g)
	for b in spec.get("buttons", []):
		var bm := Mk.mat(b[2], .45, 0.0)
		Mk.mi(Mk.rounded_box(Vector3(.011, .011, .007), .0015, bm, 1), null, Vector3(px.call(float(b[0])), py.call(float(b[1])), .0045), g)
	for t in spec.get("toggles", []):
		var at := Vector3(px.call(float(t[0])), py.call(float(t[1])), .002)
		var nut := Mk.mi(_meshes.nut, _mats_k().alu, at, g)
		nut.rotation.x = PI / 2
		var bat := Mk.mi(_meshes.bat, _mats_k().chrome, at + Vector3(0, .003, .008), g)
		bat.rotation.x = PI / 2 - .5
	for l in spec.get("lamps", []):
		var lm := Mk.glow(l[2], 2.5)
		var j := Mk.mi(Mk.sphere(.0055, 12, 6, true), lm, Vector3(px.call(float(l[0])), py.call(float(l[1])), .002), g)
		j.rotation.x = PI / 2
		var ring := Mk.mi(_meshes.nut, _mats_k().chrome, Vector3(px.call(float(l[0])), py.call(float(l[1])), .002), g)
		ring.rotation.x = PI / 2
		ring.scale = Vector3(1.3, .5, 1.3)
	for l in spec.get("leds", []):
		var led := Mk.mi(Mk.sphere(.0026, 8, 5, true), Mk.glow(l[2], 2.2), Vector3(px.call(float(l[0])), py.call(float(l[1])), .002), g)
		led.rotation.x = PI / 2
	if spec.has("display"):
		var d: Array = spec.display
		var dm := StandardMaterial3D.new()
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dm.albedo_color = Color(1, .1, .05, .4)
		Mk.mi(Mk.quad(float(d[2]) * bw * .96, float(d[3]) * uh * .9), _mats_k().glass, Vector3(px.call(float(d[0])), py.call(float(d[1])), .004), g)
		Mk.mi(Mk.quad(float(d[2]) * bw * .9, float(d[3]) * uh * .8), dm, Vector3(px.call(float(d[0])), py.call(float(d[1])), .0025), g)
	if spec.get("patch", false):
		# quelques cordons de brassage qui pendent
		var cols := [Color(.7, .1, .08), Color(.08, .08, .08), Color(.1, .25, .6), Color(.8, .7, .1)]
		for i in 6:
			var x0: float = px.call(.12 + randf() * .76)
			var x1: float = px.call(.12 + randf() * .76)
			var y0: float = py.call(.35)
			var y1: float = py.call(.77)
			var cm := Mk.mat(cols[i % cols.size()], .5)
			Mk.mi(Mk.tube([Vector3(x0, y0, .004), Vector3(x0, y0 - .02, .03), Vector3((x0 + x1) / 2, cy - uh * 1.2, .06), Vector3(x1, y1 - .02, .03), Vector3(x1, y1, .004)], .0022, 24, 6), cm, Vector3.ZERO, g)
	# poignées sur les appareils de 2U et plus
	if units >= 2:
		for sx in [-1, 1]:
			var x: float = sx * (bw / 2 - .024)
			var t := Vector3(x, cy + uh / 2 - .012, .0)
			var bt := Vector3(x, cy - uh / 2 + .012, .0)
			Mk.mi(Mk.tube([t, t + Vector3(0, -.003, .022), bt + Vector3(0, .003, .022), bt], .0038, 16, 8), _mats_k().chrome, Vector3.ZERO, g)


static func _init_meshes() -> void:
	if not _meshes.is_empty():
		return
	_meshes.knob_big = Mk.cyl(.011, .0125, .018, 24)
	_meshes.skirt_big = Mk.cyl(.016, .0165, .003, 28)
	_meshes.knob_small = Mk.cyl(.0065, .0075, .012, 18)
	_meshes.skirt_small = Mk.cyl(.0095, .01, .002, 20)
	_meshes.line = Mk.box(Vector3(.0014, .0008, .007))
	_meshes.chicken_base = Mk.cyl(.0105, .012, .012, 20)
	_meshes.chicken_ptr = Mk.box(Vector3(.008, .009, .03))
	_meshes.nut = Mk.cyl(.0045, .0045, .004, 6)
	_meshes.bat = Mk.cyl(.0012, .0022, .016, 8)


static func _mats_k() -> Dictionary:
	if not _mats.has("_k"):
		var vu := StandardMaterial3D.new()   # rétroéclairage ambré, ajouté par-dessus le cadran imprimé
		vu.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		vu.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		vu.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		vu.albedo_color = Color(1.0, .55, .2, .35)
		var glass := Mk.mat(Color(1, 1, 1, .1), .03, 0.0, {"clearcoat": 1.0})
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mats["_k"] = {
			"black": Mk.mat(Mk.c(0x141414), .38, .1, {"clearcoat": .4}),
			"white": Mk.mat(Mk.c(0xf0ece4), .5),
			"alu": Mk.mat(Mk.c(0xb0aca4), .28, 1.0),
			"chrome": Mk.chrome_mat(),
			"bakelite": Mk.mat(Mk.c(0x1a0e08), .3, 0.0, {"clearcoat": .7}),
			"vu_glow": vu,
			"glass": glass,
		}
	return _mats["_k"]
