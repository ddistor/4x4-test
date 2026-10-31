class_name Yard
extends RefCounted
## Bakuran: the club's practice yard outside Morong, an open 160 x 160 m lot
## (one terrain tile) with a station for each thing you can buy or tune, a
## gravel road joining them. Not a trail: you drive where you like. The
## terrain asks this file what's where (heights, soil, rocks, water); the
## stations are fixed, so the yard is also a repeatable test bed.
##
##                         N (+z)
##   [10] hill lanes: 20, 30, 40, 45 deg up to the bank top
##   [5] tilt ramp  [9] winch rock  [6] flex humps
##   [1] bump strip [7] mud pit     [4] rock squeeze (off-camber)
##   [2] ledges     [8] wading pool [3] straddle line
##   ======= road ======= * spawn ======= road =======
##
## Every station is driven up +z from its start (Backspace takes you to the
## nearest one, the pause menu to any).

const SIZE := 160.0
const SPAWN := Vector2(80.0, 10.0)
const ROAD_Z := Vector2(16.0, 22.0)      # the road across the south side
const SPINE_X := Vector2(77.0, 83.0)     # and up the middle

## [name, what it tests, start (x, z), the lane's rect (x0, z0, x1, z1)]
const STATIONS := [
	["Bump strip", "humps of 5 to 30 cm: clay on the left, rock on the right", Vector2(40, 26), Rect2(33, 28, 14, 24)],
	["Ledges", "steps of 20, 40 and 60 cm onto bare rock, then a ramp down", Vector2(40, 56), Rect2(33, 58, 14, 28)],
	["Tilt ramp", "a side slope that steepens from 5 to 40 deg: where does it tip?", Vector2(40, 88), Rect2(32, 90, 20, 34)],
	["Straddle line", "rocks 0.45, 0.6 and 0.75 m tall on the centre line: belly and skids", Vector2(120, 26), Rect2(113, 28, 14, 24)],
	["Rock squeeze", "an off-camber with boulders on the low side: sills and tie rods", Vector2(120, 56), Rect2(111, 58, 18, 28)],
	["Flex humps", "humps under one wheel then the other: flex and lockers", Vector2(120, 88), Rect2(112, 90, 16, 30)],
	["Wading pool", "clear water, deepening to 1.6 m: the posts mark 0.3 m steps", Vector2(80, 46), Rect2(68, 50, 24, 28)],
	["Mud pit", "firm at the rim, soup in the middle: air down, tread, the radiator", Vector2(80, 82), Rect2(64, 86, 32, 30)],
	["Winch rock", "a big boulder to winch to, out of the mud pit", Vector2(80, 120), Rect2(72, 118, 16, 16)],
	["Hill lanes", "four climbs: 20, 30, 40 and 45 deg (lanes west to east)", Vector2(28, 130), Rect2(18, 134, 124, 26)]]

## the hill lanes: [x centre, grade in degrees]
const HILLS := [[28.0, 20.0], [62.0, 30.0], [98.0, 40.0], [132.0, 45.0]]
const HILL_Z := 136.0
const HILL_TOP := 9.0
const POOL := {"x0": 70.0, "x1": 90.0, "z_in": 54.0, "z_deep": 66.0, "z_out": 76.0, "depth": 1.6, "level": -0.05}
const PIT := {"c": Vector2(80, 100), "r": 14.0}


## The ground height anywhere in the yard (before soft ground goes on top).
static func height(x: float, z: float, noise: FastNoiseLite) -> float:
	var h := 0.12 * noise.get_noise_2d(x * 0.6, z * 0.6)
	# a bank all round, so the yard is a yard, not the edge of the world
	var edge := minf(minf(x, SIZE - x), z)
	h += 3.0 * (1.0 - smoothstep(0.0, 9.0, edge))
	# [1] bump strip: rounded humps across the lane
	if _in(x, z, 34, 46, 29, 52):
		var bumps := [[32.0, 0.05], [36.0, 0.1], [40.0, 0.15], [44.0, 0.2], [48.0, 0.3]]
		for b: Array in bumps:
			var d := absf(z - float(b[0]))
			if d < 0.6:
				h += float(b[1]) * 0.5 * (1.0 + cos(PI * d / 0.6))
	# [2] ledges: up 0.2, 0.4 and 0.6 m, benches between, then a ramp down
	if _in(x, z, 34, 46, 58, 88):
		var rise := 0.0
		for step: Array in [[64.0, 0.2], [70.0, 0.4], [76.0, 0.6]]:
			rise += float(step[1]) * smoothstep(float(step[0]) - 0.06, float(step[0]) + 0.06, z)
		rise *= 1.0 - smoothstep(80.0, 87.0, z)
		h += rise * _lane(x, 34, 46)
	# [5] tilt ramp: the lane leans, more and more, east side up
	if _in(x, z, 30, 54, 90, 126):
		var a := deg_to_rad(lerpf(5.0, 40.0, clampf((z - 94.0) / 28.0, 0.0, 1.0)))
		var lean := tan(a) * clampf(x - 36.0, 0.0, 8.0)
		# a bank behind the high side back down to the field
		lean *= 1.0 - smoothstep(44.0, 52.0, x)
		h += lean * smoothstep(90.0, 93.0, z) * (1.0 - smoothstep(122.0, 126.0, z))
	# [4] rock squeeze: an off-camber, east side up
	if _in(x, z, 108, 132, 58, 86):
		var camber := tan(deg_to_rad(14.0)) * clampf(x - 112.0, 0.0, 16.0)
		camber *= 1.0 - smoothstep(128.0, 132.0, x)
		h += camber * smoothstep(58.0, 61.0, z) * (1.0 - smoothstep(83.0, 86.0, z))
	# [6] flex humps: under one wheel, then under the other
	if _in(x, z, 112, 128, 92, 120):
		for k in range(4):
			var zk := 96.0 + 5.2 * k
			for hump: Vector2 in [Vector2(119.0, zk), Vector2(121.0, zk + 2.6)]:
				var d := Vector2(x, z).distance_to(hump) / 1.5
				if d < 1.0:
					h += 0.5 * (0.5 + 0.5 * cos(PI * d))
	# [8] wading pool: in at the south end, deepest in the middle, out at the north
	var x0: float = POOL["x0"]
	var x1: float = POOL["x1"]
	if x > x0 - 3.0 and x < x1 + 3.0:
		var across := 1.0 - smoothstep(0.0, 3.0, maxf(x0 - x, x - x1))
		h -= pool_depth(z) * across
	# [7] mud pit: a shallow dish
	var dp := Vector2(x, z).distance_to(PIT["c"]) / float(PIT["r"])
	if dp < 1.0:
		h -= 0.35 * (1.0 - dp * dp)
	# [10] hill lanes up to the bank top along the north side
	if z > HILL_Z - 2.0:
		var near: Array = HILLS[0]
		for hl: Array in HILLS:
			if absf(x - float(hl[0])) < absf(x - float(near[0])):
				near = hl
		# the lane at its grade; between lanes the bank is steeper still
		var g := lerpf(float(near[1]), 62.0, smoothstep(5.0, 9.0, absf(x - float(near[0]))))
		h += minf(HILL_TOP, tan(deg_to_rad(g)) * maxf(0.0, z - HILL_Z))
	return h


## Soft ground: Vector4(mud thickness, wetness, rut, grip), as Terrain wants it.
static func soil(x: float, z: float, patchy: float) -> Vector4:
	# the field: short grass on firm, thin soil
	var m := Vector4(0.03, 0.2, 0.0, 1.0)
	if _road(x, z) > 0.0:
		m = Vector4(0.04, 0.15, 0.0, 1.0)   # packed gravel
	if bedrock(x, z) > 0.5:
		m = Vector4(0.0, 0.1, 0.0, 1.1)     # bare rock: counts as rock for grip and damage
	var dp := Vector2(x, z).distance_to(PIT["c"]) / float(PIT["r"])
	if dp < 1.1:
		var k := 1.0 - smoothstep(0.0, 1.1, dp)
		# (wet enough in the middle that it's soup whatever the season)
		m = Vector4(0.05 + 0.6 * k * (0.85 + 0.3 * patchy), minf(1.0, 0.5 + 0.8 * k), 0.0, 1.0)
	return m


## Where the ground is bare rock (the shader's bedrock, and grip).
static func bedrock(x: float, z: float) -> float:
	if _in(x, z, 40, 46, 29, 52):
		return 1.0   # the rock half of the bump strip
	if _in(x, z, 34, 46, 61, 80):
		return 1.0   # the ledges
	if _in(x, z, 108, 132, 58, 86):
		return 0.8   # the squeeze
	return 0.0


## The gravel road: 1 on it.
static func _road(x: float, z: float) -> float:
	if z > ROAD_Z.x and z < ROAD_Z.y and x > 16.0 and x < 144.0:
		return 1.0
	if x > SPINE_X.x and x < SPINE_X.y and z > 2.0 and z < 50.0:
		return 1.0
	return 0.0


## Boulders: Vector4(x, centre y offset from the ground, z, radius); the
## terrain sets them on its own ground. ROCK_TOP: the rock mesh stands two
## thirds of its radius over its centre.
static func rocks() -> Array[Vector4]:
	var out: Array[Vector4] = []
	var top := 0.67
	# [3] straddle line: (height over the ground, radius)
	for r: Array in [[34.0, 0.45], [41.0, 0.6], [48.0, 0.75]]:
		var hgt: float = r[1]
		var rad := hgt * 1.05
		out.append(Vector4(120.0, hgt - top * rad, float(r[0]), rad))
	# [4] squeeze: boulders on the low side of the camber, a few up the high side
	for b: Array in [[64.0, -1.0, 1.0], [70.0, 1.0, 0.9], [76.0, -1.0, 1.1], [81.0, 1.0, 0.85]]:
		var rad: float = b[2]
		out.append(Vector4(120.0 + float(b[1]) * (1.2 + rad), 0.05, float(b[0]), rad))
	# [9] the winch rock, and a second to try a redirect off
	out.append(Vector4(80.0, 0.1, 128.0, 1.5))
	out.append(Vector4(92.0, 0.1, 126.0, 1.1))
	return out


## How deep the pool's bed is below the field at `z` (its middle, across).
static func pool_depth(z: float) -> float:
	var down := smoothstep(float(POOL["z_in"]), float(POOL["z_deep"]), z) \
		* (1.0 - smoothstep(float(POOL["z_deep"]) + 2.0, float(POOL["z_out"]), z))
	return float(POOL["depth"]) * down


## Depth posts along the wading pool's east edge: (x, z, water depth there).
static func pool_posts() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var level: float = POOL["level"]
	for d: float in [0.3, 0.6, 0.9, 1.2, 1.5]:
		var z: float = POOL["z_in"]
		while z < float(POOL["z_deep"]) and pool_depth(z) + level < d:
			z += 0.05
		out.append(Vector3(float(POOL["x1"]) - 0.6, z, d))
	return out


## Which station (x, z) is at or nearest, as an index into STATIONS.
static func station_at(x: float, z: float) -> int:
	var best := 0
	var best_d := INF
	for i in STATIONS.size():
		var r: Rect2 = STATIONS[i][3]
		var c := r.get_center()
		var d := Vector2(x, z).distance_to(c) - 0.5 * minf(r.size.x, r.size.y)
		if r.has_point(Vector2(x, z)):
			d = -1.0
		if d < best_d:
			best_d = d
			best = i
	return best


static func _in(x: float, z: float, x0: float, z0: float, x1: float, z1: float) -> bool:
	return x >= x0 and x <= x1 and z >= z0 and z <= z1


## 1 across a lane, easing off at its edges (so a raised lane has banks).
static func _lane(x: float, x0: float, x1: float) -> float:
	return smoothstep(x0, x0 + 1.5, x) * (1.0 - smoothstep(x1 - 1.5, x1, x))
