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

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.box(Color(0.05, 0.04, 0.03, 0.72), 10))
	panel.position = Vector2(60, 60)
	panel.custom_minimum_size = Vector2(430, 0)
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	col.add_child(UiKit.label("GARAGE", 46))
	_name = UiKit.label("", 30)
	col.add_child(_name)
	_blurb = UiKit.label("", 18, UiKit.DIM)
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb.custom_minimum_size = Vector2(400, 0)
	col.add_child(_blurb)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	col.add_child(gap)
	var rigs := []
	for k in RigSpec.kinds():
		rigs.append([k.name, Color(0, 0, 0, 0)])
	var prints := []
	for l: Array in Game.LOGOS:
		prints.append([l[0], Color(0, 0, 0, 0)])
	col.add_child(_choice("Rig", rigs, "rig_kind"))
	col.add_child(_choice("Paint", Game.PAINTS, "paint"))
	col.add_child(_choice("Shirt", Game.SHIRTS, "shirt"))
	col.add_child(_choice("Jorts", Game.SHORTS, "shorts"))
	col.add_child(_choice("Print", prints, "logo"))
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 8)
	col.add_child(gap2)
	var drive := UiKit.button("Drive stage %d" % Game.stage_seed, 400)
	drive.pressed.connect(_drive)
	col.add_child(drive)
	var back := UiKit.button("Back", 400)
	back.pressed.connect(Game.to_menu)
	col.add_child(back)
	drive.grab_focus()
	_show_names()

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
	_view.add_child(_rig)
	# hubs ride ~0.05 m above the body origin in the preview pose
	_rig.position = Vector3(0, _rig.spec.tire_radius - 0.05, 0)
	_rig.driver.snap()


func _show_names() -> void:
	var s := RigSpec.get_kind(Game.rig_kind)
	_name.text = s.name
	_blurb.text = s.blurb


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
		var over_ui: bool = mb.position.x < 520.0   # the choices panel
		_dragging = mb.pressed and not over_ui
	var mm := event as InputEventMouseMotion
	if mm and _dragging:
		_yaw -= mm.relative.x * 0.008


func _drive() -> void:
	_loading.visible = true
	# let the card draw before the main thread goes off to build the world
	await get_tree().process_frame
	await get_tree().process_frame
	Game.start_stage(Game.stage_seed)


func _snap() -> void:
	for i in range(30):
		await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://snaps"))
	get_viewport().get_texture().get_image().save_png("res://snaps/95_garage.png")
	print("saved ", ProjectSettings.globalize_path("res://snaps/95_garage.png"))
	get_tree().quit()
