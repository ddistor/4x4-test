class_name MudField
extends RefCounted
## Per-cell soft-ground data for the trail. Lives alongside the terrain
## heightmap. The physics collider is the *firm* base; everything here is
## the soft layer on top of it that tires sink into and carve ruts through.
##
## Per cell:
##   thickness  - metres of soft mud sitting on the firm base (0 = hard ground)
##   wetness    - 0 dry clay .. 1 water-saturated soup
##   rut        - metres already carved out / compacted by tires (<= thickness);
##                negative where displaced mud has piled up above the surface
##
## Lateritic clay in Morong behaves two ways: dry it is firm and grippy, wet it
## is slick on the surface and sucks the wheel down. Both axes matter.

var width: int
var height: int
var cell_size: float
var origin: Vector2  # world XZ of cell (0,0)

var thickness: PackedFloat32Array
var wetness: PackedFloat32Array
var rut: PackedFloat32Array  # negative = mud piled above the surface (berms, flung clods)
## 0..1 how worn the cover is: tires rolling over grass flatten it and wear it
## to bare dirt (the texture's alpha: the ground and grass shaders read it)
var wear: PackedFloat32Array

const MAX_PILE := 0.3

## RGB float image: R = rut depth (m), G = wetness, B = thickness (m). Sampled by the terrain shader.
var image: Image
var texture: ImageTexture
var _dirty := false


func _init(p_width: int, p_height: int, p_cell_size: float, p_origin: Vector2) -> void:
	width = p_width
	height = p_height
	cell_size = p_cell_size
	origin = p_origin
	var n := width * height
	thickness.resize(n)
	wetness.resize(n)
	rut.resize(n)
	wear.resize(n)
	wear.fill(0.0)
	thickness.fill(0.0)
	wetness.fill(0.0)
	rut.fill(0.0)
	image = Image.create(width, height, false, Image.FORMAT_RGBAF)
	texture = ImageTexture.create_from_image(image)


func idx(cx: int, cy: int) -> int:
	return cy * width + cx


func world_to_cell(world_xz: Vector2) -> Vector2i:
	var c := (world_xz - origin) / cell_size
	return Vector2i(clampi(int(floor(c.x)), 0, width - 1), clampi(int(floor(c.y)), 0, height - 1))


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


## Bilinear sample of all three channels at a world XZ position.
func sample(world_xz: Vector2) -> Dictionary:
	var c := (world_xz - origin) / cell_size - Vector2(0.5, 0.5)
	var x0 := clampi(int(floor(c.x)), 0, width - 2)
	var y0 := clampi(int(floor(c.y)), 0, height - 2)
	var tx := clampf(c.x - x0, 0.0, 1.0)
	var ty := clampf(c.y - y0, 0.0, 1.0)
	var i00 := idx(x0, y0)
	var i10 := idx(x0 + 1, y0)
	var i01 := idx(x0, y0 + 1)
	var i11 := idx(x0 + 1, y0 + 1)
	return {
		"thickness": _bilerp(thickness[i00], thickness[i10], thickness[i01], thickness[i11], tx, ty),
		"wetness": _bilerp(wetness[i00], wetness[i10], wetness[i01], wetness[i11], tx, ty),
		"rut": _bilerp(rut[i00], rut[i10], rut[i01], rut[i11], tx, ty),
	}


func _bilerp(a: float, b: float, c: float, d: float, tx: float, ty: float) -> float:
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


## Carve a rut: a tire pressed `amount` metres further into the soft layer
## around world position. Radius is the tire half-width. Returns the actual
## depth carved (limited by remaining soft mud).
func carve(world_xz: Vector2, radius: float, amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var centre := world_to_cell(world_xz)
	var r_cells := maxi(1, int(ceil(radius / cell_size)))
	var carved := 0.0
	for dy in range(-r_cells, r_cells + 1):
		for dx in range(-r_cells, r_cells + 1):
			var c := centre + Vector2i(dx, dy)
			if not in_bounds(c):
				continue
			var cell_world := origin + (Vector2(c) + Vector2(0.5, 0.5)) * cell_size
			var d := cell_world.distance_to(world_xz)
			if d > radius + cell_size * 0.5:
				continue
			var falloff := 1.0 - clampf(d / (radius + cell_size * 0.5), 0.0, 1.0)
			var i := idx(c.x, c.y)
			var room := thickness[i] - rut[i]
			if room <= 0.0:
				continue
			var dr := minf(room, amount * falloff)
			rut[i] += dr
			carved = maxf(carved, dr)
			image.set_pixel(c.x, c.y, Color(rut[i], wetness[i], thickness[i], wear[i]))
	if carved > 0.0:
		_dirty = true
	return carved


## Press a tire's footprint to `depth` below the original surface: every cell
## under it (`radius` across, a softened edge) is cut down to at least that
## depth, never past the soft layer. Nothing happens where it's already that
## deep, so a tire sitting still doesn't keep digging. The cell keeps its own
## wetness: a rut only holds water where the ground was wet already (rain,
## a high water table), never because it was dug. Returns the deepest
## amount it had to cut this time (what gets shoved into the berms).
func carve_to(world_xz: Vector2, radius: float, depth: float) -> float:
	if depth <= 0.0:
		return 0.0
	var centre := world_to_cell(world_xz)
	var r_cells := maxi(1, int(ceil(radius / cell_size)))
	var cut := 0.0
	for dy in range(-r_cells, r_cells + 1):
		for dx in range(-r_cells, r_cells + 1):
			var c := centre + Vector2i(dx, dy)
			if not in_bounds(c):
				continue
			var cell_world := origin + (Vector2(c) + Vector2(0.5, 0.5)) * cell_size
			var d := cell_world.distance_to(world_xz)
			# full depth under the tread, rounding off over the shoulder
			var shape := 1.0 - smoothstep(radius * 0.5, radius + cell_size * 1.5, d)   # walls slump, not sheer
			if shape <= 0.0:
				continue
			var i := idx(c.x, c.y)
			var want := minf(depth * shape, thickness[i])
			if want > rut[i] + 0.001:
				cut = maxf(cut, want - maxf(rut[i], 0.0))
				rut[i] = want
				image.set_pixel(c.x, c.y, Color(rut[i], wetness[i], thickness[i], wear[i]))
	if cut > 0.0:
		_dirty = true
	return cut


## Pile displaced mud on the surface round a point: the berms a tire shoves
## up beside its rut, and clods a spinning tire throws behind it. Stored as
## negative rut (mud above the original surface), so the terrain shader
## raises the ground there and the wheels treat it as more soft clay.
func deposit(world_xz: Vector2, radius: float, amount: float, wet: float) -> void:
	if amount <= 0.0:
		return
	var centre := world_to_cell(world_xz)
	var r_cells := maxi(1, int(ceil(radius / cell_size)))
	for dy in range(-r_cells, r_cells + 1):
		for dx in range(-r_cells, r_cells + 1):
			var c := centre + Vector2i(dx, dy)
			if not in_bounds(c):
				continue
			var cell_world := origin + (Vector2(c) + Vector2(0.5, 0.5)) * cell_size
			var falloff := 1.0 - clampf(cell_world.distance_to(world_xz) / (radius + cell_size * 0.5), 0.0, 1.0)
			if falloff <= 0.0:
				continue
			var i := idx(c.x, c.y)
			rut[i] = maxf(rut[i] - amount * falloff, -MAX_PILE)
			wetness[i] = lerpf(wetness[i], maxf(wetness[i], wet), falloff * 0.5)
			image.set_pixel(c.x, c.y, Color(rut[i], wetness[i], thickness[i], wear[i]))
	_dirty = true


## Push the whole image to the GPU if anything changed. Call once per frame.
## A tire rolling over `world_xz` (`radius` across) wears the cover there a
## little: `amount` per pass at the middle, softer at the edge.
func wear_at(world_xz: Vector2, radius: float, amount: float) -> void:
	if amount <= 0.0:
		return
	var centre := world_to_cell(world_xz)
	var r_cells := maxi(1, int(ceil(radius / cell_size)))
	for dy in range(-r_cells, r_cells + 1):
		for dx in range(-r_cells, r_cells + 1):
			var c := centre + Vector2i(dx, dy)
			if not in_bounds(c):
				continue
			var d := (origin + (Vector2(c) + Vector2(0.5, 0.5)) * cell_size).distance_to(world_xz)
			if d > radius + cell_size * 0.5:
				continue
			var i := idx(c.x, c.y)
			if wear[i] >= 1.0:
				continue
			wear[i] = minf(1.0, wear[i] + amount * (1.0 - clampf(d / (radius + cell_size * 0.5), 0.0, 1.0)))
			image.set_pixel(c.x, c.y, Color(rut[i], wetness[i], thickness[i], wear[i]))
			_dirty = true


func flush() -> void:
	if _dirty:
		texture.update(image)
		_dirty = false


## Rebuild the image from the arrays (after authoring the field).
func bake_image() -> void:
	for y in range(height):
		for x in range(width):
			var i := idx(x, y)
			image.set_pixel(x, y, Color(rut[i], wetness[i], thickness[i], wear[i]))
	texture.update(image)
	_dirty = false
