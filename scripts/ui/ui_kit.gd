class_name UiKit
extends RefCounted
## Shared look for the menus: dark glassy panels, cream text, laterite-red
## highlights.

const TEXT := Color(0.96, 0.93, 0.86)
const DIM := Color(0.8, 0.76, 0.68)
const CLAY := Color(0.72, 0.3, 0.12)


static func box(col: Color, radius := 6, border := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	if border.a > 0.0:
		sb.border_color = border
		sb.set_border_width_all(2)
	return sb


static func button(text: String, wide := 320) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(wide, 50)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", box(Color(0.06, 0.05, 0.04, 0.62)))
	b.add_theme_stylebox_override("hover", box(Color(CLAY, 0.85)))
	b.add_theme_stylebox_override("pressed", box(CLAY.darkened(0.3)))
	b.add_theme_stylebox_override("focus", box(Color(0, 0, 0, 0), 6, Color(CLAY.lightened(0.3), 0.9)))
	return b


static func label(text: String, size: int, col := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l
