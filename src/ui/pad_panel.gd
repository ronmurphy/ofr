class_name PadPanel
extends Control

## "Press a button for: move up."
##
## Exists because four people asked for controller support in one night on four
## different devices, and no table written here could be right for all of them.
## The walk-through asks the controller what it calls itself instead of
## assuming.
##
## It reads JOYPAD events directly -- the only panel in the game that does.
## Everything else speaks keycodes, which is the whole design of `Gamepad`; but
## this is the one place that has to see the raw button index, because learning
## that index is its entire job.

signal closed()
signal log_requested()

@export var font: Font
@export var font_bold: Font
@export var font_size: int = 17

## The exported default, reachable without a node -- the same seam MenuPanel
## and SummaryPanel already have, and for the same reason: the height check
## needs the size the panel actually draws at, and an @export is not a
## constant. Writing the literal 17 into the test instead would put the layout
## in the hands of a number maintained by hand in two places, which is the
## pattern that overflowed both this panel and the pause menu in one hour.
static func font_size_default() -> int:
	return 17

## TWO COLUMNS, and the width is the point rather than the height.
##
## Brad's call, from a screenshot: at fourteen rows the single column was a
## 560px tower on a 900px canvas, and the footer had run one pixel past the
## edge -- which the height assertion could not see, because it measures the
## rows and never measured the footer. Splitting the list halves the height,
## widens the panel enough for the footer to breathe, and leaves room for
## roughly 28 bindings, which is more than a controller has buttons.
##
## Sized from the content: the widest row is "swap reach / blade" with a
## "button 12" right-aligned against it, measured at 327px, so a 350px column
## holds anything the walk-through is likely to name.
const PANEL := Vector2(820.0, 400.0)
const COL_GAP := 44.0

## Rows in the left column. The right column takes the remainder, so an odd
## count leaves the extra on the left and the columns stay top-aligned.
static func left_rows() -> int:
	return int(ceil(PadConfig.WALK.size() / 2.0))
const PAD := 26.0
const ROW_H := 30.0

var cfg: PadConfig
var _at := 0
## Set while waiting for a press, so a player can see which row is live.
var _listening := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	if font == null:
		font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
	if font_bold == null:
		font_bold = load("res://assets/fonts/JetBrainsMono-Bold.ttf")

## Opens SHOWING, not listening.
##
## Reported from play on a Legion Go S: this screen used to begin capturing the
## moment it opened, so a player who came to look at their bindings rebound
## "move up" to whatever they pressed next -- and the way out is keyboard-only,
## by an earlier decision, so on a handheld there was no way to stop. Brad had
## to quit through the Steam overlay.
##
## The keyboard-only exit was right for a DEAD pad and wrong for a live one. A
## screen that reads your bindings back is the common case; rebinding is the
## rare one, and it now has to be asked for.
func open(config: PadConfig) -> void:
	cfg = config
	_at = 0
	_listening = false
	visible = true
	queue_redraw()

func close() -> void:
	visible = false
	if cfg != null:
		cfg.save()
	closed.emit()

## A joypad press, while this is open, means "bind that to the current row".
## Answers whether it was used.
func handle_pad(event: InputEvent) -> bool:
	if not visible:
		return false
	var button := event as InputEventJoypadButton
	if button == null or not button.pressed:
		return false
	# Not listening: the first press ASKS to rebind rather than rebinding. So a
	# player can open this, read what their pad does, and leave without having
	# changed anything -- which is what they came for most of the time.
	if not _listening:
		_listening = true
		_at = 0
		queue_redraw()
		return true
	if _at >= PadConfig.WALK.size():
		close()
		return true
	cfg.bind(button.button_index, int(PadConfig.WALK[_at][0]))
	_at += 1
	if _at >= PadConfig.WALK.size():
		_listening = false
	queue_redraw()
	return true

## Keys drive the panel itself: escape leaves, backspace steps back, r resets.
## Deliberately keyboard-only -- a player rebinding a broken controller cannot
## be asked to use that controller to get out.
func handle_key(key: int) -> bool:
	if not visible:
		return false
	match key:
		KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER:
			close()
		KEY_BACKSPACE:
			_at = maxi(0, _at - 1)
			_listening = true
		KEY_R:
			cfg.reset()
			_at = 0
			_listening = true
		KEY_L:
			# The escape hatch for a pad nobody can identify: start recording
			# what it sends, so a tester can send the file back rather than
			# describing the buttons in prose.
			log_requested.emit()
	queue_redraw()
	return true

func _draw() -> void:
	var at := (size - PANEL) * 0.5
	draw_rect(Rect2(at, PANEL), Color(0.07, 0.07, 0.09, 0.97), true)
	draw_rect(Rect2(at, PANEL), Color(0.38, 0.36, 0.42), false, 2.0)

	var y := at.y + PAD + font_size
	draw_string(font_bold, Vector2(at.x + PAD, y), "CONTROLLER",
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.92, 0.88, 0.70))
	y += ROW_H

	# Three states, not two: showing what you have, walking through a rebind,
	# and finished. The first is new -- it used to open straight into the walk.
	var note := "press any button to start rebinding     esc  leave"
	if _listening and _at < PadConfig.WALK.size():
		note = "press a button for each line"
	elif _listening:
		note = "all set -- enter to finish"
	draw_string(font, Vector2(at.x + PAD, y), note,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 3, Color(0.68, 0.66, 0.72))
	y += ROW_H

	# Two columns, filled down the left and then down the right, so the reading
	# order matches the order the walk-through asks in. Filling across would
	# put "move up" and "move down" side by side and the eye would follow the
	# wrong one.
	var split := left_rows()
	var col_w := (PANEL.x - PAD * 2.0 - COL_GAP) * 0.5
	var top := y
	for i in PadConfig.WALK.size():
		var row: Array = PadConfig.WALK[i]
		var col := 0 if i < split else 1
		var col_x: float = at.x + PAD + float(col) * (col_w + COL_GAP)
		var row_y: float = top + float(i - (split if col == 1 else 0)) * ROW_H

		var live := i == _at and _listening
		var tint := Color(0.95, 0.82, 0.45) if live else Color(0.78, 0.76, 0.80)
		if i < _at:
			tint = Color(0.60, 0.72, 0.60)
		draw_string(font, Vector2(col_x, row_y), String(row[1]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)
		var said := "press a button" if live else "--"
		var has := cfg.button_for_key(int(row[0])) if cfg != null else -1
		if not live and has >= 0:
			said = PadConfig.button_name(has)
		# Right-aligned within its own column rather than the panel, or the
		# left column's bindings would sit in the right column's labels.
		draw_string(font, Vector2(col_x, row_y), said,
			HORIZONTAL_ALIGNMENT_RIGHT, col_w, font_size, tint)

	y = top + float(split) * ROW_H + 6.0
	draw_string(font, Vector2(at.x + PAD, y),
		"backspace  back     r  defaults     l  log this pad     esc  done",
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 4, Color(0.58, 0.56, 0.62))
