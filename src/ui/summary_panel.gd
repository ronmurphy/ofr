class_name SummaryPanel
extends Control

## The record of a finished run.
##
## Shown when the run ends, either way. It exists because everything on it was
## already being computed and then thrown away: the morgue got one line, and
## the player got "You die."
##
## THE RULE HERE IS THAT IT SKIPS WHAT IT DOES NOT KNOW. A run carried over
## from a save written before the recorder existed has no counters, and this
## draws the sections it can fill and silently drops the rest, rather than
## reporting a confident zero about a run nobody was counting. That is why the
## whole thing is built from `_rows()` returning a list rather than from a
## fixed layout -- a missing section closes up instead of leaving a hole.

signal close_requested()

@export var font: Font
@export var font_bold: Font
@export var font_size: int = 16

## The exported default, reachable without a node -- the overflow test needs
## the size the panel actually draws at, and an @export is not a constant.
static func font_size_default() -> int:
	return 16

var state: GameState

## Width is fixed; height is not. The record's length depends on the run --
## three superlative lists or none, gear or none -- and a fixed box either
## wastes half a screen on a short run or, as the first draft did, spills the
## deeds column straight through the footer on a long one.
const PANEL_W := 720.0
const PANEL_MIN_H := 320.0
const FOOTER_H := 46.0
const HEADER_H := 44.0
const PAD := 30.0
const LINE := 23.0
const HEAD_GAP := 10.0
## How many entries a "most often" list shows. Three is enough to have a shape
## and few enough that nobody reads it as a table.
const TOP_N := 3

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	if font == null:
		font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
	if font_bold == null:
		font_bold = load("res://assets/fonts/JetBrainsMono-Bold.ttf")

func open() -> void:
	visible = true
	queue_redraw()

func close() -> void:
	visible = false

func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed:
		close_requested.emit()

func _panel_size() -> Vector2:
	var tall := maxf(_column_height(_rows()), _column_height(_deeds()))
	var h := clampf(PAD * 2.0 + HEADER_H + tall + FOOTER_H,
		PANEL_MIN_H, maxf(PANEL_MIN_H, size.y - 40.0))
	return Vector2(PANEL_W, ceilf(h))

func _column_height(rows: Array) -> float:
	var h := 0.0
	for row in rows:
		h += HEAD_GAP if row[0] == "gap" else LINE
	return h

func _panel_rect() -> Rect2:
	var p := _panel_size()
	return Rect2(((size - p) * 0.5).floor(), p)

## The headline: what happened, in the same words the morgue uses.
func _fate() -> String:
	if state.won:
		return "ESCAPED WITH THE AMULET OF THE DEEP"
	if state.death_cause != "":
		return "%s ON DEPTH %d" % [state.death_cause.to_upper(), state.depth]
	return "LEFT THE DUNGEON ON DEPTH %d" % state.depth

## Every row the panel wants to draw, as ["head"|"row"|"gap", a, b].
##
## Built rather than laid out, so a section with nothing to say costs no space.
func _rows() -> Array:
	var out: Array = []
	var s: Dictionary = state.stats

	out.append(["head", "THE RUN", ""])
	# Approximate when the save predates the elapsed counter -- flagged with a
	# tilde rather than quietly presented as measured.
	var mark := "~" if state.elapsed_estimated else ""
	out.append(["row", "time underground", mark + Clock.text(state.time_underground())])
	out.append(["row", "turns taken", str(state.turns)])
	if s.has("deepest"):
		out.append(["row", "deepest floor", str(int(s["deepest"]))])

	out.append(["gap", "", ""])
	out.append(["head", "THE CHARACTER", ""])
	out.append(["row", "level", str(state.player.level)])
	out.append(["row", "power", str(state.player.total_power())])
	out.append(["row", "defense", str(state.player.total_defense())])
	out.append(["row", "hit points", "%d / %d" % [state.player.hp, state.player.max_hp]])

	var worn := _carried()
	if not worn.is_empty():
		out.append(["gap", "", ""])
		out.append(["head", "IN HAND", ""])
		for w in worn:
			out.append(["row", w, ""])
	return out

## The second column: what the run actually did. Empty entirely on a save that
## predates the recorder, and the column simply does not appear.
func _deeds() -> Array:
	var out: Array = []
	var s: Dictionary = state.stats
	if s.is_empty():
		return out

	var killed := _bucket_total(s, "kills")
	out.append(["head", "WHAT YOU DID", ""])
	if killed > 0:
		out.append(["row", "things killed", str(killed)])
	if s.has("dealt"):
		out.append(["row", "damage dealt", str(int(s["dealt"]))])
	if s.has("taken"):
		out.append(["row", "damage taken", str(int(s["taken"]))])
	if s.has("shots"):
		out.append(["row", "shots loosed", str(int(s["shots"]))])
	if s.has("braziers"):
		out.append(["row", "braziers burned out", str(int(s["braziers"]))])
	if s.has("forges"):
		out.append(["row", "things forged", str(int(s["forges"]))])
	# Its own row rather than a parenthetical on the one above. As "9 (3 in
	# embers)" it was the widest value on the panel by a margin and left no gap
	# against a long label.
	if s.has("ember_forges"):
		out.append(["row", "forged in embers", str(int(s["ember_forges"]))])

	var supers: Array = []
	for pair in [["kills", "killed most"], ["swings", "swung most"],
			["picked", "gathered most"]]:
		var top := _top(s, pair[0])
		if not top.is_empty():
			supers.append([pair[1], top])
	if not supers.is_empty():
		out.append(["gap", "", ""])
		out.append(["head", "MOST OFTEN", ""])
		for sup in supers:
			out.append(["row", sup[0], ""])
			for entry in sup[1]:
				out.append(["row", "   " + String(entry[0]), str(int(entry[1]))])
	return out

func _carried() -> Array:
	var out: Array = []
	if state.player == null:
		return out
	for slot in state.player.equipped:
		out.append(state.player.equipped[slot].display_name())
	out.sort()
	return out

func _bucket_total(s: Dictionary, key: String) -> int:
	if not s.has(key) or not (s[key] is Dictionary):
		return 0
	var n := 0
	for k in s[key]:
		n += int(s[key][k])
	return n

## The TOP_N entries of a bucket, biggest first.
func _top(s: Dictionary, key: String) -> Array:
	if not s.has(key) or not (s[key] is Dictionary):
		return []
	var pairs: Array = []
	for k in s[key]:
		pairs.append([String(k), int(s[key][k])])
	pairs.sort_custom(func(a, b): return a[1] > b[1])
	return pairs.slice(0, TOP_N)

func _draw() -> void:
	if state == null or font == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.72), true)
	var p := _panel_rect()
	draw_rect(p, Palette.UI_PANEL_BG, true)
	draw_rect(p, Palette.UI_FRAME, false, 1.0)

	var asc := font.get_ascent(font_size)
	draw_string(font_bold, p.position + Vector2(PAD, PAD + asc), _fate(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
		Palette.AMULET if state.won else Palette.HP_BAD)

	var col_w := (PANEL_W - PAD * 3.0) * 0.5
	# Two columns, drawn independently so neither has to know how tall the
	# other came out.
	_column(_rows(), p.position + Vector2(PAD, PAD + HEADER_H), col_w)
	_column(_deeds(), p.position + Vector2(PAD * 2.0 + col_w, PAD + HEADER_H), col_w)

	draw_string(font, Vector2(p.position.x + PAD, p.end.y - PAD),
		"esc or click to close  ·  tab to show it again  ·  r to descend anew",
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 4, Palette.UI_DIM)

func _column(rows: Array, at: Vector2, w: float) -> void:
	var y := at.y
	for row in rows:
		match row[0]:
			"gap":
				y += HEAD_GAP
			"head":
				draw_string(font_bold, Vector2(at.x, y + font.get_ascent(font_size - 3)),
					row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 3, Palette.UI_DIM)
				y += LINE
			_:
				var base := Vector2(at.x, y + font.get_ascent(font_size - 1))
				draw_string(font, base, row[1], HORIZONTAL_ALIGNMENT_LEFT, -1,
					font_size - 1, Palette.UI_TEXT)
				if row[2] != "":
					draw_string(font, base, row[2], HORIZONTAL_ALIGNMENT_RIGHT,
						w, font_size - 1, Palette.STAIRS)
				y += LINE
