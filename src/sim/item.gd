class_name Item
extends RefCounted

## A carryable thing.
##
## Deliberately restricted to effects that need no targeting UI. Targeting is
## its own feature -- a cursor, a line-of-fire check, range validation -- and
## folding it in here would triple the size of this step for no gain. Fireball
## can wait until there is something to aim it with.

enum Kind { POTION, SCROLL }

var id: StringName
var name: String
var appearance: StringName
var kind: int
var effect: StringName
var magnitude: int

## Only meaningful while lying on the floor.
var x: int
var y: int

const CATALOGUE := {
	&"potion_healing": {
		"name": "potion of healing", "app": &"potion", "kind": Kind.POTION,
		"effect": &"heal", "magnitude": 12, "min_depth": 1, "weight": 12,
	},
	&"scroll_light": {
		"name": "scroll of light", "app": &"scroll", "kind": Kind.SCROLL,
		"effect": &"light", "magnitude": 16, "min_depth": 1, "weight": 6,
	},
	&"scroll_blink": {
		"name": "scroll of blink", "app": &"scroll", "kind": Kind.SCROLL,
		"effect": &"blink", "magnitude": 12, "min_depth": 2, "weight": 6,
	},
}

static func make(item_id: StringName) -> Item:
	var data: Dictionary = CATALOGUE[item_id]
	var it := Item.new()
	it.id = item_id
	it.name = data["name"]
	it.appearance = data["app"]
	it.kind = data["kind"]
	it.effect = data["effect"]
	it.magnitude = data["magnitude"]
	return it

## Weighted pick from everything legal at this depth.
static func roll(rng: RandomNumberGenerator, depth: int) -> Item:
	var pool := []
	var total := 0
	for key in CATALOGUE:
		var data: Dictionary = CATALOGUE[key]
		if data["min_depth"] > depth:
			continue
		total += data["weight"]
		pool.append({"id": key, "weight": data["weight"]})
	if pool.is_empty():
		return null
	var pick := rng.randi_range(1, total)
	for entry in pool:
		pick -= entry["weight"]
		if pick <= 0:
			return make(entry["id"])
	return make(pool[-1]["id"])
