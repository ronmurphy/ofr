class_name TitleScreen
extends Control

## THE FRONT DOOR. Brad's design, 2026-09-28:
##
##   - behind everything, a generated dungeon, revealed and faded the way the
##     map remembers a floor, with its monsters standing in it;
##   - in front of that, the retirement home in the 3D view's own style --
##     three heroes and the traveller, no monsters -- the camera circling it;
##   - down the side: new game, settings, the Legends Run once it is unlocked,
##     and exit.
##
## Continue sits at the top whenever a run is suspended, because before this
## screen existed a suspended run resumed straight into itself -- a title that
## made you hunt for it would be a step backwards.
##
## The backdrop floor is a real one, built by the real generator, and it must
## not touch anything the player owns. Building a level notes every visible
## monster in the bestiary, so it is built with the bestiary held; and it is
## never saved, never played and never written to the morgue.

signal chosen(id: StringName)

@export var font: Font
@export var font_bold: Font
@export var font_size: int = 22

## "main" or "settings". Both are the same list mechanism with different rows.
var page := &"main"
var can_continue := false
var legends_open := false
## A second press is needed before New game abandons a suspended run. One slot,
## destroyed on load: this is the only place it can be lost by a stray press.
var _new_armed := false
## What each settings row currently reads, answered by main.gd, which owns the
## settings. Called with the row's id.
var value_of: Callable = func(_id: StringName) -> String: return ""
## One line under the rows, for anything the screen has to say.
var note := ""

var _hover := 0
var backdrop: GlyphGrid
## The home: the game's own 3D view on a hand-built hall (TitleHall). The
## cottage in TitleHome is kept, unused, for an idea Brad has for it.
var home: Control

const MENU_W := 420.0
const MENU_RIGHT := 64.0
const ROW_H := 50.0
const ROWS_TOP := 330.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	if font == null:
		font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
	if font_bold == null:
		font_bold = load("res://assets/fonts/JetBrainsMono-Bold.ttf")

## Shows the screen, building the backdrop and the home the first time.
##
## Built on first open rather than in _ready so the test harnesses, which never
## see the title, never pay for a second dungeon either.
func open(resumable: bool, legends: bool, backdrop_seed := 0) -> void:
	can_continue = resumable
	legends_open = legends
	page = &"main"
	_new_armed = false
	note = ""
	_hover = 0
	if backdrop == null:
		backdrop = GlyphGrid.new()
		# Faded, as the map draws a floor it only remembers.
		backdrop.modulate = Color(0.95, 0.95, 1.0)
		# Scenery only. GlyphGrid._ready claims the mouse unless told not to,
		# and it did: the backdrop sat over the buttons taking every click
		# (Brad, first play). Setting mouse_filter from here was not enough,
		# because _ready can run after it.
		backdrop.takes_mouse = false
		add_child(backdrop)
		backdrop.state = TitleScreen.backdrop_state(backdrop_seed)
		home = TitleHall.new()
		add_child(home)
	_layout()
	visible = true
	queue_redraw()

func close() -> void:
	visible = false
	# Nothing behind a closed title should keep animating.
	if backdrop != null:
		backdrop.set_process(false)
	if home != null:
		home.set_process(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and backdrop != null:
		_layout()
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		if backdrop != null:
			backdrop.set_process(true)
		if home != null:
			home.set_process(true)

func _layout() -> void:
	backdrop.position = Vector2.ZERO
	backdrop.size = size
	# The home takes the space left of the menu, a little inset so the dungeon
	# shows round it.
	var left := size.x - MENU_W - MENU_RIGHT - 40.0
	home.position = Vector2(40.0, 40.0)
	home.size = Vector2(left - 40.0, size.y - 80.0)
	backdrop.centre_on_player()

## A floor to look at: from the room bands, the most crowded of a few, fully
## remembered, with its monsters lit where they stand.
static func backdrop_state(seed_value := 0) -> GameState:
	var pick := RandomNumberGenerator.new()
	if seed_value == 0:
		pick.randomize()
	else:
		pick.seed = seed_value
	var best: GameState = null
	var best_score := -1
	BestiaryLog.paused = true
	for i in 3:
		var gs := GameState.new(pick.randi() | 1)
		gs.new_game()
		gs.depth = pick.randi_range(3, 6)
		gs.build_level()
		var monsters := 0
		for e in gs.entities:
			if not e.is_player and e.alive:
				monsters += 1
		var score := gs.room_rects.size() * 3 + monsters
		if score > best_score:
			best_score = score
			best = gs
	BestiaryLog.paused = false
	# Remembered everywhere, seen nowhere -- except where something stands.
	best.map.reveal_all()
	best.map.clear_visible()
	for e in best.entities:
		if not e.is_player and e.alive:
			best.map.show_cell(e.x, e.y)
	# No hero on the title's floor: the one standing in the picture is the
	# house. The player stays in the state, invisible, at the middle of the map
	# -- the renderer's camera centres on them.
	best.entities.erase(best.player)
	best.player.x = best.map.width / 2
	best.player.y = best.map.height / 2
	return best

func rows() -> Array:
	var out := []
	if page == &"settings":
		for id in [&"3d", &"art", &"camera", &"effects", &"sound", &"music", &"text", &"pad"]:
			out.append([id, _setting_label(id), String(value_of.call(id))])
		out.append([&"back", "back", ""])
		return out
	if can_continue:
		out.append([&"continue", "continue", ""])
	out.append([&"new", "new game -- again to abandon your saved run"
		if _new_armed else "new game", ""])
	if legends_open:
		out.append([&"legends", "Legends Run", ""])
	out.append([&"settings", "settings", ""])
	if Platform.can_quit():
		out.append([&"exit", "exit", ""])
	return out

static func _setting_label(id: StringName) -> String:
	match id:
		&"3d": return "view"
		&"art": return "3D art"
		&"effects": return "effects"
		&"sound": return "sound"
		&"music": return "music"
		&"camera": return "3D camera"
		&"text": return "text size"
		&"pad": return "controller"
	return String(id)

## Every up and down a player might reach for. The map's own keys (arrows, vi,
## numpad) and WASD too: nothing on the title needs those letters, and they
## are the first thing many players try (Brad, first play).
const UP_KEYS: Array[int] = [KEY_UP, KEY_K, KEY_KP_8, KEY_W]
const DOWN_KEYS: Array[int] = [KEY_DOWN, KEY_J, KEY_KP_2, KEY_S]

func handle_key(key: int) -> bool:
	var n := rows().size()
	if key in UP_KEYS:
		key = KEY_UP
	elif key in DOWN_KEYS:
		key = KEY_DOWN
	match key:
		KEY_UP:
			_hover = posmod(_hover - 1, n)
		KEY_DOWN:
			_hover = posmod(_hover + 1, n)
		KEY_PERIOD, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			activate(_hover)
		KEY_ESCAPE:
			# Back out of settings; on the main page there is nowhere to go.
			if page == &"settings":
				_to_page(&"main")
		_:
			return false
	queue_redraw()
	return true

func activate(i: int) -> void:
	var r := rows()
	if i < 0 or i >= r.size():
		return
	var id: StringName = r[i][0]
	if id != &"new":
		_new_armed = false
	match id:
		&"settings":
			_to_page(&"settings")
		&"back":
			_to_page(&"main")
		&"new":
			if can_continue and not _new_armed:
				_new_armed = true
			else:
				chosen.emit(id)
		_:
			chosen.emit(id)
	queue_redraw()

func _to_page(p: StringName) -> void:
	page = p
	_hover = 0
	note = ""
	queue_redraw()

func _menu_rect() -> Rect2:
	return Rect2(size.x - MENU_W - MENU_RIGHT, 0.0, MENU_W, size.y)

func _row_rect(i: int) -> Rect2:
	var m := _menu_rect()
	return Rect2(m.position.x + 28.0, ROWS_TOP + i * ROW_H, MENU_W - 56.0, ROW_H - 8.0)

func _row_at(pos: Vector2) -> int:
	for i in rows().size():
		if _row_rect(i).has_point(pos):
			return i
	return -1

func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		var at := _row_at(motion.position)
		if at >= 0 and at != _hover:
			_hover = at
			queue_redraw()
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		var at := _row_at(click.position)
		if at >= 0:
			_hover = at
			activate(at)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.BG, true)

## The menu is drawn by a child above the backdrop and the home, so it is a
## separate node rather than this control's own _draw -- a Control draws UNDER
## its children.
class Front extends Control:
	var title: TitleScreen
	func _draw() -> void:
		title._paint(self)

var _front: Front

func _enter_tree() -> void:
	if _front == null:
		_front = Front.new()
		_front.title = self
		_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_front.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_front)

func _process(_delta: float) -> void:
	if visible and _front != null:
		# Keeps the front above whatever open() added after it.
		if _front.get_index() != get_child_count() - 1:
			move_child(_front, -1)
		_front.queue_redraw()

func _paint(c: Control) -> void:
	var m := _menu_rect()
	# A dark column for the menu, fading into the dungeon at its left edge.
	var shade := Color(Palette.BG, 0.86)
	c.draw_rect(Rect2(m.position, m.size), shade, true)
	for i in 24:
		var a := 0.86 * float(i) / 24.0
		c.draw_rect(Rect2(m.position.x - 48.0 + i * 2.0, 0, 2.0, size.y),
			Color(Palette.BG, a), true)

	var x := m.position.x + 28.0
	c.draw_string(font_bold, Vector2(x, 170.0), "OFR", HORIZONTAL_ALIGNMENT_LEFT,
		-1, 96, Palette.STAIRS)
	c.draw_string(font, Vector2(x + 4.0, 212.0), "an old fashioned roguelike",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.UI_DIM)
	if page == &"settings":
		c.draw_string(font_bold, Vector2(x, 290.0), "SETTINGS",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.UI_DIM)

	var r := rows()
	var asc := font.get_ascent(font_size)
	for i in r.size():
		var rect := _row_rect(i)
		var on := i == _hover
		if on:
			c.draw_rect(rect, Color(Palette.CURSOR, 0.16), true)
			c.draw_rect(Rect2(rect.position, Vector2(4.0, rect.size.y)), Palette.STAIRS, true)
		var base := rect.position + Vector2(18.0, (rect.size.y + asc) * 0.5 - 3.0)
		var label: String = r[i][1]
		var col := Color.WHITE if on else Palette.UI_TEXT
		if r[i][0] == &"legends":
			col = Palette.AMULET
		var size_here := font_size if label.length() < 26 else font_size - 6
		c.draw_string(font, base, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size_here, col)
		var value: String = r[i][2]
		if value != "":
			c.draw_string(font, base, value, HORIZONTAL_ALIGNMENT_RIGHT,
				rect.size.x - 36.0, font_size - 4, Palette.UI_DIM)

	if note != "":
		c.draw_multiline_string(font, Vector2(x, ROWS_TOP + r.size() * ROW_H + 24.0),
			note, HORIZONTAL_ALIGNMENT_LEFT, MENU_W - 56.0, 15, -1, Palette.UI_DIM)
	c.draw_string(font, Vector2(x, size.y - 32.0), BuildInfo.BUILD,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.UI_DIM)
