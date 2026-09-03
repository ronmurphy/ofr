class_name Fov
extends RefCounted

## Recursive shadowcasting field of view.
##
## Writes into a caller-supplied byte buffer rather than onto the map, so the
## same routine serves two different jobs: the player's line of sight, and the
## occlusion pass for every individual light source. That is the whole reason
## a torch's glow stops at a wall corner instead of bleeding through it.

# Eight octant transforms. Each column is one octant.
const XX := [1,  0,  0, -1, -1,  0,  0,  1]
const XY := [0,  1, -1,  0,  0, -1,  1,  0]
const YX := [0,  1,  1,  0,  0, -1, -1,  0]
const YY := [1,  0,  0,  1, -1,  0,  0, -1]

## Fills `out` with 1 for every cell visible from (ox, oy) within `radius`.
static func compute(map: DungeonMap, ox: int, oy: int, radius: int, out: PackedByteArray) -> void:
	out.fill(0)
	if not map.in_bounds(ox, oy):
		return
	out[map.idx(ox, oy)] = 1
	for oct in 8:
		_cast(map, out, ox, oy, 1, 1.0, 0.0, radius, XX[oct], XY[oct], YX[oct], YY[oct])

static func _cast(map: DungeonMap, out: PackedByteArray, cx: int, cy: int, row: int,
		start: float, end: float, radius: int, xx: int, xy: int, yx: int, yy: int) -> void:
	if start < end:
		return
	var radius2 := radius * radius
	for j in range(row, radius + 1):
		var dx := -j - 1
		var dy := -j
		var blocked := false
		var new_start := 0.0
		while dx <= 0:
			dx += 1
			var l_slope := (dx - 0.5) / (dy + 0.5)
			var r_slope := (dx + 0.5) / (dy - 0.5)
			if start < r_slope:
				continue
			elif end > l_slope:
				break

			var mx := cx + dx * xx + dy * xy
			var my := cy + dx * yx + dy * yy

			if map.in_bounds(mx, my) and dx * dx + dy * dy <= radius2:
				out[map.idx(mx, my)] = 1

			# Out of bounds counts as opaque, which correctly seals the map edge.
			var clear := map.is_transparent(mx, my)

			if blocked:
				if not clear:
					new_start = r_slope
					continue
				blocked = false
				start = new_start
			elif not clear and j < radius:
				blocked = true
				_cast(map, out, cx, cy, j + 1, start, l_slope, radius, xx, xy, yx, yy)
				new_start = r_slope
		if blocked:
			break
