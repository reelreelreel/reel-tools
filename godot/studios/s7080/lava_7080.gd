class_name Lava7080
extends Node3D
## Lampe à lave 70s (forme fusée) : socle conique en alu brossé, bouteille de verre teinté, chapeau.
## La cire chauffe en bas, monte en gouttes qui s'étirent, refroidit en haut et redescend.
## Couleur au choix (clic sur la lampe = couleur suivante, ou nuancier dans les réglages) : la lumière
## qu'elle jette dans la pièce suit. Mémorisée dans Store (`lava_color`).

## nom (UI en français), cire, liquide
const COLORS := [
	["Rouge", Color(1.0, .16, .06), Color(1.0, .78, .25)],
	["Orange", Color(1.0, .42, .05), Color(1.0, .85, .35)],
	["Rose", Color(1.0, .25, .55), Color(.6, .25, .9)],
	["Violet", Color(.62, .2, 1.0), Color(.25, .45, 1.0)],
	["Bleu", Color(.15, .45, 1.0), Color(.6, .85, 1.0)],
	["Vert", Color(.35, 1.0, .2), Color(1.0, .9, .3)],
	["Blanc", Color(1.0, .95, .85), Color(.3, .5, 1.0)],
]
const BLOBS := 7

var index := 0
var _wax: StandardMaterial3D
var _liquid: StandardMaterial3D
var _light: OmniLight3D
var _blobs: Array[MeshInstance3D] = []
var _seeds: Array = []


func _init() -> void:
	name = "LavaLamp"
	var alu := Mk.mat(Mk.c(0xb8b4ac), .3, 1.0)
	var dark := Mk.mat(Mk.c(0x2a2826), .4, .8)
	# socle (cône évasé) + bague
	Mk.mi(Mk.lathe([[0, 0], [.085, 0], [.085, .008], [.05, .15], [.046, .15], [0, .15]], 40), alu, Vector3.ZERO, self)
	Mk.mi(Mk.cyl(.05, .05, .01, 32), dark, Vector3(0, .152, 0), self)
	# bouteille : large au milieu, fine en haut
	_liquid = StandardMaterial3D.new()
	_liquid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_liquid.roughness = .05
	_liquid.metallic_specular = .8
	_liquid.cull_mode = BaseMaterial3D.CULL_DISABLED
	_liquid.emission_enabled = true
	_liquid.emission_energy_multiplier = .5
	Mk.mi(Mk.lathe([[.044, .155], [.058, .22], [.056, .3], [.036, .4], [.03, .43]], 40), _liquid, Vector3.ZERO, self)
	# chapeau
	Mk.mi(Mk.lathe([[.03, .43], [.034, .435], [.022, .5], [0, .5]], 32), alu, Vector3.ZERO, self)
	# cire
	_wax = StandardMaterial3D.new()
	_wax.roughness = .35
	_wax.emission_enabled = true
	_wax.emission_energy_multiplier = 2.6
	var pool := Mk.mi(Mk.sphere(.042, 20, 10), _wax, Vector3(0, .165, 0), self)
	pool.scale = Vector3(1, .45, 1)
	var cap := Mk.mi(Mk.sphere(.026, 16, 8), _wax, Vector3(0, .405, 0), self)
	cap.scale = Vector3(1, .5, 1)
	var r := Tex.rng(1977)
	for i in BLOBS:
		var b := Mk.mi(Mk.sphere(1.0, 16, 10), _wax, Vector3(0, .2, 0), self)
		_blobs.append(b)
		_seeds.append([r.randf() * TAU, .12 + r.randf() * .1, .012 + r.randf() * .014, r.randf_range(-.02, .02), r.randf_range(-.02, .02)])
	_light = OmniLight3D.new()
	_light.omni_range = 1.8
	_light.light_energy = 1.0
	_light.position = Vector3(0, .3, 0)
	add_child(_light)
	# la lampe n'éclaire pas son propre verre (sinon il est brûlé de lumière de l'intérieur)
	for n in find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).layers = 1 << 19
	_light.light_cull_mask = ~(1 << 19)
	set_color(int(Store.get_v("lava_color", 0)))
	Mk.add_pick_later(self, "deco:lava", .02)


func set_color(i: int) -> void:
	index = posmod(i, COLORS.size())
	var wax: Color = COLORS[index][1]
	var liq: Color = COLORS[index][2]
	_wax.albedo_color = wax
	_wax.emission = wax
	_liquid.albedo_color = Color(liq.r, liq.g, liq.b, .5)
	_liquid.emission = liq * .3
	_light.light_color = wax.lerp(liq, .3)
	Store.set_v("lava_color", index)


func next_color() -> void:
	set_color(index + 1)
	Toast.say("Lampe à lave : " + COLORS[index][0])


func animate(t: float) -> void:
	# chaque goutte fait l'aller-retour bas -> haut à sa vitesse, s'étire en montant, se tasse en haut
	for i in _blobs.size():
		var sd: Array = _seeds[i]
		var ph: float = t * float(sd[1]) + float(sd[0])
		var k := .5 - .5 * cos(ph)
		var y := lerpf(.18, .39, k)
		var vel := sin(ph)
		var rad: float = float(sd[2]) * lerpf(1.0, .7, k)   # elle maigrit en refroidissant
		var narrow := lerpf(1.0, .62, smoothstep(.3, .43, y))  # la bouteille se resserre
		var b := _blobs[i]
		b.position = Vector3(float(sd[3]) * narrow, y, float(sd[4]) * narrow)
		b.scale = Vector3(rad, rad * (1.0 + absf(vel) * .7), rad) * narrow
	_light.light_energy = .9 + .1 * sin(t * .7)
