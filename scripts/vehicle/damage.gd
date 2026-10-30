class_name Damage
extends RefCounted
## What breaks on the rig, and why (career mode; `--damage` in free play).
## Every part has a condition, 1 new .. 0 broken, carried from event to
## event until you pay for repairs in the garage. Each hit has a cause you
## can see, read off the body's contacts each physics step:
##   - belly on a rock: the oil pan and transfer case. Cracked, the engine
##     loses oil and runs hot; broken, low range is gone. Skid plates.
##   - a front tire slammed sideways into a rock: the tie rod bends and the
##     rig pulls to one side. Heavy-duty tie rods.
##   - a spinning tire that suddenly grips (worst with the lockers in, on a
##     steered front wheel): an axle shaft snaps, that axle stops driving
##     (with the diff open, both its wheels). Chromoly shafts.
##   - the sills on rocks, the roof in a rollover: body panels (money, and
##     the driver's pride). Rock sliders; a roll bar or cage.
##   - mud on the nose blocks the radiator: crawling hard in low range the
##     coolant climbs, the engine goes into limp and then quits. A river
##     washes the radiator.
##   - water over the intake while it's running: hydrolock. Dead until the
##     marshals (Backspace) pull the plugs and crank the water out, and the
##     engine is never quite the same. Snorkel.

## part -> [name, full repair cost in pesos]
const PARTS := {
	"underbody": ["Oil pan and transfer case", 40000],
	"steering": ["Tie rod", 8000],
	"shaft_f": ["Front axle shaft", 15000],
	"shaft_r": ["Rear axle shaft", 15000],
	"engine": ["Engine", 150000],
	"body": ["Body panels", 60000]}
const COOLANT_OK := 88.0
const COOLANT_HOT := 108.0
const COOLANT_MAX := 120.0

var rig: Rig
var enabled := false
var cond := {}
var coolant := COOLANT_OK
var hydrolocked := false
## overheated and quit: it won't start again until it's cooled to 105
var cooked := false
## the tie rod's bend pulls the steering this way (-1 left .. 1 right)
var pull := 0.0
var _slip_prev: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _sill := Vector2.ZERO
var _cool := {"belly": 0.0, "sill": 0.0, "roof": 0.0, "panel": 0.0, "tire": 0.0}
var _note := ""
var _note_t := 0.0


func setup(r: Rig, saved: Dictionary, on: bool) -> void:
	rig = r
	enabled = on
	for k: String in PARTS:
		cond[k] = clampf(float(saved.get(k, 1.0)), 0.0, 1.0)
	pull = float(saved.get("pull", 0.0))
	_sill = Armor.sill(rig)
	if enabled:
		rig.contact_monitor = true
		rig.max_contacts_reported = 16


## What goes in the save.
func to_dict() -> Dictionary:
	var d := cond.duplicate()
	d["pull"] = pull
	return d


## What putting it all right costs, from a saved condition dictionary.
static func repair_cost(saved: Dictionary) -> int:
	var total := 0.0
	for k: String in PARTS:
		total += (1.0 - clampf(float(saved.get(k, 1.0)), 0.0, 1.0)) * float(PARTS[k][1])
	return int(roundf(total / 100.0) * 100.0)


## The parts that need fixing, for the garage and the finish card.
static func summary(saved: Dictionary) -> String:
	var out := []
	for k: String in PARTS:
		var c := float(saved.get(k, 1.0))
		if c < 0.97:
			out.append("%s %s" % [PARTS[k][0].to_lower(), "broken" if c <= 0.0 else "%d%%" % roundi(c * 100.0)])
	return ", ".join(out)


func shaft_ok(front: bool) -> bool:
	return cond["shaft_f" if front else "shaft_r"] > 0.0


func low_range_ok() -> bool:
	return cond["underbody"] > 0.2


## What's left of the engine's torque: wear, and limp mode when it's hot.
func power() -> float:
	var p := 0.55 + 0.45 * float(cond["engine"])
	p *= 1.0 - 0.5 * clampf((coolant - COOLANT_HOT) / (COOLANT_MAX - COOLANT_HOT - 2.0), 0.0, 1.0)
	return p


## The bent tie rod's toe: added to the steering angle, rad.
func steer_offset() -> float:
	return (1.0 - float(cond["steering"])) * 0.12 * pull


func step(delta: float) -> void:
	_note_t = maxf(0.0, _note_t - delta)
	if not enabled:
		return
	_contacts(delta)
	_shafts()
	_heat(delta)
	# water over the intake with the engine turning: it draws water in
	var gb := rig.gearbox
	if rig.choke > 0.85 and gb.running and gb.rpm > gb.idle_rpm * 0.6:
		hydrolocked = true
		_hurt("engine", 0.35, "HYDROLOCKED: water in the engine (Backspace for the marshals)")
	if coolant >= COOLANT_MAX:
		cooked = true
	elif coolant < 105.0:
		cooked = false
	gb.seized = hydrolocked or cooked
	if gb.seized:
		gb.running = false


## The marshals put you back on the trail: they drain a hydrolocked engine
## and let a cooked one cool.
func on_recover() -> void:
	hydrolocked = false
	coolant = minf(coolant, 100.0)
	cooked = false


func _contacts(delta: float) -> void:
	var state := PhysicsServer3D.body_get_direct_state(rig.get_rid())
	if state == null:
		return
	var s := rig.spec
	var inv := rig.global_basis.inverse()
	var upside := rig.global_basis.y.y < 0.4
	for k: String in _cool:
		_cool[k] = maxf(0.0, _cool[k] - delta)
	# How hard each place was struck this step: the speed that point of the
	# rig was going into what it hit, for contacts that really push back.
	# Not the impulse itself: the solver also shoves overlapping bodies
	# apart, a spike that isn't a knock.
	var hit := {"belly": 0.0, "sill": 0.0, "roof": 0.0, "panel": 0.0, "tire": 0.0}
	var belly_force := 0.0
	var belly_rock := false
	var tire_x := 0.0
	for i in state.get_contact_count():
		var at := state.get_contact_local_position(i)
		var p := rig.to_local(at)
		var imp := state.get_contact_impulse(i)
		var push := clampf(imp.length() / rig.mass / 0.1, 0.0, 1.0)
		if push <= 0.0:
			continue
		var v_pt := rig.linear_velocity + rig.angular_velocity.cross(at - rig.global_position)
		# rock hits full; clay gives under you
		var hard := 1.0 if _hard(state.get_contact_collider_object(i), at) else 0.3
		var into := absf(v_pt.dot(imp.normalized())) * push * hard
		var at_front := absf(p.z - s.front_z) < s.tire_radius * 0.85
		var at_rear := absf(p.z - s.rear_z) < s.tire_radius * 0.85
		var zone := "panel"
		if (at_front or at_rear) and absf(p.x) > s.track - s.tire_width * 0.5 - 0.1 and p.y < s.ride_hub_y() + 0.25:
			# a tire's own solid: a sideways slam on a front one bends the tie rod
			if not at_front:
				continue
			zone = "tire"
			if hard < 1.0:
				continue   # a clay bank doesn't bend steering
			into = absf(v_pt.dot(rig.global_basis.x)) * push * absf((inv * imp).normalized().x)
			if into > hit["tire"]:
				tire_x = p.x
		elif p.y > s.seat.y + 0.45 and upside:
			zone = "roof"
		elif p.y < _sill.y + 0.12 and absf(p.x) < _sill.x - 0.15 and p.z > s.front_z - 0.1 and p.z < s.rear_z + 0.1:
			zone = "belly"
			belly_force += imp.length() / delta
			belly_rock = belly_rock or hard >= 1.0
		elif p.y < _sill.y + 0.4 and absf(p.x) >= _sill.x - 0.15:
			zone = "sill"
		hit[zone] = maxf(hit[zone], into)
	var speed := rig.linear_velocity.length()
	if OS.get_environment("DAMAGE_DEBUG") != "":
		for k: String in hit:
			if hit[k] > 0.8:
				print("HIT %s %.2f m/s (rig %.1f m/s)" % [k, hit[k], speed])
	if belly_force > 0.0:
		var plate := 0.08 if s.skid else 1.0
		# dragging the belly over rock wears through the pan (clay just polishes it)
		if belly_rock:
			_hurt("underbody", minf(speed, 3.0) * delta * 0.006 * plate, "")
		if s.skid and speed > 0.2:
			# smooth steel slides: push it on over the rock instead of hanging
			rig.apply_central_force(rig.linear_velocity.normalized() * minf(belly_force, rig.mass * 9.8) * 0.35)
	_knock("belly", hit["belly"], 1.0, 0.25 * (0.08 if s.skid else 1.0), "underbody", "" if s.skid else "BELLY ON THE ROCK")
	_knock("sill", hit["sill"], 1.5, 0.05 * (0.1 if s.sliders else 1.0), "body", "")
	_knock("roof", hit["roof"], 1.0, 0.2 * [1.0, 0.45, 0.15][s.cage], "body", "ROLLED IT" if s.cage == 0 else "")
	_knock("panel", hit["panel"], 2.5, 0.03, "body", "")
	# the tire model trips on a face it slides into before the tire's solid
	# gets there: that's the same slam
	for i in range(mini(2, rig.wheel_status.size())):
		var t: float = rig.wheel_status[i].get("trip_speed", 0.0)
		if t > hit["tire"]:
			hit["tire"] = t
			tire_x = rig.wheels[i].position.x
	if hit["tire"] > 1.5 and _cool["tire"] <= 0.0 and float(cond["steering"]) >= 1.0:
		# hit on the left tire, it toes in: the rig pulls right, and back
		pull = signf(tire_x)
	_knock("tire", hit["tire"], 1.5, 0.06 * (0.15 if s.hd_steering else 1.0), "steering", "TIE ROD BENT")


## Is what it hit rock: a boulder, or bare rock in the ground (the rock
## steps' ledges, a gully's floor)?
func _hard(what: Object, at: Vector3) -> bool:
	var n := what as Node
	if n and n.is_in_group("rock"):
		return true
	if n and n.is_in_group("boards"):
		return false
	if rig.terrain == null:
		return false
	return float(rig.terrain.ground_sample(at).get("grip", 1.0)) > 1.05


## One knock in a place counts once, however many steps it's in contact:
## `speed` m/s over `floor` costs `rate` of `part` per m/s.
func _knock(zone: String, speed: float, floor: float, rate: float, part: String, note: String) -> void:
	if speed <= floor or _cool[zone] > 0.0:
		return
	_cool[zone] = 0.3
	_hurt(part, (speed - floor) * rate, note)


## A tire that was spinning and suddenly bites shock-loads its axle shaft.
func _shafts() -> void:
	var s := rig.spec
	for i in range(rig.wheels.size()):
		var w := rig.wheels[i]
		var was := _slip_prev[i]
		_slip_prev[i] = w.slip
		if was < 0.55 or w.slip > 0.2 or not w.contact:
			continue
		var force := absf(rig.drive_per_wheel[i])
		if force < 3000.0:
			continue
		var front := i < 2
		var k := pow(force / 8000.0, 2.0) * (1.0 if rig.diff_locked else 0.3) * 0.12
		if front and absf(rig.steer) > 0.25:
			k *= 1.6   # a CV joint at full lock is the weak spot
		if s.chromoly:
			k *= 0.15
		var part := "shaft_f" if front else "shaft_r"
		var was_ok := shaft_ok(front)
		_hurt(part, k, "")
		if was_ok and not shaft_ok(front):
			_say("%s AXLE SHAFT SNAPPED" % ("FRONT" if front else "REAR"))


func _heat(delta: float) -> void:
	var gb := rig.gearbox
	# how blocked the radiator is: what the front tires threw on the nose,
	# and the cake on the body
	var block := clampf((rig.corner_mud[0] + rig.corner_mud[1]) * 0.2 + rig.cake * 0.3, 0.0, 0.75)
	# heat to shed: the power it's making, against the most it can make
	var work := 0.0
	if gb.running:
		work = maxf(0.0, gb.torque_out) * gb.rpm / (gb.torque_nm * gb.redline) + 0.05
	if cond["underbody"] < 0.5:
		work += 0.25 * (0.5 - float(cond["underbody"]))   # low on oil
	# the fan alone at a crawl, more with air through it at speed
	var airflow := 1.0 + 0.6 * minf(rig.speed_kmh / 25.0, 1.0)
	var capacity := airflow * (1.0 - 0.8 * block)
	if work > capacity * 0.9:
		coolant += (work - capacity * 0.9) * 0.4 * delta
	else:
		coolant = move_toward(coolant, COOLANT_OK, delta * (1.5 if gb.running else 0.6))
	coolant = clampf(coolant, COOLANT_OK, COOLANT_MAX)
	if coolant > 115.0:
		_hurt("engine", delta * 0.01, "")
	if coolant >= COOLANT_MAX and gb.running:
		_say("ENGINE OVERHEATED: it quit (wait for it to cool, or wash the radiator)")


func _hurt(part: String, amount: float, note: String) -> void:
	if amount <= 0.0:
		return
	var before := float(cond[part])
	cond[part] = maxf(0.0, before - amount)
	if note != "" and amount > 0.004:
		_say(note)


func _say(note: String) -> void:
	_note = note
	_note_t = 4.0


## HUD lines: the gauge, anything broken, the latest knock.
func status_lines() -> Array[String]:
	var out: Array[String] = []
	if not enabled:
		return out
	var t := "coolant %3.0f C" % coolant
	if cooked:
		t += "  OVERHEATED: engine off till it cools"
	elif coolant >= COOLANT_HOT:
		t += "  HOT: limp mode"
	elif coolant > 100.0:
		t += "  running warm"
	out.append(t)
	if hydrolocked:
		out.append("HYDROLOCKED (Backspace for the marshals)")
	if not shaft_ok(true):
		out.append("front axle shaft snapped")
	if not shaft_ok(false):
		out.append("rear axle shaft snapped")
	if not low_range_ok():
		out.append("transfer case broken: no low range")
	elif cond["underbody"] < 0.5:
		out.append("oil pan cracked: losing oil")
	if cond["steering"] < 0.85:
		out.append("tie rod bent: pulls %s" % ("right" if pull > 0.0 else "left"))
	if _note_t > 0.0:
		out.append(_note)
	return out
