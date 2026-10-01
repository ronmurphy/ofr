class_name Keycap
extends RefCounted

## A key drawn as a key: a small cap round a letter, a chord or a pad button's
## picture, so the two devices read alike and "g" stops looking like a word
## in a sentence. First drawn in the HERE box (the UI review, 2026-10-01); the
## legend, the pause menu and the controller screen share it now, because
## three copies of a cap would be three caps that drift.
##
## Pictures go through PadGlyphs, as every pad glyph must -- a cap is sized
## by PadGlyphs.width and lettered by PadGlyphs.draw, so a button's picture
## and a letter take the same path.

const PAD_X := 6.0
const H := 20.0
const GAP := 4.0
const FILL := Color("181924")
const EDGE := Color("5a5866")

static func width(label: String, font: Font, size: int) -> float:
	return PadGlyphs.width(label, font, size) + PAD_X * 2.0

## The cap's box for a label whose text baseline is at `pos`.
static func rect(pos: Vector2, label: String, font: Font, size: int) -> Rect2:
	return Rect2(Vector2(pos.x, pos.y - H + 5.0), Vector2(width(label, font, size), H))

## One cap at `pos` (a text baseline). Dashed for a key that is not bound to
## anything -- an empty cap, drawn as one. Returns the width taken.
static func draw(canvas: CanvasItem, pos: Vector2, label: String, font: Font,
		size: int, colour: Color, dashed := false) -> float:
	var r := rect(pos, label, font, size)
	canvas.draw_rect(r, FILL, true)
	if dashed:
		var tl := r.position
		var tr := r.position + Vector2(r.size.x, 0.0)
		var bl := r.position + Vector2(0.0, r.size.y)
		canvas.draw_dashed_line(tl, tr, EDGE, 1.0, 3.0)
		canvas.draw_dashed_line(tr, r.end, EDGE, 1.0, 3.0)
		canvas.draw_dashed_line(bl, r.end, EDGE, 1.0, 3.0)
		canvas.draw_dashed_line(tl, bl, EDGE, 1.0, 3.0)
	else:
		canvas.draw_rect(r, EDGE, false, 1.0)
		# The lower edge drawn twice: a key has a bottom.
		canvas.draw_line(r.position + Vector2(0.0, r.size.y), r.end, EDGE, 2.0)
	PadGlyphs.draw(canvas, Vector2(pos.x + PAD_X, pos.y), label, font, size, colour)
	return r.size.x

## Several caps in a row, for a chord or a choice of keys. Returns the width.
static func row_width(labels: Array, font: Font, size: int) -> float:
	var w := 0.0
	for i in labels.size():
		w += width(String(labels[i]), font, size)
		if i > 0:
			w += GAP
	return w

static func draw_row(canvas: CanvasItem, pos: Vector2, labels: Array, font: Font,
		size: int, colour: Color) -> float:
	var x := pos.x
	for label in labels:
		x += draw(canvas, Vector2(x, pos.y), String(label), font, size, colour) + GAP
	return x - pos.x - (GAP if not labels.is_empty() else 0.0)
