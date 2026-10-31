extends Node
## The practice yard: builds it, drives each station up its lane from its
## start (4L, lockers in, half throttle, 25 s) and prints how far the rig got,
## the deepest water and mud it saw, the most roll and pitch, and whether it
## hung up. Fails only if the yard won't build, the spawn isn't on the road,
## or the pool and mud pit aren't what they say.
##   godot --headless --path . res://tests/yard_test.tscn -- --rig gera
var rig: Rig
var terrain: Terrain
var bad := 0


func _ready() -> void:
	Game.playground = true
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	rig = main.get_node("Rig")
	terrain = main.get_node("Terrain")
	_run.call_deferred()


func _check(what: String, ok: bool, got: Variant = "") -> void:
	print("%s  %s  %s" % ["ok  " if ok else "FAIL", what, str(got)])
	if not ok:
		bad += 1


func _wait(s: float) -> void:
	for i in range(int(s * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame


func _run() -> void:
	await _wait(1.0)
	_check("the yard builds as the yard", terrain.plan.yard and terrain.length == Yard.SIZE)
	var p := rig.global_position
	_check("spawns by the road", Vector2(p.x, p.z).distance_to(Yard.SPAWN) < 3.0, p)
	var deep := Yard.pool_posts()
	var level := terrain.water_at(Yard.POOL["x0"] + 10.0, float(Yard.POOL["z_deep"]))
	var bed := terrain.get_height(Yard.POOL["x0"] + 10.0, float(Yard.POOL["z_deep"]))
	_check("the pool is about 1.6 m deep", absf((level - bed) - 1.55) < 0.25, level - bed)
	_check("no water outside the pool", terrain.water_at(40.0, 64.0) == Terrain.NO_WATER and terrain.water_at(80.0, 100.0) == Terrain.NO_WATER)
	var g := terrain.ground_sample(Vector3(80.0, 0.0, 100.0))
	_check("the mud pit is deep soup in the middle", float(g["thickness"]) > 0.5 and float(g["wetness"]) > 0.8, [g["thickness"], g["wetness"]])
	_check("five depth posts", deep.size() == 5)
	for i in Yard.STATIONS.size():
		var st: Array = Yard.STATIONS[i]
		rig.go_to_station(i)
		await _wait(1.5)
		rig.low_range = true
		rig.diff_locked = true
		var z0 := rig.global_position.z
		var water := 0.0
		var sink := 0.0
		var roll := 0.0
		var pitch := 0.0
		var lane: Rect2 = st[3]
		Input.action_press("throttle", 0.5)
		for k in range(60):
			await _wait(0.5)
			if rig.global_position.z > lane.end.y:
				break   # through the station: done
			for w in rig.wheels:
				water = maxf(water, w.ground.get("water_depth", 0.0))
				sink = maxf(sink, w.sink)
			var rp := rig.roll_pitch()
			roll = maxf(roll, absf(rp.x))
			pitch = maxf(pitch, absf(rp.y))
		Input.action_release("throttle")
		var made := rig.global_position.z - z0
		var through := rig.global_position.z > lane.end.y
		print("    %-14s %5.1f m up the lane   water %.2f  sink %.2f  roll %2.0f  pitch %2.0f  %s" % [
			st[0], made, water, sink, roll, pitch, "through" if through else ("STOPPED" if rig.speed_kmh < 0.5 else "")])
	print("RESULT ", "PASS" if bad == 0 else "FAIL")
	get_tree().quit()
