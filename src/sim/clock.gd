class_name Clock
extends RefCounted

## Game time, in the oldest unit the genre has.
##
## One round is six seconds, straight out of D&D, which is where the whole
## fiction of a "turn" in this game comes from anyway. It buys two things: an
## end screen that can say "escaped in 17h 52m" instead of "turn 10720", and a
## line in the pause menu that is interesting rather than pressing.
##
## What it deliberately is NOT is a deadline. Nothing in OFR is measured
## against elapsed time -- no hunger, no torch burning down -- so this is
## flavour, and it is shown where flavour belongs: in the menu, and at the end.
## A clock ticking in the corner of the screen would imply a resource that does
## not exist.
const SECONDS_PER_ROUND := 6

## Energy spent -> seconds underground.
##
## Energy, NOT the turn counter, and the difference is the whole point of the
## thing existing. `GameState.turns` counts player ACTIONS: one keypress, one
## turn, whether you stepped onto clean stone or waded through mud that cost
## the world two moves against you. Multiplying that by six would produce a
## clock wrong in exactly the way a clock is supposed to be right.
static func seconds(energy: int) -> int:
	return energy * SECONDS_PER_ROUND / Scheduler.ACTION_COST

## Rounded to the unit above the one that matters, because nobody reads a
## dungeon crawl to the second. The seconds only survive on a run short enough
## to have nothing else to show.
static func text(secs: int) -> String:
	var s := maxi(0, secs)
	var days := s / 86400
	var hours := (s % 86400) / 3600
	var minutes := (s % 3600) / 60
	if days > 0:
		return "%dd %dh %02dm" % [days, hours, minutes]
	if hours > 0:
		return "%dh %02dm" % [hours, minutes]
	if minutes > 0:
		return "%dm %02ds" % [minutes, s % 60]
	return "%ds" % (s % 60)
