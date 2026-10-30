extends Node
## Headless check of the recovery kit on a real stage:
##   godot --headless --path . res://tests/kit_test.tscn -- --seed 326339
## Drops the rig in the middle of the bog (or the kanal), in 4H with the diff
## open so it bogs down, then tries the shovel, the boards and the jack in
## turn, driving a few seconds after each and printing how far it got.

var rig: Rig


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	rig = main.get_node("Rig")
	_run.call_deferred(main.get_node("Terrain"))


func _wait(seconds: float) -> void:
	for i in range(int(seconds * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame


func _drive(seconds: float, strength := 0.5) -> float:
	var z0 := rig.global_position.z
	Input.action_press("throttle", strength)
	await _wait(seconds)
	Input.action_release("throttle")
	await _wait(1.5)
	return rig.global_position.z - z0


func _say(what: String, moved: float) -> void:
	var sinks := []
	for w in rig.wheels:
		sinks.append("%.2f" % w.sink)
	print("%-22s moved %5.2f m   sink %s   %s" % [what, moved, sinks, rig.kit.status()])


func _run(terrain: Terrain) -> void:
	await _wait(1.0)
	var spot := -1.0
	for kind in ["kanal", "bog", "clay"]:
		for s in terrain.plan.sections:
			if s["kind"] == kind and spot < 0.0:
				spot = lerpf(s["z0"], s["z1"], 0.5)
				print("in the %s at z=%.0f" % [kind, spot])
	rig.contact_monitor = true
	rig.max_contacts_reported = 16
	rig.place_on_trail(spot)
	await _wait(2.0)
	# dig itself in the way people do: 4H, diff open, foot to the floor
	_say("bogging it, 4H full", await _drive(6.0, 1.0))
	# then drive it properly: 4L, lockers in, half throttle
	rig.low_range = true
	rig.diff_locked = true
	_say("4L locked, no kit", await _drive(4.0))
	Input.action_press("throttle", 0.5)
	await _wait(1.0)
	var rp := rig.roll_pitch()
	var wl := []
	for i in range(4):
		wl.append("%s load %.0f slip %.2f %s" % [["FL", "FR", "RL", "RR"][i], rig.wheels[i].load, rig.wheels[i].slip, "contact" if rig.wheels[i].contact else "AIR"])
	print("  pushing: roll %.0f pitch %.0f  %s %4.0f rpm  drive torque %.0f  %s" % [rp.x, rp.y, rig.gearbox.gear_name(), rig.gearbox.rpm, rig.gearbox.torque_out, "  ".join(wl)])
	# what is the body itself resting on?
	print("  colliding with: %s" % [rig.get_colliding_bodies().map(func(b: Node) -> String: return "%s (%s)" % [b.name, b.get_class()])])
	var ds := PhysicsServer3D.body_get_direct_state(rig.get_rid())
	for c in range(ds.get_contact_count()):
		var owner_id := rig.shape_find_owner(ds.get_contact_local_shape(c))
		var cs := rig.shape_owner_get_owner(owner_id) as CollisionShape3D
		print("  body touches at %s with shape %s (%s at %s), impulse %.0f" % [rig.to_local(ds.get_contact_local_position(c)), cs.name, cs.shape.get_class(), cs.position, ds.get_contact_impulse(c).length()])
	Input.action_release("throttle")
	rig.kit._start("dig")
	await _wait(RecoveryKit.DIG_TIME + 0.5)
	_say("after digging", await _drive(4.0))
	rig.kit._start("boards")
	await _wait(0.5)
	for b in rig.kit._boards:
		print("board at %s, wheel FL contact at %s" % [b.global_position, rig.wheels[0].contact_point])
	Input.action_press("throttle", 0.5)
	for k in range(4):
		await _wait(0.5)
		var st := []
		for i in range(4):
			st.append("%s slip %.2f load %.0f" % [["FL", "FR", "RL", "RR"][i], rig.wheels[i].slip, rig.wheels[i].load])
		print("  %.1f km/h %s %4.0f rpm  %s" % [rig.speed_kmh, rig.gearbox.gear_name(), rig.gearbox.rpm, "  ".join(st)])
	Input.action_release("throttle")
	_say("onto the boards", await _drive(2.0))
	var before := rig.global_position
	rig.kit._start("jack")
	await _wait(RecoveryKit.JACK_TIME + 2.0)
	print("jack moved it %.2f m, now %.2f m up (was %.2f)   %s" % [
		Vector2(rig.global_position.x - before.x, rig.global_position.z - before.z).length(),
		rig.global_position.y, before.y, rig.kit.status()])
	_say("after the jack", await _drive(4.0))
	get_tree().quit()
