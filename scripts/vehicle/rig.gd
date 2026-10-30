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

# Engine and gears: gearbox.gd, set up from the RigSpec
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
var gearbox := Gearbox.new()
var kit: RecoveryKit      # shovel, traction boards, high-lift jack
var mud_ash := 0.0        # 0 the mud on it is red clay .. 1 grey lahar ash
var choke := 0.0         # 0..1 how drowned the air intake is (no drive at 1)
var winch_active := false
var winch_anchor := Vector3.INF
var winch_target_len := 0.0
var winch_tension := 0.0    # N in the cable this step (HUD, tests)
const WINCH_K := 60000.0    # N per m the line stretches
const WINCH_C := 16000.0    # N per m/s: damping, ~0.7 of critical for a 2 t rig
var throttle := 0.0
var brake := 0.0
var steer := 0.0
var speed_kmh := 0.0
var cake := 0.0          # 0..1 belly line from wallowing
var corner_mud: Array[float] = [0.0, 0.0, 0.0, 0.0]  # 0..2 clay each tire has thrown on the body
var dryness := 0.4
var crust := 0.0         # 0..1 how set the old mud is: dried hard, it grips the paint and resists washing
var flaked := 0.0        # 0..1 how much dried crust has chipped off (leaves pale stains)
var wash_y := -10.0      # rig-space height the last wade reached; mud below it is washed
var washed := 0.0        # 0..1 how clean the wade has got the body below wash_y
var _last_vel := Vector3.ZERO
var _flake_chips: GPUParticles3D
var _no_flake := 0.0
var _knock_cool := 0.0
var _plumes: Array[Vector4] = []   # clay stirred into the water: x, z, strength, time
var _plume_next := 0
var _plume_wait := 0.0
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
	gearbox.setup(spec)
	# no blanket linear damping (Godot's default 0.1/s is ~3 kN at 60 km/h):
	# air drag and rolling resistance in _physics_process slow it instead
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
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
	kit = RecoveryKit.new()
	kit.name = "RecoveryKit"
	add_child(kit)
	kit.setup(self)
	_build_wheels()
	_build_axles()
	_build_cable()
	_build_flake_chips()
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
	if spec.cabin_hi.x > 0.0:
		m.set_shader_parameter("cabin_lo", spec.cabin_lo)
		m.set_shader_parameter("cabin_hi", spec.cabin_hi)
		m.set_shader_parameter("cabin_open", spec.cabin_open)
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
		w.wheel_color = spec.wheel_color
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


## Little chips of dry clay that fall off the body when a knock cracks the crust.
func _build_flake_chips() -> void:
	_flake_chips = GPUParticles3D.new()
	_flake_chips.emitting = false
	_flake_chips.one_shot = true
	_flake_chips.amount = 48
	_flake_chips.lifetime = 1.4
	_flake_chips.explosiveness = 0.85
	_flake_chips.position = Vector3(0, 0.75, 0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(spec.track + 0.1, 0.3, absf(spec.front_z) + 0.3)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 60.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 1.2
	pm.gravity = Vector3(0, -9.8, 0)
	pm.angular_velocity_min = -400.0
	pm.angular_velocity_max = 400.0
	pm.scale_min = 0.5
	pm.scale_max = 1.6
	_flake_chips.process_material = pm
	var chip := BoxMesh.new()
	chip.size = Vector3(0.025, 0.006, 0.02)
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.55, 0.3, 0.16)
	cm.roughness = 0.95
	chip.material = cm
	_flake_chips.draw_pass_1 = chip
	_flake_chips.local_coords = false
	add_child(_flake_chips)


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
	elif event.is_action_pressed("shift_up"):
		gearbox.shift(1)
	elif event.is_action_pressed("shift_down"):
		gearbox.shift(-1)
	elif event.is_action_pressed("gear_mode"):
		gearbox.auto = not gearbox.auto
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
	_last_vel = Vector3.ZERO
	_no_flake = 1.5   # the drop back onto the trail isn't a knock on the crust
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
	if kit.busy > 0.0:
		# the driver's out with the shovel or the jack: handbrake on
		throttle = 0.0
		brake = 0.0
		handbrake = true

	var fwd := -global_transform.basis.z
	var v_fwd := linear_velocity.dot(fwd)
	speed_kmh = absf(v_fwd) * 3.6

	# --- engine ------------------------------------------------------------
	# the brake held at a standstill backs up (reverse gear)
	var reverse := brake > 0.0 and v_fwd < 0.6 and throttle <= 0.0
	var pedal := brake * 0.6 if reverse else throttle
	var braking := (brake > 0.0 and not reverse) or handbrake
	var tire_spin := 0.0
	for w in wheels:
		tire_spin += w.slip * 0.25
	var drive_total := gearbox.step(delta, pedal, reverse, braking, low_range, v_fwd, wheels[0].effective_radius(), tire_spin)
	# hydrolock-lite: a drowned intake chokes the engine
	var front_water := maxf(wheels[0].ground.get("water_depth", 0.0), wheels[1].ground.get("water_depth", 0.0))
	choke = smoothstep(0.75, 1.05, front_water)
	drive_total *= 1.0 - choke
	# spinning tires turn at what the engine turns them through the gears
	var spin_omega := gearbox.rpm * TAU / 60.0 / gearbox.ratio(low_range) * (-1.0 if gearbox.gear < 0 else 1.0)
	for w in wheels:
		w.spin_omega = spin_omega

	# air and rolling resistance: what sets the top speed in each gear now
	var v := linear_velocity
	apply_central_force(-v * v.length() * 0.6 * spec.drag_area)   # ½ρ ≈ 0.6
	var grounded := 0.0
	for w in wheels:
		grounded += 0.25 if w.contact else 0.0
	apply_central_force(-fwd * 0.015 * mass * 9.8 * grounded * clampf(v_fwd / 0.5, -1.0, 1.0))

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
			# it only moves load across: it can't hand over more than the light
			# side carries (or it would hold the rig up and stop it ever tipping)
			var light := wheels[b] if bar > 0.0 else wheels[a]
			var light_c := cb if bar > 0.0 else ca
			bar = clampf(bar, -light.stiffness * maxf(light_c, 0.0), light.stiffness * maxf(light_c, 0.0))
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
	if body_water > 0.1:
		# pushing water: ½ρ·Cd·A·v², A the submerged front of the rig, so it
		# bites hard as you speed up (the bow wave); walking pace is cheap
		var v_plan := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
		var area := minf(body_water, 1.2) * (spec.track * 2.0 + spec.tire_width)
		apply_central_force(-v_plan * v_plan.length() * 0.5 * 1000.0 * 0.9 * area)
	if body_water > 0.4:
		# the body floats once it's in: a closed cab holds air and lifts about
		# half the rig; an open tub just fills with water
		var submerged := clampf((body_water - 0.4) / 0.9, 0.0, 1.0)
		var lift := 0.55 if spec.closed() else 0.2
		apply_central_force(Vector3.UP * mass * 9.8 * lift * submerged)
		apply_central_force(-linear_velocity * 600.0 * submerged)

	# --- winch -----------------------------------------------------------------
	_winch_step(delta)
	_air_step(delta)

	# --- mud on the rig -------------------------------------------------------
	# Each tire throws what it churns onto the bodywork around and behind it.
	# It builds slowly: rolling through clay flecks the arches, it's wheelspin
	# in deep wet mud that plasters a corner, and it piles on from the bottom
	# up. Left alone it dries and sets into a crust that grips the paint; hard
	# knocks chip the dry crust off. A wade only washes what's under the water,
	# and only slowly: fresh mud softens and goes in a few seconds, set crust
	# barely shifts.
	var thrown := 0.0
	var rinse := 0.0
	var corners: Array[Vector4] = []
	# how high the water came up the body, in rig space
	var water_top := -10.0
	for w in wheels:
		var depth: float = w.ground.get("water_depth", 0.0)
		if w.contact and depth > 0.05:
			water_top = maxf(water_top, to_local(w.contact_point + global_basis.y * depth).y)
	var ground_speed := absf(v_fwd)
	for i in range(wheel_status.size()):
		var s := wheel_status[i]
		var w := wheels[i]
		var spin: float = s["slip"] * s["slip"]
		var fling: float = s["in_mud"] * (1.1 * spin + 0.012 * absf(w.omega) * w.radius) * (0.3 + 0.9 * s["wet"])
		# slow at first, slower again as the corner fills
		corner_mud[i] = minf(2.0, corner_mud[i] + fling * delta * 0.09 * (1.0 - corner_mud[i] / 2.3))
		# what it throws is what it's rolling in: a fresh coat of grey ash over
		# red clay turns the rig grey, by how much goes on against what's there
		var ash: float = w.ground.get("ash", 0.0)
		mud_ash = move_toward(mud_ash, ash, fling * delta * 0.09 / maxf(0.15, corner_mud[i] * 0.5))
		cake = minf(1.0, cake + s["in_mud"] * maxf(0.0, w.sink - 0.18) * delta * 0.025)
		# a corner only washes once the water is up over the wheel's patch
		var hub := w.position + Vector3(0, -0.21, 0)
		var under := clampf((water_top - hub.y + 0.15) / 0.8, 0.0, 1.0)
		if under > 0.0:
			var soft := lerpf(1.0, 0.12, crust)
			corner_mud[i] = maxf(0.0, corner_mud[i] - delta * 0.035 * under * soft * (0.4 + 0.25 * minf(ground_speed, 4.0)))
			rinse = maxf(rinse, under)
		thrown += fling
		# where the clay was thrown from: the wheel at ride height, fixed to the
		# body, so the splatter stays put instead of sliding with the suspension
		corners.append(Vector4(hub.x, hub.y, hub.z, corner_mud[i]))
	var belly_under := clampf((water_top - 0.45) / 0.6, 0.0, 1.0)
	if belly_under > 0.0:
		cake = maxf(0.0, cake - delta * 0.03 * belly_under * lerpf(1.0, 0.12, crust))
	# the wash line: everything below the water gets cleaner the longer it sits in it
	if water_top > -5.0:
		if water_top > wash_y or washed < 0.05:
			wash_y = maxf(wash_y, water_top)
		washed = minf(1.0, washed + delta * 0.06 * lerpf(1.0, 0.15, crust) * (0.5 + 0.2 * minf(ground_speed, 4.0)))
	# fresh mud thrown over the washed part dirties it again
	washed = maxf(0.0, washed - thrown * delta * 0.15)
	if washed <= 0.0:
		wash_y = -10.0
	# fresh mud goes on wet and glossy; it takes a good few minutes to bake pale
	if thrown > 0.05 or rinse > 0.0:
		dryness = move_toward(dryness, 0.0, delta * (0.25 * thrown + 0.4 * rinse))
	else:
		dryness = move_toward(dryness, 1.0, delta * 0.006)
	# drying sets it; water softens it; a fresh coat goes on soft over the old
	if rinse > 0.0:
		crust = move_toward(crust, 0.0, delta * 0.02 * rinse)
	elif dryness > 0.7:
		crust = move_toward(crust, 1.0, delta * 0.004)
	crust = maxf(0.0, crust - thrown * delta * 0.05)
	# knocks crack the dry crust off in chips
	var jolt := (linear_velocity - _last_vel).length() / maxf(delta, 1e-4)
	_last_vel = linear_velocity
	var brittle := smoothstep(0.55, 0.95, dryness)
	_no_flake = maxf(0.0, _no_flake - delta)
	var hit := maxf(0.0, jolt - 7.0) if _no_flake <= 0.0 else 0.0
	# one knock, one shower of chips: a landing is many frames of jolt
	_knock_cool = maxf(0.0, _knock_cool - delta)
	if brittle > 0.0 and hit > 0.0 and _knock_cool <= 0.0 and flaked < 0.7:
		var chip := minf(hit * 0.004, 0.09) * brittle * minf(crust + 0.3, 1.0)
		flaked = minf(0.7, flaked + chip)
		_knock_cool = 0.4
		if chip > 0.01 and _flake_chips:
			_flake_chips.amount_ratio = clampf(chip * 10.0, 0.2, 1.0)
			_flake_chips.restart()
	# fresh mud covers the flaked spots again
	flaked = maxf(0.0, flaked - thrown * delta * 0.2)
	for m in _body_mats:
		for i in range(corners.size()):
			m.set_shader_parameter(CORNER_PARAMS[i], corners[i])
		m.set_shader_parameter("cake", cake)
		m.set_shader_parameter("dryness", dryness)
		m.set_shader_parameter("flaked", flaked)
		m.set_shader_parameter("wash_y", wash_y)
		m.set_shader_parameter("washed", washed)
		m.set_shader_parameter("mud_ash", mud_ash)
	for w in wheels:
		w.tire_mat.set_shader_parameter("dryness", dryness)
	if spare_mat:
		spare_mat.set_shader_parameter("mud_ash", mud_ash)
		spare_mat.set_shader_parameter("tire_mud", minf(1.0, (corner_mud[2] + corner_mud[3]) * 0.25))
		spare_mat.set_shader_parameter("dryness", dryness)

	_stir_water(delta)
	terrain.mud.flush()


## Tell the water where the tires are (wakes, white water) and drop clay into
## a clear river where they churn the bed: it drifts off downstream.
func _stir_water(delta: float) -> void:
	if terrain.water_mats.is_empty():
		return
	var now := Time.get_ticks_msec() * 0.001
	var wheel_u: Array[Vector4] = []
	var churn := 0.0
	var wet_at := Vector3.ZERO
	for i in range(wheels.size()):
		var w := wheels[i]
		var depth: float = w.ground.get("water_depth", 0.0)
		var v := 0.0
		if w.contact and depth > 0.04:
			v = linear_velocity.length() + absf(w.omega) * w.radius * w.slip
			churn = maxf(churn, (0.4 + w.slip) * minf(v, 3.0))
			wet_at = w.contact_point
		wheel_u.append(Vector4(w.global_position.x, w.global_position.y, w.global_position.z, v if depth > 0.04 else 0.0))
	if _plumes.is_empty():
		for i in range(12):
			_plumes.append(Vector4(0, 0, 0, -100.0))
	_plume_wait -= delta
	if churn > 0.3 and _plume_wait <= 0.0:
		_plumes[_plume_next] = Vector4(wet_at.x, wet_at.z, minf(churn * 0.6, 1.5), now)
		_plume_next = (_plume_next + 1) % _plumes.size()
		_plume_wait = 0.6
	for m in terrain.water_mats:
		m.set_shader_parameter("wheels", wheel_u)
		m.set_shader_parameter("rig_vel", linear_velocity)
		m.set_shader_parameter("plumes", _plumes)
		m.set_shader_parameter("now", now)


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
	winch_tension = 0.0
	if not winch_active:
		return
	var bumper := _bumper_pos()
	var to := winch_anchor - bumper
	var dist := to.length()
	if dist < 1.6:
		winch_active = false
		return
	winch_target_len = maxf(1.2, winch_target_len - winch_pull_speed * delta)
	# The line is a stiff spring with a damper: the damper soaks up the snap
	# when the rig lurches off whatever it was hung up on, instead of the
	# stored stretch flinging it forward and the line going slack and tight.
	var dir := to / dist
	var bumper_vel := linear_velocity + angular_velocity.cross(bumper - global_position)
	var closing := bumper_vel.dot(dir)   # + when the bumper runs toward the anchor
	var stretch := dist - winch_target_len
	var force := clampf(stretch * WINCH_K - closing * WINCH_C, 0.0, winch_max_force)
	# it stalls rather than snapping: the drum stops paying in at full pull
	# (and a slack line is reeled in to just taut, not left to snap tight)
	if stretch * WINCH_K >= winch_max_force:
		winch_target_len = dist - winch_max_force / WINCH_K
	elif stretch < 0.0:
		winch_target_len = dist
	winch_tension = force
	apply_force(dir * force, bumper - global_position)
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
	lines.append("%3.0f km/h   %s %s %s   %s" % [speed_kmh, "4L" if low_range else "4H", gearbox.gear_name(),
		"auto" if gearbox.auto else "manual", "DIFF LOCK" if diff_locked else "diff open"])
	if choke > 0.3:
		lines.append("ENGINE CHOKING: water over the intake (winch out)")
	elif gearbox.running:
		lines.append("%4.0f rpm" % gearbox.rpm)
	else:
		lines.append("STALLED  (throttle to crank it)")
	if winch_active:
		lines.append("WINCH  pulling (%.1f m)" % _bumper_pos().distance_to(winch_anchor))
	var job := kit.status()
	if job != "":
		lines.append(job)
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
