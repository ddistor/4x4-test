class_name Career
extends RefCounted
## Career mode: the rigs you own (you start with one you pick, buy more as
## the pesos come in), the parts each has bought and fitted, the damage each
## carries, your pesos, and the club events you can enter. Kept between
## launches in user://career.cfg. Free play doesn't touch any of it.
##
## Parts stay with the rig they were bought for: lifts, gears, cages and the
## rest are made for that chassis (see docs/upgrades.md).
##
## No clock (it's a drive, not a race): an event pays for getting to the end,
## double the first time, a bonus for a clean run with no marshals, less the
## marshals' fee each time they put you back on the trail, never less than a
## quarter of the purse (the club covers your fuel). Damage is paid for in
## the garage, when you choose to fix it, a part at a time if money's short.
##
## The ladder: each event opens after finishes of the one before it, and the
## top ones are run under competition rules, so the scrutineers want a roll
## bar, then a full cage and a snorkel, before you're let on the trail. Each
## event runs its own kind of trail. Win the Morong Trophy and that's the
## season: the next one's purses and fees are a fifth bigger (sponsors know
## your name now), every season you win.

const FILE := "user://career.cfg"
const VERSION := 2
const START_PESOS := 60000
const RECOVERY_FEE := 4000
const FIRST_BONUS := 0.5     # the first finish of an event pays this much more
const CLEAN_BONUS := 0.25    # finished without the marshals
const MIN_PAY := 0.25        # of the purse, whatever the fees
const SEASON_RAISE := 0.2    # purses and fees, each season won
const SELL_BACK := 0.6       # what a rig and its parts fetch, sold on
const SELL_PART := 0.5       # a part off the shelf, sold on its own
## name; trail level (StagePlan.DIFFICULTY); purse; entry fee, paid when you
## set off; the event before it and how many finishes of it open this one;
## weather (-1 the seed decides, 1 rainy season); what the scrutineers want:
## cage (1 roll bar, 2 full), snorkel; trail: the section kinds its stage
## always has (on top of a river and a kanal). Tuned with
## tests/career_test.gd: a careful driver reaches the trophy in about a dozen.
const EVENTS := [
	{"name": "Sunday club run", "level": 0, "pay": 20000, "fee": 0, "after": -1, "runs": 0, "weather": -1,
		"trail": ["pasture", "niyog"]},
	{"name": "Club challenge", "level": 1, "pay": 35000, "fee": 0, "after": 0, "runs": 2, "weather": -1,
		"trail": ["clay"]},
	{"name": "Tanay Cup round", "level": 1, "pay": 50000, "fee": 5000, "after": 1, "runs": 3, "weather": 1,
		"trail": ["bog", "clay"]},
	{"name": "Invitational", "level": 2, "pay": 75000, "fee": 15000, "after": 2, "runs": 3, "weather": -1, "cage": 1,
		"trail": ["rocky", "gully"]},
	{"name": "Morong Trophy", "level": 2, "pay": 120000, "fee": 25000, "after": 3, "runs": 3, "weather": 1, "cage": 2,
		"snorkel": true, "trail": ["rocky", "gully", "lahar"]}]
## What another rig costs, as it comes (a used rig off a club member).
const RIG_PRICES := {"gera": 650000, "kuwarenta": 550000, "feroz": 350000, "ronda": 700000,
	"owner": 300000, "rubikon": 1600000, "gerilya": 950000}

var started := false
## the rig you're working on and drive
var rig_id := ""
var pesos := 0
## rig id -> {"owned": slot -> [ids bought], "fitted": slot -> id (only
## where it isn't stock), "damage": part -> condition (damage.gd)}
var rigs := {}
## finishes per event
var finishes: Array[int] = [0, 0, 0, 0, 0]
var event := 0
## Morong Trophies won: each is a season, and puts the purses up
var trophies := 0
## the first-visit explainer in the garage has been read
var seen_help := false
## Where it's kept (the tests point this somewhere else).
var file := FILE

## The current rig's parts bought and fitted, and its damage.
var owned: Dictionary:
	get: return _state().get_or_add("owned", {})
	set(v): _state()["owned"] = v
var fitted: Dictionary:
	get: return _state().get_or_add("fitted", {})
	set(v): _state()["fitted"] = v
var damage: Dictionary:
	get: return _state().get_or_add("damage", {})
	set(v): _state()["damage"] = v


func _state() -> Dictionary:
	return rigs.get_or_add(rig_id, {})


func load_file() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(file) != OK:
		return
	started = cfg.get_value("career", "started", false)
	rig_id = cfg.get_value("career", "rig", "")
	pesos = cfg.get_value("career", "pesos", START_PESOS)
	rigs = cfg.get_value("career", "rigs", {})
	if rigs.is_empty() and rig_id != "":
		# a save from before you could own more than one rig
		rigs[rig_id] = {"owned": cfg.get_value("career", "owned", {}), "fitted": cfg.get_value("career", "fitted", {})}
	var f: Array = cfg.get_value("career", "finishes", [])
	if int(cfg.get_value("career", "version", 1)) < 2 and f.size() == 3:
		# three events then: club run, challenge, invitational
		f = [f[0], f[1], 0, f[2], 0]
	finishes = [0, 0, 0, 0, 0]
	for i in mini(f.size(), finishes.size()):
		finishes[i] = int(f[i])
	event = clampi(cfg.get_value("career", "event", 0), 0, EVENTS.size() - 1)
	trophies = int(cfg.get_value("career", "trophies", finishes[4]))
	seen_help = cfg.get_value("career", "seen_help", false)
	if rig_kind() < 0:
		started = false


func save_file() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("career", "version", VERSION)
	cfg.set_value("career", "started", started)
	cfg.set_value("career", "rig", rig_id)
	cfg.set_value("career", "pesos", pesos)
	cfg.set_value("career", "rigs", rigs)
	cfg.set_value("career", "finishes", finishes)
	cfg.set_value("career", "event", event)
	cfg.set_value("career", "trophies", trophies)
	cfg.set_value("career", "seen_help", seen_help)
	cfg.save(file)


## A fresh career in `kind` (index into RigSpec.kinds()), as it came.
func start(kind: int) -> void:
	started = true
	rig_id = RigSpec.get_kind(kind).id
	pesos = START_PESOS
	rigs = {rig_id: {}}
	finishes = [0, 0, 0, 0, 0]
	event = 0
	trophies = 0
	save_file()


## Throw the career away: the next visit to the garage picks a rig afresh.
func reset() -> void:
	started = false
	rig_id = ""
	pesos = START_PESOS
	rigs = {}
	finishes = [0, 0, 0, 0, 0]
	event = 0
	trophies = 0
	save_file()


## Index into RigSpec.kinds() of the career rig, -1 if there's none.
func rig_kind() -> int:
	return kind_of(rig_id)


static func kind_of(id: String) -> int:
	var all := RigSpec.kinds()
	for k in all.size():
		if all[k].id == id:
			return k
	return -1


func stock_spec() -> RigSpec:
	return RigSpec.get_kind(rig_kind())


func owns_rig(id: String) -> bool:
	return rigs.has(id)


## Work on and drive another rig you own.
func switch_rig(id: String) -> void:
	if owns_rig(id):
		rig_id = id
		save_file()


## Buy rig `id` and switch to it. False if you can't afford it.
func buy_rig(id: String) -> bool:
	var cost: int = RIG_PRICES.get(id, 0)
	if owns_rig(id) or cost > pesos:
		return false
	pesos -= cost
	rigs[id] = {}
	switch_rig(id)
	return true


func fitted_id(slot: String) -> String:
	return fitted.get(slot, Parts.stock_option(stock_spec(), slot))


func owns(slot: String, id: String) -> bool:
	return id == Parts.stock_option(stock_spec(), slot) or (owned.get(slot, []) as Array).has(id) \
		or (slot == "tires" and tires_elsewhere(id) != "")


## Another rig of yours with the same bolt pattern that has a set of `id`
## tires: they'll bolt straight on this one too. "" if none.
func tires_elsewhere(id: String) -> String:
	var bolt := stock_spec().bolt
	for other: String in rigs:
		if other == rig_id or RigSpec.get_kind(kind_of(other)).bolt != bolt:
			continue
		if (((rigs[other] as Dictionary).get("owned", {}) as Dictionary).get("tires", []) as Array).has(id):
			return other
	return ""


## Fit a part you own; it goes back on the shelf when you swap it out. A
## set of tires off another rig with the same bolt pattern moves over (that
## rig goes back on its own).
func fit(slot: String, id: String) -> void:
	if slot == "tires" and not (owned.get("tires", []) as Array).has(id):
		var other := tires_elsewhere(id)
		if other != "":
			var st: Dictionary = rigs[other]
			(st["owned"]["tires"] as Array).erase(id)
			if (st.get("fitted", {}) as Dictionary).get("tires", "") == id:
				(st["fitted"] as Dictionary).erase("tires")
			var mine: Array = owned.get("tires", [])
			mine.append(id)
			owned["tires"] = mine
	if id == Parts.stock_option(stock_spec(), slot):
		fitted.erase(slot)
	else:
		fitted[slot] = id
	save_file()


## Pay for a part and fit it. False if it costs more than you have.
func buy(slot: String, id: String) -> bool:
	var cost := Parts.price(slot, id)
	if cost > pesos:
		return false
	pesos -= cost
	var list: Array = owned.get(slot, [])
	list.append(id)
	owned[slot] = list
	fit(slot, id)
	return true


## What a rig fetches sold on: 60% of what it cost, and of its parts.
func sell_value(id: String) -> int:
	var total := float(RIG_PRICES.get(id, 0))
	var st: Dictionary = rigs.get(id, {})
	for slot: String in st.get("owned", {}):
		for part: String in st["owned"][slot]:
			total += Parts.price(slot, part)
	# less what it needs fixing
	total = total * SELL_BACK - Damage.repair_cost(st.get("damage", {}))
	return maxi(0, int(roundf(total / 500.0) * 500.0))


## Sell the rig you're on (not your last one) and move to another.
func sell_rig() -> bool:
	if rigs.size() < 2:
		return false
	pesos += sell_value(rig_id)
	rigs.erase(rig_id)
	rig_id = rigs.keys()[0]
	save_file()
	return true


## Can part `id` in `slot` be sold off the current rig? "" if it can, else why not.
func cant_sell(slot: String, id: String) -> String:
	if not (owned.get(slot, []) as Array).has(id):
		return "not yours to sell"
	if fitted_id(slot) == id:
		var stock := Parts.stock_option(stock_spec(), slot)
		var why := Parts.blocked(stock_spec(), fitted, slot, stock)
		if why != "":
			return "it's holding the rest up (" + why + ")"
	return ""


## Sell a part you bought for this rig, half what it cost. Fitted, it comes
## off and the rig goes back to what it came with there.
func sell_part(slot: String, id: String) -> bool:
	if cant_sell(slot, id) != "":
		return false
	pesos += int(Parts.price(slot, id) * SELL_PART)
	(owned[slot] as Array).erase(id)
	if fitted.get(slot, "") == id:
		fitted.erase(slot)
	save_file()
	return true


## What fixing the current rig would cost.
func repair_cost() -> int:
	return Damage.repair_cost(damage)


## Fix one part of the current rig. False if you can't afford it.
func repair_part(part: String) -> bool:
	var cost := Damage.part_cost(damage, part)
	if cost > pesos or cost == 0:
		return false
	pesos -= cost
	var d := damage.duplicate()
	d.erase(part)
	if part == "steering":
		d.erase("pull")
	if part == "body":
		d.erase("dents")   # beaten out
	damage = d
	save_file()
	return true


## Fix everything on the current rig. False if you can't afford it.
func repair() -> bool:
	var cost := repair_cost()
	if cost > pesos:
		return false
	pesos -= cost
	damage = {}
	save_file()
	return true


## Keep what the stage did to the rig.
func bank_damage(d: Dictionary) -> void:
	damage = d
	save_file()


func unlocked(e: int) -> bool:
	var ev: Dictionary = EVENTS[e]
	return ev["after"] < 0 or finishes[ev["after"]] >= ev["runs"]


## Why event `e` is shut, for the button.
func lock_reason(e: int) -> String:
	var ev: Dictionary = EVENTS[e]
	var need: int = ev["runs"] - finishes[ev["after"]]
	return "finish the %s %s" % [(EVENTS[ev["after"]]["name"] as String).to_lower(),
		"once more" if need == 1 else "%d more times" % need]


## What the scrutineers won't let the current rig in without, "" if it passes.
func gear_missing(e: int) -> String:
	var ev: Dictionary = EVENTS[e]
	var s := Parts.apply(stock_spec(), fitted)
	var need: Array[String] = []
	if s.cage < int(ev.get("cage", 0)):
		need.append("a full cage" if int(ev["cage"]) >= 2 else "a roll bar")
	if ev.get("snorkel", false) and s.intake_depth < 1.0:
		need.append("a snorkel")
	return "" if need.is_empty() else "needs " + " and ".join(need)


## This season's purse and entry fee for event `e`.
func purse(e: int) -> int:
	return int(roundf(float(EVENTS[e]["pay"]) * (1.0 + SEASON_RAISE * trophies) / 500.0) * 500.0)


func fee(e: int) -> int:
	return int(roundf(float(EVENTS[e]["fee"]) * (1.0 + SEASON_RAISE * trophies) / 500.0) * 500.0)


func season() -> int:
	return trophies + 1


func can_enter(e: int) -> bool:
	return unlocked(e) and gear_missing(e) == "" and pesos >= fee(e)


## Pay event `e`'s entry fee as you set off. False if you can't go.
func enter(e: int) -> bool:
	if not can_enter(e):
		return false
	pesos -= fee(e)
	save_file()
	return true


## You got to the end of event `e`: the purse, double the first time, a bonus
## with no marshals, less their fees, never under a quarter of the purse.
## Banked and saved. Returns the sums for the finish card, and any event it
## opened.
func finish(e: int, recoveries: int) -> Dictionary:
	var base := purse(e)
	var was_open: Array[bool] = []
	for i in EVENTS.size():
		was_open.append(unlocked(i))
	var out := {"base": base, "first": 0, "clean": 0, "fees": recoveries * RECOVERY_FEE}
	if finishes[e] == 0:
		out["first"] = int(base * FIRST_BONUS)
	if recoveries == 0:
		out["clean"] = int(base * CLEAN_BONUS)
	var pay: int = base + out["first"] + out["clean"] - out["fees"]
	out["pay"] = maxi(pay, int(base * MIN_PAY))
	pesos += out["pay"]
	finishes[e] += 1
	out["season_won"] = e == EVENTS.size() - 1
	if out["season_won"]:
		trophies += 1
	var opened: Array[String] = []
	for i in EVENTS.size():
		if unlocked(i) and not was_open[i]:
			opened.append(EVENTS[i]["name"])
	out["opened"] = opened
	save_file()
	return out


static func pesos_text(p: int) -> String:
	var s := str(absi(p))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if p < 0 else "") + "₱" + s + out
