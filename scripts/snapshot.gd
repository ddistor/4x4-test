extends Node
## Snapshot mode: lets Claude (or anyone without a hand on the keyboard) see the
## game. Drops the rig mid-way through every section of the stage and at each
## river crossing, lets it settle, saves a PNG from the chase camera at each,
## plus a driving shot and a close-up of the driver, then quits.
##
##   Godot.exe --path . -- --snap [--seed N]
##   Godot.exe --path . -- --snap --snap-driver   (only the driver close-ups)
##   Godot.exe --path . -- --snap --snap-rig [--rig ID]   (the rig from outside)
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
	if "--snap-rig" in OS.get_cmdline_user_args():
		await _rig_shots()
		get_tree().quit()
		return
	if "--snap-driver" in OS.get_cmdline_user_args():
		await _driver_shot()
		get_tree().quit()
		return
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
	await _driver_shot()
	get_tree().quit()


## The driver head-on through the windshield: his tee and the club print on it.
func _driver_shot() -> void:
	_rig.place_on_trail(_trail_start())
	for i in range(SETTLE_FRAMES):
		await get_tree().physics_frame
	var cam := Camera3D.new()
	cam.fov = 40.0
	get_parent().add_child(cam)
	var r := _rig.global_transform
	(get_parent().get_node("HUD") as CanvasLayer).visible = false
	# head-on over the hood, three-quarters from his side, and side on
	var views := [["98_driver", Vector3(-0.33, 1.72, -1.6), Vector3(-0.33, 1.15, 0.2)],
		["98_driver_34", Vector3(-1.0, 1.72, -1.2), Vector3(-0.33, 1.15, 0.12)],
		["98_driver_side", Vector3(-1.5, 1.45, -0.1), Vector3(-0.33, 1.1, 0.15)],
		["98_driver_close", Vector3(-0.12, 1.5, -0.36), Vector3(-0.33, 1.18, 0.25)],
		["98_driver_hand", Vector3(-0.8, 1.5, -0.45), Vector3(-0.5, 1.29, -0.14)],
		["98_driver_hand_top", Vector3(-0.42, 1.62, 0.02), Vector3(-0.5, 1.29, -0.14)]]
	for v: Array in views:
		cam.fov = 70.0 if v[0] == "98_driver_close" else (35.0 if v[0].begins_with("98_driver_hand") else 40.0)
		cam.global_position = r * (v[1] as Vector3)
		cam.look_at(r * (v[2] as Vector3), r.basis.y)
		cam.make_current()
		for i in range(3):
			await RenderingServer.frame_post_draw
		var path := "res://snaps/%s.png" % v[0]
		get_viewport().get_texture().get_image().save_png(path)
		print("saved ", ProjectSettings.globalize_path(path))


## The rig from outside: front three-quarters, side on, rear three-quarters.
func _rig_shots() -> void:
	_rig.place_on_trail(_trail_start())
	for i in range(SETTLE_FRAMES):
		await get_tree().physics_frame
	(get_parent().get_node("HUD") as CanvasLayer).visible = false
	var cam := Camera3D.new()
	cam.fov = 40.0
	get_parent().add_child(cam)
	var r := _rig.global_transform
	var views := [["97_rig_front", Vector3(-3.6, 1.9, -5.0)], ["97_rig_side", Vector3(-6.5, 1.5, 0.0)],
		["97_rig_rear", Vector3(3.8, 2.1, 5.2)]]
	for v: Array in views:
		cam.global_position = r * (v[1] as Vector3)
		cam.look_at(r * Vector3(0, 0.95, 0), r.basis.y)
		cam.make_current()
		for i in range(3):
			await RenderingServer.frame_post_draw
		var path := "res://snaps/%s_%s.png" % [v[0], _rig.spec.id]
		get_viewport().get_texture().get_image().save_png(path)
		print("saved ", ProjectSettings.globalize_path(path))


func _trail_start() -> float:
	var terrain: Terrain = get_parent().get_node("Terrain")
	return lerpf(terrain.plan.sections[0]["z0"], terrain.plan.sections[0]["z1"], 0.5)
