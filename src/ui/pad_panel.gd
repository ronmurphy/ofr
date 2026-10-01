class_name PadPanel
extends Control

## "Press a button for: move up."
##
## Exists because four people asked for controller support in one night on four
## different devices, and no table written here could be right for all of them.
## The walk-through asks the controller what it calls itself instead of
## assuming.
##
## It reads JOYPAD events directly -- the only panel in the game that does.
## Everything else speaks keycodes, which is the whole design of `Gamepad`; but
## this is the one place that has to see the raw button index, because learning
## that index is its entire job.

signal closed()
signal log_requested()

@export var font: Font
@export var font_bold: Font
@export var font_size: int = 17

## The exported default, reachable without a node -- the same seam MenuPanel
## and SummaryPanel already have, and for the same reason: the height check
## needs the size the panel actually draws at, and an @export is not a
## constant. Writing the literal 17 into the test instead would put the layout
## in the hands of a number maintained by hand in two places, which is the
## pattern that overflowed both this panel and the pause menu in one hour.
static func font_size_default() -> int:
	return 17

## TWO COLUMNS, and the width is the point rather than the height.
##
## Brad's call, from a screenshot: at fourteen rows the single column was a
## 560px tower on a 900px canvas, and the footer had run one pixel past the
## edge -- which the height assertion could not see, because it measures the
## rows and never measured the footer. Splitting the list halves the height,
## widens the panel enough for the footer to breathe, and leaves room for
## roughly 28 bindings, which is more than a controller has buttons.
##
## Sized from the content: the widest row is "swap reach / blade" with a
## "button 12" right-aligned against it, measured at 327px, so a 350px column
## holds anything the walk-through is likely to name.
## Height chosen by hand for 19 rows, not computed: the guard in the suite is
## meant to FAIL when the walk-through grows, so that somebody looks at the
## panel rather than letting it silently resize past the screen. It grew from
## 400 to 460 on 2026-09-22 when the d-pad picked up four actions -- stairs
## both ways, the torch and praying -- at 10 rows in the taller column.
## 460 leaves about 25px of slack; the next addition will fail here again, and
## should.
## 472 on 2026-10-01 (the screens review): the two footers became rows of
## keycaps, which stand 20px tall, and the second one ran 2px past 460.
const PANEL := Vector2(820.0, 472.0)
const COL_GAP := 44.0

## Rows in the left column. The right column takes the remainder, so an odd
## count leaves the extra on the left and the columns stay top-aligned.
static func left_rows() -> int:
	return int(ceil(PadConfig.WALK.size() / 2.0))
## Measured by the suite rather than eyeballed: this panel shipped with a
## footer 39px past its own edge, and the height guard sitting above it said
## nothing because a guard on one axis says nothing about the other.
const KEY_FOOTER := "backspace  back     r  defaults     l  log this pad     esc  done"
## The same footer as caps: [key, what it does]. KEY_FOOTER above is what the
## suite measures and the words these are drawn from, so the two cannot
## disagree without a test noticing.
const KEY_FOOT := [["backspace", "back"], ["r", "defaults"], ["l", "log this pad"],
	["esc", "done"]]

## Built from the LIVE binding rather than written out, so it cannot claim a
## button that does not do that any more.
static func pad_footer() -> String:
	return "%s  rebind     %s  defaults     %s  done" % [
		PadConfig.button_name(JOY_BUTTON_Y),
		PadConfig.button_name(JOY_BUTTON_BACK),
		PadConfig.button_name(JOY_BUTTON_START)]

## The pad's footer as caps: the button's picture and its name in each.
static func pad_foot() -> Array:
	return [[button_cap(JOY_BUTTON_Y), "rebind"], [button_cap(JOY_BUTTON_BACK), "defaults"],
		[button_cap(JOY_BUTTON_START), "done"]]

## A button as a cap's label: its picture, then its name, so the cap reads
## on a pad that has no pictures in this font too.
static func button_cap(index: int) -> String:
	var name := PadConfig.button_name(index)
	if PadConfig.BUTTON_GLYPHS.has(index):
		return "%s %s" % [String.chr(int(PadConfig.BUTTON_GLYPHS[index])), name]
	return name

const PAD := 26.0
const ROW_H := 30.0

## The rows as drawn: {label, said, cap, dashed, tint}. Not WALK itself, for
## one reason (the screens review): the four move rows read as four unbound
## actions, "move up  --", when the stick moves you. While nothing is bound to
## them and nobody is rebinding, they are ONE row, "move", with the stick in
## its cap. Walking through a rebind shows all four, as the walk asks them.
func display_rows() -> Array:
	var out: Array = []
	var moves_bound := false
	for i in 4:
		if cfg != null and cfg.button_for_key(int(PadConfig.WALK[i][0])) >= 0:
			moves_bound = true
	var collapse := not _listening and not moves_bound
	for i in PadConfig.WALK.size():
		var row: Array = PadConfig.WALK[i]
		if collapse and i < 4:
			if i == 0:
				out.append({"label": "move", "said": "%s left stick" % String.chr(PadConfig.STICK_GLYPH),
					"cap": true, "dashed": false, "tint": Color(0.60, 0.72, 0.60)})
			continue
		var state := row_state(i)
		var live := state == &"live"
		var tint := Color(0.95, 0.82, 0.45) if live else Color(0.78, 0.76, 0.80)
		if state == &"done":
			tint = Color(0.60, 0.72, 0.60)
		elif state == &"lost":
			tint = LOST_TINT
		var has := cfg.button_for_key(int(row[0])) if cfg != null else -1
		var said := "--"
		var cap := false
		var dashed := false
		if live:
			said = "press a button"
		elif has >= 0:
			said = button_cap(has)
			cap = true
		elif state == &"lost":
			said = "not bound"
			cap = true
			dashed = true
		out.append({"label": String(row[1]), "said": said, "cap": cap, "dashed": dashed,
			"tint": tint})
	return out

var cfg: PadConfig
var _at := 0
## Set while waiting for a press, so a player can see which row is live.
var _listening := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	if font == null:
		font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
	if font_bold == null:
		font_bold = load("res://assets/fonts/JetBrainsMono-Bold.ttf")

## Opens SHOWING, not listening.
##
## Reported from play on a Legion Go S: this screen used to begin capturing the
## moment it opened, so a player who came to look at their bindings rebound
## "move up" to whatever they pressed next -- and the way out is keyboard-only,
## by an earlier decision, so on a handheld there was no way to stop. Brad had
## to quit through the Steam overlay.
##
## The keyboard-only exit was right for a DEAD pad and wrong for a live one. A
## screen that reads your bindings back is the common case; rebinding is the
## rare one, and it now has to be asked for.
func open(config: PadConfig) -> void:
	cfg = config
	_at = 0
	_listening = false
	visible = true
	queue_redraw()

func close() -> void:
	visible = false
	if cfg != null:
		cfg.save()
	closed.emit()

## A joypad press, while this is open, means "bind that to the current row".
## Answers whether it was used.
func handle_pad(event: InputEvent) -> bool:
	if not visible:
		return false
	var button := event as InputEventJoypadButton
	if button == null or not button.pressed:
		return false
	# Not listening: the first press ASKS to rebind rather than rebinding. So a
	# player can open this, read what their pad does, and leave without having
	# changed anything -- which is what they came for most of the time.
	#
	# TWO BUTTONS WORK HERE, and they are the reason this screen stopped being a
	# one-way door.
	#
	# Reported from play on a Legion Go S, 2026-09-22: main.gd hands joypad
	# events to this panel BEFORE translating them, so while it is open every
	# button is swallowed by the walk-through. Start could not close it because
	# Start was just another button to bind, and the footer's four ways out --
	# backspace, r, l, esc -- are all keyboard keys on a device with no
	# keyboard. Brad could not leave without the Steam overlay.
	#
	# The keyboard-only rule above it was written for a DEAD pad, and it still
	# holds: a controller that sends nothing cannot press Start either, so the
	# keyboard hatch has to stay. These are not alternatives. One serves a
	# broken pad, the other a missing keyboard, and neither case covers the
	# other.
	#
	# Reserved ONLY while not listening. Once the walk-through is running every
	# button binds, including these two -- otherwise Start could never be
	# assigned to anything, and reaching the "menu" row and pressing the
	# obvious button would quit instead of binding it. The walk-through always
	# ends by itself after WALK.size() presses, so this can never trap anyone.
	if not _listening:
		# REBINDING IS ASKED FOR, NOT STUMBLED INTO.
		#
		# Reported from play by two people independently -- Stephanie twice,
		# Brad once. Opening this screen and pressing ANY button began the
		# walk-through, so anyone who came to check what their pad does
		# rebound "move up" to whatever they touched. Reading your bindings is
		# the common case; changing them is the rare one, and the rare one
		# should be the one that costs a deliberate press.
		#
		# Y because it is the only face button not already spoken for here, and
		# the footer names it -- a reserved button nobody is told about is no
		# better than none.
		if button.button_index == JOY_BUTTON_Y:
			_listening = true
			_at = 0
			queue_redraw()
			return true
		if button.button_index == JOY_BUTTON_START:
			close()
			return true
		if button.button_index == JOY_BUTTON_BACK:
			# The stale-config escape hatch, and the reason it had to be here.
			# `load_saved` clears the defaults and takes the file wholesale, so
			# anyone who ever ran the walk-through keeps their old bindings
			# forever -- which is how four testers ended up unable to reach the
			# stairs after the d-pad was given new work. `r` fixed it and `r`
			# needs a keyboard.
			cfg.reset()
			cfg.save()
			_at = 0
			queue_redraw()
			return true
		# Anything else is inert. This is the whole fix: a player exploring
		# their controller on this screen changes nothing by doing so.
		return true
	if _at >= PadConfig.WALK.size():
		close()
		return true
	cfg.bind(button.button_index, int(PadConfig.WALK[_at][0]))
	_at += 1
	if _at >= PadConfig.WALK.size():
		_listening = false
	queue_redraw()
	return true

## Keys drive the panel itself: escape leaves, backspace steps back, r resets.
## Deliberately keyboard-only -- a player rebinding a broken controller cannot
## be asked to use that controller to get out.
func handle_key(key: int) -> bool:
	if not visible:
		return false
	match key:
		KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER:
			close()
		KEY_BACKSPACE:
			_at = maxi(0, _at - 1)
			_listening = true
		KEY_R:
			cfg.reset()
			_at = 0
			_listening = true
		KEY_L:
			# The escape hatch for a pad nobody can identify: start recording
			# what it sends, so a tester can send the file back rather than
			# describing the buttons in prose.
			log_requested.emit()
	queue_redraw()
	return true

## A finished row whose button was taken by a later one. Warm red rather than
## the finished green, and never colour alone: the row also says "unbound".
const LOST_TINT := Color(0.90, 0.52, 0.42)

## What row `i` of the walk-through is right now: &"live" (waiting for a
## press), &"todo" (not reached), &"done" (reached and bound) or &"lost".
##
## LOST is the reason this exists. `PadConfig.bind` gives each key one button
## and each button one key, so pressing a button again further down the list
## MOVES it -- which is how you correct a mistake, and is kept. But the action
## it came off is left with no button at all, and that row used to stay green,
## the "done" colour, beside a "--". Found in the 2026-09-27 hunt: the worst
## case is pick-up, because the pack, the conversation and the counter all go
## back on whatever button picks up (`MainScene.PACK_BACK_KEY`), so orphaning
## it took the way out of all three -- and their footers then offered "G" to
## someone holding a controller.
##
## A method rather than inline in _draw so the suite can ask it directly.
func row_state(i: int) -> StringName:
	if i == _at and _listening:
		return &"live"
	if i >= _at:
		return &"todo"
	var key := int(PadConfig.WALK[i][0])
	if cfg == null or cfg.button_for_key(key) >= 0:
		return &"done"
	# Passed, and nothing does it now. That is only a LOSS if the action needs
	# a button. Movement does not: DEFAULTS leaves it unbound on purpose because
	# the stick sends the arrows by itself, so a move row with no button is
	# working, not broken. Everything the defaults DO bind needs one.
	#
	# Keyed on the defaults rather than on "was it bound during this walk"
	# because the walk can only pass a row by binding it (`_at` advances only
	# after `cfg.bind`), so today the two agree -- but this one stays right if
	# a way to skip a row is ever added, and needs no state to be kept in step.
	return &"lost" if PadConfig.DEFAULTS.values().has(key) else &"done"

func _draw() -> void:
	var at := (size - PANEL) * 0.5
	draw_rect(Rect2(at, PANEL), Color(0.07, 0.07, 0.09, 0.97), true)
	draw_rect(Rect2(at, PANEL), Color(0.38, 0.36, 0.42), false, 2.0)

	var y := at.y + PAD + font_size
	draw_string(font_bold, Vector2(at.x + PAD, y), "CONTROLLER",
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.92, 0.88, 0.70))
	y += ROW_H

	# Three states, not two: showing what you have, walking through a rebind,
	# and finished. The first is new -- it used to open straight into the walk.
	# Not "any button" any more -- that was the bug two people hit. The footers
	# below name the three that do something; this says what the screen is for.
	var note := "your controller, as it stands     nothing changes until you ask"
	if _listening and _at < PadConfig.WALK.size():
		note = "press a button for each line"
	elif _listening:
		note = "all set -- enter to finish"
	draw_string(font, Vector2(at.x + PAD, y), note,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 3, Color(0.68, 0.66, 0.72))
	y += ROW_H

	# Two columns, filled down the left and then down the right, so the reading
	# order matches the order the walk-through asks in. Filling across would
	# put "move up" and "move down" side by side and the eye would follow the
	# wrong one.
	var rows := display_rows()
	var split := int(ceil(rows.size() / 2.0))
	var col_w := (PANEL.x - PAD * 2.0 - COL_GAP) * 0.5
	var top := y
	for i in rows.size():
		var row: Dictionary = rows[i]
		var col := 0 if i < split else 1
		var col_x: float = at.x + PAD + float(col) * (col_w + COL_GAP)
		var row_y: float = top + float(i - (split if col == 1 else 0)) * ROW_H
		var tint: Color = row["tint"]
		draw_string(font, Vector2(col_x, row_y), String(row["label"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)
		# Right-aligned within its own column rather than the panel, or the
		# left column's bindings would sit in the right column's labels. A
		# binding is a cap; "not bound" a dashed one; the rest plain words.
		var said := String(row["said"])
		if bool(row["cap"]):
			var w := Keycap.width(said, font, font_size)
			Keycap.draw(self, Vector2(col_x + col_w - w, row_y), said, font, font_size,
				tint, bool(row["dashed"]))
		else:
			draw_string(font, Vector2(col_x, row_y), said,
				HORIZONTAL_ALIGNMENT_RIGHT, col_w, font_size, tint)

	# The footers sit under the LONGEST possible column, not the drawn one,
	# so collapsing the move rows never moves them about.
	y = top + float(left_rows()) * ROW_H + 6.0
	_draw_foot(Vector2(at.x + PAD, y), KEY_FOOT, Color(0.58, 0.56, 0.62))

	# The pad's own way out, said in the pad's own words.
	#
	# BOTH footers are always drawn, rather than choosing one by asking whether
	# a controller is connected. That question has already lied once: the
	# diagnostic log asks it at startup, before Steam's virtual pad has
	# enumerated, and printed "NO PAD CONNECTED" on a machine holding a working
	# controller. A line of text is cheaper than being wrong about which device
	# somebody is holding.
	#
	# Hidden mid-walk-through because it is not true then: every button binds
	# while listening, including these two.
	if not _listening:
		_draw_foot(Vector2(at.x + PAD, y + 24.0), pad_foot(), Color(0.55, 0.62, 0.72))

## A footer of caps and what each does, left to right.
func _draw_foot(pos: Vector2, foot: Array, tint: Color) -> void:
	var x := pos.x
	var fs := font_size - 4
	for pair in foot:
		x += Keycap.draw(self, Vector2(x, pos.y), String(pair[0]), font, fs, tint) + 6.0
		draw_string(font, Vector2(x, pos.y), String(pair[1]), HORIZONTAL_ALIGNMENT_LEFT,
			-1, fs, tint)
		x += font.get_string_size(String(pair[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 18.0

## The width a footer takes, for the suite.
func foot_width(foot: Array) -> float:
	var x := 0.0
	var fs := font_size - 4
	for pair in foot:
		x += Keycap.width(String(pair[0]), font, fs) + 6.0
		x += font.get_string_size(String(pair[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 18.0
	return x - 18.0
