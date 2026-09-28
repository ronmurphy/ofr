class_name RegionLook
extends RefCounted

## Colour by region: each band of the dungeon casts its own faint colour over
## the walls you can see and over the dark around the map.
##
##     1-3    the entrance   green, as if you came in from a forest -- strongest
##                           on the first floor and fading by the third
##     4-6    the caves      grey rock, and an earth-brown dark (the cave floor
##                           is already earth)
##     7-10   the fortress   stone greys (the deep floor is built too)
##     11-19  the climb      the same places, drained and tinged purple
##
## Shared by both views, so a floor is the same colour whichever is showing.
##
## THE FLOOR KEEPS ITS COLOURS. Everything that matters lies on it -- water,
## mud, fungus, bones, traps, stairs, shrines -- and every hue tried on plain
## ground moved it towards one of them for somebody: a green entrance put cave
## floor within deltaE 0.4 of mud for protanopes, an earth-brown cave within
## 1.4 of it for deuteranopes, and the climb's purple pulled floor under 25 from
## water. Stone has one thing to stay apart from, the door set into it, so the
## region lives in the masonry and the dark, and tools/check_palette.py's
## measure of wall against door stays over 25 under all four vision models
## (the view tests hold the normal-vision half of that).
##
## Also untouched: remembered ground -- memory's blue, and the material colours
## that tell one remembered room from another, the hoard's violet among them --
## and brightness. Every shift holds a colour's luminance, so how lit a wall
## looks does not change.

## The hues, as multipliers; each result is scaled back to the colour's own
## luminance, so only the hue moves. Corruption drains colour as well as
## tinting it -- a little grey first -- which reads as sickly rather than as a
## coloured lamp; stronger, under the torch's orange, it came out pink.
const FOREST := Color(0.85, 1.10, 0.85)
const COOL_STONE := Color(0.97, 1.00, 1.05)
const CORRUPTION := Color(1.07, 0.91, 1.10)
const CORRUPTION_GREY := 0.20
## How much of FOREST the entrance's walls take, at most. Walls green enough to
## see from across a room came within 25 of a door for protanopes; this is the
## most that measured clear. The dark around the map carries the rest.
const FOREST_STONE := 0.35
const FOREST_STONE_GREY := 0.20

## The dark around the map, per region: the backdrop's own colour, so the
## whole screen carries the place and not just what the torch reaches.
const DARK_FOREST := Color("0a0f0d")
const DARK_EARTH := Color("0f0d0b")
const DARK_STONE := Color("0c0c0e")
const DARK_CORRUPT := Color("0f0b14")

## What this floor does to stone in view: its hue, how far it is first pulled
## towards grey, the colour of the dark around the map, and a name for it.
var stone := Color.WHITE
var stone_grey := 0.0
var backdrop := Palette.BG
var label := &"none"

static var _cache := {}

## The look for an effective depth (GameState.effective_depth), made once.
static func for_depth(effective: int) -> RegionLook:
	if not _cache.has(effective):
		_cache[effective] = _make(effective)
	return _cache[effective]

static func _make(effective: int) -> RegionLook:
	var look := RegionLook.new()
	var band := Bands.of(effective)
	var corrupted := Bands.is_corrupted(effective)
	# The climb keeps the band it mirrors, at half strength, under the purple:
	# the same places, changed.
	var own := 0.5 if corrupted else 1.0
	match band:
		Bands.UPPER:
			# Floor 1 is the doorway to the outside; by floor 3 the forest is
			# behind you. Mirrored on the climb, so it comes back as you near
			# the way out.
			var near := (4.0 - float(Bands.mirrored(effective))) / 3.0
			look.stone = Color.WHITE.lerp(FOREST, near * FOREST_STONE * own)
			look.stone_grey = near * FOREST_STONE_GREY * own
			look.backdrop = Palette.BG.lerp(DARK_FOREST, near)
			look.label = &"entrance"
		Bands.CAVES:
			look.stone_grey = 0.50 * own
			look.backdrop = DARK_EARTH
			look.label = &"caves"
		_:
			look.stone_grey = 0.40 * own
			look.stone = Color.WHITE.lerp(COOL_STONE, own)
			look.backdrop = DARK_STONE
			look.label = &"fortress"
	if corrupted:
		look.stone = look.stone * CORRUPTION
		look.stone_grey = maxf(look.stone_grey, CORRUPTION_GREY)
		look.backdrop = DARK_CORRUPT
		look.label = StringName("corrupted " + String(look.label))
	return look

## True for the tiles the region colours: walls, rock, pillars, stalagmites.
static func is_stone(tile: int) -> bool:
	return tile == Tiles.WALL or tile == Tiles.ROCK or tile == Tiles.PILLAR \
		or tile == Tiles.STALAGMITE

## Stone colour `c` as this region shows it. Luminance is kept.
func shift(c: Color) -> Color:
	var out := c
	if stone_grey > 0.0:
		# Towards a grey of the same luminance, which keeps luminance already.
		var l := c.get_luminance()
		out = c.lerp(Color(l, l, l, c.a), stone_grey)
	return keep_luma(out, stone)

## `c` times `tint`, scaled back to c's own luminance: the hue moves, the
## brightness does not. (GlyphGrid's memory tint is this, too.)
static func keep_luma(c: Color, tint: Color) -> Color:
	var before := c.get_luminance()
	if before <= 0.001:
		return c
	var out := c * tint
	var after := out.get_luminance()
	if after <= 0.001:
		return c
	return (out * (before / after)).clamp()
