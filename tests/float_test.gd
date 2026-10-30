extends Node
## Parks the rig in a deep river pool (off the ford) and prints how its weight
## splits between the tires and the water, and how far the body rides up.
##   godot --headless --path . res://tests/float_test.tscn -- --seed 9 --rig ronda
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
func _report(label: String) -> void:
	var loads := 0.0
	var comp := 0.0
	var water := 0.0
	for w in rig.wheels:
		loads += w.load
		comp += w.compression() * 0.25
		water = maxf(water, float(w.ground.get("water_depth", 0.0)))
	print("%-10s water %.2f m  tires carry %3.0f%% of the weight  suspension compression %.2f m  (%s)" % [label, water, 100.0 * loads / (rig.mass * 9.8), comp, "closed cab" if rig.spec.closed() else "open tub"])
func _run() -> void:
	await _wait(1.0)
	var c: Dictionary = {}
	for x in terrain.crossings:
		if x.get("ford", false):
			c = x
	var zc: float = c["zc"]
	rig.place_on_trail(zc - 30.0)
	await _wait(2.0)
	_report("dry")
	# in the pool beside the riffle, where it's deepest
	var px: float = float(c["ford_x"]) + 9.0
	var t := Transform3D(Basis.IDENTITY, Vector3(px, terrain.get_height(px, zc) + 1.0, zc))
	PhysicsServer3D.body_set_state(rig.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, t)
	rig.global_transform = t
	rig.linear_velocity = Vector3.ZERO
	rig.driver.snap()
	await _wait(3.0)
	_report("deep pool")
	get_tree().quit()
