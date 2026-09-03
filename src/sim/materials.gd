class_name Materials
extends RefCounted

## What a stretch of the dungeon is made of.
##
## Semantic, like a tile id -- the simulation says "this is a flooded crypt"
## and the render theme decides what colour that is. The generator already
## distinguished room archetypes; this is what finally makes that visible.
##
## The point is navigation, not decoration. On a 96x54 map every remembered
## room previously looked like every other remembered room.

enum { STONE, FLOODED, RUIN, SANCTUM, CAVERN }

const NAMES := {
	STONE:   &"stone",
	FLOODED: &"flooded",
	RUIN:    &"ruin",
	SANCTUM: &"sanctum",
	CAVERN:  &"cavern",
}
