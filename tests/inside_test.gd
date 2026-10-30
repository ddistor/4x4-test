extends Node
## A muddy rig seen from inside its cab, to check nothing gets in and there
## are no holes: godot --path . res://tests/inside_test.tscn -- --rig ronda
## Saves snaps/92_inside_*.png.
var rig: Rig

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	rig = main.get_node("Rig")
	_run.call_deferred()

func _wait(s: float) -> void:
	for i in range(int(s * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame

func _run() -> void:
	await _wait(1.5)
	# plastered, as after a bog
	for i in range(4):
		rig.corner_mud[i] = 2.0
	rig.cake = 0.8
	await _wait(0.5)
	rig.set_physics_process(false)
	(rig.get_parent().get_node("HUD") as CanvasLayer).visible = false
	rig.driver.visible = false
	var cam := Camera3D.new()
	cam.fov = 80.0
	cam.near = 0.02
	add_child(cam)
	var r := rig.global_transform
	var mid_z := (rig.spec.cabin_lo.z + rig.spec.cabin_hi.z) * 0.5
	var eye_y := rig.spec.seat.y + 0.55
	var views := [
		["fwd", Vector3(0.0, eye_y, rig.spec.cabin_hi.z - 0.3), Vector3(0.0, eye_y - 0.5, rig.spec.cabin_lo.z)],
		["back", Vector3(0.0, eye_y, rig.spec.cabin_lo.z + 0.6), Vector3(0.0, eye_y - 0.6, rig.spec.cabin_hi.z)],
		["left", Vector3(0.3, eye_y, mid_z), Vector3(-1.0, eye_y - 0.7, mid_z)],
		["floor", Vector3(0.0, eye_y + 0.2, mid_z), Vector3(-0.3, rig.spec.cabin_lo.y, mid_z + 0.3)],
	]
	if rig.spec.cabin_hi.x <= 0.0:
		views = [["open", Vector3(0.6, 2.4, 0.8), Vector3(0.0, 0.7, 0.3)], ["floor", Vector3(0.0, 1.6, 0.5), Vector3(-0.2, 0.55, 0.6)]]
	# close on the left rear wheel well from inside, for holes
	var t_in := rig.spec.tire_inner()
	views.append(["arch", Vector3(-t_in + 0.45, 1.25, rig.spec.rear_z - 0.5), Vector3(-t_in - 0.05, 0.75, rig.spec.rear_z)])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://snaps"))
	for v: Array in views:
		cam.global_position = r * (v[1] as Vector3)
		cam.look_at(r * (v[2] as Vector3), r.basis.y)
		cam.make_current()
		for i in range(4):
			await RenderingServer.frame_post_draw
		var f := "res://snaps/92_inside_%s_%s.png" % [rig.spec.id, v[0]]
		get_viewport().get_texture().get_image().save_png(f)
		print("saved ", f)
	get_tree().quit()
