class_name GlyphGrid
extends Control

## Draws the simulation as a grid of glyphs.
##
## Three things here are what separate this from a terminal:
##   - square cells, so the dungeon is not vertically stretched and diagonal
##     movement looks correct
##   - per-cell BACKGROUND colour, which almost no terminal roguelike uses well
##     and which is most of what makes the map read as a lit scene
##   - box-drawing walls chosen from neighbours, so rooms have real outlines

signal cell_clicked(cell: Vector2i)

enum WallStyle {
	LINE,   ## procedural single-line box drawing -- always connects
	SOLID,  ## filled blocks, heavier and more "dungeon"
	GLYPH,  ## font box-drawing characters; dashes in a square cell
}

@export var cell_size: int = 18
@export var font_size: int = 16
@export var font: Font
## Purely a taste call, so it is exposed rather than decided. LINE is the
## default because font box-glyphs are only ~0.6 cells wide and leave visible
## gaps in horizontal runs once the cell is square.
@export var wall_style: WallStyle = WallStyle.LINE

var state: GameState
var render_theme: RenderTheme = AsciiTheme.new()

# Wall connection bits: N=1 S=2 W=4 E=8
const BOX := {
	0: "█", 1: "║", 2: "║", 3: "║",
	4: "═", 5: "╝", 6: "╗", 7: "╣",
	8: "═", 9: "╚", 10: "╔", 11: "╠",
	12: "═", 13: "╩", 14: "╦", 15: "╬",
}

## Driven by the keyboard look mode. When valid it takes precedence over the
## mouse hover, since the two would otherwise fight for the same highlight.
var look_cursor := Vector2i(-1, -1)
var _hover := Vector2i(-1, -1)
var _preview: Array[Vector2i] = []
var _glyph_dx := 0.0
var _glyph_baseline := 0.0
## Torch flicker lives here, in the renderer, NOT in the simulation. The sim
## must stay deterministic and turn-driven; flicker is a per-frame visual.
var _flicker := 1.0
var _flicker_accum := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if font == null:
		font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
	_measure_font()
	set_process(true)

func _measure_font() -> void:
	var advance := font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	_glyph_dx = (cell_size - advance) * 0.5
	_glyph_baseline = (cell_size - (ascent + descent)) * 0.5 + ascent

func _process(delta: float) -> void:
	# Refresh flicker at ~15Hz rather than every frame: cheaper, and a choppier
	# flame actually reads more like a real torch than a smooth sine does.
	_flicker_accum += delta
	if _flicker_accum < 1.0 / 15.0:
		return
	_flicker_accum = 0.0
	var t := Time.get_ticks_msec() / 1000.0
	_flicker = 1.0 + sin(t * 11.0) * 0.035 + sin(t * 23.7) * 0.022 + randf_range(-0.02, 0.02)
	queue_redraw()

func grid_size() -> Vector2:
	if state == null:
		return Vector2.ZERO
	return Vector2(state.map.width * cell_size, state.map.height * cell_size)

func cell_at(local_pos: Vector2) -> Vector2i:
	return Vector2i(floori(local_pos.x / cell_size), floori(local_pos.y / cell_size))

# ------------------------------------------------------------------ input ---

func _gui_input(event: InputEvent) -> void:
	if state == null:
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		var c := cell_at(motion.position)
		if c != _hover:
			_hover = c
			_update_preview()
			queue_redraw()
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		cell_clicked.emit(cell_at(click.position))

func _update_preview() -> void:
	_preview.clear()
	if not state.map.in_bounds(_hover.x, _hover.y):
		return
	if not state.map.is_explored(_hover.x, _hover.y):
		return
	_preview = state.pathfinder.path(Vector2i(state.player.x, state.player.y), _hover)

func hovered_cell() -> Vector2i:
	return _hover

# ----------------------------------------------------------------- drawing ---

func _draw() -> void:
	if state == null:
		return
	var map := state.map
	draw_rect(Rect2(Vector2.ZERO, grid_size()), Palette.BG, true)

	for y in map.height:
		for x in map.width:
			_draw_cell(map, x, y)

	# Ground items sit under actors, so a monster standing on loot still reads
	# as the thing you need to deal with first.
	for it in state.ground:
		if map.is_visible(it.x, it.y):
			_draw_glyph(it.appearance, it.x, it.y)

	for e in state.entities:
		if e.alive and not e.is_player and map.is_visible(e.x, e.y):
			_draw_glyph(e.appearance, e.x, e.y)
	if state.player.alive:
		_draw_glyph(state.player.appearance, state.player.x, state.player.y)

	_draw_preview()
	_draw_cursor()

func _draw_cell(map: DungeonMap, x: int, y: int) -> void:
	var visible_here := map.is_visible(x, y)
	if not visible_here and not map.is_explored(x, y):
		return

	var tile := map.get_tile(x, y)
	var is_wall := tile == Tiles.WALL
	var ch := ""
	var fg: Color
	var bg: Color

	if is_wall:
		fg = Palette.STONE_LIGHT
		bg = Palette.STONE_DARK
	else:
		var app := render_theme.appearance(Tiles.appearance_id(tile))
		ch = app["ch"]
		fg = app["fg"]
		bg = app.get("bg", Palette.BG)

	if visible_here:
		var lit: Color = state.light_map.get_light(x, y) * _flicker
		fg = (fg * lit).clamp()
		bg = (bg * lit).clamp()
	else:
		fg = _remembered(fg)
		bg = _remembered(bg)

	var origin := Vector2(x * cell_size, y * cell_size)
	if is_wall:
		_draw_wall(origin, _wall_mask(map, x, y), fg, bg)
		return

	draw_rect(Rect2(origin, Vector2(cell_size, cell_size)), bg, true)
	if ch != " ":
		draw_char(font, origin + Vector2(_glyph_dx, _glyph_baseline), ch, font_size, fg)

## Walls are drawn from their connection mask rather than from a font glyph.
##
## A box-drawing character fills its own advance width, which is about 0.6 of a
## square cell -- so a run of ═ comes out as dashes with gaps between them.
## Drawing the strokes directly connects perfectly at any cell size and stays
## crisp when you change cell_size later.
func _draw_wall(origin: Vector2, mask: int, fg: Color, bg: Color) -> void:
	var cell := Vector2(cell_size, cell_size)

	if wall_style == WallStyle.SOLID:
		draw_rect(Rect2(origin, cell), fg, true)
		return
	if wall_style == WallStyle.GLYPH:
		draw_rect(Rect2(origin, cell), bg, true)
		draw_char(font, origin + Vector2(_glyph_dx, _glyph_baseline), BOX[mask], font_size, fg)
		return

	draw_rect(Rect2(origin, cell), bg, true)
	var c := origin + cell * 0.5
	var t := maxf(1.0, cell_size * 0.11)
	var half := t * 0.5

	if mask == 0:
		draw_rect(Rect2(c - Vector2(t, t) * 0.75, Vector2(t, t) * 1.5), fg, true)
		return
	if mask & 1:  # north
		draw_rect(Rect2(c.x - half, origin.y, t, c.y + half - origin.y), fg, true)
	if mask & 2:  # south
		draw_rect(Rect2(c.x - half, c.y - half, t, origin.y + cell_size - c.y + half), fg, true)
	if mask & 4:  # west
		draw_rect(Rect2(origin.x, c.y - half, c.x + half - origin.x, t), fg, true)
	if mask & 8:  # east
		draw_rect(Rect2(c.x - half, c.y - half, origin.x + cell_size - c.x + half, t), fg, true)

## Walls only connect to other walls that actually face open space. Without
## this every wall in the solid rock would join up and the whole map would be
## a field of ╬.
func _wall_mask(map: DungeonMap, x: int, y: int) -> int:
	var mask := 0
	if _is_face_wall(map, x, y - 1): mask |= 1
	if _is_face_wall(map, x, y + 1): mask |= 2
	if _is_face_wall(map, x - 1, y): mask |= 4
	if _is_face_wall(map, x + 1, y): mask |= 8
	return mask

func _is_face_wall(map: DungeonMap, x: int, y: int) -> bool:
	if not map.in_bounds(x, y) or map.get_tile(x, y) != Tiles.WALL:
		return false
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			if map.is_walkable(x + dx, y + dy):
				return true
	return false

func _remembered(c: Color) -> Color:
	var m := c.lerp(Palette.MEMORY, Palette.MEMORY_MIX)
	return Color(m.r * Palette.MEMORY_DIM, m.g * Palette.MEMORY_DIM, m.b * Palette.MEMORY_DIM, 1.0)

func _draw_glyph(id: StringName, x: int, y: int) -> void:
	var app := render_theme.appearance(id)
	var fg: Color = app["fg"]
	var lit: Color = state.light_map.get_light(x, y) * _flicker
	# Floor of 0.45 so something standing in gloom is still legible. Realism
	# loses to readability every time in a game you play by reading.
	fg = (fg * lit.lerp(Color.WHITE, 0.45)).clamp()
	var origin := Vector2(x * cell_size, y * cell_size)
	draw_char(font, origin + Vector2(_glyph_dx, _glyph_baseline), app["ch"], font_size, fg)

func _draw_preview() -> void:
	if _preview.is_empty() or state.game_over:
		return
	if state.map.in_bounds(look_cursor.x, look_cursor.y):
		return
	var r := cell_size * 0.16
	for cell in _preview:
		var c := Vector2(cell.x * cell_size, cell.y * cell_size) + Vector2(cell_size, cell_size) * 0.5
		draw_circle(c, r, Color(Palette.PATH_HINT, 0.55))

func _draw_cursor() -> void:
	var cell := Vector2(cell_size, cell_size)
	if state.map.in_bounds(look_cursor.x, look_cursor.y):
		var lo := Vector2(look_cursor.x * cell_size, look_cursor.y * cell_size)
		draw_rect(Rect2(lo, cell), Color(Palette.CURSOR, 0.14), true)
		draw_rect(Rect2(lo, cell), Palette.CURSOR, false, 2.0)
		return
	if not state.map.in_bounds(_hover.x, _hover.y):
		return
	var origin := Vector2(_hover.x * cell_size, _hover.y * cell_size)
	draw_rect(Rect2(origin, cell), Color(Palette.CURSOR, 0.85), false, 1.0)
