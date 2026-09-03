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
	_test_equipment()
	_test_inventory_letters()
	_test_inventory_grouping()

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
	check("depth 5 can roll plate mail", seen.has(&"plate_mail"))

	# min_depth is inclusive, so the exclusion boundary is the depth below.
	seen.clear()
	for _i in 400:
		var it := Item.roll(rng, 4)
		if it != null:
			seen[it.id] = true
	check("depth 4 never rolls plate mail", not seen.has(&"plate_mail"))
	check("depth 4 can roll a war axe", seen.has(&"war_axe"))

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

func _test_equipment() -> void:
	var gs := GameState.new(2024)
	gs.new_game()
	# Immortal so a stray goblin cannot end the run mid-assertion.
	gs.player.max_hp = 9999
	gs.player.hp = 9999
	var base_power := gs.player.total_power()
	var base_def := gs.player.total_defense()

	var dagger := Item.make(&"dagger")
	gs.player.inventory.append(dagger)
	check("a dagger is equipment", dagger.is_equipment())
	check("equipping succeeds", gs.player_use(0))
	check("weapon is equipped", gs.player.is_equipped(dagger))
	check("power rose by the weapon bonus",
		gs.player.total_power() == base_power + dagger.power_bonus)
	check("equipped weapon stays in the pack", gs.player.inventory.has(dagger))

	# A second weapon must replace the first, not stack with it.
	var axe := Item.make(&"war_axe")
	gs.player.inventory.append(axe)
	gs.player_use(1)
	check("second weapon swaps in", gs.player.is_equipped(axe))
	check("displaced weapon is unequipped", not gs.player.is_equipped(dagger))
	check("weapon bonuses do not stack",
		gs.player.total_power() == base_power + axe.power_bonus)

	gs.player_use(1)
	check("using an equipped item takes it off", not gs.player.is_equipped(axe))
	check("power returns to base", gs.player.total_power() == base_power)

	# Armour occupies an independent slot.
	var mail := Item.make(&"chain_mail")
	gs.player.inventory.append(mail)
	gs.player_use(2)
	check("armour equips", gs.player.is_equipped(mail))
	check("defense rose by the armour bonus",
		gs.player.total_defense() == base_def + mail.defense_bonus)

	gs.player_use(0)
	check("weapon and armour coexist",
		gs.player.is_equipped(dagger) and gs.player.is_equipped(mail))

	gs.player_drop(2)
	check("dropping worn armour takes it off", not gs.player.is_equipped(mail))
	check("defense returns to base", gs.player.total_defense() == base_def)

## Letters must belong to the item, not to its row -- otherwise sorting the
## list silently rebinds every key the player has memorised.
func _test_inventory_letters() -> void:
	var gs := GameState.new(4040)
	gs.new_game()
	gs.player.max_hp = 9999
	gs.player.hp = 9999

	var a := Item.make(&"potion_healing")
	var b := Item.make(&"dagger")
	gs.give_item(a)
	gs.give_item(b)
	check("first item gets 'a'", a.letter == "a")
	check("second item gets 'b'", b.letter == "b")

	var c := Item.make(&"scroll_light")
	gs.give_item(c)
	check("adding an item disturbs no existing letter", a.letter == "a" and b.letter == "b")
	check("third item gets 'c'", c.letter == "c")

	gs.player_drop(gs.player.inventory.find(b))
	check("a dropped item releases its letter", b.letter == "")
	var d := Item.make(&"leather_armour")
	gs.give_item(d)
	check("the freed letter is reused", d.letter == "b")
	check("untouched items keep their letters", a.letter == "a" and c.letter == "c")

	var panel := InventoryPanel.new()
	panel.state = gs
	check("letter 'a' resolves to the potion",
		gs.player.inventory[panel.letter_to_index(KEY_A)] == a)
	check("letter 'c' resolves to the scroll",
		gs.player.inventory[panel.letter_to_index(KEY_C)] == c)
	panel.free()

func _test_inventory_grouping() -> void:
	var gs := GameState.new(5050)
	gs.new_game()
	var dagger := Item.make(&"dagger")
	var axe := Item.make(&"war_axe")
	var mail := Item.make(&"leather_armour")
	var potion := Item.make(&"potion_healing")
	for it in [potion, dagger, axe, mail]:
		gs.give_item(it)
	gs.player.equipped[Item.Slot.ARMOR] = mail

	var panel := InventoryPanel.new()
	panel.state = gs
	panel.filter = InventoryPanel.Filter.ALL
	var rows: Array = panel._build_rows()

	check("equipped group comes first",
		rows.size() > 0 and rows[0].get("header", "") == "EQUIPPED")
	check("worn armour is the first listed item",
		rows.size() > 1 and rows[1].get("item", null) == mail)

	var weapons := []
	var in_weapons := false
	for r in rows:
		if r.has("header"):
			in_weapons = r["header"] == "WEAPONS"
			continue
		if in_weapons:
			weapons.append(r["item"].name)
	check("better weapon sorts above worse", weapons == ["war axe", "dagger"], str(weapons))

	panel.filter = InventoryPanel.Filter.POTIONS
	var only: Array = panel._build_rows()
	check("filtering shows only that kind",
		only.size() == 1 and only[0]["item"] == potion)
	check("filtering drops the group headers",
		only.filter(func(r): return r.has("header")).is_empty())
	panel.free()

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
