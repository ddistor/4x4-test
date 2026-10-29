class_name RondaBody
extends RefCounted
## The Ronda: a big four-door wagon. Long hood with a raised centre, flat
## sides in the paint picked in the menu, four doors and rear quarter
## windows, big black flares, rectangular lamps either side of a barred
## grille, a snorkel up the right A-pillar, roof rack, side steps, the spare
## on the back door and a winch bumper. Lifted on 35s. No badges.
## Rig space: forward -Z, left -X, wheel hubs at y~0.13.

const SILL := 0.55
const BELT := 1.18
const ROOF := 1.98
const HALF_W := 0.92
const COWL_Z := -0.78
const TAIL_Z := 2.24
const NOSE_Z := -2.36
const B_Z := 0.36       # front door shut line / B-pillar
const C_Z := 1.24       # rear door shut line / C-pillar
const HUB_Y := 0.13


static func build(rig: Rig) -> void:
	BodyKit.collide(rig, NOSE_Z, TAIL_Z, 0.55, 1.19, HALF_W)   # body and nose
	for col: Array in [
		[Vector3(1.82, 0.8, 3.0), Vector3(0, 1.58, 0.74)],      # cab
		[Vector3(1.96, 0.18, 0.18), Vector3(0, 0.62, -2.46)],   # bumper
	]:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = col[0]
		cs.shape = box
		cs.position = col[1]
		rig.add_child(cs)

	var paint := MeshKit.begin()
	var plastic := MeshKit.begin()   # flares, steps, bumpers, snorkel, rack
	var bright := MeshKit.begin()
	var chassis := MeshKit.begin()
	var trim := MeshKit.begin()
	var c := Color.WHITE
	var at := func(p: Vector3) -> Transform3D: return Transform3D(Basis.IDENTITY, p)
	var rb := func(st: SurfaceTool, size: Vector3, r: float, xf: Transform3D) -> void:
		MeshKit.rounded_box(st, size, r, xf, c)
	var fz := rig.spec.front_z
	var rz := rig.spec.rear_z
	var arch := BodyKit.well_radius(rig.spec)   # clears a tire at the bump stop

	for sx: float in [-1.0, 1.0]:
		rb.call(chassis, Vector3(0.09, 0.16, 4.3), 0.01, at.call(Vector3(sx * 0.46, 0.46, -0.06)))
	for z: float in [-2.1, -0.8, 0.4, 1.5, 2.1]:
		rb.call(chassis, Vector3(0.92, 0.08, 0.08), 0.01, at.call(Vector3(0, 0.46, z)))

	# body sides, nose to tail, both arches cut; floor, cowl, tail panel
	BodyKit.floor_panel(paint, rig.spec, COWL_Z, TAIL_Z, HALF_W - 0.03, SILL + 0.01, c)
	for zc: float in [fz, rz]:
		BodyKit.wheel_houses(plastic, rig.spec, zc, HALF_W, SILL, c)
	for sx: float in [-1.0, 1.0]:
		var x := sx * HALF_W
		KuwarentaBody._side_panel(paint, x, NOSE_Z - 0.02, TAIL_Z, SILL, BELT, [[fz, arch], [rz, arch]], 0.035, c)
		for zc: float in [fz, rz]:
			_flare(plastic, x + sx * 0.035, zc, arch, c)
		# door shut lines and handles
		for z: float in [COWL_Z + 0.02, B_Z, C_Z]:
			rb.call(chassis, Vector3(0.006, BELT - SILL - 0.08, 0.008), 0.002, at.call(Vector3(x + sx * 0.004, (BELT + SILL) * 0.5 + 0.02, z)))
		for z: float in [B_Z - 0.16, C_Z - 0.16]:
			rb.call(plastic, Vector3(0.025, 0.03, 0.14), 0.01, at.call(Vector3(x + sx * 0.012, BELT - 0.1, z)))
		# side step between the arches
		MeshKit.tube(plastic, Vector3(x - sx * 0.02, SILL - 0.06, fz + arch + 0.06), Vector3(x - sx * 0.02, SILL - 0.06, rz - arch - 0.06), 0.035, Transform3D.IDENTITY, c, 10)
		for z: float in [fz + arch + 0.25, rz - arch - 0.25]:
			MeshKit.tube(plastic, Vector3(x - sx * 0.02, SILL - 0.06, z), Vector3(x - sx * 0.25, SILL - 0.04, z), 0.025, Transform3D.IDENTITY, c, 8)
		# body-colour belt rail and the door mirror
		rb.call(paint, Vector3(0.05, 0.035, TAIL_Z - COWL_Z), 0.012, at.call(Vector3(x - sx * 0.01, BELT, (TAIL_Z + COWL_Z) * 0.5)))
		rb.call(plastic, Vector3(0.06, 0.16, 0.22), 0.035, at.call(Vector3(x + sx * 0.09, BELT + 0.12, COWL_Z + 0.08)))
	rb.call(paint, Vector3(HALF_W * 2.0, BELT - SILL, 0.04), 0.02, at.call(Vector3(0, (BELT + SILL) * 0.5, TAIL_Z)))
	rb.call(paint, Vector3(HALF_W * 2.0, BELT - SILL, 0.04), 0.02, at.call(Vector3(0, (BELT + SILL) * 0.5, COWL_Z)))
	rb.call(trim, Vector3(1.7, 0.14, 0.34), 0.04, at.call(Vector3(0, BELT - 0.02, COWL_Z + 0.15)))

	# hood: long, a raised centre, a touch of slope to the nose
	var hood := Transform3D(Basis(Vector3.RIGHT, -0.04), Vector3(0, BELT - 0.02, (COWL_Z + NOSE_Z) * 0.5))
	rb.call(paint, Vector3(HALF_W * 2.0, 0.05, COWL_Z - NOSE_Z + 0.02), 0.03, hood)
	rb.call(paint, Vector3(0.9, 0.04, COWL_Z - NOSE_Z - 0.3), 0.02, hood * at.call(Vector3(0, 0.035, 0.05)))
	# nose: flat face, barred grille between big rectangular lamps
	var face_top := BELT - 0.07
	rb.call(paint, Vector3(HALF_W * 2.0, face_top - SILL - 0.08, 0.04), 0.02, at.call(Vector3(0, (face_top + SILL + 0.08) * 0.5, NOSE_Z)))
	rb.call(bright, Vector3(0.72, 0.26, 0.03), 0.012, at.call(Vector3(0, 0.95, NOSE_Z - 0.02)))
	for k in range(4):
		rb.call(chassis, Vector3(0.66, 0.03, 0.02), 0.006, at.call(Vector3(0, 0.87 + k * 0.055, NOSE_Z - 0.035)))
	for sx: float in [-1.0, 1.0]:
		rb.call(plastic, Vector3(0.36, 0.2, 0.03), 0.015, at.call(Vector3(sx * 0.58, 0.97, NOSE_Z - 0.02)))

	# windshield, raked, with its frame
	var rake := 0.32
	var wh := (ROOF - BELT) / cos(rake)
	var ws := Transform3D(Basis(Vector3.RIGHT, rake), Vector3(0, BELT, COWL_Z + 0.02))
	for sx: float in [-1.0, 1.0]:
		rb.call(paint, Vector3(0.07, wh, 0.05), 0.015, ws * at.call(Vector3(sx * (HALF_W - 0.035), wh * 0.5, 0)))
	rb.call(paint, Vector3(HALF_W * 2.0, 0.05, 0.05), 0.015, ws * at.call(Vector3(0, 0.0, 0)))
	var roof_z0 := COWL_Z + 0.02 + sin(rake) * wh
	for sx: float in [-1.0, 1.0]:
		MeshKit.tube(chassis, ws * Vector3(sx * 0.45 - 0.3, 0.04, -0.03), ws * Vector3(sx * 0.45 + 0.14, 0.5, -0.03), 0.006, Transform3D.IDENTITY, c, 5)

	# roof and pillars (B, C, and the wide D at the back), roof rack
	rb.call(paint, Vector3(HALF_W * 2.0, 0.05, TAIL_Z - roof_z0 + 0.03), 0.03, at.call(Vector3(0, ROOF, (TAIL_Z + roof_z0) * 0.5)))
	for sx: float in [-1.0, 1.0]:
		var x := sx * HALF_W
		for p: Array in [[B_Z, 0.1], [C_Z, 0.1], [TAIL_Z - 0.1, 0.2]]:
			rb.call(paint, Vector3(0.045, ROOF - BELT, float(p[1])), 0.014, at.call(Vector3(x, (ROOF + BELT) * 0.5, float(p[0]))))
		rb.call(paint, Vector3(0.045, 0.045, TAIL_Z - roof_z0), 0.012, at.call(Vector3(x, ROOF - 0.025, (TAIL_Z + roof_z0) * 0.5)))
		# rack side rail on its feet
		var rail_y := ROOF + 0.12
		MeshKit.tube(plastic, Vector3(x - sx * 0.06, rail_y, roof_z0 + 0.15), Vector3(x - sx * 0.06, rail_y, TAIL_Z - 0.1), 0.022, Transform3D.IDENTITY, c, 8)
		for z: float in [roof_z0 + 0.2, 0.8, TAIL_Z - 0.15]:
			MeshKit.tube(plastic, Vector3(x - sx * 0.06, ROOF + 0.02, z), Vector3(x - sx * 0.06, rail_y, z), 0.016, Transform3D.IDENTITY, c, 6)
	for z: float in [roof_z0 + 0.25, 0.4, 1.0, 1.6, TAIL_Z - 0.2]:
		MeshKit.tube(plastic, Vector3(-HALF_W + 0.06, ROOF + 0.12, z), Vector3(HALF_W - 0.06, ROOF + 0.12, z), 0.016, Transform3D.IDENTITY, c, 6)
	# the back door frame round its window
	for px: float in [-HALF_W + 0.1, HALF_W - 0.1]:
		rb.call(paint, Vector3(0.18, ROOF - BELT, 0.04), 0.015, at.call(Vector3(px, (ROOF + BELT) * 0.5, TAIL_Z)))
	rb.call(paint, Vector3(HALF_W * 2.0, 0.08, 0.04), 0.015, at.call(Vector3(0, ROOF - 0.04, TAIL_Z)))
	rb.call(paint, Vector3(HALF_W * 2.0, 0.06, 0.04), 0.015, at.call(Vector3(0, BELT + 0.03, TAIL_Z)))

	# snorkel: up the right front fender and A-pillar, intake head facing forward
	var sn0 := Vector3(HALF_W + 0.07, BELT - 0.18, COWL_Z - 0.25)
	var sn1 := Vector3(HALF_W + 0.07, BELT + 0.02, COWL_Z - 0.08)
	var sn2 := ws * Vector3(HALF_W + 0.07, wh + 0.12, -0.02)
	MeshKit.sweep(plastic, PackedVector3Array([sn0, sn1, sn1.lerp(sn2, 0.5), sn2]), PackedFloat32Array([0.05, 0.048, 0.045, 0.045]), Transform3D.IDENTITY, c, 12)
	rb.call(plastic, Vector3(0.13, 0.13, 0.2), 0.05, at.call(sn2 + Vector3(0, 0.04, -0.06)))

	# seats, rear bench, column, shifters
	var seat := rig.spec.seat
	for sx: float in [-1.0, 1.0]:
		rb.call(trim, Vector3(0.48, 0.14, 0.48), 0.05, at.call(Vector3(sx * absf(seat.x), seat.y - 0.12, seat.z - 0.06)))
		rb.call(trim, Vector3(0.46, 0.62, 0.11), 0.045, Transform3D(Basis(Vector3.RIGHT, 0.16), Vector3(sx * absf(seat.x), seat.y + 0.22, seat.z + 0.22)))
	rb.call(trim, Vector3(1.5, 0.14, 0.46), 0.05, at.call(Vector3(0, 0.76, 0.95)))
	rb.call(trim, Vector3(1.5, 0.55, 0.1), 0.04, Transform3D(Basis(Vector3.RIGHT, 0.14), Vector3(0, 1.08, 1.22)))
	MeshKit.tube(chassis, Vector3(seat.x, BELT - 0.08, COWL_Z + 0.06), rig.spec.wheel_at, 0.024, Transform3D.IDENTITY, c)
	MeshKit.tube(chassis, Vector3(0.02, 0.66, -0.36), Vector3(0.0, 1.06, -0.24), 0.013, Transform3D.IDENTITY, c, 6)
	MeshKit.tube(chassis, Vector3(0.11, 0.66, -0.36), Vector3(0.13, 1.0, -0.26), 0.011, Transform3D.IDENTITY, c, 6)

	# bumpers: winch bar up front, black bar at the back
	rb.call(plastic, Vector3(1.96, 0.18, 0.18), 0.03, at.call(Vector3(0, 0.62, -2.46)))
	MeshKit.cylinder(chassis, 0.085, 0.48, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 0.74, -2.47)), c, 16)
	for sx: float in [-1.0, 1.0]:
		MeshKit.cylinder(chassis, 0.1, 0.06, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(sx * 0.27, 0.74, -2.47)), c, 16)
		rb.call(plastic, Vector3(0.045, 0.13, 0.045), 0.01, at.call(Vector3(sx * 0.7, 0.62, -2.57)))
	rb.call(plastic, Vector3(0.24, 0.08, 0.05), 0.015, at.call(Vector3(0, 0.74, -2.56)))
	rb.call(plastic, Vector3(1.9, 0.15, 0.15), 0.03, at.call(Vector3(0, 0.6, TAIL_Z + 0.08)))

	# spare on the back door
	var spare := MeshInstance3D.new()
	rig.spare_mat = ShaderMaterial.new()
	rig.spare_mat.shader = load("res://shaders/tire.gdshader")
	spare.mesh = MeshKit.commit(RigWheel.build_wheel_mesh(rig.spec.tire_radius, rig.spec.tire_width, false), rig.spare_mat)
	spare.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.25, 1.1, TAIL_Z + 0.22))
	rig.add_child(spare)
	rb.call(chassis, Vector3(0.12, 0.12, 0.12), 0.01, at.call(Vector3(0.25, 1.1, TAIL_Z + 0.05)))

	var chassis_mat := rig._body_mat(Color(0.05, 0.05, 0.05), 0.7, 0.2, 0.0)
	rig._add_mesh(MeshKit.commit(paint, rig.paint_mat(0.22, 0.8)))   # picked in the start menu
	rig._add_mesh(MeshKit.commit(plastic, rig._body_mat(Color(0.035, 0.035, 0.037), 0.75, 0.0, 0.0)))
	rig._add_mesh(MeshKit.commit(bright, rig._body_mat(Color(0.62, 0.63, 0.62), 0.32, 0.85, 0.0)))
	rig._add_mesh(MeshKit.commit(chassis, chassis_mat))
	rig._add_mesh(MeshKit.commit(trim, rig._body_mat(Color(0.07, 0.065, 0.06), 0.6, 0.0, 0.0)))

	# glass: windshield, four door windows, rear quarters, the back door
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.4, 0.46, 0.5, 0.32)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic_specular = 0.9
	var gst := MeshKit.begin()
	MeshKit.rounded_box(gst, Vector3(HALF_W * 2.0 - 0.12, wh - 0.07, 0.008), 0.02, ws * at.call(Vector3(0, wh * 0.5, 0)), c, 1)
	var wy := (ROOF + BELT) * 0.5
	var wh2 := ROOF - BELT - 0.1
	for sx: float in [-1.0, 1.0]:
		var x := sx * HALF_W
		for seg: Array in [[roof_z0 + 0.06, B_Z - 0.06], [B_Z + 0.06, C_Z - 0.06], [C_Z + 0.06, TAIL_Z - 0.21]]:
			var z0: float = seg[0]
			var z1: float = seg[1]
			MeshKit.rounded_box(gst, Vector3(0.008, wh2, z1 - z0), 0.03, at.call(Vector3(x, wy, (z0 + z1) * 0.5)), c, 1)
	MeshKit.rounded_box(gst, Vector3(HALF_W * 2.0 - 0.38, wh2 - 0.04, 0.008), 0.03, at.call(Vector3(0, wy, TAIL_Z + 0.022)), c, 1)
	rig._add_mesh(MeshKit.commit(gst, glass))
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color(0.95, 0.93, 0.85)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.92, 0.7)
	lamp.emission_energy_multiplier = 1.1
	lamp.roughness = 0.1
	var lst := MeshKit.begin()
	for sx: float in [-1.0, 1.0]:
		MeshKit.rounded_box(lst, Vector3(0.3, 0.15, 0.02), 0.015, at.call(Vector3(sx * 0.58, 0.97, NOSE_Z - 0.04)), c, 2)
	rig._add_mesh(MeshKit.commit(lst, lamp))
	var amber := StandardMaterial3D.new()
	amber.albedo_color = Color(0.9, 0.5, 0.08)
	amber.emission_enabled = true
	amber.emission = Color(0.9, 0.45, 0.05)
	amber.emission_energy_multiplier = 0.3
	var ast := MeshKit.begin()
	for sx: float in [-1.0, 1.0]:
		MeshKit.rounded_box(ast, Vector3(0.05, 0.16, 0.1), 0.012, at.call(Vector3(sx * (HALF_W - 0.02), 0.97, NOSE_Z + 0.03)), c, 2)
	rig._add_mesh(MeshKit.commit(ast, amber))
	var tail := StandardMaterial3D.new()
	tail.albedo_color = Color(0.5, 0.03, 0.02)
	tail.emission_enabled = true
	tail.emission = Color(0.8, 0.05, 0.02)
	tail.emission_energy_multiplier = 0.4
	var tst := MeshKit.begin()
	for sx: float in [-1.0, 1.0]:
		MeshKit.rounded_box(tst, Vector3(0.12, 0.3, 0.03), 0.015, at.call(Vector3(sx * (HALF_W - 0.1), 1.3, TAIL_Z + 0.03)), c, 2)
	rig._add_mesh(MeshKit.commit(tst, tail))



## A big rounded-square flare round an arch on the side at `x`.
static func _flare(st: SurfaceTool, x: float, zc: float, r: float, col: Color) -> void:
	var low := SILL + 0.02
	var top := HUB_Y + r * 0.95
	var pts := PackedVector3Array([
		Vector3(x, low, zc - r * 1.04), Vector3(x, HUB_Y + r * 0.6, zc - r * 1.0),
		Vector3(x, top - 0.03, zc - r * 0.72), Vector3(x, top, zc - r * 0.3), Vector3(x, top, zc + r * 0.3),
		Vector3(x, top - 0.03, zc + r * 0.72), Vector3(x, HUB_Y + r * 0.6, zc + r * 1.0),
		Vector3(x, low, zc + r * 1.04)])
	var radii := PackedFloat32Array()
	for i in pts.size():
		radii.append(0.055)
	MeshKit.sweep(st, pts, radii, Transform3D.IDENTITY, col, 8)
