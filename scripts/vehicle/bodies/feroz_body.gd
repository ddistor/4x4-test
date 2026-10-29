class_name FerozBody
extends RefCounted
## The Feroz: a boxy little 90s two-door. Flat sides in the paint picked in
## the menu over black lower cladding, a pinstripe along the flanks, chunky
## black plastic flares round squared-off arches, rectangular lamps in a
## slatted grille, a raked windshield and the stepped-up rear roof over the
## big quarter windows. Spare on the back door, winch bumper. On 31s.
## Rig space: forward -Z, left -X, wheel hubs at y~0.13.

const SILL := 0.5
const CLAD := 0.64      # top of the black lower cladding
const BELT := 1.04
const ROOF := 1.7
const STEP := 0.06      # how far the rear roof steps up
const STEP_Z := 0.42    # where it does
const HALF_W := 0.74
const COWL_Z := -0.5
const TAIL_Z := 1.62
const NOSE_Z := -1.72
const STRIPE := Color(0.82, 0.82, 0.8)


static func build(rig: Rig) -> void:
	BodyKit.collide(rig, NOSE_Z, TAIL_Z, 0.48, 1.04, HALF_W)   # body and nose
	for col: Array in [
		[Vector3(1.46, 0.68, 2.1), Vector3(0, 1.38, 0.55)],    # cab
		[Vector3(1.64, 0.15, 0.15), Vector3(0, 0.58, -1.84)],  # bumper
	]:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = col[0]
		cs.shape = box
		cs.position = col[1]
		rig.add_child(cs)

	var paint := MeshKit.begin()
	var plastic := MeshKit.begin()   # flares, cladding, bumpers: textured black
	var stripe := MeshKit.begin()
	var bright := MeshKit.begin()
	var chassis := MeshKit.begin()
	var trim := MeshKit.begin()
	var c := Color.WHITE
	var at := func(p: Vector3) -> Transform3D: return Transform3D(Basis.IDENTITY, p)
	var rb := func(st: SurfaceTool, size: Vector3, r: float, xf: Transform3D) -> void:
		MeshKit.rounded_box(st, size, r, xf, c)
	var fz := rig.spec.front_z
	var rz := rig.spec.rear_z
	var arch := BodyKit.well_radius(rig.spec)   # big arches that clear a tire at the bump stop

	for sx: float in [-1.0, 1.0]:
		rb.call(chassis, Vector3(0.08, 0.13, 3.3), 0.01, at.call(Vector3(sx * 0.4, 0.43, -0.05)))
	for z: float in [-1.6, -0.4, 0.6, 1.5]:
		rb.call(chassis, Vector3(0.8, 0.07, 0.07), 0.01, at.call(Vector3(0, 0.43, z)))

	# body sides, nose to tail: paint above the cladding, black plastic below,
	# both with the arches cut
	BodyKit.floor_panel(paint, rig.spec, COWL_Z, TAIL_Z, HALF_W - 0.02, SILL + 0.01, c)
	for zc: float in [fz, rz]:
		BodyKit.wheel_houses(plastic, rig.spec, zc, HALF_W, SILL, c)
	for sx: float in [-1.0, 1.0]:
		var x := sx * HALF_W
		KuwarentaBody._side_panel(paint, x, NOSE_Z - 0.02, TAIL_Z, CLAD, BELT, [[fz, arch], [rz, arch]], 0.03, c)
		KuwarentaBody._side_panel(plastic, x + sx * 0.008, NOSE_Z - 0.02, TAIL_Z, SILL, CLAD, [[fz, arch], [rz, arch]], 0.03, c)
		# pinstripe along the flank, broken by the arches
		for seg: Array in [[NOSE_Z + 0.08, fz - arch - 0.04], [fz + arch + 0.04, rz - arch - 0.04], [rz + arch + 0.04, TAIL_Z - 0.03]]:
			var z0: float = seg[0]
			var z1: float = seg[1]
			if z1 - z0 < 0.05:
				continue   # no room between the nose and the arch
			rb.call(stripe, Vector3(0.01, 0.035, z1 - z0), 0.004, at.call(Vector3(x + sx * 0.004, 0.86, (z0 + z1) * 0.5)))
		# square-cut plastic flares round both arches
		for zc: float in [fz, rz]:
			_flare(plastic, x + sx * 0.03, zc, arch, c)
		# door shut line and handle, the little quarter vent behind the door
		rb.call(chassis, Vector3(0.006, BELT - SILL - 0.06, 0.008), 0.002, at.call(Vector3(x + sx * 0.004, (BELT + SILL) * 0.5, 0.45)))
		rb.call(plastic, Vector3(0.025, 0.03, 0.13), 0.01, at.call(Vector3(x + sx * 0.012, BELT - 0.1, 0.32)))
		# belt rail and mirror
		rb.call(paint, Vector3(0.05, 0.035, TAIL_Z - COWL_Z), 0.012, at.call(Vector3(x - sx * 0.01, BELT, (TAIL_Z + COWL_Z) * 0.5)))
		rb.call(plastic, Vector3(0.05, 0.13, 0.17), 0.03, at.call(Vector3(x + sx * 0.07, BELT + 0.1, COWL_Z + 0.02)))
	# the back: tailgate panel with the spare, black bumper
	rb.call(paint, Vector3(HALF_W * 2.0, BELT - CLAD, 0.04), 0.02, at.call(Vector3(0, (BELT + CLAD) * 0.5, TAIL_Z)))
	rb.call(plastic, Vector3(HALF_W * 2.0 + 0.02, CLAD - SILL, 0.05), 0.02, at.call(Vector3(0, (CLAD + SILL) * 0.5, TAIL_Z)))
	rb.call(plastic, Vector3(1.58, 0.13, 0.13), 0.03, at.call(Vector3(0, 0.56, TAIL_Z + 0.07)))
	# cowl and dash
	rb.call(paint, Vector3(HALF_W * 2.0, BELT - SILL, 0.04), 0.02, at.call(Vector3(0, (BELT + SILL) * 0.5, COWL_Z)))
	rb.call(trim, Vector3(1.38, 0.12, 0.3), 0.04, at.call(Vector3(0, BELT - 0.02, COWL_Z + 0.13)))

	# hood: short, sloping a touch to the nose
	var hood := Transform3D(Basis(Vector3.RIGHT, -0.06), Vector3(0, BELT - 0.02, (COWL_Z + NOSE_Z) * 0.5))
	rb.call(paint, Vector3(HALF_W * 2.0, 0.05, COWL_Z - NOSE_Z + 0.02), 0.025, hood)
	# nose: a flat face, slatted grille between rectangular lamps
	var face_top := BELT - 0.08
	rb.call(paint, Vector3(HALF_W * 2.0, face_top - CLAD, 0.04), 0.02, at.call(Vector3(0, (face_top + CLAD) * 0.5, NOSE_Z)))
	rb.call(plastic, Vector3(0.64, 0.2, 0.03), 0.01, at.call(Vector3(0, 0.83, NOSE_Z - 0.02)))
	for k in range(5):
		rb.call(bright, Vector3(0.6, 0.012, 0.02), 0.004, at.call(Vector3(0, 0.76 + k * 0.035, NOSE_Z - 0.035)))
	for sx: float in [-1.0, 1.0]:
		rb.call(plastic, Vector3(0.26, 0.15, 0.03), 0.015, at.call(Vector3(sx * 0.5, 0.83, NOSE_Z - 0.02)))

	# windshield, raked; the A-pillars run up to the roof
	var rake := 0.42
	var wh := (ROOF - BELT) / cos(rake)
	var ws := Transform3D(Basis(Vector3.RIGHT, rake), Vector3(0, BELT, COWL_Z + 0.02))
	for sx: float in [-1.0, 1.0]:
		rb.call(paint, Vector3(0.06, wh, 0.05), 0.015, ws * at.call(Vector3(sx * (HALF_W - 0.03), wh * 0.5, 0)))
	rb.call(paint, Vector3(HALF_W * 2.0, 0.05, 0.05), 0.015, ws * at.call(Vector3(0, 0.0, 0)))
	var roof_z0 := COWL_Z + 0.02 + sin(rake) * wh
	for sx: float in [-1.0, 1.0]:
		MeshKit.tube(chassis, ws * Vector3(sx * 0.36 - 0.24, 0.04, -0.03), ws * Vector3(sx * 0.36 + 0.12, 0.42, -0.03), 0.006, Transform3D.IDENTITY, c, 5)

	# roof: front over the seats, stepped up over the back, with the pillars
	rb.call(paint, Vector3(HALF_W * 2.0, 0.05, STEP_Z - roof_z0 + 0.04), 0.03, at.call(Vector3(0, ROOF, (STEP_Z + roof_z0) * 0.5)))
	rb.call(paint, Vector3(HALF_W * 2.0, 0.05, TAIL_Z - STEP_Z + 0.02), 0.03, at.call(Vector3(0, ROOF + STEP, (TAIL_Z + STEP_Z) * 0.5)))
	rb.call(paint, Vector3(HALF_W * 2.0, STEP + 0.04, 0.05), 0.015, at.call(Vector3(0, ROOF + STEP * 0.5, STEP_Z)))
	for sx: float in [-1.0, 1.0]:
		var x := sx * HALF_W
		rb.call(paint, Vector3(0.045, ROOF - BELT, 0.09), 0.012, at.call(Vector3(x, (ROOF + BELT) * 0.5, STEP_Z)))
		rb.call(paint, Vector3(0.045, ROOF + STEP - BELT, 0.16), 0.015, at.call(Vector3(x, (ROOF + STEP + BELT) * 0.5, TAIL_Z - 0.08)))
		rb.call(paint, Vector3(0.04, 0.04, STEP_Z - roof_z0), 0.012, at.call(Vector3(x, ROOF - 0.02, (STEP_Z + roof_z0) * 0.5)))
		rb.call(paint, Vector3(0.04, 0.04, TAIL_Z - STEP_Z), 0.012, at.call(Vector3(x, ROOF + STEP - 0.02, (TAIL_Z + STEP_Z) * 0.5)))
	for px: float in [-HALF_W + 0.05, HALF_W - 0.05]:
		rb.call(paint, Vector3(0.1, ROOF + STEP - BELT, 0.04), 0.015, at.call(Vector3(px, (ROOF + STEP + BELT) * 0.5, TAIL_Z)))
	rb.call(paint, Vector3(HALF_W * 2.0, 0.06, 0.04), 0.015, at.call(Vector3(0, ROOF + STEP - 0.03, TAIL_Z)))
	rb.call(paint, Vector3(HALF_W * 2.0, 0.05, 0.04), 0.015, at.call(Vector3(0, BELT + 0.03, TAIL_Z)))

	# seats, rear bench, column, shifters
	var seat := rig.spec.seat
	for sx: float in [-1.0, 1.0]:
		rb.call(trim, Vector3(0.44, 0.13, 0.44), 0.05, at.call(Vector3(sx * absf(seat.x), seat.y - 0.12, seat.z - 0.06)))
		rb.call(trim, Vector3(0.42, 0.58, 0.1), 0.045, Transform3D(Basis(Vector3.RIGHT, 0.17), Vector3(sx * absf(seat.x), seat.y + 0.2, seat.z + 0.2)))
	rb.call(trim, Vector3(1.24, 0.12, 0.4), 0.05, at.call(Vector3(0, 0.66, 1.15)))
	rb.call(trim, Vector3(1.24, 0.45, 0.09), 0.04, Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0, 0.95, 1.4)))
	MeshKit.tube(chassis, Vector3(seat.x, BELT - 0.08, COWL_Z + 0.05), rig.spec.wheel_at, 0.022, Transform3D.IDENTITY, c)
	MeshKit.tube(chassis, Vector3(0.02, 0.58, -0.18), Vector3(0.0, 0.96, -0.08), 0.012, Transform3D.IDENTITY, c, 6)
	MeshKit.tube(chassis, Vector3(0.1, 0.58, -0.18), Vector3(0.12, 0.9, -0.1), 0.01, Transform3D.IDENTITY, c, 6)

	# front bumper with the winch
	rb.call(plastic, Vector3(1.64, 0.14, 0.14), 0.03, at.call(Vector3(0, 0.58, -1.84)))
	MeshKit.cylinder(chassis, 0.075, 0.42, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 0.66, -1.84)), c, 16)
	for sx: float in [-1.0, 1.0]:
		MeshKit.cylinder(chassis, 0.09, 0.05, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(sx * 0.235, 0.66, -1.84)), c, 16)
		rb.call(plastic, Vector3(0.04, 0.11, 0.04), 0.01, at.call(Vector3(sx * 0.58, 0.58, -1.93)))
	rb.call(plastic, Vector3(0.2, 0.07, 0.05), 0.015, at.call(Vector3(0, 0.66, -1.92)))

	# spare on the back door, under a body-colour cover
	var spare := MeshInstance3D.new()
	rig.spare_mat = ShaderMaterial.new()
	rig.spare_mat.shader = load("res://shaders/tire.gdshader")
	spare.mesh = MeshKit.commit(RigWheel.build_wheel_mesh(rig.spec.tire_radius, rig.spec.tire_width, false), rig.spare_mat)
	spare.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.98, TAIL_Z + 0.2))
	rig.add_child(spare)
	rb.call(chassis, Vector3(0.12, 0.12, 0.12), 0.01, at.call(Vector3(0, 0.98, TAIL_Z + 0.05)))

	var chassis_mat := rig._body_mat(Color(0.05, 0.05, 0.05), 0.7, 0.2, 0.0)
	rig._add_mesh(MeshKit.commit(paint, rig.paint_mat(0.22, 0.8)))   # picked in the start menu
	rig._add_mesh(MeshKit.commit(plastic, rig._body_mat(Color(0.035, 0.035, 0.037), 0.8, 0.0, 0.0)))
	rig._add_mesh(MeshKit.commit(stripe, rig._body_mat(STRIPE, 0.3, 0.0, 0.6)))
	rig._add_mesh(MeshKit.commit(bright, rig._body_mat(Color(0.62, 0.63, 0.62), 0.32, 0.85, 0.0)))
	rig._add_mesh(MeshKit.commit(chassis, chassis_mat))
	rig._add_mesh(MeshKit.commit(trim, rig._body_mat(Color(0.07, 0.065, 0.06), 0.6, 0.0, 0.0)))

	# glass: windshield, door windows, the big quarter windows, the back
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.45, 0.52, 0.56, 0.3)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic_specular = 0.9
	var gst := MeshKit.begin()
	MeshKit.rounded_box(gst, Vector3(HALF_W * 2.0 - 0.1, wh - 0.06, 0.008), 0.02, ws * at.call(Vector3(0, wh * 0.5, 0)), c, 1)
	for sx: float in [-1.0, 1.0]:
		var x := sx * HALF_W
		var door_z0 := roof_z0 + 0.04
		var dz := STEP_Z - 0.05 - door_z0
		MeshKit.rounded_box(gst, Vector3(0.008, ROOF - BELT - 0.08, dz), 0.02, at.call(Vector3(x, (ROOF + BELT) * 0.5, door_z0 + dz * 0.5)), c, 1)
		var qz := TAIL_Z - 0.16 - STEP_Z - 0.05
		MeshKit.rounded_box(gst, Vector3(0.008, ROOF + STEP - BELT - 0.1, qz), 0.04, at.call(Vector3(x, (ROOF + STEP + BELT) * 0.5, STEP_Z + 0.05 + qz * 0.5)), c, 1)
	MeshKit.rounded_box(gst, Vector3(HALF_W * 2.0 - 0.2, ROOF + STEP - BELT - 0.12, 0.008), 0.03, at.call(Vector3(0, (ROOF + STEP + BELT) * 0.5, TAIL_Z + 0.022)), c, 1)
	rig._add_mesh(MeshKit.commit(gst, glass))
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color(0.95, 0.93, 0.85)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.92, 0.7)
	lamp.emission_energy_multiplier = 1.1
	lamp.roughness = 0.1
	var lst := MeshKit.begin()
	for sx: float in [-1.0, 1.0]:
		MeshKit.rounded_box(lst, Vector3(0.2, 0.1, 0.02), 0.012, at.call(Vector3(sx * 0.5, 0.84, NOSE_Z - 0.04)), c, 2)
	rig._add_mesh(MeshKit.commit(lst, lamp))
	var amber := StandardMaterial3D.new()
	amber.albedo_color = Color(0.9, 0.5, 0.08)
	amber.emission_enabled = true
	amber.emission = Color(0.9, 0.45, 0.05)
	amber.emission_energy_multiplier = 0.3
	var ast := MeshKit.begin()
	for sx: float in [-1.0, 1.0]:
		MeshKit.rounded_box(ast, Vector3(0.1, 0.05, 0.02), 0.01, at.call(Vector3(sx * 0.6, 0.7, NOSE_Z - 0.03)), c, 2)
	rig._add_mesh(MeshKit.commit(ast, amber))
	var tail := StandardMaterial3D.new()
	tail.albedo_color = Color(0.5, 0.03, 0.02)
	tail.emission_enabled = true
	tail.emission = Color(0.8, 0.05, 0.02)
	tail.emission_energy_multiplier = 0.4
	var tst := MeshKit.begin()
	for sx: float in [-1.0, 1.0]:
		MeshKit.rounded_box(tst, Vector3(0.07, 0.24, 0.03), 0.012, at.call(Vector3(sx * (HALF_W - 0.05), 0.86, TAIL_Z + 0.03)), c, 2)
	rig._add_mesh(MeshKit.commit(tst, tail))



## A square-cut plastic flare round an arch on the side at `x`: two short
## legs and a flat top, standing proud of the body.
static func _flare(st: SurfaceTool, x: float, zc: float, r: float, col: Color) -> void:
	var hub := KuwarentaBody.HUB_Y
	var top := hub + r * 0.92
	var low := SILL + 0.02
	var pts := PackedVector3Array([
		Vector3(x, low, zc - r * 1.02), Vector3(x, hub + r * 0.55, zc - r * 0.98),
		Vector3(x, top, zc - r * 0.62), Vector3(x, top + 0.01, zc),
		Vector3(x, top, zc + r * 0.62), Vector3(x, hub + r * 0.55, zc + r * 0.98),
		Vector3(x, low, zc + r * 1.02)])
	var radii := PackedFloat32Array()
	for i in pts.size():
		radii.append(0.045)
	MeshKit.sweep(st, pts, radii, Transform3D.IDENTITY, col, 8)
