class_name KuwarentaBody
extends RefCounted
## The Kuwarenta: a forty-series-style hardtop. Flat-sided steel body in the
## paint picked in the menu with the white top over it, short flat hood, round
## headlights set in the fronts of the fenders and a slotted grille between,
## upright windshield, twin rear doors with the spare, steel bumpers and a
## winch. Lifted on 33s. No badges: it's a type, not a brand.
## Rig space: forward -Z, left -X, wheel hubs at y~0.13.

const TOP := Color(0.88, 0.88, 0.85)   # the white hardtop
const SILL := 0.5                      # bottom edge of the body
const BELT := 1.13                     # where the windows start
const ROOF := 1.9
const HALF_W := 0.8                    # body half-width
const COWL_Z := -0.46
const TAIL_Z := 1.74
const NOSE_Z := -1.8
const HUB_Y := 0.13


static func build(rig: Rig) -> void:
	BodyKit.collide(rig, COWL_Z, TAIL_Z, 0.55, 1.17, HALF_W)          # body
	BodyKit.collide(rig, NOSE_Z, COWL_Z, 0.58, 1.1, HALF_W + 0.01)    # front clip
	for col: Array in [
		[Vector3(1.58, 0.76, 2.18), Vector3(0, 1.52, 0.64)],  # cab under the top
		[Vector3(1.72, 0.16, 0.16), Vector3(0, 0.6, -1.9)],   # bumper
	]:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = col[0]
		cs.shape = box
		cs.position = col[1]
		rig.add_child(cs)

	var paint := MeshKit.begin()
	var top := MeshKit.begin()       # white hardtop
	var steel := MeshKit.begin()     # bumpers, winch, mirrors: satin black
	var bright := MeshKit.begin()    # grille, bezels, handles: brushed steel
	var chassis := MeshKit.begin()
	var trim := MeshKit.begin()      # seats, dash pad
	var c := Color.WHITE
	var at := func(p: Vector3) -> Transform3D: return Transform3D(Basis.IDENTITY, p)
	var rb := func(st: SurfaceTool, size: Vector3, r: float, xf: Transform3D) -> void:
		MeshKit.rounded_box(st, size, r, xf, c)
	var fz := rig.spec.front_z
	var rz := rig.spec.rear_z
	var arch := BodyKit.well_radius(rig.spec)   # the cut clears a tire at the bump stop

	# frame and crossmembers
	for sx: float in [-1.0, 1.0]:
		rb.call(chassis, Vector3(0.08, 0.14, 3.5), 0.01, at.call(Vector3(sx * 0.42, 0.45, -0.05)))
	for z: float in [-1.75, -0.4, 0.6, 1.62]:
		rb.call(chassis, Vector3(0.84, 0.08, 0.08), 0.01, at.call(Vector3(0, 0.45, z)))

	# body tub: floor, sides with the rear arch cut, back panel, cowl and dash
	BodyKit.floor_panel(paint, rig.spec, COWL_Z, TAIL_Z, HALF_W - 0.02, SILL + 0.01, c)
	BodyKit.wheel_houses(paint, rig.spec, rz, HALF_W, SILL, c)
	BodyKit.wheel_houses(paint, rig.spec, fz, HALF_W + 0.03, 0.6, c)
	for sx: float in [-1.0, 1.0]:
		_side_panel(paint, sx * HALF_W, COWL_Z, TAIL_Z, SILL, BELT, [[rz, arch]], 0.035, c)
		# rear arch: a rolled lip round the cut
		_arch_lip(paint, sx * HALF_W, rz, arch, SILL, c)
		# door shut lines and handles
		rb.call(chassis, Vector3(0.006, BELT - SILL - 0.06, 0.008), 0.002, at.call(Vector3(sx * (HALF_W + 0.018), (BELT + SILL) * 0.5, 0.52)))
		rb.call(bright, Vector3(0.025, 0.025, 0.12), 0.008, at.call(Vector3(sx * (HALF_W + 0.025), BELT - 0.09, 0.4)))
		# body-colour belt rail along the top of the sides
		rb.call(paint, Vector3(0.06, 0.04, TAIL_Z - COWL_Z), 0.015, at.call(Vector3(sx * (HALF_W - 0.01), BELT, (TAIL_Z + COWL_Z) * 0.5)))
	rb.call(paint, Vector3(1.62, BELT - SILL, 0.04), 0.02, at.call(Vector3(0, (BELT + SILL) * 0.5, TAIL_Z)))
	rb.call(chassis, Vector3(0.008, BELT - SILL - 0.05, 0.006), 0.002, at.call(Vector3(-0.08, (BELT + SILL) * 0.5, TAIL_Z + 0.022)))
	rb.call(paint, Vector3(1.62, BELT - SILL + 0.02, 0.04), 0.02, at.call(Vector3(0, (BELT + SILL) * 0.5, COWL_Z)))
	rb.call(paint, Vector3(1.62, 0.07, 0.26), 0.03, at.call(Vector3(0, BELT + 0.02, COWL_Z - 0.08)))
	rb.call(trim, Vector3(1.3, 0.1, 0.2), 0.04, at.call(Vector3(0, BELT - 0.04, COWL_Z + 0.12)))

	# front fenders: flat tops with a rounded outer edge, the front faces
	# carry the headlights, the arch cut round the front tire
	var fender_in := 0.53
	var fw := HALF_W + 0.03 - fender_in
	var fx := (HALF_W + 0.03 + fender_in) * 0.5
	var fender_top := 1.04
	var fender_front := 0.6
	for sx: float in [-1.0, 1.0]:
		rb.call(paint, Vector3(fw, 0.05, COWL_Z - NOSE_Z), 0.022, at.call(Vector3(sx * fx, fender_top, (COWL_Z + NOSE_Z) * 0.5)))
		_side_panel(paint, sx * (HALF_W + 0.03), NOSE_Z + 0.03, COWL_Z, SILL, fender_top, [[fz, arch]], 0.035, c, fender_front)
		_arch_lip(paint, sx * (HALF_W + 0.03), fz, arch, fender_front, c)
		rb.call(paint, Vector3(fw, fender_top - fender_front + 0.03, 0.05), 0.022, at.call(Vector3(sx * fx, (fender_top + fender_front) * 0.5, NOSE_Z)))
		# inner fender apron beside the engine
		rb.call(paint, Vector3(0.03, fender_top - 0.62, COWL_Z - NOSE_Z), 0.01, at.call(Vector3(sx * fender_in, (fender_top + 0.62) * 0.5, (COWL_Z + NOSE_Z) * 0.5)))
		# headlight bezel and lens on the fender face, signal lamp under it
		var bez := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx * fx, 0.9, NOSE_Z - 0.03))
		MeshKit.lathe(bright, [Vector2(0.07, -0.025), Vector2(0.1, -0.025), Vector2(0.104, 0.0),
			Vector2(0.098, 0.025), Vector2(0.078, 0.025)], bez, c, 24)
		# mirror on the cowl
		MeshKit.tube(steel, Vector3(sx * (HALF_W + 0.02), BELT + 0.05, COWL_Z + 0.05), Vector3(sx * (HALF_W + 0.16), BELT + 0.25, COWL_Z - 0.02), 0.01, Transform3D.IDENTITY, c, 6)
		MeshKit.cylinder(steel, 0.075, 0.025, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx * (HALF_W + 0.17), BELT + 0.27, COWL_Z - 0.03)), c, 16)

	# hood: flat, a slight crown, between the fenders
	rb.call(paint, Vector3(fender_in * 2.0 + 0.02, 0.06, COWL_Z - NOSE_Z - 0.04), 0.025, at.call(Vector3(0, 1.085, (COWL_Z + NOSE_Z) * 0.5 - 0.01)))
	rb.call(paint, Vector3(0.5, 0.03, COWL_Z - NOSE_Z - 0.2), 0.012, at.call(Vector3(0, 1.12, (COWL_Z + NOSE_Z) * 0.5)))

	# grille: a bright slotted panel between the fenders
	rb.call(bright, Vector3(fender_in * 2.0, 0.44, 0.04), 0.02, at.call(Vector3(0, 0.86, NOSE_Z + 0.01)))
	for k in range(9):
		rb.call(chassis, Vector3(0.04, 0.34, 0.02), 0.008, at.call(Vector3((k - 4) * 0.1, 0.85, NOSE_Z - 0.006)))
	rb.call(paint, Vector3(fender_in * 2.0, 0.08, 0.05), 0.02, at.call(Vector3(0, 0.6, NOSE_Z + 0.02)))

	# windshield: nearly upright frame on the cowl
	var ws := Transform3D(Basis(Vector3.RIGHT, 0.1), Vector3(0, BELT + 0.04, COWL_Z - 0.06))
	var wh := ROOF - BELT - 0.09
	rb.call(paint, Vector3(1.6, 0.05, 0.05), 0.015, ws * at.call(Vector3(0, 0.0, 0)))
	rb.call(paint, Vector3(1.6, 0.05, 0.05), 0.015, ws * at.call(Vector3(0, wh, 0)))
	for sx: float in [-1.0, 1.0]:
		rb.call(paint, Vector3(0.06, wh, 0.05), 0.015, ws * at.call(Vector3(sx * 0.77, wh * 0.5, 0)))
	rb.call(paint, Vector3(0.03, wh, 0.035), 0.01, ws * at.call(Vector3(0, wh * 0.5, 0)))
	for sx: float in [-1.0, 1.0]:
		MeshKit.tube(steel, ws * Vector3(sx * 0.38 - 0.22, 0.04, -0.03), ws * Vector3(sx * 0.38 + 0.1, 0.4, -0.03), 0.006, Transform3D.IDENTITY, c, 5)

	# the white hardtop: roof, rain gutters, pillars, window frames
	var top_z0 := COWL_Z - 0.06 + sin(0.1) * wh
	rb.call(top, Vector3(1.64, 0.06, TAIL_Z - top_z0 + 0.03), 0.035, at.call(Vector3(0, ROOF, (TAIL_Z + top_z0) * 0.5)))
	for sx: float in [-1.0, 1.0]:
		rb.call(top, Vector3(0.03, 0.025, TAIL_Z - top_z0), 0.01, at.call(Vector3(sx * 0.815, ROOF - 0.035, (TAIL_Z + top_z0) * 0.5)))
		# pillars: behind the door, the wide rear quarter, the back corner
		for p: Array in [[0.54, 0.09], [1.04, 0.05], [TAIL_Z - 0.05, 0.12]]:
			rb.call(top, Vector3(0.04, ROOF - BELT, float(p[1])), 0.012, at.call(Vector3(sx * HALF_W, (ROOF + BELT) * 0.5, float(p[0]))))
		rb.call(top, Vector3(0.04, 0.05, TAIL_Z - 0.54), 0.012, at.call(Vector3(sx * HALF_W, BELT + 0.04, (TAIL_Z + 0.54) * 0.5)))
		# door window frame (body colour, like the doors)
		rb.call(paint, Vector3(0.035, 0.03, 0.98), 0.01, at.call(Vector3(sx * HALF_W, ROOF - 0.06, 0.03)))
	# back of the top: a frame round the two rear-door windows
	var bh := ROOF - BELT
	rb.call(top, Vector3(1.62, 0.07, 0.04), 0.015, at.call(Vector3(0, ROOF - 0.04, TAIL_Z)))
	rb.call(top, Vector3(1.62, 0.07, 0.04), 0.015, at.call(Vector3(0, BELT + 0.04, TAIL_Z)))
	for px: float in [-0.76, -0.04, 0.04, 0.76]:
		rb.call(top, Vector3(0.09 if absf(px) > 0.5 else 0.07, bh, 0.04), 0.015, at.call(Vector3(px, (ROOF + BELT) * 0.5, TAIL_Z)))

	# seats, rear bench, steering column, shifters
	var seat := rig.spec.seat
	for sx: float in [-1.0, 1.0]:
		rb.call(trim, Vector3(0.46, 0.13, 0.46), 0.05, at.call(Vector3(sx * absf(seat.x), seat.y - 0.12, seat.z - 0.07)))
		var back := Transform3D(Basis(Vector3.RIGHT, 0.16), Vector3(sx * absf(seat.x), seat.y + 0.2, seat.z + 0.2))
		rb.call(trim, Vector3(0.44, 0.58, 0.1), 0.045, back)
	rb.call(trim, Vector3(1.3, 0.13, 0.42), 0.05, at.call(Vector3(0, 0.7, 1.3)))
	rb.call(trim, Vector3(1.3, 0.45, 0.09), 0.04, Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0, 0.98, 1.56)))
	MeshKit.tube(chassis, Vector3(seat.x, BELT - 0.06, COWL_Z + 0.02), rig.spec.wheel_at, 0.022, Transform3D.IDENTITY, c)
	MeshKit.tube(chassis, Vector3(0.02, 0.6, -0.12), Vector3(0.0, 1.0, -0.02), 0.012, Transform3D.IDENTITY, c, 6)
	MeshKit.tube(chassis, Vector3(0.1, 0.6, -0.12), Vector3(0.12, 0.94, -0.04), 0.01, Transform3D.IDENTITY, c, 6)

	# bumpers and the winch
	rb.call(steel, Vector3(1.72, 0.14, 0.14), 0.025, at.call(Vector3(0, 0.6, -1.9)))
	rb.call(steel, Vector3(1.64, 0.12, 0.12), 0.025, at.call(Vector3(0, 0.58, TAIL_Z + 0.1)))
	MeshKit.cylinder(chassis, 0.08, 0.44, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 0.72, -1.88)), c, 16)
	for sx: float in [-1.0, 1.0]:
		MeshKit.cylinder(chassis, 0.095, 0.06, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(sx * 0.25, 0.72, -1.88)), c, 16)
		rb.call(steel, Vector3(0.04, 0.12, 0.04), 0.01, at.call(Vector3(sx * 0.62, 0.6, -1.99)))
	rb.call(steel, Vector3(0.22, 0.08, 0.05), 0.015, at.call(Vector3(0, 0.72, -1.97)))

	# spare on a swing-out carrier at the back, off to the left
	var spare := MeshInstance3D.new()
	rig.spare_mat = ShaderMaterial.new()
	rig.spare_mat.shader = load("res://shaders/tire.gdshader")
	spare.mesh = MeshKit.commit(RigWheel.build_wheel_mesh(rig.spec.tire_radius, rig.spec.tire_width, false), rig.spare_mat)
	spare.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-0.38, 1.12, TAIL_Z + 0.22))
	rig.add_child(spare)
	rb.call(chassis, Vector3(0.12, 0.12, 0.14), 0.01, at.call(Vector3(-0.38, 1.12, TAIL_Z + 0.05)))

	var chassis_mat := rig._body_mat(Color(0.05, 0.05, 0.05), 0.7, 0.2, 0.0)
	rig._add_mesh(MeshKit.commit(paint, rig.paint_mat(0.22, 0.8)))   # picked in the start menu
	rig._add_mesh(MeshKit.commit(top, rig._body_mat(TOP, 0.3, 0.0, 0.6)))
	rig._add_mesh(MeshKit.commit(steel, rig._body_mat(Color(0.03, 0.03, 0.032), 0.55, 0.3, 0.0)))
	rig._add_mesh(MeshKit.commit(bright, rig._body_mat(Color(0.62, 0.63, 0.62), 0.32, 0.85, 0.0)))
	rig._add_mesh(MeshKit.commit(chassis, chassis_mat))
	rig._add_mesh(MeshKit.commit(trim, rig._body_mat(Color(0.06, 0.055, 0.05), 0.6, 0.0, 0.0)))

	# glass: windshield, door and quarter windows, the back doors
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.5, 0.58, 0.62, 0.25)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic_specular = 0.9
	var gst := MeshKit.begin()
	for sx: float in [-1.0, 1.0]:
		MeshKit.rounded_box(gst, Vector3(0.72, wh - 0.06, 0.008), 0.004, ws * at.call(Vector3(sx * 0.38, wh * 0.5, 0)), c, 1)
		var wy := (ROOF - 0.08 + BELT + 0.07) * 0.5
		var wy_h := ROOF - 0.08 - BELT - 0.07
		MeshKit.rounded_box(gst, Vector3(0.008, wy_h, 0.94), 0.004, at.call(Vector3(sx * HALF_W, wy, 0.03)), c, 1)
		MeshKit.rounded_box(gst, Vector3(0.008, wy_h, 0.42), 0.03, at.call(Vector3(sx * HALF_W, wy, 0.8)), c, 1)
		MeshKit.rounded_box(gst, Vector3(0.008, wy_h, 0.5), 0.03, at.call(Vector3(sx * HALF_W, wy, 1.38)), c, 1)
		MeshKit.rounded_box(gst, Vector3(0.62, wy_h, 0.008), 0.03, at.call(Vector3(sx * 0.4, wy, TAIL_Z + 0.022)), c, 1)
	rig._add_mesh(MeshKit.commit(gst, glass))
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color(0.95, 0.93, 0.85)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.92, 0.7)
	lamp.emission_energy_multiplier = 1.2
	lamp.roughness = 0.1
	var lst := MeshKit.begin()
	for sx: float in [-1.0, 1.0]:
		var lens := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx * fx, 0.9, NOSE_Z - 0.035))
		MeshKit.lathe(lst, [Vector2(0.0, -0.02), Vector2(0.082, -0.02), Vector2(0.065, 0.0), Vector2(0.0, 0.012)], lens, c, 20)
	rig._add_mesh(MeshKit.commit(lst, lamp))
	var amber := StandardMaterial3D.new()
	amber.albedo_color = Color(0.9, 0.5, 0.08)
	amber.emission_enabled = true
	amber.emission = Color(0.9, 0.45, 0.05)
	amber.emission_energy_multiplier = 0.3
	var ast := MeshKit.begin()
	for sx: float in [-1.0, 1.0]:
		MeshKit.cylinder(ast, 0.035, 0.03, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx * fx, 0.77, NOSE_Z - 0.03)), c, 12)
	rig._add_mesh(MeshKit.commit(ast, amber))
	var tail := StandardMaterial3D.new()
	tail.albedo_color = Color(0.5, 0.03, 0.02)
	tail.emission_enabled = true
	tail.emission = Color(0.8, 0.05, 0.02)
	tail.emission_energy_multiplier = 0.4
	var tst := MeshKit.begin()
	for sx: float in [-1.0, 1.0]:
		MeshKit.rounded_box(tst, Vector3(0.08, 0.16, 0.03), 0.012, at.call(Vector3(sx * 0.72, 0.9, TAIL_Z + 0.03)), c, 2)
	rig._add_mesh(MeshKit.commit(tst, tail))

	# whip with an orange flag off the back corner
	var whip_base := Vector3(0.72, ROOF + 0.02, TAIL_Z - 0.1)
	var wst := MeshKit.begin()
	MeshKit.tube(wst, whip_base, whip_base + Vector3(0, 1.6, 0), 0.006, Transform3D.IDENTITY, c, 5)
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
	rig._flag.position = whip_base + Vector3(0, 1.58, 0)


## A flat body side at `x` from z0 to z1, from `bottom` up to `top_y`, with
## round wheel arches cut out of its lower edge ([centre z, radius] each).
## `front_bottom`, if set, lifts the bottom edge at z0 (a fender's front).
static func _side_panel(st: SurfaceTool, x: float, z0: float, z1: float, bottom: float, top_y: float,
		arches: Array, thick: float, col: Color, front_bottom := -1.0) -> void:
	var n := 48
	var out := Vector3(signf(x), 0, 0)
	var xi := x - out.x * thick
	var prev_top: Array[Vector3] = []
	var prev_bot: Array[Vector3] = []
	for i in range(n + 1):
		var z := lerpf(z0, z1, float(i) / n)
		var yb := bottom
		if front_bottom > 0.0:
			yb = lerpf(front_bottom, bottom, smoothstep(z0, z0 + 0.35, z))
		for a: Array in arches:
			var dz := z - float(a[0])
			var r: float = a[1]
			if absf(dz) < r:
				yb = maxf(yb, HUB_Y + sqrt(r * r - dz * dz))
		yb = minf(yb, top_y - 0.02)
		var t: Array[Vector3] = [Vector3(x, top_y, z), Vector3(xi, top_y, z)]
		var b: Array[Vector3] = [Vector3(x, yb, z), Vector3(xi, yb, z)]
		if i > 0:
			for k in range(2):
				var nn := out if k == 0 else -out
				MeshKit._quad(st, Transform3D.IDENTITY, [prev_bot[k], b[k], t[k], prev_top[k]], [nn, nn, nn, nn], col)
			# the bottom edge, facing down (and out of the arch)
			var down := (b[0] - prev_bot[0]).cross(out).normalized()
			if down.y > 0.0:
				down = -down
			MeshKit._quad(st, Transform3D.IDENTITY, [prev_bot[0], b[0], b[1], prev_bot[1]], [down, down, down, down], col)
		prev_top = t
		prev_bot = b


## A rolled lip round a wheel arch on the side at `x`, down to `floor_y`.
static func _arch_lip(st: SurfaceTool, x: float, zc: float, r: float, floor_y: float, col: Color) -> void:
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	var lim := acos(clampf((floor_y - HUB_Y) / r, -1.0, 1.0))
	var n := 20
	for i in range(n + 1):
		var a := lerpf(-lim, lim, float(i) / n)
		pts.append(Vector3(x + signf(x) * 0.012, HUB_Y + cos(a) * r, zc + sin(a) * r))
		radii.append(0.022)
	MeshKit.sweep(st, pts, radii, Transform3D.IDENTITY, col, 8)
