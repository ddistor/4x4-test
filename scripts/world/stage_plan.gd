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
	#       how far the trail wanders side to side (m), how often (rad/m)
	"paddy": {"name": "Barangay road", "place": "Morong, Rizal", "len": Vector2(90, 105), "rise": Vector2(0, 0), "wander": 6.0, "freq": 0.03},
	"clay": {"name": "Laterite climb", "place": "Baras, Rizal", "len": Vector2(120, 160), "rise": Vector2(7, 12), "wander": 14.0, "freq": 0.035},
	"kanal": {"name": "Kanal ruts", "place": "Tanay, Rizal", "len": Vector2(110, 140), "rise": Vector2(2, 6), "wander": 7.0, "freq": 0.03},
	"river": {"name": "Boulder river", "place": "Daraitan, Tanay", "len": Vector2(110, 130), "rise": Vector2(-2, 1), "wander": 4.0, "freq": 0.02},
	"lahar": {"name": "Lahar wash", "place": "Porac, Pampanga", "len": Vector2(130, 160), "rise": Vector2(-5, -2), "wander": 16.0, "freq": 0.022},
	"rocky": {"name": "Rock steps", "place": "Kayapa, Nueva Vizcaya", "len": Vector2(120, 145), "rise": Vector2(10, 15), "wander": 12.0, "freq": 0.05},
	"bog": {"name": "Logging-road bog", "place": "General Nakar, Quezon", "len": Vector2(100, 130), "rise": Vector2(0, 0), "wander": 5.0, "freq": 0.03},
	"cogon": {"name": "Cogon hills", "place": "San Felipe, Zambales", "len": Vector2(120, 150), "rise": Vector2(-2, 4), "wander": 12.0, "freq": 0.03},
	"niyog": {"name": "Niyogan farm road", "place": "Lucban, Quezon", "len": Vector2(100, 125), "rise": Vector2(-3, 3), "wander": 10.0, "freq": 0.03},
	"end": {"name": "Finish clearing", "place": "", "len": Vector2(45, 45), "rise": Vector2(0, 0), "wander": 4.0, "freq": 0.03},
}

## Sections meet over this many metres either side of the join.
const BLEND := 18.0
const TILE := 160.0

var seed_value: int
## Array of {kind, z0, z1, h0, h1, wet, phase}
var sections: Array[Dictionary] = []
var length := 0.0
## 0 dry season (firm, pale, cracked clay) .. 1 rainy season (slick soup)
var rain := 0.5
var finish_z := 0.0


## `weather`: -1 let the seed decide, 0 dry season, 1 rainy season.
static func generate(p_seed: int, weather := -1) -> StagePlan:
	var plan := StagePlan.new()
	plan.seed_value = p_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	plan.rain = rng.randf()
	if weather == 0:
		plan.rain *= 0.25
	elif weather == 1:
		plan.rain = 0.72 + plan.rain * 0.28
	var kinds: Array[String] = ["river", "kanal"]
	var pool: Array[String] = ["clay", "lahar", "rocky", "bog", "cogon", "niyog"]
	for i in range(4):
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

	var z := 0.0
	var h := 0.0
	for k in kinds:
		var spec: Dictionary = KINDS[k]
		var lr: Vector2 = spec["len"]
		var rr: Vector2 = spec["rise"]
		var l := roundf(rng.randf_range(lr.x, lr.y))
		var rise := rng.randf_range(rr.x, rr.y)
		plan.sections.append({
			"kind": k, "z0": z, "z1": z + l, "h0": h, "h1": h + rise,
			"wet": clampf(plan.rain + rng.randf_range(-0.25, 0.25), 0.0, 1.0),  # how much rain this stretch had
			"phase": rng.randf_range(0.0, TAU),
		})
		z += l
		h += rise
	# the terrain is built in TILE-long collider tiles; the clearing takes up the slack
	var last := plan.sections[plan.sections.size() - 1]
	plan.length = ceilf(z / TILE) * TILE
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
## runs from its h0 to its h1 and its own features fade out at the ends.
func profile(z: float) -> float:
	var s := section_at(z)
	var z0: float = s["z0"]
	var z1: float = s["z1"]
	var t := clampf((z - z0) / (z1 - z0), 0.0, 1.0)
	var h0: float = s["h0"]
	var h1: float = s["h1"]
	var k: String = s["kind"]
	var window := sin(PI * t)
	match k:
		"rocky":
			# ledges: short steep steps with flatter benches between them
			var steps := 9.0
			var q := t * steps
			var stair := (floorf(q) + smoothstep(0.55, 1.0, fmod(q, 1.0))) / steps
			return lerpf(h0, h1, lerpf(smoothstep(0.0, 1.0, t), stair, window))
		"cogon", "niyog", "lahar":
			return lerpf(h0, h1, smoothstep(0.0, 1.0, t)) + window * 1.6 * sin(z * 0.045 + float(s["phase"]))
	return lerpf(h0, h1, smoothstep(0.0, 1.0, t))


func describe() -> String:
	var lines := PackedStringArray()
	lines.append(season() + "\n")
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
