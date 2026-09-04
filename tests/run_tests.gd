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
	_test_terrain_properties()
	_test_pillar_casts_a_shadow()
	_test_spawn_points_are_open()
	_test_caves_are_reachable()
	_test_line_of_sight()
	_test_ranged_attacks_from_afar()
	_test_a_pillar_stops_an_arrow()
	_test_wounded_monsters_flee()
	_test_cornered_monsters_fight()
	_test_erratic_is_not_a_beeline()
	_test_goblins_are_bolder_together()
	_test_projectile_path()
	_test_combat_events_are_recorded()
	_test_damage_cancels_travel()
	_test_monsters_start_asleep()
	_test_sleeping_monsters_do_not_act()
	_test_adjacency_always_notices()
	_test_torch_makes_you_visible()
	_test_fighting_is_loud()
	_test_awake_monsters_lose_the_trail()
	_test_cave_cover_exists()
	_test_brazier_resting()
	_test_levels_offer_braziers()
	_test_threat_ceiling_holds()
	_test_tiers_fade_with_depth()
	_test_camera_deadzone()
	_test_forging()
	_test_materials_are_painted()
	_test_experience_and_levels()
	_test_armour_reduces_but_never_negates()
	_test_deep_tiers()
	_test_regeneration()
	_test_relighting_a_brazier()
	_test_monsters_carry_gear()
	_test_the_amulet_and_the_ascent()
	_test_player_ranged_attacks()
	_test_throwing()
	_test_launchers_are_poor_clubs()
	_test_suspend_round_trip()
	_test_suspend_slot_is_destroyed_on_load()
	_test_morgue_line()
	_test_shrines_appear()
	_test_shrine_effects()
	_test_shrine_identity_is_shuffled()
	_test_torch_flare()
	_test_difficult_ground()
	_test_bones_are_loud()
	_test_pits()
	_test_fungus_glows()
	_report_encounter_curve()

	print("")
	print("  %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

var _silent_ok := true

func check_silent(condition: bool) -> void:
	if not condition:
		_silent_ok = false

func check(name: String, condition: bool, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("  ok    %s" % name)
	else:
		_failed += 1
		print("  FAIL  %s   %s" % [name, detail])

# --------------------------------------------------------------- helpers ----

## A controlled open arena, so AI tests are not at the mercy of whatever the
## dungeon generator felt like producing.
func _arena(w: int, h: int) -> GameState:
	var gs := GameState.new(1)
	gs.new_game()
	gs.map = DungeonMap.new(w, h)
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			gs.map.set_tile(x, y, Tiles.FLOOR)
	gs.map.set_all_visible()
	gs.light_map = LightMap.new(w, h)
	gs.pathfinder = Pathfinder.new(gs.map)
	gs.entities = [gs.player]
	gs.ground = []
	gs.player.max_hp = 9999
	gs.player.hp = 9999
	# Resize by assignment, not `gs._fov_buffer.resize()` -- PackedArrays are
	# copy-on-write and reaching through a property mutates a temporary.
	var buf := PackedByteArray()
	buf.resize(w * h)
	gs._fov_buffer = buf
	return gs

func _spawn(gs: GameState, mname: String, x: int, y: int) -> Entity:
	for e in GameState.BESTIARY:
		if e["name"] != mname:
			continue
		var m := Entity.new(e["name"], e["app"], x, y)
		m.max_hp = e["hp"]
		m.hp = e["hp"]
		m.power = e["power"]
		m.defense = e["def"]
		m.speed = e["speed"]
		m.ai = e.get("ai", &"hunter")
		m.attack_range = e.get("range", 1)
		m.flee_below = e.get("flee", 0.0)
		# Kept in step with GameState._spawn_in. A test double that quietly
		# drops fields makes the tests disagree with the game about what a
		# monster even is.
		m.regen = e.get("regen", 0)
		m.threat = int(e["threat"])
		m.flying = e.get("flying", false)
		m.heavy = e.get("heavy", false)
		# Behaviour tests want behaviour, not the awareness gate. Awareness has
		# its own tests below, which set this back to ASLEEP explicitly.
		m.alertness = Entity.Alert.AWAKE
		gs.entities.append(m)
		return m
	return null

# ---------------------------------------------------------------- tests ----

func _test_monsters_start_asleep() -> void:
	var gs := GameState.new(9100)
	gs.new_game()
	var awake := 0
	var total := 0
	for e in gs.entities:
		if e.is_player:
			continue
		total += 1
		if e.alertness != Entity.Alert.ASLEEP:
			awake += 1
	check("the level has monsters to check", total > 0, "%d" % total)
	check("every monster starts asleep", awake == 0, "%d awake" % awake)

func _test_sleeping_monsters_do_not_act() -> void:
	var gs := _arena(31, 13)
	gs.player.x = 5
	gs.player.y = 6
	gs.torch_lit = false
	gs.update_vision()

	var m := _spawn(gs, "kobold", 20, 6)
	m.alertness = Entity.Alert.ASLEEP
	var where := Vector2i(m.x, m.y)
	var hp := gs.player.hp
	for _i in 10:
		gs._take_ai_turn(m)
	check("a sleeping monster stays put", Vector2i(m.x, m.y) == where)
	check("and does not attack", gs.player.hp == hp)

func _test_adjacency_always_notices() -> void:
	var gs := _arena(21, 9)
	gs.player.x = 5
	gs.player.y = 4
	gs.torch_lit = false
	gs.update_vision()

	var m := _spawn(gs, "kobold", 6, 4)
	m.alertness = Entity.Alert.ASLEEP
	gs._update_awareness(m)
	gs._update_awareness(m)
	check("standing next to something wakes it however dark it is",
		m.alertness == Entity.Alert.AWAKE)

## The mechanic in one test: the torch is both how you see and how you are seen.
func _test_torch_makes_you_visible() -> void:
	var trials := 200
	var lit_notices := 0
	var dark_notices := 0

	for lit in [true, false]:
		var gs := _arena(31, 13)
		gs.player.x = 5
		gs.player.y = 6
		gs.torch_lit = lit
		gs.update_vision()
		for _i in trials:
			var m := _spawn(gs, "kobold", 11, 6)
			m.alertness = Entity.Alert.ASLEEP
			gs._update_awareness(m)
			if m.alertness != Entity.Alert.ASLEEP:
				if lit:
					lit_notices += 1
				else:
					dark_notices += 1
			gs.entities.erase(m)

	check("a lit torch gets you noticed (%d/%d)" % [lit_notices, trials],
		lit_notices > trials / 5, "%d" % lit_notices)
	check("dousing it roughly halves that or better (%d vs %d)"
		% [dark_notices, lit_notices], dark_notices * 2 < lit_notices)

func _test_fighting_is_loud() -> void:
	var gs := _arena(25, 11)
	gs.player.x = 5
	gs.player.y = 4
	var target := _spawn(gs, "kobold", 6, 4)
	var neighbour := _spawn(gs, "goblin", 9, 4)
	var distant := _spawn(gs, "orc", 20, 9)
	for m in [target, neighbour, distant]:
		m.alertness = Entity.Alert.ASLEEP
		# Durable enough to survive the blow, or a lucky roll kills the target
		# and `wake` skips it for being dead -- which made this test depend on
		# the damage dice.
		m.max_hp = 500
		m.hp = 500

	gs._attack(gs.player, target)
	check("the thing you hit wakes", target.alertness == Entity.Alert.AWAKE)
	check("so does anything within earshot", neighbour.alertness == Entity.Alert.AWAKE)
	check("but not something across the level",
		distant.alertness == Entity.Alert.ASLEEP)

func _test_awake_monsters_lose_the_trail() -> void:
	var gs := _arena(31, 13)
	gs.player.x = 3
	gs.player.y = 6
	var m := _spawn(gs, "kobold", 27, 6)
	m.alertness = Entity.Alert.AWAKE

	for _i in 11:
		gs._update_awareness(m)
	check("a monster that loses you stops hunting",
		m.alertness != Entity.Alert.AWAKE)

	for _i in 8:
		gs._update_awareness(m)
	check("and eventually settles back to sleep",
		m.alertness == Entity.Alert.ASLEEP)

## Caves were open killing floors, which left ranged monsters unanswerable in
## exactly the place the generator liked to put them.
func _test_cave_cover_exists() -> void:
	var with_cover := 0
	var caves := 0
	for i in 60:
		var gs := GameState.new(9500 + i)
		gs.new_game()
		for region in gs.cave_regions:
			caves += 1
			var found := false
			for y in range(region.position.y, region.end.y):
				for x in range(region.position.x, region.end.x):
					if gs.map.get_tile(x, y) == Tiles.STALAGMITE:
						found = true
						break
				if found:
					break
			if found:
				with_cover += 1
	check("caves are generated to check", caves > 0, "%d" % caves)
	check("most caves carry some cover (%d/%d)" % [with_cover, caves],
		with_cover > caves / 2, "%d" % with_cover)
	check("stalagmites block movement", not Tiles.is_walkable(Tiles.STALAGMITE))
	check("stalagmites block sight", not Tiles.is_transparent(Tiles.STALAGMITE))

func _test_brazier_resting() -> void:
	var gs := _arena(21, 9)
	gs.player.x = 5
	gs.player.y = 4
	gs.map.set_tile(6, 4, Tiles.BRAZIER)
	gs.brazier_charge = {Vector2i(6, 4): GameState.BRAZIER_CHARGE}
	gs._gather_lights()
	gs.player.max_hp = 30
	gs.player.hp = 10
	check("the brazier is lighting the room", gs.static_lights.size() == 1)

	gs.player_wait()
	check("resting beside a brazier heals", gs.player.hp == 12, "%d" % gs.player.hp)
	check("and draws down its charge",
		int(gs.brazier_charge[Vector2i(6, 4)]) == GameState.BRAZIER_CHARGE - 2)

	for _i in 10:
		gs.player_wait()
	check("a brazier's pool is finite",
		gs.player.hp == 10 + GameState.BRAZIER_CHARGE, "%d" % gs.player.hp)
	check("a spent brazier goes out", gs.map.get_tile(6, 4) == Tiles.BRAZIER_SPENT)
	check("and stops giving light", gs.static_lights.is_empty())
	check("a spent brazier is still an obstacle",
		not Tiles.is_walkable(Tiles.BRAZIER_SPENT))

	var hp := gs.player.hp
	gs.player.x = 15
	gs.player_wait()
	check("waiting away from a brazier is just waiting", gs.player.hp == hp)

	# Charge must not be wasted by resting at full health.
	var full := _arena(21, 9)
	full.player.x = 5
	full.player.y = 4
	full.map.set_tile(6, 4, Tiles.BRAZIER)
	full.brazier_charge = {Vector2i(6, 4): GameState.BRAZIER_CHARGE}
	full.player.max_hp = 30
	full.player.hp = 30
	full.player_wait()
	check("resting at full health wastes nothing",
		int(full.brazier_charge[Vector2i(6, 4)]) == GameState.BRAZIER_CHARGE)

func _test_levels_offer_braziers() -> void:
	var with_any := 0
	var trials := 40
	var total := 0
	for i in trials:
		var gs := GameState.new(9700 + i)
		gs.new_game()
		total += gs.brazier_charge.size()
		if gs.brazier_charge.size() > 0:
			with_any += 1
	check("most levels offer somewhere to rest (%d/%d, %d braziers)"
		% [with_any, trials, total], with_any > trials * 3 / 4, "%d" % with_any)

## The headline guarantee: no room can roll something unsurvivable.
func _test_threat_ceiling_holds() -> void:
	var worst_over := 0
	var breaches := 0
	var rooms_checked := 0

	for d in range(1, 9):
		for i in 25:
			var gs := GameState.new(11000 + d * 100 + i)
			gs.new_game()
			gs.depth = d
			gs.build_level()
			var ceiling := gs.room_threat_ceiling()
			for room in gs.room_rects:
				rooms_checked += 1
				var sum := 0
				for e in gs.entities:
					if not e.is_player and room.has_point(Vector2i(e.x, e.y)):
						sum += e.threat
				if sum > ceiling:
					breaches += 1
					worst_over = maxi(worst_over, sum - ceiling)

	check("no room exceeds its threat ceiling (%d rooms, depths 1-8)" % rooms_checked,
		breaches == 0, "%d breaches, worst %d over" % [breaches, worst_over])

func _test_tiers_fade_with_depth() -> void:
	var shallow_orcs := 0
	var deep_rats := 0
	for i in 40:
		var shallow := GameState.new(12000 + i)
		shallow.new_game()
		for e in shallow.entities:
			if e.name == "orc":
				shallow_orcs += 1

		var deep := GameState.new(12500 + i)
		deep.new_game()
		deep.depth = 10
		deep.build_level()
		for e in deep.entities:
			if e.name == "giant rat":
				deep_rats += 1

	check("orcs never appear on depth 1", shallow_orcs == 0, "%d" % shallow_orcs)
	check("giant rats have faded out by depth 10", deep_rats == 0, "%d" % deep_rats)

## Not an assertion -- a measurement, so the numbers can be argued with.
func _report_encounter_curve() -> void:
	print("")
	print("  encounter curve            ceiling   worst room   avg room   monsters/floor")
	for d in [1, 2, 3, 4, 6, 8]:
		var worst := 0
		var total := 0
		var rooms := 0
		var mobs := 0
		var runs := 30
		var ceiling := 0
		for i in runs:
			var gs := GameState.new(13000 + d * 100 + i)
			gs.new_game()
			gs.depth = d
			gs.build_level()
			ceiling = gs.room_threat_ceiling()
			for e in gs.entities:
				if not e.is_player:
					mobs += 1
			for room in gs.room_rects:
				var sum := 0
				for e in gs.entities:
					if not e.is_player and room.has_point(Vector2i(e.x, e.y)):
						sum += e.threat
				rooms += 1
				total += sum
				worst = maxi(worst, sum)
		print("    depth %-2d                  %3d       %3d          %5.1f      %5.1f"
			% [d, ceiling, worst, float(total) / maxf(1.0, float(rooms)),
			   float(mobs) / float(runs)])
	print("")

## The camera is renderer-only, but it is still logic and still worth pinning.
func _test_camera_deadzone() -> void:
	var gs := _arena(120, 60)
	var grid := GlyphGrid.new()
	grid.cell_size = 18
	grid.scroll_margin = 8
	grid.size = Vector2(72 * 18, 40 * 18)
	grid.state = gs

	check("the viewport is 72x40 cells", grid.viewport_cells() == Vector2i(72, 40),
		str(grid.viewport_cells()))

	gs.player.x = 40
	gs.player.y = 30
	grid.centre_on_player()
	var start: Vector2i = grid._origin

	# Moving inside the deadzone must not shift the map at all -- this is the
	# whole point of the margin.
	gs.player.x = 45
	grid._update_camera()
	check("the camera holds still inside the deadzone", grid._origin == start,
		"%s -> %s" % [start, grid._origin])

	gs.player.x = 100
	grid._update_camera()
	check("it follows once you approach the edge", grid._origin.x > start.x)
	check("and keeps you inside the margin",
		gs.player.x - grid._origin.x <= 72 - grid.scroll_margin)

	gs.player.x = 119
	gs.player.y = 59
	grid._update_camera()
	check("it never scrolls past the map edge",
		grid._origin.x <= 120 - 72 and grid._origin.y <= 60 - 40,
		str(grid._origin))

	# A mouse click must resolve to the right cell once the view has moved.
	var probe := grid.cell_at(Vector2(5 * 18 + 4, 3 * 18 + 4))
	check("mouse position accounts for the scroll",
		probe == Vector2i(grid._origin.x + 5, grid._origin.y + 3), str(probe))

	# Look mode must be able to reach terrain the player is nowhere near --
	# it inspects what you remember, and most of a 120-wide map is off screen.
	gs.player.x = 10
	gs.player.y = 10
	grid.look_cursor = Vector2i(-1, -1)
	grid.centre_on_player()
	var parked: Vector2i = grid._origin
	grid.look_cursor = Vector2i(110, 55)
	grid._update_camera()
	check("the camera follows the look cursor", grid._origin != parked)
	check("and brings the cursor into view",
		grid.look_cursor.x - grid._origin.x < 72
			and grid.look_cursor.y - grid._origin.y < 40,
		"%s from %s" % [grid.look_cursor, grid._origin])

	grid.look_cursor = Vector2i(-1, -1)
	grid._update_camera()
	check("leaving look mode returns the view to the player",
		gs.player.x - grid._origin.x < 72 and gs.player.x >= grid._origin.x)
	grid.free()

func _forge_arena() -> GameState:
	var gs := _arena(21, 9)
	gs.player.x = 5
	gs.player.y = 4
	gs.map.set_tile(6, 4, Tiles.BRAZIER)
	gs.brazier_charge = {Vector2i(6, 4): GameState.BRAZIER_CHARGE}
	gs._gather_lights()
	gs.player.max_hp = 30
	gs.player.hp = 30
	return gs

func _test_forging() -> void:
	var gs := _forge_arena()
	var a := Item.make(&"dagger")
	var b := Item.make(&"dagger")
	gs.give_item(a)
	gs.give_item(b)

	check("a brazier can forge", gs.can_forge_here())
	check("merging succeeds", gs.player_merge(0))
	check("the donor is consumed", gs.player.inventory.size() == 1)
	check("the survivor gained a point",
		a.power_bonus == a.base_power_bonus + 1, "%d" % a.power_bonus)
	check("it reads as upgraded", a.display_name() == "dagger +1", a.display_name())
	check("forging drew down the brazier",
		int(gs.brazier_charge[Vector2i(6, 4)])
			== GameState.BRAZIER_CHARGE - GameState.MERGE_COST)

	# Two upgrades is the cap: three daggers take one to +4 total.
	gs.give_item(Item.make(&"dagger"))
	check("a plain donor can feed an upgraded item", gs.player_merge(0))
	check("a second merge lands", a.upgrade_level() == 2, "%d" % a.upgrade_level())
	check("and then it is capped", not a.can_upgrade())
	check("three daggers is the whole cost", a.power_bonus == 4, "%d" % a.power_bonus)
	gs.give_item(Item.make(&"dagger"))
	check("merging past the cap is refused", not gs.player_merge(0))

	# Everything else that should be refused.
	var bare := _arena(21, 9)
	bare.player.x = 5
	bare.player.y = 4
	bare.give_item(Item.make(&"dagger"))
	bare.give_item(Item.make(&"dagger"))
	check("no brazier, no forge", not bare.player_merge(0))

	var lone := _forge_arena()
	lone.give_item(Item.make(&"dagger"))
	check("a single item has nothing to merge with", not lone.player_merge(0))

	var potions := _forge_arena()
	potions.give_item(Item.make(&"potion_healing"))
	potions.give_item(Item.make(&"potion_healing"))
	check("consumables cannot be forged", not potions.player_merge(0))

	# Forging away something you are wearing must take it off first.
	var worn := _forge_arena()
	var keep := Item.make(&"leather_armour")
	var donor := Item.make(&"leather_armour")
	worn.give_item(keep)
	worn.give_item(donor)
	worn.player.equipped[Item.Slot.ARMOR] = donor
	check("merging a worn donor works", worn.player_merge(0))
	check("and it is no longer equipped", not worn.player.is_equipped(donor))
	check("armour gains defense, not power",
		keep.defense_bonus == keep.base_defense_bonus + 1)

## Materials are what finally make the archetypes visible. Without a check
## here, a generator change could silently stop painting them and the only
## symptom would be a map that quietly got harder to read.
func _test_materials_are_painted() -> void:
	var seen := {}
	var caverns_ok := 0
	var caves := 0
	for i in 40:
		var gs := GameState.new(41000 + i)
		gs.new_game()
		for y in gs.map.height:
			for x in gs.map.width:
				seen[gs.map.material_at(x, y)] = true
		for region in gs.cave_regions:
			caves += 1
			var c := region.get_center()
			if gs.map.material_at(c.x, c.y) == Materials.CAVERN:
				caverns_ok += 1

	check("plain stone is painted", seen.has(Materials.STONE))
	check("flooded rooms are painted", seen.has(Materials.FLOODED))
	check("ruined rooms are painted", seen.has(Materials.RUIN))
	check("sanctums are painted", seen.has(Materials.SANCTUM))
	check("caverns are painted", seen.has(Materials.CAVERN))
	check("every cave centre reads as cavern (%d/%d)" % [caverns_ok, caves],
		caverns_ok == caves, "%d of %d" % [caverns_ok, caves])
	var probe := GameState.new(1)
	probe.new_game()
	check("out of bounds falls back to stone",
		probe.map.material_at(-5, -5) == Materials.STONE)

func _test_experience_and_levels() -> void:
	var gs := _arena(21, 9)
	gs.player.x = 5
	gs.player.y = 4
	check("a new character is level 1 with no xp",
		gs.player.level == 1 and gs.player.xp == 0)
	check("level 1 costs nothing", gs.xp_for_level(1) == 0)
	check("levels cost progressively more",
		gs.xp_for_level(3) - gs.xp_for_level(2)
			< gs.xp_for_level(4) - gs.xp_for_level(3))

	# A kill pays its threat, which is the same number the ceiling is built on.
	var orc := _spawn(gs, "orc", 6, 4)
	orc.hp = 1
	gs.player.power = 99
	gs._attack(gs.player, orc)
	check("killing something awards its threat", gs.player.xp == orc.threat,
		"%d vs %d" % [gs.player.xp, orc.threat])

	var before_hp := gs.player.max_hp
	var before_power := gs.player.power
	gs.award_xp(gs.xp_for_level(2))
	check("enough xp raises the level", gs.player.level == 2)
	check("a level grants hit points",
		gs.player.max_hp == before_hp + GameState.LEVEL_HP)
	check("and power on even levels", gs.player.power == before_power + 1)

	# A single large award must be able to cross several thresholds at once.
	gs.award_xp(gs.xp_for_level(6))
	check("one award can cross several levels", gs.player.level >= 5,
		"%d" % gs.player.level)

	# Descending pays a multiple of the ceiling for the floor just left.
	var deep := GameState.new(777)
	deep.new_game()
	var expected := deep.room_threat_ceiling() * GameState.XP_DEPTH_MULTIPLIER
	deep.player.x = deep.stairs.x
	deep.player.y = deep.stairs.y
	check("descending succeeds", deep.player_descend())
	check("and pays for the floor survived", deep.player.xp == expected,
		"%d vs %d" % [deep.player.xp, expected])
	check("the payment uses the OLD floor's ceiling",
		expected < deep.room_threat_ceiling() * GameState.XP_DEPTH_MULTIPLIER)

	# Stealth must not fall hopelessly behind: descending alone has to be a
	# meaningful share of what clearing the floor would pay.
	var ghost := GameState.new(4242)
	ghost.new_game()
	var floor_kills := 0
	for e in ghost.entities:
		if not e.is_player:
			floor_kills += e.threat
	var descend_pay := ghost.room_threat_ceiling() * GameState.XP_DEPTH_MULTIPLIER
	check("descending is worth a real share of clearing (%d vs %d)"
		% [descend_pay, floor_kills], descend_pay * 2 >= floor_kills)

## Armour must stay worth wearing without becoming immunity.
func _test_armour_reduces_but_never_negates() -> void:
	var gs := _arena(21, 9)
	gs.player.x = 5
	gs.player.y = 4
	gs.player.max_hp = 9999
	gs.player.hp = 9999

	var orc := _spawn(gs, "orc", 6, 4)
	orc.alertness = Entity.Alert.AWAKE

	# Defense equal to the attacker's power used to floor damage at 1.
	gs.player.defense = orc.power
	var worst := 0
	for _i in 60:
		var before := gs.player.hp
		gs._attack(orc, gs.player)
		worst = maxi(worst, before - gs.player.hp)
	var least := int(ceil(float(orc.power) * GameState.DAMAGE_FLOOR_FRACTION))
	check("heavy armour never reduces a blow to nothing", worst >= least,
		"worst %d, floor %d" % [worst, least])

	# Absurd armour still cannot make you immune.
	gs.player.defense = 999
	var before2 := gs.player.hp
	gs._attack(orc, gs.player)
	check("even absurd armour leaves the floor intact",
		before2 - gs.player.hp >= least)

	# And the early game is untouched: a rat still does what it always did.
	var rat := _spawn(gs, "giant rat", 4, 4)
	gs.player.defense = 1
	var seen := 0
	for _i in 40:
		var b := gs.player.hp
		gs._attack(rat, gs.player)
		seen = maxi(seen, b - gs.player.hp)
	check("a rat against light armour is unchanged", seen <= 2, "%d" % seen)

func _test_deep_tiers() -> void:
	var shallow := {}
	for i in 30:
		var gs := GameState.new(6100 + i)
		gs.new_game()
		for e in gs.entities:
			if not e.is_player:
				shallow[e.name] = true
	check("no dragons on depth 1", not shallow.has("young dragon"))
	check("no ogres on depth 1", not shallow.has("ogre"))

	var deep := {}
	for i in 30:
		var gs := GameState.new(6200 + i)
		gs.new_game()
		gs.depth = 10
		gs.build_level()
		for e in gs.entities:
			if not e.is_player:
				deep[e.name] = true
	check("deep floors field the heavy tiers",
		deep.has("young dragon") or deep.has("stone golem") or deep.has("shadow"),
		str(deep.keys()))
	check("and the starting rabble has faded out",
		not deep.has("giant rat") and not deep.has("kobold"), str(deep.keys()))

	# The ascent runs at effective depths past the deepest tier. Without the
	# fade clamp every monster would drop out of the pool and floors would
	# generate empty.
	var ascent := 0
	for i in 20:
		var gs := GameState.new(6300 + i)
		gs.new_game()
		gs.depth = 19
		gs.build_level()
		for e in gs.entities:
			if not e.is_player:
				ascent += 1
	check("floors beyond the deepest tier still populate (%d)" % ascent,
		ascent > 0, "%d" % ascent)

func _test_regeneration() -> void:
	var gs := _arena(21, 9)
	gs.player.x = 15
	gs.player.y = 4

	var troll := _spawn(gs, "cave troll", 3, 4)
	troll.alertness = Entity.Alert.ASLEEP
	troll.hp = 10
	gs._take_ai_turn(troll)
	check("a troll knits itself back together even asleep",
		troll.hp == 10 + troll.regen, "%d" % troll.hp)

	troll.hp = troll.max_hp
	gs._take_ai_turn(troll)
	check("and never past full", troll.hp == troll.max_hp)

	var orc := _spawn(gs, "orc", 4, 6)
	orc.hp = 5
	gs._take_ai_turn(orc)
	check("things without regeneration stay wounded", orc.hp == 5)

func _test_relighting_a_brazier() -> void:
	var gs := _forge_arena()
	gs.map.set_tile(6, 4, Tiles.BRAZIER_SPENT)
	gs.brazier_charge = {}
	gs._gather_lights()
	check("a spent brazier gives no light", gs.static_lights.is_empty())
	check("and cannot be rested at", not gs.can_forge_here())

	gs.give_item(Item.make(&"scroll_light"))
	gs.map.reveal_all()
	check("reading a scroll beside it works", gs.player_use(0))
	check("the brazier is lit again", gs.map.get_tile(6, 4) == Tiles.BRAZIER)
	check("with a weaker charge than a fresh one",
		int(gs.brazier_charge[Vector2i(6, 4)]) == GameState.RELIGHT_CHARGE
			and GameState.RELIGHT_CHARGE < GameState.BRAZIER_CHARGE)
	check("and it gives light once more", gs.static_lights.size() == 1)
	check("the scroll is spent", gs.player.inventory.is_empty())

	# Away from a dead brazier the scroll does what it always did.
	var open_ground := _arena(31, 13)
	open_ground.player.x = 15
	open_ground.player.y = 6
	open_ground.give_item(Item.make(&"scroll_light"))
	var explored_before := 0
	for i in open_ground.map.explored.size():
		if open_ground.map.explored[i] != 0:
			explored_before += 1
	check("reading it elsewhere still reveals", open_ground.player_use(0))
	var explored_after := 0
	for i in open_ground.map.explored.size():
		if open_ground.map.explored[i] != 0:
			explored_after += 1
	check("and the map grows", explored_after > explored_before,
		"%d -> %d" % [explored_before, explored_after])

func _test_monsters_carry_gear() -> void:
	const ANIMALS := ["giant rat", "cave bat", "harpy", "wyvern", "shadow",
		"stone golem", "young dragon", "cave troll"]
	var armed := 0
	var total := 0
	var armed_animals := 0
	var understated := 0

	for d in [1, 3, 5, 8]:
		for i in 25:
			var gs := GameState.new(71000 + d * 100 + i)
			gs.new_game()
			gs.depth = d
			gs.build_level()
			for e in gs.entities:
				if e.is_player:
					continue
				total += 1
				if e.equipped.is_empty():
					continue
				armed += 1
				if ANIMALS.has(e.name):
					armed_animals += 1
				# Gear has to be paid for in threat, or the ceiling lies.
				var base := 0
				for b in GameState.BESTIARY:
					if b["name"] == e.name:
						base = int(b["threat"])
				if e.threat <= base:
					understated += 1

	check("some monsters carry gear (%d of %d)" % [armed, total], armed > 0)
	check("but not all of them", armed < total)
	check("animals and constructs carry nothing", armed_animals == 0,
		"%d armed" % armed_animals)
	check("gear is always paid for in threat", understated == 0,
		"%d understated" % understated)

	# Gear must actually make the monster harder, not just decorate it.
	var arena := _arena(21, 9)
	var orc := _spawn(arena, "orc", 8, 4)
	var base_power := orc.total_power()
	var base_def := orc.total_defense()
	orc.equipped[Item.Slot.WEAPON] = Item.make(&"short_sword")
	orc.equipped[Item.Slot.ARMOR] = Item.make(&"chain_mail")
	check("an armed monster hits harder", orc.total_power() > base_power)
	check("and takes less", orc.total_defense() > base_def)

	# Loot drops sometimes, and not every time.
	# One arena reused across the run, so the rng actually advances. Rebuilding
	# it each pass reseeded from the same value and produced 200 copies of the
	# same roll.
	var loot := _arena(21, 9)
	loot.player.x = 5
	loot.player.y = 4
	loot.player.power = 999
	var drops := 0
	var kills := 200
	for i in kills:
		loot.ground.clear()
		var victim := _spawn(loot, "orc", 6, 4)
		victim.hp = 1
		victim.equipped[Item.Slot.WEAPON] = Item.make(&"dagger")
		loot._attack(loot.player, victim)
		drops += loot.ground.size()
		check_silent(victim.equipped.is_empty())
		loot.entities.erase(victim)
	check("gear drops sometimes (%d of %d)" % [drops, kills], drops > 0)
	check("and not every time", drops < kills)
	check("a corpse never keeps its equipment", _silent_ok)

func _test_the_amulet_and_the_ascent() -> void:
	var gs := GameState.new(8800)
	gs.new_game()

	# Shallow floors have stairs down and no relic.
	check("depth 1 has a way down",
		gs.map.get_tile(gs.stairs.x, gs.stairs.y) == Tiles.STAIRS_DOWN)
	var relics := 0
	for it in gs.ground:
		if it.kind == Item.Kind.AMULET:
			relics += 1
	check("and no amulet", relics == 0)

	# The bottom has the amulet and no way further down.
	gs.depth = GameState.MAX_DEPTH
	gs.build_level()
	check("the bottom has no stairs down",
		gs.map.get_tile(gs.stairs.x, gs.stairs.y) != Tiles.STAIRS_DOWN)
	var found: Item = null
	for it in gs.ground:
		if it.kind == Item.Kind.AMULET:
			found = it
	check("the amulet waits at the bottom", found != null)

	# Taking it turns the run around.
	check("not ascending yet", not gs.ascending)
	gs.player.x = found.x
	gs.player.y = found.y
	check("taking the amulet works", gs.player_pickup())
	check("the run has turned around", gs.ascending)
	check("the amulet is carried", gs.player.inventory.size() == 1
		and gs.player.inventory[0].kind == Item.Kind.AMULET)
	check("the floor now has a way up",
		gs.map.get_tile(gs.stairs.x, gs.stairs.y) == Tiles.STAIRS_UP)

	# Climbing is harder than descending was, and gets harder as you go.
	var at_bottom := gs.room_threat_ceiling()
	gs.depth = 5
	gs.build_level()
	var midway := gs.room_threat_ceiling()
	gs.depth = 1
	gs.build_level()
	var at_the_door := gs.room_threat_ceiling()
	check("the climb tightens as you near the exit (%d -> %d -> %d)"
		% [at_bottom, midway, at_the_door],
		at_bottom < midway and midway < at_the_door)

	var descending := GameState.new(8801)
	descending.new_game()
	descending.depth = 1
	descending.build_level()
	check("floor 1 on the way out is far worse than on the way in (%d vs %d)"
		% [at_the_door, descending.room_threat_ceiling()],
		at_the_door > descending.room_threat_ceiling() * 2)

	# And the exit.
	gs.player.x = gs.stairs.x
	gs.player.y = gs.stairs.y
	var xp_before := gs.player.xp
	check("climbing out of depth 1 works", gs.player_ascend())
	check("that is the win", gs.won)
	check("the run is over", gs.game_over)
	check("and the last floor paid out", gs.player.xp > xp_before)

func _test_player_ranged_attacks() -> void:
	var gs := _arena(31, 11)
	gs.player.x = 4
	gs.player.y = 5
	gs.player.max_hp = 9999
	gs.player.hp = 9999
	gs.map.set_all_visible()

	var far := _spawn(gs, "kobold", 20, 5)
	var near := _spawn(gs, "goblin", 9, 5)
	far.max_hp = 500
	far.hp = 500
	near.max_hp = 500
	near.hp = 500

	check("bare hands have no reach", gs.player.total_range() == 1)
	check("and no targets", gs.firing_targets().is_empty())
	check("firing without a launcher is refused",
		not gs.player_fire(Vector2i(9, 5)))

	var bow := Item.make(&"short_bow")
	gs.player.inventory.append(bow)
	gs.player.equipped[Item.Slot.WEAPON] = bow
	check("a bow grants reach", gs.player.total_range() == bow.range_bonus)

	# Only what is actually shootable: the far kobold is out of reach at 16.
	var targets := gs.firing_targets()
	check("targets are the legal shots only",
		targets.size() == 1 and targets[0] == near, "%d" % targets.size())
	check("and are ordered nearest first",
		targets.is_empty() or targets[0] == near)
	check("out of range is not a shot", not gs.can_fire_at(Vector2i(20, 5)))

	# Cover breaks the shot -- the whole reason the reticle shows blocked.
	gs.map.set_tile(6, 5, Tiles.PILLAR)
	check("a pillar blocks the shot", not gs.can_fire_at(Vector2i(9, 5)))
	check("and firing into it is refused", not gs.player_fire(Vector2i(9, 5)))
	gs.map.set_tile(6, 5, Tiles.FLOOR)
	check("clearing the cover restores the shot", gs.can_fire_at(Vector2i(9, 5)))

	# A real shot lands and costs a turn.
	var hp_before := near.hp
	var turns_before := gs.turns
	check("the shot is taken", gs.player_fire(Vector2i(9, 5)))
	check("it wounds the target", near.hp < hp_before)
	check("and spends a turn", gs.turns > turns_before)

	# Shooting empty floor is refused rather than wasted.
	var turns_now := gs.turns
	check("shooting nothing is refused", not gs.player_fire(Vector2i(11, 5)))
	check("and costs no turn", gs.turns == turns_now)

	# Melee weapons must not quietly become ranged.
	var axe := Item.make(&"war_axe")
	gs.player.equipped[Item.Slot.WEAPON] = axe
	check("a war axe has no reach", gs.player.total_range() == 1)
	check("and the launcher trades damage for it",
		bow.power_bonus < axe.power_bonus)

func _test_throwing() -> void:
	check("daggers can be thrown", Item.make(&"dagger").is_throwable())
	check("so can a short sword", Item.make(&"short_sword").is_throwable())
	check("but not a bow", not Item.make(&"short_bow").is_throwable())
	check("nor armour", not Item.make(&"chain_mail").is_throwable())
	check("nor a potion", not Item.make(&"potion_healing").is_throwable())
	check("light things fly further than heavy ones",
		Item.make(&"dagger").throw_range > Item.make(&"war_axe").throw_range)

	var gs := _arena(31, 11)
	gs.player.x = 4
	gs.player.y = 5
	gs.player.max_hp = 9999
	gs.player.hp = 9999
	gs.player.power = 10
	gs.map.set_all_visible()

	var mark := _spawn(gs, "goblin", 8, 5)
	mark.max_hp = 500
	mark.hp = 500

	var blade := Item.make(&"dagger")
	gs.give_item(blade)
	check("the pack offers it", gs.throwables().size() == 1)

	# Out of reach, and behind cover, both refused.
	check("beyond its reach is refused", not gs.player_throw(0, Vector2i(25, 5)))
	gs.map.set_tile(6, 5, Tiles.PILLAR)
	check("cover refuses it too", not gs.player_throw(0, Vector2i(8, 5)))
	gs.map.set_tile(6, 5, Tiles.FLOOR)
	check("empty floor is refused", not gs.player_throw(0, Vector2i(7, 5)))
	check("and none of that cost the dagger", gs.player.inventory.size() == 1)

	var hp_before := mark.hp
	check("the throw lands", gs.player_throw(0, Vector2i(8, 5)))
	check("it wounds the target", mark.hp < hp_before)
	check("the dagger leaves the pack", gs.player.inventory.is_empty())
	check("and lands at the target's feet",
		gs.items_at(8, 5).size() == 1 and gs.items_at(8, 5)[0] == blade)
	check("so it can be recovered", blade.letter == "")

	# Reach should not be free twice: a thrown blade is weaker than a bow shot.
	var thrown := blade.power_bonus + int(gs.player.power / 2)
	var bow := Item.make(&"short_bow")
	gs.player.equipped[Item.Slot.WEAPON] = bow
	check("a thrown dagger hits softer than a bow (%d vs %d)"
		% [thrown, gs.player.total_power()], thrown < gs.player.total_power())

	# Throwing what you are holding works, and disarms you.
	#
	# Aimed at where the goblin actually is, not where it started: a world turn
	# has passed since the first throw and it may well have walked. Hardcoding
	# the cell made this test depend on a coin flip in the pack AI.
	var spare := Item.make(&"dagger")
	gs.give_item(spare)
	gs.player.equipped[Item.Slot.WEAPON] = spare
	check("you may hurl your own weapon",
		gs.player_throw(gs.player.inventory.find(spare), Vector2i(mark.x, mark.y)))
	check("which leaves you holding nothing",
		not gs.player.equipped.has(Item.Slot.WEAPON))

## An archer must fear being adjacent, or peek-and-duck has no stakes.
func _test_launchers_are_poor_clubs() -> void:
	var gs := _arena(21, 9)
	gs.player.x = 5
	gs.player.y = 4
	gs.player.power = 12
	gs.player.max_hp = 9999
	gs.player.hp = 9999
	gs.map.set_all_visible()

	var dummy := _spawn(gs, "goblin", 6, 4)
	dummy.max_hp = 100000
	dummy.hp = 100000
	dummy.defense = 0

	# Baseline: a proper weapon in hand.
	gs.player.equipped[Item.Slot.WEAPON] = Item.make(&"short_sword")
	var with_sword := 0
	for _i in 40:
		var b := dummy.hp
		gs._attack(gs.player, dummy)
		with_sword = maxi(with_sword, b - dummy.hp)

	gs.player.equipped[Item.Slot.WEAPON] = Item.make(&"short_bow")
	var with_bow := 0
	for _i in 40:
		var b := dummy.hp
		gs._attack(gs.player, dummy)
		with_bow = maxi(with_bow, b - dummy.hp)

	check("clubbing with a bow is far worse than a sword (%d vs %d)"
		% [with_bow, with_sword], with_bow * 2 < with_sword)

	# But shooting with it is not penalised.
	var shot := 0
	for _i in 40:
		var b := dummy.hp
		gs._attack(gs.player, dummy, true)
		shot = maxi(shot, b - dummy.hp)
	# Not compared against the sword: a launcher is meant to hit slightly
	# softer than melee, since it buys reach. The point is only that firing it
	# carries no clumsiness penalty.
	check("shooting the same bow carries no penalty (%d vs %d clubbing)"
		% [shot, with_bow], shot > with_bow * 2)
	check("and still lands a little under a sword (%d vs %d)"
		% [shot, with_sword], shot < with_sword)

	# And a thrown weapon is not treated as a clumsy swing either.
	var hurled := 0
	for _i in 20:
		var b := dummy.hp
		gs._attack(gs.player, dummy, true, 8)
		hurled = maxi(hurled, b - dummy.hp)
	check("an explicit throw keeps its own power", hurled > with_bow)

func _suspended_state() -> GameState:
	var gs := GameState.new(5150)
	gs.new_game()
	gs.depth = 4
	gs.build_level()
	gs.torch_lit = false
	gs.award_xp(500)
	gs.give_item(Item.make(&"war_axe"))
	gs.give_item(Item.make(&"chain_mail"))
	gs.player.equipped[Item.Slot.WEAPON] = gs.player.inventory[0]
	gs.player.equipped[Item.Slot.ARMOR] = gs.player.inventory[1]
	gs.player.hp = 17
	gs.update_vision()
	return gs

func _test_suspend_round_trip() -> void:
	var gs := _suspended_state()
	var back := GameState.new(1)
	check("a save restores at all", back.apply_dict(gs.to_dict()))

	check("depth survives", back.depth == gs.depth)
	check("the torch state survives", back.torch_lit == gs.torch_lit)
	check("level and experience survive",
		back.player.xp == gs.player.xp and back.player.level == gs.player.level)
	check("hit points survive", back.player.hp == gs.player.hp)
	check("the map survives", back.map.tiles == gs.map.tiles)
	check("room materials survive", back.map.material == gs.map.material)
	check("what was explored survives", back.map.explored == gs.map.explored)
	check("the monster roster survives",
		back.entities.size() == gs.entities.size(), "%d vs %d"
			% [back.entities.size(), gs.entities.size()])
	check("ground loot survives", back.ground.size() == gs.ground.size())
	check("brazier charges survive",
		back.brazier_charge.size() == gs.brazier_charge.size())
	check("equipment survives", back.player.equipped.size() == 2)
	check("and so does what it adds up to",
		back.player.total_power() == gs.player.total_power()
			and back.player.total_defense() == gs.player.total_defense())

	# The pack and the worn slots hold the SAME objects. Writing them out twice
	# would restore a character wearing a copy of their own armour, and
	# dropping it would leave a duplicate behind.
	check("worn gear is the pack's own object",
		back.player.inventory.has(back.player.equipped[Item.Slot.WEAPON]))

	# Stored as a string for exactly this reason: as a JSON number the low bits
	# of a 64-bit state are lost and the resumed run diverges.
	check("the rng resumes exactly where it stopped",
		back.rng.state == gs.rng.state, "%d vs %d" % [back.rng.state, gs.rng.state])

	# Monster awareness has to survive, or suspending would be a free reset on
	# everything that had noticed you.
	var awake_before := 0
	var awake_after := 0
	for e in gs.entities:
		if e.alertness == Entity.Alert.AWAKE:
			awake_before += 1
	for e in back.entities:
		if e.alertness == Entity.Alert.AWAKE:
			awake_after += 1
	check("who had noticed you survives", awake_before == awake_after)

func _test_suspend_slot_is_destroyed_on_load() -> void:
	GameState.clear_suspend()
	check("no slot to begin with", not GameState.has_suspend())

	var gs := _suspended_state()
	check("saving writes one", gs.save_suspend())
	check("the slot is there", GameState.has_suspend())

	var resumed := GameState.load_suspend()
	check("it resumes", resumed != null)
	check("resuming destroys the slot", not GameState.has_suspend())
	check("so there is nothing to load a second time",
		GameState.load_suspend() == null)
	check("and the resumed run is the one that was saved",
		resumed != null and resumed.depth == gs.depth
			and resumed.player.hp == gs.player.hp)
	GameState.clear_suspend()

func _test_morgue_line() -> void:
	var gs := _suspended_state()
	gs.death_cause = "killed by a wyvern"
	var line := gs.morgue_line()
	check("the morgue names what killed you", line.contains("wyvern"))
	check("and where", line.contains("depth 4"))
	check("and says you had no amulet", line.contains("empty-handed"))

	gs.give_item(Item.make(&"amulet"))
	gs.won = true
	var victory := gs.morgue_line()
	check("a win reads as an escape", victory.contains("escaped"))
	check("and records the amulet", victory.contains("with the Amulet"))

func _shrine_arena(kind: int) -> GameState:
	var gs := _arena(31, 13)
	gs.player.x = 8
	gs.player.y = 6
	gs.player.max_hp = 60
	gs.player.hp = 30
	gs.map.set_tile(8, 6, Tiles.SHRINE)
	gs.shrine_at = {Vector2i(8, 6): kind}
	gs.map.set_all_visible()
	return gs

func _test_shrines_appear() -> void:
	var with_shrine := 0
	var total := 0
	for i in 40:
		var gs := GameState.new(77000 + i)
		gs.new_game()
		if gs.shrine_at.size() > 0:
			with_shrine += 1
		total += gs.shrine_at.size()
	check("most floors hold a shrine (%d/40)" % with_shrine, with_shrine >= 36,
		"%d" % with_shrine)
	check("one or two of them, not a dozen (%.1f avg)" % (float(total) / 40.0),
		float(total) / 40.0 <= 2.5, "%.2f" % (float(total) / 40.0))
	check("a shrine can be stood on", Tiles.is_walkable(Tiles.SHRINE))

func _test_shrine_effects() -> void:
	# Quiet puts the floor to sleep.
	var quiet := _shrine_arena(Shrines.QUIET)
	var sleeper := _spawn(quiet, "orc", 12, 6)
	sleeper.alertness = Entity.Alert.AWAKE
	check("praying works", quiet.player_pray())
	check("the quiet sends them back to sleep",
		sleeper.alertness == Entity.Alert.ASLEEP,
		"alertness %d" % sleeper.alertness)
	# And keeps them there long enough to matter, even standing lit beside one.
	for _i in 5:
		quiet.player_wait()
	check("and they stay asleep for a while",
		sleeper.alertness == Entity.Alert.ASLEEP,
		"alertness %d after 5 turns" % sleeper.alertness)
	check("and the shrine is spent",
		quiet.map.get_tile(8, 6) != Tiles.SHRINE and quiet.shrine_at.is_empty())
	check("praying at nothing is refused", not quiet.player_pray())
	# But the hush does run out.
	for _i in GameState.QUIET_TURNS + 6:
		quiet.player_wait()
	check("the hush eventually lifts",
		sleeper.alertness != Entity.Alert.ASLEEP,
		"alertness %d" % sleeper.alertness)

	# Vigil is the opposite.
	var vigil := _shrine_arena(Shrines.VIGIL)
	var dozing := _spawn(vigil, "orc", 12, 6)
	dozing.alertness = Entity.Alert.ASLEEP
	vigil.player_pray()
	check("the vigil wakes the floor", dozing.alertness == Entity.Alert.AWAKE)

	# Embers rekindles dead braziers.
	var embers := _shrine_arena(Shrines.EMBERS)
	embers.map.set_tile(11, 6, Tiles.BRAZIER_SPENT)
	embers.player_pray()
	check("embers relights spent braziers",
		embers.map.get_tile(11, 6) == Tiles.BRAZIER)
	check("at a reduced charge",
		int(embers.brazier_charge[Vector2i(11, 6)]) < GameState.BRAZIER_CHARGE)

	# The anvil raises the forging ceiling for the rest of the run.
	var anvil := _shrine_arena(Shrines.ANVIL)
	var cap_before := anvil.upgrade_cap()
	anvil.player_pray()
	check("the anvil raises the forging cap",
		anvil.upgrade_cap() == cap_before + 1)
	var blade := Item.make(&"dagger")
	blade.upgrade()
	blade.upgrade()
	check("a maxed blade could not be improved before",
		not blade.can_upgrade())
	check("but the anvil lets it take one more",
		anvil.item_can_upgrade(blade))

	# The weight blesses gear and slows you until the next floor.
	var weight := _shrine_arena(Shrines.WEIGHT)
	var kit := Item.make(&"short_sword")
	weight.give_item(kit)
	weight.player.equipped[Item.Slot.WEAPON] = kit
	var edge := kit.power_bonus
	weight.player_pray()
	check("the weight blesses what you carry", kit.power_bonus == edge + 1)
	check("and slows you", weight.player.speed == GameState.WEIGHT_SPEED)
	weight.depth = 2
	weight.build_level()
	check("but not past the stairs", weight.player.speed == GameState.BASE_SPEED)

	# Mending closes everything.
	var mend := _shrine_arena(Shrines.MENDING)
	mend.player_pray()
	check("mending heals in full", mend.player.hp == mend.player.max_hp)

	# Summons brings company, awake.
	var call := _shrine_arena(Shrines.SUMMONS)
	var before := call.entities.size()
	call.player_pray()
	check("summons brings something through", call.entities.size() > before,
		"%d -> %d" % [before, call.entities.size()])
	var all_awake := true
	for i in range(before, call.entities.size()):
		if call.entities[i].alertness != Entity.Alert.AWAKE:
			all_awake = false
	check("and it arrives already looking for you", all_awake)

func _test_shrine_identity_is_shuffled() -> void:
	# Same seed, same secret. Different seed, usually a different one.
	var a := GameState.new(4242)
	a.new_game()
	var b := GameState.new(4242)
	b.new_game()
	check("a seeded run hides the same effect behind the same colour",
		a.shrine_hues == b.shrine_hues)

	var differ := 0
	for i in 20:
		var other := GameState.new(60000 + i)
		other.new_game()
		if other.shrine_hues != a.shrine_hues:
			differ += 1
	check("but other runs shuffle it (%d/20 differ)" % differ, differ >= 18)

	var gs := _shrine_arena(Shrines.QUIET)
	gs._shuffle_shrines()
	check("an unused shrine is unnamed",
		gs.shrine_label(Shrines.QUIET) == "an unfamiliar shrine")
	gs.player_pray()
	check("using one teaches you its colour",
		gs.shrine_label(Shrines.QUIET) == Shrines.NAMES[Shrines.QUIET])

func _test_torch_flare() -> void:
	var gs := _shrine_arena(Shrines.FLARE)
	gs.torch_lit = false
	gs.player_pray()
	check("the flare lights the torch", gs.torch_lit)
	check("and burns for a while", gs.torch_flare > 0)
	check("it cannot be smothered", not gs.player_toggle_torch())
	check("still burning after the attempt", gs.torch_lit)

	var lit_radius := 0
	for i in gs.map.visible_now.size():
		if gs.map.visible_now[i] != 0:
			lit_radius += 1

	# Run it out.
	for _i in GameState.FLARE_TURNS + 2:
		gs.player_wait()
	check("the flare burns out", gs.torch_flare == 0)
	check("and the torch can be smothered again", gs.player_toggle_torch())

	var normal := 0
	for i in gs.map.visible_now.size():
		if gs.map.visible_now[i] != 0:
			normal += 1
	check("a flare shows far more than an ordinary torch (%d vs %d)"
		% [lit_radius, normal], lit_radius > normal)

func _test_difficult_ground() -> void:
	check("dry floor is a normal stride", Tiles.move_cost(Tiles.FLOOR) == 1.0)
	check("water is slower than dry", Tiles.move_cost(Tiles.WATER) > 1.0)
	check("mud is slower than water",
		Tiles.move_cost(Tiles.MUD) > Tiles.move_cost(Tiles.WATER))
	check("rubble slows you a little", Tiles.move_cost(Tiles.RUBBLE) > 1.0)
	check("all of it is still walkable",
		Tiles.is_walkable(Tiles.MUD) and Tiles.is_walkable(Tiles.WATER)
			and Tiles.is_walkable(Tiles.RUBBLE))
	check("and none of it blocks sight",
		Tiles.is_transparent(Tiles.MUD) and Tiles.is_transparent(Tiles.WATER))

	var gs := _arena(21, 9)
	gs.player.x = 5
	gs.player.y = 4
	gs.map.set_tile(6, 4, Tiles.MUD)
	gs.map.set_tile(7, 4, Tiles.WATER)

	var dry := gs.move_cost_for(gs.player, 5, 5)
	var wet := gs.move_cost_for(gs.player, 7, 4)
	var deep := gs.move_cost_for(gs.player, 6, 4)
	check("wading costs more than walking (%d vs %d)" % [wet, dry], wet > dry)
	check("mud costs more than water (%d vs %d)" % [deep, wet], deep > wet)

	# A flyer never touches it.
	var bat := _spawn(gs, "cave bat", 10, 4)
	check("a bat is flying", bat.flying)
	check("and difficult ground costs it nothing",
		gs.move_cost_for(bat, 6, 4) == Scheduler.ACTION_COST)

	# Something heavy sinks. This is what makes mud a tool and not only a
	# hazard: retreat across it and the ogre falls behind while you do not.
	var ogre := _spawn(gs, "ogre", 12, 4)
	check("an ogre is heavy", ogre.heavy)
	check("and it suffers worse in mud than you do (%d vs %d)"
		% [gs.move_cost_for(ogre, 6, 4), deep],
		gs.move_cost_for(ogre, 6, 4) > deep)
	check("but not on dry ground",
		gs.move_cost_for(ogre, 5, 5) == gs.move_cost_for(gs.player, 5, 5))

	# The terrain pass actually lays some down.
	var wet_floors := 0
	var muddy := 0
	for i in 40:
		var level := GameState.new(88000 + i)
		level.new_game()
		for y in level.map.height:
			for x in level.map.width:
				var t := level.map.get_tile(x, y)
				if t == Tiles.WATER:
					wet_floors += 1
				elif t == Tiles.MUD:
					muddy += 1
	check("levels have water on them (%d cells / 40)" % wet_floors, wet_floors > 0)
	check("and mud (%d cells / 40)" % muddy, muddy > 0)

## Noise is the second thing that can give you away. Until now the awareness
## system had exactly one input: light.
func _test_bones_are_loud() -> void:
	var gs := _arena(31, 13)
	gs.player.x = 5
	gs.player.y = 6
	gs.torch_lit = false
	gs.map.set_tile(6, 6, Tiles.BONES)
	gs.update_vision()

	var near := _spawn(gs, "orc", 11, 6)
	var far := _spawn(gs, "orc", 25, 11)
	near.alertness = Entity.Alert.ASLEEP
	far.alertness = Entity.Alert.ASLEEP

	check("bones cost a little extra to cross", Tiles.move_cost(Tiles.BONES) > 1.0)
	check("and they are loud", Tiles.noise_radius(Tiles.BONES) > 0)
	check("plain floor is quiet", Tiles.noise_radius(Tiles.FLOOR) == 0)

	gs.player_move(1, 0)
	check("crossing bones wakes what is near",
		near.alertness == Entity.Alert.AWAKE)
	check("but not what is across the level",
		far.alertness == Entity.Alert.ASLEEP)

	# Noise goes through stone: it is not line of sight.
	var walled := _arena(31, 13)
	walled.player.x = 5
	walled.player.y = 6
	walled.map.set_tile(6, 6, Tiles.BONES)
	for y in range(1, 12):
		walled.map.set_tile(9, y, Tiles.WALL)
	walled.pathfinder = Pathfinder.new(walled.map)
	var hidden := _spawn(walled, "orc", 11, 6)
	hidden.alertness = Entity.Alert.ASLEEP
	walled.update_vision()
	walled.player_move(1, 0)
	check("noise carries through a wall", hidden.alertness == Entity.Alert.AWAKE)

func _test_pits() -> void:
	check("a pit can be stepped into", Tiles.is_walkable(Tiles.PIT))
	check("but is never routed through", Tiles.is_avoided(Tiles.PIT))

	var gs := _arena(31, 13)
	gs.player.x = 5
	gs.player.y = 6
	gs.player.max_hp = 200
	gs.player.hp = 200
	gs.map.set_tile(6, 6, Tiles.PIT)
	gs.pathfinder = Pathfinder.new(gs.map)

	# Travel must go around, not down.
	gs.map.reveal_all()
	var route := gs.pathfinder.path(Vector2i(5, 6), Vector2i(8, 6))
	check("a route around a pit exists", not route.is_empty())
	check("and it does not pass through it",
		not route.has(Vector2i(6, 6)), str(route))

	var depth_before := gs.depth
	var hp_before := gs.player.hp
	check("stepping in works", gs.player_move(1, 0))
	check("it drops you a floor", gs.depth == depth_before + 1)
	check("and it hurts", gs.player.hp < hp_before)
	check("you never land in another pit",
		gs.map.get_tile(gs.player.x, gs.player.y) != Tiles.PIT)

	# No pits on the bottom floor, and none on the way out.
	var bottom := GameState.new(3300)
	bottom.new_game()
	bottom.depth = GameState.MAX_DEPTH
	bottom.build_level()
	var holes := 0
	for y in bottom.map.height:
		for x in bottom.map.width:
			if bottom.map.get_tile(x, y) == Tiles.PIT:
				holes += 1
	check("the bottom floor has no pits", holes == 0, "%d" % holes)

func _test_fungus_glows() -> void:
	check("fungus is luminous", Tiles.is_luminous(Tiles.FUNGUS))
	check("and can be walked over", Tiles.is_walkable(Tiles.FUNGUS))

	var gs := _arena(21, 9)
	gs.player.x = 3
	gs.player.y = 4
	gs.torch_lit = false
	gs.map.set_tile(14, 4, Tiles.FUNGUS)
	gs._gather_lights()
	check("a fungus patch is a light source", gs.static_lights.size() == 1)

	gs.update_vision()
	var lit: Color = gs.light_map.get_light(14, 4)
	var dark: Color = gs.light_map.get_light(19, 8)
	check("it lights its own cell", lit.get_luminance() > dark.get_luminance())
	check("but only faintly", lit.get_luminance() < 0.6,
		"%.2f" % lit.get_luminance())

func _test_projectile_path() -> void:
	var line := Los.path(2, 2, 6, 2)
	check("a path excludes the origin", not line.has(Vector2i(2, 2)))
	check("a path ends on the target", line.back() == Vector2i(6, 2))
	check("a four-cell shot crosses four cells", line.size() == 4)
	check("a diagonal path counts three, not six", Los.path(0, 0, 3, 3).size() == 3)
	check("a zero-length path is empty", Los.path(5, 5, 5, 5).is_empty())

## The renderer animates from these. The simulation must never wait on them.
func _test_combat_events_are_recorded() -> void:
	var gs := _arena(21, 9)
	gs.player.x = 3
	gs.player.y = 4
	gs.take_events()

	var kobold := _spawn(gs, "kobold", 4, 4)
	gs._attack(kobold, gs.player)
	var evts := gs.take_events()
	check("a melee hit records one event", evts.size() == 1, str(evts.size()))
	check("it is tagged melee", evts.size() > 0 and evts[0]["kind"] == &"melee")
	check("it is tagged as landing on the player",
		evts.size() > 0 and evts[0]["on_player"])
	check("it carries the damage dealt", evts.size() > 0 and evts[0]["amount"] > 0)
	check("take_events drains the queue", gs.take_events().is_empty())

	var archer := _spawn(gs, "kobold slinger", 9, 4)
	gs._attack(archer, gs.player, true)
	var shots := gs.take_events()
	check("a shot is tagged ranged", shots.size() == 1 and shots[0]["kind"] == &"ranged")
	check("a shot records where it was fired from",
		shots.size() > 0 and shots[0]["from"] == Vector2i(9, 4))

func _test_damage_cancels_travel() -> void:
	var gs := _arena(25, 11)
	gs.player.x = 3
	gs.player.y = 5
	# Parked far away so it does not stop travel merely by being seen.
	var rat := _spawn(gs, "giant rat", 21, 9)
	# The arena marks every cell visible for the AI tests; recompute real field
	# of view here so the rat is genuinely out of sight.
	gs.update_vision()
	gs.map.reveal_all()

	check("auto-travel starts", gs.begin_travel(Vector2i(20, 5)))
	if gs.travelling():
		gs._attack(rat, gs.player)
		check("taking damage stops auto-travel", not gs.travelling())
	else:
		check("taking damage stops auto-travel", false, "travel ended early")

func _test_line_of_sight() -> void:
	var m := DungeonMap.new(15, 5)
	for y in 5:
		for x in 15:
			m.set_tile(x, y, Tiles.FLOOR)
	check("clear line across open floor", Los.clear(m, 1, 2, 12, 2))

	m.set_tile(6, 2, Tiles.PILLAR)
	check("a pillar breaks the line", not Los.clear(m, 1, 2, 12, 2))
	check("a parallel line is unaffected", Los.clear(m, 1, 1, 12, 1))

	# A brazier is solid but see-through, so it must not stop an arrow.
	m.set_tile(6, 2, Tiles.BRAZIER)
	check("a brazier does not break the line", Los.clear(m, 1, 2, 12, 2))
	check("diagonals count as one step", Los.steps(0, 0, 3, 3) == 3)

func _test_ranged_attacks_from_afar() -> void:
	var gs := _arena(21, 9)
	gs.player.x = 3
	gs.player.y = 4
	var archer := _spawn(gs, "kobold slinger", 9, 4)
	var hp_before := gs.player.hp
	var where := Vector2i(archer.x, archer.y)
	gs._take_ai_turn(archer)
	check("an archer hurts you from six cells away", gs.player.hp < hp_before)
	check("and does not close the distance to do it",
		Vector2i(archer.x, archer.y) == where)

## The whole justification for the behaviour pass: cover now works.
func _test_a_pillar_stops_an_arrow() -> void:
	var gs := _arena(21, 9)
	gs.player.x = 3
	gs.player.y = 4
	gs.map.set_tile(6, 4, Tiles.PILLAR)
	gs.pathfinder = Pathfinder.new(gs.map)

	var archer := _spawn(gs, "kobold slinger", 9, 4)
	var hp_before := gs.player.hp
	gs._take_ai_turn(archer)
	check("a pillar stops the arrow", gs.player.hp == hp_before)
	check("the archer moves to regain its line",
		Vector2i(archer.x, archer.y) != Vector2i(9, 4))

func _test_wounded_monsters_flee() -> void:
	var gs := _arena(21, 9)
	gs.player.x = 5
	gs.player.y = 4
	var rat := _spawn(gs, "giant rat", 7, 4)
	rat.hp = 1
	var before := Los.steps(rat.x, rat.y, gs.player.x, gs.player.y)
	gs._take_ai_turn(rat)
	check("a badly wounded rat breaks", rat.fleeing)
	check("and it puts distance between you",
		Los.steps(rat.x, rat.y, gs.player.x, gs.player.y) > before)

	# A skeleton is mindless and must never run.
	var bones := _spawn(gs, "skeleton", 9, 4)
	bones.hp = 1
	gs._take_ai_turn(bones)
	check("undead never break", not bones.fleeing)

func _test_cornered_monsters_fight() -> void:
	var gs := _arena(5, 5)
	gs.player.x = 2
	gs.player.y = 2
	var rat := _spawn(gs, "giant rat", 1, 1)
	rat.hp = 1
	var hp_before := gs.player.hp
	gs._take_ai_turn(rat)
	check("a cornered animal fights instead of cowering", gs.player.hp < hp_before)

func _test_erratic_is_not_a_beeline() -> void:
	var gs := _arena(25, 11)
	gs.player.x = 3
	gs.player.y = 5
	var closed := 0
	var trials := 60
	for _i in trials:
		var bat := _spawn(gs, "cave bat", 12, 5)
		var before := Los.steps(bat.x, bat.y, gs.player.x, gs.player.y)
		gs._take_ai_turn(bat)
		if Los.steps(bat.x, bat.y, gs.player.x, gs.player.y) < before:
			closed += 1
		gs.entities.erase(bat)
	check("a bat approaches sometimes but never reliably (%d/%d)" % [closed, trials],
		closed > 5 and closed < trials - 5, "%d" % closed)

func _test_goblins_are_bolder_together() -> void:
	var trials := 50
	var lone := 0
	var together := 0

	var gs := _arena(25, 11)
	gs.player.x = 4
	gs.player.y = 5
	for _i in trials:
		var g := _spawn(gs, "goblin", 12, 5)
		var before := Vector2i(g.x, g.y)
		gs._take_ai_turn(g)
		if Vector2i(g.x, g.y) != before:
			lone += 1
		gs.entities.erase(g)

	for _i in trials:
		var g := _spawn(gs, "goblin", 12, 5)
		var mate := _spawn(gs, "goblin", 13, 7)
		var before := Vector2i(g.x, g.y)
		gs._take_ai_turn(g)
		if Vector2i(g.x, g.y) != before:
			together += 1
		gs.entities.erase(g)
		gs.entities.erase(mate)

	check("a lone goblin often hangs back (%d/%d advanced)" % [lone, trials],
		lone < trials - 5, "%d" % lone)
	check("goblins with company always advance (%d/%d)" % [together, trials],
		together == trials, "%d" % together)

func _test_terrain_properties() -> void:
	check("pillars block movement", not Tiles.is_walkable(Tiles.PILLAR))
	check("pillars block sight", not Tiles.is_transparent(Tiles.PILLAR))
	check("natural rock is solid", not Tiles.is_walkable(Tiles.ROCK))
	check("water can be waded", Tiles.is_walkable(Tiles.WATER))
	check("rubble can be walked over", Tiles.is_walkable(Tiles.RUBBLE))

## The whole point of a pillar: it breaks line of sight, so a room with a
## colonnade offers cover instead of being an open killing floor.
func _test_pillar_casts_a_shadow() -> void:
	var m := DungeonMap.new(21, 5)
	for y in 5:
		for x in 21:
			m.set_tile(x, y, Tiles.FLOOR)
	m.set_tile(10, 2, Tiles.PILLAR)

	var buf := PackedByteArray()
	buf.resize(21 * 5)
	Fov.compute(m, 2, 2, 15, buf)
	check("pillar itself is seen", buf[m.idx(10, 2)] == 1)
	check("pillar hides what stands behind it", buf[m.idx(14, 2)] == 0)
	check("you can still see past it on another row", buf[m.idx(14, 1)] == 1)

## Decoration can now paint pillars, water and braziers into rooms, so the
## spots the player and the stairs land on are no longer trivially safe.
func _test_spawn_points_are_open() -> void:
	var bad_start := 0
	var bad_stairs := 0
	var trials := 200
	for i in trials:
		var gs := GameState.new(6000 + i)
		gs.new_game()
		if not gs.map.is_walkable(gs.player.x, gs.player.y):
			bad_start += 1
		if not gs.map.is_walkable(gs.stairs.x, gs.stairs.y):
			bad_stairs += 1
	check("player never starts inside solid terrain (%d seeds)" % trials,
		bad_start == 0, "%d bad" % bad_start)
	check("stairs always sit on open ground", bad_stairs == 0, "%d bad" % bad_stairs)

func _test_caves_are_reachable() -> void:
	var seen := 0
	var unreachable := 0
	for i in 120:
		var gs := GameState.new(7000 + i)
		gs.new_game()
		for region in gs.cave_regions:
			var target := Vector2i(-1, -1)
			for y in range(region.position.y, region.end.y):
				for x in range(region.position.x, region.end.x):
					if gs.map.get_tile(x, y) == Tiles.CAVE_FLOOR:
						target = Vector2i(x, y)
						break
				if target.x >= 0:
					break
			if target.x < 0:
				continue
			seen += 1
			if gs.pathfinder.path(Vector2i(gs.player.x, gs.player.y), target).is_empty():
				unreachable += 1
	check("caves actually generate", seen > 0, "%d found" % seen)
	check("every cave is reachable (%d checked)" % seen, unreachable == 0,
		"%d unreachable" % unreachable)

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
	# player" by testing the player's own field of view, which is only fair if
	# the two agree. Perfect symmetry is not achievable with shadowcasting, so
	# this asserts the practical property -- overwhelming agreement.
	#
	# Sampled across several levels rather than one. A single level offers only
	# a few dozen cells, which is far too small to hold a 97% threshold steady:
	# two awkward corners in one room would fail it on nothing but luck.
	var checked := 0
	var mismatch := 0
	for run in 6:
		var gs := GameState.new(4242 + run * 17)
		gs.new_game()
		var a := PackedByteArray()
		a.resize(gs.map.width * gs.map.height)
		var b := PackedByteArray()
		b.resize(gs.map.width * gs.map.height)
		Fov.compute(gs.map, gs.player.x, gs.player.y, 8, a)

		for y in gs.map.height:
			for x in gs.map.width:
				if a[gs.map.idx(x, y)] == 0 or not gs.map.is_walkable(x, y):
					continue
				Fov.compute(gs.map, x, y, 8, b)
				checked += 1
				if b[gs.map.idx(gs.player.x, gs.player.y)] == 0:
					mismatch += 1

	var rate := 1.0 - float(mismatch) / maxf(1.0, float(checked))
	check("fov is near-symmetric (%.1f%% of %d cells across 6 levels)"
		% [rate * 100.0, checked], rate > 0.97, "%d mismatches" % mismatch)

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
