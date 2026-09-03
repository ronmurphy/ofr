class_name InventoryPanel
extends Control

## Modal inventory: grouped, sorted, and filterable.
##
## Both input routes stay first class -- click a row, or press its letter.
## Crucially the letter comes from the ITEM, not from its position on screen,
## so sorting and filtering can rearrange the list freely without invalidating
## anything the player has memorised.

signal use_requested(index: int)
signal drop_requested(index: int)
signal merge_requested(index: int)
signal close_requested()

enum Filter { ALL, WEAPONS, ARMOUR, POTIONS, SCROLLS }

const FILTERS := [
	{"id": Filter.ALL,      "label": "all"},
	{"id": Filter.WEAPONS,  "label": "weapons"},
	{"id": Filter.ARMOUR,   "label": "armour"},
	{"id": Filter.POTIONS,  "label": "potions"},
	{"id": Filter.SCROLLS,  "label": "scrolls"},
]

const GROUPS := [
	[Filter.WEAPONS, "WEAPONS"],
	[Filter.ARMOUR,  "ARMOUR"],
	[Filter.POTIONS, "POTIONS"],
	[Filter.SCROLLS, "SCROLLS"],
]

@export var font: Font
@export var font_bold: Font
@export var font_size: int = 16

var state: GameState
var filter: int = Filter.ALL
var _hover_index := -1

const PANEL_W := 620.0
const PAD := 22.0
const ROW_H := 23.0
const HEAD_H := 30.0
const TOP := 100.0
const BOTTOM := 54.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	if font == null:
		font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
	if font_bold == null:
		font_bold = load("res://assets/fonts/JetBrainsMono-Bold.ttf")

func open() -> void:
	visible = true
	# Reset to ALL on open. A sticky filter means reopening later and finding
	# your potions "missing", which is a worse bug than an extra keystroke.
	filter = Filter.ALL
	_hover_index = -1
	queue_redraw()

func close() -> void:
	visible = false
	_hover_index = -1

func cycle_filter(step: int = 1) -> void:
	filter = wrapi(filter + step, 0, FILTERS.size())
	_hover_index = -1
	queue_redraw()

## Letter lookup runs against the pack, not the visible rows, so an item stays
## reachable by its letter even while filtered out of view.
func letter_to_index(key: int) -> int:
	if key < KEY_A or key > KEY_Z or state == null:
		return -1
	var ch := String.chr(key).to_lower()
	for i in state.player.inventory.size():
		if state.player.inventory[i].letter == ch:
			return i
	return -1

# ------------------------------------------------------------------ model ---

func _matches(item: Item, f: int) -> bool:
	match f:
		Filter.ALL:      return true
		Filter.WEAPONS:  return item.kind == Item.Kind.WEAPON
		Filter.ARMOUR:   return item.kind == Item.Kind.ARMOR
		Filter.POTIONS:  return item.kind == Item.Kind.POTION
		Filter.SCROLLS:  return item.kind == Item.Kind.SCROLL
	return true

## Best first, then alphabetical -- so deciding what to wear is a glance at the
## top of the group rather than a scan of the whole list.
func _sorted(entries: Array) -> Array:
	entries.sort_custom(func(a, b):
		var ia: Item = a["item"]
		var ib: Item = b["item"]
		var ba := ia.power_bonus + ia.defense_bonus
		var bb := ib.power_bonus + ib.defense_bonus
		if ba != bb:
			return ba > bb
		return ia.name < ib.name)
	return entries

func _build_rows() -> Array:
	var rows := []
	if state == null:
		return rows
	var entries := []
	for i in state.player.inventory.size():
		entries.append({"item": state.player.inventory[i], "index": i})

	if filter != Filter.ALL:
		for e in _sorted(entries.filter(func(e): return _matches(e["item"], filter))):
			rows.append(e)
		return rows

	var worn := entries.filter(func(e): return state.player.is_equipped(e["item"]))
	worn.sort_custom(func(a, b): return a["item"].slot < b["item"].slot)
	if not worn.is_empty():
		rows.append({"header": "EQUIPPED"})
		rows.append_array(worn)

	for group in GROUPS:
		var g: Array = entries.filter(func(e):
			return _matches(e["item"], group[0]) and not state.player.is_equipped(e["item"]))
		if g.is_empty():
			continue
		rows.append({"header": group[1]})
		rows.append_array(_sorted(g))
	return rows

# ----------------------------------------------------------------- layout ---

func _content_height() -> float:
	var h := 0.0
	for r in _build_rows():
		h += HEAD_H if r.has("header") else ROW_H
	return maxf(h, ROW_H)

func _panel_rect() -> Rect2:
	# Sized to its contents, so a pack holding two things is not a mostly
	# empty box.
	var h := clampf(TOP + _content_height() + BOTTOM, 240.0, size.y - 60.0)
	return Rect2((Vector2(size.x - PANEL_W, size.y - h) * 0.5).floor(),
		Vector2(PANEL_W, h))

func _row_rects() -> Array:
	var p := _panel_rect()
	var out := []
	var y := p.position.y + TOP
	for r in _build_rows():
		var h: float = HEAD_H if r.has("header") else ROW_H
		out.append({"row": r, "rect": Rect2(p.position.x + PAD, y, PANEL_W - PAD * 2.0, h)})
		y += h
	return out

func _chip_rects() -> Array:
	var p := _panel_rect()
	var out := []
	var x := p.position.x + PAD
	for f in FILTERS:
		var w := font.get_string_size(f["label"], HORIZONTAL_ALIGNMENT_LEFT,
			-1, font_size - 2).x + 20.0
		out.append({"id": f["id"], "label": f["label"],
			"rect": Rect2(x, p.position.y + PAD + 32.0, w, 25.0)})
		x += w + 6.0
	return out

# ------------------------------------------------------------------ input ---

func _gui_input(event: InputEvent) -> void:
	if state == null:
		return

	var motion := event as InputEventMouseMotion
	if motion != null:
		var idx := _index_at(motion.position)
		if idx != _hover_index:
			_hover_index = idx
			queue_redraw()
		return

	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return

	for chip in _chip_rects():
		if chip["rect"].has_point(click.position):
			filter = chip["id"]
			_hover_index = -1
			queue_redraw()
			return

	var hit := _index_at(click.position)
	if hit < 0:
		if not _panel_rect().has_point(click.position):
			close_requested.emit()
		return
	if click.button_index == MOUSE_BUTTON_LEFT:
		if click.shift_pressed:
			merge_requested.emit(hit)
		else:
			use_requested.emit(hit)
	elif click.button_index == MOUSE_BUTTON_RIGHT:
		drop_requested.emit(hit)

func _index_at(pos: Vector2) -> int:
	for entry in _row_rects():
		if entry["row"].has("header"):
			continue
		if entry["rect"].has_point(pos):
			return entry["row"]["index"]
	return -1

# ---------------------------------------------------------------- drawing ---

func _draw() -> void:
	if state == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.55), true)

	var p := _panel_rect()
	draw_rect(p, Palette.UI_PANEL_BG, true)
	draw_rect(p, Palette.UI_FRAME, false, 1.0)

	var asc := font.get_ascent(font_size)
	draw_string(font_bold, p.position + Vector2(PAD, PAD + asc), "INVENTORY",
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.STAIRS)
	# On the title's baseline and right-aligned, so it cannot collide with the
	# filter chips on the line below.
	draw_string(font, p.position + Vector2(PAD, PAD + asc),
		"%d / %d carried" % [state.player.inventory.size(), Entity.INVENTORY_MAX],
		HORIZONTAL_ALIGNMENT_RIGHT, PANEL_W - PAD * 2.0, font_size, Palette.UI_DIM)

	for chip in _chip_rects():
		_draw_chip(chip)

	var rows := _row_rects()
	if rows.is_empty():
		draw_string(font, Vector2(p.position.x + PAD, p.position.y + TOP + asc),
			"(nothing here)", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.UI_DIM)
	for entry in rows:
		if entry["row"].has("header"):
			_draw_header(entry["rect"], entry["row"]["header"])
		else:
			_draw_row(entry["rect"], entry["row"]["item"], entry["row"]["index"])

	# The forge line only appears where forging is possible, so it teaches the
	# mechanic exactly when it is relevant instead of being permanent clutter.
	var hint := "click use/equip  ·  right-click drop  ·  tab filter  ·  esc close"
	if state.can_forge_here():
		hint = "shift+click FORGE  ·  click use/equip  ·  right-click drop  ·  esc"
	var hs := font_size - 2
	while hs > 9 and font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hs).x \
			> PANEL_W - PAD * 2.0:
		hs -= 1
	draw_string(font, Vector2(p.position.x + PAD, p.end.y - PAD), hint,
		HORIZONTAL_ALIGNMENT_LEFT, -1, hs, Palette.UI_DIM)

func _draw_chip(chip: Dictionary) -> void:
	var active: bool = chip["id"] == filter
	var r: Rect2 = chip["rect"]
	draw_rect(r, Color(Palette.CURSOR, 0.18) if active else Color(1, 1, 1, 0.04), true)
	draw_rect(r, Palette.CURSOR if active else Palette.UI_FRAME, false, 1.0)
	draw_string(font, Vector2(r.position.x + 10.0,
		r.position.y + r.size.y * 0.5 + font.get_ascent(font_size - 2) * 0.5 - 2.0),
		chip["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 2,
		Palette.CURSOR if active else Palette.UI_DIM)

func _draw_header(r: Rect2, text: String) -> void:
	var y := r.position.y + HEAD_H - 7.0
	draw_string(font_bold, Vector2(r.position.x, y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 3, Palette.UI_DIM)
	var tw := font_bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		font_size - 3).x
	draw_line(Vector2(r.position.x + tw + 10.0, y - 4.0),
		Vector2(r.end.x, y - 4.0), Color(Palette.UI_FRAME, 0.7), 1.0)

func _draw_row(r: Rect2, item: Item, index: int) -> void:
	if index == _hover_index:
		draw_rect(r, Color(Palette.CURSOR, 0.13), true)

	var app: Dictionary = AsciiTheme.TABLE.get(item.appearance,
		{"ch": "?", "fg": Palette.UI_TEXT})
	var base := r.position + Vector2(0, font.get_ascent(font_size) + 2.0)
	var equipped: bool = state.player.is_equipped(item)
	var label := Palette.UI_TEXT
	if equipped:
		label = Palette.HP_GOOD
	elif index == _hover_index:
		label = Color.WHITE

	var tag := item.letter if item.letter != "" else "-"
	draw_string(font, base, "%s)" % tag,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.UI_DIM)
	draw_string(font, base + Vector2(34.0, 0.0), app["ch"],
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, app["fg"])
	draw_string(font, base + Vector2(60.0, 0.0), item.display_name(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, label)

	var status := item.bonus_text()
	if equipped:
		status = ("%s  ·  %s" % [status, item.equipped_text()]) if status != "" \
			else item.equipped_text()
	if status != "":
		draw_string(font, base, status, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x,
			font_size, Palette.HP_GOOD if equipped else Palette.UI_DIM)
