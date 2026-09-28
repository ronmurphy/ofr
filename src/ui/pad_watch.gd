class_name PadWatch
extends Control

## WHAT GODOT SEES FROM THE CONTROLLER, drawn over the game. F8 shows and hides it.
##
## Exists because of Firefox. An Xbox Wireless pad there puts its right stick
## somewhere odd, and two fixes written from what the BROWSER reports (see
## ofr-hunt/tools/pad-check.html) both failed on itch: Godot's web layer remaps
## the browser's axes again before the game sees them, so the browser's view is
## one step removed from the only view that matters. This is that view.
##
## On screen rather than in a file, which is what the older `--pad-log` does,
## because a browser build's user:// is the page's own storage and nobody can
## open it. A screenshot of this is the whole report.
##
## Reads device 0 -- the one the game reads -- and lists every connected pad, so
## a controller arriving as device 1 shows up as a mismatch rather than silence.

const AXES := 10         # JOY_AXIS_MAX
const BUTTONS := 21      # JOY_BUTTON_SDL_MAX
## How far an axis has to have travelled before its row is marked as moved.
## A resting stick jitters by a few hundredths; a push covers most of the range.
## Under 0.5 because Firefox's right stick rests at 0.5 on a 0..1 value, so one
## push in one direction travels exactly 0.5.
const MOVED := 0.4
const AXIS_NAMES := ["left X", "left Y", "right X", "right Y", "LT", "RT"]
const EVENTS_KEPT := 6

var font: Font
var font_size := 15
## What the 3D camera read this frame, written by main.gd -- so the screenshot
## shows both what arrived and what the camera made of it.
var camera_line := ""

var _mins := PackedFloat32Array()
var _maxs := PackedFloat32Array()
var _now := PackedFloat32Array()
## The same ranges from EVENTS rather than polling. In Firefox they disagree --
## the reason this column exists.
var _ev_mins := PackedFloat32Array()
var _ev_maxs := PackedFloat32Array()
var _ever: Dictionary = {}           # button index -> true once pressed
var _events: Array[String] = []
var _browser := ""

const PAD := 12.0
const LINE := 20.0
const WIDTH := 780.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	if font == null:
		font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
	_browser = Platform.browser()
	reset()

func toggle() -> void:
	visible = not visible
	if visible:
		reset()

## Forget every range and event. Opening the overlay starts a fresh measurement,
## so an old push cannot be mistaken for a new one.
func reset() -> void:
	for arr in [_mins, _maxs, _now, _ev_mins, _ev_maxs]:
		arr.resize(AXES)
	for i in AXES:
		_mins[i] = INF
		_maxs[i] = -INF
		_ev_mins[i] = INF
		_ev_maxs[i] = -INF
		_now[i] = 0.0
	_ever.clear()
	_events.clear()

## One frame's axis values. Separate from _process so the tests can feed it.
func sample(values: PackedFloat32Array) -> void:
	for i in mini(AXES, values.size()):
		_now[i] = values[i]
		_mins[i] = minf(_mins[i], values[i])
		_maxs[i] = maxf(_maxs[i], values[i])

## One reported value. Separate from _input so the tests can feed it.
func sample_event(axis: int, value: float) -> void:
	if axis >= 0 and axis < AXES:
		_ev_mins[axis] = minf(_ev_mins[axis], value)
		_ev_maxs[axis] = maxf(_ev_maxs[axis], value)

## Moved by either measure: polled, or as its events reported.
func moved(axis: int) -> bool:
	return _maxs[axis] - _mins[axis] > MOVED \
		or _ev_maxs[axis] - _ev_mins[axis] > MOVED

## "Firefox/131.0" out of a whole user-agent string. Edge claims to be Chrome
## as well, so it is looked for first.
static func browser_from(ua: String) -> String:
	for tag in ["Firefox/", "Edg/", "Chrome/", "Safari/"]:
		var at := ua.find(tag)
		if at >= 0:
			var end := ua.find(" ", at)
			return ua.substr(at, (end - at) if end >= 0 else -1)
	return ua.left(40)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	var button := event as InputEventJoypadButton
	if button != null and button.pressed:
		_ever[button.button_index] = true
		_note("device %d  button %d" % [button.device, button.button_index])
		return
	var motion := event as InputEventJoypadMotion
	if motion != null and motion.device == 0:
		sample_event(int(motion.axis), motion.axis_value)
	# The decisive part of a push only. Axes report continuously, and a list of
	# every intermediate value would scroll away the one that mattered.
	if motion != null and absf(motion.axis_value) > 0.85:
		_note("device %d  axis %d at %+.2f" % [motion.device, motion.axis,
			motion.axis_value])

func _note(line: String) -> void:
	if not _events.is_empty() and _events[-1] == line:
		return
	_events.append(line)
	while _events.size() > EVENTS_KEPT:
		_events.pop_front()

func _process(_delta: float) -> void:
	if not visible:
		return
	var values := PackedFloat32Array()
	for i in AXES:
		values.append(Input.get_joy_axis(0, i))
	sample(values)
	queue_redraw()

func _draw() -> void:
	var pads := Input.get_connected_joypads()
	var lines := 6 + 2 * maxi(1, pads.size()) + AXES + EVENTS_KEPT
	draw_rect(Rect2(0, 0, WIDTH, PAD * 2 + LINE * lines + 18),
		Color(0.03, 0.03, 0.05, 0.90))
	var y := PAD + LINE * 0.8
	var gold := Color(0.91, 0.72, 0.42)
	var dim := Color(0.55, 0.55, 0.58)
	var on := Color(0.56, 0.84, 0.71)
	var text := Color(0.85, 0.83, 0.78)
	_text("PAD WATCH  --  what Godot sees (polled, then ev = from events).  F8 hides.",
		PAD, y, gold)
	y += LINE
	_text("%s %s  %s" % [OS.get_name(), Engine.get_version_info().get("string", "?"),
		_browser], PAD, y, dim)
	y += LINE
	if pads.is_empty():
		_text("no pad connected -- press a button on it", PAD, y, gold)
		y += LINE
	for id in pads:
		_text("pad %d: %s" % [id, Input.get_joy_name(id)], PAD, y, text)
		y += LINE
		_text("   guid %s" % Input.get_joy_guid(id), PAD, y, dim)
		y += LINE
	y += 4
	for i in AXES:
		var label := "axis %d %-7s" % [i, AXIS_NAMES[i] if i < AXIS_NAMES.size() else ""]
		var hot := moved(i)
		_text(label, PAD, y, on if hot else text)
		# A bar centred on zero, so a resting 0.5 stands out from a resting 0.
		var bx := PAD + 170.0
		var bw := 160.0
		draw_rect(Rect2(bx, y - 11, bw, 10), Color(0.14, 0.14, 0.18))
		draw_line(Vector2(bx + bw / 2, y - 12), Vector2(bx + bw / 2, y), dim)
		var v := clampf(_now[i], -1.0, 1.0)
		var fill_from := bx + bw / 2 + minf(v, 0.0) * bw / 2
		draw_rect(Rect2(fill_from, y - 10, absf(v) * bw / 2, 8), Color(0.23, 0.45, 1.0))
		var seen := "" if _mins[i] == INF else "%+.2f..%+.2f" % [_mins[i], _maxs[i]]
		var ev := "--" if _ev_mins[i] == INF else "%+.2f..%+.2f" % [_ev_mins[i], _ev_maxs[i]]
		_text("%+.2f  %s  ev %s%s" % [_now[i], seen, ev, "  moved" if hot else ""],
			bx + bw + 10, y, on if hot else text)
		y += LINE
	y += 4
	# Buttons 0-20: filled while held, outlined once pressed at all.
	var x := PAD
	for b in BUTTONS:
		var r := Rect2(x, y - 14, 25, 20)
		if Input.is_joy_button_pressed(0, b):
			draw_rect(r, on)
			_text(str(b), x + 3, y, Color(0.05, 0.05, 0.06))
		else:
			draw_rect(r, on if _ever.has(b) else Color(0.25, 0.25, 0.30), false, 1.0)
			_text(str(b), x + 3, y, on if _ever.has(b) else dim)
		x += 27
	y += LINE + 6
	_text(camera_line if camera_line != "" else "camera: not in the 3D view",
		PAD, y, gold)
	y += LINE + 4
	_text("last events:", PAD, y, dim)
	y += LINE
	for e in _events:
		_text("  " + e, PAD, y, text)
		y += LINE

func _text(s: String, x: float, y: float, c: Color) -> void:
	draw_string(font, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, c)
