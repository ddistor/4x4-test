extends Node
## Headless check of how mud builds, sets, flakes and washes on the rig:
##   godot --headless --path . res://tests/mud_test.tscn -- --seed 7
## Coats the rig as if it had churned a bog, lets it dry and set, bounces it
## to crack the crust, then drives it into the first river and back out,
## printing the mud figures at each step.

var rig: Rig
var terrain: Terrain


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	rig = main.get_node("Rig")
	terrain = main.get_node("Terrain")
	_run()


func _say(what: String) -> void:
	print("%-26s mud=%3.0f%%  corners=[%.2f %.2f %.2f %.2f]  cake=%.2f  dry=%.2f  crust=%.2f  flaked=%.2f  wash_y=%.2f washed=%.2f" % [
		what, rig.mud_amount() * 100.0, rig.corner_mud[0], rig.corner_mud[1], rig.corner_mud[2], rig.corner_mud[3],
		rig.cake, rig.dryness, rig.crust, rig.flaked, rig.wash_y, rig.washed])


## With a window (no --headless), save a picture of the rig's side to snaps/.
func _shot(name_: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	(rig.get_parent().get_node("HUD") as CanvasLayer).visible = false
	var cam: Camera3D = get_node_or_null("ShotCam")
	if cam == null:
		cam = Camera3D.new()
		cam.name = "ShotCam"
		cam.fov = 45.0
		add_child(cam)
	var r := rig.global_transform
	cam.global_position = r * Vector3(-4.2, 1.3, 1.4)
	cam.look_at(r * Vector3(0, 0.75, 0.2), Vector3.UP)
	cam.make_current()
	for i in range(4):
		await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://snaps"))
	get_viewport().get_texture().get_image().save_png("res://snaps/94_mud_%s.png" % name_)


func _wait(seconds: float) -> void:
	var n := int(seconds * Engine.physics_ticks_per_second)
	for i in range(n):
		await get_tree().physics_frame


func _run() -> void:
	await _wait(1.0)
	var river := -1.0
	for c in terrain.crossings:
		if c["stones"]:
			river = c["zc"]
			break
	# as if it had churned through a bog: plastered corners, a belly line, wet
	for i in range(4):
		rig.corner_mud[i] = 1.6
	rig.cake = 0.3
	rig.dryness = 0.0
	rig.crust = 0.0
	_say("after a bog")
	await _shot("1_wet")
	# parked a while in the sun
	Engine.time_scale = 1.0
	for k in range(6):
		await _wait(30.0)
		_say("parked %d s" % ((k + 1) * 30))
	await _shot("2_dried")
	# a few hard knocks: drop it from 0.8 m a few times
	for k in range(4):
		var t := rig.global_transform
		t.origin.y += 0.8
		rig.global_transform = t
		PhysicsServer3D.body_set_state(rig.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, t)
		await _wait(2.0)
		_say("dropped %d" % (k + 1))
	await _shot("3_flaked")
	if river < 0.0:
		print("no stony river on this seed")
		get_tree().quit()
		return
	# into the river: sit in the middle for a while, then drive out
	rig.place_on_trail(river)
	await _wait(1.5)
	for k in range(4):
		await _wait(5.0)
		_say("in the river %d s" % ((k + 1) * 5))
	Input.action_press("throttle")
	await _wait(6.0)
	Input.action_release("throttle")
	_say("out the other side")
	await _wait(4.0)
	await _shot("4_after_river")
	get_tree().quit()
