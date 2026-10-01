class_name CreatureMarks
extends RefCounted

## What a creature's condition looks like: the marker over its head and the
## wash under its feet. Both views ask here, so the two can never disagree
## about whether a monster is asleep, alarmed, fleeing or hurt -- each only
## decides how to draw the answer. (Moved out of GlyphGrid.)

## The marker over a creature's head, as {"text", "colour"}; empty when there
## is nothing to say. Awareness markers are STATE, not events -- they persist
## for as long as the monster is in that state, unlike the one-shot "!".
## The spores a creature carries, as the colour of its outline -- the visual
## tell (Brad, 2026-09-29): red means "kill it and it comes back", purple that
## its body will rot into purple. Transparent for an unmarked creature.
static func spore_colour(e: Entity) -> Color:
	match e.spores:
		&"red":
			return Palette.FUNGUS_RED
		&"purple":
			return Palette.FUNGUS_PURPLE
	return Color(0, 0, 0, 0)

static func awareness(e: Entity) -> Dictionary:
	# Frozen solid (the gem of frost), with the turns it has left: nothing
	# else it was is true while it stands there, and the count is the whole
	# play -- cross the room before it runs out.
	if e.frozen > 0:
		return {"text": "✶%d" % e.frozen, "colour": Palette.FROZEN}
	# Unaware AND actually asleep. A patrolling guard has not noticed you
	# either, but it is walking -- drawing "z" over something mid-stride would
	# be the marker telling a plain lie, and the marker is how a player decides
	# whether to sneak past.
	if e.alertness == Entity.Alert.ASLEEP \
			and e.activity == Entity.Activity.SLEEPING:
		# Cycles z / zZ / zzZ so it reads as breathing rather than a label.
		var phase := int(Time.get_ticks_msec() / 420.0) % 3 if Effects.any() else 1
		return {"text": ["z", "zZ", "zzZ"][phase], "colour": Palette.SLEEP}
	if e.alertness == Entity.Alert.SUSPICIOUS:
		return {"text": "?", "colour": Palette.ALERT}
	if e.activity == Entity.Activity.PATROLLING:
		# BUSY, AND NOT WITH YOU.
		#
		# Drawing nothing would be truthful but ambiguous -- an unmarked
		# creature is one you have to work out for yourself, and the markers
		# exist precisely so you do not have to. "z" was the first attempt and
		# read as sleepwalking; this says "occupied" without claiming the thing
		# is unaware, which is the honest state of a guard walking a beat.
		var tick := int(Time.get_ticks_msec() / 380.0) % 3 if Effects.any() else 2
		return {"text": [".", "..", "..."][tick], "colour": Palette.SLEEP}
	if e.fleeing:
		# A creature running away looked exactly like one hunting you, which
		# is the difference between spending three turns chasing and letting
		# it go. Every other state had a mark; this one was simply missed.
		return {"text": "<<", "colour": Palette.FLEEING}
	return {}

## Blood under a hurt creature, rather than a tint on it: the colour and alpha
## of the wash, or a transparent colour when it is whole.
##
## Tinting was tried and measured first, and it does not work: pulling every
## wounded thing toward the same red collapses the palette that was built to
## keep them apart. At a mix strong enough to read, a critical wyvern and a
## critical dragon came out deltaE 15.5 under deuteranopia -- one creature.
## A wash underneath is a channel of its own. Deliberately NOT dimmed by the
## light map: a monster you can see is a monster whose condition you can see.
static func wound(e: Entity) -> Color:
	var w := e.wound()
	if w == Entity.Wound.WHOLE:
		return Color(0, 0, 0, 0)
	var tone := Palette.CRITICAL if w == Entity.Wound.CRITICAL else Palette.BLOODIED
	var alpha := Palette.CRITICAL_WASH if w == Entity.Wound.CRITICAL \
		else Palette.BLOODIED_WASH
	return Color(tone, alpha)
