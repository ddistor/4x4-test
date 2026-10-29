class_name RigWheel
extends Node3D
## One corner of the rig: raycast suspension + a simple brush tire model +
## the soft-ground interaction (sink, drag, rut carving, spin-digging).
##
## The node sits at the top of the suspension travel in rig space. The wheel
## mesh is a child that gets moved down to wherever the tire actually sits.

@export var radius := 0.42          # 33" mud terrain
@export var width := 0.30
@export var rest_length := 0.36     # suspension travel at rest
@export var max_travel := 0.30      # extra droop below rest
@export var stiffness := 38000.0
@export var damping := 3600.0
@export var steerable := false
@export var left_side := false

# Runtime state
var contact := false
var contact_point := Vector3.ZERO
var contact_normal := Vector3.UP
var load := 0.0               # N pushing the tire into the ground
var sink := 0.0               # metres below the (rutted) surface the tire sits
var slip := 0.0               # 0 = gripping, 1 = fully spinning / sliding
var omega := 0.0              # rad/s, for visuals and dig
var steer_angle := 0.0
var ground := {}              # last terrain sample
var _last_compression := 0.0

var mesh: MeshInstance3D
var spray: GPUParticles3D
var splash: GPUParticles3D

const NOMINAL_LOAD := 5500.0


func _ready() -> void:
	_build_mesh()
	_build_particles()


func _build_mesh() -> void:
	mesh = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = width
	cyl.radial_segments = 20
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.08, 0.08)
	mat.roughness = 0.95
	cyl.material = mat
	mesh.mesh = cyl
	mesh.rotation_degrees = Vector3(0, 0, 90)
	add_child(mesh)
	# Rim: a slightly smaller, lighter disc so rotation reads.
	var rim := MeshInstance3D.new()
	var rc := CylinderMesh.new()
	rc.top_radius = radius * 0.55
	rc.bottom_radius = radius * 0.55
	rc.height = width + 0.02
	rc.radial_segments = 6
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.55, 0.52, 0.48)
	rmat.metallic = 0.6
	rmat.roughness = 0.5
	rc.material = rmat
	rim.mesh = rc
	mesh.add_child(rim)


func _build_particles() -> void:
	spray = GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 1)
	pm.spread = 35.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 7.0
	pm.gravity = Vector3(0, -9.8, 0)
	pm.scale_min = 0.05
	pm.scale_max = 0.16
	pm.color = Color(0.42, 0.21, 0.09)
	spray.process_material = pm
	spray.amount = 60
	spray.lifetime = 1.1
	spray.emitting = false
	spray.local_coords = false
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 6
	sm.rings = 3
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.42, 0.21, 0.09)
	smat.roughness = 0.9
	sm.material = smat
	spray.draw_pass_1 = sm
	add_child(spray)

	splash = GPUParticles3D.new()
	var wm := pm.duplicate() as ParticleProcessMaterial
	wm.color = Color(0.65, 0.55, 0.4, 0.8)
	wm.initial_velocity_min = 4.0
	wm.initial_velocity_max = 9.0
	wm.spread = 55.0
	splash.process_material = wm
	splash.amount = 90
	splash.lifetime = 0.8
	splash.emitting = false
	splash.local_coords = false
	var wmesh := sm.duplicate() as SphereMesh
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.7, 0.6, 0.45)
	wmat.roughness = 0.3
	wmesh.material = wmat
	splash.draw_pass_1 = wmesh
	add_child(splash)


## Called from the rig every physics tick. `drive_force` is the longitudinal
## force the drivetrain is asking this tire to put down (N, +forward).
## Returns a dictionary with what actually happened so the rig can model the
## open diff and the mud caking.
func physics_step(rig: RigidBody3D, terrain: Terrain, delta: float, drive_force: float,
		brake_force: float, grip_cap_override: float) -> Dictionary:
	var space := rig.get_world_3d().direct_space_state
	var top := global_position
	var down := -rig.global_transform.basis.y
	var ray_len := rest_length + max_travel + radius + 0.9  # 0.9: deepest mud we allow
	var query := PhysicsRayQueryParameters3D.create(top, top + down * ray_len)
	query.exclude = [rig.get_rid()]
	var hit := space.intersect_ray(query)

	var result := {"slip": 0.0, "in_mud": 0.0, "wet": 0.0, "in_water": 0.0, "cap": 0.0}
	if hit.is_empty():
		contact = false
		load = 0.0
		sink = lerpf(sink, 0.0, delta * 4.0)
		slip = 0.0
		_update_mesh(rest_length + max_travel, delta)
		spray.emitting = false
		splash.emitting = false
		return result

	# --- where the tire actually sits -------------------------------------
	ground = terrain.ground_sample(hit.position)
	var room: float = maxf(0.0, ground["thickness"] - ground["rut"])
	var wet: float = ground["wetness"]
	var water: float = ground["water_depth"]
	# Soft surface the tire would rest on if it didn't sink: firm + room.
	var surface_dist: float = (hit.position - top).length() - room
	# How far it wants to sink: wetter + heavier + spinning = deeper, capped by room.
	var load_k := clampf(load / NOMINAL_LOAD, 0.4, 1.6)
	var target_sink: float = room * clampf((0.25 + 0.75 * wet) * load_k + 0.35 * slip, 0.0, 1.0)
	var yield_rate := 2.5 + 6.0 * slip  # churning mud gives way faster
	sink = move_toward(sink, target_sink, yield_rate * delta * maxf(room, 0.05))
	sink = minf(sink, room)
	var contact_dist: float = surface_dist + sink
	contact = contact_dist <= rest_length + max_travel + radius
	contact_point = top + down * contact_dist
	contact_normal = hit.normal

	# --- suspension ------------------------------------------------------
	var compression: float = (rest_length + radius) - contact_dist
	var spring := 0.0
	if contact:
		var comp_vel := (compression - _last_compression) / delta
		spring = maxf(0.0, stiffness * compression + damping * comp_vel)
		# bottoming out
		if compression > rest_length * 0.95:
			spring += stiffness * 4.0 * (compression - rest_length * 0.95)
	_last_compression = compression
	load = spring
	var hub := top + down * (contact_dist - radius)
	rig.apply_force(-down * spring, hub - rig.global_position)

	if not contact:
		slip = 0.0
		_update_mesh(contact_dist, delta)
		spray.emitting = false
		splash.emitting = false
		return result

	# --- tire frame ------------------------------------------------------
	var basis := rig.global_transform.basis
	var fwd := (-basis.z).rotated(basis.y, steer_angle)  # Godot: -Z is forward
	# project onto contact plane
	fwd = (fwd - contact_normal * fwd.dot(contact_normal)).normalized()
	var right := fwd.cross(contact_normal).normalized()
	var vel := rig.linear_velocity + rig.angular_velocity.cross(contact_point - rig.global_position)
	var v_fwd := vel.dot(fwd)
	var v_lat := vel.dot(right)

	# --- grip -----------------------------------------------------------
	var soft := smoothstep(0.03, 0.2, room + ground["rut"])
	var mu := lerpf(0.95, 0.40, wet)                    # slick when wet
	mu *= 1.0 - 0.15 * soft                              # soup has less to push on
	var sink_ratio := sink / maxf(room, 0.05)
	mu += 0.3 * sink_ratio * (1.0 - wet * 0.5)           # bite once the tire is in
	var mu_lat := mu + 0.45 * smoothstep(0.05, 0.25, ground["rut"])  # rut walls guide
	var cap := mu * load
	if grip_cap_override >= 0.0:
		cap = minf(cap, grip_cap_override)
	result["cap"] = mu * load

	# --- longitudinal ---------------------------------------------------
	var f_long := drive_force
	if brake_force > 0.0:
		f_long -= signf(v_fwd) * minf(brake_force, absf(v_fwd) * load * 2.0 + 200.0)
	var slipping := absf(f_long) > cap
	if slipping:
		f_long = signf(f_long) * cap
	# --- lateral --------------------------------------------------------
	var f_lat := -v_lat * load * 1.9
	f_lat = clampf(f_lat, -mu_lat * load, mu_lat * load)
	# friction circle: a spinning tire has little sideways grip
	var long_use := absf(f_long) / maxf(cap, 1.0)
	f_lat *= sqrt(maxf(0.0, 1.0 - long_use * long_use)) * 0.6 + 0.4

	# --- soft-ground resistance -----------------------------------------
	# Pushing a tire through mud: drag that grows with sink and wetness, plus
	# water drag in the creek. This is what makes the bog feel like a bog.
	var planar := vel - contact_normal * vel.dot(contact_normal)
	var drag_c := sink * 1500.0 * (0.6 + 0.6 * wet) + water * 900.0
	var f_drag := -planar * drag_c
	# suction: hard to get moving from a stop in deep mud
	if planar.length() < 0.6 and sink > 0.08:
		f_drag -= planar.normalized() * sink * 1800.0 * (planar.length() / 0.6)

	rig.apply_force(fwd * f_long + right * f_lat + f_drag, contact_point - rig.global_position)

	# --- slip / wheel speed / digging -------------------------------------
	var target_slip := 0.0
	if slipping:
		target_slip = clampf((absf(drive_force) - cap) / maxf(cap, 500.0), 0.0, 1.0)
	slip = lerpf(slip, target_slip, delta * 8.0)
	var free_omega := signf(drive_force) * 28.0 * (0.3 + 0.7 * slip)
	var rolling_omega := v_fwd / radius
	omega = lerpf(rolling_omega, free_omega, slip)

	# Carve: settling into the mud makes a rut; spinning flings it out faster.
	var carve_amt := maxf(0.0, sink - ground["rut"]) * 0.8 * delta + slip * 0.35 * delta * soft
	if carve_amt > 0.001:
		terrain.mud.carve(Vector2(contact_point.x, contact_point.z), width * 0.5, carve_amt)

	# --- feedback for rig ------------------------------------------------
	result["slip"] = slip
	result["in_mud"] = soft
	result["wet"] = wet
	result["in_water"] = water
	spray.global_position = contact_point
	spray.emitting = soft > 0.3 and (slip > 0.25 or absf(v_fwd) > 3.5)
	splash.global_position = contact_point
	splash.emitting = water > 0.1 and planar.length() > 1.5

	_update_mesh(contact_dist, delta)
	return result


var _spin := 0.0


func _update_mesh(contact_dist: float, delta: float) -> void:
	_spin -= omega * delta
	# cylinder axis is Y: rotate it onto X (the axle), spin about X, then yaw for steering
	var b := Basis.from_euler(Vector3(0, steer_angle, 0)) * Basis(Vector3.RIGHT, _spin) * Basis(Vector3.BACK, PI / 2.0)
	mesh.transform = Transform3D(b, Vector3(0, -(contact_dist - radius), 0))
