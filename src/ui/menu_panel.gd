class_name MenuPanel
extends Control

## The pause menu. Deliberately tiny: this exists so a run can span sessions,
## not to be a front end.

signal resume_requested()
signal save_and_quit_requested()
signal new_run_requested()

@export var font: Font
@export var font_bold: Font
@export var font_size: int = 17

## The exported default, reachable without a node. The overflow test needs the
## size the panel actually draws at, and an @export is not a constant.
static func font_size_default() -> int:
	return 17

var state: GameState

const PANEL := Vector2(460.0, 250.0)
const PAD := 26.0
const ROW_H := 34.0

const OPTIONS_DESKTOP := [
	["c", "continue", "resume"],
	["s", "save and quit", "save"],
	["n", "abandon this run", "new"],
]

## A browser tab has no quit, so the menu does not pretend otherwise. The run
## is written when the page is hidden anyway; this is the deliberate version of
## the same thing, for someone who wants to be told it worked.
const OPTIONS_WEB := [
	["c", "continue", "resume"],
	["s", "save for later", "save"],
	["n", "abandon this run", "new"],
]

var OPTIONS: Array = OPTIONS_DESKTOP

## Named constants so the overflow test can measure them. The web line was six
## characters too long and ran through the panel edge; it was caught only
## because a screenshot of the browser build happened to be taken.
const NOTE_DESKTOP := "saving quits to the desktop; resuming deletes it"
const NOTE_WEB := "leaving the page saves your run; resuming deletes it"

var _hover := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	if Platform.is_web():
		OPTIONS = OPTIONS_WEB
	if font == null:
		font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
	if font_bold == null:
		font_bold = load("res://assets/fonts/JetBrainsMono-Bold.ttf")

func open() -> void:
	visible = true
	_hover = -1
	queue_redraw()

func close() -> void:
	visible = false
	_hover = -1

func handle_key(key: int) -> bool:
	match key:
		KEY_C, KEY_ESCAPE:
			resume_requested.emit()
		KEY_S:
			save_and_quit_requested.emit()
		KEY_N:
			new_run_requested.emit()
		_:
			return false
	return true

func _panel_rect() -> Rect2:
	return Rect2(((size - PANEL) * 0.5).floor(), PANEL)

func _row_rect(i: int) -> Rect2:
	var p := _panel_rect()
	return Rect2(p.position.x + PAD, p.position.y + 92.0 + i * ROW_H,
		PANEL.x - PAD * 2.0, ROW_H)

func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		var at := _row_at(motion.position)
		if at != _hover:
			_hover = at
			queue_redraw()
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var hit := _row_at(click.position)
	if hit < 0:
		return
	match OPTIONS[hit][2]:
		"resume": resume_requested.emit()
		"save": save_and_quit_requested.emit()
		"new": new_run_requested.emit()

func _row_at(pos: Vector2) -> int:
	for i in OPTIONS.size():
		if _row_rect(i).has_point(pos):
			return i
	return -1

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.62), true)
	var p := _panel_rect()
	draw_rect(p, Palette.UI_PANEL_BG, true)
	draw_rect(p, Palette.UI_FRAME, false, 1.0)

	var asc := font.get_ascent(font_size)
	draw_string(font_bold, p.position + Vector2(PAD, PAD + asc), "PAUSED",
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.STAIRS)
	var note := NOTE_WEB if Platform.is_web() else NOTE_DESKTOP
	draw_string(font, p.position + Vector2(PAD, PAD + 26.0 + asc), note,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 4, Palette.UI_DIM)

	# Time underground, as information rather than pressure.
	#
	# It lives here, behind a keypress, precisely so it is not a clock ticking
	# in the corner of the screen: nothing in OFR is measured against elapsed
	# time, and a permanent countdown would imply a resource that does not
	# exist. You look at it when you choose to.
	if state != null:
		var line := "%s underground  ·  %d turns" % [
			Clock.text(state.time_underground()), state.turns]
		draw_string(font, p.position + Vector2(PAD, PANEL.y - PAD),
			line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 4, Palette.UI_DIM)

	for i in OPTIONS.size():
		var r := _row_rect(i)
		if i == _hover:
			draw_rect(r, Color(Palette.CURSOR, 0.13), true)
		var base := r.position + Vector2(0, font.get_ascent(font_size) + 6.0)
		draw_string(font, base, "%s)" % OPTIONS[i][0],
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.UI_DIM)
		draw_string(font, base + Vector2(36.0, 0.0), OPTIONS[i][1],
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
			Color.WHITE if i == _hover else Palette.UI_TEXT)
