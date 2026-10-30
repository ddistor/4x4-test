extends Node
## Stones per section and how far they stand proud of the ground:
##   godot --headless --path . res://tests/rock_count.tscn -- --seed 4
func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var t: Terrain = main.get_node("Terrain")
	for s in t.plan.sections:
		var n := 0
		var proud := 0.0
		for r in t.rock_spots:
			if r.z > float(s["z0"]) and r.z < float(s["z1"]) and absf(r.x - t.trail_x_at(r.z)) < 3.0:
				n += 1
				proud += r.y + r.w * 0.5 - t.get_height(r.x, r.z)
		print("%-8s on-trail stones %4d  avg top above ground %.2f m" % [s["kind"], n, proud / maxf(n, 1)])
	get_tree().quit()
