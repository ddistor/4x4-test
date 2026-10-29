class_name MeshKit
extends RefCounted
## Tiny procedural modelling kit: rounded boxes, tubes, lathes and tori
## appended into a SurfaceTool in a given transform. The whole rig is built
## from these so it stays in text.
##
## Vertex colour is free for shader masks (the tire shader reads it).
## Winding is fixed up per triangle from the normals, so mirrored
## transforms and either profile direction come out facing the right way.


static func begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func commit(st: SurfaceTool, mat: Material) -> ArrayMesh:
	var m := st.commit()
	m.surface_set_material(0, mat)
	return m


static func _tri(st: SurfaceTool, xf: Transform3D, p: Array[Vector3], n: Array[Vector3], col: Color) -> void:
	var nb := xf.basis.inverse().transposed()
	var wp: Array[Vector3] = [xf * p[0], xf * p[1], xf * p[2]]
	var wn: Array[Vector3] = [(nb * n[0]).normalized(), (nb * n[1]).normalized(), (nb * n[2]).normalized()]
	var face := (wp[2] - wp[0]).cross(wp[1] - wp[0])
	if face.length_squared() < 1e-14:
		return
	# Godot front faces are clockwise: face normal (c-a)x(b-a) must agree with the shading normal.
	var order := [0, 1, 2] if face.dot(wn[0] + wn[1] + wn[2]) >= 0.0 else [0, 2, 1]
	for k: int in order:
		st.set_color(col)
		st.set_normal(wn[k])
		st.add_vertex(wp[k])


static func _quad(st: SurfaceTool, xf: Transform3D, p: Array[Vector3], n: Array[Vector3], col: Color) -> void:
	_tri(st, xf, [p[0], p[1], p[2]], [n[0], n[1], n[2]], col)
	_tri(st, xf, [p[0], p[2], p[3]], [n[0], n[2], n[3]], col)


## Box with every edge rounded to radius `r`. Centred on the origin of `xf`.
static func rounded_box(st: SurfaceTool, size: Vector3, r: float, xf: Transform3D, col: Color, segs := 3) -> void:
	var h := size * 0.5
	r = clampf(r, 0.0005, minf(h.x, minf(h.y, h.z)))
	var inner := h - Vector3(r, r, r)
	# Per-axis sample coordinates: dense across the rounded zones, one span across the flat.
	var samples: Array[PackedFloat32Array] = []
	for a in range(3):
		var s := PackedFloat32Array()
		for k in range(segs + 1):
			s.append(-h[a] + r * k / segs)
		for k in range(segs + 1):
			s.append(inner[a] + r * k / segs)
		samples.append(s)
	for axis in range(3):
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		for sgn: float in [-1.0, 1.0]:
			var su := samples[u]
			var sv := samples[v]
			for i in range(su.size() - 1):
				for j in range(sv.size() - 1):
					var ps: Array[Vector3] = []
					var ns: Array[Vector3] = []
					for c: Vector2i in [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]:
						var q := Vector3.ZERO
						q[axis] = sgn * h[axis]
						q[u] = su[c.x]
						q[v] = sv[c.y]
						var cl := q.clamp(-inner, inner)
						var nn := (q - cl).normalized()
						ps.append(cl + nn * r)
						ns.append(nn)
					_quad(st, xf, ps, ns, col)


## Surface of revolution about local Y. `profile` is (radius, y) points; go
## from the bottom, out along the outside, to the top, so normals face out.
## Corners sharper than ~40 degrees stay crisp.
static func lathe(st: SurfaceTool, profile: Array[Vector2], xf: Transform3D, col: Color, sides := 16) -> void:
	var seg_n: Array[Vector2] = []
	for i in range(profile.size() - 1):
		var t := profile[i + 1] - profile[i]
		seg_n.append(Vector2(t.y, -t.x).normalized())
	for i in range(profile.size() - 1):
		var n0 := seg_n[i]
		var n1 := seg_n[i]
		if i > 0 and seg_n[i - 1].dot(seg_n[i]) > 0.75:
			n0 = (seg_n[i - 1] + seg_n[i]).normalized()
		if i < seg_n.size() - 1 and seg_n[i + 1].dot(seg_n[i]) > 0.75:
			n1 = (seg_n[i + 1] + seg_n[i]).normalized()
		var a := profile[i]
		var b := profile[i + 1]
		for k in range(sides):
			var f0 := TAU * k / sides
			var f1 := TAU * (k + 1) / sides
			var c0 := Vector2(cos(f0), sin(f0))
			var c1 := Vector2(cos(f1), sin(f1))
			_quad(st, xf,
				[Vector3(a.x * c0.x, a.y, a.x * c0.y), Vector3(b.x * c0.x, b.y, b.x * c0.y),
				 Vector3(b.x * c1.x, b.y, b.x * c1.y), Vector3(a.x * c1.x, a.y, a.x * c1.y)],
				[Vector3(n0.x * c0.x, n0.y, n0.x * c0.y), Vector3(n1.x * c0.x, n1.y, n1.x * c0.y),
				 Vector3(n1.x * c1.x, n1.y, n1.x * c1.y), Vector3(n0.x * c1.x, n0.y, n0.x * c1.y)],
				col)


## Closed cylinder along local Y.
static func cylinder(st: SurfaceTool, radius: float, height: float, xf: Transform3D, col: Color, sides := 14) -> void:
	var hh := height * 0.5
	var bev := minf(radius, hh) * 0.15
	lathe(st, [Vector2(0, -hh), Vector2(radius - bev, -hh), Vector2(radius, -hh + bev),
		Vector2(radius, hh - bev), Vector2(radius - bev, hh), Vector2(0, hh)], xf, col, sides)


## Ring about local Y: `major` to the tube centre, `minor` tube radius.
static func torus(st: SurfaceTool, major: float, minor: float, xf: Transform3D, col: Color, sides := 24, rings := 8) -> void:
	var prof: Array[Vector2] = []
	for k in range(rings + 1):
		var t := -PI * 0.5 + TAU * k / rings
		prof.append(Vector2(major + minor * cos(t), minor * sin(t)))
	lathe(st, prof, xf, col, sides)


## Tube between two points (in the space of `xf`).
static func tube(st: SurfaceTool, a: Vector3, b: Vector3, radius: float, xf: Transform3D, col: Color, sides := 10) -> void:
	var axis := b - a
	var y := axis.normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	var local := Transform3D(Basis(x, y, z), (a + b) * 0.5)
	cylinder(st, radius, axis.length(), xf * local, col, sides)


## Tapered tube along a polyline (trunks, branches, culms). Frames are carried
## along the path so it doesn't twist; ends are left open.
static func sweep(st: SurfaceTool, pts: PackedVector3Array, radii: PackedFloat32Array, xf: Transform3D, col: Color, sides := 8) -> void:
	var n := pts.size()
	var rings: Array[PackedVector3Array] = []
	var norms: Array[PackedVector3Array] = []
	var t0 := (pts[1] - pts[0]).normalized()
	var side := t0.cross(Vector3.FORWARD if absf(t0.z) < 0.9 else Vector3.RIGHT).normalized()
	for i in range(n):
		var t := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		side = (side - t * side.dot(t)).normalized()
		var up := t.cross(side)
		var ring := PackedVector3Array()
		var nr := PackedVector3Array()
		for k in range(sides):
			var a := TAU * k / sides
			var d := side * cos(a) + up * sin(a)
			ring.append(pts[i] + d * radii[i])
			nr.append(d)
		rings.append(ring)
		norms.append(nr)
	for i in range(n - 1):
		for k in range(sides):
			var k1 := (k + 1) % sides
			_quad(st, xf, [rings[i][k], rings[i + 1][k], rings[i + 1][k1], rings[i][k1]],
				[norms[i][k], norms[i + 1][k], norms[i + 1][k1], norms[i][k1]], col)


static func sphere(st: SurfaceTool, radius: float, xf: Transform3D, col: Color, sides := 14) -> void:
	var prof: Array[Vector2] = []
	var rings := sides / 2
	for k in range(rings + 1):
		var t := -PI * 0.5 + PI * k / rings
		prof.append(Vector2(radius * cos(t), radius * sin(t)))
	lathe(st, prof, xf, col, sides)


## Basis whose local Y points along `dir` (for lathes/cylinders).
static func y_to(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))
