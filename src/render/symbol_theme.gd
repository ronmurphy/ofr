class_name SymbolTheme
extends RenderTheme

## Terrain and items drawn as symbols instead of letters.
##
## Every character here is one JetBrains Mono actually carries, verified with
## `Font.has_char` by a test. That check exists because of how this file got
## written the first time: with a shrine gate, a skull, an alembic and crossed
## swords, all of which LOOKED fine in a terminal and none of which are in the
## font. A terminal silently substitutes a system font. A web build has no
## system font to substitute, so every one of them would have shipped as an
## empty box to anyone playing in a browser.
##
## What the font really has, outside ASCII, is 43 geometric shapes, 32 block
## elements, 128 box-drawing pieces, 119 maths operators and 115 technical
## symbols -- and, in the pictorial blocks, exactly 5 miscellaneous symbols and
## 12 dingbats. So this mode is abstract-but-evocative, not pictorial. Real
## pictures need an icon font, which is a desktop download.
##
## Creatures are deliberately absent and fall through to their letters. The
## font has no animals at all -- the block holding a bat, a rat and a dragon is
## simply not in it. Falling through also means a new monster needs one table
## entry rather than two, and the bestiary will keep growing.

## Layered over AsciiTheme.TABLE -- anything not named here keeps its letter.
const OVERRIDES := {
	# Filled is shut, hollow is open. The pair reads as one idea at a glance,
	# which "+" and "'" never did.
	&"door_closed": {"ch": "■"},
	&"door_open":   {"ch": "□"},

	# Direction, rather than two characters that only differ by which way a
	# wedge points if you look closely.
	&"stairs_down": {"ch": "≫"},
	&"stairs_up":   {"ch": "≪"},

	&"shrine":        {"ch": "⌂"},
	&"brazier":       {"ch": "✶"},
	&"brazier_spent": {"ch": "✶"},

	# "~" was always a compromise for water. "≈" is the thing itself.
	&"water":  {"ch": "≈"},
	&"fungus": {"ch": "◌"},

	# The one unambiguous pictograph the font does have, and it lands on the
	# one tile that is purely a hazard.
	&"trap": {"ch": "⚠"},

	# Scattered fragments rather than a single comma.
	&"bones": {"ch": "∴"},

	&"potion":   {"ch": "◔"},
	&"scroll":   {"ch": "≡"},
	&"amulet":   {"ch": "◎"},
	&"weapon":   {"ch": "†"},
	&"launcher": {"ch": "➜"},
	&"armour":   {"ch": "◫"},
}

func appearance(id: StringName) -> Dictionary:
	var base: Dictionary = AsciiTheme.TABLE.get(id, AsciiTheme.FALLBACK)
	if not OVERRIDES.has(id):
		return base
	# Colour and background stay with the ASCII table: this mode changes the
	# shape of the dungeon, not its palette.
	var out := base.duplicate()
	out["ch"] = OVERRIDES[id]["ch"]
	return out
