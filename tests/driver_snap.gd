extends Node
## The driver at the controls (needs a window): pictures of him idling, on the
## throttle, braking, shifting, in low range and on the handbrake, from his
## seat, beside him and down at his feet; snaps/96_drv_<rig>_<what>_<view>.png.
## Prints how he fits the rig: hip to ankle, knee bend, knee under the wheel.
##   godot --path . res://tests/driver_snap.tscn -- --rig ronda --rain 0 [--only seat]
var rig: Rig


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	rig = main.get_node("Rig")
	_run.call_deferred()


func _run() -> void:
	for i in 60:
		await get_tree().physics_frame
	rig.freeze = true
	rig.set_physics_process(false)   # the test works the pedals
	(get_child(0).get_node("HUD") as CanvasLayer).visible = false
	var s := rig.spec
	var l := CabinKit.layout(s)
	var d: Driver = rig.driver
	_fit(d, s)
	var only := ""
	var args := OS.get_cmdline_user_args()
	if args.has("--only"):
		only = args[args.find("--only") + 1]
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.02
	add_child(cam)
	cam.cull_mask = cam.cull_mask & ~2
	var fl: float = l["floor"]
	var wall: float = l["wall"]
	var views := {
		"seat": [s.seat + Vector3(0, 0.8, -0.07), s.wheel_at + Vector3(0, -0.15, -0.3)],
		"hands": [Vector3(s.seat.x + 0.28, s.wheel_at.y + 0.28, s.wheel_at.z + 0.3), s.wheel_at],
		"front": [Vector3(s.seat.x + 0.05, s.wheel_at.y + 0.05, s.wheel_at.z - 0.32), s.wheel_at + Vector3(0, 0, 0.05)],
		"side": [Vector3(-s.seat.x * 0.6, s.seat.y + 0.35, s.seat.z - 0.35), Vector3(s.seat.x, fl + 0.3, (s.seat.z + wall) * 0.5)],
		"feet": [Vector3(s.seat.x + 0.42, fl + 0.4, wall + 0.55), Vector3(s.seat.x, fl + 0.12, wall + 0.15)],
		"lever": [Vector3(0.4, s.seat.y + 0.55, s.seat.z - 0.1), Vector3(0.0, fl + 0.45, wall + 0.45)],
		"out": [Vector3(-2.4, 2.1, s.seat.z + 1.4), Vector3(0.0, 1.0, s.seat.z)],
		"dashside": [Vector3(-1.6, s.wheel_at.y + 0.1, s.wheel_at.z - 0.5), Vector3(s.seat.x, float(l["dash"][0]) - 0.05, float(l["dash"][1]))],
	}
	# what, then the views to take of it
	var cases := [
		["idle", ["seat", "hands", "front", "side", "feet", "out", "dashside"]],
		["gas", ["feet", "side"]],
		["brake", ["feet", "side"]],
		["shift", ["seat", "lever", "side"]],
		["low", ["lever"]],
		["handbrake", ["lever", "side"]],
	]
	for c: Array in cases:
		await _pose(String(c[0]))
		for v: String in c[1]:
			if only != "" and v != only:
				continue
			var at: Array = views[v]
			cam.global_position = rig.global_transform * (at[0] as Vector3)
			cam.look_at(rig.global_transform * (at[1] as Vector3), rig.global_basis.y)
			cam.make_current()
			for f in range(6):
				await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://snaps/96_drv_%s_%s_%s.png" % [s.id, c[0], v])
	print("saved ", s.id)
	get_tree().quit()


## Set the controls for a case and let him get there.
func _pose(what: String) -> void:
	rig.pedal_gas = 0.0
	rig.pedal_brake = 0.0
	rig.handbrake_on = false
	rig.speed_kmh = 15.0
	match what:
		"gas":
			rig.pedal_gas = 1.0
		"brake":
			rig.pedal_brake = 1.0
		"shift":
			rig.gearbox.gear = 2
		"low":
			rig.gearbox.gear = 1
			rig.low_range = true
		"handbrake":
			rig.handbrake_on = true
			rig.speed_kmh = 0.0
	# (mid-shift: catch the hand on the lever)
	var t := 0.42 if what == "shift" else 1.2
	var n := int(t * Engine.physics_ticks_per_second)
	for i in n:
		await get_tree().physics_frame


## How he fits the seat: the numbers to hold up against a real cab.
func _fit(d: Driver, s: RigSpec) -> void:
	var cab: CabinKit = rig.get_node("Cabin")
	var hip := s.seat + Vector3(0.09, 0, -0.04)
	var foot := cab.foot_on("gas")
	var ankle := foot.origin
	var knee := Driver._knee(hip, ankle, Driver.THIGH, Driver.SHIN, 1.0)
	var bend := rad_to_deg((hip - knee).angle_to(ankle - knee))
	var reach := hip.distance_to(ankle) / (Driver.THIGH + Driver.SHIN)
	# the wheel's lowest point, over the knee
	var wb := s.wheel_at + Basis(Vector3.RIGHT, Driver.WHEEL_TILT) * Vector3(0, 0, Driver.WHEEL_R)
	print("%s: hip to ankle %.2f m ahead, %.2f down (%.0f%% of the leg), knee bent to %.0f deg, knee %.2f m below the wheel rim, %.2f behind it; wheel %.2f m ahead of the hip" % [
		s.id, hip.z - ankle.z, hip.y - ankle.y, reach * 100.0, bend, wb.y - (knee.y + 0.055), wb.z - knee.z, s.seat.z - s.wheel_at.z])
