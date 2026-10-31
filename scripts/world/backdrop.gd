class_name Backdrop
extends Node3D
## What you see past the edge of the playable strip: Sierra Madre foothills
## rising up-trail (+Z) and along the sides, paddies running out round the
## start, and Laguna de Bay behind it (-Z). Rings of vertices around the
## strip's rectangle, spaced wider the further out; haze does the rest.

const RINGS := 46
const OUTER := 3200.0
const SIDE_STEP := 6.0     # metres between vertices along the strip's edges, on the inner ring
const CORNER_SEGS := 8
const LAKE_LEVEL := -0.25
const NEAR_SOLID := 250.0  # m past the edge that's solid ground

var terrain: Terrain


func build(t: Terrain) -> void:
	terrain = t
	var noise := FastNoiseLite.new()
	noise.seed = t.seed_value + 11
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	noise.fractal_octaves = 5
	noise.frequency = 0.0022
	var w := Terrain.WIDTH
	var l := t.length
	var nw := int(w / SIDE_STEP)
	var nl := int(l / SIDE_STEP)

	# one loop round the rectangle: [point on the edge, outward direction]
	var loop: Array = []
	var corner := func(c: Vector2, a0: float) -> void:
		for k in range(CORNER_SEGS):
			var a := a0 + PI * 0.5 * k / CORNER_SEGS
			loop.append([c, Vector2(cos(a), sin(a))])
	for k in range(nw):
		loop.append([Vector2(w * k / nw, 0.0), Vector2(0, -1)])
	corner.call(Vector2(w, 0.0), -PI * 0.5)
	for k in range(nl):
		loop.append([Vector2(w, l * k / nl), Vector2(1, 0)])
	corner.call(Vector2(w, l), 0.0)
	for k in range(nw):
		loop.append([Vector2(w - w * k / nw, l), Vector2(0, 1)])
	corner.call(Vector2(0.0, l), PI * 0.5)
	for k in range(nl):
		loop.append([Vector2(0.0, l - l * k / nl), Vector2(-1, 0)])
	corner.call(Vector2(0.0, 0.0), PI)
	var segs := loop.size()

	var pts := PackedVector3Array()
	for ri in range(RINGS + 1):
		# ring 0 tucks a few metres under the terrain's edge so there's no crack
		var e := -4.0 if ri == 0 else pow(OUTER, float(ri) / RINGS)
		for si in range(segs):
			var edge: Vector2 = loop[si][0]
			var out: Vector2 = loop[si][1]
			var xz: Vector2 = edge + out * e
			pts.append(Vector3(xz.x, _height(xz, edge, maxf(e, 0.0), noise), xz.y))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in pts:
		st.add_vertex(p)
	for ri in range(RINGS):
		for si in range(segs):
			var a := ri * segs + si
			var b := ri * segs + (si + 1) % segs
			var c := a + segs
			var d := b + segs
			for tri: Array in [[a, b, c], [b, d, c]]:
				var pa := pts[tri[0]]
				var cr := (pts[tri[2]] - pa).cross(pts[tri[1]] - pa)
				if cr.length_squared() < 1e-10:
					continue
				# front faces wind clockwise seen from above
				if cr.y < 0.0:
					tri = [tri[0], tri[2], tri[1]]
				for k: int in tri:
					st.add_index(k)
	# the near rings are solid: a rig that gets over the edge lands on the
	# hills it can see and rolls to a stop, rather than falling out of the
	# world (the marshals bring it back: Rig's off-course check)
	var faces := PackedVector3Array()
	for ri in range(RINGS):
		if ri > 0 and pow(OUTER, float(ri) / RINGS) > NEAR_SOLID:
			break
		for si in range(segs):
			var a := ri * segs + si
			var b := ri * segs + (si + 1) % segs
			faces.append_array([pts[a], pts[b], pts[a + segs], pts[b], pts[b + segs], pts[a + segs]])
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var body := StaticBody3D.new()
	body.name = "FarHillsGround"
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	st.generate_normals()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/backdrop.gdshader")
	st.set_material(mat)
	var mi := MeshInstance3D.new()
	mi.name = "FarHills"
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

	var lake := MeshInstance3D.new()
	lake.name = "LagunaDeBay"
	var plane := PlaneMesh.new()
	plane.size = Vector2(OUTER * 2.2, OUTER)
	lake.mesh = plane
	var lm := ShaderMaterial.new()
	lm.shader = load("res://shaders/water.gdshader")
	lm.set_shader_parameter("tint", Color(0.25, 0.27, 0.2, 0.92))
	lake.material_override = lm
	lake.position = Vector3(w * 0.5, LAKE_LEVEL, -OUTER * 0.5 - 4.0)
	add_child(lake)


func _height(xz: Vector2, edge: Vector2, e: float, noise: FastNoiseLite) -> float:
	var base := terrain.get_height(clampf(edge.x, 0.0, Terrain.WIDTH), clampf(edge.y, 0.0, terrain.length))
	if e <= 0.0:
		return base - 3.0  # tucked under the real terrain
	# hills everywhere, mountains up-trail and toward the far end
	var up_trail := smoothstep(40.0, 600.0, xz.y)
	var amp := minf(e * 0.04, 30.0) + minf(e * 0.22, 420.0) * up_trail
	var hills := (noise.get_noise_2d(xz.x, xz.y) * 0.5 + 0.5) * amp
	var h := base + hills * smoothstep(0.0, 60.0, e)
	# paddy plain: low and flat near the lake end
	var plain := 1.0 - smoothstep(30.0, 160.0, xz.y)
	h = lerpf(h, -0.3 + hills * 0.02, plain * smoothstep(0.0, 30.0, e))
	# Laguna de Bay: the lakeshore wanders a little
	var shore := -6.0 - 25.0 * sin(xz.x * 0.004) - 10.0 * sin(xz.x * 0.011)
	h = lerpf(h, LAKE_LEVEL - 3.0, smoothstep(shore, shore - 40.0, xz.y))
	return h
