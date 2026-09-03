class_name Sidebar
extends Control

## Character status, plus a look-panel describing whatever the mouse is over.
## Drawn by hand with the same font as the map so the whole screen reads as one
## surface rather than a game with a GUI bolted beside it.

@export var font: Font
@export var font_bold: Font
@export var font_size: int = 15

var state: GameState
var hovered := Vector2i(-1, -1)
var look_mode := false

const PAD := 14.0
const LINE := 21.0

const KEYS := [
	["arrows / hjklyubn", "move"],
	[". or 5", "wait"],
	[">", "descend"],
	["x", "look"],
	["g", "pick up"],
	["i", "inventory"],
	["click", "travel"],
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font == null:
		font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
	if font_bold == null:
		font_bold = load("res://assets/fonts/JetBrainsMono-Bold.ttf")

func _draw() -> void:
	if state == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Palette.UI_PANEL_BG, true)
	draw_rect(Rect2(Vector2.ZERO, size), Palette.UI_FRAME, false, 1.0)

	var y := PAD + font.get_ascent(font_size)

	_line(font_bold, y, "OFR", Palette.STAIRS)
	y += LINE
	_line(font, y, "depth %d    turn %d" % [state.depth, state.turns], Palette.UI_DIM)
	y += LINE * 1.6

	# Health bar. A bar plus the numbers -- the bar for the glance, the numbers
	# for the decision about whether one more fight is survivable.
	var p := state.player
	var frac := float(p.hp) / float(p.max_hp)
	var col := Palette.HP_GOOD
	if frac < 0.3:
		col = Palette.HP_BAD
	elif frac < 0.6:
		col = Palette.HP_WARN

	_line(font, y, "HP %d/%d" % [p.hp, p.max_hp], Palette.UI_TEXT)
	y += 8.0
	var bar_w := size.x - PAD * 2.0
	draw_rect(Rect2(Vector2(PAD, y), Vector2(bar_w, 10)), Color("1e1f26"), true)
	draw_rect(Rect2(Vector2(PAD, y), Vector2(bar_w * frac, 10)), col, true)
	draw_rect(Rect2(Vector2(PAD, y), Vector2(bar_w, 10)), Palette.UI_FRAME, false, 1.0)
	y += 10 + LINE

	_line(font, y, "power    %d" % p.power, Palette.UI_TEXT)
	y += LINE
	_line(font, y, "defense  %d" % p.defense, Palette.UI_TEXT)
	y += LINE * 1.8

	# Look panel. Retitled in look mode so it is obvious the keys are now
	# driving a cursor rather than the player.
	if look_mode:
		_line(font_bold, y, "LOOKING AT", Palette.CURSOR)
	else:
		_line(font_bold, y, "UNDER CURSOR", Palette.UI_DIM)
	y += LINE
	for text in _describe():
		_line(font, y, _fit(text), Palette.UI_TEXT)
		y += LINE

	y = size.y - PAD - LINE * 8.0
	_line(font_bold, y, "KEYS", Palette.UI_DIM)
	y += LINE
	for row in KEYS:
		_key_row(y, row[0], row[1])
		y += LINE

func _line(f: Font, y: float, text: String, color: Color) -> void:
	draw_string(f, Vector2(PAD, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

## Key on the left, action right-aligned against the frame.
##
## The previous version padded the gap with spaces, which is terminal thinking:
## it assumes a fixed panel width and silently pushes "inventory" through the
## edge the moment either string grows. Measured alignment cannot overflow.
func _key_row(y: float, key: String, action: String) -> void:
	draw_string(font, Vector2(PAD, y), key,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.UI_DIM)
	draw_string(font, Vector2(PAD, y), action,
		HORIZONTAL_ALIGNMENT_RIGHT, size.x - PAD * 2.0, font_size, Palette.UI_DIM)

## Same defence for the look panel, where a long item name would otherwise run
## through the frame.
func _fit(text: String) -> String:
	var limit := size.x - PAD * 2.0
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= limit:
		return text
	var out := text
	while out.length() > 1 and font.get_string_size(out + "..",
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > limit:
		out = out.substr(0, out.length() - 1)
	return out + ".."

func _describe() -> Array:
	var m := state.map
	if not m.in_bounds(hovered.x, hovered.y) or not m.is_explored(hovered.x, hovered.y):
		return ["unknown"]
	var out := []
	if m.is_visible(hovered.x, hovered.y):
		for e in state.entities:
			if e.alive and e.x == hovered.x and e.y == hovered.y:
				out.append("%s  %d/%d hp" % [e.name, e.hp, e.max_hp])
		for it in state.items_at(hovered.x, hovered.y):
			out.append(it.name)
	else:
		out.append("(remembered)")
	var tile := m.get_tile(hovered.x, hovered.y)
	out.append(String(Tiles.appearance_id(tile)).replace("_", " "))
	return out
