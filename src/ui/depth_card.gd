class_name DepthCard
extends Control

## THE DEPTH CARD (2026-10-10, from the mock-up Brad had made, reworked with
## him): a title card when you walk into a new band of the dungeon -- the
## entrance, the caves, the fortress, the Deep, and each of them again,
## changed, on the climb -- and at the start of every run and every load.
## The floor's number large, the band's name, one line of what the place is
## like. Any key or click dismisses it; it goes by itself after HOLD.
##
## WHAT IT DOES NOT SAY: what lives there. The mock-up listed "you will
## meet"; OFR hides a floor's creatures until torchlight or sound gives
## them away, and the card does not undo that.
##
## Between bands, a new floor gets only its number, briefly, over the map,
## and nothing waits for it: twenty-odd floors a run, and a keypress on every
## one would be a chore. The card itself is five or six a run.
##
## Not shown while `paused` (the title, naming a character): it waits, and
## the floor under them gets its card when they close.

var state: GameState
var paused := false
## Off in the test harnesses and probes (scratch files), as the title is:
## they load the scene and expect to be playing. Its own test turns it on.
var enabled := true
## The full card is up, and takes the next key or click.
var showing := false

## How long the card stays if nothing is pressed, and its fade in and out.
const HOLD := 4.5
const FADE := 0.4
## The number-only label between bands: in, held, out.
const LABEL_TIME := 1.6

## What each band is called, and what it is like. Keyed by band_key: the
## band, and "c" on the climb. One line each, of what you see and smell --
## never of what lives there.
const TITLES := {
	"0": ["THE ENTRANCE", "Daylight is behind you. The smell of the forest is fading."],
	"1": ["THE CAVES", "The walls stop being walls. Water runs somewhere you cannot see."],
	"2": ["THE FORTRESS", "Someone built this, this deep. Someone still keeps it."],
	"3": ["THE DEEP", "The Amulet of the Deep lies on this floor."],
	"2c": ["THE CLIMB  ·  THE FORTRESS", "The halls you came down through. Something has been at them."],
	"1c": ["THE CLIMB  ·  THE CAVES", "The same caves, darker now."],
	"0c": ["THE CLIMB  ·  THE ENTRANCE", "Daylight, somewhere above. Nearly out."],
}

@export var font: Font
@export var font_bold: Font

var _t := 0.0
var _label_t := -1.0
var _last_map: DungeonMap = null
var _last_band := ""
var _depth := 0
var _effective := 1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	if font == null:
		font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
	if font_bold == null:
		font_bold = load("res://assets/fonts/JetBrainsMono-Bold.ttf")

## A band, and whether this is the climb's version of it: "1" the caves on
## the way down, "1c" on the way up.
static func band_key(effective: int) -> String:
	return "%d%s" % [Bands.of(effective), "c" if Bands.is_corrupted(effective) else ""]

static func title_for(effective: int) -> String:
	return String(TITLES.get(band_key(effective), ["", ""])[0])

static func line_for(effective: int) -> String:
	return String(TITLES.get(band_key(effective), ["", ""])[1])

## A new run or a load: its first floor gets the card, whatever the last
## floor of the last run was.
func reset() -> void:
	_last_map = null
	_last_band = ""
	showing = false
	_label_t = -1.0

func dismiss() -> void:
	showing = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _process(delta: float) -> void:
	if state == null or state.map == null or paused or not enabled:
		if paused:
			_last_map = null
		visible = false
		return
	if state.map != _last_map:
		var key := band_key(state.effective_depth())
		_depth = state.depth
		_effective = state.effective_depth()
		if _last_map == null or key != _last_band:
			showing = true
			_t = 0.0
			_label_t = -1.0
			mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			_label_t = 0.0
		_last_map = state.map
		_last_band = key
	if showing:
		_t += delta
		if _t >= HOLD:
			dismiss()
	if _label_t >= 0.0:
		_label_t += delta
		if _label_t >= LABEL_TIME:
			_label_t = -1.0
	visible = showing or _label_t >= 0.0
	if visible:
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if showing and click != null and click.pressed:
		dismiss()
		accept_event()

## How opaque the card is: up over FADE, down over the last FADE. On
## "still", none of that -- it is simply there, then gone.
func _alpha() -> float:
	if not Effects.any():
		return 1.0
	return clampf(minf(_t / FADE, (HOLD - _t) / FADE), 0.0, 1.0)

func _draw() -> void:
	if showing:
		_draw_card(_alpha())
	elif _label_t >= 0.0:
		var a := 1.0
		if Effects.any():
			a = clampf(minf(_label_t / 0.25, (LABEL_TIME - _label_t) / 0.5), 0.0, 1.0)
		draw_string(font_bold, Vector2(0, size.y * 0.16), "DEPTH  %d" % _depth,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 34, Color(Palette.UI_TEXT, a * 0.85))

func _draw_card(a: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.03, 0.04, 0.94 * a), true)
	var mid := size.y * 0.5
	var climb := Bands.is_corrupted(_effective)
	draw_string(font_bold, Vector2(0, mid - 40.0), "DEPTH  %d" % _depth,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 72, Color(Palette.UI_TEXT, a))
	var rule_w := 520.0
	draw_rect(Rect2(Vector2((size.x - rule_w) * 0.5, mid - 12.0), Vector2(rule_w, 3.0)),
		Color(Palette.STAIRS, a), true)
	draw_string(font_bold, Vector2(0, mid + 38.0), title_for(_effective),
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, Color(Palette.CORRUPTED if climb else Palette.STAIRS, a))
	draw_string(font, Vector2(0, mid + 84.0), line_for(_effective),
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color(Palette.UI_DIM, a))
	draw_string(font, Vector2(0, size.y - 60.0), "any key",
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(Palette.STAIRS, a * 0.8))
