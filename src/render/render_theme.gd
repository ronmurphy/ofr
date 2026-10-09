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
## The map renderer is a separate choice from its glyph theme. The 3D view
## uses picture billboards -- or pixel sprites, `v` in 3D (_sprites, below)
## -- while `v` in the classic view keeps cycling the classic themes.
## 3D by default, from 2026-09-28 (Brad: "i have yet to talk to a person that
## plays the game that dislikes it"). A player who chose classic keeps it: the
## saved value wins over this default.
static var _diorama := true
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

static func diorama_enabled() -> bool:
	return _diorama

## THE OVERHEAD VIEW (Brad, 2026-10-01): the 3D view with its camera pitched
## nearly straight down -- a modern 3D version of the classic overhead. The
## same renderer, the same turning camera, the same keys; only the pitch.
## Saved with the rest of the view, so you come back to the view you left.
static var _overhead := false

static func overhead_enabled() -> bool:
	return _diorama and _overhead

## Q cycles the three views -- classic, 3D, 3D overhead -- rather than
## toggling two, so a pad reaches all three with the one button it has.
## Returns what to tell the player.
static func cycle_view() -> String:
	if not _diorama:
		_diorama = true
		_overhead = false
	elif not _overhead:
		_overhead = true
	else:
		_diorama = false
		_overhead = false
	_save()
	return "View: %s." % view_name()

static func view_name() -> String:
	if not _diorama:
		return "classic"
	return "3D overhead" if _overhead else "3D"

## Gabe's follow camera (2026-09-28): in the 3D view the camera stays behind
## the player and the keys become forward/back/turn. Off by default.
## On by default too, after Gabe, David and Steph -- the most motion-sensitive
## tester -- played it swinging and snapping without discomfort.
static var _follow := true

static func camera_follows() -> bool:
	return _follow

static func toggle_follow() -> String:
	_follow = not _follow
	_save()
	return "Camera: %s." % ("follows you" if _follow else "fixed")

## THE PIXEL LOOK (2026-10-09): the 3D views' cards drawn from the sprite
## files in assets/sprites/ (PixelSprites) instead of the icon pictures,
## wherever a drawing exists. 3D only; off by default until the set is
## drawn by hand. `v` in a 3D view turns it on and off.
static var _sprites := false

static func sprites_enabled() -> bool:
	return _sprites

static func toggle_sprites() -> String:
	_sprites = not _sprites
	_save()
	return "Look: %s." % ("pixel art" if _sprites else "pictures")

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
	_diorama = bool(cfg.get_value("view", "diorama", true))
	_overhead = bool(cfg.get_value("view", "overhead", false))
	_follow = bool(cfg.get_value("view", "follow", true))
	_sprites = bool(cfg.get_value("view", "sprites", false))
	# Set directly rather than through set_cell_size(), which would write the
	# file back out during the load that is reading it.
	var px := int(cfg.get_value("view", "cell", 18))
	_cell = px if CELL_SIZES.has(px) else 18

static func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(GameState.SETTINGS_PATH)
	cfg.set_value("view", "mode", _mode)
	cfg.set_value("view", "diorama", _diorama)
	cfg.set_value("view", "overhead", _overhead)
	cfg.set_value("view", "follow", _follow)
	cfg.set_value("view", "sprites", _sprites)
	cfg.set_value("view", "cell", _cell)
	cfg.save(GameState.SETTINGS_PATH)
