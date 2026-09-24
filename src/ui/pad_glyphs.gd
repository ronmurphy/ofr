class_name PadGlyphs
extends RefCounted

## Draws a line that mixes words with controller button pictures.
##
## THE BUTTON PICTURES ARE DRAWN FROM THEIR OWN FONT, DIRECTLY. Not through the
## text font's `fallbacks`, which would be one line of code and is the way this
## project has already been burned: the sidebar once reached its icons through
## a fallback, and on the itch web build every one of them came out as a tofu
## box spelling its own codepoint. Desktop resolved the fallback happily and
## the suite passed, so the only witness was somebody looking at the page.
##
## So a label is split into runs -- ordinary text, and button pictures -- and
## each run is drawn with the face that actually carries it, which is how the
## map, the legend and the pack have always drawn their icons.

static var _glyph_font: Font = null

static func glyph_font() -> Font:
	if _glyph_font == null:
		_glyph_font = load(PadConfig.GLYPH_FONT)
	return _glyph_font

## The picture is drawn a little LARGER than the words around it: Kenney drew
## these as badges with a margin inside the em square, and at text size an A
## button reads as a dot.
const GLYPH_SCALE := 1.35

## The line broken into [text, is_glyph] runs.
static func runs(text: String) -> Array:
	var out := []
	var cur := ""
	var cur_glyph := false
	for i in text.length():
		var cp := text.unicode_at(i)
		var g := PadConfig.is_glyph(cp)
		if cur != "" and g != cur_glyph:
			out.append([cur, cur_glyph])
			cur = ""
		cur += text[i]
		cur_glyph = g
	if cur != "":
		out.append([cur, cur_glyph])
	return out

static func width(text: String, text_font: Font, size: int) -> float:
	var w := 0.0
	for r in runs(text):
		if r[1]:
			w += glyph_font().get_string_size(String(r[0]), HORIZONTAL_ALIGNMENT_LEFT,
				-1, int(size * GLYPH_SCALE)).x
		else:
			w += text_font.get_string_size(String(r[0]), HORIZONTAL_ALIGNMENT_LEFT,
				-1, size).x
	return w

## Left-aligned at `pos` (a text baseline, as draw_string takes). Returns the
## width drawn, so a caller can carry on from the end of it.
static func draw(canvas: CanvasItem, pos: Vector2, text: String, text_font: Font,
		size: int, color: Color) -> float:
	var x := pos.x
	for r in runs(text):
		var s := String(r[0])
		if r[1]:
			var gs := int(size * GLYPH_SCALE)
			# Sit the badge on the text's centre line rather than its baseline,
			# or a larger glyph hangs below the words beside it.
			var lift := (glyph_font().get_ascent(gs) - text_font.get_ascent(size)) * 0.5
			canvas.draw_string(glyph_font(), Vector2(x, pos.y + lift), s,
				HORIZONTAL_ALIGNMENT_LEFT, -1, gs, color)
			x += glyph_font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, gs).x
		else:
			canvas.draw_string(text_font, Vector2(x, pos.y), s,
				HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
			x += text_font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return x - pos.x
