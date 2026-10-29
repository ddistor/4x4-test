class_name Rocks
extends Node3D
## Boulders and river stones: a handful of lumpy, faceted rock meshes made in
## code, scattered with MultiMeshes. Every one has a convex collider, so tires
## climb them and a diff or a belly can hang up on them. The wheels treat a
## rock as firm ground (group "rock").

const VARIANTS := 5
const CHUNK := 80.0

var _hulls: Array[PackedVector3Array] = []


func build(t: Terrain, spots: Array[Vector4]) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/rock.gdshader")
	mat.set_shader_parameter("soil_tex", t.soil_texture)
	mat.set_shader_parameter("world_size", Vector2(Terrain.WIDTH, t.length))
	var meshes: Array[ArrayMesh] = []
	for v in range(VARIANTS):
		meshes.append(_rock_mesh(t.seed_value * 13 + v, mat))

	var rng := RandomNumberGenerator.new()
	rng.seed = t.seed_value + 17
	var body := StaticBody3D.new()
	body.name = "RockBodies"
	body.collision_layer = 1
	body.add_to_group("rock")
	var chunks := {}  # Vector2i(chunk, variant) -> Array[Transform3D]
	for s in spots:
		var v := rng.randi() % VARIANTS
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s.w)
		var xf := Transform3D(basis, Vector3(s.x, s.y, s.z))
		var key := Vector2i(int(s.z / CHUNK), v)
		if not chunks.has(key):
			chunks[key] = [] as Array[Transform3D]
		(chunks[key] as Array[Transform3D]).append(xf)
		var shape := ConvexPolygonShape3D.new()
		var pts := PackedVector3Array()
		for p in _hulls[v]:
			pts.append(p * s.w)
		shape.points = pts
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.transform = Transform3D(Basis(Vector3.UP, basis.get_euler().y), xf.origin)
		body.add_child(cs)
	add_child(body)

	for key: Vector2i in chunks:
		var list: Array[Transform3D] = chunks[key]
		var centre := Vector3(Terrain.WIDTH * 0.5, 0.0, (key.x + 0.5) * CHUNK)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[key.y]
		mm.instance_count = list.size()
		for k in range(list.size()):
			var x := list[k]
			x.origin -= centre
			mm.set_instance_transform(k, x)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Rocks_%d_%d" % [key.x, key.y]
		mmi.multimesh = mm
		mmi.position = centre
		mmi.visibility_range_end = 320.0
		mmi.visibility_range_end_margin = 20.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(mmi)


## A unit boulder: a squashed sphere pushed about by noise, with a few flat
## fracture faces sliced off and a flattish bottom where it sits in the ground.
func _rock_mesh(seed_v: int, mat: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var noise := FastNoiseLite.new()
	noise.seed = seed_v
	noise.frequency = 0.9
	noise.fractal_octaves = 3
	var cuts: Array[Plane] = []
	for k in range(rng.randi_range(3, 5)):
		var n := Vector3(rng.randfn(), rng.randfn() * 0.6 + 0.3, rng.randfn()).normalized()
		cuts.append(Plane(n, rng.randf_range(0.6, 0.85)))
	var squash := Vector3(rng.randf_range(0.9, 1.25), rng.randf_range(0.55, 0.8), rng.randf_range(0.8, 1.1))
	var rings := 10
	var segs := 16
	var grid: Array[Vector3] = []
	for ri in range(rings + 1):
		var lat := PI * (float(ri) / rings - 0.5)
		for si in range(segs):
			var lon := TAU * si / segs
			var d := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
			var r := 1.0 + 0.25 * noise.get_noise_3dv(d * 1.3) + 0.06 * noise.get_noise_3dv(d * 5.0 + Vector3(9, 0, 0))
			var p := d * r * squash
			for c in cuts:
				var over := c.distance_to(p)
				if over > 0.0:
					p -= c.normal * over
			p.y = maxf(p.y, -0.45)
			grid.append(p)
	var hull := PackedVector3Array()
	for p in grid:
		hull.append(p)
	_hulls.append(hull)
	# smooth normals from the neighbours (the sliced faces come out flat by themselves)
	var normals: Array[Vector3] = []
	for ri in range(rings + 1):
		for si in range(segs):
			var p := grid[ri * segs + si]
			var n := p.normalized()
			if ri > 0 and ri < rings:
				var e := grid[ri * segs + (si + 1) % segs] - grid[ri * segs + (si + segs - 1) % segs]
				var u := grid[(ri + 1) * segs + si] - grid[(ri - 1) * segs + si]
				var c := e.cross(u)
				if c.length_squared() > 1e-8:
					n = c.normalized() * signf(c.dot(p))
			normals.append(n)
	var st := MeshKit.begin()
	var white := Color(1, 1, 1)
	for ri in range(rings):
		for si in range(segs):
			var ids: Array[int] = [ri * segs + si, ri * segs + (si + 1) % segs,
				(ri + 1) * segs + (si + 1) % segs, (ri + 1) * segs + si]
			var q: Array[Vector3] = []
			var qn: Array[Vector3] = []
			for i in ids:
				q.append(grid[i])
				qn.append(normals[i])
			# MeshKit sorts the winding out from the normals
			MeshKit._quad(st, Transform3D.IDENTITY, q, qn, white)
	return MeshKit.commit(st, mat)
