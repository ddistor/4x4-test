extends Node
## Headless checks of rollover and the winch, on a slab of firm ground held
## up above the stage (in group "rock": dry, firm, full grip):
##   godot --headless --path . res://tests/tip_test.tscn -- --rig gera [--winch]
## Tilt table: the slab rolls 1.5 deg/s about the rig's long axis; prints the
## angle where the rig starts to slide and where it rolls.
## --winch: the rig sits behind a 0.3 m curb with the winch hooked 14 m
## ahead; prints the cable pull and how much the body jumps as it climbs.

const UP := 40.0

var rig: Rig
var table: AnimatableBody3D


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	rig = main.get_node("Rig")
	table = AnimatableBody3D.new()
	table.add_to_group("rock")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(16, 0.4, 30)
	cs.shape = box
	table.add_child(cs)
	# a lip along the downhill edge, under the low-side tires, like a real
	# tilt table: it measures tipping, not sliding (--no-lip to slide)
	if not "--no-lip" in OS.get_cmdline_user_args():
		var lip := CollisionShape3D.new()
		var lb := BoxShape3D.new()
		lb.size = Vector3(0.1, 0.12, 30)
		lip.shape = lb
		lip.position = Vector3(-1.1, 0.26, 0)   # the table tips -X down
		table.add_child(lip)
	add_child(table)
	table.global_position = Vector3(80, UP, 300)
	if "--winch" in OS.get_cmdline_user_args():
		_winch.call_deferred()
	else:
		_tilt.call_deferred()


func _wait(seconds: float) -> void:
	for i in range(int(seconds * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame


func _drop_rig_on_table(z: float) -> void:
	await _wait(1.0)   # let the stage put the rig at its start first
	var t := Transform3D(Basis.IDENTITY, Vector3(80, UP + 0.2 + 0.75, z))
	PhysicsServer3D.body_set_state(rig.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, t)
	rig.global_transform = t
	rig.linear_velocity = Vector3.ZERO
	rig.angular_velocity = Vector3.ZERO
	rig.driver.snap()   # his torso and head are bodies of their own: bring them along
	await _wait(2.0)


func _tilt() -> void:
	await _drop_rig_on_table(300)
	var start := rig.global_position
	var slid_at := -1.0
	var angle := 0.0
	while angle < 70.0:
		angle += 1.5 / Engine.physics_ticks_per_second
		table.global_transform = Transform3D(Basis(Vector3.BACK, deg_to_rad(angle)), table.global_position)
		await get_tree().physics_frame
		var up_tbl := table.global_transform.basis.y
		var lean := rad_to_deg(rig.global_transform.basis.y.angle_to(up_tbl))
		# slide: how far it has moved across the table
		var across := (rig.global_position - start).dot(table.global_transform.basis.x)
		if slid_at < 0.0 and absf(across) > 0.5:
			slid_at = angle
			print("slides at %.1f deg (lean on the table %.1f)" % [angle, lean])
		if lean > 30.0:
			print("ROLLS at %.1f deg (slid at %s)" % [angle, ("%.1f" % slid_at) if slid_at >= 0.0 else "-"])
			get_tree().quit()
			return
		if rig.global_position.y < UP - 8.0:
			print("slid off the table at %.1f deg, never rolled" % angle)
			get_tree().quit()
			return
	print("still on its wheels at 70 deg")
	get_tree().quit()


func _winch() -> void:
	# a 0.3 m curb just ahead of the front tires, the anchor 14 m up the table
	var curb := StaticBody3D.new()
	curb.add_to_group("rock")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 0.3, 0.6)
	cs.shape = box
	curb.add_child(cs)
	add_child(curb)
	curb.global_position = Vector3(80, UP + 0.2 + 0.15, 296.0)
	await _drop_rig_on_table(299.0)
	rig.hook_winch(Vector3(80, UP + 0.9, 284.0))
	var worst_vy := 0.0
	var worst_w := 0.0
	var peak := 0.0
	var prev_vy := 0.0
	var worst_jerk := 0.0
	var slack := 0
	var was_tight := false
	for i in range(int(14.0 * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame
		var vy := rig.linear_velocity.y
		worst_vy = maxf(worst_vy, absf(vy))
		worst_w = maxf(worst_w, rig.angular_velocity.length())
		worst_jerk = maxf(worst_jerk, absf(vy - prev_vy) * Engine.physics_ticks_per_second)
		prev_vy = vy
		peak = maxf(peak, rig.winch_tension)
		if was_tight and rig.winch_tension <= 0.0:
			slack += 1   # the line went slack: it'll snap tight again
		was_tight = rig.winch_tension > 500.0
		if i % 120 == 0:
			print("t=%4.1f z=%6.2f y=%5.2f vy=%5.2f w=%4.2f pull=%5.0f N" % [
				i / float(Engine.physics_ticks_per_second), rig.global_position.z, rig.global_position.y - UP,
				vy, rig.angular_velocity.length(), rig.winch_tension])
		if not rig.winch_active:
			break
	print("worst |vy| %.2f m/s, worst spin %.2f rad/s, worst vertical accel %.1f m/s2, peak pull %.0f N, slack-snaps %d, ended at z=%.2f" % [
		worst_vy, worst_w, worst_jerk, peak, slack, rig.global_position.z])
	get_tree().quit()
