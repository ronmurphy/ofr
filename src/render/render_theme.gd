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

enum Mode { ASCII, SYMBOLS }

const MODE_NAMES := {
	Mode.ASCII: "letters",
	Mode.SYMBOLS: "symbols",
}

const SETTINGS := "user://settings.cfg"

static var _mode: int = Mode.ASCII
static var _instances := {}

static func active() -> RenderTheme:
	if not _instances.has(_mode):
		_instances[_mode] = SymbolTheme.new() if _mode == Mode.SYMBOLS \
			else AsciiTheme.new()
	return _instances[_mode]

static func mode() -> int:
	return _mode

## How many modes this build offers.
##
## Two for now. A third -- an icon font for creatures -- is a desktop-only
## download, because the font is several megabytes and the whole point of the
## symbols mode is that the web build gets pictures for free.
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

static func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) != OK:
		return
	_mode = posmod(int(cfg.get_value("view", "mode", Mode.ASCII)), mode_count())

static func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("view", "mode", _mode)
	cfg.save(SETTINGS)
