class_name Driver
extends Node3D
## The driver, modelled in code: a typical trail guy in a motocross helmet,
## a t-shirt with the sleeves cut off, jorts and tsinelas, hands on the wheel.
##
## He moves the way a body in a bucking rig does. What he feels is the rig's
## acceleration (plus gravity) in the rig's frame; his torso is a damped
## spring pivoting at the hips, thrown outward in corners, forward under
## braking, bounced by every rut. The head is a second, quicker spring on
## top that lags the torso and tries to keep the eyes level. Arms reach the
## wheel by two-bone IK, so they follow the torso and the steering.
##
## Lives in rig space; the rig adds it and the turning steering wheel.

const SKIN := Color(0.56, 0.37, 0.25)       # morena
const SKIN_DK := Color(0.46, 0.29, 0.19)
const SHIRT := Color(0.52, 0.13, 0.12)      # faded maroon band tee, sleeves cut off
const DENIM := Color(0.27, 0.36, 0.52)
const FRAY := Color(0.62, 0.66, 0.72)
const HELMET := Color(0.92, 0.92, 0.9)
const STRIPE_R := Color(0.8, 0.1, 0.1)
const STRIPE_B := Color(0.1, 0.22, 0.6)
const VISOR := Color(0.06, 0.06, 0.07)
const LENS := Color(0.9, 0.45, 0.1)
const SLIPPER := Color(0.15, 0.3, 0.65)      # rubber tsinelas, blue on white
const SOLE := Color(0.92, 0.92, 0.9)

const HIP := Vector3(-0.33, 0.8, 0.27)       # pivot on the driver's seat
const WHEEL_AT := Vector3(-0.33, 1.2, -0.1)
const WHEEL_TILT := 1.15
const WHEEL_R := 0.19
const STEER_RATIO := 3.0                     # steering wheel turns per road wheel turn (visual)
const UPPER_ARM := 0.3
const FOREARM := 0.29

var rig: RigidBody3D
var steering_wheel: Node3D
var _mat: StandardMaterial3D
var _torso: Node3D
var _head: Node3D
var _arms: Array = []   # per side: [upper arm, forearm, hand, elbow] MeshInstance3Ds

# body dynamics: angles (rad) and their rates, about the rig's X (pitch) and Z (roll)
var _t_ang := Vector2.ZERO
var _t_vel := Vector2.ZERO
var _h_ang := Vector2.ZERO
var _h_vel := Vector2.ZERO
var _bob := 0.0
var _bob_vel := 0.0
var _last_v := Vector3.ZERO
var _felt := Vector3(0, 9.8, 0)


func build(r: RigidBody3D) -> void:
	rig = r
	_mat = StandardMaterial3D.new()
	_mat.vertex_color_use_as_albedo = true
	_mat.vertex_color_is_srgb = true
	_mat.roughness = 0.75
	_build_steering_wheel()
	_build_legs()
	_torso = Node3D.new()
	_torso.position = HIP
	add_child(_torso)
	_build_torso()
	_head = Node3D.new()
	_head.position = Vector3(0, 0.68, 0.04)
	_torso.add_child(_head)
	_build_helmet()
	for side: float in [-1.0, 1.0]:
		var parts := []
		for k in range(2):
			var mi := MeshInstance3D.new()
			mi.mesh = _limb_mesh(0.052 if k == 0 else 0.042, 0.042 if k == 0 else 0.034, SKIN)
			add_child(mi)
			parts.append(mi)
		var hand := MeshInstance3D.new()
		var st := MeshKit.begin()
		MeshKit.rounded_box(st, Vector3(0.08, 0.05, 0.1), 0.022, Transform3D.IDENTITY, SKIN, 2)
		hand.mesh = MeshKit.commit(st, _mat)
		add_child(hand)
		parts.append(hand)
		var elbow := MeshInstance3D.new()
		var es := MeshKit.begin()
		MeshKit.sphere(es, 0.045, Transform3D.IDENTITY, SKIN, 10)
		elbow.mesh = MeshKit.commit(es, _mat)
		add_child(elbow)
		parts.append(elbow)
		_arms.append(parts)
	_last_v = rig.linear_velocity


# --- modelling ---------------------------------------------------------------------

## A tapered limb one metre long up +Y; stretched to length when placed.
func _limb_mesh(r0: float, r1: float, col: Color) -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.sweep(st, PackedVector3Array([Vector3.ZERO, Vector3(0, 0.5, 0), Vector3(0, 1, 0)]),
		PackedFloat32Array([r0, lerpf(r0, r1, 0.4), r1]), Transform3D.IDENTITY, col, 10)
	MeshKit.sphere(st, r0 * 1.02, Transform3D.IDENTITY, col, 10)
	return MeshKit.commit(st, _mat)


func _part(st: SurfaceTool, parent: Node3D, name_: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name_
	mi.mesh = MeshKit.commit(st, _mat)
	parent.add_child(mi)
	return mi


func _build_steering_wheel() -> void:
	steering_wheel = Node3D.new()
	steering_wheel.transform = Transform3D(Basis(Vector3.RIGHT, WHEEL_TILT), WHEEL_AT)
	add_child(steering_wheel)
	var st := MeshKit.begin()
	var c := Color(0.05, 0.05, 0.05)
	MeshKit.torus(st, WHEEL_R, 0.017, Transform3D.IDENTITY, c, 28, 8)
	for k in range(3):
		var f := TAU * k / 3.0 + PI * 0.5
		MeshKit.tube(st, Vector3.ZERO, Vector3(cos(f), 0, sin(f)) * 0.18, 0.012, Transform3D.IDENTITY, c, 6)
	MeshKit.cylinder(st, 0.035, 0.03, Transform3D.IDENTITY, Color(0.12, 0.12, 0.12), 12)
	_part(st, steering_wheel, "SteeringWheel")


func _build_legs() -> void:
	# seated: thighs forward and a little up off the seat, shins down to the pedals
	var st := MeshKit.begin()
	MeshKit.rounded_box(st, Vector3(0.36, 0.16, 0.3), 0.07, Transform3D(Basis.IDENTITY, HIP + Vector3(0, -0.01, 0.0)), DENIM, 3)
	for sx: float in [-1.0, 1.0]:
		var hip := HIP + Vector3(sx * 0.1, 0.0, -0.04)
		# a Willys footwell is short and high: knees up, feet flat on the floor
		# just behind the firewall (z -0.33)
		var knee := HIP + Vector3(sx * 0.14, 0.2, -0.38)
		var ankle := HIP + Vector3(sx * 0.15, -0.1, -0.43)
		# jorts: denim to just above the knee, frayed cuff
		var cuff := hip.lerp(knee, 0.82)
		MeshKit.sweep(st, PackedVector3Array([hip, hip.lerp(cuff, 0.5), cuff]), PackedFloat32Array([0.095, 0.088, 0.083]), Transform3D.IDENTITY, DENIM, 12)
		MeshKit.tube(st, cuff, cuff + (knee - hip).normalized() * 0.018, 0.086, Transform3D.IDENTITY, FRAY, 12)
		MeshKit.sweep(st, PackedVector3Array([cuff, knee]), PackedFloat32Array([0.068, 0.06]), Transform3D.IDENTITY, SKIN, 10)
		MeshKit.sphere(st, 0.058, Transform3D(Basis.IDENTITY, knee), SKIN, 10)
		MeshKit.sweep(st, PackedVector3Array([knee, knee.lerp(ankle, 0.35), ankle]), PackedFloat32Array([0.056, 0.05, 0.036]), Transform3D.IDENTITY, SKIN, 10)
		# bare foot on a tsinelas: thin white-and-blue sole, a Y strap between the toes
		var foot := Transform3D(Basis(Vector3.RIGHT, -0.15), ankle + Vector3(0, -0.04, -0.07))
		MeshKit.rounded_box(st, Vector3(0.09, 0.05, 0.22), 0.022, foot, SKIN, 2)
		MeshKit.rounded_box(st, Vector3(0.1, 0.018, 0.25), 0.007, foot * Transform3D(Basis.IDENTITY, Vector3(0, -0.033, 0.0)), SOLE, 2)
		MeshKit.rounded_box(st, Vector3(0.102, 0.008, 0.252), 0.003, foot * Transform3D(Basis.IDENTITY, Vector3(0, -0.02, 0.0)), SLIPPER, 2)
		var toe := foot * Vector3(0, 0.0, -0.07)
		for s2: float in [-1.0, 1.0]:
			MeshKit.tube(st, toe + foot.basis * Vector3(0, 0.02, 0), foot * Vector3(s2 * 0.048, -0.02, 0.03), 0.008, Transform3D.IDENTITY, SLIPPER, 5)
	_part(st, self, "Legs")


func _build_torso() -> void:
	# torso local: origin at the hips, leaning back into the seat a touch
	var st := MeshKit.begin()
	var lean := Basis(Vector3.RIGHT, 0.12)
	var chest := Transform3D(lean, lean * Vector3(0, 0.36, 0.02))
	MeshKit.rounded_box(st, Vector3(0.4, 0.46, 0.23), 0.09, chest, SHIRT, 3)
	MeshKit.rounded_box(st, Vector3(0.34, 0.16, 0.22), 0.07, Transform3D(lean, lean * Vector3(0, 0.1, -0.005)), SHIRT, 3)
	# the cut armholes: bare shoulders and a strip of side showing
	for sx: float in [-1.0, 1.0]:
		var sh := lean * Vector3(sx * 0.21, 0.55, 0.03)
		MeshKit.sphere(st, 0.06, Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 0.85, 1.0)), sh), SKIN, 12)
		MeshKit.rounded_box(st, Vector3(0.02, 0.13, 0.11), 0.009, Transform3D(lean, lean * Vector3(sx * 0.201, 0.43, 0.02)), SKIN_DK, 2)
	# neck
	MeshKit.cylinder(st, 0.055, 0.14, Transform3D(lean, lean * Vector3(0, 0.63, 0.03)), SKIN, 12)
	_part(st, _torso, "Torso")


func _build_helmet() -> void:
	# head local: origin at the top of the neck. One shaped shell: the chin
	# bar sweeps forward and down to a point, a wide eye port is set into it
	# for the goggles, a brow ridge over that, and a long pointed peak.
	var st := MeshKit.begin()
	_face(st)
	_helmet_shell(st)
	_goggles(st)
	_helmet_peak(st)
	var helmet := _part(st, _head, "Helmet")
	helmet.layers = 2  # hidden from the driver's-seat camera, which sits inside it


## His face, inside the helmet: what shows through the eye port round the
## goggles. Cheeks, a nose, a bit of chin above the chin bar.
func _face(st: SurfaceTool) -> void:
	MeshKit.sphere(st, 1.0, Transform3D(Basis.IDENTITY.scaled(Vector3(0.1, 0.125, 0.128)), Vector3(0, 0.1, -0.012)), SKIN, 18)
	for sx: float in [-1.0, 1.0]:
		MeshKit.sphere(st, 0.034, Transform3D(Basis.IDENTITY, Vector3(sx * 0.045, 0.085, -0.115)), SKIN, 10)  # cheeks
	MeshKit.sweep(st, PackedVector3Array([Vector3(0, 0.125, -0.128), Vector3(0, 0.098, -0.148)]), PackedFloat32Array([0.012, 0.017]), Transform3D.IDENTITY, SKIN, 8)  # nose
	MeshKit.rounded_box(st, Vector3(0.05, 0.008, 0.02), 0.004, Transform3D(Basis.IDENTITY, Vector3(0, 0.072, -0.128)), SKIN_DK, 2)  # mouth line


func _helmet_shell(st: SurfaceTool) -> void:
	var rings := 40
	var segs := 72
	var centre := Vector3(0, 0.11, 0)
	var grid: Array[Vector3] = []
	var cols: Array[Color] = []
	var open: Array[bool] = []   # inside the eye port: no shell there
	for ri in range(rings + 1):
		var lat := lerpf(deg_to_rad(-60.0), PI * 0.5, float(ri) / rings)
		for si in range(segs):
			var lon := TAU * si / segs
			# lon 0 faces forward (-Z)
			var d := Vector3(cos(lat) * sin(lon), sin(lat), -cos(lat) * cos(lon))
			var p := d * Vector3(0.135, 0.15, 0.168)
			var front := smoothstep(0.2, 0.95, -d.z)
			var below := 1.0 - smoothstep(-0.42, -0.2, d.y)
			var jaw := front * below
			# chin bar: a wide jaw that drops down and forward, the further down the
			# further out (an angled front, not a bill), pinched only at the very tip
			var down := smoothstep(-0.18, -0.8, d.y)
			p.z -= 0.13 * front * down * (0.6 + 0.4 * down)
			p.y -= 0.05 * front * down
			p.x *= 1.0 - 0.18 * jaw * smoothstep(0.8, 1.0, -d.z)
			# eye port: a wide opening set back into the shell
			# eye port: a big opening onto his face, rounded off at the corners
			var port := smoothstep(0.45, 0.62, -d.z) * smoothstep(-0.48, -0.38, d.y) * (1.0 - smoothstep(0.3, 0.38, d.y))
			p -= d * 0.012 * port
			open.append(port > 0.55)
			# brow ridge over the port
			p += d * 0.012 * smoothstep(0.45, 0.75, -d.z) * smoothstep(0.32, 0.4, d.y) * (1.0 - smoothstep(0.45, 0.6, d.y))
			# the lower back flares out a little over the neck
			p += Vector3(d.x, 0.0, maxf(d.z, 0.0)) * 0.03 * (1.0 - smoothstep(-0.85, -0.45, d.y)) * smoothstep(-0.2, 0.4, d.z)
			grid.append(centre + p)
			var c := HELMET
			if d.y > 0.18 and d.z > -0.92:
				if d.x > -0.13 and d.x < -0.03:
					c = STRIPE_R
				elif d.x > 0.03 and d.x < 0.13:
					c = STRIPE_B
			if jaw > 0.5:
				c = STRIPE_B
			if front > 0.85 and d.y < -0.55 and d.y > -0.8 and absf(d.x) < 0.12:
				c = VISOR  # mouth vent on the front of the chin bar
			if port > 0.25:
				c = VISOR  # rubber trim round the opening
			cols.append(c)
	var normals: Array[Vector3] = []
	for ri in range(rings + 1):
		for si in range(segs):
			var p := grid[ri * segs + si]
			var n := (p - centre).normalized()
			if ri > 0 and ri < rings:
				var e := grid[ri * segs + (si + 1) % segs] - grid[ri * segs + (si + segs - 1) % segs]
				var u := grid[(ri + 1) * segs + si] - grid[(ri - 1) * segs + si]
				var cr := e.cross(u)
				if cr.length_squared() > 1e-10:
					n = cr.normalized() * signf(cr.dot(p - centre))
			normals.append(n)
	for ri in range(rings):
		for si in range(segs):
			var ids: Array[int] = [ri * segs + si, ri * segs + (si + 1) % segs,
				(ri + 1) * segs + (si + 1) % segs, (ri + 1) * segs + si]
			var q: Array[Vector3] = []
			var qn: Array[Vector3] = []
			for i in ids:
				q.append(grid[i])
				qn.append(normals[i])
			if open[ids[0]] and open[ids[1]] and open[ids[2]] and open[ids[3]]:
				continue
			MeshKit._quad(st, Transform3D.IDENTITY, q, qn, cols[ids[0]])


## Motocross goggles: a thick foam-backed frame curving round the eye port,
## a wraparound tinted lens, and a wide strap round the back of the helmet.
func _goggles(st: SurfaceTool) -> void:
	var y := 0.138
	var r := 0.162
	var n := 14
	var frame := PackedVector3Array()
	var lens_top := PackedVector3Array()
	var lens_bot := PackedVector3Array()
	for i in range(n + 1):
		var a := lerpf(-0.78, 0.78, float(i) / n)
		# the lens dips in the middle over the nose
		var dip := 0.012 * (1.0 - smoothstep(0.0, 0.25, absf(a)))
		frame.append(Vector3(sin(a) * r, y, -cos(a) * r))
		lens_top.append(Vector3(sin(a) * (r + 0.038), y + 0.03, -cos(a) * (r + 0.038)))
		lens_bot.append(Vector3(sin(a) * (r + 0.038), y - 0.032 + dip, -cos(a) * (r + 0.038)))
	# frame: top and bottom rims, ends, all chunky black
	for k in range(2):
		var rim := PackedVector3Array()
		var rr := PackedFloat32Array()
		for i in range(n + 1):
			var p := lens_top[i] if k == 0 else lens_bot[i]
			rim.append(p + (Vector3(0, 0.006, 0) if k == 0 else Vector3(0, -0.006, 0)))
			rr.append(0.011)
		MeshKit.sweep(st, rim, rr, Transform3D.IDENTITY, VISOR, 6)
	for e: int in [0, n]:
		MeshKit.tube(st, lens_top[e] + Vector3(0, 0.006, 0), lens_bot[e] - Vector3(0, 0.006, 0), 0.013, Transform3D.IDENTITY, VISOR, 6)
	# foam body behind the lens, filling the eye port
	var foam := PackedFloat32Array()
	for i in range(n + 1):
		foam.append(0.034)
	MeshKit.sweep(st, frame, foam, Transform3D.IDENTITY, VISOR, 8)
	# the lens: a curved orange mirror strip, both faces
	for i in range(n):
		var q: Array[Vector3] = [lens_bot[i], lens_bot[i + 1], lens_top[i + 1], lens_top[i]]
		var out := ((q[0] + q[1] + q[2] + q[3]) * 0.25 - Vector3(0, y, 0)).normalized()
		MeshKit._quad(st, Transform3D.IDENTITY, q, [out, out, out, out], LENS)
	# strap: a wide band from the frame ends round the back of the shell
	var band := 0.036
	var m := 24
	for i in range(m):
		var a0 := lerpf(0.75, TAU - 0.75, float(i) / m)
		var a1 := lerpf(0.75, TAU - 0.75, float(i + 1) / m)
		var p0 := Vector3(sin(a0) * 0.145, y, -cos(a0) * 0.176)
		var p1 := Vector3(sin(a1) * 0.145, y, -cos(a1) * 0.176)
		var o0 := Vector3(p0.x, 0.0, p0.z).normalized()
		var o1 := Vector3(p1.x, 0.0, p1.z).normalized()
		var h := Vector3(0, band * 0.5, 0)
		var col := HELMET if i >= m / 2 - 3 and i <= m / 2 + 2 else VISOR  # the brand name across the back
		MeshKit._quad(st, Transform3D.IDENTITY, [p0 - h, p1 - h, p1 + h, p0 + h], [o0, o1, o1, o0], col)


func _helmet_peak(st: SurfaceTool) -> void:
	# a flat, pointed visor off the forehead, tipped up at the front
	var xf := Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0, 0.2, -0.08))
	var outline: Array[Vector3] = [Vector3(-0.15, 0, 0.06), Vector3(-0.125, 0, -0.16), Vector3(0, 0, -0.24),
		Vector3(0.125, 0, -0.16), Vector3(0.15, 0, 0.06)]
	var mid := Vector3(0, 0, -0.08)
	for side: float in [1.0, -1.0]:
		var n := Vector3.UP * side
		var off := Vector3(0, 0.008 * side, 0)
		for i in range(outline.size() - 1):
			MeshKit._tri(st, xf, [mid + off, outline[i] + off, outline[i + 1] + off], [n, n, n], STRIPE_R)
		MeshKit._tri(st, xf, [mid + off, outline[outline.size() - 1] + off, outline[0] + off], [n, n, n], STRIPE_R)
	# a rolled edge so it reads as one thick moulding, not two sheets
	var edge := PackedVector3Array(outline)
	var er := PackedFloat32Array()
	for i in range(edge.size()):
		er.append(0.008)
	MeshKit.sweep(st, edge, er, xf, STRIPE_R, 6)
	# a white stripe down its middle
	for i in range(2):
		var x := (i - 0.5) * 0.03
		MeshKit._quad(st, xf, [Vector3(x - 0.008, 0.0092, 0.04), Vector3(x + 0.008, 0.0092, 0.04), Vector3(x + 0.008, 0.0092, -0.19), Vector3(x - 0.008, 0.0092, -0.19)],
			[Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP], HELMET)


# --- motion ------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if rig == null or delta <= 0.0:
		return
	# what the body feels, in the rig's frame: acceleration minus gravity
	var accel := (rig.linear_velocity - _last_v) / delta
	_last_v = rig.linear_velocity
	var felt_world := accel + Vector3(0, 9.8, 0)
	var felt := rig.global_transform.basis.inverse() * felt_world
	# a crash-landing spike shouldn't fling him through the windscreen
	_felt = _felt.lerp(felt.limit_length(40.0), 1.0 - exp(-delta * 40.0))
	var f := _felt / 9.8

	# torso: thrown away from where the rig is accelerating, braced back to the seat
	var t_target := Vector2(
		clampf(-0.32 * f.z, -0.35, 0.06),     # pitch: braking (f.z > 0) folds him forward
		clampf(0.4 * f.x, -0.4, 0.4))          # roll: corners throw him to the outside
	_spring(t_target, 22.0, 0.32, delta, true)
	# head: quicker, lags the torso, and keeps the eyes roughly level
	var roll := rig.global_transform.basis.get_euler().z
	var h_target := Vector2(-_t_ang.x * 0.5 - 0.15 * f.z, -_t_ang.y * 0.6 - roll * 0.35)
	h_target -= Vector2(_t_vel.x, _t_vel.y) * 0.025
	_spring(h_target, 30.0, 0.28, delta, false)
	# bounce: sinks into the seat when the rig lands, floats when it drops away
	var bob_target := clampf(-(f.y - 1.0) * 0.03, -0.06, 0.05)
	_bob_vel += ((bob_target - _bob) * 900.0 - _bob_vel * 24.0) * delta
	_bob += _bob_vel * delta

	_torso.transform = Transform3D(Basis.from_euler(Vector3(_t_ang.x, 0, _t_ang.y)), HIP + Vector3(0, _bob, 0))
	_head.transform = Transform3D(Basis.from_euler(Vector3(_h_ang.x, 0, _h_ang.y)), Vector3(0, 0.68, 0.04))
	_place_steering()
	_place_arms()


## Damped spring toward `target`; natural frequency `w` (rad/s), damping ratio `z`.
func _spring(target: Vector2, w: float, z: float, delta: float, torso: bool) -> void:
	var ang := _t_ang if torso else _h_ang
	var vel := _t_vel if torso else _h_vel
	vel += ((target - ang) * w * w - vel * 2.0 * z * w) * delta
	ang += vel * delta
	if torso:
		_t_ang = ang
		_t_vel = vel
	else:
		_h_ang = ang
		_h_vel = vel


func _place_steering() -> void:
	var steer: float = rig.get("steer")
	steering_wheel.transform = Transform3D(Basis(Vector3.RIGHT, WHEEL_TILT) * Basis(Vector3.UP, steer * STEER_RATIO), WHEEL_AT)


func _place_arms() -> void:
	var sides: Array[float] = [-1.0, 1.0]
	for i in range(2):
		var sx := sides[i]
		var shoulder: Vector3 = _torso.transform * (Basis(Vector3.RIGHT, 0.12) * Vector3(sx * 0.21, 0.54, 0.03))
		# hands at ten and two on the rim, turning with the wheel
		var grip := Vector3(sx * WHEEL_R * 0.87, 0.0, -WHEEL_R * 0.5)
		var hand: Vector3 = steering_wheel.transform * grip
		var to := hand - shoulder
		var d := clampf(to.length(), 0.05, UPPER_ARM + FOREARM - 0.005)
		var dir := to.normalized()
		# elbows hang out and down
		var pole := Vector3(sx * 0.8, -1.0, 0.2)
		pole = (pole - dir * pole.dot(dir)).normalized()
		var a := (UPPER_ARM * UPPER_ARM - FOREARM * FOREARM + d * d) / (2.0 * d)
		var h := sqrt(maxf(UPPER_ARM * UPPER_ARM - a * a, 0.0))
		var elbow := shoulder + dir * a + pole * h
		var hand_at := shoulder + dir * d
		var parts: Array = _arms[i]
		_limb(parts[0], shoulder, elbow)
		_limb(parts[1], elbow, hand_at)
		(parts[3] as MeshInstance3D).position = elbow
		(parts[2] as MeshInstance3D).transform = Transform3D(steering_wheel.transform.basis * Basis(Vector3.UP, sx * 0.4), hand_at)


func _limb(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var v := b - a
	mi.transform = Transform3D(MeshKit.y_to(v.normalized()) * Basis.from_scale(Vector3(1.0, v.length(), 1.0)), a)
