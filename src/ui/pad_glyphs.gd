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

## HOW BIG, derived from measurements rather than chosen by eye.
##
## The first version used 1.35x, a guess, and on the itch build every button
## came out as a DOT -- Brad's screenshot, 2026-09-24. The reason is in the two
## fonts' own numbers, read with fontTools:
##
##     Kenney button body     0.48 em tall, sitting ON the baseline,
##                            centred 0.24 em above it
##     JetBrainsMono capital  0.73 em
##
## So at 1.35x a button came out slightly SHORTER than a capital letter, and the
## letter printed inside the circle was far too small to read.
##
## Target: a button 1.4 capital letters tall. Big enough to read the letter in
## it, and still inside every line it is drawn on -- 17px on HERE's 24px line,
## 15px on the 21px lines of the sidebar and the legend.
const GLYPH_BODY_EM := 0.48
const GLYPH_CENTRE_EM := 0.24
const TEXT_CAP_EM := 0.73
const BUTTON_IN_CAPS := 1.4
const GLYPH_SCALE := BUTTON_IN_CAPS * TEXT_CAP_EM / GLYPH_BODY_EM

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
			# Centre the button's BODY on the middle of a capital letter.
			#
			# The first version lined up the two fonts' ascent values, which says
			# nothing about where Kenney actually put the picture: it sits on the
			# baseline and rises only 0.48 em, so the ascent is mostly empty air.
			# These are the measured centres, so the badge is optically level
			# with the words rather than hanging off their baseline.
			var drop := GLYPH_CENTRE_EM * gs - TEXT_CAP_EM * 0.5 * size
			canvas.draw_string(glyph_font(), Vector2(x, pos.y + drop), s,
				HORIZONTAL_ALIGNMENT_LEFT, -1, gs, color)
			x += glyph_font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, gs).x
		else:
			canvas.draw_string(text_font, Vector2(x, pos.y), s,
				HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
			x += text_font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return x - pos.x
