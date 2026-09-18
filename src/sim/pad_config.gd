class_name PadConfig
extends RefCounted

## What this particular controller calls its buttons.
##
## FOUR PEOPLE ASKED FOR CONTROLLER SUPPORT IN ONE NIGHT, on four different
## devices -- a Steam Deck, a ROG handheld, a Legion Go S and something nobody
## recognised. That is what makes this a config file rather than a table in the
## source: button indices are not standardised, and a layout that is correct
## for one of those four is wrong for at least one other.
##
## So the defaults below are a best guess at the Xbox-style layout most
## handhelds report as, and the game ships a way to REBIND them. The guess
## exists so that most people never have to; the rebinding exists because some
## people always will.
##
## Stored beside settings.cfg rather than with the morgue: this describes the
## player's hardware, not their run, and it must survive a death.

const PATH := "user://gamepad.cfg"

## Button index -> the keycode it should behave as.
##
## Keycodes rather than action names, because every panel in this game already
## reads keycodes -- see Gamepad. A binding here is a promise that pressing
## this button is exactly like typing that key, which is a smaller promise than
## inventing an action layer and easier to be sure of.
var binds: Dictionary = {}

## The order the rebinding walk-through asks for them, and what to call each
## one on screen. Directions first because a player who gives up halfway
## through still has a controller they can walk with.
##
## The eight-way diagonals are deliberately NOT here: the stick covers them by
## angle, and asking someone to bind eight directions on a d-pad that has four
## is a worse first experience than having to use the stick for diagonals.
##
## EVERY KEY IN `DEFAULTS` MUST APPEAR HERE. It did not, at first: close door,
## ally stance and the legend were bound by default and absent from the
## walk-through, so rebinding could evict one and no amount of further
## rebinding could put it back -- `r` for defaults was the only way out, and it
## throws away every other choice with it. A binding you can lose and cannot
## restore is worse than one that was never offered.
##
## What is NOT here, on purpose: the pause menu ROWS (text size, save, abandon).
## Those are reached by opening the menu and choosing, not by spending one of a
## handheld's scarce buttons on each -- see the note in `src/ui/pad_panel.gd`.
const WALK := [
	[KEY_UP, "move up"],
	[KEY_DOWN, "move down"],
	[KEY_LEFT, "move left"],
	[KEY_RIGHT, "move right"],
	[KEY_PERIOD, "wait / rest"],
	[KEY_G, "pick up"],
	[KEY_I, "inventory"],
	[KEY_X, "look"],
	[KEY_F, "shoot"],
	[KEY_W, "swap reach / blade"],
	[KEY_C, "close a door"],
	[KEY_A, "ally heel / loose"],
	[KEY_QUESTION, "the legend"],
	[KEY_ESCAPE, "menu"],
]

## The Xbox-style guess. Right for most, wrong for someone, which is the point.
const DEFAULTS := {
	JOY_BUTTON_DPAD_UP: KEY_UP,
	JOY_BUTTON_DPAD_DOWN: KEY_DOWN,
	JOY_BUTTON_DPAD_LEFT: KEY_LEFT,
	JOY_BUTTON_DPAD_RIGHT: KEY_RIGHT,
	JOY_BUTTON_A: KEY_PERIOD,
	JOY_BUTTON_B: KEY_G,
	JOY_BUTTON_X: KEY_I,
	JOY_BUTTON_Y: KEY_X,
	JOY_BUTTON_LEFT_SHOULDER: KEY_F,
	JOY_BUTTON_RIGHT_SHOULDER: KEY_W,
	JOY_BUTTON_START: KEY_ESCAPE,
	JOY_BUTTON_BACK: KEY_QUESTION,
	JOY_BUTTON_LEFT_STICK: KEY_C,
	JOY_BUTTON_RIGHT_STICK: KEY_A,
}

func _init() -> void:
	binds = DEFAULTS.duplicate()

## Binds a button, taking it off whatever it used to do.
##
## One button, one meaning: a pad with A on both "wait" and "pick up" would
## be a bug report nobody could describe.
func bind(button: int, key: int) -> void:
	for b in binds.keys():
		if int(binds[b]) == key:
			binds.erase(b)
	binds[button] = key

func key_for_button(button: int) -> int:
	return int(binds.get(button, 0))

## Which button currently does this, or -1. Drives the "now: button 3" line in
## the rebinding walk-through.
func button_for_key(key: int) -> int:
	for b in binds:
		if int(binds[b]) == key:
			return int(b)
	return -1

func save() -> bool:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return false
	var out := {}
	for b in binds:
		out[str(b)] = int(binds[b])
	f.store_string(JSON.stringify(out))
	f.close()
	return true

## Missing or unreadable falls back to the defaults rather than to nothing --
## a player whose config got corrupted should find a working pad, not a dead
## one.
func load_saved() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY or (parsed as Dictionary).is_empty():
		return
	binds.clear()
	for b in parsed as Dictionary:
		binds[str(b).to_int()] = int((parsed as Dictionary)[b])

func reset() -> void:
	binds = DEFAULTS.duplicate()
