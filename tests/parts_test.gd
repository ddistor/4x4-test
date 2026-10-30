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
	var pay := c.finish(0, 2)
	_check("pay less two recoveries", pay == 30000 - 2 * Career.RECOVERY_FEE and c.pesos == before + pay, pay)
	_check("challenge opens", c.unlocked(1) and not c.unlocked(2))
	_check("fees never take you below nothing", c.finish(0, 99) == 0)
	var d := Career.new()
	d.file = TEST_FILE
	d.load_file()
	_check("save round trip", d.started and d.rig_id == "gera" and d.pesos == c.pesos and d.owns("lift", "2.5") and d.finishes[0] == 2)
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
	_check("repair", c.repair() and c.pesos == cash - 35000 and c.repair_cost() == 0)
	var old := ConfigFile.new()
	old.set_value("career", "started", true)
	old.set_value("career", "rig", "owner")
	old.set_value("career", "fitted", {"lift": "2.5"})
	old.set_value("career", "owned", {"lift": ["2.5"]})
	old.save(TEST_FILE)
	var m := Career.new()
	m.file = TEST_FILE
	m.load_file()
	_check("an old one-rig save loads", m.started and m.rig_id == "owner" and m.fitted_id("lift") == "2.5" and m.owns("lift", "2.5"))
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
