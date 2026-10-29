class_name BodyKit
extends RefCounted
## What every body needs round its wheels, so the tires never meet the body:
## wheel wells that clear a tire at the bump stop, floors that stay inboard
## of the tires, and collision boxes split round the wheels (nothing solid
## where a tire can go, only above it). Sizes come from the rig's RigSpec.


## Radius of a wheel well round the hub at ride height: clears the tire at
## the bump stop with a few centimetres to spare.
static func well_radius(spec: RigSpec) -> float:
	return spec.max_tire_top() - RigSpec.RIDE_HUB_Y + 0.04


## Wheel wells on both sides at axle `zc`: an arched roof over the tire from
## the inner tub wall out to the body side at `x_out`, and the inner wall
## itself, both down to `bottom_y`.
static func wheel_houses(st: SurfaceTool, spec: RigSpec, zc: float, x_out: float, bottom_y: float, col: Color) -> void:
	var r := well_radius(spec)
	var hub := RigSpec.RIDE_HUB_Y
	var x_in := spec.tire_inner()
	var lim := acos(clampf((bottom_y - hub) / r, -1.0, 1.0))
	var n := 20
	for sx: float in [-1.0, 1.0]:
		var xi := sx * x_in
		var xo := sx * x_out
		for i in range(n):
			var a0 := lerpf(-lim, lim, float(i) / n)
			var a1 := lerpf(-lim, lim, float(i + 1) / n)
			var p0 := Vector2(sin(a0) * r, cos(a0) * r)
			var p1 := Vector2(sin(a1) * r, cos(a1) * r)
			var n0 := -Vector3(0, p0.y, p0.x).normalized()
			var n1 := -Vector3(0, p1.y, p1.x).normalized()
			# the roof of the well, facing the tire
			MeshKit._quad(st, Transform3D.IDENTITY,
				[Vector3(xi, hub + p0.y, zc + p0.x), Vector3(xo, hub + p0.y, zc + p0.x),
				Vector3(xo, hub + p1.y, zc + p1.x), Vector3(xi, hub + p1.y, zc + p1.x)],
				[n0, n0, n1, n1], col)
			# the inner wall, a fan from the hub height down to the bottom edge
			var wn := Vector3(sx, 0, 0)
			var b0 := Vector3(xi, bottom_y, zc + p0.x)
			var b1 := Vector3(xi, bottom_y, zc + p1.x)
			MeshKit._quad(st, Transform3D.IDENTITY,
				[b0, b1, Vector3(xi, hub + p1.y, zc + p1.x), Vector3(xi, hub + p0.y, zc + p0.x)],
				[wn, wn, wn, wn], col)


## A floor from z0 to z1 at height y, `half_w` wide, narrowed to inboard of
## the tires wherever it passes over a wheel.
static func floor_panel(st: SurfaceTool, spec: RigSpec, z0: float, z1: float, half_w: float, y: float, col: Color) -> void:
	var r := well_radius(spec)
	var inner := minf(half_w, spec.tire_inner() - 0.01)
	MeshKit.rounded_box(st, Vector3(inner * 2.0, 0.04, z1 - z0), 0.01, Transform3D(Basis.IDENTITY, Vector3(0, y, (z0 + z1) * 0.5)), col)
	if half_w <= inner:
		return
	for seg in _clear_of_wheels(spec, z0, z1, r):
		var a: float = seg[0]
		var b: float = seg[1]
		for sx: float in [-1.0, 1.0]:
			MeshKit.rounded_box(st, Vector3(half_w - inner, 0.04, b - a), 0.01,
				Transform3D(Basis.IDENTITY, Vector3(sx * (half_w + inner) * 0.5, y, (a + b) * 0.5)), col)


## A solid box of body for the physics, z0..z1, y0..y1, `half_w` wide, split
## so it never fills the space a tire moves through: full width away from the
## wheels, over a wheel only above its well, and a core between the tires.
static func collide(rig: Rig, z0: float, z1: float, y0: float, y1: float, half_w: float) -> void:
	var spec := rig.spec
	var inner := minf(half_w, spec.tire_inner() - 0.02)
	var r := well_radius(spec)
	_box(rig, Vector3(inner * 2.0, y1 - y0, z1 - z0), Vector3(0, (y0 + y1) * 0.5, (z0 + z1) * 0.5))
	if half_w <= inner:
		return
	var w := half_w - inner
	for seg in _clear_of_wheels(spec, z0, z1, r):
		var a: float = seg[0]
		var b: float = seg[1]
		for sx: float in [-1.0, 1.0]:
			_box(rig, Vector3(w, y1 - y0, b - a), Vector3(sx * (half_w + inner) * 0.5, (y0 + y1) * 0.5, (a + b) * 0.5))
	var top := maxf(y0, RigSpec.RIDE_HUB_Y + r)
	if top < y1:
		for zc: float in [spec.front_z, spec.rear_z]:
			var a := maxf(z0, zc - r)
			var b := minf(z1, zc + r)
			if b > a:
				for sx: float in [-1.0, 1.0]:
					_box(rig, Vector3(w, y1 - top, b - a), Vector3(sx * (half_w + inner) * 0.5, (top + y1) * 0.5, (a + b) * 0.5))


## A plain collision box (bumpers, cab tops: things no tire reaches).
static func _box(rig: Rig, size: Vector3, at: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = at
	rig.add_child(cs)


## The stretches of z0..z1 that don't pass over either wheel.
static func _clear_of_wheels(spec: RigSpec, z0: float, z1: float, r: float) -> Array:
	var out := []
	var a := z0
	for zc: float in [spec.front_z, spec.rear_z]:
		var w0 := zc - r
		var w1 := zc + r
		if w1 <= a or w0 >= z1:
			continue
		if w0 > a:
			out.append([a, w0])
		a = maxf(a, w1)
	if a < z1:
		out.append([a, z1])
	return out
