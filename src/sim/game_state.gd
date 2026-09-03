class_name GameState
extends RefCounted

## The whole simulation. Owns no Godot nodes and knows nothing about drawing.
##
## Everything here can be exercised headless -- see tests/run_tests.gd. That is
## the single most valuable property of this layer: procedural generation and
## combat maths are exactly the things you want to run ten thousand times in a
## loop without a window open.

const MAP_W := 72
const MAP_H := 40
const TORCH_RADIUS := 8

var rng := RandomNumberGenerator.new()
var map: DungeonMap
var light_map: LightMap
var pathfinder: Pathfinder
var msg_log := MessageLog.new()

var entities: Array = []
var ground: Array = []
var player: Entity
var static_lights: Array = []
var stairs: Vector2i

var depth: int = 1
var turns: int = 0
var game_over: bool = false

var _fov_buffer := PackedByteArray()
## A queued mouse-travel path. Consumed one step per turn, abandoned the
## instant something hostile comes into view.
var _travel: Array[Vector2i] = []

const BESTIARY := [
	{"name": "giant rat",  "app": &"rat",      "hp": 4,  "power": 2, "def": 0, "speed": 120, "min_depth": 1},
	{"name": "kobold",     "app": &"kobold",   "hp": 6,  "power": 3, "def": 0, "speed": 100, "min_depth": 1},
	{"name": "goblin",     "app": &"goblin",   "hp": 9,  "power": 4, "def": 1, "speed": 100, "min_depth": 2},
	{"name": "cave bat",   "app": &"bat",      "hp": 5,  "power": 3, "def": 0, "speed": 160, "min_depth": 2},
	{"name": "skeleton",   "app": &"skeleton", "hp": 12, "power": 5, "def": 2, "speed": 90,  "min_depth": 3},
	{"name": "orc",        "app": &"orc",      "hp": 16, "power": 6, "def": 2, "speed": 100, "min_depth": 4},
]

func _init(seed_value: int = 0) -> void:
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value

func new_game() -> void:
	depth = 1
	turns = 0
	game_over = false
	player = Entity.new("you", &"player", 0, 0)
	player.is_player = true
	player.faction = Entity.Faction.PLAYER
	player.max_hp = 30
	player.hp = 30
	player.power = 5
	player.defense = 1
	player.light = LightSource.new(0, 0, TORCH_RADIUS,
		Color(1.00, 0.72, 0.36), Color(0.30, 0.34, 0.55), 1.0, true)
	build_level()
	msg_log.add("You descend into the dark, torch guttering.", Color(0.85, 0.72, 0.45))

func build_level() -> void:
	map = DungeonMap.new(MAP_W, MAP_H)
	light_map = LightMap.new(MAP_W, MAP_H)
	_fov_buffer.resize(MAP_W * MAP_H)

	var gen := MapGen.new(rng)
	gen.generate(map)

	entities = [player]
	ground = []
	static_lights = []
	_travel.clear()

	var rooms := gen.rooms
	if rooms.is_empty():
		# Degenerate level; carve a fallback chamber so the game never wedges.
		for y in range(1, 8):
			for x in range(1, 12):
				map.set_tile(x, y, Tiles.FLOOR)
		rooms = [Rect2i(1, 1, 11, 7)] as Array[Rect2i]

	var start := rooms[0].get_center()
	player.x = start.x
	player.y = start.y

	stairs = rooms[-1].get_center()
	map.set_tile(stairs.x, stairs.y, Tiles.STAIRS_DOWN)

	for i in range(1, rooms.size()):
		_populate_room(rooms[i])

	pathfinder = Pathfinder.new(map)
	update_vision()

func _populate_room(room: Rect2i) -> void:
	# A brazier now and then. Static light is what makes the dark feel
	# navigable rather than merely oppressive.
	if rng.randf() < 0.30:
		var bx := rng.randi_range(room.position.x, room.end.x - 1)
		var by := rng.randi_range(room.position.y, room.end.y - 1)
		if map.is_walkable(bx, by) and Vector2i(bx, by) != stairs:
			map.set_tile(bx, by, Tiles.BRAZIER)
			static_lights.append(LightSource.new(bx, by, 6,
				Color(0.95, 0.55, 0.20), Color(0.35, 0.20, 0.30), 0.85, true))

	# Loot. Generous on purpose: with no healing the game is just a countdown,
	# and the interesting decision is whether to drink now or hoard.
	if rng.randf() < 0.55:
		var ix := rng.randi_range(room.position.x, room.end.x - 1)
		var iy := rng.randi_range(room.position.y, room.end.y - 1)
		if map.is_walkable(ix, iy) and Vector2i(ix, iy) != stairs and items_at(ix, iy).is_empty():
			var loot := Item.roll(rng, depth)
			if loot != null:
				loot.x = ix
				loot.y = iy
				ground.append(loot)

	var count := rng.randi_range(0, 2 + depth / 3)
	for _i in count:
		var mx := rng.randi_range(room.position.x, room.end.x - 1)
		var my := rng.randi_range(room.position.y, room.end.y - 1)
		if not map.is_walkable(mx, my) or entity_at(mx, my) != null:
			continue
		var pick := _roll_monster()
		if pick.is_empty():
			continue
		var m := Entity.new(pick["name"], pick["app"], mx, my)
		m.max_hp = pick["hp"]
		m.hp = pick["hp"]
		m.power = pick["power"]
		m.defense = pick["def"]
		m.speed = pick["speed"]
		m.ai = &"hunter"
		entities.append(m)

func _roll_monster() -> Dictionary:
	var eligible := []
	for e in BESTIARY:
		if e["min_depth"] <= depth:
			eligible.append(e)
	if eligible.is_empty():
		return {}
	return eligible[rng.randi_range(0, eligible.size() - 1)]

const LETTERS := "abcdefghijklmnopqrstuvwxyz"

## Adds an item to the pack with a stable letter.
##
## Persistent letters matter more than they look. Once the inventory is sorted
## or filtered, a letter derived from screen position would change every time
## you picked something up -- so "quaff b", typed from muscle memory, would
## drink the wrong thing. The letter belongs to the item, not to the row.
func give_item(item: Item) -> bool:
	if player.inventory.size() >= Entity.INVENTORY_MAX:
		return false
	var used := {}
	for it in player.inventory:
		used[it.letter] = true
	for i in Entity.INVENTORY_MAX:
		var ch := LETTERS[i]
		if not used.has(ch):
			item.letter = ch
			break
	player.inventory.append(item)
	return true

func items_at(x: int, y: int) -> Array:
	var out := []
	for it in ground:
		if it.x == x and it.y == y:
			out.append(it)
	return out

func entity_at(x: int, y: int) -> Entity:
	for e in entities:
		if e.alive and e.blocks and e.x == x and e.y == y:
			return e
	return null

# ---------------------------------------------------------------- vision ----

func update_vision() -> void:
	Fov.compute(map, player.x, player.y, TORCH_RADIUS, _fov_buffer)
	map.visible_now = _fov_buffer.duplicate()
	map.remember_visible()

	player.light.x = player.x
	player.light.y = player.y
	var sources := [player.light]
	sources.append_array(static_lights)
	light_map.compute(map, sources)

func visible_monsters() -> Array:
	var out := []
	for e in entities:
		if e.alive and not e.is_player and map.is_visible(e.x, e.y):
			out.append(e)
	return out

# ---------------------------------------------------------- player turn ----

## Every one of these returns true if game time actually passed. Returning
## false for a bumped wall is what stops the world taking a free turn while
## the player fumbles at a dead end.

func player_move(dx: int, dy: int) -> bool:
	if game_over:
		return false
	_travel.clear()
	var nx := player.x + dx
	var ny := player.y + dy

	var target := entity_at(nx, ny)
	if target != null and target != player:
		_attack(player, target)
		_end_player_turn()
		return true

	if map.get_tile(nx, ny) == Tiles.DOOR_CLOSED:
		map.set_tile(nx, ny, Tiles.DOOR_OPEN)
		pathfinder.set_solid(nx, ny, false)
		msg_log.add("You pull the door open.")
		_end_player_turn()
		return true

	if not map.is_walkable(nx, ny):
		return false

	player.x = nx
	player.y = ny
	_end_player_turn()
	return true

func player_wait() -> bool:
	if game_over:
		return false
	_travel.clear()
	_end_player_turn()
	return true

func player_descend() -> bool:
	if game_over:
		return false
	if map.get_tile(player.x, player.y) != Tiles.STAIRS_DOWN:
		msg_log.add("There are no stairs here.", Color(0.7, 0.6, 0.4))
		return false
	depth += 1
	build_level()
	msg_log.add("You descend to depth %d." % depth, Color(0.85, 0.72, 0.45))
	return true

func player_pickup() -> bool:
	if game_over:
		return false
	_travel.clear()
	var here := items_at(player.x, player.y)
	if here.is_empty():
		msg_log.add("There is nothing here to pick up.", Color(0.7, 0.6, 0.4))
		return false
	if player.inventory.size() >= Entity.INVENTORY_MAX:
		msg_log.add("You cannot carry any more.", Color(0.9, 0.55, 0.35))
		return false
	var item: Item = here[0]
	ground.erase(item)
	give_item(item)
	msg_log.add("You pick up the %s (%s)." % [item.name, item.letter],
		Color(0.75, 0.80, 0.90))
	_end_player_turn()
	return true

func player_use(index: int) -> bool:
	if game_over or index < 0 or index >= player.inventory.size():
		return false
	_travel.clear()
	var item: Item = player.inventory[index]

	# One action for the whole list: a potion is drunk, a sword is wielded.
	# The player should not have to remember which verb a slot wants.
	if item.is_equipment():
		_toggle_equip(item)
		_end_player_turn()
		return true

	# A refused effect costs neither the item nor the turn. Wasting a potion to
	# a misclick is the kind of thing that makes people stop playing.
	if not _apply_effect(item):
		return false
	player.inventory.remove_at(index)
	item.letter = ""
	_end_player_turn()
	return true

func _toggle_equip(item: Item) -> void:
	if player.is_equipped(item):
		player.equipped.erase(item.slot)
		msg_log.add("You put away the %s." % item.name)
		return
	var previous: Item = player.equipped.get(item.slot, null)
	player.equipped[item.slot] = item
	if previous == null:
		msg_log.add("You %s the %s." % [item.verb(), item.name], Color(0.80, 0.85, 0.95))
	else:
		msg_log.add("You swap the %s for the %s." % [previous.name, item.name],
			Color(0.80, 0.85, 0.95))

func player_drop(index: int) -> bool:
	if game_over or index < 0 or index >= player.inventory.size():
		return false
	_travel.clear()
	var item: Item = player.inventory[index]
	# Dropping something you are wearing takes it off first, rather than
	# leaving a dangling reference in `equipped`.
	if player.is_equipped(item):
		player.equipped.erase(item.slot)
	player.inventory.remove_at(index)
	item.letter = ""
	item.x = player.x
	item.y = player.y
	ground.append(item)
	msg_log.add("You drop the %s." % item.name)
	_end_player_turn()
	return true

## Returns false if the item declined to be used, in which case it is not spent.
func _apply_effect(item: Item) -> bool:
	match item.effect:
		&"heal":
			if player.hp >= player.max_hp:
				msg_log.add("You are already whole.", Color(0.7, 0.6, 0.4))
				return false
			var healed := mini(item.magnitude, player.max_hp - player.hp)
			player.hp += healed
			msg_log.add("You drink the %s. %d hp restored." % [item.name, healed],
				Color(0.55, 0.85, 0.55))
			return true

		&"light":
			var buf := PackedByteArray()
			buf.resize(map.width * map.height)
			Fov.compute(map, player.x, player.y, item.magnitude, buf)
			var revealed := 0
			for i in buf.size():
				if buf[i] != 0 and map.explored[i] == 0:
					map.explored[i] = 1
					revealed += 1
			msg_log.add("Light floods out. %d new cells revealed." % revealed,
				Color(0.95, 0.88, 0.60))
			return true

		&"blink":
			var spots := []
			var r := item.magnitude
			for y in range(maxi(0, player.y - r), mini(map.height, player.y + r + 1)):
				for x in range(maxi(0, player.x - r), mini(map.width, player.x + r + 1)):
					if not map.is_walkable(x, y):
						continue
					if entity_at(x, y) != null:
						continue
					if x == player.x and y == player.y:
						continue
					spots.append(Vector2i(x, y))
			if spots.is_empty():
				msg_log.add("The scroll fizzles -- nowhere to go.", Color(0.7, 0.6, 0.4))
				return false
			var dest: Vector2i = spots[rng.randi_range(0, spots.size() - 1)]
			player.x = dest.x
			player.y = dest.y
			msg_log.add("The world lurches. You are elsewhere.", Color(0.75, 0.70, 0.95))
			return true

	return false

## Begin a mouse-driven walk. Returns false if the destination is unreachable.
func begin_travel(to: Vector2i) -> bool:
	if game_over or not map.is_explored(to.x, to.y):
		return false
	var route := pathfinder.path(Vector2i(player.x, player.y), to)
	if route.is_empty():
		return false
	_travel = route
	return step_travel()

func travelling() -> bool:
	return not _travel.is_empty()

## Advances one step of a queued mouse-travel. Stops for anything interesting.
func step_travel() -> bool:
	if _travel.is_empty() or game_over:
		return false
	if not visible_monsters().is_empty():
		_travel.clear()
		msg_log.add("You stop -- something is watching.", Color(0.9, 0.55, 0.35))
		return false
	var next := _travel[0]
	var dx := next.x - player.x
	var dy := next.y - player.y
	if entity_at(next.x, next.y) != null or not map.is_walkable(next.x, next.y):
		_travel.clear()
		return false
	_travel.remove_at(0)
	# Deliberately not player_move(): that clears the travel queue.
	player.x = next.x
	player.y = next.y
	_end_player_turn()
	return true

func _end_player_turn() -> void:
	Scheduler.spend(player)
	turns += 1
	update_vision()
	_run_world()
	update_vision()

# ----------------------------------------------------------- world turn ----

func _run_world() -> void:
	for _guard in 500:
		var actor := Scheduler.next_actor(entities)
		if actor == null or actor.is_player:
			return
		_take_ai_turn(actor)
		Scheduler.spend(actor)

func _take_ai_turn(actor: Entity) -> void:
	if not actor.alive or game_over:
		return
	# Symmetric shadowcasting means "the player can see it" and "it can see
	# the player" agree, so one FOV pass serves both sides.
	if not map.is_visible(actor.x, actor.y):
		return

	if actor.is_adjacent(player):
		_attack(actor, player)
		return

	var route := pathfinder.path(Vector2i(actor.x, actor.y), Vector2i(player.x, player.y))
	if route.is_empty():
		return
	var step := route[0]
	if entity_at(step.x, step.y) != null:
		return
	actor.x = step.x
	actor.y = step.y

func _attack(attacker: Entity, defender: Entity) -> void:
	var dmg := maxi(1, attacker.total_power() - defender.total_defense() + rng.randi_range(-1, 1))
	defender.take_damage(dmg)

	if attacker.is_player:
		msg_log.add("You hit the %s for %d." % [defender.name, dmg], Color(0.80, 0.85, 0.70))
	else:
		msg_log.add("The %s hits you for %d." % [attacker.name, dmg], Color(0.90, 0.45, 0.40))

	if not defender.alive:
		if defender.is_player:
			game_over = true
			msg_log.add("You die. Press R to begin again.", Color(1.0, 0.35, 0.35))
		else:
			msg_log.add("The %s dies." % defender.name, Color(0.65, 0.70, 0.85))
