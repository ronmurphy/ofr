class_name MessageView
extends Control

@export var font: Font
@export var font_size: int = 15

var state: GameState

const PAD := 12.0
const LINE := 20.0

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
		draw_string(font, Vector2(PAD, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size, Color(c.r, c.g, c.b, fade))
		y += LINE
