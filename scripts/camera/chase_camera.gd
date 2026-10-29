extends Camera3D
## Chase camera that hangs behind and above the rig and lags a little so
## you feel the rig pitch and roll in the ruts. C toggles a driver's-seat cam.
## Drag with either mouse button to look around, scroll to zoom; let go and
## it drifts back behind the rig.

@export var target_path: NodePath
@export var distance := 6.5
@export var min_distance := 3.5
@export var max_distance := 16.0
@export var elevation := deg_to_rad(20.0)
@export var look_height := 1.0
@export var follow_speed := 5.0
@export var mouse_sensitivity := 0.005
@export var recenter_delay := 2.5   # s after the last drag before drifting back

var target: Node3D
var hood_cam := false
var _pos := Vector3.ZERO
var _yaw := 0.0      # orbit offsets from the default view
var _pitch := 0.0
var _idle := 0.0
var _dragging := false


func _ready() -> void:
	target = get_node(target_path)
	_pos = target.global_position + Vector3(0, 3.0, distance)
	fov = 70.0


## Jump straight to the chase position (no lag). Used by snapshot mode.
func snap_behind() -> void:
	var back := target.global_transform.basis.z
	back.y = 0.0
	_pos = target.global_position + (back.normalized() * cos(elevation) + Vector3.UP * sin(elevation)) * distance
	global_position = _pos
	look_at(target.global_position + Vector3(0, look_height, 0), Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_toggle"):
		hood_cam = not hood_cam
		_yaw = 0.0
		_pitch = 0.0
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = mb.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mb.pressed else Input.MOUSE_MODE_VISIBLE
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(min_distance, distance * 0.9)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(max_distance, distance * 1.1)
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_yaw -= mm.relative.x * mouse_sensitivity
		_pitch -= mm.relative.y * mouse_sensitivity
		_idle = 0.0


func _physics_process(delta: float) -> void:
	_idle += delta
	if _idle > recenter_delay and not _dragging:
		_yaw = lerp_angle(_yaw, 0.0, clampf(delta * 1.5, 0.0, 1.0))
		_pitch = lerpf(_pitch, 0.0, clampf(delta * 1.5, 0.0, 1.0))

	if hood_cam:
		# driver's seat (left-hand drive), free look within a head-turn
		_yaw = clampf(_yaw, -2.2, 2.2)
		_pitch = clampf(_pitch, -0.9, 0.7)
		var eye := target.global_transform.translated_local(Vector3(-0.33, 1.42, 0.25))
		global_transform = eye
		rotate_object_local(Vector3.UP, _yaw)
		rotate_object_local(Vector3.RIGHT, _pitch)
		return

	var elev := clampf(elevation + _pitch, deg_to_rad(-5.0), deg_to_rad(80.0))
	_pitch = elev - elevation
	var back := target.global_transform.basis.z
	back.y = 0.0
	back = back.normalized().rotated(Vector3.UP, _yaw)
	var desired := target.global_position + (back * cos(elev) + Vector3.UP * sin(elev)) * distance
	# don't sink the camera into the hillside
	var t := get_parent().get_node_or_null("Terrain") as Terrain
	if t:
		var ground := t.get_height(desired.x, desired.z)
		desired.y = maxf(desired.y, ground + 1.2)
	# follow lazily when driving, snappily when the player is steering the view
	var k := 1.0 if _dragging else clampf(follow_speed * delta, 0.0, 1.0)
	_pos = _pos.lerp(desired, k)
	global_position = _pos
	look_at(target.global_position + Vector3(0, look_height, 0), Vector3.UP)
