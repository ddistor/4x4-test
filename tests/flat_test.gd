extends Node
## On level soft ground in each section: half throttle in 4H, then full in 4L,
## from a standstill. Prints speed after 6 s, sink and slip. A real rig on
## level clay should roll on at part throttle, not dig itself in.
##   godot --headless --path . res://tests/flat_test.tscn -- --seed 9 --rig gera
var rig: Rig
var terrain: Terrain

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	rig = main.get_node("Rig")
	terrain = main.get_node("Terrain")
	_run.call_deferred()

func _wait(s: float) -> void:
	for i in range(int(s * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame

## A level, soft, dry-of-water spot in this section, or -1.
func _flat(s: Dictionary) -> float:
	var z: float = float(s["z0"]) + 20.0
	while z < float(s["z1"]) - 20.0:
		var level := absf(terrain.plan.profile(z + 4.0) - terrain.plan.profile(z - 4.0)) < 0.25
		var g := terrain.ground_sample(Vector3(terrain.trail_x_at(z) + 0.8, 0, z))
		if level and float(g["thickness"]) > 0.08 and float(g["water_depth"]) < 0.02:
			return z
		z += 3.0
	return -1.0

func _try(z: float, low: bool, pedal: float) -> String:
	rig.place_on_trail(z)
	await _wait(1.5)
	rig.low_range = low
	rig.diff_locked = low
	var z0 := rig.global_position.z
	Input.action_press("throttle", pedal)
	await _wait(6.0)
	Input.action_release("throttle")
	var sink := 0.0
	var slip := 0.0
	for w in rig.wheels:
		sink += w.sink * 0.25
		slip += w.slip * 0.25
	return "%5.1f km/h %5.1f m  sink %.2f slip %.2f" % [rig.speed_kmh, rig.global_position.z - z0, sink, slip]

func _run() -> void:
	await _wait(1.0)
	for s in terrain.plan.sections:
		var z := _flat(s)
		if z < 0.0:
			continue
		var g := terrain.ground_sample(Vector3(terrain.trail_x_at(z) + 0.8, 0, z))
		var a := await _try(z, false, 0.5)
		var b := await _try(z, true, 1.0)
		print("%-8s mud %.2f m wet %.2f |  4H half: %s  |  4L full: %s" % [s["kind"], g["thickness"], g["wetness"], a, b])
	get_tree().quit()
