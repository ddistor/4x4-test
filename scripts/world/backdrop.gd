class_name Backdrop
extends Node3D
## What you see past the edge of the playable square: Sierra Madre foothills
## rising up-trail (+Z), paddies running out to either side, and Laguna de Bay
## behind the start (-Z). One polar-grid mesh plus a lake plane; haze does the rest.

const RINGS := 56
const SEGMENTS := 160
const INNER := 110.0
const OUTER := 3200.0
const LAKE_LEVEL := -0.25

var terrain: Terrain


func build(t: Terrain) -> void:
	terrain = t
	var noise := FastNoiseLite.new()
	noise.seed = t.seed_value + 11
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	noise.fractal_octaves = 5
	noise.frequency = 0.0022
	var centre := Vector2(Terrain.SIZE_M * 0.5, Terrain.SIZE_M * 0.5)

	var pts := PackedVector3Array()
	for ri in range(RINGS + 1):
		var r := INNER * pow(OUTER / INNER, float(ri) / RINGS)
		for si in range(SEGMENTS):
			var a := TAU * si / SEGMENTS
			var xz := centre + Vector2(cos(a), sin(a)) * r
			pts.append(Vector3(xz.x, _height(xz, noise), xz.y))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in pts:
		st.add_vertex(p)
	for ri in range(RINGS):
		for si in range(SEGMENTS):
			var a := ri * SEGMENTS + si
			var b := ri * SEGMENTS + (si + 1) % SEGMENTS
			var c := a + SEGMENTS
			var d := b + SEGMENTS
			for tri: Array in [[a, b, c], [b, d, c]]:
				var pa := pts[tri[0]]
				# front faces wind clockwise seen from above
				if (pts[tri[2]] - pa).cross(pts[tri[1]] - pa).y < 0.0:
					tri = [tri[0], tri[2], tri[1]]
				for k: int in tri:
					st.add_index(k)
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
	lake.position = Vector3(centre.x, LAKE_LEVEL, -OUTER * 0.5 - 4.0)
	add_child(lake)


func _height(xz: Vector2, noise: FastNoiseLite) -> float:
	var s := Terrain.SIZE_M
	var inside := xz.x > 0.5 and xz.x < s - 0.5 and xz.y > 0.5 and xz.y < s - 0.5
	var edge := Vector2(clampf(xz.x, 0.0, s), clampf(xz.y, 0.0, s))
	var base := terrain.get_height(edge.x, edge.y)
	if inside:
		return base - 3.0  # tucked under the real terrain
	var e := xz.distance_to(edge)
	# hills everywhere, mountains up-trail, flat paddy land toward the lake
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
