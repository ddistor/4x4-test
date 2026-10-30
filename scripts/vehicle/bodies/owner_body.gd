class_name OwnerBody
extends RefCounted
## The Owner: an owner-type jeep the way the shops in the provinces build
## them. A low doorless tub in the paint picked in the menu (polished
## stainless is the classic), flat fenders, a chrome grille of vertical bars
## with the round lamps on it, a chrome crease along the sides, an upright
## windshield, a flat canopy roof over the front seats on a roll hoop, and a
## flat deck at the back with benches down both sides. Trail-built: 31s,
## winch on the chrome bumper, the spare on the tailgate.
## Rig space: forward -Z, left -X, wheel hubs at y~0.13.

const SILL := 0.5
const BELT := 1.0
const STEP_TOP := 0.8      # the doorless opening dips to here
const OPEN_Z := 0.36       # where the opening ends and the deck sides start
const HALF_W := 0.76
const COWL_Z := -0.5
const TAIL_Z := 1.72
const NOSE_Z := -1.86
const FENDER_Y := 0.92
const CANOPY_Y := 1.66


static func build(rig: Rig) -> void:
	var spec := rig.spec
	BodyKit.collide(rig, COWL_Z, TAIL_Z, SILL, BELT, HALF_W)         # tub
	BodyKit.collide(rig, NOSE_Z, COWL_Z, 0.58, BELT, HALF_W + 0.06)  # nose and fenders
	BodyKit._box(rig, Vector3(1.5, 0.06, 1.0), Vector3(0, CANOPY_Y, -0.08))   # canopy
	BodyKit._box(rig, Vector3(1.9, 0.16, 0.16), Vector3(0, 0.6, -1.98))       # bumper

	var paint := MeshKit.begin()
	var chrome := MeshKit.begin()
	var chassis := MeshKit.begin()
	var trim := MeshKit.begin()      # seats, benches, deck mat
	var c := Color.WHITE
	var at := func(p: Vector3) -> Transform3D: return Transform3D(Basis.IDENTITY, p)
	var rb := func(st: SurfaceTool, size: Vector3, r: float, xf: Transform3D) -> void:
		MeshKit.rounded_box(st, size, r, xf, c)
	var fz := spec.front_z
	var rz := spec.rear_z
	var arch := BodyKit.well_radius(spec)

	for sx: float in [-1.0, 1.0]:
		rb.call(chassis, Vector3(0.08, 0.13, 3.6), 0.01, at.call(Vector3(sx * 0.4, 0.43, -0.1)))
	for z: float in [-1.75, -0.45, 0.6, 1.62]:
		rb.call(chassis, Vector3(0.8, 0.07, 0.07), 0.01, at.call(Vector3(0, 0.43, z)))

	# the tub: floor, the low sides by the front seats, the full-height deck
	# sides with the rear arch, the chrome crease, the tailgate
	BodyKit.floor_panel(paint, spec, COWL_Z, TAIL_Z, HALF_W - 0.02, SILL + 0.01, c)
	BodyKit.wheel_houses(paint, spec, rz, HALF_W, SILL, c)
	for sx: float in [-1.0, 1.0]:
		var x := sx * HALF_W
		KuwarentaBody._side_panel(paint, x, COWL_Z, OPEN_Z, SILL, STEP_TOP, [], 0.035, c)
		KuwarentaBody._side_panel(paint, x, OPEN_Z, TAIL_Z, SILL, BELT, [[rz, arch]], 0.035, c)
		KuwarentaBody._arch_lip(chrome, x, rz, arch, SILL, c)
		# rolled top edges, and the chrome crease along the flank
		MeshKit.tube(paint, Vector3(x, STEP_TOP, COWL_Z + 0.02), Vector3(x, STEP_TOP, OPEN_Z), 0.02, Transform3D.IDENTITY, c, 8)
		MeshKit.sweep(paint, PackedVector3Array([Vector3(x, STEP_TOP, OPEN_Z), Vector3(x, BELT - 0.04, OPEN_Z + 0.12), Vector3(x, BELT, OPEN_Z + 0.24), Vector3(x, BELT, TAIL_Z)]),
			PackedFloat32Array([0.02, 0.02, 0.02, 0.02]), Transform3D.IDENTITY, c, 8)
		# the chrome strip down the side, broken at each wheel opening
		var half_chord := sqrt(maxf(0.0, arch * arch - pow(0.7 - RigSpec.RIDE_HUB_Y, 2.0))) + 0.04
		var cuts: Array[float] = [NOSE_Z + 0.1, spec.front_z - half_chord, spec.front_z + half_chord, rz - half_chord, rz + half_chord, TAIL_Z - 0.1]
		for k in range(0, cuts.size(), 2):
			if cuts[k + 1] - cuts[k] > 0.05:
				rb.call(chrome, Vector3(0.012, 0.025, cuts[k + 1] - cuts[k]), 0.006, at.call(Vector3(x + sx * 0.02, 0.7, (cuts[k] + cuts[k + 1]) * 0.5)))
		# a chrome step under the opening
		rb.call(chrome, Vector3(0.12, 0.025, 0.36), 0.008, at.call(Vector3(x + sx * 0.05, SILL - 0.04, -0.1)))
	rb.call(paint, Vector3(HALF_W * 2.0, BELT - SILL, 0.04), 0.02, at.call(Vector3(0, (BELT + SILL) * 0.5, TAIL_Z)))
	rb.call(chrome, Vector3(HALF_W * 2.0 - 0.1, 0.03, 0.012), 0.006, at.call(Vector3(0, 0.82, TAIL_Z + 0.022)))
	# cowl and dash
	rb.call(paint, Vector3(HALF_W * 2.0, BELT - SILL, 0.04), 0.02, at.call(Vector3(0, (BELT + SILL) * 0.5, COWL_Z)))
	rb.call(paint, Vector3(HALF_W * 2.0, 0.06, 0.24), 0.025, at.call(Vector3(0, BELT + 0.02, COWL_Z - 0.08)))
	rb.call(trim, Vector3(1.3, 0.09, 0.16), 0.03, at.call(Vector3(0, BELT - 0.04, COWL_Z + 0.1)))

	# hood between flat fenders, a chrome strip down the middle
	rb.call(paint, Vector3(1.0, 0.05, COWL_Z - NOSE_Z - 0.02), 0.025, at.call(Vector3(0, BELT + 0.01, (COWL_Z + NOSE_Z) * 0.5)))
	rb.call(chrome, Vector3(0.05, 0.02, COWL_Z - NOSE_Z - 0.1), 0.008, at.call(Vector3(0, BELT + 0.04, (COWL_Z + NOSE_Z) * 0.5)))
	for sx: float in [-1.0, 1.0]:
		rb.call(paint, Vector3(0.035, BELT - 0.62, COWL_Z - NOSE_Z), 0.012, at.call(Vector3(sx * 0.49, (BELT + 0.62) * 0.5, (COWL_Z + NOSE_Z) * 0.5)))
		# flat fender, kicking down at the front, and the step down to the tub
		rb.call(paint, Vector3(0.34, 0.035, COWL_Z - NOSE_Z - 0.12), 0.012, at.call(Vector3(sx * 0.67, FENDER_Y, (COWL_Z + NOSE_Z) * 0.5 + 0.06)))
		var kick := Transform3D(Basis(Vector3.RIGHT, -0.55), Vector3(sx * 0.67, FENDER_Y - 0.06, NOSE_Z + 0.05))
		rb.call(paint, Vector3(0.34, 0.035, 0.2), 0.012, kick)
		rb.call(paint, Vector3(0.34, FENDER_Y - 0.6, 0.035), 0.012, at.call(Vector3(sx * 0.67, (FENDER_Y + 0.6) * 0.5, COWL_Z - 0.02)))
		rb.call(chrome, Vector3(0.36, 0.015, 0.02), 0.005, at.call(Vector3(sx * 0.67, FENDER_Y + 0.025, NOSE_Z + 0.16)))

	# the grille: chrome surround, vertical bars, round lamps set on it
	rb.call(chrome, Vector3(1.0, 0.4, 0.04), 0.03, at.call(Vector3(0, 0.8, NOSE_Z)))
	for k in range(13):
		rb.call(chassis, Vector3(0.025, 0.3, 0.02), 0.006, at.call(Vector3((k - 6) * 0.055, 0.79, NOSE_Z - 0.025)))
	for sx: float in [-1.0, 1.0]:
		var bez := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx * 0.4, 0.86, NOSE_Z - 0.04))
		MeshKit.lathe(chrome, [Vector2(0.06, -0.025), Vector2(0.09, -0.025), Vector2(0.094, 0.0),
			Vector2(0.088, 0.025), Vector2(0.07, 0.025)], bez, c, 24)

	# windshield: upright frame, folding hinges at the cowl, mirrors on it
	var ws := Transform3D(Basis(Vector3.RIGHT, 0.08), Vector3(0, BELT + 0.05, COWL_Z - 0.06))
	var wh := CANOPY_Y - BELT - 0.08
	rb.call(paint, Vector3(1.5, 0.05, 0.05), 0.015, ws * at.call(Vector3(0, 0.0, 0)))
	rb.call(paint, Vector3(1.5, 0.05, 0.05), 0.015, ws * at.call(Vector3(0, wh, 0)))
	for sx: float in [-1.0, 1.0]:
		rb.call(paint, Vector3(0.05, wh, 0.05), 0.015, ws * at.call(Vector3(sx * 0.725, wh * 0.5, 0)))
		MeshKit.tube(chrome, ws * Vector3(sx * 0.75, wh * 0.6, 0), ws * Vector3(sx * 0.92, wh * 0.7, 0.02), 0.009, Transform3D.IDENTITY, c, 6)
		MeshKit.cylinder(chrome, 0.07, 0.022, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), ws * Vector3(sx * 0.95, wh * 0.72, 0.03)), c, 16)
	rb.call(paint, Vector3(0.03, wh, 0.035), 0.01, ws * at.call(Vector3(0, wh * 0.5, 0)))

	# canopy: roll hoop behind the front seats, a flat roof out to the windshield
	var top_z0 := COWL_Z - 0.06 + sin(0.08) * wh
	var hoop_z := OPEN_Z + 0.06
	for sx: float in [-1.0, 1.0]:
		MeshKit.tube(chrome, Vector3(sx * (HALF_W - 0.03), BELT, hoop_z), Vector3(sx * (HALF_W - 0.03), CANOPY_Y - 0.03, hoop_z), 0.026, Transform3D.IDENTITY, c, 10)
		MeshKit.tube(chrome, Vector3(sx * (HALF_W - 0.03), CANOPY_Y - 0.03, hoop_z), Vector3(sx * (HALF_W - 0.03), CANOPY_Y - 0.03, top_z0), 0.022, Transform3D.IDENTITY, c, 10)
	MeshKit.tube(chrome, Vector3(-(HALF_W - 0.03), CANOPY_Y - 0.03, hoop_z), Vector3(HALF_W - 0.03, CANOPY_Y - 0.03, hoop_z), 0.026, Transform3D.IDENTITY, c, 10)
	rb.call(paint, Vector3(HALF_W * 2.0 + 0.02, 0.04, hoop_z - top_z0 + 0.1), 0.02, at.call(Vector3(0, CANOPY_Y, (hoop_z + top_z0) * 0.5 + 0.02)))
	rb.call(chrome, Vector3(HALF_W * 2.0 + 0.03, 0.02, 0.02), 0.006, at.call(Vector3(0, CANOPY_Y - 0.01, top_z0 - 0.02)))

	# seats, the deck with benches down both sides, column and shifters
	var seat := spec.seat
	for sx: float in [-1.0, 1.0]:
		rb.call(trim, Vector3(0.44, 0.12, 0.44), 0.05, at.call(Vector3(sx * absf(seat.x), seat.y - 0.12, seat.z - 0.06)))
		rb.call(trim, Vector3(0.42, 0.52, 0.1), 0.045, Transform3D(Basis(Vector3.RIGHT, 0.15), Vector3(sx * absf(seat.x), seat.y + 0.18, seat.z + 0.2)))
		# (up on top of the rear wheel well, not sunk into it)
		var bench_y := maxf(0.74, RigSpec.RIDE_HUB_Y + arch + 0.07)
		rb.call(trim, Vector3(0.3, 0.1, TAIL_Z - OPEN_Z - 0.35), 0.03, at.call(Vector3(sx * (HALF_W - 0.2), bench_y, (TAIL_Z + OPEN_Z) * 0.5 + 0.1)))
		rb.call(trim, Vector3(0.06, 0.28, TAIL_Z - OPEN_Z - 0.35), 0.025, at.call(Vector3(sx * (HALF_W - 0.06), bench_y + 0.12, (TAIL_Z + OPEN_Z) * 0.5 + 0.1)))
	MeshKit.tube(chassis, Vector3(seat.x, BELT - 0.08, COWL_Z + 0.04), spec.wheel_at, 0.022, Transform3D.IDENTITY, c)
	MeshKit.tube(chassis, Vector3(0.02, 0.55, -0.22), Vector3(0.0, 0.93, -0.12), 0.012, Transform3D.IDENTITY, c, 6)
	MeshKit.tube(chassis, Vector3(0.1, 0.55, -0.22), Vector3(0.12, 0.87, -0.14), 0.01, Transform3D.IDENTITY, c, 6)

	# chrome bumpers, the winch up front
	rb.call(chrome, Vector3(1.9, 0.13, 0.13), 0.04, at.call(Vector3(0, 0.6, -1.98)))
	rb.call(chrome, Vector3(1.6, 0.11, 0.11), 0.035, at.call(Vector3(0, 0.56, TAIL_Z + 0.08)))
	MeshKit.cylinder(chassis, 0.075, 0.42, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 0.66, -1.97)), c, 16)
	for sx: float in [-1.0, 1.0]:
		MeshKit.cylinder(chassis, 0.09, 0.05, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(sx * 0.235, 0.66, -1.97)), c, 16)
		rb.call(chrome, Vector3(0.04, 0.12, 0.04), 0.01, at.call(Vector3(sx * 0.7, 0.6, -2.07)))
	rb.call(chassis, Vector3(0.2, 0.07, 0.05), 0.015, at.call(Vector3(0, 0.66, -2.06)))

	# the spare on the tailgate
	var spare := MeshInstance3D.new()
	rig.spare_mat = ShaderMaterial.new()
	rig.spare_mat.shader = load("res://shaders/tire.gdshader")
	spare.mesh = MeshKit.commit(RigWheel.build_wheel_mesh(spec.tire_radius, spec.tire_width, false), rig.spare_mat)
	spare.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.98, TAIL_Z + 0.2))
	rig.add_child(spare)
	rb.call(chassis, Vector3(0.12, 0.12, 0.12), 0.01, at.call(Vector3(0, 0.98, TAIL_Z + 0.05)))

	var chassis_mat := rig._body_mat(Color(0.05, 0.05, 0.05), 0.7, 0.2, 0.0)
	rig._add_mesh(MeshKit.commit(paint, rig.paint_mat(0.2, 0.9)))   # picked in the start menu
	rig._add_mesh(MeshKit.commit(chrome, rig._body_mat(Color(0.8, 0.8, 0.78), 0.12, 0.95, 0.0)))
	rig._add_mesh(MeshKit.commit(chassis, chassis_mat))
	rig._add_mesh(MeshKit.commit(trim, rig._body_mat(Color(0.32, 0.08, 0.07), 0.55, 0.0, 0.2)))   # red vinyl

	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.5, 0.58, 0.62, 0.25)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic_specular = 0.9
	var gst := MeshKit.begin()
	for sx: float in [-1.0, 1.0]:
		MeshKit.rounded_box(gst, Vector3(0.68, wh - 0.06, 0.008), 0.004, ws * at.call(Vector3(sx * 0.36, wh * 0.5, 0)), c, 1)
	rig._add_mesh(MeshKit.commit(gst, glass))
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color(0.95, 0.93, 0.85)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.92, 0.7)
	lamp.emission_energy_multiplier = 1.2
	lamp.roughness = 0.1
	var lst := MeshKit.begin()
	for sx: float in [-1.0, 1.0]:
		var lens := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx * 0.4, 0.86, NOSE_Z - 0.045))
		MeshKit.lathe(lst, [Vector2(0.0, -0.02), Vector2(0.072, -0.02), Vector2(0.058, 0.0), Vector2(0.0, 0.01)], lens, c, 20)
	rig._add_mesh(MeshKit.commit(lst, lamp))
	var tail := StandardMaterial3D.new()
	tail.albedo_color = Color(0.5, 0.03, 0.02)
	tail.emission_enabled = true
	tail.emission = Color(0.8, 0.05, 0.02)
	tail.emission_energy_multiplier = 0.4
	var tst := MeshKit.begin()
	for sx: float in [-1.0, 1.0]:
		MeshKit.cylinder(tst, 0.05, 0.03, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx * 0.6, 0.86, TAIL_Z + 0.03)), c, 16)
	rig._add_mesh(MeshKit.commit(tst, tail))

