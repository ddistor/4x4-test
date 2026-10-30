extends Node
## Headless smoke test: build a stage (pick it with `-- --seed N`), hold throttle, and print where
## the rig ends up each second. Run with:
##   godot --headless --path . res://tests/drive_test.tscn --quit-after 2000
## Not a unit test; it is a quick "does it drive and does it bog" check. It
## drives like a person: airs down and locks in 4L off the road, winches when
## stuck 4 s, and only takes a marshal recovery after 15 s with no progress.

var rig: Rig
var terrain: Terrain
var t := 0.0
var next_print := 0.0
var best_z := 0.0
var stuck := 0.0
var recoveries := 0
var finished := false
var winches := 0
var winched_here := false
var airing_from := -1.0


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	rig = main.get_node("Rig")
	terrain = main.get_node("Terrain")
	print("spawn at ", rig.global_position)
	print("stage ", terrain.plan.seed_value, "  ", terrain.length, " m\n", terrain.plan.describe())
	Input.action_press("throttle")


func _physics_process(delta: float) -> void:
	t += delta
	# steer toward a point on the trail centre 7 m ahead
	var look_z := rig.global_position.z + 7.0
	var target := Vector3(terrain.trail_x_at(look_z), 0.0, look_z)
	var to := target - rig.global_position
	to.y = 0.0
	var fwd := -rig.global_transform.basis.z
	fwd.y = 0.0
	var cross := fwd.normalized().cross(to.normalized()).y
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	# positive cross = target is to the rig's left
	if cross > 0.05:
		Input.action_press("steer_left")
	elif cross < -0.05:
		Input.action_press("steer_right")
	# off the road, set up like a driver would: stop, air down, 4L, lockers in
	# (with the transfer case broken there's no low range: carry on in 4H)
	if t > 12.0 and not rig.low_range and rig.damage.low_range_ok():
		if airing_from < 0.0:
			airing_from = t
			rig.psi_target = 15.0
		Input.action_release("throttle")
		if rig.wheels[0].psi <= 15.5:
			rig.low_range = true
			rig.diff_locked = true
			print("aired down to 15 psi, 4L, lockers in (took %.0f s)" % (t - airing_from))
		return
	# drive it like a person: road speed in 4H, a crawl in 4L
	var limit := 12.0 if rig.low_range else 45.0
	if rig.speed_kmh > limit:
		Input.action_release("throttle")
	else:
		Input.action_press("throttle")
	var z := rig.global_position.z
	if z > best_z + 1.0:
		best_z = z
		stuck = 0.0
		winched_here = false
	else:
		stuck += delta
	# stuck for 4 s: winch to the best anchor ahead, crawling as it pulls
	if stuck > 4.0 and not rig.winch_active and not winched_here:
		winched_here = true
		rig.winch_aim.begin()
		# a driver picks the anchor furthest up the trail, not the nearest
		# (a tree beside you is a short pull that drags you sideways)
		var best := Vector3.INF
		var best_gain := 3.0
		for a: Vector3 in rig.winch_aim.candidates:
			var ahead := a - rig.fairlead()
			var gain := ahead.z - absf(a.x - terrain.trail_x_at(a.z)) * 0.5
			if gain > best_gain:
				best_gain = gain
				best = a
		rig.winch_aim.selected = best
		if best != Vector3.INF:
			var a := best
			rig.winch_aim.confirm()
			winches += 1
			print("WINCH #%d at z=%.0f (%s) to an anchor %.0f m off" % [winches, z, terrain.plan.section_at(z)["kind"], rig.fairlead().distance_to(a)])
		else:
			rig.winch_aim.cancel()
	# no progress for 15 s even so: what a marshal would do (Backspace), and say where
	if stuck > 15.0:
		recoveries += 1
		print("RECOVER #%d at z=%.0f (%s)" % [recoveries, z, terrain.plan.section_at(z)["kind"]])
		rig.place_on_trail(best_z + 4.0)
		best_z += 4.0
		stuck = 0.0
	if z > terrain.plan.finish_z and not finished:
		finished = true
		print("FINISHED at t=%.0f with %d recoveries, %d winches" % [t, recoveries, winches])
		if rig.damage.enabled:
			print("DAMAGE (repairs %s): %s" % [Career.pesos_text(Damage.repair_cost(rig.damage.to_dict())), Damage.summary(rig.damage.to_dict())])
	if t >= next_print:
		next_print += 1.0
		if rig.damage.enabled and int(t) % 30 == 0:
			print("  damage: %s  coolant %.0f" % [Damage.summary(rig.damage.to_dict()), rig.damage.coolant])
		var p := rig.global_position
		var sinks := []
		var slips := []
		for w in rig.wheels:
			sinks.append("%.2f" % w.sink)
			slips.append("%.1f" % w.slip)
		print("t=%2.0f  pos=(%.1f, %.2f, %.1f)  %.0f km/h  sink=%s slip=%s cake=%.2f mud=%.0f%%  %s  %s" % [
			t, p.x, p.y, p.z, rig.speed_kmh, sinks, slips, rig.cake, rig.mud_amount() * 100.0, "4L" if rig.low_range else "4H",
			terrain.plan.section_at(p.z)["kind"]])
