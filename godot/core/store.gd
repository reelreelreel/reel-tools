class_name Store
## Réglages et données en local (user://), sur l'ordi de l'utilisateur.

const PATH := "user://reel_tools.cfg"
static var _cfg: ConfigFile


static func _load() -> void:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(PATH)


static func get_v(key: String, default):
	_load()
	return _cfg.get_value("app", key, default)


static func set_v(key: String, value) -> void:
	_load()
	_cfg.set_value("app", key, value)
	_cfg.save(PATH)
