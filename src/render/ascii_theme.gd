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
	&"cave_floor":  {"ch": "·", "fg": Palette.CAVE_FLOOR, "bg": Color("1c1814")},
	&"rubble":      {"ch": "▒", "fg": Palette.RUBBLE,   "bg": Color("1a150f")},
	&"water":       {"ch": "~",      "fg": Palette.WATER,    "bg": Palette.WATER_BG},
	&"stalagmite":  {"ch": "▲", "fg": Palette.ROCK_LIGHT, "bg": Color("241f19")},
	&"brazier_spent": {"ch": "Ω", "fg": Palette.BRAZIER_DEAD, "bg": Color("17161a")},

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
	# Capital marks the ranged variant of a family -- it shoots back.
	&"slinger":     {"ch": "K", "fg": Color("d8a04a")},

	# Deep tiers. Capitals throughout: in a glance-read game the letter case
	# should tell you the weight of the thing before the colour does.
	&"ogre":        {"ch": "O", "fg": Color("8a9a5b")},
	&"harpy":       {"ch": "H", "fg": Color("a87fb8")},
	&"troll":       {"ch": "T", "fg": Color("6fa15c")},
	&"wight":       {"ch": "w", "fg": Color("b8c4d8")},
	&"wyvern":      {"ch": "W", "fg": Color("c05a3a")},
	&"golem":       {"ch": "G", "fg": Color("9aa0a8")},
	&"shadow":      {"ch": "S", "fg": Color("8a63c4")},
	&"dragon":      {"ch": "D", "fg": Color("e8a63c")},
}

const FALLBACK := {"ch": "?", "fg": Color.MAGENTA, "bg": Palette.BG}

func appearance(id: StringName) -> Dictionary:
	return TABLE.get(id, FALLBACK)
