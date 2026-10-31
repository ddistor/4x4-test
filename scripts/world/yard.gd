class_name Yard
extends RefCounted
## Bakuran trail park: the club's practice ground outside Morong, laid out as
## a real park trail rather than an open lot. A clay two-track loops
## anticlockwise round a wooded hill (160 x 320 m, two terrain tiles), crosses
## a creek twice, and has each thing you can buy or tune for as an obstacle on
## the trail itself, with an easy bypass beside it for whoever doesn't want it.
##
##                N (+z)
##        [5] flex humps on the open hilltop
##   [6] side slope           [4] hill climb (a washed-out chute)
##   [7] mud hole + winch rock
##   ~~[8] deep crossing~~~~~~~~~~~[3] creek ford~~~~~  the creek, flowing east
##   [9] rock squeeze               [2] ledges
##   [10] straddle line  meadow     [1] bump strip
##            * trailhead (spawn), heading east
##
## The terrain asks this file what's where (heights, soil, rock, woods,
## stones, trees); the layout is fixed, so the park is also a repeatable
## test bed. Every lookup works in a track's own (along, across) coordinates:
## the loop is one track, each bypass another.

const SIZE := 160.0          # across (x)
const LENGTH := 320.0        # along (z)
const REACH := 14.0          # how far from a track its lookup grid reaches
const HALF := 2.1            # the tread's half width
const BANK := 3.2            # its cut and fill banks, out to the natural ground

## the loop's control points (x, z), anticlockwise seen from above
const LOOP := [Vector2(80, 16), Vector2(108, 22), Vector2(128, 38), Vector2(136, 62), Vector2(134, 92),
	Vector2(126, 120), Vector2(122, 146), Vector2(126, 172), Vector2(136, 200), Vector2(130, 232),
	Vector2(112, 258), Vector2(90, 272), Vector2(64, 266), Vector2(44, 248), Vector2(32, 220),
	Vector2(30, 192), Vector2(36, 168), Vector2(40, 148), Vector2(36, 124), Vector2(28, 98),
	Vector2(28, 70), Vector2(40, 44), Vector2(58, 24)]

## the creek: Terrain's crossing, wandering across the park (mid z = zc +
## amp sin(x freq + phase)); 1.4 m deep in its runs, shallow at the riffles
const CREEK := {"zc": 152.0, "amp": 9.0, "freq": 0.05, "phase": 0.0, "half_w": 4.0, "bank": 5.0,
	"drop": 1.6, "depth": 1.2, "pool": 1.4}
## the hill: centre (x, z), radius, height
const HILL := Vector3(88.0, 262.0, 80.0)
const HILL_H := 13.0
## the open meadow inside the loop (for driving circles), and the trailhead
const MEADOW := Vector2(84.0, 76.0)
const LOT := Vector2(80.0, 16.0)

## [name, what it tests, near (x, z), length along the trail, lane half
## width, bypass side (+1 inside the loop, -1 outside, 0 none), bypass
## offset, kind]
const OBSTACLES := [
	["Bump strip", "humps of 5 to 30 cm: clay on the left, rock on the right", Vector2(134, 50), 24.0, 3.5, 1, 10.0, "bumps"],
	["Ledges", "steps of 20, 40 and 60 cm onto bare rock, then a ramp down", Vector2(135, 80), 26.0, 3.5, 1, 10.0, "ledges"],
	["Creek ford", "the creek at its riffle: knee-deep over stones, a current", Vector2(123, 146), 18.0, 3.0, 0, 0.0, "ford"],
	["Hill climb", "a washed-out chute up the hill, steepening to rock: the bypass winds round", Vector2(132, 222), 38.0, 3.2, 1, 12.0, "climb"],
	["Flex humps", "humps under one wheel then the other: flex and lockers", Vector2(84, 271), 24.0, 3.5, 1, 10.0, "flex"],
	["Side slope", "a sidehill that leans from 5 to 35 deg: where does it tip?", Vector2(38, 236), 28.0, 4.5, -1, 11.0, "tilt"],
	["Mud hole", "soup in a hollow under the trees: air down, tread, the winch rock past it", Vector2(30, 194), 26.0, 4.0, 1, 10.0, "mud"],
	["Deep crossing", "the creek's deep run, to 1.4 m: the posts mark 0.3 m steps; the ford's beside", Vector2(39, 152), 18.0, 3.0, 1, 11.0, "deep"],
	["Rock squeeze", "an off-camber with boulders on the low side: sills and tie rods", Vector2(29, 104), 26.0, 4.0, 1, 10.0, "squeeze"],
	["Straddle line", "rocks 0.45, 0.6 and 0.75 m tall on the centre line: belly and skids", Vector2(30, 74), 22.0, 3.0, 1, 9.0, "straddle"]]

static var _built := false
static var _noise: FastNoiseLite
## tracks: {pts, h (smoothed floor), loop, box, grid, gx0, gz0, gw, gh}
static var _tracks: Array[Dictionary] = []
## obstacles: {name, what, kind, sc (centre, along the loop), len, w, side, off, up, h0, h1, track}
static var _obs: Array[Dictionary] = []
static var _stations: Array[Dictionary] = []


# --- building the layout ------------------------------------------------------------

static func _setup() -> void:
	if _built:
		return
	_built = true
	_noise = FastNoiseLite.new()
	_noise.seed = 4242
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.02
	_noise.fractal_octaves = 3
	_tracks.append(_make_track(_spline(LOOP), true))
	var main: Dictionary = _tracks[0]
	var n: int = (main["pts"] as PackedVector2Array).size()
	for o: Array in OBSTACLES:
		var near: Vector2 = o[2]
		var sc := _local(main, near.x, near.y).x
		var half := float(o[3]) * 0.5
		var ob := {"name": o[0], "what": o[1], "sc": sc, "len": float(o[3]), "w": float(o[4]),
			"side": int(o[5]), "off": float(o[6]), "kind": o[7], "track": -1,
			"h0": _prof(main, sc - half), "h1": _prof(main, sc + half)}
		# which way the natural ground rises across the trail here (+1: to the left)
		var p := _at(main, sc)
		var nrm := _normal(main, sc)
		ob["up"] = 1.0 if _land(p.x + nrm.x * 6.0, p.y + nrm.y * 6.0) >= _land(p.x - nrm.x * 6.0, p.y - nrm.y * 6.0) else -1.0
		if int(o[5]) != 0:
			# the bypass: leaves the trail 14 m before, runs alongside, rejoins after
			var pts := PackedVector2Array()
			var s := sc - half - 16.0
			while s <= sc + half + 16.0:
				var u := s - (sc - half)
				var k := smoothstep(-16.0, -4.0, u) * (1.0 - smoothstep(float(o[3]) + 4.0, float(o[3]) + 16.0, u))
				pts.append(_at(main, s) + _normal(main, s) * float(o[5]) * float(o[6]) * k)
				s += 1.0
			_tracks.append(_make_track(pts, false))
			ob["track"] = _tracks.size() - 1
		_obs.append(ob)
	assert(n > 0)


## A closed Catmull-Rom spline through `ctrl`, resampled every metre.
static func _spline(ctrl: Array) -> PackedVector2Array:
	var dense := PackedVector2Array()
	var m := ctrl.size()
	for i in range(m):
		var p0: Vector2 = ctrl[(i - 1 + m) % m]
		var p1: Vector2 = ctrl[i]
		var p2: Vector2 = ctrl[(i + 1) % m]
		var p3: Vector2 = ctrl[(i + 2) % m]
		for k in range(40):
			var t := k / 40.0
			dense.append(0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
				+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t))
	dense.append(dense[0])
	var out := PackedVector2Array([dense[0]])
	var carry := 0.0
	for i in range(1, dense.size()):
		var a := dense[i - 1]
		var seg := a.distance_to(dense[i])
		var at := 1.0 - carry
		while at <= seg:
			out.append(a.lerp(dense[i], at / seg))
			at += 1.0
		carry = seg - (at - 1.0)
	if out[out.size() - 1].distance_to(out[0]) < 0.5:
		out.remove_at(out.size() - 1)
	return out


static func _make_track(pts: PackedVector2Array, loop: bool) -> Dictionary:
	var n := pts.size()
	# the tread follows the land, smoothed along it: benched into side slopes,
	# a gentle grade where the ground is lumpy
	var h := PackedFloat32Array()
	h.resize(n)
	for i in range(n):
		h[i] = _land(pts[i].x, pts[i].y)
	for pass_i in range(3):
		var sm := PackedFloat32Array()
		sm.resize(n)
		for i in range(n):
			var sum := 0.0
			var c := 0
			for j in range(i - 6, i + 7):
				var jj := posmod(j, n) if loop else clampi(j, 0, n - 1)
				sum += h[jj]
				c += 1
			sm[i] = sum / c
		h = sm
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	var gx0 := int(floor(lo.x - REACH))
	var gz0 := int(floor(lo.y - REACH))
	var gw := int(ceil(hi.x + REACH)) - gx0 + 1
	var gh := int(ceil(hi.y + REACH)) - gz0 + 1
	var grid := PackedInt32Array()
	grid.resize(gw * gh)
	grid.fill(-1)
	var best := PackedFloat32Array()
	best.resize(gw * gh)
	best.fill(REACH * REACH)
	var r := int(REACH)
	for i in range(n):
		var cx := int(floor(pts[i].x)) - gx0
		var cz := int(floor(pts[i].y)) - gz0
		for dz in range(-r, r + 1):
			var z := cz + dz
			if z < 0 or z >= gh:
				continue
			for dx in range(-r, r + 1):
				var x := cx + dx
				if x < 0 or x >= gw:
					continue
				var d2 := Vector2(x + gx0 + 0.5, z + gz0 + 0.5).distance_squared_to(pts[i])
				var k := z * gw + x
				if d2 < best[k]:
					best[k] = d2
					grid[k] = i
	return {"pts": pts, "h": h, "loop": loop, "grid": grid, "gx0": gx0, "gz0": gz0, "gw": gw, "gh": gh,
		"box": Rect2(lo, hi - lo).grow(REACH)}


# --- track lookups -------------------------------------------------------------------

## (along in metres, across: + to the left, distance) of (x, z) from track
## `t`; distance INF when it's out of the track's reach.
static func _local(t: Dictionary, x: float, z: float) -> Vector3:
	var gx := int(floor(x)) - int(t["gx0"])
	var gz := int(floor(z)) - int(t["gz0"])
	var gw: int = t["gw"]
	if gx < 0 or gz < 0 or gx >= gw or gz >= int(t["gh"]):
		return Vector3(0.0, 0.0, INF)
	var i: int = (t["grid"] as PackedInt32Array)[gz * gw + gx]
	if i < 0:
		return Vector3(0.0, 0.0, INF)
	var pts: PackedVector2Array = t["pts"]
	var n := pts.size()
	var loop: bool = t["loop"]
	var p := Vector2(x, z)
	var best := Vector3(0.0, 0.0, INF)
	for j in [i - 1, i]:
		var ia: int = j
		var ib: int = j + 1
		if loop:
			ia = posmod(ia, n)
			ib = posmod(ib, n)
		elif ia < 0 or ib >= n:
			continue
		var a := pts[ia]
		var ab := pts[ib] - a
		var tt := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		var q := a + ab * tt
		var d := p.distance_to(q)
		if d < best.z:
			var tn := ab.normalized()
			best = Vector3(float(j) + tt, (p - q).dot(Vector2(-tn.y, tn.x)), d)
	return best


static func _wrap_s(t: Dictionary, s: float) -> float:
	var n := float((t["pts"] as PackedVector2Array).size())
	return fposmod(s, n) if t["loop"] else clampf(s, 0.0, n - 1.001)


static func _at(t: Dictionary, s: float) -> Vector2:
	var pts: PackedVector2Array = t["pts"]
	var n := pts.size()
	s = _wrap_s(t, s)
	var i := int(s)
	return pts[i].lerp(pts[(i + 1) % n], s - i)


static func _tangent(t: Dictionary, s: float) -> Vector2:
	return (_at(t, s + 1.0) - _at(t, s - 1.0)).normalized()


## The left-hand normal: inside the loop.
static func _normal(t: Dictionary, s: float) -> Vector2:
	var tn := _tangent(t, s)
	return Vector2(-tn.y, tn.x)


static func _prof(t: Dictionary, s: float) -> float:
	var h: PackedFloat32Array = t["h"]
	var n := h.size()
	s = _wrap_s(t, s)
	var i := int(s)
	return lerpf(h[i], h[(i + 1) % n], s - i)


## Metres into obstacle `o`'s lane from its start, for a point `s` along the loop.
static func _along(o: Dictionary, s: float) -> float:
	var n := float((_tracks[0]["pts"] as PackedVector2Array).size())
	return wrapf(s - float(o["sc"]), -n * 0.5, n * 0.5) + float(o["len"]) * 0.5


## Distance to the nearest track (loop or bypass), and which.
static func _nearest(x: float, z: float) -> Vector2:
	var best := Vector2(INF, -1)
	for ti in _tracks.size():
		var t: Dictionary = _tracks[ti]
		if not (t["box"] as Rect2).has_point(Vector2(x, z)):
			continue
		var d := _local(t, x, z).z
		if d < best.x:
			best = Vector2(d, ti)
	return best


# --- the land -----------------------------------------------------------------------

static func creek_mid(x: float) -> float:
	return float(CREEK["zc"]) + float(CREEK["amp"]) * sin(x * float(CREEK["freq"]) + float(CREEK["phase"]))


## The natural ground, before the trail is cut into it.
static func _land(x: float, z: float) -> float:
	var near_creek := smoothstep(8.0, 30.0, absf(z - creek_mid(x)))
	var h := 1.2 * _noise.get_noise_2d(x, z) * near_creek
	var d := Vector2(x, z).distance_to(Vector2(HILL.x, HILL.y)) / HILL.z
	if d < 1.0:
		h += HILL_H * (1.0 - smoothstep(0.0, 1.0, d))
	# a bank all round, so the park is a park, not the edge of the world
	var edge := minf(minf(x, SIZE - x), minf(z, LENGTH - z))
	h += 4.0 * (1.0 - smoothstep(0.0, 10.0, edge))
	return h


## The ground height anywhere in the park (before soft ground goes on top;
## Terrain cuts the creek in after).
static func height(x: float, z: float, _n: FastNoiseLite = null) -> float:
	_setup()
	var land := _land(x, z)
	var wsum := 0.0
	var hsum := 0.0
	var wmax := 0.0
	var lm := Vector3(0.0, 0.0, INF)
	for ti in _tracks.size():
		var t: Dictionary = _tracks[ti]
		if not (t["box"] as Rect2).has_point(Vector2(x, z)):
			continue
		var l := _local(t, x, z)
		if ti == 0:
			lm = l
		if l.z > HALF + BANK:
			continue
		var w := 1.0 - smoothstep(HALF, HALF + BANK, l.z)
		wsum += w
		hsum += w * _prof(t, l.x)
		wmax = maxf(wmax, w)
	var h := land
	if wsum > 0.0:
		h = lerpf(land, hsum / wsum, wmax)
		# nothing on a real trail is flat: humps and wallows in the tread
		h += 0.06 * _noise.get_noise_2d(x * 9.0, z * 9.0) * wmax
	if lm.z < 12.0:
		h += _obstacle_height(lm)
	return h


static func _obstacle_height(l: Vector3) -> float:
	var h := 0.0
	for o in _obs:
		var u := _along(o, l.x)
		var L: float = o["len"]
		if u < -6.0 or u > L + 6.0:
			continue
		var w: float = o["w"]
		var lat := l.y
		var lane := 1.0 - smoothstep(w - 1.5, w, absf(lat))
		match o["kind"]:
			"bumps":
				# rounded humps across the lane
				for b: Vector2 in [Vector2(3, 0.05), Vector2(7, 0.1), Vector2(11, 0.15), Vector2(15, 0.2), Vector2(20, 0.3)]:
					var d := absf(u - b.x)
					if d < 0.6:
						h += b.y * 0.5 * (1.0 + cos(PI * d / 0.6)) * lane
			"ledges":
				# up 0.2, 0.4 and 0.6 m, benches between, then a ramp back down
				var rise := 0.0
				for st: Vector2 in [Vector2(5, 0.2), Vector2(11, 0.4), Vector2(17, 0.6)]:
					rise += st.y * smoothstep(st.x - 0.06, st.x + 0.06, u)
				rise *= 1.0 - smoothstep(20.0, 26.0, u)
				h += rise * lane
			"climb":
				# a chute washed into the hill: it holds low, then takes the whole
				# rise at once (the bypass beside it climbs the hill's own grade)
				var f := smoothstep(0.68, 1.0, clampf(u / L, 0.0, 1.0))
				var chute := lerpf(float(o["h0"]), float(o["h1"]), f)
				var fade := smoothstep(-6.0, 0.0, u) * (1.0 - smoothstep(L, L + 6.0, u))
				h += (chute - _prof(_tracks[0], l.x)) * fade * (1.0 - smoothstep(w - 0.5, w + 2.5, absf(lat)))
			"flex":
				var k := 0
				var zk := 3.0
				while zk < L - 3.0:
					var side := 0.85 if k % 2 == 0 else -0.85
					var d := Vector2(u - zk, lat - side).length() / 1.5
					if d < 1.0:
						h += 0.5 * (0.5 + 0.5 * cos(PI * d))
					zk += 2.6
					k += 1
			"tilt":
				# a sidehill that leans more and more, the high side the hill's
				var a := deg_to_rad(lerpf(5.0, 35.0, clampf((u - 2.0) / (L - 8.0), 0.0, 1.0)))
				var fade := smoothstep(-4.0, 0.0, u) * (1.0 - smoothstep(L, L + 5.0, u))
				h += tan(a) * lat * float(o["up"]) * fade * (1.0 - smoothstep(w - 1.0, w + 2.0, absf(lat)))
			"squeeze":
				var fade := smoothstep(-3.0, 1.0, u) * (1.0 - smoothstep(L - 1.0, L + 3.0, u))
				h += tan(deg_to_rad(14.0)) * lat * float(o["up"]) * fade * (1.0 - smoothstep(w - 1.0, w + 2.0, absf(lat)))
			"mud":
				# a dished hollow where every rig has dug
				var e := pow((u - L * 0.5) / (L * 0.5), 2.0) + pow(lat / w, 2.0)
				if e < 1.0:
					h -= 0.4 * (1.0 - e)
	return h


## Soft ground: Vector4(mud thickness, wetness, rut, grip), as Terrain wants it.
static func soil(x: float, z: float, patchy: float) -> Vector4:
	_setup()
	var f := forest(x, z)
	# the meadow: short grass on firm, thin soil; leaf litter and loam in the woods
	var m := Vector4(0.02, 0.2, 0.0, 1.0).lerp(Vector4(0.02, 0.38, 0.0, 1.0), f)
	var near := _nearest(x, z)
	if near.y >= 0.0 and near.x < HALF + 0.6:
		var t: Dictionary = _tracks[int(near.y)]
		var l := _local(t, x, z)
		var on := 1.0 - smoothstep(HALF - 0.5, HALF + 0.6, l.z)
		# the two-track's clay, churned in the wheel lines; on a climb the water
		# runs off and it's firmer, grittier clay
		var grade := absf(_prof(t, l.x + 1.5) - _prof(t, l.x - 1.5)) / 3.0
		var steep := smoothstep(0.08, 0.25, grade)
		var lines := exp(-pow((absf(l.y) - 0.8) / 0.3, 2.0))
		var thick := (0.08 + 0.14 * patchy + 0.06 * lines) * (1.0 - 0.6 * steep)
		var clay := Vector4(thick, (0.35 + 0.2 * patchy + 0.15 * lines) * (1.0 - 0.4 * steep),
			minf(thick, 0.06 * lines), 1.0 + 0.2 * steep)
		m = m.lerp(clay, on)
	# the trailhead: packed dirt and gravel
	var lot := 1.0 - smoothstep(10.0, 14.0, Vector2(x, z).distance_to(LOT))
	m = m.lerp(Vector4(0.04, 0.15, 0.0, 1.0), lot)
	var lm := _local(_tracks[0], x, z)
	if lm.z < 12.0:
		for o in _obs:
			var u := _along(o, lm.x)
			if u < -8.0 or u > float(o["len"]) + 8.0:
				continue
			if o["kind"] == "mud":
				var L: float = o["len"]
				var e := pow((u - L * 0.5) / (L * 0.5 + 3.0), 2.0) + pow(lm.y / (float(o["w"]) + 1.0), 2.0)
				if e < 1.0:
					# soup in the middle whatever the season, firmer at the rim
					var k := 1.0 - e
					m = Vector4(maxf(m.x, 0.05 + 0.62 * k * (0.85 + 0.3 * patchy)), maxf(m.y, minf(1.0, 0.55 + 0.8 * k)), 0.0, 1.0)
	if bedrock(x, z) > 0.5:
		m = Vector4(0.0, 0.1, 0.0, 1.1)     # bare rock: counts as rock for grip and damage
	return m


## Where the ground is bare rock (the shader's bedrock, and grip).
static func bedrock(x: float, z: float) -> float:
	_setup()
	var l := _local(_tracks[0], x, z)
	if l.z > 8.0:
		return 0.0
	for o in _obs:
		var u := _along(o, l.x)
		var L: float = o["len"]
		var w: float = o["w"]
		if u < -2.0 or u > L + 2.0 or absf(l.y) > w:
			continue
		match o["kind"]:
			"bumps":
				if l.y < -0.2 and u > 0.0 and u < L:
					return 1.0   # the rock half
			"ledges":
				if u > 3.0 and u < 21.0:
					return 1.0
			"climb":
				if u > L * 0.72 and u < L + 0.5:
					return 0.9   # the chute's washed down to rock where it's steepest
			"squeeze":
				return 0.8
	return 0.0


## 0 open meadow .. 1 under the trees.
static func forest(x: float, z: float) -> float:
	_setup()
	var f := smoothstep(-0.15, 0.25, _noise.get_noise_2d(x * 1.3 + 400.0, z * 1.3))
	# woods on the hill's flanks, an open top
	var hd := Vector2(x, z).distance_to(Vector2(HILL.x, HILL.y)) / HILL.z
	f = maxf(f, smoothstep(0.3, 0.45, hd) * (1.0 - smoothstep(0.9, 1.05, hd)))
	f *= smoothstep(0.22, 0.32, hd)
	# trees along the creek
	f = maxf(f, 1.0 - smoothstep(7.0, 16.0, absf(z - creek_mid(x))))
	# the meadow and the trailhead stay open
	f *= smoothstep(22.0, 34.0, Vector2(x, z).distance_to(MEADOW))
	f *= smoothstep(14.0, 22.0, Vector2(x, z).distance_to(LOT))
	f *= smoothstep(3.5, 7.0, _nearest(x, z).x)
	return f


## Distance to the nearest trail (REACH or more when far).
static func trail_dist(x: float, z: float) -> float:
	_setup()
	return minf(_nearest(x, z).x, REACH)


# --- what stands on it ----------------------------------------------------------------

static func _obs_point(o: Dictionary, u: float, lat: float) -> Vector2:
	var main: Dictionary = _tracks[0]
	var s := float(o["sc"]) - float(o["len"]) * 0.5 + u
	return _at(main, s) + _normal(main, s) * lat


static func _find(kind: String) -> Dictionary:
	_setup()
	for o in _obs:
		if o["kind"] == kind:
			return o
	return {}


## Boulders: Vector4(x, centre y offset from the ground, z, radius); the
## terrain sets them on its own ground. The rock mesh stands two thirds of
## its radius over its centre.
static func rocks() -> Array[Vector4]:
	_setup()
	var out: Array[Vector4] = []
	var top := 0.67
	# straddle line: (u, height over the ground)
	var sl := _find("straddle")
	for r: Vector2 in [Vector2(5, 0.45), Vector2(11, 0.6), Vector2(17, 0.75)]:
		var rad := r.y * 1.05
		var p := _obs_point(sl, r.x, 0.0)
		out.append(Vector4(p.x, r.y - top * rad, p.y, rad))
	# squeeze: boulders on the low side of the camber, a couple up the high side
	var sq := _find("squeeze")
	for b: Vector3 in [Vector3(6, -1, 1.0), Vector3(12, 1, 0.9), Vector3(18, -1, 1.1), Vector3(23, 1, 0.85)]:
		var p := _obs_point(sq, b.x, b.y * float(sq["up"]) * (1.2 + b.z))
		out.append(Vector4(p.x, 0.05, p.y, b.z))
	# the winch rock past the mud hole, on the far side from its bypass, and a
	# second to try a redirect off
	var mh := _find("mud")
	var away := -float(mh["side"])
	var w1 := _obs_point(mh, float(mh["len"]) + 4.0, away * 5.0)
	out.append(Vector4(w1.x, 0.1, w1.y, 1.5))
	var w2 := _obs_point(mh, float(mh["len"]) * 0.5, away * 7.5)
	out.append(Vector4(w2.x, 0.1, w2.y, 1.1))
	# stones along the creek and the odd boulder in the woods, off the trail
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + 9
	var tries := 0
	var stones := 0
	while stones < 70 and tries < 2000:
		tries += 1
		var x := rng.randf_range(12.0, SIZE - 12.0)
		var z := creek_mid(x) + rng.randf_range(-9.0, 9.0)
		if _nearest(x, z).x < 6.0:
			continue
		var r := 0.25 + pow(rng.randf(), 2.0) * 0.8
		out.append(Vector4(x, -0.35 * r, z, r))
		stones += 1
	tries = 0
	stones = 0
	while stones < 40 and tries < 2000:
		tries += 1
		var x := rng.randf_range(12.0, SIZE - 12.0)
		var z := rng.randf_range(12.0, LENGTH - 12.0)
		if forest(x, z) < 0.6 or _nearest(x, z).x < 6.0:
			continue
		var r := rng.randf_range(0.5, 1.3)
		out.append(Vector4(x, -0.35 * r, z, r))
		stones += 1
	return out


## Where trees stand: in the woods, some right at the trail's edge (winch
## anchors), a few lone ones out in the meadows.
static func tree_spots() -> Array[Vector3]:
	_setup()
	var out: Array[Vector3] = []   # x, z, scale
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + 3
	var z := 8.0
	while z < LENGTH - 6.0:
		var x := 8.0
		while x < SIZE - 6.0:
			var px := x + rng.randf_range(-2.2, 2.2)
			var pz := z + rng.randf_range(-2.2, 2.2)
			var f := forest(px, pz)
			var lone := rng.randf() < 0.012
			if (rng.randf() < 0.6 * f or lone) and _nearest(px, pz).x > 3.4 and bedrock(px, pz) < 0.5:
				out.append(Vector3(px, pz, rng.randf_range(0.75, 1.2)))
			x += 5.0
		z += 5.0
	# the mud hole has trees close on its far side, for the winch
	var mh := _find("mud")
	for u: float in [4.0, 13.0, 22.0]:
		var p := _obs_point(mh, u, -float(mh["side"]) * 6.5)
		out.append(Vector3(p.x, p.y, 1.0))
	return out


## The creek's riffles: Vector3(x, width, water depth there). One where the
## loop fords it, one where the deep crossing's bypass does.
static func fords() -> Array[Vector3]:
	_setup()
	var out: Array[Vector3] = []
	var ford := _find("ford")
	out.append(Vector3(_crossing_x(_tracks[0], float(ford["sc"]) - 20.0, float(ford["sc"]) + 20.0), 4.0, 0.35))
	var deep := _find("deep")
	var bt: Dictionary = _tracks[int(deep["track"])]
	out.append(Vector3(_crossing_x(bt, 0.0, float((bt["pts"] as PackedVector2Array).size() - 1)), 3.5, 0.45))
	return out


static func _crossing_x(t: Dictionary, s0: float, s1: float) -> float:
	var s := s0
	var prev := 0.0
	while s <= s1:
		var p := _at(t, s)
		var side := p.y - creek_mid(p.x)
		if s > s0 and signf(side) != signf(prev):
			return p.x
		prev = side
		s += 0.25
	return _at(t, (s0 + s1) * 0.5).x


## Along the deep crossing's centre line: [point, the left normal] every 0.25 m
## (Terrain puts the depth posts where the water reaches each 0.3 m).
static func deep_line() -> Array:
	var o := _find("deep")
	var out := []
	var u := -6.0
	while u < float(o["len"]) * 0.5 + 1.0:
		var s := float(o["sc"]) - float(o["len"]) * 0.5 + u
		out.append([_at(_tracks[0], s), _normal(_tracks[0], s)])
		u += 0.25
	return out


## Which side of the deep crossing the posts go (away from its bypass).
static func post_side() -> float:
	return -float(_find("deep")["side"])


# --- stations, spawn, recovery ------------------------------------------------------

## The obstacles as stations: name, what it tests, where to start (10 m
## before it, on the loop), the heading there, and a sign post.
static func stations() -> Array[Dictionary]:
	_setup()
	if not _stations.is_empty():
		return _stations
	var out: Array[Dictionary] = _stations
	for o in _obs:
		var s := float(o["sc"]) - float(o["len"]) * 0.5 - 10.0
		var tn := _tangent(_tracks[0], s)
		var side := -float(o["side"]) if int(o["side"]) != 0 else 1.0
		out.append({"name": o["name"], "what": o["what"], "at": _at(_tracks[0], s), "heading": Vector3(tn.x, 0.0, tn.y),
			"sign": _at(_tracks[0], s + 4.0) + _normal(_tracks[0], s + 4.0) * side * 3.8})
	return out


## Where the rig starts: the trailhead, heading off round the loop.
static func spawn() -> Dictionary:
	_setup()
	var tn := _tangent(_tracks[0], 0.0)
	return {"at": _at(_tracks[0], 0.0), "heading": Vector3(tn.x, 0.0, tn.y)}


## Which station (x, z) is at or coming up to, -1 out on the loop between them.
static func station_at(x: float, z: float) -> int:
	_setup()
	var near := _nearest(x, z)
	for i in _obs.size():
		if int(_obs[i]["track"]) == int(near.y) and near.x < 6.0:
			return i   # on its bypass
	var l := _local(_tracks[0], x, z)
	if l.z > 15.0:
		return -1
	for i in _obs.size():
		var u := _along(_obs[i], l.x)
		if u > -12.0 and u < float(_obs[i]["len"]) + 4.0:
			return i
	return -1


## The marshal's recovery: back on whichever track is nearest, `back` metres
## behind, facing along it.
static func recover_point(x: float, z: float, back: float) -> Dictionary:
	_setup()
	var near := _nearest(x, z)
	var t: Dictionary = _tracks[maxi(int(near.y), 0)]
	var s := _local(t, x, z).x - back
	if near.y < 0.0:
		s = _local(_tracks[0], x, z).x
	var tn := _tangent(t, s)
	return {"at": _at(t, s), "heading": Vector3(tn.x, 0.0, tn.y)}


## A point on the loop `ahead` metres on from where (x, z) is: for a bot
## (or a camera) to follow the trail.
static func ahead_on_loop(x: float, z: float, ahead: float) -> Vector2:
	_setup()
	var l := _local(_tracks[0], x, z)
	return _at(_tracks[0], l.x + ahead)


## How far round the loop (x, z) is, in metres from the trailhead; the loop's length.
static func loop_s(x: float, z: float) -> float:
	_setup()
	return _local(_tracks[0], x, z).x


static func loop_length() -> float:
	_setup()
	return float((_tracks[0]["pts"] as PackedVector2Array).size())
