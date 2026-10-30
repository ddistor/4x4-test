class_name Armor
extends RefCounted
## Career armor bolted onto a body that wasn't built with it: skid plates,
## rock sliders, a roll bar or cage, a snorkel. One shape for every rig,
## sized from the body's own collision boxes (sill line, belly) and its
## cabin box, so it sits on any of them. Satin black steel. The skid plate
## and sliders are solid: they're what touches the rock.

const STEEL := Color(0.035, 0.035, 0.037)
## The drivetrain under the floor, every rig: oil pan behind the front axle
## back to the transfer case (rig.gd's driveshafts meet at its 0.38). It
## hangs on the frame, so a lift and bigger tires raise it off the ground.
const TCASE_Z := -0.15
const UNDER_BOTTOM := 0.26     # rig space: about 0.55 m off the ground on stock rigs
const UNDER_HALF := 0.3


## Where the underbody sits: [z front, z back].
static func under_z(s: RigSpec) -> Vector2:
	return Vector2(s.front_z + s.tire_radius * 0.6, TCASE_Z + 0.25)


## Oil pan, transmission and transfer case as one solid under the floor, and
## a plain dark mesh of them. Before the wheels, after the body.
static func underbody(rig: Rig) -> void:
	var s := rig.spec
	var sl := sill(rig)
	var z := under_z(s)
	var top := maxf(sl.y, UNDER_BOTTOM + 0.1)
	# its front edge chamfered, like the bell housing and pan really are: a
	# rock rides up under it instead of meeting a square face
	var cs := CollisionShape3D.new()
	cs.name = "Armor"
	var hull := ConvexPolygonShape3D.new()
	var lo := UNDER_BOTTOM
	var ch := minf(0.2, top - lo)
	var pts := PackedVector3Array()
	for sx: float in [-UNDER_HALF, UNDER_HALF]:
		pts.append_array([Vector3(sx, lo, z.y), Vector3(sx, top, z.y), Vector3(sx, top, z.x),
			Vector3(sx, lo + ch, z.x), Vector3(sx, lo, z.x + ch)])
	hull.points = pts
	cs.shape = hull
	rig.add_child(cs, true)
	var st := MeshKit.begin()
	var c := Color(0.06, 0.055, 0.05)
	# the oil pan, the gearbox tapering back, the transfer case
	MeshKit.rounded_box(st, Vector3(0.42, 0.16, 0.5), 0.04, Transform3D(Basis.IDENTITY, Vector3(0, UNDER_BOTTOM + 0.08, z.x + 0.28)), c)
	MeshKit.rounded_box(st, Vector3(0.3, 0.2, z.y - z.x - 0.7), 0.05, Transform3D(Basis.IDENTITY, Vector3(0, UNDER_BOTTOM + 0.14, (z.x + 0.55 + z.y - 0.15) * 0.5)), c)
	MeshKit.rounded_box(st, Vector3(0.5, 0.22, 0.3), 0.05, Transform3D(Basis.IDENTITY, Vector3(0, UNDER_BOTTOM + 0.11, TCASE_Z)), c)
	rig._add_mesh(MeshKit.commit(st, rig._body_mat(c, 0.7, 0.3, 0.0)))


## Where the body's sills are: [half width, lowest y] of the body's collision
## boxes between the wheels. Call after the body is built, before the wheels.
static func sill(rig: Rig) -> Vector2:
	var s := rig.spec
	var z0 := s.front_z + s.tire_radius
	var z1 := s.rear_z - s.tire_radius
	var half := 0.0
	var low := 9.0
	for c in rig.get_children():
		var cs := c as CollisionShape3D
		if cs == null or not cs.shape is BoxShape3D or cs.name.begins_with("Armor"):
			continue
		var size: Vector3 = (cs.shape as BoxShape3D).size
		var p := cs.position
		if p.z + size.z * 0.5 < z0 or p.z - size.z * 0.5 > z1:
			continue
		low = minf(low, p.y - size.y * 0.5)
		half = maxf(half, absf(p.x) + size.x * 0.5)
	if low > 8.0:
		return Vector2(s.track, s.ride_hub_y() + 0.35)
	return Vector2(half, low)


static func build(rig: Rig) -> void:
	var s := rig.spec
	var add_cage := s.cage > s.cage_built
	var add_sliders := s.sliders and not s.sliders_built
	if not (s.skid or add_sliders or add_cage or s.intake_depth > 1.0):
		return
	var sl := sill(rig)
	var st := MeshKit.begin()
	var c := STEEL
	var zf := s.front_z + s.tire_radius + 0.08    # just behind the front tires
	var zr := s.rear_z - s.tire_radius - 0.08     # just ahead of the rear ones
	if s.skid:
		# under the oil pan (behind the front axle) back past the transfer case
		var w := minf(0.8, (s.tire_inner() - 0.05) * 2.0)
		var uz := under_z(s)
		var z0 := uz.x - 0.05
		var z1 := uz.y + 0.05
		var y := UNDER_BOTTOM - 0.012
		MeshKit.rounded_box(st, Vector3(w, 0.012, z1 - z0), 0.004, Transform3D(Basis.IDENTITY, Vector3(0, y, (z0 + z1) * 0.5)), c)
		# the front lip turns up, so it rides up onto a rock rather than catching
		MeshKit.rounded_box(st, Vector3(w, 0.012, 0.14), 0.004,
			Transform3D(Basis(Vector3.RIGHT, deg_to_rad(35.0)), Vector3(0, y + 0.04, z0 - 0.055)), c)
		_solid(rig, Vector3(w, 0.03, z1 - z0 + 0.1), Vector3(0, y, (z0 + z1) * 0.5 - 0.05))
	if add_sliders:
		var x := sl.x + 0.05
		var y := sl.y + 0.05
		for sx: float in [-1.0, 1.0]:
			MeshKit.tube(st, Vector3(sx * x, y, zf), Vector3(sx * x, y, zr), 0.03, Transform3D.IDENTITY, c, 10)
			for z: float in [zf + 0.06, (zf + zr) * 0.5, zr - 0.06]:
				MeshKit.tube(st, Vector3(sx * x, y, z), Vector3(sx * (sl.x - 0.3), sl.y - 0.02, z), 0.02, Transform3D.IDENTITY, c, 8)
			_solid(rig, Vector3(0.08, 0.08, zr - zf), Vector3(sx * x, y, (zf + zr) * 0.5))
	if add_cage:
		_cage(rig, st, sl)
	if s.intake_depth > 1.0:
		# out on the right fender and up the windshield pillar to the roof
		# line, a ram head on top facing forward
		var x := maxf(sl.x, s.cabin_hi.x) + 0.04
		var front := s.cabin_lo.z if s.cabin_hi.x > 0.0 else s.seat.z - 0.6
		var top := minf((s.cabin_hi.y if s.cabin_hi.x > 0.0 else 1.8) - 0.15, 1.75)
		var a := Vector3(x, 0.85, front - 0.25)
		var b := Vector3(x + 0.03, top, front + 0.05)
		MeshKit.tube(st, a, b, 0.045, Transform3D.IDENTITY, c, 12)
		MeshKit.rounded_box(st, Vector3(0.1, 0.1, 0.16), 0.03, Transform3D(Basis.IDENTITY, b + Vector3(0, 0.05, -0.04)), c)
	var m := rig._body_mat(STEEL, 0.55, 0.4, 0.0)
	rig._add_mesh(MeshKit.commit(st, m))


## A roll bar (a hoop behind the seats) or a full cage (front hoop at the
## windshield too, joined over the top), inside the cabin box or, with no
## box, round the seats. A collision box over its top: on its roof the rig
## rests on the cage.
static func _cage(rig: Rig, st: SurfaceTool, sl: Vector2) -> void:
	var s := rig.spec
	var has_box := s.cabin_hi.x > 0.0
	var x := (s.cabin_hi.x - 0.07) if has_box else minf(sl.x - 0.08, 0.72)
	var floor_y := (s.cabin_lo.y + 0.02) if has_box else s.seat.y - 0.2
	# a closed cab's cage sits just under the roof; an open tub's stands a
	# helmet clear over the driver
	var top := (s.cabin_hi.y - 0.08) if s.closed() else minf(s.seat.y + 1.15, (s.cabin_hi.y if has_box else 2.2) - 0.1)
	var z_main := s.seat.z + 0.38
	var z_front := (s.cabin_lo.z + 0.12) if has_box else s.seat.z - 0.75
	var c := STEEL
	var bars: Array = []
	for sx: float in [-1.0, 1.0]:
		bars.append([Vector3(sx * x, floor_y, z_main), Vector3(sx * x, top, z_main)])
	bars.append([Vector3(-x, top, z_main), Vector3(x, top, z_main)])
	bars.append([Vector3(-x, floor_y + 0.25, z_main), Vector3(x, top - 0.05, z_main)])   # diagonal brace
	if s.cage >= 2:
		for sx: float in [-1.0, 1.0]:
			bars.append([Vector3(sx * x, floor_y, z_front), Vector3(sx * x, top - 0.04, z_front + 0.18)])
			bars.append([Vector3(sx * x, top - 0.04, z_front + 0.18), Vector3(sx * x, top, z_main)])
			# back bars down to the tail
			bars.append([Vector3(sx * x, top, z_main), Vector3(sx * x, floor_y + 0.1, minf(z_main + 0.9, s.cabin_hi.z - 0.1) if has_box else z_main + 0.8)])
		bars.append([Vector3(-x, top - 0.04, z_front + 0.18), Vector3(x, top - 0.04, z_front + 0.18)])
	for b: Array in bars:
		MeshKit.tube(st, b[0], b[1], 0.026, Transform3D.IDENTITY, c, 10)
	var z0 := (z_front + 0.18) if s.cage >= 2 else z_main - 0.05
	_solid(rig, Vector3(x * 2.0 + 0.06, 0.08, z_main - z0 + 0.1), Vector3(0, top, (z0 + z_main) * 0.5))


## A collision box that isn't the body's own (named so sill() leaves it out).
static func _solid(rig: Rig, size: Vector3, at: Vector3) -> void:
	var cs := CollisionShape3D.new()
	cs.name = "Armor"
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = at
	rig.add_child(cs, true)
