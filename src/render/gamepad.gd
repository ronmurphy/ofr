class_name Gamepad
extends RefCounted

## A controller, spoken as keystrokes.
##
## Every panel in this game already reads KEYCODES -- the map, the inventory,
## the menu, the legend, the summary, the name entry, seven files in all. So
## rather than teach each of them about joypads, this turns a joypad event into
## the key it stands for and hands that back. Press B on a pad and the
## inventory receives KEY_G exactly as though you had typed it, and nothing
## downstream needs to know a controller exists.
##
## The alternative was Godot's InputMap with named actions bound to both a key
## and a button. That is the tidier long-term answer and it would give keyboard
## rebinding for free -- but it means rewriting the input handling in all seven
## files, and this gets a handheld playable in one.
##
## BUTTON INDICES VARY BY DEVICE. What a pad calls button 3 is not fixed across
## manufacturers, so `diagnostic` prints what actually arrives. Turn it on,
## press everything, and write the table from the log rather than from hope.

## Records every joypad event instead of acting on it.
##
## Written to a FILE as well as to stdout, because the machines this matters on
## are handhelds launched through Steam, where stdout goes somewhere nobody can
## reach. A tester who cannot get the log off the device cannot tell you what
## their controller is called, which is the only thing this mode is for.
var diagnostic := false

const LOG_PATH := "user://pad_log.txt"
var _log: FileAccess = null

func start_log() -> void:
	diagnostic = true
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	_say("OFR controller log -- press every button, then every direction")
	_say("godot %s on %s" % [Engine.get_version_info().get("string", "?"),
		OS.get_name()])
	for id in Input.get_connected_joypads():
		_say("pad %d: %s (%s)" % [id, Input.get_joy_name(id),
			Input.get_joy_guid(id)])
	if Input.get_connected_joypads().is_empty():
		_say("NO PAD CONNECTED -- nothing will be recorded")

func _say(line: String) -> void:
	print("[pad] %s" % line)
	if _log != null:
		_log.store_line(line)
		# Flushed every line: a handheld that is force-quit still leaves a
		# readable log, and force-quit is how these sessions usually end.
		_log.flush()

## WHAT THIS PARTICULAR PAD CALLS ITS BUTTONS. Held in a config rather than a
## constant here, because four people on four different handhelds asked for
## this in one night and no fixed table can be right for all of them. See
## PadConfig for the defaults and the rebinding walk-through.
var cfg := PadConfig.new()

## Where the stick has to reach before it counts as a direction at all.
##
## Generous, because a turn-based game would rather miss a lazy nudge than take
## a step nobody asked for. A misread here costs a turn of game time, which in
## this game can cost a run.
const STICK_DEADZONE := 0.6

## Auto-repeat while the stick is held, in seconds: the first step is instant,
## and then it walks.
##
## Without this a held stick fires once per frame -- sixty moves a second in a
## game where one move can be fatal. The d-pad needs none of this because it
## sends one event per press.
const STICK_FIRST := 0.35
const STICK_AGAIN := 0.12

var _dir := Vector2i.ZERO
var _hold := 0.0
var _walked := false

## The eight directions, as the arrow and diagonal keys the map already reads.
const STICK_KEYS := {
	Vector2i(0, -1): KEY_UP, Vector2i(0, 1): KEY_DOWN,
	Vector2i(-1, 0): KEY_LEFT, Vector2i(1, 0): KEY_RIGHT,
	Vector2i(-1, -1): KEY_Y, Vector2i(1, -1): KEY_U,
	Vector2i(-1, 1): KEY_B, Vector2i(1, 1): KEY_N,
}

## What key this joypad event stands for, or 0 for nothing.
func key_for(event: InputEvent) -> int:
	var button := event as InputEventJoypadButton
	if button != null:
		if diagnostic:
			if button.pressed:
				_say("button %d" % button.button_index)
			return 0
		if not button.pressed:
			return 0
		return cfg.key_for_button(button.button_index)
	if diagnostic:
		var motion := event as InputEventJoypadMotion
		# Only the decisive end of a push. An axis reports continuously, and a
		# log of every intermediate value is unreadable.
		if motion != null and absf(motion.axis_value) > 0.85:
			_say("axis %d at %+.2f" % [motion.axis, motion.axis_value])
	return 0

## Called every frame with the stick's position. Answers the key to send, or 0.
##
## Reading the axes directly rather than from events, because a stick held
## still emits nothing -- and "still held" is exactly the state auto-repeat
## needs to know about.
func stick_key(delta: float) -> int:
	var raw := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	var want := Vector2i.ZERO
	if raw.length() >= STICK_DEADZONE:
		# Quantised to eight, the same eight the keyboard has. A roguelike grid
		# has no use for an angle.
		want = Vector2i(signi(int(round(raw.x))), signi(int(round(raw.y))))
		if want == Vector2i.ZERO:
			want = Vector2i(signi(int(raw.x * 2.0)), signi(int(raw.y * 2.0)))

	if want == Vector2i.ZERO:
		_dir = Vector2i.ZERO
		_walked = false
		return 0
	if want != _dir:
		_dir = want
		_hold = 0.0
		_walked = true
		return STICK_KEYS.get(want, 0)
	_hold += delta
	if _hold >= (STICK_AGAIN if _walked else STICK_FIRST):
		_hold = 0.0
		_walked = true
		return STICK_KEYS.get(want, 0)
	return 0
