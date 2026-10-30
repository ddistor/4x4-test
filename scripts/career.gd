class_name Career
extends RefCounted
## Career mode: the rig you picked, your pesos, the parts you've bought and
## the ones fitted, and the club events you can enter. Kept between launches
## in user://career.cfg. Free play doesn't touch any of it.
##
## No clock (it's a drive, not a race): an event pays for getting to the end,
## less the marshals' fee each time they put you back on the trail.

const FILE := "user://career.cfg"
const START_PESOS := 60000
const RECOVERY_FEE := 4000
## [name, trail level (StagePlan.DIFFICULTY), pay, finishes of the event
## before it that open it]
const EVENTS := [
	["Sunday club run", 0, 30000, 0],
	["Club challenge", 1, 55000, 1],
	["Invitational", 2, 95000, 2]]

var started := false
var rig_id := ""
var pesos := 0
## slot -> option ids bought (the stock part is always owned)
var owned := {}
## slot -> option id, only where it isn't the stock part
var fitted := {}
## finishes per event
var finishes: Array[int] = [0, 0, 0]
var event := 0
## Where it's kept (the tests point this somewhere else).
var file := FILE


func load_file() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(file) != OK:
		return
	started = cfg.get_value("career", "started", false)
	rig_id = cfg.get_value("career", "rig", "")
	pesos = cfg.get_value("career", "pesos", START_PESOS)
	owned = cfg.get_value("career", "owned", {})
	fitted = cfg.get_value("career", "fitted", {})
	var f: Array = cfg.get_value("career", "finishes", [0, 0, 0])
	for i in mini(f.size(), finishes.size()):
		finishes[i] = int(f[i])
	event = clampi(cfg.get_value("career", "event", 0), 0, EVENTS.size() - 1)
	if rig_kind() < 0:
		started = false


func save_file() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("career", "started", started)
	cfg.set_value("career", "rig", rig_id)
	cfg.set_value("career", "pesos", pesos)
	cfg.set_value("career", "owned", owned)
	cfg.set_value("career", "fitted", fitted)
	cfg.set_value("career", "finishes", finishes)
	cfg.set_value("career", "event", event)
	cfg.save(file)


## A fresh career in `kind` (index into RigSpec.kinds()), as it came.
func start(kind: int) -> void:
	started = true
	rig_id = RigSpec.get_kind(kind).id
	pesos = START_PESOS
	owned = {}
	fitted = {}
	finishes = [0, 0, 0]
	event = 0
	save_file()


## Index into RigSpec.kinds() of the career rig, -1 if there's none.
func rig_kind() -> int:
	var all := RigSpec.kinds()
	for k in all.size():
		if all[k].id == rig_id:
			return k
	return -1


func stock_spec() -> RigSpec:
	return RigSpec.get_kind(rig_kind())


func fitted_id(slot: String) -> String:
	return fitted.get(slot, Parts.stock_option(stock_spec(), slot))


func owns(slot: String, id: String) -> bool:
	return id == Parts.stock_option(stock_spec(), slot) or (owned.get(slot, []) as Array).has(id)


## Fit a part you own; it goes back on the shelf when you swap it out.
func fit(slot: String, id: String) -> void:
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


func unlocked(e: int) -> bool:
	return e == 0 or finishes[e - 1] >= EVENTS[e][3]


## Why event `e` is shut, for the button.
func lock_reason(e: int) -> String:
	var need: int = EVENTS[e][3] - finishes[e - 1]
	return "finish %d more %s" % [need, EVENTS[e - 1][0].to_lower()]


## You got to the end of event `e`: what it pays after the marshals' fees
## (never less than nothing), banked and saved.
func finish(e: int, recoveries: int) -> int:
	var pay := maxi(0, int(EVENTS[e][2]) - recoveries * RECOVERY_FEE)
	pesos += pay
	finishes[e] += 1
	save_file()
	return pay


static func pesos_text(p: int) -> String:
	var s := str(absi(p))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if p < 0 else "") + "₱" + s + out
