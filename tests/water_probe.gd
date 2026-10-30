extends Node
## Prints the water bodies covering a z: godot --headless --path . res://tests/water_probe.tscn -- --seed 7 --z 600
func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var t: Terrain = main.get_node("Terrain")
	var a := OS.get_cmdline_user_args()
	var z := float(a[a.find("--z") + 1])
	print("section ", t.plan.section_at(z)["kind"], "  level_at ", t.water_level_at(z))
	for b in t.water_bodies:
		if z > float(b["z_lo"]) - 5.0 and z < float(b["z_hi"]) + 5.0:
			print("  body z %.0f-%.0f level %.2f %s" % [b["z_lo"], b["z_hi"], b["level"], "crossing" if b.has("crossing") else ("stream" if b.has("stream") else "band")])
	var x := t.trail_x_at(z)
	for dx in [-1.0, 0.0, 1.0]:
		print("  x%+.0f ground %.2f water %.2f mask %s" % [dx, t.get_height(x + dx, z), t.water_at(x + dx, z), t.water_mask_at(x + dx, z)])
	get_tree().quit()
