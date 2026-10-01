class_name LegendPanel
extends Control

## What everything on screen means.
##
## Built entirely from the data the game already has -- the bestiary, the
## render theme, the tile table -- never hand-written. A hand-written legend is
## correct exactly until the next monster is added, and then it quietly lies.

@export var font: Font
@export var font_bold: Font
@export var font_size: int = 14

## The live bindings and which device is in the player's hands, set by main.gd.
##
## This screen was the LAST place in the game still naming keys a handheld does
## not have -- it read `w  swap reach / blade` on a Legion Go S, where the answer
## is RB. Every other surface had been made device-aware; this one was missed
## because it is the one nobody looks at until they are already lost.
var pad_cfg: PadConfig = null
var pad_input := false

## The size the panel actually draws at, as a constant the suite can read: an
## @export is an instance property, and a layout guard must not have to build a
## panel to ask how big its text is.
static func font_size_default() -> int:
	return 14

## The icon subset, for glyphs only. Text keeps the full font: this one
## carries ascii and the symbols the game draws and nothing else, so a
## message with an unexpected character in it would come out as tofu.
@export var icon_font: Font

## A creature row was chosen, and there is a picture for it.
signal portrait_requested(app: StringName, title: String, note: String)
## Right pages across to the overview map. Brad's idea, and it is what let the
## map exist without a controller button of its own: these are two pages of one
## reference, the way a Zelda menu pages between map and equipment.
signal map_requested()

var state: GameState

## Rows you can actually open, rebuilt every draw.
##
## Only creatures you have MET are in here. An unmet row reads "not yet met"
## and has nothing behind it -- letting a player open a blank portrait for
## something they have never seen would tell them it exists, which is the one
## thing this panel is careful not to do.
var _rows: Array = []
var _pick := -1

const PAD := 24.0
const LINE := 21.0
const GLYPH_X := 4.0
## Leaves room for a second glyph beside the first -- see _entry's `second`,
## which is where a corrupted variant is shown.
const NAME_X := 44.0

## Drawn procedurally on the map rather than lettered, so the legend needs a
## stand-in for them.
const DRAWN := {
	&"wall": "█", &"rock": "█", &"pillar": "●",
	&"pit": "●", &"stalagmite": "▲",
}

## The order they are worth reading in, rather than enum order -- and only
## what has something to say (the screens review, 2026-10-01). Floor, cave
## floor, wall, rock, pillar and stalagmite are what they look like; the two
## wrong fungi, which this list had never heard of, are the tiles a player
## most needs told about.
const TERRAIN_ORDER := [
	Tiles.DOOR_CLOSED, Tiles.DOOR_OPEN, Tiles.WATER, Tiles.MUD, Tiles.RUBBLE,
	Tiles.BONES, Tiles.FUNGUS, Tiles.FUNGUS_PURPLE, Tiles.FUNGUS_RED,
	Tiles.BRAZIER, Tiles.BRAZIER_SPENT, Tiles.BRAZIER_DEAD, Tiles.SHRINE,
	Tiles.TRAP, Tiles.PIT, Tiles.STAIRS_DOWN, Tiles.STAIRS_UP,
]
const LEFT_OUT := "floor, walls, pillars: as they look"

## Short notes for the things whose behaviour is invisible. Only where the
## glyph and the name genuinely do not tell you. Every one is measured beside
## its name by the suite.
const NOTES := {
	Tiles.DOOR_CLOSED: "loud to open",
	Tiles.MUD: "slow; worst for heavy things",
	Tiles.WATER: "slow to wade",
	Tiles.RUBBLE: "slightly slow; knaps sling stones",
	Tiles.BONES: "LOUD; crumbles once crossed",
	Tiles.FUNGUS: "glows faintly; eat it",
	Tiles.FUNGUS_PURPLE: "its air poisons: 1 hp a turn",
	Tiles.FUNGUS_RED: "claims the dead; burn or bury",
	Tiles.BRAZIER: "rest at it, or forge",
	Tiles.BRAZIER_SPENT: "its embers set a gem",
	# The black one said "cold for good" until fire could relight it (a flare,
	# a gem of fire, a fire blade -- 2026-09-30); now it says only what wakes it.
	Tiles.BRAZIER_DEAD: "cold, until fire",
	Tiles.SHRINE: "its colour: pray, or the mirror",
	Tiles.TRAP: "springs once",
	Tiles.PIT: "drops you a floor",
	Tiles.TRAP + 1000: "",
}

## WHAT YOU CAN CARRY, as rows of [appearance, name, note, second line]. The
## note sits on the row where it fits; a long one for a long name goes on a
## dim second line (the two uniques). Gems, the uniques and food were missing
## until the screens review: every new system of the fortnight ran on things
## this panel did not list.
const ITEM_ROWS := [
	[&"potion", "potions", "", ""],
	[&"scroll", "scrolls", "", ""],
	[&"meat", "meat and haunches", "food", ""],
	[&"gem", "gems", "set at embers; or used in the world", ""],
	[&"weapon", "swords and daggers", "", ""],
	# These two earn their own rows because they now have their own
	# pictures, and a picture nothing explains is worse than a shared
	# one. What they are FOR is the damage type, so the row says it.
	[&"mace", "maces -- blunt", "", ""],
	[&"axe", "axes -- heavy slash", "", ""],
	[&"launcher", "slings and bows", "", ""],
	[&"armour", "armour", "", ""],
	[&"shield", "shields, not with a bow", "", ""],
	[&"ring", "the ring of the rat", "", "a rat, until it goes cold; a gem warms it"],
	[&"shovel", "the undertaker's shovel", "", "raises your last kill; buries the red's dead"],
	[&"amulet", "the Amulet of the Deep", "", ""],
]

## THE KEYS, IN GROUPS (the screens review): what you do, and what you see
## and set. Two groups rather than five -- the column has room for exactly
## this many lines, and the suite holds it there. A row of Sidebar.KEYS that
## no group names lands in the second, so a new key is never lost.
const KEY_GROUPS := [
	["ACT", ["move", "wait / rest", "descend", "ascend", "pick up", "shoot", "throw",
		"swap reach / blade", "torch", "close a door", "pray at a shrine",
		"ally: heel / loose", "inventory", "look"]],
	["VIEW AND SYSTEM", ["letters / symbols / pictures", "classic / 3D view",
		"turn 3D camera", "still / simple / full", "the map", "sound", "music",
		"screenshot", "menu", "travel"]],
]
## The pick-up row's action, as the key really behaves: g does what the
## square offers. Said on the row rather than under it -- the column has
## exactly one line to spare, and the suite holds it there.
const PICK_UP_ROW := "pick up / eat / burn / bury"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	if font == null:
		font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
	if icon_font == null:
		icon_font = load("res://assets/fonts/ofr_icons.ttf")
	if font_bold == null:
		font_bold = load("res://assets/fonts/JetBrainsMono-Bold.ttf")

func open() -> void:
	visible = true
	LegendPanel.note_seen()
	queue_redraw()

## Whether this player has ever opened the legend. Until they have, the
## sidebar's "press ? for help" is bold and gold on floors 1-2: neither teen at
## the 2026-09-26 playtest found the controls alone. Kept in settings.cfg so a
## returning player is not shouted at every new run.
static var _seen := -1

static func seen_ever() -> bool:
	if _seen < 0:
		var cfg := ConfigFile.new()
		cfg.load(GameState.SETTINGS_PATH)
		_seen = 1 if bool(cfg.get_value("help", "legend_seen", false)) else 0
	return _seen == 1

static func note_seen() -> void:
	if seen_ever():
		return
	_seen = 1
	var cfg := ConfigFile.new()
	cfg.load(GameState.SETTINGS_PATH)
	cfg.set_value("help", "legend_seen", true)
	cfg.save(GameState.SETTINGS_PATH)

## For tests: forget the cached answer, so the next ask reads the file.
static func forget_seen() -> void:
	_seen = -1

func close() -> void:
	visible = false

func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		var at := _row_at(motion.position)
		if at != _pick:
			_pick = at
			queue_redraw()
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	# A click ON a row you have met opens its picture; anywhere else closes,
	# which is what this panel has always done.
	var hit := _row_at(click.position)
	if hit >= 0:
		_open(hit)
		return
	close()
	queue_redraw()

## The wash behind the selected row.
##
## Called with the index the NEXT appended row will take -- _rows.size() -- so
## it works while the list is still being rebuilt. Reading _rows[_pick] from
## inside the draw does not: the list is cleared at the top of the column and
## refilled as rows are laid out, so for most of a frame it is a partial copy
## of itself.
func _highlight(x: float, y: float, w: float) -> void:
	if _pick == _rows.size():
		draw_rect(Rect2(x - 4.0, y, w, LINE), Color(Palette.CURSOR, 0.13), true)

func _row_at(pos: Vector2) -> int:
	for i in _rows.size():
		if Rect2(_rows[i]["rect"]).has_point(pos):
			return i
	return -1

func _open(i: int) -> void:
	if i < 0 or i >= _rows.size():
		return
	var row: Dictionary = _rows[i]
	portrait_requested.emit(row["app"], String(row["title"]),
		String(row["note"]))

## Keys, so the roster is reachable without a mouse.
##
## The whole reason this exists: a handheld has no pointer, and "click a name
## to see its picture" is not an instruction a Steam Deck player can follow.
## Up and down move the highlight, wait or enter opens it -- the same two keys
## the pause menu uses, and both bound on a default pad.
func handle_key(key: int) -> bool:
	if not visible:
		return false
	match key:
		KEY_UP:
			_move(-1)
		KEY_DOWN:
			_move(1)
		KEY_PERIOD, KEY_ENTER, KEY_KP_ENTER:
			_open(_pick)
		KEY_RIGHT:
			visible = false
			map_requested.emit()
		_:
			close()
	queue_redraw()
	return true

func _move(step: int) -> void:
	if _rows.is_empty():
		return
	if _pick < 0:
		_pick = 0 if step > 0 else _rows.size() - 1
	else:
		_pick = posmod(_pick + step, _rows.size())

# ---------------------------------------------------------------- drawing ---

func _draw() -> void:
	if state == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.72), true)

	# Sized to its contents rather than to the screen: a panel with two thirds
	# of it empty reads as unfinished.
	var tallest := maxi(maxi(_terrain_lines(), _creature_lines()),
		maxi(_item_lines(), _control_lines()))
	var wanted := PAD * 2.0 + 34.0 + float(tallest) * LINE + 10.0
	var h := minf(wanted, size.y - 48.0)
	var panel := Rect2(Vector2(24.0, (size.y - h) * 0.5), Vector2(size.x - 48.0, h))
	draw_rect(panel, Palette.UI_PANEL_BG, true)
	draw_rect(panel, Palette.UI_FRAME, false, 1.0)

	var asc := font.get_ascent(font_size)
	draw_string(font_bold, panel.position + Vector2(PAD, PAD + asc), "LEGEND",
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size + 2, Palette.STAIRS)
	draw_string(font, panel.position + Vector2(PAD, PAD + asc),
		"esc or click to close", HORIZONTAL_ALIGNMENT_RIGHT,
		panel.size.x - PAD * 2.0, font_size, Palette.UI_DIM)

	var col_w := (panel.size.x - PAD * 2.0) / 4.0
	var top := panel.position.y + PAD + 34.0
	_terrain_column(panel.position.x + PAD, top, col_w)
	_creature_column(panel.position.x + PAD + col_w, top, col_w)
	_item_column(panel.position.x + PAD + col_w * 2.0, top, col_w)
	_control_column(panel.position.x + PAD + col_w * 3.0, top, col_w)

## Line counts, so the panel can be sized before anything is drawn.
func _terrain_lines() -> int:
	return 1 + TERRAIN_ORDER.size() + 1

func _creature_lines() -> int:
	return 1 + 1 + GameState.BESTIARY.size() + 1 + 1 + 4 + 4

func _item_lines() -> int:
	var n := 1 + 1 + 1 + Shrines.COUNT
	for row in ITEM_ROWS:
		n += 2 if String(row[3]) != "" else 1
	return n

func _control_lines() -> int:
	# The movement block, a gap, the KEYS heading, a heading per group, every
	# key, and the page marker.
	return 1 + move_lines() + 1 + 1 + KEY_GROUPS.size() + Sidebar.KEYS.size() + 1

## What the panel wants to be, for the suite: it must fit the window.
func wanted_height() -> float:
	var tallest := maxi(maxi(_terrain_lines(), _creature_lines()),
		maxi(_item_lines(), _control_lines()))
	return PAD * 2.0 + 34.0 + float(tallest) * LINE + 10.0

func _heading(x: float, y: float, text: String) -> float:
	draw_string(font_bold, Vector2(x, y + font.get_ascent(font_size)), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 2, Palette.UI_DIM)
	return y + LINE

## One row: glyph, name, and an optional dim note on the right.
func _entry(x: float, y: float, w: float, glyph: String, tint: Color,
		name: String, note: String = "", second: String = "",
		name_tint: Color = Palette.UI_TEXT) -> float:
	var base := y + font.get_ascent(font_size)
	# A creature the climb has got hold of, shown BESIDE its ordinary self
	# rather than as a row of its own. One row per creature keeps the roster
	# the same length and keeps the count honest -- corruption is a second
	# thing to learn about a creature, not a second creature.
	if second != "":
		var ss := GlyphTheme.draw_size(second, font_size)
		var sf := icon_font if GlyphTheme.is_icon(second) else font
		draw_string(sf, Vector2(x + GLYPH_X + 13.0, base + (font_size - ss) * 0.35),
			second, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, Palette.CORRUPTED)
	# Icons are drawn larger here for the same reason they are on the map, and
	# it matters more here: this panel is where they are learned.
	var gs := GlyphTheme.draw_size(glyph, font_size)
	var gf := icon_font if GlyphTheme.is_icon(glyph) else font
	draw_string(gf, Vector2(x + GLYPH_X, base + (font_size - gs) * 0.35), glyph,
		HORIZONTAL_ALIGNMENT_LEFT, -1, gs, tint)
	draw_string(font, Vector2(x + NAME_X, base), name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, name_tint)
	if note != "":
		draw_string(font, Vector2(x + NAME_X, base), note,
			HORIZONTAL_ALIGNMENT_RIGHT, w - NAME_X - 12.0, font_size - 2,
			Palette.UI_DIM)
	return y + LINE

## The eight-way movement scheme, drawn rather than described.
##
## This exists because the person who built the game did not know he could move
## diagonally. He was playing on a keyboard with no number pad, using the arrow
## keys -- which are orthogonal only -- while every monster on the floor moved
## and struck in eight directions. The sidebar said "arrows / hjklyubn  move",
## which reads as though the two are the same thing.
##
## A picture says in one glance what that line failed to say at all.
## ONE DIAGRAM THAT TAKES TURNS (Brad, 2026-10-01). The vi keys, the number
## pad and the arrows each had their own picture, side by side, taking room;
## now one box shows each in turn, a few seconds apiece. The arrows get the
## sentence this block exists to deliver. On "still" nothing cycles: the
## first layout stays, and the arrows' warning is in its note.
const MOVE_LAYOUTS := [
	{"name": "the vi keys", "art": [" y k u", "  \\|/", " h-@-l", "  /|\\", " b j n"],
		"note": "eight directions; arrows give four"},
	{"name": "the number pad", "art": [" 7 8 9", "  \\|/", " 4-@-6", "  /|\\", " 1 2 3"],
		"note": "eight directions"},
	{"name": "the arrow keys", "art": ["   ^", "   |", " <-@->", "   |", "   v"],
		"note": "four directions, not eight"},
]
const MOVE_CYCLE_S := 2.5

## Which layout is up: the first, held, on still; otherwise the clock's.
func layout_index() -> int:
	if not Effects.any():
		return 0
	return int(Time.get_ticks_msec() / (MOVE_CYCLE_S * 1000.0)) % MOVE_LAYOUTS.size()

## The movement block's height in lines: on a pad two sentences, on a
## keyboard the picture and its note.
func move_lines() -> int:
	if pad_input:
		return 2
	return MOVE_LAYOUTS[0]["art"].size() + 1

func _process(_delta: float) -> void:
	# Only the cycling needs a redraw; a still panel costs nothing.
	if visible and not pad_input and Effects.any() and MOVE_LAYOUTS.size() > 1:
		queue_redraw()

## A line of the movement diagram: monospace art, with no glyph/name split.
func _art(x: float, y: float, text: String, tint: Color) -> float:
	draw_string(font, Vector2(x + GLYPH_X, y + font.get_ascent(font_size)), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)
	return y + LINE

## A key's written form as cap labels: "arrows / hjklyubn" is two caps,
## ". or 5" two, "m  - +" three, "f (no bow)" one. A pad's picture is one.
static func cap_labels(label: String) -> Array:
	var out: Array = []
	for part in label.split(" / "):
		for piece in String(part).split(" or "):
			var tokens: PackedStringArray = String(piece).split(" ", false)
			var all_short := tokens.size() > 1
			for t in tokens:
				if String(t).length() != 1:
					all_short = false
			if all_short:
				for t in tokens:
					out.append(String(t))
			elif String(piece).strip_edges() != "":
				out.append(String(piece).strip_edges())
	return out

## The key rows in group order: {group, caps, action, keyboard_only}.
## `keyboard_only` is a pad player looking at a key their pad has no button
## for -- drawn dim, so the list says which is which.
func key_rows() -> Array:
	var out: Array = []
	var placed := {}
	for g in KEY_GROUPS:
		for action in g[1]:
			for row in Sidebar.KEYS:
				if String(row[1]) == String(action) and not placed.has(String(row[1])):
					out.append(_key_row(String(g[0]), row))
					placed[String(row[1])] = true
	# Anything the groups did not name: the last group, never dropped.
	for row in Sidebar.KEYS:
		if not placed.has(String(row[1])):
			out.append(_key_row(String(KEY_GROUPS[-1][0]), row))
			placed[String(row[1])] = true
	return out

func _key_row(group: String, row: Array) -> Dictionary:
	var label := Sidebar.key_label(row, pad_cfg, pad_input)
	var kb_only := false
	if pad_input:
		var pad_word := row.size() > 3 and String(row[3]) != ""
		var bound := int(row[2]) != 0 and pad_cfg != null and pad_cfg.button_for_key(int(row[2])) >= 0
		kb_only = not pad_word and not bound
	var action := String(row[1])
	if action == "pick up":
		action = PICK_UP_ROW
	return {"group": group, "caps": cap_labels(label), "action": action,
		"keyboard_only": kb_only}

func _control_column(x: float, y: float, w: float) -> void:
	var base := y + font.get_ascent(font_size)
	if pad_input:
		y = _heading(x, y, "MOVEMENT")
		var stick := String.chr(PadConfig.STICK_GLYPH)
		PadGlyphs.draw(self, Vector2(x + GLYPH_X, y + font.get_ascent(font_size)),
			stick + "  the left stick: eight directions", font, font_size, Palette.UI_TEXT)
		y += LINE
		y = _art(x, y, "the d-pad is four actions, below", Palette.UI_DIM)
	else:
		var layout: Dictionary = MOVE_LAYOUTS[layout_index()]
		y = _heading(x, y, "MOVEMENT")
		# Which layout is up, on the heading's own line, with the count.
		draw_string(font, Vector2(x, base), "%s  %d/%d" % [layout["name"],
			layout_index() + 1, MOVE_LAYOUTS.size()], HORIZONTAL_ALIGNMENT_RIGHT,
			w - 12.0, font_size - 2, Palette.UI_DIM)
		for line in layout["art"]:
			y = _art(x, y, String(line), Palette.UI_TEXT)
		# The arrows' warning is the one sentence this block exists to deliver,
		# so it is the loud colour; the others are plain.
		y = _art(x, y, String(layout["note"]),
			Palette.AMULET if layout_index() == MOVE_LAYOUTS.size() - 1
			or not Effects.any() else Palette.UI_TEXT)

	y += LINE * 0.6
	y = _heading(x, y, "KEYS")
	# Straight from the sidebar's table, so the two can never disagree about
	# what a key does -- grouped, and drawn as caps.
	var group := ""
	for row in key_rows():
		if String(row["group"]) != group:
			group = String(row["group"])
			draw_string(font_bold, Vector2(x + GLYPH_X, y + font.get_ascent(font_size)),
				group, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 3, Palette.UI_DIM)
			y += LINE
		var row_base := y + font.get_ascent(font_size)
		var dim: bool = bool(row["keyboard_only"])
		Keycap.draw_row(self, Vector2(x + GLYPH_X, row_base), row["caps"], font,
			font_size - 1, Palette.UI_DIM if dim else Palette.STAIRS)
		draw_string(font, Vector2(x + GLYPH_X, row_base), String(row["action"]),
			HORIZONTAL_ALIGNMENT_RIGHT, w - 12.0, font_size - 1,
			Palette.UI_DIM if dim else Palette.UI_TEXT)
		y += LINE

	# The page marker. Said on the screen rather than left to be discovered,
	# because a page you do not know is there is a page nobody visits -- and on
	# a handheld this WAS the only route to the map. That stopped being true on
	# 2026-09-22, when `g` became the action key: the tile knows whether its
	# stairs go up or down, so the dedicated ascend button was freed and the map
	# took it. Kept because paging between the two reference screens is still
	# how most people will reach it, and the corrected claim is worth having
	# written down rather than silently deleted.
	y += LINE * 0.8
	draw_string(font, Vector2(x + GLYPH_X, y + font.get_ascent(font_size)),
		"right  \u2192  the map", HORIZONTAL_ALIGNMENT_LEFT, -1,
		font_size - 1, Palette.STAIRS)

func _look(id: StringName) -> Dictionary:
	# The active theme, not the ASCII table: a legend that keeps showing
	# letters while the map shows symbols is worse than no legend.
	return RenderTheme.active().appearance(id)

func _terrain_column(x: float, y: float, w: float) -> void:
	y = _heading(x, y, "GROUND AND FEATURES")
	for tile in TERRAIN_ORDER:
		var id := Tiles.appearance_id(tile)
		var art := _look(id)
		var glyph: String = DRAWN.get(id, art["ch"])
		var tint: Color = art["fg"]
		# Walls and stone are drawn, not lettered, so their colour lives in the
		# palette rather than the theme table.
		match id:
			&"wall": tint = Palette.STONE_LIGHT
			&"rock": tint = Palette.ROCK_LIGHT
			&"pillar": tint = Palette.PILLAR
			&"pit": tint = Palette.PIT_RIM
			&"stalagmite": tint = Palette.ROCK_LIGHT
		var label := String(id).replace("_", " ")
		y = _entry(x, y, w, glyph, tint, label, NOTES.get(tile, ""))
	draw_string(font, Vector2(x + NAME_X, y + font.get_ascent(font_size)), LEFT_OUT,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 2, Palette.UI_DIM)

func _creature_column(x: float, y: float, w: float) -> void:
	# Counted by walking the SAME list the rows below are drawn from, not by
	# asking the record how much it holds.
	#
	# The record can hold things this panel has no row for: the killer rabbit
	# is a transformation rather than a bestiary entry, so a player who had met
	# one and everything else would have read "21/20". A denominator and a
	# numerator that come from different places will disagree eventually.
	var known := 0
	for e in GameState.BESTIARY:
		if BestiaryLog.knows(e["app"]):
			known += 1
	_rows.clear()
	y = _heading(x, y, "CREATURES  %d/%d" % [known, GameState.BESTIARY.size()])
	y = _entry(x, y, w, "@", Palette.PLAYER, "you", "")
	# Never redacted, unlike the roster below.
	#
	# The bestiary hides what you have not met so the legend cannot spoil what
	# is waiting further down. A trader is the opposite case: knowing one exists
	# is the whole point, because the only failure mode is walking past without
	# realising there was anything to walk up to. Brad's reasoning -- somebody
	# reads this, says "wait, there is a trader?", and goes looking.
	#
	# Outside the roster loop, so it does not move the "known / total" count,
	# the same way "you" does not.
	var trader_top := y
	_highlight(x, y, w)
	y = _entry(x, y, w, "&", Palette.TRADER, "a trader",
		"first floor of a band")
	_rows.append({"rect": Rect2(x, trader_top, w, y - trader_top),
		"app": &"trader", "title": "the trader",
		"note": "first floor of a band"})
	for e in GameState.BESTIARY:
		# Not met yet: a redacted row rather than no row.
		#
		# Hiding them entirely would make the panel shrink and grow as you
		# played, and would hide the one genuinely useful fact -- that there is
		# more down there than you have seen. A dash keeps the roster's SHAPE
		# visible while saying nothing about what fills it.
		#
		# Listing them outright is what this panel used to do, and it meant a
		# player on floor two could read that there is an arch lich on the
		# climb out. A reference that answers questions you have not asked yet
		# is a spoiler wearing a helpful face.
		if not BestiaryLog.knows(e["app"]):
			y = _entry(x, y, w, "-", Palette.UI_DIM, "not yet met", "")
			continue
		var art := _look(e["app"])
		# The same glyph again in violet, once you have met one.
		var twisted: String = art["ch"] if BestiaryLog.knows_corrupted(e["app"]) else ""
		# `min_depth` is the tier the fade weights it at, which for an
		# ascent-only thing is NOT where you meet it -- the arch lich sits at
		# the dragon's tier and is gated separately. Printing "depth 10+" for
		# something you can only meet climbing out is a straightforwardly false
		# statement in the one panel that exists to tell the truth.
		var note := "depth %d+" % int(e["min_depth"])
		if e.has("ascent_from"):
			note = "the climb out"
		if int(e.get("range", 1)) > 1:
			note = "shoots  " + note
		elif int(e.get("regen", 0)) > 0:
			note = "regrows  " + note
		elif String(e.get("ai", "")) == "forager":
			note = "forages  " + note
		elif int(e.get("wail", 0)) > 0:
			# Kept to one word like the others. That the cry wakes the floor is
			# the thing worth learning by meeting one, and the log says it
			# plainly the first time it happens.
			note = "wails  " + note
		var top := y
		_highlight(x, y, w)
		y = _entry(x, y, w, art["ch"], art["fg"], e["name"], note, twisted)
		_rows.append({"rect": Rect2(x, top, w, y - top),
			"app": e["app"], "title": String(e["name"]), "note": note})

	y += LINE * 0.6
	y = _heading(x, y, "BEHAVIOUR MARKS")
	y = _entry(x, y, w, "z", Palette.SLEEP, "asleep", "")
	y = _entry(x, y, w, "?", Palette.ALERT, "stirring", "")
	y = _entry(x, y, w, "!", Palette.ALERT, "it has seen you", "")
	y = _entry(x, y, w, "<<", Palette.FLEEING, "running from you", "")
	# The spore tell, and the two kinds of creature it leads to (the screens
	# review): the outline on a map figure, as a ring here.
	y = _ring_entry(x, y, w, Palette.FUNGUS_PURPLE, "purple ring", "its body rots into purple")
	y = _ring_entry(x, y, w, Palette.FUNGUS_RED, "red ring", "it rises when it falls")
	y = _entry(x, y, w, "", Palette.UI_TEXT, "risen", "blind: it hunts by sound", "",
		Palette.FUNGUS_RED)
	y = _entry(x, y, w, "", Palette.UI_TEXT, "corrupted", "crossed the purple, and changed", "",
		Palette.CORRUPTED)

## A row led by a ring rather than a glyph: the spore outline, as drawn
## round a figure on the map.
func _ring_entry(x: float, y: float, w: float, colour: Color, name: String,
		note: String) -> float:
	draw_arc(Vector2(x + GLYPH_X + 7.0, y + LINE * 0.5), 5.0, 0.0, TAU, 16, colour, 2.0)
	return _entry(x, y, w, "", colour, name, note)

func _item_column(x: float, y: float, w: float) -> void:
	y = _heading(x, y, "WHAT YOU CAN CARRY")
	for row in ITEM_ROWS:
		var art := _look(row[0])
		y = _entry(x, y, w, art["ch"], art["fg"], String(row[1]), String(row[2]))
		if String(row[3]) != "":
			draw_string(font, Vector2(x + NAME_X, y + font.get_ascent(font_size)),
				String(row[3]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 2, Palette.UI_DIM)
			y += LINE

	y += LINE * 0.6
	y = _heading(x, y, "SHRINES")
	# Which colour does what is shuffled every run, so the legend can only
	# report what has actually been learned. Spoiling that here would undo the
	# one mechanic built on not knowing.
	for kind in Shrines.COUNT:
		var known: bool = state.shrine_known.has(kind)
		# The theme's shrine glyph, not a literal -- the colour is per-shrine but
		# the shape has to follow the view mode like everything else.
		# No trailing "?" any more. With four columns it ended up hard against
		# the key list and read as though it belonged to those rows instead --
		# and "not yet used" already says the same thing in words.
		y = _entry(x, y, w, String(_look(&"shrine")["ch"]), state.shrine_hue(kind),
			Shrines.NAMES[kind] if known else "not yet learned", "", "",
			Palette.UI_TEXT if known else Palette.UI_DIM)
