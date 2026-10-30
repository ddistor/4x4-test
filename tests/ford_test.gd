extends Node
## Headless: water depth along each river at the trail crossing, so the ford
## (shallow riffle, deep pools up and downstream) can be checked by numbers.
##   godot --headless --path . res://tests/ford_test.tscn -- --seed 7


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var terrain: Terrain = main.get_node("Terrain")
	for c in terrain.crossings:
		var zc: float = c["zc"]
		var tx := terrain.trail_x_at(zc)
		var line := ""
		for dx in range(-20, 21, 2):
			var x := tx + dx
			# the channel meanders: sample at its middle for this x
			var z := zc + float(c["amp"]) * sin(x * float(c["freq"]) + float(c["phase"]))
			var depth := terrain.water_at(x, z) - terrain.get_height(x, z)
			line += "%5.2f" % depth
		print("%s crossing z=%.0f (trail x %.0f%s): depth every 2 m, trail -20..+20 m" % [
			"ford" if c.get("ford", false) else "plain", zc, tx,
			(", riffle at %+.1f m" % (float(c["ford_x"]) - tx)) if c.get("ford", false) else ""])
		print("   ", line)
	get_tree().quit()
