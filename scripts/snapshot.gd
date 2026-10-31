extends Node
## Snapshot mode: lets Claude (or anyone without a hand on the keyboard) see the
## game. Drops the rig mid-way through every section of the stage and at each
## river crossing, lets it settle, saves a PNG from the chase camera at each,
## plus a driving shot and a close-up of the driver, then quits.
##
##   Godot.exe --path . -- --snap [--seed N]
##   Godot.exe --path . -- --snap --snap-driver   (only the driver close-ups)
##   Godot.exe --path . -- --snap --snap-rig [--rig ID]   (the rig from outside)
##   Godot.exe --path . -- --snap --snap-only KIND --seed N   (one kind of section)
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
	if terrain.plan.yard:
		await _yard_shots(terrain)
		get_tree().quit()
		return
	print("stage ", terrain.plan.seed_value, "\n", terrain.plan.describe())
	var spots: Array = []
	for i in range(terrain.plan.sections.size()):
		var s := terrain.plan.sections[i]
		spots.append(["%02d_%s" % [i + 1, s["kind"]], lerpf(s["z0"], s["z1"], 0.5)])
	for c in terrain.crossings:
		spots.append(["%02d_crossing" % spots.size(), float(c["zc"]) - float(c["half_w"]) * 0.6])
	# --snap-only KIND: just that kind of section, from the rig and from ahead
	var args := OS.get_cmdline_user_args()
	var only := ""
	if args.find("--snap-only") >= 0 and args.find("--snap-only") + 1 < args.size():
		only = args[args.find("--snap-only") + 1]
	if only != "":
		await _section_shots(terrain, only)
		get_tree().quit()
		return
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
		["98_driver_door", Vector3(-1.45, 1.55, -0.55), Vector3(-0.36, 1.2, 0.2)],
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


## A few spots through each section of `kind`: the usual chase view, a
## low look up the trail from in front of the rig, and one from above.
func _section_shots(terrain: Terrain, kind: String) -> void:
	(get_parent().get_node("HUD") as CanvasLayer).visible = false
	var cam := Camera3D.new()
	cam.fov = 55.0
	get_parent().add_child(cam)
	for i in range(terrain.plan.sections.size()):
		var s := terrain.plan.sections[i]
		if s["kind"] != kind:
			continue
		var spots: Array[float] = [lerpf(s["z0"], s["z1"], 0.35), lerpf(s["z0"], s["z1"], 0.7)]
		for c in terrain.crossings:
			if c["zc"] > s["z0"] and c["zc"] < s["z1"]:
				spots = [float(c["zc"]) - float(c["half_w"]) * 0.5, float(c["zc"])]
		# a lahar wash's slot canyon too
		for pz in terrain._pinches:
			if pz > s["z0"] and pz < s["z1"]:
				spots.append(pz)
		for k in range(spots.size()):
			var z: float = spots[k]
			_rig.place_on_trail(z)
			for f in range(SETTLE_FRAMES):
				await get_tree().physics_frame
				_cam.snap_behind()
			var tag := "%02d_%s_%d" % [i + 1, kind, int(100.0 * (z - float(s["z0"])) / (float(s["z1"]) - float(s["z0"])))]
			_cam.make_current()
			for f in range(3):
				await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://snaps/%s_chase.png" % tag)
			var r := _rig.global_transform
			var views := [["ahead", Vector3(0.6, 1.4, -9.0), Vector3(0, 0.6, 0)], ["above", Vector3(5.0, 7.0, 5.0), Vector3(0, 0, -2.0)]]
			for v: Array in views:
				var at: Vector3 = r * (v[1] as Vector3)
				# never below the ground or under a river's surface
				at.y = maxf(at.y, maxf(terrain.get_height(at.x, at.z) + 1.4, terrain.water_at(at.x, at.z) + 1.0))
				cam.global_position = at
				cam.look_at(r * (v[2] as Vector3), Vector3.UP)
				cam.make_current()
				for f in range(3):
					await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("res://snaps/%s_%s.png" % [tag, v[0]])
			print("saved ", tag)


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
	# and a close look at the front-left corner, where nose, fender and hood meet
	var corner := Vector3(-_rig.spec.track, 0.95, _rig.spec.fairlead.z + 0.35)
	views.append(["97_rig_corner", corner + Vector3(-1.1, 0.5, -1.4), corner])
	if "--snap-gaps" in OS.get_cmdline_user_args():
		# close looks all round, for panels that don't meet
		var tail := _rig.spec.rear_z + 0.7
		var fr := Vector3(_rig.spec.track, 0.95, _rig.spec.fairlead.z + 0.35)
		views = [
			["96_gap_fr", fr + Vector3(1.1, 0.5, -1.4), fr],
			["96_gap_rl", Vector3(-1.6, 1.5, tail + 1.4), Vector3(-0.6, 1.0, tail - 0.3)],
			["96_gap_rr", Vector3(1.6, 1.5, tail + 1.4), Vector3(0.6, 1.0, tail - 0.3)],
			["96_gap_roof", Vector3(-1.8, 2.9, -0.6), Vector3(-0.4, 1.7, 0.4)],
			["96_gap_low", Vector3(-2.4, 0.35, 0.0), Vector3(0, 0.7, 0.0)]]
		# every wheel well from outside: square on, and from low behind the
		# wheel looking up into the arch, where panels leave holes
		var t := _rig.spec.track
		for c: Array in [["fl", -1.0, _rig.spec.front_z], ["fr", 1.0, _rig.spec.front_z], ["rl", -1.0, _rig.spec.rear_z], ["rr", 1.0, _rig.spec.rear_z]]:
			var sx: float = c[1]
			var hub := Vector3(sx * t, 0.35, float(c[2]))
			views.append(["96_well_%s" % c[0], hub + Vector3(sx * 1.6, 0.35, 0.0), hub + Vector3(0, 0.25, 0)])
			views.append(["96_wellup_%s" % c[0], hub + Vector3(sx * 1.1, -0.1, 0.9), hub + Vector3(-sx * 0.2, 0.55, -0.1)])
			# from under the rig at the back of the wheel, where it was hollow
			views.append(["96_wheelin_%s" % c[0], Vector3(-sx * 0.25, 0.0, float(c[2]) + 1.1), hub + Vector3(0, -0.1, 0)])
	for v: Array in views:
		cam.global_position = r * (v[1] as Vector3)
		cam.look_at(r * (v[2] as Vector3 if v.size() > 2 else Vector3(0, 0.95, 0)), r.basis.y)
		cam.make_current()
		for i in range(3):
			await RenderingServer.frame_post_draw
		var path := "res://snaps/%s_%s.png" % [v[0], _rig.spec.id]
		get_viewport().get_texture().get_image().save_png(path)
		print("saved ", ProjectSettings.globalize_path(path))


func _trail_start() -> float:
	var terrain: Terrain = get_parent().get_node("Terrain")
	return lerpf(terrain.plan.sections[0]["z0"], terrain.plan.sections[0]["z1"], 0.5)


## The practice yard (`--playground --snap`): the whole lot from high over
## the spawn, then the rig at each station's start with a view up the lane.
func _yard_shots(terrain: Terrain) -> void:
	(get_parent().get_node("HUD") as CanvasLayer).visible = false
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.far = 900.0
	get_parent().add_child(cam)
	for v: Array in [["90_yard_overview", Vector3(80, 95, -40), Vector3(80, 0, 85)],
			["90_yard_west", Vector3(10, 30, 40), Vector3(45, 0, 80)],
			["90_yard_east", Vector3(150, 30, 40), Vector3(118, 0, 80)],
			["90_yard_north", Vector3(80, 28, 105), Vector3(80, 4, 148)]]:
		cam.global_position = v[1]
		cam.look_at(v[2], Vector3.UP)
		cam.make_current()
		for i in range(8):
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://snaps/%s.png" % v[0])
		print("saved ", v[0])
	for i in Yard.STATIONS.size():
		_rig.go_to_station(i)
		for f in range(SETTLE_FRAMES):
			await get_tree().physics_frame
		var p := _rig.global_position
		var lane: Rect2 = Yard.STATIONS[i][3]
		cam.global_position = Vector3(p.x + 7.0, p.y + 4.5, p.z - 6.0)
		cam.look_at(Vector3(lane.get_center().x, terrain.get_height(lane.get_center().x, lane.get_center().y), lane.get_center().y), Vector3.UP)
		cam.make_current()
		for f in range(4):
			await RenderingServer.frame_post_draw
		var path := "res://snaps/91_yard_%02d.png" % (i + 1)
		get_viewport().get_texture().get_image().save_png(path)
		print("saved ", path)
