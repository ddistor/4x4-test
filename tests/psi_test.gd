extends Node
## Tire pressure: the same rig at 35 psi and aired down to 15.
##   godot --headless --path . res://tests/psi_test.tscn -- --seed 9 --rig gera
## Bog: 4L locked half throttle, 6 s from a stop, how far and how deep.
## Rock: the steepest dry rock slab (group "rock") it can climb in 4L.
var rig: Rig
var terrain: Terrain
var slab: AnimatableBody3D

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	rig = main.get_node("Rig")
	terrain = main.get_node("Terrain")
	slab = AnimatableBody3D.new()
	slab.add_to_group("rock")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 0.4, 40)
	cs.shape = box
	slab.add_child(cs)
	add_child(slab)
	slab.global_position = Vector3(80, 60, 300)
	_run.call_deferred()

func _wait(s: float) -> void:
	for i in range(int(s * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame

func _set_psi(p: float) -> void:
	rig.psi_target = p
	for w in rig.wheels:
		w.psi = p
		w.debeaded = false

func _bog(p: float) -> String:
	var z := -1.0
	for s in terrain.plan.sections:
		if s["kind"] == "bog" and z < 0.0:
			z = lerpf(s["z0"], s["z1"], 0.4)
	rig.place_on_trail(z)
	_set_psi(p)
	await _wait(1.5)
	rig.low_range = true
	rig.diff_locked = true
	var z0 := rig.global_position.z
	Input.action_press("throttle", 0.5)
	await _wait(6.0)
	Input.action_release("throttle")
	var sink := 0.0
	for w in rig.wheels:
		sink += w.sink * 0.25
	return "bog: %.1f m in 6 s, sink %.2f m" % [rig.global_position.z - z0, sink]

## Can it climb `deg` of dry rock from a standstill?
func _climbs(deg: float, p: float) -> bool:
	var t := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(deg)), Vector3(80, 60, 300))
	slab.global_transform = t
	await get_tree().physics_frame
	var placed := Transform3D(t.basis, t * Vector3(0, 0.95, 12.0))   # low end, nose uphill
	PhysicsServer3D.body_set_state(rig.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, placed)
	rig.global_transform = placed
	rig.linear_velocity = Vector3.ZERO
	rig.angular_velocity = Vector3.ZERO
	rig.driver.snap()
	_set_psi(p)
	rig.low_range = true
	rig.diff_locked = true
	Input.action_press("handbrake")
	await _wait(1.0)
	Input.action_release("handbrake")
	var start := slab.global_transform.inverse() * rig.global_position
	Input.action_press("throttle", 1.0)
	if OS.get_cmdline_user_args().has("--log"):
		for i in range(8):
			await _wait(0.5)
			var loc := slab.global_transform.inverse() * rig.global_position
			print("  %.0f deg t=%.1f local z %.2f y %.2f  v %.1f km/h  %s %4.0f rpm  slip %.2f loads %s contact %s" % [deg, i * 0.5, loc.z, loc.y, rig.speed_kmh, rig.gearbox.gear_name(), rig.gearbox.rpm, rig.wheels[0].slip, rig.wheels.map(func(w: RigWheel) -> int: return int(w.load)), rig.wheels.map(func(w: RigWheel) -> bool: return w.contact)])
	await _wait(4.0)
	Input.action_release("throttle")
	var now := slab.global_transform.inverse() * rig.global_position
	return (start.z - now.z) > 3.0   # moved 3 m up the slab

func _rock(p: float) -> String:
	var best := 0.0
	for deg in [20.0, 25.0, 30.0, 34.0, 38.0, 42.0, 46.0]:
		if await _climbs(deg, p):
			best = deg
		else:
			break
	return "dry rock: climbs %.0f deg" % best

func _run() -> void:
	await _wait(1.0)
	for p in [35.0, 15.0]:
		var b := await _bog(p)
		var r := await _rock(p)
		print("%2.0f psi  %s  |  %s" % [p, b, r])
	get_tree().quit()
