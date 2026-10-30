extends Control
## The garage, between the start menu and the stage: your rig and your driver
## on a clay pad in the late light, turning slowly (drag to spin it), with the
## choices beside it. Every change rebuilds the rig so what you see is what
## you'll drive. `--snap-garage` saves a picture and quits.

var _view: SubViewport
var _pivot: Node3D
var _cam: Camera3D
var _rig: Rig
var _name: Label
var _blurb: Label
var _loading: Control
var _yaw := 2.3
var _spin := 0.12      # rad/s while nobody is dragging
var _dragging := false
var _flex := false
var _panel: PanelContainer
## Career: the part being tried on the pad (not bought or fitted yet)
var _try_slot := ""
var _try_id := ""
var _pesos: Label
var _desc: Label
var _part_rows := {}   # slot -> [cycle button, action button]
var _event_btn: Button
var _try_rig := ""     # a rig on the pad you're looking at (owned or for sale)
var _rig_pick: Button
var _rig_act: Button
var _repair_pick: Button
var _repair_act: Button
var _sell: Button
var _sell_armed := ""   # slot + id of a part one press from being sold
var _fix_part := "all"   # what the repairs row fixes: "all" or one part
var _drive_btn: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var holder := SubViewportContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_view = SubViewport.new()
	_view.own_world_3d = true
	_view.msaa_3d = Viewport.MSAA_4X
	holder.add_child(_view)
	_build_stage()
	_rebuild()

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiKit.box(Color(0.05, 0.04, 0.03, 0.72), 10))
	_panel.position = Vector2(60, 24)
	_panel.custom_minimum_size = Vector2(500, 0)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8 if Game.in_career else 10)
	_panel.add_child(col)
	if Game.in_career:
		_career_panel(col)
	else:
		_free_panel(col)

	var hint := UiKit.label("Drag to turn the rig", 16, UiKit.DIM)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.position = Vector2(-260, -50)
	add_child(hint)

	_loading = ColorRect.new()
	(_loading as ColorRect).color = Color(0.03, 0.025, 0.02, 0.85)
	_loading.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading.visible = false
	var msg := UiKit.label("Building the stage…", 36)
	msg.set_anchors_preset(Control.PRESET_CENTER)
	msg.position = Vector2(-170, -30)
	_loading.add_child(msg)
	add_child(_loading)

	if "--snap-garage" in OS.get_cmdline_user_args():
		_snap.call_deferred()


## Free play: any rig, its look, and drive.
func _free_panel(col: VBoxContainer) -> void:
	_header(col, "GARAGE")
	col.add_child(_choice("Rig", _rig_names(), "rig_kind"))
	_look_rows(col)
	col.add_child(_flex_button())
	_gap(col)
	_drive_btn = UiKit.button("Drive stage %d" % Game.stage_seed, 460)
	_drive_btn.pressed.connect(_drive)
	col.add_child(_drive_btn)
	var back := UiKit.button("Back", 460)
	back.pressed.connect(Game.to_menu)
	col.add_child(back)
	_drive_btn.grab_focus()
	_show_names()


## Career: pick a rig to start with, or work on the one you have: parts on
## one page, the look on the other, then the event to enter.
func _career_panel(col: VBoxContainer) -> void:
	var c := Game.career
	_header(col, "CAREER")
	if not c.started:
		var hint := UiKit.label("Pick the rig you'll build up. You start with %s for parts; club events pay for the rest." % Career.pesos_text(Career.START_PESOS), 18, UiKit.DIM)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size = Vector2(460, 0)
		col.add_child(hint)
		col.add_child(_choice("Rig", _rig_names(), "rig_kind"))
		_look_rows(col)
		_gap(col)
		_drive_btn = UiKit.button("", 460)
		_drive_btn.pressed.connect(func() -> void:
			c.start(Game.rig_kind)
			Game.use_career_rig()
			Game.to_garage(Game.stage_seed))
		col.add_child(_drive_btn)
		var back := UiKit.button("Back", 460)
		back.pressed.connect(Game.to_menu)
		col.add_child(back)
		_drive_btn.grab_focus()
		_show_names()
		return
	# the rig you're working on: click to look over your others, or ones for sale
	var rig_row := HBoxContainer.new()
	rig_row.add_theme_constant_override("separation", 10)
	_rig_pick = _small("", 300)
	_rig_act = _small("", 150)
	_rig_act.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rig_pick.pressed.connect(_cycle_rig)
	_rig_act.pressed.connect(_rig_action)
	rig_row.add_child(_rig_pick)
	rig_row.add_child(_rig_act)
	col.add_child(rig_row)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	col.add_child(tabs)
	var pages := {}
	for page: String in ["Drivetrain", "Armor", "Kit", "Look"]:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		box.visible = page == "Drivetrain"
		pages[page] = box
		var tab := _small(page, 107)
		tab.alignment = HORIZONTAL_ALIGNMENT_CENTER
		tab.pressed.connect(func() -> void:
			for k: String in pages:
				(pages[k] as Control).visible = k == page)
		tabs.add_child(tab)
		col.add_child(box)
	for slot: String in Parts.SLOTS:
		if Parts.options(c.stock_spec(), slot).size() < 2:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var pick := _small("", 280)
		var act := _small("", 110)
		act.alignment = HORIZONTAL_ALIGNMENT_CENTER
		var sell := _small("Sell", 50)
		sell.alignment = HORIZONTAL_ALIGNMENT_CENTER
		sell.add_theme_font_size_override("font_size", 15)
		pick.pressed.connect(_cycle_part.bind(slot))
		act.pressed.connect(_part_action.bind(slot))
		sell.pressed.connect(_sell_part.bind(slot))
		row.add_child(pick)
		row.add_child(act)
		row.add_child(sell)
		var on := "Drivetrain" if Parts.DRIVETRAIN.has(slot) else ("Kit" if Parts.KIT_SLOTS.has(slot) else "Armor")
		(pages[on] as VBoxContainer).add_child(row)
		_part_rows[slot] = [pick, act, sell]
	_look_rows(pages["Look"])
	(pages["Look"] as VBoxContainer).add_child(_flex_button())
	# start over: press twice, it's every rig and peso gone
	var wipe := _small("Start a new career", 460)
	var armed := [false]
	wipe.pressed.connect(func() -> void:
		if not armed[0]:
			armed[0] = true
			wipe.text = "Press again: every rig and peso goes"
			return
		c.reset()
		Game.to_garage(Game.stage_seed))
	(pages["Look"] as VBoxContainer).add_child(wipe)
	# sell the rig you're on, parts and all, for 60% less its repairs
	_sell = _small("", 460)
	var sell_armed := [false]
	_sell.pressed.connect(func() -> void:
		if not sell_armed[0]:
			sell_armed[0] = true
			_sell.text = "Press again to sell it"
			return
		if c.sell_rig():
			Game.use_career_rig()
			Game.to_garage(Game.stage_seed))
	(pages["Look"] as VBoxContainer).add_child(_sell)
	_desc = UiKit.label("", 17, UiKit.DIM)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(460, 48)
	col.add_child(_desc)
	var fix_row := HBoxContainer.new()
	fix_row.add_theme_constant_override("separation", 10)
	_repair_pick = _small("", 300)
	_repair_act = _small("", 150)
	_repair_act.alignment = HORIZONTAL_ALIGNMENT_CENTER
	# click through: everything, then each worn part on its own
	_repair_pick.pressed.connect(func() -> void:
		var list := _worn()
		_fix_part = "" if list.is_empty() else list[(list.find(_fix_part) + 1) % list.size()]
		_show_career()
		var what := Damage.summary(c.damage)
		_desc.text = ("Worn or broken: " + what + ". Click again to fix one part at a time.") if what != "" else "Nothing on this rig needs fixing.")
	_repair_act.pressed.connect(func() -> void:
		if (c.repair() if _fix_part == "all" else c.repair_part(_fix_part)):
			_fix_part = "all"
			_show_career())
	fix_row.add_child(_repair_pick)
	fix_row.add_child(_repair_act)
	col.add_child(fix_row)
	_event_btn = _small("", 460)
	_event_btn.pressed.connect(func() -> void:
		c.event = (c.event + 1) % Career.EVENTS.size()
		c.save_file()
		_show_career()
		_desc.text = _event_text(c.event))
	col.add_child(_event_btn)
	_drive_btn = _small("", 460)
	_drive_btn.pressed.connect(_drive)
	col.add_child(_drive_btn)
	var back := _small("Back to the start menu", 460)
	back.pressed.connect(Game.to_menu)
	col.add_child(back)
	_drive_btn.grab_focus()
	_show_names()
	_show_career()
	if not c.seen_help:
		_help_card()


## The first time in a career garage: how it all works, in a few lines.
func _help_card() -> void:
	var c := Game.career
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.01, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.box(Color(0.07, 0.055, 0.04, 0.96), 12, UiKit.CLAY))
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.position = Vector2(-430, -290)
	card.custom_minimum_size = Vector2(860, 0)
	dim.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)
	col.add_child(UiKit.label("How the career works", 38))
	for line: String in [
		"Drive club events to earn pesos. No clock: get to the end. The first finish of each event pays half again, a run without the marshals a quarter more; each marshal recovery (Backspace) costs %s." % Career.pesos_text(Career.RECOVERY_FEE),
		"Finish an event a few times and the next one opens. The top two are run under competition rules: the scrutineers want a roll bar, then a full cage and a snorkel.",
		"Things break: the belly on rock, the steering on a rock face, axle shafts with the lockers in, the engine in deep water or with a mud-caked radiator. It stays broken till you fix it here (Repairs).",
		"Spend on parts (Drivetrain, Armor, Kit pages): click one to try it on the rig, then buy and fit it. Bigger tires need a lift. Parts stay with their rig; tires move to a rig with the same bolt pattern.",
		"Win the Morong Trophy and the season's yours: the next pays a fifth more. Buy more rigs on the Rig row."]:
		var l := UiKit.label("·  " + line, 19, UiKit.DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(820, 0)
		col.add_child(l)
	var ok := UiKit.button("Got it", 200)
	ok.alignment = HORIZONTAL_ALIGNMENT_CENTER
	ok.pressed.connect(func() -> void:
		c.seen_help = true
		c.save_file()
		dim.queue_free()
		_drive_btn.grab_focus())
	col.add_child(ok)
	ok.grab_focus()


## A garage button a little shorter than the menu's, so the career page fits.
func _small(text: String, wide: int) -> Button:
	var b := UiKit.button(text, wide)
	b.custom_minimum_size.y = 42
	b.add_theme_font_size_override("font_size", 20)
	return b


## Look at the next rig: one of yours, or one a club member is selling.
func _cycle_rig() -> void:
	var c := Game.career
	var all := RigSpec.kinds()
	var cur := Career.kind_of(_try_rig if _try_rig != "" else c.rig_id)
	_try_rig = all[(cur + 1) % all.size()].id
	_try_slot = ""
	Game.rig_kind = Career.kind_of(_try_rig)
	_show_career()
	_rebuild()


## Back to the rig you're working on.
func _end_rig_try() -> void:
	if _try_rig == "":
		return
	_try_rig = ""
	Game.rig_kind = Game.career.rig_kind()


## Switch to a rig you own, or buy the one on the pad.
func _rig_action() -> void:
	var c := Game.career
	if _try_rig == "" or _try_rig == c.rig_id:
		return
	if c.owns_rig(_try_rig):
		c.switch_rig(_try_rig)
	elif not c.buy_rig(_try_rig):
		return
	# the page is built round the rig's own parts: build it again
	Game.use_career_rig()
	Game.to_garage(Game.stage_seed)


func _show_rig_row() -> void:
	var c := Game.career
	var id := _try_rig if _try_rig != "" else c.rig_id
	var k := RigSpec.get_kind(Career.kind_of(id))
	_rig_pick.text = "Rig: " + k.name
	_rig_act.disabled = true
	if id == c.rig_id:
		_rig_act.text = "Driving"
	elif c.owns_rig(id):
		_rig_act.text = "Switch"
		_rig_act.disabled = false
	else:
		var cost: int = Career.RIG_PRICES.get(id, 0)
		_rig_act.text = Career.pesos_text(cost)
		_rig_act.disabled = cost > c.pesos
	if _try_rig != "" and _try_rig != c.rig_id:
		_desc.text = ("Yours: switch to work on it and drive it." if c.owns_rig(id)
			else "For sale as it stands, stock. Your parts stay on the rig they were fitted to.")


## The name and blurb of the rig on the pad, under a heading.
func _header(col: VBoxContainer, title: String) -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	top.add_child(UiKit.label(title, 46))
	_pesos = UiKit.label("", 30, UiKit.CLAY.lightened(0.35))
	_pesos.size_flags_vertical = Control.SIZE_SHRINK_END
	_pesos.visible = Game.in_career and Game.career.started
	top.add_child(_pesos)
	col.add_child(top)
	_name = UiKit.label("", 30)
	# in a career the rig row names it
	_name.visible = not (Game.in_career and Game.career.started)
	col.add_child(_name)
	_blurb = UiKit.label("", 18, UiKit.DIM)
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb.custom_minimum_size = Vector2(460, 0)
	col.add_child(_blurb)
	if not (Game.in_career and Game.career.started):
		_gap(col)


func _rig_names() -> Array:
	var rigs := []
	for k in RigSpec.kinds():
		rigs.append([k.name, Color(0, 0, 0, 0)])
	return rigs


func _look_rows(col: VBoxContainer) -> void:
	var prints := []
	for l: Array in Game.LOGOS:
		prints.append([l[0], Color(0, 0, 0, 0)])
	col.add_child(_choice("Paint", Game.PAINTS, "paint"))
	col.add_child(_choice("Shirt", Game.SHIRTS, "shirt"))
	col.add_child(_choice("Jorts", Game.SHORTS, "shorts"))
	col.add_child(_choice("Print", prints, "logo"))


func _flex_button() -> Button:
	var flex := UiKit.button("Suspension: at ride height", 460)
	flex.pressed.connect(func() -> void:
		_flex = not _flex
		flex.text = "Suspension: flexed (bump and droop)" if _flex else "Suspension: at ride height"
		_rig.flex = _flex)
	if "--flex" in OS.get_cmdline_user_args():
		flex.pressed.emit.call_deferred()
	return flex


func _gap(col: VBoxContainer) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	col.add_child(gap)


## Show the next option for `slot` on the pad, before you pay for it.
func _cycle_part(slot: String) -> void:
	_end_rig_try()
	var c := Game.career
	var opts := Parts.options(c.stock_spec(), slot)
	var cur := _try_id if _try_slot == slot else c.fitted_id(slot)
	_try_slot = slot
	_try_id = opts[(opts.find(cur) + 1) % opts.size()]
	_show_career()
	_rebuild()


## Sell the part shown in `slot`'s row (press twice: the first says for how much).
func _sell_part(slot: String) -> void:
	var c := Game.career
	var id := _try_id if _try_slot == slot else c.fitted_id(slot)
	var why := c.cant_sell(slot, id)
	if why != "":
		_desc.text = "Can't sell the %s: %s." % [Parts.label(slot, id).to_lower(), why]
		return
	if _sell_armed != slot + id:
		_sell_armed = slot + id
		_show_career()
		_desc.text = "Sell the %s for %s? Press Sell again." % [Parts.label(slot, id).to_lower(),
			Career.pesos_text(int(Parts.price(slot, id) * Career.SELL_PART))]
		return
	_sell_armed = ""
	c.sell_part(slot, id)
	_try_slot = ""
	_show_career()
	_rebuild()


## Fit the part being tried (buying it first if it isn't yours yet).
func _part_action(slot: String) -> void:
	var c := Game.career
	var id := _try_id if _try_slot == slot else c.fitted_id(slot)
	if Parts.blocked(c.stock_spec(), c.fitted, slot, id) != "" or id == c.fitted_id(slot):
		return
	if c.owns(slot, id):
		c.fit(slot, id)
	elif not c.buy(slot, id):
		return
	_try_slot = ""
	_show_career()
	_rebuild()


## Refresh the career panel: pesos, each part row, the event and the drive button.
func _show_career() -> void:
	var c := Game.career
	var stock := c.stock_spec()
	_pesos.text = Career.pesos_text(c.pesos)
	if c.trophies > 0:
		_pesos.text += "   season %d" % c.season()
	_desc.text = "Click a part to try the next one on the rig, then fit it."
	if _sell:
		_sell.disabled = c.rigs.size() < 2
		_sell.text = ("Sell this rig: " + Career.pesos_text(c.sell_value(c.rig_id))) if not _sell.disabled else "Sell this rig (it's your only one)"
	_show_rig_row()
	if not _worn().has(_fix_part):
		_fix_part = "all"
	var fix := c.repair_cost() if _fix_part == "all" else Damage.part_cost(c.damage, _fix_part)
	if c.repair_cost() == 0:
		_repair_pick.text = "Repairs: nothing to fix"
	elif _fix_part == "all":
		_repair_pick.text = "Repairs: all"
	else:
		_repair_pick.text = "Repair: " + (Damage.PARTS[_fix_part][0] as String).to_lower()
	_repair_act.text = Career.pesos_text(fix) if fix > 0 else "Sound"
	_repair_act.disabled = fix == 0 or fix > c.pesos
	for slot: String in _part_rows:
		var pick: Button = _part_rows[slot][0]
		var act: Button = _part_rows[slot][1]
		var sell_btn: Button = _part_rows[slot][2]
		var trying := _try_slot == slot
		var id := _try_id if trying else c.fitted_id(slot)
		pick.text = "%s: %s" % [Parts.SLOT_NAMES[slot], Parts.label(slot, id)]
		var why := Parts.blocked(stock, c.fitted, slot, id)
		var cost := Parts.price(slot, id)
		# only what you bought can go: the stock part stays
		sell_btn.modulate.a = 1.0 if (c.owned.get(slot, []) as Array).has(id) else 0.0
		sell_btn.disabled = sell_btn.modulate.a == 0.0
		act.disabled = true
		if id == c.fitted_id(slot):
			act.text = "Fitted"
		elif why != "":
			act.text = "Won't fit"
		elif c.owns(slot, id):
			act.text = "Fit"
			act.disabled = false
		else:
			act.text = Career.pesos_text(cost)
			act.disabled = cost > c.pesos
		if trying:
			_desc.text = Parts.describe(stock, slot, id)
			if why != "":
				_desc.text = "Won't fit: %s. %s" % [why, _desc.text]
			elif not c.owns(slot, id) and cost > c.pesos:
				_desc.text = "Not enough pesos yet. " + _desc.text
			elif slot == "tires" and id != c.fitted_id(slot) and c.tires_elsewhere(id) != "" \
					and not (c.owned.get("tires", []) as Array).has(id):
				_desc.text = "Yours, off the %s (same bolt pattern): they move over. %s" % [
					RigSpec.get_kind(Career.kind_of(c.tires_elsewhere(id))).name, _desc.text]
	var e: Dictionary = Career.EVENTS[c.event]
	var open := c.unlocked(c.event)
	var gear := c.gear_missing(c.event)
	var tag := ("pays " + Career.pesos_text(c.purse(c.event))) if open else "locked"
	_event_btn.text = "Event: %s, %s  %s" % [e["name"], StagePlan.DIFFICULTY[e["level"]][0], tag]
	var idle := _try_slot == "" and (_try_rig == "" or _try_rig == c.rig_id)
	if not open:
		_drive_btn.text = "Locked"
		if idle:
			_desc.text = "To enter the %s: %s." % [(e["name"] as String).to_lower(), c.lock_reason(c.event)]
	elif gear != "":
		_drive_btn.text = "Not passed by the scrutineers"
		if idle:
			_desc.text = "Competition rules: the scrutineers say this rig %s (Armor page)." % gear
	elif c.pesos < c.fee(c.event):
		_drive_btn.text = "Entry %s: not enough pesos" % Career.pesos_text(c.fee(c.event))
		if idle:
			_desc.text = "Run an easier event for the entry money."
	else:
		_drive_btn.text = "Drive the " + (e["name"] as String).to_lower()
		if c.fee(c.event) > 0:
			_drive_btn.text += " (entry %s)" % Career.pesos_text(c.fee(c.event))
	_drive_btn.disabled = not c.can_enter(c.event)


## The worn parts of the current rig, with "all" first.
func _worn() -> Array:
	var out := []
	for k: String in Damage.PARTS:
		if Damage.part_cost(Game.career.damage, k) > 0:
			out.append(k)
	if not out.is_empty():
		out.push_front("all")
	return out


## One event, for the line under the parts.
func _event_text(e: int) -> String:
	var c := Game.career
	var ev: Dictionary = Career.EVENTS[e]
	var t := "%s trail, %s. Pays %s, +%d%% the first time you finish it, +%d%% with no marshals." % [
		StagePlan.DIFFICULTY[ev["level"]][0], "rainy season" if ev["weather"] == 1 else "dry or wet as it comes",
		Career.pesos_text(c.purse(e)), roundi(Career.FIRST_BONUS * 100.0), roundi(Career.CLEAN_BONUS * 100.0)]
	if c.fee(e) > 0:
		t += " Entry %s." % Career.pesos_text(c.fee(e))
	if ev.has("cage"):
		t += " Run under competition rules: %s%s." % ["a full cage" if ev["cage"] >= 2 else "a roll bar",
			" and a snorkel" if ev.get("snorkel", false) else ""]
	t += " Finished %d times." % c.finishes[e]
	return t


## What goes on the pad: the fitted parts, plus the one being tried if it fits.
func _preview_parts() -> Variant:
	if not (Game.in_career and Game.career.started):
		return null
	var c := Game.career
	if _try_rig != "" and _try_rig != c.rig_id:
		# another rig: as it stands in your shed, or as it comes
		return (c.rigs.get(_try_rig, {}) as Dictionary).get("fitted", {})
	var fit := c.fitted.duplicate()
	if _try_slot != "" and Parts.blocked(c.stock_spec(), c.fitted, _try_slot, _try_id) == "":
		fit[_try_slot] = _try_id
	return fit


## Light, sky and a clay pad for the rig to stand on.
func _build_stage() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.5, 0.68)
	sky_mat.sky_horizon_color = Color(0.66, 0.66, 0.64)
	sky_mat.ground_horizon_color = Color(0.5, 0.4, 0.3)
	sky_mat.ground_bottom_color = Color(0.2, 0.15, 0.1)
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.6, 0.58, 0.55)
	env.fog_density = 0.004
	var we := WorldEnvironment.new()
	we.environment = env
	_view.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.92, 0.8)
	sun.light_energy = 2.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	_pivot = Node3D.new()
	_view.add_child(_pivot)
	# the sun turns with the camera: always over the viewer's shoulder
	sun.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(30.0), 0)
	_pivot.add_child(sun)
	var pad := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 7.0
	disc.bottom_radius = 7.0
	disc.height = 0.1
	disc.radial_segments = 64
	pad.mesh = disc
	pad.position = Vector3(0, -0.05, 0)
	var clay := StandardMaterial3D.new()
	clay.albedo_color = Color(0.3, 0.16, 0.1)
	clay.roughness = 0.95
	pad.material_override = clay
	_view.add_child(pad)
	_cam = Camera3D.new()
	_cam.fov = 38.0
	_pivot.add_child(_cam)
	_cam.position = Vector3(0, 2.1, 7.6)
	# aim left of the rig so it stands in the open right of the screen
	_cam.look_at(Vector3(-1.5, 0.95, 0), Vector3.UP)
	_cam.current = true


## Throw away the shown rig and build the one Game says, standing on the pad.
func _rebuild() -> void:
	if _rig:
		_rig.queue_free()
	_rig = Rig.new()
	_rig.name = "PreviewRig"
	_rig.parts = _preview_parts()
	_view.add_child(_rig)
	# hubs ride ~0.05 m above the body origin in the preview pose (lower on a lift)
	_rig.position = Vector3(0, _rig.spec.tire_radius - 0.05 + _rig.spec.lift, 0)
	_rig.driver.snap()
	_rig.flex = _flex
	if _name:
		_show_names()


func _show_names() -> void:
	var s := RigSpec.get_kind(Game.rig_kind)
	_name.text = s.name
	_blurb.text = s.blurb
	if Game.in_career and Game.career.started and _rig and _rig.spec.tire_radius != s.tire_radius:
		# what's fitted, not what it came on
		var size := roundi(_rig.spec.tire_radius * 2.0 / 0.0254)
		var re := RegEx.create_from_string("on \\d\\ds")
		_blurb.text = re.sub(s.blurb, "now on %ds" % size)
	if Game.in_career and Game.career.started and _rig and _rig.spec.cage > s.cage:
		_blurb.text = _blurb.text.replace("roll bar", "full cage")
	if Game.in_career and not Game.career.started:
		_drive_btn.text = "Start the career in the " + s.name


func _choice(what: String, choices: Array, key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var b := UiKit.button("", 360)
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(30, 46)
	var show := func() -> void:
		var c: Array = choices[Game.get(key)]
		b.text = "%s: %s" % [what, c[0]]
		swatch.color = c[1]
	show.call()
	b.pressed.connect(func() -> void:
		Game.set(key, (int(Game.get(key)) + 1) % choices.size())
		Game.save_look()
		show.call()
		_show_names()
		_rebuild())
	row.add_child(b)
	row.add_child(swatch)
	return row


func _process(delta: float) -> void:
	if not _dragging:
		_yaw += _spin * delta
	_pivot.rotation.y = _yaw


func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		var over_ui: bool = _panel.get_global_rect().has_point(mb.position)
		_dragging = mb.pressed and not over_ui
	var mm := event as InputEventMouseMotion
	if mm and _dragging:
		_yaw -= mm.relative.x * 0.008


func _drive() -> void:
	if Game.in_career:
		if Game.career.started and not Game.career.enter(Game.career.event):
			return
		Game.use_career_rig()
	_loading.visible = true
	# let the card draw before the main thread goes off to build the world
	await get_tree().process_frame
	await get_tree().process_frame
	Game.start_stage(Game.stage_seed)


func _snap() -> void:
	_spin = 0.0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://snaps"))
	# the usual view, then (with --flex) round the rig to check the tires clear
	var yaws := [[_yaw, "95_career" if Game.in_career else "95_garage"]]
	if _flex:
		var id := RigSpec.get_kind(Game.rig_kind).id
		yaws = [[2.3, "95_flex_front_" + id], [1.57, "95_flex_side_" + id], [-2.3, "95_flex_rear_" + id]]
	for y: Array in yaws:
		_yaw = y[0]
		for i in range(30):
			await RenderingServer.frame_post_draw
		var path := "res://snaps/%s.png" % y[1]
		get_viewport().get_texture().get_image().save_png(path)
		print("saved ", ProjectSettings.globalize_path(path))
	get_tree().quit()
