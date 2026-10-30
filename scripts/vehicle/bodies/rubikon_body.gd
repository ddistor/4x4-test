class_name RubikonBody
extends RefCounted
## The Rubikon: a modern four-door trail rig. Body in the paint picked in the
## menu with a black removable-style hardtop, round lamps in a body-colour
## grille of nine slots, big black trapezoid flares, a long hood with vents,
## exposed door hinges, rock sliders, a steel winch bumper and the spare on
## the tailgate. On 35s. No badges.
## Rig space: forward -Z, left -X, wheel hubs at y~0.13.

const SILL := 0.55
const BELT := 1.2
const ROOF := 1.96
const HALF_W := 0.88
const COWL_Z := -0.76
const TAIL_Z := 2.2
const NOSE_Z := -2.3
const HOOD_Y := 1.16
const B_Z := 0.32
const C_Z := 1.22


static func build(rig: Rig) -> void:
	var spec := rig.spec
	BodyKit.collide(rig, NOSE_Z, TAIL_Z, SILL, BELT, HALF_W)
	BodyKit._box(rig, Vector3(1.74, 0.74, 2.9), Vector3(0, 1.58, 0.72))    # cab
	BodyKit._box(rig, Vector3(1.94, 0.18, 0.2), Vector3(0, 0.62, -2.4))    # bumper

	var paint := MeshKit.begin()
	var top := MeshKit.begin()       # black hardtop
	var plastic := MeshKit.begin()   # flares, bumpers, sliders, hinges
	var chassis := MeshKit.begin()
	var trim := MeshKit.begin()
	var c := Color.WHITE
	var at := func(p: Vector3) -> Transform3D: return Transform3D(Basis.IDENTITY, p)
	var rb := func(st: SurfaceTool, size: Vector3, r: float, xf: Transform3D) -> void:
		MeshKit.rounded_box(st, size, r, xf, c)
	var fz := spec.front_z
	var rz := spec.rear_z
	var arch := BodyKit.well_radius(spec)

	for sx: float in [-1.0, 1.0]:
		rb.call(chassis, Vector3(0.09, 0.16, 4.3), 0.01, at.call(Vector3(sx * 0.45, 0.46, -0.05)))
	for z: float in [-2.05, -0.8, 0.35, 1.5, 2.05]:
		rb.call(chassis, Vector3(0.9, 0.08, 0.08), 0.01, at.call(Vector3(0, 0.46, z)))

	# body tub: floor, wells, sides with both arches, the four door lines
	BodyKit.floor_panel(paint, spec, COWL_Z, TAIL_Z, HALF_W - 0.03, SILL + 0.01, c)
	for zc: float in [fz, rz]:
		BodyKit.wheel_houses(plastic, spec, zc, HALF_W, SILL, c)
	for sx: float in [-1.0, 1.0]:
		var x := sx * HALF_W
		KuwarentaBody._side_panel(paint, x, COWL_Z, TAIL_Z, SILL, BELT, [[rz, arch]], 0.035, c)
		for z: float in [COWL_Z + 0.02, B_Z, C_Z]:
			# the line stops at the arch: never across the wheel opening
			var y0 := SILL + 0.03
			for zc: float in [fz, rz]:
				if absf(z - zc) < arch:
					y0 = maxf(y0, RigSpec.RIDE_HUB_Y + sqrt(arch * arch - (z - zc) * (z - zc)) + 0.03)
			rb.call(chassis, Vector3(0.006, BELT - 0.03 - y0, 0.008), 0.002, at.call(Vector3(x + sx * 0.004, (BELT - 0.03 + y0) * 0.5, z)))
		# exposed hinges at the front edge of each door, handles at the back
		for z: float in [COWL_Z + 0.06, B_Z + 0.06]:
			for y: float in [0.78, 1.08]:
				rb.call(plastic, Vector3(0.03, 0.06, 0.05), 0.01, at.call(Vector3(x + sx * 0.02, y, z)))
		for z: float in [B_Z - 0.12, C_Z - 0.12]:
			rb.call(plastic, Vector3(0.025, 0.03, 0.12), 0.01, at.call(Vector3(x + sx * 0.012, BELT - 0.1, z)))
		# rock slider along the sill between the arches
		MeshKit.tube(plastic, Vector3(x + sx * 0.02, SILL - 0.04, fz + arch + 0.05), Vector3(x + sx * 0.02, SILL - 0.04, rz - arch - 0.05), 0.04, Transform3D.IDENTITY, c, 10)
		# trapezoid flares, front and rear
		for zc: float in [fz, rz]:
			_flare(plastic, x + sx * 0.06, zc, arch, c)
		rb.call(plastic, Vector3(0.06, 0.18, 0.2), 0.035, at.call(Vector3(x + sx * 0.08, BELT + 0.14, COWL_Z + 0.1)))
	rb.call(paint, Vector3(HALF_W * 2.0, BELT - SILL, 0.04), 0.02, at.call(Vector3(0, (BELT + SILL) * 0.5, TAIL_Z)))
	rb.call(paint, Vector3(HALF_W * 2.0, BELT - SILL, 0.04), 0.02, at.call(Vector3(0, (BELT + SILL) * 0.5, COWL_Z)))
	rb.call(trim, Vector3(1.66, 0.16, 0.36), 0.05, at.call(Vector3(0, BELT - 0.02, COWL_Z + 0.16)))

	# front: fenders with flat tops beside a long vented hood, the grille face
	for sx: float in [-1.0, 1.0]:
		var x := sx * HALF_W
		KuwarentaBody._side_panel(paint, x, NOSE_Z - 0.02, COWL_Z, SILL + 0.1, HOOD_Y, [[fz, arch]], 0.035, c)
		# fender top: from under the hood's edge out to the side, nose to cowl
		var fin := spec.tire_inner() - 0.03
		rb.call(paint, Vector3(HALF_W + 0.01 - fin, 0.05, COWL_Z - NOSE_Z + 0.02), 0.02, at.call(Vector3(sx * (HALF_W + 0.01 + fin) * 0.5, HOOD_Y, (COWL_Z + NOSE_Z) * 0.5)))
		rb.call(paint, Vector3(0.03, HOOD_Y - 0.7, COWL_Z - NOSE_Z), 0.01, at.call(Vector3(sx * spec.tire_inner(), (HOOD_Y + 0.7) * 0.5, (COWL_Z + NOSE_Z) * 0.5)))
	var hood := Transform3D(Basis(Vector3.RIGHT, -0.03), Vector3(0, HOOD_Y + 0.02, (COWL_Z + NOSE_Z) * 0.5))
	rb.call(paint, Vector3(HALF_W * 2.0 - 0.46, 0.06, COWL_Z - NOSE_Z), 0.03, hood)
	for sx: float in [-1.0, 1.0]:
		for k in range(4):
			rb.call(plastic, Vector3(0.12, 0.012, 0.018), 0.004, hood * at.call(Vector3(sx * 0.3, 0.035, -0.25 + k * 0.05)))
	var face_y0 := SILL + 0.15
	rb.call(paint, Vector3(HALF_W * 2.0 + 0.02, HOOD_Y - face_y0 + 0.02, 0.05), 0.025, at.call(Vector3(0, (HOOD_Y + face_y0) * 0.5, NOSE_Z)))
	for k in range(9):
		rb.call(chassis, Vector3(0.045, 0.24, 0.02), 0.012, at.call(Vector3((k - 4) * 0.075, 0.93, NOSE_Z - 0.03)))
	for sx: float in [-1.0, 1.0]:
		var bez := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx * 0.6, 0.97, NOSE_Z - 0.04))
		MeshKit.lathe(chassis, [Vector2(0.075, -0.025), Vector2(0.105, -0.025), Vector2(0.11, 0.0),
			Vector2(0.104, 0.025), Vector2(0.085, 0.025)], bez, c, 24)

	# windshield, raked, and the black hardtop with its pillars
	var rake := 0.42
	var wh := (ROOF - BELT) / cos(rake)
	var ws := Transform3D(Basis(Vector3.RIGHT, rake), Vector3(0, BELT, COWL_Z + 0.02))
	for sx: float in [-1.0, 1.0]:
		rb.call(paint, Vector3(0.07, wh, 0.05), 0.015, ws * at.call(Vector3(sx * (HALF_W - 0.035), wh * 0.5, 0)))
		MeshKit.tube(chassis, ws * Vector3(sx * 0.42 - 0.28, 0.04, -0.03), ws * Vector3(sx * 0.42 + 0.14, 0.5, -0.03), 0.006, Transform3D.IDENTITY, c, 5)
	rb.call(paint, Vector3(HALF_W * 2.0, 0.05, 0.05), 0.015, ws * at.call(Vector3(0, 0.0, 0)))
	rb.call(top, Vector3(HALF_W * 2.0, 0.06, 0.06), 0.02, ws * at.call(Vector3(0, wh, 0)))
	var roof_z0 := COWL_Z + 0.02 + sin(rake) * wh
	rb.call(top, Vector3(HALF_W * 2.0 + 0.02, 0.06, TAIL_Z - roof_z0 + 0.04), 0.035, at.call(Vector3(0, ROOF, (TAIL_Z + roof_z0) * 0.5)))
	for sx: float in [-1.0, 1.0]:
		var x := sx * HALF_W
		for p: Array in [[B_Z, 0.1], [C_Z, 0.12], [TAIL_Z - 0.12, 0.24]]:
			rb.call(top, Vector3(0.05, ROOF - BELT, float(p[1])), 0.015, at.call(Vector3(x, (ROOF + BELT) * 0.5, float(p[0]))))
		rb.call(top, Vector3(0.05, 0.05, TAIL_Z - roof_z0), 0.015, at.call(Vector3(x, ROOF - 0.03, (TAIL_Z + roof_z0) * 0.5)))
		rb.call(paint, Vector3(0.05, 0.04, TAIL_Z - COWL_Z), 0.012, at.call(Vector3(x - sx * 0.01, BELT, (TAIL_Z + COWL_Z) * 0.5)))
	for px: float in [-HALF_W + 0.12, HALF_W - 0.12]:
		rb.call(top, Vector3(0.24, ROOF - BELT, 0.05), 0.015, at.call(Vector3(px, (ROOF + BELT) * 0.5, TAIL_Z)))
	rb.call(top, Vector3(HALF_W * 2.0, 0.08, 0.05), 0.015, at.call(Vector3(0, ROOF - 0.04, TAIL_Z)))

	# seats, rear bench, column, shifters
	var seat := spec.seat
	for sx: float in [-1.0, 1.0]:
		rb.call(trim, Vector3(0.5, 0.14, 0.5), 0.05, at.call(Vector3(sx * absf(seat.x), seat.y - 0.12, seat.z - 0.06)))
		rb.call(trim, Vector3(0.48, 0.64, 0.11), 0.045, Transform3D(Basis(Vector3.RIGHT, 0.16), Vector3(sx * absf(seat.x), seat.y + 0.22, seat.z + 0.22)))
	rb.call(trim, Vector3(1.5, 0.14, 0.46), 0.05, at.call(Vector3(0, 0.76, 0.95)))
	rb.call(trim, Vector3(1.5, 0.56, 0.1), 0.04, Transform3D(Basis(Vector3.RIGHT, 0.14), Vector3(0, 1.08, 1.22)))
	MeshKit.tube(chassis, Vector3(seat.x, BELT - 0.08, COWL_Z + 0.08), spec.wheel_at, 0.024, Transform3D.IDENTITY, c)
	MeshKit.tube(chassis, Vector3(0.02, 0.66, -0.38), Vector3(0.0, 1.06, -0.26), 0.013, Transform3D.IDENTITY, c, 6)
	MeshKit.tube(chassis, Vector3(0.11, 0.66, -0.38), Vector3(0.13, 1.0, -0.28), 0.011, Transform3D.IDENTITY, c, 6)

	# steel bumpers with the winch, the spare on the tailgate
	rb.call(plastic, Vector3(1.94, 0.18, 0.2), 0.03, at.call(Vector3(0, 0.62, -2.4)))
	MeshKit.cylinder(chassis, 0.085, 0.48, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 0.74, -2.4)), c, 16)
	for sx: float in [-1.0, 1.0]:
		MeshKit.cylinder(chassis, 0.1, 0.06, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(sx * 0.27, 0.74, -2.4)), c, 16)
		rb.call(plastic, Vector3(0.045, 0.13, 0.045), 0.01, at.call(Vector3(sx * 0.72, 0.62, -2.52)))
	rb.call(plastic, Vector3(0.24, 0.08, 0.05), 0.015, at.call(Vector3(0, 0.74, -2.5)))
	rb.call(plastic, Vector3(1.86, 0.15, 0.15), 0.03, at.call(Vector3(0, 0.6, TAIL_Z + 0.08)))
	var spare := MeshInstance3D.new()
	rig.spare_mat = ShaderMaterial.new()
	rig.spare_mat.shader = load("res://shaders/tire.gdshader")
	spare.mesh = MeshKit.commit(RigWheel.build_wheel_mesh(spec.tire_radius, spec.tire_width, false), rig.spare_mat)
	spare.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 1.12, TAIL_Z + 0.22))
	rig.add_child(spare)
	rb.call(chassis, Vector3(0.12, 0.12, 0.12), 0.01, at.call(Vector3(0, 1.12, TAIL_Z + 0.05)))

	var chassis_mat := rig._body_mat(Color(0.05, 0.05, 0.05), 0.7, 0.2, 0.0)
	rig._add_mesh(MeshKit.commit(paint, rig.paint_mat(0.22, 0.9)))   # picked in the start menu
	rig._add_mesh(MeshKit.commit(top, rig._body_mat(Color(0.03, 0.03, 0.032), 0.5, 0.0, 0.3)))
	rig._add_mesh(MeshKit.commit(plastic, rig._body_mat(Color(0.035, 0.035, 0.037), 0.75, 0.0, 0.0)))
	rig._add_mesh(MeshKit.commit(chassis, chassis_mat))
	rig._add_mesh(MeshKit.commit(trim, rig._body_mat(Color(0.07, 0.065, 0.06), 0.6, 0.0, 0.0)))

	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.32, 0.38, 0.42, 0.4)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic_specular = 0.9
	var gst := MeshKit.begin()
	MeshKit.rounded_box(gst, Vector3(HALF_W * 2.0 - 0.12, wh - 0.08, 0.008), 0.02, ws * at.call(Vector3(0, wh * 0.5, 0)), c, 1)
	var wy := (ROOF + BELT) * 0.5
	var wh2 := ROOF - BELT - 0.04
	# side glass fitted rail to rail, the front door's up the raked A-pillar
	var y0 := BELT + 0.005
	var y1 := ROOF - 0.03
	for sx: float in [-1.0, 1.0]:
		var x := sx * HALF_W
		BodyKit.side_glass(gst, x, y0, y1, COWL_Z + 0.07 + tan(rake) * (y0 - BELT), COWL_Z + 0.07 + tan(rake) * (y1 - BELT), B_Z - 0.03, c)
		BodyKit.side_glass(gst, x, y0, y1, B_Z + 0.03, B_Z + 0.03, C_Z - 0.04, c)
		BodyKit.side_glass(gst, x, y0, y1, C_Z + 0.04, C_Z + 0.04, TAIL_Z - 0.2, c)
	MeshKit.rounded_box(gst, Vector3(HALF_W * 2.0 - 0.46, wh2, 0.008), 0.02, at.call(Vector3(0, wy, TAIL_Z + 0.026)), c, 1)
	rig._add_mesh(MeshKit.commit(gst, glass))
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color(0.95, 0.95, 0.92)
	lamp.emission_enabled = true
	lamp.emission = Color(0.95, 0.96, 1.0)
	lamp.emission_energy_multiplier = 1.3
	lamp.roughness = 0.1
	var lst := MeshKit.begin()
	for sx: float in [-1.0, 1.0]:
		var lens := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx * 0.6, 0.97, NOSE_Z - 0.045))
		MeshKit.lathe(lst, [Vector2(0.0, -0.02), Vector2(0.085, -0.02), Vector2(0.07, 0.0), Vector2(0.0, 0.012)], lens, c, 20)
	rig._add_mesh(MeshKit.commit(lst, lamp))
	var tail := StandardMaterial3D.new()
	tail.albedo_color = Color(0.5, 0.03, 0.02)
	tail.emission_enabled = true
	tail.emission = Color(0.8, 0.05, 0.02)
	tail.emission_energy_multiplier = 0.4
	var tst := MeshKit.begin()
	for sx: float in [-1.0, 1.0]:
		MeshKit.rounded_box(tst, Vector3(0.12, 0.34, 0.03), 0.02, at.call(Vector3(sx * (HALF_W - 0.08), 0.95, TAIL_Z + 0.03)), c, 2)
	rig._add_mesh(MeshKit.commit(tst, tail))



## A trapezoid flare round an arch: straight legs angled out, a flat top.
static func _flare(st: SurfaceTool, x: float, zc: float, r: float, col: Color) -> void:
	var hub := RigSpec.RIDE_HUB_Y
	var low := SILL + 0.03
	var top := hub + r + 0.05   # the tube's underside clears the tire at the bump stop
	var pts := PackedVector3Array([
		Vector3(x, low, zc - r * 1.12), Vector3(x, top - 0.02, zc - r * 0.62),
		Vector3(x, top, zc - r * 0.5), Vector3(x, top, zc + r * 0.5),
		Vector3(x, top - 0.02, zc + r * 0.62), Vector3(x, low, zc + r * 1.12)])
	var radii := PackedFloat32Array()
	for i in pts.size():
		radii.append(0.06)
	MeshKit.sweep(st, pts, radii, Transform3D.IDENTITY, col, 8)
