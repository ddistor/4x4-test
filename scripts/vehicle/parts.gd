class_name Parts
extends RefCounted
## Career-mode upgrades: what you can bolt on, what it costs and what it
## changes on the rig's RigSpec. A fitted set is a Dictionary slot -> option
## id; Parts.apply() turns the stock spec into the one you drive. Free play
## fits nothing and drives the rigs as built.
##
## Every part is a trade, not a strict upgrade (see docs/upgrades.md): bigger
## tires and a lift clear more and float more, but put the weight higher and
## gear the rig taller; deeper gears crawl but run out of top speed.
##
## Prices are rough Philippine shop prices, installed, for a set of four tires
## or both axles.

## The garage shows them on two pages.
const DRIVETRAIN := ["tires", "lift", "gears", "low", "lockers"]
const ARMOR_SLOTS := ["skid", "sliders", "cage", "snorkel", "shafts", "steering"]
const KIT_SLOTS := ["wheels", "compressor", "boards", "jack"]
const SLOTS := DRIVETRAIN + ARMOR_SLOTS + KIT_SLOTS
const SLOT_NAMES := {"tires": "Tires", "lift": "Lift", "gears": "Axle gears", "low": "Low range",
	"skid": "Skid plates", "sliders": "Rock sliders", "cage": "Cage", "snorkel": "Snorkel",
	"shafts": "Axle shafts", "steering": "Tie rods", "lockers": "Lockers",
	"wheels": "Wheels", "compressor": "Compressor", "boards": "Traction boards", "jack": "High-lift jack"}

## Lockers: id -> [name, kg, price, what it does].
const LOCKERS := {
	"open": ["Open diffs", 0.0, 0, "Each axle drives only what its lighter tire can hold: lift a wheel and it spins, the other gets nothing."],
	"rear_auto": ["Auto rear locker", 3.0, 25000, "A lunchbox locker in the rear: always locked, nothing to switch. Cheap, but it pushes the nose wide in tight turns."],
	"rear": ["Selectable rear", 5.0, 55000, "An air locker in the rear axle: L locks it when you need it, open for the turns."],
	"both": ["Selectable front and rear", 10.0, 110000, "Air lockers in both axles: L locks all four tires together. The front one shock-loads its shafts and won't steer well locked."]}
const LOCKER_IDS := ["open", "rear_auto", "rear", "both"]

## Protection, what each costs and does: slot -> {id: [name, kg, price, what it does]}.
## The first is what most rigs come with. What damage each one saves you
## from is in damage.gd.
const ARMOR := {
	"skid": {"none": ["None", 0.0, 0, "Oil pan and transfer case hang out under the belly: a rock strike cracks them."],
		"steel": ["Steel plates", 35.0, 35000, "3/16 in steel under the oil pan and transfer case: a high-centred rig slides off the rock instead of hanging and cracking the pan."]},
	"sliders": {"none": ["None", 0.0, 0, "The sills take every rock you slide against."],
		"steel": ["Steel sliders", 30.0, 40000, "Tubes along the sills, bolted to the frame: lean on a rock and slide past it, the body stays straight."]},
	"cage": {"none": ["None", 0.0, 0, "Roll it and the body takes it all."],
		"bar": ["Roll bar", 25.0, 45000, "A hoop behind the seats: on its side or roof the bar carries the rig, not the body."],
		"full": ["Full cage", 55.0, 110000, "Hoops front and back joined over the top: a rollover bends tubes, not the rig. Weight up high: tips a little sooner."]},
	"snorkel": {"none": ["None", 0.0, 0, "The air intake sits behind the grille: water over about 0.9 m at the front tires drowns the engine."],
		"snorkel": ["Snorkel", 6.0, 28000, "Intake up at the roof line: wade to about 1.5 m without hydrolocking it."]},
	"shafts": {"stock": ["Stock", 0.0, 0, "Fine until a spinning tire grabs with the lockers in: then one snaps."],
		"chromoly": ["Chromoly", 4.0, 60000, "Chromoly shafts and joints front and rear: they take a shock load the stock ones snap on."]},
	"steering": {"stock": ["Stock", 0.0, 0, "Slam a front tire sideways into a rock and the tie rod bends: the rig pulls to one side."],
		"hd": ["Heavy-duty", 3.0, 18000, "A thick-wall tie rod and drag link: they shrug off hits that bend the stock ones."]},
	# the kit (the same table: it's all bolt-on)
	"wheels": {"steel": ["Steel wheels", 0.0, 0, "Air down past 12 psi and corner hard, and the tire rolls off the rim."],
		"beadlock": ["Beadlocks", 12.0, 60000, "A ring bolts the bead to the wheel: air down to 8 psi, the tire wraps rock and floats on mud, and it stays on."]},
	"compressor": {"none": ["None", 0.0, 0, "Air down on the trail and you drive the rest of it soft."],
		"onboard": ["On-board compressor", 8.0, 22000, "Air back up on the trail when the rock gives way to road (= key, stopped)."]},
	"boards": {"none": ["None", 0.0, 0, "Just the shovel in the back."],
		"boards": ["Traction boards", 10.0, 12000, "A pair of cleated boards to lay under the tires out of a hole (2)."]},
	"jack": {"none": ["None", 0.0, 0, "Hung on a rock with nothing to winch to: the marshals."],
		"highlift": ["High-lift jack", 13.0, 9000, "Jack it off what it's hung on and pack stones under the tires (3)."]}}
const CAGE_IDS := ["none", "bar", "full"]

## Tire sizes, inches: [radius m, width m, price for a set of mud-terrains].
## All-terrains are 80% of that.
const TIRE_SIZES := {31: [0.395, 0.27, 48000], 33: [0.42, 0.3, 60000], 35: [0.445, 0.32, 76000], 37: [0.47, 0.33, 96000]}
const AT_PRICE := 0.8
## A whole tire and wheel, kg, for a 35 x 12.5 (scaled by size).
const TIRE_KG := 50.0

## Lifts: [name, lift m, extra droop m, extra bump m, kg, price].
const LIFTS := {
	"stock": ["Stock height", 0.0, 0.0, 0.0, 0.0, 0],
	"2.5": ["2.5 in lift", 0.0635, 0.02, 0.0, 15.0, 55000],
	"4": ["4 in lift", 0.1016, 0.03, 0.0, 25.0, 85000],
	"lt": ["4 in long-travel", 0.1016, 0.09, 0.04, 45.0, 165000]}

## Ring and pinion ratios on offer, both axles.
const GEARS := [4.1, 4.56, 4.88, 5.13, 5.38]
const GEAR_PRICE := 70000
## A 4:1 low-range transfer case.
const LOW_4 := 4.0
const LOW_PRICE := 120000
const LOW_KG := 12.0


## The option ids for `slot` on this rig, cheapest/stock first.
static func options(stock: RigSpec, slot: String) -> Array[String]:
	var out: Array[String] = []
	match slot:
		"tires":
			for size: int in TIRE_SIZES:
				out.append("%d_mt" % size)
				out.append("%d_at" % size)
		"lift":
			for k: String in LIFTS:
				out.append(k)
		"gears":
			var ratios := GEARS.duplicate()
			if not ratios.has(stock.final_drive):
				ratios.append(stock.final_drive)
			ratios.sort()
			for g: float in ratios:
				out.append(_ratio_id(g))
		"low":
			out.append(_ratio_id(stock.low_ratio))
			if stock.low_ratio < LOW_4:
				out.append(_ratio_id(LOW_4))
		"lockers":
			# from what it came with up
			for i in range(LOCKER_IDS.find(stock.stock_lockers), LOCKER_IDS.size()):
				out.append(LOCKER_IDS[i])
		"cage":
			# a welded-in cage stays: you can only go up from what it came with
			for i in range(stock.cage, CAGE_IDS.size()):
				out.append(CAGE_IDS[i])
		"sliders":
			if not stock.sliders:
				out.append("none")
			out.append("steel")
		_:
			if ARMOR.has(slot):
				for k: String in ARMOR[slot]:
					out.append(k)
	return out


## What the rig comes with in `slot`: owned from the start.
static func stock_option(stock: RigSpec, slot: String) -> String:
	match slot:
		"tires":
			var best := 35
			for size: int in TIRE_SIZES:
				if absf(TIRE_SIZES[size][0] - stock.tire_radius) < absf(TIRE_SIZES[best][0] - stock.tire_radius):
					best = size
			return "%d_%s" % [best, "mt" if stock.tread == 1 else "at"]
		"lift":
			return "stock"
		"gears":
			return _ratio_id(stock.final_drive)
		"low":
			return _ratio_id(stock.low_ratio)
		"cage":
			return CAGE_IDS[stock.cage]
		"lockers":
			return stock.stock_lockers
		"sliders":
			return "steel" if stock.sliders else "none"
		_:
			if ARMOR.has(slot):
				return (ARMOR[slot] as Dictionary).keys()[0]
	return ""


static func label(slot: String, id: String) -> String:
	match slot:
		"tires":
			var p := id.split("_")
			return "%s in %s" % [p[0], "mud-terrain" if p[1] == "mt" else "all-terrain"]
		"lift":
			return LIFTS[id][0]
		"gears":
			return "%s:1" % id
		"low":
			return "%s:1" % id
	if slot == "lockers":
		return LOCKERS[id][0]
	if ARMOR.has(slot):
		return ARMOR[slot][id][0]
	return id


static func price(slot: String, id: String) -> int:
	match slot:
		"tires":
			var p := id.split("_")
			var base: int = TIRE_SIZES[int(p[0])][2]
			return base if p[1] == "mt" else int(base * AT_PRICE)
		"lift":
			return LIFTS[id][5]
		"gears":
			return GEAR_PRICE
		"low":
			return LOW_PRICE
	if slot == "lockers":
		return LOCKERS[id][2]
	if ARMOR.has(slot):
		return ARMOR[slot][id][2]
	return 0


## One line on what the option does on this rig.
static func describe(stock: RigSpec, slot: String, id: String) -> String:
	match slot:
		"tires":
			var p := id.split("_")
			var tread := "Open lugs: bite in mud, shed clay at speed." if p[1] == "mt" \
				else "Cheaper, grips firm ground a little better, packs with clay fast."
			var r: float = TIRE_SIZES[int(p[0])][0]
			var d := 2.0 * (r - stock.tire_radius) * 39.37
			var size := "Same size as stock." if absf(d) < 0.5 \
				else "%+.0f in taller: %s clearance, floats more, gears the rig taller." % [d, "more" if d > 0 else "less"]
			return size + " " + tread
		"lift":
			if id == "stock":
				return "As built."
			var l: Array = LIFTS[id]
			var s := "Body sits %.0f cm higher: belly clearance and room for bigger tires, but it tips sooner." % (l[1] * 100.0)
			if id == "lt":
				s += " Long shocks: much more droop and bump, the axles keep the tires down."
			return s
		"gears":
			var g := float(id)
			var crawl := stock.gears[0] * g * stock.low_ratio
			return "Crawl ratio %.0f:1 in 4L (stock %.0f:1). Deeper pulls bigger tires and crawls slower, less top speed." % [
				crawl, stock.gears[0] * stock.final_drive * stock.low_ratio]
		"low":
			var lo := float(id)
			return "Crawl ratio %.0f:1 in 1st low (stock %.0f:1). For rock steps and steep clay." % [
				stock.gears[0] * stock.final_drive * lo, stock.gears[0] * stock.final_drive * stock.low_ratio]
	if slot == "lockers":
		return ("Came with the rig. " if id == stock.stock_lockers and id != "open" else "") + LOCKERS[id][3]
	if ARMOR.has(slot):
		if slot == "cage" and id == CAGE_IDS[stock.cage] and stock.cage > 0:
			return "Came with the rig. " + ARMOR[slot][id][3]
		return ARMOR[slot][id][3]
	return ""


## "" if `id` can go in `slot` with the rest of `fit`, else why it can't.
## Bigger tires need lift to clear the wells: about 1 in of lift per inch of
## extra tire (they grow out and sweep wider when the axle flexes and steers),
## and long-travel shocks reach higher into the wells.
static func blocked(stock: RigSpec, fit: Dictionary, slot: String, id: String) -> String:
	var trial := fit.duplicate()
	trial[slot] = id
	var tires: String = trial.get("tires", stock_option(stock, "tires"))
	var lift_id: String = trial.get("lift", "stock")
	var r: float = TIRE_SIZES[int(tires.split("_")[0])][0]
	var l: Array = LIFTS[lift_id]
	var lift: float = l[1]
	var grow := r - stock.tire_radius
	if 2.0 * grow - lift > 0.006 or grow + l[3] - lift > 0.001:
		var need := ""
		for k: String in LIFTS:
			var lk: Array = LIFTS[k]
			if 2.0 * grow - lk[1] <= 0.006 and grow + lk[3] - lk[1] <= 0.001:
				need = lk[0]
				break
		if slot == "lift":
			return "the %s tires need more lift than that" % tires.split("_")[0]
		if need == "":
			return "too big for this body"
		return "needs a %s" % need.to_lower()
	return ""


## Turn the stock spec into the rig with `fit` bolted on. The body is still
## built round the stock wheel wells (fender_top).
static func apply(s: RigSpec, fit: Dictionary) -> RigSpec:
	s.fender_top = s.max_tire_top()
	if fit.has("tires"):
		var p: PackedStringArray = (fit["tires"] as String).split("_")
		var t: Array = TIRE_SIZES[int(p[0])]
		var r0 := s.tire_radius
		var w0 := s.tire_width
		s.tire_radius = t[0]
		s.tire_width = t[1]
		s.tread = 1 if p[1] == "mt" else 0
		# a longer, wider contact patch: lower ground pressure
		s.footprint = (s.tire_width / w0) * sqrt(s.tire_radius / r0)
		s.mass += 4.0 * TIRE_KG * (_tire_bulk(s.tire_radius, s.tire_width) - _tire_bulk(r0, w0))
	if fit.has("lift"):
		var l: Array = LIFTS[fit["lift"]]
		s.lift = l[1]
		s.wheel_mount_y -= s.lift
		s.droop += l[2]
		s.bump += l[3]
		s.mass += l[4]
	if fit.has("gears"):
		s.final_drive = float(fit["gears"])
	if fit.has("low") and float(fit["low"]) != s.low_ratio:
		s.low_ratio = float(fit["low"])
		s.mass += LOW_KG
	if fit.has("lockers") and fit["lockers"] != s.stock_lockers:
		s.mass += LOCKERS[fit["lockers"]][1]
	s.lockers = fit.get("lockers", s.stock_lockers)
	s.beadlocks = fit.get("wheels", "steel") == "beadlock"
	s.compressor = fit.get("compressor", "none") != "none"
	s.boards = fit.get("boards", "none") != "none"
	s.jack = fit.get("jack", "none") != "none"
	for slot: String in ARMOR_SLOTS + KIT_SLOTS:
		if not fit.has(slot) or fit[slot] == stock_option(s, slot):
			continue
		var a: Array = ARMOR[slot][fit[slot]]
		s.mass += a[1]
		match slot:
			"skid":
				s.skid = true
			"sliders":
				s.sliders = true
			"cage":
				var c := CAGE_IDS.find(fit[slot])
				# weight up high: the cage's mass raises the centre of mass a little
				s.center_of_mass.y += 0.012 * (c - s.cage)
				s.cage = c
			"snorkel":
				s.intake_depth = 1.5
			"shafts":
				s.chromoly = true
			"steering":
				s.hd_steering = true
	return s


static func _tire_bulk(r: float, w: float) -> float:
	return (r * r * w) / (0.445 * 0.445 * 0.32)


static func _ratio_id(g: float) -> String:
	return str(g)
