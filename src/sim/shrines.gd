class_name Shrines
extends RefCounted

## Shrines, and the colours that hide them.
##
## Each type is drawn in a colour, and the colour->effect mapping is **shuffled
## per run**. If blue were always mending, everyone would learn it once and the
## guess would stop being a decision forever -- the same reason NetHack shuffles
## its potions.
##
## Eight types. At one or two a floor you meet roughly fifteen in a full run:
## enough to learn five or six colours with confidence, which is the band where
## the guess still has teeth. Twice that and the colour stops being information
## at all.

enum {
	QUIET,     # every monster on the floor falls asleep
	VIGIL,     # every monster wakes, and knows where you are
	EMBERS,    # spent braziers rekindle
	ANVIL,     # the forging cap rises for the rest of the run
	MENDING,   # wounds close
	SUMMONS,   # something answers
	FLARE,     # the torch roars, and cannot be smothered
	WEIGHT,    # gear blessed, but you move heavier for the floor
}

const COUNT := 8

const NAMES := {
	QUIET:   "shrine of the quiet",
	VIGIL:   "shrine of the vigil",
	EMBERS:  "shrine of embers",
	ANVIL:   "shrine of the anvil",
	MENDING: "shrine of mending",
	SUMMONS: "shrine of summons",
	FLARE:   "shrine of the flare",
	WEIGHT:  "shrine of the weight",
}

## Seven readable hues, deliberately far apart. Which one means what is decided
## fresh each run.
const HUES := [
	Color("6fa8dc"),  # blue
	Color("d96f6f"),  # red
	Color("7fc98a"),  # green
	Color("d9c46f"),  # yellow
	Color("b98ad9"),  # violet
	Color("d99a5f"),  # amber
	Color("8ad9d0"),  # teal
	Color("c9c9c9"),  # bone
]
