class_name Deco7080
extends Node3D
## Déco de la régie 70/80, « session en cours » : enceintes (grandes suspendues + petites sur le bureau),
## fauteuil cuir capitonné, lampes, téléphone à cadran, tasses, cendrier, bandes, casque, disques, plante…
## Le centre du bureau devant la vitre reste libre pour les futures machines.

const TOP := 0.818  # dessus du bureau

var _leather_brown: StandardMaterial3D
var _walnut: StandardMaterial3D
var _black: StandardMaterial3D
var _chrome: StandardMaterial3D
var _brass: StandardMaterial3D


func _init() -> void:
	name = "Deco7080"
	_leather_brown = Mk.weather(Mk.mat(Mk.c(0x6a3820), .5, 0.0, {"clearcoat": .25, "clearcoat_rough": .5}), _grain(), .5, .15)
	_walnut = Mk.mat(Mk.c(0x6a4028), .55, 0.0, {"map": Mk.walnut_tex(), "clearcoat": .3})
	_black = Mk.mat(Mk.c(0x121212), .45, .1)
	_chrome = Mk.chrome_mat()
	_brass = Mk.mat(Mk.c(0xc89a48), .3, 1.0)
	_big_speakers()
	_nearfields()
	_chair()
	_architect_lamp()
	_floor_lamp()
	_desk_objects()
	_floor_objects()
	_plant()
	_wall_frames()


func _put(n: Node3D, pos: Vector3, rot_y := 0.0, parent: Node3D = null) -> Node3D:
	n.position = pos
	n.rotation.y = rot_y
	(parent if parent else self).add_child(n)
	return n


# ---------------------------------------------------------------- enceintes
func _grille_tex(drivers: Array) -> Texture2D:
	return Tex.canvas(256, 384, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x6a5e52))
		for d in drivers:
			for k in 6:
				ci.draw_circle(Vector2(d[0] * w, d[1] * h), d[2] * w * (1.0 - k * .04), Mk.c(0x4a4038).lerp(Mk.c(0x2a2420), k / 6.0))
		var r := Tex.rng(4)
		for i in 4000:
			ci.draw_rect(Rect2(r.randf() * w, r.randf() * h, 1, 1), Color(1, 1, 1, .05) if r.randf() > .5 else Color(0, 0, 0, .1))
		ci.draw_rect(Rect2(w * .38, h * .9, w * .24, h * .035), Mk.c(0xc8a050)))


## Grandes enceintes de monitoring suspendues de chaque côté de la vitre, inclinées vers l'écoute :
## caisson en noyer, baffle sombre, boomer 30 cm, pavillon d'aigu, évents, vis, plaque laiton.
func _big_speakers() -> void:
	var baffle := Mk.mat(Mk.c(0x1c1714), .7)
	var cone := Mk.mat(Mk.c(0x2a2622), .85)
	var surround := Mk.mat(Mk.c(0x141210), .6)
	var horn := Mk.mat(Mk.c(0x1a1a1a), .35, .5)
	for s in [[.27, PI - .3], [2.74, PI + .3]]:
		var root := Node3D.new()
		root.position = Vector3(s[0], 1.56, -.22)
		root.basis = Basis(Vector3.UP, s[1]) * Basis(Vector3.RIGHT, .22)
		add_child(root)
		Mk.mi(Mk.rounded_box(Vector3(.42, .6, .32), .012, _walnut, 3), null, Vector3(0, 0, -.165), root)
		Mk.mi(Mk.rounded_box(Vector3(.39, .57, .02), .004, baffle, 2), null, Vector3(0, 0, -.005), root)
		# boomer
		var w := Node3D.new()
		w.position = Vector3(0, -.09, .006)
		root.add_child(w)
		var c1 := Mk.mi(Mk.lathe([[0, -.05], [.03, -.045], [.13, -.008], [.135, 0], [0, 0]], 48), cone, Vector3.ZERO, w)
		c1.rotation.x = PI / 2
		var r1 := Mk.mi(Mk.torus_ring(.142, .012), surround, Vector3(0, 0, 0), w)
		r1.rotation.x = PI / 2
		var r2 := Mk.mi(Mk.torus_ring(.163, .006), _chrome, Vector3(0, 0, .002), w)
		r2.rotation.x = PI / 2
		var cap := Mk.mi(Mk.sphere(.035, 20, 10, true), Mk.mat(Mk.c(0x8a8680), .4, .8), Vector3(0, 0, -.035), w)
		cap.rotation.x = PI / 2
		cap.scale = Vector3(1, .5, 1)
		for i in 8:
			var a := i * TAU / 8
			var sc := Mk.screw_head(.004)
			sc.rotation.x = PI / 2
			sc.position = Vector3(cos(a) * .165, sin(a) * .165, .004)
			w.add_child(sc)
		# pavillon d'aigu (évasé rectangulaire)
		var hn := Node3D.new()
		hn.position = Vector3(0, .17, .006)
		root.add_child(hn)
		Mk.mi(Mk.rounded_box(Vector3(.22, .1, .012), .004, horn, 2), null, Vector3(0, 0, 0), hn)
		var throat := Mk.mi(Mk.cyl(.012, .07, .07, 24, false), Mk.mat(Mk.c(0x0a0a0a), .5, .3, {"cull_off": true}), Vector3(0, 0, -.03), hn)
		throat.rotation.x = -PI / 2
		throat.scale = Vector3(1.4, 1, .6)
		# évents et plaque
		for x in [-.13, .13]:
			var port := Mk.mi(Mk.cyl(.022, .022, .03, 20, false), Mk.mat(Mk.c(0x050505), .8, 0.0, {"cull_off": true}), Vector3(x, .17, 0), root)
			port.rotation.x = PI / 2
		Mk.mi(Mk.rounded_box(Vector3(.09, .022, .004), .002, _brass), null, Vector3(0, -.255, .008), root)
		Mk.mi(Mk.quad(.08, .016), _badge_mat("REEL'S  MONITOR", Mk.c(0xc89a48), Mk.c(0x1a1208)), Vector3(0, -.255, .0105), root)
		# atténuateurs HF / MF sur le baffle
		for k in 2:
			var kn := Mk.knob(.009, .01)
			kn.rotation.x = PI / 2
			kn.position = Vector3(-.16 + k * .03, -.255, .005)
			root.add_child(kn)
		# étiquette de scotch « L » / « R » sur le dessus
		var tape := Mk.mi(Mk.plane(.07, .04), _badge_mat("L" if s[0] < 1.5 else "R", Mk.c(0xe8e0c8), Mk.c(0x1a1a40), "caveat"), Vector3(0, .301, -.08), root)
		tape.rotation.y = .05
		# patte de fixation au plafond
		var rod := Mk.mi(Mk.cyl(.012, .012, .5, 8), _black, Vector3(s[0], 1.85, -.2), self)
		rod.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Enceintes de proximité sur le bureau : caisson noir, baffle en retrait, membrane blanche,
## vis, dôme d'aigu protégé, évent, plaque, bornier et câble à l'arrière.
func _nearfields() -> void:
	var listener := Vector3(1.7, 1.15, -1.6)
	var cone := Mk.mat(Mk.c(0xe8e4da), .7)
	var cab := Mk.mat(Mk.c(0x141414), .4, 0.0, {"clearcoat": .3})
	for x in [1.08, 2.32]:
		var root := Node3D.new()
		var pos := Vector3(x, TOP + .245, -.2)
		var to := listener - pos
		root.position = pos
		root.rotation.y = atan2(to.x, to.z)
		add_child(root)
		Mk.mi(Mk.rounded_box(Vector3(.2, .33, .2), .008, cab, 3), null, Vector3(0, .165, 0), root)
		Mk.mi(Mk.rounded_box(Vector3(.18, .31, .01), .003, Mk.mat(Mk.c(0x0c0c0c), .6), 2), null, Vector3(0, .165, .098), root)
		var w := Node3D.new()
		w.position = Vector3(0, .11, .104)
		root.add_child(w)
		var c1 := Mk.mi(Mk.lathe([[0, -.022], [.02, -.02], [.068, -.003], [.072, 0], [0, 0]], 40), cone, Vector3.ZERO, w)
		c1.rotation.x = PI / 2
		var sr := Mk.mi(Mk.torus_ring(.074, .005), _black, Vector3.ZERO, w)
		sr.rotation.x = PI / 2
		var cap := Mk.mi(Mk.sphere(.02, 16, 8, true), Mk.mat(Mk.c(0xd8d2c6), .6), Vector3(0, 0, -.018), w)
		cap.rotation.x = PI / 2
		cap.scale = Vector3(1, .45, 1)
		for i in 4:
			var a := PI / 4 + i * PI / 2
			var sc := Mk.screw_head(.0035)
			sc.rotation.x = PI / 2
			sc.position = Vector3(cos(a) * .082, sin(a) * .082, .001)
			w.add_child(sc)
		var tw := Node3D.new()
		tw.position = Vector3(0, .255, .104)
		root.add_child(tw)
		var dome := Mk.mi(Mk.sphere(.013, 16, 8, true), Mk.mat(Mk.c(0x2a2a2a), .3, .2), Vector3.ZERO, tw)
		dome.rotation.x = PI / 2
		dome.scale = Vector3(1, .6, 1)
		var guard := Mk.mi(Mk.torus_ring(.022, .003), _chrome, Vector3(0, 0, .002), tw)
		guard.rotation.x = PI / 2
		var port := Mk.mi(Mk.cyl(.012, .012, .02, 16, false), Mk.mat(Mk.c(0x050505), .8, 0.0, {"cull_off": true}), Vector3(.055, .03, .1), root)
		port.rotation.x = PI / 2
		Mk.mi(Mk.quad(.05, .012), _badge_mat("REEL'S", Mk.c(0xb8b4ac), Mk.c(0x141414)), Vector3(-.05, .03, .1035), root)
		# papier mouchoir scotché devant le tweeter (astuce de studio)
		var tissue := Mk.mi(Mk.quad(.07, .06), Mk.mat(Mk.c(0xf4f2ec), .95, 0.0, {"alpha": .82, "cull_off": true}), Vector3(.004, .257, .106), root)
		tissue.rotation.z = .06
		Mk.mi(Mk.quad(.015, .03), Mk.mat(Mk.c(0xd8c890), .6, 0.0, {"alpha": .7}), Vector3(-.03, .285, .107), root)
		var tape := Mk.mi(Mk.plane(.05, .03), _badge_mat("L" if x > 1.5 else "R", Mk.c(0xe8e0c8), Mk.c(0x1a1a40), "caveat"), Vector3(0, .331, -.03), root)
		tape.rotation.y = -.08
		Mk.mi(Mk.rounded_box(Vector3(.05, .03, .006), .002, _black), null, Vector3(0, .07, -.102), root)
		var back := pos + root.basis * Vector3(0, .07, -.1)
		Mk.mi(Mk.tube([back, back + Vector3(0, -.03, .06), Vector3(back.x, TOP + .1, -.03), Vector3(back.x + .05, .4, -.04)], .004, 24, 6), _black, Vector3.ZERO, self)

var _badges := {}


## Grain du cuir (petites bosses irrégulières).
func _grain() -> Texture2D:
	var nt := NoiseTexture2D.new()
	nt.width = 512
	nt.height = 512
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = 3.0
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_CELLULAR
	fn.frequency = .09
	nt.noise = fn
	return nt


## Petite plaque ou étiquette avec du texte.
func _badge_mat(txt: String, bg: Color, ink: Color, fam := "archivo") -> StandardMaterial3D:
	var key := txt + str(bg) + fam
	if _badges.has(key):
		return _badges[key]
	var tex := Tex.canvas(256, 64, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), bg)
		Tex.silk(ci, txt, w / 2.0, h / 2.0, 40 if fam == "caveat" else 30, ink, "center", 700, fam)
		Tex.grime(ci, w, h, txt.length(), .4))
	var m := Mk.mat(Color.WHITE, .4, .6 if fam != "caveat" and bg.v > .5 else 0.0, {"map": tex})
	_badges[key] = m
	return m


## Fauteuil de direction 70s : cuir brun, capitonnage en losanges (boutons + plis), dossier rond
## enveloppant, accoudoirs pleins, pied étoile chromé. Reculé et tourné (session en cours).
func _chair() -> void:
	var c := Node3D.new()
	c.name = "Chair"
	_put(c, Vector3(1.85, 0, -1.55), .45)
	c.scale = Vector3.ONE * .86
	var tuft := _tufted_leather()
	var btn := Mk.mat(Mk.c(0x3e1d0e), .45, 0.0, {"clearcoat": .5})
	for i in 5:
		var a := i * TAU / 5
		var leg := Mk.mi(Mk.rounded_box(Vector3(.05, .035, .34), .014, _chrome, 2), null, Vector3(sin(a) * .16, .07, cos(a) * .16), c)
		leg.rotation.y = a
		Mk.mi(Mk.sphere(.027, 12, 6), _black, Vector3(sin(a) * .32, .027, cos(a) * .32), c)
	Mk.mi(Mk.cyl(.03, .03, .3, 16), _chrome, Vector3(0, .23, 0), c)
	Mk.mi(Mk.cyl(.06, .07, .05, 16), _black, Vector3(0, .37, 0), c)
	# assise : galette épaisse et ronde
	Mk.mi(Mk.rounded_box(Vector3(.6, .16, .56), .075, tuft, 5), null, Vector3(0, .47, .03), c)
	for p in _diamond_points(3, 3, .17, .15):
		Mk.mi(Mk.sphere(.009, 8, 4), btn, Vector3(p.x, .55, .03 + p.y), c)
	# dossier enveloppant : trois coussins arrondis (centre + deux ailes)
	var back := Node3D.new()
	back.position = Vector3(0, .86, -.24)
	back.rotation.x = -.16
	c.add_child(back)
	Mk.mi(Mk.rounded_box(Vector3(.46, .72, .16), .075, tuft, 5), null, Vector3.ZERO, back)
	for sx in [-1, 1]:
		var wing := Mk.mi(Mk.rounded_box(Vector3(.13, .66, .17), .06, tuft, 4), null, Vector3(sx * .27, -.02, .04), back)
		wing.rotation.y = -sx * .45
	for p in _diamond_points(3, 4, .13, .15):
		Mk.mi(Mk.sphere(.01, 8, 4), btn, Vector3(p.x, p.y, .081), back)
	# accoudoirs pleins
	for sx in [-1, 1]:
		Mk.mi(Mk.rounded_box(Vector3(.09, .2, .44), .04, _leather_brown, 4), null, Vector3(sx * .33, .6, .02), c)


## Positions des boutons d'un capitonnage en losanges (rangées décalées).
func _diamond_points(cols: int, rows: int, dx: float, dy: float) -> Array:
	var out := []
	for j in rows:
		var n := cols if j % 2 == 0 else cols - 1
		for i in n:
			var x := (i - (n - 1) / 2.0) * dx
			out.append(Vector2(x, (j - (rows - 1) / 2.0) * dy))
	return out


## Cuir capitonné : creux en losanges (carte de normales) + plis.
func _tufted_leather() -> StandardMaterial3D:
	var img := Image.create(256, 256, false, Image.FORMAT_L8)
	var centers := [Vector2(0, 0), Vector2(256, 0), Vector2(0, 256), Vector2(256, 256), Vector2(128, 128)]
	for y in 256:
		for x in 256:
			var v := 1.0
			for cc in centers:
				var d := Vector2(x, y).distance_to(cc)
				v -= .55 * exp(-d * d / 900.0)
			# plis en diagonale entre les boutons
			var dg := minf(absf(fmod(x + y, 256.0) - 128.0), absf(fmod(x - y + 512.0, 256.0) - 128.0))
			v -= .12 * exp(-pow(128.0 - dg, 2) / 30.0)
			img.set_pixel(x, y, Color(v, v, v))
	var m := Mk.mat(Mk.c(0x6a3820), .55, 0.0, {"normal": Tex.normal_from_bump(img, 5.0), "normal_scale": 1.0, "clearcoat": .22, "clearcoat_rough": .5})
	m.roughness_texture = Mk.noise_tex(.03)
	m.uv1_scale = Vector3(2, 2, 1)
	return m

# ---------------------------------------------------------------- lampes
## Lampe d'architecte posée sur le retour, tête au-dessus du bureau.
func _architect_lamp() -> void:
	var g := Node3D.new()
	g.name = "ArchitectLamp"
	arch_lamp = g
	_put(g, Vector3(.08, TOP, -1.62), -2.0)
	Mk.mi(Mk.cyl(.07, .08, .025, 32), _black, Vector3(0, .012, 0), g)
	var a1 := Mk.mi(Mk.cyl(.007, .007, .5, 10), _chrome, Vector3(0, .26, 0), g)
	a1.rotation.x = .12
	var a2 := Mk.mi(Mk.cyl(.007, .007, .36, 10), _chrome, Vector3(0, .5, .16), g)
	a2.rotation.x = 1.25
	var shade := Mk.mi(Mk.cyl(0.0, .07, .12, 32, false), Mk.mat(Mk.c(0x1a3020), .35, .2, {"cull_off": true}), Vector3(0, .48, .34), g)
	shade.rotation.x = -.5
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Mk.mi(Mk.sphere(.022, 16, 8), Mk.glow(Mk.c(0xffc27a), 3.0), Vector3(0, .45, .35), g)
	var sp := SpotLight3D.new()
	sp.light_color = Mk.c(0xffc890)
	sp.light_energy = .8
	sp.spot_range = 1.4
	sp.spot_angle = 45.0
	sp.shadow_enabled = true
	sp.position = Vector3(0, .44, .36)
	sp.basis = Basis.looking_at(Vector3(0, -1, .35), Vector3.FORWARD)
	g.add_child(sp)


## Lampadaire à abat-jour en tissu dans le coin, contre le mur en liège.
func _floor_lamp() -> void:
	var g := Node3D.new()
	g.name = "FloorLamp"
	_put(g, Vector3(.3, 0, -2.75))
	Mk.mi(Mk.cyl(.15, .16, .03, 32), _brass, Vector3(0, .015, 0), g)
	Mk.mi(Mk.cyl(.012, .012, 1.4, 10), _brass, Vector3(0, .72, 0), g)
	var shade := Mk.mi(Mk.cyl(.16, .23, .3, 40, false), Mk.mat(Mk.c(0xe8d2a8), .9, 0.0, {"emission": Mk.c(0xffb060), "energy": 1.8, "cull_off": true}), Vector3(0, 1.48, 0), g)
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l := OmniLight3D.new()
	l.light_color = Mk.c(0xffb870)
	l.light_energy = 1.4
	l.omni_range = 2.6
	l.shadow_enabled = true
	l.position = Vector3(0, 1.42, 0)
	g.add_child(l)


# ---------------------------------------------------------------- objets sur le bureau
func _desk_objects() -> void:
	# grande console sur le bureau principal, face à l'ingé (avant vers -Z)
	_console(Vector3(1.7, TOP, -.57), PI, 1.6, .74, 20)
	# (le module Tempo est accolé à droite de la console : voir Tempo7080)
	# l'angle et le retour restent libres pour les modules : objets en bout de bureau et au fond du retour
	_phone(Vector3(.31, TOP, -1.68), .5)
	_notepad(Vector3(2.62, TOP, -.85), .25)
	_mug(Vector3(.42, TOP, -.3), .8)
	_ashtray(Vector3(2.6, TOP, -.45))
	_tape_stack(Vector3(2.6, TOP, -.1), 3)
	_tape_stack(Vector3(.22, TOP, -.2), 2)
	# casque posé sur l'assise du fauteuil
	_headphones(Vector3(1.85, .475, -1.5), .8)


## Console de mixage posée sur le retour, tournée vers la pièce (+X) : 10 tranches + section master,
## pupitre incliné sérigraphié, potards EQ/aux/pan, boutons mute/solo éclairés, faders, scribble,
## pont de VU + baie de patch avec cordons, câbles qui partent derrière.
func _console(at: Vector3, rot: float, L: float, D: float, n: int) -> void:
	var g := Node3D.new()
	g.name = "MixConsole"
	_put(g, at, rot)  # avant de la console = +Z local
	var body := Mk.mat(Mk.c(0x2a2622), .5, .3)
	# caisse en biseau (plus haute à l'arrière), joues en noyer
	var prof := PackedVector2Array([Vector2(-D / 2, 0), Vector2(D / 2, 0), Vector2(D / 2, .045), Vector2(-D / 2, .12)])
	var box := Mk.mi(Mk.prism(prof, L), body, Vector3(L / 2, 0, 0), g)
	box.rotation.y = -PI / 2
	for sx in [-1, 1]:
		var cheek := Mk.mi(Mk.prism(PackedVector2Array([Vector2(-D / 2 - .01, 0), Vector2(D / 2 + .01, 0), Vector2(D / 2 + .01, .06), Vector2(-D / 2 - .01, .2), Vector2(-D / 2 + .05, .2)]), .025), _walnut, Vector3(sx * (L / 2 + .0125) + .0125, 0, 0), g)
		cheek.rotation.y = -PI / 2
	# pupitre incliné
	var master_w := .2     # section master à droite
	var sw := (L - .02 - master_w) / n
	var slope := atan2(.12 - .045, D)
	var plen := sqrt(D * D + pow(.12 - .045, 2))
	var deck := Node3D.new()
	deck.position = Vector3(0, (.12 + .045) / 2 + .001, 0)
	deck.rotation.x = slope
	g.add_child(deck)
	var rows := ["GAIN", "HI", "HI-MID", "LO-MID", "LO", "AUX 1", "AUX 2", "PAN"]
	var row_v := func(k: int) -> float: return -plen / 2 + .035 + k * .034
	var tex := Tex.canvas(2048, int(2048 * plen / L), func(ci, w, h):
		var P := func(m: float) -> float: return m / L * w
		var V := func(m: float) -> float: return (m + plen / 2) / plen * h
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0x3a3632))
		Tex.brushed(ci, w, h, 12, .04, 2500)
		var x_start: float = P.call(.01)
		var pw: float = P.call(sw)
		# bandes de couleur par section EQ
		ci.draw_rect(Rect2(x_start, V.call(row_v.call(1)) - 18, pw * n, V.call(row_v.call(4)) - V.call(row_v.call(1)) + 36), Color(.2, .3, .45, .25))
		ci.draw_rect(Rect2(x_start, V.call(row_v.call(5)) - 18, pw * n, V.call(row_v.call(6)) - V.call(row_v.call(5)) + 36), Color(.45, .3, .15, .25))
		for i in n:
			var x0: float = x_start + i * pw
			ci.draw_rect(Rect2(x0, 0, 2, h), Color(0, 0, 0, .6))
			Tex.silk(ci, str(i + 1), x0 + pw / 2, 18, 20, Color(.9, .88, .82, .85), "center", 700)
			for k in rows.size():
				Tex.silk(ci, rows[k], x0 + pw / 2, V.call(row_v.call(k)) + 26, 10, Color(.9, .88, .82, .55), "center", 600)
			# bande de scribble avec le nom de la piste
			var names := ["KICK", "SNARE", "HH", "TOMS", "OH L", "OH R", "BASS", "GTR 1", "GTR 2", "KEYS", "PIANO", "ORGAN", "VOX", "VOX 2", "CHOEURS", "CUIVRES", "PERC", "FX", "VERB", "DELAY"]
			ci.draw_rect(Rect2(x0 + pw * .08, h * .70, pw * .84, h * .045), Mk.c(0xe8e0c8))
			Tex.silk(ci, names[i % names.size()], x0 + pw / 2, h * .722, 18, Color(.1, .1, .3, .85), "center", 600, "caveat")
			# rainure de fader + graduations
			ci.draw_rect(Rect2(x0 + pw / 2 - 3, h * .78, 6, h * .19), Color(0, 0, 0, .85))
			for k in 9:
				ci.draw_rect(Rect2(x0 + pw / 2 + 9, h * (.785 + k * .022), 7 if k % 2 else 12, 2), Color(.9, .88, .82, .6))
		# section master
		var mx: float = x_start + pw * n
		ci.draw_rect(Rect2(mx, 0, P.call(master_w), h), Mk.c(0x2a2826))
		Tex.silk(ci, "MASTER", mx + P.call(master_w) / 2, 18, 20, Color(.95, .8, .5, .9), "center")
		for k in 2:
			ci.draw_rect(Rect2(mx + P.call(master_w) * (.3 + k * .4) - 3, h * .74, 6, h * .23), Color(0, 0, 0, .85))
		Tex.silk(ci, "L", mx + P.call(master_w) * .3, h * .72, 16, Color(.9, .88, .82, .7), "center")
		Tex.silk(ci, "R", mx + P.call(master_w) * .7, h * .72, 16, Color(.9, .88, .82, .7), "center")
		Tex.grime(ci, w, h, 13, 2))
	Mk.mi(Mk.rounded_box(Vector3(L - .02, .004, plen), .001, [body, body, Mk.mat(Color.WHITE, .5, .4, {"map": tex}), body, body, body], 1), null, Vector3.ZERO, deck)
	var knob_mesh := Mk.cyl(.0062, .0072, .011, 14)
	var cap_mesh := Mk.cyl(.0045, .0045, .003, 14)
	var big_knob := Mk.cyl(.011, .012, .014, 20)
	var row_caps := [0xd43a26, 0x2a6ab0, 0x3a8a4a, 0x3a8a4a, 0x2a6ab0, 0xe8742a, 0xe8742a, 0xd8d2c4]
	var cap_mats := []
	for cc in row_caps:
		cap_mats.append(Mk.mat(Mk.c(cc), .4, 0.0, {"clearcoat": .5}))
	var line := Mk.mat(Mk.c(0xf2efe8), .6)
	var fader_cap := Mk.mat(Mk.c(0xd8d2c4), .4)
	var mute_on := Mk.mat(Mk.c(0x400808), .3, 0.0, {"emission": Mk.c(0xff3020), "energy": 2.0})
	var mute_off := Mk.mat(Mk.c(0x5a1a14), .4)
	var solo := Mk.mat(Mk.c(0x6a5a14), .4)
	var r := Tex.rng(31)
	for i in n:
		var x := -L / 2 + .01 + sw * (i + .5)
		for k in rows.size():
			var v: float = row_v.call(k)
			var holder := Node3D.new()
			holder.position = Vector3(x, 0, v)
			holder.rotation.y = r.randf_range(-2.4, 2.4)
			deck.add_child(holder)
			Mk.mi(knob_mesh, _black, Vector3(0, .0075, 0), holder)
			Mk.mi(cap_mesh, cap_mats[k], Vector3(0, .0142, 0), holder)
			Mk.mi(Mk.box(Vector3(.001, .0005, .004)), line, Vector3(0, .0158, -.002), holder)
		# mute / solo
		var mv: float = row_v.call(rows.size()) - .004
		Mk.mi(Mk.rounded_box(Vector3(.014, .006, .01), .002, mute_on if r.randf() < .25 else mute_off, 1), null, Vector3(x - .009, .004, mv), deck)
		Mk.mi(Mk.rounded_box(Vector3(.014, .006, .01), .002, solo, 1), null, Vector3(x + .009, .004, mv), deck)
		var fv := plen / 2 - .02 - r.randf() * .085
		Mk.mi(Mk.rounded_box(Vector3(.016, .014, .024), .003, fader_cap, 2), null, Vector3(x, .009, fv), deck)
		Mk.mi(Mk.box(Vector3(.016, .0005, .002)), _black, Vector3(x, .0162, fv), deck)
	# master : gros potards + deux faders
	var mx0 := L / 2 - .01 - master_w
	for k in 3:
		Mk.mi(big_knob, _black, Vector3(mx0 + master_w * (.25 + k * .25), .008, -plen / 2 + .07 + k * .06), deck)
	for k in 2:
		Mk.mi(Mk.rounded_box(Vector3(.022, .016, .03), .004, Mk.mat(Mk.c(0xb3241a), .4), 2), null, Vector3(mx0 + master_w * (.3 + k * .4), .01, plen / 2 - .06), deck)
	# pont de VU + baie de patch à l'arrière
	var bridge := Node3D.new()
	bridge.position = Vector3(0, .18, -D / 2 + .03)
	bridge.rotation.x = -.25
	g.add_child(bridge)
	Mk.mi(Mk.rounded_box(Vector3(L, .12, .05), .006, body, 2), null, Vector3.ZERO, bridge)
	var vu := Tex.canvas(256, 160, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xe9d9aa))
		ci.draw_arc(Vector2(128, 190), 150, -2.3, -.84, 32, Mk.c(0x1a1a1a), 2.0, true)
		ci.draw_arc(Vector2(128, 190), 154, -1.12, -.84, 16, Mk.c(0xb3241a), 4.0, true)
		for k in 11:
			var a := -2.3 + k * .146
			ci.draw_line(Vector2(128, 190) + Vector2(cos(a), sin(a)) * 150, Vector2(128, 190) + Vector2(cos(a), sin(a)) * 162, Mk.c(0xb3241a) if k > 7 else Mk.c(0x1a1a1a), 2.0, true)
		Tex.silk(ci, "VU", 128, 120, 26, Mk.c(0x1a1a1a), "center"))
	var vu_mat := Mk.mat(Color.WHITE, .8, 0.0, {"map": vu, "emission": Mk.c(0xffb060), "energy": .35, "emission_tex": vu})
	var vus := []
	for k in 6:
		vus.append(-L * .36 + k * L * .144)
	for vx in vus:
		Mk.mi(Mk.rounded_box(Vector3(.115, .075, .008), .003, _black, 1), null, Vector3(vx, .01, .024), bridge)
		Mk.mi(Mk.quad(.1, .062), vu_mat, Vector3(vx, .01, .0285), bridge)
		var nd := Mk.mi(Mk.box(Vector3(.001, .05, .001)), _black, Vector3(vx - .008, .0, .029), bridge)
		nd.rotation.z = r.randf_range(.1, .6)
	# échelles de LED entre les VU
	for col in 2:
		for i in 10:
			var on := i < 6 + col
			var m := Mk.glow(Mk.c(0x40ff60) if i < 7 else (Mk.c(0xffc020) if i < 9 else Mk.c(0xff3020)), 1.6 if on else .08)
			Mk.mi(Mk.box(Vector3(.008, .004, .003)), m, Vector3(L * .43 - .012 + col * .024, -.03 + i * .007, .026), bridge)
	# baie de patch sur le dessus du pont
	var patch := Node3D.new()
	patch.position = Vector3(0, .062, .0)
	patch.rotation.x = -PI / 2 + .25
	bridge.add_child(patch)
	Mk.mi(Mk.rounded_box(Vector3(L - .04, .04, .006), .002, Mk.mat(Mk.c(0x1a1a1a), .5, .5), 1), null, Vector3.ZERO, patch)
	var jack := Mk.cyl(.0032, .0032, .004, 10)
	var jm := Mk.mat(Mk.c(0x050505), .6)
	for row in 2:
		for i in int((L - .08) / .03):
			var j := Mk.mi(jack, jm, Vector3(-L / 2 + .04 + i * .03, -.009 + row * .018, .003), patch)
			j.rotation.x = PI / 2
	# cordons de patch
	var cord_cols := [0xd43a26, 0xf2c230, 0x2a6ab0, 0x1e1e1e]
	for i in cord_cols.size():
		var a := Vector3(-L / 2 + .04 + (3 + i * 5) * .03, -.009, .006)
		var b := Vector3(-L / 2 + .04 + (7 + i * 4) * .03, .009, .006)
		var mid := (a + b) / 2 + Vector3(0, -.02 - i * .006, .05 + i * .01)
		Mk.mi(Mk.tube([a, a + Vector3(0, 0, .02), mid, b + Vector3(0, 0, .02), b], .0022, 24, 6), Mk.mat(Mk.c(cord_cols[i]), .45, 0.0, {"clearcoat": .3}), Vector3.ZERO, patch)
	# faisceau de câbles qui part derrière la console vers le sol
	for i in 5:
		var x := -.3 + i * .14
		Mk.mi(Mk.tube([Vector3(x, .1, -D / 2), Vector3(x + .02, .06, -D / 2 - .06), Vector3(x * .5, -.2, -D / 2 - .1), Vector3(x * .3, -.8, -D / 2 - .05)], .005, 20, 6), _black, Vector3.ZERO, g)


func _phone(at: Vector3, rot: float) -> void:
	var g := Node3D.new()
	_put(g, at, rot)
	var body := Mk.mat(Mk.c(0x0e0e0e), .3, 0.0, {"clearcoat": .8})
	Mk.mi(Mk.rounded_box(Vector3(.2, .08, .22), .03, body, 4), null, Vector3(0, .04, 0), g)
	var dial := Mk.mi(Mk.disc(.055, 32), Mk.mat(Mk.c(0xd8d2c4), .5), Vector3(0, .081, .04), g)
	dial.rotation.x = -.35
	for i in 10:
		var a := -2.4 + i * .52
		Mk.mi(Mk.cyl(.007, .007, .004, 10), body, Vector3(cos(a) * .04, .083, .04 + sin(a) * .036), g)
	var hs := Node3D.new()
	hs.position = Vector3(0, .1, -.03)
	hs.rotation.y = PI / 2
	g.add_child(hs)
	var bar := Mk.mi(Mk.cyl(.016, .016, .2, 16), body, Vector3.ZERO, hs)
	bar.rotation.z = PI / 2
	for sx in [-1, 1]:
		var ear := Mk.mi(Mk.sphere(.03, 16, 8), body, Vector3(sx * .1, -.01, 0), hs)
		ear.scale = Vector3(1, .8, 1.1)
	Mk.mi(Mk.tube([Vector3(-.1, .03, .1), Vector3(-.16, .01, .2), Vector3(-.1, .005, .3), Vector3(-.2, .005, .35)], .004, 24, 6), body, Vector3.ZERO, g)


func _mug(at: Vector3, rot: float) -> void:
	var g := Node3D.new()
	_put(g, at, rot)
	var m := Mk.mat(Mk.c(0xe6dccb), .3, 0.0, {"clearcoat": .7})
	Mk.mi(Mk.lathe([[0, 0], [.038, 0], [.04, .004], [.042, .095], [.039, .095], [.036, .008], [0, .008]], 40), m, Vector3.ZERO, g)
	Mk.mi(Mk.disc(.037, 32), Mk.mat(Mk.c(0x1a0d05), .1, 0.0, {"clearcoat": 1.0}), Vector3(0, .07, 0), g)
	var h := Mk.mi(Mk.torus_arc(.025, .006, PI, 12, 6), m, Vector3(.042, .05, 0), g)
	h.rotation.z = -PI / 2


func _ashtray(at: Vector3) -> void:
	var g := Node3D.new()
	_put(g, at, .3)
	Mk.mi(Mk.lathe([[0, 0], [.06, 0], [.065, .03], [.055, .03], [.045, .01], [0, .01]], 40), Mk.mat(Mk.c(0x8a4a10), .05, 0.0, {"alpha": .75, "clearcoat": 1.0}), Vector3.ZERO, g)
	var cig := Mk.mi(Mk.cyl(.004, .004, .07, 8), Mk.mat(Mk.c(0xeeeae0), .8), Vector3(.03, .028, 0), g)
	cig.rotation.z = PI / 2 + .25
	Mk.mi(Mk.sphere(.0042, 8, 4), Mk.glow(Mk.c(0xff5010), 3.0), Vector3(.066, .037, 0), g)
	for i in 3:
		var b := Mk.mi(Mk.cyl(.004, .004, .02, 6), Mk.mat(Mk.c(0xd8b070), .8), Vector3(-.02 + i * .012, .014, .015 * i - .01), g)
		b.rotation = Vector3(PI / 2, i * .8, 0)


func _notepad(at: Vector3, rot: float) -> void:
	var g := Node3D.new()
	_put(g, at, rot)
	var lines := Tex.canvas(256, 360, func(ci, w, h):
		ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xf2e48a))
		for y in range(40, 360, 14):
			ci.draw_line(Vector2(0, y), Vector2(w, y), Color(.3, .45, .7, .5), 1.0)
		ci.draw_line(Vector2(36, 0), Vector2(36, h), Color(.8, .2, .2, .6), 1.0)
		var r := Tex.rng(9)
		for row in 9:
			var x := 44.0
			var y := 52.0 + row * 28.0
			while x < w - 30 and r.randf() > .08:
				var wl := 10.0 + r.randf() * 30.0
				ci.draw_line(Vector2(x, y), Vector2(x + wl, y - 2 + r.randf() * 4), Color(.1, .1, .25, .8), 1.6, true)
				x += wl + 8)
	var edge := Mk.mat(Mk.c(0xe8e0c0), .9)
	Mk.mi(Mk.rounded_box(Vector3(.21, .012, .3), .002, [edge, edge, Mk.mat(Color.WHITE, .9, 0.0, {"map": lines}), edge, edge, edge], 1), null, Vector3(0, .006, 0), g)
	var pen := Mk.mi(Mk.cyl(.004, .004, .14, 12), Mk.mat(Mk.c(0x1a2a6a), .3, 0.0, {"clearcoat": 1.0}), Vector3(.13, .016, .02), g)
	pen.basis = Mk.euler_xyz(0, .3, PI / 2)


func _headphones(at: Vector3, rot: float) -> void:
	var g := Node3D.new()
	_put(g, at, rot)
	var band := Mk.mi(Mk.torus_arc(.09, .008, PI, 20, 8), _black, Vector3(0, .02, 0), g)
	band.rotation.x = -PI / 2
	for sx in [-1, 1]:
		var cup := Mk.mi(Mk.cyl(.045, .05, .035, 24), _black, Vector3(sx * .09, .03, 0), g)
		cup.rotation.z = PI / 2 + sx * .3
		var pad := Mk.mi(Mk.torus_ring(.035, .012), Mk.mat(Mk.c(0x2a1a12), .8), Vector3(sx * .07, .03, 0), g)
		pad.rotation.z = PI / 2
	Mk.mi(Mk.tube([Vector3(-.09, .02, .02), Vector3(-.12, .005, .15), Vector3(.05, .005, .25), Vector3(.2, .005, .2), Vector3(.3, .005, .3)], .003, 32, 6), _black, Vector3.ZERO, g)


var _tape_mat: StandardMaterial3D


func _tape_stack(at: Vector3, n: int) -> void:
	if _tape_mat == null:
		var t := Tex.canvas(256, 256, func(ci, w, h):
			ci.draw_rect(Rect2(0, 0, w, h), Mk.c(0xe0d8c4))
			ci.draw_rect(Rect2(0, 0, w, 40), Mk.c(0xb3241a))
			Tex.silk(ci, "MASTER", 128, 20, 26, Mk.c(0xf2ece0), "center")
			var r := Tex.rng(5)
			for row in 6:
				var y := 70.0 + row * 28
				ci.draw_line(Vector2(20, y), Vector2(40 + r.randf() * 180, y + r.randf() * 3), Color(.1, .1, .2, .8), 2.0, true)
			Tex.grime(ci, w, h, 6, 2))
		_tape_mat = Mk.mat(Color.WHITE, .7, 0.0, {"map": t})
	var side := Mk.mat(Mk.c(0xd8d0bc), .8)
	for i in n:
		var b := Mk.mi(Mk.rounded_box(Vector3(.19, .024, .19), .002, [side, side, _tape_mat, side, side, side], 1), null, at + Vector3(0, .012 + i * .025, 0), self)
		b.rotation.y = i * .23 - .2


# ---------------------------------------------------------------- objets au sol
func _floor_objects() -> void:
	# câble XLR enroulé
	for i in 4:
		var r := Mk.mi(Mk.torus_ring(.17 + i * .006, .005), _black, Vector3(2.35 + i * .01, .006 + i * .004, -1.25 + i * .008), self)
		r.rotation = Vector3(0.04 * i, 0, .03)
	# caisse de disques
	var crate := Node3D.new()
	_put(crate, Vector3(2.88, 0, -1.25), .1)
	var wood := Mk.mat(Mk.c(0x8a6038), .7)
	Mk.mi(Mk.box(Vector3(.34, .02, .34)), wood, Vector3(0, .01, 0), crate)
	for sx in [-1, 1]:
		Mk.mi(Mk.box(Vector3(.02, .3, .34)), wood, Vector3(sx * .16, .15, 0), crate)
	Mk.mi(Mk.box(Vector3(.34, .3, .02)), wood, Vector3(0, .15, -.16), crate)
	var cols := [0x2a4a7a, 0xd8a030, 0x1a1a1a, 0xb3241a, 0xe8e0d0, 0x3a6a3a, 0x8a3a6a]
	for i in cols.size():
		var sl := Mk.mi(Mk.box(Vector3(.31, .31, .004)), Mk.mat(Mk.c(cols[i]), .7), Vector3(0, .17, -.13 + i * .035), crate)
		sl.rotation.x = -.25
	# bandes posées par terre contre le meuble
	_tape_stack(Vector3(2.85, 0, -.75), 3)


var plant: Node3D
var arch_lamp: Node3D


func _plant() -> void:
	var g := Node3D.new()
	plant = g
	g.name = "Plant"
	_put(g, Vector3(2.86, 0, -.15))
	Mk.mi(Mk.lathe([[0, 0], [.12, 0], [.16, .3], [.17, .3], [.17, .32], [0, .32]], 32), Mk.mat(Mk.c(0xa8522a), .8), Vector3.ZERO, g)
	Mk.mi(Mk.disc(.16, 24), Mk.mat(Mk.c(0x2a1a10), 1.0), Vector3(0, .3, 0), g)
	var leaf := Mk.mat(Mk.c(0x2e4a1e), .5, 0.0, {"clearcoat": .4, "cull_off": true})
	var stem := Mk.mat(Mk.c(0x3a3a1a), .7)
	var r := Tex.rng(21)
	for i in 22:
		var a := r.randf() * TAU
		var hgt := .5 + r.randf() * .55
		var lean := .1 + r.randf() * .2
		var tip := Vector3(cos(a) * lean, .3 + hgt, sin(a) * lean)
		Mk.mi(Mk.tube([Vector3(0, .3, 0), Vector3(cos(a) * lean * .3, .3 + hgt * .5, sin(a) * lean * .3), tip], .005, 12, 5), stem, Vector3.ZERO, g)
		var l := Mk.mi(Mk.sphere(.14, 14, 7), leaf, tip + Vector3(cos(a) * .08, .02, sin(a) * .08), g)
		l.scale = Vector3(.55, .05, 1.0)
		l.rotation = Vector3(-.3 + r.randf() * .6, -a + PI / 2, r.randf() * .4)


# ---------------------------------------------------------------- cadres sur le mur en liège
func _wall_frames() -> void:
	var items := [[-2.75, 1.48, Mk.c(0xd4a838)], [-3.45, 1.42, Mk.c(0xc8c8cc)]]
	for it in items:
		var g := Node3D.new()
		g.position = Vector3(.03, it[1], it[0])
		g.rotation.y = PI / 2
		add_child(g)
		Mk.mi(Mk.rounded_box(Vector3(.4, .5, .03), .004, Mk.mat(Mk.c(0x0b0908), .35, 0.0, {"clearcoat": .6})), null, Vector3.ZERO, g)
		Mk.mi(Mk.quad(.36, .46), Mk.mat(Mk.c(0x1a1512), .9), Vector3(0, 0, .0155), g)
		var disc := Mk.mi(Mk.cyl(.13, .13, .003, 64), Mk.mat(it[2], .2, 1.0), Vector3(0, .04, .018), g)
		disc.rotation.x = PI / 2
		var lab := Mk.mi(Mk.cyl(.045, .045, .0034, 32), Mk.mat(Mk.c(0xb3241a), .6), Vector3(0, .04, .0182), g)
		lab.rotation.x = PI / 2
		Mk.mi(Mk.quad(.16, .04), Mk.mat(Mk.c(0xc9b27a), .35, .9), Vector3(0, -.17, .017), g)
		Mk.mi(Mk.quad(.36, .46), Mk.mat(Color.WHITE, .03, 0.0, {"alpha": .1, "clearcoat": 1.0}), Vector3(0, 0, .03), g)
