class_name RenderTheme
extends RefCounted

## The seam between simulation and presentation.
##
## The simulation only ever emits semantic ids -- &"wall", &"goblin". A theme
## turns an id into something drawable. This one returns a character and a
## colour; a Kenney tileset theme would return an atlas region instead, and the
## simulation would never know the difference.
##
## To add a tile-graphics mode later:
##   1. Subclass this and return {"tex": Texture2D, "region": Rect2i, ...}
##   2. Write a TileGrid Control that consumes it, mirroring GlyphGrid
##   3. Swap which node the main scene instantiates
## No file under src/sim/ needs to change.

func appearance(id: StringName) -> Dictionary:
	return {"ch": "?", "fg": Color.MAGENTA}

# ------------------------------------------------------------------- modes ---
#
# Which theme is drawing right now. Static because three unrelated panels ask
# the question -- the grid, the legend and the inventory -- and a mode they
# disagree about is worse than no mode at all.

enum Mode { ASCII, SYMBOLS, ICONS }

const MODE_NAMES := {
	Mode.ASCII: "letters",
	Mode.SYMBOLS: "symbols",
	Mode.ICONS: "pictures",
}


## Pictures, not letters.
##
## It shipped as ASCII for the retro look, and two of the three people playing
## asked why the picture mode was not the default. The retro look is still one
## keypress away and the setting is remembered, so defaulting to letters was
## costing every new player the mode most likely to make the game legible to
## them in order to protect a preference they can express in a second.
##
## Only affects players with no saved setting -- load_settings() overrides this
## from user://settings.cfg, so anyone who has already chosen keeps their
## choice.
static var _mode: int = Mode.ICONS
static var _instances := {}

## Pixels per map cell, offered to the player rather than fixed.
##
## A handheld is the reason this moved. The canvas is 1600x900 and stretches to
## fit, so a Steam Deck's 1280x800 scales it by 0.8 and the shipped 18px cell
## reaches the eye as about 14 -- fine at a desk, small at arm's length on a
## 7in panel. The low end of the list is for a large monitor, where seeing more
## of the floor at once beats bigger letters.
const CELL_SIZES := [14, 16, 18, 20, 24, 28]

## The size the game shipped at, so nobody's view moves under them on update.
static var _cell: int = 18

static func active() -> RenderTheme:
	if not _instances.has(_mode):
		match _mode:
			Mode.ICONS:   _instances[_mode] = GlyphTheme.new()
			Mode.SYMBOLS: _instances[_mode] = SymbolTheme.new()
			_:            _instances[_mode] = AsciiTheme.new()
	return _instances[_mode]

static func mode() -> int:
	return _mode

## How many modes this build offers.
##
## All three, everywhere. The icon mode was going to be desktop-only on the
## assumption that the font cost megabytes. Subsetting it to the thirty glyphs
## the game actually draws brought it to 18KB -- a fifteenth of the text font
## already being shipped. The assumption was the only thing in the way.
static func mode_count() -> int:
	return Mode.size()

static func set_mode(m: int) -> void:
	_mode = posmod(m, mode_count())
	_save()

## Returns what to tell the player, so the caller does not have to know the
## names of the modes.
static func cycle() -> String:
	set_mode(_mode + 1)
	return "View: %s." % MODE_NAMES[_mode]

static func cell_size() -> int:
	return _cell

## The glyph point size that belongs to a cell.
##
## Derived rather than stored. The shipped pair was a 16pt glyph in an 18px
## cell and 16/18 is exactly 8/9, so holding that ratio means a character never
## outgrows its cell at any step on the list. It also saves one number instead
## of two that could drift apart.
static func font_size_for(cell: int) -> int:
	return roundi(cell * 8.0 / 9.0)

static func font_size() -> int:
	return font_size_for(_cell)

## An unrecognised size falls back to the shipped one rather than being trusted.
## This is read from a file a player can edit by hand.
static func set_cell_size(px: int) -> void:
	_cell = px if CELL_SIZES.has(px) else 18
	_save()

## Returns what to tell the player, the same contract as cycle().
static func cycle_size() -> String:
	var i := CELL_SIZES.find(_cell)
	set_cell_size(CELL_SIZES[posmod(i + 1, CELL_SIZES.size())])
	return "Text size: %d px." % _cell

static func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(GameState.SETTINGS_PATH) != OK:
		return
	_mode = posmod(int(cfg.get_value("view", "mode", Mode.ICONS)), mode_count())
	# Set directly rather than through set_cell_size(), which would write the
	# file back out during the load that is reading it.
	var px := int(cfg.get_value("view", "cell", 18))
	_cell = px if CELL_SIZES.has(px) else 18

static func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(GameState.SETTINGS_PATH)
	cfg.set_value("view", "mode", _mode)
	cfg.set_value("view", "cell", _cell)
	cfg.save(GameState.SETTINGS_PATH)
