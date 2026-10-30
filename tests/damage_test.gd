extends Node
## Damage, staged: each way a rig breaks (axle shafts set up by hand: a tire
## spinning then grabbing at full torque, locked, ten times), with and without the part that
## saves it. Settling on the road breaks nothing; a high-centre dropped on a
## rock cracks the oil pan (skid plates: barely a mark); a front tire slammed
## sideways into a rock bends the tie rod (heavy-duty: far less); crawling
## hard with a mud-caked nose cooks the engine (clean, it doesn't); water
## over the intake hydrolocks it (with the intake set low for the test, as
## the river here is shallow; the snorkel's 1.5 m doesn't).
##   godot --headless --path . res://tests/damage_test.tscn -- --seed 7 --damage
var bad := 0
var main: Node
var rig: Rig
var terrain: Terrain


func _ready() -> void:
	Game.test_damage = true
	_run.call_deferred()


func _check(what: String, ok: bool, got: Variant = "") -> void:
	print("%s  %s  %s" % ["ok  " if ok else "FAIL", what, str(got)])
	if not ok:
		bad += 1


func _wait(s: float) -> void:
	for i in range(int(s * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame


## A fresh stage with the Gera and `parts` on it.
func _stage(parts: Dictionary) -> void:
	if main:
		main.queue_free()
		await get_tree().process_frame
	Game.rig_kind = 0
	Game.test_parts = parts
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	rig = main.get_node("Rig")
	terrain = main.get_node("Terrain")
	await _wait(0.5)


## A block of rock (group "rock") at `at`, world space.
func _rock(at: Vector3, size: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.add_to_group("rock")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	b.add_child(cs)
	main.add_child(b)
	b.global_position = at
	return b


func _run() -> void:
	# --- the road: nothing breaks ---
	await _stage({})
	rig.place_on_trail(30.0)
	await _wait(4.0)
	_check("settling on the road breaks nothing", Damage.repair_cost(rig.damage.to_dict()) == 0, rig.damage.to_dict())

	# --- high-centred: dropped belly-first onto a rock ---
	for skid: bool in [false, true]:
		await _stage({"skid": "steel"} if skid else {})
		rig.place_on_trail(30.0)
		await _wait(2.0)
		var p := rig.global_position
		var ground := terrain.get_height(p.x, p.z)
		# a rock under the middle standing 35 cm proud of the transfer case (taller than the springs can droop), then the
		# rig lifted and dropped on it: hung up, tires off the ground
		var top := p.y + Armor.UNDER_BOTTOM + 0.35
		var mid := rig.to_global(Vector3(0, 0, (rig.spec.front_z + rig.spec.rear_z) * 0.5))
		_rock(Vector3(mid.x, (top + ground - 0.3) * 0.5, mid.z), Vector3(0.6, top - ground + 0.3, 0.6))
		rig.global_position = p + Vector3(0, 0.6, 0)
		PhysicsServer3D.body_set_state(rig.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, rig.global_transform)
		await _wait(2.0)
		var ub: float = rig.damage.cond["underbody"]
		print("    skid %s: underbody %.2f" % [skid, ub])
		if not skid:
			_check("belly on a rock cracks the pan", ub < 0.9, ub)
		else:
			_check("skid plates take it", ub > 0.95, ub)

	# --- a front tire slammed sideways into a rock ---
	for hd: bool in [false, true]:
		await _stage({"steering": "hd"} if hd else {})
		rig.place_on_trail(30.0)
		await _wait(2.0)
		var side := rig.global_basis.x
		# a rock face 3 cm off the front right tire
		var front := rig.to_global(Vector3(rig.spec.track + rig.spec.tire_width * 0.5 + 0.28, -0.1, rig.spec.front_z))
		_rock(front, Vector3(0.5, 0.8, 0.9))
		# shove it sideways at the rock, front first
		rig.linear_velocity = side * 4.5
		await _wait(1.5)
		var st: float = rig.damage.cond["steering"]
		print("    heavy-duty %s: tie rod %.2f, pulls %+.0f" % [hd, st, rig.damage.pull])
		if not hd:
			_check("tie rod bends", st < 0.95, st)
		else:
			_check("heavy-duty tie rod hardly bends", st > 0.97, st)

	# --- a spinning rear tire that grabs, full torque, lockers in: ten times ---
	for moly: bool in [false, true]:
		await _stage({"shafts": "chromoly"} if moly else {})
		rig.place_on_trail(30.0)
		await _wait(1.5)
		rig.diff_locked = true
		for n in range(10):
			# set up the moment straight, between physics steps
			rig.damage._slip_prev[2] = 0.9
			rig.wheels[2].slip = 0.1
			rig.drive_per_wheel[2] = 8000.0
			rig.damage._shafts()
		print("    chromoly %s: rear shaft %.2f" % [moly, rig.damage.cond["shaft_r"]])
		if not moly:
			_check("stock shaft snaps", not rig.damage.shaft_ok(false))
		else:
			_check("chromoly holds", rig.damage.shaft_ok(false) and rig.damage.cond["shaft_r"] > 0.7)

	# --- crawling hard with mud on the nose ---
	for muddy: bool in [true, false]:
		await _stage({})
		rig.place_on_trail(30.0)
		await _wait(1.5)
		rig.low_range = true
		var peak := 0.0
		Input.action_press("throttle", 1.0)
		for i in range(180):
			# spinning in the paddy plasters the nose by itself: hold it caked,
			# or keep it washed
			rig.corner_mud[0] = 2.0 if muddy else 0.0
			rig.corner_mud[1] = 2.0 if muddy else 0.0
			rig.cake = 1.0 if muddy else 0.0
			# hold it to a crawl: a rig working hard, not running down the road
			rig.linear_velocity = rig.linear_velocity.limit_length(1.5)
			await _wait(1.0)
			peak = maxf(peak, rig.damage.coolant)
		Input.action_release("throttle")
		print("    muddy %s: coolant peaked %.0f C" % [muddy, peak])
		if muddy:
			_check("mud-caked radiator overheats", peak >= Damage.COOLANT_HOT, peak)
		else:
			_check("clean radiator copes", peak < Damage.COOLANT_HOT, peak)

	# --- water over the intake ---
	for snorkel: bool in [false, true]:
		await _stage({"snorkel": "snorkel"} if snorkel else {})
		if not snorkel:
			rig.spec.intake_depth = 0.3   # the river here isn't deep enough for the real 0.9 m
		var zc := -1.0
		for c in terrain.crossings:
			zc = c["zc"]
		rig.place_on_trail(zc - 12.0)
		await _wait(1.5)
		Input.action_press("throttle", 0.6)
		var deepest := 0.0
		for i in range(24):
			await _wait(0.5)
			for w in rig.wheels:
				deepest = maxf(deepest, w.ground.get("water_depth", 0.0))
			if rig.damage.hydrolocked:
				break
		Input.action_release("throttle")
		print("    snorkel %s: deepest %.2f m, hydrolocked %s" % [snorkel, deepest, rig.damage.hydrolocked])
		if not snorkel:
			_check("drowned intake hydrolocks", rig.damage.hydrolocked and not rig.gearbox.running)
			rig.recover()
			_check("the marshals drain it", not rig.damage.hydrolocked and rig.damage.cond["engine"] < 1.0)
		else:
			_check("snorkel keeps it breathing", not rig.damage.hydrolocked)

	print("RESULT ", "PASS" if bad == 0 else "FAIL")
	get_tree().quit()
