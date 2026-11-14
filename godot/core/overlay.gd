class_name Overlay
extends CanvasLayer
## Couche 2D au-dessus du studio : grain + vignettage, écran de démarrage, indication qui s'efface.

var boot: Label
var hint: Label
var _hint_on := true


func _init() -> void:
	layer = 10
	var fx := ColorRect.new()
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = load("res://core/shaders/grain_vignette.gdshader")
	fx.material = sm
	fx.visible = Studio7080.LOOK_FX
	add_child(fx)

	hint = _label("Clique une machine  ·  Échap pour revenir", 11, Color(.95, .95, .95, .45))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	var k := maxf(1.0, DisplayServer.screen_get_scale())
	hint.offset_top = -44 * k
	hint.offset_bottom = -20 * k
	add_child(hint)

	var bg := ColorRect.new()
	bg.color = Color(.0118, .0118, .0118)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boot = _label("MISE SOUS TENSION", 11, Color(.427, .4, .365))
	boot.set_anchors_preset(Control.PRESET_FULL_RECT)
	boot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bg.add_child(boot)
	bg.name = "Boot"
	add_child(bg)


func _label(txt: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ls := LabelSettings.new()
	ls.font = Tex.font("archivo", 600)
	ls.font_size = int(size * maxf(1.0, DisplayServer.screen_get_scale()))
	ls.font_color = col
	l.label_settings = ls
	# espacement façon letter-spacing .3em
	var fv := FontVariation.new()
	fv.base_font = ls.font
	fv.spacing_glyph = int(size * 0.3)
	ls.font = fv
	return l


func boot_done() -> void:
	var tw := create_tween()
	tw.tween_property(get_node("Boot"), "modulate:a", 0.0, 1.0)
	tw.tween_callback(get_node("Boot").hide)
	get_tree().create_timer(7.0).timeout.connect(hide_hint)


func hide_hint() -> void:
	if _hint_on:
		_hint_on = false
		create_tween().tween_property(hint, "modulate:a", 0.0, 1.2)
