extends Node
## Snapshot mode: lets Claude (or anyone without a hand on the keyboard) see the
## game. Drops the rig at a few spots along the trail, lets it settle, saves a
## PNG from the chase camera at each, then quits.
##
##   Godot.exe --path . -- --snap
##
## Needs a window (not --headless) so there is a GPU to render with. Output
## lands in snaps/ next to project.godot (gitignored).

const SPOTS := [
	["01_paddies_road", 8.0],
	["02_first_clay", 62.0],
	["03_before_creek", 100.0],
	["04_creek", 110.0],
	["05_switchbacks", 150.0],
	["06_upper_climb", 205.0],
]
const SETTLE_FRAMES := 90

var _rig: Rig
var _cam: Camera3D


func _ready() -> void:
	_rig = get_parent().get_node("Rig")
	_cam = get_parent().get_node("ChaseCamera")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://snaps"))
	_run()


func _run() -> void:
	await get_tree().process_frame
	for spot in SPOTS:
		_rig.place_on_trail(spot[1])
		for i in range(SETTLE_FRAMES):
			await get_tree().physics_frame
			_cam.snap_behind()
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := "res://snaps/%s.png" % spot[0]
		img.save_png(path)
		print("saved ", ProjectSettings.globalize_path(path))
	# one driving shot: 3 s of throttle on the first clay so spray/caking show
	_rig.place_on_trail(55.0)
	_rig.low_range = true
	_rig.diff_locked = true
	Input.action_press("throttle")
	for i in range(360):
		await get_tree().physics_frame
		_cam.snap_behind()
	Input.action_release("throttle")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://snaps/07_driving_clay.png")
	print("saved ", ProjectSettings.globalize_path("res://snaps/07_driving_clay.png"))
	get_tree().quit()
