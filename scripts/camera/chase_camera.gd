extends Camera3D
## Chase camera that hangs behind and above the rig and lags a little so
## you feel the rig pitch and roll in the ruts. C toggles a hood cam.

@export var target_path: NodePath
@export var distance := 7.5
@export var height := 3.0
@export var look_height := 1.0
@export var follow_speed := 5.0

var target: Node3D
var hood_cam := false
var _pos := Vector3.ZERO


func _ready() -> void:
	target = get_node(target_path)
	_pos = target.global_position + Vector3(0, height, distance)
	fov = 70.0


## Jump straight to the chase position (no lag). Used by snapshot mode.
func snap_behind() -> void:
	var fwd := -target.global_transform.basis.z
	fwd.y = 0.0
	_pos = target.global_position - fwd.normalized() * distance + Vector3(0, height, 0)
	global_position = _pos
	look_at(target.global_position + Vector3(0, look_height, 0), Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_toggle"):
		hood_cam = not hood_cam


func _physics_process(delta: float) -> void:
	if hood_cam:
		global_transform = target.global_transform.translated_local(Vector3(0, 1.35, -0.3))
		return
	var fwd := -target.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var desired := target.global_position - fwd * distance + Vector3(0, height, 0)
	# don't sink the camera into the hillside
	var t := get_parent().get_node_or_null("Terrain") as Terrain
	if t:
		var ground := t.get_height(desired.x, desired.z)
		desired.y = maxf(desired.y, ground + 1.2)
	_pos = _pos.lerp(desired, clampf(follow_speed * delta, 0.0, 1.0))
	global_position = _pos
	look_at(target.global_position + Vector3(0, look_height, 0), Vector3.UP)
