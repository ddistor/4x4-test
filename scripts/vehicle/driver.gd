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
## head also tries to keep the eyes level. Arms reach the wheel by two-bone
## IK from wherever the torso has been thrown. Legs stay planted.
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
const UPPER_ARM := 0.3
const FOREARM := 0.29

var rig: RigidBody3D
var steering_wheel: Node3D
var _mat: ShaderMaterial
var _shirt_mat: ShaderMaterial   # _mat plus the chest print
var _torso: RigidBody3D
var _head: RigidBody3D
var _arms: Array = []   # per side: [upper arm, forearm, hand, elbow] MeshInstance3Ds

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
	_build_legs()
	_torso = _body("Torso", 40.0, Vector3(0.4, 0.5, 0.24), Vector3(0, 0.3, 0.02))
	_build_torso()
	_head = _body("Head", 5.0, Vector3(0.28, 0.3, 0.32), Vector3(0, 0.11, 0.0))
	_build_helmet()
	snap()
	_joint(rig, _torso, HIP, 0.6, 0.25, 0.04)
	_joint(_torso, _head, HIP + NECK, 0.7, 0.6, 0.0)
	for side: float in [-1.0, 1.0]:
		var parts := []
		for prof: Array in [UPPER_ARM_PROFILE, FOREARM_PROFILE]:
			var mi := MeshInstance3D.new()
			mi.mesh = _limb_mesh(prof)
			add_child(mi)
			parts.append(mi)
		var hand := MeshInstance3D.new()
		hand.mesh = _hand_mesh(side)
		add_child(hand)
		parts.append(hand)
		var elbow := MeshInstance3D.new()
		var es := MeshKit.begin()
		MeshKit.sphere(es, 0.037, Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.9)), Vector3.ZERO), SKIN, 12)
		elbow.mesh = MeshKit.commit(es, _mat)
		add_child(elbow)
		parts.append(elbow)
		_arms.append(parts)


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

## A limb one metre long up +Y, shaped from a profile; stretched to length when placed.
func _limb_mesh(prof: Array) -> ArrayMesh:
	var rows: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	var segs := 18
	var steps := 24
	for j in range(steps + 1):
		var t := float(j) / steps
		var k := 0
		while k < prof.size() - 2 and t > float(prof[k + 1][0]):
			k += 1
		var a: Array = prof[k]
		var b: Array = prof[k + 1]
		var f := smoothstep(float(a[0]), float(b[0]), t)
		var rx := lerpf(a[1], b[1], f)
		var rz := lerpf(a[2], b[2], f)
		var ring := PackedVector3Array()
		var cr := PackedColorArray()
		for i in range(segs):
			var ang := TAU * i / segs
			ring.append(Vector3(cos(ang) * rx, t, sin(ang) * rz))
			cr.append(SKIN)
		rows.append(ring)
		cols.append(cr)
	var st := MeshKit.begin()
	MeshKit.grid(st, rows, cols, Transform3D.IDENTITY, false)   # ends hide in the shoulder, elbow and wrist
	return MeshKit.commit(st, _mat)


## The rim frame at a hand's grip, in steering-wheel space: R out from the
## hub, A along the column toward the driver, U along the rim toward the top.
func _grip_frame(sx: float) -> Basis:
	var r := Vector3(sx * 0.87, 0.0, -0.5)
	var a := Vector3.UP
	var u := a.cross(r).normalized()
	if u.z > 0.0:
		u = -u
	return Basis(r, a, u)


## Where the wrist sits behind the grip (steering-wheel space, from the rim).
func _wrist_offset(sx: float) -> Vector3:
	var g := _grip_frame(sx)
	return g.x * 0.05 + g.y * 0.095


## A point on the rim's cross-section circle: angle 0 straight out from the
## hub, PI/2 toward the driver; `r` from the rim's centre line.
func _round_rim(g: Basis, th: float, r: float) -> Vector3:
	return (g.x * cos(th) + g.y * sin(th)) * r


## A hand closed round the rim, built in steering-wheel space about the grip
## point so it rides the wheel exactly: one palm from the wrist to the
## knuckles over the outside of the rim, four fingers curling round behind
## it from the knuckle line, the thumb hooked over the driver's side.
func _hand_mesh(sx: float) -> ArrayMesh:
	var g := _grip_frame(sx)
	var U := g.z
	var st := MeshKit.begin()
	var wrist := _wrist_offset(sx)
	var knuckle := _round_rim(g, deg_to_rad(28.0), 0.034)
	# palm: cross-sections along a slight curve from the wrist to the knuckles,
	# wide across the rim (U), thin through the hand
	var rows: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	var bulge := _round_rim(g, deg_to_rad(52.0), 0.036)
	var segs := 16
	var steps := 10
	for j in range(steps + 1):
		var t := float(j) / steps
		var c := wrist.lerp(bulge, t).lerp(bulge.lerp(knuckle, t), t)   # quadratic curve
		var ahead := (bulge.lerp(knuckle, t) - wrist.lerp(bulge, t)).normalized()
		if j == 0:
			c -= ahead * 0.02   # tuck the heel of the hand into the forearm
		var thick := U.cross(ahead).normalized()
		var hw := lerpf(0.024, 0.041, smoothstep(0.0, 0.6, t))
		var ht := lerpf(0.017, 0.0135, t)
		var ring := PackedVector3Array()
		var cr := PackedColorArray()
		for i in range(segs):
			var ang := TAU * i / segs
			ring.append(c + U * cos(ang) * hw + thick * sin(ang) * ht)
			cr.append(SKIN)
		rows.append(ring)
		cols.append(cr)
	MeshKit.grid(st, rows, cols, Transform3D.IDENTITY, false)
	# a soft wrist over the seam where the forearm meets the hand
	var wa := (bulge - wrist).normalized()
	var wt := U.cross(wa).normalized()
	MeshKit.sphere(st, 1.0, Transform3D(Basis(U * 0.027, wa * 0.032, wt * 0.02), wrist - wa * 0.012), SKIN, 14)
	# fingers: index (toward the top of the wheel) to little finger, each from
	# its knuckle round the back of the rim (rim r 0.017)
	var fingers := [[0.027, 0.0082, 0.95], [0.009, 0.0086, 1.0], [-0.009, 0.0082, 0.95], [-0.026, 0.007, 0.8]]
	for f: Array in fingers:
		var r0: float = f[1]
		var reach: float = f[2]
		var pts := PackedVector3Array()
		var radii := PackedFloat32Array()
		var n := 10
		for i in range(n):
			var u := float(i) / (n - 1)
			var th := deg_to_rad(lerpf(28.0, -150.0 * reach, u))
			var rad := lerpf(0.034, 0.017 + r0 * 0.95, smoothstep(0.0, 0.35, u))
			pts.append(U * float(f[0]) * lerpf(1.0, 0.92, u) + _round_rim(g, th, rad))
			radii.append(r0 * lerpf(1.05, 0.8, u))
		MeshKit.sweep(st, pts, radii, Transform3D.IDENTITY, SKIN, 8)
		MeshKit.sphere(st, radii[n - 1], Transform3D(Basis.IDENTITY, pts[n - 1]), SKIN, 8)
	# thumb: from the side of the palm by the wrist, over the driver's side of
	# the rim toward the hub
	var base := wrist.lerp(knuckle, 0.35) + U * 0.03
	var thumb := PackedVector3Array([base, _round_rim(g, deg_to_rad(75.0), 0.031) + U * 0.036,
		_round_rim(g, deg_to_rad(115.0), 0.027) + U * 0.031, _round_rim(g, deg_to_rad(145.0), 0.026) + U * 0.024])
	MeshKit.sweep(st, thumb, PackedFloat32Array([0.0135, 0.0105, 0.0092, 0.008]), Transform3D.IDENTITY, SKIN, 8)
	MeshKit.sphere(st, 0.008, Transform3D(Basis.IDENTITY, thumb[3]), SKIN, 8)
	return MeshKit.commit(st, _mat)


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
		var thigh := (knee - hip).normalized()
		MeshKit.sweep(st, PackedVector3Array([hip, hip.lerp(cuff, 0.45), cuff]), PackedFloat32Array([0.097, 0.094, 0.09]), Transform3D.IDENTITY, DENIM, 16)
		MeshKit.tube(st, cuff, cuff + thigh * 0.008, 0.091, Transform3D.IDENTITY, FRAY, 16)
		MeshKit.sweep(st, PackedVector3Array([cuff - thigh * 0.02, cuff.lerp(knee, 0.5), knee]), PackedFloat32Array([0.07, 0.062, 0.05]), Transform3D.IDENTITY, SKIN, 14)
		MeshKit.sphere(st, 0.049, Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 0.9)), knee + thigh * 0.004), SKIN, 14)
		# shin: the calf bulges behind, then tapers to a slim ankle
		var shin := (ankle - knee).normalized()
		var back := shin.cross(Vector3(sx, 0, 0)).normalized() * -signf(sx)
		MeshKit.sweep(st, PackedVector3Array([knee, knee.lerp(ankle, 0.3) + back * 0.008, knee.lerp(ankle, 0.65), ankle]),
			PackedFloat32Array([0.047, 0.05, 0.04, 0.032]), Transform3D.IDENTITY, SKIN, 14)
		# bare foot on a tsinelas: thin white-and-blue sole, a Y strap between the toes
		var foot := Transform3D(Basis(Vector3.RIGHT, -0.15), ankle + Vector3(0, -0.04, -0.07))
		MeshKit.rounded_box(st, Vector3(0.09, 0.05, 0.22), 0.022, foot, SKIN, 2)
		MeshKit.rounded_box(st, Vector3(0.1, 0.018, 0.25), 0.007, foot * Transform3D(Basis.IDENTITY, Vector3(0, -0.033, 0.0)), SOLE, 2)
		MeshKit.rounded_box(st, Vector3(0.102, 0.008, 0.252), 0.003, foot * Transform3D(Basis.IDENTITY, Vector3(0, -0.02, 0.0)), SLIPPER, 2)
		var toe := foot * Vector3(0, 0.0, -0.07)
		for s2: float in [-1.0, 1.0]:
			MeshKit.tube(st, toe + foot.basis * Vector3(0, 0.02, 0), foot * Vector3(s2 * 0.048, -0.02, 0.03), 0.008, Transform3D.IDENTITY, SLIPPER, 5)
	_part(st, self, "Legs")


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
	_place_arms()
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
	steering_wheel.transform = Transform3D(Basis(Vector3.RIGHT, WHEEL_TILT) * Basis(Vector3.UP, steer * STEER_RATIO), WHEEL_AT)


func _place_arms() -> void:
	var sides: Array[float] = [-1.0, 1.0]
	for i in range(2):
		var sx := sides[i]
		# from wherever the physics has thrown the torso, into rig space
		var shoulder: Vector3 = to_local(_torso.global_transform * (Basis(Vector3.RIGHT, 0.12) * Vector3(sx * 0.21, 0.54, 0.03)))
		# hands at ten and two on the rim, turning with the wheel; the arm
		# reaches for the wrist, just behind the grip
		var grip := Vector3(sx * WHEEL_R * 0.87, 0.0, -WHEEL_R * 0.5)
		var hand: Vector3 = steering_wheel.transform * grip
		var wrist: Vector3 = steering_wheel.transform * (grip + _wrist_offset(sx))
		var to := wrist - shoulder
		var d := clampf(to.length(), 0.05, UPPER_ARM + FOREARM - 0.005)
		var dir := to.normalized()
		# elbows hang out and down
		var pole := Vector3(sx * 0.8, -1.0, 0.2)
		pole = (pole - dir * pole.dot(dir)).normalized()
		var a := (UPPER_ARM * UPPER_ARM - FOREARM * FOREARM + d * d) / (2.0 * d)
		var h := sqrt(maxf(UPPER_ARM * UPPER_ARM - a * a, 0.0))
		var elbow := shoulder + dir * a + pole * h
		var wrist_at := shoulder + dir * d
		var parts: Array = _arms[i]
		_limb(parts[0], shoulder, elbow, pole)
		_limb(parts[1], elbow, wrist_at, pole)
		(parts[3] as MeshInstance3D).position = elbow
		(parts[2] as MeshInstance3D).transform = Transform3D(steering_wheel.transform.basis, hand)


## Stretch a limb mesh from `a` to `b`, its depth axis facing away from the
## elbow's bend (`pole`) so the biceps sits on the inside of the arm.
func _limb(mi: MeshInstance3D, a: Vector3, b: Vector3, pole: Vector3) -> void:
	var y := (b - a).normalized()
	var z := (pole - y * pole.dot(y)).normalized()
	var x := y.cross(z)
	mi.transform = Transform3D(Basis(x, y * (b - a).length(), z), a)
