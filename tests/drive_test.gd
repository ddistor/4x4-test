extends Node
## Headless smoke test: build a stage (pick it with `-- --seed N`), hold throttle, and print where
## the rig ends up each second. Run with:
##   godot --headless --path . res://tests/drive_test.tscn --quit-after 2000
## Not a unit test; it is a quick "does it drive and does it bog" check.

var rig: Rig
var terrain: Terrain
var t := 0.0
var next_print := 0.0
var best_z := 0.0
var stuck := 0.0
var recoveries := 0
var finished := false


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
	if t > 12.0 and not rig.low_range:
		rig.low_range = true
		rig.diff_locked = true
	# drive it like a person: road speed in 4H, a crawl in 4L
	var limit := 12.0 if rig.low_range else 45.0
	if rig.speed_kmh > limit:
		Input.action_release("throttle")
	else:
		Input.action_press("throttle")
	# no progress for 10 s: what a marshal would do (Backspace), and say where
	var z := rig.global_position.z
	if z > best_z + 1.0:
		best_z = z
		stuck = 0.0
	else:
		stuck += delta
	if stuck > 10.0:
		recoveries += 1
		print("RECOVER #%d at z=%.0f (%s)" % [recoveries, z, terrain.plan.section_at(z)["kind"]])
		rig.place_on_trail(best_z + 4.0)
		best_z += 4.0
		stuck = 0.0
	if z > terrain.plan.finish_z and not finished:
		finished = true
		print("FINISHED at t=%.0f with %d recoveries" % [t, recoveries])
	if t >= next_print:
		next_print += 1.0
		var p := rig.global_position
		var sinks := []
		var slips := []
		for w in rig.wheels:
			sinks.append("%.2f" % w.sink)
			slips.append("%.1f" % w.slip)
		print("t=%2.0f  pos=(%.1f, %.2f, %.1f)  %.0f km/h  sink=%s slip=%s cake=%.2f  %s  %s" % [
			t, p.x, p.y, p.z, rig.speed_kmh, sinks, slips, rig.cake, "4L" if rig.low_range else "4H",
			terrain.plan.section_at(p.z)["kind"]])
