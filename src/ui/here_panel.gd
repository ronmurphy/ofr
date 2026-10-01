class_name HerePanel
extends Control

## WHAT YOU CAN DO ON THIS SQUARE, in the dead half of the message bar.
##
## It started in the sidebar, which was wrong for a measured reason: that panel
## is 256px wide, and "pick up the scroll of light" is 276px at the sidebar's
## font. It clipped mid-word and collided with the key label beside it. The fix
## is not shorter grammar -- it is Brad's observation that the message log spans
## 1568px and never uses half of it.
##
## Measured before moving: 147 message literals, median 36 characters, longest
## 65, and the worst realistic line with names substituted in is 891px. So the
## log keeps 964px, which it cannot overflow, and this takes the 588px to its
## right that had never held anything.
##
## SEPARATE FROM THE LOG rather than drawn inside it, because they answer
## different questions: the log is what just happened, this is what you can do
## next. Sharing a rectangle is a layout decision, not a reason to share a file.

@export var font: Font
@export var font_bold: Font
@export var font_size: int = 17

var state: GameState
## Live bindings and which device is in the player's hands, both set by main.gd
## so a label can read "B" on a handheld and "g" on a desk.
var pad_cfg: PadConfig = null
var pad_input := false
## Set while the targeting cursor or the look cursor is up, because then the
## keys genuinely mean something else -- and that is the moment a player is most
## likely to be lost.
var aiming := false
var look_mode := false

const PAD := 12.0
const LINE := 24.0
## The key column. Wide enough for the longest button name the pad table holds,
## measured rather than guessed: "D-pad down" at 17pt.
const KEY_COL := 132.0
## KEYCAPS (the UI review, 2026-10-01): the key column drawn as a key -- a
## small cap round the letter, the chord or the pad button's picture -- so
## the two devices read alike and "g" stops looking like a word in a sentence.
## The cap is sized to its label and the test holds the widest button name
## inside KEY_COL with its padding on.
const KEY_PAD := 6.0
const KEY_H := 20.0
const KEY_FILL := Color("181924")
const KEY_EDGE := Color("5a5866")

## The cap behind a key label whose baseline is at `y`.
func keycap_rect(y: float, label: String) -> Rect2:
	var w := PadGlyphs.width(label, font, font_size) + KEY_PAD * 2.0
	return Rect2(Vector2(PAD, y - KEY_H + 5.0), Vector2(w, KEY_H))

func _draw_keycap(y: float, label: String, colour: Color) -> void:
	var r := keycap_rect(y, label)
	draw_rect(r, KEY_FILL, true)
	draw_rect(r, KEY_EDGE, false, 1.0)
	# The lower edge drawn twice: a key has a bottom.
	draw_line(r.position + Vector2(0.0, r.size.y), r.end, KEY_EDGE, 2.0)
	PadGlyphs.draw(self, Vector2(PAD + KEY_PAD, y), label, font, font_size, colour)

## The status line's colour: what is hurting you, in its own colour.
func status_colour() -> Color:
	var line := status_line()
	if line.begins_with("poisoned") or line.begins_with("purple"):
		return Palette.FUNGUS_PURPLE
	if line.begins_with("red"):
		return Palette.FUNGUS_RED
	return Palette.BRAZIER

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font == null:
		font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
	if font_bold == null:
		font_bold = load("res://assets/fonts/JetBrainsMono-Bold.ttf")

## What to CALL the key that does this, in the language of whatever the player
## is holding.
##
## Reads the device the player last USED, not what is plugged in. The difference
## is a real player: a Steam Deck's pad is part of the hardware and permanently
## connected, so "is a controller present" would label this with buttons while
## somebody typed on a Bluetooth keyboard.
func press_name(key: int) -> String:
	if pad_cfg == null:
		return PadConfig.key_name(key)
	return pad_cfg.icon(key, pad_input)

## "wading -- every step costs 1.4 turns", or empty on firm ground.
func status_line() -> String:
	if state == null or state.game_over:
		return ""
	if state.player.poisoned > 0:
		return "poisoned -- 1 hp a turn, %d more turn%s" % [state.player.poisoned,
			"" if state.player.poisoned == 1 else "s"]
	var ground := state.map.get_tile(state.player.x, state.player.y)
	if Tiles.is_bad_fungus(ground):
		return "%s fungus -- it hurts to stand here" % ("purple"
			if ground == Tiles.FUNGUS_PURPLE else "red")
	var word := Tiles.footing_word(ground)
	if word == "":
		return ""
	return "%s -- every step costs %.1f turns" % [word, Tiles.move_cost(ground)]

## The rows to draw: what applies now, and always a way to the full list.
func rows() -> Array:
	var out := []
	if aiming:
		out.append([press_name(KEY_PERIOD), "shoot"])
		out.append([press_name(KEY_T) + " / " + press_name(KEY_P), "next target"])
		out.append([press_name(KEY_ESCAPE), "cancel"])
	elif look_mode:
		out.append(["move", "look around"])
		out.append([press_name(KEY_PERIOD), "done"])
	elif state != null:
		for row in state.actions_here():
			# A third element is the PAD's own route to the same action, for
			# the handful a controller cannot reach by the keyboard key --
			# restarting after death is the only one today.
			var key := int(row[0])
			if row.size() > 2 and pad_input and pad_cfg != null \
					and pad_cfg.button_for_key(int(row[2])) >= 0:
				key = int(row[2])
			out.append([press_name(key), String(row[1])])

	# Always reachable, always last. A player who is lost needs one thing on
	# screen that leads to everything else, and this panel can be empty.
	out.append([press_name(KEY_QUESTION), "every key"])
	return out

func _draw() -> void:
	if state == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Palette.UI_PANEL_BG, true)
	draw_rect(Rect2(Vector2.ZERO, size), Palette.UI_FRAME, false, 1.0)

	var y := PAD + font.get_ascent(font_size)
	draw_string(font_bold, Vector2(PAD, y), "HERE",
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 4, Palette.UI_DIM)
	# Slow ground, said where the player looks for what to do next -- the box
	# a fresh Legion player learned the game from. In the header line, which
	# has room to spare: the box fits four rows and a row here would push "?
	# every key" off the bottom.
	# As a chip beside the title, in the colour of what is wrong, so it reads
	# as a state rather than a sentence that happens to be up there.
	var status := status_line()
	if status != "":
		var colour := status_colour()
		var title_w := font_bold.get_string_size("HERE", HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size - 4).x
		var x := PAD + title_w + 12.0
		var room := size.x - PAD - x
		var w := minf(font.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size - 2).x + 12.0, room)
		var r := Rect2(Vector2(x, y - KEY_H + 5.0), Vector2(w, KEY_H))
		draw_rect(r, Color(colour, 0.10), true)
		draw_rect(r, Color(colour, 0.85), false, 1.0)
		draw_string(font, Vector2(x + 6.0, y - 1.0), status,
			HORIZONTAL_ALIGNMENT_LEFT, w - 12.0, font_size - 2, colour)
	y += LINE

	for row in rows():
		# Through PadGlyphs, because on a pad this column is a PICTURE of the
		# button drawn from its own font -- see pad_glyphs.gd for why that must
		# not be left to the text font's fallbacks.
		_draw_keycap(y, String(row[0]), Palette.STAIRS)
		draw_string(font, Vector2(PAD + KEY_COL, y), String(row[1]),
			HORIZONTAL_ALIGNMENT_LEFT, size.x - PAD * 2.0 - KEY_COL,
			font_size, Palette.UI_TEXT)
		y += LINE
