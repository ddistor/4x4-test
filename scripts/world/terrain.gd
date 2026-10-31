class_name Terrain
extends Node3D
## A procedural stage: a long strip of land with the trail running up it
## (+Z), built from a StagePlan of Philippine offroad sections — paddy road,
## laterite climbs, kanal ruts, boulder rivers, lahar washes, rock steps,
## rock gullies, logging-road bogs, cogon hills, coconut farm roads. Each kind shapes the
## land, the soft ground, the water and the plants its own way; neighbouring
## sections blend into each other over StagePlan.BLEND metres.
##
## The physics collider is the firm base (heights minus mud thickness), in
## square tiles. The visual mesh sits on top, in chunks, and is displaced in
## the vertex shader by the rut channel of the MudField texture, so ruts show
## without rebuilding the mesh.

const WIDTH := 160.0
const CELL := 0.5
const RES_X := int(WIDTH / CELL)  # 320
const MESH_CHUNK := 80.0
const NO_WATER := -1000.0

## How much of each kind of land is forest (leaf litter, ferns, trees).
const FOREST := {"paddy": 0.0, "clay": 1.0, "kanal": 0.9, "river": 0.7, "lahar": 0.0, "rocky": 0.6,
	"gully": 1.0, "bog": 1.0, "cogon": 0.05, "niyog": 0.0, "end": 0.3,
	"pasture": 0.0, "ridge": 0.0, "sukal": 0.4, "yard": 0.0}
## Broadleaf trees per metre of trail.
const TREES := {"paddy": 0.0, "clay": 4.0, "kanal": 3.5, "river": 2.5, "lahar": 0.6, "rocky": 2.5,
	"gully": 4.5, "bog": 5.0, "cogon": 0.35, "niyog": 0.2, "end": 1.0,
	"pasture": 1.4, "ridge": 0.12, "sukal": 1.2, "yard": 0.0}
## How lumpy the trail floor is: humps, wallows and potholes (m).
const LUMPS := {"paddy": 0.03, "clay": 0.16, "kanal": 0.1, "river": 0.12, "lahar": 0.12, "rocky": 0.0,
	"gully": 0.12, "bog": 0.2, "cogon": 0.1, "niyog": 0.16, "end": 0.06,
	"pasture": 0.12, "ridge": 0.07, "sukal": 0.12, "yard": 0.0}

@export var seed_value: int = 7
var plan: StagePlan
var length := 0.0
var res_z := 0

var mud: MudField
var grip: PackedFloat32Array           # per mud cell: multiplies tire friction (ash, wet stone)
var heights: PackedFloat32Array        # (RES_X+1) x (res_z+1) firm base heights
var trail_center: PackedFloat32Array   # x of the trail centre every 1 m of z
var trail_slope: PackedFloat32Array    # dx/dz of the centre line
var trail_floor: PackedFloat32Array    # trail floor height every 1 m
var tree_anchors: Array[Vector3] = []
var crossings: Array[Dictionary] = []  # rivers and creeks running across the trail
var pits: Array[Dictionary] = []       # holes hidden in the cogon
var streams: Array[Dictionary] = []    # streams running down a section (the lahar's), crossing the trail
var _pinches: Array[float] = []        # z where a lahar wash closes in to a slot canyon
var water_bodies: Array[Dictionary] = []
var rock_spots: Array[Vector4] = []    # xyz centre, w radius
var palm_spots: Array[Transform3D] = []
var cover_image: Image  # 1 m: R trail distance / 32, G forest, B paddy, A lahar ash
var soil_image: Image   # 1 m: R bedrock, G river cobbles, B water level, A where water can stand
var soil_texture: ImageTexture
var bed_texture: ImageTexture   # 1 m: ground height, so water knows how deep it is anywhere
var water_mats: Array[ShaderMaterial] = []   # the rig stirs these (wakes, mud plumes)

var _noise: FastNoiseLite
var _detail: FastNoiseLite


func _ready() -> void:
	if plan == null:
		plan = StagePlan.generate(seed_value)
	seed_value = plan.seed_value
	length = plan.length
	res_z = int(length / CELL)
	_noise = FastNoiseLite.new()
	_noise.seed = seed_value
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.012
	_noise.fractal_octaves = 4
	_detail = FastNoiseLite.new()
	_detail.seed = seed_value + 1
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail.frequency = 0.09

	mud = MudField.new(RES_X, res_z, CELL, Vector2.ZERO)
	grip.resize(RES_X * res_z)
	grip.fill(1.0)
	_build_trail()
	_plan_features()
	_build_heights()
	_author_mud()
	mud.bake_image()
	_build_maps()
	_build_mesh()
	_build_collision()
	_build_water()
	_place_rocks()
	_build_trees()
	_build_finish()


# --- the trail line ------------------------------------------------------------

func _build_trail() -> void:
	var n := int(length) + 1
	trail_center.resize(n)
	trail_slope.resize(n)
	trail_floor.resize(n)
	var phase := 0.0
	for z in range(n):
		var zf := float(z)
		var bl := plan.blend_at(zf)
		var a: Dictionary = StagePlan.KINDS[plan.sections[bl[0]]["kind"]]
		var b: Dictionary = StagePlan.KINDS[plan.sections[bl[1]]["kind"]]
		var w: float = bl[2]
		# integrate the phase so changing how often it bends never jumps
		phase += lerpf(a["freq"], b["freq"], w)
		var amp := lerpf(a["wander"], b["wander"], w)
		# plus a shorter, sharper wiggle; a narrow slot (the rock gully) keeps
		# only a little of it, or its floor would zig-zag faster than a rig turns
		var jitter := lerpf(a.get("jitter", 1.0), b.get("jitter", 1.0), w)
		trail_center[z] = WIDTH * 0.5 + amp * sin(phase) + 3.0 * jitter * _detail.get_noise_1d(zf * 2.0)
		trail_floor[z] = plan.profile(zf)
	for z in range(n):
		trail_slope[z] = (trail_center[mini(z + 1, n - 1)] - trail_center[maxi(z - 1, 0)]) * 0.5


func _lerp_line(arr: PackedFloat32Array, z: float) -> float:
	var i := clampi(int(z), 0, arr.size() - 2)
	return lerpf(arr[i], arr[i + 1], clampf(z - i, 0.0, 1.0))


func trail_x_at(z: float) -> float:
	return _lerp_line(trail_center, z)


func trail_floor_at(z: float) -> float:
	return _lerp_line(trail_floor, z)


## 1 / sqrt(1 + slope^2): turns sideways (x) distance from the centre line into
## distance across the trail, so the trail is as wide in a bend as on a straight.
func _across(z: float) -> float:
	var s := _lerp_line(trail_slope, z)
	return 1.0 / sqrt(1.0 + s * s)


# --- features: rivers, creeks, pits, standing water --------------------------------

func _plan_features() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 5
	var d := plan.difficulty
	for s in plan.sections:
		var z0: float = s["z0"]
		var z1: float = s["z1"]
		var zc := lerpf(z0, z1, s["cross_t"])
		match s["kind"]:
			"river":
				# wide and clear over river stones, a ford: a shallow gravel riffle
				# near where the trail crosses, deep pools up and downstream that
				# choke the engine, so read the water and pick the line
				_add_crossing(zc, {
					"half_w": rng.randf_range(10.0, 14.0), "bank": 7.0, "drop": 1.6,
					"depth": rng.randf_range(0.5, 0.72) * d, "amp": 5.0,
					"tint": Color(0.16, 0.27, 0.24, 0.85), "clarity": 1.0, "stones": true,
					"flow": 1.4 * (1.0 if rng.randf() < 0.5 else -1.0), "ford": true}, rng)
			"lahar":
				# the stream that cut the wash runs down it, braiding round sand
				# bars and crossing the trail again and again (one draw, as the
				# old single crossing took, so the rest of the stage is unchanged)
				_add_stream(s, rng.randf() * TAU)
			"clay":
				if s["cross_t"] >= 0.0:
					# the brown creek at the bottom of the climb
					_add_crossing(zc, {
						"half_w": 5.0, "bank": 9.0, "drop": 1.4, "depth": 0.75 * d, "amp": 3.0,
						"tint": Color(0.4, 0.26, 0.12, 0.75), "clarity": 0.0, "stones": false, "flow": 0.3}, rng)
			"cogon":
				for k in range(int(rng.randi_range(12, 16) * d)):
					var z := rng.randf_range(z0 + 15.0, z1 - 15.0)
					pits.append({"x": trail_x_at(z) + rng.randf_range(-2.2, 2.2), "z": z,
						"r": rng.randf_range(0.9, 1.5), "depth": rng.randf_range(0.5, 0.85) * d})
			"bog":
				water_bodies.append({"z_lo": z0 + 4.0, "z_hi": z1 - 4.0, "level": float(s["h0"]) - 0.1,
					"tint": Color(0.3, 0.2, 0.1, 0.8), "clarity": 0.0, "flow": 0.0})
			"paddy":
				water_bodies.append({"z_lo": z0 - 1.0, "z_hi": z1 + 2.0, "level": float(s["h0"]) - 0.2,
					"tint": Color(0.22, 0.26, 0.14, 0.55), "clarity": 0.15, "flow": 0.0})
			"yard":
				# the park track's creeks: deep runs, a riffle wherever the loop
				# fords one and wherever a deep crossing's or a bridge's bypass does
				var creeks := Yard.creeks()
				for ci in creeks.size():
					var creek: Dictionary = creeks[ci]
					var c := creek.duplicate()
					c.merge({"tint": Color(0.2, 0.24, 0.17, 0.85), "clarity": 0.6, "stones": not creek.get("braided", false),
						"flow": 0.5, "ford": true})
					_add_crossing(float(c["zc"]), c, rng)
					c["phase"] = creek["phase"]
					c["freq"] = creek["freq"]
					c["pool"] = creek["pool"]
					c["fords"] = Yard.fords(ci)


func _add_crossing(zc: float, c: Dictionary, rng: RandomNumberGenerator) -> void:
	c["zc"] = zc
	c["phase"] = rng.randf() * TAU
	c["freq"] = 0.02
	c["ref_h"] = plan.profile(zc)
	# a ford sits in a level bottom: flatten the trail's climb round it and let
	# the grade happen either side, or the exit bank stacks on top of the hill
	var flat := float(c["amp"]) + float(c["half_w"]) + float(c["bank"]) + 4.0
	for z in range(maxi(0, int(zc - flat - 30.0)), mini(trail_floor.size(), int(zc + flat + 30.0))):
		var k := 1.0 - smoothstep(flat, flat + 30.0, absf(z - zc))
		trail_floor[z] = lerpf(trail_floor[z], c["ref_h"], k)
	c["level"] = float(c["ref_h"]) - float(c["drop"]) + float(c["depth"])
	if c.get("ford", false):
		# the riffle sits a little off the trail line (from the phase, so the
		# rest of the stage keeps its random draws): the shallow line is there
		# to be found, not handed over
		c["ford_x"] = trail_x_at(zc) + 2.5 * sin(float(c["phase"]) * 3.1)
		c["ford_w"] = 4.5
		c["shallow"] = 0.42 * plan.difficulty * (0.85 + 0.3 * absf(cos(float(c["phase"]) * 1.7)))
		c["pool"] = float(c["depth"]) * 1.3
	c["reach"] = float(c["amp"]) + float(c["half_w"]) + float(c["bank"]) + 1.0
	if c.get("braided", false):
		c["reach"] += 3.1 + float(c["half_w"]) * 0.3   # its extra wander and swell (_channel)
	crossings.append(c)
	water_bodies.append({"z_lo": zc - float(c["reach"]), "z_hi": zc + float(c["reach"]), "level": c["level"],
		"tint": c["tint"], "clarity": c["clarity"], "flow": c["flow"], "crossing": c})


## A lahar wash's stream, as the accounts of Pinatubo and Porac trails have
## it: shallow, milky grey, braided round sand bars, its bed cobbles and
## boulders, crossing the route over and over; a couple of deeper pockets
## that catch you out, and where the wash drops steeply it runs dry over a
## cascade of stones. One slot canyon pinch per wash, where the crumbly walls
## close in and the trail runs up the stream bed itself.
func _add_stream(s: Dictionary, ph: float) -> void:
	var d := plan.difficulty
	var z0 := float(s["z0"]) + 6.0
	var z1 := float(s["z1"]) - 6.0
	var st := {
		"z0": z0, "z1": z1, "phase": ph, "freq": TAU / 68.0, "amp": 13.0, "width": 1.9,
		"cut": 0.5 * d, "depth": 0.3 * d, "flow": 0.7,
		"deep": [lerpf(z0 + 15.0, z1 - 15.0, fposmod(ph * 2.9, 1.0)), lerpf(z0 + 15.0, z1 - 15.0, fposmod(ph * 4.3, 1.0))],
	}
	if z1 - z0 > 80.0:
		_pinches.append(lerpf(z0 + 30.0, z1 - 30.0, fposmod(ph * 1.37, 1.0)))
	streams.append(st)
	# its water: a run of short sheets, each tilted to follow the wash down so
	# the surface runs on without steps; none over the steep drop: that's a
	# dry cascade of stones
	var z := z0
	while z < z1:
		var zb := minf(z + 3.0, z1)
		if absf(trail_floor_at(z) - trail_floor_at(zb)) < 0.3:
			var zm := (z + zb) * 0.5
			var cx := trail_x_at(zm)
			var half := _lahar_half(zm)
			var off := -float(st["cut"]) + float(st["depth"])
			water_bodies.append({"z_lo": z, "z_hi": zb, "level": trail_floor_at(zm) + off,
				"level_lo": trail_floor_at(z) + off, "level_hi": trail_floor_at(zb) + off,
				"tint": Color(0.52, 0.5, 0.45, 0.8), "clarity": 0.35, "flow": st["flow"], "along_z": true,
				"stream": st, "x_lo": cx - half - 4.0, "x_hi": cx + half + 4.0})
		z = zb


## Where the stream runs across the wash at `z`: it swings from wall to wall,
## less where the wash is narrow, so in a slot it follows the trail itself.
func _stream_x(st: Dictionary, z: float) -> float:
	var a := clampf(_lahar_half(z) - 7.0, 0.0, float(st["amp"]))
	return trail_x_at(z) + a * sin(z * float(st["freq"]) + float(st["phase"])) + minf(a, 1.6) * sin(z * 0.23 + float(st["phase"]) * 2.1)


## 0..1 how far into the stream's channel (x, z) is: one thread or, where a
## sand bar splits it, two; fading in and out at the ends of the wash.
func _stream_k(st: Dictionary, x: float, z: float) -> float:
	var z0: float = st["z0"]
	var z1: float = st["z1"]
	if z <= z0 or z >= z1:
		return 0.0
	var fade := smoothstep(z0, z0 + 10.0, z) * (1.0 - smoothstep(z1 - 10.0, z1, z))
	var cx := _stream_x(st, z)
	var w: float = float(st["width"]) * (0.75 + 0.5 * (_detail.get_noise_1d(z * 0.06 + 400.0) * 0.5 + 0.5))
	var bank := 0.8 + 1.4 * (_detail.get_noise_1d(z * 0.11 + 90.0) * 0.5 + 0.5)
	var split := 3.4 * smoothstep(0.15, 0.5, _detail.get_noise_1d(z * 0.03 + float(st["phase"]) * 10.0))
	var k: float
	if split > 0.4:
		var w2 := w * 0.7
		k = maxf(1.0 - smoothstep(w2, w2 + bank, absf(x - cx + split * 0.5)), 1.0 - smoothstep(w2, w2 + bank, absf(x - cx - split * 0.5)))
	else:
		k = 1.0 - smoothstep(w, w + bank, absf(x - cx))
	return k * fade


## How much deeper than usual the stream's bed is at `z`: its deep pockets.
func _stream_pocket(st: Dictionary, z: float) -> float:
	var p := 0.0
	for zp: float in st["deep"]:
		p = maxf(p, exp(-pow((z - zp) / 4.0, 2.0)))
	return float(st["depth"]) * 1.3 * p


## 0..1 how far into a lahar wash's slot canyon `z` is.
func _pinch(z: float) -> float:
	var k := 0.0
	for pz in _pinches:
		k = maxf(k, exp(-pow((z - pz) / 10.0, 2.0)))
	return k


## x: how far into the channel (1 in it, 0 past the bank), y: distance from
## the channel's middle in half-widths.
func _channel(c: Dictionary, x: float, z: float) -> Vector2:
	var mid: float = c["zc"] + c["amp"] * sin(x * c["freq"] + c["phase"])
	var hw: float = c["half_w"]
	if c.get("braided", false):
		# wanders on a short wavelength too, and swells and pinches as it goes
		var ph: float = c["phase"]
		mid += 2.2 * sin(x * 0.11 + ph * 2.3) + 0.9 * sin(x * 0.29 + ph * 5.1)
		hw *= 0.65 + 0.45 * (0.5 + 0.5 * sin(x * 0.07 + ph * 3.7)) + 0.15 * sin(x * 0.23 + ph)
	var u := absf(z - mid) / hw
	return Vector2(1.0 - smoothstep(1.0, 1.0 + float(c["bank"]) / hw, u), u)


func _near(list: Array[Dictionary], z: float, key: String, reach_key: String, pad: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f in list:
		var reach: float = f[reach_key] if reach_key != "" else 0.0
		if absf(z - float(f[key])) < reach + pad:
			out.append(f)
	return out


func water_level_at(z: float) -> float:
	var level := NO_WATER
	for b in water_bodies:
		if z > b["z_lo"] and z < b["z_hi"]:
			var l: float = b["level"]
			if b.has("level_lo"):   # a sloping stream sheet
				l = lerpf(b["level_lo"], b["level_hi"], (z - float(b["z_lo"])) / (float(b["z_hi"]) - float(b["z_lo"])))
			level = maxf(level, l)
	return level


# --- heights --------------------------------------------------------------------------

func _lahar_half(z: float) -> float:
	return lerpf(30.0 + 8.0 * _noise.get_noise_1d(z * 0.5 + 77.0), 6.5, _pinch(z))


## The two kanal ruts: deep V-ish trenches worn where every rig's wheels go,
## wandering a little so they pull you off line. Depth at signed offset `sx`.
func _kanal(z: float, sx: float, s: Dictionary) -> float:
	var off := 0.35 * sin(z * 0.05 + float(s["phase"]))
	var depth := (0.38 + 0.4 * (_detail.get_noise_1d(z * 0.4 + 300.0) * 0.5 + 0.5)) * plan.difficulty
	var d := minf(absf(sx - off - 0.82), absf(sx - off + 0.82))
	return depth * 0.5 * (1.0 + cos(PI * minf(d / 0.58, 1.0)))


## Ground height for one kind of land. `sx` is the signed distance across the
## trail, `th` the trail floor height.
func _kind_height(s: Dictionary, x: float, z: float, sx: float, th: float) -> float:
	var dx := absf(sx)
	var hills := _noise.get_noise_2d(x, z) * 0.5 + 0.5
	var detail := _detail.get_noise_2d(x, z)
	var k: String = s["kind"]
	if k == "yard":
		return Yard.height(x, z, _detail)
	match k:
		"paddy":
			# flat terraces either side of the road, pilapil dikes on a rough grid
			var land := th - 0.35 + detail * 0.05
			var gx := absf(fposmod(x + 3.0, 14.0) - 7.0)
			var gz := absf(fposmod(z + 5.0, 18.0) - 9.0)
			var dike := maxf(1.0 - smoothstep(0.3, 0.9, gx), 1.0 - smoothstep(0.3, 0.9, gz))
			land += dike * 0.45
			return lerpf(th, land, smoothstep(3.2, 4.7, dx))
		"lahar":
			# a wide flat valley floor of ash and sand between grey cliffs
			var half := _lahar_half(z)
			var floor_h := th + 0.22 * _detail.get_noise_2d(x * 0.35, z * 0.35) * smoothstep(1.5, 4.0, dx)
			# in the slot the crumbly walls stand near vertical
			return lerpf(floor_h, th + 7.0 + hills * 7.0, smoothstep(half, half + lerpf(9.0, 3.0, _pinch(z)), dx))
		"cogon":
			# open rolling grassland; the trail is two faint tracks over it
			return lerpf(th, th + hills * 5.0 + detail * 0.35, smoothstep(1.5, 16.0, dx))
		"niyog", "end":
			var h := lerpf(th, th + 0.3 + hills * 2.5 + detail * 0.3, smoothstep(3.0, 16.0, dx))
			if dx < 2.8:
				h += 0.06 * cos(dx * 1.4)
			return h
		"gully":
			# a sunken cut through the forest: a rock wall on one side, a steep
			# earth bank on the other, the floor no wider than a rig and a half
			var on_wall := sx * _gully_wall(s) > 0.0
			var up: float
			if on_wall:
				up = smoothstep(2.0, 3.6, dx) * (3.2 + hills * 2.5 + detail * 0.8) + smoothstep(3.6, 14.0, dx) * hills * 4.0
				up += 0.45 * _detail.get_noise_2d(x * 0.7, z * 0.7) * smoothstep(2.2, 3.4, dx)  # bulging rock face
			else:
				up = smoothstep(2.3, 5.5, dx) * (2.0 + hills * 2.0 + detail * 0.5) + smoothstep(5.5, 16.0, dx) * hills * 3.0
			return th + 0.08 * cos(minf(dx, 2.2) * 1.4) + up
		"pasture":
			# open green hillside pasture, the trail barely cut into it: two
			# wheel ruts worn in the grass, a grassy hump between them
			var h := lerpf(th, th + hills * 4.5 + detail * 0.3, smoothstep(1.8, 20.0, dx))
			h -= 0.13 * exp(-pow((dx - 0.8) / 0.28, 2.0))
			return h
		"ridge":
			# along a ridge crest: the land falls away on both sides to the
			# valleys, a low shoulder here and there; views all round
			var fall := pow(smoothstep(3.5, 45.0, dx), 0.8) * (12.0 + hills * 9.0)
			var shoulder := 0.6 * smoothstep(2.4, 5.0, dx) * (1.0 - smoothstep(5.0, 12.0, dx)) * (0.5 + hills)
			return th - fall + shoulder + detail * 0.25 * smoothstep(3.0, 8.0, dx)
		"sukal":
			# a narrow shelf cut across a steep hillside: up one side, a drop
			# on the other, the track no wider than a rig
			var up_side := 1.0 if sin(float(s["phase"]) * 5.0) > 0.0 else -1.0
			if sx * up_side > 0.0:
				return th + smoothstep(1.7, 3.2, dx) * 0.9 + maxf(0.0, dx - 2.0) * (0.55 + 0.25 * hills) + detail * 0.3
			return th - maxf(0.0, dx - 2.1) * (0.5 + 0.25 * hills) - smoothstep(2.1, 3.0, dx) * 0.4 + detail * 0.3 * smoothstep(3.0, 6.0, dx)
		"bog":
			# a sunken logging road with a chain of water-filled holes in it
			var h := lerpf(th, th + 0.9 + hills * 3.0 + detail * 0.5, smoothstep(2.8, 6.0, dx))
			var deepest := 0.8 * plan.difficulty
			var pit := clampf(_detail.get_noise_1d(z * 0.6 + float(s["phase"]) * 40.0) * 2.2, 0.0, deepest)
			h -= pit * (1.0 - smoothstep(1.4, 2.9, dx))
			if dx < 2.8:
				h += 0.08 * cos(dx * 1.4) * (1.0 - pit / deepest)
			return h
	# clay, kanal, river, rocky: a two-track cut into the hillside
	var relief := 6.0
	var bank_h := 1.8
	var bank_out := 7.0
	match k:
		"kanal":
			relief = 5.0
			bank_h = 1.2
		"river":
			relief = 4.0
			bank_h = 1.0
		"rocky":
			# an open rocky hillside, not a slot: the trail climbs over the rock
			relief = 5.0
			bank_h = 1.2
			bank_out = 9.0
	var h := lerpf(th, th + hills * relief + detail * 0.6 + bank_h, smoothstep(2.8, bank_out, dx))
	if dx < 2.8:
		h += 0.08 * cos(dx * 1.4)
	if k == "kanal":
		h -= _kanal(z, sx, s)
	elif k == "rocky":
		h += 0.14 * _detail.get_noise_2d(x * 2.3, z * 2.3) * (1.0 - smoothstep(2.0, 4.0, dx))
	return h


## Which side of a rock gully the rock wall is on (+1 or -1); the earth bank is the other.
func _gully_wall(s: Dictionary) -> float:
	return 1.0 if sin(float(s["phase"]) * 7.0) > 0.0 else -1.0


## Humps, wallows and potholes in the trail floor: nothing on a real trail is flat.
func _lumps(x: float, z: float) -> float:
	var big := _detail.get_noise_2d(x * 0.45 + 50.0, z * 0.45)
	var small := _detail.get_noise_2d(x * 1.3 - 20.0, z * 1.3)
	var hole := minf(0.0, _noise.get_noise_2d(x * 9.0, z * 9.0) + 0.25) * 1.6  # sharp-edged potholes
	return big * 0.6 + small * 0.3 + hole


func _height_at(x: float, z: float, bl: Array, th: float, tx: float, inv: float,
		near_cross: Array[Dictionary], near_pits: Array[Dictionary]) -> float:
	var sa: Dictionary = plan.sections[bl[0]]
	var sb: Dictionary = plan.sections[bl[1]]
	var w: float = bl[2]
	var sx := (x - tx) * inv
	var h := _kind_height(sa, x, z, sx, th)
	var lumps: float = LUMPS[sa["kind"]]
	if w > 0.0:
		h = lerpf(h, _kind_height(sb, x, z, sx, th), w)
		lumps = lerpf(lumps, LUMPS[sb["kind"]], w)
	h += lumps * _lumps(x, z) * (1.0 - smoothstep(2.5, 5.0, absf(sx)))
	# the land closes in past the finish clearing, so the trail doesn't just stop at an edge
	if not plan.yard:
		h += smoothstep(length - 30.0, length, z) * (5.0 + 3.0 * _noise.get_noise_2d(x, 0.0))
	for c in near_cross:
		var ch := _channel(c, x, z)
		if ch.x > 0.0:
			var bed: float = float(c["ref_h"]) - float(c["drop"]) + 0.35 * float(c["depth"]) * minf(ch.y * ch.y, 1.0)
			if c.get("ford", false):
				# water this deep mid-channel: the riffle's gravel bar, falling
				# away into the pools either side of it along the river
				# (the practice park's creek has two riffles)
				var deep := float(c["pool"])
				for f: Vector3 in c.get("fords", [Vector3(c["ford_x"], c["ford_w"], c["shallow"])]):
					deep = minf(deep, lerpf(float(c["pool"]), f.z, exp(-pow((x - f.x) / f.y, 2.0))))
				bed = float(c["level"]) - deep * (1.0 - 0.35 * minf(ch.y * ch.y, 1.0))
			if c["stones"]:
				bed += 0.1 * _detail.get_noise_2d(x * 1.6, z * 1.6)
			if c.get("braided", false):
				# sand bars: long low islands lying along the flow, the water
				# threading between them
				var bar := _detail.get_noise_2d(x * 0.09 + 50.0, z * 0.45 + 30.0)
				bed += float(c["depth"]) * 1.35 * smoothstep(0.05, 0.35, bar) * minf(1.0, 1.4 - ch.y)
				bed += 0.04 * _detail.get_noise_2d(x * 0.7, z * 0.7)   # rippled sand
			h = lerpf(h, minf(h, bed), ch.x)
	for p in near_pits:
		var d := Vector2(x - float(p["x"]), z - float(p["z"])).length()
		var r: float = p["r"]
		if d < r:
			var f := 1.0 - (d / r) * (d / r)
			h -= float(p["depth"]) * f * f
	for st in streams:
		var k := _stream_k(st, x, z)
		if k > 0.0:
			# cut into the ash, its bed cobbly, deeper in the pockets
			var bed := th - float(st["cut"]) - _stream_pocket(st, z) + 0.05 * _detail.get_noise_2d(x * 1.6, z * 1.6)
			h = lerpf(h, minf(h, bed), k)
	return h


func _build_heights() -> void:
	var nx := RES_X + 1
	var nz := res_z + 1
	heights.resize(nx * nz)
	for j in range(nz):
		var z := j * CELL
		var bl := plan.blend_at(z)
		var near_cross := _near(crossings, z, "zc", "reach", 1.0)
		var near_pits := _near(pits, z, "z", "", 1.6)
		var tx := trail_x_at(z)
		var th := trail_floor_at(z)
		var inv := _across(z)
		for i in range(nx):
			heights[j * nx + i] = _height_at(i * CELL, z, bl, th, tx, inv, near_cross, near_pits)


## The lowest ground within `r` of (x, z): what anything with a footprint
## (a boulder, a trunk) has to reach down to so no side of it hangs in the air.
func low_ground(x: float, z: float, r: float) -> float:
	var low := get_height(x, z)
	for k in range(8):
		var a := TAU * k / 8.0
		low = minf(low, get_height(x + cos(a) * r, z + sin(a) * r))
	return low


func get_height(x: float, z: float) -> float:
	var n := RES_X + 1
	var fx := clampf(x / CELL, 0.0, RES_X - 0.001)
	var fz := clampf(z / CELL, 0.0, res_z - 0.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var h00 := heights[j * n + i]
	var h10 := heights[j * n + i + 1]
	var h01 := heights[(j + 1) * n + i]
	var h11 := heights[(j + 1) * n + i + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


# --- soft ground ---------------------------------------------------------------------

## A churned mud hole at the foot of each steep pitch, where every rig has
## stopped, spun and dug before the climb. 0..1 along z.
func _wallow(s: Dictionary, z: float) -> float:
	if not s["kind"] in ["clay", "kanal", "gully", "cogon", "niyog", "lahar", "pasture"]:
		return 0.0
	var up: bool = float(s["h1"]) >= float(s["h0"])
	var best := 0.0
	for p: Array in s["pitches"]:
		var half: float = float(p[1]) * 0.5
		var foot: float = float(p[0]) - half - 4.0 if up else float(p[0]) + half + 4.0
		best = maxf(best, exp(-pow((z - foot) / 5.0, 2.0)))
	return best


## (thickness, wetness, preset rut, grip) for one kind of land.
func _kind_soil(s: Dictionary, x: float, z: float, sx: float, patchy: float) -> Vector4:
	var dx := absf(sx)
	var on := 1.0 - smoothstep(2.6, 4.0, dx)
	var rain: float = s["wet"]
	var wheel_line := exp(-pow((dx - 0.8) / 0.35, 2.0))  # churned by the last convoy
	if s["kind"] == "yard":
		return Yard.soil(x, z, patchy)
	match s["kind"]:
		"paddy":
			# compacted gravel road, blending into the saturated paddy
			var pk := smoothstep(3.0, 4.5, dx)
			# (the road itself goes greasy in the rains: wet packed gravel ~0.55)
			return Vector4(lerpf(0.04 * on, 0.25, pk), lerpf(0.12 + 0.5 * rain, 1.0, pk), 0.0, 1.0)
		"clay":
			var thick := on * (0.24 + 0.4 * patchy)
			return Vector4(thick, 0.3 + 0.25 * patchy + 0.3 * rain, minf(thick, 0.12 * wheel_line * (0.6 + 0.4 * patchy)), 1.0)
		"kanal":
			var tr := clampf(_kanal(z, sx, s) / 0.5, 0.0, 1.0)
			return Vector4(on * (0.12 + 0.2 * patchy) + 0.12 * tr, 0.45 + 0.25 * patchy + 0.3 * tr, 0.0, 1.0)
		"river":
			var thick := on * (0.08 + 0.14 * patchy)
			return Vector4(thick, 0.45 + 0.25 * patchy, minf(thick, 0.06 * wheel_line), 1.0)
		"lahar":
			# loose ash and sand all across the floor, packed thinner on the track
			var half := _lahar_half(z)
			var floor_k := 1.0 - smoothstep(half - 3.0, half + 4.0, dx)
			var packed := 1.0 - smoothstep(1.5, 3.0, dx)
			return Vector4(floor_k * (0.22 + 0.3 * patchy) * (1.0 - 0.5 * packed), 0.1 + 0.15 * patchy + 0.25 * rain * on, 0.0, 0.8)
		"rocky":
			return Vector4(on * 0.06 * patchy, 0.2 + 0.2 * rain, 0.0, 1.05)
		"gully":
			# wet clay between the stones, churned in the wheel lines, gritty with
			# broken rock so the tires find some bite on the climb
			var thick := on * (0.12 + 0.2 * patchy)
			return Vector4(thick, 0.38 + 0.2 * patchy + 0.2 * rain, minf(thick, 0.08 * wheel_line), 1.3)
		"bog":
			var thick := on * (0.5 + 0.35 * patchy)
			return Vector4(thick, 0.75 + 0.25 * patchy, minf(thick, 0.18 * wheel_line), 1.0)
		"cogon":
			return Vector4(on * 0.03, 0.2, 0.0, 1.0)
		"pasture":
			# the wheel ruts are mud, churned and wet after every convoy; the
			# grass between and beside them stays firm
			var lines := exp(-pow((dx - 0.8) / 0.22, 2.0))
			# on the climbs the water runs off: the ruts there are worn to firm,
			# drier clay; the mud sits in the flats and hollows
			var steep := smoothstep(0.08, 0.25, absf(plan.profile(z + 1.0) - plan.profile(z - 1.0)) * 0.5)
			var thick := lines * (0.14 + 0.2 * patchy) * (0.6 + 0.6 * rain) * (1.0 - 0.7 * steep) + on * 0.02
			return Vector4(thick, (0.45 + 0.3 * rain + 0.25 * lines) * (1.0 - 0.5 * steep), minf(thick, 0.1 * lines), 1.0)
		"ridge":
			# a hard, dry, stony dirt track: firm and gritty, slick after rain
			# (thin, but enough soil that it reads as a dirt track, not grass)
			var track := 1.0 - smoothstep(1.6, 2.4, dx)
			# (dirt over loose stones: ~0.73 dry, ~0.5 after rain, like the real thing)
			return Vector4(track * (0.06 + 0.03 * patchy), 0.05 + 0.45 * rain, 0.0, 0.82)
		"sukal":
			# a narrow clay track under the overgrowth, damp in the shade
			# (on the climbs it drains to firmer, grittier clay, roots in it)
			var track := 1.0 - smoothstep(1.3, 2.2, dx)
			var steep := smoothstep(0.08, 0.25, absf(plan.profile(z + 1.0) - plan.profile(z - 1.0)) * 0.5)
			var thick := track * (0.08 + 0.16 * patchy) * (1.0 - 0.6 * steep)
			return Vector4(thick, (0.3 + 0.2 * patchy + 0.25 * rain) * (1.0 - 0.5 * steep), minf(thick, 0.06 * wheel_line), 1.0 + 0.25 * steep)
	# niyog, end: a rutted farm road, carabao-cart deep in the wheel lines,
	# with standing puddles
	var pud := on * smoothstep(0.5, 0.68, _detail.get_noise_2d(x * 0.5, z * 0.5) * 0.5 + 0.5)
	var thick := on * (0.06 + 0.1 * patchy) + 0.32 * pud
	return Vector4(thick, maxf(0.25 + 0.25 * rain, 0.85 * pud), minf(thick, 0.1 * wheel_line), 1.0)


func _author_mud() -> void:
	var nx := RES_X + 1
	for cy in range(res_z):
		var z := (cy + 0.5) * CELL
		var bl := plan.blend_at(z)
		var sa: Dictionary = plan.sections[bl[0]]
		var sb: Dictionary = plan.sections[bl[1]]
		var w: float = bl[2]
		var near_cross := _near(crossings, z, "zc", "reach", 1.0)
		var near_pits := _near(pits, z, "z", "", 1.6)
		var tx := trail_x_at(z)
		var inv := _across(z)
		var lumps := lerpf(LUMPS[sa["kind"]], LUMPS[sb["kind"]], w)
		var rain_k := lerpf(sa["wet"], sb["wet"], w)
		var paddy_w := _weight("paddy", sa["kind"], sb["kind"], w)
		var wallow := lerpf(_wallow(sa, z), _wallow(sb, z), w)
		for cx in range(RES_X):
			var x := (cx + 0.5) * CELL
			var sx := (x - tx) * inv
			var patchy := _detail.get_noise_2d(x * 1.7, z * 1.7) * 0.5 + 0.5
			var m := _kind_soil(sa, x, z, sx, patchy)
			if w > 0.0:
				m = m.lerp(_kind_soil(sb, x, z, sx, patchy), w)
			var thick := m.x
			var wet := m.y
			# the season: dry clay is firm and thin, after rain it's deep and
			# soupy (the paddies are flooded either way)
			var dry_k := 1.0 - paddy_w
			wet = lerpf(wet, clampf(wet * lerpf(0.5, 1.3, rain_k), 0.0, 1.0), dry_k)
			thick *= lerpf(1.0, lerpf(0.75, 1.2, rain_k), dry_k)
			if wallow > 0.01:
				var on_w := 1.0 - smoothstep(2.4, 4.0, absf(sx))
				thick += on_w * wallow * 0.4 * plan.difficulty
				wet = maxf(wet, on_w * wallow * lerpf(0.6, 1.0, rain_k))
			# hollows in the lumpy floor hold more mud, and water if it has rained
			if thick > 0.02 and lumps > 0.0:
				var hollow := clampf(-_lumps(x, z), 0.0, 1.0)
				thick += hollow * lumps * 0.8
				wet = lerpf(wet, 1.0, hollow * (0.3 + 0.7 * rain_k))
			for c in near_cross:
				var k := smoothstep(0.3, 0.8, _channel(c, x, z).x)
				if k <= 0.0:
					continue
				if c["stones"]:
					thick = lerpf(thick, 0.02, k)
					m.w = lerpf(m.w, 0.75, k)  # wet river stones
				elif c["clarity"] > 0.0:
					thick = lerpf(thick, 0.2, k)
				else:
					thick = maxf(thick, 0.3 * k)
				wet = lerpf(wet, 1.0, k)
			for p in near_pits:
				var d := Vector2(x - float(p["x"]), z - float(p["z"])).length()
				var hk := 1.0 - smoothstep(float(p["r"]) * 0.5, float(p["r"]), d)
				thick = maxf(thick, 0.45 * hk)
				wet = maxf(wet, 0.9 * hk)
			for st in streams:
				var sk := _stream_k(st, x, z)
				if sk <= 0.0:
					continue
				# in the stream: wet cobbles; on its banks, here and there, sodden
				# sand that swallows a tire (the soft spots in the accounts)
				var inside := smoothstep(0.3, 0.8, sk)
				thick = lerpf(thick, 0.03, inside)
				m.w = lerpf(m.w, 0.8, inside)
				var bank := smoothstep(0.02, 0.25, sk) * (1.0 - smoothstep(0.45, 0.8, sk))
				var soft := bank * smoothstep(0.55, 0.78, patchy)
				thick = maxf(thick, 0.55 * soft * plan.difficulty)
				wet = maxf(wet, maxf(inside, soft))
			var i := mud.idx(cx, cy)
			mud.thickness[i] = thick
			mud.wetness[i] = clampf(wet, 0.0, 1.0)
			mud.rut[i] = minf(m.z, thick)
			grip[i] = m.w


## The park's depth posts at the deep crossing: white with a red band at the
## waterline, every 0.3 m of depth; and a sign post at each station's start.
func _build_yard_posts() -> void:
	var st := MeshKit.begin()
	# along the deep crossing, beside the line: a post where the water first
	# reaches 0.3, 0.6, 0.9, 1.2 m
	var want := [0.3, 0.6, 0.9, 1.2]
	for pn: Array in Yard.deep_line():
		if want.is_empty():
			break
		var c: Vector2 = pn[0]
		var level := water_at(c.x, c.y)
		if level == NO_WATER or level - get_height(c.x, c.y) < float(want[0]):
			continue
		want.pop_front()
		var p: Vector2 = c + (pn[1] as Vector2) * Yard.post_side() * 3.2
		var bed := get_height(p.x, p.y)
		var top := level + 0.5
		MeshKit.cylinder(st, 0.05, top - bed, Transform3D(Basis.IDENTITY, Vector3(p.x, (top + bed) * 0.5, p.y)), Color(0.9, 0.9, 0.88), 8)
		# the band at the waterline
		MeshKit.cylinder(st, 0.056, 0.06, Transform3D(Basis.IDENTITY, Vector3(p.x, level, p.y)), Color(0.75, 0.08, 0.05), 8)
	for s: Dictionary in Yard.stations():
		var at: Vector2 = s["sign"]
		var g := get_height(at.x, at.y)
		var face := Basis.looking_at(s["heading"], Vector3.UP)
		MeshKit.cylinder(st, 0.06, 1.6, Transform3D(Basis.IDENTITY, Vector3(at.x, g + 0.8, at.y)), Color(0.55, 0.4, 0.22), 8)
		MeshKit.rounded_box(st, Vector3(0.9, 0.5, 0.05), 0.02, Transform3D(face, Vector3(at.x, g + 1.6, at.y)), Color(0.92, 0.85, 0.5))
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.8
	var mi := MeshInstance3D.new()
	mi.name = "YardPosts"
	mi.mesh = MeshKit.commit(st, m)
	add_child(mi)


## The park track's timber: a bridge (planks on two stringers, posts down to
## the bed, low kerbs along the edges) and logs fallen across the trail.
## Solid, and in group "rock" so the wheels take them as firm ground.
func _build_park_structures() -> void:
	var list := Yard.structures()
	if list.is_empty():
		return
	var body := StaticBody3D.new()
	body.name = "Timber"
	body.add_to_group("rock")
	var st := MeshKit.begin()
	var timber := Color(0.42, 0.3, 0.19)
	var bark := Color(0.3, 0.22, 0.15)
	for s: Dictionary in list:
		var a: Vector3 = s["from"]
		var b: Vector3 = s["to"]
		var along := b - a
		var mid := (a + b) * 0.5
		var basis := Basis.looking_at(along.normalized(), Vector3.UP)   # -Z along it
		if s["type"] == "bridge":
			var wd: float = s["width"]
			var span := along.length()
			# the deck, as one solid box; planks drawn across it
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(wd, 0.16, span)
			cs.shape = box
			cs.transform = Transform3D(basis, mid + Vector3(0, -0.08, 0))
			body.add_child(cs)
			var n := int(span / 0.32)
			for k in n:
				var z := -span * 0.5 + (k + 0.5) * span / n
				var c := timber * (0.85 + 0.25 * fposmod(k * 0.618, 1.0))
				MeshKit.rounded_box(st, Vector3(wd, 0.07, span / n - 0.03), 0.01, Transform3D(basis, mid + basis * Vector3(0, -0.035, z)), c)
			# kerbs along each edge, and the stringers and posts under it
			for side: float in [-1.0, 1.0]:
				MeshKit.rounded_box(st, Vector3(0.14, 0.14, span), 0.02, Transform3D(basis, mid + basis * Vector3(side * (wd * 0.5 - 0.07), 0.07, 0.0)), timber * 0.8)
				var kerb := CollisionShape3D.new()
				var kb := BoxShape3D.new()
				kb.size = Vector3(0.14, 0.14, span)
				kerb.shape = kb
				kerb.transform = Transform3D(basis, mid + basis * Vector3(side * (wd * 0.5 - 0.07), 0.07, 0.0))
				body.add_child(kerb)
				MeshKit.rounded_box(st, Vector3(0.22, 0.3, span), 0.03, Transform3D(basis, mid + basis * Vector3(side * wd * 0.32, -0.24, 0.0)), timber * 0.7)
				for k in 3:
					var p := mid + basis * Vector3(side * wd * 0.32, 0.0, (k - 1) * span * 0.33)
					var bed := get_height(p.x, p.z)
					var top := p.y - 0.38
					if top > bed:
						MeshKit.cylinder(st, 0.12, top - bed + 0.3, Transform3D(Basis.IDENTITY, Vector3(p.x, (top + bed - 0.3) * 0.5, p.z)), timber * 0.6, 8)
		else:
			# a log: a capsule lying along it, bark-brown
			var r: float = s["radius"]
			var len := along.length()
			var lay := Basis(Vector3.RIGHT, PI * 0.5)   # cylinder's Y to -Z
			var cs := CollisionShape3D.new()
			var cap := CylinderShape3D.new()
			cap.radius = r
			cap.height = len
			cs.shape = cap
			cs.transform = Transform3D(basis * lay, mid)
			body.add_child(cs)
			MeshKit.cylinder(st, r, len, Transform3D(basis * lay, mid), bark, 12)
			# its cut ends, paler wood
			for e: float in [-1.0, 1.0]:
				MeshKit.cylinder(st, r * 0.92, 0.02, Transform3D(basis * lay, mid + along * 0.5 * e), Color(0.62, 0.5, 0.34), 12)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.85
	var mi := MeshInstance3D.new()
	mi.name = "TimberMesh"
	mi.mesh = MeshKit.commit(st, m)
	add_child(mi)
	add_child(body)


## 1 m maps for the ground shader (and vegetation / audio queries).
func _build_maps() -> void:
	var nx := int(WIDTH)
	var nz := int(length)
	cover_image = Image.create(nx, nz, false, Image.FORMAT_RGBAH)
	soil_image = Image.create(nx, nz, false, Image.FORMAT_RGBAH)  # half floats filter on every GPU
	for z in range(nz):
		var zf := z + 0.5
		var bl := plan.blend_at(zf)
		var ka: String = plan.sections[bl[0]]["kind"]
		var kb: String = plan.sections[bl[1]]["kind"]
		var w: float = bl[2]
		var forest_k := lerpf(FOREST[ka], FOREST[kb], w)
		var paddy_k := _weight("paddy", ka, kb, w)
		var ash_k := _weight("lahar", ka, kb, w)
		var rock_k := _weight("rocky", ka, kb, w)
		# a rock gully's wall is bare rock from the foot up
		var gully_k := _weight("gully", ka, kb, w)
		var wall_side := 0.0
		if gully_k > 0.0:
			wall_side = _gully_wall(plan.sections[bl[0]] if ka == "gully" else plan.sections[bl[1]])
		var level := water_level_at(zf)
		# paddies and bogs hold water wherever the ground dips; rivers and
		# creeks only in their own channel (soil A is that mask)
		var band_water := 0.0
		var pool_x := Vector2(INF, -INF)
		for b in water_bodies:
			if b.has("pool") and zf > b["z_lo"] and zf < b["z_hi"]:
				pool_x = Vector2(b["x_lo"], b["x_hi"])   # only in its basin
			elif not b.has("crossing") and not b.has("stream") and zf > b["z_lo"] and zf < b["z_hi"]:
				band_water = 1.0
		var near_cross := _near(crossings, zf, "zc", "reach", 1.0)
		var tx := trail_x_at(zf)
		var inv := _across(zf)
		var half := _lahar_half(zf)
		for x in range(nx):
			var xf := x + 0.5
			var dx := absf(xf - tx) * inv
			var edge := 4.5 + 2.5 * _detail.get_noise_2d(xf * 0.7, zf * 0.7)
			var forest := forest_k * smoothstep(edge, edge + 4.0, dx) * (1.0 - smoothstep(26.0, 40.0, dx) * 0.6)
			if ash_k > 0.0:
				forest = maxf(forest, ash_k * 0.7 * smoothstep(half + 8.0, half + 14.0, dx))  # woods on the cliff tops
			var on := 1.0 - smoothstep(2.6, 4.0, dx)
			var cobble := 0.0
			var wet_mask := band_water
			if xf > pool_x.x and xf < pool_x.y:
				wet_mask = 1.0
				cobble = 1.0   # a clean gravel bed
			for c in near_cross:
				var k := _channel(c, xf, zf).x
				if k > 0.02:
					wet_mask = 1.0
				if c["stones"]:
					cobble = maxf(cobble, smoothstep(0.2, 0.7, k))
			for st in streams:
				var sk := _stream_k(st, xf, zf)
				if sk > 0.05:
					wet_mask = 1.0
				cobble = maxf(cobble, smoothstep(0.25, 0.75, sk))
			var trail_d := minf(dx / 32.0, 1.0)
			if plan.yard:
				forest = Yard.forest(xf, zf)
				trail_d = Yard.trail_dist(xf, zf) / 32.0
				ash_k = Yard.ash(xf, zf)   # a lahar wash's grey (and the rig's mud grey too)
			cover_image.set_pixel(x, z, Color(trail_d, forest, paddy_k, ash_k))
			var bedrock := rock_k * (0.9 * on + 0.3 * (1.0 - on))
			if plan.yard:
				bedrock = Yard.bedrock(xf, zf)
			if gully_k > 0.0 and (xf - tx) * wall_side > 0.0:
				bedrock = maxf(bedrock, gully_k * smoothstep(1.3, 2.1, dx) * (1.0 - smoothstep(9.0, 13.0, dx)))
			soil_image.set_pixel(x, z, Color(bedrock, cobble, level, wet_mask))


static func _weight(kind: String, ka: String, kb: String, w: float) -> float:
	return (1.0 - w if ka == kind else 0.0) + (w if kb == kind else 0.0)


# --- geometry ------------------------------------------------------------------------

func _build_mesh() -> void:
	var nx := RES_X + 1
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/terrain.gdshader")
	mat.set_shader_parameter("mud_tex", mud.texture)
	mat.set_shader_parameter("cover_tex", ImageTexture.create_from_image(cover_image))
	soil_texture = ImageTexture.create_from_image(soil_image)
	var bw := soil_image.get_width()
	var bh := soil_image.get_height()
	var bed := Image.create(bw, bh, false, Image.FORMAT_RF)
	for z in range(bh):
		for x in range(bw):
			bed.set_pixel(x, z, Color(get_height(x + 0.5, z + 0.5), 0, 0))
	bed_texture = ImageTexture.create_from_image(bed)
	mat.set_shader_parameter("soil_tex", soil_texture)
	mat.set_shader_parameter("world_size", WIDTH)
	var rows := int(MESH_CHUNK / CELL)
	for j0 in range(0, res_z, rows):
		var j1 := mini(j0 + rows, res_z)
		var count := (j1 - j0 + 1) * nx
		var verts := PackedVector3Array()
		var normals := PackedVector3Array()
		var uvs := PackedVector2Array()
		verts.resize(count)
		normals.resize(count)
		uvs.resize(count)
		for j in range(j0, j1 + 1):
			for i in range(nx):
				var k := j * nx + i
				var q := (j - j0) * nx + i
				var x := i * CELL
				var z := j * CELL
				verts[q] = Vector3(x, heights[k], z)
				uvs[q] = Vector2(x / WIDTH, z / length)
				var hl := heights[j * nx + maxi(i - 1, 0)]
				var hr := heights[j * nx + mini(i + 1, nx - 1)]
				var hd := heights[maxi(j - 1, 0) * nx + i]
				var hu := heights[mini(j + 1, res_z) * nx + i]
				normals[q] = Vector3(hl - hr, 2.0 * CELL, hd - hu).normalized()
		var indices := PackedInt32Array()
		indices.resize((j1 - j0) * RES_X * 6)
		var q := 0
		for j in range(j1 - j0):
			for i in range(RES_X):
				var a := j * nx + i
				var b := a + 1
				var c := a + nx
				var d := c + 1
				# Godot front faces wind clockwise seen from above (+Y).
				indices[q] = a; indices[q + 1] = b; indices[q + 2] = c
				indices[q + 3] = b; indices[q + 4] = d; indices[q + 5] = c
				q += 6
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, mat)
		# ruts and berms move the surface in the shader; give culling some slack
		mesh.custom_aabb = mesh.get_aabb().grow(1.0)
		var mi := MeshInstance3D.new()
		mi.name = "Ground%d" % (j0 / rows)
		mi.mesh = mesh
		add_child(mi)


func _build_collision() -> void:
	# The collider is the FIRM floor under the soft mud, so wheels and chassis
	# can sink below the visual surface without fighting an invisible wall.
	# Square tiles, one HeightMapShape3D each.
	var nx := RES_X + 1
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = 1
	for t0 in range(0, res_z, RES_X):
		var firm := PackedFloat32Array()
		firm.resize(nx * nx)
		for jj in range(nx):
			var j := mini(t0 + jj, res_z)
			for i in range(nx):
				firm[jj * nx + i] = heights[j * nx + i] - mud.thickness[mud.idx(mini(i, RES_X - 1), mini(j, res_z - 1))]
		var shape := HeightMapShape3D.new()
		shape.map_width = nx
		shape.map_depth = nx
		shape.map_data = firm
		var cs := CollisionShape3D.new()
		cs.shape = shape
		# HeightMapShape3D is centred on its origin and 1 unit per cell; scale to CELL.
		cs.scale = Vector3(CELL, 1.0, CELL)
		cs.position = Vector3(WIDTH * 0.5, 0.0, (t0 + RES_X * 0.5) * CELL)
		body.add_child(cs)
	add_child(body)


func _build_water() -> void:
	var shader := load("res://shaders/water.gdshader")
	# One sheet per body of water, as wide as the map. Each sits below the
	# banks, so it only shows where the ground dips under it.
	for b in water_bodies:
		var plane := PlaneMesh.new()
		# a stream's pools only span the wash they run down
		var x_lo: float = b.get("x_lo", 0.0)
		var x_hi: float = b.get("x_hi", WIDTH)
		plane.size = Vector2(x_hi - x_lo, float(b["z_hi"]) - float(b["z_lo"]))
		var mi := MeshInstance3D.new()
		mi.mesh = plane
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("tint", b["tint"])
		mat.set_shader_parameter("clarity", b["clarity"])
		mat.set_shader_parameter("flow", Vector2(0.0, b["flow"]) if b.get("along_z", false) else Vector2(b["flow"], 0.0))
		mat.set_shader_parameter("use_mask", true)
		mat.set_shader_parameter("soil_tex", soil_texture)
		mat.set_shader_parameter("world_size", Vector2(WIDTH, length))
		mat.set_shader_parameter("bed_tex", bed_texture)
		water_mats.append(mat)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3((x_lo + x_hi) * 0.5, b["level"], (float(b["z_lo"]) + float(b["z_hi"])) * 0.5)
		if b.has("level_lo"):
			# tilt it down the wash; a touch longer so neighbours overlap, no seam
			var span := float(b["z_hi"]) - float(b["z_lo"])
			var drop := float(b["level_hi"]) - float(b["level_lo"])
			mi.position.y = (float(b["level_lo"]) + float(b["level_hi"])) * 0.5
			mi.rotation.x = -atan2(drop, span)
			plane.size.y = sqrt(span * span + drop * drop) + 0.3
		mi.name = "Water"
		add_child(mi)


func _place_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 9
	# `sink`: how much of the stone sits below the ground
	var add := func(x: float, z: float, r: float, sink: float) -> void:
		if x < 3.0 or x > WIDTH - 3.0 or z < 2.0 or z > length - 2.0:
			return
		# sit it on the lowest ground under its footprint, so on a slope the
		# downhill side is bedded in instead of hanging in the air
		var low := low_ground(x, z, r * 0.8)
		rock_spots.append(Vector4(x, low - r * sink, z, r))
		if r > 0.9 and absf(x - trail_x_at(z)) < 14.0:
			tree_anchors.append(Vector3(x, get_height(x, z) + r * 0.5, z))  # a boulder takes a tree saver too
	for s in plan.sections:
		var z0: float = s["z0"]
		var z1: float = s["z1"]
		var off_trail := 8
		match s["kind"]:
			"river":
				for c in crossings:
					if c["zc"] < z0 or c["zc"] > z1:
						continue
					for k in range(90):
						var x := trail_x_at(c["zc"]) + rng.randfn(0.0, 22.0)
						var z: float = c["zc"] + c["amp"] * sin(x * c["freq"] + c["phase"]) + rng.randf_range(-1.1, 1.1) * float(c["half_w"])
						var r := 0.25 + pow(rng.randf(), 2.2) * 1.2
						if absf(x - trail_x_at(z)) < 2.4 and r > 0.45:
							r = rng.randf_range(0.28, 0.55) * plan.difficulty  # crawlable, if you pick your line
						add.call(x, z, r, 0.35)
				off_trail = 12
			"rocky":
				for k in range(int(40 * plan.difficulty)):
					var z := rng.randf_range(z0 + 8.0, z1 - 8.0)
					add.call(trail_x_at(z) + rng.randf_range(-1.8, 1.8), z, rng.randf_range(0.28, 0.65) * plan.difficulty, 0.35)
				off_trail = 40
				# loose rubble broken off the steps, gathered at the foot of each
				# ledge and scattered on the benches: it rolls under the tires
				var rubble := RandomNumberGenerator.new()
				rubble.seed = seed_value + 31   # its own stream: the rest of the stage keeps its stones
				for k in range(int(70 * plan.difficulty)):
					var z := rubble.randf_range(z0 + 6.0, z1 - 6.0)
					add.call(trail_x_at(z) + rubble.randfn(0.0, 1.6), z, rubble.randf_range(0.12, 0.24), 0.4)
			"gully":
				# stones half-buried in the clay all across the floor: pick a line
				# over them and crawl it, the mud slick on every one
				# in rock gardens a few metres long, muddy gaps between them
				var placed := 0
				var tries := 0
				while placed < int(65 * plan.difficulty) and tries < 2000:
					tries += 1
					var z := rng.randf_range(z0 + 6.0, z1 - 6.0)
					if _detail.get_noise_1d(z * 0.25 + float(s["phase"]) * 30.0) < -0.1:
						continue
					add.call(trail_x_at(z) + rng.randf_range(-2.0, 2.0), z, rng.randf_range(0.2, 0.52) * plan.difficulty, 0.55)
					placed += 1
				# big ones fallen off the wall and the bank, sat at the foot of them
				for k in range(18):
					var z := rng.randf_range(z0 + 6.0, z1 - 6.0)
					var side := 1.0 if rng.randf() < 0.5 else -1.0
					add.call(trail_x_at(z) + side * rng.randf_range(2.1, 3.2), z, rng.randf_range(0.7, 1.4), 0.4)
				off_trail = 20
			"lahar":
				# what the flows carried down from Pinatubo: cobbles and boulders
				# in clusters in and along the stream, some right on the line you
				# want, and a few big ones stranded out on the sand
				for st in streams:
					if float(st["z0"]) < z0 or float(st["z0"]) > z1:
						continue
					for k in range(int(26 * plan.difficulty)):
						var z := rng.randf_range(float(st["z0"]) + 4.0, float(st["z1"]) - 4.0)
						var x := _stream_x(st, z) + rng.randfn(0.0, 2.6)
						for j in range(rng.randi_range(1, 4)):
							var r := 0.25 + pow(rng.randf(), 1.8) * 0.9
							var xj := x + rng.randf_range(-1.3, 1.3)
							var zj := z + rng.randf_range(-1.3, 1.3)
							if absf(xj - trail_x_at(zj)) < 2.4 and r > 0.5:
								r = rng.randf_range(0.3, 0.55) * plan.difficulty   # crawlable on the line
							add.call(xj, zj, r, 0.35)
					for k in range(5):
						var z := rng.randf_range(z0 + 8.0, z1 - 8.0)
						var side := 1.0 if rng.randf() < 0.5 else -1.0
						add.call(trail_x_at(z) + side * rng.randf_range(5.0, maxf(6.0, _lahar_half(z) - 3.0)), z, rng.randf_range(1.6, 2.4), 0.4)
				off_trail = 10
			"ridge":
				# loose stones on the track, a few bigger ones to pick round
				var stones := RandomNumberGenerator.new()
				stones.seed = seed_value + 37
				for k in range(int(55 * plan.difficulty)):
					var z := stones.randf_range(z0 + 6.0, z1 - 6.0)
					add.call(trail_x_at(z) + stones.randfn(0.0, 1.3), z, stones.randf_range(0.12, 0.3), 0.45)
				for k in range(int(10 * plan.difficulty)):
					var z := stones.randf_range(z0 + 8.0, z1 - 8.0)
					# the big ones sit on the level stretches, not halfway up the pitch
					if absf(plan.profile(z + 1.0) - plan.profile(z - 1.0)) > 0.4:
						continue
					add.call(trail_x_at(z) + stones.randf_range(-1.6, 1.6), z, stones.randf_range(0.3, 0.5) * plan.difficulty, 0.4)
				off_trail = 6
			"pasture", "sukal":
				off_trail = 3
			"yard":
				for v in Yard.rocks():
					rock_spots.append(Vector4(v.x, get_height(v.x, v.z) + v.y, v.z, v.w))
					if v.w > 0.9:
						tree_anchors.append(Vector3(v.x, get_height(v.x, v.z) + v.w * 0.5, v.z))
				off_trail = 0
		_straddle_rocks(s)
		for k in range(off_trail):
			var z := rng.randf_range(z0, z1)
			var side := 1.0 if rng.randf() < 0.5 else -1.0
			var big := 1.8 if s["kind"] in ["rocky", "lahar"] else 1.3
			add.call(trail_x_at(z) + side * rng.randf_range(4.5, 25.0), z, rng.randf_range(0.5, big), 0.35)
	var rocks := Rocks.new()
	rocks.name = "Rocks"
	add_child(rocks)
	rocks.build(self, rock_spots)


## Set pieces for career damage, Hard and Extreme only (none on Moderate),
## each kind from its own random stream so every other stone keeps its place:
##   - straddle rocks: right on the line between the tire tracks. Straddle
##     one and a stock rig's transfer case (about 0.55 m up) lands on it: put
##     a tire on it and crawl over, or come with lift and skid plates.
##   - edge boulders: big ones just outside a tire track. Lean toward one on
##     an off-camber and the sills drag along it (rock sliders); slide
##     sideways into it and the front tire slams the rock (the tie rod).
## Rock meshes are squashed spheres, standing about two thirds of their
## radius over their centre, and sit flat on their bottom.
const ROCK_TOP := 0.67
func _straddle_rocks(s: Dictionary) -> void:
	var per := {"rocky": 4, "gully": 3, "lahar": 2, "ridge": 2}
	var edge := {"rocky": 3, "gully": 4, "lahar": 2}
	if plan.difficulty < 0.9 or not (per.has(s["kind"]) or edge.has(s["kind"])):
		return
	var z0: float = s["z0"]
	var z1: float = s["z1"]
	var more := (plan.difficulty - 0.4) * 1.6   # 1 on Hard, ~1.4 on Extreme
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 41 + int(s["z0"])
	for k in range(int(roundf(float(per.get(s["kind"], 0)) * more))):
		var z := rng.randf_range(z0 + 15.0, z1 - 15.0)
		var x := trail_x_at(z) + rng.randf_range(-0.25, 0.25)
		# how tall it stands over the trail where the rig straddles it (not
		# bedded on the lowest ground round it, as other stones are: on a
		# slope that buried them under any rig's belly)
		var h := rng.randf_range(0.5, 0.72) * (1.0 + 0.4 * (plan.difficulty - 1.0))
		var r := h * rng.randf_range(1.0, 1.15)
		rock_spots.append(Vector4(x, get_height(x, z) + h - ROCK_TOP * r, z, r))
	var side_rng := RandomNumberGenerator.new()
	side_rng.seed = seed_value + 43 + int(s["z0"])
	for k in range(int(roundf(float(edge.get(s["kind"], 0)) * more))):
		var z := side_rng.randf_range(z0 + 15.0, z1 - 15.0)
		var side := 1.0 if side_rng.randf() < 0.5 else -1.0
		var r := side_rng.randf_range(0.8, 1.15)
		# its face a hand's width or two outside the tire track (~0.95 m out)
		var x := trail_x_at(z) + side * (side_rng.randf_range(1.1, 1.35) + r)
		rock_spots.append(Vector4(x, get_height(x, z) + 0.05, z, r))


func _build_trees() -> void:
	# Trees by section: dense off the trail in the forest kinds, a few right
	# at the bank edge so there's always a winch anchor in reach. Coconut farms
	# get palms in rows instead. Trunks near the trail are solid; canopies are not.
	# The look (trees, bamboo, palms, grass, rice) is all in Vegetation.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var placements: Array[Transform3D] = []
	var anchors_body := StaticBody3D.new()
	anchors_body.name = "Trees"
	anchors_body.collision_layer = 1
	var solid := func(x: float, y: float, z: float, scale: float) -> void:
		tree_anchors.append(Vector3(x, y + 0.8, z))
		var cs := CollisionShape3D.new()
		var cap := CylinderShape3D.new()
		cap.radius = 0.3 * scale
		cap.height = 7.0 * scale
		cs.shape = cap
		cs.position = Vector3(x, y + 3.5 * scale, z)
		anchors_body.add_child(cs)
	for s in plan.sections:
		var z0: float = s["z0"]
		var z1: float = s["z1"]
		var kind: String = s["kind"]
		var count := int((z1 - z0) * float(TREES[kind]))
		for _k in range(count):
			var z := rng.randf_range(z0, z1)
			var tx := trail_x_at(z)
			var side := 1.0 if rng.randf() < 0.5 else -1.0
			# clustered just past the bank, thinning further out
			var off := 4.2 + absf(rng.randfn(0.0, 1.0)) * 9.0
			if rng.randf() < 0.12:
				off = rng.randf_range(3.6, 4.4)  # right on the bank: winch anchors
			if kind == "lahar":
				off = _lahar_half(z) + 8.0 + absf(rng.randfn(0.0, 1.0)) * 12.0
			elif kind == "cogon":
				off = rng.randf_range(6.0, 45.0)
			elif kind == "pasture":
				off = rng.randf_range(16.0, 55.0)   # the forest edge round the meadow
			elif kind == "ridge":
				off = rng.randf_range(10.0, 45.0)   # a lone tree down on the shoulders
			elif kind == "sukal":
				off = rng.randf_range(3.2, 22.0)
			var x := tx + side * off / _across(z)
			if x < 2.0 or x > WIDTH - 2.0:
				continue
			var y := get_height(x, z)
			if y < water_at(x, z) + 0.3:
				continue  # not in the river
			var scale := rng.randf_range(0.75, 1.15)
			# root the trunk at the lowest ground round its base, so on a bank
			# the downhill side doesn't hang out over the slope
			y = low_ground(x, z, 0.45 * scale)
			placements.append(Transform3D(Basis().rotated(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale), Vector3(x, y - 0.15, z)))
			if off < 22.0:
				solid.call(x, y, z, scale)  # winch anchor, and a trunk you can't drive through
		if kind == "niyog":
			# a coconut plantation: palms in loose rows either side of the road
			var gz := z0 + 4.0
			while gz < z1 - 2.0:
				var gx := 6.0
				while gx < WIDTH - 6.0:
					var x := gx + rng.randf_range(-1.2, 1.2)
					var z := gz + rng.randf_range(-1.2, 1.2)
					var dx := absf(x - trail_x_at(z))
					if dx > 4.8 and dx < 60.0 and rng.randf() < 0.85:
						var y := low_ground(x, z, 0.3)
						palm_spots.append(Transform3D(Basis().rotated(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.85, 1.15)), Vector3(x, y - 0.1, z)))
						if dx < 22.0:
							solid.call(x, y, z, 0.8)
					gx += 8.5
				gz += 8.5
	if plan.yard:
		# the park's woods (Yard decides where), every trunk solid and an anchor
		for q: Vector3 in Yard.tree_spots():
			if get_height(q.x, q.y) < water_at(q.x, q.y) + 0.3:
				continue   # not in the creek
			var y := low_ground(q.x, q.y, 0.45 * q.z)
			placements.append(Transform3D(Basis().rotated(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * q.z), Vector3(q.x, y - 0.15, q.y)))
			solid.call(q.x, y, q.y, q.z)
	add_child(anchors_body)
	var veg := Vegetation.new()
	veg.name = "Vegetation"
	add_child(veg)
	veg.build(self, placements)


func _build_finish() -> void:
	if plan.yard:
		_build_yard_posts()
		_build_park_structures()
		return
	# a bamboo arch with a tarpaulin banner across the trail, barangay-fiesta style
	var z := plan.finish_z
	var tx := trail_x_at(z)
	var arch := Node3D.new()
	arch.name = "Finish"
	var heading := Vector3(trail_x_at(z + 3.0) - trail_x_at(z - 3.0), 0.0, 6.0).normalized()
	arch.transform = Transform3D(Basis.looking_at(heading, Vector3.UP), Vector3(tx, trail_floor_at(z), z))
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.62, 0.55, 0.3)
	pole_mat.roughness = 0.6
	# the banner rides high enough to clear a caged rig and the chase camera
	# behind it; each pole runs from the ground where it stands up to it
	var banner_y := 5.6
	for side: float in [-1.0, 1.0]:
		var pole := MeshInstance3D.new()
		var at := arch.transform * Vector3(side * 4.2, 0.0, 0.0)
		var foot := low_ground(at.x, at.z, 0.1) - arch.transform.origin.y - 0.3
		var top := banner_y + 0.6
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.07
		cyl.bottom_radius = 0.085
		cyl.height = top - foot
		cyl.material = pole_mat
		pole.mesh = cyl
		pole.position = Vector3(side * 4.2, (top + foot) * 0.5, 0.0)
		arch.add_child(pole)
	var banner := MeshInstance3D.new()
	var cloth := BoxMesh.new()
	cloth.size = Vector3(8.2, 1.0, 0.03)
	var cloth_mat := StandardMaterial3D.new()
	cloth_mat.albedo_color = Color(0.75, 0.12, 0.08)
	cloth_mat.roughness = 0.8
	cloth.material = cloth_mat
	banner.mesh = cloth
	banner.position = Vector3(0.0, banner_y, 0.0)
	arch.add_child(banner)
	for flip: float in [0.0, PI]:
		var text := Label3D.new()
		text.text = "FINISH"
		text.font_size = 160
		text.pixel_size = 0.005
		text.modulate = Color(1.0, 0.86, 0.3)
		text.outline_size = 0
		text.position = Vector3(0.0, banner_y, 0.03 if flip == 0.0 else -0.03)
		text.rotation = Vector3(0.0, flip, 0.0)  # one side reads to the rig coming up the trail
		arch.add_child(text)
	add_child(arch)


# --- queries -----------------------------------------------------------------------

## Soft-ground sample at a world position. Returns the MudField dictionary
## plus "water_depth" (metres of standing water above the surface, 0 if none)
## and "grip" (friction multiplier for this kind of ground).
func ground_sample(world_pos: Vector3) -> Dictionary:
	var xz := Vector2(world_pos.x, world_pos.z)
	var s := mud.sample(xz)
	var top := get_height(world_pos.x, world_pos.z)
	var surface: float = top - s["rut"]
	s["firm_y"] = top - s["thickness"]
	s["water_depth"] = maxf(0.0, water_at(world_pos.x, world_pos.z) - surface)
	s["surface_y"] = surface
	var c := mud.world_to_cell(xz)
	s["grip"] = grip[mud.idx(c.x, c.y)]
	s["ash"] = _cover(world_pos.x, world_pos.z).a   # grey lahar ash rather than red clay
	return s


func _cover(x: float, z: float) -> Color:
	return cover_image.get_pixel(clampi(int(x), 0, cover_image.get_width() - 1), clampi(int(z), 0, cover_image.get_height() - 1))


## Water surface height here, or NO_WATER if water can't stand here.
func water_at(x: float, z: float) -> float:
	return water_level_at(z) if water_mask_at(x, z) else NO_WATER


## How the water is flowing here (m/s), zero outside a running river or creek.
func current_at(x: float, z: float) -> Vector3:
	for c in crossings:
		if absf(z - float(c["zc"])) < float(c["reach"]):
			var k := _channel(c, x, z).x
			if k > 0.0:
				return Vector3(float(c["flow"]) * k, 0.0, 0.0)
	for st in streams:
		var sk := _stream_k(st, x, z)
		if sk > 0.1:
			# down the wash, the way the ground falls
			var down := signf(trail_floor_at(z) - trail_floor_at(z + 2.0))
			return Vector3(0.0, 0.0, float(st["flow"]) * sk * down)
	return Vector3.ZERO


## Can water stand here (a paddy, a bog hole, inside a river or creek channel)?
func water_mask_at(x: float, z: float) -> bool:
	return soil_image.get_pixel(clampi(int(x), 0, soil_image.get_width() - 1), clampi(int(z), 0, soil_image.get_height() - 1)).a > 0.5


func forest_at(x: float, z: float) -> float:
	return _cover(x, z).g


func paddy_at(x: float, z: float) -> float:
	return _cover(x, z).b


func nearest_anchor(from: Vector3, max_dist: float) -> Vector3:
	var best := Vector3.INF
	var best_d := max_dist
	for a in tree_anchors:
		var d := from.distance_to(a)
		if d < best_d:
			best_d = d
			best = a
	return best
