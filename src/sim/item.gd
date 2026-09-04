class_name Item
extends RefCounted

## A carryable thing: consumables and equipment.
##
## Equipment deliberately modifies the `power` and `defense` fields that
## already exist on Entity. No stat system is needed to make a sword work, and
## adding one now would be inventing a dependency that isn't there.

enum Kind { POTION, SCROLL, WEAPON, ARMOR, AMULET }
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
## Reach, for launchers. They sit in the weapon slot and trade damage for it:
## at every tier the ranged option is about two points weaker than the melee
## one, and that gap is the price of never being adjacent.
var range_bonus: int = 1
## How far this can be hurled. Zero means it cannot be -- a bow or a breastplate
## is not a missile. Light things fly further.
var throw_range: int = 0
## What this item rolled as. Upgrades are capped relative to this, so a dagger
## can never become a war axe -- merging improves an item, it does not replace
## the reason to find better ones.
var base_power_bonus: int = 0
var base_defense_bonus: int = 0

## A dagger tops out at +4, a short sword at +6, leather at +3, and so on.
const MAX_UPGRADES := 2

## Stable inventory letter, held from pickup until the item leaves the pack.
var letter: String = ""

## Only meaningful while lying on the floor.
var x: int
var y: int

const CATALOGUE := {
	## Never rolled -- placed by hand at the bottom of the dungeon.
	&"amulet": {
		"name": "Amulet of the Deep", "app": &"amulet", "kind": Kind.AMULET,
		"min_depth": 999, "weight": 0,
	},

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
		"slot": Slot.WEAPON, "power": 2, "throw": 5, "min_depth": 1, "weight": 7,
	},
	&"short_sword": {
		"name": "short sword", "app": &"weapon", "kind": Kind.WEAPON,
		"slot": Slot.WEAPON, "power": 4, "throw": 3, "min_depth": 2, "weight": 5,
	},
	&"war_axe": {
		"name": "war axe", "app": &"weapon", "kind": Kind.WEAPON,
		"slot": Slot.WEAPON, "power": 7, "throw": 2, "min_depth": 4, "weight": 3,
	},
	&"sling": {
		"name": "sling", "app": &"launcher", "kind": Kind.WEAPON,
		"slot": Slot.WEAPON, "power": 1, "range": 5, "min_depth": 1, "weight": 5,
	},
	&"short_bow": {
		"name": "short bow", "app": &"launcher", "kind": Kind.WEAPON,
		"slot": Slot.WEAPON, "power": 3, "range": 7, "min_depth": 3, "weight": 4,
	},
	&"war_bow": {
		"name": "war bow", "app": &"launcher", "kind": Kind.WEAPON,
		"slot": Slot.WEAPON, "power": 5, "range": 8, "min_depth": 6, "weight": 3,
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
	it.range_bonus = data.get("range", 1)
	it.throw_range = data.get("throw", 0)
	it.base_power_bonus = it.power_bonus
	it.base_defense_bonus = it.defense_bonus
	return it

## How many times this item has been merged.
func upgrade_level() -> int:
	return (power_bonus - base_power_bonus) + (defense_bonus - base_defense_bonus)

func can_upgrade() -> bool:
	return is_equipment() and upgrade_level() < MAX_UPGRADES

## Applies one merge. Weapons gain power, armour gains defense.
func upgrade() -> void:
	if kind == Kind.WEAPON:
		power_bonus += 1
	else:
		defense_bonus += 1

## Name as the player should see it, carrying any upgrades.
func display_name() -> String:
	var up := upgrade_level()
	return name if up == 0 else "%s +%d" % [name, up]

func is_throwable() -> bool:
	return throw_range > 0

func is_equipment() -> bool:
	return slot != Slot.NONE

## What the item does when clicked, for messages and the inventory hint.
func verb() -> String:
	match kind:
		Kind.POTION: return "drink"
		Kind.SCROLL: return "read"
		Kind.WEAPON: return "wield"
		Kind.ARMOR:  return "wear"
		Kind.AMULET: return "carry"
	return "use"

## Past-tense marker shown against an equipped item.
func equipped_text() -> String:
	return "wielded" if kind == Kind.WEAPON else "worn"

## A short "+2" style tag for the inventory list.
func bonus_text() -> String:
	if range_bonus > 1:
		return "+%d power  reach %d" % [power_bonus, range_bonus]
	if power_bonus != 0:
		return "+%d power" % power_bonus
	if defense_bonus != 0:
		return "+%d defense" % defense_bonus
	return ""

## Weighted pick from the equipment only, for one slot. Used to arm monsters,
## which must not be handed a potion.
static func roll_equipment(rng: RandomNumberGenerator, depth: int, want_slot: int) -> Item:
	var pool := []
	var total := 0
	for key in CATALOGUE:
		var data: Dictionary = CATALOGUE[key]
		if data["min_depth"] > depth or data.get("slot", Slot.NONE) != want_slot:
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
