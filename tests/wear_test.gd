extends Node
## Ground and rig reacting to driving: circles on the practice yard's grass
## for 40 s, then prints how worn the ground under the circle is and how much
## dust the rig picked up; with a window (xvfb-run) it saves pictures of the
## worn ring from above and the rig close up (snaps/93_wear_*.png).
##   godot --path . res://tests/wear_test.tscn [-- --rig gera]
var rig: Rig
var terrain: Terrain
var main: Node


func _ready() -> void:
	Game.playground = true
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	rig = main.get_node("Rig")
	terrain = main.get_node("Terrain")
	_run.call_deferred()


func _wait(s: float) -> void:
	for i in range(int(s * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame


func _run() -> void:
	await _wait(1.0)
	# out on the open meadow inside the loop
	rig.place_at(Yard.MEADOW.x, Yard.MEADOW.y - 8.0, Vector3.BACK)
	await _wait(1.5)
	var start := rig.global_position
	# no drawing while it drives (a software display would take an age)
	RenderingServer.render_loop_enabled = false
	Input.action_press("throttle", 0.55)
	Input.action_press("steer_left", 0.6)
	await _wait(40.0)
	Input.action_release("throttle")
	Input.action_release("steer_left")
	await _wait(2.0)
	# how worn the ground is along where it drove (sample a ring of cells near the rig's track)
	var worn := 0.0
	var n := 0
	var c := Vector2(start.x, start.z)
	var mud := terrain.mud
	for i in range(mud.wear.size()):
		if mud.wear[i] > 0.05:
			worn += mud.wear[i]
			n += 1
	print("worn cells %d, mean wear %.2f" % [n, worn / maxf(n, 1)])
	print("corner dust %s  (0 clean .. 0.6 dusty, 2 plastered)" % [rig.corner_mud])
	print("RESULT ", "PASS" if n > 200 and rig.corner_mud.max() > 0.1 else "FAIL")
	RenderingServer.render_loop_enabled = true
	if DisplayServer.get_name() != "headless":
		(main.get_node("HUD") as CanvasLayer).visible = false
		var cam := Camera3D.new()
		main.add_child(cam)
		var p := rig.global_position
		for v: Array in [["93_wear_above", p + Vector3(0, 22, -14), p + Vector3(0, 0, 4)],
				["93_wear_ground", p + Vector3(-6, 2.2, -6), p + Vector3(0, 0, 3)],
				["93_wear_rig", p + Vector3(3.5, 1.4, 3.5), p + Vector3(0, 0.7, 0)]]:
			cam.global_position = v[1]
			cam.look_at(v[2], Vector3.UP)
			cam.make_current()
			for f in range(6):
				await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://snaps/%s.png" % v[0])
			print("saved ", v[0])
	get_tree().quit()
