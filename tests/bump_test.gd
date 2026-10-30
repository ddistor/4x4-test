extends Node
## Small bumps: a rig rolling flat out in first over a low rounded hump of
## rock across the road (10 cm, 20 cm) should jolt, not stop dead. Prints the
## speed through each, the hardest deceleration, and what touched (body
## contacts, rig space) besides the tires' rays. (Real ground bumps: run
## drive_test with SNAG=1, which prints every contact that shoves the rig
## back hard.)
##   godot --headless --path . res://tests/bump_test.tscn -- --seed 7 --rig gera
var rig: Rig
var terrain: Terrain
var main: Node
var bad := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	rig = main.get_node("Rig")
	terrain = main.get_node("Terrain")
	_run.call_deferred()


func _wait(s: float) -> void:
	for i in range(int(s * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame


func _bump(at_z: float, h: float, rock: bool) -> StaticBody3D:
	var b := StaticBody3D.new()
	if rock:
		b.add_to_group("rock")
	var cs := CollisionShape3D.new()
	# a rounded hump: a cylinder lying across the road, mostly buried
	var cyl := CylinderShape3D.new()
	cyl.radius = maxf(h, 0.25)
	cyl.height = 4.0
	cs.shape = cyl
	cs.rotation = Vector3(0, 0, PI * 0.5)
	b.add_child(cs)
	main.add_child(b)
	var x := terrain.trail_x_at(at_z)
	b.global_position = Vector3(x, terrain.get_height(x, at_z) + h - cyl.radius, at_z)
	return b


func _pass(label: String, h: float, rock: bool) -> void:
	rig.place_on_trail(20.0)
	await _wait(1.5)
	rig.contact_monitor = true
	rig.max_contacts_reported = 16
	var bz := rig.global_position.z + 30.0
	var b := _bump(bz, h, rock)
	Input.action_press("throttle", 1.0)
	var v_before := 0.0
	var v_min := 99.0
	var worst := 0.0
	var touched := {}
	var last_v := rig.linear_velocity
	for i in range(int(20.0 * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame
		var dz := rig.global_position.z - bz
		var v := rig.linear_velocity
		var decel := -(v - last_v).dot(-rig.global_basis.z) / get_physics_process_delta_time()
		last_v = v
		if dz < -6.0:
			v_before = rig.speed_kmh
			continue
		if dz > 6.0:
			break
		v_min = minf(v_min, rig.speed_kmh)
		worst = maxf(worst, decel)
		var st := PhysicsServer3D.body_get_direct_state(rig.get_rid())
		for c in st.get_contact_count():
			if st.get_contact_collider_object(c) == b and st.get_contact_impulse(c).length() > 20.0:
				var p := rig.to_local(st.get_contact_local_position(c))
				touched["(%.1f, %.2f, %.1f)" % [p.x, p.y, p.z]] = true
	Input.action_release("throttle")
	b.queue_free()
	var stuck := v_min < v_before * 0.4
	print("%s %-16s %4.1f km/h -> min %4.1f  worst decel %5.1f m/s2  %s  body touched: %s" % [
		"FAIL" if stuck else "ok  ", label, v_before, v_min, worst, rig.gearbox.gear_name(), touched.keys()])
	if stuck:
		bad += 1


func _run() -> void:
	await _wait(1.0)
	print("rig ", rig.spec.id)
	await _pass("10 cm rock", 0.1, true)
	await _pass("20 cm rock", 0.2, true)
	print("RESULT ", "PASS" if bad == 0 else "FAIL")
	get_tree().quit()
