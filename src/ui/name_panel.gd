class_name NamePanel
extends Control

## Who are you? Asked once, at the start of a run.
##
## A name is the only thing this game asks a player to invent, and it is asked
## for a mechanical reason rather than a decorative one: it goes on the morgue
## line, onto the gravestone a later run finds, and onto the skeleton that rises
## from it. A run that gives no name still gets one -- the dungeon rolls it, and
## you meet it above the HP bar.
##
## Escape or an empty return both mean "you choose for me", which is why there
## is no cancel button. There is no wrong way to leave this panel.

signal chosen(name: String)

const PAD := 18.0
const LINE := 22.0

@export var font: Font
@export var font_bold: Font
@export var font_size: int = 15

var typed := ""
## Drawn under the cursor so the field reads as something you can type into
## rather than a label that happens to change.
var _blink := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	if font == null:
		font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
	if font_bold == null:
		font_bold = load("res://assets/fonts/JetBrainsMono-Bold.ttf")
	set_process(false)

func open() -> void:
	typed = ""
	visible = true
	set_process(true)
	queue_redraw()

func close() -> void:
	visible = false
	set_process(false)

func _process(delta: float) -> void:
	_blink += delta
	if _blink > 0.5:
		_blink = 0.0
		queue_redraw()

## Returns true if the key was consumed.
##
## Takes the whole event rather than a keycode, because a name needs the typed
## CHARACTER -- keycodes cannot tell "a" from "A", and a player who capitalises
## their own name should get what they typed.
func handle_key(event: InputEventKey) -> bool:
	if not visible:
		return false
	match event.keycode:
		KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE:
			var out := Morgue.clean_name(typed)
			close()
			chosen.emit(out)
			return true
		KEY_BACKSPACE:
			if typed.length() > 0:
				typed = typed.substr(0, typed.length() - 1)
			queue_redraw()
			return true
	var ch := char(event.unicode)
	# Printable only. A tab or a control character in a name would survive into
	# the morgue file and come back as something nobody typed.
	if event.unicode >= 32 and event.unicode != 127 \
			and typed.length() < Morgue.NAME_MAX:
		typed += ch
		queue_redraw()
	return true

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.72), true)
	var w := 360.0
	var h := PAD * 2.0 + LINE * 4.0
	var box := Rect2(Vector2((size.x - w) * 0.5, (size.y - h) * 0.5), Vector2(w, h))
	draw_rect(box, Palette.UI_PANEL_BG, true)
	draw_rect(box, Palette.UI_FRAME, false, 1.0)

	var asc := font.get_ascent(font_size)
	var x := box.position.x + PAD
	var y := box.position.y + PAD + asc
	draw_string(font_bold, Vector2(x, y), "WHO GOES DOWN?",
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size + 1, Palette.STAIRS)
	y += LINE

	# The field, with a caret that blinks so it reads as editable.
	var shown := typed
	if _blink < 0.25:
		shown += "_"
	draw_string(font, Vector2(x, y), "> " + shown,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.UI_TEXT)
	y += LINE

	draw_string(font, Vector2(x, y), "enter to begin",
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 1, Palette.UI_DIM)
	y += LINE
	draw_string(font, Vector2(x, y), "leave it blank and the dungeon names you",
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 1, Palette.UI_DIM)
