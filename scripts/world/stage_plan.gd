class_name StagePlan
extends RefCounted
## One stage: the trail as a chain of Philippine offroad sections, picked,
## ordered and sized from a seed. Same seed, same stage; every new seed is a
## different run. Cheap to build, so the start menu can preview a seed.
##
## The trail always starts on the barangay road by the paddies. After that
## come six sections (always a river crossing and a stretch of kanal ruts),
## then a short clearing with the finish.

const KINDS := {
	# kind: name, where it's typical, length range (m), height gained (m),
	#       how far the trail wanders side to side (m), how often (rad/m),
	#       steep pitches the climb is packed into [count, grade range]
	"paddy": {"name": "Barangay road", "place": "Morong, Rizal", "len": Vector2(90, 105), "rise": Vector2(0, 0), "wander": 6.0, "freq": 0.03, "pitch": [0, Vector2.ZERO]},
	"clay": {"name": "Laterite climb", "place": "Baras, Rizal", "len": Vector2(130, 170), "rise": Vector2(14, 24), "wander": 12.0, "freq": 0.035, "pitch": [2, Vector2(0.42, 0.62)]},
	"kanal": {"name": "Kanal ruts", "place": "Tanay, Rizal", "len": Vector2(110, 140), "rise": Vector2(6, 11), "wander": 7.0, "freq": 0.03, "pitch": [1, Vector2(0.32, 0.45)]},
	"river": {"name": "Boulder river", "place": "Daraitan, Tanay", "len": Vector2(110, 130), "rise": Vector2(-3, 2), "wander": 4.0, "freq": 0.02, "pitch": [0, Vector2.ZERO]},
	"lahar": {"name": "Lahar wash", "place": "Porac, Pampanga", "len": Vector2(130, 160), "rise": Vector2(-9, -5), "wander": 16.0, "freq": 0.022, "pitch": [1, Vector2(0.45, 0.6)]},
	"rocky": {"name": "Rock steps", "place": "Kayapa, Nueva Vizcaya", "len": Vector2(120, 150), "rise": Vector2(18, 28), "wander": 11.0, "freq": 0.05, "pitch": [2, Vector2(0.5, 0.7)]},
	"gully": {"name": "Rock gully", "place": "Wawa, Montalban", "len": Vector2(110, 140), "rise": Vector2(6, 11), "wander": 6.0, "freq": 0.04, "pitch": [1, Vector2(0.25, 0.38)], "jitter": 0.25},
	"bog": {"name": "Logging-road bog", "place": "General Nakar, Quezon", "len": Vector2(100, 130), "rise": Vector2(0, 0), "wander": 5.0, "freq": 0.03, "pitch": [0, Vector2.ZERO]},
	"cogon": {"name": "Cogon hills", "place": "San Felipe, Zambales", "len": Vector2(120, 150), "rise": Vector2(-6, 9), "wander": 12.0, "freq": 0.03, "pitch": [1, Vector2(0.38, 0.52)]},
	"niyog": {"name": "Niyogan farm road", "place": "Lucban, Quezon", "len": Vector2(100, 125), "rise": Vector2(-5, 6), "wander": 10.0, "freq": 0.03, "pitch": [1, Vector2(0.3, 0.42)]},
	"pasture": {"name": "Pastulan two-track", "place": "Sampaloc, Tanay", "len": Vector2(110, 140), "rise": Vector2(-4, 10), "wander": 13.0, "freq": 0.028, "pitch": [1, Vector2(0.22, 0.32)]},
	"ridge": {"name": "Talahib ridge", "place": "Mt. Balagbag, Rodriguez", "len": Vector2(120, 150), "rise": Vector2(8, 16), "wander": 7.0, "freq": 0.025, "pitch": [1, Vector2(0.28, 0.38)]},
	"sukal": {"name": "Overgrown trail", "place": "Real, Quezon", "len": Vector2(100, 130), "rise": Vector2(4, 10), "wander": 9.0, "freq": 0.04, "pitch": [1, Vector2(0.22, 0.32)], "jitter": 0.5},
	"end": {"name": "Finish clearing", "place": "", "len": Vector2(35, 35), "rise": Vector2(0, 0), "wander": 4.0, "freq": 0.03, "pitch": [0, Vector2.ZERO]},
	# the practice park (yard.gd): a loop trail round a hill
	"yard": {"name": "Bakuran trail park", "place": "Morong, Rizal", "len": Vector2(320, 320), "rise": Vector2(0, 0), "wander": 0.0, "freq": 0.0, "pitch": [0, Vector2.ZERO], "jitter": 0.0},
}

## Where a river or creek crosses the trail (fraction along the section), and
## how often a laterite climb has a creek in it.
const CROSSING := {"river": Vector2(0.42, 0.58), "lahar": Vector2(0.35, 0.65), "clay": Vector2(0.1, 0.22)}
const CLAY_CREEK_CHANCE := 0.6

## Trail difficulty: scales how much each section climbs, how steep its
## pitches are and how deep its ruts, holes and water get.
const DIFFICULTY := {0: ["Moderate", 0.65], 1: ["Hard", 1.0], 2: ["Extreme", 1.3]}

## Sections meet over this many metres either side of the join.
const BLEND := 18.0
const TILE := 160.0

var seed_value: int
## Array of {kind, z0, z1, h0, h1, wet, phase, cross_t, pitches: [[z centre, length, share of the rise]]}
var sections: Array[Dictionary] = []
var length := 0.0
## 0 dry season (firm, pale, cracked clay) .. 1 rainy season (slick soup)
var rain := 0.5
var finish_z := 0.0
## key into DIFFICULTY, and its multiplier
var level := 1
var difficulty := 1.0
## the practice park: its own loop trail (Yard), no finish
var yard := false


## The practice park (Yard): one section, two terrain tiles, between rains.
static func practice_yard() -> StagePlan:
	var plan := StagePlan.new()
	plan.seed_value = 4242
	plan.yard = true
	plan.rain = 0.45
	plan.sections.append({"kind": "yard", "z0": 0.0, "z1": Yard.LENGTH, "h0": 0.0, "h1": 0.0, "wet": 0.45,
		"phase": 0.0, "cross_t": -1.0, "pitches": []})
	plan.length = Yard.LENGTH
	plan.finish_z = INF
	return plan


## `weather`: -1 let the seed decide, 0 dry season, 1 rainy season.
## `level`: key into DIFFICULTY. `must`: section kinds the stage has to have
## (a career event's own trail), drawn first; none, and it's the seed's alone.
static func generate(p_seed: int, weather := -1, level := 1, must: Array = []) -> StagePlan:
	var plan := StagePlan.new()
	plan.seed_value = p_seed
	plan.level = level
	plan.difficulty = DIFFICULTY[level][1]
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	plan.rain = rng.randf()
	if weather == 0:
		plan.rain *= 0.25
	elif weather == 1:
		plan.rain = 0.72 + plan.rain * 0.28
	var kinds: Array[String] = ["river", "kanal"]
	var pool: Array[String] = ["clay", "lahar", "rocky", "gully", "bog", "cogon", "niyog", "pasture", "ridge", "sukal"]
	for k: String in must:
		if pool.has(k) and kinds.size() < 6:
			pool.erase(k)
			kinds.append(k)
	while kinds.size() < 6:
		kinds.append(pool.pop_at(rng.randi() % pool.size()))
	# shuffle, then nudge the river away from the very first slot so the
	# paddy road leads into something to climb first most of the time
	for i in range(kinds.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp := kinds[i]
		kinds[i] = kinds[j]
		kinds[j] = tmp
	if kinds[0] == "river" and rng.randf() < 0.7:
		kinds[0] = kinds[1]
		kinds[1] = "river"
	kinds.push_front("paddy")
	kinds.append("end")

	# lengths first: the terrain is built in TILE-long collider tiles, so the
	# slack to the next whole tile is shared out among the middle sections
	# (never one long empty stretch at the end)
	var lens: Array[float] = []
	var total := 0.0
	var middle := 0.0
	for i in range(kinds.size()):
		var lr: Vector2 = KINDS[kinds[i]]["len"]
		lens.append(roundf(rng.randf_range(lr.x, lr.y)))
		total += lens[i]
		if i > 0 and i < kinds.size() - 1:
			middle += lens[i]
	var stretch := 1.0 + (ceilf(total / TILE) * TILE - total) / middle
	for i in range(1, kinds.size() - 1):
		lens[i] *= stretch

	var z := 0.0
	var h := 0.0
	for i in range(kinds.size()):
		var k := kinds[i]
		var spec: Dictionary = KINDS[k]
		var rr: Vector2 = spec["rise"]
		var l := lens[i]
		var rise := rng.randf_range(rr.x, rr.y) * plan.difficulty
		var s := {
			"kind": k, "z0": z, "z1": z + l, "h0": h, "h1": h + rise,
			"wet": clampf(plan.rain + rng.randf_range(-0.25, 0.25), 0.0, 1.0),  # how much rain this stretch had
			"phase": rng.randf_range(0.0, TAU),
			"cross_t": -1.0,
			"pitches": [],
		}
		if CROSSING.has(k) and (k != "clay" or rng.randf() < CLAY_CREEK_CHANCE):
			var cr: Vector2 = CROSSING[k]
			s["cross_t"] = rng.randf_range(cr.x, cr.y)
		# Pack most of the climb into short steep pitches. A pitch's steepest
		# point is 1.5x its average (smoothstep), so size it from the grade.
		var pitch: Array = spec["pitch"]
		var count: int = pitch[0]
		if count > 0 and absf(rise) > 0.5:
			var share := 0.75 / count
			var grades: Vector2 = pitch[1]
			var lo := 0.15
			for p in range(count):
				var grade := minf(rng.randf_range(grades.x, grades.y) * plan.difficulty, 0.85)
				var plen := maxf(1.5 * share * absf(rise) / grade, 6.0)
				var span := plen / l
				var t := rng.randf_range(lo + span * 0.5, lerpf(lo + span * 0.5, 0.85 - span * 0.5, 1.0 / (count - p)))
				var cross_t: float = s["cross_t"]
				if cross_t >= 0.0 and absf(t - cross_t) * l < plen * 0.5 + 45.0:
					t = minf(cross_t + (plen * 0.5 + 45.0) / l, 0.85 - span * 0.5)
				(s["pitches"] as Array).append([z + t * l, plen, share])
				lo = t + span * 0.5 + 0.05
		plan.sections.append(s)
		z += l
		h += rise
	plan.length = ceilf(z / TILE - 0.001) * TILE
	var last := plan.sections[plan.sections.size() - 1]
	last["z1"] = plan.length
	plan.finish_z = float(last["z0"]) + 15.0
	return plan


func index_at(z: float) -> int:
	for i in range(sections.size()):
		if z < sections[i]["z1"]:
			return i
	return sections.size() - 1


func section_at(z: float) -> Dictionary:
	return sections[index_at(z)]


## Which two sections shape the ground at `z`, and how much of the second.
## Returns [index_a, index_b, weight_b]; weight is 0.5 right on a join and
## falls to 0 BLEND metres either side.
func blend_at(z: float) -> Array:
	var i := index_at(z)
	var s := sections[i]
	var d0: float = z - s["z0"]
	var d1: float = s["z1"] - z
	if d0 < BLEND and i > 0:
		return [i, i - 1, 0.5 * (1.0 - smoothstep(0.0, BLEND, d0))]
	if d1 < BLEND and i < sections.size() - 1:
		return [i, i + 1, 0.5 * (1.0 - smoothstep(0.0, BLEND, d1))]
	return [i, i, 0.0]


## Trail floor height along the stage. Continuous across joins: each section
## runs from its h0 to its h1 and its own features fade out at the ends. Most
## of the height comes in the section's steep pitches; the rest is spread out.
func profile(z: float) -> float:
	var s := section_at(z)
	var z0: float = s["z0"]
	var z1: float = s["z1"]
	var t := clampf((z - z0) / (z1 - z0), 0.0, 1.0)
	var h0: float = s["h0"]
	var h1: float = s["h1"]
	var window := sin(PI * t)
	var pitches: Array = s["pitches"]
	var spread := 1.0
	var shape := 0.0
	for p: Array in pitches:
		var half: float = p[1] * 0.5
		shape += float(p[2]) * smoothstep(float(p[0]) - half, float(p[0]) + half, z)
		spread -= float(p[2])
	shape += spread * smoothstep(0.0, 1.0, t)
	var h := lerpf(h0, h1, shape)
	match s["kind"]:
		"rocky":
			# ledges: a sharp step up every few metres with a bench behind it,
			# the climb unchanged on average
			var u := fposmod(z + float(s["phase"]) * 3.0, 5.5) / 5.5
			h += 0.7 * difficulty * (smoothstep(0.78, 1.0, u) - u + 0.39) * window
		"cogon", "niyog", "lahar", "pasture", "ridge":
			h += window * 1.6 * sin(z * 0.045 + float(s["phase"]))
	return h


func describe() -> String:
	var lines := PackedStringArray()
	var climb := 0.0
	var steepest := 0.0
	for s in sections:
		var rise: float = float(s["h1"]) - float(s["h0"])
		climb += maxf(rise, 0.0)
		for p: Array in s["pitches"]:
			steepest = maxf(steepest, 1.5 * float(p[2]) * absf(rise) / float(p[1]))
	lines.append(season())
	lines.append("%s trail: %d m of climbing, steepest pitch %d%%\n" % [DIFFICULTY[level][0], int(climb), int(steepest * 100.0)])
	for i in range(sections.size()):
		var s := sections[i]
		var spec: Dictionary = KINDS[s["kind"]]
		var place: String = spec["place"]
		lines.append("%d  %s%s   %d m" % [i + 1, spec["name"], ("  ·  " + place) if place != "" else "", int(s["z1"] - s["z0"])])
	return "\n".join(lines)


func season() -> String:
	if rain < 0.3:
		return "Dry season: firm, dusty clay, cracked where it dried"
	if rain < 0.65:
		return "Between rains: sticky clay, soft in the low spots"
	return "Rainy season: slick, deep, soupy mud everywhere"


static func display_name(s: Dictionary) -> String:
	var spec: Dictionary = KINDS[s["kind"]]
	return spec["name"] + (("  ·  " + spec["place"]) if spec["place"] != "" else "")
