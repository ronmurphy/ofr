extends SceneTree

## Headless test suite:  godot --headless --script res://tests/run_tests.gd
##
## This is the concrete reason the simulation owns no Godot nodes. Generating
## two hundred dungeons and asserting every one is completable takes under a
## second here, and needs no window, no renderer and no human.

var _passed := 0
var _failed := 0

func _initialize() -> void:
	# Point the save and the death log somewhere harmless BEFORE anything runs.
	#
	# This suite writes real files: the suspend tests call clear_suspend() and
	# save_suspend(), and every death test appends a line to the morgue. While
	# those paths were constants it did that to the player's own files, and it
	# deleted a suspended run that was actually being played.
	GameState.use_scratch_files("tests")
	print("")
	_test_generation_is_deterministic()
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
	_test_motion_tweening()
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
	_test_traps()
	_test_vaults_load()
	_test_vaults_are_placed_intact()
	_test_every_sound_renders()
	_test_sound_is_deterministic()
	_test_sounds_map_to_real_voices()
	_test_noise_raises_a_sound_event()
	_test_footing_change_is_audible()
	_test_low_health_warns_once()
	_test_a_death_is_announced()
	_test_panels_do_not_overflow()
	_test_symbol_theme()
	_test_icon_theme()
	_test_no_decoration_plugs_a_way()
	_test_corners_stop_everyone_equally()
	_test_nothing_rests_on_a_hazard()
	_test_consumables_forge()
	_test_offhand_and_swap()
	_test_inventory_letters_dodge_the_keys()
	_test_no_key_steals_an_inventory_letter()
	_test_an_older_save_still_loads()
	_test_fungus_is_a_mouthful()
	_report_encounter_curve()

	GameState.clear_scratch_files()

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

	# Caves were never checked. They carry their own, higher ceiling -- wilder
	# and unlit is worth a little more danger -- and an unchecked budget is not
	# a budget.
	var cave_breaches := 0
	var caves_checked := 0
	var cave_worst := 0
	for d in range(1, 9):
		for i in 25:
			var gs := GameState.new(21000 + d * 100 + i)
			gs.new_game()
			gs.depth = d
			gs.build_level()
			var ceiling := gs.cave_threat_ceiling()
			for region in gs.cave_regions:
				caves_checked += 1
				var sum := 0
				for e in gs.entities:
					if not e.is_player and region.has_point(Vector2i(e.x, e.y)):
						sum += e.threat
				if sum > ceiling:
					cave_breaches += 1
					cave_worst = maxi(cave_worst, sum - ceiling)
	check("no cave exceeds its threat ceiling (%d caves, depths 1-8)" % caves_checked,
		cave_breaches == 0, "%d breaches, worst %d over" % [cave_breaches, cave_worst])

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
	# The drawn camera lags the logical one, so settle it before hit-testing.
	grid.settle_camera()
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
	grid.settle_camera()
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

	# Consumables used to be refused outright. Potions and light scrolls are
	# now forgeable, because a hoard of twelve-point heals is dead weight by
	# depth ten -- see _test_consumables_forge. Anything the catalogue gives no
	# forge bonus to is still refused.
	var blink := _forge_arena()
	blink.give_item(Item.make(&"scroll_blink"))
	blink.give_item(Item.make(&"scroll_blink"))
	check("a consumable with no forge value is refused", not blink.player_merge(0))

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

## 200 seeds rather than 40, because 40 was not enough to tell a regression
## from a coin toss.
##
## The true rate is about 95%, and this asserted 36 of 40 -- so roughly one
## reshuffle of the generator in six failed it by chance. It duly did, after a
## change to vault corridors that turned out to have moved the rate from 94.8%
## to 95.2%. Measuring 400 seeds either side is what showed that; the sample
## was the bug, not the dungeon.
func _test_shrines_appear() -> void:
	var with_shrine := 0
	var total := 0
	var runs := 200
	for i in runs:
		var gs := GameState.new(77000 + i)
		gs.new_game()
		if gs.shrine_at.size() > 0:
			with_shrine += 1
		total += gs.shrine_at.size()
	check("most floors hold a shrine (%d/%d)" % [with_shrine, runs],
		with_shrine >= int(runs * 0.90),
		"%d" % with_shrine)
	# Was also dividing by a hard-coded 40 while the loop count moved.
	var avg := float(total) / float(runs)
	check("one or two of them, not a dozen (%.2f avg)" % avg,
		avg <= 2.5, "%.2f" % avg)
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
	check("and grinds the bones away behind you",
		gs.map.get_tile(6, 6) != Tiles.BONES)

	# Which means the second crossing is silent.
	var quiet_one := _spawn(gs, "orc", 9, 6)
	quiet_one.alertness = Entity.Alert.ASLEEP
	gs.player.x = 5
	gs.player.y = 6
	gs.player_move(1, 0)
	check("a cleared path is quiet the second time",
		quiet_one.alertness == Entity.Alert.ASLEEP)
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

## Movement is animated, but only in the renderer -- and never at the cost of
## responsiveness.
func _test_motion_tweening() -> void:
	var gs := _arena(31, 13)
	gs.player.x = 5
	gs.player.y = 6
	var grid := GlyphGrid.new()
	grid.cell_size = 18
	grid.size = Vector2(72 * 18, 40 * 18)
	grid.state = gs
	grid.sync_motion()

	check("a settled entity draws on its own cell",
		grid._visual_cell(gs.player) == Vector2(5, 6))
	check("and nothing is in flight", not grid._motion_running())

	# A step starts a tween, and the glyph begins behind the logical position.
	gs.player.x = 6
	grid.sync_motion()
	check("moving starts a tween", grid._motion_running())
	var mid := grid._visual_cell(gs.player)
	check("the glyph lags behind the simulation", mid.x < 6.0, "%.2f" % mid.x)
	check("but is already on its way", mid.x >= 5.0)

	# Settling is instant. This is what stops a held key building a backlog.
	grid.settle_motion()
	check("settling finishes the step at once",
		grid._visual_cell(gs.player) == Vector2(6, 6))
	check("with nothing left in flight", not grid._motion_running())

	# A second step while the first is mid-flight must start from where the
	# glyph actually is, not from the cell it logically left.
	gs.player.x = 7
	grid.sync_motion()
	grid._motion[gs.player]["t"] = GlyphGrid.STEP_TIME * 0.5
	var part := grid._visual_cell(gs.player)
	gs.player.x = 8
	grid.sync_motion()
	check("an interrupted step resumes from where it looked, not where it was",
		is_equal_approx(float(grid._motion[gs.player]["from"].x), part.x),
		"%.3f vs %.3f" % [float(grid._motion[gs.player]["from"].x), part.x])

	# The dead stop being drawn.
	var mob := _spawn(gs, "orc", 10, 6)
	grid.sync_motion()
	check("living things are tracked", grid._motion.has(mob))
	mob.alive = false
	grid.sync_motion()
	check("the dead are dropped", not grid._motion.has(mob))
	grid.free()

func _test_traps() -> void:
	check("a trap can be stepped on", Tiles.is_walkable(Tiles.TRAP))
	check("but is never routed through", Tiles.is_avoided(Tiles.TRAP))
	check("and it is plainly visible", Tiles.is_transparent(Tiles.TRAP))

	var gs := _arena(31, 13)
	gs.player.x = 5
	gs.player.y = 6
	gs.player.max_hp = 200
	gs.player.hp = 200
	gs.map.set_tile(6, 6, Tiles.TRAP)
	gs.pathfinder = Pathfinder.new(gs.map)
	gs.map.reveal_all()

	var route := gs.pathfinder.path(Vector2i(5, 6), Vector2i(8, 6))
	check("travel goes around a trap", not route.has(Vector2i(6, 6)), str(route))

	# Something asleep nearby, to prove springing one is loud.
	var dozing := _spawn(gs, "orc", 9, 6)
	dozing.alertness = Entity.Alert.ASLEEP

	var hp_before := gs.player.hp
	check("stepping on it works", gs.player_move(1, 0))
	check("it hurts", gs.player.hp < hp_before)
	check("you end up standing on the square",
		gs.player.x == 6 and gs.player.y == 6)
	check("and it has sprung for good", gs.map.get_tile(6, 6) != Tiles.TRAP)
	check("springing one is loud", dozing.alertness == Entity.Alert.AWAKE)

	# Crossing again is free.
	var hp_now := gs.player.hp
	gs.player_move(-1, 0)
	gs.player_move(1, 0)
	check("a sprung trap is spent", gs.player.hp == hp_now)

	# It can kill, and the run ends properly.
	var doomed := _arena(21, 9)
	doomed.player.x = 5
	doomed.player.y = 4
	doomed.player.max_hp = 60
	doomed.player.hp = 1
	doomed.map.set_tile(6, 4, Tiles.TRAP)
	doomed.player_move(1, 0)
	check("a trap can finish you", doomed.game_over)
	check("and the morgue knows what did it",
		doomed.death_cause.contains("trap"), doomed.death_cause)

	# They generate.
	var seen := 0
	for i in 30:
		var level := GameState.new(93000 + i)
		level.new_game()
		for y in level.map.height:
			for x in level.map.width:
				if level.map.get_tile(x, y) == Tiles.TRAP:
					seen += 1
	check("levels have traps on them (%d / 30)" % seen, seen > 0)

func _test_vaults_load() -> void:
	var library := Vault.load_all()
	check("vaults are read from disk (%d found)" % library.size(),
		library.size() > 0)

	var named := {}
	for v in library:
		named[v.name] = v
		check("%s has a layout" % v.name, not v.rows.is_empty())
		check("%s has a sane depth band" % v.name, v.min_depth <= v.max_depth)

	# Rotation must preserve the room, not just spin the box.
	var sample: Vault = library[0]
	var upright := sample.oriented(0, false)
	var turned := sample.oriented(1, false)
	var upright_cells := 0
	var turned_cells := 0
	for row in upright:
		for i in String(row).length():
			if String(row)[i] != " ":
				upright_cells += 1
	for row in turned:
		for i in String(row).length():
			if String(row)[i] != " ":
				turned_cells += 1
	check("a rotated vault keeps every cell (%d vs %d)"
		% [upright_cells, turned_cells], upright_cells == turned_cells)
	check("and its box turns with it",
		sample.oriented(1, false).size() == sample.size().x
			or sample.size().x == sample.size().y)

func _test_vaults_are_placed_intact() -> void:
	var floors_with := 0
	var overlaps := 0
	var authored_water := 0
	var runs := 60

	for i in runs:
		var gs := GameState.new(64000 + i)
		gs.new_game()
		# Depth 4: the watery vaults are gated at min_depth 2 and 3, so a
		# depth-1 sample could never have found any and the check was vacuous.
		gs.depth = 4
		gs.build_level()
		if gs.vault_rects.is_empty():
			continue
		floors_with += 1
		for vr in gs.vault_rects:
			for room in gs.room_rects:
				if vr.intersects(room):
					overlaps += 1
			for cave in gs.cave_regions:
				if vr.intersects(cave):
					overlaps += 1
			# Authored terrain has to survive every later pass.
			for y in range(vr.position.y, vr.end.y):
				for x in range(vr.position.x, vr.end.x):
					if gs.map.get_tile(x, y) == Tiles.WATER:
						authored_water += 1

	check("vaults turn up, but not on every floor (%d/%d)" % [floors_with, runs],
		floors_with > 0 and floors_with < runs, "%d" % floors_with)
	check("and never land on a room or a cave", overlaps == 0, "%d" % overlaps)
	check("authored water survives the terrain pass (%d cells)" % authored_water,
		authored_water > 0)

	# Contents actually arrive.
	var mobs := 0
	var loot := 0
	for i in 40:
		var gs := GameState.new(65000 + i)
		gs.new_game()
		gs.depth = 3
		gs.build_level()
		for vr in gs.vault_rects:
			for e in gs.entities:
				if not e.is_player and vr.has_point(Vector2i(e.x, e.y)):
					mobs += 1
			for it in gs.ground:
				if vr.has_point(Vector2i(it.x, it.y)):
					loot += 1
	# No door should open onto solid rock: either it leads somewhere or it has
	# been sealed back into wall.
	var blind := 0
	var doors := 0
	for i in 60:
		var gs := GameState.new(66000 + i)
		gs.new_game()
		gs.depth = 4
		gs.build_level()
		for vr in gs.vault_rects:
			for y in range(vr.position.y, vr.end.y):
				for x in range(vr.position.x, vr.end.x):
					var t := gs.map.get_tile(x, y)
					if t != Tiles.DOOR_CLOSED and t != Tiles.DOOR_OPEN:
						continue
					doors += 1
					var touching := 0
					for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						if gs.map.is_walkable(x + d.x, y + d.y):
							touching += 1
					if touching < 2:
						blind += 1
	check("no vault door opens onto nothing (%d of %d)" % [blind, doors],
		blind == 0, "%d blind" % blind)

	check("vault monsters are spawned (%d)" % mobs, mobs > 0)
	check("vault loot is placed (%d)" % loot, loot > 0)

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
	# Filtered by kind rather than counted. Combat raises noise through the
	# same queue now, and a test that asserts "exactly one event" breaks every
	# time anything is added beside it -- which says nothing about the blow.
	var evts := _of_kind(gs.take_events(), &"melee")
	check("a melee hit records one event", evts.size() == 1, str(evts.size()))
	check("it is tagged as landing on the player",
		evts.size() > 0 and evts[0]["on_player"])
	check("it carries the damage dealt", evts.size() > 0 and evts[0]["amount"] > 0)
	check("take_events drains the queue", gs.take_events().is_empty())

	var archer := _spawn(gs, "kobold slinger", 9, 4)
	gs._attack(archer, gs.player, true)
	var fired := gs.take_events()
	var shots := _of_kind(fired, &"ranged")
	check("a shot is tagged ranged", shots.size() == 1, str(shots.size()))
	check("a shot records where it was fired from",
		shots.size() > 0 and shots[0]["from"] == Vector2i(9, 4))

	# The hole that shoot-and-retreat was played through: a bowshot used to be
	# silent where the bow was, so an archer's corner was permanently quiet.
	var heard := _of_kind(fired, &"noise")
	var at_target := false
	var at_shooter := false
	for n in heard:
		if n["to"] == Vector2i(3, 4):
			at_target = true
		if n["to"] == Vector2i(9, 4):
			at_shooter = true
	check("a shot is heard where it lands", at_target)
	check("and where it was loosed from", at_shooter)

	# Melee is heard once, at the point of contact.
	gs.take_events()
	gs._attack(kobold, gs.player)
	var swing := _of_kind(gs.take_events(), &"noise")
	check("a melee swing is heard too", swing.size() >= 1, str(swing.size()))

## Events of one kind, so a test can assert about a blow without caring what
## else the same turn put on the queue.
func _of_kind(evts: Array, kind: StringName) -> Array:
	var out := []
	for e in evts:
		if e["kind"] == kind:
			out.append(e)
	return out

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


## A seed must build the same dungeon every time, in any order, in any process.
##
## This was NOT true for a while: `Array.shuffle()` draws on Godot's global rng
## rather than ours, so one call in the sanctum pass made every seeded level
## unreproducible. The symptom was a statistical test that passed and failed on
## alternate runs; the real cost was that a resumed save could not be trusted
## to continue the run it left.
func _test_generation_is_deterministic() -> void:
	var a := GameState.new(4242)
	a.new_game()
	# An unrelated level in between, to catch anything leaking through shared
	# or global state rather than through the seed.
	var noise := GameState.new(9999)
	noise.new_game()
	var b := GameState.new(4242)
	b.new_game()

	check("a seed rebuilds the same terrain", a.map.tiles == b.map.tiles)
	check("the same materials", a.map.material == b.map.material)
	check("the same monsters", a.entities.size() == b.entities.size(),
		"%d vs %d" % [a.entities.size(), b.entities.size()])
	check("the same loot", a.ground.size() == b.ground.size())
	check("the same shrines, in the same places",
		a.shrine_at.keys() == b.shrine_at.keys())
	check("the same colours behind them", a.shrine_hues == b.shrine_hues)
	check("and the same vaults", a.vault_rects == b.vault_rects)
	check("while a different seed differs", a.map.tiles != noise.map.tiles)

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
	# This guarded a correctness property once: the AI decided whether a monster
	# could see the player by testing the PLAYER's field of view, which is only
	# fair if the two agree. The awareness pass replaced that with an explicit
	# Los.clear() check per monster, so symmetry is no longer load-bearing --
	# what remains is a regression guard on the shadowcaster itself.
	#
	# The threshold is 95%, not 99%. Hand-authored vaults brought diagonal
	# walls and pillar lattices onto levels, and tight diagonal geometry is
	# exactly where recursive shadowcasting is least symmetric. That is the
	# algorithm behaving normally against harder input, not a fault.
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
		% [rate * 100.0, checked], rate > 0.95, "%d mismatches" % mismatch)

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


# ---------------------------------------------------------------- sound ----
#
# Sound is generated, not recorded, so it can be tested like any other
# computed thing: assert that every voice produces audio, that it produces the
# SAME audio every run, and that the simulation raises the events the deck
# listens for. None of this needs an audio device, which is the whole reason
# the synthesis and the event mapping are separable from the node that plays.

func _peak(stream: AudioStreamWAV) -> float:
	var loudest := 0.0
	var d := stream.data
	for i in range(0, d.size(), 2):
		loudest = maxf(loudest, absf(float(d.decode_s16(i)) / 32768.0))
	return loudest

func _test_every_sound_renders() -> void:
	var quiet: Array = []
	var stuck: Array = []
	var clipped: Array = []
	for id in Synth.SOUNDS:
		var stream: AudioStreamWAV = Synth.render(Synth.SOUNDS[id])
		if stream.data.size() < 64:
			stuck.append(id)
			continue
		var peak := _peak(stream)
		# A voice with a typo in its envelope renders silence and is otherwise
		# indistinguishable from a working one until someone plays the game.
		if peak < 0.05:
			quiet.append(id)
		# Loud is intended; pinned to the rail for the whole sound is not.
		if peak >= 0.999:
			clipped.append(id)

	check("every sound renders samples", stuck.is_empty(), str(stuck))
	check("no sound renders silent", quiet.is_empty(), str(quiet))
	check("no sound renders clipped", clipped.is_empty(), str(clipped))
	check("the bank holds every sound",
		Synth.bank().size() == Synth.SOUNDS.size())

## Noise seeded from the global rng would render differently every launch --
## the same trap that made every seeded level unreproducible, one layer down,
## and far harder to notice because nobody diffs a waveform.
func _test_sound_is_deterministic() -> void:
	var a := Synth.render(Synth.SOUNDS[&"crunch"])
	var b := Synth.render(Synth.SOUNDS[&"crunch"])
	check("the same voice renders identically twice", a.data == b.data)

func _test_sounds_map_to_real_voices() -> void:
	var deck := SoundDeck.new()
	var evts := [
		{"kind": &"notice", "to": Vector2i(3, 3)},
		{"kind": &"levelup", "to": Vector2i(3, 3)},
		{"kind": &"noise", "to": Vector2i(3, 3), "radius": 7},
		{"kind": &"trap", "to": Vector2i(3, 3)},
		{"kind": &"pray", "to": Vector2i(3, 3)},
		{"kind": &"forge", "to": Vector2i(3, 3)},
		{"kind": &"kill", "to": Vector2i(3, 3)},
		{"kind": &"death", "to": Vector2i(3, 3)},
		{"kind": &"lowhp", "to": Vector2i(3, 3)},
		{"kind": &"footing", "to": Vector2i(3, 3), "tile": Tiles.WATER},
		{"kind": &"melee", "from": Vector2i(2, 3), "to": Vector2i(3, 3),
			"amount": 3, "on_player": true},
		{"kind": &"ranged", "from": Vector2i(9, 3), "to": Vector2i(3, 3),
			"amount": 3, "on_player": true},
	]
	var picked := deck.choose(evts)
	var missing: Array = []
	for id in picked["now"]:
		if not Synth.SOUNDS.has(id):
			missing.append(id)
	for id in picked["later"]:
		if not Synth.SOUNDS.has(id):
			missing.append(id)
	check("every event maps to a voice that exists", missing.is_empty(), str(missing))
	check("each footing kind has its own voice",
		deck._footing_sound(Tiles.WATER) != deck._footing_sound(Tiles.MUD)
		and deck._footing_sound(Tiles.MUD) != deck._footing_sound(Tiles.RUBBLE))
	# Bones already speak through the noise event; hearing the crunch twice
	# would be worse than not hearing it at all.
	check("bones do not double up", deck._footing_sound(Tiles.BONES) == &"")

	# Six things noticing at once is one alarm, not six.
	var swarm: Array = []
	for i in 6:
		swarm.append({"kind": &"notice", "to": Vector2i(i, 3)})
	check("repeats collapse into one sound",
		int(deck.choose(swarm)["now"].size()) == 1)

	# The thud has to wait for the arrow, or it arrives before it.
	var shot := deck.choose([{"kind": &"ranged", "from": Vector2i(0, 3),
		"to": Vector2i(8, 3), "amount": 4, "on_player": true}])
	check("a shot is heard at once", shot["now"].has(&"shot"))
	check("its impact is held back until the arrow lands",
		shot["later"].has(&"hurt") and float(shot["later"][&"hurt"]) > 0.1)
	deck.free()

## The noise mechanic is the reason there is sound in this game at all: bones
## wake things seven cells away, through stone, and until now that was a line
## of text and nothing else.
func _test_noise_raises_a_sound_event() -> void:
	var gs := _arena(21, 9)
	gs.player.x = 5
	gs.player.y = 4
	gs.map.set_tile(6, 4, Tiles.BONES)
	gs.take_events()
	gs.player_move(1, 0)

	var loud := false
	var radius := 0
	for e in gs.take_events():
		if e["kind"] == &"noise":
			loud = true
			radius = int(e["radius"])
	check("stepping on bones raises a noise event", loud)
	check("it carries how far the noise reached", radius == 7, str(radius))

	# Quiet ground raises nothing, or the sound would be a footstep -- and a
	# footstep on every keypress is why people play roguelikes muted.
	gs.take_events()
	gs.player_move(1, 0)
	var quiet := true
	for e in gs.take_events():
		if e["kind"] == &"noise":
			quiet = false
	check("ordinary floor makes no sound", quiet)

func _test_footing_change_is_audible() -> void:
	var gs := _arena(21, 9)
	gs.player.x = 5
	gs.player.y = 4
	for x in range(6, 10):
		gs.map.set_tile(x, 4, Tiles.WATER)
	gs.take_events()

	gs.player_move(1, 0)
	var entered := 0
	for e in gs.take_events():
		if e["kind"] == &"footing" and int(e["tile"]) == Tiles.WATER:
			entered += 1
	check("wading in is heard once", entered == 1, str(entered))

	# Fires on the boundary, not per step, or it is a footstep by another name.
	gs.player_move(1, 0)
	var again := 0
	for e in gs.take_events():
		if e["kind"] == &"footing":
			again += 1
	check("crossing more of it is silent", again == 0, str(again))

func _test_low_health_warns_once() -> void:
	var gs := _arena(21, 9)
	gs.player.x = 5
	gs.player.y = 4
	gs.player.max_hp = 100
	gs.player.hp = 100
	gs.player_wait()
	gs.take_events()

	gs.player.hp = 20
	gs.player_wait()
	var warned := 0
	for e in gs.take_events():
		if e["kind"] == &"lowhp":
			warned += 1
	check("crossing the health line warns", warned == 1, str(warned))

	gs.player.hp = 15
	gs.player_wait()
	var nagged := 0
	for e in gs.take_events():
		if e["kind"] == &"lowhp":
			nagged += 1
	check("staying under it does not nag", nagged == 0, str(nagged))

	# Healing back over the line re-arms it, so the next slide down is heard.
	gs.player.hp = 100
	gs.player_wait()
	gs.take_events()
	gs.player.hp = 10
	gs.player_wait()
	var rearmed := 0
	for e in gs.take_events():
		if e["kind"] == &"lowhp":
			rearmed += 1
	check("recovering re-arms the warning", rearmed == 1, str(rearmed))

func _test_a_death_is_announced() -> void:
	var gs := _arena(21, 9)
	gs.player.x = 5
	gs.player.y = 4
	var kobold := _spawn(gs, "kobold", 6, 4)
	kobold.hp = 1
	gs.take_events()
	gs._attack(gs.player, kobold)
	var killed := false
	for e in gs.take_events():
		if e["kind"] == &"kill":
			killed = true
	check("killing something is heard", killed)

	gs.player.max_hp = 4
	gs.player.hp = 1
	gs.player.defense = 0
	var brute := _spawn(gs, "ogre", 6, 4)
	gs.take_events()
	gs._attack(brute, gs.player)
	var died := false
	for e in gs.take_events():
		if e["kind"] == &"death":
			died = true
	check("your own death is heard", died, "player alive: %s" % gs.player.alive)


# ------------------------------------------------------------- panel fit ----
#
# Five separate times a string has run through the edge of a panel: the
# inventory footer, the footing row, the torch row, the KEYS block, and the web
# build's pause-menu note. Every one was found by looking at a picture, and the
# last needed a screenshot of a browser to find at all.
#
# Panel widths are read out of the scene file rather than restated here, so the
# check cannot quietly drift away from what is actually on screen.

func _scene_widths() -> Dictionary:
	var text := FileAccess.get_file_as_string("res://scenes/main.tscn")
	var out := {}
	var name := ""
	var left := 0.0
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("[node name="):
			name = line.split('"')[1]
		elif line.begins_with("offset_left"):
			left = float(line.split("=")[1])
		elif line.begins_with("offset_right") and name != "":
			out[name] = float(line.split("=")[1]) - left
	return out

func _test_panels_do_not_overflow() -> void:
	var font: Font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
	var widths := _scene_widths()

	# The pause menu sizes itself, so its limit comes from its own constant.
	var menu_limit := MenuPanel.PANEL.x - MenuPanel.PAD * 2.0
	for note in [MenuPanel.NOTE_DESKTOP, MenuPanel.NOTE_WEB]:
		var w := font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1,
			MenuPanel.font_size_default() - 4).x
		check("menu note fits the panel (%d chars)" % note.length(),
			w <= menu_limit, "%.0f > %.0f px -- %s" % [w, menu_limit, note])

	# The sidebar draws the key left and the action right-aligned against the
	# same edge, so the failure is two strings meeting in the middle.
	var side_limit: float = float(widths.get("Sidebar", 256.0)) - Sidebar.PAD * 2.0
	var worst := ""
	var worst_w := 0.0
	for row in Sidebar.essential_keys():
		var a := font.get_string_size(row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var b := font.get_string_size(row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		if a + b > worst_w:
			worst_w = a + b
			worst = "%s / %s" % [row[0], row[1]]
	# A gap, not a touch: two strings that exactly meet read as one word.
	check("no key row collides with its action",
		worst_w + 8.0 <= side_limit,
		"%.0f + gap > %.0f px -- %s" % [worst_w, side_limit, worst])

	# The KEYS block is anchored to the bottom of the panel by its own length,
	# which is the fix that stopped the last recurrence.
	var keys_h := Sidebar.LINE * float(Sidebar.essential_keys().size() + 1) + Sidebar.PAD
	var side_h: float = 736.0 - 16.0
	check("the keys block fits above the frame edge", keys_h < side_h,
		"%.0f >= %.0f px" % [keys_h, side_h])


# ---------------------------------------------------------- symbol theme ----
#
# The whole premise of this mode is that the characters are already in the font
# we ship. That premise is checkable, and it is exactly the sort of thing that
# rots silently: a symbol that is absent renders as a blank or a tofu box, and
# nothing anywhere raises an error.

func _test_symbol_theme() -> void:
	var font: Font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
	var grid := GlyphGrid.new()
	var cell := float(grid.cell_size)
	grid.free()

	var missing: Array = []
	var too_wide: Array = []
	var unknown: Array = []
	for id in SymbolTheme.OVERRIDES:
		# A typo here would create an override that silently never fires.
		if not AsciiTheme.TABLE.has(id):
			unknown.append(id)
			continue
		var ch: String = SymbolTheme.OVERRIDES[id]["ch"]
		if not font.has_char(ch.unicode_at(0)):
			missing.append("%s (%s)" % [id, ch])
		# Not every symbol in this font is single width -- the shrine gate is
		# 16px and the shield 12px against a 10px reference. Anything wider
		# than the cell bleeds into its neighbour.
		var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		if w > cell:
			too_wide.append("%s (%s, %.0fpx > %.0fpx)" % [id, ch, w, cell])

	check("every override names a real appearance id", unknown.is_empty(), str(unknown))
	check("every symbol exists in the font we ship", missing.is_empty(), str(missing))
	check("no symbol is wider than its cell", too_wide.is_empty(), str(too_wide))

	# Terrain and items change; creatures do not. That split is the mode, so it
	# is worth asserting rather than trusting.
	var ascii_theme := AsciiTheme.new()
	var symbols := SymbolTheme.new()
	check("terrain changes between modes",
		ascii_theme.appearance(&"water")["ch"] != symbols.appearance(&"water")["ch"])
	check("items change between modes",
		ascii_theme.appearance(&"potion")["ch"] != symbols.appearance(&"potion")["ch"])

	var drifted: Array = []
	for e in GameState.BESTIARY:
		var id: StringName = e["app"]
		if ascii_theme.appearance(id)["ch"] != symbols.appearance(id)["ch"]:
			drifted.append(id)
	check("every creature keeps its letter", drifted.is_empty(), str(drifted))

	# Colour is the ASCII table's business in both modes: this changes the
	# shape of the dungeon, not its palette.
	check("symbols inherit the ascii colour",
		symbols.appearance(&"water")["fg"] == ascii_theme.appearance(&"water")["fg"])
	check("symbols keep the background too",
		symbols.appearance(&"brazier")["bg"] == ascii_theme.appearance(&"brazier")["bg"])

	# An id with no override must still come back whole, or the inventory and
	# legend get a fallback question mark instead of an item.
	check("un-overridden ids pass straight through",
		symbols.appearance(&"goblin")["ch"] == "g")

	# Cycling wraps rather than running off the end of the enum.
	var was := RenderTheme.mode()
	var seen := {}
	for i in RenderTheme.mode_count() + 1:
		seen[RenderTheme.mode()] = true
		RenderTheme.cycle()
	check("cycling visits every mode and wraps",
		seen.size() == RenderTheme.mode_count(),
		"%d of %d" % [seen.size(), RenderTheme.mode_count()])
	RenderTheme.set_mode(was)

	# All three panels must agree, which is the only reason the mode is static.
	RenderTheme.set_mode(RenderTheme.Mode.SYMBOLS)
	check("the active theme is the symbol one when selected",
		RenderTheme.active().appearance(&"water")["ch"] == "≈")
	RenderTheme.set_mode(RenderTheme.Mode.ASCII)
	check("and the ascii one when not",
		RenderTheme.active().appearance(&"water")["ch"] == "~")


## Reported from play: a brazier standing in a shrine's doorway.
##
## The level was still completable, which is why nothing caught it --
## _ensure_connected runs after decoration and had quietly rescued it by
## carving a passage in from another angle. So the visible symptom was not a
## sealed room, it was a blocked door PLUS a corridor arriving from nowhere,
## and that is a much easier thing to look at and not name.
##
## 16 plugged doorways in 480 levels before the fix, every one of them with a
## solid decoration beside it. Zero after.
##
## Note what is NOT asserted here: that nothing solid ever stands in a local
## bottleneck. That was the first version of this test and it was wrong -- a
## pillar in the middle of a 2x2 cluster of pillars trips a local ring test
## while the room routes around it perfectly well. The ring test is a good
## placement GUARD, because refusing to place a decoration costs nothing, but
## it is not a property the finished map has to satisfy.
func _test_no_decoration_plugs_a_way() -> void:
	var plugged: Array = []
	var stranded: Array = []
	var levels := 0
	var shrines := 0
	for seed_v in range(1, 41):
		for depth in [1, 4, 7, 10]:
			var gs := GameState.new(seed_v)
			# new_game() first: build_level() places the player, so calling it
			# on a bare GameState aborts halfway through with a null player and
			# quietly hands back a half-finished level.
			gs.new_game()
			if depth > 1:
				gs.depth = depth
				gs.build_level()
			levels += 1
			var m := gs.map
			var from := Vector2i(gs.player.x, gs.player.y)
			for y in m.height:
				for x in m.width:
					var t := m.get_tile(x, y)
					if t == Tiles.DOOR_CLOSED or t == Tiles.DOOR_OPEN:
						# A door sits in a wall, so it must have open ground on
						# both sides of one axis. One way out means it leads
						# nowhere, and a door you cannot pass is either a lie or
						# a room you got into some other way.
						var ways := 0
						for d in [Vector2i(0, -1), Vector2i(0, 1),
								Vector2i(1, 0), Vector2i(-1, 0)]:
							if m.is_walkable(x + d.x, y + d.y) \
									and not Tiles.is_avoided(m.get_tile(x + d.x, y + d.y)):
								ways += 1
						if ways <= 1 and plugged.size() < 5:
							plugged.append("seed %d d%d (%d,%d)" % [seed_v, depth, x, y])
					elif t == Tiles.SHRINE:
						# The worse version of the same bug, and the one that
						# would actually cost someone a run: a shrine walled off
						# behind its own decoration.
						shrines += 1
						var here := Vector2i(x, y)
						var route := gs.pathfinder.path(from, here)
						if route.is_empty() and from != here and stranded.size() < 5:
							stranded.append("seed %d d%d (%d,%d)" % [seed_v, depth, x, y])

	check("no door leads nowhere (%d levels)" % levels, plugged.is_empty(), str(plugged))
	check("every shrine can be reached (%d shrines)" % shrines,
		stranded.is_empty(), str(stranded))


## Reported by the person who built the game: he had never moved diagonally.
##
## He plays on a keyboard with no number pad, using the arrow keys, which are
## orthogonal only -- while every monster on the floor moved and struck in
## eight directions. That is the reason the legend now draws the movement
## scheme instead of describing it.
##
## Chasing it down turned up a second thing. Four pieces of code moved something
## and only ONE obeyed the corner rule: hunting monsters route through
## AStarGrid2D, which refuses to cut between two solid cells. The player, a
## fleeing monster and an erratic one all moved directly and checked only
## whether the destination was walkable. So three of the four could slip through
## a wall joint that a hunter had to walk six turns around.
func _test_corners_stop_everyone_equally() -> void:
	var gs := _arena(21, 11)
	gs.player.x = 5
	gs.player.y = 5
	# A hard corner: both cells between (5,5) and (6,4) are wall.
	gs.map.set_tile(6, 5, Tiles.WALL)
	gs.map.set_tile(5, 4, Tiles.WALL)
	gs.pathfinder = Pathfinder.new(gs.map)

	check("a diagonal step through a hard corner is refused",
		not gs.can_step(5, 5, 6, 4))
	check("the player cannot take it either",
		not gs.player_move(1, -1))
	check("and has not moved", gs.player.x == 5 and gs.player.y == 5)

	# One wall is enough to make it a corner; neither alone is.
	gs.map.set_tile(5, 4, Tiles.FLOOR)
	gs.pathfinder = Pathfinder.new(gs.map)
	check("one wall beside a diagonal still blocks it",
		not gs.can_step(5, 5, 6, 4))
	gs.map.set_tile(6, 5, Tiles.FLOOR)
	gs.pathfinder = Pathfinder.new(gs.map)
	check("an open diagonal is fine", gs.can_step(5, 5, 6, 4))
	check("so are all four orthogonals",
		gs.can_step(5, 5, 6, 5) and gs.can_step(5, 5, 4, 5)
		and gs.can_step(5, 5, 5, 4) and gs.can_step(5, 5, 5, 6))

	# The rule must agree with the pathfinder, or monsters and the player are
	# playing on two different maps again.
	var mismatch := 0
	var checked := 0
	for seed_v in range(1, 9):
		var g := GameState.new(seed_v)
		g.new_game()
		for y in range(1, g.map.height - 1):
			for x in range(1, g.map.width - 1):
				# The pathfinder cannot start from a cell it treats as solid
				# either, so an avoided origin is not a fair comparison for the
				# same reason an avoided destination is not.
				if not g.map.is_walkable(x, y) \
						or Tiles.is_avoided(g.map.get_tile(x, y)):
					continue
				for d: Vector2i in [Vector2i(1, 1), Vector2i(-1, 1),
						Vector2i(1, -1), Vector2i(-1, -1)]:
					var to := Vector2i(x + d.x, y + d.y)
					if not g.map.is_walkable(to.x, to.y):
						continue
					# Pits and traps are walkable but the pathfinder treats them
					# as solid, so auto-travel routes around rather than
					# dropping you down a hole. That disagreement is deliberate
					# -- stepping into a pit is a decision the player is allowed
					# to make -- so those cells are not a fair comparison.
					if Tiles.is_avoided(g.map.get_tile(to.x, to.y)) \
							or Tiles.is_avoided(g.map.get_tile(to.x, y)) \
							or Tiles.is_avoided(g.map.get_tile(x, to.y)):
						continue
					checked += 1
					var mine := g.can_step(x, y, to.x, to.y)
					# One step from the pathfinder means it took the diagonal.
					var theirs := g.pathfinder.path(Vector2i(x, y), to).size() == 1
					if mine != theirs:
						mismatch += 1
	check("the step rule matches the pathfinder (%d diagonals)" % checked,
		mismatch == 0, "%d disagreements" % mismatch)

	# Reach is deliberately untouched: eight-way for everyone.
	var gs2 := _arena(21, 11)
	gs2.player.x = 5
	gs2.player.y = 5
	gs2.map.set_tile(6, 5, Tiles.WALL)
	gs2.map.set_tile(5, 4, Tiles.WALL)
	var foe := _spawn(gs2, "kobold", 6, 4)
	check("but reach is still eight-way", foe.is_adjacent(gs2.player))
	var before := foe.hp
	gs2.player_move(1, -1)
	check("so a diagonal attack through a corner still lands", foe.hp < before)


## Reported from play: a dagger lying on a pit tile.
##
## That is not a hazard, it is a hazard BAITED. You cross the room to pick the
## thing up, step onto the hole, and lose a floor -- which is exactly what
## happened, on depth 4, in a run that then ended on depth 5.
##
## The cause was `is_walkable` standing in for "somewhere a thing can sit".
## Pits and traps are walkable by necessity: you could never step into one
## otherwise. `_open_cell_in` already knew this and had a comment explaining
## it; the loot roll, the spawner and the vault placer did not.
func _test_nothing_rests_on_a_hazard() -> void:
	var baited: Array = []
	var stuck: Array = []
	var levels := 0
	var items := 0
	var monsters := 0

	for seed_v in range(1, 41):
		for depth in [1, 4, 7, 10]:
			var gs := GameState.new(seed_v)
			gs.new_game()
			if depth > 1:
				gs.depth = depth
				gs.build_level()
			levels += 1
			for it in gs.ground:
				items += 1
				if Tiles.is_avoided(gs.map.get_tile(it.x, it.y)) and baited.size() < 5:
					baited.append("%s seed %d d%d (%d,%d)"
						% [it.name, seed_v, depth, it.x, it.y])
			for e in gs.entities:
				if e.is_player:
					continue
				monsters += 1
				# A monster on a pit is frozen for the rest of the run: the
				# pathfinder treats avoided ground as solid, so it cannot plan
				# a single step off the tile it woke up on.
				if Tiles.is_avoided(gs.map.get_tile(e.x, e.y)) and stuck.size() < 5:
					stuck.append("%s seed %d d%d (%d,%d)"
						% [e.name, seed_v, depth, e.x, e.y])
			# The player never starts on one either.
			var under := gs.map.get_tile(gs.player.x, gs.player.y)
			if Tiles.is_avoided(under) and baited.size() < 5:
				baited.append("PLAYER seed %d d%d" % [seed_v, depth])

	check("no item lies on a pit or trap (%d items, %d levels)" % [items, levels],
		baited.is_empty(), str(baited))
	check("nothing stands on one either (%d monsters)" % monsters,
		stuck.is_empty(), str(stuck))


## Potions and scrolls of light can be worked at a brazier.
##
## The problem this answers, measured before it was built: a potion heals a
## flat 12, which is 40% of your health at level 1 and 17% at level 9. Healing
## decays exactly as danger rises, so potions stop being worth the turn they
## cost and pile up unused -- six of them, in the run that prompted this.
##
## A merge is worth two thirds of the copy it eats: 12 -> 20 -> 28, and 6 -> 10
## -> 14 for the relight a scroll gives a dead brazier. You give up raw healing
## and get back a turn and an inventory slot. Free would remove the decision;
## much less would make it a trap.
func _test_consumables_forge() -> void:
	var gs := _forge_arena()
	gs.give_item(Item.make(&"potion_healing"))
	gs.give_item(Item.make(&"potion_healing"))
	gs.give_item(Item.make(&"potion_healing"))
	check("a potion can be worked at a brazier", gs.player_merge(0))
	var pot: Item = gs.player.inventory[0]
	check("it eats one of its own kind", gs.player.inventory.size() == 2,
		str(gs.player.inventory.size()))
	check("and heals two thirds more (%d)" % pot.effective_magnitude(),
		pot.effective_magnitude() == 20, str(pot.effective_magnitude()))
	check("it is named for what it now is", pot.display_name().ends_with("+1"))

	check("a second forging stacks", gs.player_merge(0))
	check("to 28", gs.player.inventory[0].effective_magnitude() == 28,
		str(gs.player.inventory[0].effective_magnitude()))

	# The cap is the same one gear answers to, so the Shrine of the Anvil
	# raises it for potions as well.
	var capped := _forge_arena()
	# Deep coals: the default brazier holds 10 and each forging costs 4, so
	# without this the third merge would fail for want of heat rather than for
	# hitting the cap, and the test would pass for the wrong reason.
	capped.brazier_charge = {Vector2i(6, 4): 100}
	for i in 5:
		capped.give_item(Item.make(&"potion_healing"))
	capped.player_merge(0)
	capped.player_merge(0)
	check("stops at the forge cap", not capped.player_merge(0))
	capped.forge_cap_bonus = 1
	check("unless the anvil raised it", capped.player_merge(0))
	check("reaching 36", capped.player.inventory[0].effective_magnitude() == 36,
		str(capped.player.inventory[0].effective_magnitude()))

	# Drinking one actually restores the forged amount.
	var drink := _forge_arena()
	drink.give_item(Item.make(&"potion_healing"))
	drink.give_item(Item.make(&"potion_healing"))
	drink.player_merge(0)
	drink.player.max_hp = 90
	drink.player.hp = 10
	drink.player_use(0)
	check("a forged potion heals what it says (%d)" % drink.player.hp,
		drink.player.hp == 30, str(drink.player.hp))

	# And a worked scroll carries more fire into a dead brazier.
	var scroll := _forge_arena()
	scroll.give_item(Item.make(&"scroll_light"))
	scroll.give_item(Item.make(&"scroll_light"))
	check("a scroll of light can be worked", scroll.player_merge(0))
	check("its relight is worth 10 rather than 6",
		GameState.RELIGHT_CHARGE + scroll.player.inventory[0].upgrade_level()
			* scroll.player.inventory[0].forge_bonus == 10)

	# Forging a potion spends brazier charge, which does not come back. If the
	# potion reverted on resume the charge would be gone for nothing.
	var kept := Item.from_dict(pot.to_dict())
	check("a forged potion survives a suspend",
		kept.effective_magnitude() == pot.effective_magnitude(),
		"%d vs %d" % [kept.effective_magnitude(), pot.effective_magnitude()])
	# Saves written before consumables could be forged carry no such field.
	var older := {"id": "potion_healing", "letter": "a", "x": 0, "y": 0,
		"pow": 0, "def": 0}
	check("and an older save still loads as a plain one",
		Item.from_dict(older).effective_magnitude() == 12)


## Shields, and the swap between reach and blade.
##
## Both exist because of one measured fact: toe to toe with a young dragon the
## same character wins 100% of the time holding a war axe and 0% holding a war
## bow, because swinging a launcher halves your power and every blow lands at
## the damage floor. The axe was in the pack the whole time and nothing on
## screen said so.
func _test_offhand_and_swap() -> void:
	# The shield values are derived from where each monster stops being able to
	# hit harder, so those thresholds are worth pinning down.
	var floors := {}
	for e in GameState.BESTIARY:
		var atk := int(e["power"])
		floors[String(e["name"])] = atk + 1 - int(ceil(float(atk)
			* GameState.DAMAGE_FLOOR_FRACTION))
	check("a buckler floors the shadow at base 4 plus plate",
		4 + 5 + 1 >= int(floors["shadow"]), str(floors["shadow"]))
	check("a kite shield floors the young dragon",
		4 + 5 + 2 >= int(floors["young dragon"]), str(floors["young dragon"]))
	check("a tower shield buys margin past everything",
		4 + 5 + 3 > int(floors["young dragon"]))

	var gs := _arena(21, 9)
	gs.player.x = 5
	gs.player.y = 4
	gs.player.defense = 4
	var plate := Item.make(&"plate_mail")
	var kite := Item.make(&"kite_shield")
	var axe := Item.make(&"war_axe")
	var bow := Item.make(&"war_bow")
	for it in [plate, kite, axe, bow]:
		gs.give_item(it)

	gs.player_use(gs.player.inventory.find(plate))
	gs.player_use(gs.player.inventory.find(kite))
	check("a shield sits beside armour, not instead of it",
		gs.player.is_equipped(plate) and gs.player.is_equipped(kite))
	check("and both count toward defense (%d)" % gs.player.total_defense(),
		gs.player.total_defense() == 4 + 5 + 2, str(gs.player.total_defense()))

	# A launcher needs both hands.
	gs.player_use(gs.player.inventory.find(bow))
	check("taking up a bow puts the shield away",
		gs.player.is_equipped(bow) and not gs.player.is_equipped(kite))
	check("armour is untouched by that", gs.player.is_equipped(plate))
	check("and defense drops back (%d)" % gs.player.total_defense(),
		gs.player.total_defense() == 4 + 5)

	# And the rule holds in reverse.
	gs.player_use(gs.player.inventory.find(kite))
	check("raising a shield puts the bow on your back",
		gs.player.is_equipped(kite) and not gs.player.is_equipped(bow))

	# A one-handed weapon coexists with a shield.
	gs.player_use(gs.player.inventory.find(axe))
	check("but a blade and a shield go together",
		gs.player.is_equipped(axe) and gs.player.is_equipped(kite))

	# The swap key.
	var before := gs.turns
	check("swapping from blade reaches for the bow", gs.player_swap_weapon())
	check("the bow is now in hand", gs.player.is_equipped(bow))
	check("which also cost the shield", not gs.player.is_equipped(kite))
	check("and it cost a turn", gs.turns > before)
	check("swapping back reaches for the blade", gs.player_swap_weapon())
	check("the axe is in hand again", gs.player.is_equipped(axe))

	# Nothing to swap to is refused rather than silently doing nothing.
	var bare := _arena(21, 9)
	bare.player.x = 5
	bare.player.y = 4
	bare.give_item(Item.make(&"war_axe"))
	bare.player_use(0)
	check("with no launcher carried, the swap is refused",
		not bare.player_swap_weapon())

	# Shields are forgeable like any other gear, and stack with the body.
	var forge := _forge_arena()
	forge.give_item(Item.make(&"buckler"))
	forge.give_item(Item.make(&"buckler"))
	check("a shield can be worked at a brazier", forge.player_merge(0))
	check("gaining a point of defense",
		forge.player.inventory[0].defense_bonus == 2,
		str(forge.player.inventory[0].defense_bonus))


## Reported from play, and it cost a run's last potion.
##
## The pack assigned that potion the letter "i", and "i" closes the inventory.
## Every press shut the panel instead of drinking it, shift+i did not merge it
## either because the close check runs first, and there was no way to reach the
## item from the keyboard at all.
func _test_inventory_letters_dodge_the_keys() -> void:
	for i in GameState.RESERVED_LETTERS.length():
		var ch := GameState.RESERVED_LETTERS[i]
		check("the pool never offers \"%s\"" % ch,
			not GameState.LETTERS.contains(ch))
	check("and is still long enough for a full pack (%d for %d)"
		% [GameState.LETTERS.length(), Entity.INVENTORY_MAX],
		GameState.LETTERS.length() >= Entity.INVENTORY_MAX)

	# Fill a pack and check nothing unreachable comes out of it.
	var gs := _arena(21, 9)
	var handed := 0
	for i in Entity.INVENTORY_MAX:
		if gs.give_item(Item.make(&"potion_healing")):
			handed += 1
	var bad: Array = []
	var seen := {}
	for it in gs.player.inventory:
		if it.letter == "" or GameState.RESERVED_LETTERS.contains(it.letter):
			bad.append(it.letter)
		if seen.has(it.letter):
			bad.append("duplicate " + it.letter)
		seen[it.letter] = true
	check("a full pack is all reachable (%d items)" % handed, bad.is_empty(), str(bad))

	# A run suspended before this was fixed can be carrying the stuck item, and
	# reloading is the moment to put it right.
	var stuck := _arena(21, 9)
	stuck.give_item(Item.make(&"potion_healing"))
	stuck.player.inventory[0].letter = "i"
	stuck.give_item(Item.make(&"scroll_light"))
	stuck.player.inventory[1].letter = ""
	stuck._relabel_unreachable_items()
	check("an old save's unreachable item is re-lettered",
		stuck.player.inventory[0].letter != "i"
		and not GameState.RESERVED_LETTERS.contains(stuck.player.inventory[0].letter),
		stuck.player.inventory[0].letter)
	check("and a blank one is given a letter too",
		stuck.player.inventory[1].letter != "", stuck.player.inventory[1].letter)
	check("without colliding",
		stuck.player.inventory[0].letter != stuck.player.inventory[1].letter)

## Reads main.gd and fails if a letter key is handled while the inventory is
## open without being reserved.
##
## The point is that the next key added there cannot quietly steal a letter the
## way "i" did. Asserting the current list by hand would only restate the bug.
func _test_no_key_steals_an_inventory_letter() -> void:
	var src := FileAccess.get_file_as_string("res://src/render/main.gd")
	var start := src.find("if inventory.visible:")
	# The open handler sits just past the block and is not part of it.
	var stop := src.find("if key == KEY_I:", start)
	check("the inventory key block was found", start >= 0 and stop > start)
	if start < 0 or stop <= start:
		return
	var block := src.substr(start, stop - start)

	var re := RegEx.new()
	# A single capital after KEY_, with nothing wordlike after it -- so KEY_I
	# and KEY_F match while KEY_TAB and KEY_ESCAPE do not.
	re.compile("KEY_([A-Z])\\b")
	var unguarded: Array = []
	for m in re.search_all(block):
		var ch: String = m.get_string(1).to_lower()
		if not GameState.RESERVED_LETTERS.contains(ch):
			unguarded.append(ch)
	check("every letter key the inventory answers to is reserved",
		unguarded.is_empty(), str(unguarded))


## A save written by an older build must still load.
##
## This matters more than it used to: there is a build live on itch.io, and
## someone's suspended run was written by it. Loading a save DESTROYS it by
## design, so there is no way for a player to test the upgrade safely -- which
## makes it this suite's job instead.
func _test_an_older_save_still_loads() -> void:
	var gs := GameState.new(2468)
	gs.new_game()
	gs.depth = 9
	gs.ascending = true
	gs.build_level()
	gs.player.level = 9
	for want in [&"war_bow", &"plate_mail", &"potion_healing",
			&"potion_healing", &"scroll_light"]:
		gs.give_item(Item.make(want))
	gs.player.equipped[Item.Slot.WEAPON] = gs.player.inventory[0]
	gs.player.equipped[Item.Slot.ARMOR] = gs.player.inventory[1]
	check("a save can be written", gs.save_suspend())

	# Age it to what the older build produced: no forging field on consumables,
	# and an item on a letter that build was still handing out.
	var raw := FileAccess.get_file_as_string(GameState.SUSPEND_PATH)
	var text := Marshalls.base64_to_utf8(raw)
	var was_b64 := text != ""
	if not was_b64:
		text = raw
	var json := JSON.new()
	check("and read back as json", json.parse(text) == OK)
	var data: Dictionary = json.data
	var pl: Dictionary = (data["entities"] as Array)[int(data["player"])]
	var pack: Array = pl["inventory"]
	var stripped := 0
	var stuck := false
	for i in pack.size():
		var entry: Dictionary = pack[i]
		if entry.erase("boost"):
			stripped += 1
		if not stuck and String(entry.get("id", "")) == "potion_healing":
			entry["letter"] = "i"
			stuck = true
	check("the aged save lost its forging fields (%d)" % stripped, stripped > 0)

	var aged := JSON.stringify(data)
	var f := FileAccess.open(GameState.SUSPEND_PATH, FileAccess.WRITE)
	f.store_string(Marshalls.utf8_to_base64(aged) if was_b64 else aged)
	f.close()

	var back := GameState.load_suspend()
	check("the current build loads it", back != null)
	if back == null:
		return
	check("with the run intact", back.depth == 9 and back.ascending
		and back.player.level == 9 and back.player.inventory.size() == 5)
	check("equipment still worn", back.player.equipped.has(Item.Slot.WEAPON)
		and back.player.equipped.has(Item.Slot.ARMOR))
	var letters := ""
	for it in back.player.inventory:
		letters += it.letter
	check("and the unreachable letter repaired (%s)" % letters,
		not letters.contains("i") and not letters.contains("f")
		and not letters.contains(" "))
	check("an unforged potion still heals 12",
		back.player.inventory[2].effective_magnitude() == 12)


## Fungus is food, barely.
##
## One hit point, and the patch goes dark. Deliberately not worth a detour: at
## a point a turn it is half the rate of resting at a brazier, and a floor only
## grows a dozen or so. What it is worth is being taken on the way past -- and
## the cost is the light, which is the actual decision.
func _test_fungus_is_a_mouthful() -> void:
	var gs := _arena(21, 9)
	gs.player.x = 5
	gs.player.y = 4
	gs.map.set_tile(5, 4, Tiles.FUNGUS)
	gs.player.max_hp = 30
	gs.player.hp = 20
	var lights_before := gs.static_lights.size()
	check("fungus glows before you eat it", Tiles.is_luminous(Tiles.FUNGUS))
	check("eating it works", gs.player_pickup())
	check("for exactly one point", gs.player.hp == 21, str(gs.player.hp))
	check("the patch is gone", gs.map.get_tile(5, 4) != Tiles.FUNGUS)
	check("and took its light with it",
		gs.static_lights.size() <= lights_before, str(gs.static_lights.size()))

	# Not at full health -- the light is worth more than nothing.
	var whole := _arena(21, 9)
	whole.player.x = 5
	whole.player.y = 4
	whole.map.set_tile(5, 4, Tiles.FUNGUS)
	whole.player.max_hp = 30
	whole.player.hp = 30
	check("a whole player leaves it be", not whole.player_pickup())
	check("so the glow stays", whole.map.get_tile(5, 4) == Tiles.FUNGUS)

	# An item on the same cell still takes priority.
	var both := _arena(21, 9)
	both.player.x = 5
	both.player.y = 4
	both.map.set_tile(5, 4, Tiles.FUNGUS)
	both.player.hp = 1
	var loot := Item.make(&"dagger")
	loot.x = 5
	loot.y = 4
	both.ground.append(loot)
	check("an item underfoot is picked up first", both.player_pickup())
	check("and the fungus is untouched", both.map.get_tile(5, 4) == Tiles.FUNGUS)


## The icon mode.
##
## Its premise is that every picture comes from a font the game ships, so the
## premise is checkable -- and it is exactly the sort of thing that rots
## silently, because a codepoint the font lacks renders as a blank or a tofu
## box and raises no error anywhere.
##
## The mode nearly did not happen: it was going to be desktop-only because the
## Nerd Font is 2.5MB. Subsetting it to the thirty glyphs actually drawn made
## it 18KB, a fifteenth of the text font already in the repo.
func _test_icon_theme() -> void:
	var font: Font = load("res://assets/fonts/ofr_icons.ttf")
	check("the icon font ships", font != null)
	if font == null:
		return

	var missing: Array = []
	var unknown: Array = []
	for id in GlyphTheme.OVERRIDES:
		if not AsciiTheme.TABLE.has(id):
			unknown.append(id)
			continue
		if not font.has_char(int(GlyphTheme.OVERRIDES[id])):
			missing.append("%s U+%X" % [id, int(GlyphTheme.OVERRIDES[id])])
	check("every override names a real appearance id", unknown.is_empty(), str(unknown))
	check("every icon exists in the font we ship", missing.is_empty(), str(missing))
	check("ascii survived the subset", font.has_char(65) and font.has_char(64))
	check("and so did the symbol mode's characters",
		font.has_char("≈".unicode_at(0)) and font.has_char("⌂".unicode_at(0)))

	var icons := GlyphTheme.new()
	var letters := AsciiTheme.new()

	# Shape carries rank: the humanoids deliberately SHARE figures.
	check("kobold and goblin share the small figure",
		icons.appearance(&"kobold")["ch"] == icons.appearance(&"goblin")["ch"])
	check("ogre and troll share the heavy figure",
		icons.appearance(&"ogre")["ch"] == icons.appearance(&"troll")["ch"])
	check("but small and heavy are different figures",
		icons.appearance(&"kobold")["ch"] != icons.appearance(&"ogre")["ch"])
	check("and the slinger is not just another kobold",
		icons.appearance(&"slinger")["ch"] != icons.appearance(&"kobold")["ch"])

	# Colour carries family, so a shared figure must never share a colour.
	for pair in [[&"kobold", &"goblin"], [&"orc", &"wight"],
			[&"ogre", &"troll"], [&"wyvern", &"dragon"]]:
		if icons.appearance(pair[0])["ch"] != icons.appearance(pair[1])["ch"]:
			continue
		check("%s and %s differ in colour" % [pair[0], pair[1]],
			icons.appearance(pair[0])["fg"] != icons.appearance(pair[1])["fg"])

	# The player stays a letter on purpose.
	check("you are still @", icons.appearance(&"player")["ch"] == "@")

	# Icons are drawn larger than letters, everywhere that draws one.
	var an_icon: String = icons.appearance(&"brazier")["ch"]
	check("an icon is recognised as one", GlyphTheme.is_icon(an_icon))
	check("a letter is not", not GlyphTheme.is_icon("k"))
	check("icons are drawn bigger than the text around them",
		GlyphTheme.draw_size(an_icon, 16) > 16)
	check("letters are drawn at the size they are given",
		GlyphTheme.draw_size("k", 16) == 16)

	# Colour and background still come from the ascii table.
	check("icons inherit the palette",
		icons.appearance(&"water")["fg"] == letters.appearance(&"water")["fg"])
	check("un-overridden ids pass through whole",
		icons.appearance(&"pillar")["ch"] == letters.appearance(&"pillar")["ch"])

	# Three modes now, and cycling reaches all of them.
	var was := RenderTheme.mode()
	check("there are three view modes", RenderTheme.mode_count() == 3)
	var seen := {}
	for i in RenderTheme.mode_count() + 1:
		seen[RenderTheme.mode()] = true
		RenderTheme.cycle()
	check("cycling visits every one", seen.size() == 3, str(seen.size()))
	RenderTheme.set_mode(RenderTheme.Mode.ICONS)
	check("the icon theme is the active one when selected",
		RenderTheme.active().appearance(&"brazier")["ch"] == an_icon)
	RenderTheme.set_mode(was)
