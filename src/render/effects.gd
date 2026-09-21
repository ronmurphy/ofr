class_name Effects
extends RefCounted

## How much of the map is allowed to move.
##
## This exists for accessibility before it exists for taste. Motion effects stop
## some people playing games at all, and a dungeon where every brazier flickers
## and every pool ripples is exactly the shape of thing that does it. Brad has a
## friend who cannot play some games for this reason and who plays THIS one --
## the timer effects sit under her threshold. That is the whole design: the
## middle setting is what she already tolerates, and the ends are for people on
## either side of her.
##
##   NONE     nothing moves. No flicker, no pulse, no ripple.
##   TIMERS   the small CPU effects that have always been here -- torch
##            flicker, the stairs breathing, the ember pulse.
##   SHADERS  those replaced by the shader, which does more and moves more.
##
## Deliberately three rather than an on/off. One person's threshold is not a
## specification, and NONE costs almost nothing once the other two exist.
enum Mode { NONE, TIMERS, SHADERS }

const MODE_NAMES := {
	Mode.NONE: "still",
	Mode.TIMERS: "simple",
	Mode.SHADERS: "full",
}

## The same file the view mode uses, for the same reason: these are both
## settings a player picks once and expects to still be there tomorrow.

## SHADERS by default, Brad's call 2026-09-20.
##
## TIMERS shipped as a precaution for weak hardware, and the precaution was
## never measured. These are small fragment shaders over a 1600x900 canvas;
## decade-old integrated graphics run them. Everyone testing turns them on
## immediately, and the setting stays for anyone who wants it off.
static var _mode: int = Mode.SHADERS

static func mode() -> int:
	return _mode

static func mode_count() -> int:
	return Mode.size()

## Does anything move at all?
static func any() -> bool:
	return _mode != Mode.NONE

## Should the CPU timer effects run?
static func timers() -> bool:
	return _mode == Mode.TIMERS

## Should the shader run?
static func shaders() -> bool:
	return _mode == Mode.SHADERS

static func set_mode(m: int) -> void:
	_mode = posmod(m, mode_count())
	_save()

## Returns what to tell the player, so the caller need not know the names.
static func cycle() -> String:
	set_mode(_mode + 1)
	return "Effects: %s." % MODE_NAMES[_mode]

static func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(GameState.SETTINGS_PATH) != OK:
		return
	_mode = posmod(int(cfg.get_value("view", "effects", Mode.TIMERS)), mode_count())

static func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(GameState.SETTINGS_PATH)
	cfg.set_value("view", "effects", _mode)
	cfg.save(GameState.SETTINGS_PATH)
