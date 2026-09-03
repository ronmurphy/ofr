class_name Tiles
extends RefCounted

## Tile type definitions.
##
## The simulation stores tiles as small integer ids. Everything about how a
## tile LOOKS lives in the render theme, keyed by the semantic `id` below --
## never here. That seam is what lets a Kenney tileset drop in later without
## the simulation knowing anything changed.

enum {
	VOID,
	FLOOR,
	WALL,
	DOOR_CLOSED,
	DOOR_OPEN,
	STAIRS_DOWN,
	BRAZIER,
}

## walk  = an actor may stand here
## clear = light and line-of-sight pass through
const DATA := {
	VOID:        {"id": &"void",        "walk": false, "clear": false},
	FLOOR:       {"id": &"floor",       "walk": true,  "clear": true},
	WALL:        {"id": &"wall",        "walk": false, "clear": false},
	DOOR_CLOSED: {"id": &"door_closed", "walk": true,  "clear": false},
	DOOR_OPEN:   {"id": &"door_open",   "walk": true,  "clear": true},
	STAIRS_DOWN: {"id": &"stairs_down", "walk": true,  "clear": true},
	# Waist-high: you cannot walk through it, but you can see over it.
	BRAZIER:     {"id": &"brazier",     "walk": false, "clear": true},
}

static func is_walkable(t: int) -> bool:
	return DATA[t]["walk"]

static func is_transparent(t: int) -> bool:
	return DATA[t]["clear"]

static func appearance_id(t: int) -> StringName:
	return DATA[t]["id"]
