class_name Threat
extends RefCounted

## HOW MUCH DANGER A ROOM OR A CAVE IS ALLOWED TO HOLD.
##
## Split out of GameState on 2026-09-23. The prompt was an outside review that
## proposed seven modules; this was the only one worth taking, and it is a
## smaller piece than that review thought.
##
## The test is not "do these constants look related" -- it is what the code
## REACHES FOR. Measured before splitting anything: a light module would have
## needed eleven GameState fields, a brazier module nine across fourteen
## functions. Those are not modules, they are the same code with a prefix typed
## in front of every line, and two objects that can disagree about one piece of
## state is the bug this project spends most of its time preventing.
##
## This reaches for NOTHING. It is arithmetic over an effective depth and a cell
## count, which is why it can be a file of static functions and why it can be
## tested without building a dungeon to ask it a question.
##
## TIER_FADE and TIER_GRACE deliberately did NOT come with it, though the review
## listed them. They live inside monster ROLLING -- how fast a creature stops
## appearing once the dungeon has moved past its tier -- and share only the word
## "threat". Moving them would have dragged the bestiary weighting out too.

const ROOM_BASE := 10
const ROOM_PER_DEPTH := 2

## Caverns are open ground, so a lone character cannot use a doorway to turn
## being outnumbered into a series of duels. Less forgiving terrain, smaller
## ceiling.
##
## What a cave may hold as a share of a room's budget -- for a cave of TYPICAL
## size. Bigger caverns scale up from here, smaller ones down.
const CAVE_SCALE := 0.7

## The walkable cells in an average cave, measured across 388 of them. The scale
## above is expressed against this number so an average cave keeps exactly the
## budget it always had: this redistributes danger by size, it does not add any.
const CAVE_TYPICAL_CELLS := 113

## Floor and ceiling on that scaling. The upper bound is the one that matters:
## a cave is never deadlier than a room, which is the bound the old flat 0.7 was
## really there to keep.
const CAVE_MIN := 0.5
const CAVE_MAX := 1.0

## What a room at this effective depth may spend on monsters.
##
## The survivability guarantee rests on this: the room you walk into can be
## beaten by the character who walks into it.
static func room_ceiling(effective: int) -> int:
	return ROOM_BASE + ROOM_PER_DEPTH * effective

## The same, for a cave of a given size.
##
## A flat cave share of 0.7 made a cave about half as dangerous as a room, while
## the cave populator's own comment claimed caves were "wilder than rooms, worth
## a little more danger". The constant and the comment had pointed opposite ways
## since they were written.
##
## The consequence was a whole class of creature quietly locked out of the place
## it is named for. A cave ceiling of 14 at depth 5 cannot afford a cave bear at
## 17, a cave troll at 16, a wyvern at 20 or a cave giant at 26 -- so the five
## entries carrying the strongest cave weightings in the bestiary were rejected
## on price before the weighting was ever consulted. Measured across rotated
## seeds, the creatures MOST flagged for caves turned up in them least: ogre and
## orc at 1.3-1.6 weight were in caves 43-46% of the time, while cave bear and
## cave troll at 2.2-2.6 managed 13%.
##
## Scaling by size fixes that without making the dark band harder, which was
## Brad's objection to simply raising the number: an average cave lands on 0.7
## exactly as before, so the band's total danger does not move. What moves is
## WHERE it sits. A big cavern can hold something big; a cramped one cannot. A
## floor typically carries one large cave, one small and a couple of ordinary
## ones, so this sorts them rather than lifting them.
static func cave_ceiling(effective: int, cells: int) -> int:
	var scale := CAVE_SCALE * float(cells) / float(CAVE_TYPICAL_CELLS)
	return int(round(room_ceiling(effective)
		* clampf(scale, CAVE_MIN, CAVE_MAX)))
