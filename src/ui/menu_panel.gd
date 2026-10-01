class_name MenuPanel
extends Control

## The pause menu. Deliberately tiny: this exists so a run can span sessions,
## not to be a front end.

signal resume_requested()
signal pad_requested()
signal text_size_requested()
signal save_and_quit_requested()
signal new_run_requested()
signal morgue_requested()
## The legend, from the menu. Brad, 2026-09-28: in Firefox an Xbox pad's View
## button -- the legend's button -- never arrives at all (the pad watch showed
## nothing), but Start does. Every device reaches this menu, so the legend is
## one row away everywhere, with no button rebound.
signal help_requested()

@export var font: Font
@export var font_bold: Font
@export var font_size: int = 17

## The exported default, reachable without a node. The overflow test needs the
## size the panel actually draws at, and an @export is not a constant.
static func font_size_default() -> int:
	return 17

var state: GameState
## Which device is in the player's hands, set by main.gd as for the sidebar.
## On a pad the letters mean nothing, so the rows drop them, the highlight
## starts on the first row, and a line under the rows names the two buttons
## that pick and leave (the screens review, 2026-10-01).
var pad_cfg: PadConfig = null
var pad_input := false

## Grown a row for the controller option, and another for text size.
##
## The overflow test measures PANEL.x against the note strings. Until the text
## size row was added nothing checked the HEIGHT at all, and the comment here
## claimed that it did -- a comment asserting a measurement that was never
## taken. _test_panels_do_not_overflow now asserts the rows fit too, so this is
## the one place the height is stated and the claim is true again.
## 404: 386 plus the pad's hint line under the rows (the screens review).
const PANEL := Vector2(460.0, 404.0)
## Where the rows' text starts: past a keycap on a keyboard, and the same
## place on a pad, so the two layouts line up.
const TEXT_X := 40.0
const PAD := 26.0
const ROW_H := 34.0

const OPTIONS_DESKTOP := [
	["c", "continue", "resume"],
	["h", "help: every key", "help"],
	["g", "controller", "pad"],
	["t", "text size", "text"],
	["m", "open the morgue folder", "morgue"],
	["s", "save and quit", "save"],
	["n", "abandon this run", "new"],
]

## A browser tab has no quit, so the menu does not pretend otherwise. The run
## is written when the page is hidden anyway; this is the deliberate version of
## the same thing, for someone who wants to be told it worked.
const OPTIONS_WEB := [
	["c", "continue", "resume"],
	["h", "help: every key", "help"],
	["g", "controller", "pad"],
	["t", "text size", "text"],
	["m", "download the morgue", "morgue"],
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
	# A pad has no letters to press, so it opens with a row already chosen.
	_hover = 0 if pad_input else -1
	queue_redraw()

## The letter a row prints before its name: none on a pad.
func row_prefix(i: int) -> String:
	if pad_input or i < 0 or i >= OPTIONS.size():
		return ""
	return String(OPTIONS[i][0])

## Who you are and where, on the title's line: the thing a player coming back
## to a suspended run wants to know before anything else.
func whereabouts() -> String:
	if state == null:
		return ""
	var name := state.player_name if state.player_name != "" else "OFR"
	if state.won:
		return "%s \u00b7 escaped" % name
	return "%s \u00b7 depth %d%s \u00b7 level %d" % [name, state.depth,
		" UP" if state.ascending else "", state.player.level]

## The pad's way round the menu, in its own pictures: pick, and back.
func pad_hint() -> String:
	if pad_cfg == null:
		return ""
	return "%s pick     %s back" % [pad_cfg.icon(KEY_PERIOD, true),
		pad_cfg.icon(KEY_ESCAPE, true)]

func close() -> void:
	visible = false
	_hover = -1

func handle_key(key: int) -> bool:
	# Escape has no row of its own, so it stays an alias for continue.
	if key == KEY_ESCAPE:
		resume_requested.emit()
		return true

	# A controller cannot press the letters. A default pad sends UP DOWN LEFT
	# RIGHT PERIOD G I X F W ESCAPE QUESTION C A, so `t`, `s` and `n` are
	# unreachable and are not bindable either -- which left text size, the one
	# row that exists FOR handhelds, as a row a handheld could not press.
	# Moving a highlight with the d-pad and choosing with wait costs no new
	# bindings, works before anything is rebound, and covers every future row.
	if key == KEY_UP:
		_move_hover(-1)
		return true
	if key == KEY_DOWN:
		_move_hover(1)
		return true
	if key == KEY_PERIOD or key == KEY_ENTER or key == KEY_KP_ENTER:
		_activate(_hover)
		return true

	# The letter a row PRINTS is the key it answers to, read off OPTIONS rather
	# than repeated in a second list. There were three dispatch paths here --
	# mouse, keyboard and now controller -- and keeping three lists in step by
	# hand is what left the controller row working by letter and dead to clicks.
	# Deriving this one means adding a row wires all three in a single edit.
	var pressed := String.chr(key).to_lower()
	for i in OPTIONS.size():
		if OPTIONS[i][0] == pressed:
			_activate(i)
			return true
	return false

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
	_activate(_row_at(click.position))

## The one place a row becomes a signal, so the mouse path and the controller
## path cannot drift apart. They already did once: the controller row was added
## to OPTIONS and to the keyboard and stayed dead to clicks, because the match
## that turns a row into a signal was duplicated and only one copy was updated.
func _activate(i: int) -> void:
	if i < 0 or i >= OPTIONS.size():
		return
	match OPTIONS[i][2]:
		"resume": resume_requested.emit()
		"pad": pad_requested.emit()
		"text": text_size_requested.emit()
		"morgue": morgue_requested.emit()
		"help": help_requested.emit()
		"save": save_and_quit_requested.emit()
		"new": new_run_requested.emit()

## Moves the highlight, wrapping at both ends.
##
## From nowhere, down lands on the first row and up on the last, so the first
## press on a pad always goes somewhere predictable rather than depending on
## where a mouse happened to be left.
func _move_hover(step: int) -> void:
	if _hover < 0:
		_hover = 0 if step > 0 else OPTIONS.size() - 1
	else:
		_hover = posmod(_hover + step, OPTIONS.size())
	queue_redraw()

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
	# Right of the title, in the room the title leaves.
	var title_w := font_bold.get_string_size("PAUSED", HORIZONTAL_ALIGNMENT_LEFT, -1,
		font_size).x
	draw_string(font, p.position + Vector2(PAD + title_w + 12.0, PAD + asc), whereabouts(),
		HORIZONTAL_ALIGNMENT_RIGHT, PANEL.x - PAD * 2.0 - title_w - 12.0, font_size - 4,
		Palette.UI_DIM)
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

	# Which build this is, right-aligned on the SAME baseline as the clock, so
	# it costs no height and the panel guard does not have to move.
	#
	# Here rather than on the title screen because this is the one panel a
	# player can always reach, including from a handheld with no keyboard --
	# and "which build are you running" is a question that only ever gets asked
	# once something is already wrong.
	draw_string(font, p.position + Vector2(PAD, PANEL.y - PAD),
		BuildInfo.BUILD, HORIZONTAL_ALIGNMENT_RIGHT, PANEL.x - PAD * 2.0,
		font_size - 4, Palette.UI_DIM)

	for i in OPTIONS.size():
		var r := _row_rect(i)
		if i == _hover:
			draw_rect(r, Color(Palette.CURSOR, 0.13), true)
		var base := r.position + Vector2(0, font.get_ascent(font_size) + 6.0)
		# A keycap on a keyboard; on a pad, a mark on the chosen row instead.
		var prefix := row_prefix(i)
		if prefix != "":
			Keycap.draw(self, base, prefix, font, font_size - 2, Palette.STAIRS)
		elif i == _hover:
			draw_string(font, base, "\u203a", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
				Palette.CURSOR)
		# Abandoning is the one row that ends a run: it wears a warning.
		var tint: Color = Palette.UI_TEXT
		if String(OPTIONS[i][2]) == "new":
			tint = Color("e08a8a")
		draw_string(font, base + Vector2(TEXT_X, 0.0), OPTIONS[i][1],
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
			Color.WHITE if i == _hover else tint)
	# Under the rows, on a pad: how to pick and how to leave.
	if pad_input and pad_cfg != null:
		PadGlyphs.draw(self, p.position + Vector2(PAD, PANEL.y - PAD - 20.0), pad_hint(),
			font, font_size - 4, Palette.UI_DIM)
