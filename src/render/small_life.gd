class_name SmallLife
extends RefCounted

## The dungeon's small life, for both views: spores drifting up off fungus,
## drips falling in the caves, bubbles swelling in mud, dust hanging in your
## torchlight, and the trader idling on their spot (idle_offset). ONE of these
## is shared by both views (main.gd hands it out), so they show the same spore
## at the same moment.
##
## Only on "full". It never stops moving, and constant motion is exactly what
## someone who chose "simple" or "still" asked not to have. (The splash of a
## footstep is Fx.footfalls, which is an event, and runs on "simple" too.)
##
## Nothing here is random when it is drawn. Every mote is a function of the
## clock and of the cell it belongs to, so both views agree, and the same
## moment can be photographed twice. The sources -- which fungus, which mud,
## which cells drip, where the dust hangs -- are gathered once a turn, from
## what is in sight near you. A mote is only ever drawn over a cell you can see.

## How far from you small life is gathered, and how many cells of each kind at
## most, nearest first -- so a vast fungus cavern costs what a small one does.
const REACH := 16
const MAX_FUNGUS := 36
const MAX_MUD := 24
const MAX_DRIPS := 12
const MAX_DUST := 18
## Of the cave floor and water in sight, about this share drips.
const DRIP_SHARE := 0.06
## Of the lit ground near you, about this share holds a mote of dust.
const DUST_SHARE := 0.22

## Each kind's colour. A spore takes the colour of its fungus (green stays
## pale green); a bubble is mud a shade lighter than the mud; a drop is cold
## water; dust is torchlight caught on nothing much.
const SPORE := Color(0.80, 1.00, 0.90)
const BUBBLE := Color(0.58, 0.48, 0.36)
const DROP := Color(0.72, 0.84, 0.98)
const DUST := Color(1.00, 0.93, 0.78)

## The trader shifting their weight, in cells: side to side every four seconds
## or so, and half as much front to back.
const TRADER_SWAY := 0.08
## How far the trader leans towards you when you are close, in cells, and how
## close is close: all the way at a step away, nothing from this far on.
const TRADER_LEAN := 0.18
const TRADER_NOTICE := 6.0

var _fungus: Array[Vector2i] = []
var _mud: Array[Vector2i] = []
var _drips: Array[Vector2i] = []
var _dust: Array[Vector2i] = []
var _state: GameState = null

## Gathers the cells that have small life, from what is in sight near you.
## Once a turn, alongside LivingLight.rebuild.
func rebuild(state: GameState) -> void:
	_state = state
	_fungus.clear()
	_mud.clear()
	_drips.clear()
	_dust.clear()
	var map := state.map
	var p := Vector2i(state.player.x, state.player.y)
	var caves := Bands.is_caves(state.effective_depth())
	var lit := 0
	if state.player.light != null:
		lit = state.player.light.radius
	var found := {"fungus": [], "mud": [], "drips": [], "dust": []}
	for y in range(maxi(0, p.y - REACH), mini(map.height, p.y + REACH + 1)):
		for x in range(maxi(0, p.x - REACH), mini(map.width, p.x + REACH + 1)):
			if not map.is_visible(x, y):
				continue
			var d := (x - p.x) * (x - p.x) + (y - p.y) * (y - p.y)
			var tile := map.get_tile(x, y)
			# All three colours share one nearest-first budget. A mixed cave must
			# not cost more to animate than a green-only one.
			if tile == Tiles.FUNGUS or tile == Tiles.FUNGUS_PURPLE \
					or tile == Tiles.FUNGUS_RED:
				found["fungus"].append([d, Vector2i(x, y)])
			elif tile == Tiles.MUD:
				found["mud"].append([d, Vector2i(x, y)])
			if caves and (tile == Tiles.CAVE_FLOOR or tile == Tiles.WATER) \
					and LivingLight.hash01(x * 13 + 7, y * 17 + 3) < DRIP_SHARE:
				found["drips"].append([d, Vector2i(x, y)])
			if d <= lit * lit and Tiles.is_open_floor(tile) \
					and LivingLight.hash01(x * 5 + 1, y * 7 + 2) < DUST_SHARE:
				found["dust"].append([d, Vector2i(x, y)])
	_nearest(found["fungus"], _fungus, MAX_FUNGUS)
	_nearest(found["mud"], _mud, MAX_MUD)
	_nearest(found["drips"], _drips, MAX_DRIPS)
	_nearest(found["dust"], _dust, MAX_DUST)

static func _nearest(pairs: Array, into: Array[Vector2i], most: int) -> void:
	pairs.sort_custom(func(a, b): return a[0] < b[0])
	for i in mini(most, pairs.size()):
		into.append(pairs[i][1])

## Every mote in the air at time `t` (seconds): [where on the floor in cells,
## fractional; how high above it in cells; colour with its alpha; size in
## cells]. Empty unless the setting is "full".
func motes(t: float) -> Array:
	var out: Array = []
	if _state == null or not Effects.shaders():
		return out
	var map := _state.map
	# Spores: two to a patch, rising and swaying as they go, fading in and out.
	for c in _fungus:
		var spore_colour := _spore_colour(map.get_tile(c.x, c.y))
		for k in 2:
			var h := LivingLight.hash01(c.x * 3 + k * 17, c.y * 5 + k * 29)
			var cyc := fposmod(t / (3.5 + h * 2.5) + h, 1.0)
			var home := Vector2(c) + Vector2(0.3 + h * 0.4, 0.3 + fposmod(h * 7.0, 1.0) * 0.4)
			var sway := Vector2(sin(t * 0.9 + h * 20.0) * 0.16, cos(t * 0.7 + h * 13.0) * 0.10)
			_add(out, map, home + sway * cyc, 0.10 + cyc * 0.90,
				Color(spore_colour, sin(cyc * PI) * 0.85), 0.09, false)
	# Mud: a bubble swells, then pops into two flecks.
	for c in _mud:
		var h := LivingLight.hash01(c.x * 7 + 3, c.y * 11 + 5)
		var cyc := fposmod(t / (2.4 + h * 2.2) + h, 1.0)
		var at := Vector2(c) + Vector2(0.25 + h * 0.5, 0.25 + fposmod(h * 5.0, 1.0) * 0.5)
		if cyc < 0.30:
			_add(out, map, at, 0.02, Color(BUBBLE, 0.85), 0.05 + 0.08 * cyc / 0.30, true)
		elif cyc < 0.40:
			var s := (cyc - 0.30) / 0.10
			for side in [-1.0, 1.0]:
				_add(out, map, at + Vector2(side * 0.09 * s, 0.0), 0.03 + 0.12 * s,
					Color(BUBBLE, 1.0 - s), 0.045, true)
	# Drips: now and then a drop falls from the dark above and breaks on the
	# floor. Falling, it speeds up; landing, it throws three flecks.
	for c in _drips:
		var h := LivingLight.hash01(c.x * 13 + 7, c.y * 17 + 3)
		var cyc := fposmod(t / (4.0 + h * 4.0) + h, 1.0)
		var at := Vector2(c) + Vector2(0.3 + h * 0.4, 0.3 + fposmod(h * 3.0, 1.0) * 0.4)
		if cyc >= 0.84 and cyc < 0.93:
			var s := (cyc - 0.84) / 0.09
			_add(out, map, at, 1.35 * (1.0 - s * s), Color(DROP, 0.9), 0.06, true)
		elif cyc >= 0.93:
			var s := (cyc - 0.93) / 0.07
			for i in 3:
				var a := float(i) * TAU / 3.0 + h * TAU
				_add(out, map, at + Vector2(cos(a), sin(a)) * 0.14 * s,
					0.03 + 0.4 * s * (1.0 - s), Color(DROP, 0.8 * (1.0 - s)), 0.045, true)
	# Dust: specks hanging in the air near you, drifting slowly, visible only
	# as far as the light catches them.
	for c in _dust:
		var h := LivingLight.hash01(c.x * 5 + 1, c.y * 7 + 2)
		var at := Vector2(c) + Vector2(0.5, 0.5) \
			+ Vector2(sin(t * 0.21 + h * 40.0), cos(t * 0.17 + h * 25.0)) * 0.45
		_add(out, map, at, 0.45 + 0.35 * sin(t * 0.3 + h * 9.0),
			Color(DUST, 0.45), 0.05, true)
	return out

## The source patch colours its spores; green keeps its existing pale tint.
static func _spore_colour(tile: int) -> Color:
	match tile:
		Tiles.FUNGUS_PURPLE:
			return Palette.FUNGUS_PURPLE
		Tiles.FUNGUS_RED:
			return Palette.FUNGUS_RED
		_:
			return SPORE

## Where the trader stands off their own cell at time `t`, in cells on the
## floor, with you at `you_at` (where you are drawn, so the lean follows your
## step): shifting their weight about, and leaning towards you when you are
## close. Their picture faces the front -- a bust in a circle -- so leaning in
## is how they turn to you. Zero for anyone else, and unless the setting is
## "full": like the rest of small life, it never stops moving. Nobody leaves
## their cell by it: the most it adds up to is about a quarter of a cell.
func idle_offset(e: Entity, you_at: Vector2, t: float) -> Vector2:
	if _state == null or e == null or e != _state.trader or not Effects.shaders():
		return Vector2.ZERO
	var h := LivingLight.hash01(e.x * 3 + 1, e.y * 5 + 2)
	var sway := Vector2(sin(t * 1.6 + h * 20.0), 0.5 * sin(t * 1.1 + h * 13.0)) \
		* TRADER_SWAY
	var to_you := you_at - Vector2(e.x, e.y)
	var d := to_you.length()
	if d < 0.5 or d >= TRADER_NOTICE:
		return sway
	var near := clampf((TRADER_NOTICE - d) / (TRADER_NOTICE - 1.0), 0.0, 1.0)
	return sway + to_you / d * TRADER_LEAN * near

## Keeps a mote only over a cell you can see, and, unless it glows by itself,
## only as bright as the light where it is.
func _add(out: Array, map: DungeonMap, at: Vector2, height: float, colour: Color,
		size: float, lit: bool) -> void:
	var cell := Vector2i(floori(at.x), floori(at.y))
	if not map.is_visible(cell.x, cell.y):
		return
	if lit:
		colour.a *= clampf(_state.light_map.get_light(cell.x, cell.y).get_luminance() * 1.6,
			0.0, 1.0)
	if colour.a > 0.02:
		out.append([at, height, colour, size])
