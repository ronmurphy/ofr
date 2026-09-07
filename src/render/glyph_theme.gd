class_name GlyphTheme
extends RenderTheme

## Pictures, from an 18KB subset of JetBrains Mono Nerd Font.
##
## The whole font is 2.5MB and carries some twelve thousand glyphs; this game
## draws thirty of them. `pyftsubset` throws the rest away and what is left is
## a fifteenth the size of the text font already in the repo -- so the reason
## this mode was nearly abandoned, weight on a web build, turned out not to
## exist. tools/ has the fetch-and-subset recipe.
##
## SHAPE CARRIES RANK, COLOUR CARRIES FAMILY.
##
## Not decoration: it is the architecture the letters already had -- case for
## rank, letter for family -- moved into pictures. Six humanoids share three
## figures:
##
##     small figure   kobold, goblin     the nuisances
##     adult figure   orc, wight         man-sized
##     heavy figure   ogre, troll        the ones that hurt
##
## One figure in seven colours was measured and rejected. Goblin and cave troll
## sit deltaE 5.4 apart in the shipped palette, and under deuteranopia ogre and
## troll are 1.7 -- the same colour. A depth-2 nuisance and a depth-6
## regenerating bruiser would be one creature on screen. With a size ladder,
## colour only separates two creatures inside a class instead of seven across
## the board, and tools/check_palette.py asserts it holds under all three
## dichromacies.

## Codepoints rather than literals: U+F02E7 in the source says nothing, and an
## astral private-use character is the sort of thing an editor or a shell
## quietly mangles. Names come from the Nerd Font glyph set.
const SMALL_FIGURE := 0xF02E7   # md-human_child
const ADULT_FIGURE := 0xF02E6   # md-human
const HEAVY_FIGURE := 0xF115D   # md-weight_lifter
## An active stance, not a bow. A bow icon standing on a monster reads as loot
## lying on the floor.
const ARMED_SMALL  := 0xF082C   # md-karate

## Semantic id -> codepoint. Alternates are already in the font subset, so
## changing one's mind costs a line here rather than rebuilding the font.
const OVERRIDES := {
	# --- the humanoid ladder ------------------------------------------------
	&"kobold":   SMALL_FIGURE,
	&"goblin":   SMALL_FIGURE,
	&"slinger":  ARMED_SMALL,
	&"orc":      ADULT_FIGURE,
	&"wight":    ADULT_FIGURE,
	&"ogre":     HEAVY_FIGURE,
	&"troll":    HEAVY_FIGURE,

	# --- everything else keeps its own silhouette ---------------------------
	&"rat":      0xF1327,   # md-rodent
	&"bat":      0xF0B5F,   # md-bat
	&"harpy":    0xF15C6,   # md-bird
	&"skeleton": 0xF068C,   # md-skull
	&"shadow":   0xF02A0,   # md-ghost -- the incognito hat read as a detective
	&"golem":    0xF06A9,   # md-robot
	# Wyvern and dragon share a silhouette and are told apart by colour alone,
	# which is why check_palette.py checks that pair too.
	&"wyvern":   0xEEF8,    # fa-dragon
	&"dragon":   0xEEF8,

	# You are an OUTLINE of a person while every humanoid down here is a solid
	# one. That is the distinction doing the work -- not shape and not colour,
	# but filled against hollow, which survives both a crowded room and colour
	# blindness. "@" is one line away if it turns out to be harder to find.
	&"player":   0xEA67,    # cod-person

	# --- carryables ---------------------------------------------------------
	&"potion":   0xF0093,   # md-flask
	&"scroll":   0xF0BC2,   # md-script_text
	&"weapon":   0xF04E5,   # md-sword
	&"launcher": 0xF1841,   # md-bow_arrow
	&"ammo":     0xF1840,   # md-arrow_projectile -- spent arrows on the floor
	&"armour":   0xF0A7B,   # md-tshirt_crew
	&"shield":   0xF0498,   # md-shield
	&"amulet":   0xF0F0B,   # md-necklace

	# --- ground and features ------------------------------------------------
	&"brazier":       0xF0238,   # md-fire
	&"brazier_spent": 0xF0238,
	&"brazier_dead":  0xF0238,
	# A torii gate, not a cross. The cross read as Christian iconography in a
	# dungeon, and at cell size it was too close to the sword -- a shrine you
	# might walk onto looking like a weapon you might pick up.
	&"shrine":        0xEEE6,    # fa-torii_gate
	&"stairs_down":   0xF12BE,
	&"stairs_up":     0xF12BD,
	&"door_closed":   0xF081B,
	&"door_open":     0xF081C,
	# A wave, not a droplet. A droplet is a picture of water; a wave is a
	# picture of water DOING something, and it gives a shader an edge to move.
	&"water":         0xEF30,    # fa-water
	&"fungus":        0xF07DF,   # md-mushroom
	&"trap":          0xF0026,   # md-alert
	&"bones":         0xF00B9,   # md-bone
}

## How much bigger an icon is drawn than a letter.
##
## A letter is designed to sit on a baseline with side bearing either side, and
## it looks right doing that. An icon at the same size looks lost: it has the
## same 10px advance in an 18px cell, but none of that surrounding whitespace
## is meant to be there. This is the difference between a picture IN a cell and
## a picture floating in one.
const ICON_SCALE := 1.55

## Icons live in the private use area, and that is how everything that draws
## one knows to draw it larger.
static func is_icon(ch: String) -> bool:
	return ch.length() > 0 and ch.unicode_at(0) >= 0xE000

## The point size to draw `ch` at, given the size the surrounding text uses.
##
## Shared by the map, the legend and the inventory rather than repeated in
## each: the legend is where the icons are LEARNED, so icons that are tiny
## there defeat the mode more thoroughly than icons that are tiny on the map.
static func draw_size(ch: String, base: int) -> int:
	return int(round(float(base) * ICON_SCALE)) if is_icon(ch) else base

func appearance(id: StringName) -> Dictionary:
	var base: Dictionary = AsciiTheme.TABLE.get(id, AsciiTheme.FALLBACK)
	if not OVERRIDES.has(id):
		return base
	# Colour and background stay with the ASCII table. This mode changes the
	# shape of the dungeon, not its palette.
	var out := base.duplicate()
	out["ch"] = String.chr(OVERRIDES[id])
	return out
