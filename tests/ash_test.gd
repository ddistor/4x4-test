extends Node
## Mud takes the colour of the ground it came from. With a window:
##   godot --path . res://tests/ash_test.tscn -- --seed 7
## Spins the rig in the lahar wash, then in laterite clay, saving a picture of
## the rig and the ground it churned after each (snaps/93_ash_*.png), and
## printing how grey its mud is.

var rig: Rig
var terrain: Terrain


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	rig = main.get_node("Rig")
	terrain = main.get_node("Terrain")
	_run.call_deferred()


func _wait(seconds: float) -> void:
	for i in range(int(seconds * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame


func _shot(name_: String) -> void:
	print("%-10s rig mud_ash %.2f  tires %s  mud on rig %.0f%%" % [name_, rig.mud_ash,
		rig.wheels.map(func(w: RigWheel) -> String: return "%.2f" % w.mud_ash), rig.mud_amount() * 100.0])
	if DisplayServer.get_name() == "headless":
		return
	(rig.get_parent().get_node("HUD") as CanvasLayer).visible = false
	var cam := Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	var r := rig.global_transform
	cam.global_position = r * Vector3(-3.6, 1.6, 3.2)
	cam.look_at(r * Vector3(0, 0.5, 0.8), Vector3.UP)
	cam.make_current()
	for i in range(4):
		await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://snaps"))
	get_viewport().get_texture().get_image().save_png("res://snaps/93_ash_%s.png" % name_)
	cam.queue_free()


## Somewhere soft in the first section of `kind`, off the stream.
func _spot(kind: String) -> float:
	for s in terrain.plan.sections:
		if s["kind"] == kind:
			for k in range(40):
				var z := lerpf(s["z0"], s["z1"], 0.2 + 0.015 * k)
				var g := terrain.ground_sample(Vector3(terrain.trail_x_at(z), 0, z))
				if float(g["thickness"]) > 0.15 and float(g["water_depth"]) < 0.05:
					return z
			return lerpf(s["z0"], s["z1"], 0.3)
	return -1.0


func _churn(kind: String) -> void:
	var z := _spot(kind)
	if z < 0.0:
		print("no %s on this seed" % kind)
		return
	rig.place_on_trail(z)
	await _wait(1.5)
	# spin it in place, then crawl on a little and spin again
	rig.low_range = false
	rig.diff_locked = false
	for k in range(3):
		Input.action_press("throttle")
		await _wait(5.0)
		Input.action_release("throttle")
		await _wait(0.8)
	await _shot(kind)


func _run() -> void:
	await _wait(1.0)
	await _churn("lahar")
	await _churn("clay" if _spot("clay") >= 0.0 else "kanal")
	await _churn("lahar")
	get_tree().quit()
