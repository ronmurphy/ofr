class_name TradePanel
extends Control

## The trader's counter: your pack on the left, the trader's shelf on the right.
##
## BUILT FOR A CONTROLLER FROM THE FIRST LINE. Every controller bug this week
## came from a screen built for the keyboard and fixed afterwards -- the stairs,
## the missile confirm, restarting, forging, and a pack where a pad press used
## whatever item wore that button's letter. So this screen has no letter
## shortcuts at all: the stick moves, A acts on what is highlighted, Y asks for
## the enchant roll, left/right changes side and the shoulders turn over the
## piles. A keyboard does the same with the arrows, enter, x and tab.
##
## The rules live in GameState (the counter's state) and Trade (the prices).
## This only draws them and turns a press into one of a handful of calls.

signal closed()

@export var font: Font
@export var font_bold: Font
@export var font_size: int = 17
## The icon subset, drawn from DIRECTLY and never reached through a text font's
## fallbacks: fallback resolution does not survive the web export for these
## codepoints, which is how the sidebar's skull became a box. See sidebar.gd.
@export var icon_font: Font

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
const ROWS := 18
const COL_GAP := 40.0
## Where the name starts in a row, after the item's picture.
const NAME_X := 32.0

## The band under the title that holds the piles.
const PILE_Y := 40.0
const PILE_H := 30.0
const PILE_W := 64.0
const PILE_GAP := 8.0
## Column headers, then the rows, below the piles.
const HEAD_Y := PILE_Y + PILE_H + 16.0

const PACK := 0
const SHELF := 1
## The last row on the shelf is not an item: it trades three gems for one of your choice.
const GEM_ROW := -1

## THE TRADER'S PILES. A monster's idea of a shop.
##
## Brad, 2026-09-24: the counter should sort like the pack does, but it need
## not LOOK like the pack -- the trader is a monster that collects, and what it
## thinks a shop is need not be what a person expects. So the shelf is sorted
## the way a collector who used to fight for a living would sort a hoard: by
## what a thing is FOR. Things that cut, things you wear, things to hide
## behind, bottles and scrolls, and what the dead left.
##
## A dead hero's dagger is in BOTH "cut" and "the dead" -- the piles are ways of
## looking, not places things live. "Everything" comes first and is where the
## counter opens, so a player who never touches the piles loses nothing.
##
## `icon` is an item id whose picture stands for the pile; the dead's pile draws
## a skull instead, and "everything" draws its word.
const PILES := [
	{"id": &"all",  "name": "everything I have",     "icon": &""},
	{"id": &"cut",  "name": "things that cut",       "icon": &"dagger"},
	{"id": &"wear", "name": "things you wear",       "icon": &"leather_armour"},
	{"id": &"hide", "name": "things to hide behind", "icon": &"buckler"},
	{"id": &"else", "name": "bottles and scrolls",   "icon": &"potion_healing"},
	{"id": &"dead", "name": "what the dead left",    "icon": &""},
]
## md-skull, the same picture the skeleton wears, from the game's own icon font.
const SKULL := 0xF068C

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
var pile := 0
var _at := [0, 0]
var _top := [0, 0]
## Choosing which gem to take for the three given.
var choosing_gem := false
var _gem_at := 0
## The pile under the pointer, so a mouse player can learn the icons' names.
var _hover_pile := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	if font == null:
		font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
	if font_bold == null:
		font_bold = load("res://assets/fonts/JetBrainsMono-Bold.ttf")
	if icon_font == null:
		icon_font = load("res://assets/fonts/ofr_icons.ttf")

func open() -> void:
	# An empty pack has nothing to sell, and a highlight parked on nothing
	# makes enter do nothing -- Brad met exactly that on a fresh floor one.
	side = PACK if not pack_rows().is_empty() else SHELF
	pile = 0
	_at = [0, 0]
	_top = [0, 0]
	_hover_pile = -1
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

## Shelf rows: the stock indices in the current pile, then the gem exchange,
## which belongs to no pile and so is under every one of them.
func shelf_rows() -> Array:
	var out := []
	if state != null:
		for i in state.trader_stock.size():
			if in_pile(pile, state.trader_stock[i]):
				out.append(i)
	out.append(GEM_ROW)
	return out

## Does this shelf entry belong in pile `p`?
static func in_pile(p: int, entry: Dictionary) -> bool:
	var it: Item = entry["item"]
	match StringName(PILES[p]["id"]):
		&"cut":
			return it.slot == Item.Slot.WEAPON
		&"wear":
			return it.slot == Item.Slot.ARMOR
		&"hide":
			return it.slot == Item.Slot.OFFHAND
		&"else":
			return it.slot == Item.Slot.NONE
		&"dead":
			return String(entry.get("hero", "")) != ""
	return true

## How many things are in pile `p` right now.
func pile_count(p: int) -> int:
	var n := 0
	if state != null:
		for entry in state.trader_stock:
			if in_pile(p, entry):
				n += 1
	return n

## Turn to another pile. Always lands on the shelf, at its top: turning over the
## trader's piles while the highlight stayed in your own pack would change
## something you could not see.
func set_pile(p: int) -> void:
	pile = posmod(p, PILES.size())
	side = SHELF
	_at[SHELF] = 0
	_top[SHELF] = 0
	queue_redraw()

## Which way a pad press turns the piles: -1 for the left shoulder, +1 for the
## right, 0 for anything else. Read from the live bindings, so it follows a
## rebind: the SHOULDER turns the piles, whatever key it was given to send.
static func pad_pile_step(cfg: PadConfig, key: int) -> int:
	if cfg == null:
		return 0
	match cfg.button_for_key(key):
		JOY_BUTTON_LEFT_SHOULDER:
			return -1
		JOY_BUTTON_RIGHT_SHOULDER:
			return 1
	return 0

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
## `back` is shift on a keyboard, and the left shoulder on a pad.
##
## main.gd has already refused any pad press that is not one of these, so a
## controller cannot reach anything by accident; letters simply do nothing.
func handle_key(key: int, back := false) -> bool:
	if not visible or state == null:
		return false
	key = int(ALIASES.get(key, key))
	# A key means the player has left the pointer; a pile's name parked on the
	# info line would hide the price of the row the key just moved to.
	_hover_pile = -1
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
		KEY_TAB:
			set_pile(pile + (-1 if back else 1))
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
## same act as A. The WHEEL walks the highlight, which scrolls a long shelf, and
## over the piles it turns them. The piles are pictures, so hovering one names
## it. And the gem chooser answers to the mouse too; the first version opened
## it on a click and then only let the keyboard choose.
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
			var over_pile := _pile_hit(motion.position)
			if over_pile != _hover_pile:
				_hover_pile = over_pile
				queue_redraw()
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
		var up := click.button_index == MOUSE_BUTTON_WHEEL_UP
		if not choosing_gem and _pile_hit(click.position) >= 0:
			set_pile(pile + (-1 if up else 1))
			_hover_pile = pile
		else:
			var over := _hit(click.position)
			if over.x >= 0:
				side = over.x
			handle_key(KEY_UP if up else KEY_DOWN)
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
	var chosen_pile := _pile_hit(click.position)
	if chosen_pile >= 0:
		set_pile(chosen_pile)
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

## A pile's button, shared by drawing and clicking so the two cannot drift.
## Fixed widths, never measured from the font: the suite clicks these without
## a scene tree, where there is no font to measure with.
func _pile_rect(p: int) -> Rect2:
	var panel := _panel()
	var x := panel.position.x + PAD + _col_w() + COL_GAP + float(p) * (PILE_W + PILE_GAP)
	return Rect2(Vector2(x, panel.position.y + PAD + PILE_Y), Vector2(PILE_W, PILE_H))

## Which pile's button is under this point, or -1.
func _pile_hit(pos: Vector2) -> int:
	for p in PILES.size():
		if _pile_rect(p).has_point(pos):
			return p
	return -1

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
	var y := p.position.y + PAD + HEAD_Y + LINE * 1.2 + float(slot) * LINE
	return Rect2(Vector2(x, y), Vector2(_col_w(), LINE))

## What the highlighted row means, in one line -- the refusal, the worth, the
## price. The place a player learns the economy by looking rather than reading.
func info() -> String:
	if state == null:
		return ""
	if choosing_gem:
		return "choose the gem you will take for your %d" % Trade.GEMS_FOR_ONE
	if _hover_pile >= 0:
		var n := pile_count(_hover_pile)
		return "%s  ·  %s" % [PILES[_hover_pile]["name"],
			"nothing yet" if n == 0 else "%d on the pile" % n]
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
	if bool(entry.get("yours", false)):
		return "\"You gave me this. It is yours again for %d.\"  ·  you have %d credit" \
			% [Trade.price(it2), state.trader_credit]
	return "costs %d  ·  you have %d credit" % [Trade.price(it2), state.trader_credit]

## The footer, in the language of whatever the player is holding.
func footer() -> String:
	if pad_input and pad_cfg != null:
		var ok := pad_cfg.icon(KEY_PERIOD, true)
		var roll := pad_cfg.icon(MainScene.PACK_FORGE_KEY, true)
		var back := pad_cfg.icon(MainScene.PACK_BACK_KEY, true)
		var lb := pad_cfg.icon(pad_cfg.key_for_button(JOY_BUTTON_LEFT_SHOULDER), true)
		var rb := pad_cfg.icon(pad_cfg.key_for_button(JOY_BUTTON_RIGHT_SHOULDER), true)
		if choosing_gem:
			return "%s take it  ·  %s back" % [ok, back]
		return "%s sell / buy  ·  %s %s piles  ·  %s enchant (%d)  ·  ◄ ► side  ·  %s leave" % [
			ok, lb, rb, roll, Trade.ENCHANT, back]
	if choosing_gem:
		return "enter or click take it  ·  esc back"
	return "point to see a price  ·  click or enter sell / buy  ·  tab piles  ·  x enchant (%d)  ·  esc leave" \
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

	for i in PILES.size():
		_draw_pile(i)

	var head_y := p.position.y + PAD + HEAD_Y + asc - 6.0
	for s in [PACK, SHELF]:
		var hx := x0 + float(s) * (_col_w() + COL_GAP)
		var head := "YOUR PACK" if s == PACK else String(PILES[pile]["name"]).to_upper()
		draw_string(font_bold, Vector2(hx, head_y), head,
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

	# An empty pile answers in the trader's voice, under the gem row that every
	# pile keeps.
	if pile != 0 and pile_count(pile) == 0:
		var r := _row_rect(SHELF, 1)
		draw_string(font, Vector2(r.position.x + NAME_X, r.position.y + asc + 8.0),
			"\"Nothing like that. Not yet.\"", HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size - 1, Palette.UI_DIM)

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

## One pile's button: its picture and how many are on it.
func _draw_pile(i: int) -> void:
	var r := _pile_rect(i)
	var active := i == pile
	var n := pile_count(i)
	var tone := Palette.CURSOR if active \
		else (Palette.UI_TEXT if i == _hover_pile else Palette.UI_DIM)
	draw_rect(r, Color(Palette.CURSOR, 0.18) if active else Color(1, 1, 1, 0.04), true)
	draw_rect(r, Palette.CURSOR if active else Palette.UI_FRAME, false, 1.0)
	var mid := r.position.y + r.size.y * 0.5
	var entry: Dictionary = PILES[i]
	var left := r.position.x + 8.0
	if StringName(entry["id"]) == &"all":
		draw_string(font, Vector2(left, mid + font.get_ascent(font_size - 3) * 0.5 - 2.0),
			"all", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 3, tone)
	else:
		var ch := char(SKULL)
		var fg := Palette.GRAVE
		if StringName(entry["icon"]) != &"":
			var app: Dictionary = RenderTheme.active().appearance(
				Item.make(StringName(entry["icon"])).appearance)
			ch = app["ch"]
			fg = app["fg"]
		# Centred on the button by eye: the icons draw larger than the text size
		# they are asked for, so the text's own centring leaves them high.
		_draw_glyph(ch, Vector2(left, mid + font.get_ascent(font_size) * 0.5 + 4.0),
			font_size, fg if n > 0 or active else Color(fg, 0.4))
	draw_string(font, Vector2(r.position.x, mid + font.get_ascent(font_size - 4) * 0.5 - 2.0),
		str(n), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 8.0, font_size - 4, tone)

## A picture from whichever face carries it: the icon font for icons, drawn
## directly, and the text font for the ascii theme's characters.
func _draw_glyph(ch: String, base: Vector2, at_size: int, colour: Color) -> void:
	var gsz := GlyphTheme.draw_size(ch, at_size)
	var face := icon_font if GlyphTheme.is_icon(ch) else font
	draw_string(face, base + Vector2(0.0, (at_size - gsz) * 0.35), ch,
		HORIZONTAL_ALIGNMENT_LEFT, -1, gsz, colour)

func _draw_row(which: int, slot: int, row: Variant, lit: bool) -> void:
	var r := _row_rect(which, slot)
	if lit:
		draw_rect(r, Color(Palette.CURSOR, 0.16), true)
	var base := Vector2(r.position.x + 6.0, r.position.y + font.get_ascent(font_size) + 2.0)
	var text := ""
	var right := ""
	var bright := true
	var item: Item = null
	var hero := ""
	var yours := false
	if which == PACK:
		item = state.player.inventory[int(row)]
		text = item.display_name()
		if state.player.is_equipped(item):
			text += "  (worn)"
		if Trade.refusal(item) != "":
			right = "--"
			bright = false
		elif Trade.is_gem(item):
			right = "gem"
		else:
			right = "+%d" % Trade.worth(item)
	elif int(row) == GEM_ROW:
		text = "a gem of your choice"
		right = "%d gems" % Trade.GEMS_FOR_ONE
		bright = state.trader_gems >= Trade.GEMS_FOR_ONE
	else:
		var entry: Dictionary = state.trader_stock[int(row)]
		item = entry["item"]
		hero = String(entry["hero"])
		yours = bool(entry.get("yours", false))
		text = item.display_name()
		if hero != "":
			text = "%s's %s" % [hero, item.display_name()]
		var cost := Trade.price(item)
		right = "%d" % cost
		bright = cost <= state.trader_credit

	var colour := Palette.UI_TEXT if bright else Palette.UI_DIM
	if hero != "":
		colour = Palette.STAIRS if bright else Palette.UI_DIM
	elif yours:
		colour = Palette.TRADE_YOURS if bright else Color(Palette.TRADE_YOURS, 0.5)

	# The picture: the item's own, or a gem for the exchange row.
	var pic := item if item != null else Item.make(&"gem_fire")
	var app: Dictionary = RenderTheme.active().appearance(pic.appearance)
	var fg: Color = Palette.GEM if item == null else \
		(Palette.MAGIC if pic.shows_enchanted() else app["fg"])
	_draw_glyph(app["ch"], base, font_size, fg if bright else Color(fg, 0.45))

	var name_at := base + Vector2(NAME_X, 0.0)
	draw_string(font, name_at, text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 80.0 - NAME_X,
		font_size, colour)
	# A dead hero's things carry the skull after the name, as the sidebar marks
	# a death -- in both the dead's pile and the pile the thing belongs to.
	if hero != "":
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		_draw_glyph(char(SKULL), name_at + Vector2(w + 8.0, 0.0), font_size - 2,
			Palette.GRAVE if bright else Palette.UI_DIM)
	draw_string(font, base, right, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 12.0,
		font_size, colour)

func _draw_gem_chooser() -> void:
	var box := _gem_box()
	draw_rect(box, Palette.UI_PANEL_BG, true)
	draw_rect(box, Palette.STAIRS, false, 1.0)
	draw_string(font_bold, Vector2(box.position.x + 16.0, box.position.y + 30.0),
		"WHICH GEM?", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 2, Palette.STAIRS)
	for i in gem_choices().size():
		var el := StringName(gem_choices()[i])
		var gem := Item.make(StringName(Item.ELEMENTS[el]["gem"]))
		var r := _gem_row_rect(i)
		if i == _gem_at:
			draw_rect(r, Color(Palette.CURSOR, 0.16), true)
		draw_string(font, Vector2(r.position.x + 8.0, r.position.y + font.get_ascent(font_size)),
			gem.name if gem != null else String(el), HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size, Palette.UI_TEXT)
