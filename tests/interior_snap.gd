extends Node
## Pictures inside a rig (needs a window): the driver's view of the dash, the
## footwell, the engine bay from under the hood, underneath. snaps/97_in_<rig>_*.png
##   godot --path . res://tests/interior_snap.tscn -- --rig ronda --rain 0
var rig: Rig
func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	rig = main.get_node("Rig")
	_run.call_deferred()
func _run() -> void:
	for i in 90:
		await get_tree().physics_frame
	rig.freeze = true
	main_hud().visible = false
	var id := rig.spec.id
	var s := rig.spec
	var l := CabinKit.layout(s)
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.02
	add_child(cam)
	cam.cull_mask = cam.cull_mask & ~2
	var b := rig.global_transform
	var eye := s.seat + Vector3(0.0, 0.62, -0.02)
	var shots := [
		["seat", eye, s.wheel_at + Vector3(0, -0.12, -0.25)],
		["feet", s.seat + Vector3(0.25, 0.45, 0.05), Vector3(s.seat.x + 0.05, float(l["floor"]) + 0.1, float(l["wall"]) + 0.2)],
		["dash", Vector3(0.25, float(l["dash"][0]) + 0.05, s.seat.z - 0.1), Vector3(s.seat.x, float(l["dash"][0]) - 0.15, float(l["dash"][1]))],
		["bay", Vector3(float(l["bay"][1]) - 0.06, float(l["bay"][2]) - 0.05, float(l["bay"][0]) + 0.12), Vector3(0, 0.6, float(l["wall"]) - 0.2)],
		["under", Vector3(1.6, 0.05, 0.3), Vector3(0, 0.4, 0.3)],
	]
	for v: Array in shots:
		# the bay shot: see through the hood
		for c in rig.get_children():
			if c is MeshInstance3D and v[0] == "bay":
				var aabb: AABB = (c as MeshInstance3D).get_aabb()
				if aabb.position.y > float(l["bay"][2]) - 0.15 and aabb.size.y < 0.4:
					(c as MeshInstance3D).visible = false
		cam.global_position = b * (v[1] as Vector3)
		cam.look_at(b * (v[2] as Vector3), b.basis.y)
		cam.make_current()
		for f in range(8):
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://snaps/97_in_%s_%s.png" % [id, v[0]])
	print("saved ", id)
	get_tree().quit()
func main_hud() -> CanvasLayer:
	return get_child(0).get_node("HUD")
