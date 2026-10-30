extends Control
## The graphics settings screen, over the start menu or the pause menu: one
## row per setting, click (or Enter) for the next option, right-click for the
## previous. Changes apply and save at once (GraphicsSettings). Esc or Back
## closes it and emits `closed`.

signal closed

var _buttons := {}   # setting key -> Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.01, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.position = Vector2(110, 36)
	add_child(box)
	box.add_child(UiKit.label("GRAPHICS", 48))
	box.add_child(UiKit.label("Click for the next option, right-click for the previous. Saved as you go.", 17, UiKit.DIM))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	box.add_child(gap)
	for r: Array in Game.gfx.rows():
		var key: String = r[0]
		var b := UiKit.button("", 520)
		_compact(b)
		b.pressed.connect(func() -> void: _step(key, 1))
		b.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
				_step(key, -1))
		box.add_child(b)
		_buttons[key] = b
		if key == "preset":
			var g2 := Control.new()
			g2.custom_minimum_size = Vector2(0, 6)
			box.add_child(g2)
	var g3 := Control.new()
	g3.custom_minimum_size = Vector2(0, 10)
	box.add_child(g3)
	var back := UiKit.button("Back", 520)
	_compact(back)
	back.pressed.connect(_close)
	box.add_child(back)
	_refresh()
	(_buttons["preset"] as Button).grab_focus()


## Slimmer rows than the menu buttons: thirteen of them have to fit.
func _compact(b: Button) -> void:
	b.custom_minimum_size.y = 38
	b.add_theme_font_size_override("font_size", 19)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var sb := b.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		b.add_theme_stylebox_override(state, sb)


func _step(key: String, step: int) -> void:
	Game.gfx.cycle(key, step)
	_refresh()


## Every row, since a preset changes many and a hand change turns it Custom.
func _refresh() -> void:
	for r: Array in Game.gfx.rows():
		var key: String = r[0]
		var opts: Array = r[2]
		(_buttons[key] as Button).text = "%s:   %s" % [r[1], opts[clampi(int(Game.gfx.get(key)), 0, opts.size() - 1)]]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	closed.emit()
	queue_free()
