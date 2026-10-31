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
	box.position = Vector2(110, -330 if terrain.plan.yard else -230)
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
	if terrain.plan.yard:
		_yard_buttons(box)
	# in a career a restart is a new entry: the fee again
	var fee := 0
	if Game.in_career and Game.career.started:
		fee = Game.career.fee(Game.career.event)
	var cost := (" (entry %s)" % Career.pesos_text(fee)) if fee > 0 else ""
	var restart := UiKit.button("Restart this stage" + cost, 420)
	restart.pressed.connect(func() -> void: _again(Game.stage_seed))
	var fresh := UiKit.button("New stage" + cost, 420)
	fresh.pressed.connect(func() -> void: _again(Game.random_seed()))
	if not terrain.plan.yard:
		box.add_child(restart)
		box.add_child(fresh)
	if fee > Game.career.pesos and Game.in_career:
		restart.disabled = true
		fresh.disabled = true
	var gfx := UiKit.button("Graphics")
	gfx.pressed.connect(func() -> void:
		box.visible = false
		var s: Control = load("res://scripts/ui/settings_menu.gd").new()
		s.closed.connect(func() -> void:
			box.visible = true
			gfx.grab_focus())
		_root.add_child(s))
	box.add_child(gfx)
	var menu := UiKit.button("Back to the garage" if Game.in_career else "Back to start menu")
	if terrain.plan.yard:
		menu.text = "Leave the park"
	menu.pressed.connect(Game.leave_stage)
	box.add_child(menu)
	var quit := UiKit.button("Quit")
	quit.pressed.connect(Game.quit_game)
	box.add_child(quit)


## The practice park: drive to any station, and damage on or off (off,
## nothing breaks; on, you see what would, but in the park it never sticks).
func _yard_buttons(box: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	var stations := Yard.stations()
	for i in stations.size():
		var b := UiKit.button(stations[i]["name"], 260)
		b.custom_minimum_size.y = 40
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(func() -> void:
			_toggle()
			rig.go_to_station(i))
		grid.add_child(b)
	box.add_child(grid)
	var dmg := UiKit.button("", 530)
	var show := func() -> void:
		dmg.text = "Damage: %s" % ("on (shows what would break; it doesn't stick)" if Game.yard_damage else "off")
	show.call()
	dmg.pressed.connect(func() -> void:
		Game.yard_damage = not Game.yard_damage
		rig.damage.enabled = Game.yard_damage
		if Game.yard_damage:
			rig.contact_monitor = true
			rig.max_contacts_reported = 16
		else:
			rig.damage.cond = {}
			for k: String in Damage.PARTS:
				rig.damage.cond[k] = 1.0
		show.call())
	box.add_child(dmg)


## Drive it again: in a career, entering again pays the fee.
func _again(seed_v: int) -> void:
	if Game.in_career and Game.career.started and not Game.career.enter(Game.career.event):
		return
	Game.start_stage(seed_v)


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
		if terrain.plan.yard:
			_where.text = "Bakuran trail park, Morong   ·   free: nothing you do here costs"
		_resume.grab_focus()
