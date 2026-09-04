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

## Targeting. Two routes in, because roguelike players split hard on this:
## `f` opens a keyboard cursor with tab-cycling, and right-clicking a monster
## shoots it outright. Right-click rather than left, so aiming can never be
## confused with the click-to-travel that shares the map.
var _aiming := false
var _aim_at := Vector2i.ZERO
var _aim_targets: Array = []
var _aim_index := 0
## Set when the cursor is aiming a thrown object rather than a launcher.
var _throw_index := -1

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
	grid.cell_right_clicked.connect(_on_cell_right_clicked)
	inventory.use_requested.connect(_use_item)
	inventory.drop_requested.connect(_drop_item)
	inventory.merge_requested.connect(_merge_item)
	inventory.throw_requested.connect(_on_throw_chosen)
	inventory.close_requested.connect(_close_inventory)
	_refresh()

func _process(delta: float) -> void:
	if _look:
		sidebar.hovered = _look_at
	elif _aiming:
		sidebar.hovered = _aim_at
	else:
		sidebar.hovered = grid.hovered_cell()
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
		if inventory.throw_mode:
			if key == KEY_ESCAPE or key == KEY_F:
				_close_inventory()
			else:
				var chosen: int = inventory.letter_to_index(key)
				if chosen >= 0:
					_on_throw_chosen(chosen)
			return
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

	if _aiming:
		if key == KEY_ESCAPE or key == KEY_F:
			_end_aim()
		elif key == KEY_TAB:
			_cycle_target(-1 if key_event.shift_pressed else 1)
		elif key == KEY_ENTER or key == KEY_KP_ENTER:
			_fire_at_cursor()
		elif MOVES.has(key):
			var step: Vector2i = MOVES[key]
			_aim_at.x = clampi(_aim_at.x + step.x, 0, state.map.width - 1)
			_aim_at.y = clampi(_aim_at.y + step.y, 0, state.map.height - 1)
			_update_aim()
		return

	if key == KEY_F:
		# A launcher shoots. Anything else means going to the off hand for
		# something to hurl.
		if state.player.total_range() > 1:
			_begin_aim()
		else:
			_begin_throw_pick()
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
		_end_aim()
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

func _begin_throw_pick() -> void:
	if state.game_over:
		return
	if state.throwables().is_empty():
		state.msg_log.add("You have nothing worth throwing.", Color(0.7, 0.6, 0.4))
		_refresh()
		return
	_end_look()
	inventory.open_for_throw()
	_refresh()

func _on_throw_chosen(index: int) -> void:
	if index < 0 or index >= state.player.inventory.size():
		return
	var item: Item = state.player.inventory[index]
	if not item.is_throwable():
		return
	_close_inventory()
	_throw_index = index
	_begin_aim(item.throw_range)

func _begin_aim(reach: int = -1) -> void:
	if state.game_over:
		return
	var r := state.player.total_range() if reach < 0 else reach
	if r <= 1:
		state.msg_log.add("You have nothing to shoot with.", Color(0.7, 0.6, 0.4))
		_refresh()
		return
	_end_look()
	_aim_targets = state.firing_targets(r)
	_aiming = true
	_aim_index = 0
	# Opens on the nearest legal target, so the common case needs no cursor
	# work at all.
	if _aim_targets.is_empty():
		_aim_at = Vector2i(state.player.x, state.player.y)
	else:
		_aim_at = Vector2i(_aim_targets[0].x, _aim_targets[0].y)
	sidebar.aiming = true
	_update_aim()

func _end_aim() -> void:
	if not _aiming:
		return
	_aiming = false
	_aim_targets = []
	_throw_index = -1
	grid.aim_cursor = Vector2i(-1, -1)
	grid.aim_line = []
	sidebar.aiming = false
	_refresh()

func _cycle_target(step: int) -> void:
	if _aim_targets.is_empty():
		return
	_aim_index = wrapi(_aim_index + step, 0, _aim_targets.size())
	var t: Entity = _aim_targets[_aim_index]
	_aim_at = Vector2i(t.x, t.y)
	_update_aim()

func _update_aim() -> void:
	grid.aim_cursor = _aim_at
	if _throw_index >= 0 and _throw_index < state.player.inventory.size():
		var held: Item = state.player.inventory[_throw_index]
		grid.aim_valid = state.can_reach(_aim_at, held.throw_range)
	else:
		grid.aim_valid = state.can_fire_at(_aim_at)
	grid.aim_line = Los.path(state.player.x, state.player.y, _aim_at.x, _aim_at.y)
	_refresh()

func _fire_at_cursor() -> void:
	var done := false
	if _throw_index >= 0:
		done = state.player_throw(_throw_index, _aim_at)
	else:
		done = state.player_fire(_aim_at)
	if done:
		_end_aim()
	else:
		_refresh()

func _on_cell_right_clicked(cell: Vector2i) -> void:
	if state.game_over:
		return
	if _aiming:
		_aim_at = cell
		_fire_at_cursor()
		return
	# Straight to the shot: no mode, no confirmation, and it can never be
	# mistaken for click-to-travel.
	if state.player_fire(cell):
		_refresh()
	else:
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
