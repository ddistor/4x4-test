extends SceneTree
## Tiles snaps/96_well*_<rig>.png into snaps/95_sheet_<rig>.png (4 x 2).
##   godot --headless --path . --script res://tests/contact_sheet.gd -- gera ronda ...
func _init() -> void:
	for rig in OS.get_cmdline_user_args():
		var sheet := Image.create(2560, 720, false, Image.FORMAT_RGB8)
		var i := 0
		for kind in ["96_well_", "96_wellup_"]:
			for c in ["fl", "fr", "rl", "rr"]:
				var img := Image.load_from_file(ProjectSettings.globalize_path("res://snaps/%s%s_%s.png" % [kind, c, rig]))
				if img == null:
					continue
				img.convert(Image.FORMAT_RGB8)
				img.resize(640, 360)
				sheet.blit_rect(img, Rect2i(0, 0, 640, 360), Vector2i((i % 4) * 640, (i / 4) * 360))
				i += 1
		sheet.save_png(ProjectSettings.globalize_path("res://snaps/95_sheet_%s.png" % rig))
	quit()
