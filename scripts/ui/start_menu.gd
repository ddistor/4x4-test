extends Control
## Start menu: pick a stage and go. The panel on the right previews the stage
## the seed will build (sections, places, lengths); Reroll draws a new one,
## or type a seed to replay a stage. Building the stage takes a few seconds,
## so a "building" card goes up first.

var _seed_edit: LineEdit
var _preview: Label
var _title: Label
var _loading: Control
var _drive: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if "--snap" in OS.get_cmdline_user_args():
		Game.start_stage.call_deferred(Game.stage_seed)
		return

	var art := Scenery.new()
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(art)

	var left := VBoxContainer.new()
	left.position = Vector2(80, 90)
	left.add_theme_constant_override("separation", 12)
	add_child(left)
	var title := UiKit.label("PUTIK", 128)
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	left.add_child(title)
	left.add_child(UiKit.label("4x4 trail runs from Morong, Rizal and on up the islands", 22, UiKit.DIM))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	left.add_child(gap)

	_drive = UiKit.button("Drive this stage")
	_drive.pressed.connect(_start)
	left.add_child(_drive)
	var reroll := UiKit.button("Reroll the stage")
	reroll.pressed.connect(func() -> void: _show_seed(Game.random_seed()))
	left.add_child(reroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var seed_label := UiKit.label("Seed", 20, UiKit.DIM)
	seed_label.custom_minimum_size = Vector2(60, 0)
	seed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(seed_label)
	_seed_edit = LineEdit.new()
	_seed_edit.custom_minimum_size = Vector2(250, 46)
	_seed_edit.add_theme_font_size_override("font_size", 22)
	_seed_edit.add_theme_color_override("font_color", UiKit.TEXT)
	_seed_edit.add_theme_stylebox_override("normal", UiKit.box(Color(0.06, 0.05, 0.04, 0.62)))
	_seed_edit.add_theme_stylebox_override("focus", UiKit.box(Color(0.06, 0.05, 0.04, 0.8), 6, UiKit.CLAY))
	_seed_edit.text_changed.connect(func(t: String) -> void:
		if t.is_valid_int():
			_preview_seed(int(t)))
	_seed_edit.text_submitted.connect(func(_t: String) -> void: _start())
	row.add_child(_seed_edit)
	left.add_child(row)
	var weather := UiKit.button("")
	var names := {-1: "Weather: random", 0: "Weather: dry season", 1: "Weather: rainy season"}
	weather.text = names[Game.weather]
	weather.pressed.connect(func() -> void:
		Game.weather = (Game.weather + 2) % 3 - 1  # random -> dry -> rainy -> random
		weather.text = names[Game.weather]
		if _seed_edit.text.is_valid_int():
			_preview_seed(int(_seed_edit.text)))
	left.add_child(weather)
	var trail := UiKit.button("")
	trail.text = "Trail: " + StagePlan.DIFFICULTY[Game.level][0]
	trail.pressed.connect(func() -> void:
		Game.level = (Game.level + 1) % 3  # hard -> extreme -> moderate -> hard
		trail.text = "Trail: " + StagePlan.DIFFICULTY[Game.level][0]
		if _seed_edit.text.is_valid_int():
			_preview_seed(int(_seed_edit.text)))
	left.add_child(trail)
	var rigs := []
	for k in RigSpec.kinds():
		rigs.append([k.name, Color(0, 0, 0, 0)])
	left.add_child(_look_button("Rig", rigs, "rig_kind"))
	left.add_child(_look_button("Rig paint", Game.PAINTS, "paint"))
	left.add_child(_look_button("Shirt", Game.SHIRTS, "shirt"))
	left.add_child(_look_button("Jorts", Game.SHORTS, "shorts"))
	var quit := UiKit.button("Quit")
	quit.pressed.connect(func() -> void: get_tree().quit())
	left.add_child(quit)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.box(Color(0.05, 0.04, 0.03, 0.66), 10))
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-640, 120)
	panel.custom_minimum_size = Vector2(560, 0)
	add_child(panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	panel.add_child(pv)
	_title = UiKit.label("", 26)
	pv.add_child(_title)
	_preview = UiKit.label("", 19, UiKit.DIM)
	pv.add_child(_preview)

	var help := UiKit.label("W/S drive   A/D steer   G low range   L diff lock   F winch   -/= tire pressure   Backspace recover   Esc pause", 16, UiKit.DIM)
	help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help.position = Vector2(80, -60)
	add_child(help)

	_loading = ColorRect.new()
	(_loading as ColorRect).color = Color(0.03, 0.025, 0.02, 0.85)
	_loading.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading.visible = false
	var msg := UiKit.label("Building the stage…", 36)
	msg.set_anchors_preset(Control.PRESET_CENTER)
	msg.position = Vector2(-170, -30)
	_loading.add_child(msg)
	add_child(_loading)

	_show_seed(Game.stage_seed)
	_drive.grab_focus()


## A button that cycles one of Game's colour choices, with a swatch beside it.
func _look_button(what: String, choices: Array, key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var b := UiKit.button("")
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(46, 46)
	var show := func() -> void:
		var c: Array = choices[Game.get(key)]
		b.text = "%s: %s" % [what, c[0]]
		swatch.color = c[1]
	show.call()
	b.pressed.connect(func() -> void:
		Game.set(key, (int(Game.get(key)) + 1) % choices.size())
		Game.save_look()
		show.call())
	row.add_child(b)
	row.add_child(swatch)
	return row


func _show_seed(s: int) -> void:
	_seed_edit.text = str(s)
	_preview_seed(s)


func _preview_seed(s: int) -> void:
	var plan := StagePlan.generate(s, Game.weather, Game.level)
	_title.text = "Stage %d   ·   %.1f km" % [s, plan.length / 1000.0]
	_preview.text = plan.describe()


func _start() -> void:
	var t := _seed_edit.text
	var s := int(t) if t.is_valid_int() else Game.random_seed()
	_loading.visible = true
	# let the card draw before the main thread goes off to build the world
	await get_tree().process_frame
	await get_tree().process_frame
	Game.start_stage(s)


## The menu backdrop, painted in code: hazy late-afternoon sky, ridgelines
## of the Sierra Madre fading into the distance, paddies catching the light
## and a red clay track climbing away. Clouds drift.
class Scenery:
	extends Control
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var s := size
		# sky: warm at the horizon, blue-grey overhead
		var sky := PackedColorArray([Color(0.42, 0.55, 0.66), Color(0.42, 0.55, 0.66), Color(0.93, 0.8, 0.62), Color(0.93, 0.8, 0.62)])
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, s.y * 0.62), Vector2(0, s.y * 0.62)]), sky)
		draw_circle(Vector2(s.x * 0.72, s.y * 0.4), s.y * 0.05, Color(1.0, 0.93, 0.78, 0.9))
		draw_circle(Vector2(s.x * 0.72, s.y * 0.4), s.y * 0.11, Color(1.0, 0.9, 0.7, 0.15))
		# clouds: soft drifting blobs
		# many faint overlapping puffs in a flattened bank read as cloud, not bubbles
		for k in range(7):
			var cx := fposmod(k * 397.0 + _t * (5.0 + k), s.x + 800.0) - 400.0
			var cy := s.y * (0.07 + 0.045 * (k % 4))
			draw_set_transform(Vector2(cx, cy), 0.0, Vector2(1.0, 0.45))
			for b in range(26):
				var u := b / 26.0
				var off := Vector2((u - 0.5) * 340.0 + sin(b * 7.3 + k) * 30.0, cos(b * 3.1 + k) * 40.0 * sin(PI * u))
				draw_circle(off, 30.0 + 40.0 * sin(PI * u) * (0.6 + 0.4 * sin(b * 2.7)), Color(1, 0.97, 0.93, 0.05))
		draw_set_transform(Vector2.ZERO)
		# ridgelines, far to near: bluer and paler with distance
		var ridges := [
			[0.42, Color(0.47, 0.56, 0.6), 0.6, 1.0],
			[0.48, Color(0.33, 0.43, 0.4), 0.9, 2.3],
			[0.55, Color(0.2, 0.3, 0.2), 1.1, 3.7],
			[0.62, Color(0.12, 0.2, 0.1), 0.8, 5.1],
		]
		for r: Array in ridges:
			var pts := PackedVector2Array()
			pts.append(Vector2(0, s.y))
			var n := 80
			for i in range(n + 1):
				var x := s.x * i / n
				var u := float(i) / n
				var h := sin(u * 7.0 * r[2] + r[3]) * 0.05 + sin(u * 17.0 + r[3] * 3.0) * 0.02 + sin(u * 41.0 + r[3]) * 0.006
				pts.append(Vector2(x, s.y * (float(r[0]) - h - 0.06 * smoothstep(0.3, 1.0, u))))
			pts.append(Vector2(s.x, s.y))
			draw_colored_polygon(pts, r[1])
		# paddies: flat water in bands, the light catching it
		var top := s.y * 0.66
		draw_rect(Rect2(0, top, s.x, s.y - top), Color(0.18, 0.26, 0.12))
		for i in range(14):
			var y := top + pow(i / 14.0, 1.6) * (s.y - top)
			var hgt := 3.0 + i * 3.0
			draw_rect(Rect2(0, y, s.x, hgt), Color(0.62, 0.66, 0.55, 0.22 - i * 0.012))
			draw_line(Vector2(0, y + hgt), Vector2(s.x, y + hgt), Color(0.25, 0.32, 0.12, 0.8), 2.0 + i * 0.5)
		# the clay track running up into the hills
		var track := PackedVector2Array()
		var right := PackedVector2Array()
		for i in range(31):
			var u := i / 30.0
			var y := lerpf(s.y, s.y * 0.6, pow(u, 0.7))
			var x := s.x * (0.52 + 0.14 * sin(u * 5.0) * (1.0 - u * 0.5))
			var w := lerpf(s.x * 0.16, 4.0, pow(u, 0.6))
			track.append(Vector2(x - w, y))
			right.append(Vector2(x + w, y))
		right.reverse()
		track.append_array(right)
		draw_colored_polygon(track, Color(0.52, 0.22, 0.09))
		# wheel ruts in the near track
		for side: float in [-0.45, 0.45]:
			var rut := PackedVector2Array()
			for i in range(16):
				var u := i / 30.0
				var y := lerpf(s.y, s.y * 0.6, pow(u, 0.7))
				var x := s.x * (0.52 + 0.14 * sin(u * 5.0) * (1.0 - u * 0.5))
				rut.append(Vector2(x + side * lerpf(s.x * 0.16, 4.0, pow(u, 0.6)), y))
			draw_polyline(rut, Color(0.3, 0.12, 0.05, 0.85), 10.0)
		# shade the left so the menu reads
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.55, 0), Vector2(s.x * 0.55, s.y), Vector2(0, s.y)]),
			PackedColorArray([Color(0, 0, 0, 0.55), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.55)]))
