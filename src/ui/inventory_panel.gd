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
signal throw_requested(index: int)
signal bind_requested(index: int)
signal close_requested()

## Live bindings and which device the player last used, set by main.gd, so the
## footer names BUTTONS on a handheld. It said "shift+click a ● item to FORGE"
## on a Legion Go S, where there is no shift, no click and no letters.
var pad_cfg: PadConfig = null
var pad_input := false

## Keep existing IDs stable. AMULET is an all-view group without a filter chip,
## so cycle_filter follows FILTERS' explicit order rather than the enum values.
enum Filter { ALL, WEAPONS, ARMOUR, POTIONS, SCROLLS, GEMS, AMULET, UNIQUES }

const FILTERS := [
	{"id": Filter.ALL,      "label": "all"},
	{"id": Filter.WEAPONS,  "label": "weapons"},
	{"id": Filter.ARMOUR,   "label": "armour"},
	{"id": Filter.POTIONS,  "label": "food & potions"},
	{"id": Filter.SCROLLS,  "label": "scrolls"},
	{"id": Filter.GEMS,     "label": "gems"},
	{"id": Filter.UNIQUES,  "label": "uniques"},
]

## Every kind needs a group or its items are INVISIBLE -- the list is drawn by
## walking this, not by walking the pack, so an item belonging to none of these
## is carried and never shown. A gem was picked up and vanished for exactly
## this reason.
const GROUPS := [
	[Filter.WEAPONS, "WEAPONS"],
	[Filter.ARMOUR,  "ARMOUR"],
	[Filter.POTIONS, "FOOD & POTIONS"],
	[Filter.SCROLLS, "SCROLLS"],
	[Filter.GEMS,    "GEMS"],
	# The thing the whole game is about, and it was homeless until a test went
	# looking: Kind.AMULET belonged to no group, so the Amulet of the Deep was
	# carried and never shown in the pack. Found by the guard written for gems.
	[Filter.AMULET,  "AMULET"],
	# Uniques have their own group regardless of the Kind used for equip/use.
	[Filter.UNIQUES, "UNIQUES"],
]

@export var font: Font
@export var font_bold: Font
@export var font_size: int = 16

## The icon subset, for glyphs only. Text keeps the full font: this one
## carries ascii and the symbols the game draws and nothing else, so a
## message with an unexpected character in it would come out as tofu.
@export var icon_font: Font

var state: GameState
var filter: int = Filter.ALL
## Off-hand mode: the pack opens filtered to what can be hurled, and a choice
## here hands straight to the targeting cursor.
var throw_mode := false
## Setting a gem: the pack opens filtered to the weapons that will TAKE it, and
## a choice here is the weapon it goes into.
##
## The same shape as throw_mode above, deliberately. It answers the question
## binding could not before -- a player with a dagger and a short sword had the
## gem forced into whichever was in hand, and "logic says the sword but I want
## it in the dagger" had no way to be expressed.
var bind_mode := false
## Which gem is being placed, as an index into the pack.
var bind_gem := -1
var _hover_index := -1

## THE DETAIL PANE (the UI review, 2026-10-01): the list keeps its 576 px
## and a pane to its right says what the thing under the cursor IS and how it
## compares with what you have on -- "power 11 -> 8 (-3)", "frees the shield
## hand" -- so a swap is a decision made in the pack rather than discovered
## in a fight. Every line is fitted to DETAIL_W by measurement; the test runs
## the whole catalogue through it.
const LIST_W := 576.0
const DETAIL_W := 280.0
const PANEL_W := PAD * 3.0 + LIST_W + DETAIL_W
const PAD := 22.0
const ROW_H := 23.0
const HEAD_H := 30.0
const TOP := 100.0
const BOTTOM := 54.0
## A tighter gap keeps the longer food label and seventh tab inside the panel.
const CHIP_GAP := 4.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	if font == null:
		font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
	if icon_font == null:
		icon_font = load("res://assets/fonts/ofr_icons.ttf")
	if font_bold == null:
		font_bold = load("res://assets/fonts/JetBrainsMono-Bold.ttf")

func open_for_throw() -> void:
	throw_mode = true
	bind_mode = false
	visible = true
	filter = Filter.ALL
	_hover_index = -1
	queue_redraw()

func open_for_bind(gem_index: int) -> void:
	bind_mode = true
	bind_gem = gem_index
	throw_mode = false
	visible = true
	filter = Filter.ALL
	_hover_index = -1
	queue_redraw()

func open() -> void:
	throw_mode = false
	bind_mode = false
	bind_gem = -1
	visible = true
	# Reset to ALL on open. A sticky filter means reopening later and finding
	# your potions "missing", which is a worse bug than an extra keystroke.
	filter = Filter.ALL
	_hover_index = -1
	queue_redraw()

func close() -> void:
	visible = false
	throw_mode = false
	bind_mode = false
	bind_gem = -1
	_hover_index = -1

func cycle_filter(step: int = 1) -> void:
	var index: int = 0
	for i in FILTERS.size():
		if FILTERS[i]["id"] == filter:
			index = i
			break
	index = wrapi(index + step, 0, FILTERS.size())
	filter = FILTERS[index]["id"]
	_hover_index = -1
	queue_redraw()

## Letter lookup runs against the pack, not the visible rows, so an item stays
## reachable by its letter even while filtered out of view.
## Would this item accept the gem currently being placed?
func _takes_the_gem(it: Item) -> bool:
	if bind_gem < 0 or bind_gem >= state.player.inventory.size():
		return false
	var gem: Item = state.player.inventory[bind_gem]
	# The ring and a dull shovel take any stone as fuel (6c).
	return (it.element == &"" and it.accepts_element(gem.element)) or state.can_feed(it)

func letter_to_index(key: int) -> int:
	if key < KEY_A or key > KEY_Z or state == null:
		return -1
	var ch := String.chr(key).to_lower()
	for i in state.player.inventory.size():
		if state.player.inventory[i].letter == ch:
			return i
	return -1

# ------------------------------------------------------------------ model ---

## Uniques use their own shelf instead of also appearing under their Kind.
func _matches(item: Item, f: int) -> bool:
	match f:
		Filter.ALL:      return true
		Filter.UNIQUES:  return item.unique
		Filter.WEAPONS:  return not item.unique and item.kind == Item.Kind.WEAPON
		Filter.ARMOUR:   return not item.unique and item.kind == Item.Kind.ARMOR
		Filter.POTIONS:  return not item.unique and item.kind == Item.Kind.POTION
		Filter.SCROLLS:  return not item.unique and item.kind == Item.Kind.SCROLL
		Filter.GEMS:     return not item.unique and item.kind == Item.Kind.GEM
		Filter.AMULET:   return not item.unique and item.kind == Item.Kind.AMULET
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
		var it: Item = state.player.inventory[i]
		if throw_mode and not it.is_throwable():
			continue
		if bind_mode and not _takes_the_gem(it):
			continue
		entries.append({"item": it, "index": i})

	if throw_mode or bind_mode:
		return _sorted(entries)

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

## The filter chips are hidden when picking something to throw, so the space
## they would have taken is given back.
func _top_offset() -> float:
	return TOP - 30.0 if throw_mode else TOP

func _content_height() -> float:
	var h := 0.0
	for r in _build_rows():
		h += HEAD_H if r.has("header") else ROW_H
	return maxf(h, ROW_H)

func _panel_rect() -> Rect2:
	# Sized to its contents, so a pack holding two things is not a mostly
	# empty box.
	var h := clampf(_top_offset() + _content_height() + BOTTOM, 240.0, size.y - 60.0)
	return Rect2((Vector2(size.x - PANEL_W, size.y - h) * 0.5).floor(),
		Vector2(PANEL_W, h))

func _row_rects() -> Array:
	var p := _panel_rect()
	var out := []
	var y := p.position.y + _top_offset()
	for r in _build_rows():
		var h: float = HEAD_H if r.has("header") else ROW_H
		out.append({"row": r, "rect": Rect2(p.position.x + PAD, y, LIST_W, h)})
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
		x += w + CHIP_GAP
	return out

## The pane's box: right of the list, from the first row to the footer.
func detail_rect() -> Rect2:
	var p := _panel_rect()
	return Rect2(Vector2(p.position.x + PAD * 2.0 + LIST_W, p.position.y + _top_offset()),
		Vector2(DETAIL_W, p.size.y - _top_offset() - BOTTOM))

## What the pane describes: the highlighted row, else what is in your hand.
func detail_item() -> Item:
	var i := hovered()
	if i >= 0:
		return state.player.inventory[i]
	return state.player.equipped.get(Item.Slot.WEAPON, null)

func _fit_detail(text: String) -> String:
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= DETAIL_W:
		return text
	var out := text
	while out.length() > 1 and font.get_string_size(out + "..",
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > DETAIL_W:
		out = out.substr(0, out.length() - 1)
	return out + ".."

## "power  11 -> 8 (-3)", tinted by whether the change is for the better.
func _delta_line(label: String, old: int, new: int) -> Dictionary:
	var tint: Color = Palette.UI_DIM
	if new > old:
		tint = Palette.HP_GOOD
	elif new < old:
		tint = Palette.HP_BAD
	return {"text": "%s  %d -> %d (%+d)" % [label, old, new, new - old], "colour": tint}

## The pane's lines as {text, colour, bold}: the name, its facts, then how it
## stands against what is worn in the same place.
func detail_lines(item: Item) -> Array:
	var out := []
	out.append({"text": _fit_detail(item.display_name()), "colour": Palette.STAIRS, "bold": true})
	# bonus_text() already says reach, and reach is what takes both hands
	# (Item.is_two_handed), so the hands are said only in the comparison.
	var facts := item.bonus_text()
	if facts != "":
		out.append({"text": _fit_detail(facts), "colour": Palette.UI_TEXT})
	if item.uses_ammo():
		out.append({"text": "%d of %d arrows" % [item.ammo, item.ammo_max],
			"colour": Palette.UI_TEXT if item.ammo > 0 else Palette.HP_BAD})
	if item.element != &"" and item.kind != Item.Kind.GEM:
		out.append({"text": "%s set into it" % item.element, "colour": Palette.MAGIC})
	if item.transforms():
		out.append({"text": ("%d turns as a rat" % item.charges) if item.charges > 0
			else "cold: a gem at the embers", "colour": Palette.UI_TEXT})
	if item.dulls():
		out.append({"text": ("dull: a gem, or %d more graves" % (GameState.BURIALS_TO_SHARPEN
			- item.laid_to_rest)) if item.dull else "sharp: one raise",
			"colour": Palette.UI_TEXT})
	match item.effect:
		&"heal":
			out.append({"text": "restores %d hp" % item.effective_magnitude(), "colour": Palette.HP_GOOD})
		&"light":
			out.append({"text": "reveals, or relights a fire", "colour": Palette.UI_TEXT})
		&"blink":
			out.append({"text": "somewhere else, within %d" % item.magnitude, "colour": Palette.UI_TEXT})
		&"summon":
			out.append({"text": "calls a bone ally to you", "colour": Palette.UI_TEXT})
		&"raise_corpse":
			out.append({"text": "raises what you just killed", "colour": Palette.UI_TEXT})
		&"open_sack":
			out.append({"text": "open it to see what is in it", "colour": Palette.UI_TEXT})
	if item.is_equipment() and item.don_turns > 1:
		out.append({"text": "%d turns to get into" % item.don_turns, "colour": Palette.UI_DIM})
	if not item.is_equipment():
		return out
	var worn: Variant = state.player.equipped.get(item.slot, null)
	if worn == null or worn == item:
		return out
	out.append({"text": "", "colour": Palette.UI_DIM})
	out.append({"text": _fit_detail("against the %s" % worn.display_name()),
		"colour": Palette.UI_DIM, "bold": true})
	if item.slot == Item.Slot.WEAPON or worn.power_bonus != 0 or item.power_bonus != 0:
		out.append(_delta_line("power", worn.power_bonus, item.power_bonus))
	if item.slot != Item.Slot.WEAPON or worn.defense_bonus != 0 or item.defense_bonus != 0:
		out.append(_delta_line("defense", worn.defense_bonus, item.defense_bonus))
	if worn.range_bonus != item.range_bonus:
		out.append({"text": "reach  %d -> %d" % [worn.range_bonus, item.range_bonus],
			"colour": Palette.HP_GOOD if item.range_bonus > worn.range_bonus else Palette.HP_BAD})
	if worn.is_two_handed() and not item.is_two_handed():
		out.append({"text": "frees the shield hand", "colour": Palette.HP_GOOD})
	elif item.is_two_handed() and not worn.is_two_handed():
		out.append({"text": "needs both hands", "colour": Palette.HP_BAD})
	if worn.uses_ammo() and not item.uses_ammo():
		out.append({"text": "no arrows needed", "colour": Palette.HP_GOOD})
	elif item.uses_ammo() and not worn.uses_ammo():
		out.append({"text": "needs arrows", "colour": Palette.HP_BAD})
	if item.don_turns != worn.don_turns:
		out.append({"text": "%d turns to change" % item.don_turns, "colour": Palette.UI_DIM})
	return out

func _draw_detail() -> void:
	var r := detail_rect()
	# A hairline between the list and the pane.
	draw_line(Vector2(r.position.x - PAD * 0.5, r.position.y),
		Vector2(r.position.x - PAD * 0.5, r.end.y), Palette.UI_FRAME, 1.0)
	var asc := font.get_ascent(font_size)
	var y := r.position.y + asc + 2.0
	var item := detail_item()
	draw_string(font_bold, Vector2(r.position.x, y),
		"UNDER THE CURSOR" if hovered() >= 0 else "IN HAND",
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 4, Palette.UI_DIM)
	y += ROW_H
	if item == null:
		draw_string(font, Vector2(r.position.x, y), "nothing",
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.UI_DIM)
		return
	for line in detail_lines(item):
		if y > r.end.y:
			break
		if String(line["text"]) != "":
			draw_string(font_bold if bool(line.get("bold", false)) else font,
				Vector2(r.position.x, y), String(line["text"]),
				HORIZONTAL_ALIGNMENT_LEFT, DETAIL_W, font_size, line["colour"])
		y += ROW_H

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
	if throw_mode:
		if click.button_index == MOUSE_BUTTON_LEFT:
			throw_requested.emit(hit)
		return
	if bind_mode:
		if click.button_index == MOUSE_BUTTON_LEFT:
			bind_requested.emit(hit)
		return

	if click.button_index == MOUSE_BUTTON_LEFT:
		if click.shift_pressed:
			merge_requested.emit(hit)
		else:
			use_requested.emit(hit)
	elif click.button_index == MOUSE_BUTTON_RIGHT:
		drop_requested.emit(hit)

## The pack's footer for a keyboard and mouse.
func _keyboard_footer() -> String:
	if throw_mode:
		return "pick something to hurl  ·  click or press its letter  ·  esc cancel"
	if bind_mode:
		var g: String = "the gem"
		if bind_gem >= 0 and bind_gem < state.player.inventory.size():
			g = state.player.inventory[bind_gem].display_name()
		return "set %s into what?  ·  click or press its letter  ·  esc cancel" % g
	if state.can_forge_here():
		# Embers get their own line. The two costs are nothing alike -- one
		# spends hit points you can see on the bar, the other spends quiet --
		# and a player who read the first line would otherwise have no reason
		# to expect the second.
		if state.forging_in_embers():
			return "shift+click a ● item to FORGE in the embers  ·  loud, and final"
		return "shift+click or shift+letter a ● item to FORGE it  ·  click use  ·  esc"
	return "click use/equip  ·  right-click drop  ·  tab filter  ·  esc close"

## The pack's footer for a controller, named through the live bindings.
##
## Empty on a keyboard, where the long-standing lines below still apply. Split
## out so the suite can read the words a pad player is actually shown.
func footer() -> String:
	if not pad_input or pad_cfg == null:
		return ""
	var ok := pad_cfg.icon(KEY_PERIOD, true)
	var out := pad_cfg.icon(KEY_ESCAPE, true)
	var forge := pad_cfg.icon(MainScene.PACK_FORGE_KEY, true)
	if throw_mode:
		return "pick something to hurl  ·  %s throw  ·  %s cancel" % [
			ok, pad_cfg.icon(KEY_F, true)]
	if bind_mode:
		return "set it into which weapon?  ·  %s set  ·  %s cancel" % [ok, out]
	var back := pad_cfg.icon(MainScene.PACK_BACK_KEY, true)
	if state != null and state.forging_in_embers():
		return "%s forge a ● item in the embers  ·  loud, and final  ·  %s close" % [
			forge, back]
	# One line for the whole layout. The d-pad verbs are written as arrows
	# because that is what the player's thumb is on; the face buttons by name.
	return "%s use  ·  %s forge  ·  ▼ drop  ·  ► throw  ·  %s close" % [
		ok, forge, back]

## Every item index currently on screen, in the order they are drawn.
##
## Built from the same `_row_rects()` the mouse hit-tests against, so the
## highlight can never land somewhere the pointer could not, and a filter that
## hides a row hides it from both at once.
func selectable() -> Array[int]:
	var out: Array[int] = []
	for entry in _row_rects():
		var row: Dictionary = entry["row"]
		if row.has("header"):
			continue
		out.append(int(row["index"]))
	return out

## Moves the highlight, wrapping at both ends.
##
## From nowhere, down lands on the first row and up on the last, so the first
## press always goes somewhere predictable rather than depending on where a
## mouse was last left. The same rule the pause menu follows.
func move_hover(step: int) -> void:
	var rows := selectable()
	if rows.is_empty():
		_hover_index = -1
		return
	var at := rows.find(_hover_index)
	if at < 0:
		_hover_index = rows[0] if step > 0 else rows[-1]
	else:
		_hover_index = rows[posmod(at + step, rows.size())]
	queue_redraw()

## What the highlight is on, or -1.
## After an action, keep the highlight only if it still sits on the SAME KIND of
## thing.
##
## The highlight remembers a POSITION, not an item. Now that the pack stays open,
## drinking the last potion slides whatever was next into that slot -- often a
## scroll -- and the next press of confirm would read it. With another potion
## there, the highlight stays and "drink, drink" works as intended; with
## anything else there, it clears and the player has to choose again.
func settle_hover(prev_id: StringName) -> void:
	if _hover_index < 0 or state == null \
			or _hover_index >= state.player.inventory.size() \
			or state.player.inventory[_hover_index].id != prev_id:
		_hover_index = -1
	queue_redraw()

func hovered() -> int:
	return _hover_index if selectable().has(_hover_index) else -1

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
	draw_string(font_bold, p.position + Vector2(PAD, PAD + asc),
		"THROW WHAT?" if throw_mode else "INVENTORY",
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
		Palette.AIM_OK if throw_mode else Palette.STAIRS)
	# On the title's baseline and right-aligned, so it cannot collide with the
	# filter chips on the line below.
	draw_string(font, p.position + Vector2(PAD, PAD + asc),
		"%d / %d carried" % [state.player.inventory.size(), Entity.INVENTORY_MAX],
		HORIZONTAL_ALIGNMENT_RIGHT, PANEL_W - PAD * 2.0, font_size, Palette.UI_DIM)

	if not throw_mode:
		for chip in _chip_rects():
			_draw_chip(chip)

	var rows := _row_rects()
	if rows.is_empty():
		draw_string(font, Vector2(p.position.x + PAD, p.position.y + _top_offset() + asc),
			"(nothing to throw)" if throw_mode else "(nothing here)", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.UI_DIM)
	for entry in rows:
		if entry["row"].has("header"):
			_draw_header(entry["rect"], entry["row"]["header"])
		else:
			_draw_row(entry["rect"], entry["row"]["item"], entry["row"]["index"])
	_draw_detail()

	# The forge line only appears where forging is possible, so it teaches the
	# mechanic exactly when it is relevant instead of being permanent clutter.
	# A pad gets its own words (footer()); a keyboard keeps the long-standing
	# lines, which are right for a keyboard and wrong for anything else.
	var hint := footer()
	if hint == "":
		hint = _keyboard_footer()
	var hs := font_size - 2
	while hs > 9 and PadGlyphs.width(hint, font, hs) > PANEL_W - PAD * 2.0:
		hs -= 1
	PadGlyphs.draw(self, Vector2(p.position.x + PAD, p.end.y - PAD), hint, font,
		hs, Palette.UI_DIM)

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

## What clicking this row would do right now, named, or "" for the ordinary
## verbs the player already knows.
##
## Only the acts that are ambiguous or destructive get a line. "wield" on every
## sword would be noise; "bind -> dagger +2" is the one the player cannot work
## out from the row itself.
func _action_hint(item: Item) -> String:
	# The uniques that wait for a gem say so (6c).
	if item.transforms() and item.charges <= 0:
		return "cold: a gem at the embers"
	if item.dulls() and item.dull:
		# Both roads back (Gabe's graves, 2026-10-01).
		return "dull: a gem, or %d more graves" % (GameState.BURIALS_TO_SHARPEN
			- item.laid_to_rest)
	if item.kind == Item.Kind.GEM:
		# A gem with a use of its own, here and now, says so first (6d).
		if item.element == &"reflect" and state.mirror_target() >= 0:
			return "name the shrine"
		if item.element == &"crag" and state.crag_target().x >= 0:
			return "fill the pit"
		if item.element == &"block" and state.bulwark_target().x >= 0:
			return "bar the door"
		if item.element == &"return":
			match state.return_target():
				&"mark": return "mark this brazier"
				&"return": return "return to the fire"
		if item.element == &"travel" and not state.road_shown:
			return "show the way out"
		# A gem of fire beside a cold brazier relights it -- through G, not the
		# pack, which is why the pack has to say so (Brad, 2026-10-01: he stood
		# by the brazier with the gem and the pack said only "already set").
		# Only when the gem is what G would spend: a fire blade in hand goes
		# first, and the HERE box names that.
		if item.element == &"fire" and state._adjacent_cold_brazier().x >= 0 \
				and state._fire_to_give() == item:
			var g := pad_cfg.icon(KEY_G, true) if pad_input and pad_cfg != null else "g"
			return "%s: relight the brazier (%d)" % [g, GameState.GEM_KINDLE]
		if item.element == &"leech":
			var body := state.thirst_target()
			if not body.is_empty():
				return "drink the %s (+%d)" % [String(body["e"].get("name", body["app"])),
					state._thirst_heal(body)]
		# The host the GAME would choose (_gem_host), not the weapon in
		# hand. This used to look only at the weapon, from when every stone
		# went into a blade -- so a gem of the bulwark, which goes in a SHIELD,
		# told Brad "sling +2 (fire) is already set" with the buckler sitting
		# in his pack (2026-09-29).
		var blade: Variant = state._gem_host(item)
		if blade == null:
			return "needs %s" % Item.host_words(item.element)
		var feeding: bool = state.can_feed(blade)
		if blade.element != &"" and not feeding:
			return "%s is already set" % blade.display_name()
		if state._adjacent_embers().x >= 0:
			if feeding:
				return "feed the %s" % ("ring" if blade.transforms() else "shovel")
			return "set into %s" % blade.display_name()
		if state._adjacent_brazier().x >= 0:
			return "rake the fire down first"
		return "needs a guttering brazier"
	if state.can_forge_item(item):
		return "merge -> +%d" % (item.upgrade_level() + 1)
	return ""

func _draw_row(r: Rect2, item: Item, index: int) -> void:
	if index == _hover_index:
		draw_rect(r, Color(Palette.CURSOR, 0.13), true)

	var app: Dictionary = RenderTheme.active().appearance(item.appearance)
	var base := r.position + Vector2(0, font.get_ascent(font_size) + 2.0)
	var equipped: bool = state.player.is_equipped(item)
	var label := Palette.UI_TEXT
	if equipped:
		label = Palette.HP_GOOD
	elif index == _hover_index:
		label = Color.WHITE

	# A dot marks what can be forged right now, so the player does not have to
	# work out that the item to click is the one being IMPROVED, not the one
	# being consumed.
	if state.can_forge_item(item) \
			or (item.kind == Item.Kind.GEM and state.can_bind_gem(item)):
		draw_string(font, base - Vector2(14.0, 0.0), "●",
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 4, Palette.STAIRS)

	var tag := item.letter if item.letter != "" else "-"
	draw_string(font, base, "%s)" % tag,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.UI_DIM)
	var glyph_size := GlyphTheme.draw_size(app["ch"], font_size)
	var glyph_font := icon_font if GlyphTheme.is_icon(app["ch"]) else font
	draw_string(glyph_font, base + Vector2(34.0, (font_size - glyph_size) * 0.35),
		app["ch"], HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size,
		# Gems excluded: they carry an element as catalogue data and must keep
		# Palette.GEM. See the note in GlyphGrid's ground loop.
		Palette.MAGIC if item.shows_enchanted() else app["fg"])
	draw_string(font, base + Vector2(60.0, 0.0), item.display_name(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, label)

	var status := item.bonus_text()
	if equipped:
		status = ("%s  ·  %s" % [status, item.equipped_text()]) if status != "" \
			else item.equipped_text()
	# What the click will DO takes the right-hand slot when there is something
	# worth saying, and the stat line keeps it otherwise.
	#
	# The dot in the margin says only that something can happen here, which was
	# enough when one thing could. It now stands for two unrelated acts --
	# merging a twin and setting a gem -- and a player binding a gem has no way
	# to know WHICH weapon received it until the log scrolls, under a panel that
	# is covering the log. Brad set frost into a dagger +2, equipped a dagger +4
	# moments later, and fought a floor with the wrong blade.
	#
	# On the same line rather than a second one because `_hover_index` is set
	# by mouse motion alone: a hint shown only on the row under the cursor is
	# invisible to anyone playing by letter keys, which is half the players.
	var doing := _action_hint(item)
	if doing != "":
		draw_string(font, base, doing, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x,
			font_size - 2, Palette.STAIRS)
	elif status != "":
		draw_string(font, base, status, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x,
			font_size, Palette.HP_GOOD if equipped else Palette.UI_DIM)
