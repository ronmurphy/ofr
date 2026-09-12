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
	SHRINE,
	MUD,
	BONES,
	FUNGUS,
	PIT,
	TRAP,
	BRAZIER_DEAD,
	GRAVE,
	## A chest. Appended last -- tiles are saved as integers, so inserting
	## would rewrite what every existing suspend means.
	CHEST,
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
	# Stood upon, not bumped into. Praying is a deliberate key, so a curse can
	# never be triggered by walking.
	SHRINE:      {"id": &"shrine",      "walk": true,  "clear": true},
	MUD:         {"id": &"mud",         "walk": true,  "clear": true},
	# Loose and loud. Crossing it is heard.
	BONES:       {"id": &"bones",       "walk": true,  "clear": true},
	# Faintly luminous. Light you did not have to carry, and cannot put out.
	FUNGUS:      {"id": &"fungus",      "walk": true,  "clear": true},
	# Walkable on purpose: falling in is always a choice, never an accident.
	# The pathfinder treats it as solid, so neither travel nor a monster will
	# ever route you into one.
	PIT:         {"id": &"pit",         "walk": true,  "clear": true},
	# Visible on purpose. Every death in this game should be one the player
	# could have avoided, and a hidden trap is the one thing that guarantees
	# otherwise. You can see it, the pathfinder goes round it, so springing one
	# is always a choice.
	TRAP:        {"id": &"trap",        "walk": true,  "clear": true},
	# Forged in, and finished. Not even the shrine of embers finds anything
	# left to catch. Appended to the enum rather than filed beside its two
	# siblings on purpose: tiles are saved as raw bytes, so inserting an id in
	# the middle would renumber every tile in every existing save.
	BRAZIER_DEAD: {"id": &"brazier_dead", "walk": false, "clear": true},
	# Walkable, unlike every other standing feature. A headstone you could not
	# step onto would be one more thing generation has to prove it never wedged
	# into a corridor; walkable, it can be dropped anywhere a monster could
	# stand and cannot block a route by construction. Standing on the grave to
	# read it is also the better image.
	GRAVE:       {"id": &"grave",        "walk": true,  "clear": true},
	## Solid on purpose: you open it by walking INTO it, the way a door works,
	## so no key is needed and the act is unmistakably deliberate. A walkable
	## chest would be one you could cross without noticing.
	CHEST:       {"id": &"chest",        "walk": false, "clear": true},
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
	return t == FLOOR or t == CAVE_FLOOR or t == RUBBLE or t == WATER \
		or t == MUD or t == BONES or t == FUNGUS

## What it costs to step onto this, as a multiple of an ordinary stride.
##
## Applied to the ACTION, not to the actor's speed. Slowing the actor would
## slow everything it does, including swinging -- but mud does not make you a
## worse fighter, only a slower traveller.
static func move_cost(t: int) -> float:
	match t:
		MUD:    return 2.0
		WATER:  return 1.4
		RUBBLE: return 1.3
		BONES:  return 1.2
	return 1.0

## Ground a route should never be planned through, even though a determined
## player may still step there.
static func is_avoided(t: int) -> bool:
	return t == PIT or t == TRAP

## How far the noise of crossing this carries. Zero for anything quiet.
static func noise_radius(t: int) -> int:
	return 7 if t == BONES else 0

static func is_luminous(t: int) -> bool:
	return t == FUNGUS
