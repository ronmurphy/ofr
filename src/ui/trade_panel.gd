class_name TradePanel
extends Control

## The trader's counter: your pack on the left, the trader's shelf on the right.
##
## BUILT FOR A CONTROLLER FROM THE FIRST LINE. Every controller bug this week
## came from a screen built for the keyboard and fixed afterwards -- the stairs,
## the missile confirm, restarting, forging, and a pack where a pad press used
## whatever item wore that button's letter. So this screen has no letter
## shortcuts at all: the stick moves, A acts on what is highlighted, Y asks for
## the enchant roll, and left/right changes side. A keyboard does the same with
## the arrows, enter and x.
##
## The rules live in GameState (the counter's state) and Trade (the prices).
## This only draws them and turns a press into one of four calls.

signal closed()

@export var font: Font
@export var font_bold: Font
@export var font_size: int = 17

var state: GameState
## Live bindings and which device the player last used, set by main.gd, so the
## footer names BUTTONS on a handheld.
var pad_cfg: PadConfig = null
var pad_input := false

const PANEL := Vector2(1120.0, 700.0)
const PAD := 26.0
const LINE := 24.0
## Rows shown per column before it scrolls. Selling puts things ON the shelf,
## so the trader's side has no fixed length and has to scroll.
const ROWS := 20
const COL_GAP := 40.0

const PACK := 0
const SHELF := 1
## The last row on the shelf is not an item: it trades three gems for one of your choice.
const GEM_ROW := -1

## The movement keys a roguelike player already has under their fingers --
## vi-keys and the numpad -- read as the arrows. The first version answered only
## to the arrows, which is a controller-and-casual assumption; the people most
## likely to play this with a keyboard are the ones with hjkl in their hands.
## A pad never reaches these: main.gd refuses its letters before this panel.
const ALIASES := {
	KEY_K: KEY_UP, KEY_J: KEY_DOWN, KEY_H: KEY_LEFT, KEY_L: KEY_RIGHT,
	KEY_KP_8: KEY_UP, KEY_KP_2: KEY_DOWN, KEY_KP_4: KEY_LEFT, KEY_KP_6: KEY_RIGHT,
}

var side := PACK
var _at := [0, 0]
var _top := [0, 0]
## Choosing which gem to take for the three given.
var choosing_gem := false
var _gem_at := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	if font == null:
		font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
	if font_bold == null:
		font_bold = load("res://assets/fonts/JetBrainsMono-Bold.ttf")

func open() -> void:
	# An empty pack has nothing to sell, and a highlight parked on nothing
	# makes enter do nothing -- Brad met exactly that on a fresh floor one.
	side = PACK if not pack_rows().is_empty() else SHELF
	_at = [0, 0]
	_top = [0, 0]
	choosing_gem = false
	visible = true
	queue_redraw()

func close() -> void:
	visible = false
	closed.emit()

## Pack rows: every item you carry, by index. Refused ones stay listed, dimmed,
## with the reason on the info line -- hiding them would read as "the trader
## did not notice I had it" rather than "the trader will not take it".
func pack_rows() -> Array:
	var out := []
	if state != null:
		for i in state.player.inventory.size():
			out.append(i)
	return out

## Shelf rows: stock indices, then the gem exchange.
func shelf_rows() -> Array:
	var out := []
	if state != null:
		for i in state.trader_stock.size():
			out.append(i)
	out.append(GEM_ROW)
	return out

func _rows(which: int) -> Array:
	return pack_rows() if which == PACK else shelf_rows()

## Every gem the trader can make, in the element table's own order.
func gem_choices() -> Array:
	return Item.ELEMENTS.keys()

## The row under the highlight on the active side, or null.
func current() -> Variant:
	var rows := _rows(side)
	if rows.is_empty():
		return null
	return rows[clampi(int(_at[side]), 0, rows.size() - 1)]

func _clamp() -> void:
	for s in [PACK, SHELF]:
		var n := _rows(s).size()
		_at[s] = clampi(int(_at[s]), 0, maxi(n - 1, 0))
		if int(_at[s]) < int(_top[s]):
			_top[s] = _at[s]
		if int(_at[s]) >= int(_top[s]) + ROWS:
			_top[s] = int(_at[s]) - ROWS + 1
		_top[s] = clampi(int(_top[s]), 0, maxi(n - ROWS, 0))

## Keys drive the counter. Answers whether the key meant something here.
##
## main.gd has already refused any pad press that is not one of these, so a
## controller cannot reach anything by accident; letters simply do nothing.
func handle_key(key: int) -> bool:
	if not visible or state == null:
		return false
	key = int(ALIASES.get(key, key))
	if choosing_gem:
		var n := gem_choices().size()
		match key:
			KEY_UP:
				_gem_at = posmod(_gem_at - 1, n)
			KEY_DOWN:
				_gem_at = posmod(_gem_at + 1, n)
			KEY_ESCAPE:
				choosing_gem = false
			_:
				if key in MainScene.CONFIRM:
					if state.trade_buy_gem(StringName(gem_choices()[_gem_at])):
						choosing_gem = false
				else:
					return false
		queue_redraw()
		return true

	var rows := _rows(side)
	match key:
		KEY_UP:
			if not rows.is_empty():
				_at[side] = posmod(int(_at[side]) - 1, rows.size())
		KEY_DOWN:
			if not rows.is_empty():
				_at[side] = posmod(int(_at[side]) + 1, rows.size())
		KEY_LEFT:
			side = PACK
		KEY_RIGHT:
			side = SHELF
		KEY_ESCAPE:
			close()
			return true
		MainScene.PACK_FORGE_KEY:
			# The same key the pack uses for its second action, so a thumb that
			# has learned Y does not have to learn it twice.
			if side == PACK and current() != null:
				state.trade_enchant(int(current()))
		_:
			if key in MainScene.CONFIRM:
				_act()
			else:
				return false
	_clamp()
	queue_redraw()
	return true

## A on the highlighted row: sell from the pack, buy from the shelf.
func _act() -> void:
	var row = current()
	if row == null:
		return
	if side == PACK:
		state.trade_sell(int(row))
	elif int(row) == GEM_ROW:
		if state.trader_gems >= Trade.GEMS_FOR_ONE:
			choosing_gem = true
			_gem_at = 0
		else:
			state.msg_log.add("\"Bring me %d gems and choose one.\"" % Trade.GEMS_FOR_ONE,
				Color(0.85, 0.75, 0.55))
	else:
		state.trade_buy(int(row))

## THE MOUSE, which most players will use and which the first version barely
## served.
##
## HOVER moves the highlight, as it does in the pack, so the info line says what
## an item is worth BEFORE a click sells it -- without this a mouse player sold
## blind and learned the prices by accident. A CLICK then acts on that row, the
## same act as A. The WHEEL walks the highlight, which scrolls a long shelf. And
## the gem chooser answers to the mouse too; the first version opened it on a
## click and then only let the keyboard choose.
func _gui_input(event: InputEvent) -> void:
	if state == null or not visible:
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		if choosing_gem:
			var g := _gem_hit(motion.position)
			if g >= 0 and g != _gem_at:
				_gem_at = g
				queue_redraw()
		else:
			var hit := _hit(motion.position)
			if hit.x >= 0 and (hit.x != side or hit.y != int(_at[hit.x])):
				side = hit.x
				_at[side] = hit.y
				queue_redraw()
		return

	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	if click.button_index == MOUSE_BUTTON_WHEEL_UP \
			or click.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		var over := _hit(click.position)
		if over.x >= 0:
			side = over.x
		handle_key(KEY_UP if click.button_index == MOUSE_BUTTON_WHEEL_UP else KEY_DOWN)
		_swallow()
		return
	if click.button_index != MOUSE_BUTTON_LEFT:
		return
	if choosing_gem:
		var g := _gem_hit(click.position)
		if g >= 0:
			_gem_at = g
			handle_key(KEY_ENTER)
		else:
			# A click outside the chooser backs out of it, as esc does.
			choosing_gem = false
			queue_redraw()
		_swallow()
		return
	var hit := _hit(click.position)
	if hit.x >= 0:
		side = hit.x
		_at[side] = hit.y
		_act()
		_clamp()
		queue_redraw()
		_swallow()

## Only a panel in the scene tree can mark an event handled; the suite drives
## this headless, and asking outside the tree is an engine error.
func _swallow() -> void:
	if is_inside_tree():
		accept_event()

## Which row is under this point, as (side, row index), or (-1, -1).
func _hit(pos: Vector2) -> Vector2i:
	for s in [PACK, SHELF]:
		var rows := _rows(s)
		for i in range(int(_top[s]), mini(rows.size(), int(_top[s]) + ROWS)):
			if _row_rect(s, i - int(_top[s])).has_point(pos):
				return Vector2i(s, i)
	return Vector2i(-1, -1)

## The chooser's box, shared by drawing and clicking so the two cannot drift.
func _gem_box() -> Rect2:
	var p := _panel()
	return Rect2(p.position + Vector2(PANEL.x * 0.5 - 180.0, 120.0),
		Vector2(360.0, 60.0 + LINE * float(gem_choices().size())))

func _gem_row_rect(i: int) -> Rect2:
	var box := _gem_box()
	return Rect2(Vector2(box.position.x + 8.0, box.position.y + 46.0 + LINE * float(i)),
		Vector2(box.size.x - 16.0, LINE))

## Which gem row is under this point, or -1.
func _gem_hit(pos: Vector2) -> int:
	for i in gem_choices().size():
		if _gem_row_rect(i).has_point(pos):
			return i
	return -1

func _panel() -> Rect2:
	return Rect2(((size - PANEL) * 0.5).floor(), PANEL)

func _col_w() -> float:
	return (PANEL.x - PAD * 2.0 - COL_GAP) * 0.5

func _row_rect(which: int, slot: int) -> Rect2:
	var p := _panel()
	var x := p.position.x + PAD + float(which) * (_col_w() + COL_GAP)
	var y := p.position.y + PAD + 34.0 + LINE * 1.6 + float(slot) * LINE
	return Rect2(Vector2(x, y), Vector2(_col_w(), LINE))

## What the highlighted row means, in one line -- the refusal, the worth, the
## price. The place a player learns the economy by looking rather than reading.
func info() -> String:
	if state == null:
		return ""
	if choosing_gem:
		return "choose the gem you will take for your %d" % Trade.GEMS_FOR_ONE
	var row = current()
	if row == null:
		return ""
	if side == PACK:
		var it: Item = state.player.inventory[int(row)]
		var no := Trade.refusal(it)
		if no != "":
			return no
		if Trade.is_gem(it):
			return "a gem: give me %d and choose any one you like" % Trade.GEMS_FOR_ONE
		return "worth %d to the trader" % Trade.worth(it)
	if int(row) == GEM_ROW:
		return "%d of %d gems given; %d buy a gem of your choice" % [
			state.trader_gems, Trade.GEMS_FOR_ONE, Trade.GEMS_FOR_ONE]
	var entry: Dictionary = state.trader_stock[int(row)]
	var it2: Item = entry["item"]
	if String(entry["hero"]) != "":
		return "all that is left of %s. Nobody will sell it again." % entry["hero"]
	return "costs %d  ·  you have %d credit" % [Trade.price(it2), state.trader_credit]

## The footer, in the language of whatever the player is holding.
func footer() -> String:
	if pad_input and pad_cfg != null:
		var ok := pad_cfg.icon(KEY_PERIOD, true)
		var roll := pad_cfg.icon(MainScene.PACK_FORGE_KEY, true)
		var back := pad_cfg.icon(MainScene.PACK_BACK_KEY, true)
		if choosing_gem:
			return "%s take it  ·  %s back" % [ok, back]
		return "%s sell / buy  ·  %s enchant (%d)  ·  ◄ ► side  ·  %s leave" % [
			ok, roll, Trade.ENCHANT, back]
	if choosing_gem:
		return "enter or click take it  ·  esc back"
	return "point to see a price  ·  click or enter sell / buy  ·  x enchant (%d)  ·  esc leave" \
		% Trade.ENCHANT

func _draw() -> void:
	if state == null:
		return
	var p := _panel()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55), true)
	draw_rect(p, Palette.UI_PANEL_BG, true)
	draw_rect(p, Palette.UI_FRAME, false, 1.0)
	var asc := font.get_ascent(font_size)
	var x0 := p.position.x + PAD
	var y := p.position.y + PAD + asc

	draw_string(font_bold, Vector2(x0, y), "THE TRADER", HORIZONTAL_ALIGNMENT_LEFT, -1,
		font_size + 2, Palette.STAIRS)
	var purse := "credit %d  ·  gems %d/%d  ·  enchant %s" % [
		state.trader_credit, state.trader_gems, Trade.GEMS_FOR_ONE,
		"spent" if state.trader_rolled else "ready"]
	draw_string(font, Vector2(x0, y), purse, HORIZONTAL_ALIGNMENT_RIGHT,
		PANEL.x - PAD * 2.0, font_size - 1, Palette.UI_TEXT)

	var head_y := p.position.y + PAD + 34.0 + asc
	for s in [PACK, SHELF]:
		var hx := x0 + float(s) * (_col_w() + COL_GAP)
		draw_string(font_bold, Vector2(hx, head_y),
			"YOUR PACK" if s == PACK else "ON THE SHELF",
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 3,
			Palette.CURSOR if s == side else Palette.UI_DIM)
		var rows := _rows(s)
		for slot in ROWS:
			var i := int(_top[s]) + slot
			if i >= rows.size():
				break
			_draw_row(s, slot, rows[i], s == side and i == int(_at[s]))
		if rows.size() > ROWS:
			draw_string(font, Vector2(hx, _row_rect(s, ROWS).position.y + asc),
				"%d of %d" % [mini(int(_top[s]) + ROWS, rows.size()), rows.size()],
				HORIZONTAL_ALIGNMENT_RIGHT, _col_w(), font_size - 4, Palette.UI_DIM)

	if choosing_gem:
		_draw_gem_chooser()

	var info_y := p.end.y - PAD - LINE
	draw_string(font, Vector2(x0, info_y), info(), HORIZONTAL_ALIGNMENT_LEFT,
		PANEL.x - PAD * 2.0, font_size - 1, Palette.UI_TEXT)
	var hint := footer()
	var hs := font_size - 3
	while hs > 9 and PadGlyphs.width(hint, font, hs) > PANEL.x - PAD * 2.0:
		hs -= 1
	PadGlyphs.draw(self, Vector2(x0, p.end.y - PAD), hint, font, hs, Palette.UI_DIM)

func _draw_row(which: int, slot: int, row: Variant, lit: bool) -> void:
	var r := _row_rect(which, slot)
	if lit:
		draw_rect(r, Color(Palette.CURSOR, 0.16), true)
	var base := Vector2(r.position.x + 6.0, r.position.y + font.get_ascent(font_size) + 2.0)
	var text := ""
	var right := ""
	var bright := true
	if which == PACK:
		var it: Item = state.player.inventory[int(row)]
		text = it.display_name()
		if state.player.is_equipped(it):
			text += "  (worn)"
		if Trade.refusal(it) != "":
			right = "--"
			bright = false
		elif Trade.is_gem(it):
			right = "gem"
		else:
			right = "+%d" % Trade.worth(it)
	elif int(row) == GEM_ROW:
		text = "a gem of your choice"
		right = "%d gems" % Trade.GEMS_FOR_ONE
		bright = state.trader_gems >= Trade.GEMS_FOR_ONE
	else:
		var entry: Dictionary = state.trader_stock[int(row)]
		var it2: Item = entry["item"]
		text = it2.display_name()
		if String(entry["hero"]) != "":
			text = "%s's %s" % [entry["hero"], it2.display_name()]
		var cost := Trade.price(it2)
		right = "%d" % cost
		bright = cost <= state.trader_credit
	var colour := Palette.UI_TEXT if bright else Palette.UI_DIM
	if which == SHELF and int(row) != GEM_ROW \
			and String(state.trader_stock[int(row)]["hero"]) != "":
		colour = Palette.STAIRS if bright else Palette.UI_DIM
	draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 70.0,
		font_size, colour)
	draw_string(font, base, right, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 12.0,
		font_size, colour)

func _draw_gem_chooser() -> void:
	var box := _gem_box()
	draw_rect(box, Palette.UI_PANEL_BG, true)
	draw_rect(box, Palette.STAIRS, false, 1.0)
	draw_string(font_bold, Vector2(box.position.x + 16.0, box.position.y + 30.0),
		"WHICH STONE?", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 2, Palette.STAIRS)
	for i in gem_choices().size():
		var el := StringName(gem_choices()[i])
		var gem := Item.make(StringName(Item.ELEMENTS[el]["gem"]))
		var r := _gem_row_rect(i)
		if i == _gem_at:
			draw_rect(r, Color(Palette.CURSOR, 0.16), true)
		draw_string(font, Vector2(r.position.x + 8.0, r.position.y + font.get_ascent(font_size)),
			gem.name if gem != null else String(el), HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size, Palette.UI_TEXT)
