extends Node
## Career parts and money: which tires fit under which lift, buying and
## fitting, event pay less marshal fees, the save round trip, and on a real
## stage that a lift and bigger tires raise the rig by what they should.
## Uses its own save file; the player's career is left alone.
##   godot --headless --path . res://tests/parts_test.tscn -- --seed 7
const TEST_FILE := "user://career_test.cfg"
var bad := 0


func _ready() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool, got: Variant = "") -> void:
	print("%s  %s  %s" % ["ok  " if ok else "FAIL", what, str(got)])
	if not ok:
		bad += 1


func _kind(id: String) -> RigSpec:
	for k in RigSpec.kinds():
		if k.id == id:
			return k
	return null


func _run() -> void:
	# --- what fits ---
	var gera := _kind("gera")
	var feroz := _kind("feroz")
	var kuw := _kind("kuwarenta")
	_check("gera stock tires", Parts.stock_option(gera, "tires") == "35_mt", Parts.stock_option(gera, "tires"))
	_check("gera 37s need a lift", Parts.blocked(gera, {}, "tires", "37_mt") == "needs a 2.5 in lift", Parts.blocked(gera, {}, "tires", "37_mt"))
	_check("gera 37s on 2.5 in", Parts.blocked(gera, {"lift": "2.5"}, "tires", "37_mt") == "")
	_check("gera smaller tires always fit", Parts.blocked(gera, {}, "tires", "31_at") == "")
	_check("feroz 35s need 4 in", Parts.blocked(feroz, {}, "tires", "35_mt") == "needs a 4 in lift", Parts.blocked(feroz, {}, "tires", "35_mt"))
	_check("feroz 37s too big", Parts.blocked(feroz, {"lift": "lt"}, "tires", "37_mt") == "too big for this body")
	_check("kuwarenta 37s on long-travel", Parts.blocked(kuw, {"lift": "lt"}, "tires", "37_mt") == "")
	_check("can't drop the lift under 37s", Parts.blocked(gera, {"tires": "37_mt", "lift": "2.5"}, "lift", "stock") != "")
	_check("rubikon has no 4:1 to buy", Parts.options(_kind("rubikon"), "low").size() == 1)
	_check("ronda's own gears on the list", Parts.options(_kind("ronda"), "gears").has(Parts.stock_option(_kind("ronda"), "gears")))
	var built := Parts.apply(_kind("gera"), {"tires": "37_mt", "lift": "2.5", "gears": "5.13", "low": "4.0"})
	_check("wells stay stock", is_equal_approx(built.max_tire_top(), gera.max_tire_top()), built.max_tire_top())
	_check("lifted tire clears at the bump stop", built.ride_hub_y() + built.bump + built.tire_radius <= built.max_tire_top() + 0.001)
	_check("gears fitted", is_equal_approx(built.final_drive, 5.13) and is_equal_approx(built.low_ratio, 4.0))
	_check("heavier", built.mass > gera.mass, built.mass)
	_check("stock fit changes nothing", Parts.apply(_kind("gera"), {}).tire_radius == gera.tire_radius and Parts.apply(_kind("gera"), {}).lift == 0.0)

	# --- money ---
	var c := Career.new()
	c.file = TEST_FILE
	c.start(0)
	_check("start pesos", c.pesos == Career.START_PESOS, c.pesos)
	_check("too dear", not c.buy("tires", "37_mt") and c.pesos == Career.START_PESOS)
	_check("buy a lift", c.buy("lift", "2.5") and c.fitted_id("lift") == "2.5", c.pesos)
	c.fit("lift", "stock")
	_check("swap back to stock, still own it", c.fitted_id("lift") == "stock" and c.owns("lift", "2.5"))
	_check("only the first event open", c.unlocked(0) and not c.unlocked(1))
	var before := c.pesos
	var r := c.finish(0, 2)
	_check("first finish pays half again, less two recoveries", r["pay"] == 30000 - 2 * Career.RECOVERY_FEE and c.pesos == before + r["pay"], r)
	_check("one club run isn't enough for the challenge", not c.unlocked(1) and r["opened"].is_empty())
	_check("fees never take more than three quarters", c.finish(0, 99)["pay"] == 5000)
	_check("the second finish opens the challenge", c.unlocked(1) and not c.unlocked(2))
	_check("a clean run pays a bonus", c.finish(0, 0)["pay"] == 20000 + 5000)
	var d := Career.new()
	d.file = TEST_FILE
	d.load_file()
	_check("save round trip", d.started and d.rig_id == "gera" and d.pesos == c.pesos and d.owns("lift", "2.5") and d.finishes[0] == 3)
	_check("pesos text", Career.pesos_text(1234567) == "₱1,234,567", Career.pesos_text(1234567))

	# --- armor ---
	_check("gera's cage is the one it came with", Array(Parts.options(gera, "cage")) == ["full"])
	_check("kuwarenta's roll bar goes to a full cage", Array(Parts.options(kuw, "cage")) == ["bar", "full"])
	_check("gerilya comes with sliders", Parts.options(_kind("gerilya"), "sliders").size() == 1)
	var armored := Parts.apply(_kind("feroz"), {"skid": "steel", "sliders": "steel", "cage": "full", "snorkel": "snorkel", "shafts": "chromoly", "steering": "hd"})
	_check("armor fitted", armored.skid and armored.sliders and armored.cage == 2 and armored.intake_depth > 1.0 and armored.chromoly and armored.hd_steering)
	_check("armor weighs", armored.mass > feroz.mass + 100.0, armored.mass - feroz.mass)

	# --- more rigs, repairs ---
	c.pesos = 2000000
	_check("buy a second rig", c.buy_rig("rubikon") and c.rig_id == "rubikon" and c.pesos == 2000000 - Career.RIG_PRICES["rubikon"])
	_check("it comes stock", c.fitted.is_empty())
	c.buy("lift", "4")
	c.switch_rig("gera")
	_check("parts stay on their rig", c.fitted_id("lift") == "stock" and not c.owns("lift", "4"))
	c.bank_damage({"underbody": 0.5, "shaft_f": 0.0})
	_check("repair bill", c.repair_cost() == 20000 + 15000, c.repair_cost())
	var cash := c.pesos
	_check("repair one part", c.repair_part("shaft_f") and c.pesos == cash - 15000 and c.repair_cost() == 20000)
	_check("repair the rest", c.repair() and c.pesos == cash - 35000 and c.repair_cost() == 0)
	var old := ConfigFile.new()
	old.set_value("career", "started", true)
	old.set_value("career", "rig", "owner")
	old.set_value("career", "fitted", {"lift": "2.5"})
	old.set_value("career", "owned", {"lift": ["2.5"]})
	old.set_value("career", "finishes", [4, 2, 1])
	old.save(TEST_FILE)
	var m := Career.new()
	m.file = TEST_FILE
	m.load_file()
	_check("an old one-rig save loads", m.started and m.rig_id == "owner" and m.fitted_id("lift") == "2.5" and m.owns("lift", "2.5"))
	_check("its finishes move to the new ladder", Array(m.finishes) == [4, 2, 0, 1, 0], m.finishes)

	# --- lockers, kit, tires between rigs, selling, seasons, a fresh start ---
	_check("lockers from open up", Array(Parts.options(gera, "lockers")) == ["open", "rear_auto", "rear", "both"])
	_check("the rubikon came with them", Array(Parts.options(_kind("rubikon"), "lockers")) == ["both"])
	var kitted := Parts.apply(_kind("gera"), {"lockers": "rear", "wheels": "beadlock", "compressor": "onboard"})
	_check("lockers and kit fitted", kitted.lockers == "rear" and kitted.beadlocks and kitted.compressor and not kitted.boards and not kitted.jack)
	_check("a career rig starts without the kit", not Parts.apply(_kind("gera"), {}).compressor and Parts.apply(_kind("gera"), {}).lockers == "open")
	var t := Career.new()
	t.file = TEST_FILE
	t.start(0)
	t.pesos = 5000000
	t.buy("tires", "37_mt")
	t.buy_rig("owner")
	_check("the gera's 37s fit the owner (same bolt pattern)", t.owns("tires", "37_mt"))
	t.fit("tires", "37_mt")
	_check("they move over", t.fitted_id("tires") == "37_mt" and not t.rigs["gera"]["owned"]["tires"].has("37_mt"))
	t.buy_rig("kuwarenta")
	_check("not onto a kuwarenta (6 on 5.5)", not t.owns("tires", "37_mt"))
	var worth := t.sell_value("kuwarenta")
	var before_sale := t.pesos
	_check("sell a rig for 60%", worth == int(Career.RIG_PRICES["kuwarenta"] * 0.6) and t.sell_rig() and t.pesos == before_sale + worth and not t.rigs.has("kuwarenta"))
	t.switch_rig("gera")
	t.sell_rig()
	_check("can't sell your last rig", not t.sell_rig() and t.rigs.size() == 1)
	var p0 := t.purse(4)
	t.finishes = [3, 3, 3, 3, 0]
	var won := t.finish(4, 0)
	_check("the trophy wins the season", won["season_won"] and t.season() == 2 and t.purse(4) == int(p0 * 1.2), t.purse(4))
	t.reset()
	var u := Career.new()
	u.file = TEST_FILE
	u.load_file()
	_check("a new career starts from nothing", not u.started and u.rigs.is_empty() and u.trophies == 0)
	var plan := StagePlan.generate(5, -1, 1, ["bog", "clay"])
	var kinds := plan.sections.map(func(sec: Dictionary) -> String: return sec["kind"])
	_check("an event's trail is in its stage", kinds.has("bog") and kinds.has("clay") and kinds.has("river") and kinds.has("kanal"), kinds)
	var free_a := StagePlan.generate(5).sections.map(func(sec: Dictionary) -> String: return sec["kind"])
	var free_b := StagePlan.generate(5, -1, 1, []).sections.map(func(sec: Dictionary) -> String: return sec["kind"])
	_check("free play stages unchanged", free_a == free_b)

	c.start(0)

	# --- on the stage: lift + 37s raise the body by 2.5 in + 1 in of radius ---
	Game.career = c
	Game.in_career = true
	Game.rig_kind = 0
	c.fitted = {}
	var h0 := await _ride_height()
	c.fitted = {"lift": "2.5", "tires": "37_mt"}
	var h1 := await _ride_height()
	var want := 0.0635 + (0.47 - 0.445)
	_check("body sits higher by %.3f m" % want, absf((h1 - h0) - want) < 0.03, "%.3f" % (h1 - h0))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_FILE))
	print("RESULT ", "PASS" if bad == 0 else "FAIL")
	get_tree().quit()


## Settle the rig on the paddy road and read how high its origin sits over
## the ground under it.
func _ride_height() -> float:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var rig: Rig = main.get_node("Rig")
	var terrain: Terrain = main.get_node("Terrain")
	for i in range(30):
		await get_tree().physics_frame
	rig.place_on_trail(30.0)
	for i in range(int(4.0 * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame
	var p := rig.global_position
	var h := p.y - terrain.get_height(p.x, p.z)
	print("    %s lift %.3f tires %.3f: origin %.3f m over the ground" % [rig.spec.id, rig.spec.lift, rig.spec.tire_radius, h])
	main.queue_free()
	await get_tree().process_frame
	return h
