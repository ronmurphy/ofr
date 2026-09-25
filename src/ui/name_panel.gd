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
##
## THREE WAYS IN, one field. A keyboard types, exactly as it always has. A pad
## could not -- it sends no characters, so until 2026-09-25 every controller
## player was named by the dungeon (Brad on the Legion, Steph on her Deck). So
## under the field sit the dungeon's own names to pick from, and an alphabet to
## spell one with, walked by the d-pad or the stick the way consoles always did
## it. A mouse can click either.

signal chosen(name: String)

const PAD := 20.0
const LINE := 24.0
const BOX_W := 600.0
## One grid cell's height, and the gap between cells.
const CELL_H := 30.0
const GAP := 6.0
const NAMES_PER_ROW := 6
const LETTERS_PER_ROW := 10

## The alphabet a pad can spell with. Lower case comes from the case toggle.
## Only characters a name may hold -- `Morgue.clean_name` strips ";" and line
## breaks, and none of these is either.
const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ -'"

## The controls under the alphabet.
const CONTROLS := [&"case", &"erase", &"begin"]
const CONTROL_LABELS := {&"case": "a / A", &"erase": "erase", &"begin": "begin"}

@export var font: Font
@export var font_bold: Font
@export var font_size: int = 15

## Live bindings and the device last used, set by main.gd, so the footer can
## name buttons on a handheld.
var pad_cfg: PadConfig = null
var pad_input := false

var typed := ""
## The grid cursor, as (row, column). Rows: the names, then the alphabet, then
## the controls -- one grid, so the d-pad walks straight from a name to a letter.
var at := Vector2i.ZERO
## Upper case. Set for the first letter of a name and cleared after it, the way
## a phone does it; the case control flips it by hand.
var upper := true
## Whether the cursor is drawn. A keyboard player types and never needs it; it
## appears the moment a pad or the pointer is used.
var _show_cursor := false
## Drawn under the cursor so the field reads as something you can type into
## rather than a label that happens to change.
var _blink := 0.0

func _ready() -> void:
	# STOP, not IGNORE: the grid is clickable now.
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	if font == null:
		font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
	if font_bold == null:
		font_bold = load("res://assets/fonts/JetBrainsMono-Bold.ttf")
	set_process(false)

func open() -> void:
	typed = ""
	upper = true
	at = Vector2i.ZERO
	_show_cursor = false
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

# ------------------------------------------------------------------- grid ---

## The names on offer: the dungeon's own, never the rare ones. Erdrick, Rodney
## and Yendor are found, not chosen -- a secret on a menu is not a secret.
static func names() -> Array:
	return Morgue.ROLLED.duplicate()

## Every row of the grid, as a list of cells. A cell is {kind, value}.
func rows() -> Array:
	var out := []
	var list := names()
	for start in range(0, list.size(), NAMES_PER_ROW):
		var row := []
		for i in range(start, mini(start + NAMES_PER_ROW, list.size())):
			row.append({"kind": &"name", "value": list[i]})
		out.append(row)
	for start in range(0, LETTERS.length(), LETTERS_PER_ROW):
		var row := []
		for i in range(start, mini(start + LETTERS_PER_ROW, LETTERS.length())):
			row.append({"kind": &"letter", "value": LETTERS[i]})
		out.append(row)
	var controls := []
	for c in CONTROLS:
		controls.append({"kind": &"control", "value": c})
	out.append(controls)
	return out

func cell_at(p: Vector2i) -> Dictionary:
	var all := rows()
	if p.y < 0 or p.y >= all.size():
		return {}
	var row: Array = all[p.y]
	if p.x < 0 or p.x >= row.size():
		return {}
	return row[p.x]

## Where the grid starts: under the title, the field and the list heading.
func _box() -> Rect2:
	var h := PAD * 2.0 + LINE * 4.0 + _grid_height() + LINE * 2.0
	return Rect2(((size - Vector2(BOX_W, h)) * 0.5).floor(), Vector2(BOX_W, h))

func _grid_height() -> float:
	return float(rows().size()) * (CELL_H + GAP) + LINE

## A cell's rectangle, shared by drawing and clicking so the two cannot drift.
## The names, the alphabet and the controls each fill the full width, so a row
## of six names and a row of ten letters line up edge to edge.
func cell_rect(p: Vector2i) -> Rect2:
	var all := rows()
	var box := _box()
	var inner := BOX_W - PAD * 2.0
	var y := box.position.y + PAD + LINE * 3.5
	var name_rows := ceili(float(names().size()) / float(NAMES_PER_ROW))
	for r in p.y:
		y += CELL_H + GAP
		# A breath between the names and the alphabet, where the second
		# heading sits.
		if r == name_rows - 1:
			y += LINE
	var row: Array = all[p.y]
	var per := NAMES_PER_ROW if p.y < name_rows \
		else (CONTROLS.size() if p.y == all.size() - 1 else LETTERS_PER_ROW)
	var w := (inner - GAP * float(per - 1)) / float(per)
	var x := box.position.x + PAD + float(p.x) * (w + GAP)
	if p.x >= row.size():
		return Rect2()
	return Rect2(Vector2(x, y), Vector2(w, CELL_H))

func _hit(pos: Vector2) -> Vector2i:
	var all := rows()
	for r in all.size():
		for c in (all[r] as Array).size():
			if cell_rect(Vector2i(c, r)).has_point(pos):
				return Vector2i(c, r)
	return Vector2i(-1, -1)

## The cursor moves. Left/right wrap within a row; up/down land on whichever
## cell of the next row sits closest under the current one, since rows hold
## different numbers of cells.
func move(dir: Vector2i) -> void:
	var all := rows()
	_show_cursor = true
	if dir.x != 0:
		var n := (all[at.y] as Array).size()
		at.x = posmod(at.x + dir.x, n)
	elif dir.y != 0:
		var here := cell_rect(at).get_center().x
		var r := posmod(at.y + dir.y, all.size())
		var best := 0
		var best_d := INF
		for c in (all[r] as Array).size():
			var d := absf(cell_rect(Vector2i(c, r)).get_center().x - here)
			if d < best_d:
				best_d = d
				best = c
		at = Vector2i(best, r)
	queue_redraw()

## A on the highlighted cell, or a click on it.
func press() -> void:
	var cell := cell_at(at)
	if cell.is_empty():
		return
	match StringName(cell["kind"]):
		&"name":
			typed = String(cell["value"])
			# Straight to "begin": a name was chosen, and the next A starts.
			at = Vector2i(CONTROLS.find(&"begin"), rows().size() - 1)
		&"letter":
			_add(String(cell["value"]))
		&"control":
			match StringName(cell["value"]):
				&"case":
					upper = not upper
				&"erase":
					erase()
				&"begin":
					begin()
					return
	queue_redraw()

func _add(ch: String) -> void:
	if typed.length() >= Morgue.NAME_MAX:
		return
	typed += ch.to_upper() if upper else ch.to_lower()
	# A capital to start a name, then small letters, as a phone does.
	upper = false

func erase() -> void:
	if typed.length() > 0:
		typed = typed.substr(0, typed.length() - 1)
	upper = typed.is_empty()
	queue_redraw()

func begin() -> void:
	var out := Morgue.clean_name(typed)
	close()
	chosen.emit(out)

# ------------------------------------------------------------------ input ---

## What a pad press means here, read from the live bindings so a rebound
## button still does its job: the d-pad and stick move, A presses, B erases,
## Y flips the case, Start begins. Everything else means nothing.
static func pad_action(cfg: PadConfig, key: int) -> StringName:
	# The stick is not bound -- it arrives as the arrows.
	match key:
		KEY_UP:
			return &"up"
		KEY_DOWN:
			return &"down"
		KEY_LEFT:
			return &"left"
		KEY_RIGHT:
			return &"right"
	if cfg == null:
		return &""
	match cfg.button_for_key(key):
		JOY_BUTTON_DPAD_UP:
			return &"up"
		JOY_BUTTON_DPAD_DOWN:
			return &"down"
		JOY_BUTTON_DPAD_LEFT:
			return &"left"
		JOY_BUTTON_DPAD_RIGHT:
			return &"right"
		JOY_BUTTON_A:
			return &"press"
		JOY_BUTTON_B:
			return &"erase"
		JOY_BUTTON_Y:
			return &"case"
		JOY_BUTTON_START:
			return &"begin"
	return &""

## A pad press, as the meaning `pad_action` gave it.
func pad_act(action: StringName) -> void:
	if not visible:
		return
	match action:
		&"up":
			move(Vector2i.UP)
		&"down":
			move(Vector2i.DOWN)
		&"left":
			move(Vector2i.LEFT)
		&"right":
			move(Vector2i.RIGHT)
		&"press":
			_show_cursor = true
			press()
		&"erase":
			erase()
		&"case":
			upper = not upper
			queue_redraw()
		&"begin":
			begin()

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
			begin()
			return true
		KEY_BACKSPACE:
			erase()
			return true
	var ch := char(event.unicode)
	# Printable only. A tab or a control character in a name would survive into
	# the morgue file and come back as something nobody typed.
	if event.unicode >= 32 and event.unicode != 127 \
			and typed.length() < Morgue.NAME_MAX:
		typed += ch
		upper = false
		queue_redraw()
	return true

## The pointer: hover moves the cursor, a click presses. Outside the grid it
## does nothing -- there is no wrong way to leave, and no way to leave by
## accident either.
func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		var hit := _hit(motion.position)
		if hit.x >= 0 and (hit != at or not _show_cursor):
			at = hit
			_show_cursor = true
			queue_redraw()
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var hit := _hit(click.position)
	if hit.x >= 0:
		at = hit
		_show_cursor = true
		press()
		if is_inside_tree():
			accept_event()

## The footer, in the language of whatever the player is holding.
func footer() -> String:
	if pad_input and pad_cfg != null:
		return "%s choose  ·  %s erase  ·  %s a / A  ·  %s begin" % [
			pad_cfg.icon(pad_cfg.key_for_button(JOY_BUTTON_A), true),
			pad_cfg.icon(pad_cfg.key_for_button(JOY_BUTTON_B), true),
			pad_cfg.icon(pad_cfg.key_for_button(JOY_BUTTON_Y), true),
			pad_cfg.icon(pad_cfg.key_for_button(JOY_BUTTON_START), true)]
	return "type a name, or click one  ·  enter to begin"

# ------------------------------------------------------------------- draw ---

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.72), true)
	var box := _box()
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
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size + 1, Palette.UI_TEXT)
	y += LINE
	draw_string(font, Vector2(x, y), "leave it blank and the dungeon names you",
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 2, Palette.UI_DIM)

	# Headings sit just above their first row.
	var name_rows := ceili(float(names().size()) / float(NAMES_PER_ROW))
	draw_string(font_bold, Vector2(x, cell_rect(Vector2i(0, 0)).position.y - 8.0),
		"A NAME THE DUNGEON KNOWS", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 3,
		Palette.UI_DIM)
	draw_string(font_bold, Vector2(x, cell_rect(Vector2i(0, name_rows)).position.y - 8.0),
		"OR SPELL YOUR OWN", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 3,
		Palette.UI_DIM)

	var all := rows()
	for r in all.size():
		for c in (all[r] as Array).size():
			_draw_cell(Vector2i(c, r), all[r][c])

	var hint := footer()
	var hs := font_size - 2
	while hs > 9 and PadGlyphs.width(hint, font, hs) > BOX_W - PAD * 2.0:
		hs -= 1
	PadGlyphs.draw(self, Vector2(x, box.end.y - PAD), hint, font, hs, Palette.UI_DIM)

func _draw_cell(p: Vector2i, cell: Dictionary) -> void:
	var r := cell_rect(p)
	var lit := _show_cursor and p == at
	draw_rect(r, Color(Palette.CURSOR, 0.20) if lit else Color(1, 1, 1, 0.04), true)
	draw_rect(r, Palette.CURSOR if lit else Palette.UI_FRAME, false, 1.0)
	var label := ""
	var tone := Palette.UI_TEXT
	match StringName(cell["kind"]):
		&"name":
			label = String(cell["value"])
		&"letter":
			label = String(cell["value"])
			label = label.to_upper() if upper else label.to_lower()
			if label == " ":
				label = "space"
		&"control":
			label = String(CONTROL_LABELS[cell["value"]])
			if StringName(cell["value"]) == &"begin":
				tone = Palette.STAIRS
	var fs := font_size if label.length() > 1 else font_size + 2
	if label == "space":
		fs = font_size - 3
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(r.position.x + (r.size.x - tw) * 0.5,
		r.position.y + r.size.y * 0.5 + font.get_ascent(fs) * 0.5 - 2.0),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
		Palette.CURSOR if lit else tone)
