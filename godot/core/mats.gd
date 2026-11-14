class_name Mats
## Bibliothèque de matières du studio, pour varier les meubles : essences de bois (noyer, teck,
## palissandre, chêne clair), laques, velours, velours côtelé, skaï, formica, métal brossé, tôle
## perforée, tolex de flight case. Les textures « teak_wood », « rosewood », « light_oak »,
## « corduroy », « velvet », « vinyl » sont cuites dans Blender (blender/bake_textures.py).
## Chaque appel avec les mêmes paramètres renvoie le même matériau (mis en cache).

static var _cache := {}


static func _cached(key: String, make: Callable) -> Material:
	if not _cache.has(key):
		_cache[key] = make.call()
	return _cache[key]


## Bois : "walnut" | "teak" | "rosewood" | "oak". `wear` = patine (0 = presque neuf).
static func wood(kind: String, wear := .45, size := .7) -> Material:
	var key := "wood:%s:%.2f:%.2f" % [kind, wear, size]
	if _cache.has(key):
		return _cache[key]
	var m: Material
	if kind == "teak":
		m = Mk.pbr("teak_wood", size, {"wear": wear, "tint": Mk.c(0xffc890), "rough": .65, "clearcoat": .35, "clearcoat_rough": .3})
	elif kind == "rosewood":
		m = Mk.pbr("rosewood", size * .8, {"wear": wear, "tint": Mk.c(0xe8d8d0), "rough": .55, "clearcoat": .6, "clearcoat_rough": .18})
	elif kind == "oak":
		m = Mk.pbr("light_oak", size, {"wear": wear, "rough": .8, "clearcoat": .12, "clearcoat_rough": .5})
	else:
		m = Mk.pbr("dark_wood", size, {"wear": wear, "tint": Mk.c(0xc89878), "rough": .8, "clearcoat": .4, "clearcoat_rough": .35})
	_cache[key] = m
	return m


## Laque brillante (bois laqué, fibre de verre) : peau d'orange très légère.
static func lacquer(col: Color) -> Material:
	return _cached("lacq:" + col.to_html(), func() -> Material:
		return Mk.mat(col, .22, 0.0, {"clearcoat": 1.0, "clearcoat_rough": .06, "normal": Mk.noise_tex(.9, 256, 2), "normal_scale": .05}))


## Velours : reflet doux sur les bords (sheen) et zones écrasées.
static func velvet(col: Color) -> Material:
	return _cached("velv:" + col.to_html(), func() -> Material:
		var m: StandardMaterial3D = (Mk.pbr("velvet", .35, {"tint": col, "rough": 1.0, "normal_scale": .6}) as StandardMaterial3D).duplicate()
		m.rim_enabled = true
		m.rim = .75
		m.rim_tint = .55
		return m)


static func corduroy(col: Color) -> Material:
	return _cached("cord:" + col.to_html(), func() -> Material:
		var m: StandardMaterial3D = (Mk.pbr("corduroy", .12, {"tint": col, "rough": .95, "normal_scale": 1.4}) as StandardMaterial3D).duplicate()
		m.rim_enabled = true
		m.rim = .45
		m.rim_tint = .5
		return m)


## Skaï / vinyle : grain de cuir synthétique, un peu brillant.
static func vinyl(col: Color) -> Material:
	return _cached("vinyl:" + col.to_html(), func() -> Material:
		return Mk.pbr("vinyl", .18, {"tint": col, "rough": .38, "clearcoat": .55, "clearcoat_rough": .2, "normal_scale": .8}))


## Stratifié façon formica : motif « boomerang » années 50-70 sur fond uni, vernis.
static func formica(base: Color) -> Material:
	return _cached("form:" + base.to_html(), func() -> Material:
		var draw := func(ci: CanvasItem, w: float, h: float) -> void:
			ci.draw_rect(Rect2(0, 0, w, h), base)
			var r := Tex.rng(1955)
			var inks := [base.darkened(.35), base.lightened(.4), Color(.85, .5, .2, .8), Color(.2, .35, .45, .7)]
			for i in 70:
				var c := Vector2(r.randf() * w, r.randf() * h)
				var a := r.randf() * TAU
				var s := 10.0 + r.randf() * 16.0
				var k: Color = inks[i % inks.size()]
				var p1 := c + Vector2.from_angle(a) * s * 1.6
				var p2 := c + Vector2.from_angle(a + 2.3) * s * 1.2
				ci.draw_colored_polygon(PackedVector2Array([c, p1, c.lerp(p1, .5) + Vector2.from_angle(a + 1.2) * s * .3, p2]), Color(k.r, k.g, k.b, .55))
			for i in 900:
				ci.draw_circle(Vector2(r.randf() * w, r.randf() * h), 1.2, Color(0, 0, 0, .12) if r.randf() < .5 else Color(1, 1, 1, .12))
		var m := Mk.mat(Color.WHITE, .3, 0.0, {"map": Tex.canvas(512, 512, draw), "clearcoat": .5, "clearcoat_rough": .2})
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * 2.0
		return m)


static func brushed_steel() -> Material:
	return _cached("steel", func() -> Material:
		return Mk.mat(Mk.c(0xa8a8a6), .32, 1.0, {"normal": Mk.scratch_normal(), "normal_scale": .25}))


## Tôle perforée (trous ronds en quinconce), peinte en gris martelé.
static func perforated() -> Material:
	return _cached("perf", func() -> Material:
		var draw := func(ci: CanvasItem, w: float, h: float) -> void:
			ci.draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, 1))
			for j in 16:
				for i in 16:
					var x := (i + (.5 if j % 2 else 0.0)) * w / 16.0
					ci.draw_circle(Vector2(x, (j + .5) * h / 16.0), w / 16.0 * .3, Color(0, 0, 0, 0))
		var m := Mk.mat(Mk.c(0x6a6c6c), .5, .7, {"map": Tex.canvas(256, 256, draw, true), "cull_off": true})
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * 6.0
		return m)


## Tolex noir de flight case (grain marqué, mat).
static func tolex() -> Material:
	return _cached("tolex", func() -> Material:
		return Mk.pbr("vinyl", .08, {"tint": Mk.c(0x2a2a2c), "rough": .75, "normal_scale": 1.6}))
