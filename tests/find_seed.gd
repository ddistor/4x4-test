extends SceneTree
## Prints seeds whose stage holds the given section kinds:
##   godot --headless --path . --script res://tests/find_seed.gd -- pasture ridge sukal
func _init() -> void:
	var want := OS.get_cmdline_user_args()
	var found := 0
	for s in range(1, 20000):
		var plan := StagePlan.generate(s)
		var kinds := []
		for sec in plan.sections:
			kinds.append(sec["kind"])
		var ok := true
		for k in want:
			if not k in kinds:
				ok = false
		if ok:
			print(s, "  ", kinds)
			found += 1
			if found >= 3:
				break
	quit()
