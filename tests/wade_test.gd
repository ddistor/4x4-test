extends Node
## Wading: drive at the river from 20 m out, flat out in 4H, then again
## crawling in 4L; prints speed against water depth.
##   godot --headless --path . res://tests/wade_test.tscn -- --seed 7 --rig gera
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

func _pass(label: String, low: bool, pedal: float) -> void:
	var zc := -1.0
	for c in terrain.crossings:
		if c["stones"]:
			zc = c["zc"]
	rig.place_on_trail(zc - 22.0)
	await _wait(1.5)
	rig.low_range = low
	rig.diff_locked = low
	Input.action_press("throttle", pedal)
	var top_dry := 0.0
	for i in range(int(14.0 / 0.5)):
		await _wait(0.5)
		var depth := 0.0
		for w in rig.wheels:
			depth = maxf(depth, w.ground.get("water_depth", 0.0))
		if depth < 0.05:
			top_dry = maxf(top_dry, rig.speed_kmh)
		if i % 2 == 0:
			print("%s t=%4.1f  %5.1f km/h  water %.2f m  %s %4.0f rpm %s" % [label, i * 0.5, rig.speed_kmh, depth,
				rig.gearbox.gear_name(), rig.gearbox.rpm, "CHOKING" if rig.choke > 0.3 else ""])
		if rig.global_position.z > zc + 25.0:
			break
	Input.action_release("throttle")
	print("%s done at z %+.0f from the river's middle" % [label, rig.global_position.z - zc])

func _run() -> void:
	await _wait(1.0)
	await _pass("4H full ", false, 1.0)
	await _pass("4L crawl", true, 0.5)
	get_tree().quit()
