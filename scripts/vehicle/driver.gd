class_name Driver
extends Node3D
## The driver, modelled in code: a typical trail guy in a full-face helmet,
## a t-shirt with the sleeves cut off, jorts and tsinelas, hands on the wheel.
##
## His torso and head are real physics bodies. The torso (40 kg) hangs on a
## joint at the hips with a little seat-cushion travel; the head (5 kg) on a
## joint at the neck. The engine throws them about with whatever the rig does:
## lurches, ruts, landings, rollovers. His muscles are only torques that hold
## him upright against that, well damped, the way a braced person rides; the
## head also tries to keep the eyes level. Arms reach by two-bone IK from
## wherever the torso has been thrown, legs from the seat to the pedals; each
## limb is one skin shoulder to wrist (hip to ankle), reshaped every frame.
##
## He drives it: the right foot goes from the throttle to the brake, the left
## works the clutch for a shift or a stop and rests on the dead pedal; the
## right hand leaves the wheel for the gear lever (through the H), the
## transfer-case lever and the handbrake, and the levers move with it.
## Proportions are a man about 1.7 m tall.
##
## Lives in rig space; the rig adds it and the turning steering wheel.

const SKIN := Color(0.5, 0.355, 0.28)       # morena
const SKIN_DK := Color(0.405, 0.288, 0.227)
# clothes: picked in the start menu (Game.SHIRTS / Game.SHORTS); the trims follow
var SHIRT := Color(0.52, 0.13, 0.12)        # band tee, sleeves cut off
var SHIRT_EDGE := Color(0.62, 0.3, 0.27)    # frayed edge where the sleeves were cut
var COLLAR := Color(0.44, 0.11, 0.1)        # crew-neck rib
var DENIM := Color(0.27, 0.36, 0.52)
var FRAY := Color(0.42, 0.49, 0.6)          # frayed denim, paler threads
const HELMET := Color(0.92, 0.92, 0.9)
const STRIPE_R := Color(0.8, 0.1, 0.1)
const STRIPE_B := Color(0.1, 0.22, 0.6)
const VISOR := Color(0.06, 0.06, 0.07)
const LENS := Color(0.9, 0.45, 0.1)
const SLIPPER := Color(0.15, 0.3, 0.65)      # rubber tsinelas, blue on white
const SOLE := Color(0.92, 0.92, 0.9)
const PRINT_SIZE := 0.24                     # m across

# where he sits and where the wheel is: from the rig's RigSpec at build time
var HIP := Vector3(-0.33, 0.8, 0.27)         # pivot on the driver's seat
var WHEEL_AT := Vector3(-0.33, 1.2, -0.1)
const WHEEL_TILT := 1.15
const WHEEL_R := 0.19
const STEER_RATIO := 3.0                     # steering wheel turns per road wheel turn (visual)
const UPPER_ARM := 0.3                       # shoulder to elbow
const FOREARM := 0.27                        # elbow to wrist
const THIGH := 0.42                          # hip joint to knee
const SHIN := 0.4                            # knee to ankle
## The ball of the foot under the sole, in the foot's frame from the ankle
## (CabinKit.foot_on puts it on the pedal)
const BALL := Vector3(0, -0.095, -0.13)
const RIM_R := 0.017                         # the steering wheel rim's thickness (radius)
const HAND_TURN := 0.3                       # how far the backs of the hands turn toward him on the rim
const NAIL := Color(0.6, 0.45, 0.4)
const LOFT_SIDES := 16

var rig: RigidBody3D
var steering_wheel: Node3D
var _mat: ShaderMaterial
var _shirt_mat: ShaderMaterial   # _mat plus the chest print
var _torso: RigidBody3D
var _head: RigidBody3D
var _arm_mesh: Array[ArrayMesh] = []      # left, right: shoulder to wrist, rebuilt each step
var _hands: Array[MeshInstance3D] = []
var _hand_meshes := {}                     # how the hand is closed: wheel, gear, tc, hb, open
var _leg_mesh: Array[ArrayMesh] = []
var _feet: Array[MeshInstance3D] = []
var _index_cache := {}
var _cabin: CabinKit
# the feet: what each is on (left: rest/clutch, right: gas/brake), where it
# was when it left the last one, how far over it is (0..1)
var _foot_on: Array[String] = ["rest", "gas"]
var _foot_from: Array[Transform3D] = [Transform3D(), Transform3D()]
var _foot_t: Array[float] = [1.0, 1.0]
var _foot_xf: Array[Transform3D] = [Transform3D(), Transform3D()]
var _press := {"clutch": 0.0, "brake": 0.0, "gas": 0.0}
var _leg_key := PackedVector3Array()
# the right hand: where it is going (wheel, gear, tc, hb), from where, how far
var _hand := "wheel"
var _hand_from := Transform3D()
var _hand_t := 1.0
var _hand_xf := Transform3D()
var _hold := 0.0
var _lever := Vector2.ZERO       # the gear lever in the H as it stands
var _shown_gear := 1             # the gear the lever is in
var _tc_f := 0.0                 # transfer lever, 0 high .. 1 low
var _hb_f := 0.0                 # handbrake lever, 0 down .. 1 up

const NECK := Vector3(0, 0.68, 0.04)   # head pivot, in torso space
# muscles: stiffness (N m/rad) and damping (N m s/rad) holding each body up
const TORSO_K := 800.0     # ~2 Hz
const TORSO_C := 85.0      # damping ratio ~0.7: leans and settles, never rocks
const HEAD_K := 30.0
const HEAD_C := 2.2
const HEAD_LEVEL := 18.0                 # extra pull toward a level gaze
# seat cushion: the torso can sink and lift a few cm
const SEAT_K := 25000.0
const SEAT_C := 1000.0


func build(r: RigidBody3D) -> void:
	rig = r
	HIP = (r as Rig).spec.seat
	WHEEL_AT = (r as Rig).spec.wheel_at
	SHIRT = Game.shirt_color()
	SHIRT_EDGE = SHIRT.lerp(Color(0.85, 0.8, 0.74), 0.22)
	COLLAR = SHIRT.darkened(0.16)
	DENIM = Game.shorts_color()
	FRAY = DENIM.lerp(Color(0.86, 0.86, 0.84), 0.28)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/driver.gdshader")
	_mat.set_shader_parameter("shirt_col", Vector3(SHIRT.r, SHIRT.g, SHIRT.b))
	_build_steering_wheel()
	_cabin = r.get_node_or_null("Cabin") as CabinKit
	_build_legs()
	_torso = _body("Torso", 40.0, Vector3(0.4, 0.5, 0.24), Vector3(0, 0.3, 0.02))
	_build_torso()
	_head = _body("Head", 5.0, Vector3(0.28, 0.3, 0.32), Vector3(0, 0.11, 0.0))
	_build_helmet()
	snap()
	_joint(rig, _torso, HIP, 0.6, 0.25, 0.04)
	_joint(_torso, _head, HIP + NECK, 0.7, 0.6, 0.0)
	_hand_meshes = {"wheel": _hand_mesh(RIM_R), "gear": _hand_mesh(0.035), "tc": _hand_mesh(0.022),
		"hb": _hand_mesh(0.018), "open": _hand_mesh(0.075)}
	for i in range(2):
		var arm := MeshInstance3D.new()
		arm.name = "Arm" + str(i)
		arm.mesh = ArrayMesh.new()
		add_child(arm)
		_arm_mesh.append(arm.mesh)
		var hand := MeshInstance3D.new()
		hand.name = "Hand" + str(i)
		hand.mesh = _hand_meshes["wheel"]
		add_child(hand)
		_hands.append(hand)
	# the levers as they stand when he gets in
	var gb: Gearbox = (r as Rig).gearbox
	_shown_gear = gb.gear
	_lever = CabinKit.gate(gb.gear, gb.gears.size())
	_tc_f = 1.0 if (r as Rig).low_range else 0.0
	_hand_xf = steering_wheel.transform * _wheel_grip()
	_work_controls(0.0)


# --- modelling ---------------------------------------------------------------------

## Limb cross-sections, shoulder (or elbow) at t = 0 to elbow (or wrist) at
## t = 1: [t, half-width, half-depth]. Depth is front-back with the arm hanging.
const UPPER_ARM_PROFILE := [
	[0.0, 0.056, 0.058], [0.1, 0.057, 0.056], [0.22, 0.05, 0.05],   # deltoid
	[0.42, 0.044, 0.049], [0.6, 0.042, 0.046],                      # biceps
	[0.82, 0.037, 0.039], [1.0, 0.034, 0.036]]
const FOREARM_PROFILE := [
	[0.0, 0.035, 0.036], [0.12, 0.04, 0.037], [0.3, 0.041, 0.035],  # meaty below the elbow
	[0.6, 0.033, 0.027], [0.86, 0.026, 0.019], [1.0, 0.023, 0.017]]  # flat wrist

## Profile lookup: [half-width, half-depth] at `t` (0..1) along a limb.
static func _prof(prof: Array, t: float) -> Vector2:
	t = clampf(t, 0.0, 1.0)
	var k := 0
	while k < prof.size() - 2 and t > float(prof[k + 1][0]):
		k += 1
	var a: Array = prof[k]
	var b: Array = prof[k + 1]
	var f := smoothstep(float(a[0]), float(b[0]), t)
	return Vector2(lerpf(a[1], b[1], f), lerpf(a[2], b[2], f))


## One limb as a single skin along `pts` (driver space), rebuilt as it moves:
## an elliptic ring round each point, `rx` across and `rz` along the depth
## axis, which starts as `depth` and is carried round the bends without
## twisting (from ring `twist_from` on it turns to end up along `twist`, if
## given: the forearm turning to the hand); rounded ends. The shader gets a
## fixed place on the limb for each vertex (UV, UV2) so the mud stays put on
## the skin as the limb moves.
func _loft(mesh: ArrayMesh, pts: PackedVector3Array, rx: PackedFloat32Array, rz: PackedFloat32Array,
		cols: PackedColorArray, depth: Vector3, twist := Vector3.ZERO, twist_from := 0, rest := 0.0) -> void:
	var n := pts.size()
	var segs := LOFT_SIDES
	var count := n * segs + 2
	var verts := PackedVector3Array()
	verts.resize(count)
	var norms := PackedVector3Array()
	norms.resize(count)
	var colors := PackedColorArray()
	colors.resize(count)
	var uv := PackedVector2Array()
	uv.resize(count)
	var uv2 := PackedVector2Array()
	uv2.resize(count)
	var tans: Array[Vector3] = []
	for i in range(n):
		var t := pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		if t.length_squared() < 1e-12:
			t = tans[i - 1] if i > 0 else Vector3.DOWN
		tans.append(t.normalized())
	var zs: Array[Vector3] = []
	var z := depth
	for i in range(n):
		z = z - tans[i] * z.dot(tans[i])
		if z.length_squared() < 1e-10:
			z = tans[i].cross(Vector3.RIGHT if absf(tans[i].x) < 0.9 else Vector3.UP)
		z = z.normalized()
		zs.append(z)
	if twist != Vector3.ZERO:
		var want := (twist - tans[n - 1] * twist.dot(tans[n - 1])).normalized()
		var ang := zs[n - 1].signed_angle_to(want, tans[n - 1])
		for i in range(twist_from, n):
			var f := float(i - twist_from) / maxf(float(n - 1 - twist_from), 1.0)
			zs[i] = zs[i].rotated(tans[i], ang * f)
	var s := rest
	for i in range(n):
		if i > 0:
			s += pts[i].distance_to(pts[i - 1])
		var x := zs[i].cross(tans[i])
		for k in range(segs):
			var a := TAU * k / segs
			var c := cos(a)
			var sn := sin(a)
			var v := i * segs + k
			verts[v] = pts[i] + x * (c * rx[i]) + zs[i] * (sn * rz[i])
			norms[v] = (x * (c / rx[i]) + zs[i] * (sn / rz[i])).normalized()
			colors[v] = cols[i]
			uv[v] = Vector2(c * 0.05, s)
			uv2[v] = Vector2(sn * 0.05, 1.0)
	for e in range(2):
		var i := 0 if e == 0 else n - 1
		var v := n * segs + e
		var dir := -tans[0] if e == 0 else tans[n - 1]
		verts[v] = pts[i] + dir * minf(rx[i], rz[i]) * 0.9
		norms[v] = dir
		colors[v] = cols[i]
		uv[v] = Vector2(0.0, s if e == 1 else rest)
		uv2[v] = Vector2(0.0, 1.0)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = _loft_index(n)
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _mat)


## Triangles for a loft of `n` rings (the same every frame).
func _loft_index(n: int) -> PackedInt32Array:
	if _index_cache.has(n):
		return _index_cache[n]
	var segs := LOFT_SIDES
	var idx := PackedInt32Array()
	for i in range(n - 1):
		for k in range(segs):
			var a := i * segs + k
			var b := i * segs + (k + 1) % segs
			idx.append_array([a, a + segs, b + segs, a, b + segs, b])
	var p0 := n * segs
	for k in range(segs):
		var k1 := (k + 1) % segs
		idx.append_array([p0, k, k1, p0 + 1, (n - 1) * segs + k1, (n - 1) * segs + k])
	_index_cache[n] = idx
	return idx


# --- the hand -------------------------------------------------------------------------

## The right hand, in its own frame: origin at the wrist, +Y along the hand to
## the knuckles, +Z out of the back of the hand, the thumb on -X (the left
## hand is this one mirrored). Fingers: knuckle x and y, the three bones, radius.
const FINGERS := [
	[-0.026, 0.09, [0.042, 0.025, 0.02], 0.0092],    # index
	[-0.008, 0.094, [0.046, 0.028, 0.021], 0.0096],  # middle
	[0.011, 0.09, [0.043, 0.027, 0.02], 0.009],      # ring
	[0.028, 0.08, [0.034, 0.02, 0.018], 0.0079]]     # little
const GRIP_Y := 0.085   # where the axis of what's held crosses the hand


## The axis of something `r` thick held in the hand (hand frame: y, z): across
## the base of the fingers, just under the palm.
static func _grip_axis(r: float) -> Vector2:
	return Vector2(GRIP_Y, -(0.012 + r))


## Where a hand holding something `r` thick goes so that it holds it with
## the thing's axis through `centre` along `across` (the hand's +X), the back
## of the hand facing `back` (as near as it can).
static func _hold_at(centre: Vector3, across: Vector3, back: Vector3, r: float) -> Transform3D:
	var x := across.normalized()
	var z := (back - x * back.dot(x)).normalized()
	var b := Basis(x, z.cross(x), z)
	var g := _grip_axis(r)
	return Transform3D(b, centre - b * Vector3(0.0, g.x, g.y))


## Bones of a finger curled round a bar: from the knuckle `p0` (the hand's
## y, z), each joint the bone's length on round, as close round the bar's
## axis `c` as `rho` (the bar plus the finger's own thickness) lets it.
static func _curl(p0: Vector2, lens: Array, c: Vector2, rho: float) -> Array[Vector2]:
	var out: Array[Vector2] = [p0]
	var cur := p0
	for l: float in lens:
		var d := cur.distance_to(c)
		var nxt: Vector2
		if d > rho + l:
			nxt = cur + (c - cur).normalized() * l
		elif d < absf(rho - l) or d < 1e-5:
			var u := cur - c
			nxt = c + u.rotated(-l / maxf(u.length(), 0.01))
		else:
			var u := (cur - c) / d
			var a := (d * d + rho * rho - l * l) / (2.0 * d)
			var h := sqrt(maxf(rho * rho - a * a, 0.0))
			nxt = c + u * a + Vector2(u.y, -u.x) * h   # on round: the way the fingers close
		out.append(nxt)
		cur = nxt
	return out


## A right hand closed round a bar `r` thick (the rim 0.017, a gear knob 0.035;
## wide open for a big r): a palm slab from the wrist to the knuckle line,
## the soft pads at its heel, knuckles, fingers in three bones each curled
## round the bar with a nail on the tip, the thumb hooked round the near side.
func _hand_mesh(r: float) -> ArrayMesh:
	var st := MeshKit.begin()
	var g := _grip_axis(r)
	# palm: squarish cross-sections, the knuckle line swept back to the little finger
	var rows: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	var ys := [-0.014, 0.012, 0.04, 0.064, 0.082, 0.094]
	var hw := [0.024, 0.033, 0.039, 0.042, 0.043, 0.04]
	var ht := [0.017, 0.019, 0.018, 0.016, 0.0145, 0.012]
	var arc := [0.0, 0.0, 0.2, 0.5, 0.9, 1.0]
	for j in range(ys.size()):
		var ring := PackedVector3Array()
		var cr := PackedColorArray()
		for i in range(20):
			var a := TAU * i / 20.0
			var x: float = hw[j] * _sgnpow(cos(a), 0.7)
			var z: float = ht[j] * _sgnpow(sin(a), 0.8)
			var y: float = ys[j] + float(arc[j]) * (-6.0 * pow(x + 0.008, 2.0) - 0.1 * maxf(x, 0.0))
			ring.append(Vector3(x, y, z))
			cr.append(SKIN)
		rows.append(ring)
		cols.append(cr)
	MeshKit.grid(st, rows, cols, Transform3D.IDENTITY)
	# the ball of the thumb and the pad under the little finger, on the palm side
	MeshKit.sphere(st, 1.0, Transform3D(Basis(Vector3.BACK, -0.4) * Basis.from_scale(Vector3(0.019, 0.03, 0.013)), Vector3(-0.021, 0.028, -0.01)), SKIN, 12)
	MeshKit.sphere(st, 1.0, Transform3D(Basis.from_scale(Vector3(0.014, 0.032, 0.011)), Vector3(0.024, 0.036, -0.009)), SKIN, 12)
	# fingers
	for f: Array in FINGERS:
		var x0: float = f[0]
		var fr: float = f[3]
		var j := _curl(Vector2(f[1], 0.0), f[2], g, r + fr * 1.05)
		var pts := PackedVector3Array([Vector3(x0, j[0].x - 0.014, j[0].y)])
		var radii := PackedFloat32Array([fr * 1.12])
		for k in range(4):
			pts.append(Vector3(x0 * lerpf(1.0, 0.92, k / 3.0), j[k].x, j[k].y))
			radii.append(fr * lerpf(1.1, 0.84, k / 3.0))
		MeshKit.sweep(st, pts, radii, Transform3D.IDENTITY, SKIN, 10)
		for k in range(1, 5):
			MeshKit.sphere(st, radii[k] * (1.06 if k < 4 else 1.0), Transform3D(Basis.IDENTITY, pts[k] + Vector3(0, 0, 0.002 if k == 1 else 0.0)), SKIN, 10)
		_nail(st, pts[3], pts[4], fr, Vector3(x0, g.x, g.y))
	# thumb: from the heel of the palm, round the near side of the bar
	var cmc := Vector3(-0.02, 0.012, -0.006)
	var mcp := Vector3(-0.044, 0.042, -0.02)
	var th := deg_to_rad(-125.0)
	var rt := r + 0.009
	var tip := Vector3(-0.05, g.x + cos(th) * rt, g.y + sin(th) * rt)
	if tip.distance_to(mcp) > 0.055:
		tip = mcp + (tip - mcp).normalized() * 0.055
	var dt := tip - mcp
	var d := clampf(dt.length(), 0.01, 0.0585)
	var along := (0.032 * 0.032 - 0.027 * 0.027 + d * d) / (2.0 * d)
	var away := (mcp + tip) * 0.5 - Vector3(-0.05, g.x, g.y)
	away = (away - dt.normalized() * away.dot(dt.normalized())).normalized()
	var ip := mcp + dt.normalized() * along + away * sqrt(maxf(0.032 * 0.032 - along * along, 0.0))
	var tpts := PackedVector3Array([cmc, mcp, ip, tip])
	var trad := PackedFloat32Array([0.015, 0.0118, 0.0104, 0.0092])
	MeshKit.sweep(st, tpts, trad, Transform3D.IDENTITY, SKIN, 10)
	for k in range(1, 4):
		MeshKit.sphere(st, trad[k] * 1.04, Transform3D(Basis.IDENTITY, tpts[k]), SKIN, 10)
	_nail(st, ip, tip, 0.0095, Vector3(-0.05, g.x, g.y))
	return MeshKit.commit(st, _mat)


## A fingernail on the back of the last bone (`a` to the tip `b`), facing away
## from the bar's axis at `axis`.
func _nail(st: SurfaceTool, a: Vector3, b: Vector3, r: float, axis: Vector3) -> void:
	var along := (b - a).normalized()
	var mid := a.lerp(b, 0.62)
	var out := mid - axis
	out.x = 0.0
	out = (out - along * out.dot(along)).normalized()
	var side := out.cross(along).normalized()
	MeshKit.rounded_box(st, Vector3(r * 1.25, 0.002, 0.011), 0.001, Transform3D(Basis(side, out, along), mid + out * r * 0.78), NAIL, 1)


func _part(st: SurfaceTool, parent: Node3D, name_: String, mat: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name_
	mi.mesh = MeshKit.commit(st, mat if mat else _mat)
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
	# the seat of the jorts; each leg is a skin from the hip to the ankle
	# (`_place_legs`), a bare foot in a tsinelas on the end of it
	var st := MeshKit.begin()
	MeshKit.rounded_box(st, Vector3(0.36, 0.16, 0.3), 0.07, Transform3D(Basis.IDENTITY, HIP + Vector3(0, -0.01, 0.0)), DENIM, 3)
	_part(st, self, "Seat")
	var foot := _foot_mesh()
	for i in range(2):
		var leg := MeshInstance3D.new()
		leg.name = "Leg" + str(i)
		leg.mesh = ArrayMesh.new()
		add_child(leg)
		_leg_mesh.append(leg.mesh)
		var f := MeshInstance3D.new()
		f.name = "Foot" + str(i)
		f.mesh = foot
		add_child(f)
		_feet.append(f)


## A bare foot on a tsinelas, in its frame from the ankle (toes to -Z): the
## foot itself, a thin white-and-blue rubber sole, a Y strap between the toes.
func _foot_mesh() -> ArrayMesh:
	var st := MeshKit.begin()
	var at := func(p: Vector3) -> Transform3D: return Transform3D(Basis.IDENTITY, p)
	MeshKit.sphere(st, 1.0, Transform3D(Basis.from_scale(Vector3(0.034, 0.04, 0.036)), Vector3(0, -0.02, 0.008)), SKIN, 12)   # ankle and heel
	MeshKit.rounded_box(st, Vector3(0.088, 0.048, 0.2), 0.022, at.call(Vector3(0, -0.062, -0.07)), SKIN, 2)
	for k in range(5):
		var tx := lerpf(-0.03, 0.032, k / 4.0)
		MeshKit.sphere(st, 0.011 - 0.0012 * k, at.call(Vector3(tx, -0.07, -0.17 + 0.006 * k * k * 0.25)), SKIN, 8)
	var sole := Vector3(0, -0.0905, -0.065)
	MeshKit.rounded_box(st, Vector3(0.1, 0.012, 0.25), 0.005, at.call(sole), SOLE, 2)
	MeshKit.rounded_box(st, Vector3(0.102, 0.006, 0.252), 0.003, at.call(sole + Vector3(0, 0.008, 0)), SLIPPER, 2)
	var toe := Vector3(0, -0.06, -0.15)
	for s2: float in [-1.0, 1.0]:
		MeshKit.tube(st, toe, Vector3(s2 * 0.047, -0.078, -0.06), 0.006, Transform3D.IDENTITY, SLIPPER, 5)
	return MeshKit.commit(st, _mat)


## The knee for a leg from `hip` to `ankle`, thigh `a` and shin `b` long:
## bent up (and splayed out by side `sx`); straight, if the ankle's out of reach.
static func _knee(hip: Vector3, ankle: Vector3, a: float, b: float, sx: float) -> Vector3:
	var d := ankle - hip
	var dist := clampf(d.length(), 0.05, a + b - 0.001)
	var dir := d.normalized()
	var along := (a * a - b * b + dist * dist) / (2.0 * dist)
	var up := (Vector3.UP - dir * dir.dot(Vector3.UP)).normalized()
	up = (up + Vector3(sx * 0.15, 0, 0)).normalized()
	return hip + dir * along + up * sqrt(maxf(a * a - along * along, 0.0))


## Torso cross-sections (torso space, before the lean): height, half-width,
## front depth, back depth, squareness. A trail guy's build: solid shoulders,
## a bit of a belly, a thick neck.
const TORSO_ROWS := [
	[-0.02, 0.165, 0.112, 0.1, 2.5], [0.08, 0.162, 0.12, 0.098, 2.5],    # hips, belly
	[0.2, 0.152, 0.118, 0.094, 2.5], [0.3, 0.163, 0.116, 0.098, 2.6],    # waist
	[0.4, 0.18, 0.122, 0.104, 2.8], [0.47, 0.19, 0.116, 0.104, 2.8],     # chest
	[0.52, 0.192, 0.098, 0.095, 2.6], [0.555, 0.172, 0.08, 0.086, 2.4],  # shoulders, traps
	[0.585, 0.128, 0.066, 0.074, 2.2], [0.615, 0.082, 0.062, 0.066, 2.0],
	[0.65, 0.068, 0.06, 0.062, 2.0], [0.72, 0.064, 0.056, 0.058, 2.0]]   # thick neck


func _sgnpow(v: float, e: float) -> float:
	return signf(v) * pow(absf(v), e)


## One point on the torso at height y, angle a (0 = his right, PI/2 = his back).
func _torso_point(y: float, a: float) -> Vector3:
	var k := 0
	while k < TORSO_ROWS.size() - 2 and y > float(TORSO_ROWS[k + 1][0]):
		k += 1
	var r0: Array = TORSO_ROWS[k]
	var r1: Array = TORSO_ROWS[k + 1]
	var f := smoothstep(float(r0[0]), float(r1[0]), y)
	var w := lerpf(r0[1], r1[1], f)
	var df := lerpf(r0[2], r1[2], f)
	var db := lerpf(r0[3], r1[3], f)
	var e := 2.0 / lerpf(r0[4], r1[4], f)
	var x := w * _sgnpow(cos(a), e)
	var zz := _sgnpow(sin(a), e)
	return Vector3(x, y, 0.02 + zz * (db if zz > 0.0 else df))


## What covers the torso at a point: the tee, its collar, the frayed armholes, or skin.
func _torso_paint(p: Vector3) -> Color:
	if p.y > 0.6:
		return SKIN
	if p.y > 0.582:
		return COLLAR
	# the cut armholes: big ovals on each side, a strap of shirt over the shoulder
	var h := Vector2((p.z - 0.025) / 0.088, (p.y - 0.468) / 0.112)
	if absf(p.x) > 0.13:
		var d := h.length()
		if d < 0.93:
			return SKIN
		if d < 1.0:
			return SHIRT_EDGE
	return SHIRT


func _build_torso() -> void:
	# torso local: origin at the hips, leaning back into the seat a touch
	var st := MeshKit.begin()
	var lean := Basis(Vector3.RIGHT, 0.12)
	var rows: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	var segs := 64
	var steps := 70
	var y0 := float(TORSO_ROWS[0][0])
	var y1 := float(TORSO_ROWS[TORSO_ROWS.size() - 1][0])
	for j in range(steps + 1):
		var y := lerpf(y0, y1, float(j) / steps)
		var ring := PackedVector3Array()
		var cr := PackedColorArray()
		for i in range(segs):
			var p := _torso_point(y, TAU * i / segs)
			ring.append(lean * p)
			# paint by the middle of the quad this point starts
			var yc := lerpf(y0, y1, (j + 0.5) / steps)
			cr.append(_torso_paint(_torso_point(yc, TAU * (i + 0.5) / segs)))
		rows.append(ring)
		cols.append(cr)
	MeshKit.grid(st, rows, cols, Transform3D.IDENTITY)
	# the bare shoulders: a deltoid cap where each arm leaves the body
	for sx: float in [-1.0, 1.0]:
		var sh := lean * Vector3(sx * 0.196, 0.53, 0.028)
		MeshKit.sphere(st, 0.06, Transform3D(Basis.IDENTITY.scaled(Vector3(0.95, 0.8, 1.0)), sh), SKIN, 16)
	# the club logo, big on the chest (the seat back would hide one on his back).
	# Seen from the front his left (-X) is the print's right.
	_shirt_mat = _mat.duplicate()
	var tex := _club_print()
	if tex:
		var at := Transform3D(lean * Basis(Vector3(-PRINT_SIZE, 0, 0), Vector3(0, PRINT_SIZE, 0), Vector3(0, 0, -1)),
			lean * Vector3(0, 0.37, 0.02 - 0.115))
		_shirt_mat.set_shader_parameter("has_print", true)
		_shirt_mat.set_shader_parameter("print_tex", tex)
		_shirt_mat.set_shader_parameter("print_inv", at.affine_inverse())
	_part(st, _torso, "Torso", _shirt_mat)


## The print picked in the menu (Game.LOGOS), or null for a plain tee:
## imported when the editor has seen it, else read straight off disk.
func _club_print() -> Texture2D:
	var path := Game.logo_path()
	if path == "":
		return null
	if ResourceLoader.exists(path):
		return load(path)
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return null
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _build_helmet() -> void:
	# head local: origin at the top of the neck. A full-face helmet: one
	# smooth shell with the chin tapering forward, and a glossy black visor
	# across the front.
	var st := MeshKit.begin()
	var visor := MeshKit.begin()
	_helmet_shell(st, visor)
	var helmet := _part(st, _head, "Helmet")
	helmet.layers = 2  # hidden from the driver's-seat camera, which sits inside it
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.015, 0.015, 0.02)
	glass.roughness = 0.04
	glass.metallic = 0.3
	var vi := MeshInstance3D.new()
	vi.name = "Visor"
	vi.mesh = MeshKit.commit(visor, glass)
	vi.layers = 2
	_head.add_child(vi)


## The shell is a lat/long grid in 5 degree steps (lat -55..90). The visor
## covers a lat/long window (lat -20..20, lon -60..60 off the front), so its
## edges run along grid lines and come out clean.
func _helmet_shell(st: SurfaceTool, visor: SurfaceTool) -> void:
	var step := deg_to_rad(5.0)
	var lat0 := deg_to_rad(-55.0)
	var rings := 29
	var segs := 72
	var centre := Vector3(0, 0.11, 0)
	var grid: Array[Vector3] = []
	var dirs: Array[Vector3] = []
	var cols: Array[Color] = []
	for ri in range(rings + 1):
		var lat := lat0 + ri * step
		for si in range(segs):
			var lon := si * step - PI   # -180..175, 0 = straight ahead
			var d := Vector3(cos(lat) * sin(lon), sin(lat), -cos(lat) * cos(lon))
			var p := d * Vector3(0.138, 0.152, 0.17)
			var front := smoothstep(0.35, 1.0, -d.z)
			var down := smoothstep(-0.25, -0.8, d.y)
			# chin: tapers forward and a little narrower toward the bottom
			p.z -= 0.06 * front * down
			p.x *= 1.0 - 0.12 * front * down
			# lower back rolls out slightly over the neck
			p += Vector3(d.x, 0.0, maxf(d.z, 0.0)) * 0.02 * (1.0 - smoothstep(-0.85, -0.45, d.y)) * smoothstep(-0.2, 0.4, d.z)
			grid.append(centre + p)
			dirs.append(d)
			var c := HELMET
			if d.y > 0.4 and d.z > -0.85:
				if d.x > -0.11 and d.x < -0.035:
					c = STRIPE_R
				elif d.x > 0.035 and d.x < 0.11:
					c = STRIPE_B
			# blue chin and a black vent, on grid lines so their edges are clean
			var off := si - segs / 2
			if ri < 5 and absi(off) < 9:
				c = STRIPE_B
			if ri >= 1 and ri < 3 and absi(off) < 2:
				c = VISOR
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
	var win_lat := Vector2i(7, 15)    # rings for lat -20..20
	var win_lon := 12                 # segments either side of straight ahead (60 degrees)
	for ri in range(rings):
		for si in range(segs):
			var ids: Array[int] = [ri * segs + si, ri * segs + (si + 1) % segs,
				(ri + 1) * segs + (si + 1) % segs, (ri + 1) * segs + si]
			var q: Array[Vector3] = []
			var qn: Array[Vector3] = []
			for i in ids:
				q.append(grid[i])
				qn.append(normals[i])
			var off := si - segs / 2
			if ri >= win_lat.x and ri < win_lat.y and off >= -win_lon and off < win_lon:
				# the visor: same patch, standing a few millimetres proud
				var vq: Array[Vector3] = []
				for k in range(4):
					vq.append(q[k] + qn[k] * 0.006)
				MeshKit._quad(visor, Transform3D.IDENTITY, vq, qn, VISOR)
				continue
			MeshKit._quad(st, Transform3D.IDENTITY, q, qn, cols[ids[0]])
	# the visor's edge seal and its two pivots
	var edge := PackedVector3Array()
	var er := PackedFloat32Array()
	var loop: Array[int] = []
	for k in range(-win_lon, win_lon + 1):
		loop.append(win_lat.y * segs + segs / 2 + k)
	for ri in range(win_lat.y - 1, win_lat.x - 1, -1):
		loop.append(ri * segs + segs / 2 + win_lon)
	for k in range(win_lon - 1, -win_lon - 1, -1):
		loop.append(win_lat.x * segs + segs / 2 + k)
	for ri in range(win_lat.x + 1, win_lat.y + 1):
		loop.append(ri * segs + segs / 2 - win_lon)
	for i in loop:
		edge.append(grid[i] + normals[i] * 0.004)
		er.append(0.006)
	MeshKit.sweep(st, edge, er, Transform3D.IDENTITY, VISOR, 6)
	for side: int in [-win_lon - 1, win_lon + 1]:
		var i := (win_lat.y - 1) * segs + segs / 2 + side
		MeshKit.cylinder(st, 0.016, 0.01, Transform3D(MeshKit.y_to(normals[i]), grid[i] + normals[i] * 0.004), VISOR, 12)


## A body part the physics engine moves: no collisions (he's strapped in),
## just mass and shape so it swings like a torso or a head.
func _body(name_: String, kg: float, size: Vector3, centre: Vector3) -> RigidBody3D:
	var b := RigidBody3D.new()
	b.name = name_
	b.top_level = true
	b.mass = kg
	b.collision_layer = 0
	b.collision_mask = 0
	b.can_sleep = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = centre
	b.add_child(cs)
	add_child(b)
	return b


## Pin `b` to `a` at `at` (rig space): free to tip forward/back and side to
## side up to `tip` rad, twist up to `twist`, and slide up/down `travel` m.
func _joint(a: PhysicsBody3D, b: PhysicsBody3D, at: Vector3, tip: float, twist: float, travel: float) -> void:
	var j := Generic6DOFJoint3D.new()
	j.position = at
	add_child(j)
	for axis in range(3):
		var lim := twist if axis == 1 else tip
		match axis:
			0:
				j.set_flag_x(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
				j.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -lim)
				j.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, lim)
			1:
				j.set_flag_y(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
				j.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -lim)
				j.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, lim)
				j.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, -travel)
				j.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, travel * 0.75)
			2:
				j.set_flag_z(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
				j.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -lim)
				j.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, lim)
	j.node_a = j.get_path_to(a)
	j.node_b = j.get_path_to(b)


## Put him back in the seat, at rest (after a reset or a teleport).
func snap() -> void:
	var seat := rig.global_transform * Transform3D(Basis.IDENTITY, HIP)
	for pair: Array in [[_torso, seat], [_head, seat * Transform3D(Basis.IDENTITY, NECK)]]:
		var b: RigidBody3D = pair[0]
		var t: Transform3D = pair[1]
		b.global_transform = t
		PhysicsServer3D.body_set_state(b.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, t)
		b.linear_velocity = rig.linear_velocity
		b.angular_velocity = rig.angular_velocity


# --- motion ------------------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if rig == null:
		return
	# muscles: hold the torso upright on the seat, the head on the torso,
	# and the eyes roughly level with the horizon
	_brace(_torso, rig, TORSO_K, TORSO_C)
	_brace(_head, _torso, HEAD_K, HEAD_C)
	var tilt := _head.global_basis.y.cross(Vector3.UP)
	_head.apply_torque(tilt * HEAD_LEVEL)
	_cushion()
	_place_steering()
	_work_controls(_delta)
	_place_arms()
	_place_legs()
	# in an open tub what the tires throw at the rig lands on him too; behind
	# glass all round it doesn't
	var closed: bool = (rig.get("spec") as RigSpec).closed()
	for m: ShaderMaterial in [_mat, _shirt_mat]:
		m.set_shader_parameter("mud", 0.0 if closed else rig.call("mud_amount"))
		m.set_shader_parameter("dryness", rig.get("dryness"))
		m.set_shader_parameter("mud_ash", rig.get("mud_ash"))


## Torque `body` back toward its rest pose relative to `parent` (equal and
## opposite on the parent): a damped rotational spring.
func _brace(body: RigidBody3D, parent: RigidBody3D, k: float, c: float) -> void:
	var rel := (parent.global_basis.inverse() * body.global_basis).get_rotation_quaternion()
	var angle := rel.get_angle()
	if angle > PI:
		angle -= TAU
	var bend := Vector3.ZERO
	if absf(angle) > 1e-5:
		bend = parent.global_basis * (rel.get_axis() * angle)
	var torque := -bend * k - (body.angular_velocity - parent.angular_velocity) * c
	body.apply_torque(torque)
	parent.apply_torque(-torque)


## The seat cushion under him: springs him back to sitting height.
func _cushion() -> void:
	var seat := rig.global_transform * HIP
	var up := rig.global_basis.y
	var dy := (_torso.global_position - seat).dot(up)
	var rel_v := _torso.linear_velocity - rig.linear_velocity - rig.angular_velocity.cross(seat - rig.global_position)
	var f := up * (-dy * SEAT_K - rel_v.dot(up) * SEAT_C)
	_torso.apply_central_force(f)
	rig.apply_force(-f, seat - rig.global_position)


func _place_steering() -> void:
	var steer: float = rig.get("steer")
	# a bent tie rod: the spokes sit off-centre (where you'd hold them to go
	# straight), so you can see it from the seat
	var dmg = rig.get("damage")
	if dmg:
		steer -= (dmg as Damage).steer_offset()
	steering_wheel.transform = Transform3D(Basis(Vector3.RIGHT, WHEEL_TILT) * Basis(Vector3.UP, steer * STEER_RATIO), WHEEL_AT)


func _place_arms() -> void:
	var sides: Array[float] = [-1.0, 1.0]
	var left := steering_wheel.transform * Transform3D(Basis.from_scale(Vector3(-1, 1, 1)), Vector3.ZERO) * _wheel_grip()
	_hands[0].transform = left
	_hands[1].transform = _hand_xf
	for i in range(2):
		var sx := sides[i]
		var hand: Transform3D = left if i == 0 else _hand_xf
		# from wherever the physics has thrown the torso, into rig space
		var shoulder: Vector3 = to_local(_torso.global_transform * (Basis(Vector3.RIGHT, 0.12) * Vector3(sx * 0.2, 0.53, 0.03)))
		var wrist := hand.origin
		var to := wrist - shoulder
		var d := clampf(to.length(), 0.05, UPPER_ARM + FOREARM - 0.005)
		var dir := to.normalized()
		# elbows hang out and down
		var pole := Vector3(sx * 0.8, -1.0, 0.2)
		pole = (pole - dir * pole.dot(dir)).normalized()
		var a := (UPPER_ARM * UPPER_ARM - FOREARM * FOREARM + d * d) / (2.0 * d)
		var h := sqrt(maxf(UPPER_ARM * UPPER_ARM - a * a, 0.0))
		var elbow := shoulder + dir * a + pole * h
		wrist = shoulder + dir * d
		_arm_skin(_arm_mesh[i], shoulder, elbow, wrist, hand, pole, float(i) * 3.0)


## Shoulder to wrist in one skin: the upper arm's profile, round the elbow,
## the forearm's, turning to meet the hand, and on a little into the hand.
func _arm_skin(mesh: ArrayMesh, shoulder: Vector3, elbow: Vector3, wrist: Vector3, hand: Transform3D, pole: Vector3, rest: float) -> void:
	var pts := PackedVector3Array()
	var rx := PackedFloat32Array()
	var rz := PackedFloat32Array()
	var d1 := (elbow - shoulder).normalized()
	var d2 := (wrist - elbow).normalized()
	var e1 := elbow - d1 * 0.04
	var e2 := elbow + d2 * 0.04
	var start := shoulder - d1 * 0.03
	for k in range(9):
		var p := start.lerp(e1, k / 8.0)
		pts.append(p)
		var w := _prof(UPPER_ARM_PROFILE, (p - shoulder).dot(d1) / UPPER_ARM)
		rx.append(w.x)
		rz.append(w.y)
	var up_end := _prof(UPPER_ARM_PROFILE, 1.0)
	var fore0 := _prof(FOREARM_PROFILE, 0.0)
	for k in range(1, 4):
		var u := k / 4.0
		pts.append(e1.lerp(elbow, u).lerp(elbow.lerp(e2, u), u))
		var w := up_end.lerp(fore0, u) + Vector2(0.0, 0.004 * sin(u * PI))   # the point of the elbow
		rx.append(w.x)
		rz.append(w.y)
	var twist_from := pts.size()
	for k in range(10):
		var p := e2.lerp(wrist, k / 9.0)
		pts.append(p)
		var w := _prof(FOREARM_PROFILE, (p - elbow).dot(d2) / FOREARM)
		rx.append(w.x)
		rz.append(w.y)
	pts.append(wrist + hand.basis.y.normalized() * 0.012)
	var wr := _prof(FOREARM_PROFILE, 1.0)
	rx.append(wr.x)
	rz.append(wr.y)
	var cols := PackedColorArray()
	cols.resize(pts.size())
	cols.fill(SKIN)
	_loft(mesh, pts, rx, rz, cols, pole, hand.basis.z.normalized(), twist_from, rest)


## The right hand on the rim at two o'clock (steering-wheel space): round the
## rim with the thumb up along it toward the top, the back of the hand out
## and turned a little toward him. The left is this mirrored.
func _wheel_grip() -> Transform3D:
	var g0 := Vector3(WHEEL_R * 0.87, 0.0, -WHEEL_R * 0.5)
	var out := g0.normalized()
	var up_rim := Vector3.UP.cross(out)
	return _hold_at(g0, -up_rim, out * cos(HAND_TURN) + Vector3.UP * sin(HAND_TURN), RIM_R)


## The right hand on a lever (rig space): over the top of a knob, fingers
## round its front; along the handbrake's handle, fingers round under it.
func _lever_grip(what: String) -> Transform3D:
	var at := _cabin.grip_at(what)
	if what == "hb":
		var back := at.basis.z.normalized()
		return _hold_at(at.origin, back, at.basis.y.normalized() * 0.85 + Vector3.LEFT * 0.5, 0.018)
	var up := at.basis.y.normalized()
	var fingers := Vector3(0.35, -0.2, -1.0).normalized()
	var across := fingers.cross(up)
	return _hold_at(at.origin, across, up + Vector3(-0.3, 0.0, 0.25), 0.035 if what == "gear" else 0.022)


## The legs to wherever the feet are now.
func _place_legs() -> void:
	var key := PackedVector3Array([_foot_xf[0].origin, _foot_xf[1].origin, _foot_xf[0].basis.z, _foot_xf[1].basis.z])
	if key == _leg_key:
		return
	_leg_key = key
	var sides: Array[float] = [-1.0, 1.0]
	for i in range(2):
		var sx := sides[i]
		var hip := HIP + Vector3(sx * 0.09, 0.0, -0.04)
		var foot := _foot_xf[i]
		var ankle := foot.origin
		var knee := _knee(hip, ankle, THIGH, SHIN, sx)
		ankle = knee + (ankle - knee).normalized() * minf(SHIN, (ankle - knee).length())
		_feet[i].transform = Transform3D(foot.basis, ankle)
		_leg_skin(_leg_mesh[i], hip, knee, ankle, sx, 7.0 + float(i) * 3.0)


## Hip to ankle in one skin: jorts to just above the knee with a frayed hem,
## then bare skin over the knee, the calf, down to a slim ankle.
func _leg_skin(mesh: ArrayMesh, hip: Vector3, knee: Vector3, ankle: Vector3, sx: float, rest: float) -> void:
	var pts := PackedVector3Array()
	var rx := PackedFloat32Array()
	var rz := PackedFloat32Array()
	var cols := PackedColorArray()
	var add := func(p: Vector3, a: float, b: float, c: Color) -> void:
		pts.append(p)
		rx.append(a)
		rz.append(b)
		cols.append(c)
	var d1 := (knee - hip).normalized()
	var d2 := (ankle - knee).normalized()
	var k1 := knee - d1 * 0.05
	var k2 := knee + d2 * 0.05
	for k in range(6):
		var t := lerpf(-0.12, 0.78, k / 5.0)
		add.call(hip + d1 * THIGH * t, lerpf(0.098, 0.088, maxf(t, 0.0)), lerpf(0.09, 0.084, maxf(t, 0.0)), DENIM)
	# the hem: a frayed edge where the legs were cut off
	var hem := hip + d1 * THIGH * 0.8
	add.call(hem, 0.091, 0.087, DENIM)
	add.call(hem + d1 * 0.004, 0.09, 0.086, FRAY)
	add.call(hem + d1 * 0.004, 0.064, 0.064, FRAY)
	add.call(hem + d1 * 0.004, 0.063, 0.063, SKIN)
	add.call(k1, 0.054, 0.056, SKIN)
	for k in range(1, 4):
		var u := k / 4.0
		add.call(k1.lerp(knee, u).lerp(knee.lerp(k2, u), u), 0.052, 0.056 + 0.004 * sin(u * PI), SKIN)
	# shin: the calf behind, tapering to the ankle
	for k in range(8):
		var t := k / 7.0
		var w := _prof(SHIN_PROFILE, t)
		add.call(k2.lerp(ankle, t), w.x, w.y, SKIN)
	var pole := (Vector3.UP + Vector3(sx * 0.15, 0, 0)).normalized()
	_loft(mesh, pts, rx, rz, cols, pole, Vector3.ZERO, 0, rest)


const SHIN_PROFILE := [[0.0, 0.046, 0.05], [0.3, 0.05, 0.056], [0.6, 0.04, 0.044], [1.0, 0.029, 0.032]]


# --- working the controls ----------------------------------------------------------------

## The feet on the pedals and the right hand on the levers, from what the
## rig is doing this step: the brake or the throttle under the right foot,
## the clutch down for a shift, a stop or pulling away; the hand off the
## wheel to put the lever where the gearbox now is.
func _work_controls(delta: float) -> void:
	var r := rig as Rig
	if r == null or _cabin == null:
		return
	var gb := r.gearbox
	var low := 1.0 if r.low_range else 0.0
	var gate := CabinKit.gate(gb.gear, gb.gears.size())
	# --- the right hand
	var done := true
	match _hand:
		"gear":
			done = _shown_gear == gb.gear and _lever == gate
		"tc":
			done = is_equal_approx(_tc_f, low)
		"hb":
			done = not r.handbrake_on and _hb_f <= 0.0
	var want := "wheel"
	if r.handbrake_on:
		want = "hb"
	elif _hand != "wheel" and (not done or _hold < 0.15):
		want = _hand
	elif gb.gear != _shown_gear:
		want = "gear"
	elif not is_equal_approx(_tc_f, low):
		want = "tc"
	if want != _hand:
		_hand_from = _hand_xf
		_hand = want
		_hand_t = 0.0 if delta > 0.0 else 1.0
		_hold = 0.0
	_hand_t = minf(_hand_t + delta / 0.28, 1.0)
	var target := steering_wheel.transform * _wheel_grip() if _hand == "wheel" else _lever_grip(_hand)
	if _hand_t < 1.0:
		var s := smoothstep(0.0, 1.0, _hand_t)
		_hand_xf = _hand_from.interpolate_with(target, s)
		_hand_xf.origin += Vector3.UP * 0.05 * sin(PI * s)
	else:
		_hand_xf = target
		# on the lever: move it
		match _hand:
			"gear":
				if _lever != gate:
					# back to neutral, across the gate, then into the gear
					if not is_equal_approx(_lever.x, gate.x) and absf(_lever.y) > 0.0:
						_lever.y = move_toward(_lever.y, 0.0, delta * 7.0)
					elif not is_equal_approx(_lever.x, gate.x):
						_lever.x = move_toward(_lever.x, gate.x, delta * 7.0)
					else:
						_lever.y = move_toward(_lever.y, gate.y, delta * 7.0)
				else:
					_shown_gear = gb.gear
					_hold += delta
			"tc":
				_tc_f = move_toward(_tc_f, low, delta * 3.0)
				if is_equal_approx(_tc_f, low):
					_hold += delta
			"hb":
				_hb_f = move_toward(_hb_f, 1.0 if r.handbrake_on else 0.0, delta * 5.0)
				if not r.handbrake_on and _hb_f <= 0.0:
					_hold += delta
			_:
				_hold += delta
	if delta == 0.0:
		_lever = gate
		_shown_gear = gb.gear
		_tc_f = low
	var pose := "open" if _hand_t < 0.85 else _hand
	if _hands.size() > 1:
		_hands[1].mesh = _hand_meshes[pose]
	_cabin.set_gear_lever(_lever)
	_cabin.set_transfer(_tc_f)
	_cabin.set_handbrake(_hb_f)
	# --- the clutch: down for a shift (and while the hand's at the gear lever),
	# a stop on the brake, a stall; half up as he pulls away
	var clutch := 0.0
	if _hand == "gear" or gb.shifting > 0.0 or not gb.running:
		clutch = 1.0
	elif (r.pedal_brake > 0.05 or r.handbrake_on) and r.speed_kmh < 8.0:
		clutch = 1.0
	elif r.speed_kmh < 4.0 and r.pedal_gas > 0.05:
		clutch = 0.45
	# --- the feet: over to a pedal, then press it
	var wants: Array[String] = ["clutch" if clutch > 0.0 or _press["clutch"] > 0.0 else "rest",
		"brake" if r.pedal_brake > 0.02 or (_foot_on[1] == "brake" and _press["brake"] > 0.0) else "gas"]
	var amounts := {"clutch": clutch, "brake": r.pedal_brake, "gas": r.pedal_gas}
	for i in range(2):
		if wants[i] != _foot_on[i]:
			_foot_from[i] = _foot_xf[i]
			_foot_on[i] = wants[i]
			_foot_t[i] = 0.0 if delta > 0.0 else 1.0
		_foot_t[i] = minf(_foot_t[i] + delta / 0.2, 1.0)
	for k: String in ["clutch", "brake", "gas"]:
		var on := (_foot_on[0] == k or _foot_on[1] == k) and _foot_t[0 if k == "clutch" else 1] >= 1.0
		var goal: float = amounts[k] if on else 0.0
		# (a pedal goes down quick and comes up a touch slower, the clutch slowest)
		var rate := 9.0 if goal > _press[k] else (3.0 if k == "clutch" else 6.0)
		_press[k] = move_toward(_press[k], goal, delta * rate) if delta > 0.0 else goal
	_cabin.set_pedals(_press["clutch"], _press["brake"], _press["gas"])
	for i in range(2):
		var target_f := _cabin.foot_on(_foot_on[i])
		if _foot_t[i] < 1.0:
			var s := smoothstep(0.0, 1.0, _foot_t[i])
			_foot_xf[i] = _foot_from[i].interpolate_with(target_f, s)
			_foot_xf[i].origin += Vector3.UP * 0.045 * sin(PI * s)
		else:
			_foot_xf[i] = target_f
