extends Node
## Headless smoke test: load the playground, hold throttle, and print where
## the rig ends up each second. Run with:
##   godot --headless --path . res://tests/drive_test.tscn --quit-after 2000
## Not a unit test; it is a quick "does it drive and does it bog" check.

var rig: Rig
var terrain: Terrain
var t := 0.0
var next_print := 0.0


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	rig = main.get_node("Rig")
	terrain = main.get_node("Terrain")
	print("spawn at ", rig.global_position)
	print("creek level ", terrain.creek_water_level())
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
	if t >= next_print:
		next_print += 1.0
		var p := rig.global_position
		var sinks := []
		var slips := []
		for w in rig.wheels:
			sinks.append("%.2f" % w.sink)
			slips.append("%.1f" % w.slip)
		print("t=%2.0f  pos=(%.1f, %.2f, %.1f)  %.0f km/h  sink=%s slip=%s cake=%.2f  %s" % [
			t, p.x, p.y, p.z, rig.speed_kmh, sinks, slips, rig.cake, "4L" if rig.low_range else "4H"])
