extends Node
## What the tires feel on each kind of section, sampled along the wheel lines:
##   godot --headless --path . res://tests/surface_table.tscn -- --seed 7 [--weather dry|rain]
## friction (as wheel.gd works it out before any sinking), soft mud depth,
## wetness, water depth.
func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var t: Terrain = main.get_node("Terrain")
	print("season ", t.plan.season())
	for s in t.plan.sections:
		var mus := []
		var soft := 0.0
		var wet := 0.0
		var water := 0.0
		var n := 0
		var z: float = float(s["z0"]) + 20.0
		while z < float(s["z1"]) - 20.0:
			for side: float in [-0.8, 0.8]:
				var x := t.trail_x_at(z) + side
				var g := t.ground_sample(Vector3(x, 0, z))
				var room: float = maxf(0.0, float(g["thickness"]) - float(g["rut"]))
				var w: float = g["wetness"]
				var sk := smoothstep(0.03, 0.2, room + float(g["rut"]))
				var mu := lerpf(0.92, 0.3, w) * (1.0 - 0.15 * sk) * float(g["grip"])
				mus.append(mu)
				soft += room
				wet += w
				water += float(g["water_depth"])
				n += 1
			z += 2.0
		mus.sort()
		print("%-8s mu median %.2f (10%% %.2f, 90%% %.2f)  soft %.2f m  wet %.2f  water %.2f m" % [s["kind"],
			mus[mus.size() / 2], mus[mus.size() / 10], mus[mus.size() * 9 / 10], soft / n, wet / n, water / n])
	get_tree().quit()
