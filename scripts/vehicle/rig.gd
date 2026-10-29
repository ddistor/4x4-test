class_name Rig
extends RigidBody3D
## The FJ-style trail rig. Body-on-frame boxy 4x4: snorkel-less, roof rack,
## light bar, bull bar with a winch. Built from primitives for M1.
##
## Forward is -Z (Godot convention). Wheels are RigWheel children placed at
## the top of their suspension travel.

@export var terrain_path: NodePath

# Drivetrain
@export var max_drive_force_high := 13000.0   # N, total at the wheels, from rest
@export var max_speed_high := 26.0            # m/s where drive force reaches zero
@export var max_drive_force_low := 26000.0
@export var max_speed_low := 11.0
@export var brake_force := 9000.0              # N per wheel
@export var max_steer := deg_to_rad(32.0)
@export var steer_speed := 3.2                 # rad/s
@export var winch_max_force := 32000.0
@export var winch_pull_speed := 0.9            # m/s cable retract
@export var winch_reach := 18.0

var terrain: Terrain
var wheels: Array[RigWheel] = []
var diff_locked := false
var low_range := false
var winch_active := false
var winch_anchor := Vector3.INF
var winch_target_len := 0.0
var throttle := 0.0
var brake := 0.0
var steer := 0.0
var speed_kmh := 0.0
var cake := 0.0          # 0..1 mud on the paint
var dryness := 0.4
var wheel_status: Array[Dictionary] = []

var _body_mats: Array[ShaderMaterial] = []
var _cable: MeshInstance3D
var _cable_mesh: ImmediateMesh
var _spawn: Transform3D


func _ready() -> void:
	terrain = get_node(terrain_path) as Terrain
	mass = 2150.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.25, 0.05)
	can_sleep = false
	continuous_cd = true
	_build_body()
	_build_wheels()
	_build_cable()
	_spawn = global_transform


func _build_body() -> void:
	var shader := load("res://shaders/mud_cake.gdshader")
	var paint := Color(0.80, 0.12, 0.09)  # Voodoo-blue would be cooler; red matches the photo
	var make_mat := func(col: Color) -> ShaderMaterial:
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("paint", col)
		_body_mats.append(m)
		return m

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.75, 0.85, 4.2)
	col.shape = box
	col.position = Vector3(0, 0.47, 0)
	add_child(col)
	var cab_col := CollisionShape3D.new()
	var cab_box := BoxShape3D.new()
	cab_box.size = Vector3(1.65, 0.75, 2.4)
	cab_col.shape = cab_box
	cab_col.position = Vector3(0, 1.25, 0.3)
	add_child(cab_col)

	# lower body (fenders + bed), cab, hood
	_add_box(Vector3(1.78, 0.75, 4.25), Vector3(0, 0.45, 0), make_mat.call(paint))
	_add_box(Vector3(1.70, 0.78, 2.45), Vector3(0, 1.18, 0.35), make_mat.call(paint))
	_add_box(Vector3(1.60, 0.12, 1.1), Vector3(0, 0.86, -1.45), make_mat.call(paint))
	# white roof like the FJ, glass as a dark band
	_add_box(Vector3(1.72, 0.08, 2.5), Vector3(0, 1.61, 0.35), make_mat.call(Color(0.92, 0.92, 0.88)))
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.12, 0.15, 0.17)
	glass.metallic = 0.3
	glass.roughness = 0.2
	_add_box(Vector3(1.66, 0.42, 2.3), Vector3(0, 1.37, 0.35), glass)
	# roof rack + light bar
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.1, 0.1, 0.1)
	black.roughness = 0.8
	_add_box(Vector3(1.5, 0.06, 2.0), Vector3(0, 1.75, 0.4), black)
	for i in range(4):
		var lamp := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.09
		cyl.bottom_radius = 0.09
		cyl.height = 0.12
		var lm := StandardMaterial3D.new()
		lm.albedo_color = Color(0.95, 0.9, 0.7)
		lm.emission_enabled = true
		lm.emission = Color(1.0, 0.9, 0.6)
		lm.emission_energy_multiplier = 0.6
		cyl.material = lm
		lamp.mesh = cyl
		lamp.rotation_degrees = Vector3(90, 0, 0)
		lamp.position = Vector3(-0.6 + i * 0.4, 1.82, -0.62)
		add_child(lamp)
	# bull bar + winch drum
	_add_box(Vector3(1.6, 0.35, 0.12), Vector3(0, 0.45, -2.2), black)
	_add_box(Vector3(0.9, 0.28, 0.2), Vector3(0, 0.25, -2.1), black)
	# spare on the back
	var spare := MeshInstance3D.new()
	var sc := CylinderMesh.new()
	sc.top_radius = 0.4
	sc.bottom_radius = 0.4
	sc.height = 0.28
	sc.material = black
	spare.mesh = sc
	spare.rotation_degrees = Vector3(90, 0, 0)
	spare.position = Vector3(0, 0.95, 2.25)
	add_child(spare)


func _add_box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	add_child(mi)


func _build_wheels() -> void:
	var track := 0.82
	var wb := 2.70
	var layout := [
		[Vector3(-track, 0.35, -wb * 0.5), true, true],
		[Vector3(track, 0.35, -wb * 0.5), true, false],
		[Vector3(-track, 0.35, wb * 0.5), false, true],
		[Vector3(track, 0.35, wb * 0.5), false, false],
	]
	for entry in layout:
		var w := RigWheel.new()
		w.position = entry[0]
		w.steerable = entry[1]
		w.left_side = entry[2]
		add_child(w)
		wheels.append(w)


func _build_cable() -> void:
	_cable_mesh = ImmediateMesh.new()
	_cable = MeshInstance3D.new()
	_cable.mesh = _cable_mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.75, 0.7)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cable.material_override = m
	_cable.top_level = true
	add_child(_cable)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("diff_lock"):
		diff_locked = not diff_locked
	elif event.is_action_pressed("low_range"):
		low_range = not low_range
	elif event.is_action_pressed("winch"):
		_toggle_winch()
	elif event.is_action_pressed("reset_rig"):
		reset_to_spawn()


func reset_to_spawn() -> void:
	# Put it back on the road, upright, pointed up the trail.
	var t := _spawn
	t.origin = Vector3(terrain.trail_x_at(6.0), terrain.get_height(terrain.trail_x_at(6.0), 6.0) + 1.2, 6.0)
	t.basis = Basis.looking_at(Vector3(0, 0, 1), Vector3.UP)
	global_transform = t
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	winch_active = false


func _physics_process(delta: float) -> void:
	if global_position.y < -25.0 or global_transform.basis.y.y < -0.6 and linear_velocity.length() < 0.3:
		# fell off the map or settled on the roof
		reset_to_spawn()
	throttle = Input.get_action_strength("throttle")
	brake = Input.get_action_strength("brake")
	var steer_in := Input.get_action_strength("steer_left") - Input.get_action_strength("steer_right")
	steer = move_toward(steer, steer_in * max_steer, steer_speed * delta)
	var handbrake := Input.is_action_pressed("handbrake")

	var fwd := -global_transform.basis.z
	var v_fwd := linear_velocity.dot(fwd)
	speed_kmh = absf(v_fwd) * 3.6

	# --- engine ------------------------------------------------------------
	var max_f := max_drive_force_low if low_range else max_drive_force_high
	var max_v := max_speed_low if low_range else max_speed_high
	var reverse := brake > 0.0 and v_fwd < 0.6 and throttle <= 0.0
	var demand := throttle
	if reverse:
		demand = -brake * 0.6
	var fade := clampf(1.0 - pow(absf(v_fwd) / max_v, 2.0), 0.0, 1.0)
	var drive_total := demand * max_f * fade
	# hydrolock-lite: a drowned intake chokes the engine
	var front_water := maxf(wheels[0].ground.get("water_depth", 0.0), wheels[1].ground.get("water_depth", 0.0))
	drive_total *= 1.0 - smoothstep(0.75, 1.05, front_water)

	var wheel_brake := 0.0
	if brake > 0.0 and not reverse:
		wheel_brake = brake * brake_force
	if handbrake:
		wheel_brake = maxf(wheel_brake, brake_force * 1.5)

	# --- steering & diffs ---------------------------------------------------
	for w in wheels:
		w.steer_angle = steer if w.steerable else 0.0

	# Open diff: an axle can only put down twice what its weaker tire holds —
	# the light/wet wheel spins, the planted one gets nothing. Locked: each
	# tire takes its full share. This is why the L key matters in the bog.
	var per_axle := drive_total * 0.5  # 4H: centre split front/rear
	wheel_status.clear()
	var caps: Array[float] = []
	for w in wheels:
		var mu_guess := lerpf(0.95, 0.40, w.ground.get("wetness", 0.3))
		caps.append(mu_guess * maxf(w.load, 0.0))
	for axle in range(2):
		var a := axle * 2
		var b := a + 1
		var cap_override_a := -1.0
		var cap_override_b := -1.0
		if not diff_locked:
			var weakest: float = minf(caps[a], caps[b])
			cap_override_a = weakest
			cap_override_b = weakest
		var ra := wheels[a].physics_step(self, terrain, delta, per_axle * 0.5, wheel_brake, cap_override_a)
		var rb := wheels[b].physics_step(self, terrain, delta, per_axle * 0.5, wheel_brake, cap_override_b)
		wheel_status.append(ra)
		wheel_status.append(rb)

	# --- water on the body ---------------------------------------------------
	var body_water := 0.0
	for w in wheels:
		body_water = maxf(body_water, w.ground.get("water_depth", 0.0))
	if body_water > 0.4:
		var submerged := clampf((body_water - 0.4) / 0.9, 0.0, 1.0)
		apply_central_force(Vector3.UP * mass * 9.8 * 0.55 * submerged)
		apply_central_force(-linear_velocity * 1400.0 * submerged)

	# --- winch -----------------------------------------------------------------
	_winch_step(delta)

	# --- mud on the paint ---------------------------------------------------
	var churn := 0.0
	var wet := 0.0
	for s in wheel_status:
		churn += s["in_mud"] * (0.5 * s["slip"] + 0.08 * absf(v_fwd) / 10.0)
		wet = maxf(wet, s["wet"] * s["in_mud"] + s["in_water"])
	cake = clampf(cake + churn * delta * 0.03, 0.0, 1.0)
	dryness = move_toward(dryness, 0.0 if wet > 0.3 else 1.0, delta * (0.5 if wet > 0.3 else 0.02))
	for m in _body_mats:
		m.set_shader_parameter("cake", cake)
		m.set_shader_parameter("dryness", dryness)

	terrain.mud.flush()


func _toggle_winch() -> void:
	if winch_active:
		winch_active = false
		return
	var bumper := _bumper_pos()
	var fwd := -global_transform.basis.z
	var best := Vector3.INF
	var best_d := winch_reach
	for a in terrain.tree_anchors:
		var to := a - bumper
		var d := to.length()
		if d < best_d and to.normalized().dot(fwd) > 0.15:
			best_d = d
			best = a
	if best == Vector3.INF:
		return
	winch_anchor = best
	winch_target_len = best_d
	winch_active = true


func _bumper_pos() -> Vector3:
	return to_global(Vector3(0, 0.4, -2.15))


func _winch_step(delta: float) -> void:
	_cable_mesh.clear_surfaces()
	if not winch_active:
		return
	var bumper := _bumper_pos()
	var to := winch_anchor - bumper
	var dist := to.length()
	if dist < 1.6:
		winch_active = false
		return
	winch_target_len = maxf(1.2, winch_target_len - winch_pull_speed * delta)
	var stretch := dist - winch_target_len
	var force := clampf(stretch * 60000.0, 0.0, winch_max_force)
	# cable can't push, and it stalls rather than snapping: hold target
	if force >= winch_max_force:
		winch_target_len = dist - winch_max_force / 60000.0
	apply_force(to.normalized() * force, bumper - global_position)
	_cable_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_cable_mesh.surface_add_vertex(bumper)
	_cable_mesh.surface_add_vertex(winch_anchor)
	_cable_mesh.surface_end()


func status_text() -> String:
	var lines := []
	lines.append("%3.0f km/h   %s   %s" % [speed_kmh, "4L" if low_range else "4H", "DIFF LOCK" if diff_locked else "diff open"])
	if winch_active:
		lines.append("WINCH  pulling (%.1f m)" % _bumper_pos().distance_to(winch_anchor))
	var names := ["FL", "FR", "RL", "RR"]
	for i in range(mini(4, wheel_status.size())):
		var s := wheel_status[i]
		var w := wheels[i]
		var tag := ""
		if s["in_water"] > 0.1:
			tag = "water %.1fm" % s["in_water"]
		elif s["in_mud"] > 0.2:
			tag = "mud sink %.2fm wet %.0f%%" % [w.sink, s["wet"] * 100.0]
		else:
			tag = "firm"
		if s["slip"] > 0.3:
			tag += "  SPINNING"
		lines.append("%s  %s" % [names[i], tag])
	lines.append("mud on rig %.0f%%" % (cake * 100.0))
	return "\n".join(lines)
