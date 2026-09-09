class_name Item
extends RefCounted

## A carryable thing: consumables and equipment.
##
## Equipment deliberately modifies the `power` and `defense` fields that
## already exist on Entity. No stat system is needed to make a sword work, and
## adding one now would be inventing a dependency that isn't there.

enum Kind { POTION, SCROLL, WEAPON, ARMOR, AMULET }
## OFFHAND is the shield hand. A launcher claims it -- see is_two_handed --
## which is what turns "bow or blade" from a damage question into a posture.
enum Slot { NONE = -1, WEAPON, ARMOR, OFFHAND }

var id: StringName
var name: String
var appearance: StringName
var kind: int
var slot: int = Slot.NONE

# Consumable fields
var effect: StringName = &""
var magnitude: int = 0
## How much one forging adds to `magnitude`. Zero means this cannot be worked
## at a brazier at all, which is how the catalogue says "not forgeable" without
## anything having to name items by id.
##
## Set to two thirds of the base value, so a merge is worth two thirds of the
## second copy it eats. That is the whole balance of it: you give up raw
## healing and get back a turn and an inventory slot. Free would remove the
## decision; much less would make it a trap.
var forge_bonus: int = 0
## Forgings applied to a consumable. Equipment carries the same information in
## its power and defense bonuses, so this stays zero there.
var boosts: int = 0

# Equipment fields
var power_bonus: int = 0
var defense_bonus: int = 0
## Ammunition, carried by the launcher rather than by the pack.
##
## Anyone with a bow has a quiver, so a quiver does not need an inventory slot
## -- and putting the count on the weapon puts it where the decision is made,
## beside the reach in the sidebar.
##
## `ammo_max` is the real constraint, not scarcity in the world. A floor grows
## about thirty rubble tiles and each gives two or three stones, so there are
## sixty to ninety lying around; if a sling could hold them all, nothing would
## ever tax it. Capacity plus the turns spent reloading is the cost.
##
## Stones outnumber arrows on purpose -- a pouch of pebbles against a quiver --
## which makes the sling the sustainable, feeble option and the bow the strong,
## finite one. That is a real difference between the two launcher families,
## which until now differed only in numbers.
var ammo: int = 0
var ammo_max: int = 0
## What this launcher fires, so a sling cannot be loaded with arrows.
var ammo_kind: StringName = &""

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

	# What a rabbit leaves. Its magnitude is written at the moment it drops --
	# exactly the fungus the thing ate -- so the meat is a refund of what was
	# taken and never a profit on it. See GameState._drop_meat.
	&"meat": {
		"name": "haunch of rabbit", "app": &"meat", "kind": Kind.POTION,
		"effect": &"heal", "magnitude": 1,
		"min_depth": 999, "weight": 0,
	},

	&"potion_healing": {
		"name": "potion of healing", "app": &"potion", "kind": Kind.POTION,
		"effect": &"heal", "magnitude": 12, "forge": 8,
		"min_depth": 1, "weight": 12,
	},
	&"scroll_light": {
		"name": "scroll of light", "app": &"scroll", "kind": Kind.SCROLL,
		"effect": &"light", "magnitude": 16, "forge": 4,
		"min_depth": 1, "weight": 6,
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
		# Four, not five. Reported from play as "I can take out enemies before
		# they reach me" -- and the fix is reach rather than damage, because
		# damage has nowhere left to go.
		#
		# Measured: total_power() ADDS the launcher to your own, so weapons
		# converge as you level. A sling is half a war bow's shot at level one
		# and 78% of it by level nineteen, and by then the sling itself is 6%
		# of what it fires -- the rest is your arm. Dropping power below 1 would
		# change nothing anybody could feel.
		#
		# Reach is what makes a ranged weapon a KITING tool rather than a
		# backup, so that is the honest lever: four against a short bow's seven
		# and a war bow's eight. The sling stays the thing you use when
		# something is nearly on you and you have free stones from the rubble.
		"name": "sling", "app": &"launcher", "kind": Kind.WEAPON,
		"slot": Slot.WEAPON, "power": 1, "range": 4, "min_depth": 1, "weight": 5,
		"ammo_max": 30, "ammo_kind": &"stone",
	},
	&"short_bow": {
		"name": "short bow", "app": &"launcher", "kind": Kind.WEAPON,
		"slot": Slot.WEAPON, "power": 3, "range": 7, "min_depth": 3, "weight": 4,
		"ammo_max": 16, "ammo_kind": &"arrow",
	},
	&"war_bow": {
		"name": "war bow", "app": &"launcher", "kind": Kind.WEAPON,
		"slot": Slot.WEAPON, "power": 5, "range": 8, "min_depth": 6, "weight": 3,
		"ammo_max": 20, "ammo_kind": &"arrow",
	},

	## Shields. Kind.ARMOR so the inventory filter and the "wear" verb both find
	## them; Slot.OFFHAND so they sit beside a weapon rather than instead of
	## armour.
	##
	## The values are derived, not chosen. Damage never falls below a quarter of
	## the attacker's power, so defense buys nothing past the point where an
	## enemy is already hitting the floor -- and those points are known:
	##
	##     cave troll  def 7      shadow        def 10
	##     wight       def 8      young dragon  def 11
	##     wyvern      def 9
	##
	## Base defense is 4 by level 9 and plate mail is 5, so nine is where a
	## well-equipped character already sits. That makes the ladder read cleanly:
	## a buckler floors the shadow, a kite shield floors the young dragon, and a
	## tower shield buys one point of margin past everything in the game. Any
	## larger and the extra would do literally nothing.
	&"buckler": {
		"name": "buckler", "app": &"shield", "kind": Kind.ARMOR,
		"slot": Slot.OFFHAND, "defense": 1, "min_depth": 1, "weight": 6,
	},
	&"kite_shield": {
		"name": "kite shield", "app": &"shield", "kind": Kind.ARMOR,
		"slot": Slot.OFFHAND, "defense": 2, "min_depth": 3, "weight": 4,
	},
	&"tower_shield": {
		"name": "tower shield", "app": &"shield", "kind": Kind.ARMOR,
		"slot": Slot.OFFHAND, "defense": 3, "min_depth": 6, "weight": 2,
	},

	## Spent arrows lying on the floor. Never rolled as loot -- they only exist
	## because you shot them -- so weight is zero and min_depth is out of reach.
	&"arrows": {
		"name": "spent arrows", "app": &"ammo", "kind": Kind.SCROLL,
		"min_depth": 999, "weight": 0,
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
	it.forge_bonus = data.get("forge", 0)
	it.power_bonus = data.get("power", 0)
	it.defense_bonus = data.get("defense", 0)
	it.range_bonus = data.get("range", 1)
	it.ammo_max = data.get("ammo_max", 0)
	it.ammo_kind = data.get("ammo_kind", &"")
	# A launcher found on the floor arrives loaded. An empty one would look
	# broken rather than interesting.
	it.ammo = it.ammo_max
	it.throw_range = data.get("throw", 0)
	it.base_power_bonus = it.power_bonus
	it.base_defense_bonus = it.defense_bonus
	return it

## How many times this item has been merged.
## One expression for both: equipment carries its level in the stat bonuses it
## has gained, a consumable in `boosts`, and the other term is always zero.
func upgrade_level() -> int:
	return (power_bonus - base_power_bonus) \
		+ (defense_bonus - base_defense_bonus) + boosts

func can_upgrade() -> bool:
	return can_be_forged() and upgrade_level() < MAX_UPGRADES

## Anything the brazier can work: gear, and any consumable the catalogue gave a
## forge bonus to.
func can_be_forged() -> bool:
	return is_equipment() or forge_bonus > 0

## Applies one merge. Weapons gain power, armour gains defense, and a
## consumable gains potency.
func upgrade() -> void:
	if not is_equipment():
		boosts += 1
	elif kind == Kind.WEAPON:
		power_bonus += 1
	else:
		defense_bonus += 1

## What the effect is actually worth, after forging.
func effective_magnitude() -> int:
	return magnitude + boosts * forge_bonus

## Name as the player should see it, carrying any upgrades.
func display_name() -> String:
	var up := upgrade_level()
	return name if up == 0 else "%s +%d" % [name, up]

func is_throwable() -> bool:
	return throw_range > 0

func is_equipment() -> bool:
	return slot != Slot.NONE

## A launcher needs both hands, so it cannot be carried with a shield.
##
## This is the whole point of the offhand slot. Reach was already paid for in
## damage -- at every tier the ranged option is about two points weaker than
## the melee one -- and now it is paid for in defense as well. "Bow or blade"
## stops being a damage question and becomes a posture: strike first from
## eight cells, or be harder to kill up close.
## A launcher with a quiver, as opposed to a club that happens to have reach.
func uses_ammo() -> bool:
	return ammo_max > 0

func is_two_handed() -> bool:
	return is_equipment() and range_bonus > 1

## What the item does when clicked, for messages and the inventory hint.
func verb() -> String:
	match kind:
		Kind.POTION: return "drink"
		Kind.SCROLL: return "read"
		Kind.WEAPON: return "wield"
		Kind.ARMOR:  return "raise" if slot == Slot.OFFHAND else "wear"
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

# ------------------------------------------------------------ persistence ---

## Only what cannot be recovered from the catalogue. Everything static -- name,
## glyph, base bonuses, reach -- is looked up again on load, so a later balance
## change reaches saved runs instead of being frozen into them.
func to_dict() -> Dictionary:
	return {
		"id": String(id), "letter": letter, "x": x, "y": y,
		"pow": power_bonus, "def": defense_bonus, "ammo": ammo,
		# Forgings on a consumable live nowhere else. Without this a suspended
		# run gives back plain potions, and the brazier charge that made them
		# is gone. `forge_bonus` itself is not saved: it comes from the
		# catalogue, so it rebuilds itself on load.
		"boost": boosts,
	}

static func from_dict(d: Dictionary) -> Item:
	var key := StringName(d.get("id", ""))
	if not CATALOGUE.has(key):
		return null
	var it := make(key)
	it.letter = d.get("letter", "")
	it.x = int(d.get("x", 0))
	it.y = int(d.get("y", 0))
	it.power_bonus = int(d.get("pow", it.power_bonus))
	it.defense_bonus = int(d.get("def", it.defense_bonus))
	# Absent in saves written before consumables could be forged, and zero is
	# exactly right for those.
	it.boosts = int(d.get("boost", 0))
	# Saves written before launchers held ammunition come back loaded rather
	# than empty: a resumed run should not find its bow inexplicably dry.
	it.ammo = int(d.get("ammo", it.ammo_max))
	return it

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
