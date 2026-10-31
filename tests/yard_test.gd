extends Node
## The practice park: builds it, checks the creek, the mud hole and the spawn,
## then drives each obstacle from its station (4L, lockers in, following the
## loop, 30 s) and prints how far it got, the deepest water and mud it saw,
## the most roll and pitch, and whether it stopped. Then, with `--loop`, the
## whole loop from the trailhead, taking the main line, with the marshal's
## recovery after 15 s stuck, and says where.
## Fails only if the park won't build or the creek and mud aren't what they say.
##   godot --headless --path . res://tests/yard_test.tscn -- --rig gera [--loop]
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


## Steer toward the loop 7 m ahead of the rig.
func _steer() -> void:
	var p := rig.global_position
	var to3 := Yard.ahead_on_loop(p.x, p.z, 7.0)
	var to := Vector3(to3.x - p.x, 0.0, to3.y - p.z)
	var fwd := -rig.global_transform.basis.z
	fwd.y = 0.0
	var cross := fwd.normalized().cross(to.normalized()).y
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	if cross > 0.05:
		Input.action_press("steer_left")
	elif cross < -0.05:
		Input.action_press("steer_right")


func _depth_on_line(st: Dictionary, ahead: float) -> float:
	var at: Vector2 = st["at"]
	var p := Yard.ahead_on_loop(at.x, at.y, ahead)
	var level := terrain.water_at(p.x, p.y)
	return 0.0 if level == Terrain.NO_WATER else level - terrain.get_height(p.x, p.y)


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	await _wait(1.0)
	_check("the park builds", terrain.plan.yard and terrain.length == Yard.LENGTH, "loop %.0f m" % Yard.loop_length())
	var p := rig.global_position
	var sp: Dictionary = Yard.spawn()
	_check("spawns at the trailhead", Vector2(p.x, p.z).distance_to(sp["at"]) < 3.0, p)
	var stations := Yard.stations()
	var names := []
	for s in stations:
		names.append(s["name"])
	print("    track %d: %s, %d obstacles" % [Yard.current(), Yard.info()["name"], stations.size()])
	if names.has("Deep crossing"):
		var deepest := 0.0
		var ford_deepest := 0.0
		for a in range(0, 40):
			deepest = maxf(deepest, _depth_on_line(stations[names.find("Deep crossing")], float(a)))
			ford_deepest = maxf(ford_deepest, _depth_on_line(stations[names.find("Creek ford")], float(a)))
		_check("the deep crossing is about 1.4 m", absf(deepest - 1.4) < 0.25, deepest)
		_check("the ford is knee-deep", ford_deepest > 0.15 and ford_deepest < 0.6, ford_deepest)
	_check("no water on the meadow", terrain.water_at(Yard.meadow().x, Yard.meadow().y) == Terrain.NO_WATER)
	if names.has("Mud hole"):
		var mud_at := Yard.ahead_on_loop(stations[names.find("Mud hole")]["at"].x, stations[names.find("Mud hole")]["at"].y, 23.0)
		var g := terrain.ground_sample(Vector3(mud_at.x, 0.0, mud_at.y))
		_check("the mud hole is soup in the middle", float(g["thickness"]) > 0.45 and float(g["wetness"]) > 0.8, [g["thickness"], g["wetness"]])
	# how steep the loop gets (over 4 m), and where
	var steepest := 0.0
	var where := 0.0
	var s := 0.0
	while s < Yard.loop_length():
		var a := Yard.ahead_on_loop(sp["at"].x, sp["at"].y, s)
		var b := Yard.ahead_on_loop(sp["at"].x, sp["at"].y, s + 4.0)
		var deg := rad_to_deg(atan2(absf(terrain.get_height(b.x, b.y) - terrain.get_height(a.x, a.y)), a.distance_to(b)))
		if deg > steepest:
			steepest = deg
			where = s
		s += 2.0
	print("    steepest on the loop: %.0f deg, %.0f m round (%s)" % [steepest, where, "built in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0)])
	for i in stations.size():
		var st: Dictionary = stations[i]
		rig.go_to_station(i)
		await _wait(1.5)
		rig.low_range = true
		rig.diff_locked = true
		var s0 := Yard.loop_s(rig.global_position.x, rig.global_position.z)
		var water := 0.0
		var sink := 0.0
		var roll := 0.0
		var pitch := 0.0
		var made := 0.0
		Input.action_press("throttle", 0.5)
		for k in range(240):
			await _wait(0.125)
			_steer()
			made = wrapf(Yard.loop_s(rig.global_position.x, rig.global_position.z) - s0, -50.0, Yard.loop_length() - 50.0)
			if made > 50.0:
				break   # through the obstacle: done
			for w in rig.wheels:
				water = maxf(water, w.ground.get("water_depth", 0.0))
				sink = maxf(sink, w.sink)
			var rp := rig.roll_pitch()
			roll = maxf(roll, absf(rp.x))
			pitch = maxf(pitch, absf(rp.y))
		Input.action_release("throttle")
		Input.action_release("steer_left")
		Input.action_release("steer_right")
		print("    %-14s %5.1f m on   water %.2f  sink %.2f  roll %2.0f  pitch %2.0f  %s" % [
			st["name"], made, water, sink, roll, pitch, "through" if made > 50.0 else ("STOPPED" if rig.speed_kmh < 0.5 else "")])
	if "--loop" in OS.get_cmdline_user_args():
		await _loop()
	print("RESULT ", "PASS" if bad == 0 else "FAIL")
	get_tree().quit()


## Round the whole loop on the main line, recovering when stuck.
func _loop() -> void:
	rig.reset_to_spawn()
	await _wait(1.5)
	rig.low_range = true
	rig.diff_locked = true
	var start := Yard.loop_s(rig.global_position.x, rig.global_position.z)
	var best := 0.0
	var stuck := 0.0
	var t := 0.0
	var recoveries := 0
	while t < 600.0:
		await _wait(0.125)
		t += 0.125
		_steer()
		Input.action_press("throttle", 0.7 if rig.speed_kmh < 10.0 else 0.0)
		var made := fposmod(Yard.loop_s(rig.global_position.x, rig.global_position.z) - start, Yard.loop_length())
		if made > best + 1.0 and made < best + 40.0:
			best = made
			stuck = 0.0
		else:
			stuck += 0.125
		if stuck > 15.0:
			recoveries += 1
			var i := Yard.station_at(rig.global_position.x, rig.global_position.z)
			print("    RECOVER #%d at %.0f m (%s)" % [recoveries, best, Yard.stations()[i]["name"] if i >= 0 else "the loop"])
			var on := Yard.ahead_on_loop(rig.global_position.x, rig.global_position.z, 6.0)
			var ahead := Yard.ahead_on_loop(on.x, on.y, 3.0)
			rig.place_at(on.x, on.y, Vector3(ahead.x - on.x, 0.0, ahead.y - on.y))
			stuck = 0.0
		if best > Yard.loop_length() - 15.0:
			break
	Input.action_release("throttle")
	print("    loop: %.0f of %.0f m in %.0f s, %d recoveries" % [best, Yard.loop_length(), t, recoveries])
