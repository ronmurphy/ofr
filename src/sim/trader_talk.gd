class_name TraderTalk
extends RefCounted

## What the trader says, and whether you have heard the beginning of it.
##
## The trader is a monster that stopped wanting to fight. It is fascinated by
## adventurers, it collects what the dead leave behind, and it carries the stock
## between the bands -- which is why it is only ever found on the first floor of
## one. Trading is the excuse; what it actually wants is the conversation, and
## to hear that somebody is getting on well.
##
## THE FIRST MEETING DOES NOT TELL THE TRUTH ABOUT THE AMULET. The trader
## believes what everyone believes: that the thing at the bottom stops the flow
## of monsters. It does the opposite, and only the lich knows, having given up
## being an adventurer to own the fact. That is a late revelation and it costs
## something to reach -- putting it in the first thirty seconds would spend the
## only secret the game has on a player who has not yet met a kobold.
##
## What the trader does say, because it is true and it is theirs: it cannot go
## near the amulet. Things like it cannot. That is the whole reason it needs
## somebody like you, and it is said plainly rather than asked for.

const SECTION := "story"
const KEY := "met_trader"

## Has this player ever heard the introduction?
##
## In settings.cfg rather than the save, deliberately. The suspend slot is
## DESTROYED when it loads -- that is the anti-scum rule -- so a flag living
## there would either vanish on the first load or replay the introduction every
## run. This belongs with the things that describe the player rather than the
## run, beside the bestiary and the pad bindings.
static func intro_seen() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(GameState.SETTINGS_PATH) != OK:
		return false
	return bool(cfg.get_value(SECTION, KEY, false))

static func mark_intro_seen() -> void:
	var cfg := ConfigFile.new()
	# Loaded first so this does not wipe the view and audio sections that share
	# the file.
	cfg.load(GameState.SETTINGS_PATH)
	cfg.set_value(SECTION, KEY, true)
	cfg.save(GameState.SETTINGS_PATH)

const AMULET_ART := "res://assets/art/amulet-of-deep.png"
const TRADER_ART := "res://assets/art/trader.png"

## The first meeting. Told once per player, on floor one.
##
## The clipped cadence is deliberate and it is characterisation, not shorthand:
## this is something that learned to speak by listening to people who were
## mostly shouting, and it has never had anybody correct it.
static func intro() -> Array:
	return [
		{"text": "You are not running.\n\nMost run.", "art": TRADER_ART},
		{"text": "I am not going to fight you. I have never wanted to. I wanted to ask how you are.",
		 "art": TRADER_ART},
		{"text": "You came for the amulet. Everyone comes for the amulet.\n\nThey say it stops the monsters coming. Nobody says how, and nobody who went to look has come back to explain it.",
		 "art": AMULET_ART},
		{"text": "That is it. I saw it once, from a long way off.\n\nI could not go closer. Things like me cannot.",
		 "art": AMULET_ART},
		{"text": "You can. That is the only difference between us that matters down here.",
		 "art": TRADER_ART},
		{"text": "I collect. It is what I am for. Armour nobody is wearing any more, blades, stones out of the shrines. I carry it between the floors.",
		 "art": TRADER_ART},
		{"text": "So come and find me when you have something you do not want. I will take it, and I will ask how you are getting on, and you will tell me.\n\nThat is the trade.",
		 "art": TRADER_ART},
		TALLY,
		{"text": "Go carefully.\n\nAnd if you ever reach the top still holding it -- I would like very much to know what the daylight does.",
		 "art": TRADER_ART},
	]

## HOW THE COUNTER COUNTS, with the scale -- the rule alone is not enough.
##
## Gabe, 2026-09-25: he liked the trader but "it took a moment to figure out
## the points value", and Brad had stalled the same way on the first night. The
## cause is floor one itself: it sells tier 1 only, so every number on the
## counter is 1, and a column of 1s reads as a count rather than a price. The
## first trader never shows two different values. So the trader SAYS them,
## 1 / 3 / 9, before the player ever sees the counter.
const TALLY := {
	"text": "I keep a tally. What you leave with me, I count; what you take, I count back.\n\nA dagger is worth one to me. A short sword, three. A war axe, nine. Gems I count apart -- bring me three and choose one.",
	"art": TRADER_ART}

## Every meeting after the first, until there is something to trade.
##
## Short on purpose. A player who walks into the trader on floor seven wants to
## be reminded who this is, not told the whole thing again. On FLOOR ONE the
## tally is said again (Brad's call): it is the first counter of the run, and
## the one whose prices are all 1.
static func greeting(first_floor := false) -> Array:
	var out := [
		{"text": "You are still going.\n\nGood. Tell me how it is down there.",
		 "art": TRADER_ART},
	]
	if first_floor:
		out.append(TALLY)
	out.append({"text": "Show me what you are carrying.\n\nI will take anything that is not the amulet, and you can have anything on my shelf that you can pay for.",
		 "art": TRADER_ART})
	return out
