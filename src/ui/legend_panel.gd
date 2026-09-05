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

var state: GameState

const PAD := 24.0
const LINE := 21.0
const GLYPH_X := 4.0
const NAME_X := 30.0

## Drawn procedurally on the map rather than lettered, so the legend needs a
## stand-in for them.
const DRAWN := {
	&"wall": "█", &"rock": "█", &"pillar": "●",
	&"pit": "●", &"stalagmite": "▲",
}

## The order they are worth reading in, rather than enum order.
const TERRAIN_ORDER := [
	Tiles.FLOOR, Tiles.CAVE_FLOOR, Tiles.WALL, Tiles.ROCK, Tiles.PILLAR,
	Tiles.STALAGMITE, Tiles.DOOR_CLOSED, Tiles.DOOR_OPEN, Tiles.WATER,
	Tiles.MUD, Tiles.RUBBLE, Tiles.BONES, Tiles.FUNGUS, Tiles.BRAZIER,
	Tiles.BRAZIER_SPENT, Tiles.SHRINE, Tiles.TRAP, Tiles.PIT,
	Tiles.STAIRS_DOWN, Tiles.STAIRS_UP,
]

## Short notes for the things whose behaviour is invisible. Only where the
## glyph and the name genuinely do not tell you.
const NOTES := {
	Tiles.MUD: "slow; worst for heavy things",
	Tiles.WATER: "slow to wade",
	Tiles.RUBBLE: "slightly slow",
	Tiles.BONES: "LOUD; crumbles once crossed",
	Tiles.FUNGUS: "glows faintly",
	Tiles.BRAZIER: "rest at it, or forge",
	Tiles.TRAP: "springs once",
	Tiles.PIT: "drops you a floor",
	Tiles.TRAP + 1000: "",
}

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
		close()
		queue_redraw()

# ---------------------------------------------------------------- drawing ---

func _draw() -> void:
	if state == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.72), true)

	# Sized to its contents rather than to the screen: a panel with two thirds
	# of it empty reads as unfinished.
	var tallest := maxi(maxi(_terrain_lines(), _creature_lines()), _item_lines())
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

	var col_w := (panel.size.x - PAD * 2.0) / 3.0
	var top := panel.position.y + PAD + 34.0
	_terrain_column(panel.position.x + PAD, top, col_w)
	_creature_column(panel.position.x + PAD + col_w, top, col_w)
	_item_column(panel.position.x + PAD + col_w * 2.0, top, col_w)

## Line counts, so the panel can be sized before anything is drawn.
func _terrain_lines() -> int:
	return 1 + TERRAIN_ORDER.size()

func _creature_lines() -> int:
	return 1 + 1 + GameState.BESTIARY.size() + 1 + 1 + 3

func _item_lines() -> int:
	return 1 + 6 + 1 + 1 + Shrines.COUNT

func _heading(x: float, y: float, text: String) -> float:
	draw_string(font_bold, Vector2(x, y + font.get_ascent(font_size)), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 2, Palette.UI_DIM)
	return y + LINE

## One row: glyph, name, and an optional dim note on the right.
func _entry(x: float, y: float, w: float, glyph: String, tint: Color,
		name: String, note: String = "") -> float:
	var base := y + font.get_ascent(font_size)
	draw_string(font, Vector2(x + GLYPH_X, base), glyph,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)
	draw_string(font, Vector2(x + NAME_X, base), name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.UI_TEXT)
	if note != "":
		draw_string(font, Vector2(x + NAME_X, base), note,
			HORIZONTAL_ALIGNMENT_RIGHT, w - NAME_X - 12.0, font_size - 2,
			Palette.UI_DIM)
	return y + LINE

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

func _creature_column(x: float, y: float, w: float) -> void:
	y = _heading(x, y, "CREATURES")
	y = _entry(x, y, w, "@", Palette.PLAYER, "you", "")
	for e in GameState.BESTIARY:
		var art := _look(e["app"])
		var note := "depth %d+" % int(e["min_depth"])
		if int(e.get("range", 1)) > 1:
			note = "shoots  " + note
		elif int(e.get("regen", 0)) > 0:
			note = "regrows  " + note
		y = _entry(x, y, w, art["ch"], art["fg"], e["name"], note)

	y += LINE * 0.6
	y = _heading(x, y, "BEHAVIOUR MARKS")
	y = _entry(x, y, w, "z", Palette.SLEEP, "asleep", "")
	y = _entry(x, y, w, "?", Palette.ALERT, "stirring", "")
	y = _entry(x, y, w, "!", Palette.ALERT, "it has seen you", "")

func _item_column(x: float, y: float, w: float) -> void:
	y = _heading(x, y, "WHAT YOU CAN CARRY")
	for pair in [[&"potion", "potions"], [&"scroll", "scrolls"],
			[&"weapon", "melee weapons"], [&"launcher", "slings and bows"],
			[&"armour", "armour"], [&"amulet", "the Amulet of the Deep"]]:
		var art := _look(pair[0])
		y = _entry(x, y, w, art["ch"], art["fg"], pair[1], "")

	y += LINE * 0.6
	y = _heading(x, y, "SHRINES")
	# Which colour does what is shuffled every run, so the legend can only
	# report what has actually been learned. Spoiling that here would undo the
	# one mechanic built on not knowing.
	for kind in Shrines.COUNT:
		var known: bool = state.shrine_known.has(kind)
		# The theme's shrine glyph, not a literal -- the colour is per-shrine but
		# the shape has to follow the view mode like everything else.
		y = _entry(x, y, w, String(_look(&"shrine")["ch"]), state.shrine_hue(kind),
			Shrines.NAMES[kind] if known else "not yet used",
			"" if known else "?")
