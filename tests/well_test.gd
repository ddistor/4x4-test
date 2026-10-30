extends Node
## Every rig: does any body part reach into the space a tire sweeps (from
## full droop to the bump stop, across its width)? Anything in there is seen
## through the wheel arch as a hole, and the tire would hit it. Samples
## points across every triangle, not just corners.
##   godot --headless --path . res://tests/well_test.tscn
func _ready() -> void:
	var bad := 0
	for k in range(RigSpec.kinds().size()):
		for fit: Dictionary in _builds(RigSpec.get_kind(k)):
			bad += await _check(k, fit)
	print("RESULT ", "PASS" if bad == 0 else "FAIL")
	get_tree().quit()


## Stock, and each lift with the biggest tires that fit under it and all the
## armor (career parts).
func _builds(stock: RigSpec) -> Array[Dictionary]:
	var out: Array[Dictionary] = [{}]
	for lift: String in Parts.options(stock, "lift"):
		var best := ""
		for t: String in Parts.options(stock, "tires"):
			if t.ends_with("_mt") and Parts.blocked(stock, {"lift": lift}, "tires", t) == "":
				best = t
		# and every bit of armor bolted on (it mustn't reach into a tire either)
		out.append({"lift": lift, "tires": best, "skid": "steel", "sliders": "steel", "cage": "full", "snorkel": "snorkel"})
	return out


## How many body parts reach into the tire's space on rig `k` with `fit` on.
func _check(k: int, fit: Dictionary) -> int:
	var bad := 0
	Game.rig_kind = k
	var rig := Rig.new()
	rig.preview = true
	add_child(rig)
	var s := rig.spec
	var r_well := s.max_tire_top() - RigSpec.RIDE_HUB_Y
	var x_in := s.track - s.tire_width * 0.5
	var x_out := s.track + s.tire_width * 0.5
	var found := {}   # part -> [count, example]
	var idx := 0
	for child in rig.get_children():
		if not child is MeshInstance3D:
			continue
		var mi := child as MeshInstance3D
		idx += 1
		if mi.mesh == null:
			continue
		for surf in range(mi.mesh.get_surface_count()):
			var arr := mi.mesh.surface_get_arrays(surf)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ind = arr[Mesh.ARRAY_INDEX]
			var tri := PackedVector3Array()
			if ind != null and (ind as PackedInt32Array).size() > 0:
				for i in ind:
					tri.append(verts[i])
			else:
				tri = verts
			var mat := mi.mesh.surface_get_material(surf)
			var col := ""
			if mat is ShaderMaterial and (mat as ShaderMaterial).get_shader_parameter("paint") != null:
				col = str((mat as ShaderMaterial).get_shader_parameter("paint"))
			elif mat is StandardMaterial3D:
				col = str((mat as StandardMaterial3D).albedo_color)
			var part := "mesh#%d %s" % [idx, col]
			for t in range(0, tri.size() - 2, 3):
				var a: Vector3 = mi.transform * tri[t]
				var b: Vector3 = mi.transform * tri[t + 1]
				var c: Vector3 = mi.transform * tri[t + 2]
				for u in range(7):
					for w in range(7 - u):
						var p := a + (b - a) * (u / 6.0) + (c - a) * (w / 6.0)
						if absf(p.x) < x_in + 0.01 or absf(p.x) > x_out - 0.01 or p.y < s.ride_hub_y():
							continue
						for zc in [s.front_z, s.rear_z]:
							# the tire is a disc sliding from full droop up to the bump stop
							var hub_y := s.ride_hub_y() + clampf(p.y - s.ride_hub_y(), -s.droop, s.bump)
							if Vector2(p.z - zc, p.y - hub_y).length() < s.tire_radius + 0.01:
								if not found.has(part):
									found[part] = [0, p, AABB(p, Vector3.ZERO)]
								found[part][0] += 1
								found[part][2] = (found[part][2] as AABB).expand(p)
	var line := "OK"
	if not found.is_empty():
		line = ""
		for part in found:
			var bb: AABB = found[part][2]
			line += "\n    %s: %d points, x %.2f..%.2f y %.2f..%.2f z %.2f..%.2f" % [part, found[part][0],
				bb.position.x, bb.end.x, bb.position.y, bb.end.y, bb.position.z, bb.end.z]
	print("%-10s %-28s %s" % [s.id, " ".join([fit.get("lift", ""), fit.get("tires", "")]), line])
	bad += found.size()
	rig.queue_free()
	await get_tree().process_frame
	return bad
