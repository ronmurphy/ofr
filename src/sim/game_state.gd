class_name GameState
extends RefCounted

## The whole simulation. Owns no Godot nodes and knows nothing about drawing.
##
## Everything here can be exercised headless -- see tests/run_tests.gd. That is
## the single most valuable property of this layer: procedural generation and
## combat maths are exactly the things you want to run ten thousand times in a
## loop without a window open.

## The bottom of the dungeon. The amulet waits here and there are no stairs
## down -- the only way on is back the way you came.
const MAX_DEPTH := 10

## A single suspend slot, destroyed the moment it is loaded. That deletion is
## the entire anti-scum mechanism: there is never a point at which a save from
## *before* something went wrong still exists.
const SUSPEND_PATH := "user://suspend.save"
const MORGUE_PATH := "user://morgue.txt"
const SAVE_VERSION := 1

const MAP_W := 96
const MAP_H := 54
const TORCH_RADIUS := 8
## Dark-adapted eyes: enough to move by, far too little to be seen by. The
## trade between seeing and being seen is the whole mechanic.
const DOUSED_RADIUS := 3

## Resting at a brazier. Each one holds a fixed pool, spent two points at a
## time, and then goes out for good.
const BRAZIER_CHARGE := 10
const BRAZIER_HEAL := 2
## Merging two identical items costs brazier charge, which is the same finite
## pool as healing. That is the whole point: standing at a brazier hurt, with
## two daggers in your pack, should be a real choice between recovering now and
## hitting harder later. Durability was the other candidate and it fails,
## because it punishes using the good item and players simply hoard it.
const MERGE_COST := 4
## A scroll of light poured into a dead brazier relights it, but weakly.
## Deliberately less than a fresh one holds, and deliberately INSTEAD of the
## scroll's reveal rather than as well as it -- otherwise there is no decision,
## just a strictly better way to read the scroll.
const RELIGHT_CHARGE := 6

## A flared torch, in turns. It cannot be smothered while it burns -- that is
## the curse half: you see much further, and so does everything else.
const FLARE_TURNS := 100
const FLARE_MULTIPLIER := 2
## How long the shrine of the quiet keeps a floor from noticing you. Long
## enough to move, or to get the torch out and leave on your own terms.
const QUIET_TURNS := 12

## Ordinary human pace, and what the shrine of the weight costs you until the
## next floor. The energy scheduler has supported this since the beginning and
## nothing has ever moved it.
const BASE_SPEED := 100
const WEIGHT_SPEED := 82

## How often a slain monster's gear survives the fight.
##
## Not 1.0 on purpose. Every kill yielding a usable item would flood the floor,
## and with forging in the game that compounds -- three daggers make a +2
## dagger, so guaranteed drops would accelerate a power curve that already
## outruns monster defense.
const LOOT_DROP_CHANCE := 0.5

## Experience.
##
## A kill is worth its `threat` -- that value already IS this game's challenge
## rating, hand-tuned for what makes something dangerous to a lone character,
## so there is no second table to keep in sync.
##
## Descending pays a multiple of the threat ceiling for the floor just left.
## Tying it to the ceiling means the same number that decides how hard a floor
## may be also decides what surviving it is worth: change one and the other
## follows, with no drift.
##
## The split matters because stealth is intended play. If XP came only from
## kills, creeping past things -- the mode the game is built around -- would
## quietly fall behind the depth curve. Descending is the main driver, fighting
## is the accelerator.
const XP_DEPTH_MULTIPLIER := 6

## Levels cost quadratically more, NOT exponentially like D&D. See the README:
## D&D's curve is shaped around campaign tiers across dozens of sessions, and
## transplanted here it would grant three levels on floor one and then nothing
## for an hour.
const XP_CURVE_A := 18
const XP_CURVE_B := 42

const LEVEL_HP := 5

## The least a blow can be reduced to, as a fraction of the attacker's power.
##
## Flat damage reduction has a known failure mode: negligible while small, then
## absolute once defense catches up to power. Measured at depth 8, a levelled
## player in chain mail took the floored minimum of 1 from every orc in the
## game -- sixty hit points against one damage a hit.
##
## A floor tied to the attacker keeps armour worth wearing without ever making
## it immunity, and it makes the armour curve smooth instead of cliff-edged. It
## barely touches the early game: nothing changes at depths 1-3.
const DAMAGE_FLOOR_FRACTION := 0.25

## The threat ceiling.
##
## Deliberately a CEILING, not a budget. A budget would shape every room toward
## a target and flatten the swinginess that makes the game tense; this only
## clips the disasters -- the room that rolls three orcs against a 30 hp
## character with no answer. Density is untouched.
const ROOM_THREAT_BASE := 10
const ROOM_THREAT_PER_DEPTH := 2
## Caverns are open ground, so a lone character cannot use a doorway to turn
## being outnumbered into a series of duels. Less forgiving terrain, smaller
## ceiling.
const CAVE_THREAT_SCALE := 0.7

## How fast a monster stops appearing once the dungeon has moved past its tier.
## Without this, rats are as likely on depth 9 as on depth 1.
const TIER_FADE := 0.22
const TIER_GRACE := 1

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
## Kept so the encounter maths can be measured after the fact.
var room_rects: Array[Rect2i] = []

var torch_lit := true
var depth: int = 1
## Set the moment the amulet is taken. Everything downstream reads
## `effective_depth()` rather than `depth`, which is what makes the climb out
## harder than the climb down.
var ascending := false
var won := false
## What finished the run, for the morgue.
var death_cause := ""

## Cell -> shrine type. Shrines are consumed when used.
var shrine_at: Dictionary = {}
## Shrine type -> hue index, shuffled once per run so the colours have to be
## learned again each time.
var shrine_hues: Array[int] = []
var shrine_known: Dictionary = {}
## Raised by the shrine of the anvil, for the rest of the run.
var forge_cap_bonus := 0
var torch_flare := 0
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
## Set by whichever movement helper an AI turn used, so the scheduler can
## charge for the ground actually crossed.
var _last_move_cost := Scheduler.ACTION_COST

## Behaviour matters more than the numbers here. Six monsters that all walk at
## you in a straight line are one monster with six stat blocks; the point of
## this pass is that a bat, an archer and a goblin now play differently.
##
## Capital glyphs mark the dangerous variant of a family -- K is a kobold that
## shoots back.
## Behaviour matters more than the numbers here. Six monsters that all walk at
## you in a straight line are one monster with six stat blocks.
##
## `threat` is this game's challenge rating. It is not derived from the stats
## by formula, because the stats do not capture what actually makes something
## dangerous to a lone character: a slinger costs more than its hit points
## suggest because it attacks from safety, and a bat costs more than its damage
## suggests because you cannot disengage from it.
##
## Capital glyphs mark the dangerous variant of a family -- K is a kobold that
## shoots back.
const BESTIARY := [
	{"name": "giant rat", "app": &"rat", "hp": 4, "power": 2, "def": 0,
	 "speed": 120, "ai": &"hunter", "flee": 0.30, "min_depth": 1, "threat": 2},
	{"name": "kobold", "app": &"kobold", "hp": 6, "power": 3, "def": 0,
	 "speed": 100, "ai": &"hunter", "flee": 0.25, "gear": 0.35, "min_depth": 1, "threat": 3},
	{"name": "kobold slinger", "app": &"slinger", "hp": 5, "power": 3, "def": 0,
	 "speed": 100, "ai": &"ranged", "range": 6, "flee": 0.45, "gear": 0.25, "min_depth": 2,
	 "threat": 6},
	{"name": "cave bat", "app": &"bat", "hp": 5, "power": 3, "def": 0,
	 "speed": 170, "ai": &"erratic", "flee": 0.0, "flying": true, "min_depth": 2, "threat": 5},
	{"name": "goblin", "app": &"goblin", "hp": 9, "power": 4, "def": 1,
	 "speed": 100, "ai": &"pack", "flee": 0.20, "gear": 0.50, "min_depth": 2, "threat": 5},
	{"name": "skeleton", "app": &"skeleton", "hp": 12, "power": 5, "def": 2,
	 "speed": 90, "ai": &"hunter", "flee": 0.0, "gear": 0.40, "min_depth": 3, "threat": 8},
	{"name": "orc", "app": &"orc", "hp": 16, "power": 6, "def": 2,
	 "speed": 100, "ai": &"hunter", "flee": 0.15, "gear": 0.70, "min_depth": 4, "threat": 10},

	# --- deep tiers -------------------------------------------------------
	# Power from 7 upward, because below that a levelled character in chain
	# mail simply stops taking damage and the dungeon gets easier as it goes
	# deeper. These also carry the whole ascent, which runs at effective
	# depths of 10 to 19.
	{"name": "ogre", "app": &"ogre", "hp": 26, "power": 9, "def": 3,
	 "speed": 90, "ai": &"hunter", "flee": 0.12, "gear": 0.50, "heavy": true, "min_depth": 5, "threat": 14},
	{"name": "harpy", "app": &"harpy", "hp": 16, "power": 7, "def": 1,
	 "speed": 160, "ai": &"erratic", "flee": 0.25, "flying": true, "min_depth": 5, "threat": 12},
	{"name": "cave troll", "app": &"troll", "hp": 30, "power": 8, "def": 3,
	 "speed": 90, "ai": &"hunter", "flee": 0.0, "regen": 2, "heavy": true, "min_depth": 6,
	 "threat": 16},
	{"name": "wight", "app": &"wight", "hp": 24, "power": 10, "def": 4,
	 "speed": 100, "ai": &"hunter", "flee": 0.0, "gear": 0.60, "min_depth": 7, "threat": 17},
	{"name": "wyvern", "app": &"wyvern", "hp": 32, "power": 11, "def": 4,
	 "speed": 140, "ai": &"hunter", "flee": 0.10, "flying": true, "min_depth": 7, "threat": 20},
	{"name": "stone golem", "app": &"golem", "hp": 42, "power": 10, "def": 7,
	 "speed": 70, "ai": &"hunter", "flee": 0.0, "heavy": true, "min_depth": 8, "threat": 20},
	{"name": "shadow", "app": &"shadow", "hp": 20, "power": 13, "def": 1,
	 "speed": 130, "ai": &"erratic", "flee": 0.0, "flying": true, "min_depth": 9, "threat": 19},
	{"name": "young dragon", "app": &"dragon", "hp": 55, "power": 14, "def": 6,
	 "speed": 110, "ai": &"ranged", "range": 5, "flee": 0.0, "flying": true, "min_depth": 10,
	 "threat": 28},
]

## The deepest tier that exists.
##
## Beyond it the tier fade stops progressing. Without this the ascent -- which
## runs at effective depths of 10 to 19 -- would fade every monster in the game
## out of the pool and generate empty floors.
static func deepest_tier() -> int:
	var d := 1
	for e in BESTIARY:
		d = maxi(d, int(e["min_depth"]))
	return d

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
	_shuffle_shrines()
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
	if ascending:
		map.set_tile(stairs.x, stairs.y, Tiles.STAIRS_UP)
	elif depth < MAX_DEPTH:
		map.set_tile(stairs.x, stairs.y, Tiles.STAIRS_DOWN)
	else:
		# The bottom. Where the stairs would have been, the amulet.
		var relic := Item.make(&"amulet")
		relic.x = stairs.x
		relic.y = stairs.y
		ground.append(relic)

	# The weight does not follow you down the stairs.
	player.speed = BASE_SPEED

	shrine_at.clear()
	for y in map.height:
		for x in map.width:
			if map.get_tile(x, y) == Tiles.SHRINE:
				shrine_at[Vector2i(x, y)] = rng.randi_range(0, Shrines.COUNT - 1)

	cave_regions = gen.caves.duplicate()
	room_rects = gen.rooms.duplicate()
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

## How dangerous this floor is, as opposed to which floor it is.
##
## Descending they are the same. Climbing out they are not: floor 10 fights at
## depth 10 and floor 1, with the exit in sight, fights at depth 19. Tension
## should peak at the door, not ease off as you near it.
func effective_depth() -> int:
	if not ascending:
		return depth
	return MAX_DEPTH + (MAX_DEPTH - depth)

## Fisher-Yates through the run's own rng, so a seeded run always hides the
## same effect behind the same colour.
func _shuffle_shrines() -> void:
	shrine_hues = []
	for i in Shrines.COUNT:
		shrine_hues.append(i)
	for i in range(shrine_hues.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := shrine_hues[i]
		shrine_hues[i] = shrine_hues[j]
		shrine_hues[j] = swap
	shrine_known.clear()
	forge_cap_bonus = 0

func shrine_hue(kind: int) -> Color:
	if kind < 0 or kind >= shrine_hues.size():
		return Palette.UI_TEXT
	return Shrines.HUES[shrine_hues[kind]]

## What the player may call it. Unknown shrines are named by colour alone.
func shrine_label(kind: int) -> String:
	if shrine_known.has(kind):
		return Shrines.NAMES[kind]
	return "an unfamiliar shrine"

## The forging ceiling, which the anvil raises.
func upgrade_cap() -> int:
	return Item.MAX_UPGRADES + forge_cap_bonus

func item_can_upgrade(item: Item) -> bool:
	return item.is_equipment() and item.upgrade_level() < upgrade_cap()

## What a step onto this cell costs, for this actor.
func move_cost_for(actor: Entity, x: int, y: int) -> int:
	if actor.flying:
		return Scheduler.ACTION_COST
	var m := Tiles.move_cost(map.get_tile(x, y))
	if actor.heavy and m > 1.0:
		m += 0.6
	return int(round(Scheduler.ACTION_COST * m))

func room_threat_ceiling() -> int:
	return ROOM_THREAT_BASE + ROOM_THREAT_PER_DEPTH * effective_depth()

func cave_threat_ceiling() -> int:
	return int(round(room_threat_ceiling() * CAVE_THREAT_SCALE))

func _populate_room(room: Rect2i, archetype: int) -> void:
	if rng.randf() < 0.55:
		var ix := rng.randi_range(room.position.x, room.end.x - 1)
		var iy := rng.randi_range(room.position.y, room.end.y - 1)
		if map.is_walkable(ix, iy) and Vector2i(ix, iy) != stairs and items_at(ix, iy).is_empty():
			var loot := Item.roll(rng, effective_depth())
			if loot != null:
				loot.x = ix
				loot.y = iy
				ground.append(loot)

	# A shrine keeps a guardian; a collapsed room is where things nest.
	var bonus := 0
	if archetype == MapGen.Archetype.SHRINE or archetype == MapGen.Archetype.COLLAPSED:
		bonus = 1
	# The count roll is unchanged -- density is intentional. The ceiling only
	# stops that count from landing on something unsurvivable.
	var count := rng.randi_range(0, 2 + effective_depth() / 3) + bonus
	var spent := 0
	var ceiling := room_threat_ceiling()
	for _i in count:
		var cost := _spawn_in(Rect2i(room.position, room.size), ceiling - spent)
		if cost < 0:
			break
		spent += cost

func _populate_cave(region: Rect2i) -> void:
	# Caves are wilder than rooms, and unlit -- worth a little more danger.
	var count := rng.randi_range(1, 3 + effective_depth() / 3)
	var spent := 0
	var ceiling := cave_threat_ceiling()
	for _i in count:
		var cost := _spawn_in(region, ceiling - spent)
		if cost < 0:
			break
		spent += cost

## Returns the threat spent, or -1 if nothing was placed.
func _spawn_in(area: Rect2i, remaining: int) -> int:
	var mx := rng.randi_range(area.position.x, area.end.x - 1)
	var my := rng.randi_range(area.position.y, area.end.y - 1)
	if not map.is_walkable(mx, my) or entity_at(mx, my) != null:
		return 0
	if Vector2i(mx, my) == stairs or Vector2i(mx, my) == Vector2i(player.x, player.y):
		return 0
	var pick := _roll_monster(remaining)
	if pick.is_empty():
		return -1
	var m := Entity.new(pick["name"], pick["app"], mx, my)
	m.max_hp = pick["hp"]
	m.hp = pick["hp"]
	m.power = pick["power"]
	m.defense = pick["def"]
	m.speed = pick["speed"]
	m.ai = pick.get("ai", &"hunter")
	m.attack_range = pick.get("range", 1)
	m.flee_below = pick.get("flee", 0.0)
	m.regen = pick.get("regen", 0)
	m.flying = pick.get("flying", false)
	m.heavy = pick.get("heavy", false)
	m.threat = int(pick["threat"])
	# Gear raises what a monster is actually worth facing, so it must raise the
	# threat too. Otherwise a room of armed orcs quietly costs more than its
	# ceiling claims, and the survivability guarantee becomes a lie.
	m.threat += _arm_monster(m, pick, remaining - m.threat)
	entities.append(m)
	return m.threat

## Arms a monster within whatever threat budget is left, returning what the
## gear cost. Anything it cannot afford, it does not get.
func _arm_monster(m: Entity, pick: Dictionary, spare: int) -> int:
	var chance: float = pick.get("gear", 0.0)
	if chance <= 0.0 or rng.randf() >= chance:
		return 0

	var spent := 0
	for slot in [Item.Slot.WEAPON, Item.Slot.ARMOR]:
		if rng.randf() > 0.65:
			continue
		var it := Item.roll_equipment(rng, effective_depth(), slot)
		if it == null:
			continue
		# Melee only. A goblin handed a bow would carry reach its `pack` AI
		# never uses, which reads as a bug rather than a surprise.
		if it.range_bonus > 1:
			continue
		var cost := it.power_bonus + it.defense_bonus
		if spent + cost > spare:
			continue
		m.equipped[slot] = it
		m.inventory.append(it)
		spent += cost
	return spent

## Whatever a corpse leaves behind.
func _drop_loot(victim: Entity) -> void:
	for slot in victim.equipped:
		var it: Item = victim.equipped[slot]
		if rng.randf() > LOOT_DROP_CHANCE:
			continue
		it.x = victim.x
		it.y = victim.y
		it.letter = ""
		ground.append(it)
		msg_log.add("It drops the %s." % it.display_name(), Color(0.72, 0.78, 0.90))
	victim.equipped.clear()
	victim.inventory.clear()

## Weighted by tier, and filtered to what still fits under the ceiling.
##
## A monster is at full weight for its own tier and a grace depth after it,
## then fades. That is what stops depth 9 from spawning giant rats, and it is
## also why the ceiling alone would not be enough: without the fade, deep
## floors would just be many cheap monsters instead of few expensive ones.
func _roll_monster(remaining: int) -> Dictionary:
	var pool := []
	var total := 0.0
	# Past the deepest tier the fade stops advancing, so the heaviest monsters
	# stay at full weight instead of everything vanishing.
	var here := effective_depth()
	var effective := mini(here, deepest_tier() + TIER_GRACE)
	for e in BESTIARY:
		if e["min_depth"] > here:
			continue
		if int(e["threat"]) > remaining:
			continue
		var band := effective - int(e["min_depth"])
		var weight := 1.0 - TIER_FADE * float(maxi(0, band - TIER_GRACE))
		if weight <= 0.0:
			continue
		total += weight
		pool.append({"entry": e, "weight": weight})

	if pool.is_empty():
		return {}
	var pick := rng.randf() * total
	for p in pool:
		pick -= p["weight"]
		if pick <= 0.0:
			return p["entry"]
	return pool[-1]["entry"]

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
	if torch_flare > 0:
		radius = TORCH_RADIUS * FLARE_MULTIPLIER
	Fov.compute(map, player.x, player.y, radius, _fov_buffer)
	map.visible_now = _fov_buffer.duplicate()
	map.remember_visible()

	player.light.x = player.x
	player.light.y = player.y
	if torch_flare > 0:
		player.light.radius = TORCH_RADIUS * FLARE_MULTIPLIER
		player.light.intensity = 1.25
		player.light.color = Color(1.00, 0.94, 0.72)
		player.light.color_far = Color(0.45, 0.48, 0.62)
	elif torch_lit:
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

## Everything the player could shoot right now, nearest first. Drives target
## cycling, so the list the cursor walks is exactly the list of legal shots.
func firing_targets(reach: int = -1) -> Array:
	var out := []
	var r := player.total_range() if reach < 0 else reach
	if r <= 1:
		return out
	for e in entities:
		if e.is_player or not e.alive:
			continue
		if can_reach(Vector2i(e.x, e.y), r):
			out.append(e)
	out.sort_custom(func(a, b):
		return Los.steps(player.x, player.y, a.x, a.y) \
			< Los.steps(player.x, player.y, b.x, b.y))
	return out

## One reach test for shooting and throwing alike -- they differ only in how
## far the thing goes.
func can_reach(cell: Vector2i, reach: int) -> bool:
	if reach <= 1:
		return false
	if not map.is_visible(cell.x, cell.y):
		return false
	if Los.steps(player.x, player.y, cell.x, cell.y) > reach:
		return false
	return Los.clear(map, player.x, player.y, cell.x, cell.y)

func can_fire_at(cell: Vector2i) -> bool:
	return can_reach(cell, player.total_range())

func player_fire(cell: Vector2i) -> bool:
	if game_over:
		return false
	if player.total_range() <= 1:
		msg_log.add("You have nothing to shoot with.", Color(0.7, 0.6, 0.4))
		return false
	if not can_fire_at(cell):
		msg_log.add("You have no clear shot there.", Color(0.7, 0.6, 0.4))
		return false

	var target := entity_at(cell.x, cell.y)
	if target == null or target.is_player:
		# Refused rather than spent. With no ammunition there is nothing to be
		# gained by shooting empty floor, so a misclick should cost nothing.
		msg_log.add("There is nothing there to shoot.", Color(0.7, 0.6, 0.4))
		return false

	_travel.clear()
	_attack(player, target, true)
	_end_player_turn()
	return true

## Everything in the pack that could be hurled.
func throwables() -> Array:
	var out := []
	for it in player.inventory:
		if it.is_throwable():
			out.append(it)
	return out

## Hurling something. Weaker than a bow on purpose -- reach should not be free
## twice -- and the weapon lands where it hit, so throwing is a positioning
## decision rather than a consumable.
func player_throw(index: int, cell: Vector2i) -> bool:
	if game_over or index < 0 or index >= player.inventory.size():
		return false
	var item: Item = player.inventory[index]
	if not item.is_throwable():
		msg_log.add("You cannot throw the %s." % item.name, Color(0.7, 0.6, 0.4))
		return false
	if not can_reach(cell, item.throw_range):
		msg_log.add("You cannot reach there with the %s." % item.name,
			Color(0.7, 0.6, 0.4))
		return false

	var target := entity_at(cell.x, cell.y)
	if target == null or target.is_player:
		msg_log.add("There is nothing there to throw at.", Color(0.7, 0.6, 0.4))
		return false

	_travel.clear()
	if player.is_equipped(item):
		player.equipped.erase(item.slot)
	player.inventory.remove_at(index)
	item.letter = ""

	# Half your own strength behind it, plus whatever the thing is worth.
	var throw_power := item.power_bonus + int(player.power / 2)
	msg_log.add("You hurl the %s." % item.display_name(), Color(0.85, 0.88, 0.68))
	_attack(player, target, true, throw_power)

	# It lands where it struck, whether or not that killed anything.
	item.x = cell.x
	item.y = cell.y
	ground.append(item)

	_end_player_turn()
	return true

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

	var cost := move_cost_for(player, nx, ny)
	player.x = nx
	player.y = ny
	_end_player_turn(cost)
	return true

## Costs a turn on purpose. Going dark is a decision, not a free toggle.
func player_toggle_torch() -> bool:
	if game_over:
		return false
	if torch_flare > 0:
		msg_log.add("The flare will not be smothered. %d turns of it left."
			% torch_flare, Color(0.95, 0.80, 0.45))
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
## Praying is its own key so that walking onto a shrine can never spring a
## curse. A deliberate act, deliberately.
func player_pray() -> bool:
	if game_over:
		return false
	var here := Vector2i(player.x, player.y)
	if map.get_tile(here.x, here.y) != Tiles.SHRINE:
		msg_log.add("There is nothing here to pray at.", Color(0.7, 0.6, 0.4))
		return false

	var kind := int(shrine_at.get(here, Shrines.MENDING))
	_travel.clear()
	map.set_tile(here.x, here.y, Tiles.FLOOR)
	shrine_at.erase(here)
	shrine_known[kind] = true
	msg_log.add("You lay a hand on the %s." % Shrines.NAMES[kind],
		shrine_hue(kind))
	_invoke_shrine(kind)
	_end_player_turn()
	return true

func _invoke_shrine(kind: int) -> void:
	match kind:
		Shrines.QUIET:
			var n := 0
			for e in entities:
				if e.is_player or not e.alive:
					continue
				e.notice_block = QUIET_TURNS
				if e.alertness != Entity.Alert.ASLEEP:
					e.alertness = Entity.Alert.ASLEEP
					e.fleeing = false
					n += 1
			msg_log.add("A hush settles. %d things stop looking for you." % n,
				Color(0.70, 0.85, 0.95))

		Shrines.VIGIL:
			# Set directly rather than through wake(), which would log and
			# flash an exclamation mark for every monster on the floor.
			var n := 0
			for e in entities:
				if e.is_player or not e.alive:
					continue
				if e.alertness != Entity.Alert.AWAKE:
					e.alertness = Entity.Alert.AWAKE
					e.last_seen = Vector2i(player.x, player.y)
					e.lost_turns = 0
					n += 1
			msg_log.add("Something calls out, and %d things answer." % n,
				Color(0.95, 0.55, 0.40))

		Shrines.EMBERS:
			var n := 0
			for y in map.height:
				for x in map.width:
					if map.get_tile(x, y) != Tiles.BRAZIER_SPENT:
						continue
					map.set_tile(x, y, Tiles.BRAZIER)
					brazier_charge[Vector2i(x, y)] = BRAZIER_CHARGE / 2
					n += 1
			_gather_lights()
			msg_log.add("Cold ash catches. %d braziers burn again." % n,
				Color(0.98, 0.78, 0.42))

		Shrines.ANVIL:
			forge_cap_bonus += 1
			msg_log.add("Your hands remember an older craft. Metal will take "
				+ "another edge.", Color(0.85, 0.88, 0.70))

		Shrines.MENDING:
			var healed := player.max_hp - player.hp
			player.hp = player.max_hp
			msg_log.add("Warmth floods through you. %d hit points restored."
				% healed, Color(0.55, 0.85, 0.55))

		Shrines.SUMMONS:
			var before := entities.size()
			var area := Rect2i(player.x - 4, player.y - 4, 9, 9)
			for _i in rng.randi_range(1, 3):
				_spawn_in(area, room_threat_ceiling())
			var made := entities.size() - before
			for i in range(before, entities.size()):
				entities[i].alertness = Entity.Alert.AWAKE
			msg_log.add("The air splits, and %d things step through." % made,
				Color(0.95, 0.50, 0.45))

		Shrines.WEIGHT:
			var blessed := 0
			for slot in player.equipped:
				var it: Item = player.equipped[slot]
				it.upgrade()
				blessed += 1
			player.speed = WEIGHT_SPEED
			if blessed > 0:
				msg_log.add("Your gear drinks it in and grows heavier. You move "
					+ "slower for it.", Color(0.88, 0.86, 0.78))
			else:
				msg_log.add("The weight settles on you with nothing to bless. "
					+ "You move slower for nothing.", Color(0.75, 0.70, 0.62))

		Shrines.FLARE:
			torch_flare = FLARE_TURNS
			torch_lit = true
			msg_log.add("Your torch roars white. You can see far -- and be seen "
				+ "just as far.", Color(1.00, 0.90, 0.55))

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

## Total experience required to have reached `n`.
func xp_for_level(n: int) -> int:
	if n <= 1:
		return 0
	var k := n - 1
	return XP_CURVE_A * k * k + XP_CURVE_B * k

func xp_into_level() -> int:
	# Clamped: level only ever rises through award_xp today, but a drain effect
	# or a loaded save could get here with less xp than the level implies, and
	# a progress bar should not render backwards.
	return maxi(0, player.xp - xp_for_level(player.level))

func xp_needed_for_next() -> int:
	return xp_for_level(player.level + 1) - xp_for_level(player.level)

func award_xp(amount: int) -> void:
	if amount <= 0:
		return
	player.xp += amount
	while player.xp >= xp_for_level(player.level + 1):
		_level_up()

func _level_up() -> void:
	player.level += 1
	player.max_hp += LEVEL_HP
	# Healed by the gain, so a level is a small reprieve as well as a stat bump.
	player.hp = mini(player.max_hp, player.hp + LEVEL_HP)
	if player.level % 2 == 0:
		player.power += 1
	if player.level % 3 == 0:
		player.defense += 1
	msg_log.add("You reach level %d." % player.level, Color(0.98, 0.90, 0.45))
	events.append({"kind": &"levelup", "to": Vector2i(player.x, player.y)})

## Is there a lit brazier beside the player with enough heat left to forge?
func can_forge_here() -> bool:
	var b := _adjacent_brazier()
	return b.x >= 0 and int(brazier_charge.get(b, 0)) >= MERGE_COST

## Can this specific item be forged right now? Drives the inventory marker, so
## the mechanic advertises itself instead of relying on the player guessing
## which of the two items involved is the one to click.
func can_forge_item(item: Item) -> bool:
	return item_can_upgrade(item) and _find_duplicate(item) != null \
		and can_forge_here()

## Merge the item at `index` with an identical one from the pack, at a brazier.
func player_merge(index: int) -> bool:
	if game_over or index < 0 or index >= player.inventory.size():
		return false
	var item: Item = player.inventory[index]

	if not item.is_equipment():
		msg_log.add("Only weapons and armour can be worked.", Color(0.7, 0.6, 0.4))
		return false
	if not item_can_upgrade(item):
		msg_log.add("The %s cannot take another edge." % item.display_name(),
			Color(0.7, 0.6, 0.4))
		return false

	var brazier := _adjacent_brazier()
	if brazier.x < 0:
		msg_log.add("You need a lit brazier to work metal.", Color(0.7, 0.6, 0.4))
		return false
	if int(brazier_charge.get(brazier, 0)) < MERGE_COST:
		msg_log.add("The brazier has not the heat left.", Color(0.7, 0.6, 0.4))
		return false

	var donor := _find_duplicate(item)
	if donor == null:
		msg_log.add("You have nothing else like the %s." % item.name,
			Color(0.7, 0.6, 0.4))
		return false

	_travel.clear()
	if player.is_equipped(donor):
		player.equipped.erase(donor.slot)
	player.inventory.erase(donor)
	donor.letter = ""

	item.upgrade()
	brazier_charge[brazier] = int(brazier_charge[brazier]) - MERGE_COST
	msg_log.add("You work the metal together over the flame. (%s)" % item.display_name(),
		Color(0.85, 0.88, 0.70))
	if int(brazier_charge[brazier]) <= 0:
		brazier_charge.erase(brazier)
		map.set_tile(brazier.x, brazier.y, Tiles.BRAZIER_SPENT)
		_gather_lights()
		msg_log.add("The brazier gutters out.", Color(0.58, 0.55, 0.50))

	_end_player_turn()
	return true

## Any other item of the same kind, whatever its own upgrade level.
##
## Requiring matched levels was the first version and it made the cost
## geometric -- four daggers for a +2 rather than three. The cap already does
## the balancing, so the simpler rule wins.
func _find_duplicate(item: Item) -> Item:
	for other in player.inventory:
		if other != item and other.id == item.id:
			return other
	return null

func _adjacent_spent_brazier() -> Vector2i:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var c := Vector2i(player.x + dx, player.y + dy)
			if map.get_tile(c.x, c.y) == Tiles.BRAZIER_SPENT:
				return c
	return Vector2i(-1, -1)

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
	# Paid for the floor just survived, not the one being entered.
	var earned := room_threat_ceiling() * XP_DEPTH_MULTIPLIER
	depth += 1
	build_level()
	msg_log.add("You descend to depth %d." % depth, Color(0.85, 0.72, 0.45))
	award_xp(earned)
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
	if item.kind == Item.Kind.AMULET:
		_seize_amulet(item)
		return true
	ground.erase(item)
	give_item(item)
	msg_log.add("You pick up the %s (%s)." % [item.name, item.letter],
		Color(0.75, 0.80, 0.90))
	_end_player_turn()
	return true

## Taking the amulet turns the run around.
##
## The dungeon is regenerated rather than restored, which the fiction covers:
## the artefact was trapped, and the depths rearrange behind you. That justifies
## both the new layout and the heavier population, and it costs nothing --
## remembering ten floors would have meant serialising them.
func _seize_amulet(relic: Item) -> void:
	ground.erase(relic)
	give_item(relic)
	ascending = true

	msg_log.add("You lift the Amulet of the Deep. The dungeon shudders.",
		Color(1.00, 0.88, 0.45))
	msg_log.add("Stone grinds on stone. When it stills, nothing is where you "
		+ "left it.", Color(0.85, 0.80, 0.70))
	msg_log.add("More eyes than before catch your torchlight. The way out is "
		+ "up.", Color(0.95, 0.70, 0.40))

	build_level()
	update_vision()

## Climbing out. Pays for the floor survived, exactly as descending does.
func player_ascend() -> bool:
	if game_over:
		return false
	if map.get_tile(player.x, player.y) != Tiles.STAIRS_UP:
		msg_log.add("There is no way up here.", Color(0.7, 0.6, 0.4))
		return false

	var earned := room_threat_ceiling() * XP_DEPTH_MULTIPLIER
	depth -= 1
	if depth <= 0:
		won = true
		game_over = true
		award_xp(earned)
		write_morgue()
		msg_log.add("You climb into daylight, the Amulet of the Deep in hand. "
			+ "You have escaped. Press R to descend again.",
			Color(1.00, 0.92, 0.55))
		return true

	build_level()
	msg_log.add("You climb to depth %d." % depth, Color(0.85, 0.72, 0.45))
	award_xp(earned)
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
			var dead := _adjacent_spent_brazier()
			if dead.x >= 0:
				map.set_tile(dead.x, dead.y, Tiles.BRAZIER)
				brazier_charge[dead] = RELIGHT_CHARGE
				_gather_lights()
				msg_log.add("The scroll's light pours into the dead brazier. "
					+ "It catches, weakly.", Color(0.98, 0.82, 0.45))
				return true

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
	var cost := move_cost_for(player, next.x, next.y)
	player.x = next.x
	player.y = next.y
	_end_player_turn(cost)
	return true

func _end_player_turn(cost: int = Scheduler.ACTION_COST) -> void:
	Scheduler.spend(player, cost)
	turns += 1
	if torch_flare > 0:
		torch_flare -= 1
		if torch_flare == 0:
			msg_log.add("The flare gutters down to an ordinary flame.",
				Color(0.80, 0.75, 0.60))
	update_vision()
	_run_world()
	update_vision()

# ----------------------------------------------------------- world turn ----

# ----------------------------------------------------------- persistence ----

static func has_suspend() -> bool:
	return FileAccess.file_exists(SUSPEND_PATH)

static func clear_suspend() -> void:
	if FileAccess.file_exists(SUSPEND_PATH):
		DirAccess.remove_absolute(SUSPEND_PATH)

func save_suspend() -> bool:
	var f := FileAccess.open(SUSPEND_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict()))
	f.close()
	return true

## Reads the slot and immediately destroys it. That deletion is the entire
## anti-scum mechanism: there is never a moment when a save from *before*
## something went wrong still exists.
static func load_suspend() -> GameState:
	if not has_suspend():
		return null
	var f := FileAccess.open(SUSPEND_PATH, FileAccess.READ)
	if f == null:
		return null
	var text := f.get_as_text()
	f.close()
	clear_suspend()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	var gs := GameState.new(1)
	if not gs.apply_dict(parsed):
		return null
	return gs

func _shrines_to_dict() -> Dictionary:
	var out := {}
	for cell in shrine_at:
		out["%d,%d" % [cell.x, cell.y]] = int(shrine_at[cell])
	return out

func to_dict() -> Dictionary:
	var mobs := []
	for e in entities:
		mobs.append(e.to_dict())
	var loot := []
	for it in ground:
		loot.append(it.to_dict())
	var charges := {}
	for cell in brazier_charge:
		charges["%d,%d" % [cell.x, cell.y]] = int(brazier_charge[cell])
	var caves := []
	for r in cave_regions:
		caves.append([r.position.x, r.position.y, r.size.x, r.size.y])
	var rooms := []
	for r in room_rects:
		rooms.append([r.position.x, r.position.y, r.size.x, r.size.y])
	var lines := []
	for entry in msg_log.entries:
		var c: Color = entry["color"]
		lines.append({"t": entry["text"], "n": entry["count"], "c": [c.r, c.g, c.b]})

	return {
		"version": SAVE_VERSION,
		# Strings, not numbers: JSON stores numbers as doubles, and a 64-bit
		# rng state would quietly lose its low bits -- so a resumed run would
		# drift away from the one that was saved.
		"seed": str(rng.seed), "state": str(rng.state),
		"depth": depth, "turns": turns, "ascending": ascending,
		"won": won, "game_over": game_over, "torch_lit": torch_lit,
		"cause": death_cause,
		"w": map.width, "h": map.height,
		"tiles": Marshalls.raw_to_base64(map.tiles),
		"material": Marshalls.raw_to_base64(map.material),
		"explored": Marshalls.raw_to_base64(map.explored),
		"stairs": [stairs.x, stairs.y],
		"braziers": charges, "caves": caves, "rooms": rooms,
		"shrines": _shrines_to_dict(), "hues": shrine_hues,
		"known": shrine_known.keys(), "forge_bonus": forge_cap_bonus,
		"flare": torch_flare,
		"entities": mobs, "player": entities.find(player),
		"ground": loot, "log": lines,
	}

func apply_dict(d: Dictionary) -> bool:
	if int(d.get("version", 0)) != SAVE_VERSION:
		return false

	rng.seed = str(d.get("seed", "0")).to_int()
	rng.state = str(d.get("state", "0")).to_int()
	depth = int(d.get("depth", 1))
	turns = int(d.get("turns", 0))
	ascending = d.get("ascending", false)
	won = d.get("won", false)
	game_over = d.get("game_over", false)
	torch_lit = d.get("torch_lit", true)
	death_cause = d.get("cause", "")

	map = DungeonMap.new(int(d.get("w", MAP_W)), int(d.get("h", MAP_H)))
	map.tiles = Marshalls.base64_to_raw(d.get("tiles", ""))
	map.material = Marshalls.base64_to_raw(d.get("material", ""))
	map.explored = Marshalls.base64_to_raw(d.get("explored", ""))
	light_map = LightMap.new(map.width, map.height)
	var buf := PackedByteArray()
	buf.resize(map.width * map.height)
	_fov_buffer = buf

	var st: Array = d.get("stairs", [0, 0])
	stairs = Vector2i(int(st[0]), int(st[1]))

	brazier_charge.clear()
	var charges: Dictionary = d.get("braziers", {})
	for key in charges:
		var parts: PackedStringArray = String(key).split(",")
		if parts.size() == 2:
			brazier_charge[Vector2i(parts[0].to_int(), parts[1].to_int())] = int(charges[key])

	shrine_at.clear()
	var saved_shrines: Dictionary = d.get("shrines", {})
	for key in saved_shrines:
		var bits: PackedStringArray = String(key).split(",")
		if bits.size() == 2:
			shrine_at[Vector2i(bits[0].to_int(), bits[1].to_int())] = int(saved_shrines[key])
	shrine_hues.clear()
	for h in d.get("hues", []):
		shrine_hues.append(int(h))
	shrine_known.clear()
	for k in d.get("known", []):
		shrine_known[int(k)] = true
	forge_cap_bonus = int(d.get("forge_bonus", 0))
	torch_flare = int(d.get("flare", 0))

	cave_regions.clear()
	for r in d.get("caves", []):
		cave_regions.append(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
	room_rects.clear()
	for r in d.get("rooms", []):
		room_rects.append(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))

	entities = []
	for entry in d.get("entities", []):
		entities.append(Entity.from_dict(entry))
	var pi := int(d.get("player", 0))
	if pi < 0 or pi >= entities.size():
		return false
	player = entities[pi]
	# Derived, never stored: the torch is rebuilt from the saved torch_lit.
	player.light = LightSource.new(player.x, player.y, TORCH_RADIUS,
		Color(1.00, 0.72, 0.36), Color(0.30, 0.34, 0.55), 1.0, true)

	ground = []
	for entry in d.get("ground", []):
		var it := Item.from_dict(entry)
		if it != null:
			ground.append(it)

	msg_log = MessageLog.new()
	for entry in d.get("log", []):
		var c: Array = entry.get("c", [1, 1, 1])
		msg_log.entries.append({"text": entry.get("t", ""),
			"count": int(entry.get("n", 1)),
			"color": Color(float(c[0]), float(c[1]), float(c[2]))})

	events = []
	_travel.clear()
	pathfinder = Pathfinder.new(map)
	_gather_lights()
	update_vision()
	return true

# --------------------------------------------------------------- morgue ----

func morgue_line() -> String:
	var when := Time.get_datetime_string_from_system(false, true)
	var fate := ""
	if won:
		fate = "escaped the dungeon with the Amulet of the Deep"
	elif death_cause != "":
		fate = "%s on depth %d" % [death_cause, depth]
	else:
		fate = "left the dungeon on depth %d" % depth
	var carried := "with the Amulet" if _carrying_amulet() else "empty-handed"
	return "%s  level %d  %s, %s, after %d turns" \
		% [when, player.level, fate, carried, turns]

func _carrying_amulet() -> bool:
	for it in player.inventory:
		if it.kind == Item.Kind.AMULET:
			return true
	return false

func write_morgue() -> void:
	var f := FileAccess.open(MORGUE_PATH, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(MORGUE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(morgue_line())
	f.close()

func _run_world() -> void:
	for _guard in 500:
		var actor := Scheduler.next_actor(entities)
		if actor == null or actor.is_player:
			return
		Scheduler.spend(actor, _take_ai_turn(actor))

## Returns what the turn cost -- difficult ground slows monsters exactly as it
## slows the player, which is the whole reason mud can be used as a shield.
func _take_ai_turn(actor: Entity) -> int:
	if not actor.alive or game_over:
		return Scheduler.ACTION_COST

	# Regeneration ticks even while asleep, so a troll you wounded and fled
	# from is whole again when you come back. That is the point of it.
	if actor.regen > 0 and actor.hp < actor.max_hp:
		actor.hp = mini(actor.max_hp, actor.hp + actor.regen)

	_update_awareness(actor)
	# Asleep, or merely stirring: it spends its turn not acting. That pause is
	# the player's window to withdraw, and it is the point of the middle state.
	if actor.alertness != Entity.Alert.AWAKE:
		return Scheduler.ACTION_COST

	_update_morale(actor)
	_last_move_cost = Scheduler.ACTION_COST
	if actor.fleeing:
		_ai_flee(actor)
		return _last_move_cost

	match actor.ai:
		&"erratic": _ai_erratic(actor)
		&"ranged":  _ai_ranged(actor)
		&"pack":    _ai_pack(actor)
		_:          _ai_hunter(actor)
	return _last_move_cost

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

	if actor.notice_block > 0:
		actor.notice_block -= 1
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

	if dist <= actor.total_range() and Los.clear(map, actor.x, actor.y, player.x, player.y):
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
	_last_move_cost = move_cost_for(actor, step.x, step.y)
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
	_last_move_cost = move_cost_for(actor, pick.x, pick.y)
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
	_last_move_cost = move_cost_for(actor, best.x, best.y)
	actor.x = best.x
	actor.y = best.y
	return true

func _attack(attacker: Entity, defender: Entity, ranged: bool = false,
		power_override: int = -1) -> void:
	var atk := attacker.total_power() if power_override < 0 else power_override

	# Swinging a bow is not fighting. Without this an archer has no reason to
	# fear being adjacent, and the whole peek-and-duck loop has no stakes: you
	# could stand toe to toe with a launcher in hand and lose almost nothing.
	var clumsy := power_override < 0 and not ranged and attacker.total_range() > 1
	if clumsy:
		atk = maxi(1, int(attacker.power / 2))

	var raw := atk - defender.total_defense() + rng.randi_range(-1, 1)
	var least := int(ceil(float(atk) * DAMAGE_FLOOR_FRACTION))
	var dmg := maxi(maxi(1, least), raw)
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
		if ranged:
			msg_log.add("You shoot the %s for %d." % [defender.name, dmg],
				Color(0.85, 0.88, 0.68))
		elif clumsy:
			msg_log.add("You club at the %s for %d -- a poor weapon up close."
				% [defender.name, dmg], Color(0.85, 0.75, 0.55))
		else:
			msg_log.add("You hit the %s for %d." % [defender.name, dmg],
				Color(0.80, 0.85, 0.70))
	elif ranged:
		msg_log.add("The %s shoots you for %d." % [attacker.name, dmg], Color(0.95, 0.62, 0.35))
	else:
		msg_log.add("The %s hits you for %d." % [attacker.name, dmg], Color(0.90, 0.45, 0.40))

	if not defender.alive:
		if defender.is_player:
			game_over = true
			death_cause = "killed by a %s" % attacker.name
			write_morgue()
			msg_log.add("You die. Press R to begin again.", Color(1.0, 0.35, 0.35))
		else:
			msg_log.add("The %s dies." % defender.name, Color(0.65, 0.70, 0.85))
			_drop_loot(defender)
			if attacker.is_player:
				award_xp(defender.threat)
