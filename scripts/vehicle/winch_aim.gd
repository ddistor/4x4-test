class_name WinchAim
extends Node3D
## Picking what to winch to. F starts aiming: every anchor the cable can
## reach (a tree, palm or big boulder within reach, ahead of or beside the
## bumper) gets a ring where the tree-saver strap would go, and the best one
## is picked to start with. Point the mouse at another, or Tab through them;
## F hooks up, Esc puts the hook away.

const MAX_MARKERS := 40
const MAX_ANGLE := deg_to_rad(80.0)   # a roller fairlead pulls well off to the side, not behind

var rig: Rig
var active := false
var candidates: Array[Vector3] = []
var selected := Vector3.INF

var _markers: Array[MeshInstance3D] = []
var _mat_idle: StandardMaterial3D
var _mat_pick: StandardMaterial3D
var _line_mesh: ImmediateMesh
var _line: MeshInstance3D
var _hint: Label
var _layer: CanvasLayer
var _mouse := Vector2(-1, -1)
var _mouse_moved := false


func setup(r: Rig) -> void:
	rig = r
	top_level = true
	_mat_idle = StandardMaterial3D.new()
	_mat_idle.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_idle.albedo_color = Color(1, 1, 1, 0.55)
	_mat_idle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_idle.no_depth_test = true
	_mat_pick = StandardMaterial3D.new()
	_mat_pick.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_pick.albedo_color = Color(1.0, 0.75, 0.1)
	_mat_pick.no_depth_test = true
	var ring := TorusMesh.new()
	ring.inner_radius = 0.38
	ring.outer_radius = 0.46
	ring.rings = 24
	ring.ring_segments = 6
	for i in range(MAX_MARKERS):
		var m := MeshInstance3D.new()
		m.mesh = ring
		m.material_override = _mat_idle
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false
		add_child(m)
		_markers.append(m)
	_line_mesh = ImmediateMesh.new()
	_line = MeshInstance3D.new()
	_line.mesh = _line_mesh
	_line.material_override = _mat_pick
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_line)
	_layer = CanvasLayer.new()
	add_child(_layer)
	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position = Vector2(-420, -110)
	_hint.size = Vector2(840, 60)
	_hint.add_theme_font_size_override("font_size", 20)
	_hint.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_hint.add_theme_constant_override("shadow_offset_x", 2)
	_hint.add_theme_constant_override("shadow_offset_y", 2)
	_hint.visible = false
	_layer.add_child(_hint)


func begin() -> void:
	active = true
	selected = Vector3.INF
	_refresh()
	if not candidates.is_empty():
		selected = _best()
	_hint.visible = true


func cancel() -> void:
	active = false
	_hint.visible = false
	_line_mesh.clear_surfaces()
	for m in _markers:
		m.visible = false


func confirm() -> void:
	if selected != Vector3.INF:
		rig.hook_winch(selected)
	cancel()


func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion:
		_mouse = (event as InputEventMouseMotion).position
		_mouse_moved = true
	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		var key := (event as InputEventKey).physical_keycode
		if key == KEY_ESCAPE:
			cancel()
			get_viewport().set_input_as_handled()  # don't open the pause menu too
		elif key == KEY_TAB:
			_cycle()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not active:
		return
	_refresh()
	if candidates.is_empty():
		selected = Vector3.INF
	elif _mouse_moved:
		_mouse_moved = false
		var hovered := _under_mouse()
		if hovered != Vector3.INF:
			selected = hovered
	# keep the pick if it's still in reach, else fall back to the best
	if selected != Vector3.INF and not candidates.has(selected):
		selected = _best() if not candidates.is_empty() else Vector3.INF
	_draw()


## Anchors the cable can reach from the bumper right now.
func _refresh() -> void:
	candidates.clear()
	var bumper := rig.fairlead()
	var fwd := -rig.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var reach := rig.winch_reach
	for a in rig.terrain.tree_anchors:
		if absf(a.x - bumper.x) > reach or absf(a.z - bumper.z) > reach:
			continue
		var to := a - bumper
		if to.length() > reach or to.length() < 2.0:
			continue
		var flat := Vector3(to.x, 0.0, to.z).normalized()
		if flat.angle_to(fwd) > MAX_ANGLE:
			continue
		candidates.append(a)
	# nearest first, so the markers go to the likeliest ones
	candidates.sort_custom(func(p: Vector3, q: Vector3) -> bool: return p.distance_squared_to(bumper) < q.distance_squared_to(bumper))
	if candidates.size() > MAX_MARKERS:
		candidates.resize(MAX_MARKERS)


## Straight ahead and close beats far off to the side.
func _best() -> Vector3:
	var bumper := rig.fairlead()
	var fwd := -rig.global_transform.basis.z
	var best := Vector3.INF
	var best_score := INF
	for a in candidates:
		var to := a - bumper
		var score := to.length() * (1.0 + 1.5 * Vector3(to.x, 0, to.z).normalized().angle_to(Vector3(fwd.x, 0, fwd.z).normalized()))
		if score < best_score:
			best_score = score
			best = a
	return best


func _under_mouse() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.INF
	var best := Vector3.INF
	var best_d := 90.0  # px
	for a in candidates:
		if cam.is_position_behind(a):
			continue
		var d := cam.unproject_position(a).distance_to(_mouse)
		if d < best_d:
			best_d = d
			best = a
	return best


## Tab: the next anchor round from left to right.
func _cycle() -> void:
	if candidates.is_empty():
		return
	var bumper := rig.fairlead()
	var fwd := -rig.global_transform.basis.z
	var right := rig.global_transform.basis.x
	var sorted := candidates.duplicate()
	sorted.sort_custom(func(p: Vector3, q: Vector3) -> bool:
		return atan2((p - bumper).dot(right), (p - bumper).dot(fwd)) < atan2((q - bumper).dot(right), (q - bumper).dot(fwd)))
	var i := sorted.find(selected)
	selected = sorted[(i + 1) % sorted.size()]


func _draw() -> void:
	for i in range(MAX_MARKERS):
		var m := _markers[i]
		if i >= candidates.size():
			m.visible = false
			continue
		var a := candidates[i]
		var pick := a == selected
		m.visible = true
		m.global_position = a
		m.scale = Vector3.ONE * (1.25 if pick else 0.9)
		m.material_override = _mat_pick if pick else _mat_idle
	_line_mesh.clear_surfaces()
	if selected == Vector3.INF:
		_hint.text = "WINCH  nothing in reach (%d m): get closer to a tree or boulder\nEsc to put the hook away" % int(rig.winch_reach)
		return
	# dashed preview of where the cable would run
	var from := rig.fairlead()
	var dist := from.distance_to(selected)
	var dashes := int(dist / 0.6)
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for k in range(dashes):
		_line_mesh.surface_add_vertex(from.lerp(selected, float(k) / dashes))
		_line_mesh.surface_add_vertex(from.lerp(selected, (k + 0.5) / dashes))
	_line_mesh.surface_end()
	_hint.text = "WINCH  %.0f m  ·  %d anchors in reach\nMouse or Tab to pick   F hook up   Esc cancel" % [dist, candidates.size()]
