extends Node
## Off the edge: on a stage and in the trail park, drop the rig past the
## side of the strip and check it lands on the solid far hills (doesn't fall
## out of the world), the off-course count runs, and after the wait the
## marshals put it back on the trail without counting a recovery. Also that
## the strip's edge rises into a bank.
##   godot --headless --path . res://tests/edge_test.tscn
var bad := 0


func _ready() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool, got: Variant = "") -> void:
	print("%s  %s  %s" % ["ok  " if ok else "FAIL", what, str(got)])
	if not ok:
		bad += 1


func _wait(s: float) -> void:
	for i in range(int(s * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame


func _run() -> void:
	for park in [false, true]:
		Game.playground = park
		Game.park_track = 0
		var main: Node = load("res://scenes/main.tscn").instantiate()
		add_child(main)
		var rig: Rig = main.get_node("Rig")
		var t: Terrain = main.get_node("Terrain")
		await _wait(1.0)
		var where := "the park" if park else "a stage"
		var z := 100.0
		var floor_h := t.trail_floor_at(z) if not park else t.get_height(Yard.ahead_on_loop(30.0, z, 0.0).x, z)
		var bank := t.get_height(1.0, z) - floor_h
		if park:
			_check("%s: the edge stands well over the trail" % where, bank > 3.0, "%.1f m" % bank)
		var q := PhysicsRayQueryParameters3D.create(Vector3(-25.0, 300.0, z), Vector3(-25.0, -300.0, z))
		var hit: Dictionary = main.get_world_3d().direct_space_state.intersect_ray(q)
		# over the edge, out on the far hills
		_check("%s: solid ground past the edge" % where, not hit.is_empty())
		rig.place_at(-25.0, z, Vector3.BACK)
		if not hit.is_empty():
			rig.global_position = (hit["position"] as Vector3) + Vector3(0, 1.4, 0)
			PhysicsServer3D.body_set_state(rig.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, rig.global_transform)
		var lowest := INF
		var counted := false
		for k in 20:
			await _wait(0.25)
			lowest = minf(lowest, rig.global_position.y)
			counted = counted or rig.off_course > 0.0
			if k % 4 == 0:
				print("    t=%.1f pos %s off %.2f" % [k * 0.25, rig.global_position, rig.off_course])
		# (it may roll down the hills toward a low edge, but never below the ground there)
		var floor_y := minf(t.get_height(0.0, z), (hit["position"] as Vector3).y if not hit.is_empty() else 0.0) - 3.0
		_check("%s: lands on the far hills, not into the void" % where, lowest > floor_y, "lowest %.1f m (ground no lower than %.1f)" % [lowest, floor_y + 3.0])
		_check("%s: the off-course count runs" % where, counted)
		var before := rig.recoveries
		await _wait(Rig.OFF_COURSE_WAIT + 1.0)
		var p := rig.global_position
		var on := p.x > 0.0 and p.x < Terrain.WIDTH and p.z > 0.0 and p.z < t.length
		_check("%s: back on the course after the wait" % where, on and rig.off_course == 0.0, p)
		_check("%s: and it wasn't a recovery" % where, rig.recoveries == before, rig.recoveries)
		main.queue_free()
		await get_tree().process_frame
	print("RESULT ", "PASS" if bad == 0 else "FAIL")
	get_tree().quit()
