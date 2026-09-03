class_name DungeonMap
extends RefCounted

## A level's terrain plus the player's knowledge of it.
##
## Three visibility states are tracked, because they are three different
## things and conflating them is the classic beginner mistake:
##   visible  - lit and in line of sight RIGHT NOW
##   explored - seen at some point, drawn dim from memory
##   neither  - never seen, drawn as nothing at all

var width: int
var height: int
var tiles: PackedByteArray
var explored: PackedByteArray
var visible_now: PackedByteArray

func _init(w: int, h: int) -> void:
	width = w
	height = h
	var n := w * h
	tiles.resize(n)
	tiles.fill(Tiles.VOID)
	explored.resize(n)
	visible_now.resize(n)

func idx(x: int, y: int) -> int:
	return y * width + x

func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height

func get_tile(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return Tiles.VOID
	return tiles[idx(x, y)]

func set_tile(x: int, y: int, t: int) -> void:
	if in_bounds(x, y):
		tiles[idx(x, y)] = t

func is_walkable(x: int, y: int) -> bool:
	return Tiles.is_walkable(get_tile(x, y))

func is_transparent(x: int, y: int) -> bool:
	return Tiles.is_transparent(get_tile(x, y))

func is_visible(x: int, y: int) -> bool:
	return in_bounds(x, y) and visible_now[idx(x, y)] != 0

func is_explored(x: int, y: int) -> bool:
	return in_bounds(x, y) and explored[idx(x, y)] != 0

## Fold the current field of view into permanent memory.
func remember_visible() -> void:
	for i in visible_now.size():
		if visible_now[i] != 0:
			explored[i] = 1

func clear_visible() -> void:
	visible_now.fill(0)

func reveal_all() -> void:
	explored.fill(1)
