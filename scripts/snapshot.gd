extends Node
## Snapshot mode: lets Claude (or anyone without a hand on the keyboard) see the
## game. Drops the rig mid-way through every section of the stage and at each
## river crossing, lets it settle, saves a PNG from the chase camera at each,
## then quits.
##
##   Godot.exe --path . -- --snap [--seed N]
##
## Needs a window (not --headless) so there is a GPU to render with. Output
## lands in snaps/ next to project.godot (gitignored).

const MAX_SPOTS := 14
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
	var terrain: Terrain = get_parent().get_node("Terrain")
	print("stage ", terrain.plan.seed_value, "\n", terrain.plan.describe())
	var spots: Array = []
	for i in range(terrain.plan.sections.size()):
		var s := terrain.plan.sections[i]
		spots.append(["%02d_%s" % [i + 1, s["kind"]], lerpf(s["z0"], s["z1"], 0.5)])
	for c in terrain.crossings:
		spots.append(["%02d_crossing" % spots.size(), float(c["zc"]) - float(c["half_w"]) * 0.6])
	for spot in spots.slice(0, MAX_SPOTS):
		_rig.place_on_trail(spot[1])
		for i in range(SETTLE_FRAMES):
			await get_tree().physics_frame
			_cam.snap_behind()
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := "res://snaps/%s.png" % spot[0]
		img.save_png(path)
		print("saved ", ProjectSettings.globalize_path(path), "  rig at ", _rig.global_position.snapped(Vector3.ONE * 0.1))
	# one driving shot: 3 s of throttle on the first clay so spray/caking show
	_rig.place_on_trail(terrain.plan.sections[1]["z0"] + 10.0)
	_rig.low_range = true
	_rig.diff_locked = true
	Input.action_press("throttle")
	for i in range(360):
		await get_tree().physics_frame
		_cam.snap_behind()
	Input.action_release("throttle")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://snaps/99_driving.png")
	print("saved ", ProjectSettings.globalize_path("res://snaps/99_driving.png"))
	get_tree().quit()
