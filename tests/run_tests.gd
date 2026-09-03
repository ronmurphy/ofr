extends SceneTree

## Headless test suite:  godot --headless --script res://tests/run_tests.gd
##
## This is the concrete reason the simulation owns no Godot nodes. Generating
## two hundred dungeons and asserting every one is completable takes under a
## second here, and needs no window, no renderer and no human.

var _passed := 0
var _failed := 0

func _initialize() -> void:
	print("")
	_test_map_always_connected()
	_test_fov_blocked_by_walls()
	_test_fov_is_symmetric()
	_test_light_does_not_pass_walls()
	_test_scheduler_respects_speed()
	_test_combat_and_death()
	_test_doors_block_sight_until_opened()
	_test_brazier_is_obstacle_but_not_opaque()
	_test_item_depth_gating()
	_test_pickup_use_and_drop()
	_test_blink_relocates()

	print("")
	print("  %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func check(name: String, condition: bool, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("  ok    %s" % name)
	else:
		_failed += 1
		print("  FAIL  %s   %s" % [name, detail])

# ---------------------------------------------------------------- tests ----

func _test_item_depth_gating() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var seen := {}
	for _i in 400:
		var it := Item.roll(rng, 1)
		if it != null:
			seen[it.id] = true
	check("depth 1 rolls healing potions", seen.has(&"potion_healing"))
	check("depth 1 never rolls blink scrolls", not seen.has(&"scroll_blink"))

	seen.clear()
	for _i in 400:
		var it := Item.roll(rng, 5)
		if it != null:
			seen[it.id] = true
	check("depth 5 can roll blink scrolls", seen.has(&"scroll_blink"))

func _test_pickup_use_and_drop() -> void:
	var gs := GameState.new(777)
	gs.new_game()

	var potion := Item.make(&"potion_healing")
	potion.x = gs.player.x
	potion.y = gs.player.y
	gs.ground.append(potion)

	check("item lies on the ground", gs.items_at(gs.player.x, gs.player.y).size() == 1)
	check("pick up succeeds", gs.player_pickup())
	check("ground is now clear", gs.items_at(gs.player.x, gs.player.y).is_empty())
	check("item is carried", gs.player.inventory.size() == 1)

	# A potion drunk at full health must cost neither the item nor the turn.
	gs.player.hp = gs.player.max_hp
	check("refuses to drink at full health", not gs.player_use(0))
	check("refused potion is not consumed", gs.player.inventory.size() == 1)

	gs.player.hp = 5
	var before := gs.player.hp
	check("drinking succeeds when hurt", gs.player_use(0))
	check("potion is consumed", gs.player.inventory.is_empty())
	check("hp went up", gs.player.hp > before)

	gs.player.inventory.append(Item.make(&"scroll_light"))
	var px := gs.player.x
	var py := gs.player.y
	check("drop succeeds", gs.player_drop(0))
	check("dropped item is back on the floor", gs.items_at(px, py).size() == 1)
	check("dropped item left the pack", gs.player.inventory.is_empty())

func _test_blink_relocates() -> void:
	var gs := GameState.new(31337)
	gs.new_game()
	gs.player.inventory.append(Item.make(&"scroll_blink"))
	var before := Vector2i(gs.player.x, gs.player.y)
	check("blink scroll is used", gs.player_use(0))
	check("blink moved the player", Vector2i(gs.player.x, gs.player.y) != before)
	check("blink landed somewhere walkable", gs.map.is_walkable(gs.player.x, gs.player.y))


func _test_map_always_connected() -> void:
	var bad := 0
	var trials := 200
	for i in trials:
		var gs := GameState.new(1000 + i)
		gs.new_game()
		var route := gs.pathfinder.path(
			Vector2i(gs.player.x, gs.player.y), gs.stairs)
		# Same cell is legitimately reachable with an empty path.
		if route.is_empty() and Vector2i(gs.player.x, gs.player.y) != gs.stairs:
			bad += 1
	check("dungeon is always completable (%d seeds)" % trials, bad == 0,
		"%d unreachable" % bad)

func _test_fov_blocked_by_walls() -> void:
	var m := DungeonMap.new(21, 5)
	for y in 5:
		for x in 21:
			m.set_tile(x, y, Tiles.FLOOR)
	m.set_tile(10, 2, Tiles.WALL)

	var buf := PackedByteArray()
	buf.resize(21 * 5)
	Fov.compute(m, 2, 2, 15, buf)

	check("origin sees itself", buf[m.idx(2, 2)] == 1)
	check("sees along an open row", buf[m.idx(8, 2)] == 1)
	check("wall itself is visible", buf[m.idx(10, 2)] == 1)
	check("cell directly behind wall is hidden", buf[m.idx(14, 2)] == 0)

func _test_fov_is_symmetric() -> void:
	# Symmetry matters for more than looks: monster AI asks "can it see the
	# player" by testing the player's own FOV, which is only fair if the two
	# agree. Perfect symmetry is not achievable with shadowcasting, so this
	# asserts the practical property -- overwhelming agreement.
	var gs := GameState.new(4242)
	gs.new_game()
	var a := PackedByteArray(); a.resize(gs.map.width * gs.map.height)
	var b := PackedByteArray(); b.resize(gs.map.width * gs.map.height)
	Fov.compute(gs.map, gs.player.x, gs.player.y, 8, a)

	var checked := 0
	var mismatch := 0
	for y in gs.map.height:
		for x in gs.map.width:
			if a[gs.map.idx(x, y)] == 0 or not gs.map.is_walkable(x, y):
				continue
			Fov.compute(gs.map, x, y, 8, b)
			checked += 1
			if b[gs.map.idx(gs.player.x, gs.player.y)] == 0:
				mismatch += 1
	var rate := 1.0 - float(mismatch) / maxf(1.0, float(checked))
	check("fov is near-symmetric (%.1f%% of %d cells)" % [rate * 100.0, checked],
		rate > 0.97, "%d mismatches" % mismatch)

func _test_light_does_not_pass_walls() -> void:
	var m := DungeonMap.new(21, 5)
	for y in 5:
		for x in 21:
			m.set_tile(x, y, Tiles.FLOOR)
	m.set_tile(10, 2, Tiles.WALL)

	var lm := LightMap.new(21, 5)
	var src := LightSource.new(2, 2, 15, Color(1, 0.7, 0.3), Color(0.3, 0.3, 0.5), 1.0)
	lm.compute(m, [src])

	var near := lm.get_light(6, 2)
	var behind := lm.get_light(14, 2)
	check("light reaches an open cell", near.r > lm.ambient.r + 0.1)
	check("light stops at a wall", is_equal_approx(behind.r, lm.ambient.r),
		"got %f vs ambient %f" % [behind.r, lm.ambient.r])

func _test_scheduler_respects_speed() -> void:
	var fast := Entity.new("fast", &"rat", 0, 0)
	fast.speed = 200
	var slow := Entity.new("slow", &"orc", 1, 0)
	slow.speed = 100

	var fast_turns := 0
	var slow_turns := 0
	for _i in 300:
		var who := Scheduler.next_actor([fast, slow])
		if who == null:
			break
		if who == fast:
			fast_turns += 1
		else:
			slow_turns += 1
		Scheduler.spend(who)

	var ratio := float(fast_turns) / maxf(1.0, float(slow_turns))
	check("double speed acts about twice as often (%.2f)" % ratio,
		ratio > 1.8 and ratio < 2.2, "%d vs %d" % [fast_turns, slow_turns])

func _test_combat_and_death() -> void:
	var e := Entity.new("victim", &"rat", 0, 0)
	e.max_hp = 10
	e.hp = 10
	e.take_damage(4)
	check("damage reduces hp", e.hp == 6)
	check("survivor is still alive", e.alive)
	e.take_damage(99)
	check("hp floors at zero", e.hp == 0)
	check("dead entity stops blocking", not e.alive and not e.blocks)

## Braziers are solid, which means level generation could in principle wall off
## the stairs with one. The 200-seed connectivity test above is what actually
## guards that; this just pins the intent.
func _test_brazier_is_obstacle_but_not_opaque() -> void:
	check("brazier blocks movement", not Tiles.is_walkable(Tiles.BRAZIER))
	check("brazier does not block sight", Tiles.is_transparent(Tiles.BRAZIER))

func _test_doors_block_sight_until_opened() -> void:
	var m := DungeonMap.new(11, 3)
	for x in 11:
		m.set_tile(x, 1, Tiles.FLOOR)
	m.set_tile(5, 1, Tiles.DOOR_CLOSED)

	var buf := PackedByteArray()
	buf.resize(11 * 3)
	Fov.compute(m, 1, 1, 10, buf)
	check("closed door blocks sight", buf[m.idx(8, 1)] == 0)
	check("closed door is walkable", m.is_walkable(5, 1))

	m.set_tile(5, 1, Tiles.DOOR_OPEN)
	Fov.compute(m, 1, 1, 10, buf)
	check("open door lets sight through", buf[m.idx(8, 1)] == 1)
