class_name Props
## Objets 3D importés (assets/props/*.glb, fournis par Maxime) : on les pose par le bas-centre de
## leur boîte englobante, à une échelle donnée, avec la possibilité de ne garder que certains nœuds.

static var _scenes := {}


static func _scene(file: String) -> PackedScene:
	if not _scenes.has(file):
		_scenes[file] = load("res://assets/props/" + file)
	return _scenes[file]


## Pose un objet : bas-centre de ses meshes visibles en `at`, tourné de rot_y.
##   o.scale (1), o.turn (rotation y propre au modèle, appliquée avant), o.tilt (rotation x),
##   o.keep (noms : on ne garde que les meshes sous ces nœuds), o.hide (noms à masquer).
static func place(parent: Node3D, file: String, at: Vector3, rot_y := 0.0, o := {}) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = file.get_basename().capitalize().replace(" ", "")
	pivot.position = at
	pivot.rotation.y = rot_y
	parent.add_child(pivot)
	if OS.has_environment("NOPROPS"):
		return pivot
	var inst: Node3D = _scene(file).instantiate()
	var s: float = o.get("scale", 1.0)
	inst.basis = Basis(Vector3.UP, o.get("turn", 0.0)) * Basis(Vector3.RIGHT, o.get("tilt", 0.0)) * Basis.from_scale(Vector3.ONE * s)
	pivot.add_child(inst)
	var keep: Array = o.get("keep", [])
	var hide: Array = o.get("hide", [])
	for nm in hide:
		var n := inst.find_child(nm, true, false)
		if n is Node3D:
			(n as Node3D).visible = false
	var acc := [null]
	_walk(inst, inst.transform, keep, false, acc)
	if acc[0] != null:
		var bb: AABB = acc[0]
		var c := bb.get_center()
		inst.position -= Vector3(c.x, bb.position.y, c.z)
	pivot.set_meta("size", (acc[0] as AABB).size if acc[0] != null else Vector3.ZERO)
	return pivot


static func _walk(n: Node, xf: Transform3D, keep: Array, kept: bool, acc: Array) -> void:
	var k := kept or keep.is_empty() or keep.has(String(n.name))
	if n is Node3D and not (n as Node3D).visible:
		return
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if not k:
			mi.visible = false
		elif mi.mesh:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			var bb: AABB = xf * mi.mesh.get_aabb()
			acc[0] = bb if acc[0] == null else (acc[0] as AABB).merge(bb)
	for c in n.get_children():
		var t := xf
		if c is Node3D:
			t = xf * (c as Node3D).transform
		_walk(c, t, keep, k, acc)
