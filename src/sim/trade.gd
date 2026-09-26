class_name Trade
extends RefCounted

## WHAT THINGS ARE WORTH TO THE TRADER.
##
## Pure arithmetic over an item: reaches for no game state and makes no random
## draws, which is the two-part test this project uses before splitting anything
## out of GameState (see threat.gd, the first one to pass it). The trader's
## STATE -- stock, credit, what has been rolled -- lives on GameState; the
## PRICES live here, where they can be read and tested without a dungeon.
##
## The economy was settled with Brad on 2026-09-23 and is written up in full in
## BACKLOG.md. The short version:
##
##   - Three denominations, one word per catalogue row (`Item.tier`).
##   - An item is worth what it cost to make: a +2 dagger consumed daggers to
##     become that, so it counts as those daggers.
##   - THE TRADER CONVERTS WITHIN A CURRENCY, NEVER ACROSS. Equipment is
##     fungible junk; gems are what the magic system runs on, so gems trade
##     only for gems. Price a gem in equipment points and nine daggers buy
##     magic, which ends the chest's reason to exist.
##   - Consumables are SOLD, never bought. Their value is situational -- a potion
##     at full health on floor 1 against one at 5 hp on floor 9 -- so any fixed
##     buying price is wrong in both directions. And meat comes from hunting;
##     paying for it would turn hunting into income and quietly undo the
##     scarcity the caves are built on.
##   - Selling and buying are at PAR. No margin, so a mistaken sale can be bought
##     straight back at no loss, and there is no loop that manufactures value.

## Tier -> points. The whole equipment price list.
const POINTS := {1: 1, 2: 3, 3: 9}

## What a bound gem adds to an item's worth. A BOUND gem is not a gem: a free
## one is portable and chosen, which is what makes it the better prize, while a
## bound one is locked to that item forever. So buying one is buying a single
## magic weapon, not magic in general, and it is priced in equipment points.
##
## Found magic and bound magic cost the same because the code cannot tell them
## apart -- `Item.element` is one field, set by generation and by binding alike.
const MAGIC := 9

## The trader will put something random into an item for this much. The same
## bargain the world already offers -- found magic -- on demand. A gem stays
## better because it is portable and CHOSEN; this is neither.
const ENCHANT := 9

## Gems for a gem of your choice.
const GEMS_FOR_ONE := 3

## PROVISIONAL -- nobody has settled these yet. What the trader asks for the
## consumables it stocks. Three points is a tier-2 item: a short sword buys a
## potion. Brad to tune after play.
const SELLS := {
	&"potion_healing": 3,
	&"scroll_light": 3,
	&"scroll_blink": 3,
}

## The gem of the road's element. Named once, here, for the counter's rules.
const ROAD := &"travel"

## Armour with the road bound into it: sold only when offered twice.
static func carries_road(it: Item) -> bool:
	return it != null and not is_gem(it) and it.element == ROAD

static func is_gem(it: Item) -> bool:
	return it != null and it.kind == Item.Kind.GEM

## What the trader GIVES for this, in points. 0 means it will not take it -- ask
## `refusal` why. Gems are 0 here on purpose: they are a separate currency.
static func worth(it: Item) -> int:
	if it == null or not refusal(it).is_empty() or is_gem(it):
		return 0
	# `upgrade_level`, never `boosts`. Equipment keeps its forging in its power
	# and defense bonuses and leaves `boosts` at zero -- that field is for
	# consumables. The first version read `boosts`, so every forged weapon and
	# armour sold at base price, and its test set `boosts` by hand and agreed.
	var base: int = int(POINTS.get(it.tier, 0)) * (1 + it.upgrade_level())
	return base + (MAGIC if it.element != &"" else 0)

## What the trader ASKS for this. Equipment at par; consumables off the list.
static func price(it: Item) -> int:
	if it == null:
		return 0
	if SELLS.has(it.id):
		return int(SELLS[it.id])
	return worth(it)

## Why the trader will not take this, in its own voice. Empty when it will.
static func refusal(it: Item) -> String:
	if it == null:
		return "There is nothing there."
	if it.kind == Item.Kind.AMULET:
		return "The trader will not touch it. \"Not that. Never that.\""
	if is_gem(it):
		# The one stone the trader will not take -- Brad, 2026-09-26. Every
		# other gem is a third of a gem of your choice; this one cannot be had
		# any other way than walking the dungeon, and the trader knows it.
		if it.element == ROAD:
			return "The trader turns the stone over and over in its hands. \"A stone of the road. I held one once, a long time ago. I will not take this from you.\""
		return ""
	if it.unique:
		return "\"I have never seen another. I cannot say what it is worth.\""
	# "I sell those" only for what it genuinely sells. Arrows and bones are
	# filed as scrolls too, and the trader stocks neither -- telling a player
	# it sells arrows would send them looking for something that is not there.
	if SELLS.has(it.id):
		return "\"I sell those. I do not buy them.\""
	if it.kind == Item.Kind.POTION or it.kind == Item.Kind.SCROLL:
		return "\"That is no use to me.\""
	if it.tier <= 0:
		return "\"That is worth nothing to me.\""
	return ""
