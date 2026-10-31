class_name CabinKit
extends Node3D
## What every rig has inside and under the hood, built to each body's own
## measurements (LAYOUT, rig space: forward -Z, left -X, hubs at y~0.13):
##   - the engine bay: the rig's own engine on the oil pan (Armor.underbody's),
##     V8, V6, straight-six, four, or the diesels; radiator, fan and shroud,
##     battery, hoses; exhaust manifold down to a pipe beside the gearbox, back
##     under the floor to a muffler and out the tail
##   - the footwell: a transmission tunnel, pedals (clutch, brake, throttle)
##     hung where the driver's feet land on them (Driver reaches its legs to
##     `pedal_targets`), rubber mats
##   - the dash: a gauge cluster in front of the wheel, tach and speedo with
##     live needles plus oil, temperature, fuel and volts, switches, a centre
##     stack; the open Willys gets its flat painted dash panel
##   - the levers: gear lever, transfer-case lever with boots on the tunnel,
##     a handbrake between the seats
##   - a closed cab: door cards with armrests and pulls, a headliner, the
##     rear-view mirror and sun visors
## Everything bar the gauges takes the body's mud shader (so the cab box
## keeps a closed cab clean and an open tub flecked, and the engine bay gets
## what the front tires throw).

## floor: footwell floor top; wall: firewall's cabin face (z); dash: its top y,
## its rear face z, half width, and whether the body has no dash and needs a
## panel; cab: inner half width; bay: radiator's front face z (behind the
## grille), the bay's half width and the hood's underside; engine kind;
## tail: the rear end (z); closed cab: door inner face x, belt, roof underside,
## windscreen top z, doors (2 or 4)
const LAYOUT := {
	"gera": {"floor": 0.58, "wall": -0.305, "dash": [1.17, -0.32, 0.66, true], "cab": 0.66,
		"bay": [-1.57, 0.46, 1.16], "engine": "v8", "tail": 1.58},
	"gerilya": {"floor": 0.58, "wall": -0.305, "dash": [1.17, -0.32, 0.66, true], "cab": 0.66,
		"bay": [-1.57, 0.46, 1.16], "engine": "v8", "tail": 1.58},
	"kuwarenta": {"floor": 0.53, "wall": -0.44, "dash": [1.14, -0.24, 0.65, false], "cab": 0.765,
		"bay": [-1.72, 0.5, 1.03], "engine": "i6", "tail": 1.74},
	"feroz": {"floor": 0.53, "wall": -0.48, "dash": [1.08, -0.22, 0.69, false], "cab": 0.705,
		"bay": [-1.69, 0.48, 0.98], "engine": "i4", "tail": 1.62,
		"closed": [0.705, 1.04, 1.675, -0.19, 2]},
	"ronda": {"floor": 0.58, "wall": -0.76, "dash": [1.23, -0.46, 0.85, false], "cab": 0.885,
		"bay": [-2.33, 0.6, 1.13], "engine": "i6d", "tail": 2.24,
		"closed": [0.885, 1.18, 1.955, -0.5, 4]},
	"owner": {"floor": 0.53, "wall": -0.48, "dash": [1.005, -0.32, 0.65, false], "cab": 0.725,
		"bay": [-1.83, 0.47, 1.0], "engine": "i4d", "tail": 1.72},
	"rubikon": {"floor": 0.58, "wall": -0.74, "dash": [1.26, -0.42, 0.83, false], "cab": 0.845,
		"bay": [-2.27, 0.6, 1.17], "engine": "v6", "tail": 2.2,
		"closed": [0.845, 1.2, 1.93, -0.4, 4]},
}

## Engine paint: the classic small-block's orange, Toyota grey-blue, diesel grey...
const BLOCK := {"v8": Color(0.62, 0.2, 0.06), "i6": Color(0.32, 0.38, 0.44), "i4": Color(0.2, 0.2, 0.22),
	"i6d": Color(0.38, 0.4, 0.4), "i4d": Color(0.18, 0.24, 0.3), "v6": Color(0.14, 0.14, 0.15)}

var rig: Rig
var _tach: Node3D
var _speedo: Node3D
var _temp: Node3D
var _fuel: Node3D
var _redline := 4800.0


static func layout(spec: RigSpec) -> Dictionary:
	return LAYOUT.get(spec.id, LAYOUT["gera"])


## Where the driver's feet go (rig space): the right on the throttle pad, the
## left on the floor left of the clutch. [right foot, its toe-up angle, left foot, angle]
static func pedal_targets(spec: RigSpec) -> Array:
	var l := layout(spec)
	var floor_y: float = l["floor"]
	var wall: float = l["wall"]
	var x := spec.seat.x
	# (ankle heights put the heel on the mat, toes tipped up onto the pad)
	var gas := Vector3(x + 0.16, floor_y + 0.12, wall + 0.29)
	var rest := Vector3(x - 0.2, floor_y + 0.11, wall + 0.34)
	return [gas, 0.42, rest, 0.18]


func build(r: Rig) -> void:
	rig = r
	name = "Cabin"
	_redline = r.spec.redline
	var l := layout(r.spec)
	var c := Color.WHITE
	var block := MeshKit.begin()     # engine paint
	var iron := MeshKit.begin()      # heads, manifolds, brackets: dark cast metal
	var alu := MeshKit.begin()       # valve covers, air cleaner, pulleys
	var black := MeshKit.begin()     # rubber: hoses, belts, mats, pedal pads, boots
	var rust := MeshKit.begin()      # the exhaust
	var rad := MeshKit.begin()       # radiator core
	var trim := MeshKit.begin()      # dash, door cards, headliner, levers: soft black
	var bright := MeshKit.begin()    # chrome: bezels, pedal arms, mirror
	var paint := MeshKit.begin()     # the Willys' flat dash, in the body colour
	_engine_bay(l, block, iron, alu, black, rust, rad, c)
	_footwell(l, black, trim, bright, c)
	_dash(l, trim, bright, paint, c)
	if l.has("closed"):
		_closed_cab(l, trim, bright, c)
	r._add_mesh(MeshKit.commit(block, r._body_mat(BLOCK.get(l["engine"], BLOCK["v8"]), 0.55, 0.1, 0.3)))
	r._add_mesh(MeshKit.commit(iron, r._body_mat(Color(0.12, 0.12, 0.12), 0.7, 0.4, 0.0)))
	r._add_mesh(MeshKit.commit(alu, r._body_mat(Color(0.62, 0.62, 0.6), 0.35, 0.8, 0.0)))
	r._add_mesh(MeshKit.commit(black, r._body_mat(Color(0.03, 0.03, 0.03), 0.85, 0.0, 0.0)))
	r._add_mesh(MeshKit.commit(rust, r._body_mat(Color(0.26, 0.15, 0.09), 0.85, 0.3, 0.0)))
	r._add_mesh(MeshKit.commit(rad, r._body_mat(Color(0.08, 0.08, 0.07), 0.6, 0.5, 0.0)))
	r._add_mesh(MeshKit.commit(trim, r._body_mat(Color(0.055, 0.052, 0.05), 0.75, 0.0, 0.0)))
	r._add_mesh(MeshKit.commit(bright, r._body_mat(Color(0.7, 0.7, 0.72), 0.15, 1.0, 0.0)))
	if l["dash"][3]:
		r._add_mesh(MeshKit.commit(paint, r.paint_mat(0.2, 0.8)))


# --- under the hood ---------------------------------------------------------------

func _engine_bay(l: Dictionary, block: SurfaceTool, iron: SurfaceTool, alu: SurfaceTool, black: SurfaceTool,
		rust: SurfaceTool, rad: SurfaceTool, c: Color) -> void:
	var s := rig.spec
	var kind: String = l["engine"]
	var rad_z: float = l["bay"][0]
	var half: float = l["bay"][1]
	var ceil: float = l["bay"][2] - 0.02
	var wall: float = l["wall"]
	var base := Armor.UNDER_BOTTOM + 0.16    # the pan's top
	# the engine sits back against the firewall, its bellhousing through it
	var lengths := {"v8": 0.62, "i6": 0.82, "i4": 0.5, "i6d": 0.86, "i4d": 0.6, "v6": 0.52}
	var rear := wall - 0.08
	var front := maxf(rear - float(lengths.get(kind, 0.6)), rad_z + 0.3)
	var len := rear - front
	var mid := (front + rear) * 0.5
	var v := kind.begins_with("v")
	var diesel := kind.ends_with("d")
	var bw := 0.42 if v else 0.3                              # block width
	var bh := clampf(ceil - base - 0.3, 0.22, 0.34)           # block height, leaving room on top
	var top := base + bh
	var at := func(p: Vector3) -> Transform3D: return Transform3D(Basis.IDENTITY, p)
	# block, timing cover, bellhousing back to the firewall
	MeshKit.rounded_box(block, Vector3(bw, bh, len), 0.04, at.call(Vector3(0, base + bh * 0.5, mid)), c)
	MeshKit.rounded_box(block, Vector3(bw * 0.8, bh * 0.8, 0.06), 0.03, at.call(Vector3(0, base + bh * 0.45, front - 0.03)), c)
	MeshKit.lathe(iron, [Vector2(0.0, 0.0), Vector2(0.19, 0.0), Vector2(0.15, 0.18), Vector2(0.0, 0.18)],
		Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, base + 0.12, rear - 0.02)), c, 16)
	# heads and valve covers: two banks leaning out on a V, one on an inline
	var bank_top := top
	if v:
		for sx: float in [-1.0, 1.0]:
			var lean := Basis(Vector3.BACK, sx * 0.55)
			var hp := Vector3(sx * bw * 0.33, top + 0.05, mid)
			MeshKit.rounded_box(iron, Vector3(0.17, 0.1, len * 0.94), 0.02, Transform3D(lean, hp), c)
			MeshKit.rounded_box(alu, Vector3(0.15, 0.07, len * 0.9), 0.03, Transform3D(lean, hp + Vector3(sx * 0.05, 0.08, 0)), c)
			# exhaust manifold down the outside of each bank
			MeshKit.rounded_box(iron, Vector3(0.06, 0.08, len * 0.8), 0.02, at.call(Vector3(sx * (bw * 0.5 + 0.04), top - 0.06, mid)), c)
		bank_top = top + 0.17
		# intake manifold in the valley and, on the V8, a carburettor under a round air cleaner
		MeshKit.rounded_box(iron, Vector3(0.18, 0.08, len * 0.7), 0.02, at.call(Vector3(0, top + 0.09, mid)), c)
		if kind == "v8":
			var ac := minf(bank_top + 0.12, ceil - 0.03)
			# the carburettor on the intake, the cleaner sat on it
			MeshKit.rounded_box(iron, Vector3(0.12, ac - top - 0.16, 0.12), 0.015, at.call(Vector3(0, (top + 0.13 + ac - 0.035) * 0.5, mid)), c)
			MeshKit.cylinder(alu, 0.17, 0.07, at.call(Vector3(0, ac, mid)), c, 24)
			MeshKit.cylinder(alu, 0.03, 0.03, at.call(Vector3(0, ac + 0.05, mid)), c, 8)   # the wing nut
		else:
			# the V6's plastic engine cover and an air box at the side
			MeshKit.rounded_box(black, Vector3(0.36, 0.05, len * 0.8), 0.03, at.call(Vector3(0, minf(top + 0.2, ceil - 0.04), mid)), c)
			MeshKit.rounded_box(black, Vector3(0.16, 0.14, 0.24), 0.03, at.call(Vector3(-half + 0.14, ceil - 0.12, front + 0.1)), c)
	else:
		MeshKit.rounded_box(iron, Vector3(bw * 0.9, 0.1, len * 0.96), 0.02, at.call(Vector3(0, top + 0.05, mid)), c)
		var vc := Vector3(0, top + 0.13, mid)
		MeshKit.rounded_box(alu if not diesel else block, Vector3(bw * 0.75, 0.08, len * 0.9), 0.035, at.call(vc), c)
		MeshKit.cylinder(black, 0.025, 0.03, at.call(vc + Vector3(0, 0.05, -len * 0.25)), c, 10)   # oil filler cap
		bank_top = top + 0.17
		# manifolds down the sides: intake on the left, exhaust on the right
		MeshKit.rounded_box(iron, Vector3(0.07, 0.1, len * 0.85), 0.02, at.call(Vector3(-bw * 0.5 - 0.05, top - 0.02, mid)), c)
		MeshKit.rounded_box(iron, Vector3(0.06, 0.08, len * 0.85), 0.02, at.call(Vector3(bw * 0.5 + 0.04, top - 0.06, mid)), c)
		# the air cleaner: an oil-bath can on the old six, a box with a duct on the rest
		if kind == "i6":
			MeshKit.cylinder(alu, 0.12, 0.16, at.call(Vector3(-bw * 0.5 - 0.14, minf(top + 0.1, ceil - 0.1), mid - 0.05)), c, 18)
		else:
			MeshKit.rounded_box(black, Vector3(0.18, 0.14, 0.26), 0.03, at.call(Vector3(-half + 0.13, minf(top + 0.05, ceil - 0.09), front + 0.12)), c)
			MeshKit.tube(black, Vector3(-half + 0.13, minf(top + 0.05, ceil - 0.09), front + 0.25), Vector3(-bw * 0.5 - 0.05, top, mid), 0.04, Transform3D.IDENTITY, c, 10)
		if diesel:
			# injection pump on the left, injector lines over to the head
			MeshKit.rounded_box(alu, Vector3(0.1, 0.12, 0.22), 0.02, at.call(Vector3(-bw * 0.5 - 0.06, base + 0.12, front + 0.2)), c)
			var n_cyl := 6 if kind == "i6d" else 4
			for k in n_cyl:
				var z := front + len * (k + 0.5) / n_cyl
				MeshKit.tube(alu, Vector3(-bw * 0.5 - 0.06, base + 0.18, front + 0.2), Vector3(-0.04, top + 0.1, z), 0.005, Transform3D.IDENTITY, c, 4)
	# front of the engine: crank and water-pump pulleys, the belt, the fan
	var fz := front - 0.08
	MeshKit.cylinder(alu, 0.085, 0.03, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, base + 0.06, fz + 0.03)), c, 18)
	MeshKit.cylinder(alu, 0.065, 0.03, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, top - 0.04, fz + 0.03)), c, 18)
	MeshKit.cylinder(alu, 0.05, 0.03, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(bw * 0.5 + 0.06, top - 0.02, fz + 0.04)), c, 14)   # alternator pulley
	MeshKit.cylinder(iron, 0.07, 0.14, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(bw * 0.5 + 0.12, top - 0.02, fz + 0.12)), c, 16)   # the alternator
	MeshKit.tube(black, Vector3(0, base + 0.06, fz + 0.03), Vector3(0, top - 0.04, fz + 0.03), 0.012, Transform3D.IDENTITY, c, 6)
	MeshKit.tube(black, Vector3(0, top - 0.04, fz + 0.03), Vector3(bw * 0.5 + 0.06, top - 0.02, fz + 0.04), 0.012, Transform3D.IDENTITY, c, 6)
	var fan_y := top - 0.04
	var fan_z := fz - 0.04
	for k in 5:
		var a := TAU * k / 5.0
		MeshKit.rounded_box(iron, Vector3(0.05, 0.16, 0.01), 0.005,
			Transform3D(Basis(Vector3.BACK, a) * Basis(Vector3.UP, 0.4), Vector3(0, fan_y, fan_z) + Vector3(cos(a + PI * 0.5), sin(a + PI * 0.5), 0) * 0.09), c)
	# radiator: the core behind the grille, top and bottom tanks, a shroud round the fan
	var rad_h := clampf(ceil - base - 0.08, 0.3, 0.55)
	var rad_w := minf(half * 1.7, 0.72)
	var rad_y := base + 0.06 + rad_h * 0.5
	MeshKit.rounded_box(rad, Vector3(rad_w, rad_h, 0.06), 0.01, at.call(Vector3(0, rad_y, rad_z + 0.04)), c)
	MeshKit.rounded_box(iron, Vector3(rad_w + 0.04, 0.05, 0.08), 0.01, at.call(Vector3(0, rad_y + rad_h * 0.5, rad_z + 0.04)), c)
	MeshKit.rounded_box(iron, Vector3(rad_w + 0.04, 0.05, 0.08), 0.01, at.call(Vector3(0, rad_y - rad_h * 0.5, rad_z + 0.04)), c)
	MeshKit.cylinder(alu, 0.03, 0.03, at.call(Vector3(rad_w * 0.3, rad_y + rad_h * 0.5 + 0.035, rad_z + 0.04)), c, 10)   # cap
	var shroud_z := (rad_z + 0.08 + fan_z) * 0.5
	MeshKit.lathe(black, [Vector2(0.2, -0.04), Vector2(0.21, 0.04), Vector2(0.18, 0.04), Vector2(0.17, -0.04)],
		Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, fan_y, shroud_z)), c, 20)
	# top hose to the thermostat, bottom hose to the water pump
	MeshKit.sweep(black, PackedVector3Array([Vector3(-rad_w * 0.3, rad_y + rad_h * 0.45, rad_z + 0.08), Vector3(-0.08, top + 0.04, fz - 0.05), Vector3(0, top + 0.02, front + 0.04)]),
		PackedFloat32Array([0.025, 0.025, 0.025]), Transform3D.IDENTITY, c, 8)
	MeshKit.sweep(black, PackedVector3Array([Vector3(rad_w * 0.35, rad_y - rad_h * 0.4, rad_z + 0.08), Vector3(0.12, base + 0.1, fz), Vector3(0.04, base + 0.14, front + 0.02)]),
		PackedFloat32Array([0.025, 0.025, 0.025]), Transform3D.IDENTITY, c, 8)
	# battery on the right apron, its terminals and leads
	var bat := Vector3(half - 0.13, minf(base + 0.32, ceil - 0.14), rear - 0.22)
	MeshKit.rounded_box(black, Vector3(0.18, 0.18, 0.26), 0.012, at.call(bat), c)
	MeshKit.rounded_box(iron, Vector3(0.2, 0.02, 0.28), 0.005, at.call(bat - Vector3(0, 0.1, 0)), c)
	MeshKit.cylinder(alu, 0.012, 0.025, at.call(bat + Vector3(-0.05, 0.1, -0.08)), c, 8)
	MeshKit.cylinder(alu, 0.012, 0.025, at.call(bat + Vector3(-0.05, 0.1, 0.08)), c, 8)
	MeshKit.sweep(black, PackedVector3Array([bat + Vector3(-0.05, 0.11, -0.08), bat + Vector3(-0.2, 0.05, -0.1), Vector3(bw * 0.5, base + 0.1, mid)]),
		PackedFloat32Array([0.009, 0.009, 0.009]), Transform3D.IDENTITY, c, 6)
	# brake master cylinder and booster on the firewall, driver's side
	var mc := Vector3(s.seat.x, minf(top + 0.05, ceil - 0.12), wall - 0.1)
	MeshKit.cylinder(iron, 0.11, 0.08, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), mc), c, 20)
	MeshKit.rounded_box(alu, Vector3(0.07, 0.07, 0.16), 0.015, at.call(mc + Vector3(0, 0.02, -0.12)), c)
	MeshKit.cylinder(black, 0.025, 0.04, at.call(mc + Vector3(0, 0.07, -0.12)), c, 10)
	# exhaust: down from the right-hand manifold, back beside the gearbox under
	# the floor, a muffler under the back, out the tail
	var ex_x := 0.24
	var ex_y := Armor.UNDER_BOTTOM + 0.1
	var tail: float = l["tail"]
	var muffler := clampf(s.rear_z - s.tire_radius - 0.45, mid + 0.6, tail - 0.5)
	var ex_pts := PackedVector3Array([Vector3(bw * 0.5 + 0.05, top - 0.08, mid + len * 0.25), Vector3(bw * 0.5 + 0.06, base, mid + len * 0.35),
		Vector3(ex_x, ex_y, rear + 0.1), Vector3(ex_x, ex_y, muffler - 0.32)])
	MeshKit.sweep(rust, ex_pts, PackedFloat32Array([0.03, 0.03, 0.03, 0.03]), Transform3D.IDENTITY, c, 10)
	MeshKit.cylinder(rust, 0.1, 0.5, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(ex_x, ex_y + 0.02, muffler)), c, 18)
	MeshKit.sweep(rust, PackedVector3Array([Vector3(ex_x, ex_y, muffler + 0.25), Vector3(ex_x + 0.12, ex_y + 0.04, tail - 0.4), Vector3(ex_x + 0.18, ex_y + 0.08, tail + 0.04)]),
		PackedFloat32Array([0.028, 0.028, 0.028]), Transform3D.IDENTITY, c, 10)
	# engine mounts onto the frame rails
	for sx: float in [-1.0, 1.0]:
		MeshKit.rounded_box(iron, Vector3(absf(0.42 - bw * 0.5), 0.06, 0.08), 0.01, at.call(Vector3(sx * (bw * 0.5 + 0.42) * 0.5, base + 0.08, front + len * 0.3)), c)


# --- the footwell, pedals and levers ---------------------------------------------------

func _footwell(l: Dictionary, black: SurfaceTool, trim: SurfaceTool, bright: SurfaceTool, c: Color) -> void:
	var s := rig.spec
	var floor_y: float = l["floor"]
	var wall: float = l["wall"]
	var cab: float = l["cab"]
	var dash_top: float = l["dash"][0]
	var at := func(p: Vector3) -> Transform3D: return Transform3D(Basis.IDENTITY, p)
	# the transmission tunnel, firewall back to under the seats
	var tun_len := clampf(s.seat.z - wall + 0.1, 0.5, 0.95)
	MeshKit.rounded_box(trim, Vector3(0.26, 0.16, tun_len), 0.07, at.call(Vector3(0.03, floor_y + 0.05, wall + tun_len * 0.5)), c)
	# rubber mats in each footwell
	for sx: float in [-1.0, 1.0]:
		var mx := sx * (0.16 + (cab - 0.16) * 0.45)
		MeshKit.rounded_box(black, Vector3(cab - 0.24, 0.012, 0.5), 0.004, at.call(Vector3(mx, floor_y + 0.006, wall + 0.3)), c)
	# pedals: clutch and brake hung from under the dash, the throttle beside
	# them; pads where the feet go (Driver puts them there)
	var tg := pedal_targets(s)
	var gas: Vector3 = tg[0]
	# (pivots up under the dash, out of sight; short dark arms down to the pads)
	var pivot_y := minf(dash_top - 0.2, floor_y + 0.4)
	for p: Array in [[s.seat.x - 0.13, 0.07, 0.06], [s.seat.x + 0.03, 0.08, 0.07]]:
		var x: float = p[0]
		var pad := Vector3(x, floor_y + 0.16, wall + 0.2)
		var top := Vector3(x, pivot_y, wall + 0.06)
		MeshKit.sweep(black, PackedVector3Array([top, top.lerp(pad, 0.5) + Vector3(0, 0, 0.04), pad + Vector3(0, 0.03, -0.01)]),
			PackedFloat32Array([0.011, 0.011, 0.011]), Transform3D.IDENTITY, c, 6)
		MeshKit.rounded_box(black, Vector3(p[1], p[2], 0.025), 0.01, Transform3D(Basis(Vector3.RIGHT, -0.35), pad), c)
	# throttle: a tall pad on its arm, toe of the foot on it
	var gas_pad := gas + Vector3(0, 0.07, -0.09)
	MeshKit.tube(black, Vector3(gas.x, pivot_y, wall + 0.06), gas_pad + Vector3(0, 0.05, 0.0), 0.009, Transform3D.IDENTITY, c, 6)
	MeshKit.rounded_box(black, Vector3(0.06, 0.13, 0.02), 0.008, Transform3D(Basis(Vector3.RIGHT, -0.55), gas_pad), c)
	# the dead pedal, a ribbed rest the left foot finds
	var rest: Vector3 = tg[2]
	MeshKit.rounded_box(black, Vector3(0.09, 0.12, 0.02), 0.008, Transform3D(Basis(Vector3.RIGHT, -0.9), rest + Vector3(0, 0.03, -0.14)), c)
	# gear lever and the transfer-case lever out of the tunnel, booted; a
	# handbrake lever between the seats
	var tun_top := floor_y + 0.13
	var gear_base := Vector3(0.03, tun_top, wall + 0.32)
	var gear_top := gear_base + Vector3(-0.04, 0.42, 0.12)
	MeshKit.tube(bright, gear_base, gear_top, 0.011, Transform3D.IDENTITY, c, 8)
	MeshKit.sphere(trim, 0.035, at.call(gear_top), c, 12)
	MeshKit.lathe(black, [Vector2(0.06, 0.0), Vector2(0.045, 0.05), Vector2(0.02, 0.1), Vector2(0.014, 0.12)], at.call(gear_base), c, 12)
	var tc_base := Vector3(0.12, tun_top, wall + 0.38)
	var tc_top := tc_base + Vector3(0.02, 0.32, 0.1)
	MeshKit.tube(bright, tc_base, tc_top, 0.009, Transform3D.IDENTITY, c, 8)
	MeshKit.rounded_box(trim, Vector3(0.035, 0.06, 0.035), 0.012, at.call(tc_top), c)
	MeshKit.lathe(black, [Vector2(0.045, 0.0), Vector2(0.03, 0.05), Vector2(0.012, 0.09)], at.call(tc_base), c, 10)
	var hb := Vector3(0.0, floor_y + 0.14, s.seat.z - 0.02)
	MeshKit.rounded_box(trim, Vector3(0.1, 0.07, 0.22), 0.02, at.call(hb), c)
	MeshKit.rounded_box(trim, Vector3(0.035, 0.035, 0.26), 0.012, Transform3D(Basis(Vector3.RIGHT, 0.25), hb + Vector3(0, 0.07, -0.08)), c)


# --- the dash ---------------------------------------------------------------------------

func _dash(l: Dictionary, trim: SurfaceTool, bright: SurfaceTool, paint: SurfaceTool, c: Color) -> void:
	var s := rig.spec
	var d: Array = l["dash"]
	var top: float = d[0]
	var face: float = d[1]
	var half: float = d[2]
	var at := func(p: Vector3) -> Transform3D: return Transform3D(Basis.IDENTITY, p)
	if d[3]:
		# the Willys: a flat steel panel across under the cowl lip, in the body colour
		MeshKit.rounded_box(paint, Vector3(half * 2.0, 0.24, 0.03), 0.01, at.call(Vector3(0, top - 0.13, face)), c)
		face += 0.015
	else:
		# a padded lower dash under the body's own dash top, the full width
		MeshKit.rounded_box(trim, Vector3(half * 2.0, 0.2, 0.08), 0.03, at.call(Vector3(0, top - 0.18, face - 0.03)), c)
		face += 0.01
	# the instrument binnacle in front of the wheel, a hood over it
	# (seen through the top half of the wheel: on a low dash it stands up in
	# a pod on top; the Willys keeps its gauges down in the flat panel)
	var gx := s.seat.x
	var gy := top - 0.08 if d[3] else s.wheel_at.y + 0.04
	# and a good hand's span ahead of the wheel rim, set back into its pod
	var pod := minf(face, s.wheel_at.z - 0.2)
	if gy + 0.08 > top:
		var pod_lo := top - 0.06
		MeshKit.rounded_box(trim, Vector3(0.38, gy + 0.08 - pod_lo, 0.1), 0.03, at.call(Vector3(gx, (gy + 0.08 + pod_lo) * 0.5, pod - 0.04)), c)
	MeshKit.rounded_box(trim, Vector3(0.36, 0.15, 0.06), 0.03, at.call(Vector3(gx, gy, pod + 0.02)), c)
	MeshKit.rounded_box(trim, Vector3(0.38, 0.03, 0.07), 0.015, Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3(gx, gy + 0.085, pod + 0.04)), c)
	var dials := Node3D.new()
	dials.name = "Gauges"
	add_child(dials)
	var gz := pod + 0.052
	_speedo = _gauge(dials, Vector3(gx - 0.085, gy, gz), 0.058, 9)
	_tach = _gauge(dials, Vector3(gx + 0.085, gy, gz), 0.058, 9)
	_temp = _gauge(dials, Vector3(gx - 0.02, gy - 0.045, gz + 0.002), 0.022, 3)
	_fuel = _gauge(dials, Vector3(gx + 0.02, gy - 0.045, gz + 0.002), 0.022, 3)
	_gauge(dials, Vector3(gx - 0.02, gy + 0.045, gz + 0.002), 0.022, 3)   # oil pressure (steady)
	_gauge(dials, Vector3(gx + 0.02, gy + 0.045, gz + 0.002), 0.022, 3)   # volts
	# a row of toggle switches and the ignition, the centre stack with the radio
	for k in 4:
		var sw := Vector3(gx + 0.24 + k * 0.045, gy - 0.07, face + 0.01)
		MeshKit.cylinder(bright, 0.008, 0.012, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), sw), c, 8)
		MeshKit.tube(bright, sw, sw + Vector3(0, 0.012, 0.03), 0.003, Transform3D.IDENTITY, c, 4)
	MeshKit.cylinder(bright, 0.016, 0.01, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(gx + 0.2, gy - 0.12, face + 0.01)), c, 12)
	var stack := Vector3(0.03, top - 0.2, face + 0.03)
	MeshKit.rounded_box(trim, Vector3(0.22, 0.16, 0.06), 0.015, at.call(stack), c)
	MeshKit.rounded_box(bright, Vector3(0.18, 0.05, 0.01), 0.004, at.call(stack + Vector3(0, 0.03, 0.03)), c)
	for k in 2:
		MeshKit.cylinder(bright, 0.012, 0.015, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), stack + Vector3(-0.07 + k * 0.14, -0.035, 0.035)), c, 10)
	# vents each end, and a grab handle in front of the passenger
	for sx: float in [-1.0, 1.0]:
		MeshKit.rounded_box(bright, Vector3(0.08, 0.05, 0.01), 0.01, at.call(Vector3(sx * (half - 0.08), top - 0.07, face + 0.005)), c)
	MeshKit.tube(trim, Vector3(-gx - 0.12, top - 0.12, face + 0.01), Vector3(-gx + 0.12, top - 0.12, face + 0.01), 0.012, Transform3D.IDENTITY, c, 6)


## One round gauge facing the driver: a chrome bezel, a black face with
## `ticks` white marks round 270 degrees, and a needle on its own pivot
## (returned, to turn).
func _gauge(parent: Node3D, at: Vector3, r: float, ticks: int) -> Node3D:
	var face_x := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), at)
	var st := MeshKit.begin()
	MeshKit.cylinder(st, r, 0.01, face_x, Color(0.02, 0.02, 0.022), 24)
	var ticks_st := MeshKit.begin()
	for k in ticks:
		var a := deg_to_rad(225.0 - 270.0 * k / (ticks - 1))
		var p := at + Vector3(cos(a), sin(a), 0) * r * 0.8 + Vector3(0, 0, 0.006)
		MeshKit.rounded_box(ticks_st, Vector3(r * 0.08, r * 0.24, 0.002), 0.0005, Transform3D(Basis(Vector3.BACK, a - PI * 0.5), p), Color.WHITE, 1)
	var bez := MeshKit.begin()
	MeshKit.torus(bez, r, r * 0.12, face_x, Color(0.75, 0.75, 0.78), 24, 6)
	var face := MeshInstance3D.new()
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.02, 0.02, 0.022)
	fm.roughness = 0.25
	face.mesh = MeshKit.commit(st, fm)
	parent.add_child(face)
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.9, 0.9, 0.86)
	tm.emission_enabled = true
	tm.emission = Color(0.9, 0.9, 0.8)
	tm.emission_energy_multiplier = 0.15
	var tk := MeshInstance3D.new()
	tk.mesh = MeshKit.commit(ticks_st, tm)
	parent.add_child(tk)
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.75, 0.75, 0.78)
	bm.metallic = 1.0
	bm.roughness = 0.2
	var bz := MeshInstance3D.new()
	bz.mesh = MeshKit.commit(bez, bm)
	parent.add_child(bz)
	# the needle: from the hub out along local +Y, turned about the face's axis
	var pivot := Node3D.new()
	pivot.position = at + Vector3(0, 0, 0.009)
	parent.add_child(pivot)
	var ns := MeshKit.begin()
	MeshKit.rounded_box(ns, Vector3(r * 0.07, r * 0.85, 0.002), 0.0008, Transform3D(Basis.IDENTITY, Vector3(0, r * 0.35, 0)), Color.WHITE, 1)
	MeshKit.cylinder(ns, r * 0.12, 0.004, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), Color(0.2, 0.2, 0.2), 10)
	var nm := StandardMaterial3D.new()
	nm.albedo_color = Color(1.0, 0.35, 0.08)
	nm.emission_enabled = true
	nm.emission = Color(1.0, 0.35, 0.08)
	nm.emission_energy_multiplier = 0.3
	var needle := MeshInstance3D.new()
	needle.mesh = MeshKit.commit(ns, nm)
	pivot.add_child(needle)
	_set_needle(pivot, 0.0)
	return pivot


## Needle at `f` (0..1) of the dial's 270 degrees, from bottom left round to bottom right.
static func _set_needle(pivot: Node3D, f: float) -> void:
	pivot.rotation = Vector3(0, 0, deg_to_rad(135.0 - 270.0 * clampf(f, 0.0, 1.0)))


func _process(delta: float) -> void:
	if rig == null or _tach == null:
		return
	var gb := rig.gearbox
	_set_needle(_tach, gb.rpm / maxf(_redline * 1.15, 1.0))
	_set_needle(_speedo, rig.speed_kmh / 120.0)
	# temperature warms up to the middle and creeps up crawling in 4L
	var warm := 0.5 + (0.08 if rig.low_range else 0.0)
	_temp.rotation.z = lerp_angle(_temp.rotation.z, deg_to_rad(135.0 - 270.0 * warm), 1.0 - exp(-delta * 0.3))
	_set_needle(_fuel, 0.72)


# --- a closed cab ----------------------------------------------------------------------

func _closed_cab(l: Dictionary, trim: SurfaceTool, bright: SurfaceTool, c: Color) -> void:
	var s := rig.spec
	var cl: Array = l["closed"]
	var door_x: float = cl[0]
	var belt: float = cl[1]
	var roof: float = cl[2]
	var ws_top: float = cl[3]
	var floor_y: float = l["floor"]
	var wall: float = l["wall"]
	var at := func(p: Vector3) -> Transform3D: return Transform3D(Basis.IDENTITY, p)
	# door cards: a panel inside each front door, an armrest and a pull, the
	# window winder; the same on the back doors behind the seats
	for sx: float in [-1.0, 1.0]:
		var doors: Array = [[wall + 0.08, s.seat.z + 0.2]]
		if int(cl[4]) == 4:
			doors.append([s.seat.z + 0.35, s.seat.z + 1.15])
		for door: Array in doors:
			var z0: float = door[0]
			# (clear of the rear wheel as it sweeps up to the bump stop)
			var z1: float = minf(door[1], s.rear_z - s.tire_radius - 0.32)
			if z1 - z0 < 0.3:
				continue
			var x := sx * (door_x - 0.02)
			var zm := (z0 + z1) * 0.5
			MeshKit.rounded_box(trim, Vector3(0.03, belt - floor_y - 0.08, z1 - z0), 0.012, at.call(Vector3(x, (belt + floor_y) * 0.5 + 0.02, zm)), c)
			MeshKit.rounded_box(trim, Vector3(0.07, 0.05, (z1 - z0) * 0.45), 0.02, at.call(Vector3(x - sx * 0.04, floor_y + 0.33, zm + 0.05)), c)
			MeshKit.rounded_box(bright, Vector3(0.012, 0.025, 0.09), 0.006, at.call(Vector3(x - sx * 0.025, belt - 0.12, z0 + 0.12)), c)
			MeshKit.cylinder(bright, 0.03, 0.01, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(x - sx * 0.02, floor_y + 0.42, z1 - 0.15)), c, 10)
	# the headliner, and sun visors folded up behind the windscreen header
	var cab_back := float(l["tail"]) - 0.1
	MeshKit.rounded_box(trim, Vector3((door_x - 0.03) * 2.0, 0.02, cab_back - ws_top), 0.01, at.call(Vector3(0, roof - 0.015, (ws_top + cab_back) * 0.5)), c)
	for sx: float in [-1.0, 1.0]:
		MeshKit.rounded_box(trim, Vector3(0.4, 0.025, 0.16), 0.01, at.call(Vector3(sx * 0.36, roof - 0.04, ws_top + 0.12)), c)
	# the rear-view mirror on its stalk
	var m := Vector3(0.0, roof - 0.1, ws_top + 0.06)
	MeshKit.tube(trim, Vector3(0, roof - 0.02, ws_top + 0.04), m, 0.008, Transform3D.IDENTITY, c, 6)
	MeshKit.rounded_box(trim, Vector3(0.24, 0.065, 0.025), 0.015, at.call(m + Vector3(0, -0.02, 0)), c)
	MeshKit.rounded_box(bright, Vector3(0.22, 0.05, 0.004), 0.008, at.call(m + Vector3(0, -0.02, 0.014)), c)
