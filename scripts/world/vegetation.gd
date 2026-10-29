class_name Vegetation
extends Node3D
## Everything green on the Morong trail, modelled in code:
##   - secondary-forest broadleaf trees (sweep trunks + leaf-card canopies)
##   - bamboo clumps by the trail and the creek
##   - saging (banana) plants and coconut palms round the paddies
##   - grass and ferns, rice planted in rows in the paddies
## Each kind is a handful of mesh variants scattered with MultiMeshes; the
## small stuff is chunked and only drawn near the camera.

const CHUNK := 32.0
const TREE_CHUNK := 64.0
const TREE_RANGE := 300.0

var terrain: Terrain
var _rng := RandomNumberGenerator.new()
var _bark_mat: ShaderMaterial
var _leaf_mat: ShaderMaterial
var _bamboo_leaf_mat: ShaderMaterial
var _plant_mat: ShaderMaterial


func build(t: Terrain, tree_spots: Array[Transform3D]) -> void:
	terrain = t
	_rng.seed = t.seed_value + 101
	_make_materials()
	_place_trees(tree_spots)
	_place_bamboo()
	_place_paddy_edge_plants()
	_place_ground_cover()


# --- materials ----------------------------------------------------------------

func _make_materials() -> void:
	var foliage := load("res://shaders/foliage.gdshader")
	_bark_mat = ShaderMaterial.new()
	_bark_mat.shader = load("res://shaders/bark.gdshader")
	_leaf_mat = ShaderMaterial.new()
	_leaf_mat.shader = foliage
	_leaf_mat.set_shader_parameter("use_tex", true)
	_leaf_mat.set_shader_parameter("leaf_tex", leaf_texture(false, 3))
	_leaf_mat.set_shader_parameter("sway", 0.25)
	_bamboo_leaf_mat = ShaderMaterial.new()
	_bamboo_leaf_mat.shader = foliage
	_bamboo_leaf_mat.set_shader_parameter("use_tex", true)
	_bamboo_leaf_mat.set_shader_parameter("leaf_tex", leaf_texture(true, 5))
	_bamboo_leaf_mat.set_shader_parameter("sway", 0.5)
	_bamboo_leaf_mat.set_shader_parameter("sway_height", 9.0)
	_plant_mat = ShaderMaterial.new()
	_plant_mat.shader = foliage
	_plant_mat.set_shader_parameter("sway", 0.12)
	_plant_mat.set_shader_parameter("sway_height", 2.5)
	_plant_mat.set_shader_parameter("roughness", 0.55)


## A sprig of leaves on a twig, drawn into an alpha texture. `narrow` makes
## bamboo's long thin leaves instead of broad forest leaves.
static func leaf_texture(narrow: bool, seed_v: int) -> ImageTexture:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	# transparent texels keep a leaf colour so mipmaps don't fringe dark
	img.fill(Color(0.2, 0.33, 0.1, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var twig := Color(0.3, 0.24, 0.15)
	for y in range(int(size * 0.08), size):
		for w in range(-1, 2):
			img.set_pixel(size / 2 + w + int(sin(y * 0.03) * 4.0), y, twig)
	var count := 22 if narrow else 15
	for k in range(count):
		var along := float(k) / count
		var base := Vector2(size * 0.5 + sin(along * 18.0) * 4.0, size * (0.95 - 0.82 * along))
		var spread := 1.2 if narrow else 1.0
		var ang := -PI * 0.5 + (1.0 if k % 2 == 0 else -1.0) * rng.randf_range(0.35, spread) * (1.0 - along * 0.5)
		var length := rng.randf_range(85.0, 120.0) if narrow else rng.randf_range(60.0, 95.0)
		var width := length * (0.14 if narrow else 0.45)
		var dir := Vector2(cos(ang), sin(ang))
		var perp := Vector2(-dir.y, dir.x)
		var shade := rng.randf_range(0.75, 1.2)
		var col := (Color(0.32, 0.47, 0.13) if narrow else Color(0.2, 0.38, 0.1)) * shade
		var lo := Vector2(minf(base.x, base.x + dir.x * length) - width, minf(base.y, base.y + dir.y * length) - width)
		var hi := Vector2(maxf(base.x, base.x + dir.x * length) + width, maxf(base.y, base.y + dir.y * length) + width)
		for py in range(maxi(0, int(lo.y)), mini(size, int(hi.y) + 1)):
			for px in range(maxi(0, int(lo.x)), mini(size, int(hi.x) + 1)):
				var rel := Vector2(px, py) - base
				var u := rel.dot(dir) / length
				if u < 0.0 or u > 1.0:
					continue
				var prof := pow(sin(PI * pow(u, 0.75)), 0.8)
				var v := absf(rel.dot(perp)) / (width * 0.5)
				if v > prof:
					continue
				var c := col
				if v < 0.07:
					c = c.lightened(0.2)  # midrib
				c = c.darkened(0.1 * (0.5 + 0.5 * sin((u * 16.0 - v * 4.0) * PI)))  # veins
				c = c.darkened(0.15 * smoothstep(0.7, 1.0, v / maxf(prof, 0.01)))
				c = c.lightened(0.15 * u)  # newer growth toward the tip
				c.a = 1.0
				img.set_pixel(px, py, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# --- mesh helpers -------------------------------------------------------------

## Leaf card hanging from `base`, extending along `up` (full length) and
## +-`right` (half width). `n` is the shading normal (soft canopy lighting).
static func _card(st: SurfaceTool, base: Vector3, right: Vector3, up: Vector3, n: Vector3, col: Color) -> void:
	var v := [base - right, base + right, base + right + up, base - right + up]
	var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for k: int in [0, 1, 2, 0, 2, 3]:
		st.set_color(col)
		st.set_normal(n)
		st.set_uv(uv[k])
		st.add_vertex(v[k])


## A flat ribbon along a path (grass blades, fronds, banana leaves). `widths`
## per point; `bend` adds a V-fold down the middle (leaf midrib).
static func _ribbon(st: SurfaceTool, pts: PackedVector3Array, widths: PackedFloat32Array, side: Vector3, cols: PackedColorArray, bend := 0.0) -> void:
	var n := pts.size()
	for i in range(n - 1):
		var t0 := (pts[i + 1] - pts[i]).normalized()
		var face := side.cross(t0).normalized()
		if face.y < 0.0:
			face = -face
		var a := [pts[i] - side * widths[i] - face * bend * widths[i], pts[i], pts[i] + side * widths[i] - face * bend * widths[i]]
		var b := [pts[i + 1] - side * widths[i + 1] - face * bend * widths[i + 1], pts[i + 1], pts[i + 1] + side * widths[i + 1] - face * bend * widths[i + 1]]
		for half in range(2):
			var q := [a[half], b[half], b[half + 1], a[half + 1]]
			var cq := [cols[i], cols[i + 1], cols[i + 1], cols[i]]
			var nn := (face + Vector3.UP * 0.6).normalized()
			for k: int in [0, 1, 2, 0, 2, 3]:
				st.set_color(cq[k])
				st.set_normal(nn)
				st.set_uv(Vector2(0.5, 0.5))
				st.add_vertex(q[k])


static func _bark_col(c: Color, clay := 1.0) -> Color:
	return Color(c.r, c.g, c.b, clay)


func _finish(surfaces: Array) -> ArrayMesh:
	# surfaces: [[SurfaceTool, Material], ...] -> one multi-surface mesh
	var mesh := ArrayMesh.new()
	var i := 0
	for s: Array in surfaces:
		(s[0] as SurfaceTool).commit(mesh)
		mesh.surface_set_material(i, s[1])
		i += 1
	return mesh


func _multi(mesh: Mesh, xforms: Array[Transform3D], name_: String, shadows := true, vis_end := 0.0, centre := Vector3.ZERO) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for k in range(xforms.size()):
		mm.set_instance_transform(k, xforms[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = name_
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if vis_end > 0.0:
		mmi.visibility_range_end = vis_end
		mmi.visibility_range_end_margin = 12.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		# visibility is measured from the node origin, so put it mid-chunk
		mmi.position = centre
		for k in range(xforms.size()):
			var x := xforms[k]
			x.origin -= centre
			mm.set_instance_transform(k, x)
	add_child(mmi)


func _ground_xf(x: float, z: float, scale: float, sink := 0.05) -> Transform3D:
	var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * scale)
	return Transform3D(b, Vector3(x, terrain.get_height(x, z) - sink, z))


# --- broadleaf trees -------------------------------------------------------------

func _tree_mesh(seed_v: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var bark := MeshKit.begin()
	var leaves := MeshKit.begin()
	var height := rng.randf_range(10.0, 14.0)
	var bark_c := _bark_col(Color(0.36, 0.32, 0.27).lerp(Color(0.45, 0.42, 0.38), rng.randf()))

	# trunk: slight lean and wander, flared at the foot
	var trunk := PackedVector3Array()
	var tr := PackedFloat32Array()
	var lean := Vector3(rng.randf_range(-0.04, 0.04), 1.0, rng.randf_range(-0.04, 0.04))
	var p := Vector3.ZERO
	var segs := 9
	var trunk_top := height * 0.78
	for i in range(segs + 1):
		var f := float(i) / segs
		trunk.append(p)
		tr.append(lerpf(0.3, 0.13, f) + 0.2 * pow(1.0 - f, 8.0))
		p += (lean + Vector3(rng.randf_range(-0.06, 0.06), 0, rng.randf_range(-0.06, 0.06))) * trunk_top / segs
	MeshKit.sweep(bark, trunk, tr, Transform3D.IDENTITY, bark_c, 10)

	var clusters: Array = []  # [centre, radius]
	clusters.append([trunk[segs] + Vector3.UP * 1.2, rng.randf_range(2.0, 2.6)])
	var nb := rng.randi_range(4, 6)
	for b in range(nb):
		var at := rng.randi_range(int(segs * 0.5), segs - 1)
		var start := trunk[at]
		var a := TAU * b / nb + rng.randf_range(-0.4, 0.4)
		var dir := Vector3(cos(a), rng.randf_range(0.55, 1.0), sin(a)).normalized()
		var length := rng.randf_range(2.8, 4.6)
		var bp := PackedVector3Array()
		var br := PackedFloat32Array()
		for i in range(5):
			var f := i / 4.0
			bp.append(start + dir * length * f + Vector3.UP * (f * f * 0.8))
			br.append(lerpf(tr[at] * 0.6, 0.035, f))
		MeshKit.sweep(bark, bp, br, Transform3D.IDENTITY, bark_c, 6)
		clusters.append([bp[4] + Vector3.UP * 0.5, rng.randf_range(1.5, 2.2)])
		if rng.randf() < 0.6:
			clusters.append([bp[2] + Vector3.UP * 0.6, rng.randf_range(1.0, 1.4)])

	for cl: Array in clusters:
		var c: Vector3 = cl[0]
		var r: float = cl[1]
		var cards := int(r * r * 5.5)
		for k in range(cards):
			var d := Vector3(rng.randfn(), rng.randfn() * 0.6, rng.randfn()).normalized()
			var pos := c + d * r * pow(rng.randf(), 0.4)
			var up := (d * 0.7 + Vector3(rng.randfn(), rng.randfn(), rng.randfn()) * 0.5 + Vector3.UP * 0.3).normalized()
			var right := up.cross(Vector3(rng.randfn(), rng.randfn(), rng.randfn())).normalized()
			var size := rng.randf_range(1.1, 1.6)
			var n := ((pos - c).normalized() + Vector3.UP * 0.45).normalized()
			_card(leaves, pos - up * size * 0.3, right * size * 0.5, up * size, n, Color(1, 1, 1, 1))
	return _finish([[bark, _bark_mat], [leaves, _leaf_mat]])


func _place_trees(spots: Array[Transform3D]) -> void:
	var variants := 4
	var meshes: Array[ArrayMesh] = []
	for v in range(variants):
		meshes.append(_tree_mesh(terrain.seed_value * 31 + v))
	var groups: Array = []
	for v in range(variants):
		groups.append([] as Array[Transform3D])
	for s in spots:
		(groups[_rng.randi() % variants] as Array[Transform3D]).append(s)
	for v in range(variants):
		_chunked(meshes[v], groups[v], "Trees%d" % v, TREE_CHUNK, TREE_RANGE)


## Split a long scatter into chunks along the stage, each drawn only within
## `vis` metres, so a kilometre of forest doesn't all render at once.
func _chunked(mesh: Mesh, xforms: Array[Transform3D], name_: String, chunk: float, vis: float, shadows := true) -> void:
	var by := {}
	for x in xforms:
		var k := int(x.origin.z / chunk)
		if not by.has(k):
			by[k] = [] as Array[Transform3D]
		(by[k] as Array[Transform3D]).append(x)
	for k: int in by:
		var centre := Vector3(Terrain.WIDTH * 0.5, 0.0, (k + 0.5) * chunk)
		centre.y = terrain.trail_floor_at(centre.z)
		_multi(mesh, by[k], "%s_%d" % [name_, k], shadows, vis, centre)


# --- bamboo -----------------------------------------------------------------------

func _bamboo_mesh(seed_v: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var culms := MeshKit.begin()
	var leaves := MeshKit.begin()
	var count := rng.randi_range(16, 24)
	for k in range(count):
		var a := rng.randf() * TAU
		var base := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.1, 0.9)
		var out := Vector3(cos(a), 0, sin(a))
		var height := rng.randf_range(7.0, 11.0)
		var arch := rng.randf_range(0.15, 0.45)
		var pts := PackedVector3Array()
		var rad := PackedFloat32Array()
		var n := 10
		for i in range(n + 1):
			var f := float(i) / n
			pts.append(base + Vector3.UP * height * f + out * height * arch * f * f)
			rad.append(lerpf(0.055, 0.025, f))
		var green := Color(0.42, 0.5, 0.16).lerp(Color(0.58, 0.55, 0.25), rng.randf())
		MeshKit.sweep(culms, pts, rad, Transform3D.IDENTITY, _bark_col(green, 0.0), 6)
		# nodes: a slight collar every ~40 cm
		var node_count := int(height / 0.4)
		for i in range(1, node_count):
			var f := float(i) / node_count
			var at := pts[int(f * n)].lerp(pts[mini(int(f * n) + 1, n)], fmod(f * n, 1.0))
			var axis := (pts[mini(int(f * n) + 1, n)] - pts[int(f * n)]).normalized()
			MeshKit.cylinder(culms, lerpf(0.062, 0.03, f), 0.025, Transform3D(MeshKit.y_to(axis), at), _bark_col(green.darkened(0.25), 0.0), 6)
		# leafy twigs on the upper half, drooping
		for i in range(int(n * 0.45), n + 1):
			for j in range(2):
				var side := out.rotated(Vector3.UP, rng.randf_range(-1.6, 1.6))
				var up := (side + Vector3.DOWN * rng.randf_range(0.2, 0.7)).normalized()
				var right := up.cross(Vector3.UP).normalized()
				var size := rng.randf_range(0.9, 1.3)
				_card(leaves, pts[i], right * size * 0.5, up * size, (side + Vector3.UP * 0.5).normalized(), Color(1, 1, 1, 1))
	return _finish([[culms, _bark_mat], [leaves, _bamboo_leaf_mat]])


func _place_bamboo() -> void:
	var meshes: Array[ArrayMesh] = [_bamboo_mesh(901), _bamboo_mesh(902), _bamboo_mesh(903)]
	var groups: Array = [[] as Array[Transform3D], [] as Array[Transform3D], [] as Array[Transform3D]]
	# clumps crowd the rivers and creeks, and line the trail through the hills
	var spots: Array[float] = []
	for c in terrain.crossings:
		for k in range(14):
			spots.append(float(c["zc"]) + _rng.randf_range(-1.0, 1.0) * float(c["reach"]))
	for s in terrain.plan.sections:
		if s["kind"] in ["clay", "kanal", "river", "rocky", "gully", "niyog"]:
			for k in range(int((s["z1"] - s["z0"]) / 8.0)):
				spots.append(_rng.randf_range(s["z0"], s["z1"]))
	var k := 0
	for z in spots:
		var side := 1.0 if _rng.randf() < 0.5 else -1.0
		var x := terrain.trail_x_at(z) + side * _rng.randf_range(5.5, 12.0)
		if x < 3.0 or x > Terrain.WIDTH - 3.0 or terrain.get_height(x, z) < terrain.water_at(x, z) + 0.2:
			continue
		(groups[k % 3] as Array[Transform3D]).append(_ground_xf(x, z, _rng.randf_range(0.8, 1.15), 0.1))
		k += 1
	for v in range(3):
		_chunked(meshes[v], groups[v], "Bamboo%d" % v, TREE_CHUNK, TREE_RANGE)


# --- banana and coconut --------------------------------------------------------

func _banana_mesh(seed_v: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var stem := MeshKit.begin()
	var leaves := MeshKit.begin()
	var h := rng.randf_range(2.0, 2.8)
	MeshKit.sweep(stem, PackedVector3Array([Vector3.ZERO, Vector3(0, h * 0.5, 0.03), Vector3(0, h, 0.05)]),
		PackedFloat32Array([0.15, 0.12, 0.09]), Transform3D.IDENTITY, _bark_col(Color(0.36, 0.4, 0.18), 0.5), 8)
	var count := rng.randi_range(6, 9)
	for k in range(count):
		var a := TAU * k / count + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(a), 0, sin(a))
		var side := out.cross(Vector3.UP).normalized()
		var rise := rng.randf_range(0.6, 1.3)
		var length := rng.randf_range(1.6, 2.4)
		var pts := PackedVector3Array()
		var w := PackedFloat32Array()
		var cols := PackedColorArray()
		var top := Vector3(0, h - 0.1, 0.05)
		var n := 9
		# one old leaf, dried brown and hanging; the rest green, yellower at the tips
		var dead := k == 0 and rng.randf() < 0.7
		for i in range(n + 1):
			var f := float(i) / n
			# up and out, then the heavy blade droops
			pts.append(top + out * length * f + Vector3.UP * (rise * f - (2.4 if dead else 1.5) * f * f * f))
			w.append(0.32 * pow(sin(PI * clampf(f * 0.95 + 0.05, 0.0, 1.0)), 0.6))
			var c := Color(0.42, 0.32, 0.16) if dead else Color(0.3, 0.5, 0.12).lerp(Color(0.55, 0.5, 0.2), 0.25 * f)
			c.a = f
			cols.append(c)
		_ribbon(leaves, pts, w, side, cols, 0.25)
	return _finish([[stem, _bark_mat], [leaves, _plant_mat]])


func _palm_mesh(seed_v: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var trunk := MeshKit.begin()
	var fronds := MeshKit.begin()
	var h := rng.randf_range(8.0, 12.0)
	var lean := rng.randf_range(0.12, 0.3)
	var pts := PackedVector3Array()
	var rad := PackedFloat32Array()
	for i in range(11):
		var f := i / 10.0
		pts.append(Vector3(h * lean * f * f, h * f, 0))
		rad.append(lerpf(0.24, 0.15, f))
	MeshKit.sweep(trunk, pts, rad, Transform3D.IDENTITY, _bark_col(Color(0.5, 0.47, 0.41), 0.3), 10)
	var top := pts[10]
	for k in range(4):
		MeshKit.sphere(trunk, 0.12, Transform3D(Basis.IDENTITY, top + Vector3(cos(k * 1.6) * 0.18, -0.25, sin(k * 1.6) * 0.18)), _bark_col(Color(0.4, 0.3, 0.12), 0.0), 8)
	var count := 16
	for k in range(count):
		var a := TAU * k / count + rng.randf_range(-0.15, 0.15)
		var out := Vector3(cos(a), 0, sin(a))
		var side := out.cross(Vector3.UP).normalized()
		var length := rng.randf_range(3.2, 4.2)
		var up0 := rng.randf_range(0.4, 1.0)
		var rach := PackedVector3Array()
		var n := 12
		for i in range(n + 1):
			var f := float(i) / n
			rach.append(top + out * length * f + Vector3.UP * (up0 * f * 2.0 - 2.6 * f * f))
		var col := Color(0.36, 0.48, 0.14).lerp(Color(0.55, 0.52, 0.2), rng.randf() * 0.5)
		# leaflets hang off both sides of the rachis
		for i in range(1, n):
			var f := float(i) / n
			var ll := 0.75 * sin(PI * f) + 0.1
			for s: float in [-1.0, 1.0]:
				for sub in range(2):
					var at := rach[i].lerp(rach[i + 1], sub * 0.5)
					var tip := at + (side * s * 0.8 + Vector3.DOWN * 0.6 + out * 0.2).normalized() * ll
					var lp := PackedVector3Array([at, (at + tip) * 0.5 + Vector3.UP * 0.05, tip])
					var tang := (rach[i + 1] - rach[i]).normalized()
					_ribbon(fronds, lp, PackedFloat32Array([0.03, 0.035, 0.005]), tang,
						PackedColorArray([Color(col, 0.3), Color(col, 0.6), Color(col.lightened(0.1), 1.0)]))
	return _finish([[trunk, _bark_mat], [fronds, _plant_mat]])


func _place_paddy_edge_plants() -> void:
	var bananas: Array[ArrayMesh] = [_banana_mesh(41), _banana_mesh(42), _banana_mesh(43)]
	var palms: Array[ArrayMesh] = [_palm_mesh(61), _palm_mesh(62)]
	var bg: Array = [[] as Array[Transform3D], [] as Array[Transform3D], [] as Array[Transform3D]]
	var pg: Array = [[] as Array[Transform3D], [] as Array[Transform3D]]
	for s in terrain.plan.sections:
		var kind: String = s["kind"]
		var z0: float = s["z0"]
		var z1: float = s["z1"]
		# saging by the road edge, on the dikes, under the coconuts
		var bananas_here: float = {"paddy": 0.6, "niyog": 0.5, "clay": 0.05, "end": 0.2}.get(kind, 0.0)
		for k in range(int((z1 - z0) * bananas_here)):
			var z := _rng.randf_range(z0, z1)
			var side := 1.0 if _rng.randf() < 0.5 else -1.0
			var x := terrain.trail_x_at(z) + side * _rng.randf_range(4.8, 14.0 if kind != "niyog" else 40.0)
			if terrain.get_height(x, z) < terrain.water_at(x, z) + 0.05:
				continue  # in the paddy water
			(bg[k % 3] as Array[Transform3D]).append(_ground_xf(x, z, _rng.randf_range(0.8, 1.2), 0.05))
		if kind != "paddy":
			continue
		for k in range(int((z1 - z0) * 0.4)):
			var z := _rng.randf_range(z0, z1)
			var x := _rng.randf_range(20.0, Terrain.WIDTH - 20.0)
			if absf(x - terrain.trail_x_at(z)) < 5.0:
				continue
			# palms stand on the dikes and the road shoulder, not in the water
			if terrain.get_height(x, z) < terrain.water_at(x, z) + 0.1:
				x = terrain.trail_x_at(z) + signf(x - terrain.trail_x_at(z)) * _rng.randf_range(4.8, 6.0)
			(pg[k % 2] as Array[Transform3D]).append(_ground_xf(x, z, _rng.randf_range(0.85, 1.15), 0.1))
	for k in range(terrain.palm_spots.size()):
		(pg[k % 2] as Array[Transform3D]).append(terrain.palm_spots[k])
	for v in range(3):
		_chunked(bananas[v], bg[v], "Saging%d" % v, TREE_CHUNK, TREE_RANGE)
	for v in range(2):
		_chunked(palms[v], pg[v], "Niyog%d" % v, TREE_CHUNK, TREE_RANGE)


# --- grass, ferns, rice ------------------------------------------------------------

func _clump_mesh(blades: int, height: float, spread: float, base: Color, tip: Color, droop: float, seed_v: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var st := MeshKit.begin()
	for k in range(blades):
		var a := rng.randf() * TAU
		var out := Vector3(cos(a), 0, sin(a))
		var root := out * rng.randf_range(0.0, spread)
		var h := height * rng.randf_range(0.6, 1.1)
		var lean := rng.randf_range(0.15, 0.5)
		var pts := PackedVector3Array()
		var w := PackedFloat32Array()
		var cols := PackedColorArray()
		for i in range(4):
			var f := i / 3.0
			pts.append(root + Vector3.UP * h * (f - droop * f * f) + out * h * lean * f * f)
			w.append(lerpf(0.011, 0.0015, f) * (0.6 + height * 0.6))
			var c := base.lerp(tip, f)
			cols.append(Color(c, f))
		_ribbon(st, pts, w, out.cross(Vector3.UP).normalized(), cols)
	return _finish([[st, _plant_mat]])


func _fern_mesh(seed_v: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var st := MeshKit.begin()
	var count := rng.randi_range(6, 9)
	for k in range(count):
		var a := TAU * k / count + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(a), 0, sin(a))
		var length := rng.randf_range(0.7, 1.1)
		var pts := PackedVector3Array()
		var w := PackedFloat32Array()
		var cols := PackedColorArray()
		for i in range(6):
			var f := i / 5.0
			pts.append(out * length * f + Vector3.UP * (0.7 * f - 0.75 * f * f) * length)
			w.append(0.13 * sin(PI * clampf(f + 0.1, 0.0, 1.0)))
			cols.append(Color(Color(0.12, 0.26, 0.06).lerp(Color(0.24, 0.38, 0.1), f), f))
		_ribbon(st, pts, w, out.cross(Vector3.UP).normalized(), cols, 0.3)
	return _finish([[st, _plant_mat]])


func _place_ground_cover() -> void:
	var grass_meshes: Array[ArrayMesh] = [
		_clump_mesh(9, 0.45, 0.12, Color(0.12, 0.2, 0.05), Color(0.36, 0.45, 0.14), 0.1, 1),
		_clump_mesh(12, 0.7, 0.16, Color(0.14, 0.2, 0.05), Color(0.52, 0.5, 0.2), 0.15, 2),  # cogon
		_clump_mesh(7, 0.3, 0.1, Color(0.1, 0.18, 0.04), Color(0.26, 0.4, 0.1), 0.05, 3),
	]
	var rice := _clump_mesh(22, 0.75, 0.05, Color(0.14, 0.28, 0.06), Color(0.36, 0.52, 0.14), 0.3, 4)
	var ferns: Array[ArrayMesh] = [_fern_mesh(7), _fern_mesh(8)]
	# talahib / tall cogon, head-high on a rig: it hides what the trail is doing
	var tall := _clump_mesh(16, 1.35, 0.22, Color(0.16, 0.22, 0.06), Color(0.62, 0.58, 0.32), 0.2, 5)
	var chunks := {}  # Vector2i -> {kind: Array[Transform3D]}

	var add := func(kind: String, xf: Transform3D) -> void:
		var key := Vector2i(int(xf.origin.x / CHUNK), int(xf.origin.z / CHUNK))
		if not chunks.has(key):
			chunks[key] = {}
		var c: Dictionary = chunks[key]
		if not c.has(kind):
			c[kind] = [] as Array[Transform3D]
		(c[kind] as Array[Transform3D]).append(xf)

	var cover := terrain.mud
	var step := 0.75
	var nz := int(terrain.length / step)
	for iz in range(nz):
		var z := (iz + 0.5) * step
		var tx := terrain.trail_x_at(z)
		var kind: String = terrain.plan.section_at(z)["kind"]
		for ix in range(int(Terrain.WIDTH / step)):
			var x := (ix + 0.5) * step + _rng.randf_range(-0.3, 0.3)
			var zz := z + _rng.randf_range(-0.3, 0.3)
			var dx := absf(x - tx)
			if dx > 55.0:
				continue
			var h := terrain.get_height(x, zz)
			if h < terrain.water_at(x, zz) + 0.05:
				continue  # under water: rice goes in separately
			var cell := cover.world_to_cell(Vector2(x, zz))
			var thick := cover.thickness[cover.idx(cell.x, cell.y)]
			var map := terrain._cover(x, zz)
			if map.b > 0.5:
				if dx < 4.3:
					continue  # road
			elif kind == "cogon":
				# the cogon grows right over the faint two-track and hides the pits;
				# only the wheel lines themselves are worn bare
				if absf(dx - 0.8) < 0.35:
					continue
			elif thick > 0.04:
				continue  # trail mud
			# steep cut banks stay bare
			var slope := absf(terrain.get_height(x + 0.5, zz) - terrain.get_height(x - 0.5, zz)) + absf(terrain.get_height(x, zz + 0.5) - terrain.get_height(x, zz - 0.5))
			if slope > 0.9:
				continue
			if map.g > 0.5:
				if _rng.randf() < 0.08:
					add.call("fern%d" % (_rng.randi() % 2), _ground_xf(x, zz, _rng.randf_range(0.7, 1.3)))
				continue
			if map.a > 0.5:
				# lahar sand: the odd tuft of talahib
				if _rng.randf() < 0.05:
					add.call("tall", _ground_xf(x, zz, _rng.randf_range(0.6, 1.0)))
				continue
			if kind == "cogon":
				add.call("tall" if _rng.randf() < 0.7 else "grass1", _ground_xf(x, zz, _rng.randf_range(0.75, 1.25)))
				continue
			var grass := "grass%d" % (1 if _rng.randf() < 0.25 else (0 if _rng.randf() < 0.6 else 2))
			add.call(grass, _ground_xf(x, zz, _rng.randf_range(0.7, 1.3)))

	# rice: rows 0.45 m apart, a hill every 0.35 m, in the flooded paddies only
	for s in terrain.plan.sections:
		if s["kind"] != "paddy":
			continue
		var rz: float = s["z0"] + 1.0
		while rz < float(s["z1"]) - 1.0:
			var level := terrain.water_level_at(rz)
			var rx := 20.0
			while rx < Terrain.WIDTH - 20.0:
				var hx := rx + _rng.randf_range(-0.04, 0.04)
				if absf(hx - terrain.trail_x_at(rz)) > 5.0 and terrain.get_height(hx, rz) < level - 0.05 and terrain.paddy_at(hx, rz) > 0.5:
					var xf := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.85, 1.1)), Vector3(hx, terrain.get_height(hx, rz), rz))
					add.call("rice", xf)
				rx += 0.35
			rz += 0.45

	var kinds := {
		"grass0": grass_meshes[0], "grass1": grass_meshes[1], "grass2": grass_meshes[2],
		"rice": rice, "fern0": ferns[0], "fern1": ferns[1], "tall": tall,
	}
	for key: Vector2i in chunks:
		var centre := Vector3((key.x + 0.5) * CHUNK, 0.0, (key.y + 0.5) * CHUNK)
		centre.y = terrain.get_height(centre.x, centre.z)
		var c: Dictionary = chunks[key]
		for kind: String in c:
			_multi(kinds[kind], c[kind], "%s_%d_%d" % [kind, key.x, key.y], false, 70.0, centre)
