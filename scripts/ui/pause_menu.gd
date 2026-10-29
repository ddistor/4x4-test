extends CanvasLayer
## Esc pauses the stage: resume, restart the same stage, roll a new one, or
## go back to the start menu.

var terrain: Terrain
var rig: Rig
var _root: Control
var _where: Label
var _resume: Button


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.01, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	box.position = Vector2(110, -230)
	_root.add_child(box)
	box.add_child(UiKit.label("PAUSED", 64))
	_where = UiKit.label("", 20, UiKit.DIM)
	box.add_child(_where)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	box.add_child(gap)
	_resume = UiKit.button("Resume")
	_resume.pressed.connect(_toggle)
	box.add_child(_resume)
	var restart := UiKit.button("Restart this stage")
	restart.pressed.connect(func() -> void: Game.start_stage(Game.stage_seed))
	box.add_child(restart)
	var fresh := UiKit.button("New stage")
	fresh.pressed.connect(func() -> void: Game.start_stage(Game.random_seed()))
	box.add_child(fresh)
	var menu := UiKit.button("Back to start menu")
	menu.pressed.connect(Game.to_menu)
	box.add_child(menu)
	var quit := UiKit.button("Quit")
	quit.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	_root.visible = paused
	if paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var s := terrain.plan.section_at(rig.global_position.z)
		_where.text = "Stage %d   ·   section %d of %d: %s" % [
			Game.stage_seed, terrain.plan.sections.find(s) + 1, terrain.plan.sections.size(), StagePlan.display_name(s)]
		_resume.grab_focus()
