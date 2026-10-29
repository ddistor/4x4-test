class_name Rig
extends RigidBody3D
## The trail rig: the drivetrain, suspension, winch, mud and recovery every
## rig shares. Which rig it is (size, weight, tires, gearing, the body and
## where the driver sits) comes from a RigSpec, picked in the start menu;
## each body is modelled procedurally in scripts/vehicle/bodies/.
##
## Forward is -Z (Godot convention). Wheels are RigWheel children placed at
## the top of their suspension travel.

@export var terrain_path: NodePath

# Drivetrain: defaults here, each RigSpec sets its own in _ready
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
@export var axle_roll_stiffness := 18000.0   # N/m side-to-side, per axle

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
var cake := 0.0          # 0..1 belly line from wallowing
var corner_mud: Array[float] = [0.0, 0.0, 0.0, 0.0]  # 0..2 clay each tire has thrown on the body
var dryness := 0.4
var wheel_status: Array[Dictionary] = []
var psi_target := 35.0
var airing := 0          # -1 letting air out, +1 compressor running, 0 idle

const PSI_STEPS: Array[float] = [35.0, 28.0, 22.0, 18.0, 15.0, 12.0]

const CORNER_PARAMS: Array[StringName] = [&"corner_fl", &"corner_fr", &"corner_rl", &"corner_rr"]

var spare_mat: ShaderMaterial   # set by the body if it carries a spare
var _body_mats: Array[ShaderMaterial] = []
var _axles: Array = []   # [MeshInstance3D, ShaderMaterial, diff x]
var _shafts: Array = []  # [MeshInstance3D, ShaderMaterial]
var _flag: MeshInstance3D
var _cable: MeshInstance3D
var _cable_mesh: ImmediateMesh
var _spawn: Transform3D
var driver: Driver
var winch_aim: WinchAim
var spec: RigSpec
## Shown in the garage: no terrain, the body held still, wheels at ride height.
var preview := false
## In the preview: front-left and rear-right at the bump stop, the others at
## full droop, to check every body clears its tires.
var flex := false


func _ready() -> void:
	preview = terrain_path.is_empty()
	if not preview:
		terrain = get_node(terrain_path) as Terrain
	freeze = preview
	spec = RigSpec.get_kind(Game.rig_kind)
	mass = spec.mass
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = spec.center_of_mass
	max_drive_force_high = spec.drive_force_high
	max_speed_high = spec.speed_high
	max_drive_force_low = spec.drive_force_low
	max_speed_low = spec.speed_low
	max_steer = spec.max_steer
	axle_roll_stiffness = spec.axle_roll_stiffness
	can_sleep = false
	continuous_cd = true
	_build_body()
	driver = Driver.new()
	driver.name = "Driver"
	add_child(driver)
	driver.build(self)
	winch_aim = WinchAim.new()
	winch_aim.name = "WinchAim"
	add_child(winch_aim)
	winch_aim.setup(self)
	_build_wheels()
	_build_axles()
	_build_cable()
	_spawn = global_transform
	if preview:
		set_process_unhandled_input(false)
		winch_aim.set_process_unhandled_input(false)
		winch_aim.set_process(false)


func _build_body() -> void:
	spec.build_body.call(self)


## The body colour picked in the menu: gloss paint, or polished stainless.
func paint_mat(rough: float, coat: float) -> ShaderMaterial:
	var metal := Game.paint_metal()
	return _body_mat(Game.paint_color(), lerpf(rough, 0.24, metal), metal, coat * (1.0 - metal))


func _body_mat(col: Color, rough: float, metal: float, coat: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/mud_cake.gdshader")
	m.set_shader_parameter("paint", col)
	m.set_shader_parameter("paint_roughness", rough)
	m.set_shader_parameter("paint_metallic", metal)
	m.set_shader_parameter("clearcoat", coat)
	_body_mats.append(m)
	return m


func _add_mesh(m: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	add_child(mi)
	return mi


## Solid axles that follow the wheels, with the diffs and driveshafts.
func _build_axles() -> void:
	var c := Color.WHITE
	for front: bool in [true, false]:
		var st := MeshKit.begin()
		var half := spec.track - 0.14   # axle tube ends just inside the hubs
		MeshKit.tube(st, Vector3(-half, 0, 0), Vector3(half, 0, 0), 0.045, Transform3D.IDENTITY, c, 12)
		var diff_x := -0.18 if front else 0.0
		MeshKit.sphere(st, 0.15, Transform3D(Basis.from_scale(Vector3(1.0, 0.95, 0.8)), Vector3(diff_x, 0, 0)), c, 16)
		MeshKit.cylinder(st, 0.12, 0.05, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(diff_x, 0, 0.11 if front else -0.11)), c, 16)
		for sx: float in [-1.0, 1.0]:
			MeshKit.cylinder(st, 0.09, 0.1, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(sx * half, 0, 0)), c, 14)
		var m := _body_mat(Color(0.05, 0.05, 0.05), 0.65, 0.3, 0.0)
		_axles.append([_add_mesh(MeshKit.commit(st, m)), m, diff_x])
	for _i in range(2):
		var st := MeshKit.begin()
		MeshKit.tube(st, Vector3(0, -0.5, 0), Vector3(0, 0.5, 0), 0.032, Transform3D.IDENTITY, c, 10)
		var m := _body_mat(Color(0.05, 0.05, 0.05), 0.65, 0.3, 0.0)
		_shafts.append([_add_mesh(MeshKit.commit(st, m)), m])


func _process(_delta: float) -> void:
	if _axles.is_empty():
		return
	var tcase := Vector3(0.0, 0.38, -0.15)
	for a in range(2):
		var l := wheels[a * 2]
		var r := wheels[a * 2 + 1]
		var pl := l.position + l.hub_offset
		var pr := r.position + r.hub_offset
		var x_axis := (pr - pl).normalized()
		var y_axis := Vector3.BACK.cross(x_axis).normalized()
		var xf := Transform3D(Basis(x_axis, y_axis, x_axis.cross(y_axis)), (pl + pr) * 0.5)
		_place(_axles[a], xf)
		var diff_pos: Vector3 = xf * Vector3(_axles[a][2], 0, 0)
		var dir := diff_pos - tcase
		_place(_shafts[a], Transform3D(MeshKit.y_to(dir).scaled_local(Vector3(1, dir.length(), 1)), (diff_pos + tcase) * 0.5))
	# flag flutters harder the faster you go
	if _flag == null:
		return
	var t := Time.get_ticks_msec() * 0.001
	var gust := 0.25 + clampf(speed_kmh / 40.0, 0.0, 1.0)
	_flag.rotation = Vector3(0, sin(t * 6.3) * 0.25 * gust + sin(t * 2.1) * 0.15, sin(t * 9.0) * 0.1 * gust)


func _place(part: Array, xf: Transform3D) -> void:
	(part[0] as MeshInstance3D).transform = xf
	(part[1] as ShaderMaterial).set_shader_parameter("part_xform", Projection(xf))


func _build_wheels() -> void:
	var track := spec.track
	var y := spec.wheel_mount_y
	var layout := [
		[Vector3(-track, y, spec.front_z), true, true],
		[Vector3(track, y, spec.front_z), true, false],
		[Vector3(-track, y, spec.rear_z), false, true],
		[Vector3(track, y, spec.rear_z), false, false],
	]
	for entry in layout:
		var w := RigWheel.new()
		w.radius = spec.tire_radius
		w.width = spec.tire_width
		w.stiffness = spec.spring_stiffness
		w.max_travel = spec.droop
		# bump stop where the hub has risen `bump` above ride height
		w.bump_limit = RigSpec.RIDE_HUB_Y + spec.bump - spec.wheel_mount_y + w.rest_length
		w.position = entry[0]
		w.steerable = entry[1]
		w.left_side = entry[2]
		add_child(w)
		wheels.append(w)
		# the tire as a solid, a little inside the tread: it carries the rig
		# when it's on its side and is the bump stop when the springs bottom
		var tire := CollisionShape3D.new()
		var drum := CylinderShape3D.new()
		drum.radius = spec.tire_radius - 0.145
		drum.height = spec.tire_width - 0.12
		tire.shape = drum
		tire.transform = Transform3D(Basis(Vector3.BACK, PI * 0.5), w.position + Vector3(0, -0.1, 0))  # axle along X
		add_child(tire)


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
	elif event.is_action_pressed("air_down") or event.is_action_pressed("air_up"):
		var i := PSI_STEPS.find(psi_target) + (1 if event.is_action_pressed("air_down") else -1)
		psi_target = PSI_STEPS[clampi(i, 0, PSI_STEPS.size() - 1)]
	elif event.is_action_pressed("reset_rig"):
		recover()


func reset_to_spawn() -> void:
	# Put it back on the road, upright, pointed up the trail.
	place_on_trail(6.0)


## Back on the trail where you are, a couple of metres behind: the marshal's
## recovery, not a trip back to the start of the stage.
func recover() -> void:
	place_on_trail(clampf(global_position.z - 2.0, 6.0, terrain.length - 5.0))


## Drop the rig on the trail centre at distance `z`, upright, facing up-trail.
func place_on_trail(z: float) -> void:
	var x := terrain.trail_x_at(z)
	# face along the trail, not just up the map: it curves from the first metre
	var heading := Vector3(terrain.trail_x_at(z + 3.0) - terrain.trail_x_at(z - 3.0), 0.0, 6.0)
	var t := Transform3D(Basis.looking_at(heading, Vector3.UP), Vector3(x, terrain.get_height(x, z) + 1.2, z))
	global_transform = t
	# also straight to the server: from inside a physics-frame callback the
	# node-side set alone gets overwritten by the next step
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, t)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	winch_active = false
	if driver:
		driver.snap()
	for w in wheels:
		w.sink = 0.0
		w.slip = 0.0
		# reseat any bead that came off; pressure goes back to the target
		w.debeaded = false
		w.psi = psi_target


func _physics_process(delta: float) -> void:
	if preview:
		for i in wheels.size():
			var w := wheels[i]
			var d := w.rest_length + w.effective_radius() - 0.06
			if flex:
				d = 0.0 if i == 0 or i == 3 else 99.0   # clamped to the bump stop / full droop
			w._update_mesh(d, delta)
		return
	if global_position.y < -25.0 or global_transform.basis.y.y < -0.6 and linear_velocity.length() < 0.3:
		# fell off the map or settled on the roof
		recover()
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
		var mu_guess := lerpf(0.92, 0.3, w.ground.get("wetness", 0.3))
		caps.append(mu_guess * maxf(w.load, 0.0))
	for axle in range(2):
		var a := axle * 2
		var b := a + 1
		# Solid axle: the two sides are one beam, so when the body leans the
		# axle hands load from the inside tire to the outside one instead of
		# letting the body jack up off the inside wheel.
		var ca := wheels[a].compression()
		var cb := wheels[b].compression()
		var bar := 0.0
		if ca > -0.5 and cb > -0.5:
			bar = axle_roll_stiffness * (ca - cb)
		wheels[a].axle_load = bar
		wheels[b].axle_load = -bar
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
	_air_step(delta)

	# --- mud on the rig -------------------------------------------------------
	# Each tire throws what it churns onto the bodywork around and behind it:
	# a second of wheelspin shows, a minute in the bog buries the corner.
	# Wallowing deep smears the belly; the creek rinses it all back off.
	var thrown := 0.0
	var rinse := 0.0
	var corners: Array[Vector4] = []
	for i in range(wheel_status.size()):
		var s := wheel_status[i]
		var w := wheels[i]
		var fling: float = s["in_mud"] * (0.9 * s["slip"] + 0.05 * absf(w.omega) * w.radius) * (0.5 + s["wet"])
		corner_mud[i] = minf(2.0, corner_mud[i] + fling * delta * 0.35 * (1.0 - corner_mud[i] / 2.2))
		cake = minf(1.0, cake + s["in_mud"] * maxf(0.0, w.sink - 0.15) * delta * 0.04)
		var water: float = s["in_water"]
		if water > 0.15:
			corner_mud[i] = maxf(0.0, corner_mud[i] - delta * 0.12 * water * (1.0 + absf(v_fwd)))
			rinse = maxf(rinse, water)
		thrown += fling
		# where the clay was thrown from: the wheel at ride height, fixed to the
		# body, so the splatter stays put instead of sliding with the suspension
		var hub := w.position + Vector3(0, -0.21, 0)
		corners.append(Vector4(hub.x, hub.y, hub.z, corner_mud[i]))
	if rinse > 0.0:
		cake = maxf(0.0, cake - delta * 0.1 * rinse * (1.0 + absf(v_fwd)))
	# fresh mud goes on wet and glossy; it takes a good minute to bake pale
	if thrown > 0.05 or rinse > 0.0:
		dryness = move_toward(dryness, 0.0, delta * (0.6 * thrown + rinse))
	else:
		dryness = move_toward(dryness, 1.0, delta * 0.012)
	for m in _body_mats:
		for i in range(corners.size()):
			m.set_shader_parameter(CORNER_PARAMS[i], corners[i])
		m.set_shader_parameter("cake", cake)
		m.set_shader_parameter("dryness", dryness)
	for w in wheels:
		w.tire_mat.set_shader_parameter("dryness", dryness)
	if spare_mat:
		spare_mat.set_shader_parameter("tire_mud", minf(1.0, (corner_mud[2] + corner_mud[3]) * 0.25))
		spare_mat.set_shader_parameter("dryness", dryness)

	terrain.mud.flush()


func _toggle_winch() -> void:
	# F: release a running winch; otherwise aim, and F again hooks the pick
	if winch_active:
		winch_active = false
	elif winch_aim.active:
		winch_aim.confirm()
	else:
		winch_aim.begin()


## Run the cable out to `anchor` and start pulling.
func hook_winch(anchor: Vector3) -> void:
	winch_anchor = anchor
	winch_target_len = fairlead().distance_to(anchor)
	winch_active = true


func fairlead() -> Vector3:
	return _bumper_pos()


func _bumper_pos() -> Vector3:
	return to_global(spec.fairlead)


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


## Rough 0..1 for the HUD: how much of the rig is clay.
func mud_amount() -> float:
	var corners := 0.0
	for m in corner_mud:
		corners += m
	return clampf(corners / 8.0 * 0.75 + cake * 0.4, 0.0, 1.0)


## Air down / up toward psi_target, but only while stopped: you get out and
## let air out of each valve (quick), or run the compressor (slow).
func _air_step(delta: float) -> void:
	airing = 0
	if speed_kmh > 3.0:
		return
	for w in wheels:
		if w.debeaded:
			continue
		if w.psi > psi_target + 0.05:
			w.psi = move_toward(w.psi, psi_target, 2.5 * delta)
			airing = -1
		elif w.psi < psi_target - 0.05:
			w.psi = move_toward(w.psi, psi_target, 0.8 * delta)
			airing = 1


## Body roll and pitch in degrees (+roll = leaning right, +pitch = nose up).
func roll_pitch() -> Vector2:
	var b := global_transform.basis
	var roll := rad_to_deg(asin(clampf(-b.x.y, -1.0, 1.0)))
	var pitch := rad_to_deg(asin(clampf(-b.z.y, -1.0, 1.0)))
	return Vector2(roll, pitch)


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
		if w.packing > 0.5:
			tag += "  tread packed"
		if w.debeaded:
			tag += "  OFF THE BEAD"
		lines.append("%s  %s" % [names[i], tag])
	var psi_line := "tires %.0f psi" % wheels[0].psi
	if airing < 0:
		psi_line += "  airing down to %.0f" % psi_target
	elif airing > 0:
		psi_line += "  compressor on, to %.0f" % psi_target
	elif absf(wheels[0].psi - psi_target) > 0.5:
		psi_line += "  (stop to set %.0f)" % psi_target
	lines.append(psi_line)
	lines.append("mud on rig %.0f%%" % (mud_amount() * 100.0))
	return "\n".join(lines)
