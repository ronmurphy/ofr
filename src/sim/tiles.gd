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
	PILLAR,
	RUBBLE,
	WATER,
	ROCK,
	CAVE_FLOOR,
	STALAGMITE,
	BRAZIER_SPENT,
	STAIRS_UP,
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
	# A pillar is the inverse -- solid AND opaque, so it throws a real shadow
	# and gives you something to break line of sight behind.
	PILLAR:      {"id": &"pillar",      "walk": false, "clear": false},
	RUBBLE:      {"id": &"rubble",      "walk": true,  "clear": true},
	WATER:       {"id": &"water",       "walk": true,  "clear": true},
	# Natural stone, as opposed to WALL's masonry. Drawn differently.
	ROCK:        {"id": &"rock",        "walk": false, "clear": false},
	CAVE_FLOOR:  {"id": &"cave_floor",  "walk": true,  "clear": true},
	# A pillar's natural cousin. Caves were open killing floors without them,
	# which left ranged monsters with no counter-play in exactly the place the
	# generator liked to put them.
	STALAGMITE:  {"id": &"stalagmite",  "walk": false, "clear": false},
	# A brazier you have already burned down. Still an obstacle, no longer a
	# light, and visibly dead so you can see at a glance which ones are used.
	BRAZIER_SPENT: {"id": &"brazier_spent", "walk": false, "clear": true},
	STAIRS_UP:   {"id": &"stairs_up",   "walk": true,  "clear": true},
}

static func is_walkable(t: int) -> bool:
	return DATA[t]["walk"]

static func is_transparent(t: int) -> bool:
	return DATA[t]["clear"]

static func appearance_id(t: int) -> StringName:
	return DATA[t]["id"]

## Anything an actor can stand on. Used by generation and decoration to avoid
## painting over a corridor or a staircase.
static func is_open_floor(t: int) -> bool:
	return t == FLOOR or t == CAVE_FLOOR or t == RUBBLE or t == WATER
