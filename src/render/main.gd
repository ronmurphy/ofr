extends Control

## Wires the simulation to the three panels and translates input into intents.
##
## Note what this file does NOT do: it never touches game rules. It converts a
## keypress or a click into a call on GameState and then asks the panels to
## redraw. Keeping that boundary honest is what will let a tile renderer, or a
## party, or a second view drop in later without rewriting the game.

@onready var grid: GlyphGrid = $Grid
@onready var sidebar: Sidebar = $Sidebar
@onready var log_view: MessageView = $Log
@onready var inventory: InventoryPanel = $Inventory

var state: GameState

## Milliseconds between steps of a mouse-driven walk. Fast enough not to
## annoy, slow enough that you can see where you went and react.
const TRAVEL_STEP := 0.045
var _travel_accum := 0.0

## Keyboard look mode. The mouse could already inspect cells; this is the same
## affordance for people who never take their hands off the keys -- which, in a
## roguelike, is most of them.
var _look := false
var _look_at := Vector2i.ZERO

const MOVES := {
	KEY_LEFT: Vector2i(-1, 0), KEY_RIGHT: Vector2i(1, 0),
	KEY_UP: Vector2i(0, -1), KEY_DOWN: Vector2i(0, 1),

	KEY_H: Vector2i(-1, 0), KEY_L: Vector2i(1, 0),
	KEY_K: Vector2i(0, -1), KEY_J: Vector2i(0, 1),
	KEY_Y: Vector2i(-1, -1), KEY_U: Vector2i(1, -1),
	KEY_B: Vector2i(-1, 1), KEY_N: Vector2i(1, 1),

	KEY_KP_1: Vector2i(-1, 1), KEY_KP_2: Vector2i(0, 1), KEY_KP_3: Vector2i(1, 1),
	KEY_KP_4: Vector2i(-1, 0), KEY_KP_6: Vector2i(1, 0),
	KEY_KP_7: Vector2i(-1, -1), KEY_KP_8: Vector2i(0, -1), KEY_KP_9: Vector2i(1, -1),
}

func _ready() -> void:
	var fresh := GameState.new()
	fresh.new_game()
	_bind_state(fresh)
	grid.cell_clicked.connect(_on_cell_clicked)
	inventory.use_requested.connect(_use_item)
	inventory.drop_requested.connect(_drop_item)
	inventory.merge_requested.connect(_merge_item)
	inventory.close_requested.connect(_close_inventory)
	_refresh()

func _process(delta: float) -> void:
	sidebar.hovered = _look_at if _look else grid.hovered_cell()
	sidebar.queue_redraw()

	if not state.travelling():
		return
	_travel_accum += delta
	if _travel_accum < TRAVEL_STEP:
		return
	_travel_accum = 0.0
	state.step_travel()
	_refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	var key: int = key_event.keycode

	# The inventory is modal and swallows everything else while it is up.
	if inventory.visible:
		if key == KEY_TAB:
			inventory.cycle_filter(-1 if key_event.shift_pressed else 1)
		elif key == KEY_ESCAPE or key == KEY_I:
			_close_inventory()
		else:
			var picked: int = inventory.letter_to_index(key)
			if picked >= 0:
				if key_event.shift_pressed:
					_merge_item(picked)
				else:
					_use_item(picked)
		return

	if key == KEY_I:
		_open_inventory()
		return

	if key == KEY_X or key == KEY_SEMICOLON:
		_toggle_look()
		return

	if _look:
		if key == KEY_ESCAPE or key == KEY_ENTER or key == KEY_KP_ENTER:
			_end_look()
		elif MOVES.has(key):
			var step: Vector2i = MOVES[key]
			_look_at.x = clampi(_look_at.x + step.x, 0, state.map.width - 1)
			_look_at.y = clampi(_look_at.y + step.y, 0, state.map.height - 1)
			grid.look_cursor = _look_at
			_refresh()
		return

	if key == KEY_R:
		_end_look()
		_close_inventory()
		var fresh := GameState.new()
		fresh.new_game()
		_bind_state(fresh)
		return

	if state.game_over:
		return

	if MOVES.has(key):
		var d: Vector2i = MOVES[key]
		if state.player_move(d.x, d.y):
			_refresh()
		return

	match key:
		KEY_PERIOD, KEY_KP_5:
			if key_event.shift_pressed and key == KEY_PERIOD:
				if state.player_descend():
					_refresh()
			elif state.player_wait():
				_refresh()
		KEY_GREATER:
			if state.player_descend():
				_refresh()
		KEY_G:
			if state.player_pickup():
				_refresh()
		KEY_COMMA:
			# Shift+comma is "<", so the same physical key both picks up and
			# climbs, exactly as period both waits and descends.
			if key_event.shift_pressed:
				if state.player_ascend():
					_refresh()
			elif state.player_pickup():
				_refresh()
		KEY_LESS:
			if state.player_ascend():
				_refresh()
		KEY_T:
			if state.player_toggle_torch():
				_refresh()

func _on_cell_clicked(cell: Vector2i) -> void:
	_end_look()
	if state.game_over:
		return
	if state.begin_travel(cell):
		_travel_accum = 0.0
		_refresh()

## Look mode is available after death too -- reading the room that killed you
## is half of what makes a run worth losing.
func _toggle_look() -> void:
	if _look:
		_end_look()
		return
	_look = true
	_look_at = Vector2i(state.player.x, state.player.y)
	grid.look_cursor = _look_at
	sidebar.look_mode = true
	_refresh()

func _end_look() -> void:
	if not _look:
		return
	_look = false
	grid.look_cursor = Vector2i(-1, -1)
	sidebar.look_mode = false
	_refresh()

## The single place that points every panel at a GameState. Having this wiring
## copied into _ready, the restart path and the capture tool is exactly how the
## inventory ended up rendering a stale, empty pack.
func _bind_state(s: GameState) -> void:
	state = s
	grid.state = s
	sidebar.state = s
	log_view.state = s
	inventory.state = s
	_refresh()

func _open_inventory() -> void:
	_end_look()
	inventory.open()
	_refresh()

func _close_inventory() -> void:
	inventory.close()
	_refresh()

## A refused item (drinking at full health) keeps the panel open, so the click
## is not punished by having to reopen and re-read the list.
func _use_item(index: int) -> void:
	if state.player_use(index):
		_close_inventory()
	_refresh()

## Forging keeps the panel open, so the result is visible and a second merge
## does not need the list reopened.
func _merge_item(index: int) -> void:
	state.player_merge(index)
	_refresh()

func _drop_item(index: int) -> void:
	state.player_drop(index)
	_refresh()

func _refresh() -> void:
	# Hand the turn's events to the renderer to animate. The simulation has
	# already resolved them; this is purely showing the player what happened.
	grid.play_events(state.take_events())
	grid.refresh_preview()
	grid.queue_redraw()
	sidebar.queue_redraw()
	log_view.queue_redraw()
	inventory.queue_redraw()
