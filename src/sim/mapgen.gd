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

## Ground is rolled separately from archetype, so the same room shape plays
## differently between levels. Two orthogonal axes multiply the variety instead
## of adding to it: a pillared hall can be dry on one floor and knee-deep in
## mud on the next.
enum Ground { DRY, DAMP, FLOODED, MUDDY, RUBBLED, BONEYARD }

const MAX_ROOMS := 22
const ROOM_MIN := 6
const ROOM_MAX := 13
const CAVE_MIN := Vector2i(14, 10)
const CAVE_MAX := Vector2i(22, 15)

var rng: RandomNumberGenerator
## Cleared on the bottom floor and on the way out: there is nothing below the
## deepest level, and falling while climbing would undo the run.
var allow_pits := true
## Set by GameState; vaults are gated by depth like everything else.
var depth := 1
var library: Array[Vault] = []

## Placed vaults, and what they asked to have put in them.
var vault_spots: Array = []
var vault_contents: Array = []
## Cells a vault owns. Corridors, decoration and scattered features all route
## around these -- a hand-authored room must survive every later pass intact.
var protected: Dictionary = {}
var rooms: Array[Rect2i] = []
var archetypes: Array[int] = []
var caves: Array[Rect2i] = []

func _init(random: RandomNumberGenerator) -> void:
	rng = random

func generate(map: DungeonMap) -> void:
	rooms.clear()
	archetypes.clear()
	caves.clear()
	vault_spots.clear()
	vault_contents.clear()
	protected.clear()
	map.tiles.fill(Tiles.WALL)

	# Caves are reserved BEFORE rooms rather than squeezed in afterwards.
	# Placing rooms first fills the map so thoroughly that a cave-sized gap
	# almost never survives -- the first version of this produced one cave in
	# a hundred and twenty levels.
	# Vaults claim their space first. They are the least flexible thing on the
	# level -- a fixed rectangle that cannot be nudged or reshaped -- so
	# everything else gets to fit around them rather than the other way round.
	_reserve_vaults(map)
	_reserve_caves(map)
	_place_rooms(map)
	_carve_caves(map)
	_connect_rooms(map)
	_connect_caves(map)
	_stamp_vaults(map)
	_connect_vaults(map)
	_place_doors(map)
	_ensure_sanctums()
	_decorate(map)
	_lay_terrain(map)
	_scatter_features(map)
	# Sealing runs BEFORE the connectivity net, not after.
	#
	# It was the other way round, and _seal_blind_doors is the only pass after
	# decoration that changes what is walkable -- so a vault whose one live
	# door got sealed became an island that nothing checked again. That is how
	# five shrines in two hundred and fifty ended up standing in rooms with no
	# way in: the whole vault was unreachable, not just the shrine.
	#
	# The rule this encodes: _ensure_connected must be the LAST pass that can
	# affect walkability. _naturalise_cave_walls after it is fine because it
	# only turns WALL into ROCK, and both are solid.
	_seal_blind_doors(map)
	_ensure_connected(map)
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
		# Vaults reserve their space before any room exists, so the check in
		# _free_box sees an empty room list. The avoidance has to be here too,
		# or a room lands on top of an authored one.
		for spot in vault_spots:
			if room.grow(1).intersects(spot["rect"].grow(2)):
				blocked = true
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

## `force` carves through authored vault ground as well.
##
## Normally corridors refuse to touch a vault, which is the whole point of
## `protected` -- an authored room should arrive on the map as it was drawn.
## But that refusal is silent, and it is silent in exactly the case where it
## matters: when the region being connected TO is the vault. The corridor then
## stops at the vault's edge and the vault stays an island. Five shrines in
## two hundred and fifty stood in rooms with no way in for this reason.
##
## So the last-resort pass is allowed to break the rule. A vault with one
## unplanned doorway is a far better outcome than a vault nobody can enter.
func _carve_corridor(map: DungeonMap, a: Vector2i, b: Vector2i,
		force: bool = false) -> void:
	if rng.randf() < 0.5:
		_carve_h(map, a.x, b.x, a.y, force)
		_carve_v(map, a.y, b.y, b.x, force)
	else:
		_carve_v(map, a.y, b.y, a.x, force)
		_carve_h(map, a.x, b.x, b.y, force)

func _carve_h(map: DungeonMap, x1: int, x2: int, y: int, force: bool = false) -> void:
	for x in range(mini(x1, x2), maxi(x1, x2) + 1):
		if not force and protected.has(Vector2i(x, y)):
			continue
		if not Tiles.is_open_floor(map.get_tile(x, y)):
			map.set_tile(x, y, Tiles.FLOOR)

func _carve_v(map: DungeonMap, y1: int, y2: int, x: int, force: bool = false) -> void:
	for y in range(mini(y1, y2), maxi(y1, y2) + 1):
		if not force and protected.has(Vector2i(x, y)):
			continue
		if not Tiles.is_open_floor(map.get_tile(x, y)):
			map.set_tile(x, y, Tiles.FLOOR)

# ----------------------------------------------------------------- vaults ---

func _reserve_vaults(map: DungeonMap) -> void:
	if library.is_empty():
		return
	var here := Bands.of(depth)
	var eligible: Array[Vault] = []
	var total := 0
	for v in library:
		if v.min_depth <= depth and v.max_depth >= depth and v.weight > 0 \
				and v.suits(here):
			eligible.append(v)
			total += v.weight
	if eligible.is_empty():
		return

	# Roughly three floors in ten have none. A vault that turns up every single
	# level is furniture; one that does not is a find.
	#
	# The fortress band is the exception: built, complex ground is its whole
	# character, and authored rooms are what "built" means here. Caves get none
	# at all -- a hand-drawn masonry room in a cavern reads as a mistake.
	var roll := rng.randf()
	var wanted := 0 if roll < 0.30 else (1 if roll < 0.84 else 2)
	if here == Bands.FORTRESS:
		wanted = rng.randi_range(3, 4)
	elif here == Bands.CAVES:
		wanted = 0 if rng.randf() < 0.75 else 1
	for _i in wanted:
		var pick := _weighted_vault(eligible, total)
		if pick == null:
			continue
		var quarters := rng.randi_range(0, 3) if pick.may_rotate else 0
		var mirror := pick.may_rotate and rng.randf() < 0.5
		var grid := pick.oriented(quarters, mirror)
		var w := 0
		for r in grid:
			w = maxi(w, String(r).length())
		var box := Vector2i(w, grid.size())
		var at := _free_box(map, box)
		if at.x < 0:
			continue
		vault_spots.append({
			"vault": pick, "grid": grid,
			"rect": Rect2i(at, box),
		})

func _weighted_vault(pool: Array[Vault], total: int) -> Vault:
	var pick := rng.randi_range(1, maxi(1, total))
	for v in pool:
		pick -= v.weight
		if pick <= 0:
			return v
	return pool[-1]

## Somewhere the box fits with a cell of clearance, clear of anything already
## claimed.
func _free_box(map: DungeonMap, box: Vector2i) -> Vector2i:
	for _try in 80:
		var x := rng.randi_range(2, maxi(2, map.width - box.x - 3))
		var y := rng.randi_range(2, maxi(2, map.height - box.y - 3))
		var here := Rect2i(x, y, box.x, box.y)
		var clear := true
		for other in vault_spots:
			if here.grow(2).intersects(other["rect"]):
				clear = false
		for cave in caves:
			if here.grow(2).intersects(cave):
				clear = false
		for room in rooms:
			if here.grow(2).intersects(room):
				clear = false
		if clear:
			return Vector2i(x, y)
	return Vector2i(-1, -1)

func _stamp_vaults(map: DungeonMap) -> void:
	for spot in vault_spots:
		var grid: Array = spot["grid"]
		var at: Vector2i = spot["rect"].position
		for y in grid.size():
			var row := String(grid[y])
			for x in row.length():
				var ch := row[x]
				if ch == " ":
					continue
				var cell := at + Vector2i(x, y)
				if not map.in_bounds(cell.x, cell.y):
					continue
				if Vault.TERRAIN.has(ch):
					map.set_tile(cell.x, cell.y, Vault.TERRAIN[ch])
				elif Vault.CONTENTS.has(ch):
					map.set_tile(cell.x, cell.y, Tiles.FLOOR)
					vault_contents.append({"ch": ch, "pos": cell})
				else:
					continue
				if spot["vault"].fixed_terrain:
					protected[cell] = true

## Joins each vault to the nearest room through one of its own doors, rather
## than letting a corridor punch a hole wherever it likes.
func _connect_vaults(map: DungeonMap) -> void:
	for spot in vault_spots:
		var mouths := _vault_mouths(spot)
		if mouths.is_empty() or rooms.is_empty():
			continue
		# Every door against every room, and take the shortest pairing.
		#
		# This used to pick a door at random and then find the room nearest to
		# it, which is the same question asked backwards: a random door can
		# easily be the one facing away from everything, and the corridor then
		# has to travel round the vault to reach it. Choosing the pair makes
		# the run short, and a short run is one that cannot wander across the
		# vault it is trying to reach.
		var best_room := rooms[0].get_center()
		var best_mouth: Dictionary = mouths[0]
		var best_d := 1 << 30
		for mouth: Dictionary in mouths:
			var m: Vector2i = mouth["out"]
			for room in rooms:
				var c := room.get_center()
				var d := absi(c.x - m.x) + absi(c.y - m.y)
				if d < best_d:
					best_d = d
					best_room = c
					best_mouth = mouth

		# Tried and rejected: walking the corridor a few cells straight out of
		# the door before turning, on the theory that it would stop a leg
		# running along the vault wall. It measured slightly WORSE -- 8.1%
		# against 7.6% -- because the extra length simply meets other geometry.
		# The short, direct L is the better shape.
		_carve_around(map, best_room, best_mouth["out"], spot["rect"])

## Carves an L to `b`, choosing the corner that keeps the path out of `avoid`.
##
## Both orderings reach the target. Only one of them may cross the vault on the
## way -- and `_carve_h`/`_carve_v` SILENTLY SKIP protected ground, so the wrong
## ordering leaves a corridor with a hole punched out of its middle and the
## vault still unconnected. The connectivity net then rescued it by forcing a
## passage through the vault wall somewhere else entirely, which is why nearly
## one vault in five arrived with a corridor entering through its side rather
## than through the door it was aimed at.
##
## Measured before this change: 18.5% of placed vaults had a punched wall.
func _carve_around(map: DungeonMap, a: Vector2i, b: Vector2i, avoid: Rect2i) -> void:
	var corner_h := Vector2i(b.x, a.y)
	var corner_v := Vector2i(a.x, b.y)
	var cost_h := _leg_crosses(a, corner_h, avoid) + _leg_crosses(corner_h, b, avoid)
	var cost_v := _leg_crosses(a, corner_v, avoid) + _leg_crosses(corner_v, b, avoid)
	if cost_h <= cost_v:
		_carve_h(map, a.x, b.x, a.y)
		_carve_v(map, a.y, b.y, b.x)
	else:
		_carve_v(map, a.y, b.y, a.x)
		_carve_h(map, a.x, b.x, b.y)

## How many cells of a straight leg fall inside `avoid`.
func _leg_crosses(a: Vector2i, b: Vector2i, avoid: Rect2i) -> int:
	var n := 0
	if a.y == b.y:
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			if avoid.has_point(Vector2i(x, a.y)):
				n += 1
	else:
		for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
			if avoid.has_point(Vector2i(a.x, y)):
				n += 1
	return n

## Every cell just outside one of the vault's doors.
func _vault_mouths(spot: Dictionary) -> Array:
	var grid: Array = spot["grid"]
	var at: Vector2i = spot["rect"].position
	var options := []
	for y in grid.size():
		var row := String(grid[y])
		for x in row.length():
			if row[x] != "+" and row[x] != "'":
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + d
				var outside := n.y < 0 or n.y >= grid.size()
				if not outside:
					var nrow := String(grid[n.y])
					outside = n.x < 0 or n.x >= nrow.length() or nrow[n.x] == " "
				if outside:
					# The door and the way out of it, so a corridor can be made
					# to leave the vault before it turns anywhere.
					options.append({"door": at + Vector2i(x, y), "out": at + n})
	return options

## A door that opens onto solid rock is a small lie, and forcing a corridor to
## every door on a four-door vault would turn it into a crossroads. So the
## third option: if it does not lead anywhere, it is not a door.
##
## A door is live when it has walkable ground on two or more sides -- which
## covers both an interior door joining two halves of a vault and an exterior
## one a corridor actually reached. The last live door is never sealed, so this
## can never cut a vault off.
func _seal_blind_doors(map: DungeonMap) -> void:
	for spot in vault_spots:
		var doors := []
		var live := 0
		var grid: Array = spot["grid"]
		var at: Vector2i = spot["rect"].position
		for y in grid.size():
			var row := String(grid[y])
			for x in row.length():
				if row[x] != "+" and row[x] != "'":
					continue
				var cell := at + Vector2i(x, y)
				var touching := 0
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if map.is_walkable(cell.x + d.x, cell.y + d.y):
						touching += 1
				doors.append({"cell": cell, "live": touching >= 2})
				if touching >= 2:
					live += 1
		if live == 0:
			continue
		for door in doors:
			if not door["live"]:
				var c: Vector2i = door["cell"]
				map.set_tile(c.x, c.y, Tiles.WALL)

# ----------------------------------------------------------- connectivity ---

## Guarantees the level is one connected space, whatever every pass before it
## did. A safety net rather than a plan: vaults and caves both claim ground
## that corridors were counting on, and the alternative is discovering it in a
## seed nobody ever plays.
func _ensure_connected(map: DungeonMap) -> void:
	# Tracked so a carve that changed nothing can be retried without the
	# protection rule. Without this the loop cheerfully carves the same
	# ineffective corridor eight times and gives up.
	var last_count := -1
	for _attempt in 8:
		var regions := _walkable_regions(map)
		if regions.size() <= 1:
			return
		var stalled := regions.size() == last_count
		last_count = regions.size()
		var main: Array = regions[0]
		var other: Array = regions[1]
		var from: Vector2i = main[0]
		var to: Vector2i = other[0]
		var best := 1 << 30
		# Sampled rather than exhaustive: regions can be thousands of cells and
		# the nearest pair does not have to be exact, only close.
		for a: Vector2i in _sample(main, 120):
			for b: Vector2i in _sample(other, 120):
				var d: int = absi(a.x - b.x) + absi(a.y - b.y)
				if d < best:
					best = d
					from = a
					to = b
		_carve_corridor(map, from, to, stalled)

func _routable(map: DungeonMap, x: int, y: int) -> bool:
	return map.is_walkable(x, y) and not Tiles.is_avoided(map.get_tile(x, y))

func _sample(cells: Array, limit: int) -> Array:
	if cells.size() <= limit:
		return cells
	var out := []
	var step := float(cells.size()) / float(limit)
	for i in limit:
		out.append(cells[int(i * step)])
	return out

## Walkable regions, largest first.
##
## Uses the same rule the pathfinder does -- walkable AND not avoided -- because
## a region reachable only across a pit is not reachable at all as far as
## travel or a monster is concerned.
func _walkable_regions(map: DungeonMap) -> Array:
	var seen := {}
	var regions := []
	for y in map.height:
		for x in map.width:
			var start := Vector2i(x, y)
			if seen.has(start) or not _routable(map, x, y):
				continue
			var region := []
			var stack := [start]
			seen[start] = true
			while not stack.is_empty():
				var cur: Vector2i = stack.pop_back()
				region.append(cur)
				# Orthogonal only, and that is the whole point.
				#
				# This used to spread diagonally as well, which quietly made
				# this function disagree with the pathfinder. The pathfinder
				# runs DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES: it will not cut the
				# corner between two solid cells. So a room joined to the rest
				# of the level by nothing but a diagonal squeeze counted as
				# connected here, _ensure_connected saw one region and did
				# nothing, and the player could not walk through it.
				#
				# Four-way is exactly right rather than merely conservative:
				# any diagonal step the pathfinder allows needs both adjacent
				# orthogonals open, and that is an orthogonal route already.
				#
				# Same mistake as the last bug in this function, one level
				# down. That one had the wrong rule for which TILES count;
				# this one had the wrong rule for which MOVES do.
				for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1),
						Vector2i(-1, 0), Vector2i(1, 0)]:
					var n := cur + d
					if seen.has(n) or not _routable(map, n.x, n.y):
						continue
					seen[n] = true
					stack.append(n)
			regions.append(region)
	regions.sort_custom(func(a, b): return a.size() > b.size())
	return regions

# ------------------------------------------------------------------ caves ---

## Claim one or two rectangles for caverns up front. Rooms then route around
## them, which is what makes caves actually appear.
func _reserve_caves(map: DungeonMap) -> void:
	# The cave band is mostly cavern; everywhere else a cave is a feature the
	# floor happens to have. Note what this costs elsewhere: braziers are placed
	# per ROOM, so trading rooms for caverns trades away healing and light at
	# the same time. That is the whole reason the band wants its own answer to
	# the dark -- see the fungus bias below.
	var wanted := 1 if rng.randf() < 0.62 else 2
	if Bands.is_caves(depth):
		wanted = rng.randi_range(6, 7)
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
			for spot in vault_spots:
				if region.grow(2).intersects(spot["rect"]):
					clear = false
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

## Guarantees one or two sanctums per level.
##
## A sanctum always holds a shrine, so the gold room reads as a promise that
## one is there -- while which shrine it is stays hidden behind its colour.
func _ensure_sanctums(): 
	var want := 1 if rng.randf() < 0.55 else 2
	var have := 0
	for a in archetypes:
		if a == Archetype.SHRINE:
			have += 1
	# Never the first room, which is where the player starts.
	var candidates := []
	for i in range(1, rooms.size()):
		# 6x6 rather than 7x7: vaults now compete for the large rooms, and a
		# slightly cramped sanctum beats a floor with no shrine on it.
		if archetypes[i] != Archetype.SHRINE and rooms[i].size.x >= 6 and rooms[i].size.y >= 6:
			candidates.append(i)
	# NOT candidates.shuffle(): Array.shuffle() draws on Godot's GLOBAL rng, so
	# it made level generation unreproducible from a seed. The same seed built
	# different dungeons on different runs, which made seeded tests flaky and
	# quietly undermined the promise that a resumed save continues the run it
	# left.
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: int = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = swap
	while have < want and not candidates.is_empty():
		archetypes[candidates.pop_back()] = Archetype.SHRINE
		have += 1

## Somewhere inside a cavern, for things that belong to the dark rather than to
## the masonry. Empty result if this floor has no caves.
func _cave_cell() -> Vector2i:
	if caves.is_empty():
		return Vector2i(-1, -1)
	var region: Rect2i = caves[rng.randi_range(0, caves.size() - 1)]
	return Vector2i(
		rng.randi_range(region.position.x + 1, maxi(region.position.x + 1, region.end.x - 2)),
		rng.randi_range(region.position.y + 1, maxi(region.position.y + 1, region.end.y - 2)))

## Fungus patches and pits: features rather than ground, so they are scattered
## rather than rolled per room.
func _scatter_features(map: DungeonMap) -> void:
	# The cave band gets more fungus, and gets it IN the caves.
	#
	# Not decoration. Trading rooms for caverns costs the floor its braziers,
	# which are placed per room -- so the dark band loses most of its light at
	# the same time as it loses its healing. Fungus is the answer the terrain
	# provides: the only light source that grows rather than being built, and
	# the one the player can choose to eat instead.
	#
	# That choice is the point. It has always been worth 1 hp and a glow, and
	# on these floors the glow is finally worth more than the hit point.
	var caveish := Bands.is_caves(depth)
	var patches := rng.randi_range(3, 5) if caveish else rng.randi_range(1, 3)
	for _patch in patches:
		var seed_cell := _cave_cell() if caveish else Vector2i(-1, -1)
		if seed_cell.x < 0:
			seed_cell = _random_open(map)
		if seed_cell.x < 0:
			continue
		for _cell in rng.randi_range(3, 7):
			var c := seed_cell + Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
			if map.get_tile(c.x, c.y) == Tiles.FLOOR \
					or map.get_tile(c.x, c.y) == Tiles.CAVE_FLOOR:
				map.set_tile(c.x, c.y, Tiles.FUNGUS)

	for _snare in rng.randi_range(0, 3):
		var t := _open_ground(map)
		if t.x >= 0:
			map.set_tile(t.x, t.y, Tiles.TRAP)

	if not allow_pits:
		return
	for _hole in rng.randi_range(0, 3):
		var spot := _open_ground(map)
		if spot.x >= 0:
			map.set_tile(spot.x, spot.y, Tiles.PIT)

## A cell with open ground on all eight sides.
##
## Both pits and traps are treated as solid by the pathfinder, so one dropped
## into a corridor severs the route -- the 200-seed connectivity test caught
## exactly that, three levels in two hundred with unreachable stairs. Out in
## the open there is always a way past, and a hazard you can see and walk
## around is a choice rather than a toll.
func _open_ground(map: DungeonMap) -> Vector2i:
	for _try in 40:
		var spot := _random_open(map)
		if spot.x < 0:
			continue
		var clear := true
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if not map.is_walkable(spot.x + dx, spot.y + dy):
					clear = false
		if clear:
			return spot
	return Vector2i(-1, -1)

func _random_open(map: DungeonMap) -> Vector2i:
	for _try in 60:
		var x := rng.randi_range(1, map.width - 2)
		var y := rng.randi_range(1, map.height - 2)
		if protected.has(Vector2i(x, y)):
			continue
		var t := map.get_tile(x, y)
		if t == Tiles.FLOOR or t == Tiles.CAVE_FLOOR:
			return Vector2i(x, y)
	return Vector2i(-1, -1)

func _roll_ground() -> int:
	var r := rng.randf()
	if r < 0.60: return Ground.DRY
	if r < 0.73: return Ground.DAMP
	if r < 0.83: return Ground.MUDDY
	if r < 0.90: return Ground.RUBBLED
	if r < 0.96: return Ground.BONEYARD
	return Ground.FLOODED

## Difficult ground is never placed over anything that matters -- only over
## plain floor -- so it can never bury a shrine, a brazier or a staircase. And
## because all of it stays walkable, it cannot sever a level either.
func _lay_terrain(map: DungeonMap) -> void:
	for room in rooms:
		var g := _roll_ground()
		if g != Ground.DRY:
			_paint_ground(map, room, g)
	for region in caves:
		if rng.randf() < 0.45:
			_paint_ground(map, region,
				Ground.MUDDY if rng.randf() < 0.55 else Ground.DAMP)

func _paint_ground(map: DungeonMap, area: Rect2i, g: int) -> void:
	var tile := Tiles.WATER
	var density := 0.3
	match g:
		Ground.DAMP:    tile = Tiles.WATER;  density = 0.28
		Ground.FLOODED: tile = Tiles.WATER;  density = 0.80
		Ground.MUDDY:   tile = Tiles.MUD;    density = 0.66
		Ground.RUBBLED:  tile = Tiles.RUBBLE; density = 0.34
		Ground.BONEYARD: tile = Tiles.BONES;  density = 0.55

	# Wettest in the middle, drying towards the walls, so it reads as something
	# that pooled rather than something that was sprayed on.
	var c := area.get_center()
	var rx := maxf(1.0, float(area.size.x) * 0.5)
	var ry := maxf(1.0, float(area.size.y) * 0.5)
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if protected.has(Vector2i(x, y)):
				continue
			var here := map.get_tile(x, y)
			if here != Tiles.FLOOR and here != Tiles.CAVE_FLOOR:
				continue
			var dx := float(x - c.x) / rx
			var dy := float(y - c.y) / ry
			var falloff := 1.0 - clampf(sqrt(dx * dx + dy * dy), 0.0, 1.0)
			if rng.randf() < density * (0.30 + 0.90 * falloff):
				map.set_tile(x, y, tile)

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
	_try_place(map, c.x, c.y, Tiles.SHRINE)
	for d in [Vector2i(2, 0), Vector2i(-2, 0)]:
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

## The eight neighbours in ring order, so a walk around them is a walk around
## the cell. Order matters: consecutive entries must be adjacent.
const RING := [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0),
	Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0),
]

## Decoration only ever paints over plain floor -- and, when what it is placing
## is solid, only where that cannot cut a route.
##
## The floor check on its own was not enough, though the old comment here
## claimed it was. It stops a brazier landing ON a door, a corridor or the
## stairs, but nothing stopped one landing on the floor tile just INSIDE a
## doorway, which plugs the door exactly as well. _decorate_shrine was the
## worst offender: it puts braziers two cells either side of the room centre,
## and in a six-wide room that is the tile in front of the west door.
##
## The symptom was not an unreachable room, because _ensure_connected runs
## afterwards and rescued the level by carving a fresh passage somewhere else.
## The symptom was a room with a blocked door AND a corridor arriving at an odd
## angle -- which is exactly what turned up in play.
func _try_place(map: DungeonMap, x: int, y: int, tile: int) -> void:
	if map.get_tile(x, y) != Tiles.FLOOR:
		return
	if not Tiles.is_walkable(tile) and _is_a_narrows(map, x, y):
		return
	map.set_tile(x, y, tile)

## Is this cell the only link between separate patches of open ground?
##
## Walks the eight neighbours as a ring and counts the runs of open ground that
## touch this cell. One run means it sits at the edge of open space and can be
## filled safely -- against a wall, in a corner, out in the middle of a floor.
## Two or more means it is a bridge between them: a doorway, a corridor, the
## mouth of an alcove.
##
## Cheaper and more general than a rule about doors, and it catches the cases a
## door rule would miss -- the one-cell gap between two pillars, the neck of a
## cave passage. It is deliberately conservative: it only ever refuses to place
## a decoration, which costs nothing.
func _is_a_narrows(map: DungeonMap, x: int, y: int) -> bool:
	var open: Array[bool] = []
	var any_closed := false
	for d in RING:
		var routable := _routable(map, x + d.x, y + d.y)
		open.append(routable)
		any_closed = any_closed or not routable
	# Open on all eight sides: nothing to cut.
	if not any_closed:
		return false
	var runs := 0
	for i in RING.size():
		if open[i] and not open[(i + RING.size() - 1) % RING.size()]:
			runs += 1
	return runs > 1
