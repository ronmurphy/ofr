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
## Dark-adapted eyes: enough to move by, far too little to be seen by. The
## trade between seeing and being seen is the whole mechanic.
const DOUSED_RADIUS := 3

## Resting at a brazier. Each one holds a fixed pool, spent two points at a
## time, and then goes out for good.
const BRAZIER_CHARGE := 10
const BRAZIER_HEAL := 2

var rng := RandomNumberGenerator.new()
var map: DungeonMap
var light_map: LightMap
var pathfinder: Pathfinder
var msg_log := MessageLog.new()

var entities: Array = []
var ground: Array = []
var player: Entity
var static_lights: Array = []
## Cell -> hit points left in that brazier.
var brazier_charge: Dictionary = {}
var stairs: Vector2i
## Cave regions carved on this level, kept so tests and later features can
## reason about them.
var cave_regions: Array[Rect2i] = []

var torch_lit := true
var depth: int = 1
var turns: int = 0
var game_over: bool = false

## Presentation events produced by the turn just resolved.
##
## The simulation NEVER waits for an animation. A shot resolves instantly in
## game time -- exactly as Angband and DCSS do it -- and this queue only tells
## the renderer what to draw after the fact. Anything else would put a reflex
## test inside a turn-based game.
var events: Array = []

var _fov_buffer := PackedByteArray()
## A queued mouse-travel path. Consumed one step per turn, abandoned the
## instant something hostile comes into view.
var _travel: Array[Vector2i] = []

## Behaviour matters more than the numbers here. Six monsters that all walk at
## you in a straight line are one monster with six stat blocks; the point of
## this pass is that a bat, an archer and a goblin now play differently.
##
## Capital glyphs mark the dangerous variant of a family -- K is a kobold that
## shoots back.
const BESTIARY := [
	{"name": "giant rat", "app": &"rat", "hp": 4, "power": 2, "def": 0,
	 "speed": 120, "ai": &"hunter", "flee": 0.30, "min_depth": 1},
	{"name": "kobold", "app": &"kobold", "hp": 6, "power": 3, "def": 0,
	 "speed": 100, "ai": &"hunter", "flee": 0.25, "min_depth": 1},
	{"name": "kobold slinger", "app": &"slinger", "hp": 5, "power": 3, "def": 0,
	 "speed": 100, "ai": &"ranged", "range": 6, "flee": 0.45, "min_depth": 2},
	{"name": "cave bat", "app": &"bat", "hp": 5, "power": 3, "def": 0,
	 "speed": 170, "ai": &"erratic", "flee": 0.0, "min_depth": 2},
	{"name": "goblin", "app": &"goblin", "hp": 9, "power": 4, "def": 1,
	 "speed": 100, "ai": &"pack", "flee": 0.20, "min_depth": 2},
	{"name": "skeleton", "app": &"skeleton", "hp": 12, "power": 5, "def": 2,
	 "speed": 90, "ai": &"hunter", "flee": 0.0, "min_depth": 3},
	{"name": "orc", "app": &"orc", "hp": 16, "power": 6, "def": 2,
	 "speed": 100, "ai": &"hunter", "flee": 0.15, "min_depth": 4},
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

	var start := _open_cell_in(rooms[0])
	player.x = start.x
	player.y = start.y

	stairs = _open_cell_in(rooms[-1])
	map.set_tile(stairs.x, stairs.y, Tiles.STAIRS_DOWN)

	cave_regions = gen.caves.duplicate()
	brazier_charge.clear()
	for y in map.height:
		for x in map.width:
			if map.get_tile(x, y) == Tiles.BRAZIER:
				brazier_charge[Vector2i(x, y)] = BRAZIER_CHARGE
	_gather_lights()
	for i in range(1, rooms.size()):
		_populate_room(rooms[i], gen.archetypes[i])
	for region in gen.caves:
		_populate_cave(region)

	pathfinder = Pathfinder.new(map)
	update_vision()

## Decoration can now put a pillar or a brazier on a room's exact centre, so
## neither the player nor the stairs can simply be dropped there any more.
func _open_cell_in(room: Rect2i) -> Vector2i:
	var c := room.get_center()
	var best := c
	var best_d := 1 << 30
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			if not map.is_walkable(x, y):
				continue
			var d := absi(x - c.x) + absi(y - c.y)
			if d < best_d:
				best_d = d
				best = Vector2i(x, y)
	return best

## Braziers are terrain now -- the generator places them, and the lighting
## rig is derived from the map rather than maintained alongside it.
func _gather_lights() -> void:
	static_lights = []
	for y in map.height:
		for x in map.width:
			if map.get_tile(x, y) == Tiles.BRAZIER:
				static_lights.append(LightSource.new(x, y, 6,
					Color(0.95, 0.55, 0.20), Color(0.35, 0.20, 0.30), 0.85, true))

func _populate_room(room: Rect2i, archetype: int) -> void:
	if rng.randf() < 0.55:
		var ix := rng.randi_range(room.position.x, room.end.x - 1)
		var iy := rng.randi_range(room.position.y, room.end.y - 1)
		if map.is_walkable(ix, iy) and Vector2i(ix, iy) != stairs and items_at(ix, iy).is_empty():
			var loot := Item.roll(rng, depth)
			if loot != null:
				loot.x = ix
				loot.y = iy
				ground.append(loot)

	# A shrine keeps a guardian; a collapsed room is where things nest.
	var bonus := 0
	if archetype == MapGen.Archetype.SHRINE or archetype == MapGen.Archetype.COLLAPSED:
		bonus = 1
	var count := rng.randi_range(0, 2 + depth / 3) + bonus
	for _i in count:
		_spawn_in(Rect2i(room.position, room.size))

func _populate_cave(region: Rect2i) -> void:
	# Caves are wilder than rooms, and unlit -- worth a little more danger.
	var count := rng.randi_range(1, 3 + depth / 3)
	for _i in count:
		_spawn_in(region)

func _spawn_in(area: Rect2i) -> void:
	var mx := rng.randi_range(area.position.x, area.end.x - 1)
	var my := rng.randi_range(area.position.y, area.end.y - 1)
	if not map.is_walkable(mx, my) or entity_at(mx, my) != null:
		return
	if Vector2i(mx, my) == stairs or Vector2i(mx, my) == Vector2i(player.x, player.y):
		return
	var pick := _roll_monster()
	if pick.is_empty():
		return
	var m := Entity.new(pick["name"], pick["app"], mx, my)
	m.max_hp = pick["hp"]
	m.hp = pick["hp"]
	m.power = pick["power"]
	m.defense = pick["def"]
	m.speed = pick["speed"]
	m.ai = pick.get("ai", &"hunter")
	m.attack_range = pick.get("range", 1)
	m.flee_below = pick.get("flee", 0.0)
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
	var radius := TORCH_RADIUS if torch_lit else DOUSED_RADIUS
	Fov.compute(map, player.x, player.y, radius, _fov_buffer)
	map.visible_now = _fov_buffer.duplicate()
	map.remember_visible()

	player.light.x = player.x
	player.light.y = player.y
	if torch_lit:
		player.light.radius = TORCH_RADIUS
		player.light.intensity = 1.0
		player.light.color = Color(1.00, 0.72, 0.36)
		player.light.color_far = Color(0.30, 0.34, 0.55)
	else:
		player.light.radius = DOUSED_RADIUS
		player.light.intensity = 0.30
		player.light.color = Color(0.42, 0.50, 0.68)
		player.light.color_far = Color(0.20, 0.24, 0.36)
	var sources := [player.light]
	sources.append_array(static_lights)
	light_map.compute(map, sources)

## Drains the presentation queue. Called by the renderer once per refresh.
func take_events() -> Array:
	var out := events.duplicate()
	events.clear()
	return out

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

## Costs a turn on purpose. Going dark is a decision, not a free toggle.
func player_toggle_torch() -> bool:
	if game_over:
		return false
	_travel.clear()
	torch_lit = not torch_lit
	if torch_lit:
		msg_log.add("You uncover the torch. Light floods back.", Color(0.95, 0.78, 0.42))
	else:
		msg_log.add("You smother the torch. The dark closes in.", Color(0.58, 0.64, 0.85))
	_end_player_turn()
	return true

## Waiting beside a lit brazier warms you. The light keeps the dark at bay.
##
## Note what this costs, which is not obvious: resting puts you in the
## brightest cell on the level for several turns while the world keeps taking
## turns. The awareness system makes that genuinely dangerous, which is why
## this heals slowly rather than all at once -- an instant heal would be free,
## and a free heal is not a decision.
func player_wait() -> bool:
	if game_over:
		return false
	_travel.clear()

	var brazier := _adjacent_brazier()
	if brazier.x >= 0 and player.hp < player.max_hp:
		var healed := mini(BRAZIER_HEAL, player.max_hp - player.hp)
		player.hp += healed
		brazier_charge[brazier] = int(brazier_charge[brazier]) - healed
		msg_log.add("You warm yourself at the brazier. (+%d)" % healed,
			Color(0.96, 0.76, 0.44))
		if int(brazier_charge[brazier]) <= 0:
			brazier_charge.erase(brazier)
			map.set_tile(brazier.x, brazier.y, Tiles.BRAZIER_SPENT)
			_gather_lights()
			msg_log.add("The brazier gutters out.", Color(0.58, 0.55, 0.50))

	_end_player_turn()
	return true

## A lit brazier beside the player with something left in it.
func _adjacent_brazier() -> Vector2i:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var c := Vector2i(player.x + dx, player.y + dy)
			if map.get_tile(c.x, c.y) == Tiles.BRAZIER and int(brazier_charge.get(c, 0)) > 0:
				return c
	return Vector2i(-1, -1)

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

	_update_awareness(actor)
	# Asleep, or merely stirring: it spends its turn not acting. That pause is
	# the player's window to withdraw, and it is the point of the middle state.
	if actor.alertness != Entity.Alert.AWAKE:
		return

	_update_morale(actor)
	if actor.fleeing:
		_ai_flee(actor)
		return

	match actor.ai:
		&"erratic": _ai_erratic(actor)
		&"ranged":  _ai_ranged(actor)
		&"pack":    _ai_pack(actor)
		_:          _ai_hunter(actor)

func _update_awareness(actor: Entity) -> void:
	var d := Los.steps(actor.x, actor.y, player.x, player.y)

	if actor.alertness == Entity.Alert.AWAKE:
		# Keep track of the player, or eventually lose the trail. Without this
		# a woken monster would pursue across the whole level forever.
		if d <= actor.notice_range * 2 and Los.clear(map, actor.x, actor.y, player.x, player.y):
			actor.last_seen = Vector2i(player.x, player.y)
			actor.lost_turns = 0
		else:
			actor.lost_turns += 1
			if actor.lost_turns > 10:
				actor.alertness = Entity.Alert.SUSPICIOUS
				actor.calm_turns = 0
		return

	if _notices_player(actor, d):
		if actor.alertness == Entity.Alert.ASLEEP:
			actor.alertness = Entity.Alert.SUSPICIOUS
			actor.calm_turns = 0
		else:
			wake(actor)
		return

	if actor.alertness == Entity.Alert.SUSPICIOUS:
		actor.calm_turns += 1
		if actor.calm_turns > 6:
			actor.alertness = Entity.Alert.ASLEEP

## Light dominates the roll. Carrying a torch is both how you see and how you
## are seen, which is the trade the whole mechanic rests on.
func _notices_player(actor: Entity, d: int) -> bool:
	if d > actor.notice_range:
		return false
	if not Los.clear(map, actor.x, actor.y, player.x, player.y):
		return false
	# Anything you are standing next to finds you, however dark it is.
	if d <= 1:
		return true

	var lum := light_map.get_light(player.x, player.y).get_luminance()
	var closeness := 1.0 - float(d) / float(actor.notice_range + 1)
	var chance := closeness * (0.10 + 1.6 * lum)
	if actor.alertness == Entity.Alert.SUSPICIOUS:
		chance *= 2.0
	return rng.randf() < clampf(chance, 0.0, 0.95)

func wake(actor: Entity) -> void:
	if actor.alertness == Entity.Alert.AWAKE or not actor.alive:
		return
	actor.alertness = Entity.Alert.AWAKE
	actor.last_seen = Vector2i(player.x, player.y)
	actor.lost_turns = 0
	events.append({"kind": &"notice", "to": Vector2i(actor.x, actor.y)})
	msg_log.add("The %s notices you!" % actor.name, Color(0.98, 0.78, 0.35))

## Nothing rallies yet, since only the player can heal -- but the threshold is
## checked each turn rather than latched, so a healing monster later works
## without touching this.
func _update_morale(actor: Entity) -> void:
	if actor.flee_below <= 0.0:
		return
	var frac := float(actor.hp) / float(actor.max_hp)
	if not actor.fleeing and frac <= actor.flee_below:
		actor.fleeing = true
		msg_log.add("The %s turns to flee!" % actor.name, Color(0.78, 0.82, 0.58))
	elif actor.fleeing and frac > actor.flee_below + 0.25:
		actor.fleeing = false

func _ai_hunter(actor: Entity) -> void:
	if actor.is_adjacent(player):
		_attack(actor, player)
		return
	_step_toward(actor, Vector2i(player.x, player.y))

## Bites when it happens to be beside you, but will not hold a line -- so you
## cannot reliably disengage from one, and cannot reliably corner it either.
func _ai_erratic(actor: Entity) -> void:
	if actor.is_adjacent(player) and rng.randf() < 0.7:
		_attack(actor, player)
		return
	if rng.randf() < 0.6:
		_step_random(actor)
		return
	_step_toward(actor, Vector2i(player.x, player.y))

## The behaviour that makes pillars matter: it needs a clear line, so stepping
## behind cover genuinely stops it, and it backs off rather than letting you
## close to melee for free.
func _ai_ranged(actor: Entity) -> void:
	var dist := Los.steps(actor.x, actor.y, player.x, player.y)

	if dist <= 1:
		if _step_away(actor):
			return
		_attack(actor, player)
		return

	if dist <= actor.attack_range and Los.clear(map, actor.x, actor.y, player.x, player.y):
		_attack(actor, player, true)
		return

	_step_toward(actor, Vector2i(player.x, player.y))

## Bold with company, hesitant alone -- so a lone goblin hangs back and a pair
## of them commit, which makes thinning a group worth doing.
func _ai_pack(actor: Entity) -> void:
	if actor.is_adjacent(player):
		_attack(actor, player)
		return
	if _allies_near(actor, 5) > 0 or rng.randf() < 0.45:
		_step_toward(actor, Vector2i(player.x, player.y))

func _allies_near(actor: Entity, radius: int) -> int:
	var n := 0
	for e in entities:
		if e == actor or not e.alive or e.is_player:
			continue
		if Los.steps(actor.x, actor.y, e.x, e.y) <= radius:
			n += 1
	return n

func _ai_flee(actor: Entity) -> void:
	if _step_away(actor):
		return
	# Cornered. A trapped animal fights.
	if actor.is_adjacent(player):
		_attack(actor, player)

func _step_toward(actor: Entity, target: Vector2i) -> void:
	var route := pathfinder.path(Vector2i(actor.x, actor.y), target)
	if route.is_empty():
		return
	var step: Vector2i = route[0]
	if entity_at(step.x, step.y) != null:
		return
	actor.x = step.x
	actor.y = step.y

func _step_random(actor: Entity) -> void:
	var opts: Array[Vector2i] = []
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var nx: int = actor.x + dx
			var ny: int = actor.y + dy
			if map.is_walkable(nx, ny) and entity_at(nx, ny) == null:
				opts.append(Vector2i(nx, ny))
	if opts.is_empty():
		return
	var pick: Vector2i = opts[rng.randi_range(0, opts.size() - 1)]
	actor.x = pick.x
	actor.y = pick.y

## Returns false when there is nowhere further from the player to go.
func _step_away(actor: Entity) -> bool:
	var here := Los.steps(actor.x, actor.y, player.x, player.y)
	var best := Vector2i(actor.x, actor.y)
	var best_d := here
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var nx: int = actor.x + dx
			var ny: int = actor.y + dy
			if not map.is_walkable(nx, ny) or entity_at(nx, ny) != null:
				continue
			var d := Los.steps(nx, ny, player.x, player.y)
			if d > best_d:
				best_d = d
				best = Vector2i(nx, ny)
	if best_d <= here:
		return false
	actor.x = best.x
	actor.y = best.y
	return true

func _attack(attacker: Entity, defender: Entity, ranged: bool = false) -> void:
	var dmg := maxi(1, attacker.total_power() - defender.total_defense() + rng.randi_range(-1, 1))
	defender.take_damage(dmg)

	events.append({
		"kind": &"ranged" if ranged else &"melee",
		"from": Vector2i(attacker.x, attacker.y),
		"to": Vector2i(defender.x, defender.y),
		"amount": dmg,
		"on_player": defender.is_player,
	})
	if defender.is_player:
		# Never keep auto-walking into something that is hurting you.
		_travel.clear()
	else:
		wake(defender)

	# Fighting is loud. Noise carries through stone, so this deliberately
	# ignores line of sight.
	for e in entities:
		if e.alive and not e.is_player and Los.steps(e.x, e.y, defender.x, defender.y) <= 4:
			wake(e)

	if attacker.is_player:
		msg_log.add("You hit the %s for %d." % [defender.name, dmg], Color(0.80, 0.85, 0.70))
	elif ranged:
		msg_log.add("The %s shoots you for %d." % [attacker.name, dmg], Color(0.95, 0.62, 0.35))
	else:
		msg_log.add("The %s hits you for %d." % [attacker.name, dmg], Color(0.90, 0.45, 0.40))

	if not defender.alive:
		if defender.is_player:
			game_over = true
			msg_log.add("You die. Press R to begin again.", Color(1.0, 0.35, 0.35))
		else:
			msg_log.add("The %s dies." % defender.name, Color(0.65, 0.70, 0.85))
