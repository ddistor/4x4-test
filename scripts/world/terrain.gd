class_name Terrain
extends Node3D
## Procedural "Morong uplands" trail segment.
##
## Layout (looking along +Z):
##   z   0 ..  45  barangay road beside flooded rice paddies (flat, firm)
##   z  45 .. 100  first climb into the laterite foothills, cut two-track with banks
##   z 100 .. 125  creek crossing in a dip (water, saturated mud both sides)
##   z 125 .. 250  steeper climb toward the Sierra Madre side, deep rutted clay
##
## The physics collider is the firm base. The visual mesh sits on top and is
## displaced downward in the vertex shader by the rut channel of the MudField
## texture, so ruts show without rebuilding the mesh.

const SIZE_M := 256.0
const CELL := 0.5
const RES := int(SIZE_M / CELL)  # 512

@export var seed_value: int = 7

var mud: MudField
var heights: PackedFloat32Array  # (RES+1)^2 firm base heights
var trail_center: PackedFloat32Array  # x of trail centre for every 1 m of z
var tree_anchors: Array[Vector3] = []

var _mesh_instance: MeshInstance3D
var _noise: FastNoiseLite
var _detail: FastNoiseLite

const WATER_PADDY := 0.15
const CREEK_Z := 112.0
const CREEK_LEVEL_OFFSET := -0.9  # water surface relative to trail floor at the creek


func _ready() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = seed_value
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.012
	_noise.fractal_octaves = 4
	_detail = FastNoiseLite.new()
	_detail.seed = seed_value + 1
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail.frequency = 0.09

	mud = MudField.new(RES, RES, CELL, Vector2(0.0, 0.0))
	_build_trail_centre()
	_build_heights()
	_author_mud()
	mud.bake_image()
	_build_mesh()
	_build_collision()
	_build_water()
	_build_trees()


# --- Authoring ---------------------------------------------------------------

func trail_x_at(z: float) -> float:
	var i := clampi(int(z), 0, trail_center.size() - 2)
	var t := clampf(z - i, 0.0, 1.0)
	return lerpf(trail_center[i], trail_center[i + 1], t)


func _build_trail_centre() -> void:
	trail_center.resize(int(SIZE_M) + 1)
	for z in range(trail_center.size()):
		var zf := float(z)
		# Gentle S-curves, tighter switchbacks on the upper climb.
		var x := SIZE_M * 0.5
		x += 14.0 * sin(zf * 0.035)
		if zf > 140.0:
			x += 18.0 * sin((zf - 140.0) * 0.07)
		x += 3.0 * _detail.get_noise_1d(zf * 2.0)
		trail_center[z] = x


func _climb_profile(z: float) -> float:
	# Base elevation along the trail (metres).
	if z < 45.0:
		return 0.0
	var h := 0.0
	# first climb
	h += smoothstep(45.0, 100.0, z) * 9.0
	# creek dip
	h -= 1.6 * exp(-pow((z - CREEK_Z) / 7.0, 2.0))
	# second, steeper climb
	h += smoothstep(125.0, 250.0, z) * 32.0
	return h


func _base_height(x: float, z: float) -> float:
	var tx := trail_x_at(z)
	var dx := absf(x - tx)
	var trail_h := _climb_profile(z)
	# Surrounding land: hills rising away from the trail, more so uphill.
	var land := trail_h + (_noise.get_noise_2d(x, z) * 0.5 + 0.5) * 6.0 * smoothstep(40.0, 120.0, z)
	land += _detail.get_noise_2d(x, z) * 0.6
	if z < 45.0:
		# Paddies: flat terraces either side of the road.
		land = -0.35 + _detail.get_noise_2d(x, z) * 0.05
		# pilapil: the low earth dikes between paddies, on a rough 14 x 18 m grid
		var gx := absf(fposmod(x + 3.0, 14.0) - 7.0)
		var gz := absf(fposmod(z + 5.0, 18.0) - 9.0)
		var dike := maxf(1.0 - smoothstep(0.3, 0.9, gx), 1.0 - smoothstep(0.3, 0.9, gz))
		land += dike * 0.45
		# road shoulder slopes down into the paddy over 1.5 m
		return lerpf(0.0, land, smoothstep(3.2, 4.7, dx))
	# Cut two-track: floor 3 m half-width, banks ramping up over the next 4 m.
	var bank := smoothstep(2.8, 7.0, dx)
	var h := lerpf(trail_h, land + 1.8 * smoothstep(60.0, 140.0, z), bank)
	# crown + a shallow camber so water collects in the wheel lines
	if dx < 2.8:
		h += 0.08 * cos(dx * 1.4)
	return h


func _build_heights() -> void:
	var n := RES + 1
	heights.resize(n * n)
	for j in range(n):
		for i in range(n):
			var x := i * CELL
			var z := j * CELL
			heights[j * n + i] = _base_height(x, z)


func get_height(x: float, z: float) -> float:
	var n := RES + 1
	var fx := clampf(x / CELL, 0.0, RES - 1.001)
	var fz := clampf(z / CELL, 0.0, RES - 1.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var h00 := heights[j * n + i]
	var h10 := heights[j * n + i + 1]
	var h01 := heights[(j + 1) * n + i]
	var h11 := heights[(j + 1) * n + i + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func creek_water_level() -> float:
	return _climb_profile(CREEK_Z) + CREEK_LEVEL_OFFSET + 1.6


func _author_mud() -> void:
	for cy in range(RES):
		for cx in range(RES):
			var x := (cx + 0.5) * CELL
			var z := (cy + 0.5) * CELL
			var tx := trail_x_at(z)
			var dx := absf(x - tx)
			var i := mud.idx(cx, cy)
			var on_trail := 1.0 - smoothstep(2.6, 4.0, dx)
			var thick := 0.0
			var wet := 0.0
			if z < 45.0:
				# compacted gravel road: thin, dry
				# blending into the paddy (saturated, but not the trail) keeps the
				# road edge from stair-stepping on the 0.5 m grid
				var paddy_k := smoothstep(3.0, 4.5, dx)
				thick = lerpf(0.04 * on_trail, 0.25, paddy_k)
				wet = lerpf(0.15, 1.0, paddy_k)
			else:
				var patchy := _detail.get_noise_2d(x * 1.7, z * 1.7) * 0.5 + 0.5
				thick = on_trail * (0.18 + 0.32 * patchy)
				# the lower climb holds water, the top is drier and firmer
				var creek_influence := exp(-pow((z - CREEK_Z) / 14.0, 2.0))
				thick += on_trail * 0.35 * creek_influence
				wet = 0.35 + 0.25 * patchy
				wet = lerpf(wet, 1.0, creek_influence)
				wet *= 1.0 - 0.45 * smoothstep(170.0, 250.0, z)
				# wheel lines already churned by the last convoy
				var wheel_line := exp(-pow((dx - 0.8) / 0.35, 2.0))
				mud.rut[i] = minf(thick, 0.12 * wheel_line * (0.6 + 0.4 * patchy)) * smoothstep(50.0, 70.0, z)
				if absf(z - CREEK_Z) < 18.0 and get_height(x, z) < creek_water_level():
					wet = 1.0
					thick = maxf(thick, 0.3)
			mud.thickness[i] = thick
			mud.wetness[i] = clampf(wet, 0.0, 1.0)


# --- Geometry ----------------------------------------------------------------

func _build_mesh() -> void:
	var n := RES + 1
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	verts.resize(n * n)
	normals.resize(n * n)
	uvs.resize(n * n)
	for j in range(n):
		for i in range(n):
			var k := j * n + i
			var x := i * CELL
			var z := j * CELL
			verts[k] = Vector3(x, heights[k], z)
			uvs[k] = Vector2(x / SIZE_M, z / SIZE_M)
			var hl := heights[j * n + maxi(i - 1, 0)]
			var hr := heights[j * n + mini(i + 1, n - 1)]
			var hd := heights[maxi(j - 1, 0) * n + i]
			var hu := heights[mini(j + 1, n - 1) * n + i]
			normals[k] = Vector3(hl - hr, 2.0 * CELL, hd - hu).normalized()
	indices.resize(RES * RES * 6)
	var q := 0
	for j in range(RES):
		for i in range(RES):
			var a := j * n + i
			var b := a + 1
			var c := a + n
			var d := c + 1
			# Godot front faces wind clockwise seen from above (+Y).
			indices[q] = a; indices[q + 1] = b; indices[q + 2] = c
			indices[q + 3] = b; indices[q + 4] = d; indices[q + 5] = c
			q += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/terrain.gdshader")
	mat.set_shader_parameter("mud_tex", mud.texture)
	mat.set_shader_parameter("world_size", SIZE_M)
	mat.set_shader_parameter("creek_level", creek_water_level())
	mesh.surface_set_material(0, mat)
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "TerrainMesh"
	_mesh_instance.mesh = mesh
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_mesh_instance)


func _build_collision() -> void:
	var n := RES + 1
	# The collider is the FIRM floor under the soft mud, so wheels and chassis
	# can sink below the visual surface without fighting an invisible wall.
	var firm := PackedFloat32Array()
	firm.resize(n * n)
	for j in range(n):
		for i in range(n):
			var cx := mini(i, RES - 1)
			var cy := mini(j, RES - 1)
			firm[j * n + i] = heights[j * n + i] - mud.thickness[mud.idx(cx, cy)]
	var shape := HeightMapShape3D.new()
	shape.map_width = n
	shape.map_depth = n
	shape.map_data = firm
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	cs.shape = shape
	# HeightMapShape3D is centred on its origin and 1 unit per cell; scale to CELL.
	cs.scale = Vector3(CELL, 1.0, CELL)
	cs.position = Vector3(SIZE_M * 0.5, 0.0, SIZE_M * 0.5)
	body.add_child(cs)
	add_child(body)


func _build_water() -> void:
	var shader := load("res://shaders/water.gdshader")
	# Paddy water: one sheet over the first 45 m. The road crown sits above it,
	# so it follows the road's curves without having to be cut to shape.
	var plane := PlaneMesh.new()
	plane.size = Vector2(SIZE_M, 44.0)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("tint", Color(0.22, 0.26, 0.14, 0.55))
	mi.material_override = mat
	mi.position = Vector3(SIZE_M * 0.5, -0.35 + WATER_PADDY, 22.0)
	mi.name = "PaddyWater"
	add_child(mi)
	# Creek: a sheet across the dip; the mesh is below the banks so it only
	# shows where the ground dips under it.
	var creek := PlaneMesh.new()
	creek.size = Vector2(SIZE_M, 36.0)
	var cmi := MeshInstance3D.new()
	cmi.mesh = creek
	var cmat := ShaderMaterial.new()
	cmat.shader = shader
	cmat.set_shader_parameter("tint", Color(0.40, 0.26, 0.12, 0.7))
	cmi.material_override = cmat
	cmi.position = Vector3(SIZE_M * 0.5, creek_water_level(), CREEK_Z)
	cmi.name = "CreekWater"
	add_child(cmi)


func _build_trees() -> void:
	# Secondary forest: dense off the trail, a few right at the bank edge so
	# there's always a winch anchor in reach. Trunks are solid; canopies are not.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.18
	trunk_mesh.bottom_radius = 0.28
	trunk_mesh.height = 7.0
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.32, 0.24, 0.16)
	trunk_mesh.material = trunk_mat
	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radius = 2.6
	canopy_mesh.height = 4.2
	var canopy_mat := StandardMaterial3D.new()
	canopy_mat.albedo_color = Color(0.16, 0.34, 0.14)
	canopy_mesh.material = canopy_mat

	var trunks := MultiMesh.new()
	trunks.transform_format = MultiMesh.TRANSFORM_3D
	trunks.mesh = trunk_mesh
	var canopies := MultiMesh.new()
	canopies.transform_format = MultiMesh.TRANSFORM_3D
	canopies.mesh = canopy_mesh

	var placements: Array[Transform3D] = []
	var anchors_body := StaticBody3D.new()
	anchors_body.name = "Trees"
	anchors_body.collision_layer = 1
	for _k in range(900):
		var z := rng.randf_range(48.0, SIZE_M - 4.0)
		var tx := trail_x_at(z)
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		# clustered just past the bank, thinning further out
		var off := 4.2 + absf(rng.randfn(0.0, 1.0)) * 9.0
		if rng.randf() < 0.12:
			off = rng.randf_range(3.6, 4.4)  # right on the bank: winch anchors
		var x := tx + side * off
		if x < 2.0 or x > SIZE_M - 2.0:
			continue
		var y := get_height(x, z)
		var scale := rng.randf_range(0.8, 1.5)
		var t := Transform3D(Basis().rotated(Vector3.UP, rng.randf() * TAU).scaled(Vector3(scale, scale, scale)), Vector3(x, y + 3.5 * scale, z))
		placements.append(t)
		if off < 7.0:
			tree_anchors.append(Vector3(x, y + 0.8, z))
			var cs := CollisionShape3D.new()
			var cap := CylinderShape3D.new()
			cap.radius = 0.3 * scale
			cap.height = 7.0 * scale
			cs.shape = cap
			cs.position = Vector3(x, y + 3.5 * scale, z)
			anchors_body.add_child(cs)
	trunks.instance_count = placements.size()
	canopies.instance_count = placements.size()
	for k in range(placements.size()):
		trunks.set_instance_transform(k, placements[k])
		var ct := placements[k]
		ct.origin.y += 4.6 * ct.basis.get_scale().y
		canopies.set_instance_transform(k, ct)
	var tmi := MultiMeshInstance3D.new()
	tmi.multimesh = trunks
	tmi.name = "Trunks"
	add_child(tmi)
	var cmi := MultiMeshInstance3D.new()
	cmi.multimesh = canopies
	cmi.name = "Canopies"
	add_child(cmi)
	add_child(anchors_body)


# --- Queries used by the vehicle -------------------------------------------

## Soft-ground sample at a world position. Returns the MudField dictionary
## plus "water_depth" (metres of standing water above the surface, 0 if none).
func ground_sample(world_pos: Vector3) -> Dictionary:
	var s := mud.sample(Vector2(world_pos.x, world_pos.z))
	var top := get_height(world_pos.x, world_pos.z)
	var surface: float = top - s["rut"]
	s["firm_y"] = top - s["thickness"]
	var water := 0.0
	if world_pos.z > CREEK_Z - 20.0 and world_pos.z < CREEK_Z + 20.0:
		water = maxf(0.0, creek_water_level() - surface)
	elif world_pos.z < 45.0 and absf(world_pos.x - trail_x_at(world_pos.z)) > 3.5:
		water = maxf(0.0, (-0.35 + WATER_PADDY) - surface)
	s["water_depth"] = water
	s["surface_y"] = surface
	return s


func nearest_anchor(from: Vector3, max_dist: float) -> Vector3:
	var best := Vector3.INF
	var best_d := max_dist
	for a in tree_anchors:
		var d := from.distance_to(a)
		if d < best_d:
			best_d = d
			best = a
	return best
