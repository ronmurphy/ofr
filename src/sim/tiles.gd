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
	## The wrong fungus (Dwarf Fortress plan, 2026-09-29), appended for the same
	## reason. PURPLE is poison -- it will be the miasma's source -- and RED is
	## blood: it crawls toward the dead and, next strand, raises them. Neither
	## can be eaten, standing on either hurts, and fire burns both.
	FUNGUS_PURPLE,
	FUNGUS_RED,
	## A door the gem of the bulwark has barred (6d, 2026-10-01): shut, and
	## nothing that opens doors can open it -- only a bear's shoulder, enough
	## heaving (GameState.BAR_HOLDS), or your own hand lifting the bar.
	## Appended, like everything after CHEST.
	DOOR_BARRED,
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
	FUNGUS_PURPLE: {"id": &"purple_fungus", "walk": true, "clear": true},
	FUNGUS_RED:    {"id": &"red_fungus",    "walk": true, "clear": true},
	# Walkable like a shut door -- walking into it is how you open it -- and
	# as opaque as one.
	DOOR_BARRED:   {"id": &"door_barred",   "walk": true, "clear": false},
	# Walkable on purpose: falling in is always a choice, never an accident.
	# The pathfinder treats it as solid, so neither travel nor a monster will
	# ever route you into one.
	PIT:         {"id": &"pit",         "walk": true,  "clear": true},
	# HIDDEN until spotted (the 2026-09-26 playtest: "if I can spot a trap
	# I'll never step on it"). A hidden trap is not this tile at all -- its
	# square is floor, in GameState.hidden_traps -- so this is only ever a
	# trap you have SEEN: drawn, remembered, and routed round. Spotting is
	# likely in torchlight and unlikely in the dark, which is the point.
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
		or t == MUD or t == BONES or t == FUNGUS or t == FUNGUS_PURPLE or t == FUNGUS_RED

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

## What standing on slow ground is CALLED, for the sidebar's status line and the
## HERE box. Empty for firm ground.
##
## From the 2026-09-26 playtest: "I can't tell that the water and mud and
## gravel do anything." The cost was shown only as a multiplier beside the
## word "footing"; the Legion teen's idea was a status that says what is
## happening to you -- "wading · slowed".
static func footing_word(t: int) -> String:
	match t:
		MUD:    return "sinking"
		WATER:  return "wading"
		RUBBLE: return "scrambling"
		BONES:  return "crunching"
	return ""

## Ground a route should never be planned through, even though a determined
## player may still step there.
##
## NOT the wrong fungus: whether a creature walks through purple or red is its
## own nature (Entity.careful), not a rule of the ground -- see Pathfinder's
## careful grid. Brad, 2026-09-29: crossing it is a CHOICE, never a wall.
static func is_avoided(t: int) -> bool:
	return t == PIT or t == TRAP

## Purple or red: the fungus that hurts, cannot be eaten, and burns.
static func is_bad_fungus(t: int) -> bool:
	return t == FUNGUS_PURPLE or t == FUNGUS_RED

## How far the noise of crossing this carries. Zero for anything quiet.
##
## Water splashes (Brad, 2026-10-01: washing the red off had to COST
## something, and the cost is noise). WADING_NOISE sits under a fight's 6 and
## the bones' 7: it never raises a grave, but the blind risen hear it, so a
## pool is a choice -- wash, and what the red already has comes to the sound.
static func noise_radius(t: int) -> int:
	if t == BONES:
		return 7
	if t == WATER:
		return WADING_NOISE
	return 0
const WADING_NOISE := 4

static func is_luminous(t: int) -> bool:
	return t == FUNGUS or t == FUNGUS_PURPLE or t == FUNGUS_RED
