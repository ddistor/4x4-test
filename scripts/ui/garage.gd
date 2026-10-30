extends Control
## The garage, between the start menu and the stage: your rig and your driver
## on a clay pad in the late light, turning slowly (drag to spin it), with the
## choices beside it. Every change rebuilds the rig so what you see is what
## you'll drive. `--snap-garage` saves a picture and quits.

var _view: SubViewport
var _pivot: Node3D
var _cam: Camera3D
var _rig: Rig
var _name: Label
var _blurb: Label
var _loading: Control
var _yaw := 2.3
var _spin := 0.12      # rad/s while nobody is dragging
var _dragging := false
var _flex := false
var _panel: PanelContainer
## Career: the part being tried on the pad (not bought or fitted yet)
var _try_slot := ""
var _try_id := ""
var _pesos: Label
var _desc: Label
var _part_rows := {}   # slot -> [cycle button, action button]
var _event_btn: Button
var _drive_btn: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var holder := SubViewportContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_view = SubViewport.new()
	_view.own_world_3d = true
	_view.msaa_3d = Viewport.MSAA_4X
	holder.add_child(_view)
	_build_stage()
	_rebuild()

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiKit.box(Color(0.05, 0.04, 0.03, 0.72), 10))
	_panel.position = Vector2(60, 24)
	_panel.custom_minimum_size = Vector2(500, 0)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8 if Game.in_career else 10)
	_panel.add_child(col)
	if Game.in_career:
		_career_panel(col)
	else:
		_free_panel(col)

	var hint := UiKit.label("Drag to turn the rig", 16, UiKit.DIM)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.position = Vector2(-260, -50)
	add_child(hint)

	_loading = ColorRect.new()
	(_loading as ColorRect).color = Color(0.03, 0.025, 0.02, 0.85)
	_loading.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading.visible = false
	var msg := UiKit.label("Building the stage…", 36)
	msg.set_anchors_preset(Control.PRESET_CENTER)
	msg.position = Vector2(-170, -30)
	_loading.add_child(msg)
	add_child(_loading)

	if "--snap-garage" in OS.get_cmdline_user_args():
		_snap.call_deferred()


## Free play: any rig, its look, and drive.
func _free_panel(col: VBoxContainer) -> void:
	_header(col, "GARAGE")
	col.add_child(_choice("Rig", _rig_names(), "rig_kind"))
	_look_rows(col)
	col.add_child(_flex_button())
	_gap(col)
	_drive_btn = UiKit.button("Drive stage %d" % Game.stage_seed, 460)
	_drive_btn.pressed.connect(_drive)
	col.add_child(_drive_btn)
	var back := UiKit.button("Back", 460)
	back.pressed.connect(Game.to_menu)
	col.add_child(back)
	_drive_btn.grab_focus()
	_show_names()


## Career: pick a rig to start with, or work on the one you have: parts on
## one page, the look on the other, then the event to enter.
func _career_panel(col: VBoxContainer) -> void:
	var c := Game.career
	_header(col, "CAREER")
	if not c.started:
		var hint := UiKit.label("Pick the rig you'll build up. You start with %s for parts; club events pay for the rest." % Career.pesos_text(Career.START_PESOS), 18, UiKit.DIM)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size = Vector2(460, 0)
		col.add_child(hint)
		col.add_child(_choice("Rig", _rig_names(), "rig_kind"))
		_look_rows(col)
		_gap(col)
		_drive_btn = UiKit.button("", 460)
		_drive_btn.pressed.connect(func() -> void:
			c.start(Game.rig_kind)
			Game.use_career_rig()
			Game.to_garage(Game.stage_seed))
		col.add_child(_drive_btn)
		var back := UiKit.button("Back", 460)
		back.pressed.connect(Game.to_menu)
		col.add_child(back)
		_drive_btn.grab_focus()
		_show_names()
		return
	_pesos = UiKit.label("", 28, UiKit.CLAY.lightened(0.35))
	col.add_child(_pesos)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	var parts_tab := UiKit.button("Parts", 225)
	var look_tab := UiKit.button("Look", 225)
	tabs.add_child(parts_tab)
	tabs.add_child(look_tab)
	col.add_child(tabs)
	var parts_box := VBoxContainer.new()
	parts_box.add_theme_constant_override("separation", 8)
	col.add_child(parts_box)
	var look_box := VBoxContainer.new()
	look_box.add_theme_constant_override("separation", 8)
	look_box.visible = false
	col.add_child(look_box)
	parts_tab.pressed.connect(func() -> void:
		parts_box.visible = true
		look_box.visible = false)
	look_tab.pressed.connect(func() -> void:
		parts_box.visible = false
		look_box.visible = true)
	for slot: String in Parts.SLOTS:
		if Parts.options(c.stock_spec(), slot).size() < 2:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var pick := UiKit.button("", 300)
		var act := UiKit.button("", 150)
		act.alignment = HORIZONTAL_ALIGNMENT_CENTER
		pick.pressed.connect(_cycle_part.bind(slot))
		act.pressed.connect(_part_action.bind(slot))
		row.add_child(pick)
		row.add_child(act)
		parts_box.add_child(row)
		_part_rows[slot] = [pick, act]
	_desc = UiKit.label("", 17, UiKit.DIM)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(460, 48)
	parts_box.add_child(_desc)
	parts_box.add_child(_flex_button())
	_look_rows(look_box)
	_event_btn = UiKit.button("", 460)
	_event_btn.pressed.connect(func() -> void:
		c.event = (c.event + 1) % Career.EVENTS.size()
		c.save_file()
		_show_career())
	col.add_child(_event_btn)
	_drive_btn = UiKit.button("", 460)
	_drive_btn.pressed.connect(_drive)
	col.add_child(_drive_btn)
	var back := UiKit.button("Back to the start menu", 460)
	back.pressed.connect(Game.to_menu)
	col.add_child(back)
	_drive_btn.grab_focus()
	_show_names()
	_show_career()


## The name and blurb of the rig on the pad, under a heading.
func _header(col: VBoxContainer, title: String) -> void:
	col.add_child(UiKit.label(title, 46))
	_name = UiKit.label("", 30)
	col.add_child(_name)
	_blurb = UiKit.label("", 18, UiKit.DIM)
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb.custom_minimum_size = Vector2(460, 0)
	col.add_child(_blurb)
	if not (Game.in_career and Game.career.started):
		_gap(col)


func _rig_names() -> Array:
	var rigs := []
	for k in RigSpec.kinds():
		rigs.append([k.name, Color(0, 0, 0, 0)])
	return rigs


func _look_rows(col: VBoxContainer) -> void:
	var prints := []
	for l: Array in Game.LOGOS:
		prints.append([l[0], Color(0, 0, 0, 0)])
	col.add_child(_choice("Paint", Game.PAINTS, "paint"))
	col.add_child(_choice("Shirt", Game.SHIRTS, "shirt"))
	col.add_child(_choice("Jorts", Game.SHORTS, "shorts"))
	col.add_child(_choice("Print", prints, "logo"))


func _flex_button() -> Button:
	var flex := UiKit.button("Suspension: at ride height", 460)
	flex.pressed.connect(func() -> void:
		_flex = not _flex
		flex.text = "Suspension: flexed (bump and droop)" if _flex else "Suspension: at ride height"
		_rig.flex = _flex)
	if "--flex" in OS.get_cmdline_user_args():
		flex.pressed.emit.call_deferred()
	return flex


func _gap(col: VBoxContainer) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	col.add_child(gap)


## Show the next option for `slot` on the pad, before you pay for it.
func _cycle_part(slot: String) -> void:
	var c := Game.career
	var opts := Parts.options(c.stock_spec(), slot)
	var cur := _try_id if _try_slot == slot else c.fitted_id(slot)
	_try_slot = slot
	_try_id = opts[(opts.find(cur) + 1) % opts.size()]
	_show_career()
	_rebuild()


## Fit the part being tried (buying it first if it isn't yours yet).
func _part_action(slot: String) -> void:
	var c := Game.career
	var id := _try_id if _try_slot == slot else c.fitted_id(slot)
	if Parts.blocked(c.stock_spec(), c.fitted, slot, id) != "" or id == c.fitted_id(slot):
		return
	if c.owns(slot, id):
		c.fit(slot, id)
	elif not c.buy(slot, id):
		return
	_try_slot = ""
	_show_career()
	_rebuild()


## Refresh the career panel: pesos, each part row, the event and the drive button.
func _show_career() -> void:
	var c := Game.career
	var stock := c.stock_spec()
	_pesos.text = Career.pesos_text(c.pesos)
	_desc.text = "Click a part to try the next one on the rig, then fit it."
	for slot: String in _part_rows:
		var pick: Button = _part_rows[slot][0]
		var act: Button = _part_rows[slot][1]
		var trying := _try_slot == slot
		var id := _try_id if trying else c.fitted_id(slot)
		pick.text = "%s: %s" % [Parts.SLOT_NAMES[slot], Parts.label(slot, id)]
		var why := Parts.blocked(stock, c.fitted, slot, id)
		var cost := Parts.price(slot, id)
		act.disabled = true
		if id == c.fitted_id(slot):
			act.text = "Fitted"
		elif why != "":
			act.text = "Won't fit"
		elif c.owns(slot, id):
			act.text = "Fit"
			act.disabled = false
		else:
			act.text = Career.pesos_text(cost)
			act.disabled = cost > c.pesos
		if trying:
			_desc.text = Parts.describe(stock, slot, id)
			if why != "":
				_desc.text = "Won't fit: %s. %s" % [why, _desc.text]
			elif not c.owns(slot, id) and cost > c.pesos:
				_desc.text = "Not enough pesos yet. " + _desc.text
	var e: Array = Career.EVENTS[c.event]
	var open := c.unlocked(c.event)
	_event_btn.text = "Event: %s, %s  %s" % [e[0], StagePlan.DIFFICULTY[e[1]][0],
		("pays " + Career.pesos_text(e[2])) if open else "(" + c.lock_reason(c.event) + ")"]
	_drive_btn.text = ("Drive the " + (e[0] as String).to_lower()) if open else "Locked"
	_drive_btn.disabled = not open


## What goes on the pad: the fitted parts, plus the one being tried if it fits.
func _preview_parts() -> Variant:
	if not (Game.in_career and Game.career.started):
		return null
	var c := Game.career
	var fit := c.fitted.duplicate()
	if _try_slot != "" and Parts.blocked(c.stock_spec(), c.fitted, _try_slot, _try_id) == "":
		fit[_try_slot] = _try_id
	return fit


## Light, sky and a clay pad for the rig to stand on.
func _build_stage() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.5, 0.68)
	sky_mat.sky_horizon_color = Color(0.66, 0.66, 0.64)
	sky_mat.ground_horizon_color = Color(0.5, 0.4, 0.3)
	sky_mat.ground_bottom_color = Color(0.2, 0.15, 0.1)
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.6, 0.58, 0.55)
	env.fog_density = 0.004
	var we := WorldEnvironment.new()
	we.environment = env
	_view.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.92, 0.8)
	sun.light_energy = 2.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	_pivot = Node3D.new()
	_view.add_child(_pivot)
	# the sun turns with the camera: always over the viewer's shoulder
	sun.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(30.0), 0)
	_pivot.add_child(sun)
	var pad := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 7.0
	disc.bottom_radius = 7.0
	disc.height = 0.1
	disc.radial_segments = 64
	pad.mesh = disc
	pad.position = Vector3(0, -0.05, 0)
	var clay := StandardMaterial3D.new()
	clay.albedo_color = Color(0.3, 0.16, 0.1)
	clay.roughness = 0.95
	pad.material_override = clay
	_view.add_child(pad)
	_cam = Camera3D.new()
	_cam.fov = 38.0
	_pivot.add_child(_cam)
	_cam.position = Vector3(0, 2.1, 7.6)
	# aim left of the rig so it stands in the open right of the screen
	_cam.look_at(Vector3(-1.5, 0.95, 0), Vector3.UP)
	_cam.current = true


## Throw away the shown rig and build the one Game says, standing on the pad.
func _rebuild() -> void:
	if _rig:
		_rig.queue_free()
	_rig = Rig.new()
	_rig.name = "PreviewRig"
	_rig.parts = _preview_parts()
	_view.add_child(_rig)
	# hubs ride ~0.05 m above the body origin in the preview pose (lower on a lift)
	_rig.position = Vector3(0, _rig.spec.tire_radius - 0.05 + _rig.spec.lift, 0)
	_rig.driver.snap()
	_rig.flex = _flex


func _show_names() -> void:
	var s := RigSpec.get_kind(Game.rig_kind)
	_name.text = s.name
	_blurb.text = s.blurb
	if Game.in_career and not Game.career.started:
		_drive_btn.text = "Start the career in the " + s.name


func _choice(what: String, choices: Array, key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var b := UiKit.button("", 360)
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(30, 46)
	var show := func() -> void:
		var c: Array = choices[Game.get(key)]
		b.text = "%s: %s" % [what, c[0]]
		swatch.color = c[1]
	show.call()
	b.pressed.connect(func() -> void:
		Game.set(key, (int(Game.get(key)) + 1) % choices.size())
		Game.save_look()
		show.call()
		_show_names()
		_rebuild())
	row.add_child(b)
	row.add_child(swatch)
	return row


func _process(delta: float) -> void:
	if not _dragging:
		_yaw += _spin * delta
	_pivot.rotation.y = _yaw


func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		var over_ui: bool = _panel.get_global_rect().has_point(mb.position)
		_dragging = mb.pressed and not over_ui
	var mm := event as InputEventMouseMotion
	if mm and _dragging:
		_yaw -= mm.relative.x * 0.008


func _drive() -> void:
	if Game.in_career:
		Game.use_career_rig()
	_loading.visible = true
	# let the card draw before the main thread goes off to build the world
	await get_tree().process_frame
	await get_tree().process_frame
	Game.start_stage(Game.stage_seed)


func _snap() -> void:
	_spin = 0.0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://snaps"))
	# the usual view, then (with --flex) round the rig to check the tires clear
	var yaws := [[_yaw, "95_career" if Game.in_career else "95_garage"]]
	if _flex:
		var id := RigSpec.get_kind(Game.rig_kind).id
		yaws = [[2.3, "95_flex_front_" + id], [1.57, "95_flex_side_" + id], [-2.3, "95_flex_rear_" + id]]
	for y: Array in yaws:
		_yaw = y[0]
		for i in range(30):
			await RenderingServer.frame_post_draw
		var path := "res://snaps/%s.png" % y[1]
		get_viewport().get_texture().get_image().save_png(path)
		print("saved ", ProjectSettings.globalize_path(path))
	get_tree().quit()
