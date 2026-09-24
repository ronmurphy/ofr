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
	## BOUND NOW, to d-pad up. This used to say the map could never have a
	## button because every one was spoken for, and that stopped being true
	## when `g` became the action key: a tile knows whether its stairs go up
	## or down, so the dedicated ascend and pray buttons became redundant and
	## d-pad up was the first thing freed. Brad's call on what to spend it on.
	##
	## `<` is still in this list and still works on a keyboard -- it is simply
	## no longer worth a button, which is different from being removed.
	[KEY_O, "the map"],
	[KEY_ESCAPE, "menu"],

	## THE D-PAD'S NEW JOB, and the reason it has one.
	##
	## Measured 2026-09-21: a controller could not reach descend, ascend, pray
	## or the torch AT ALL. Every button is translated into a bare keycode --
	## main.gd `_press` builds an InputEventKey with no modifiers -- so the two
	## stairs actions, which want shift+period and shift+comma, were impossible
	## however they were bound. `p` and `t` were not even in this list to bind.
	## A pad-only handheld could not leave floor one.
	##
	## Brad's fix, and it is better than overloading a face button: THE LEFT
	## STICK ALREADY WALKS, in all eight directions, straight off the axes and
	## with no binding involved (`Gamepad.stick_key`). The d-pad was only ever
	## the four cardinals, a strict subset of what the stick already did, so
	## spending it on movement was spending it twice. These four are what it
	## buys instead.
	##
	## Down descends and up ascends because the staircase is the thing you are
	## standing on, and no contextual rule is needed to say which -- two keys
	## that already exist, `>` and `<`, doing exactly what they always did.
	[KEY_GREATER, "go down stairs"],
	[KEY_LESS, "go up stairs"],
	[KEY_T, "torch on / off"],
	[KEY_P, "pray at a shrine"],
]

## The Xbox-style guess. Right for most, wrong for someone, which is the point.
## What to CALL a button, rather than what number it is.
##
## Reported from play: the screen read "button 12", which tells a player
## nothing. It is a lookup rather than a guess because Godot normalises every
## pad it recognises to this layout through SDL's controller database -- so
## index 0 really is A on an Xbox pad, on a Steam Deck and on a Legion Go, and
## Cross on a PlayStation pad. The numbers in a bug report decode the same way.
##
## Xbox naming because that is what the handhelds copy. A PlayStation pad shows
## the same positions under different names, which is a per-device refinement
## worth having later and not worth guessing at now.
const BUTTON_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Back", JOY_BUTTON_GUIDE: "Guide",
	JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down",
	JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right",
}

## What to CALL a KEY on screen.
##
## `OS.get_keycode_string` is built for settings dialogs and answers "Period",
## "Question", "Greater". Printed in a hint that says "press this", those read as
## instructions to type the word -- seen in play, the panel said `period  warm
## yourself`. Punctuation wants to be shown as itself; letters are fine as they
## come back.
const KEY_NAMES := {
	KEY_PERIOD: ".", KEY_COMMA: ",", KEY_QUESTION: "?",
	KEY_GREATER: ">", KEY_LESS: "<", KEY_SLASH: "/",
	KEY_SEMICOLON: ";", KEY_MINUS: "-", KEY_EQUAL: "=",
	KEY_ESCAPE: "esc", KEY_ENTER: "enter", KEY_KP_ENTER: "enter",
	KEY_TAB: "tab", KEY_SPACE: "space", KEY_BACKSPACE: "backspace",
}

static func key_name(key: int) -> String:
	if KEY_NAMES.has(key):
		return String(KEY_NAMES[key])
	return OS.get_keycode_string(key).to_lower()

## The PICTURE of each button, as a codepoint in Kenney's Xbox Series font.
##
## Xbox rather than Steam Deck or PlayStation, by Brad's reasoning: PC pad
## players are overwhelmingly on an Xbox or Steam controller, the Deck puts the
## same letters in the same places, and every label in this game already uses
## Xbox NAMES. Start and Back are drawn as the Series controller's Menu and View
## icons, because that is what is printed on the buttons being pressed.
##
## These are private-use codepoints and they mean something ONLY in that font --
## Kenney's Steam Deck file uses the very same numbers for different pictures --
## so a string carrying one must be drawn through PadGlyphs, never handed to
## the text font and hoped for.
const GLYPH_FONT := "res://assets/fonts/kenney_input_xbox_series.ttf"
const BUTTON_GLYPHS := {
	JOY_BUTTON_A: 0xE004, JOY_BUTTON_B: 0xE006,
	JOY_BUTTON_X: 0xE01E, JOY_BUTTON_Y: 0xE020,
	JOY_BUTTON_LEFT_SHOULDER: 0xE043, JOY_BUTTON_RIGHT_SHOULDER: 0xE049,
	JOY_BUTTON_START: 0xE014, JOY_BUTTON_BACK: 0xE01C,
	JOY_BUTTON_LEFT_STICK: 0xE053, JOY_BUTTON_RIGHT_STICK: 0xE05B,
	JOY_BUTTON_DPAD_UP: 0xE035, JOY_BUTTON_DPAD_DOWN: 0xE024,
	JOY_BUTTON_DPAD_LEFT: 0xE028, JOY_BUTTON_DPAD_RIGHT: 0xE02B,
}
## The left stick itself, for "move" -- it is not a button and has no index.
const STICK_GLYPH := 0xE04F

## Is this character one of the button pictures above?
static func is_glyph(cp: int) -> bool:
	return cp == STICK_GLYPH or BUTTON_GLYPHS.values().has(cp)

## Like `label`, but a PICTURE of the button when a pad is in hand and one
## exists. Falls back to the name, then to the keyboard key, so it never goes
## blank. Anything drawing the result must go through PadGlyphs.
func icon(key: int, on_pad: bool) -> String:
	if on_pad:
		var button := button_for_key(key)
		if button >= 0 and BUTTON_GLYPHS.has(button):
			return String.chr(int(BUTTON_GLYPHS[button]))
	return label(key, on_pad)

## What to show the player for this action, in the language of what they hold.
##
## An instance method because it needs the LIVE bindings: on a pad, `?` is
## whatever button the legend currently sits on, and that is rebindable.
##
## `on_pad` is the device last USED, not what is plugged in -- a Steam Deck's
## controller is part of the hardware and permanently connected, so asking the
## other question labels the screen with buttons while somebody types.
##
## Here rather than in a panel because two panels now ask it, and a second copy
## is how the two would start disagreeing.
func label(key: int, on_pad: bool) -> String:
	if on_pad:
		var button := button_for_key(key)
		if button >= 0:
			return button_name(button)
	return key_name(key)

## A name if we have one, the raw index if we do not.
##
## The fallback matters: a pad SDL does not recognise reports indices this table
## has never heard of, and "button 17" is at least true. A wrong name would be
## worse than a number.
static func button_name(index: int) -> String:
	return String(BUTTON_NAMES.get(index, "button %d" % index))

const DEFAULTS := {
	## NOT movement. The stick does that already and does it better -- eight
	## directions against four, and hardcoded rather than bound, so this cannot
	## strand anybody who rebinds. See the note in WALK.
	##
	## Still offered by the walk-through as "move up/down/left/right", so a
	## player who wants the d-pad back can have it; they are simply not bound
	## here any more.
	JOY_BUTTON_DPAD_DOWN: KEY_GREATER,
	JOY_BUTTON_DPAD_UP: KEY_O,
	JOY_BUTTON_DPAD_LEFT: KEY_T,
	JOY_BUTTON_DPAD_RIGHT: KEY_P,
	JOY_BUTTON_A: KEY_PERIOD,
	JOY_BUTTON_B: KEY_G,
	JOY_BUTTON_X: KEY_I,
	JOY_BUTTON_Y: KEY_X,
	JOY_BUTTON_LEFT_SHOULDER: KEY_F,
	JOY_BUTTON_RIGHT_SHOULDER: KEY_W,
	JOY_BUTTON_START: KEY_ESCAPE,
	## The legend. A candidate to give up if the map should have a button by
	## default: both are reference screens you read between fights, and the
	## map is the one you want repeatedly on a floor while the legend is
	## mostly read once. Brad's call, not made yet.
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
