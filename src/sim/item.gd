class_name Item
extends RefCounted

## A carryable thing: consumables and equipment.
##
## Equipment deliberately modifies the `power` and `defense` fields that
## already exist on Entity. No stat system is needed to make a sword work, and
## adding one now would be inventing a dependency that isn't there.

enum Kind { POTION, SCROLL, WEAPON, ARMOR }
enum Slot { NONE = -1, WEAPON, ARMOR }

var id: StringName
var name: String
var appearance: StringName
var kind: int
var slot: int = Slot.NONE

# Consumable fields
var effect: StringName = &""
var magnitude: int = 0

# Equipment fields
var power_bonus: int = 0
var defense_bonus: int = 0

## Stable inventory letter, held from pickup until the item leaves the pack.
var letter: String = ""

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

	&"dagger": {
		"name": "dagger", "app": &"weapon", "kind": Kind.WEAPON,
		"slot": Slot.WEAPON, "power": 2, "min_depth": 1, "weight": 7,
	},
	&"short_sword": {
		"name": "short sword", "app": &"weapon", "kind": Kind.WEAPON,
		"slot": Slot.WEAPON, "power": 4, "min_depth": 2, "weight": 5,
	},
	&"war_axe": {
		"name": "war axe", "app": &"weapon", "kind": Kind.WEAPON,
		"slot": Slot.WEAPON, "power": 7, "min_depth": 4, "weight": 3,
	},
	&"leather_armour": {
		"name": "leather armour", "app": &"armour", "kind": Kind.ARMOR,
		"slot": Slot.ARMOR, "defense": 1, "min_depth": 1, "weight": 7,
	},
	&"chain_mail": {
		"name": "chain mail", "app": &"armour", "kind": Kind.ARMOR,
		"slot": Slot.ARMOR, "defense": 3, "min_depth": 3, "weight": 5,
	},
	&"plate_mail": {
		"name": "plate mail", "app": &"armour", "kind": Kind.ARMOR,
		"slot": Slot.ARMOR, "defense": 5, "min_depth": 5, "weight": 2,
	},
}

static func make(item_id: StringName) -> Item:
	var data: Dictionary = CATALOGUE[item_id]
	var it := Item.new()
	it.id = item_id
	it.name = data["name"]
	it.appearance = data["app"]
	it.kind = data["kind"]
	it.slot = data.get("slot", Slot.NONE)
	it.effect = data.get("effect", &"")
	it.magnitude = data.get("magnitude", 0)
	it.power_bonus = data.get("power", 0)
	it.defense_bonus = data.get("defense", 0)
	return it

func is_equipment() -> bool:
	return slot != Slot.NONE

## What the item does when clicked, for messages and the inventory hint.
func verb() -> String:
	match kind:
		Kind.POTION: return "drink"
		Kind.SCROLL: return "read"
		Kind.WEAPON: return "wield"
		Kind.ARMOR:  return "wear"
	return "use"

## Past-tense marker shown against an equipped item.
func equipped_text() -> String:
	return "wielded" if kind == Kind.WEAPON else "worn"

## A short "+2" style tag for the inventory list.
func bonus_text() -> String:
	if power_bonus != 0:
		return "+%d power" % power_bonus
	if defense_bonus != 0:
		return "+%d defense" % defense_bonus
	return ""

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
