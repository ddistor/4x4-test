extends Node
## Career progression, end to end. First the money over a whole career, by
## sum: a careful driver and a rough one each climb the ladder from their
## starting rig to a Morong Trophy finish, repairing when they can and buying
## what the scrutineers ask for, and neither gets stuck broke. Then through
## the real scenes: the career garage, drive the club run, cross the finish
## (the HUD pays), back to the garage with the damage kept, the next event
## open, the scrutineers turning away a rig without a cage.
## Uses its own save file; the player's career is left alone.
##   godot --headless --path . res://tests/career_test.tscn
const TEST_FILE := "user://career_test.cfg"
var bad := 0


func _ready() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool, got: Variant = "") -> void:
	print("%s  %s  %s" % ["ok  " if ok else "FAIL", what, str(got)])
	if not ok:
		bad += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	# the test scene is the current scene, which a scene change frees: hand
	# that role to a stand-in and carry on from the root
	var tree := get_tree()
	var stand_in := Node.new()
	tree.root.add_child(stand_in)
	tree.current_scene = stand_in
	reparent(tree.root)
	_economy("careful, Gera", 0, 1, {"underbody": 0.85, "body": 0.9}, 0)
	_economy("rough, Owner", 4, 3, {"underbody": 0.6, "body": 0.7, "steering": 0.8}, 3)
	_economy("rough, Feroz", 4, 4, {"underbody": 0.5, "body": 0.6, "steering": 0.7}, 2)
	await _scenes()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_FILE))
	print("RESULT ", "PASS" if bad == 0 else "FAIL")
	get_tree().quit()


## A whole career by sum: `recov` marshal recoveries a run, what each run does
## to the rig (`wear`: part -> condition after it) and a hydrolock every
## `drown` runs (0: never), until the right part stops it (skid plates for
## the pan, heavy-duty tie rods, a snorkel). Each run the driver does what a
## sensible one would: fix what stops the rig working, buy the protection
## for what keeps breaking, then what the scrutineers want for the highest
## event that's open, body work only with money to spare, and drive the
## highest event they're let into.
func _economy(label: String, kind: int, recov: int, wear: Dictionary, drown: int) -> void:
	var c := Career.new()
	c.file = TEST_FILE
	c.start(kind)
	var runs := 0
	var first_at := {}     # event -> the run it was first finished on
	var poorest := c.pesos
	var spent := {"repairs": 0, "parts": 0, "fees": 0}
	while runs < 120 and c.finishes[4] == 0:
		var cash := c.pesos
		for part: String in ["engine", "shaft_f", "shaft_r", "underbody", "steering"]:
			if float(c.damage.get(part, 1.0)) < 0.75:
				c.repair_part(part)
		spent["repairs"] += cash - c.pesos
		cash = c.pesos
		var top := 0
		for e in Career.EVENTS.size():
			if c.unlocked(e):
				top = e
		# protection first for what keeps breaking, then the scrutineers' list
		if wear.has("underbody"):
			_fit_part(c, "skid", "steel")
		if drown > 0:
			_fit_part(c, "snorkel", "snorkel")
		if wear.has("steering"):
			_fit_part(c, "steering", "hd")
		_gear_up(c, top)
		spent["parts"] += cash - c.pesos
		cash = c.pesos
		if c.pesos > 250000:
			c.repair()
		spent["repairs"] += cash - c.pesos
		var e := 0
		for i in Career.EVENTS.size():
			if c.can_enter(i):
				e = i
		spent["fees"] += c.fee(e)
		c.enter(e)
		c.finish(e, recov)
		runs += 1
		if not first_at.has(e):
			first_at[e] = runs
		var s := Parts.apply(c.stock_spec(), c.fitted)
		var d := c.damage.duplicate()
		for part: String in wear:
			var w: float = wear[part]
			if part == "underbody" and s.skid:
				w = lerpf(1.0, w, 0.1)
			if part == "steering" and s.hd_steering:
				w = lerpf(1.0, w, 0.15)
			d[part] = float(d.get(part, 1.0)) * w
		if drown > 0 and runs % drown == 0 and s.intake_depth < 1.0:
			d["engine"] = float(d.get("engine", 1.0)) - 0.35
		c.bank_damage(d)
		poorest = mini(poorest, c.pesos)
	var path := []
	for ev in first_at:
		path.append("%s @%d" % [Career.EVENTS[ev]["name"], first_at[ev]])
	print("    %s: trophy after %d runs; %s; spent %s repairs, %s parts, %s entry; %s in the bank" % [label, runs,
		", ".join(path), Career.pesos_text(spent["repairs"]), Career.pesos_text(spent["parts"]),
		Career.pesos_text(spent["fees"]), Career.pesos_text(c.pesos)])
	_check("%s reaches the Morong Trophy" % label, c.finishes[4] > 0, runs)
	_check("%s takes a career, not an afternoon (12 to 40 runs)" % label, runs >= 12 and runs <= 40, runs)
	_check("%s never runs out of pesos" % label, poorest >= 0, poorest)


## Fit `id` in `slot` if the rig doesn't have it and there's the money.
func _fit_part(c: Career, slot: String, id: String) -> void:
	if c.fitted_id(slot) == id or Parts.price(slot, id) > c.pesos:
		return
	if c.owns(slot, id):
		c.fit(slot, id)
	else:
		c.buy(slot, id)


## Buy what event `e`'s scrutineers want, if the pesos are there.
func _gear_up(c: Career, e: int) -> void:
	var ev: Dictionary = Career.EVENTS[e]
	var s := Parts.apply(c.stock_spec(), c.fitted)
	var want_cage: int = ev.get("cage", 0)
	if s.cage < want_cage:
		var id: String = Parts.CAGE_IDS[want_cage]
		if c.owns("cage", id):
			c.fit("cage", id)
		else:
			c.buy("cage", id)
	if ev.get("snorkel", false) and s.intake_depth < 1.0:
		c.buy("snorkel", "snorkel")


func _scene_is(script_end: String) -> bool:
	var sc := get_tree().current_scene
	return sc != null and sc.get_script() != null and (sc.get_script() as Script).resource_path.ends_with(script_end)


func _wait_scene(script_end: String) -> bool:
	for i in 600:
		if _scene_is(script_end):
			await _frames(5)
			return true
		await get_tree().process_frame
	return false


## Through the real scenes.
func _scenes() -> void:
	var weather_before := Game.weather
	var c := Career.new()
	c.file = TEST_FILE
	c.start(0)   # the Gera, stock
	Game.career = c
	Game.to_career()
	_check("career opens in the garage", await _wait_scene("garage.gd"))
	var g: Node = get_tree().current_scene
	_check("the club run is open to drive", not g._drive_btn.disabled and g._drive_btn.text == "Drive the sunday club run", g._drive_btn.text)
	_check("pesos shown", g._pesos.text == "₱60,000", g._pesos.text)

	g._drive_btn.pressed.emit()
	_check("driving loads the stage", await _wait_scene("main.gd"))
	_check("the club run is a Moderate trail", Game.level == 0)
	var main := get_tree().current_scene
	var rig: Rig = main.get_node("Rig")
	_check("damage is on in a career", rig.damage.enabled)
	await _frames(30)
	var hud := main.find_children("*", "", true, false).filter(func(n: Node) -> bool:
		return n.get_script() != null and (n.get_script() as Script).resource_path.ends_with("hud.gd"))
	rig.place_on_trail(rig.terrain.plan.finish_z + 4.0)
	await _frames(20)
	var paid := 20000 + 10000 + 5000   # purse, first finish, clean run
	_check("the finish pays: purse, first-finish and clean-run bonuses", c.pesos == 60000 + paid and c.finishes[0] == 1, c.pesos)
	if not hud.is_empty():
		var card: String = (hud[0].get("_finish") as Label).text
		_check("the card shows the sums", card.contains("+ first finish ₱10,000") and card.contains("+ clean run ₱5,000"), card)

	# the pause menu's restart is a new entry: on the Tanay Cup that's the fee
	var keep := c.finishes.duplicate()
	c.finishes = [2, 3, 0, 0, 0]
	c.event = 2
	var before := c.pesos
	var pause: Node = main.find_children("*", "", true, false).filter(func(n: Node) -> bool:
		return n.get_script() != null and (n.get_script() as Script).resource_path.ends_with("pause_menu.gd"))[0]
	Game.use_career_rig()
	pause._again(Game.stage_seed)
	_check("restarting pays the entry again", c.pesos == before - c.fee(2), c.pesos)
	await _frames(3)
	_check("and the stage comes back", await _wait_scene("main.gd"))
	main = get_tree().current_scene
	rig = main.get_node("Rig")
	var kinds: Array = rig.terrain.plan.sections.map(func(sec: Dictionary) -> String: return sec["kind"])
	_check("the Tanay Cup's own trail: bog and clay", kinds.has("bog") and kinds.has("clay"), kinds)
	c.finishes = keep
	c.event = 0
	c.pesos = before
	await _frames(30)
	rig.damage.cond["engine"] = 0.6
	Game.leave_stage()
	_check("back to the garage", await _wait_scene("garage.gd"))
	g = get_tree().current_scene
	_check("the damage came home", is_equal_approx(float(c.damage.get("engine", 1.0)), 0.6) and c.repair_cost() == 40000, c.damage)
	_check("the repairs row shows it", g._repair_act.text == "₱40,000", g._repair_act.text)
	g._repair_pick.pressed.emit()
	_check("one part at a time", g._repair_pick.text == "Repair: engine", g._repair_pick.text)
	g._repair_act.pressed.emit()
	_check("engine fixed", c.repair_cost() == 0 and c.pesos == 60000 + paid - 40000, c.pesos)

	g._event_btn.pressed.emit()
	_check("the club challenge waits on a second club run", c.event == 1 and g._drive_btn.text == "Locked", g._desc.text)
	c.finishes[0] = 2
	g._show_career()
	_check("then it's open", g._drive_btn.text == "Drive the club challenge", g._drive_btn.text)
	g._event_btn.pressed.emit()
	_check("the Tanay Cup round waits on three challenges", g._drive_btn.disabled and g._drive_btn.text == "Locked", g._desc.text)
	g._drive_btn.pressed.emit()
	await _frames(10)
	_check("a locked event doesn't start", _scene_is("garage.gd"))

	# further up: a stock Feroz isn't let into the invitational without a cage
	c.finishes = [3, 3, 3, 0, 0]
	c.event = 3
	c.pesos = 1000000
	_check("the Gera's own cage passes the invitational", c.can_enter(3))
	c.buy_rig("feroz")
	Game.use_career_rig()
	Game.to_garage(Game.stage_seed)
	await _wait_scene("garage.gd")
	g = get_tree().current_scene
	_check("a stock Feroz is turned away", g._drive_btn.disabled and g._drive_btn.text == "Not passed by the scrutineers", g._desc.text)
	c.buy("cage", "bar")
	g._show_career()
	_check("with a roll bar it's in, for the entry fee", not g._drive_btn.disabled and g._drive_btn.text.ends_with("(entry ₱15,000)"), g._drive_btn.text)
	var cash := c.pesos
	c.pesos = 10000
	g._show_career()
	_check("short of the entry, you can't go", g._drive_btn.disabled, g._drive_btn.text)
	c.pesos = cash
	c.event = 2
	Game.use_career_rig()
	_check("the Tanay Cup is run in the rainy season", Game.weather == 1 and Game.level == 1)
	Game.to_menu()
	await _wait_scene("start_menu.gd")
	_check("leaving the career puts free play's weather back", Game.weather == weather_before and not Game.in_career)
