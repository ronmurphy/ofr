class_name TalkPanel
extends Control

## Somebody in the dungeon is talking to you.
##
## Built for the trader, who is the only thing down here that says anything, but
## it knows nothing about traders -- it takes a list of lines and shows them one
## at a time. A line can carry a picture, and the picture appears BESIDE the
## words rather than behind or above them.
##
## Side by side, for a measured reason. The art is 720x720 and the game draws in
## a 1600x900 logical space (stretch/mode canvas_items, so every device gets the
## same coordinates). Stacking picture over text would leave 180px for the words
## and force the art down to about 0.9 scale; side by side, 720 + a 760-wide
## column fits in 1600 with room to spare and the picture is drawn at 1:1.
##
## That matters more than it sounds: the art is made of individual character
## glyphs, and any resampling softens exactly the detail that makes it work.
## The fallback below only ever shrinks, never enlarges.

signal finished()

@export var font: Font
@export var font_bold: Font
@export var font_size: int = 18

## One beat of a conversation: some words, and optionally a picture to show
## while they are said.
##
## `art` is a res:// path or "". A path that fails to load is not an error the
## player should ever see -- the line is simply shown on its own.
var beats: Array = []
var _at := 0
var _who := ""
var _art_cache: Dictionary = {}

const PAD := 40.0
const ART := 720.0
const GAP := 40.0
const LINE_H := 30.0
## Never drawn wider than this, however much room there is -- a line of prose
## 1500 pixels long is one your eye loses its place in.
const TEXT_MAX := 760.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	if font == null:
		font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
	if font_bold == null:
		font_bold = load("res://assets/fonts/JetBrainsMono-Bold.ttf")

func open(speaker: String, script: Array) -> void:
	_who = speaker
	beats = script
	_at = 0
	visible = true
	queue_redraw()

func close() -> void:
	visible = false
	beats = []
	_at = 0
	finished.emit()

## Anything that means "go on" advances a beat; escape leaves early.
##
## Escape is deliberately allowed even on the first beat. A player who has read
## this before, or who simply does not want it, should not have to press space
## eight times to get back to their game -- and the flag that decides whether it
## is shown at all is set when the conversation OPENS, not when it ends.
func handle_key(key: int) -> bool:
	if not visible:
		return false
	match key:
		KEY_ESCAPE:
			close()
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_PERIOD, KEY_RIGHT, KEY_DOWN:
			_advance()
		KEY_LEFT, KEY_UP, KEY_BACKSPACE:
			_at = maxi(0, _at - 1)
			queue_redraw()
		_:
			return false
	return true

func _advance() -> void:
	_at += 1
	if _at >= beats.size():
		close()
		return
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_advance()

func _art_for(path: String) -> Texture2D:
	if path == "":
		return null
	if _art_cache.has(path):
		return _art_cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_art_cache[path] = tex
	return tex

func _draw() -> void:
	if beats.is_empty() or _at >= beats.size():
		return
	var beat: Dictionary = beats[_at]
	var words := String(beat.get("text", ""))
	var tex := _art_for(String(beat.get("art", "")))

	# The whole screen goes dark. This is a conversation; nothing else on the
	# floor is happening while it runs.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.03, 0.93), true)

	var text_w: float = minf(TEXT_MAX, size.x - PAD * 2.0)
	var art_w := 0.0
	var scale := 1.0
	if tex != null:
		# Shrink only if it genuinely will not fit. Never enlarge: the picture
		# is drawn out of character glyphs and scaling up turns them to mush.
		var room_w: float = size.x - text_w - GAP - PAD * 2.0
		var room_h: float = size.y - PAD * 2.0
		scale = minf(1.0, minf(room_w / ART, room_h / ART))
		art_w = ART * scale

	var total := art_w + (GAP if art_w > 0.0 else 0.0) + text_w
	var left: float = floor((size.x - total) * 0.5)

	if tex != null:
		var art_h := ART * scale
		var art_at := Vector2(left, floor((size.y - art_h) * 0.5))
		draw_texture_rect(tex, Rect2(art_at, Vector2(art_w, art_h)), false)
		left += art_w + GAP

	# The words are laid out from the middle outwards so a one-line beat and an
	# eight-line beat both sit in the same place on screen, rather than the text
	# crawling up the panel as it gets longer.
	var lines := _wrap(words, text_w)
	var block_h := lines.size() * LINE_H
	var y: float = floor((size.y - block_h) * 0.5) + font.get_ascent(font_size)

	draw_string(font_bold, Vector2(left, y - LINE_H * 1.6), _who,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 2, Palette.TRADER)
	for line in lines:
		draw_string(font, Vector2(left, y), line,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.UI_TEXT)
		y += LINE_H

	var hint := "space  go on     esc  leave"
	if _at > 0:
		hint = "space  go on     backspace  back     esc  leave"
	draw_string(font, Vector2(left, size.y - PAD),
		"%s        %d / %d" % [hint, _at + 1, beats.size()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 5, Palette.UI_DIM)

## Greedy wrap on spaces, measured with the font that will draw it.
##
## Measured rather than counted in characters: the face is monospaced today, but
## a panel that only lays out correctly in a monospaced font is one that breaks
## silently the day somebody changes the face.
func _wrap(text: String, width: float) -> PackedStringArray:
	var out := PackedStringArray()
	for para in text.split("\n"):
		if para.strip_edges() == "":
			out.append("")
			continue
		var line := ""
		for word in para.split(" "):
			var trial: String = word if line == "" else line + " " + word
			if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1,
					font_size).x <= width:
				line = trial
			else:
				if line != "":
					out.append(line)
				line = word
		if line != "":
			out.append(line)
	return out
