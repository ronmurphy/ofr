class_name AsciiTheme
extends RenderTheme

## Semantic id -> glyph and colour.
##
## Note the walls are absent here: wall glyphs are chosen by GlyphGrid from
## their neighbours, because a wall's appearance depends on the shape of the
## room around it rather than on the tile alone.

const TABLE := {
	&"floor":       {"ch": "·", "fg": Palette.FLOOR_FG, "bg": Palette.FLOOR_BG},
	&"door_closed": {"ch": "+",      "fg": Palette.DOOR,     "bg": Color("1c1712")},
	&"door_open":   {"ch": "'",      "fg": Palette.DOOR,     "bg": Color("14120f")},
	&"stairs_down": {"ch": ">",      "fg": Palette.STAIRS,   "bg": Color("1a1a20")},
	&"brazier":     {"ch": "Ω",      "fg": Palette.BRAZIER,  "bg": Color("241408")},
	&"void":        {"ch": " ",      "fg": Palette.BG,       "bg": Palette.BG},

	# Classic item glyphs: ! is a flask, ? is a rolled scroll.
	&"potion":      {"ch": "!", "fg": Palette.POTION},
	&"scroll":      {"ch": "?", "fg": Palette.SCROLL},
	&"weapon":      {"ch": ")", "fg": Palette.WEAPON},
	&"armour":      {"ch": "[", "fg": Palette.ARMOUR},

	&"player":      {"ch": "@", "fg": Palette.PLAYER},
	&"rat":         {"ch": "r", "fg": Color("8a7f6a")},
	&"kobold":      {"ch": "k", "fg": Color("9a7f4e")},
	&"goblin":      {"ch": "g", "fg": Color("6f9c4e")},
	&"bat":         {"ch": "b", "fg": Color("8e6fa8")},
	&"skeleton":    {"ch": "s", "fg": Color("d6d2c4")},
	&"orc":         {"ch": "o", "fg": Color("b5643c")},
}

const FALLBACK := {"ch": "?", "fg": Color.MAGENTA, "bg": Palette.BG}

func appearance(id: StringName) -> Dictionary:
	return TABLE.get(id, FALLBACK)
