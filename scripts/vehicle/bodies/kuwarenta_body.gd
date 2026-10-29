class_name KuwarentaBody
extends RefCounted
## The Kuwarenta: a forty-series-style rig the way they run on the trail,
## top off. Flat-sided steel tub in the paint picked in the menu, round
## front fenders that flare out over the tires, a flat grille panel carrying
## both headlights with a dark mesh between them, a wide hood with a crowned
## middle, a low raked windshield and a roll bar over the seats. Steel
## bumpers, winch, spare on the back. Lifted on 33s. No badges: it's a type,
## not a brand.
## Rig space: forward -Z, left -X, wheel hubs at y~0.13.

const SILL := 0.5                      # bottom edge of the body
const BELT := 1.13                     # top edge of the tub
const HALF_W := 0.8                    # body half-width
const COWL_Z := -0.46
const TAIL_Z := 1.74
const NOSE_Z := -1.8
const HUB_Y := 0.13
# front fenders: inner edge by the hood, outer face over the tire
const FX_IN := 0.6
const FX_OUT := 0.9
const F_TOP := 1.05
const F_SHOULDER := 0.12               # radius of the rounded top edge
const F_FRONT := 0.62                  # bottom of the fender at the nose
const HOOD_Y := 1.06
# headlights in the grille panel
const HL_X := 0.46
const HL_Y := 0.83
# windshield: low, raked back a little
const WS_TILT := 0.2
const WS_H := 0.5
# roll bar hoop behind the front seats
const HOOP_Z := 0.66
const HOOP_X := 0.72
const HOOP_TOP := 1.86


static func build(rig: Rig) -> void:
	BodyKit.collide(rig, COWL_Z, TAIL_Z, 0.55, 1.17, HALF_W)          # body
	BodyKit.collide(rig, NOSE_Z, COWL_Z, 0.58, 1.1, FX_OUT)           # front clip
	for col: Array in [
		[Vector3(1.48, 0.62, 1.24), Vector3(0, 1.5, 0.08)],   # windshield to roll bar
		[Vector3(1.48, 0.5, 1.0), Vector3(0, 1.4, 1.2)],      # roll bar back to the tail
		[Vector3(1.72, 0.16, 0.16), Vector3(0, 0.6, -1.9)],   # bumper
	]:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = col[0]
		cs.shape = box
		cs.position = col[1]
		rig.add_child(cs)

	var paint := MeshKit.begin()
	var steel := MeshKit.begin()     # bumpers, roll bar, winch, mirrors: satin black
	var bright := MeshKit.begin()    # bezels, handles: brushed steel
	var chassis := MeshKit.begin()   # frame, grille mesh
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
	BodyKit.wheel_houses(paint, rig.spec, fz, FX_OUT, F_FRONT, c)
	for sx: float in [-1.0, 1.0]:
		_side_panel(paint, sx * HALF_W, COWL_Z, TAIL_Z, SILL, BELT, [[rz, arch]], 0.035, c)
		# rear arch: a rolled lip round the cut
		_arch_lip(paint, sx * HALF_W, rz, arch, SILL, c)
		# door shut lines and handles
		rb.call(chassis, Vector3(0.006, BELT - SILL - 0.06, 0.008), 0.002, at.call(Vector3(sx * (HALF_W + 0.018), (BELT + SILL) * 0.5, 0.52)))
		rb.call(bright, Vector3(0.025, 0.025, 0.12), 0.008, at.call(Vector3(sx * (HALF_W + 0.025), BELT - 0.09, 0.4)))
		# body-colour rail rolled over the top of the sides
		rb.call(paint, Vector3(0.06, 0.04, TAIL_Z - COWL_Z), 0.015, at.call(Vector3(sx * (HALF_W - 0.01), BELT, (TAIL_Z + COWL_Z) * 0.5)))
	rb.call(paint, Vector3(1.62, BELT - SILL, 0.04), 0.02, at.call(Vector3(0, (BELT + SILL) * 0.5, TAIL_Z)))
	rb.call(paint, Vector3(1.62, 0.04, 0.06), 0.015, at.call(Vector3(0, BELT, TAIL_Z)))
	rb.call(chassis, Vector3(1.4, 0.006, 0.006), 0.002, at.call(Vector3(0, BELT - 0.12, TAIL_Z + 0.022)))   # tailgate seam
	rb.call(paint, Vector3(1.62, BELT - SILL + 0.02, 0.04), 0.02, at.call(Vector3(0, (BELT + SILL) * 0.5, COWL_Z)))
	rb.call(paint, Vector3(1.62, 0.07, 0.26), 0.03, at.call(Vector3(0, BELT + 0.02, COWL_Z - 0.08)))
	rb.call(trim, Vector3(1.3, 0.1, 0.2), 0.04, at.call(Vector3(0, BELT - 0.04, COWL_Z + 0.12)))

	# front fenders: round-shouldered, flared out over the tires, the arch cut
	# round the front tire and a rolled lip on it
	for sx: float in [-1.0, 1.0]:
		_fender(paint, sx, fz, arch, c)
		_arch_lip(paint, sx * (FX_OUT + 0.02), fz, arch, F_FRONT, c)
		# inner fender apron beside the engine
		rb.call(paint, Vector3(0.03, F_TOP - 0.62, COWL_Z - NOSE_Z), 0.01, at.call(Vector3(sx * FX_IN, (F_TOP + 0.62) * 0.5, (COWL_Z + NOSE_Z) * 0.5)))
		# mirror on the cowl
		MeshKit.tube(steel, Vector3(sx * (HALF_W + 0.02), BELT + 0.05, COWL_Z + 0.05), Vector3(sx * (HALF_W + 0.16), BELT + 0.25, COWL_Z - 0.02), 0.01, Transform3D.IDENTITY, c, 6)
		MeshKit.cylinder(steel, 0.075, 0.025, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx * (HALF_W + 0.17), BELT + 0.27, COWL_Z - 0.03)), c, 16)

	# hood: wide, a raised crown down the middle, the front edge rolled down
	_hood(paint, c)

	# grille panel: flat, between the fenders, both headlights in it and a
	# dark mesh between them
	var gz := NOSE_Z + 0.05
	rb.call(paint, Vector3(FX_IN * 2.0, 0.44, 0.04), 0.015, at.call(Vector3(0, 0.8, gz)))
	rb.call(chassis, Vector3(0.52, 0.26, 0.03), 0.012, at.call(Vector3(0, 0.84, gz - 0.012)))
	for k in range(7):
		rb.call(steel, Vector3(0.5, 0.008, 0.012), 0.003, at.call(Vector3(0, 0.73 + k * 0.037, gz - 0.03)))
	for k in range(13):
		rb.call(steel, Vector3(0.008, 0.24, 0.012), 0.003, at.call(Vector3((k - 6) * 0.04, 0.84, gz - 0.032)))
	for sx: float in [-1.0, 1.0]:
		var bez := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx * HL_X, HL_Y, gz - 0.03))
		MeshKit.lathe(bright, [Vector2(0.075, -0.03), Vector2(0.1, -0.03), Vector2(0.106, 0.0),
			Vector2(0.1, 0.03), Vector2(0.08, 0.03)], bez, c, 24)

	# windshield: a low frame raked back on the cowl, a hinge at each foot
	var ws := Transform3D(Basis(Vector3.RIGHT, WS_TILT), Vector3(0, BELT + 0.06, COWL_Z - 0.08))
	rb.call(paint, Vector3(1.56, 0.06, 0.05), 0.015, ws * at.call(Vector3(0, 0.0, 0)))
	rb.call(paint, Vector3(1.56, 0.045, 0.045), 0.015, ws * at.call(Vector3(0, WS_H, 0)))
	for sx: float in [-1.0, 1.0]:
		rb.call(paint, Vector3(0.05, WS_H, 0.045), 0.015, ws * at.call(Vector3(sx * 0.755, WS_H * 0.5, 0)))
		rb.call(chassis, Vector3(0.06, 0.05, 0.08), 0.01, at.call(Vector3(sx * 0.7, BELT + 0.04, COWL_Z - 0.06)))
		MeshKit.tube(steel, ws * Vector3(sx * 0.36 - 0.2, 0.05, -0.03), ws * Vector3(sx * 0.36 + 0.08, 0.32, -0.03), 0.006, Transform3D.IDENTITY, c, 5)

	# roll bar: a hoop behind the front seats, bars forward to the windshield
	# corners and back down to the tail
	var tl := Vector3(-HOOP_X, HOOP_TOP, HOOP_Z)
	var tr := Vector3(HOOP_X, HOOP_TOP, HOOP_Z)
	var ws_top_l := ws * Vector3(-0.74, WS_H, 0.03)
	var ws_top_r := ws * Vector3(0.74, WS_H, 0.03)
	var bars: Array = [
		[Vector3(-HOOP_X, BELT, HOOP_Z), tl], [Vector3(HOOP_X, BELT, HOOP_Z), tr], [tl, tr],
		[tl, ws_top_l], [tr, ws_top_r],
		[tl, Vector3(-HOOP_X, BELT, TAIL_Z - 0.12)], [tr, Vector3(HOOP_X, BELT, TAIL_Z - 0.12)],
		[Vector3(-HOOP_X, BELT + 0.25, HOOP_Z), Vector3(HOOP_X, HOOP_TOP - 0.05, HOOP_Z)],   # diagonal brace
	]
	for bar: Array in bars:
		MeshKit.tube(steel, bar[0], bar[1], 0.026, Transform3D.IDENTITY, c, 10)
	for p: Vector3 in [tl, tr, ws_top_l, ws_top_r]:
		MeshKit.sphere(steel, 0.03, at.call(p), c, 10)
	for sx: float in [-1.0, 1.0]:
		rb.call(steel, Vector3(0.1, 0.02, 0.1), 0.005, at.call(Vector3(sx * HOOP_X, BELT + 0.01, HOOP_Z)))
		rb.call(steel, Vector3(0.1, 0.02, 0.1), 0.005, at.call(Vector3(sx * HOOP_X, BELT + 0.01, TAIL_Z - 0.12)))

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
	MeshKit.cylinder(chassis, 0.08, 0.44, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 0.72, -1.9)), c, 16)
	for sx: float in [-1.0, 1.0]:
		MeshKit.cylinder(chassis, 0.095, 0.06, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(sx * 0.25, 0.72, -1.9)), c, 16)
		rb.call(steel, Vector3(0.04, 0.12, 0.04), 0.01, at.call(Vector3(sx * 0.62, 0.6, -1.99)))
	rb.call(steel, Vector3(0.22, 0.08, 0.05), 0.015, at.call(Vector3(0, 0.72, -1.99)))

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
	rig._add_mesh(MeshKit.commit(steel, rig._body_mat(Color(0.03, 0.03, 0.032), 0.55, 0.3, 0.0)))
	rig._add_mesh(MeshKit.commit(bright, rig._body_mat(Color(0.62, 0.63, 0.62), 0.32, 0.85, 0.0)))
	rig._add_mesh(MeshKit.commit(chassis, chassis_mat))
	rig._add_mesh(MeshKit.commit(trim, rig._body_mat(Color(0.06, 0.055, 0.05), 0.6, 0.0, 0.0)))

	# glass: just the windshield
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.5, 0.58, 0.62, 0.25)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic_specular = 0.9
	var gst := MeshKit.begin()
	MeshKit.rounded_box(gst, Vector3(1.46, WS_H - 0.05, 0.008), 0.004, ws * at.call(Vector3(0, WS_H * 0.5, 0)), c, 1)
	rig._add_mesh(MeshKit.commit(gst, glass))
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color(0.95, 0.93, 0.85)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.92, 0.7)
	lamp.emission_energy_multiplier = 1.2
	lamp.roughness = 0.1
	var lst := MeshKit.begin()
	for sx: float in [-1.0, 1.0]:
		var lens := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx * HL_X, HL_Y, gz - 0.035))
		MeshKit.lathe(lst, [Vector2(0.0, -0.022), Vector2(0.084, -0.022), Vector2(0.068, 0.0), Vector2(0.0, 0.012)], lens, c, 20)
	rig._add_mesh(MeshKit.commit(lst, lamp))
	var amber := StandardMaterial3D.new()
	amber.albedo_color = Color(0.9, 0.5, 0.08)
	amber.emission_enabled = true
	amber.emission = Color(0.9, 0.45, 0.05)
	amber.emission_energy_multiplier = 0.3
	var ast := MeshKit.begin()
	for sx: float in [-1.0, 1.0]:
		# signal lamps on the fronts of the fenders, beside the headlights
		MeshKit.cylinder(ast, 0.04, 0.03, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx * 0.73, 0.82, NOSE_Z - 0.01)), c, 12)
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


## One front fender on side `sx`: a sheet from the inner edge by the hood over
## a rounded shoulder and down the outer face, flaring out at its bottom edge,
## which follows the wheel arch round the axle at `fz`. The top drops in a
## curve at the nose, and both ends are closed.
static func _fender(st: SurfaceTool, sx: float, fz: float, arch: float, col: Color) -> void:
	var rows: Array[PackedVector3Array] = []
	var refs: Array[Vector3] = []
	var n := 40
	for i in range(n + 1):
		var z := lerpf(NOSE_Z, COWL_Z, float(i) / n)
		var t := clampf((NOSE_Z + 0.24 - z) / 0.24, 0.0, 1.0)
		var top := F_TOP - 0.14 * (1.0 - sqrt(1.0 - t * t))
		var yb := lerpf(F_FRONT, SILL, smoothstep(COWL_Z - 0.3, COWL_Z, z))
		var dz := z - fz
		if absf(dz) < arch:
			yb = maxf(yb, HUB_Y + sqrt(arch * arch - dz * dz))
		yb = minf(yb, top - F_SHOULDER - 0.03)
		var row := PackedVector3Array()
		for k in range(3):
			row.append(Vector3(lerpf(FX_IN, FX_OUT - F_SHOULDER, k / 3.0), top, z))
		for k in range(7):
			var a := PI * 0.5 * k / 6.0
			row.append(Vector3(FX_OUT - F_SHOULDER + sin(a) * F_SHOULDER, top - F_SHOULDER + cos(a) * F_SHOULDER, z))
		for k in range(1, 4):
			row.append(Vector3(FX_OUT + 0.012 * k / 3.0, lerpf(top - F_SHOULDER, yb + 0.03, k / 3.0), z))
		row.append(Vector3(FX_OUT + 0.03, yb, z))
		for k in range(row.size()):
			row[k] = Vector3(row[k].x * sx, row[k].y, row[k].z)
		rows.append(row)
		refs.append(Vector3(sx * FX_IN, 0.5, z))
	_shell(st, rows, refs, 0.025, col)
	# close the nose and the back: the section filled in down to its bottom edge
	for end: Array in [[0, -1.0], [n, 1.0]]:
		var row: PackedVector3Array = rows[end[0]]
		var nn := Vector3(0, 0, end[1])
		var last := row[row.size() - 1]
		var corner := Vector3(sx * FX_IN, last.y, last.z)
		var mid := (row[0] + corner) * 0.5 + Vector3(sx * 0.1, 0, 0)
		var loop: Array[Vector3] = []
		for p in row:
			loop.append(p)
		loop.append(corner)
		for k in range(loop.size()):
			MeshKit._tri(st, Transform3D.IDENTITY, [mid, loop[k], loop[(k + 1) % loop.size()]], [nn, nn, nn], col)


## The hood: between the fenders from the nose to the cowl, crowned in the
## middle with its sides and front edge rolled down.
static func _hood(st: SurfaceTool, col: Color) -> void:
	var rows: Array[PackedVector3Array] = []
	var refs: Array[Vector3] = []
	var hw := FX_IN + 0.03
	var z0 := NOSE_Z + 0.03
	var z1 := COWL_Z - 0.03
	var n := 16
	for i in range(n + 1):
		var z := lerpf(z0, z1, float(i) / n)
		var drop := 0.05 * pow(clampf((z0 + 0.08 - z) / 0.08, 0.0, 1.0), 2.0)
		var row := PackedVector3Array()
		for k in range(21):
			var x := lerpf(-hw, hw, k / 20.0)
			var ax := absf(x)
			var y := HOOD_Y + 0.02 * (1.0 - pow(x / hw, 2.0))
			y += 0.022 * smoothstep(0.27, 0.19, ax)              # the raised middle
			y -= 0.035 * smoothstep(hw - 0.06, hw, ax)           # sides rolled down
			row.append(Vector3(x, y - drop, z))
		rows.append(row)
		refs.append(Vector3(0, 0.7, z))
	_shell(st, rows, refs, 0.02, col)


## A sheet of steel through rows of points (rows run along the part, each an
## open line across it), `thick` deep, skinned on both sides and round its
## edges. `refs` holds a point inside the part for each row: the outer skin
## faces away from it.
static func _shell(st: SurfaceTool, rows: Array[PackedVector3Array], refs: Array[Vector3], thick: float, col: Color) -> void:
	var n := rows.size()
	var m := rows[0].size()
	var outer: Array[PackedVector3Array] = []
	var inner: Array[PackedVector3Array] = []
	for i in range(n):
		var nr := PackedVector3Array()
		var ir := PackedVector3Array()
		for k in range(m):
			var e := rows[i][mini(k + 1, m - 1)] - rows[i][maxi(k - 1, 0)]
			var u := rows[mini(i + 1, n - 1)][k] - rows[maxi(i - 1, 0)][k]
			var nn := e.cross(u)
			var away := rows[i][k] - refs[i]
			if nn.length_squared() < 1e-12:
				nn = away
			nn = nn.normalized()
			if nn.dot(away) < 0.0:
				nn = -nn
			nr.append(nn)
			ir.append(rows[i][k] - nn * thick)
		outer.append(nr)
		inner.append(ir)
	var I := Transform3D.IDENTITY
	for i in range(n - 1):
		for k in range(m - 1):
			var o := outer
			MeshKit._quad(st, I, [rows[i][k], rows[i + 1][k], rows[i + 1][k + 1], rows[i][k + 1]],
				[o[i][k], o[i + 1][k], o[i + 1][k + 1], o[i][k + 1]], col)
			MeshKit._quad(st, I, [inner[i][k], inner[i + 1][k], inner[i + 1][k + 1], inner[i][k + 1]],
				[-o[i][k], -o[i + 1][k], -o[i + 1][k + 1], -o[i][k + 1]], col)
		# the two long edges
		for e: Array in [[0, 1], [m - 1, m - 2]]:
			var k: int = e[0]
			var nn := (rows[i][k] - rows[i][e[1]]).normalized()
			MeshKit._quad(st, I, [rows[i][k], rows[i + 1][k], inner[i + 1][k], inner[i][k]], [nn, nn, nn, nn], col)
	# the two ends
	for e: Array in [[0, 1], [n - 1, n - 2]]:
		var i: int = e[0]
		for k in range(m - 1):
			var nn := (rows[i][k] - rows[e[1]][k]).normalized()
			MeshKit._quad(st, I, [rows[i][k], rows[i][k + 1], inner[i][k + 1], inner[i][k]], [nn, nn, nn, nn], col)


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
