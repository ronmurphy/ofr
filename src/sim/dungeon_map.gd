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
## Parallel to `tiles`: what each cell is built from. See Materials.
var material: PackedByteArray
var explored: PackedByteArray
var visible_now: PackedByteArray

func _init(w: int, h: int) -> void:
	width = w
	height = h
	var n := w * h
	tiles.resize(n)
	tiles.fill(Tiles.VOID)
	material.resize(n)
	material.fill(Materials.STONE)
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

func material_at(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return Materials.STONE
	return material[idx(x, y)]

## Paints a rectangle, including one cell of surrounding wall so a room's
## masonry carries its own material rather than the corridor's.
func paint_material(rect: Rect2i, m: int) -> void:
	var grown := rect.grow(1)
	for y in range(grown.position.y, grown.end.y):
		for x in range(grown.position.x, grown.end.x):
			if in_bounds(x, y):
				material[idx(x, y)] = m

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

## Overview/debug helper: treat every cell as currently lit.
##
## This exists as a method rather than being done from outside because
## `some_map.visible_now.fill(1)` mutates a COPY -- PackedArrays are
## copy-on-write, and reaching through a property hands you a temporary. Inside
## the class the member access is direct and the write sticks.
func set_all_visible() -> void:
	visible_now.fill(1)
