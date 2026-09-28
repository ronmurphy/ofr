class_name StepMotion
extends RefCounted

## Where creatures are DRAWN while a step settles, which lags where they are.
##
## The simulation resolves a turn instantly and always will; this only changes
## where things are drawn for a tenth of a second afterwards. Nothing under
## src/sim/ knows. ONE of these is shared by both views, so a creature glides
## the same way in classic and in 3D, and switching views mid-stride does not
## make anything jump. (Moved out of GlyphGrid.)

## Short on purpose. The rule that decides whether this feels good is that an
## animation must never delay input -- see settle().
##
## That is an ordinary stride. A step onto heavy ground glides for longer, by
## the same multiple the simulation charges for it (Tiles.move_cost): twice as
## long through mud, 1.4 times through water. Still never a delay -- the next
## key settles it like any other.
const STEP_TIME := 0.10

## Visual positions, keyed by entity.
var _motion: Dictionary = {}
## Moves that go out and come back without leaving the cell: a lunge at what
## you swing at, a recoil from what hits you. Each is {"e", "dir", "amount",
## "t", "life"}; negative t is a delay, as in Fx. Nobody changes tile this way
## -- only a shove does that, and a shove is a real move.
var _nudges: Array = []

## How far a lunge reaches, in cells, by the weapon's damage type: a thrust
## goes furthest, a cut the least. Monsters and bare hands take "". The table
## is the place to tune it -- a third of a cell is the most, so a lunge never
## looks like a step.
const LUNGE := {&"pierce": 0.34, &"blunt": 0.28, &"slash": 0.24, &"": 0.20}
const LUNGE_TIME := 0.16
const RECOIL_TIME := 0.20

func tick(delta: float) -> void:
	for e in _motion:
		var life := _life(_motion[e])
		if float(_motion[e]["t"]) < life:
			_motion[e]["t"] = minf(life, float(_motion[e]["t"]) + delta)
	if not _nudges.is_empty():
		for n in _nudges:
			n["t"] += delta
		_nudges = _nudges.filter(func(n): return n["t"] < n["life"])

## A move out along `dir` by `amount` cells and back, over `life` seconds,
## starting after `delay`. Only while things are allowed to move at all.
func nudge(e: Entity, dir: Vector2, amount: float, life: float, delay := 0.0) -> void:
	if e == null or dir == Vector2.ZERO or not Effects.any():
		return
	_nudges.append({"e": e, "dir": dir.normalized(), "amount": amount,
		"t": -delay, "life": life})

## Everything still in flight completes at once.
##
## This is the rule the whole feature rests on: holding a direction key must
## never be slower than the simulation. Fast play then looks essentially
## instant, and only considered play looks animated.
func settle() -> void:
	for e in _motion:
		_motion[e]["from"] = _motion[e]["to"]
		_motion[e]["t"] = _life(_motion[e])
	_nudges.clear()

## Starts a glide for anything that has moved since we last looked, and returns
## who did -- the views give a step into water, mud or rubble its splash from
## that (Fx.footfalls). With `map`, a step onto heavy ground glides for longer.
func sync(entities: Array, map: DungeonMap = null) -> Array:
	var moved: Array = []
	var seen := {}
	for e in entities:
		if not e.alive:
			continue
		seen[e] = true
		var now := Vector2(e.x, e.y)
		if not _motion.has(e):
			_motion[e] = {"from": now, "to": now, "t": STEP_TIME, "life": STEP_TIME}
			continue
		var m: Dictionary = _motion[e]
		if m["to"] != now:
			m["from"] = visual_cell(e)
			m["to"] = now
			m["t"] = 0.0
			m["life"] = STEP_TIME * footing(map, e.x, e.y)
			moved.append(e)
	for e in _motion.keys():
		if not seen.has(e):
			_motion.erase(e)
	return moved

## How much longer than a stride a step onto (x, y) glides: the simulation's
## own cost for that ground. An ordinary stride while nothing may move.
static func footing(map: DungeonMap, x: int, y: int) -> float:
	if map == null or not Effects.any() or not map.in_bounds(x, y):
		return 1.0
	return Tiles.move_cost(map.get_tile(x, y))

## How long a glide lasts: its own length, or a stride for one made before
## lengths were kept.
static func _life(m: Dictionary) -> float:
	return float(m.get("life", STEP_TIME))

## Where `e` is drawn now, in cells, fractional mid-stride.
func visual_cell(e: Entity) -> Vector2:
	if not _motion.has(e):
		return Vector2(e.x, e.y) + nudge_offset(e)
	var m: Dictionary = _motion[e]
	var k := clampf(float(m["t"]) / _life(m), 0.0, 1.0)
	# Eased out, so a step lands rather than drifting to a halt.
	k = 1.0 - pow(1.0 - k, 2.0)
	return (m["from"] as Vector2).lerp(m["to"], k) + nudge_offset(e)

## Where a lunge or a recoil has `e` right now, relative to its cell. Out and
## back on one half-sine: quick to leave, quick to return, never a drift.
func nudge_offset(e: Entity) -> Vector2:
	var out := Vector2.ZERO
	for n in _nudges:
		if n["e"] != e or n["t"] < 0.0:
			continue
		out += n["dir"] * (float(n["amount"]) * sin(PI * float(n["t"]) / float(n["life"])))
	return out

## Is anything still gliding?
func running() -> bool:
	if not _nudges.is_empty():
		return true
	for e in _motion:
		if float(_motion[e]["t"]) < _life(_motion[e]):
			return true
	return false
