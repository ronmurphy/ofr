class_name MapGen
extends RefCounted

## Level generation, as a pipeline of passes.
##
##   rooms -> caves -> corridors -> cave links -> doors -> decoration -> stone
##
## Order matters. Caves are carved BEFORE corridors so that corridors, cut last,
## punch through whatever the cave automaton left behind -- which is what keeps
## the level connected without any special-case repair logic.

enum Archetype { PLAIN, PILLARED, SHRINE, COLLAPSED, POOL }

const MAX_ROOMS := 22
const ROOM_MIN := 6
const ROOM_MAX := 13
const CAVE_MIN := Vector2i(14, 10)
const CAVE_MAX := Vector2i(22, 15)

var rng: RandomNumberGenerator
var rooms: Array[Rect2i] = []
var archetypes: Array[int] = []
var caves: Array[Rect2i] = []

func _init(random: RandomNumberGenerator) -> void:
	rng = random

func generate(map: DungeonMap) -> void:
	rooms.clear()
	archetypes.clear()
	caves.clear()
	map.tiles.fill(Tiles.WALL)

	# Caves are reserved BEFORE rooms rather than squeezed in afterwards.
	# Placing rooms first fills the map so thoroughly that a cave-sized gap
	# almost never survives -- the first version of this produced one cave in
	# a hundred and twenty levels.
	_reserve_caves(map)
	_place_rooms(map)
	_carve_caves(map)
	_connect_rooms(map)
	_connect_caves(map)
	_place_doors(map)
	_decorate(map)
	_naturalise_cave_walls(map)
	_paint_materials(map)

# ------------------------------------------------------------------ rooms ---

func _place_rooms(map: DungeonMap) -> void:
	for _attempt in MAX_ROOMS * 4:
		if rooms.size() >= MAX_ROOMS:
			break
		var w := rng.randi_range(ROOM_MIN, ROOM_MAX)
		var h := rng.randi_range(ROOM_MIN, ROOM_MAX)
		var x := rng.randi_range(1, maxi(1, map.width - w - 2))
		var y := rng.randi_range(1, maxi(1, map.height - h - 2))
		var room := Rect2i(x, y, w, h)
		if _overlaps(room):
			continue
		var blocked := false
		for reserved in caves:
			if room.grow(1).intersects(reserved.grow(2)):
				blocked = true
				break
		if blocked:
			continue
		for ry in range(room.position.y, room.end.y):
			for rx in range(room.position.x, room.end.x):
				map.set_tile(rx, ry, Tiles.FLOOR)
		rooms.append(room)
		archetypes.append(_roll_archetype(room))

func _overlaps(room: Rect2i) -> bool:
	var padded := room.grow(1)
	for other in rooms:
		if padded.intersects(other.grow(1)):
			return true
	return false

func _roll_archetype(room: Rect2i) -> int:
	# Small rooms stay plain: a colonnade in a 6x6 box is just an obstacle.
	if room.size.x < 8 or room.size.y < 8:
		return Archetype.PLAIN if rng.randf() < 0.75 else Archetype.COLLAPSED
	var r := rng.randf()
	if r < 0.34: return Archetype.PLAIN
	if r < 0.55: return Archetype.PILLARED
	if r < 0.72: return Archetype.COLLAPSED
	if r < 0.88: return Archetype.POOL
	return Archetype.SHRINE

func _connect_rooms(map: DungeonMap) -> void:
	for i in range(1, rooms.size()):
		_carve_corridor(map, rooms[i - 1].get_center(), rooms[i].get_center())

func _carve_corridor(map: DungeonMap, a: Vector2i, b: Vector2i) -> void:
	if rng.randf() < 0.5:
		_carve_h(map, a.x, b.x, a.y)
		_carve_v(map, a.y, b.y, b.x)
	else:
		_carve_v(map, a.y, b.y, a.x)
		_carve_h(map, a.x, b.x, b.y)

func _carve_h(map: DungeonMap, x1: int, x2: int, y: int) -> void:
	for x in range(mini(x1, x2), maxi(x1, x2) + 1):
		if not Tiles.is_open_floor(map.get_tile(x, y)):
			map.set_tile(x, y, Tiles.FLOOR)

func _carve_v(map: DungeonMap, y1: int, y2: int, x: int) -> void:
	for y in range(mini(y1, y2), maxi(y1, y2) + 1):
		if not Tiles.is_open_floor(map.get_tile(x, y)):
			map.set_tile(x, y, Tiles.FLOOR)

# ------------------------------------------------------------------ caves ---

## Claim one or two rectangles for caverns up front. Rooms then route around
## them, which is what makes caves actually appear.
func _reserve_caves(map: DungeonMap) -> void:
	var wanted := 1 if rng.randf() < 0.62 else 2
	for _i in wanted:
		for _try in 40:
			var w := rng.randi_range(CAVE_MIN.x, CAVE_MAX.x)
			var h := rng.randi_range(CAVE_MIN.y, CAVE_MAX.y)
			var x := rng.randi_range(1, maxi(1, map.width - w - 2))
			var y := rng.randi_range(1, maxi(1, map.height - h - 2))
			var region := Rect2i(x, y, w, h)
			var clear := true
			for other in caves:
				if region.grow(2).intersects(other):
					clear = false
					break
			if clear:
				caves.append(region)
				break

func _carve_caves(map: DungeonMap) -> void:
	var gen := CaveGen.new(rng)
	var kept: Array[Rect2i] = []
	for region in caves:
		var cells := gen.generate(region.size.x, region.size.y)
		var painted := 0
		for y in region.size.y:
			for x in region.size.x:
				if cells[y * region.size.x + x] == 1:
					map.set_tile(region.position.x + x, region.position.y + y, Tiles.CAVE_FLOOR)
					painted += 1
		# A cellular automaton can collapse to almost nothing; drop the region
		# rather than leaving a link to three cells of floor.
		if painted >= 24:
			_scatter_cave_cover(map, region)
			kept.append(region)
	caves = kept

## Stalagmites, placed only where all eight neighbours are open floor.
##
## That restriction is what makes this safe: a lone obstacle in the middle of
## open ground always leaves eight ways around it, so scattering cover can
## never sever a cavern. It also means they land in the open middle of a cave
## rather than plugging its narrow throats.
func _scatter_cave_cover(map: DungeonMap, region: Rect2i) -> void:
	for y in range(region.position.y + 1, region.end.y - 1):
		for x in range(region.position.x + 1, region.end.x - 1):
			if map.get_tile(x, y) != Tiles.CAVE_FLOOR:
				continue
			if rng.randf() >= 0.055:
				continue
			var open := true
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					if not map.is_walkable(x + dx, y + dy):
						open = false
						break
				if not open:
					break
			if open:
				map.set_tile(x, y, Tiles.STALAGMITE)

## Tie each cave back to the nearest room, so it is somewhere you can reach
## rather than a pocket of unreachable scenery.
func _connect_caves(map: DungeonMap) -> void:
	for region in caves:
		var mouth := _nearest_cave_cell(map, region)
		if mouth.x < 0 or rooms.is_empty():
			continue
		var best := rooms[0].get_center()
		var best_d := 1 << 30
		for room in rooms:
			var c := room.get_center()
			var d := absi(c.x - mouth.x) + absi(c.y - mouth.y)
			if d < best_d:
				best_d = d
				best = c
		_carve_corridor(map, best, mouth)

func _nearest_cave_cell(map: DungeonMap, region: Rect2i) -> Vector2i:
	var centre := region.get_center()
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if map.get_tile(x, y) != Tiles.CAVE_FLOOR:
				continue
			var d := absi(x - centre.x) + absi(y - centre.y)
			if d < best_d:
				best_d = d
				best = Vector2i(x, y)
	return best

## Masonry that touches a cavern becomes natural stone, so the renderer can
## draw the two differently and a cave never looks like a bricked-up room.
func _naturalise_cave_walls(map: DungeonMap) -> void:
	var changes: Array[Vector2i] = []
	for y in map.height:
		for x in map.width:
			if map.get_tile(x, y) != Tiles.WALL:
				continue
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					if map.get_tile(x + dx, y + dy) == Tiles.CAVE_FLOOR:
						changes.append(Vector2i(x, y))
						break
	for c in changes:
		map.set_tile(c.x, c.y, Tiles.ROCK)

# ------------------------------------------------------------------ doors ---

func _place_doors(map: DungeonMap) -> void:
	for room in rooms:
		var edge := room.grow(1)
		for y in range(edge.position.y, edge.end.y):
			for x in range(edge.position.x, edge.end.x):
				if map.get_tile(x, y) != Tiles.FLOOR or room.has_point(Vector2i(x, y)):
					continue
				var horiz := not map.is_walkable(x, y - 1) and not map.is_walkable(x, y + 1)
				var vert := not map.is_walkable(x - 1, y) and not map.is_walkable(x + 1, y)
				if (horiz or vert) and rng.randf() < 0.55:
					map.set_tile(x, y, Tiles.DOOR_CLOSED)

## Materials ride on the archetypes the generator already assigns, so this adds
## no new generation logic -- it just stops the renderer throwing that
## information away.
func _paint_materials(map: DungeonMap) -> void:
	for region in caves:
		map.paint_material(region, Materials.CAVERN)
	for i in rooms.size():
		var m := Materials.STONE
		match archetypes[i]:
			Archetype.POOL:      m = Materials.FLOODED
			Archetype.COLLAPSED: m = Materials.RUIN
			Archetype.SHRINE:    m = Materials.SANCTUM
		map.paint_material(rooms[i], m)

# ------------------------------------------------------------- decoration ---

func _decorate(map: DungeonMap) -> void:
	for i in rooms.size():
		match archetypes[i]:
			Archetype.PILLARED:  _decorate_pillared(map, rooms[i])
			Archetype.SHRINE:    _decorate_shrine(map, rooms[i])
			Archetype.COLLAPSED: _decorate_collapsed(map, rooms[i])
			Archetype.POOL:      _decorate_pool(map, rooms[i])
			_:                   _decorate_plain(map, rooms[i])

## Pillars are laid on an even lattice inset from the walls. That spacing
## guarantees a free cell between any two of them, so a colonnade can never
## seal a room off no matter how the corridors entered it.
func _decorate_pillared(map: DungeonMap, room: Rect2i) -> void:
	var inner := room.grow(-2)
	for y in range(inner.position.y, inner.end.y):
		for x in range(inner.position.x, inner.end.x):
			if (x - inner.position.x) % 2 != 0 or (y - inner.position.y) % 2 != 0:
				continue
			_try_place(map, x, y, Tiles.PILLAR)
	if rng.randf() < 0.5:
		var c := room.get_center()
		_try_place(map, c.x, c.y, Tiles.BRAZIER)

func _decorate_shrine(map: DungeonMap, room: Rect2i) -> void:
	var inner := room.grow(-2)
	for corner in [inner.position, Vector2i(inner.end.x - 1, inner.position.y),
			Vector2i(inner.position.x, inner.end.y - 1), inner.end - Vector2i.ONE]:
		_try_place(map, corner.x, corner.y, Tiles.PILLAR)
	var c := room.get_center()
	_try_place(map, c.x, c.y, Tiles.BRAZIER)
	for d in [Vector2i(2, 0), Vector2i(-2, 0)]:
		if rng.randf() < 0.6:
			_try_place(map, c.x + d.x, c.y + d.y, Tiles.BRAZIER)

func _decorate_collapsed(map: DungeonMap, room: Rect2i) -> void:
	var inner := room.grow(-1)
	for y in range(inner.position.y, inner.end.y):
		for x in range(inner.position.x, inner.end.x):
			var r := rng.randf()
			if r < 0.16:
				_try_place(map, x, y, Tiles.RUBBLE)
			elif r < 0.19:
				_try_place(map, x, y, Tiles.PILLAR)

func _decorate_pool(map: DungeonMap, room: Rect2i) -> void:
	var c := room.get_center()
	var rx := maxf(1.5, room.size.x * 0.26)
	var ry := maxf(1.5, room.size.y * 0.26)
	for y in range(room.position.y + 1, room.end.y - 1):
		for x in range(room.position.x + 1, room.end.x - 1):
			var dx := (x - c.x) / rx
			var dy := (y - c.y) / ry
			if dx * dx + dy * dy <= 1.0 + rng.randf() * 0.35:
				_try_place(map, x, y, Tiles.WATER)
	if rng.randf() < 0.4:
		_try_place(map, room.position.x + 1, room.position.y + 1, Tiles.BRAZIER)

func _decorate_plain(map: DungeonMap, room: Rect2i) -> void:
	if rng.randf() < 0.35:
		var bx := rng.randi_range(room.position.x + 1, room.end.x - 2)
		var by := rng.randi_range(room.position.y + 1, room.end.y - 2)
		_try_place(map, bx, by, Tiles.BRAZIER)

## Decoration only ever paints over plain floor, so it can never bury the
## stairs, plug a doorway, or overwrite a corridor.
func _try_place(map: DungeonMap, x: int, y: int, tile: int) -> void:
	if map.get_tile(x, y) != Tiles.FLOOR:
		return
	map.set_tile(x, y, tile)
