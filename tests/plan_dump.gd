extends SceneTree
## Prints a stage's sections and pitches: godot --headless --path . --script res://tests/plan_dump.gd -- 9
func _init() -> void:
	var plan := StagePlan.generate(int(OS.get_cmdline_user_args()[0]))
	for s in plan.sections:
		var ps := []
		for p in s["pitches"]:
			ps.append("z%.0f len %.0f (%.0f%% avg)" % [p[0], p[1], 100.0 * float(p[2]) * absf(float(s["h1"]) - float(s["h0"])) / float(p[1])])
		print("%-8s z %4.0f-%4.0f  h %5.1f -> %5.1f  %s" % [s["kind"], s["z0"], s["z1"], s["h0"], s["h1"], ps])
	for z in range(150, 300, 5):
		print("z=%d floor %.2f grade %+.0f%%" % [z, plan.profile(z), 100.0 * (plan.profile(z + 1.0) - plan.profile(z - 1.0)) / 2.0])
	quit()
