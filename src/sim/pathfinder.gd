class_name Pathfinder
extends RefCounted

## Thin wrapper over Godot's built-in AStarGrid2D.
##
## Worth noting what the engine hands you for free here: gridded A* with
## diagonal handling and solid-point marking, which in a from-scratch stack is
## an afternoon of work and a source of subtle bugs.
##
## TWO GRIDS. The plain one, and a CAREFUL one where the wrong fungus is solid
## as well. The careful grid is for the creatures that know better
## (Entity.careful -- dragons, wizards, liches) and for the player's own
## auto-travel; everything else walks straight through purple and red, and the
## ground hurts it. Brad, 2026-09-29: crossing it is a choice, never a wall.

var _grid: AStarGrid2D
var _careful: AStarGrid2D

func _init(map: DungeonMap) -> void:
	_grid = _make(map)
	_careful = _make(map)
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
			var blocked := not map.is_walkable(x, y) or Tiles.is_avoided(t)
			_grid.set_point_solid(Vector2i(x, y), blocked)
			_careful.set_point_solid(Vector2i(x, y), blocked or Tiles.is_bad_fungus(t))

func set_solid(x: int, y: int, solid: bool) -> void:
	_grid.set_point_solid(Vector2i(x, y), solid)
	_careful.set_point_solid(Vector2i(x, y), solid)

## A cell's ground changed to or from the wrong fungus: only careful routes care.
func set_fungus(x: int, y: int, bad: bool) -> void:
	if not _grid.is_point_solid(Vector2i(x, y)):
		_careful.set_point_solid(Vector2i(x, y), bad)

## Returns the path from `from` to `to`, excluding the starting cell. Careful
## routes go round the wrong fungus.
func path(from: Vector2i, to: Vector2i, careful := false) -> Array[Vector2i]:
	var g := _careful if careful else _grid
	if g.is_in_boundsv(to) and g.is_point_solid(to):
		return []
	var pts := g.get_id_path(from, to)
	if pts.size() <= 1:
		return []
	pts.remove_at(0)
	return pts
