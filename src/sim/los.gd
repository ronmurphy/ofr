class_name Los
extends RefCounted

## Bresenham line-of-sight between two cells.
##
## Separate from Fov on purpose. Field of view answers "what can this actor see"
## and costs a full shadowcast; this answers "is there a clear line from A to B"
## for one pair, which is what a ranged attack actually needs and is far cheaper
## to ask once per archer per turn.
##
## Both endpoints are excluded from the opacity test: an archer standing in a
## doorway can still shoot out of it, and you can always be shot at even if you
## are standing in something opaque.

static func clear(map: DungeonMap, x0: int, y0: int, x1: int, y1: int) -> bool:
	var dx := absi(x1 - x0)
	var dy := absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx - dy
	var x := x0
	var y := y0

	while true:
		if x == x1 and y == y1:
			return true
		var e2 := err * 2
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy
		if x == x1 and y == y1:
			return true
		if not map.is_transparent(x, y):
			return false
	return true

## The cells a projectile crosses, excluding the origin and including the
## target. Purely for animation -- the shot itself has already resolved.
static func path(x0: int, y0: int, x1: int, y1: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var dx := absi(x1 - x0)
	var dy := absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx - dy
	var x := x0
	var y := y0
	for _guard in 512:
		if x == x1 and y == y1:
			break
		var e2 := err * 2
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy
		out.append(Vector2i(x, y))
	return out

## Chebyshev distance -- the right metric on an 8-way grid, where a diagonal
## step costs the same as a straight one.
static func steps(x0: int, y0: int, x1: int, y1: int) -> int:
	return maxi(absi(x1 - x0), absi(y1 - y0))
