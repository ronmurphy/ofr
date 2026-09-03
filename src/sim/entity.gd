class_name Entity
extends RefCounted

## Anything that occupies a cell. The player is not a special case -- it is an
## Entity with `is_player` set. That is deliberate: when a party arrives later,
## it is four of these in a list rather than a new concept.

enum Faction { PLAYER, MONSTER, NEUTRAL }

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

var ai: StringName = &"none"
var light: LightSource = null

var alive: bool = true

func _init(n: String, app: StringName, px: int, py: int) -> void:
	name = n
	appearance = app
	x = px
	y = py

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
