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
	&"stairs_up":   {"ch": "<",      "fg": Palette.STAIRS,   "bg": Color("1a1a20")},
	# Colour is supplied per-shrine by the grid, not from here.
	&"shrine":      {"ch": "∩", "fg": Palette.UI_TEXT,  "bg": Color("1c1826")},
	&"brazier":     {"ch": "Ω",      "fg": Palette.BRAZIER,  "bg": Color("241408")},
	&"void":        {"ch": " ",      "fg": Palette.BG,       "bg": Palette.BG},
	&"cave_floor":  {"ch": "·", "fg": Palette.CAVE_FLOOR, "bg": Color("1c1814")},
	&"rubble":      {"ch": "▒", "fg": Palette.RUBBLE,   "bg": Color("1a150f")},
	&"water":       {"ch": "~",      "fg": Palette.WATER,    "bg": Palette.WATER_BG},
	&"mud":         {"ch": "░", "fg": Palette.MUD,      "bg": Palette.MUD_BG},
	&"bones":       {"ch": ",",      "fg": Palette.BONES,    "bg": Color("1d1c19")},
	&"fungus":      {"ch": "*",      "fg": Palette.FUNGUS,   "bg": Color("14201b")},
	&"pit":         {"ch": " ",      "fg": Palette.PIT_RIM,  "bg": Color("000000")},
	&"trap":        {"ch": "^",      "fg": Palette.TRAP,     "bg": Color("2a1714")},
	&"stalagmite":  {"ch": "▲", "fg": Palette.ROCK_LIGHT, "bg": Color("241f19")},
	&"brazier_spent": {"ch": "Ω", "fg": Palette.BRAZIER_DEAD, "bg": Color("17161a")},
	&"brazier_dead":  {"ch": "Ω", "fg": Palette.BRAZIER_BLACK, "bg": Color("121013")},
	# A headstone shape, and reachable now that the map font falls back to the
	# full text face -- see GlyphGrid.map_font().
	&"grave":         {"ch": "Π", "fg": Palette.GRAVE, "bg": Color("15161b")},

	# Classic item glyphs: ! is a flask, ? is a rolled scroll.
	&"potion":      {"ch": "!", "fg": Palette.POTION},
	&"scroll":      {"ch": "?", "fg": Palette.SCROLL},
	&"amulet":      {"ch": "\"", "fg": Palette.AMULET},
	&"weapon":      {"ch": ")", "fg": Palette.WEAPON},
	&"launcher":    {"ch": "}", "fg": Palette.LAUNCHER},
	&"ammo":        {"ch": "\\", "fg": Palette.LAUNCHER},
	&"armour":      {"ch": "[", "fg": Palette.ARMOUR},
	## Shields get their own glyph rather than sharing the armour "[", so a
	## shield on the floor can be told from a breastplate without inspecting it.
	&"shield":      {"ch": "(", "fg": Palette.ARMOUR},

	&"player":      {"ch": "@", "fg": Palette.PLAYER},
	&"rat":         {"ch": "r", "fg": Color("8a7f6a")},
	&"kobold":      {"ch": "k", "fg": Color("e8d9a0")},
	&"goblin":      {"ch": "g", "fg": Color("2f6b4f")},
	&"bat":         {"ch": "b", "fg": Color("8e6fa8")},
	&"skeleton":    {"ch": "s", "fg": Color("d6d2c4")},
	&"orc":         {"ch": "o", "fg": Color("b5643c")},
	# Capital marks the ranged variant of a family -- it shoots back.
	&"slinger":     {"ch": "K", "fg": Color("d8a04a")},

	# Deep tiers. Capitals throughout: in a glance-read game the letter case
	# should tell you the weight of the thing before the colour does.
	&"ogre":        {"ch": "O", "fg": Color("9a7fb8")},
	&"harpy":       {"ch": "H", "fg": Color("d08fc0")},
	&"troll":       {"ch": "T", "fg": Color("6b4a2a")},
	&"wight":       {"ch": "w", "fg": Color("b8c4d8")},
	&"wyvern":      {"ch": "W", "fg": Color("c05a3a")},
	&"golem":       {"ch": "G", "fg": Color("9aa0a8")},
	&"shadow":      {"ch": "S", "fg": Color("8a63c4")},
	&"dragon":      {"ch": "D", "fg": Color("e8c33c")},
	# Lowercase weak, uppercase deadly -- the same rule that makes K a kobold
	# that shoots back. The lich is the wizard's end state, so they share a
	# letter and differ in case.
	# h for haunt. The s/S pair that would have said "spirit, and worse spirit"
	# was spent long ago on skeleton and shadow.
	# u and U: the case pair says "and then it got worse" without a word, and
	# the rabbit is the one monster in the game that literally transforms, so it
	# earns the convention outright.
	&"rabbit":        {"ch": "u", "fg": Color("e0a05c")},
	&"killer_rabbit": {"ch": "U", "fg": Color("fff2f2")},
	&"meat":          {"ch": "%", "fg": Color("c46b5a")},
	&"banshee":     {"ch": "h", "fg": Color("f2f4ff")},
	&"wizard":      {"ch": "l", "fg": Color("3d6ee8")},
	&"lich":        {"ch": "L", "fg": Color("7cf0d8")},
}

const FALLBACK := {"ch": "?", "fg": Color.MAGENTA, "bg": Palette.BG}

func appearance(id: StringName) -> Dictionary:
	return TABLE.get(id, FALLBACK)
