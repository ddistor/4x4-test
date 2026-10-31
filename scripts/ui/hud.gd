extends CanvasLayer
## Driver HUD: rig status, inclinometers, and the stage line (section, distance, clock).

@export var rig_path: NodePath

var rig: Rig
var _label: Label
var _help: Label
var _incl: Inclinometer
var _stage: Label
var _finish: Label
var _finished := false


func _ready() -> void:
	rig = get_node(rig_path) as Rig
	_label = Label.new()
	_label.position = Vector2(18, 14)
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color(0.96, 0.93, 0.86))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_label)
	_help = Label.new()
	_help.text = "W/S drive   A/D steer   Space handbrake   E/Q shift (T auto)   L diff lock   G low range   F winch   1 dig  2 boards  3 jack   -/= tires   C camera   Backspace recover   Esc pause"
	_help.add_theme_font_size_override("font_size", 15)
	_help.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8, 0.85))
	_help.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_help.position = Vector2(18, -34)
	add_child(_help)
	_incl = Inclinometer.new()
	_incl.rig = rig
	_incl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_incl.position = Vector2(-300, -170)
	_incl.size = Vector2(280, 140)
	add_child(_incl)
	_stage = Label.new()
	_stage.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage.position = Vector2(-400, 14)
	_stage.size = Vector2(800, 60)
	_style(_stage, 20)
	add_child(_stage)
	_finish = Label.new()
	_finish.set_anchors_preset(Control.PRESET_CENTER)
	_finish.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_finish.position = Vector2(-400, -120)
	_finish.size = Vector2(800, 160)
	_style(_finish, 54)
	_finish.visible = false
	add_child(_finish)


func _style(l: Label, size: int) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.96, 0.93, 0.86))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)


func _process(_delta: float) -> void:
	_label.text = rig.status_text()
	_incl.queue_redraw()
	_stage_step(_delta)


## Career: bank the event's pay (bonuses, less the marshals' fees) and say
## so, with any event it opened and the repairs waiting.
func _career_pay() -> String:
	var c := Game.career
	var e: Dictionary = Career.EVENTS[c.event]
	var r := c.finish(c.event, rig.recoveries)
	c.bank_damage(rig.damage.to_dict())
	var fix := c.repair_cost()
	_finish.add_theme_font_size_override("font_size", 32)
	_finish.position = Vector2(-700, -150)
	_finish.size = Vector2(1400, 220)
	var sums := Career.pesos_text(r["base"])
	if r["first"] > 0:
		sums += "  + first finish " + Career.pesos_text(r["first"])
	if r["clean"] > 0:
		sums += "  + clean run " + Career.pesos_text(r["clean"])
	if r["fees"] > 0:
		sums += "  - %d marshal recover%s %s" % [rig.recoveries, "y" if rig.recoveries == 1 else "ies",
			Career.pesos_text(r["fees"])]
	sums += "  =  " + Career.pesos_text(r["pay"])
	var lines := ["%s: you made it to the end." % e["name"], sums]
	if r["season_won"]:
		lines[0] = "You won the Morong Trophy: season %d is yours. Next season pays %d%% more." % [
			c.season() - 1, roundi(Career.SEASON_RAISE * 100.0 * c.trophies)]
	if not (r["opened"] as Array).is_empty():
		lines.append("Now open: " + ", ".join(r["opened"]))
	lines.append("In the bank: %s%s  ·  Esc for the garage" % [Career.pesos_text(c.pesos),
		("  ·  repairs waiting " + Career.pesos_text(fix)) if fix > 0 else ""])
	return "\n".join(lines)


## Which section you're in and how far up the trail; no clock, it's a drive.
func _stage_step(_delta: float) -> void:
	var plan := rig.terrain.plan
	var z := rig.global_position.z
	if plan.yard:
		# the practice park: which obstacle you're at, and what it's for
		var i := Yard.station_at(rig.global_position.x, z)
		if i < 0:
			_stage.text = "%s   ·   the loop\nevery obstacle has a bypass beside it" % Yard.info()["name"]
		else:
			var st: Dictionary = Yard.stations()[i]
			_stage.text = "%s   ·   %s\n%s" % [Yard.info()["name"], st["name"], st["what"]]
		return
	# the nose under the banner counts (the rig's middle is a couple of metres back)
	if not _finished and z + 2.0 > plan.finish_z:
		_finished = true
		_finish.text = "You made it to the end of the trail.\nStage %d  ·  Esc for the menu" % plan.seed_value
		if Game.in_career and Game.career.started:
			_finish.text = _career_pay()
		# it stays up: it's the end of the run, Esc takes you on from here
		_finish.visible = true
	var i := plan.index_at(z)
	_stage.text = "%d / %d   %s\n%d / %d m" % [i + 1, plan.sections.size(), StagePlan.display_name(plan.sections[i]),
		clampi(int(z), 0, int(plan.finish_z)), int(plan.finish_z)]


## Two dash inclinometers: the rig seen from behind (roll) and from the side
## (pitch). Amber as you near the tipping point, red past it.
class Inclinometer:
	extends Control
	var rig: Rig
	const ROLL_WARN := 25.0
	const ROLL_LIMIT := 35.0
	const PITCH_WARN := 30.0
	const PITCH_LIMIT := 42.0

	func _draw() -> void:
		if rig == null:
			return
		var rp := rig.roll_pitch()
		_gauge(Vector2(70, 62), rp.x, ROLL_WARN, ROLL_LIMIT, true, "ROLL")
		_gauge(Vector2(210, 62), rp.y, PITCH_WARN, PITCH_LIMIT, false, "PITCH")

	func _gauge(c: Vector2, deg: float, warn: float, limit: float, rear: bool, label: String) -> void:
		var a := absf(deg)
		var col := Color(0.92, 0.9, 0.82)
		if a > limit:
			col = Color(1.0, 0.25, 0.15)
		elif a > warn:
			col = Color(1.0, 0.7, 0.2)
		draw_circle(c, 54.0, Color(0, 0, 0, 0.45))
		draw_arc(c, 54.0, 0.0, TAU, 48, Color(1, 1, 1, 0.25), 2.0)
		# tick marks every 10 degrees, warning band marked
		for t in range(-50, 51, 10):
			var ang := deg_to_rad(float(t)) + PI * 0.5
			var d := Vector2(cos(ang), sin(ang))
			var tick_col := Color(1, 0.4, 0.2, 0.8) if absf(t) >= limit else Color(1, 1, 1, 0.5)
			draw_line(c + d * 46.0, c + d * 53.0, tick_col, 2.0)
		draw_line(c + Vector2(-50, 0), c + Vector2(50, 0), Color(1, 1, 1, 0.15), 1.0)
		var r := deg_to_rad(deg)
		var x := Transform2D(r if rear else -r, c)
		if rear:
			# body, cage and two tires seen from behind
			draw_colored_polygon(x * PackedVector2Array([Vector2(-22, -2), Vector2(22, -2), Vector2(22, -14), Vector2(-22, -14)]), col)
			draw_polyline(x * PackedVector2Array([Vector2(-17, -14), Vector2(-15, -32), Vector2(15, -32), Vector2(17, -14)]), col, 2.0)
			for sx: float in [-1.0, 1.0]:
				draw_colored_polygon(x * PackedVector2Array([Vector2(sx * 18 - 6, 14), Vector2(sx * 18 + 6, 14), Vector2(sx * 18 + 6, -6), Vector2(sx * 18 - 6, -6)]), col.darkened(0.3))
		else:
			# side view: nose to the right
			draw_colored_polygon(x * PackedVector2Array([Vector2(-30, -2), Vector2(32, -2), Vector2(32, -12), Vector2(6, -12), Vector2(4, -16), Vector2(-30, -16)]), col)
			draw_polyline(x * PackedVector2Array([Vector2(4, -16), Vector2(-6, -34), Vector2(-24, -34), Vector2(-28, -16)]), col, 2.0)
			for sx: float in [-1.0, 1.0]:
				draw_circle(x * Vector2(sx * 20, 6), 10.0, col.darkened(0.3))
		var font := get_theme_default_font()
		draw_string(font, c + Vector2(-26, 46), "%s %d°" % [label, int(round(a))], HORIZONTAL_ALIGNMENT_CENTER, 52, 13, col)
