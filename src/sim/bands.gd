class_name Bands
extends RefCounted

## What kind of place a floor is.
##
## Themes, in Brad's design: the dungeon changes character in groups of three
## rather than drifting evenly, and the climb out reuses the same groups in
## reverse -- the same places, corrupted, rather than the descent replayed
## backwards.
##
## Keyed on EFFECTIVE depth, which is what makes the reversal free: descending
## floor 5 and climbing floor 5 are effective 5 and 15, and both land in caves
## without either side having to know which direction you are going.
##
##     1-3    upper      ordinary dungeon, a little cave
##     4-6    caves      mostly cavern, and dark
##     7-9    fortress   built, complex, vault-heavy
##     10     deep       the amulet's own floor
##     11-13  fortress   the same, corrupted
##     14-16  caves      the same, darker
##     17-19  upper      the same, and nearly out
enum { UPPER, CAVES, FORTRESS, DEEP }

const NAMES := {
	UPPER: &"upper", CAVES: &"caves", FORTRESS: &"fortress", DEEP: &"deep",
}

## The band an effective depth falls in.
static func of(effective: int) -> int:
	# Folded around the bottom, so the climb mirrors the descent without a
	# second table to keep in step with the first.
	var d := effective
	if d > GameState.MAX_DEPTH:
		d = GameState.MAX_DEPTH * 2 - d
	if d <= 3:
		return UPPER
	if d <= 6:
		return CAVES
	if d <= 9:
		return FORTRESS
	return DEEP

static func is_caves(effective: int) -> bool:
	return of(effective) == CAVES

## True only on the way back up, where a band is the corrupted version of
## itself. Effective depth above the bottom means climbing, by definition.
static func is_corrupted(effective: int) -> bool:
	return effective > GameState.MAX_DEPTH
