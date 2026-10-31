class_name GeraBody
extends RefCounted
## The Gera ("war", for its army roots): a lifted Willys-style tub in the paint picked in the menu,
## on 35s, roll cage, winch bumper, flat fenders, spare on the back panel.
## The Gerilya is the same tub built harder for the trail (`build_trail`):
## a full cage with a flat steel plate for a roof and a light bar, the
## windshield folded down on the hood, an army-green bumper with D-rings and
## driving lights, wire guards on the headlights, rock sliders, bucket seats
## and a jerry can. On 37s.
## Rig space: forward -Z, left -X, wheel hubs at y~0.13.

const DRAB := Color(0.2, 0.23, 0.13)     # army green: bumpers, jerry can
const RUST := Color(0.3, 0.17, 0.1)      # the roof plate
const TAN := Color(0.5, 0.41, 0.29)      # bucket seats


static func build(rig: Rig) -> void:
	_build(rig, false)


static func build_trail(rig: Rig) -> void:
	_build(rig, true)


static func _build(rig: Rig, trail: bool) -> void:
	# Collision: tub, hood/front clip, bumper and the cage top (the trail
	# cage runs forward to the cowl, so its box does too).
	BodyKit.collide(rig, -0.34, 1.58, 0.55, 1.17, 0.725)   # tub, split round the rear wheels
	for c: Array in [
		[Vector3(1.05, 0.6, 1.3), Vector3(0, 0.88, -0.98)],
		[Vector3(1.75, 0.16, 0.16), Vector3(0, 0.6, -1.74)],
		[Vector3(1.3, 0.8, 1.2), Vector3(0, 1.57, 0.06)] if trail else [Vector3(1.3, 0.78, 1.0), Vector3(0, 1.56, 0.16)],
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
	var drab := MeshKit.begin()      # army green (trail build)
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
		# one tub side, cowl to tail, the rear wheel arch cut out of it; the
		# trail build has the Willys door cutout, a deep curved scoop
		if trail:
			_scooped_side(paint, sx * 0.705, rig.spec.rear_z, arch, c)
			MeshKit.cylinder(paint, 0.045, 0.6, at.call(Vector3(sx * 0.68, 0.87, 1.555)), c, 12)   # rounded back corner
		else:
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
	if trail:
		# the Willys grille: a pressed panel with round shoulders at the top
		# corners round the headlights, tall slots running up between them
		_grille_panel(paint, 0.5, 0.56, 1.2, 0.15, -1.6, 0.05, c)
		for k in range(9):
			rb.call(chassis, Vector3(0.036, 0.5, 0.02), 0.01, at.call(Vector3((k - 4) * 0.06, 0.86, -1.627)))
	else:
		rb.call(paint, Vector3(1.0, 0.64, 0.05), 0.025, at.call(Vector3(0, 0.88, -1.6)))
		for k in range(9):
			rb.call(chassis, Vector3(0.034, 0.4, 0.02), 0.008, at.call(Vector3((k - 4) * 0.062, 0.82, -1.627)))
	for sx: float in [-1.0, 1.0]:
		var bez := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx * 0.37, 1.0, -1.65))
		MeshKit.lathe(steel, [Vector2(0.06, -0.03), Vector2(0.095, -0.03), Vector2(0.1, 0.0),
			Vector2(0.095, 0.03), Vector2(0.075, 0.03)], bez, c, 24)
		var sig := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx * 0.37, 0.68, -1.64))
		MeshKit.cylinder(steel, 0.035, 0.03, sig, c, 12)

	# windshield frame, hinged at the cowl and raked back a little; on the
	# trail build it's folded forward flat on the hood
	var ws := Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3(0, 1.2, -0.42))
	if trail:
		ws = Transform3D(Basis(Vector3.RIGHT, -1.5), Vector3(0, 1.245, -0.42))
	rb.call(paint, Vector3(1.4, 0.05, 0.05), 0.015, ws * at.call(Vector3(0, 0.025, 0)))
	rb.call(paint, Vector3(1.4, 0.05, 0.05), 0.015, ws * at.call(Vector3(0, 0.56, 0)))
	for sx: float in [-1.0, 1.0]:
		rb.call(paint, Vector3(0.05, 0.56, 0.05), 0.015, ws * at.call(Vector3(sx * 0.675, 0.29, 0)))
	rb.call(paint, Vector3(0.03, 0.52, 0.035), 0.01, ws * at.call(Vector3(0, 0.29, 0)))

	# seats, steering wheel, shifters
	var bucket := MeshKit.begin()
	for sx: float in [-1.0, 1.0]:
		if trail:
			# bucket seats: tall backs with a headrest slot and side bolsters
			rb.call(bucket, Vector3(0.46, 0.13, 0.46), 0.05, at.call(Vector3(sx * 0.33, 0.68, 0.2)))
			var bb := Transform3D(Basis(Vector3.RIGHT, 0.14), Vector3(sx * 0.33, 1.1, 0.47))
			rb.call(bucket, Vector3(0.44, 0.78, 0.1), 0.045, bb)
			for side: float in [-1.0, 1.0]:
				rb.call(bucket, Vector3(0.07, 0.5, 0.16), 0.03, bb * at.call(Vector3(side * 0.2, -0.08, -0.05)))
				rb.call(bucket, Vector3(0.07, 0.1, 0.36), 0.03, at.call(Vector3(sx * 0.33 + side * 0.2, 0.76, 0.2)))
			rb.call(trim, Vector3(0.12, 0.06, 0.106), 0.02, bb * at.call(Vector3(0, 0.27, 0)))   # harness slot
		else:
			rb.call(trim, Vector3(0.46, 0.13, 0.46), 0.05, at.call(Vector3(sx * 0.33, 0.68, 0.2)))
			var back := Transform3D(Basis(Vector3.RIGHT, 0.18), Vector3(sx * 0.33, 1.0, 0.47))
			rb.call(trim, Vector3(0.44, 0.55, 0.1), 0.045, back)
	rb.call(trim, Vector3(0.82, 0.13, 0.4), 0.05, at.call(Vector3(0, 0.68, 1.2)))
	rb.call(trim, Vector3(0.82, 0.4, 0.09), 0.04, Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0, 0.95, 1.46)))
	# the steering wheel itself turns, so the driver builds it (driver.gd)
	MeshKit.tube(chassis, Vector3(-0.33, 0.98, -0.42), rig.spec.wheel_at, 0.022, Transform3D.IDENTITY, c)

	# roll cage: main hoop behind the seats, bars to the windshield and the back corners
	var top_l := Vector3(-0.62, 1.95, 0.62)
	var top_r := Vector3(0.62, 1.95, 0.62)
	var cage: Array = [
		[Vector3(-0.66, 1.17, 0.62), top_l], [Vector3(0.66, 1.17, 0.62), top_r], [top_l, top_r],
		[top_l, Vector3(-0.64, 1.17, 1.54)], [top_r, Vector3(0.64, 1.17, 1.54)],
		[Vector3(-0.645, 1.45, 0.62), Vector3(0.645, 1.45, 0.62)],
	]
	var corners: Array[Vector3] = [top_l, top_r]
	if trail:
		# the windshield is down, so the cage carries its own front hoop
		# down to the cowl, a cross bar and the roof bars to it
		var fl := Vector3(-0.62, 1.93, -0.3)
		var fr := Vector3(0.62, 1.93, -0.3)
		cage.append_array([
			[Vector3(-0.66, 1.17, -0.36), fl], [Vector3(0.66, 1.17, -0.36), fr], [fl, fr],
			[top_l, fl], [top_r, fr],
			[Vector3(-0.62, 1.93, 0.16), Vector3(0.62, 1.93, 0.16)],
		])
		corners.append_array([fl, fr])
	else:
		cage.append_array([[top_l, Vector3(-0.66, 1.74, -0.3)], [top_r, Vector3(0.66, 1.74, -0.3)]])
	for bar: Array in cage:
		MeshKit.tube(steel, bar[0], bar[1], 0.027, Transform3D.IDENTITY, c, 10)
	for corner: Vector3 in corners:
		MeshKit.sphere(steel, 0.034, at.call(corner), c, 10)

	# bumpers and winch: plain black, or army green with D-rings on the trail build
	var bumper := drab if trail else steel
	# (far enough forward that the tires clear it at the bump stop)
	var bumper_z := rig.spec.front_z - sqrt(pow(rig.spec.tire_radius + 0.02, 2.0) - 0.04) - 0.065
	rb.call(bumper, Vector3(1.75, 0.14, 0.13), 0.025, at.call(Vector3(0, 0.6, bumper_z)))
	rb.call(bumper, Vector3(1.5, 0.12, 0.11), 0.025, at.call(Vector3(0, 0.58, 1.68)))
	MeshKit.cylinder(chassis, 0.085, 0.46, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 0.75, -1.74)), c, 16)
	for sx: float in [-1.0, 1.0]:
		MeshKit.cylinder(chassis, 0.1, 0.06, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(sx * 0.26, 0.75, -1.74)), c, 16)
		rb.call(steel, Vector3(0.04, 0.12, 0.04), 0.01, at.call(Vector3(sx * 0.62, 0.6, -1.83)))
	rb.call(steel, Vector3(0.22, 0.08, 0.05), 0.015, at.call(Vector3(0, 0.75, -1.84)))

	# the trail build's extras
	var lenses: Array[Transform3D] = []   # driving lights and the light bar, lit below
	var roof := MeshKit.begin()
	if trail:
		for sx: float in [-1.0, 1.0]:
			# D-ring shackles on tabs at the bumper ends
			rb.call(drab, Vector3(0.03, 0.12, 0.1), 0.01, at.call(Vector3(sx * 0.42, 0.52, -1.82)))
			MeshKit.torus(steel, 0.045, 0.012, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(sx * 0.42, 0.46, -1.86)), c, 14, 6)
			# a pair of round driving lights on the bumper each side of the winch
			for lx: float in [0.47, 0.7]:
				var dl := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx * lx, 0.77, -1.78))
				MeshKit.lathe(steel, [Vector2(0.0, 0.05), Vector2(0.06, 0.05), Vector2(0.075, 0.0),
					Vector2(0.08, -0.03), Vector2(0.065, -0.035)], dl, c, 18)
				rb.call(steel, Vector3(0.02, 0.06, 0.02), 0.005, at.call(Vector3(sx * lx, 0.69, -1.76)))
				lenses.append(dl * Transform3D(Basis.IDENTITY, Vector3(0, -0.032, 0)).scaled_local(Vector3(0.95, 1, 0.95)))
			# wire guards over the headlights: a ring and two bars across
			var hl := Vector3(sx * 0.37, 1.0, -1.72)
			MeshKit.torus(steel, 0.1, 0.007, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), hl), c, 20, 5)
			MeshKit.tube(steel, hl + Vector3(-0.07, 0.07, 0), hl + Vector3(0.07, -0.07, 0), 0.006, Transform3D.IDENTITY, c, 5)
			MeshKit.tube(steel, hl + Vector3(0, 0.1, 0.04), hl + Vector3(0, -0.1, 0.04), 0.006, Transform3D.IDENTITY, c, 5)
			# rock sliders along the sills, braced to the frame
			MeshKit.tube(steel, Vector3(sx * 0.78, 0.5, -0.56), Vector3(sx * 0.78, 0.5, 0.32), 0.03, Transform3D.IDENTITY, c, 10)
			for z: float in [-0.45, 0.2]:
				MeshKit.tube(steel, Vector3(sx * 0.78, 0.5, z), Vector3(sx * 0.46, 0.45, z), 0.022, Transform3D.IDENTITY, c, 8)
			for z: float in [-0.56, 0.32]:
				MeshKit.tube(steel, Vector3(sx * 0.78, 0.5, z), Vector3(sx * 0.705, 0.6, z + signf(z) * 0.06), 0.03, Transform3D.IDENTITY, c, 10)
		# flat steel plate bolted on the cage for a roof, and a light bar under its front edge
		rb.call(roof, Vector3(1.38, 0.02, 1.06), 0.008, at.call(Vector3(0, 1.975, 0.15)))
		rb.call(roof, Vector3(1.38, 0.05, 0.02), 0.006, at.call(Vector3(0, 1.96, -0.38)))
		rb.call(steel, Vector3(1.0, 0.08, 0.08), 0.015, at.call(Vector3(0, 1.88, -0.33)))
		# the army blackout lamp on the left fender, and round mirrors on the cowl
		var bo := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-0.66, 1.05, -1.32))
		MeshKit.cylinder(drab, 0.055, 0.12, bo, c, 14)
		rb.call(drab, Vector3(0.13, 0.02, 0.1), 0.006, at.call(Vector3(-0.66, 1.115, -1.35)))   # its hood
		rb.call(drab, Vector3(0.03, 0.06, 0.03), 0.006, at.call(Vector3(-0.66, 0.99, -1.3)))
		for sx: float in [-1.0, 1.0]:
			MeshKit.tube(steel, Vector3(sx * 0.7, 1.15, -0.36), Vector3(sx * 0.86, 1.4, -0.4), 0.01, Transform3D.IDENTITY, c, 6)
			MeshKit.cylinder(steel, 0.075, 0.025, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx * 0.87, 1.43, -0.41)), c, 16)
		# jerry can behind the passenger seat
		var can: Transform3D = at.call(Vector3(0.4, 0.8, 0.88))
		rb.call(drab, Vector3(0.16, 0.46, 0.34), 0.02, can)
		rb.call(drab, Vector3(0.05, 0.05, 0.12), 0.01, can * at.call(Vector3(0, 0.25, -0.06)))
		for d: float in [-1.0, 1.0]:
			rb.call(drab, Vector3(0.012, 0.36, 0.03), 0.005, Transform3D(Basis(Vector3.RIGHT, d * 0.62), Vector3(0.48, 0.8, 0.88)))

	# spare on the back panel
	var spare := MeshInstance3D.new()
	rig.spare_mat = ShaderMaterial.new()
	rig.spare_mat.shader = load("res://shaders/tire.gdshader")
	rig.spare_mat.set_shader_parameter("wheel_paint", rig.spec.wheel_color)
	spare.mesh = MeshKit.commit(RigWheel.build_wheel_mesh(rig.spec.tire_radius, rig.spec.tire_width, false), rig.spare_mat)
	spare.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 1.0, 1.79))
	rig.add_child(spare)
	rb.call(chassis, Vector3(0.12, 0.12, 0.1), 0.01, at.call(Vector3(0, 1.0, 1.63)))

	var chassis_mat := rig._body_mat(Color(0.05, 0.05, 0.05), 0.7, 0.2, 0.0)
	rig._add_mesh(MeshKit.commit(paint, rig.paint_mat(0.18, 1.0)))   # picked in the start menu
	rig._add_mesh(MeshKit.commit(steel, rig._body_mat(Color(0.03, 0.03, 0.032), 0.55, 0.3, 0.0)))
	rig._add_mesh(MeshKit.commit(chassis, chassis_mat))
	rig._add_mesh(MeshKit.commit(trim, rig._body_mat(Color(0.06, 0.055, 0.05), 0.6, 0.0, 0.0)))
	if trail:
		rig._add_mesh(MeshKit.commit(drab, rig._body_mat(DRAB, 0.75, 0.0, 0.0)))
		rig._add_mesh(MeshKit.commit(roof, rig._body_mat(RUST, 0.85, 0.3, 0.0)))
		rig._add_mesh(MeshKit.commit(bucket, rig._body_mat(TAN, 0.7, 0.0, 0.0)))

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
	for lens: Transform3D in lenses:
		MeshKit.lathe(lst, [Vector2(0.0, -0.02), Vector2(0.075, -0.02), Vector2(0.06, 0.0), Vector2(0.0, 0.01)], lens, c, 18)
	if trail:
		# the light bar: one long LED strip
		MeshKit.rounded_box(lst, Vector3(0.94, 0.05, 0.012), 0.006, at.call(Vector3(0, 1.88, -0.372)), c, 2)
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


## A flat panel facing forward at `z`, `half_w` wide from `y0` up to `y1`,
## its top corners rounded off by `r`, `thick` deep (the Willys grille).
static func _grille_panel(st: SurfaceTool, half_w: float, y0: float, y1: float, r: float, z: float, thick: float, col: Color) -> void:
	var outline: Array[Vector2] = [Vector2(-half_w, y0), Vector2(half_w, y0)]
	# right shoulder (0 to 90 deg), then the left (90 to 180), round the top
	for side: float in [1.0, -1.0]:
		var cx := side * (half_w - r)
		for k in range(9):
			var a := PI * 0.5 * k / 8.0 + (0.0 if side > 0.0 else PI * 0.5)
			outline.append(Vector2(cx + cos(a) * r, y1 - r + sin(a) * r))
	var front := z - thick * 0.5
	var back := z + thick * 0.5
	var mid := Vector2(0, (y0 + y1) * 0.5)
	var m := outline.size()
	for k in range(m):
		var p := outline[k]
		var q := outline[(k + 1) % m]
		for face: Array in [[front, Vector3.FORWARD], [back, Vector3.BACK]]:
			var fz: float = face[0]
			var nn: Vector3 = face[1]
			MeshKit._tri(st, Transform3D.IDENTITY, [Vector3(mid.x, mid.y, fz), Vector3(p.x, p.y, fz), Vector3(q.x, q.y, fz)], [nn, nn, nn], col)
		var e := q - p
		var side_n := Vector3(e.y, -e.x, 0).normalized()
		if side_n.dot(Vector3(p.x - mid.x, p.y - mid.y, 0)) < 0.0:
			side_n = -side_n
		MeshKit._quad(st, Transform3D.IDENTITY, [Vector3(p.x, p.y, front), Vector3(q.x, q.y, front), Vector3(q.x, q.y, back), Vector3(p.x, p.y, back)],
			[side_n, side_n, side_n, side_n], col)


## Top edge of the trail tub's side at `z`: full height at the cowl and the
## back, dipping in a smooth curve to seat height in the door opening.
static func _scoop_top(z: float) -> float:
	var w := smoothstep(-0.31, -0.06, z) * (1.0 - smoothstep(0.32, 0.6, z))
	return 1.17 - 0.36 * w


## A Willys tub side at `x`, cowl to tail: the door cutout scooped out of
## its top edge, the rear arch out of its bottom, a rolled edge along the top.
static func _scooped_side(st: SurfaceTool, x: float, rz: float, arch: float, col: Color) -> void:
	var z0 := -0.33
	var z1 := 1.58
	var bottom := 0.56
	var thick := 0.04
	var n := 64
	var out := Vector3(signf(x), 0, 0)
	var xi := x - out.x * thick
	var rail := PackedVector3Array()
	var radii := PackedFloat32Array()
	var prev: Array[Vector3] = []
	for i in range(n + 1):
		var z := lerpf(z0, z1, float(i) / n)
		var top := _scoop_top(z)
		var yb := bottom
		var dz := z - rz
		if absf(dz) < arch:
			yb = maxf(yb, KuwarentaBody.HUB_Y + sqrt(arch * arch - dz * dz))
		yb = minf(yb, top - 0.02)
		# outer bottom, outer top, inner top, inner bottom
		var cur: Array[Vector3] = [Vector3(x, yb, z), Vector3(x, top, z), Vector3(xi, top, z), Vector3(xi, yb, z)]
		if i > 0:
			MeshKit._quad(st, Transform3D.IDENTITY, [prev[0], cur[0], cur[1], prev[1]], [out, out, out, out], col)
			MeshKit._quad(st, Transform3D.IDENTITY, [prev[3], cur[3], cur[2], prev[2]], [-out, -out, -out, -out], col)
			var down := (cur[0] - prev[0]).cross(out).normalized()
			if down.y > 0.0:
				down = -down
			MeshKit._quad(st, Transform3D.IDENTITY, [prev[0], cur[0], cur[3], prev[3]], [down, down, down, down], col)
		prev = cur
		rail.append(Vector3(x - out.x * thick * 0.5, top, z))
		radii.append(0.026)
	MeshKit.sweep(st, rail, radii, Transform3D.IDENTITY, col, 8)

