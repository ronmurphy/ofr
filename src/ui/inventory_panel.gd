class_name InventoryPanel
extends Control

## Modal inventory.
##
## Both input routes are first class: click a row to use it, or press its
## letter. Roguelike players are split down the middle on this and neither half
## should feel like the afterthought.

signal use_requested(index: int)
signal drop_requested(index: int)
signal close_requested()

@export var font: Font
@export var font_bold: Font
@export var font_size: int = 16

var state: GameState
var _hover_row := -1

const PANEL := Vector2(560.0, 440.0)
const ROW_H := 27.0
const PAD := 22.0
const HEADER := 76.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	if font == null:
		font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
	if font_bold == null:
		font_bold = load("res://assets/fonts/JetBrainsMono-Bold.ttf")

func open() -> void:
	visible = true
	_hover_row = -1
	queue_redraw()

func close() -> void:
	visible = false
	_hover_row = -1

func letter_to_index(key: int) -> int:
	if key < KEY_A or key > KEY_Z:
		return -1
	var i := key - KEY_A
	if state == null or i >= state.player.inventory.size():
		return -1
	return i

func _panel_rect() -> Rect2:
	return Rect2(((size - PANEL) * 0.5).floor(), PANEL)

func _row_rect(i: int) -> Rect2:
	var p := _panel_rect()
	return Rect2(p.position.x + PAD, p.position.y + HEADER + i * ROW_H,
		PANEL.x - PAD * 2.0, ROW_H)

# ------------------------------------------------------------------ input ---

func _gui_input(event: InputEvent) -> void:
	if state == null:
		return

	var motion := event as InputEventMouseMotion
	if motion != null:
		var row := _row_at(motion.position)
		if row != _hover_row:
			_hover_row = row
			queue_redraw()
		return

	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return

	var hit := _row_at(click.position)
	if hit < 0:
		# Clicking outside the panel dismisses it, which is what every other
		# modal on the machine does.
		if not _panel_rect().has_point(click.position):
			close_requested.emit()
		return
	if click.button_index == MOUSE_BUTTON_LEFT:
		use_requested.emit(hit)
	elif click.button_index == MOUSE_BUTTON_RIGHT:
		drop_requested.emit(hit)

func _row_at(pos: Vector2) -> int:
	for i in state.player.inventory.size():
		if _row_rect(i).has_point(pos):
			return i
	return -1

# ---------------------------------------------------------------- drawing ---

func _draw() -> void:
	if state == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.55), true)

	var p := _panel_rect()
	draw_rect(p, Palette.UI_PANEL_BG, true)
	draw_rect(p, Palette.UI_FRAME, false, 1.0)

	var items: Array = state.player.inventory
	draw_string(font_bold, p.position + Vector2(PAD, PAD + font.get_ascent(font_size)),
		"INVENTORY", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.STAIRS)
	draw_string(font, p.position + Vector2(PAD, PAD + 26.0 + font.get_ascent(font_size)),
		"%d / %d carried" % [items.size(), Entity.INVENTORY_MAX],
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.UI_DIM)

	if items.is_empty():
		draw_string(font, _row_rect(0).position + Vector2(0, font.get_ascent(font_size)),
			"(nothing)", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.UI_DIM)
	else:
		for i in items.size():
			_draw_row(i, items[i])

	var hint := "click use   ·   right-click drop   ·   a-z use   ·   esc close"
	draw_string(font, Vector2(p.position.x + PAD, p.end.y - PAD),
		hint, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 2, Palette.UI_DIM)

func _draw_row(i: int, item: Item) -> void:
	var r := _row_rect(i)
	if i == _hover_row:
		draw_rect(r, Color(Palette.CURSOR, 0.13), true)

	var app: Dictionary = AsciiTheme.TABLE.get(item.appearance, {"ch": "?", "fg": Palette.UI_TEXT})
	var base := r.position + Vector2(0, font.get_ascent(font_size) + 3.0)
	var label := Palette.UI_TEXT if i != _hover_row else Color.WHITE

	draw_string(font, base, "%s)" % String.chr(KEY_A + i).to_lower(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.UI_DIM)
	draw_string(font, base + Vector2(34.0, 0.0), app["ch"],
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, app["fg"])
	draw_string(font, base + Vector2(60.0, 0.0), item.name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, label)
