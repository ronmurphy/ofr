class_name CaveGen
extends RefCounted

## Cellular-automata cavern generation.
##
## Random noise, then repeated smoothing: a cell becomes rock if most of its
## neighbours are rock. Four passes is enough to turn static into something
## that reads as carved by water rather than by masons.
##
## The output is trimmed to its single largest connected region, because raw
## CA output is usually several disconnected pockets and an unreachable cave
## is worse than no cave.

const FILL := 0.46
const SMOOTHING_PASSES := 4
const BIRTH_LIMIT := 5

var rng: RandomNumberGenerator

func _init(random: RandomNumberGenerator) -> void:
	rng = random

## Returns a w*h byte grid, 1 where floor.
func generate(w: int, h: int) -> PackedByteArray:
	var cells := PackedByteArray()
	cells.resize(w * h)

	for y in h:
		for x in w:
			# Seal the border so a cave never opens onto the map edge.
			var edge := x == 0 or y == 0 or x == w - 1 or y == h - 1
			cells[y * w + x] = 0 if edge or rng.randf() < FILL else 1

	for _pass in SMOOTHING_PASSES:
		cells = _smooth(cells, w, h)

	return _largest_region(cells, w, h)

func _smooth(cells: PackedByteArray, w: int, h: int) -> PackedByteArray:
	var out := cells.duplicate()
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var walls := 0
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					if dx == 0 and dy == 0:
						continue
					if cells[(y + dy) * w + (x + dx)] == 0:
						walls += 1
			out[y * w + x] = 0 if walls >= BIRTH_LIMIT else 1
	return out

## Flood fill every pocket, keep only the biggest.
func _largest_region(cells: PackedByteArray, w: int, h: int) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(w * h)
	var best: Array[int] = []

	for start in cells.size():
		if cells[start] == 0 or seen[start] != 0:
			continue
		var region: Array[int] = []
		var stack: Array[int] = [start]
		seen[start] = 1
		while not stack.is_empty():
			var i: int = stack.pop_back()
			region.append(i)
			var x: int = i % w
			var y: int = i / w
			for d: Array in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
				var nx: int = x + d[0]
				var ny: int = y + d[1]
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var ni: int = ny * w + nx
				if cells[ni] == 1 and seen[ni] == 0:
					seen[ni] = 1
					stack.append(ni)
		if region.size() > best.size():
			best = region

	var out := PackedByteArray()
	out.resize(w * h)
	for i in best:
		out[i] = 1
	return out
