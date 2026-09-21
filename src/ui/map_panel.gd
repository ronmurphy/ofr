class_name MapPanel
extends Control

## The floor as you know it, all at once.
##
## Reported by Brad and by a player independently: you remember passing a lit
## brazier, you need one now, and it is somewhere off the edge of a viewport
## that only ever shows part of the floor. The information was earned and then
## withheld, which is different from the information this game withholds on
## purpose.
##
## So it shows ONLY what is explored. A cell you have never seen is not drawn,
## and the shape of the unknown is itself the useful part -- a floor with a
## black quarter is a floor with somewhere left to go.
##
## Drawn as blocks rather than glyphs. At the scale a whole floor needs, a
## character is unreadable anyway, and a block says "ground" or "wall" at a
## glance. The landmarks are the exception: those are the whole reason to open
## this, so they are drawn bigger and in their own colours.

signal closed()
signal legend_requested()

@export var font: Font
@export var font_bold: Font
@export var font_size: int = 17

var state: GameState

const PAD := 34.0
## Never smaller than this, or a landmark dot lands between pixels and the
## floor reads as noise.
const MIN_CELL := 3.0
const MAX_CELL := 10.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	if font == null:
		font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
	if font_bold == null:
		font_bold = load("res://assets/fonts/JetBrainsMono-Bold.ttf")

func open() -> void:
	visible = true
	queue_redraw()

func close() -> void:
	visible = false
	closed.emit()

## Left goes back to the legend, and everything else closes.
##
## The two screens are pages of one reference, the way a Zelda menu pages
## between map and equipment -- Brad's comparison, and it is why the map needed
## no controller button of its own. The legend already has one; this rides in
## beside it. On a pad, left and right are the d-pad, which costs nothing and
## is already bound on every device.
func handle_key(key: int) -> bool:
	if not visible:
		return false
	if key == KEY_LEFT:
		visible = false
		legend_requested.emit()
		return true
	close()
	return true

func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed:
		close()

func _draw() -> void:
	if state == null or state.map == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.86), true)

	var w := state.map.width
	var h := state.map.height
	# Fit the whole floor, then clamp: a tiny dungeon should not be drawn at
	# forty pixels a cell, and a big one must not shrink below legibility.
	var room := size - Vector2(PAD * 2.0, PAD * 2.0 + 64.0)
	var cell: float = clampf(minf(room.x / w, room.y / h), MIN_CELL, MAX_CELL)
	var board := Vector2(w * cell, h * cell)
	var at := ((size - board) * 0.5).floor()
	at.y = maxf(at.y, PAD + 30.0)

	draw_string(font_bold, Vector2(at.x, at.y - 14.0),
		"THE FLOOR SO FAR", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
		Palette.STAIRS)

	# Terrain first, landmarks over it.
	for y in h:
		for x in w:
			if not state.map.is_explored(x, y):
				continue
			var t := state.map.get_tile(x, y)
			var c := _terrain_colour(t)
			if c.a <= 0.0:
				continue
			draw_rect(Rect2(at + Vector2(x * cell, y * cell),
				Vector2(cell, cell)), c, true)

	# The things you opened this to find.
	for y in h:
		for x in w:
			if not state.map.is_explored(x, y):
				continue
			var mark := _landmark(x, y)
			if mark.a <= 0.0:
				continue
			# Bigger than a terrain cell so a single brazier is findable on a
			# floor of two thousand squares.
			var r: float = maxf(cell, 4.0)
			draw_rect(Rect2(at + Vector2(x * cell, y * cell)
				- Vector2(r - cell, r - cell) * 0.5, Vector2(r, r)), mark, true)

	if state.player != null:
		var pr: float = maxf(cell * 1.4, 6.0)
		draw_rect(Rect2(at + Vector2(state.player.x * cell, state.player.y * cell)
			- Vector2(pr - cell, pr - cell) * 0.5, Vector2(pr, pr)),
			MARK_PLAYER, true)

	_legend_line(at, board)

## Walls and floor only, and both dim: this is a shape, not a scene.
func _terrain_colour(t: int) -> Color:
	if t == Tiles.WALL or t == Tiles.ROCK:
		return Color(0.20, 0.20, 0.24)
	if t == Tiles.DOOR_CLOSED or t == Tiles.DOOR_OPEN:
		return Color(0.55, 0.42, 0.28)
	if t == Tiles.WATER:
		return Color(0.16, 0.26, 0.36)
	if t == Tiles.PIT:
		return Color(0.06, 0.05, 0.07)
	if Tiles.is_walkable(t):
		return Color(0.32, 0.31, 0.33)
	return Color(0, 0, 0, 0)

## The map's own palette, and NOT the map's colours.
##
## The first version reused Palette.STAIRS, AMULET and so on, so a brazier and
## a chest on the overview would match a brazier and a chest on the floor. That
## was wrong for a reason the palette checker states plainly: colour only has to
## be distinct where SHAPE is not, and on this screen every landmark is the
## same square. There is no glyph to fall back on, so colour carries the whole
## difference.
##
## Measured, reusing the game's colours: five of the fifteen pairs were
## indistinguishable, brazier against chest at deltaE 9.9 and stairs against
## chest at 15.1 -- and Brad spotted it from the legend strip in a screenshot.
##
## These clear 25 on all fifteen pairs under normal vision and all three
## dichromacies, worst 28.5. They are checked by the suite, so a future
## landmark cannot quietly collide with an existing one.
const MARK_STAIRS  := Color("fff36b")
const MARK_SHRINE  := Color("b98cd6")
const MARK_BRAZIER := Color("e86a10")
const MARK_SPENT   := Color("7a5c3d")
const MARK_CHEST   := Color("3fd0a0")
const MARK_PLAYER  := Color("ffffff")

## Named, in the order the strip prints them. One table so the key at the
## bottom and the marks on the floor cannot drift apart, and so the suite can
## walk every pair.
const MARKS := [
	["you", MARK_PLAYER], ["stairs", MARK_STAIRS], ["shrine", MARK_SHRINE],
	["brazier", MARK_BRAZIER], ["spent", MARK_SPENT], ["chest", MARK_CHEST],
]

## A brazier that has burned out is drawn DIM rather than left off: knowing
## where a dead one stands is what makes a scroll of light worth carrying.
func _landmark(x: int, y: int) -> Color:
	return _landmark_for(state.map.get_tile(x, y))

## Split from _landmark so the colours can be asserted without a map to stand
## on: a test that has to build a floor to find out what colour a spent brazier
## is will stop being written.
func _landmark_for(t: int) -> Color:
	match t:
		Tiles.STAIRS_DOWN, Tiles.STAIRS_UP:
			return MARK_STAIRS
		Tiles.SHRINE:
			return MARK_SHRINE
		Tiles.BRAZIER:
			return MARK_BRAZIER
		Tiles.BRAZIER_SPENT, Tiles.BRAZIER_DEAD:
			return MARK_SPENT
		Tiles.CHEST:
			return MARK_CHEST
	return Color(0, 0, 0, 0)

func _legend_line(at: Vector2, board: Vector2) -> void:
	var y := at.y + board.y + 22.0
	var parts := MARKS
	var x := at.x
	for p in parts:
		draw_rect(Rect2(Vector2(x, y - 9.0), Vector2(9.0, 9.0)), p[1], true)
		draw_string(font, Vector2(x + 14.0, y), String(p[0]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 4, Palette.UI_DIM)
		x += 14.0 + font.get_string_size(String(p[0]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 4).x + 18.0

	draw_string(font, Vector2(at.x, y + 24.0),
		"left  the legend        any other key  close",
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 4, Palette.UI_DIM)
