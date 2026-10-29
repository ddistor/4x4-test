extends CanvasLayer
## Debug/driver HUD for the mud playground.

@export var rig_path: NodePath

var rig: Rig
var _label: Label
var _help: Label


func _ready() -> void:
	rig = get_node(rig_path) as Rig
	_label = Label.new()
	_label.position = Vector2(18, 14)
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color(0.96, 0.93, 0.86))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_label)
	_help = Label.new()
	_help.text = "W/S drive   A/D steer   Space handbrake   L diff lock   G low range   F winch   C camera   Backspace reset"
	_help.add_theme_font_size_override("font_size", 15)
	_help.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8, 0.85))
	_help.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_help.position = Vector2(18, -34)
	add_child(_help)


func _process(_delta: float) -> void:
	_label.text = rig.status_text()
