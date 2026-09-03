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
var ai: StringName = &"none"

## Attacks beyond 1 cell need a clear line of sight, which is what turns a
## pillar from decoration into cover.
var attack_range: int = 1

## Runs once hp falls to this fraction of max. 0.0 never breaks -- undead and
## mindless things should not.
var flee_below: float = 0.0
var fleeing: bool = false

## Monsters start asleep. Until this pass everything was omnisciently aware the
## instant the player could see it, which handed the initiative to whatever was
## in the room.
var alertness: int = Alert.ASLEEP
var notice_range: int = 8
var last_seen := Vector2i(-1, -1)
var lost_turns: int = 0
var calm_turns: int = 0
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

func distance_to(other: Entity) -> float:
	return Vector2(x - other.x, y - other.y).length()

## Chebyshev distance -- the correct adjacency test on an 8-way grid.
func steps_to(other: Entity) -> int:
	return maxi(absi(x - other.x), absi(y - other.y))

func is_adjacent(other: Entity) -> bool:
	return steps_to(other) == 1

func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)
	if hp == 0:
		alive = false
		blocks = false
