class_name Entity
extends RefCounted

## Anything that occupies a cell. The player is not a special case -- it is an
## Entity with `is_player` set. That is deliberate: when a party arrives later,
## it is four of these in a list rather than a new concept.

enum Faction { PLAYER, MONSTER, NEUTRAL }

## Three states rather than two. A binary asleep/awake makes stealth feel
## arbitrary -- you are either invisible or caught, with no warning. The middle
## state is the tell that lets a player back off before it is too late.
enum Alert { ASLEEP, SUSPICIOUS, AWAKE }

var name: String = "thing"
var appearance: StringName = &"unknown"
var x: int
var y: int
var blocks: bool = true
var is_player: bool = false
var faction: int = Faction.MONSTER

var hp: int = 1
var max_hp: int = 1
var power: int = 1
var defense: int = 0

## Energy economy: an actor gains `speed` per tick and spends
## Scheduler.ACTION_COST to act. speed 100 is the human baseline; 150 is a
## dog, 50 is a zombie. Building this in from the start rather than bolting it
## on later is the difference between a half hour and a painful refactor.
var speed: int = 100
var energy: int = 0

## Carried items. Lives on Entity rather than on the player specifically, so
## lootable corpses later are a read of this field rather than a new system.
var inventory: Array = []
const INVENTORY_MAX := 20

## Item.Slot -> Item. Equipped things stay in `inventory` and are merely
## flagged here, which is how most roguelikes do it and saves inventing a
## second screen to move things between two lists.
var equipped: Dictionary = {}

## How this actor decides what to do. See GameState._take_ai_turn.
##   hunter  - walks at you and hits you
##   erratic - moves unpredictably; hard to disengage from
##   ranged  - attacks along a clear line, and backs off when crowded
##   pack    - bold with allies nearby, hesitant alone
## This game's challenge rating, and what a kill is worth in XP.
var threat: int = 0

var level: int = 1
var xp: int = 0

var ai: StringName = &"none"

## Attacks beyond 1 cell need a clear line of sight, which is what turns a
## pillar from decoration into cover.
var attack_range: int = 1

## How close a ranged attacker lets you get before it gives ground.
##
## One for the slinger and the dragon, which stand and shoot until you are
## actually on top of them. Higher for something that fights at arm's length by
## choice -- and note that a stand-off is only survivable for the PLAYER if the
## thing doing it is slower than they are, or it simply never gets caught.
var standoff: int = 1

## How far this can blink away, and how long before it can do it again. Zero
## range means it cannot -- only the arch lich does, today.
##
## The cooldown is what keeps it a fight rather than a chore: with no cooldown
## a teleporter can never be cornered, so it does nothing but chip you forever,
## which is tedious rather than difficult.
var blink_range: int = 0
var blink_cool: int = 0

## Walks through stone. Nothing else does, and it is half of what makes the
## banshee unanswerable by hiding -- you cannot put a wall between you and it.
var phasing := false
## How many cells this creature's melee hit shoves its target back. 0 for
## everything that fights by standing still and swinging.
var knockback := 0
## Follows its own knockback into the ground it just cleared, so the shove buys
## the target no distance at all. Meaningless without `knockback`.
var charges := false
## Damage types this shrugs off, and the one that finds it. Lists rather than
## single values: a skeleton has nothing to cut AND nothing to puncture, and an
## arrow goes between the ribs.
##
## Deliberately NOT keyed on `unliving`. A golem resists a sword because it is
## made of rock, a skeleton because there is no flesh on it -- same effect,
## different reason, and a future creature could have one without the other.
var resists: Array[StringName] = []
var weak_to: Array[StringName] = []

## Dead, or never alive in the way that matters. Skeletons, wights, shadows,
## banshees and the lich.
##
## Three separate rules want this and none of them is about combat: a wolf's
## howl wakes the LIVING, a rat disguise does not fool the dead, and a dropped
## fungus offends them rather than drawing them. The stone golem is
## deliberately NOT one -- it was never alive, but it is not a corpse either,
## and every rule here is about things that used to breathe.
var unliving := false

## Turns of frost left on it. Slows its movement, not its attacks -- a chilled
## thing still swings as hard, it just cannot close or flee as fast.
var chilled := 0

## A low-tier creature the climb has made worse. Cosmetically a colour, but the
## flag is what the renderer and the bestiary key on -- and what stops a
## corrupted thing being mistaken for its own base entry in a save.
var corrupted := false

## Came up out of a grave wearing a dead run's gear. Its kit is the player's
## own, so it hands ALL of it back rather than rolling per item -- see
## GameState._drop_loot.
var risen := false
## Finds you without seeing you, and without caring how dark it is. The other
## half: dousing the torch is the game's main defence, and this ignores it.
var senses := false
## How far its cry carries, and how long until the next one. Zero radius means
## it has no cry. The cooldown is what makes it a rhythm you can race rather
## than a wall of noise.
var wail_radius: int = 0
var wail_cool: int = 0

## Turns this actor is occupied and cannot act. The rabbit's mouthful is the
## only user today, and it is the whole reason the rabbit is catchable: a thing
## faster than you that never stops is not a monster, it is scenery.
var busy: int = 0
## How much of the floor's fungus this has eaten. Drives both the meat it
## leaves and, at RABBIT_TURNS, what it becomes.
var meal: int = 0

## Runs once hp falls to this fraction of max. 0.0 never breaks -- undead and
## mindless things should not.
var flee_below: float = 0.0
var fleeing: bool = false

## Hit points recovered each turn. A regenerating monster cannot be chipped
## down and then escaped from -- you either commit to the kill or you have
## wasted the damage, which makes disengaging a real decision rather than a
## free one.
var regen: int = 0

## Difficult ground is nothing to something that never touches it.
var flying := false
## And it is worse for something that sinks. Heavy things suffer most in mud,
## which is what makes mud a tool rather than only a hazard -- back across it
## and the ogre falls behind while you do not.
var heavy := false

## Monsters start asleep. Until this pass everything was omnisciently aware the
## instant the player could see it, which handed the initiative to whatever was
## in the room.
var alertness: int = Alert.ASLEEP
var notice_range: int = 8
var last_seen := Vector2i(-1, -1)
var lost_turns: int = 0
var calm_turns: int = 0
## Turns during which this cannot notice the player at all. Without it the
## shrine of the quiet buys about two turns -- everything simply re-notices the
## lit figure standing next to it, and the shrine reads as broken.
var notice_block: int = 0
var light: LightSource = null

var alive: bool = true

func _init(n: String, app: StringName, px: int, py: int) -> void:
	name = n
	appearance = app
	x = px
	y = py

## Base power/defense plus whatever is worn. Combat reads only these, so a
## stat system later slots in here rather than at every call site.
func total_power() -> int:
	var v := power
	for slot in equipped:
		v += equipped[slot].power_bonus
	return v

## Effective reach: innate, or whatever is being wielded, whichever is longer.
func total_range() -> int:
	var r := attack_range
	for slot in equipped:
		r = maxi(r, equipped[slot].range_bonus)
	return r

func total_defense() -> int:
	var v := defense
	for slot in equipped:
		v += equipped[slot].defense_bonus
	return v

func is_equipped(item) -> bool:
	for slot in equipped:
		if equipped[slot] == item:
			return true
	return false

# ------------------------------------------------------------ persistence ---

## Equipped gear is stored as indices into `inventory`, because the two hold
## the SAME objects -- writing them out twice would restore a monster wearing a
## copy of its own armour, and dropping it would leave a duplicate behind.
func to_dict() -> Dictionary:
	var pack := []
	for it in inventory:
		pack.append(it.to_dict())
	var worn := {}
	for slot in equipped:
		var idx := inventory.find(equipped[slot])
		if idx >= 0:
			worn[str(slot)] = idx
	return {
		"name": name, "app": String(appearance), "x": x, "y": y,
		"blocks": blocks, "is_player": is_player, "faction": faction,
		"hp": hp, "max_hp": max_hp, "power": power, "defense": defense,
		"speed": speed, "energy": energy, "threat": threat,
		"level": level, "xp": xp, "ai": String(ai),
		"attack_range": attack_range, "standoff": standoff,
		"blink_range": blink_range, "blink_cool": blink_cool,
		"phasing": phasing, "senses": senses, "knockback": knockback,
		"charges": charges, "risen": risen, "corrupted": corrupted,
		"unliving": unliving,
		"resists": resists, "weak_to": weak_to,
		"chilled": chilled,
		"wail_radius": wail_radius, "wail_cool": wail_cool,
		"busy": busy, "meal": meal,
		"flee_below": flee_below,
		"fleeing": fleeing, "regen": regen, "alertness": alertness,
		"notice_range": notice_range, "last_seen": [last_seen.x, last_seen.y],
		"lost_turns": lost_turns, "calm_turns": calm_turns,
		"notice_block": notice_block, "alive": alive,
		"flying": flying, "heavy": heavy,
		"inventory": pack, "equipped": worn,
	}

static func from_dict(d: Dictionary) -> Entity:
	var e := Entity.new(d.get("name", "thing"),
		StringName(d.get("app", "unknown")), int(d.get("x", 0)), int(d.get("y", 0)))
	e.blocks = d.get("blocks", true)
	e.is_player = d.get("is_player", false)
	e.faction = int(d.get("faction", Faction.MONSTER))
	e.hp = int(d.get("hp", 1))
	e.max_hp = int(d.get("max_hp", 1))
	e.power = int(d.get("power", 1))
	e.defense = int(d.get("defense", 0))
	e.speed = int(d.get("speed", 100))
	e.energy = int(d.get("energy", 0))
	e.threat = int(d.get("threat", 0))
	e.level = int(d.get("level", 1))
	e.xp = int(d.get("xp", 0))
	e.ai = StringName(d.get("ai", "none"))
	e.attack_range = int(d.get("attack_range", 1))
	e.standoff = int(d.get("standoff", 1))
	e.blink_range = int(d.get("blink_range", 0))
	e.blink_cool = int(d.get("blink_cool", 0))
	e.phasing = bool(d.get("phasing", false))
	e.senses = bool(d.get("senses", false))
	e.wail_radius = int(d.get("wail_radius", 0))
	e.wail_cool = int(d.get("wail_cool", 0))
	e.busy = int(d.get("busy", 0))
	e.meal = int(d.get("meal", 0))
	e.flee_below = float(d.get("flee_below", 0.0))
	e.fleeing = d.get("fleeing", false)
	e.regen = int(d.get("regen", 0))
	e.alertness = int(d.get("alertness", Alert.ASLEEP))
	e.notice_range = int(d.get("notice_range", 8))
	var seen: Array = d.get("last_seen", [-1, -1])
	e.last_seen = Vector2i(int(seen[0]), int(seen[1]))
	e.lost_turns = int(d.get("lost_turns", 0))
	e.calm_turns = int(d.get("calm_turns", 0))
	e.notice_block = int(d.get("notice_block", 0))
	e.flying = d.get("flying", false)
	e.heavy = d.get("heavy", false)
	e.knockback = int(d.get("knockback", 0))
	e.charges = d.get("charges", false)
	e.risen = d.get("risen", false)
	e.corrupted = d.get("corrupted", false)
	e.unliving = d.get("unliving", false)
	e.resists.clear()
	for r in d.get("resists", []):
		e.resists.append(StringName(r))
	e.weak_to.clear()
	for w in d.get("weak_to", []):
		e.weak_to.append(StringName(w))
	e.chilled = int(d.get("chilled", 0))
	e.alive = d.get("alive", true)

	for entry in d.get("inventory", []):
		var it := Item.from_dict(entry)
		if it != null:
			e.inventory.append(it)
	var worn: Dictionary = d.get("equipped", {})
	for slot_key in worn:
		var idx := int(worn[slot_key])
		if idx >= 0 and idx < e.inventory.size():
			e.equipped[int(slot_key)] = e.inventory[idx]
	return e

func distance_to(other: Entity) -> float:
	return Vector2(x - other.x, y - other.y).length()

## Chebyshev distance -- the correct adjacency test on an 8-way grid.
func steps_to(other: Entity) -> int:
	return maxi(absi(x - other.x), absi(y - other.y))

## D&D's word for it: at or below half. A second step at a quarter, because by
## then the question has changed from "can I win this" to "can I finish it
## before it finishes me".
enum Wound { WHOLE, BLOODIED, CRITICAL }

func wound() -> int:
	if hp * 4 <= max_hp:
		return Wound.CRITICAL
	if hp * 2 <= max_hp:
		return Wound.BLOODIED
	return Wound.WHOLE

func is_adjacent(other: Entity) -> bool:
	return steps_to(other) == 1

func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)
	if hp == 0:
		alive = false
		blocks = false
