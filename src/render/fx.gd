class_name Fx
extends RefCounted

## What the map shows HAPPENING, as opposed to what is.
##
## The simulation resolves a turn instantly and always will; these are the
## pictures of it -- a number rising off a hit, an arrow crossing the room, a
## noise spreading. ONE list for both views: the classic grid and the 3D view
## hold the same Fx, read the same effects with the same timings and the same
## rules about what may be shown, and differ only in how they draw them. A new
## effect is added here once, and each view gains a few lines to draw it.
##
## Moved out of GlyphGrid, where every rule below was first worked out. The
## comments came with it.
##
## Deliberately generic: a floating damage number and an overhead "!" are the
## same thing -- a marker that appears above a cell and fades.

## Roughly DCSS's pace. A quarter-second per cell would add a second and a half
## to every archer's turn, hundreds of times a run.
const SHOT_PER_CELL := 0.028
const FLASH_LIFE := 0.30
const POPUP_LIFE := 0.85
## How long a noise ring dwells on each cell it crosses.
##
## Per CELL, not per ring, so every wavefront travels at the same speed and a
## bigger noise takes longer to arrive rather than moving faster. With a fixed
## lifetime a floor-wide shrine and a footstep on bones crossed their very
## different distances in the same fraction of a second, which read as the loud
## one being quicker rather than larger.
const RING_PER_CELL := 0.045
## How long a knockback chevron stays up. Deliberately the longest effect in
## the game -- longer than a popup -- because it is the only one explaining
## something the player did not do themselves. Brad asked for "a second or
## two"; this is short of that because effects here overlap the next turn, and
## it is the number to raise if the shove still reads as the screen jumping.
const SHOVE_LIFE := 0.80
## The breathe pass's impacts. Short: an impact is a moment, not a scene.
const BURST_LIFE := 0.45
const SHATTER_LIFE := 0.60
const HURT_LIFE := 0.55

## What a footstep throws up from the ground it lands on -- see footfalls().
## Each is the colour, how many bits, how long they last, and how they move:
## where they start (base, in cells above the floor), how far out (speed), how
## hard up (lift) and how fast they come down (fall). Water splashes up and
## drops fast, mud barely leaves the ground, rubble dust hangs and drifts. The
## colours are paler versions of the ground's own, so a splash reads as that
## ground thrown up and never as something new arriving.
const FOOTFALL := {
	Tiles.WATER:  {"colour": Color(0.62, 0.80, 0.90), "count": 8, "life": 0.38,
		"base": 0.04, "speed": 0.75, "lift": 1.90, "fall": 4.80},
	Tiles.MUD:    {"colour": Color(0.55, 0.44, 0.33), "count": 4, "life": 0.30,
		"base": 0.03, "speed": 0.35, "lift": 0.90, "fall": 3.60},
	Tiles.RUBBLE: {"colour": Color(0.62, 0.56, 0.47), "count": 4, "life": 0.70,
		"base": 0.05, "speed": 0.30, "lift": 0.45, "fall": 0.30},
}

## The effects in flight. Each is a Dictionary with a "type", a clock "t" in
## seconds (negative means "not yet": a delay) and whatever that type needs.
var list: Array = []
## Capture-only: stops effects ageing so a screenshot tool can park one at a
## chosen point in its life and photograph it.
##
## _shot waits several frames per image, which is easily longer than an effect
## lives, so every attempt to photograph the knockback chevron caught the frame
## after it had already been culled. Three rounds of hunting a rendering bug
## that was not there.
var hold := false
## Guards against an animation outliving the level it belongs to. Descending
## mid-flight would otherwise draw the old level's arrow on the new one.
var _map: DungeonMap = null

func running() -> bool:
	return not list.is_empty()

func clear() -> void:
	list.clear()

## Forget everything in flight when the level changes under it.
func watch_map(map: DungeonMap) -> void:
	if map != _map:
		_map = map
		list.clear()

func tick(delta: float) -> void:
	if hold or list.is_empty():
		return
	for e in list:
		e["t"] += delta
	list = list.filter(func(e): return not expired(e))

## Turns simulation events into effects. The outcome is already decided by the
## time this runs -- these only show the player what happened. `popup_size` is
## the classic view's font size, which its popups are measured against.
func add_events(evts: Array, popup_size: int) -> void:
	for e in evts:
		# EVERY event carries "to", including the ones with no animation --
		# this is read before the kind is looked at, so an event without one
		# does not fall through harmlessly, it freezes the game. A talk event
		# shipped without it for one build and walking into the trader hung.
		var to: Vector2i = e["to"]

		if e["kind"] == &"levelup":
			list.append({"type": &"popup", "cell": to, "t": 0.0,
				"text": "LEVEL UP", "colour": Palette.STAIRS, "size": popup_size})
			continue

		# Noise, drawn as the wavefront it already was.
		#
		# The simulation has always known exactly how far a sound carried, and
		# the player could only ever infer it. Showing it turns a hidden rule
		# into something you can plan around -- whether to take the shot when
		# there are two more of them in the next room.
		if e["kind"] == &"noise":
			# Motion, so it answers to the accessibility setting. The message
			# log still reports the same thing in words for anyone playing on
			# "still", so nothing is only available to people who can take the
			# movement.
			if Effects.any():
				var reach := int(e["radius"])
				list.append({"type": &"ring", "cell": to, "t": 0.0,
					"radius": reach,
					"life": maxf(0.12, float(reach) * RING_PER_CELL)})
			continue

		if e["kind"] == &"recall":
			# Drawn as a flight from the pile to the player, which is the same
			# path a shot takes in reverse -- so the picture says "these are
			# your arrows coming back" without a word.
			if Effects.any():
				var line := Los.path(e["from"].x, e["from"].y, to.x, to.y)
				if not line.is_empty():
					list.append({"type": &"shot", "path": line, "t": 0.0})
			continue

		if e["kind"] == &"shove":
			# You just moved two cells without pressing anything. Without a
			# mark where you landed that reads as the screen glitching rather
			# than as something having happened to you. A chevron rather than
			# a ring: a ring says something happened HERE, and the whole point
			# of a shove is that it happened in a DIRECTION.
			if Effects.any():
				var was: Vector2i = e["from"]
				list.append({"type": &"shove", "from": was, "to": to,
					"dir": Vector2i(signi(to.x - was.x), signi(to.y - was.y)),
					"t": 0.0, "life": SHOVE_LIFE})
			continue

		if e["kind"] == &"notice":
			# The Metal Gear beat: a big "!" over the head of whatever just
			# clocked you.
			list.append({"type": &"popup", "cell": to, "t": 0.0, "text": "!",
				"colour": Palette.ALERT, "size": popup_size + 3})
			continue

		# Everything else on the queue is for the ears. The same list feeds
		# SoundDeck, and most of what is on it -- noise carrying through
		# stone, a change of footing, crossing the health line -- has no
		# picture to draw by definition.
		if e["kind"] != &"melee" and e["kind"] != &"ranged":
			continue

		var hostile: bool = e["on_player"]
		var delay := 0.0

		if e["kind"] == &"ranged":
			var line := Los.path(e["from"].x, e["from"].y, to.x, to.y)
			if not line.is_empty():
				list.append({"type": &"shot", "path": line, "t": 0.0})
				delay = line.size() * SHOT_PER_CELL

		# Negative time is a delay: the impact lands when the shot arrives.
		list.append({"type": &"flash", "cell": to, "t": -delay,
			"colour": Palette.HP_BAD if hostile else Palette.HIT_FLASH})
		list.append({"type": &"popup", "cell": to, "t": -delay,
			"text": str(e["amount"]),
			"colour": Palette.HP_BAD if hostile else Palette.UI_TEXT})

## Everything one refresh's events become, for both views: the effects the
## classic view always drew (add_events), then the breathe pass's impacts
## (add_impacts). The views call this and nothing else.
func play(evts: Array, popup_size: int, state: GameState, motion: StepMotion) -> void:
	add_events(evts, popup_size)
	add_impacts(evts, state, motion)

## The breathe pass's impacts: lunges and recoils (handed to `motion`), sparks
## off a magic weapon, a creature shattering, the red edge when you are hurt,
## a ring of light when you level up or pray, and pictures for events that were
## for the ears only -- blink, forging, a trap, the health line.
##
## Nothing here needs the simulation to say more than it already does. Who
## struck is whoever stands where the blow came from; what died is the creature
## lying where the kill was.
func add_impacts(evts: Array, state: GameState, motion: StepMotion) -> void:
	if state == null:
		return
	for e in evts:
		var to: Vector2i = e["to"]
		match e["kind"]:
			&"melee", &"ranged":
				_hit(e, state, motion)
			&"kill":
				_shatter(to, state)
			&"levelup":
				if Effects.any():
					list.append({"type": &"ring", "cell": to, "t": 0.0, "radius": 5,
						"life": 0.70, "colour": Palette.STAIRS, "strength": 1.6})
			&"pray":
				# The shrine answers in its own colour.
				if Effects.any():
					list.append({"type": &"ring", "cell": to, "t": 0.0, "radius": 2,
						"life": 0.50, "colour": state.shrine_hue(int(state.shrine_at.get(to, 0))),
						"strength": 2.0})
			&"forge":
				_burst(to, Palette.EMBERS, 10, 0.0)
			&"trap":
				_burst(to, Palette.TRAP, 6, 0.0)
			&"blink":
				_burst(e["from"], Palette.MAGIC, 10, 0.0)
				_burst(to, Palette.MAGIC, 10, 0.08)
			&"lowhp":
				# A heartbeat at the edge as you cross the health line.
				list.append({"type": &"hurt", "t": 0.0, "strength": 0.45,
					"life": 1.10, "beat": true})

func _hit(e: Dictionary, state: GameState, motion: StepMotion) -> void:
	var from: Vector2i = e["from"]
	var to: Vector2i = e["to"]
	var ranged: bool = e["kind"] == &"ranged"
	# A ranged blow lands when its shot arrives, like the flash and number.
	var delay := 0.0
	if ranged:
		delay = Los.path(from.x, from.y, to.x, to.y).size() * SHOT_PER_CELL
	var attacker := _alive_at(state, from)
	var target := _alive_at(state, to)
	var dir := Vector2(to - from)
	if motion != null and from != to:
		if not ranged and attacker != null:
			motion.nudge(attacker, dir, _lunge_reach(attacker), StepMotion.LUNGE_TIME)
		# The harder the blow, the further it rocks what it hit -- within the
		# tile. A hit that kills leaves nothing standing to rock.
		if target != null:
			var share := float(e["amount"]) / float(maxi(1, target.max_hp))
			motion.nudge(target, dir, clampf(0.06 + share * 0.6, 0.06, 0.25),
				StepMotion.RECOIL_TIME, delay if ranged else StepMotion.LUNGE_TIME * 0.4)
	# Sparks in the magic colour: the one colour every enchanted or gem-set
	# weapon already wears, so the spark says whose blade it was.
	if attacker != null and attacker.is_player and not e["on_player"]:
		var weapon: Item = attacker.equipped.get(Item.Slot.WEAPON)
		if weapon != null and weapon.shows_enchanted():
			_burst(to, Palette.MAGIC, 8, delay)
	if e["on_player"]:
		var hurt := float(e["amount"]) / float(maxi(1, state.player.max_hp))
		list.append({"type": &"hurt", "t": -delay,
			"strength": clampf(0.20 + hurt * 1.5, 0.20, 0.45), "life": HURT_LIFE})

## How far a creature lunges: by its weapon's damage type -- see
## StepMotion.LUNGE.
func _lunge_reach(attacker: Entity) -> float:
	var weapon: Item = attacker.equipped.get(Item.Slot.WEAPON)
	var kind: StringName = weapon.damage_type if weapon != null else &""
	return float(StepMotion.LUNGE.get(kind, StepMotion.LUNGE[&""]))

func _alive_at(state: GameState, cell: Vector2i) -> Entity:
	for x in state.entities:
		if x.alive and x.x == cell.x and x.y == cell.y:
			return x
	return null

## A creature breaking apart where it fell: its picture fades while shards in
## its colour fly out. Motion, so not on "still", where it simply goes -- as it
## always did.
func _shatter(at: Vector2i, state: GameState) -> void:
	if not Effects.any():
		return
	var victim: Entity = null
	for x in state.entities:
		# The last one lying there is the one that just fell.
		if not x.alive and x.x == at.x and x.y == at.y:
			victim = x
	if victim == null:
		return
	var colour: Color = AsciiTheme.TABLE.get(victim.appearance, AsciiTheme.FALLBACK)["fg"]
	if victim.corrupted:
		colour = Palette.CORRUPTED
	elif victim.faction == Entity.Faction.PLAYER:
		colour = Palette.ALLY
	list.append({"type": &"shatter", "cell": at, "t": 0.0, "life": SHATTER_LIFE,
		"appearance": victim.appearance, "colour": colour, "count": 7,
		"seed": at.x * 73 + at.y * 151 + list.size()})

func _burst(at: Vector2i, colour: Color, count: int, delay: float) -> void:
	if not Effects.any():
		return
	list.append({"type": &"sparks", "cell": at, "t": -delay, "life": BURST_LIFE,
		"colour": colour, "count": count, "seed": at.x * 37 + at.y * 211 + list.size()})

## Ground you can see being walked on: a step into water splashes, into mud
## squelches, onto rubble kicks up dust -- for anyone in sight, not just you.
## `moved` is who StepMotion.sync just started gliding. Landing as the step
## does, so the splash is where the foot comes down, not where it lifted.
## Motion, so not on "still".
func footfalls(moved: Array, state: GameState) -> void:
	if not Effects.any():
		return
	for e in moved:
		if not state.map.is_visible(e.x, e.y):
			continue
		var kind: Dictionary = FOOTFALL.get(state.map.get_tile(e.x, e.y), {})
		if kind.is_empty():
			continue
		var at := Vector2i(e.x, e.y)
		var landing := StepMotion.STEP_TIME * StepMotion.footing(state.map, e.x, e.y) * 0.6
		var puff := kind.duplicate()
		puff.merge({"type": &"sparks", "cell": at, "t": -landing,
			"seed": at.x * 53 + at.y * 197 + list.size()}, true)
		list.append(puff)

## ADD EVERY NEW EFFECT TYPE HERE. The fallthrough is "expired", so an effect
## this function has not been taught about is created correctly, culled on the
## very first frame, and never draws once -- with nothing wrong in the effect
## itself and nothing logged. The knockback chevron was invisible for exactly
## this reason and took a screenshot to find.
##
## The fallthrough stays `true` on purpose: the other way round, a typo would
## pin an effect on screen forever.
static func expired(e: Dictionary) -> bool:
	match e["type"]:
		&"ring":  return e["t"] >= float(e.get("life", 0.42))
		&"shot":  return e["t"] >= e["path"].size() * SHOT_PER_CELL
		&"flash": return e["t"] >= FLASH_LIFE
		&"popup": return e["t"] >= POPUP_LIFE
		&"shove": return e["t"] >= float(e.get("life", SHOVE_LIFE))
		&"sparks": return e["t"] >= float(e.get("life", BURST_LIFE))
		&"shatter": return e["t"] >= float(e.get("life", SHATTER_LIFE))
		&"hurt": return e["t"] >= float(e.get("life", HURT_LIFE))
	return true

# ---------------------------------------------------------------- shapes ---
#
# What each effect looks like at a moment, in map cells: the part both views
# agree on. The rule that no effect is ever drawn over ground you cannot see
# lives here too, once -- a visible arrow from an invisible archer would give
# away a position the player has not earned.

## The cells a noise ring covers at time `t`, each as [cell, alpha].
##
## Chebyshev distance, not Euclidean, because that is the metric _make_noise
## itself uses to decide who heard it -- so the ring is not an impression of
## the noise footprint, it is exactly the footprint. A square wavefront looks
## odd for about a second and then reads as correct, because it IS what the
## rule does.
##
## Only cells you can see. A banshee wailing somewhere dark should arrive as an
## arc sweeping in from the edge of your vision, not as a marker over its head.
static func ring_cells(e: Dictionary, t: float, map: DungeonMap) -> Array:
	var out: Array = []
	var progress := clampf(t / float(e.get("life", 0.42)), 0.0, 1.0)
	var reach: int = e["radius"]
	var at: Vector2i = e["cell"]
	var edge := progress * float(reach)
	# Louder carries further AND hits harder, so the two scale together.
	var loud := clampf(float(reach) / 10.0, 0.25, 1.0)
	# Fades as it goes, like the sound it is standing in for.
	var alpha := (1.0 - progress) * 0.5 * loud * float(e.get("strength", 1.0))
	if alpha <= 0.005:
		return out
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var d := float(maxi(absi(dx), absi(dy)))
			# One cell thick, so the wavefront is a line and not a filled disc.
			if absf(d - edge) > 0.5:
				continue
			var c := Vector2i(at.x + dx, at.y + dy)
			if not map.in_bounds(c.x, c.y) or not map.is_visible(c.x, c.y):
				continue
			out.append([c, alpha])
	return out

## The blow that moved you, as a chevron pointing the way you went: the cells
## it covers at time `t`, each as [cell, alpha].
##
## Three blocks, snapped to whole cells, travelling over the first half of its
## life and then holding while it fades: the shove is a shove, not a fade-in.
static func shove_cells(e: Dictionary, t: float, map: DungeonMap) -> Array:
	var out: Array = []
	var life: float = e.get("life", SHOVE_LIFE)
	var k := clampf(t / life, 0.0, 1.0)
	var from: Vector2i = e["from"]
	var to: Vector2i = e["to"]
	var dir: Vector2i = e["dir"]
	if dir == Vector2i.ZERO:
		return out
	var span := maxi(absi(to.x - from.x), absi(to.y - from.y))
	# Clamped to `span` so the point ARRIVES at the player and stops there.
	# Unclamped it ran one cell past, which left the chevron sitting beyond you
	# pointing at empty floor -- the force overtaking the thing it moved.
	var step := int(round(clampf(k / 0.5, 0.0, 1.0) * float(span)))
	var tip := from + dir * mini(step + 1, maxi(span, 1))
	var alpha := 1.0 if k < 0.5 else 1.0 - (k - 0.5) / 0.5
	alpha *= 0.75
	if alpha <= 0.005:
		return out
	# The arrowhead: the point, and two wings one cell back to either side.
	var perp := Vector2i(-dir.y, dir.x)
	for m: Vector2i in [tip, tip - dir + perp, tip - dir - perp]:
		if not map.in_bounds(m.x, m.y) or not map.is_visible(m.x, m.y):
			continue
		out.append([m, alpha])
	return out

## The cell a shot is passing through at time `t`, or (-1, -1) while that cell
## is out of sight.
static func shot_cell(e: Dictionary, t: float, map: DungeonMap) -> Vector2i:
	var line: Array = e["path"]
	var i := clampi(int(t / SHOT_PER_CELL), 0, line.size() - 1)
	var cell: Vector2i = line[i]
	if not map.is_visible(cell.x, cell.y):
		return Vector2i(-1, -1)
	return cell

## Where a shot is at time `t` between cells, for a view that draws it moving
## smoothly rather than cell by cell. Pair it with shot_cell for visibility.
static func shot_point(e: Dictionary, t: float) -> Vector2:
	var line: Array = e["path"]
	var f := clampf(t / SHOT_PER_CELL, 0.0, float(line.size() - 1))
	var i := mini(int(f), line.size() - 1)
	var j := mini(i + 1, line.size() - 1)
	return Vector2(line[i]).lerp(Vector2(line[j]), f - float(i))

## How strongly a hit flash shows at time `t`; 0 once over or out of sight.
static func flash_alpha(e: Dictionary, t: float, map: DungeonMap) -> float:
	var cell: Vector2i = e["cell"]
	if not map.is_visible(cell.x, cell.y):
		return 0.0
	return (1.0 - t / FLASH_LIFE) * 0.5

## A popup at time `t`, as [how far it has risen in cells, alpha]; alpha is 0
## when out of sight. It rises steadily, and holds before it fades. Plain
## floats rather than a Vector2, which would round them to single precision.
static func popup_state(e: Dictionary, t: float, map: DungeonMap) -> Array:
	var at: Vector2i = e["cell"]
	if not map.is_visible(at.x, at.y):
		return [0.0, 0.0]
	var k := t / POPUP_LIFE
	var a := 1.0 if k < 0.55 else 1.0 - (k - 0.55) / 0.45
	return [0.35 + k * 1.1, a]

## The pieces of a burst at time `t` -- sparks off a blade, or the shards of a
## creature -- each as [offset from the cell's centre in cells, height above
## the floor in cells, alpha]. The same pieces in both views: classic lays them
## on its grid, 3D throws them in an arc. Empty over ground you cannot see.
static func burst_points(e: Dictionary, t: float, map: DungeonMap) -> Array:
	var out: Array = []
	var at: Vector2i = e["cell"]
	if t < 0.0 or not map.is_visible(at.x, at.y):
		return out
	var k := clampf(t / float(e.get("life", BURST_LIFE)), 0.0, 1.0)
	# Shards are heavier than sparks: slower out, and they fall sooner. A
	# footfall carries its own numbers -- see FOOTFALL.
	var heavy: bool = e["type"] == &"shatter"
	var seed: int = e.get("seed", 0)
	var base := float(e.get("base", 0.45))
	var out_speed := float(e.get("speed", 0.9 if heavy else 1.6))
	var up := float(e.get("lift", 0.9 if heavy else 1.3))
	var down := float(e.get("fall", 3.0 if heavy else 2.2))
	for i in int(e.get("count", 6)):
		var angle := _noise01(seed, i * 2) * TAU
		var speed := out_speed * (0.55 + _noise01(seed, i * 2 + 1) * 0.6)
		var lift := up * t - down * t * t
		out.append([Vector2(cos(angle), sin(angle)) * speed * t,
			maxf(0.0, base + lift), 1.0 - k])
	return out

## How much of a shattering creature's own picture is still there: gone in the
## first third, so what you see is it breaking, not lingering.
static func shatter_ghost(e: Dictionary, t: float) -> float:
	return clampf(1.0 - (t / float(e.get("life", SHATTER_LIFE))) / 0.35, 0.0, 1.0)

## How red the edge of the map is right now, from every hurt in flight: each
## fades from its strength, and a heartbeat pulses twice as it goes -- unless
## nothing may move, when it simply fades.
static func hurt_now(effects: Array) -> float:
	var most := 0.0
	for e in effects:
		if e["type"] != &"hurt" or e["t"] < 0.0:
			continue
		var k := clampf(float(e["t"]) / float(e.get("life", HURT_LIFE)), 0.0, 1.0)
		var level := float(e["strength"]) * (1.0 - k)
		if e.get("beat", false) and Effects.any():
			level *= absf(sin(PI * k * 2.0))
		most = maxf(most, level)
	return most

## Deterministic 0..1 from two numbers, so a burst looks the same every time
## it is drawn -- and in both views.
static func _noise01(seed: int, i: int) -> float:
	return fposmod(sin(float(seed * 131 + i * 977) * 12.9898) * 43758.5453, 1.0)
