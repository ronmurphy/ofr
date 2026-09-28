class_name MapMemory
extends RefCounted

## How long ago each cell was last in view, so remembered ground fades the
## longer ago you saw it -- except the landmarks, which a player keeps: stairs,
## doors, braziers, shrines, and the trader. ONE of these is shared by both
## views (main.gd hands it out), so the two agree on what you remember.
##
## Kept by the view, not the save: a loaded game starts with everything it
## remembers counted as freshly seen. Fading is atmosphere, not a rule, so it
## does not touch the save format.

## Memory holds for this many turns, then fades over the next few hundred to a
## floor it never goes below -- a map you walked is dimmer, never lost.
const FADE_AFTER := 100
const FADE_FULL := 500
const FADE_FLOOR := 0.5

## The tiles a player navigates by, which never fade.
const LANDMARK_TILES := {
	Tiles.STAIRS_DOWN: true, Tiles.STAIRS_UP: true,
	Tiles.DOOR_CLOSED: true, Tiles.DOOR_OPEN: true,
	Tiles.BRAZIER: true, Tiles.BRAZIER_SPENT: true, Tiles.BRAZIER_DEAD: true,
	Tiles.SHRINE: true,
}

## The turn each cell was last in view, for the floor in `_map`.
var _seen := PackedInt32Array()
var _map: DungeonMap = null
var _turn := -1
## Where the remembered trader stands, or (-1, -1) -- see remembered_trader.
var trader_cell := Vector2i(-1, -1)

## Every cell in view is seen now. Cheap to call more than once a turn: the
## cells are only stamped when the turn or the floor has changed. The trader is
## looked up every time -- one lookup, and it means a floor revealed between
## turns (a test, a debug reveal) still shows them.
func update(state: GameState) -> void:
	trader_cell = remembered_trader(state)
	var map := state.map
	var now := state.turns
	if map == _map and now == _turn:
		return
	if map != _map:
		_map = map
		_seen.resize(map.width * map.height)
		# Whatever is already known counts as just seen.
		_seen.fill(now)
	_turn = now
	var shown := map.visible_now
	for i in _seen.size():
		if shown[i] != 0:
			_seen[i] = now

## How bright remembered ground at (x, y) still is: 1, down to FADE_FLOOR.
## Cheap for the common case -- ground seen recently -- because the classic
## view asks for every remembered cell it draws.
func fade(x: int, y: int, turns: int) -> float:
	if _map == null or not _map.in_bounds(x, y):
		return 1.0
	var age := turns - _seen[y * _map.width + x]
	if age <= FADE_AFTER or not _map.is_explored(x, y) or is_landmark(x, y):
		return 1.0
	return fade_for_age(age)

## fade() for every cell of the floor at once, in map order. Ground never seen
## is left at 1: nothing draws it, so there is nothing to work out.
func fades(turns: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_seen.size())
	out.fill(1.0)
	if _map == null:
		return out
	var tiles := _map.tiles
	var known := _map.explored
	var trader := -1
	if trader_cell.x >= 0:
		trader = trader_cell.y * _map.width + trader_cell.x
	var recent := turns - FADE_AFTER
	for i in _seen.size():
		if _seen[i] >= recent or known[i] == 0 or i == trader \
				or LANDMARK_TILES.has(tiles[i]):
			continue
		out[i] = fade_for_age(turns - _seen[i])
	return out

## The fade for ground last seen `age` turns ago. Split out so the curve can be
## checked without a floor to stand on.
static func fade_for_age(age: int) -> float:
	var k := clampf(float(age - FADE_AFTER) / float(FADE_FULL - FADE_AFTER), 0.0, 1.0)
	return 1.0 - (1.0 - FADE_FLOOR) * k

## The things a player navigates by never fade: LANDMARK_TILES, and the trader.
func is_landmark(x: int, y: int) -> bool:
	return Vector2i(x, y) == trader_cell or LANDMARK_TILES.has(_map.get_tile(x, y))

## Where the trader is known to stand, or (-1, -1): a floor with a trader, on a
## cell you have seen. In sight or not -- the views draw the live trader while
## the cell is in view and this picture of them once it is not.
##
## "Seen the cell" stands in for "seen the trader" because a trader never moves
## and nothing fights one (GameState._place_trader): whoever saw that cell saw
## them in it. It also means the memory survives a save and load, which a
## record of sightings kept here would not. Static, so the overview map can ask
## without holding one of these.
static func remembered_trader(state: GameState) -> Vector2i:
	var t: Entity = state.trader
	if t == null or not t.alive or not state.map.is_explored(t.x, t.y):
		return Vector2i(-1, -1)
	return Vector2i(t.x, t.y)

## The trader as remembered: their own gold, muted towards memory's blue so
## nobody mistakes the picture for the trader in sight -- but never dimmed, and
## never faded, because a landmark is the point of remembering.
static func trader_colour() -> Color:
	return Palette.TRADER.lerp(Palette.MEMORY, 0.45)
