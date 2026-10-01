class_name MessageView
extends Control

@export var font: Font
@export var font_size: int = 15

var state: GameState

const PAD := 12.0
const LINE := 20.0
## A RULE AT THE LEFT OF EVERY LINE (the UI review, 2026-10-01), in the
## line's own colour and at full strength even when the words have faded: the
## kind of thing that happened -- a notice, a blow, a gain, a danger -- reads
## at the edge before the sentence is read. The newest line, when it is a
## danger, keeps a faint wash of its colour across the row, so "the red has
## laid claim to Wren" cannot be scrolled past unseen. The text moves right by
## the rule and its gap; the widest real line was measured at 891 px against
## the log's 964, and the test holds the line.
const RULE_W := 3.0
const RULE_GAP := 8.0
const DANGER_WASH := 0.09

## Red-dominant colours are the game's danger lines: you are hit, you die,
## the dead rise, the fungus bites. A notice is amber (its green is high)
## and is not one.
static func is_danger(c: Color) -> bool:
	return c.r >= 0.85 and c.g <= 0.5

## Where the words start, past the rule.
static func text_x() -> float:
	return PAD + RULE_W + RULE_GAP

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font == null:
		font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")

func _draw() -> void:
	if state == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Palette.UI_PANEL_BG, true)
	draw_rect(Rect2(Vector2.ZERO, size), Palette.UI_FRAME, false, 1.0)

	var rows := int((size.y - PAD * 2.0) / LINE)
	var entries := state.msg_log.tail(rows)
	var y := PAD + font.get_ascent(font_size)

	for i in entries.size():
		var e: Dictionary = entries[i]
		var text: String = e["text"]
		if e["count"] > 1:
			text += " (x%d)" % e["count"]
		# Older lines fade out, so the eye lands on what just happened.
		var age := float(entries.size() - 1 - i)
		var fade := clampf(1.0 - age * 0.14, 0.35, 1.0)
		var c: Color = e["color"]
		var top := y - font.get_ascent(font_size) + 1.0
		if i == entries.size() - 1 and is_danger(c):
			draw_rect(Rect2(Vector2(PAD, top), Vector2(size.x - PAD * 2.0, LINE - 2.0)),
				Color(c, DANGER_WASH), true)
		draw_rect(Rect2(Vector2(PAD, top), Vector2(RULE_W, LINE - 2.0)), Color(c, 0.9), true)
		draw_string(font, Vector2(text_x(), y), text, HORIZONTAL_ALIGNMENT_LEFT,
			size.x - text_x() - PAD, font_size, Color(c.r, c.g, c.b, fade))
		y += LINE
