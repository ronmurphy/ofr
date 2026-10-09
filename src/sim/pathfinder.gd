class_name Pathfinder
extends RefCounted

## Thin wrapper over Godot's built-in AStarGrid2D.
##
## Worth noting what the engine hands you for free here: gridded A* with
## diagonal handling and solid-point marking, which in a from-scratch stack is
## an afternoon of work and a source of subtle bugs.
##
## FOUR GRIDS, by two flags. The plain one is what a monster walks: it knows
## its own floor, so only a pit stops a route. CAREFUL adds the wrong fungus
## as solid, for the creatures that know better (Entity.careful -- dragons,
## wizards, liches) and for the player's own auto-travel; everything else
## walks straight through purple and red, and the ground hurts it. Brad,
## 2026-09-29: crossing it is a choice, never a wall. TRAPS adds every FOUND
## trap, for the player's travel and for allies (a trap the player has
## spotted is one their side knows about); monsters step over traps they laid
## (2026-10-02 -- before this a found trap was solid to everyone, and one in a
## doorway shut every guard in its room).

## GATES (2026-10-09): two more grids, plain and trap-wary, in which a shut
## latched gate is solid -- for what cannot work a latch (the animals, your
## tamed wolves among them). Not careful: nothing that squeezes under a door
## is careful today, and a careful squeezer would get the plain gated route.
## Six grids, not eight, because every floor build pays for each one.
var _grids := {}

func _init(map: DungeonMap) -> void:
	for careful in [false, true]:
		for traps in [false, true]:
			_grids[[careful, traps, false]] = _make(map)
	for traps in [false, true]:
		_grids[[false, traps, true]] = _make(map)
	refresh(map)

func _make(map: DungeonMap) -> AStarGrid2D:
	var g := AStarGrid2D.new()
	g.region = Rect2i(0, 0, map.width, map.height)
	g.cell_size = Vector2(1, 1)
	# Never cut a diagonal corner through a wall -- it looks wrong and lets
	# monsters slip through gaps the player cannot use.
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	g.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	g.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	g.update()
	return g

func refresh(map: DungeonMap) -> void:
	for y in map.height:
		for x in map.width:
			# Pits are walkable but never routed through, so auto-travel and
			# monster pursuit both go around rather than dropping in.
			var t := map.get_tile(x, y)
			var blocked := not map.is_walkable(x, y) or t == Tiles.PIT
			for key in _grids:
				_grids[key].set_point_solid(Vector2i(x, y), blocked
					or (key[0] and Tiles.is_bad_fungus(t)) or (key[1] and t == Tiles.TRAP)
					or (key[2] and t == Tiles.GATE_CLOSED))

func set_solid(x: int, y: int, solid: bool) -> void:
	for key in _grids:
		_grids[key].set_point_solid(Vector2i(x, y), solid)

## A cell's ground changed to or from the wrong fungus: only careful routes care.
func set_fungus(x: int, y: int, bad: bool) -> void:
	if _grids[[false, false, false]].is_point_solid(Vector2i(x, y)):
		return
	for key in _grids:
		if key[0]:
			_grids[key].set_point_solid(Vector2i(x, y), bad)

## A gate was latched, or opened or smashed: only the gated routes care.
func set_gate(x: int, y: int, shut: bool) -> void:
	if _grids[[false, false, false]].is_point_solid(Vector2i(x, y)):
		return
	for key in _grids:
		if key[2]:
			_grids[key].set_point_solid(Vector2i(x, y), shut)

## A trap was found, or a found one sprang or was disarmed: only the routes
## that avoid traps care.
func set_trap(x: int, y: int, found: bool) -> void:
	if _grids[[false, false, false]].is_point_solid(Vector2i(x, y)):
		return
	for key in _grids:
		if key[1]:
			_grids[key].set_point_solid(Vector2i(x, y), found)

## Returns the path from `from` to `to`, excluding the starting cell. Careful
## routes go round the wrong fungus; trap-wary ones round every found trap.
func path(from: Vector2i, to: Vector2i, careful := false, traps := false,
		gates := false) -> Array[Vector2i]:
	var g: AStarGrid2D = _grids[[false, traps, true]] if gates else _grids[[careful, traps, false]]
	if g.is_in_boundsv(to) and g.is_point_solid(to):
		return []
	var pts := g.get_id_path(from, to)
	if pts.size() <= 1:
		return []
	pts.remove_at(0)
	return pts
