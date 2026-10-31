extends Control
## The trail park's track list, after the garage: the tracks down the left,
## the one you're on previewed on the right (a map from above drawn from its
## layout, what it teaches, its obstacles in order), then drive it with the
## rig you picked.

const StartMenu := preload("res://scripts/ui/start_menu.gd")

var _buttons: Array[Button] = []
var _title: Label
var _facts: Label
var _teaches: Label
var _list: Label
var _map: MapView
var _loading: Control
var _cache := {}   # track -> its preview, rotated to lie across the screen


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var art := StartMenu.Scenery.new()
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(art)

	var left := VBoxContainer.new()
	left.position = Vector2(80, 50)
	left.add_theme_constant_override("separation", 10)
	add_child(left)
	left.add_child(UiKit.label("TRAIL PARK", 64))
	left.add_child(UiKit.label("Bakuran, Morong   ·   %s" % RigSpec.get_kind(Game.rig_kind).name, 20, UiKit.DIM))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	left.add_child(gap)
	for i in Yard.TRACKS.size():
		var t: Dictionary = Yard.TRACKS[i]
		var b := UiKit.button("%s   ·   %s" % [t["name"], t["grade"]], 460)
		b.toggle_mode = true
		b.pressed.connect(_pick.bind(i))
		b.focus_entered.connect(_pick.bind(i))
		left.add_child(b)
		_buttons.append(b)
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 14)
	left.add_child(gap2)
	var drive := UiKit.button("Drive this track", 460)
	drive.pressed.connect(_drive)
	left.add_child(drive)
	var back := UiKit.button("Back to the garage", 460)
	back.pressed.connect(func() -> void:
		if Game.in_career:
			Game.to_garage(Game.stage_seed)
		else:
			Game.to_garage(Game.stage_seed, true))
	left.add_child(back)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.box(Color(0.05, 0.04, 0.03, 0.72), 10))
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-1010, 50)
	panel.custom_minimum_size = Vector2(940, 0)
	add_child(panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	panel.add_child(pv)
	_title = UiKit.label("", 30)
	pv.add_child(_title)
	_facts = UiKit.label("", 18, UiKit.DIM)
	pv.add_child(_facts)
	_teaches = UiKit.label("", 19)
	_teaches.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_teaches.custom_minimum_size = Vector2(900, 0)
	pv.add_child(_teaches)
	_map = MapView.new()
	_map.custom_minimum_size = Vector2(900, 450)
	pv.add_child(_map)
	_list = UiKit.label("", 16, UiKit.DIM)
	_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.custom_minimum_size = Vector2(900, 0)
	pv.add_child(_list)

	_loading = ColorRect.new()
	(_loading as ColorRect).color = Color(0.03, 0.025, 0.02, 0.85)
	_loading.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading.visible = false
	var msg := UiKit.label("Building the track…", 36)
	msg.set_anchors_preset(Control.PRESET_CENTER)
	msg.position = Vector2(-170, -30)
	_loading.add_child(msg)
	add_child(_loading)

	_pick(Game.park_track)
	_buttons[Game.park_track].grab_focus()
	if "--snap-park" in OS.get_cmdline_user_args():
		_snap.call_deferred()


func _pick(i: int) -> void:
	Game.park_track = i
	for k in _buttons.size():
		_buttons[k].set_pressed_no_signal(k == i)
	var t: Dictionary = Yard.TRACKS[i]
	if not _cache.has(i):
		_cache[i] = _rotated(Yard.preview(i))
	var pv: Dictionary = _cache[i]
	_title.text = "%s" % t["name"]
	var season := "dry season" if float(t["rain"]) < 0.3 else ("rainy season" if float(t["rain"]) > 0.7 else "between the rains")
	_facts.text = "%s   ·   %s   ·   %.0f m loop   ·   %s" % [t["place"], t["grade"], pv["length"], season]
	_teaches.text = t["teaches"]
	var lines := []
	for k in (pv["marks"] as Array).size():
		var m: Dictionary = pv["marks"][k]
		lines.append("%d  %s" % [k + 1, m["name"]])
	_list.text = "Round the loop from the trailhead (the flag):   " + "    ".join(lines) + ("\nThe thin lines are the bypasses; the fords and a few others have none." if (t["obstacles"] as Array).any(func(o: Array) -> bool: return o[5] == 0) else "\nEvery obstacle has a bypass beside it (the thin line).")
	_map.show_preview(pv)


## The map lies across the screen: the park's length (z) left to right,
## the trailhead on the left.
func _rotated(pv: Dictionary) -> Dictionary:
	var src: Image = pv["image"]
	var w := src.get_height()
	var h := src.get_width()
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			img.set_pixel(x, y, src.get_pixel(y, x))
	var flip := func(p: Vector2) -> Vector2: return Vector2(p.y, p.x)
	var paths := []
	for path: PackedVector2Array in pv["paths"]:
		var q := PackedVector2Array()
		for p in path:
			q.append(flip.call(p))
		paths.append(q)
	var marks := []
	for m: Dictionary in pv["marks"]:
		marks.append({"name": m["name"], "at": flip.call(m["at"])})
	return {"texture": ImageTexture.create_from_image(img), "paths": paths, "marks": marks,
		"spawn": flip.call(pv["spawn"]), "length": pv["length"], "size": Vector2(w, h)}


func _drive() -> void:
	_loading.visible = true
	# let the card draw before the main thread goes off to build the world
	await get_tree().process_frame
	await get_tree().process_frame
	Game.to_playground()


func _snap() -> void:
	for i in Yard.TRACKS.size():
		_pick(i)
		for f in range(6):
			await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://snaps"))
		var file := "res://snaps/89_park_%d.png" % i
		get_viewport().get_texture().get_image().save_png(file)
		print("saved ", file)
	get_tree().quit()


## The track from above: the relief picture, the loop in clay, the bypasses
## thinner, a numbered marker on each obstacle and a flag at the trailhead.
class MapView:
	extends Control
	var _pv: Dictionary

	func show_preview(pv: Dictionary) -> void:
		_pv = pv
		queue_redraw()

	func _draw() -> void:
		if _pv.is_empty():
			return
		var sz: Vector2 = _pv["size"]
		var k := minf(size.x / sz.x, size.y / sz.y)
		var off := (size - sz * k) * 0.5
		draw_texture_rect(_pv["texture"], Rect2(off, sz * k), false)
		var paths: Array = _pv["paths"]
		for i in paths.size():
			var pts := PackedVector2Array()
			for p: Vector2 in paths[i]:
				pts.append(off + p * k)
			if i == 0:
				draw_polyline(pts, Color(0.1, 0.05, 0.02, 0.6), 7.0, true)
				draw_polyline(pts, Color(0.72, 0.36, 0.16), 4.0, true)
			else:
				draw_polyline(pts, Color(0.86, 0.66, 0.42, 0.9), 2.0, true)
		var font := ThemeDB.fallback_font
		var marks: Array = _pv["marks"]
		for i in marks.size():
			var c: Vector2 = off + (marks[i]["at"] as Vector2) * k
			draw_circle(c, 13.0, Color(0.1, 0.07, 0.05, 0.9))
			draw_circle(c, 11.0, Color(0.95, 0.85, 0.55))
			var s := str(i + 1)
			var tw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
			draw_string(font, c + Vector2(-tw.x * 0.5, 5.5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.1, 0.07, 0.05))
		var f: Vector2 = off + (_pv["spawn"] as Vector2) * k
		draw_line(f, f + Vector2(0, -24), Color(0.95, 0.95, 0.9), 2.0)
		draw_colored_polygon(PackedVector2Array([f + Vector2(0, -24), f + Vector2(14, -19), f + Vector2(0, -14)]), Color(0.85, 0.15, 0.1))
