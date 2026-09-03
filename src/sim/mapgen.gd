class_name MapGen
extends RefCounted

## Classic room-and-corridor generation.
##
## Kept intentionally boring: it is well understood, it always produces a
## connected level, and it is easy to debug. Cave and cavern generators are a
## later flourish, and they slot in behind the same interface.

const MAX_ROOMS := 22
const ROOM_MIN := 6
const ROOM_MAX := 13

var rng: RandomNumberGenerator
var rooms: Array[Rect2i] = []

func _init(random: RandomNumberGenerator) -> void:
	rng = random

func generate(map: DungeonMap) -> void:
	rooms.clear()
	map.tiles.fill(Tiles.WALL)

	for _attempt in MAX_ROOMS * 4:
		if rooms.size() >= MAX_ROOMS:
			break
		var w := rng.randi_range(ROOM_MIN, ROOM_MAX)
		var h := rng.randi_range(ROOM_MIN, ROOM_MAX)
		var x := rng.randi_range(1, maxi(1, map.width - w - 2))
		var y := rng.randi_range(1, maxi(1, map.height - h - 2))
		var room := Rect2i(x, y, w, h)

		# One cell of padding, so rooms never share a wall.
		if _overlaps(room):
			continue

		_carve_room(map, room)
		if not rooms.is_empty():
			var prev := rooms[-1].get_center()
			var cur := room.get_center()
			_carve_corridor(map, prev, cur)
		rooms.append(room)

	_place_doors(map)

func _overlaps(room: Rect2i) -> bool:
	var padded := room.grow(1)
	for other in rooms:
		if padded.intersects(other.grow(1)):
			return true
	return false

func _carve_room(map: DungeonMap, room: Rect2i) -> void:
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			map.set_tile(x, y, Tiles.FLOOR)

func _carve_corridor(map: DungeonMap, a: Vector2i, b: Vector2i) -> void:
	# L-shaped, with the elbow direction chosen at random for variety.
	if rng.randf() < 0.5:
		_carve_h(map, a.x, b.x, a.y)
		_carve_v(map, a.y, b.y, b.x)
	else:
		_carve_v(map, a.y, b.y, a.x)
		_carve_h(map, a.x, b.x, b.y)

func _carve_h(map: DungeonMap, x1: int, x2: int, y: int) -> void:
	for x in range(mini(x1, x2), maxi(x1, x2) + 1):
		map.set_tile(x, y, Tiles.FLOOR)

func _carve_v(map: DungeonMap, y1: int, y2: int, x: int) -> void:
	for y in range(mini(y1, y2), maxi(y1, y2) + 1):
		map.set_tile(x, y, Tiles.FLOOR)

## A corridor cell flanked by walls on opposite sides, sitting on a room edge,
## is a doorway. Doors block light until opened, which makes them tactically
## interesting rather than decorative.
func _place_doors(map: DungeonMap) -> void:
	for room in rooms:
		var edge := room.grow(1)
		for y in range(edge.position.y, edge.end.y):
			for x in range(edge.position.x, edge.end.x):
				if not map.in_bounds(x, y) or map.get_tile(x, y) != Tiles.FLOOR:
					continue
				if room.has_point(Vector2i(x, y)):
					continue
				var horiz := not map.is_walkable(x, y - 1) and not map.is_walkable(x, y + 1)
				var vert := not map.is_walkable(x - 1, y) and not map.is_walkable(x + 1, y)
				if (horiz or vert) and rng.randf() < 0.55:
					map.set_tile(x, y, Tiles.DOOR_CLOSED)
