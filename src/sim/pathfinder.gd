class_name Pathfinder
extends RefCounted

## Thin wrapper over Godot's built-in AStarGrid2D.
##
## Worth noting what the engine hands you for free here: gridded A* with
## diagonal handling and solid-point marking, which in a from-scratch stack is
## an afternoon of work and a source of subtle bugs.

var _grid: AStarGrid2D

func _init(map: DungeonMap) -> void:
	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(0, 0, map.width, map.height)
	_grid.cell_size = Vector2(1, 1)
	# Never cut a diagonal corner through a wall -- it looks wrong and lets
	# monsters slip through gaps the player cannot use.
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.update()
	refresh(map)

func refresh(map: DungeonMap) -> void:
	for y in map.height:
		for x in map.width:
			# Pits are walkable but never routed through, so auto-travel and
			# monster pursuit both go around rather than dropping in.
			var blocked := not map.is_walkable(x, y) or Tiles.is_avoided(map.get_tile(x, y))
			_grid.set_point_solid(Vector2i(x, y), blocked)

func set_solid(x: int, y: int, solid: bool) -> void:
	_grid.set_point_solid(Vector2i(x, y), solid)

## Returns the path from `from` to `to`, excluding the starting cell.
func path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if _grid.is_in_boundsv(to) and _grid.is_point_solid(to):
		return []
	var pts := _grid.get_id_path(from, to)
	if pts.size() <= 1:
		return []
	pts.remove_at(0)
	return pts
