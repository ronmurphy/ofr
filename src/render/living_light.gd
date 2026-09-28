class_name LivingLight
extends RefCounted

## Light that moves: firelight flickering, fungus slowly breathing its glow in
## and out, coals pulsing as they cool, the remembered stairs, and the blue
## under magic lying on the floor. Presentation only -- the light map in
## src/sim/ stays still and deterministic, and this only changes how lit a cell
## LOOKS from moment to moment.
##
## ONE of these is shared by both views (main.gd hands it out), so they agree
## about which light every cell is under. The shader half of the same maths is
## shaders/breathe.gdshaderinc, which both views' shaders include; the numbers
## the two halves share are checked against each other by the view tests.
##
## The light map accumulates every source into one colour per cell, so by the
## time a view sees it, whose light it was is gone. This recovers that: each
## cell gets the phase of the nearest flickering light that reaches it, and
## separately the phase of the nearest fungus -- so two braziers in a room
## never gutter together, and each patch of fungus breathes on its own clock.
## (The firelight half of this used to live in GlyphGrid.)

## How deep and how slow fungus breathes: a fifth of its light either way,
## over about eight seconds. Slower and softer than fire -- it glows, it does
## not burn. Mirrored in breathe.gdshaderinc. A seventh was tried first and
## could not be seen: fungus light is dim to begin with, and a slow change in a
## dim light is the hardest kind to notice.
const BREATH_DEPTH := 0.22
const BREATH_RATE := 0.8

## Extra brightness at the hot end of the ember ramp, on top of the colour.
## Held well under the lit brazier's own brightness -- a spent brazier that
## looks as alive as a burning one tells the player the opposite of the truth.
const EMBER_GLOW := 0.18

## The blue under magic on the floor: its strength, and how slowly it breathes.
const ITEM_GLOW := 0.30
const ITEM_GLOW_RATE := 1.4

## Per cell: the phase of the flame or fungus that reaches it, -1 for none.
var _fire := PackedFloat32Array()
var _breath := PackedFloat32Array()
var _w := 0
## Bumped by every rebuild, so upload() knows when there is something new.
var _version := 0
var _uploaded := []

## The clock the CPU path ("simple") runs on. Refreshed at ~15Hz rather than
## every frame: cheaper, and a choppier flame reads more like a real torch than
## a smooth sine does. The time and the jitter are shared; the PHASE is not,
## which is what stops every flame on the floor moving as one.
var _t := 0.0
var _jitter := 0.0
var _accum := 0.0

## One texel per map cell, for the shaders. `cells` is the layout the classic
## shader always had: r tile id, g per-cell hash, b firelight phase (0 = no
## flame), a 1 if in view. `extra`: r fungus breath phase (0 = none), g how far
## remembered ground has faded (0 = not at all; see MapMemory), b and a unused.
## Zero means "nothing" in every channel, so a shader that has not been handed
## these yet reads a still, unfaded map.
var cells: ImageTexture
var extra: ImageTexture
var _cells_img: Image
var _extra_img: Image
var _cells_bytes := PackedByteArray()
var _extra_bytes := PackedByteArray()
## hash01 as the byte the shader reads, per cell: it never changes, so it is
## worked out once per floor size rather than once per cell per upload.
var _hash_bytes := PackedByteArray()

## Assigns every cell the phase of the nearest flame, and of the nearest fungus.
## Once a refresh: the sources only move when a turn passes.
func rebuild(state: GameState) -> void:
	var m := state.map
	if _fire.size() != m.width * m.height:
		_fire.resize(m.width * m.height)
		_breath.resize(m.width * m.height)
	_w = m.width
	_fire.fill(-1.0)
	_breath.fill(-1.0)
	_version += 1
	var flames: Array = []
	var fungus: Array = []
	if state.player.light != null and state.player.light.flickers:
		flames.append(state.player.light)
	for src in state.static_lights:
		# Braziers flicker and fungus does not -- see GameState._gather_lights.
		if src.flickers:
			flames.append(src)
		else:
			fungus.append(src)
	_nearest(m, flames, _fire, 7, 13, PackedFloat32Array())
	# Only where no flame reaches. The light map has already added the two
	# together, so breathing a cell under your torch would pulse the TORCH --
	# and firelight has its own motion there already.
	_nearest(m, fungus, _breath, 11, 5, _fire)

## Gives each cell the phase of the nearest source that reaches it, skipping
## cells `unless` already claims. Walks each source's own square rather than
## every cell against every source: in the caves every fungus tile is a light,
## and forty of them over the whole floor was a two-hundred-thousand-step loop
## every turn. The nearest still wins, and on a tie the earlier source, as it
## always did.
func _nearest(m: DungeonMap, sources: Array, into: PackedFloat32Array,
		a: int, b: int, unless: PackedFloat32Array) -> void:
	if sources.is_empty():
		return
	var best := PackedInt32Array()
	best.resize(into.size())
	best.fill(1 << 30)
	for src in sources:
		var r: int = src.radius
		var sx: int = src.x
		var sy: int = src.y
		# Position, so two sources in one room never move together.
		var phase := float((sx * a + sy * b) % 64) * 0.0982
		for y in range(maxi(0, sy - r), mini(m.height, sy + r + 1)):
			for x in range(maxi(0, sx - r), mini(m.width, sx + r + 1)):
				var d := (x - sx) * (x - sx) + (y - sy) * (y - sy)
				var i := y * _w + x
				if d > r * r or d >= best[i]:
					continue
				if not unless.is_empty() and unless[i] >= 0.0:
					continue
				best[i] = d
				into[i] = phase

## Advances the CPU clock; true when it is time to redraw.
func tick(delta: float) -> bool:
	_accum += delta
	if _accum < 1.0 / 15.0:
		return false
	_accum = 0.0
	_t = Time.get_ticks_msec() / 1000.0
	_jitter = randf_range(-0.02, 0.02)
	return true

## How lit a cell looks right now, as a multiplier on its light, for a view
## animating on the CPU ("simple"). Cells no flame or fungus reaches are
## perfectly steady.
func pulse(x: int, y: int) -> float:
	var i := y * _w + x
	if _fire.is_empty() or x < 0 or x >= _w or i < 0 or i >= _fire.size():
		return 1.0
	var f := _fire[i]
	if f >= 0.0:
		return 1.0 + sin(_t * 11.0 + f) * 0.035 \
			+ sin(_t * 23.7 + f * 2.0) * 0.022 + _jitter
	var b := _breath[i]
	if b >= 0.0:
		return 1.0 + BREATH_DEPTH * sin(_t * BREATH_RATE + b)
	return 1.0

## The raw phases, -1 for none. For the tests, and for anything else that
## wants to know which light a cell is under without animating it.
func fire_phase(x: int, y: int) -> float:
	var i := y * _w + x
	return _fire[i] if x >= 0 and x < _w and i >= 0 and i < _fire.size() else -1.0

func breath_phase(x: int, y: int) -> float:
	var i := y * _w + x
	return _breath[i] if x >= 0 and x < _w and i >= 0 and i < _breath.size() else -1.0

## Hands the shaders what each cell is, one texel per cell -- see `cells` and
## `extra`. Only does the work when something has changed since last time: a
## rebuild, a turn, a new floor. Between those, every frame reuses the same
## two textures, where the grid used to rewrite its one on every redraw.
## `memory` may be null, and then nothing has faded.
func upload(state: GameState, memory: MapMemory) -> void:
	var map := state.map
	if memory != null:
		memory.update(state)
	var key := [map, _version, state.turns]
	if key == _uploaded and cells != null:
		return
	_uploaded = key
	var w := map.width
	var h := map.height
	var n := w * h
	if _cells_img == null or _cells_img.get_width() != w or _cells_img.get_height() != h:
		_cells_img = Image.create(w, h, false, Image.FORMAT_RGBA8)
		_extra_img = Image.create(w, h, false, Image.FORMAT_RGBA8)
		cells = ImageTexture.create_from_image(_cells_img)
		extra = ImageTexture.create_from_image(_extra_img)
		_cells_bytes.resize(n * 4)
		_extra_bytes.resize(n * 4)
		_extra_bytes.fill(0)
		_hash_bytes.resize(n)
		for y in h:
			for x in w:
				# What set_pixel wrote for hash01 when this was a Color:
				# Image truncates, it does not round.
				_hash_bytes[y * w + x] = int(hash01(x, y) * 255.0)
	var fades := memory.fades(state.turns) if memory != null else PackedFloat32Array()
	var phased := _w == w and _fire.size() == n
	var tiles := map.tiles
	var shown := map.visible_now
	# Bytes straight into the image rather than a Color per texel: this runs
	# once a turn in either view, and set_pixel five thousand times was most
	# of what a turn cost to draw.
	for i in n:
		var o := i * 4
		_cells_bytes[o] = tiles[i]
		_cells_bytes[o + 1] = _hash_bytes[i]
		# Blue carries the FIRELIGHT PHASE, and carrying it is what makes the
		# shader equal to the timers it replaced. The CPU flicker was never
		# about brazier tiles: every cell has the phase of the nearest
		# flickering light that reaches it, your torch included, so the whole
		# lit area breathes. A shader that only knew tile ids could animate the
		# brazier and nothing else -- which on screen read as the torch flicker
		# simply disappearing on "full".
		_cells_bytes[o + 2] = phase_code(_fire[i]) if phased else 0
		# Alpha is VISIBILITY, not opacity. Remembered ground must not
		# animate: a pool of water you are only remembering should be as
		# still as the memory of it.
		_cells_bytes[o + 3] = 255 if shown[i] != 0 else 0
		_extra_bytes[o] = phase_code(_breath[i]) if phased else 0
		_extra_bytes[o + 1] = int((1.0 - fades[i]) * 255.0) if not fades.is_empty() else 0
	_cells_img.set_data(w, h, false, Image.FORMAT_RGBA8, _cells_bytes)
	_extra_img.set_data(w, h, false, Image.FORMAT_RGBA8, _extra_bytes)
	cells.update(_cells_img)
	extra.update(_extra_img)

## A phase as the byte the shaders read. Zero means none, and everything else
## is the phase scaled into the remaining 254 values, so a genuine phase of 0
## is never mistaken for "nothing reaches here".
static func phase_code(phase: float) -> int:
	if phase < 0.0:
		return 0
	return int(floor(phase / TAU * 253.0)) + 1

## Cheap deterministic noise in [0,1) from a cell coordinate -- GlyphGrid's, so
## the shaders see the hash they always saw.
static func hash01(x: int, y: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663)
	return float(absi(h) % 1024) / 1024.0

## A cooling brazier's colour, from its `fg` and how much heat is left.
##
## This is the twenty-turn forging window, drawn instead of counted. Brad's
## rule for it was no number on screen -- the player works out what the fade
## means by watching one go out -- so the gauge has to BE the thing rather than
## label it.
##
## Hue alone was not enough. Walking EMBERS -> BRAZIER_DEAD moves luminance
## only 0.386 -> 0.283, so the middle third of the window was a mush of
## near-identical browns and the gauge could not be read. The glow adds the
## brightness the hue shift does not carry, and it is tied to the same heat, so
## the tile dims as well as greys.
##
## Coals breathe, and stop breathing as they cool -- the pulse is scaled by the
## same heat, so the tile visibly goes still before it goes grey. Phase from the
## cell, so two braziers in a room never pulse together. Held at rest when the
## player has asked for no motion; the COLOUR ramp stays either way -- that is
## information about how long the embers have left, and turning effects off
## must not cost you information. (Moved from GlyphGrid._draw_cell; the 3D view
## now draws the same gauge.)
static func embers(fg: Color, heat: float, x: int, y: int) -> Color:
	var beat := 1.0
	if Effects.any():
		beat += 0.10 * heat * sin(Time.get_ticks_msec() / 340.0 + hash01(x, y) * TAU)
	var c := (fg.lerp(Palette.EMBERS, heat) * (1.0 + EMBER_GLOW * heat) * beat).clamp()
	c.a = 1.0
	return c

## Remembered stairs breathe gently so the eye finds them on a large map. Still,
## but not dim, with motion off: frozen at the top of the breath rather than the
## middle, so the stairs stay as findable as they are meant to be.
static func stairs_pulse() -> float:
	if not Effects.any():
		return 1.0
	return 0.78 + 0.22 * sin(Time.get_ticks_msec() / 620.0)

## The glow under an item on the floor, alpha 0 for none: magic blue under
## enchanted gear and under gems, breathing slowly.
##
## Under the item, never on it. A gem's glyph keeps its own near-white on
## purpose -- GlyphGrid's note on shows_enchanted() has the history -- and an
## enchanted weapon is already drawn blue. The glow says "magic lies here"
## without taking a colour away from anything. Steady with motion off: it is
## information, so it stays; only the breathing goes.
static func item_glow(item: Item) -> Color:
	if not item.shows_enchanted() and item.kind != Item.Kind.GEM:
		return Color(0, 0, 0, 0)
	var a := ITEM_GLOW
	if Effects.any():
		a *= 0.75 + 0.25 * sin(Time.get_ticks_msec() / 1000.0 * ITEM_GLOW_RATE
			+ hash01(item.x, item.y) * TAU)
	return Color(Palette.MAGIC, a)
