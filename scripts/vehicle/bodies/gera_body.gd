class_name GeraBody
extends RefCounted
## The Gera ("war", for its army roots): a lifted Willys-style tub in the paint picked in the menu,
## on 35s, roll cage, winch bumper, flat fenders, spare on the back panel.
## Rig space: forward -Z, left -X, wheel hubs at y~0.13.


static func build(rig: Rig) -> void:
	# Collision: tub, hood/front clip, bumper and the cage top.
	BodyKit.collide(rig, -0.34, 1.58, 0.55, 1.17, 0.725)   # tub, split round the rear wheels
	for c: Array in [
		[Vector3(1.05, 0.6, 1.3), Vector3(0, 0.88, -0.98)],
		[Vector3(1.75, 0.16, 0.16), Vector3(0, 0.6, -1.74)],
		[Vector3(1.3, 0.78, 1.0), Vector3(0, 1.56, 0.16)],
	]:
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = c[0]
		col.shape = box
		col.position = c[1]
		rig.add_child(col)

	# Flat-fender Willys-style tub in gloss black, lifted on 35s.
	# Everything below is rig space: forward -Z, left -X, wheel hubs at y~0.13.
	var paint := MeshKit.begin()
	var steel := MeshKit.begin()     # satin black: bumpers, cage, bezels
	var chassis := MeshKit.begin()   # frame, winch, grille slots
	var trim := MeshKit.begin()      # seats, steering wheel
	var c := Color.WHITE
	var at := func(p: Vector3) -> Transform3D: return Transform3D(Basis.IDENTITY, p)
	var rb := func(st: SurfaceTool, size: Vector3, r: float, xf: Transform3D) -> void:
		MeshKit.rounded_box(st, size, r, xf, c)

	# frame rails and crossmembers
	for sx: float in [-1.0, 1.0]:
		rb.call(chassis, Vector3(0.08, 0.14, 3.4), 0.01, at.call(Vector3(sx * 0.42, 0.45, -0.1)))
	for z: float in [-1.7, -0.3, 1.5]:
		rb.call(chassis, Vector3(0.84, 0.08, 0.08), 0.01, at.call(Vector3(0, 0.45, z)))

	# tub: floor, sides cut for the rear wheels, flat rear fenders, back panel
	BodyKit.floor_panel(paint, rig.spec, -0.32, 1.56, 0.69, 0.56, c)
	var arch := BodyKit.well_radius(rig.spec)
	for sx: float in [-1.0, 1.0]:
		# one tub side, cowl to tail, the rear wheel arch cut out of it
		KuwarentaBody._side_panel(paint, sx * 0.705, -0.33, 1.58, 0.56, 1.17, [[rig.spec.rear_z, arch]], 0.04, c)
		MeshKit.tube(paint, Vector3(sx * 0.705, 1.17, -0.33), Vector3(sx * 0.705, 1.17, 1.58), 0.025, Transform3D.IDENTITY, c, 8)
		# the flat fender lip over the tire
		rb.call(paint, Vector3(0.27, 0.035, 1.02), 0.012, at.call(Vector3(sx * 0.8, 0.975, 1.1)))
	rb.call(paint, Vector3(1.45, 0.62, 0.05), 0.025, at.call(Vector3(0, 0.865, 1.58)))
	BodyKit.wheel_houses(paint, rig.spec, rig.spec.rear_z, 0.705, 0.56, c)
	# cowl and dash
	rb.call(paint, Vector3(1.45, 0.62, 0.05), 0.02, at.call(Vector3(0, 0.865, -0.33)))
	rb.call(paint, Vector3(1.45, 0.07, 0.24), 0.03, at.call(Vector3(0, 1.17, -0.43)))

	# hood, hood sides, latches
	rb.call(paint, Vector3(1.02, 0.06, 1.25), 0.03, at.call(Vector3(0, 1.17, -0.965)))
	for sx: float in [-1.0, 1.0]:
		rb.call(paint, Vector3(0.04, 0.38, 1.25), 0.015, at.call(Vector3(sx * 0.49, 0.98, -0.965)))
		rb.call(steel, Vector3(0.025, 0.07, 0.04), 0.008, at.call(Vector3(sx * 0.515, 1.08, -0.8)))

	# front fenders: flat, kicking down at the nose, stepped down to the tub
	for sx: float in [-1.0, 1.0]:
		rb.call(paint, Vector3(0.34, 0.035, 1.12), 0.012, at.call(Vector3(sx * 0.68, 0.97, -0.955)))
		var nose := Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(sx * 0.68, 0.915, -1.6))
		rb.call(paint, Vector3(0.34, 0.035, 0.24), 0.012, nose)
		rb.call(paint, Vector3(0.34, 0.42, 0.035), 0.012, at.call(Vector3(sx * 0.68, 0.77, -0.37)))
		# inner fender apron under it, nose to cowl, cut round the front tire:
		# open under the fender like the real thing, but no seeing into the engine bay
		KuwarentaBody._side_panel(paint, sx * 0.52, -1.6, -0.37, 0.56, 0.97, [[rig.spec.front_z, arch]], 0.03, c)

	# grille: body-colour plate, slotted, round headlights set into it
	rb.call(paint, Vector3(1.0, 0.64, 0.05), 0.025, at.call(Vector3(0, 0.88, -1.6)))
	for k in range(9):
		rb.call(chassis, Vector3(0.034, 0.4, 0.02), 0.008, at.call(Vector3((k - 4) * 0.062, 0.82, -1.627)))
	for sx: float in [-1.0, 1.0]:
		var bez := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx * 0.37, 1.0, -1.65))
		MeshKit.lathe(steel, [Vector2(0.06, -0.03), Vector2(0.095, -0.03), Vector2(0.1, 0.0),
			Vector2(0.095, 0.03), Vector2(0.075, 0.03)], bez, c, 24)
		var sig := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx * 0.37, 0.68, -1.64))
		MeshKit.cylinder(steel, 0.035, 0.03, sig, c, 12)

	# windshield frame, hinged at the cowl and raked back a little
	var ws := Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3(0, 1.2, -0.42))
	rb.call(paint, Vector3(1.4, 0.05, 0.05), 0.015, ws * at.call(Vector3(0, 0.025, 0)))
	rb.call(paint, Vector3(1.4, 0.05, 0.05), 0.015, ws * at.call(Vector3(0, 0.56, 0)))
	for sx: float in [-1.0, 1.0]:
		rb.call(paint, Vector3(0.05, 0.56, 0.05), 0.015, ws * at.call(Vector3(sx * 0.675, 0.29, 0)))
	rb.call(paint, Vector3(0.03, 0.52, 0.035), 0.01, ws * at.call(Vector3(0, 0.29, 0)))

	# seats, steering wheel, shifters
	for sx: float in [-1.0, 1.0]:
		rb.call(trim, Vector3(0.46, 0.13, 0.46), 0.05, at.call(Vector3(sx * 0.33, 0.68, 0.2)))
		var back := Transform3D(Basis(Vector3.RIGHT, 0.18), Vector3(sx * 0.33, 1.0, 0.47))
		rb.call(trim, Vector3(0.44, 0.55, 0.1), 0.045, back)
	rb.call(trim, Vector3(0.82, 0.13, 0.4), 0.05, at.call(Vector3(0, 0.68, 1.2)))
	rb.call(trim, Vector3(0.82, 0.4, 0.09), 0.04, Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0, 0.95, 1.46)))
	# the steering wheel itself turns, so the driver builds it (driver.gd)
	MeshKit.tube(chassis, Vector3(-0.33, 0.98, -0.42), rig.spec.wheel_at, 0.022, Transform3D.IDENTITY, c)
	MeshKit.tube(chassis, Vector3(0.02, 0.58, -0.1), Vector3(0.0, 0.98, 0.0), 0.012, Transform3D.IDENTITY, c, 6)
	MeshKit.tube(chassis, Vector3(0.1, 0.58, -0.1), Vector3(0.12, 0.92, -0.02), 0.01, Transform3D.IDENTITY, c, 6)

	# roll cage: main hoop behind the seats, bars to the windshield and the back corners
	var top_l := Vector3(-0.62, 1.95, 0.62)
	var top_r := Vector3(0.62, 1.95, 0.62)
	var cage: Array = [
		[Vector3(-0.66, 1.17, 0.62), top_l], [Vector3(0.66, 1.17, 0.62), top_r], [top_l, top_r],
		[top_l, Vector3(-0.66, 1.74, -0.3)], [top_r, Vector3(0.66, 1.74, -0.3)],
		[top_l, Vector3(-0.64, 1.17, 1.54)], [top_r, Vector3(0.64, 1.17, 1.54)],
		[Vector3(-0.645, 1.45, 0.62), Vector3(0.645, 1.45, 0.62)],
	]
	for bar: Array in cage:
		MeshKit.tube(steel, bar[0], bar[1], 0.027, Transform3D.IDENTITY, c, 10)
	for corner: Vector3 in [top_l, top_r]:
		MeshKit.sphere(steel, 0.034, at.call(corner), c, 10)

	# bumpers and winch
	rb.call(steel, Vector3(1.75, 0.14, 0.13), 0.025, at.call(Vector3(0, 0.6, -1.74)))
	rb.call(steel, Vector3(1.5, 0.12, 0.11), 0.025, at.call(Vector3(0, 0.58, 1.68)))
	MeshKit.cylinder(chassis, 0.085, 0.46, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 0.75, -1.74)), c, 16)
	for sx: float in [-1.0, 1.0]:
		MeshKit.cylinder(chassis, 0.1, 0.06, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(sx * 0.26, 0.75, -1.74)), c, 16)
		rb.call(steel, Vector3(0.04, 0.12, 0.04), 0.01, at.call(Vector3(sx * 0.62, 0.6, -1.83)))
	rb.call(steel, Vector3(0.22, 0.08, 0.05), 0.015, at.call(Vector3(0, 0.75, -1.84)))

	# spare on the back panel
	var spare := MeshInstance3D.new()
	rig.spare_mat = ShaderMaterial.new()
	rig.spare_mat.shader = load("res://shaders/tire.gdshader")
	spare.mesh = MeshKit.commit(RigWheel.build_wheel_mesh(rig.spec.tire_radius, rig.spec.tire_width, false), rig.spare_mat)
	spare.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 1.0, 1.79))
	rig.add_child(spare)
	rb.call(chassis, Vector3(0.12, 0.12, 0.1), 0.01, at.call(Vector3(0, 1.0, 1.63)))

	var chassis_mat := rig._body_mat(Color(0.05, 0.05, 0.05), 0.7, 0.2, 0.0)
	rig._add_mesh(MeshKit.commit(paint, rig.paint_mat(0.18, 1.0)))   # picked in the start menu
	rig._add_mesh(MeshKit.commit(steel, rig._body_mat(Color(0.03, 0.03, 0.032), 0.55, 0.3, 0.0)))
	rig._add_mesh(MeshKit.commit(chassis, chassis_mat))
	rig._add_mesh(MeshKit.commit(trim, rig._body_mat(Color(0.06, 0.055, 0.05), 0.6, 0.0, 0.0)))

	# glass, lamps
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.55, 0.62, 0.65, 0.22)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic_specular = 0.9
	var gst := MeshKit.begin()
	for sx: float in [-1.0, 1.0]:
		MeshKit.rounded_box(gst, Vector3(0.62, 0.48, 0.008), 0.004, ws * at.call(Vector3(sx * 0.335, 0.29, 0)), c, 1)
	rig._add_mesh(MeshKit.commit(gst, glass))
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color(0.95, 0.93, 0.85)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.92, 0.7)
	lamp.emission_energy_multiplier = 1.2
	lamp.roughness = 0.1
	var lst := MeshKit.begin()
	for sx: float in [-1.0, 1.0]:
		var lens := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx * 0.37, 1.0, -1.655))
		MeshKit.lathe(lst, [Vector2(0.0, -0.02), Vector2(0.075, -0.02), Vector2(0.06, 0.0), Vector2(0.0, 0.01)], lens, c, 20)
	rig._add_mesh(MeshKit.commit(lst, lamp))
	var tail := StandardMaterial3D.new()
	tail.albedo_color = Color(0.5, 0.03, 0.02)
	tail.emission_enabled = true
	tail.emission = Color(0.8, 0.05, 0.02)
	tail.emission_energy_multiplier = 0.4
	var tst := MeshKit.begin()
	for sx: float in [-1.0, 1.0]:
		MeshKit.rounded_box(tst, Vector3(0.09, 0.13, 0.03), 0.012, at.call(Vector3(sx * 0.6, 0.98, 1.61)), c, 2)
	rig._add_mesh(MeshKit.commit(tst, tail))

	# whip with an orange flag, like every rig at the trailhead
	var whip_base := Vector3(0.64, 1.17, 1.52)
	var wst := MeshKit.begin()
	MeshKit.tube(wst, whip_base, whip_base + Vector3(0, 1.9, 0), 0.006, Transform3D.IDENTITY, c, 5)
	rig._add_mesh(MeshKit.commit(wst, chassis_mat))
	var fm := ArrayMesh.new()
	var fa := []
	fa.resize(Mesh.ARRAY_MAX)
	fa[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3(0, -0.32, 0), Vector3(0, -0.12, 0.48)])
	fa[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT])
	fm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, fa)
	var flag_mat := StandardMaterial3D.new()
	flag_mat.albedo_color = Color(0.95, 0.42, 0.08)
	flag_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	flag_mat.roughness = 0.8
	fm.surface_set_material(0, flag_mat)
	rig._flag = rig._add_mesh(fm)
	rig._flag.position = whip_base + Vector3(0, 1.88, 0)
