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

## THE MIRROR TELL (Brad's design 2026-09-21, built 2026-10-04). A creature
## whose shield carries the mirror throws your blows back, and until now your
## first sign of it was your own hit landing on you: _arm_monster hands out
## weapon and armour only, but a scavenger takes a shield off the floor, and a
## floor shield can carry reflect (day-7 hunt, 2026-10-04). So it wears the
## same outline the spore carriers wear, in the colour of a stone.
##
## Still: a steady frame in Palette.MAGIC, the blue the player already reads
## as "this carries an enchantment". Simple and full: the same blue
## brightening to a pale glint and back, MIRROR_PERIOD seconds a lap, so the
## thing visibly SHINES. Anchored on MAGIC rather than a hue of its own so it
## is read as that colour moving (Brad, 2026-10-04: close enough to the magic
## colour to be associated with it; the exact stops are mine to tune). One
## mechanism, both renderers, no new system -- and the still form is the
## motion-sensitive tester's fallback by construction. The same shine lies on
## a mirror shield on the FLOOR (GlyphGrid, DioramaView): a visual identifier
## before you pick it up.
const MIRROR_PERIOD := 2.0
const MIRROR_LIGHT := Color("8db0ff")
const MIRROR_GLINT := Color("d6e6ff")
## When a creature carries BOTH tells, the view with one outline shows each in
## turn, this long apiece.
const MIRROR_TURN := 0.9

static func wears_a_mirror(e: Entity) -> bool:
	return e.offhand_tier(&"reflect") > 0

## A mirror shield itself, lying anywhere: it shines the same way.
static func is_a_mirror(it: Item) -> bool:
	return it.element == &"reflect" and it.slot == Item.Slot.OFFHAND

## The mirror's colour at `clock` (seconds; negative means the wall clock).
static func mirror_colour(clock := -1.0) -> Color:
	if not Effects.any():
		return Palette.MAGIC
	var t := _clock(clock)
	var stops := [Palette.MAGIC, MIRROR_LIGHT, MIRROR_GLINT]
	var lap := fposmod(t, MIRROR_PERIOD) / MIRROR_PERIOD * stops.size()
	var i := int(lap) % stops.size()
	var frac := lap - floorf(lap)
	# Eased, so the colour rests at each stop rather than sweeping through.
	return (stops[i] as Color).lerp(stops[(i + 1) % stops.size()], smoothstep(0.0, 1.0, frac))

## The frame round a creature, as the classic view draws it and the sidebar
## rings it: the fungus it carries first -- red means "kill it and it comes
## back", and that outranks a shield -- else the mirror, else nothing.
static func outline(e: Entity, clock := -1.0) -> Color:
	var spore := spore_colour(e)
	if spore.a > 0.0:
		return spore
	if wears_a_mirror(e):
		return mirror_colour(clock)
	return Color(0, 0, 0, 0)

## A second frame inside the first: the mirror, when the spores took the
## outline (a red risen that kept its shield). Transparent otherwise.
static func inner_outline(e: Entity, clock := -1.0) -> Color:
	if spore_colour(e).a > 0.0 and wears_a_mirror(e):
		return mirror_colour(clock)
	return Color(0, 0, 0, 0)

## For a view with ONE outline to give (the 3D card): both tells take turns
## while effects run, MIRROR_TURN each. On still the spores win, and the
## mirror shows in the sidebar's ring and in the classic view's inner frame
## -- the one place the 3D still view says less than the 2D one.
static func single_outline(e: Entity, clock := -1.0) -> Color:
	var inner := inner_outline(e, clock)
	if inner.a > 0.0 and Effects.any() \
			and int(_clock(clock) / MIRROR_TURN) % 2 == 1:
		return inner
	return outline(e, clock)

## Whether a frame round this creature changes between frames -- the views
## ask before redrawing every frame for it.
static func outline_moves(e: Entity) -> bool:
	return Effects.any() and wears_a_mirror(e)

static func _clock(clock: float) -> float:
	return clock if clock >= 0.0 else Time.get_ticks_msec() / 1000.0

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
