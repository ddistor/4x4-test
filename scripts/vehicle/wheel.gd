class_name RigWheel
extends Node3D
## One corner of the rig: raycast suspension + a simple brush tire model +
## the soft-ground interaction (sink, drag, rut carving, spin-digging).
##
## The node sits at the top of the suspension travel in rig space. The wheel
## mesh is a child that gets moved down to wherever the tire actually sits.

@export var radius := 0.445         # 35" mud terrain
@export var width := 0.32
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

var tire_mud := 0.0           # 0..1 how packed the tread is (visual)

var mesh: MeshInstance3D
var tire_mat: ShaderMaterial
var spray: GPUParticles3D
var splash: GPUParticles3D
var mist: GPUParticles3D

const NOMINAL_LOAD := 5500.0


func _ready() -> void:
	_build_mesh()
	_build_particles()


func _build_mesh() -> void:
	mesh = MeshInstance3D.new()
	tire_mat = ShaderMaterial.new()
	tire_mat.shader = load("res://shaders/tire.gdshader")
	# mesh +Y ends up pointing to rig -X, so the left wheels face out as built
	mesh.mesh = MeshKit.commit(build_wheel_mesh(radius, width, not left_side), tire_mat)
	add_child(mesh)


## Mud-terrain tire on a black beadlock wheel, axle along local Y with the
## wheel face on +Y (or -Y when `mirror`). Vertex colour: r lug, g wheel, b hole.
static func build_wheel_mesh(r: float, w: float, mirror: bool) -> SurfaceTool:
	var st := MeshKit.begin()
	var xf := Transform3D(Basis.from_scale(Vector3(1, -1 if mirror else 1, 1)), Vector3.ZERO)
	var hw := w * 0.5
	var carcass := r - 0.026
	var rim_r := 0.216  # 17" wheel
	var rubber := Color(0, 0, 0)
	var lug_c := Color(1, 0, 0)
	var steel := Color(0, 1, 0)
	var hole := Color(0, 1, 1)
	# carcass: sidewalls bulge a touch past the tread
	MeshKit.lathe(st, [
		Vector2(rim_r + 0.01, -hw + 0.02), Vector2(rim_r + 0.06, -hw - 0.004),
		Vector2(carcass - 0.07, -hw - 0.014), Vector2(carcass - 0.02, -hw + 0.004),
		Vector2(carcass, -hw + 0.04), Vector2(carcass, hw - 0.04),
		Vector2(carcass - 0.02, hw - 0.004), Vector2(carcass - 0.07, hw + 0.014),
		Vector2(rim_r + 0.06, hw + 0.004), Vector2(rim_r + 0.01, hw - 0.02),
	], xf, rubber, 40)
	# tread: two staggered rows of chevron lugs plus shoulder blocks
	var count := 22
	for row: float in [-1.0, 1.0]:
		for k in range(count):
			var f := TAU * (k + (0.5 if row > 0.0 else 0.0)) / count
			var radial := Vector3(cos(f), 0, sin(f))
			var tangent := Vector3(-sin(f), 0, cos(f))
			var b := Basis(tangent, Vector3.UP, radial)
			var tread := Transform3D(b * Basis(Vector3.BACK, 0.28 * row), radial * (carcass + 0.008) + Vector3.UP * row * hw * 0.42)
			MeshKit.rounded_box(st, Vector3(0.075, hw * 0.75, 0.036), 0.008, xf * tread, lug_c, 1)
			var shoulder := Transform3D(b * Basis(Vector3.RIGHT, -0.75 * row), radial * (carcass - 0.012) + Vector3.UP * row * (hw - 0.012))
			MeshKit.rounded_box(st, Vector3(0.068, 0.06, 0.05), 0.01, xf * shoulder, lug_c, 1)
	# wheel barrel (seen past the face) and dished face with holes
	MeshKit.lathe(st, [Vector2(rim_r - 0.01, hw - 0.03), Vector2(rim_r - 0.01, -hw + 0.03)], xf, steel, 24)
	MeshKit.lathe(st, [
		Vector2(rim_r - 0.004, hw - 0.012), Vector2(0.15, hw - 0.055),
		Vector2(0.085, hw - 0.055), Vector2(0.08, hw - 0.03), Vector2(0.0, hw - 0.03),
	], xf, steel, 32)
	for k in range(8):
		var f := TAU * k / 8.0
		var at := Vector3(cos(f) * 0.118, hw - 0.05, sin(f) * 0.118)
		MeshKit.cylinder(st, 0.024, 0.012, xf * Transform3D(Basis.IDENTITY, at), hole, 10)
	# beadlock ring with its bolts
	MeshKit.lathe(st, [
		Vector2(rim_r - 0.014, hw - 0.024), Vector2(rim_r + 0.026, hw - 0.024),
		Vector2(rim_r + 0.026, hw + 0.004), Vector2(rim_r - 0.014, hw + 0.004),
		Vector2(rim_r - 0.014, hw - 0.024),
	], xf, steel, 40)
	for k in range(16):
		var f := TAU * k / 16.0
		MeshKit.cylinder(st, 0.007, 0.014, xf * Transform3D(Basis.IDENTITY, Vector3(cos(f) * (rim_r + 0.006), hw + 0.009, sin(f) * (rim_r + 0.006))), steel, 6)
	# hub and lug nuts
	MeshKit.cylinder(st, 0.06, 0.05, xf * Transform3D(Basis.IDENTITY, Vector3(0, hw - 0.02, 0)), steel, 16)
	for k in range(6):
		var f := TAU * k / 6.0
		MeshKit.cylinder(st, 0.011, 0.03, xf * Transform3D(Basis.IDENTITY, Vector3(cos(f) * 0.072, hw - 0.025, sin(f) * 0.072)), steel, 6)
	return st


func _build_particles() -> void:
	# Mud: lots of small wet clods that shrink as they fly (they break up).
	spray = GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0.8, 1)
	pm.spread = 24.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 9.0
	pm.gravity = Vector3(0, -9.8, 0)
	pm.scale_min = 0.025
	pm.scale_max = 0.09
	pm.scale_curve = _shrink_curve()
	pm.angular_velocity_min = -400.0
	pm.angular_velocity_max = 400.0
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(width * 0.5, 0.05, 0.1)
	spray.process_material = pm
	spray.amount = 260
	spray.lifetime = 1.2
	spray.emitting = false
	spray.local_coords = false
	var sm := SphereMesh.new()  # unit size: scale is the clod diameter
	sm.radius = 0.5
	sm.height = 0.7
	sm.radial_segments = 6
	sm.rings = 3
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.4, 0.17, 0.07)
	smat.roughness = 0.45
	smat.metallic_specular = 0.35
	sm.material = smat
	spray.draw_pass_1 = sm
	add_child(spray)

	# Water: fine droplets plus a soft mist that hangs and spreads.
	splash = GPUParticles3D.new()
	var wm := pm.duplicate() as ParticleProcessMaterial
	wm.direction = Vector3(0, 1, 0.6)
	wm.initial_velocity_min = 3.0
	wm.initial_velocity_max = 8.0
	wm.spread = 50.0
	wm.scale_min = 0.01
	wm.scale_max = 0.035
	splash.process_material = wm
	splash.amount = 220
	splash.lifetime = 0.9
	splash.emitting = false
	splash.local_coords = false
	var wmesh := SphereMesh.new()
	wmesh.radius = 0.5
	wmesh.height = 1.0
	wmesh.radial_segments = 6
	wmesh.rings = 3
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.62, 0.58, 0.48, 0.6)
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.roughness = 0.05
	wmat.metallic_specular = 0.8
	wmesh.material = wmat
	splash.draw_pass_1 = wmesh
	add_child(splash)

	mist = GPUParticles3D.new()
	var mm := ParticleProcessMaterial.new()
	mm.direction = Vector3(0, 1, 0.4)
	mm.spread = 60.0
	mm.initial_velocity_min = 0.8
	mm.initial_velocity_max = 2.5
	mm.gravity = Vector3(0, -0.6, 0)
	mm.damping_min = 1.0
	mm.damping_max = 2.0
	mm.scale_min = 0.5
	mm.scale_max = 1.1
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 1.6))
	var gt := CurveTexture.new()
	gt.curve = grow
	mm.scale_curve = gt
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.5))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	var ft := GradientTexture1D.new()
	ft.gradient = fade
	mm.color_ramp = ft
	mist.process_material = mm
	mist.amount = 40
	mist.lifetime = 1.4
	mist.emitting = false
	mist.local_coords = false
	var quad := QuadMesh.new()
	var qmat := StandardMaterial3D.new()
	qmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qmat.vertex_color_use_as_albedo = true
	qmat.albedo_color = Color(0.85, 0.85, 0.8)
	var puff := GradientTexture2D.new()
	puff.fill = GradientTexture2D.FILL_RADIAL
	puff.fill_from = Vector2(0.5, 0.5)
	puff.fill_to = Vector2(1.0, 0.5)
	var pg := Gradient.new()
	pg.set_color(0, Color(1, 1, 1, 1))
	pg.set_color(1, Color(1, 1, 1, 0))
	puff.gradient = pg
	qmat.albedo_texture = puff
	quad.material = qmat
	mist.draw_pass_1 = quad
	add_child(mist)


static func _shrink_curve() -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0.35))
	var t := CurveTexture.new()
	t.curve = c
	return t


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
		mist.emitting = false
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
		mist.emitting = false
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
	# Clay comes off the top-back of the tire, the way it's turning; wheelspin
	# throws a rooster tail, rolling through just flicks lumps.
	var surf_speed := absf(omega) * radius
	var throw_dir := signf(omega) if absf(omega) > 0.5 else 1.0
	spray.position = Vector3(0, -(contact_dist - radius) + radius * 0.1, throw_dir * radius * 0.75)
	var spm := spray.process_material as ParticleProcessMaterial
	spm.direction = Vector3(0, 0.7, throw_dir)
	spm.initial_velocity_max = clampf(surf_speed * 0.9, 4.0, 14.0)
	spray.amount_ratio = clampf(0.15 + slip * 1.2 + surf_speed * 0.04, 0.0, 1.0)
	spray.emitting = soft > 0.3 and (slip > 0.2 or surf_speed > 2.5)
	splash.global_position = contact_point
	splash.emitting = water > 0.1 and planar.length() > 1.5
	mist.global_position = contact_point + Vector3.UP * 0.3
	mist.emitting = splash.emitting and planar.length() > 2.5

	# tread packs fast in the slop, flings clean slowly on firm ground
	if soft > 0.3:
		tire_mud = move_toward(tire_mud, 1.0, delta * soft * (0.4 + 1.5 * slip))
	else:
		tire_mud = move_toward(tire_mud, 0.2 * tire_mud, delta * 0.01 * surf_speed)
	if water > 0.15:
		tire_mud = move_toward(tire_mud, 0.0, delta * 0.15 * planar.length())
	tire_mat.set_shader_parameter("tire_mud", tire_mud)

	_update_mesh(contact_dist, delta)
	return result


var _spin := 0.0
var hub_offset := Vector3.ZERO  # where the hub sits below this node (for axles)


func _update_mesh(contact_dist: float, delta: float) -> void:
	_spin -= omega * delta
	# cylinder axis is Y: rotate it onto X (the axle), spin about X, then yaw for steering
	var b := Basis.from_euler(Vector3(0, steer_angle, 0)) * Basis(Vector3.RIGHT, _spin) * Basis(Vector3.BACK, PI / 2.0)
	hub_offset = Vector3(0, -(contact_dist - radius), 0)
	mesh.transform = Transform3D(b, Vector3(0, -(contact_dist - radius), 0))
