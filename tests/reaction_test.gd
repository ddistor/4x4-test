extends Node
## Does every kind of ground react to a rig driving on it? For each section
## kind (stages built to include them all), drop the rig mid-section, wipe
## it clean, drive 12 s up the trail in 4L at half throttle, and print what
## it left and what it picked up: ruts carved, grass worn, how deep the tires
## sank, water, and mud/dust on the body. Rock should take neither ruts nor
## wear; mud should rut and plaster; dry dirt should wear and dust.
##   godot --headless --path . res://tests/reaction_test.tscn [-- --rig gera --weather rain]
const GROUPS := [["clay", "lahar", "rocky", "gully"], ["bog", "cogon", "niyog", "pasture"], ["ridge", "sukal"]]
var seen := {}


func _ready() -> void:
	_run.call_deferred()


func _wait(s: float) -> void:
	for i in range(int(s * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame


func _run() -> void:
	print("%-8s %7s %6s %6s %6s %7s %7s" % ["kind", "rut cm", "worn", "sink", "water", "mud", "cake"])
	for g: Array in GROUPS:
		Game.test_must = g
		var main: Node = load("res://scenes/main.tscn").instantiate()
		add_child(main)
		var rig: Rig = main.get_node("Rig")
		var t: Terrain = main.get_node("Terrain")
		await _wait(0.5)
		for s in t.plan.sections:
			var k: String = s["kind"]
			if seen.has(k):
				continue
			seen[k] = true
			await _drive(rig, t, lerpf(s["z0"], s["z1"], 0.35), lerpf(s["z0"], s["z1"], 0.65), k)
		main.queue_free()
		await get_tree().process_frame
	get_tree().quit()


func _drive(rig: Rig, t: Terrain, z0: float, z1: float, kind: String) -> void:
	rig.place_on_trail(z0)
	await _wait(1.5)
	for i in 4:
		rig.corner_mud[i] = 0.0
	rig.cake = 0.0
	rig.low_range = true
	rig.diff_locked = true
	var mud := t.mud
	var rut0 := mud.rut.duplicate()
	var wear0 := mud.wear.duplicate()
	var sink := 0.0
	var water := 0.0
	Input.action_press("throttle", 0.5)
	for f in range(int(12.0 * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame
		# steer for the trail 6 m ahead
		var ahead := Vector3(t.trail_x_at(rig.global_position.z + 6.0), 0, rig.global_position.z + 6.0)
		var to := (ahead - rig.global_position) * Vector3(1, 0, 1)
		var cross := (-rig.global_basis.z * Vector3(1, 0, 1)).normalized().cross(to.normalized()).y
		Input.action_release("steer_left")
		Input.action_release("steer_right")
		if cross > 0.05:
			Input.action_press("steer_left")
		elif cross < -0.05:
			Input.action_press("steer_right")
		for w in rig.wheels:
			sink = maxf(sink, w.sink)
			water = maxf(water, w.ground.get("water_depth", 0.0))
		if rig.global_position.z > z1:
			break
	Input.action_release("throttle")
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	var rut := 0.0
	var worn := 0.0
	var n := 0
	for i in mud.rut.size():
		var d: float = mud.rut[i] - rut0[i]
		rut = maxf(rut, d)
		var dw: float = mud.wear[i] - wear0[i]
		if dw > 0.02:
			worn += mud.wear[i]
			n += 1
	print("%-8s %7.1f %6.2f %6.2f %6.2f %7.2f %7.2f" % [kind, rut * 100.0, worn / maxf(n, 1), sink, water,
		(rig.corner_mud[0] + rig.corner_mud[1] + rig.corner_mud[2] + rig.corner_mud[3]) * 0.25, rig.cake])
