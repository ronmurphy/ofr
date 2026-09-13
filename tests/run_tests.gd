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
	_test_threat_ceiling_holds_on_the_climb()
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
	_test_every_theme_glyph_is_drawable()
	_test_symbol_theme()
	_test_icon_theme()
	_test_no_decoration_plugs_a_way()
	_test_corners_stop_everyone_equally()
	_test_nothing_rests_on_a_hazard()
	_test_consumables_forge()
	_test_ember_forge()
	_test_embers_cool_and_refuse_glass()
	_test_ember_heat_reads_the_clock()
	_test_cave_band()
	_test_cave_dwellers()
	_test_memory_by_band()
	_test_generation_ignores_the_morgue()
	_test_launcher_reach()
	_test_shrine_voices()
	_test_noise_is_drawn()
	_test_dead_fires_are_dead()
	_test_effects_modes()
	_test_rabbit()
	_test_banshee()
	_test_graves_raise_the_dead()
	_test_bestiary_is_earned()
	_test_meat_keeps_its_worth()
	_test_binding_a_stone()
	_test_gems_bite()
	_test_gem_of_returning()
	_test_choosing_the_bound_weapon()
	_test_the_better_piece_is_kept()
	_test_chests()
	_test_the_dead_are_marked()
	_test_damage_types()
	_test_the_first_gem_is_certain()
	_test_every_kind_is_listed()
	_test_cave_bear()
	_test_cave_giant()
	_test_authored_pits_obey_the_rule()
	_test_casters()
	_test_caster_standoff_and_blink()
	_test_graves_remember_the_dead()
	_test_elapsed_is_time_not_keypresses()
	_test_run_is_recorded()
	_test_offhand_and_swap()
	_test_ammunition()
	_test_merging_spends_the_cheapest()
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

## Reports everything check_silent has gathered since the last report, and
## arms it again.
##
## Without the reset `_silent_ok` is a one-shot: the first block to fail one
## silently poisons every later block that reports it, and the first block to
## REPORT it clears nothing, so the next block is reporting the previous one's
## result. And it has to be reported at all -- the band-folding block gathered
## eighteen assertions and then called `check(..., true)`, so none of them
## could fail the suite.
func check_gathered(name: String, detail: String = "") -> void:
	check(name, _silent_ok, detail)
	_silent_ok = true

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
	# Straight through the game's own builder. This used to be a hand-copied
	# second version of GameState._spawn_at's field list, and it drifted three
	# separate times -- each time the suite cheerfully asserted behaviour the
	# real game did not have. A test double that can disagree with the thing it
	# doubles is worse than no double at all.
	for e in GameState.BESTIARY:
		if e["name"] != mname:
			continue
		var m := GameState.monster_from(e, x, y)
		# Behaviour tests want behaviour, not the awareness gate. Awareness has
		# its own tests below, which set this back to ASLEEP explicitly.
		m.alertness = Entity.Alert.AWAKE
		gs.entities.append(m)
		return m
	# Loudly, rather than by handing back a null that the caller dereferences
	# three lines later. A misremembered name used to read as "the mechanic is
	# broken": asking for "rat" when the bestiary says "giant rat" spawned
	# nothing, so a knockback test saw an empty cell, reported that shoves pass
	# through creatures, and then crashed on the null -- silently skipping
	# every remaining check in that function.
	check("the bestiary has a monster named '%s'" % mname, false, "no such name")
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

## The same guarantee, on the way OUT.
##
## The descent has always been checked and the climb never was, which was a
## survivable gap while the two drew from the same pool. It stopped being one
## the moment the bestiary gained something worth 32 -- an arch lich is a third
## of an entire ascent room's ceiling on its own, and a breach here is the kind
## of unwinnable room the ceiling exists to forbid.
func _test_threat_ceiling_holds_on_the_climb() -> void:
	var breaches := 0
	var worst_over := 0
	var rooms_checked := 0
	var liches := 0
	for d in range(GameState.MAX_DEPTH - 1, 0, -1):
		for i in 25:
			var gs := GameState.new(41000 + d * 100 + i)
			gs.new_game()
			gs.ascending = true
			gs.depth = d
			gs.build_level()
			var ceiling := gs.room_threat_ceiling()
			for e in gs.entities:
				if e.name == "arch lich":
					liches += 1
			for room in gs.room_rects:
				rooms_checked += 1
				var sum := 0
				for e in gs.entities:
					if not e.is_player and room.has_point(Vector2i(e.x, e.y)):
						sum += e.threat
				if sum > ceiling:
					breaches += 1
					worst_over = maxi(worst_over, sum - ceiling)
	check("no room on the climb exceeds its ceiling (%d rooms, %d liches met)"
		% [rooms_checked, liches], breaches == 0,
		"%d breaches, worst %d over" % [breaches, worst_over])
	check("and the climb actually fielded some liches", liches > 0, str(liches))

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

	# Caves were never checked, and an unchecked budget is not a budget.
	#
	# The comment here used to say caves carry a "higher" ceiling because they
	# are wilder and unlit. They carry a LOWER one -- CAVE_THREAT_SCALE is 0.7 --
	# which is the whole reason nothing named for a cave could afford to live in
	# one. Two bounds now, because one cave a floor may be a den:
	#
	#   every cave  <= the ROOM ceiling      a cave is never deadlier than a room
	#   all but one <= the CAVE ceiling      the den is the exception, and it is
	#                                        one per floor, not one per cave
	var cave_breaches := 0
	var caves_checked := 0
	var cave_worst := 0
	var dens := 0
	var many_dens := 0
	for d in range(1, 9):
		for i in 25:
			var gs := GameState.new(21000 + d * 100 + i)
			gs.new_game()
			gs.depth = d
			gs.build_level()
			var ceiling := gs.cave_threat_ceiling()
			var roof := gs.room_threat_ceiling()
			var here := 0
			for region in gs.cave_regions:
				caves_checked += 1
				var sum := 0
				for e in gs.entities:
					if not e.is_player and region.has_point(Vector2i(e.x, e.y)):
						sum += e.threat
				if sum > roof:
					cave_breaches += 1
					cave_worst = maxi(cave_worst, sum - roof)
				elif sum > ceiling:
					here += 1
			dens += here
			if here > 1:
				many_dens += 1
	check("no cave is deadlier than a room (%d caves, depths 1-8)" % caves_checked,
		cave_breaches == 0, "%d breaches, worst %d over" % [cave_breaches, cave_worst])
	check("at most one den a floor", many_dens == 0, "%d floors with more" % many_dens)
	# And the den actually happens -- a bound nothing ever reaches is not a rule,
	# it is a coincidence, and this one exists precisely to be reached.
	check("dens do occur (%d)" % dens, dens > 0)

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
	check_gathered("a corpse never keeps its equipment")

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

	# Rubble, IN A CAVE, on the band made of caves.
	#
	# The assertion the old census was missing, and the gap is why this went
	# unnoticed: `_roll_ground` is called only in the rooms loop, so RUBBLED was
	# unreachable in a cave and every rubble tile in the game stood on a floor
	# somebody built. The band that is four fifths cavern carried the LEAST
	# rubble in the dungeon -- 10 tiles a floor against 33 up top -- while being
	# the band whose economy is knapping stones for a sling.
	#
	# Counted on CAVERN material rather than anywhere on a cave-band floor,
	# because a caves-band floor still has rooms and rubble in one of those
	# would pass a weaker check while the bug was fully intact.
	var scree := 0
	var scree_floors := 0
	for i in 30:
		var level := GameState.new(46000 + i)
		level.new_game()
		level.depth = 5
		level.build_level()
		var here := 0
		for y in level.map.height:
			for x in level.map.width:
				if level.map.get_tile(x, y) == Tiles.RUBBLE \
						and level.map.material_at(x, y) == Materials.CAVERN:
					here += 1
		scree += here
		if here > 0:
			scree_floors += 1
	check("caves grow scree (%d cells / 30 floors)" % scree, scree > 0)
	# Not merely non-zero: one lucky floor in thirty would satisfy that while
	# the band stayed barren, which is exactly the shape of the original bug.
	check("on most cave-band floors, not one lucky one (%d/30)" % scree_floors,
		scree_floors >= 20, "%d floors" % scree_floors)

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
	#
	# Swept across the bands in both directions rather than sampled at one
	# depth. This loop used to sit on depth 4 alone, which was a fair sample
	# until the bands landed and made depth 4 a CAVE floor -- caves take 0 or 1
	# vault by design, so the check quietly went from inspecting 117 doors to
	# 41 while still reporting green. A test pinned to a constant the world has
	# since moved out from under is not measuring what its name claims.
	var blind := 0
	var doors := 0
	for i in 60:
		var gs := GameState.new(66000 + i)
		gs.new_game()
		# Upper, caves, fortress and deep, descending and climbing back out.
		gs.depth = [2, 5, 8, 10, 12, 15][i % 6]
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

	# The same authored room must never appear twice on one floor.
	#
	# Nothing looked at vault NAMES until this test, which is why the suite
	# stayed green while the fortress band shipped floors carrying four copies
	# of the barracks. `vault_rects` alone cannot see it -- two identical rooms
	# are two perfectly ordinary rectangles.
	var dup_floors := 0
	var checked := 0
	var worst := 0
	for i in 80:
		var gs := GameState.new(67000 + i)
		gs.new_game()
		# Weighted towards the fortress band, which asks for the most rooms and
		# so is the only band where a small library can run out.
		gs.depth = [1, 5, 7, 8, 9, 11, 12, 13, 10, 16][i % 10]
		gs.build_level()
		checked += 1
		var seen := {}
		for n in gs.vault_names:
			seen[n] = int(seen.get(n, 0)) + 1
		var repeated := false
		for n in seen:
			worst = maxi(worst, seen[n])
			if seen[n] > 1:
				repeated = true
		if repeated:
			dup_floors += 1
	check("no floor carries the same vault twice (%d of %d floors, worst %d)"
		% [dup_floors, checked, worst], dup_floors == 0, "%d" % dup_floors)

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

	# Completable is not the same as PLAYABLE, and that gap hid a severe bug.
	#
	# The check above asks whether the stairs can be reached. On seed 66043 at
	# depth 5 the answer was yes, and the floor was still broken: a caves-band
	# level generated with no rooms, GameState treated that as degenerate and
	# carved an isolated 11x7 chamber in the corner, then put the player AND the
	# stairs inside it. Seventy-seven cells of blank box against eight hundred
	# and twenty-one cells of dungeon nobody could ever walk to. Completable,
	# winnable, and almost entirely invisible.
	#
	# So this asks the whole-floor question instead: of everything you could
	# stand on, how much can you actually get to from where you woke up?
	#
	# Measured before choosing the bar -- 960 floors across both directions came
	# back at exactly 1.0000, none below. So the bar is ALL of it. A softer 90%
	# would have tolerated a tenth of the dungeon going missing, which is the
	# same mistake as asking only about the stairs, wearing a percentage.
	#
	# Four-way rather than eight, deliberately: movement is eight-way, so this
	# can only ever under-report. A test that occasionally complains about a
	# floor that is fine costs a look; one that misses a stranded region costs
	# somebody their run.
	#
	# And measured from the PLAYER's cell, not from the largest region. "Is the
	# map one connected space?" passed on seed 66043 -- the map was fine, the
	# player was outside it.
	var cut_off := []
	for i in 30:
		for d in [1, 5, 6, 8, 10, 15]:
			var gs := GameState.new(70000 + i)
			gs.use_scratch_files("reach%d_%d" % [i, d])
			gs.new_game()
			gs.depth = d
			gs.ascending = d > GameState.MAX_DEPTH
			gs.build_level()
			var total := 0
			for y in gs.map.height:
				for x in gs.map.width:
					if gs.map.is_walkable(x, y) \
							and not Tiles.is_avoided(gs.map.get_tile(x, y)):
						total += 1
			var seen := {}
			var start := Vector2i(gs.player.x, gs.player.y)
			var stack := [start]
			seen[start] = true
			var got := 0
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				got += 1
				for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = c + dd
					if seen.has(n) or not gs.map.in_bounds(n.x, n.y):
						continue
					if not gs.map.is_walkable(n.x, n.y) \
							or Tiles.is_avoided(gs.map.get_tile(n.x, n.y)):
						continue
					seen[n] = true
					stack.append(n)
			if got < total:
				cut_off.append("seed %d d%d: %d of %d (%.0f%%)"
					% [70000 + i, d, got, total, 100.0 * float(got) / float(maxi(total, 1))])
			gs.clear_scratch_files()
	check("every walkable cell is reachable from where you start (%d floors)"
		% (30 * 6), cut_off.is_empty(),
		"%d stranded: %s" % [cut_off.size(), str(cut_off.slice(0, 4))])

	# Every BAND, not just depth 1.
	#
	# The check above only ever called new_game(), which builds the first floor
	# and nothing else -- so for the life of the project it proved depth 1 was
	# completable and quietly said nothing about anywhere else. That was
	# survivable while every floor generated the same way. The cave band ended
	# that: six or seven cavern regions instead of one is exactly the change
	# that could strand a staircase, and the old test would not have noticed.
	var by_band := {}
	for spec in [[2, false], [5, false], [8, false], [10, false],
			[5, true], [2, true]]:
		var depth := int(spec[0])
		var up: bool = spec[1]
		var stranded := 0
		for i in 40:
			var gs := GameState.new(21000 + depth * 300 + i + (700 if up else 0))
			gs.new_game()
			gs.ascending = up
			gs.depth = depth
			gs.build_level()
			var here := Vector2i(gs.player.x, gs.player.y)
			if gs.pathfinder.path(here, gs.stairs).is_empty() and here != gs.stairs:
				stranded += 1
		by_band[Bands.NAMES[Bands.of(depth if not up else GameState.MAX_DEPTH * 2 - depth)]] = stranded
		if stranded > 0:
			bad += stranded
	check("and completable in every band %s" % str(by_band), bad == 0, str(by_band))

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

	# The same collision, one helper over. STAT rows draw a label left and a
	# value right against the same edge, exactly as key rows do, and only the
	# key rows were ever checked -- so the weapon row overdrew the word "weapon"
	# with "ring of the rat  x159" and nothing in 1024 tests noticed.
	#
	# The ring is the worst case by construction: the longest item name in the
	# game sharing a row with a three-digit count.
	var bar := Sidebar.new()
	bar.font = Sidebar.ui_font()
	bar.size = Vector2(float(widths.get("Sidebar", 256.0)), 720.0)
	var rows := [
		["weapon", Item.make(&"rat_ring").display_name(), "  x220"],
		["weapon", Item.make(&"war_bow").display_name(), " r8 x40"],
		["offhand", Item.make(&"tower_shield").display_name(), ""],
	]
	var spill := []
	for row in rows:
		var value: String = bar._fit_counted(row[0], row[1], row[2])
		var lw := bar.font.get_string_size(row[0] + "  ",
			HORIZONTAL_ALIGNMENT_LEFT, -1, bar.font_size).x
		var vw := bar.font.get_string_size(value,
			HORIZONTAL_ALIGNMENT_LEFT, -1, bar.font_size).x
		if lw + vw > side_limit:
			spill.append("%s / %s (%.0f > %.0f)" % [row[0], value, lw + vw, side_limit])
		# Truncating the NAME is fine; truncating the number is not, because the
		# count is the only reason the row exists.
		if row[2] != "" and not value.ends_with(row[2]):
			spill.append("%s lost its count: %s" % [row[0], value])
	check("no stat row collides with its label", spill.is_empty(), str(spill))

	# Glyph for the kind, word for which one.
	#
	# Every equippable item must answer with a tag that actually distinguishes
	# it, because the glyph has already said the kind -- a ring row reading
	# "(ring)" would be the picture twice and the answer never.
	var want := {
		&"rat_ring": "rat", &"dagger": "dagger", &"short_sword": "short",
		&"war_axe": "war", &"mace": "mace", &"sling": "sling",
		&"short_bow": "short", &"war_bow": "war", &"buckler": "buckler",
		&"kite_shield": "kite", &"tower_shield": "tower",
		&"leather_armour": "leather", &"chain_mail": "chain",
		&"plate_mail": "plate",
	}
	var wrong := []
	var untagged := []
	for id in Item.CATALOGUE:
		if Item.CATALOGUE[id].get("slot", Item.Slot.NONE) == Item.Slot.NONE:
			continue
		var made := Item.make(id)
		if made.tag() == "":
			untagged.append(id)
		elif want.has(id) and made.tag() != want[id]:
			wrong.append("%s -> %s, wanted %s" % [id, made.tag(), want[id]])
		# The whole point of the ring's override: the rule alone would return
		# the kind, which the glyph is already drawing.
		if id == &"rat_ring" and made.tag() == "ring":
			wrong.append("the ring tagged itself with its kind")
	check("every equippable item has a tag", untagged.is_empty(), str(untagged))
	check("and it is the distinguishing word", wrong.is_empty(), str(wrong))

	# The sidebar draws these with the TEXT face, not the map's, so the icon
	# fallback has to be wired -- the same failure that once left the shrine and
	# brazier glyphs invisible, and the look panel's skull after them.
	var missing_gear := []
	for id in Item.CATALOGUE:
		if Item.CATALOGUE[id].get("slot", Item.Slot.NONE) == Item.Slot.NONE:
			continue
		var app: StringName = Item.CATALOGUE[id].get("app", &"")
		if not GlyphTheme.OVERRIDES.has(app):
			continue
		if not bar.font.has_char(int(GlyphTheme.OVERRIDES[app])):
			missing_gear.append("%s (%s)" % [id, app])
	check("the sidebar's font can draw every gear icon",
		missing_gear.is_empty(), str(missing_gear))
	bar.free()

	# The record's two columns right-align their value against the same edge the
	# label starts from, so the failure mode is the sidebar's: two strings
	# meeting in the middle. Its HEIGHT needs no test -- the panel is sized from
	# its content -- but its width is still fixed.
	var sum_col: float = (SummaryPanel.PANEL_W - SummaryPanel.PAD * 3.0) * 0.5
	var sum_worst := ""
	var sum_w := 0.0
	# Real pairings only. The first version of this crossed the longest label
	# with the longest value and failed on a row that cannot exist -- a test
	# that invents its own worst case tells you nothing about the screen.
	for row in [["braziers burned out", "999"], ["forged in embers", "999"],
			["time underground", "~99d 9h 99m"], ["hit points", "999 / 999"],
			["damage dealt", "999999"], ["   scroll of blink +2", "9999"],
			["   Amulet of the Deep", "9999"], ["   cave troll", "9999"]]:
		var a2 := font.get_string_size(row[0], HORIZONTAL_ALIGNMENT_LEFT, -1,
			SummaryPanel.font_size_default() - 1).x
		var b2 := font.get_string_size(row[1], HORIZONTAL_ALIGNMENT_LEFT, -1,
			SummaryPanel.font_size_default() - 1).x
		if a2 + b2 > sum_w:
			sum_w = a2 + b2
			sum_worst = "%s / %s" % [row[0], row[1]]
	check("no record row collides with its value",
		sum_w + 8.0 <= sum_col,
		"%.0f + gap > %.0f px -- %s" % [sum_w, sum_col, sum_worst])

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

## Every character every theme can put on the map must be in the font the map
## is actually drawn with.
##
## The distinction is the whole test. _test_symbol_theme below has always
## checked JetBrainsMono-Regular.ttf -- "the font we ship" -- but the grid
## draws with ofr_icons.ttf, a pyftsubset of it. Anything present in the first
## and absent from the second passed the test and rendered as nothing: three
## braziers and a shrine, drawn as bare coloured squares, for as long as the
## letters mode has existed. Checking the wrong font is worse than not checking,
## because it reads as coverage.
func _test_every_theme_glyph_is_drawable() -> void:
	var font := GlyphGrid.map_font()
	var missing: Array = []
	for pair in [["letters", AsciiTheme.new()], ["symbols", SymbolTheme.new()],
			["pictures", GlyphTheme.new()]]:
		var theme: RenderTheme = pair[1]
		for id in AsciiTheme.TABLE:
			var ch: String = theme.appearance(id)["ch"]
			for i in ch.length():
				var cp := ch.unicode_at(i)
				if cp == 32:
					continue
				if not _renderable(font, cp):
					missing.append("%s/%s U+%04X %s" % [pair[0], id, cp, ch])
	check("every glyph in every mode is in the font the map draws with",
		missing.is_empty(), str(missing))

## Mirrors what drawing does: the face itself, then one level of fallback.
func _renderable(font: Font, cp: int) -> bool:
	if font.has_char(cp):
		return true
	for fb in font.fallbacks:
		if fb != null and fb.has_char(cp):
			return true
	return false

func _test_symbol_theme() -> void:
	# The chain the grid draws with, not the text face. Asserting against
	# JetBrainsMono-Regular.ttf here is what hid the missing brazier and shrine
	# glyphs: both are in that file and neither is in the subset the map is
	# actually drawn from.
	var font := GlyphGrid.map_font()
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
		if not _renderable(font, ch.unicode_at(0)):
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
## Is this cell inside a hand-drawn room?
func vault_holds(gs: GameState, cell: Vector2i) -> bool:
	for vr in gs.vault_rects:
		if vr.has_point(cell):
			return true
	return false

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
						#
						# A hazard the AUTHOR put there is not a plug.
						#
						# This asks about DECORATION -- the generator scattering
						# a trap or a pit into a chokepoint at random, which is
						# a bug because nobody chose it. Inside a hand-drawn
						# room the same tile is the design: `crossway` puts a
						# trap in the doorway of the alcove holding its potion,
						# so reaching the treasure costs you the trap. That is
						# the oldest idea in the genre and the test has no
						# business calling it broken.
						#
						# The door is passable either way. A trap is a price,
						# not a wall -- the pathfinder refuses to ROUTE through
						# one, which is not the same as a player being unable to
						# walk through it, and this check had been reading the
						# first as the second.
						var authored := false
						for vr in gs.vault_rects:
							if vr.has_point(Vector2i(x, y)):
								authored = true
						var ways := 0
						for d in [Vector2i(0, -1), Vector2i(0, 1),
								Vector2i(1, 0), Vector2i(-1, 0)]:
							var n := Vector2i(x + d.x, y + d.y)
							if not m.is_walkable(n.x, n.y):
								continue
							if Tiles.is_avoided(m.get_tile(n.x, n.y)) \
									and not (authored and vault_holds(gs, n)):
								continue
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
## The ember forge.
##
## A brazier that has just died will work metal once, loudly, and is then black
## for good. The clock is the load-bearing part: without it the play is to
## clear a floor and walk back round it forging at every dead brazier, because
## noise costs nothing when nothing is alive to hear it.
func _test_ember_forge() -> void:
	var gs := _forge_arena()
	var cell := Vector2i(6, 4)
	gs.player.max_hp = 40
	gs.player.hp = 30
	# Rest it down to nothing: five turns at two hit points a turn.
	for i in 5:
		gs.player_wait()
	check("resting the brazier out spends it",
		gs.map.get_tile(cell.x, cell.y) == Tiles.BRAZIER_SPENT,
		str(gs.map.get_tile(cell.x, cell.y)))
	# The window, not the exact number. It died on the turn before this one, so
	# pinning the arithmetic here would only assert how the turn counter is
	# bookkept -- which is not what the clock is for.
	var left := int(gs.ember_until.get(cell, -1)) - gs.turns
	check("and leaves embers on a clock (%d turns left)" % left,
		left > 0 and left <= GameState.EMBER_TURNS, str(left))

	var a := Item.make(&"dagger")
	gs.give_item(a)
	gs.give_item(Item.make(&"dagger"))
	check("a dead brazier still offers a forge", gs.can_forge_here())
	check("and knows it is embers, not flame", gs.forging_in_embers())

	# Something asleep across the room, to prove the noise is real.
	var sleeper := _spawn(gs, "goblin", 13, 4)
	sleeper.alertness = Entity.Alert.ASLEEP
	gs.take_events()

	check("forging in the embers succeeds", gs.player_merge(0))
	check("the survivor gained its point",
		a.power_bonus == a.base_power_bonus + 1, str(a.power_bonus))
	check("it cost no charge, because there was none",
		not gs.brazier_charge.has(cell))
	check("the brazier is black afterwards",
		gs.map.get_tile(cell.x, cell.y) == Tiles.BRAZIER_DEAD,
		str(gs.map.get_tile(cell.x, cell.y)))
	check("and the clock is gone with it", not gs.ember_until.has(cell))

	var radius := 0
	for e in gs.take_events():
		if e["kind"] == &"noise":
			radius = int(e["radius"])
	check("hammering is loud (%d)" % radius, radius == GameState.FORGE_NOISE,
		str(radius))
	check("loud enough to be heard seven cells off",
		sleeper.alertness == Entity.Alert.AWAKE)

	# Once only.
	gs.give_item(Item.make(&"dagger"))
	gs.give_item(Item.make(&"dagger"))
	check("a black brazier forges nothing more", not gs.can_forge_here())
	check("and says so rather than failing silently",
		not gs.player_merge(gs.player.inventory.size() - 1))

	# Nothing brings it back -- not the scroll, not the shrine. That is the
	# whole price, and a way round it would make the ember forge free.
	gs.give_item(Item.make(&"scroll_light"))
	gs.player_use(gs.player.inventory.size() - 1)
	check("no scroll of light rekindles it",
		gs.map.get_tile(cell.x, cell.y) == Tiles.BRAZIER_DEAD)
	gs._invoke_shrine(Shrines.EMBERS)
	check("nor does the shrine of embers",
		gs.map.get_tile(cell.x, cell.y) == Tiles.BRAZIER_DEAD)

## The cooling ramp's one number: how much heat is left, as a fraction.
##
## The colour it becomes is the renderer's, but the curve is the sim's, and it
## is the only thing telling the player how much of the forging decision is
## left -- there is deliberately no counter on screen.
## Time, as opposed to keypresses.
## Gravestones: the first thing in the game that reads the morgue back.
## A brazier that has gone out is not a fire, and nothing may treat it as one.
##
## The shader throws sparks from cells whose tile is BRAZIER and flickers cells
## a flickering light reaches. Both routes have to agree that a spent or black
## brazier is neither -- otherwise a dead fire would go on crackling, which is
## exactly the thing the ember forge's whole design says it must not do.
func _test_dead_fires_are_dead() -> void:
	var gs := _arena(21, 11)
	gs.player.x = 5
	gs.player.y = 5
	gs.map.set_tile(8, 5, Tiles.BRAZIER)
	gs.brazier_charge[Vector2i(8, 5)] = GameState.BRAZIER_CHARGE
	gs.map.set_tile(11, 5, Tiles.BRAZIER_SPENT)
	gs.ember_until[Vector2i(11, 5)] = gs.turns + GameState.EMBER_TURNS
	gs.map.set_tile(14, 5, Tiles.BRAZIER_DEAD)
	gs._gather_lights()

	var lit_at := {}
	var flickering := 0
	for src in gs.static_lights:
		lit_at[Vector2i(src.x, src.y)] = true
		if src.flickers:
			flickering += 1
	check("a burning brazier is a light", lit_at.has(Vector2i(8, 5)))
	check("and it flickers", flickering == 1, str(flickering))
	check("a spent brazier is not a light, hot embers or not",
		not lit_at.has(Vector2i(11, 5)))
	check("a black brazier is not a light", not lit_at.has(Vector2i(14, 5)))

	# The three states are three different tiles, which is what lets the shader
	# tell them apart at all -- it keys sparks on the tile id.
	check("the three states are three distinct tiles",
		Tiles.BRAZIER != Tiles.BRAZIER_SPENT
		and Tiles.BRAZIER_SPENT != Tiles.BRAZIER_DEAD
		and Tiles.BRAZIER != Tiles.BRAZIER_DEAD)

	# And when the last live one goes out, the floor holds no flame at all.
	gs.map.set_tile(8, 5, Tiles.BRAZIER_SPENT)
	gs.brazier_charge.erase(Vector2i(8, 5))
	gs._gather_lights()
	var still_burning := 0
	for src in gs.static_lights:
		if src.flickers:
			still_burning += 1
	check("once the last one gutters, nothing on the floor flickers",
		still_burning == 0, str(still_burning))

## Floor themes: the cave band, and the rule that the climb mirrors the descent.
func _test_cave_band() -> void:
	# The fold is what makes "corrupted, not reversed" free -- descending floor
	# 5 and climbing floor 5 are effective 5 and 15, and both are caves without
	# either side knowing which way you are going.
	for eff in [1, 2, 3]:
		check_silent(Bands.of(eff) == Bands.UPPER)
	for eff in [4, 5, 6, 14, 15, 16]:
		check_silent(Bands.is_caves(eff))
	for eff in [7, 8, 9, 11, 12, 13]:
		check_silent(Bands.of(eff) == Bands.FORTRESS)
	check_gathered("the bands fold around the bottom")
	check("depth 10 is its own place", Bands.of(10) == Bands.DEEP)
	check("and the climb is the corrupted half",
		Bands.is_corrupted(14) and not Bands.is_corrupted(6))

	# Caves going down, darker caves coming back, ordinary light everywhere else.
	var gs := GameState.new(4)
	gs.new_game()
	gs.depth = 5
	gs.build_level()
	check("a cave floor shortens the torch (%d)" % gs.torch_radius(),
		gs.torch_radius() == GameState.CAVE_TORCH)
	gs.ascending = true
	gs.build_level()
	check("and the corrupted one shortens it further (%d)" % gs.torch_radius(),
		gs.torch_radius() == GameState.CORRUPT_TORCH)
	check("which is still more than a doused torch",
		GameState.CORRUPT_TORCH > GameState.DOUSED_RADIUS)
	gs.ascending = false
	gs.depth = 2
	gs.build_level()
	check("ordinary floors are unchanged",
		gs.torch_radius() == GameState.TORCH_RADIUS)

	# The flare is the counterplay, and it must not be shortened with everything
	# else or the dark band would have no answer.
	gs.depth = 5
	gs.build_level()
	gs.torch_flare = GameState.FLARE_TURNS
	gs.update_vision()
	check("a flare beats the dark outright (%d vs %d)"
		% [gs.player.light.radius, GameState.CAVE_TORCH],
		gs.player.light.radius > GameState.TORCH_RADIUS,
		str(gs.player.light.radius))

	# The band trades built ground for cavern, and braziers go with the rooms.
	# Fungus is what the terrain gives back, and it is a LIGHT as much as it is
	# a hit point -- which is the whole reason the band can afford to be dark.
	var cave_fungus := 0
	var cave_rooms := 0
	var plain_fungus := 0
	var plain_rooms := 0
	for i in 14:
		var c := GameState.new(6100 + i)
		c.new_game()
		c.depth = 5
		c.build_level()
		cave_rooms += c.room_rects.size()
		var p := GameState.new(6200 + i)
		p.new_game()
		p.depth = 2
		p.build_level()
		plain_rooms += p.room_rects.size()
		for y in GameState.MAP_H:
			for x in GameState.MAP_W:
				if c.map.get_tile(x, y) == Tiles.FUNGUS:
					cave_fungus += 1
				if p.map.get_tile(x, y) == Tiles.FUNGUS:
					plain_fungus += 1
	check("caves have fewer rooms (%d vs %d)" % [cave_rooms, plain_rooms],
		cave_rooms < plain_rooms)
	check("and more fungus to see by (%d vs %d)" % [cave_fungus, plain_fungus],
		cave_fungus > plain_fungus)

## The three launchers are three different jobs, and reach is what separates
## them.
func _test_launcher_reach() -> void:
	var sling := Item.make(&"sling")
	var short_bow := Item.make(&"short_bow")
	var war_bow := Item.make(&"war_bow")
	check("a sling is the shortest-armed (%d)" % sling.range_bonus,
		sling.range_bonus < short_bow.range_bonus, str(sling.range_bonus))
	check("and a war bow the longest (%d)" % war_bow.range_bonus,
		war_bow.range_bonus > short_bow.range_bonus)
	# The gap has to be worth noticing, or a sling simply replaces a bow --
	# which is what play reported before this was widened.
	check("the gap to a bow is at least three cells (%d)"
		% (short_bow.range_bonus - sling.range_bonus),
		short_bow.range_bonus - sling.range_bonus >= 3,
		str(short_bow.range_bonus - sling.range_bonus))
	# Damage is NOT the lever here and must not quietly become one: a sling is
	# already the weakest launcher and most of its shot is the player's arm.
	check("a sling is still the weakest launcher",
		sling.power_bonus < short_bow.power_bonus
		and short_bow.power_bonus < war_bow.power_bonus)
	# Free ammunition is the sling's whole reason to exist.
	check("but it carries the most ammunition",
		sling.ammo_max > war_bow.ammo_max, str(sling.ammo_max))

## Generation must not depend on the morgue.
##
## Gravestones are read from the death log, and the death log GROWS -- so
## drawing their positions from the run's own rng made the number of draws
## depend on how many past deaths matched the floor. The same seed then built a
## different dungeon once a player had died a few times, which breaks the
## promise _test_generation_is_deterministic exists to keep.
##
## It surfaced as a flaky test rather than a bug report: the vault-door check
## reported 97 doors one run and 99 the next on identical seeds. A test that
## disagrees with itself is usually telling the truth about something.
func _test_generation_ignores_the_morgue() -> void:
	GameState.clear_scratch_files()
	var before := _floor_fingerprint()

	for i in 12:
		var d := GameState.new(1)
		d.new_game()
		d.depth = 1 + (i % 6)
		d.player.level = 3
		d.death_cause = "killed by a kobold"
		d.write_morgue()

	var after := _floor_fingerprint()
	check("a floor generates the same however many are buried in it",
		before == after, "%s vs %s" % [before, after])

	# And graves themselves still appear -- the fix must not have simply
	# stopped them being placed.
	var gs := GameState.new(4242)
	gs.new_game()
	gs.depth = 1
	gs.build_level()
	check("graves are still buried (%d)" % gs.grave_at.size(),
		not gs.grave_at.is_empty(), str(gs.grave_at.size()))

	# And they come with something to step on, or the rising can never be
	# triggered: bones carry seven cells and waiting for the terrain pass to
	# drop some beside a grave by luck is waiting a long time.
	var with_bones := 0
	var graves := 0
	for i in 40:
		var g := GameState.new(7100 + i)
		g.new_game()
		g.depth = 1
		g.build_level()
		for cell: Vector2i in g.grave_at:
			graves += 1
			var near := 0
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					if g.map.get_tile(cell.x + dx, cell.y + dy) == Tiles.BONES:
						near += 1
			if near > 0:
				with_bones += 1
	# Almost all, not all. The scatter is a roll and it only writes on plain
	# floor, so a stone that lands hemmed in by water or masonry gets none --
	# which is correct. Asserting 100% made this a test of luck: it passed at
	# 80 of 80 one day and failed at 78 the next without the mechanic changing.
	check("a headstone comes with bone litter (%d of %d)" % [with_bones, graves],
		graves > 0 and with_bones >= int(graves * 0.9),
		"%d of %d" % [with_bones, graves])

## A cheap summary of what a set of seeded floors produced.
func _floor_fingerprint() -> String:
	var walls := 0
	var doors := 0
	var mobs := 0
	for i in 8:
		var gs := GameState.new(66000 + i)
		gs.new_game()
		gs.depth = 4
		gs.build_level()
		mobs += gs.entities.size()
		for y in GameState.MAP_H:
			for x in GameState.MAP_W:
				var t := gs.map.get_tile(x, y)
				if t == Tiles.WALL:
					walls += 1
				elif t == Tiles.DOOR_CLOSED or t == Tiles.DOOR_OPEN:
					doors += 1
	return "w=%d d=%d m=%d" % [walls, doors, mobs]

## How much of a floor you get to keep in your head.
func _test_memory_by_band() -> void:
	var grid := GlyphGrid.new()
	var gs := GameState.new(9)
	gs.new_game()
	grid.state = gs

	gs.depth = 2
	check("ordinary floors are remembered whole",
		is_equal_approx(grid._memory_strength(), 1.0),
		str(grid._memory_strength()))
	gs.depth = 5
	check("caves are remembered dimly (%.2f)" % grid._memory_strength(),
		grid._memory_strength() > 0.0 and grid._memory_strength() < 1.0)
	gs.ascending = true
	check("and the corrupted ones not at all",
		is_zero_approx(grid._memory_strength()), str(grid._memory_strength()))
	gs.depth = 2
	check("but only in that band -- the climb out is remembered again",
		is_equal_approx(grid._memory_strength(), 1.0),
		str(grid._memory_strength()))
	grid.free()

	# Whatever the floor forgets, it does not forget the way on or the way out.
	# STAIRS_UP had no exemption until this band needed one, which meant the
	# staircase you climb TOWARDS was the one thing on the map that dimmed.
	var src := FileAccess.get_file_as_string("res://src/render/glyph_grid.gd")
	check("both staircases are exempt from memory dimming",
		src.contains("tile == Tiles.STAIRS_DOWN or tile == Tiles.STAIRS_UP"))

## Caves hold what dens in caves, and the same field does both ends of the band.
func _test_cave_dwellers() -> void:
	var shallow_cave := {}
	var shallow_plain := {}
	var deep_cave := {}
	for i in 30:
		var c := GameState.new(62000 + i)
		c.new_game()
		c.depth = 5
		c.build_level()
		for e in c.entities:
			if not e.is_player:
				shallow_cave[e.name] = int(shallow_cave.get(e.name, 0)) + 1
		var p := GameState.new(62500 + i)
		p.new_game()
		p.depth = 8
		p.build_level()
		for e in p.entities:
			if not e.is_player:
				shallow_plain[e.name] = int(shallow_plain.get(e.name, 0)) + 1
		var d := GameState.new(63000 + i)
		d.new_game()
		d.ascending = true
		d.depth = 5
		d.build_level()
		for e in d.entities:
			if not e.is_player:
				deep_cave[e.name] = int(deep_cave.get(e.name, 0)) + 1

	# ONE multiplier, two very different results, because the depth pool it
	# multiplies differs: vermin are what is eligible at effective 5, and
	# dragons are what is eligible at 15.
	check("caves crawl with bats (%d)" % int(shallow_cave.get("cave bat", 0)),
		int(shallow_cave.get("cave bat", 0)) > 0)
	check("and the deep ones hold dragons (%d)"
		% int(deep_cave.get("young dragon", 0)),
		int(deep_cave.get("young dragon", 0)) > 0)

	# Built things keep to built places. The slinger is a kobold with a sling,
	# not a cave dweller, and the wizard belongs to a dungeon.
	var cave_total := 0
	for k in shallow_cave:
		cave_total += int(shallow_cave[k])
	var plain_total := 0
	for k in shallow_plain:
		plain_total += int(shallow_plain[k])
	var wizard_cave := float(deep_cave.get("wizard", 0))
	var deep_total := 0
	for k in deep_cave:
		deep_total += int(deep_cave[k])
	check("wizards keep out of caves (%.1f%% vs the floor's mix)"
		% (100.0 * wizard_cave / maxf(1.0, float(deep_total))),
		wizard_cave / maxf(1.0, float(deep_total)) < 0.06,
		str(wizard_cave))

	# Rabbits are commoner where the potions are not, and the cap lifts with
	# them or the extra weight would only be rolled and refused.
	check("more rabbits in the corrupted caves (%d) than a plain floor (%d)"
		% [int(deep_cave.get("rabbit", 0)), int(shallow_plain.get("rabbit", 0))],
		int(deep_cave.get("rabbit", 0)) > int(shallow_plain.get("rabbit", 0)))

	# And their meat keeps pace with the bar it has to fill.
	# Arenas, not generated floors. The first version of this dropped a rabbit
	# at (4,4) on a real map, which was a wall -- _drop_meat found nowhere to
	# put the haunch and the test read a genuine mechanic as broken.
	#
	# effective_depth() reads only `ascending` and `depth`, so the arena's open
	# floor can be told it is deep without being rebuilt.
	var shallow := _arena(21, 11)
	var deep := _arena(21, 11)
	deep.ascending = true
	deep.depth = 2
	var bun_a := _spawn(shallow, "rabbit", 5, 5)
	var bun_b := _spawn(deep, "rabbit", 5, 5)
	shallow.ground = []
	deep.ground = []
	shallow._drop_loot(bun_a)
	deep._drop_loot(bun_b)
	var a_val := 0
	var b_val := 0
	for it in shallow.ground:
		if it.id == &"meat":
			a_val = it.effective_magnitude()
	for it in deep.ground:
		if it.id == &"meat":
			b_val = it.effective_magnitude()
	check("meat is worth more the deeper it is found (%d then %d)" % [a_val, b_val],
		b_val > a_val, "%d vs %d" % [a_val, b_val])

## The shrine that calls out gets a gong, and only it.
func _test_shrine_voices() -> void:
	check("every shrine has a bell", Synth.SOUNDS.has(&"pray"))
	check("and the loud one has a gong", Synth.SOUNDS.has(&"gong"))
	check("the gong rings longer than the bell",
		float(Synth.SOUNDS[&"gong"]["voices"][0]["len"])
		> float(Synth.SOUNDS[&"pray"]["voices"][0]["len"]))
	check("and lower",
		float(Synth.SOUNDS[&"gong"]["voices"][0]["f0"])
		< float(Synth.SOUNDS[&"pray"]["voices"][0]["f0"]))

	# A bell's partials sit near whole-number ratios and give it a pitch; a
	# gong's do not, which is the whole difference between the two sounds.
	var g: Array = Synth.SOUNDS[&"gong"]["voices"]
	var base := float(g[0]["f0"])
	var harmonic := 0
	for i in range(1, 4):
		var ratio := float(g[i]["f0"]) / base
		if absf(ratio - roundf(ratio)) < 0.08:
			harmonic += 1
	check("the gong's partials are inharmonic (%d of 3 near whole ratios)"
		% harmonic, harmonic == 0, str(harmonic))

	var deck := SoundDeck.new()
	var plain: Dictionary = deck.choose([{"kind": &"pray", "to": Vector2i(1, 1)}])["now"]
	check("an ordinary shrine chimes", plain.has(&"pray"))
	check("and does not gong", not plain.has(&"gong"))

	var vigil: Dictionary = deck.choose([
		{"kind": &"pray", "to": Vector2i(1, 1)},
		{"kind": &"noise", "to": Vector2i(1, 1), "radius": 24, "cause": &"clamour"},
	])["now"]
	check("the shrine that calls out gongs", vigil.has(&"gong"))
	# Both at once was mud -- the gong replaces the chime rather than layering.
	check("and does not also chime", not vigil.has(&"pray"))
	deck.free()

## Noise is drawn as well as heard, so the rules and the picture must agree.
func _test_noise_is_drawn() -> void:
	var gs := _arena(31, 15)
	gs.player.x = 15
	gs.player.y = 7

	# Every noise the simulation makes carries what the ring needs to draw it.
	gs.take_events()
	gs._make_noise(Vector2i(15, 7), GameState.COMBAT_NOISE, &"combat")
	var found := {}
	for e in gs.take_events():
		if e["kind"] == &"noise":
			found = e
	check("a noise event carries where it happened", found.has("to"))
	check("and how far it reached",
		int(found.get("radius", -1)) == GameState.COMBAT_NOISE,
		str(found.get("radius", -1)))

	# The shrine of the vigil is the loudest thing in the game and used to make
	# no sound at all in the event stream -- it wakes the floor directly.
	var shrine := _arena(31, 15)
	shrine.player.x = 15
	shrine.player.y = 7
	var sleeper := _spawn(shrine, "goblin", 25, 12)
	sleeper.alertness = Entity.Alert.ASLEEP
	shrine.take_events()
	shrine._invoke_shrine(Shrines.VIGIL)
	var cry := {}
	for e in shrine.take_events():
		if e["kind"] == &"noise" and e["cause"] == &"clamour":
			cry = e
	check("the vigil shrine now cries out where it can be drawn", not cry.is_empty())
	check("and it is far louder than a sword blow (%d vs %d)"
		% [int(cry.get("radius", 0)), GameState.COMBAT_NOISE],
		int(cry.get("radius", 0)) > GameState.COMBAT_NOISE * 2)
	check("the shrine still wakes the floor", sleeper.alertness == Entity.Alert.AWAKE)

	# The cry must not double up on the waking the shrine already did, nor add
	# a second line to the log about it.
	var quiet := true
	for entry in shrine.msg_log.entries:
		if String(entry["text"]).begins_with("The noise carries"):
			quiet = false
	check("and says nothing extra about it", quiet)

## The effects setting, which exists for accessibility before taste.
func _test_effects_modes() -> void:
	var was := Effects.mode()

	check("three settings, not an on/off", Effects.mode_count() == 3,
		str(Effects.mode_count()))
	check("it starts on the middle one -- what the game has always done",
		Effects.Mode.TIMERS == 1)

	Effects.set_mode(Effects.Mode.NONE)
	check("still: nothing moves", not Effects.any())
	check("still: no CPU timers", not Effects.timers())
	check("still: no shader", not Effects.shaders())

	Effects.set_mode(Effects.Mode.TIMERS)
	check("simple: something moves", Effects.any())
	check("simple: the CPU timers run", Effects.timers())
	check("simple: but not the shader", not Effects.shaders())

	Effects.set_mode(Effects.Mode.SHADERS)
	check("full: the shader runs", Effects.shaders())
	# The two must never both run: braziers would be animated twice, and the
	# player could not tell which they were seeing.
	check("full: and the CPU timers stand down", not Effects.timers())

	# Cycling wraps and names itself.
	Effects.set_mode(Effects.Mode.SHADERS)
	var said := Effects.cycle()
	check("cycling wraps round to still", Effects.mode() == Effects.Mode.NONE,
		str(Effects.mode()))
	check("and says which one it landed on", said.contains("still"), said)

	# It survives a restart, like the view mode it sits beside.
	Effects.set_mode(Effects.Mode.NONE)
	Effects.load_settings()
	check("the choice persists", Effects.mode() == Effects.Mode.NONE,
		str(Effects.mode()))

	Effects.set_mode(was)

## The rabbit: the only thing in the dungeon that wants what you want.
func _test_rabbit() -> void:
	var gs := _arena(31, 11)
	gs.player.x = 5
	gs.player.y = 5
	var bun := _spawn(gs, "rabbit", 10, 5)
	check("a rabbit is faster than you (%d)" % bun.speed, bun.speed > 100)
	check("and does not fight", bun.power == 0, str(bun.power))

	# Seen, it runs. This is the half that makes a bow the answer.
	var before := Los.steps(bun.x, bun.y, 5, 5)
	gs._take_ai_turn(bun)
	check("in sight of you it bolts (%d -> %d)"
		% [before, Los.steps(bun.x, bun.y, 5, 5)],
		Los.steps(bun.x, bun.y, 5, 5) > before)

	# Out of sight, it goes for the mushrooms.
	var farm := _arena(31, 11)
	farm.player.x = 28
	farm.player.y = 9
	farm.map.set_tile(6, 3, Tiles.FUNGUS)
	farm._gather_lights()
	var lit := farm.static_lights.size()
	check("a fungus is a light source", lit > 0, str(lit))
	var forager := _spawn(farm, "rabbit", 6, 3)
	# Standing on supper: it stops, which is the window you get to shoot it.
	farm._take_ai_turn(forager)
	check("standing on fungus it puts its head down", forager.busy > 0,
		str(forager.busy))
	check("and it is a real pause, not an instant", forager.busy >= 1)
	for i in GameState.RABBIT_MEAL + 1:
		farm._take_ai_turn(forager)
	check("then it swallows", forager.meal == 1, str(forager.meal))
	check("the fungus is gone",
		farm.map.get_tile(6, 3) != Tiles.FUNGUS)
	check("and so is its light -- that is the part that stings",
		farm.static_lights.size() < lit,
		"%d -> %d" % [lit, farm.static_lights.size()])

	# Three mouthfuls and it stops running.
	var fed := _arena(31, 11)
	fed.player.x = 28
	fed.player.y = 9
	var glut := _spawn(fed, "rabbit", 6, 3)
	for i in GameState.RABBIT_TURNS:
		fed.map.set_tile(glut.x, glut.y, Tiles.FUNGUS)
		fed._rabbit_swallows(glut)
	check("three mouthfuls and it turns (%s)" % glut.name,
		glut.name == "killer rabbit", glut.name)
	check("it stops fleeing and starts hunting", glut.ai == &"hunter", str(glut.ai))
	check("and it can actually hurt you now", glut.power > 0, str(glut.power))
	check("its picture changes with it", glut.appearance == &"killer_rabbit")

	# Half a brazier plus a mushroom's worth for each one it got to first.
	#
	# This test used to assert the opposite -- that meat could never exceed what
	# the rabbit ate. That rule came from an argument about incentives which
	# play overturned: the chase costs turns, noise and risk that the argument
	# left out. Kept as a test rather than deleted so the number is pinned.
	var kill := _arena(21, 11)
	kill.player.x = 5
	kill.player.y = 5
	var fat := _spawn(kill, "rabbit", 6, 5)
	fat.meal = 3
	kill.ground = []
	kill._drop_loot(fat)
	var meat: Item = null
	for it in kill.ground:
		if it.id == &"meat":
			meat = it
	check("killing it leaves meat", meat != null)
	if meat != null:
		check("worth half a brazier plus what it ate (%d for %d)"
			% [meat.effective_magnitude(), fat.meal],
			meat.effective_magnitude() == GameState.MEAT_BASE + fat.meal,
			str(meat.effective_magnitude()))
		check("and that is worth the arrow",
			meat.effective_magnitude() >= GameState.BRAZIER_CHARGE / 2,
			str(meat.effective_magnitude()))
		# An unfed one is still worth killing, just not worth hunting.
		var lean := _spawn(kill, "rabbit", 7, 5)
		kill.ground = []
		kill._drop_loot(lean)
		for it in kill.ground:
			if it.id == &"meat":
				check("an unfed one is worth the base alone",
					it.effective_magnitude() == GameState.MEAT_BASE,
					str(it.effective_magnitude()))

	# It eats, so it must be able to reach food on every floor it appears on.
	var seen := 0
	for i in 40:
		var g := GameState.new(52000 + i)
		g.new_game()
		g.depth = 1 + (i % 10)
		g.build_level()
		var here := 0
		for e in g.entities:
			if e.name == "rabbit":
				here += 1
		seen += here
		# Three, not two. `max_per_floor` is 2 and the cave band lifts it by one
		# for things that belong there -- the bestiary comment says so outright:
		# "three rabbits is a fifth of them by arithmetic alone, and three is
		# the cap we chose". This asserted two and had been failing silently
		# since the lift was added, invisible because nothing reported it.
		check_silent(here <= 3)
	check("rabbits turn up across the dungeon (%d in 40 floors)" % seen, seen > 0)
	# Gathered above and never reported until now. An unreported check_silent
	# is worse than none: it cannot fail the suite itself, and it leaves
	# `_silent_ok` false for whoever reports NEXT -- which is how a perfectly
	# correct test of the undead came to fail for a reason about rabbits.
	check_gathered("and never more than three on a floor")

	var kept := Entity.from_dict(glut.to_dict())
	check("a half-fed rabbit survives a suspend",
		kept.meal == glut.meal and kept.busy == glut.busy)

## The banshee: the monster that answers the player's best strategy.
## The bear moves you, which nothing else does. Every edge here is a way that
## could go wrong quietly: a shove that works but leaves the view stale, or one
## that helpfully drops you down a pit.
## The dead come back wearing what you lost.
func _test_graves_raise_the_dead() -> void:
	# --- the morgue keeps the gear, and every older line still parses -------
	var old_line := "2026-09-03 23:09:49  level 1  killed by a kobold on depth 1, empty-handed, after 228 turns"
	var mid_line := old_line + "; 62 slain, most often cave bat"
	var new_line := mid_line + "; bearing short bow +1, chain mail +2"
	var bare_gear := old_line + "; bearing war axe"

	var a := Morgue.parse(old_line)
	var b := Morgue.parse(mid_line)
	var c := Morgue.parse(new_line)
	var d := Morgue.parse(bare_gear)
	check("a death from before the run recorder still parses", int(a.get("level", 0)) == 1)
	check("and carries no gear", not a.has("gear"))
	check("a death from before gear was logged still parses",
		int(b.get("slain", 0)) == 62 and not b.has("gear"))
	check("the nemesis does not swallow the gear clause",
		String(b.get("nemesis", "")) == "cave bat"
			and String(c.get("nemesis", "")) == "cave bat")
	check("gear is read back off the line (%s)" % str(c.get("gear", [])),
		c.get("gear", []).size() == 2)
	check("gear parses without a run record", d.get("gear", []).size() == 1)

	# --- and turns back into real items ------------------------------------
	var bow := Item.from_display_name("short bow +1")
	check("a display name rebuilds its item", bow != null and bow.id == &"short_bow")
	check("with its upgrades on it", bow != null and bow.upgrade_level() == 1)
	var plain := Item.from_display_name("short bow")
	check("an unenchanted name rebuilds too",
		plain != null and plain.upgrade_level() == 0)
	check("and something the catalogue never heard of is nothing",
		Item.from_display_name("sword of nonsense +3") == null)

	# --- a stone with gear answers bones ------------------------------------
	var armed := {"level": 7, "cause": "killed by an orc", "depth": 7,
		"turns": 900, "gear": ["short bow +1", "chain mail +2"]}
	var poor := {"level": 2, "cause": "killed by a rat", "depth": 7, "turns": 90}

	var rose := 0
	var twice := 0
	for i in 60:
		var gs := _arena(25, 13)
		gs.rng = RandomNumberGenerator.new()
		gs.rng.seed = 4000 + i
		gs.player.x = 6
		gs.player.y = 6
		gs.map.set_tile(8, 6, Tiles.GRAVE)
		gs.grave_at[Vector2i(8, 6)] = armed
		gs._make_noise(Vector2i(6, 6), 7)
		var up := 0
		for e in gs.entities:
			if e.risen:
				up += 1
		if up > 0:
			rose += 1
			# A second crunch must never produce a second one.
			gs._make_noise(Vector2i(6, 6), 7)
			var after := 0
			for e in gs.entities:
				if e.risen:
					after += 1
			if after > up:
				twice += 1
	check("bones wake an armed grave sometimes (%d of 60)" % rose,
		rose > 5 and rose < 55, "%d" % rose)
	check("but never twice on one floor", twice == 0, "%d" % twice)

	# --- a stone with nothing on it stays shut ------------------------------
	var quiet := 0
	for i in 60:
		var gs := _arena(25, 13)
		gs.rng = RandomNumberGenerator.new()
		gs.rng.seed = 7000 + i
		gs.player.x = 6
		gs.player.y = 6
		gs.map.set_tile(8, 6, Tiles.GRAVE)
		gs.grave_at[Vector2i(8, 6)] = poor
		gs._make_noise(Vector2i(6, 6), 7)
		for e in gs.entities:
			if e.risen:
				quiet += 1
	check("a grave with nothing in it never rises", quiet == 0, "%d" % quiet)

	# --- and only these two noises do it ------------------------------------
	var wrong := 0
	for i in 60:
		for cause in [&"combat", &"forge", &"clamour"]:
			var gs := _arena(25, 13)
			gs.rng = RandomNumberGenerator.new()
			gs.rng.seed = 9000 + i
			gs.player.x = 6
			gs.player.y = 6
			gs.map.set_tile(8, 6, Tiles.GRAVE)
			gs.grave_at[Vector2i(8, 6)] = armed
			gs._make_noise(Vector2i(6, 6), 7, cause)
			for e in gs.entities:
				if e.risen:
					wrong += 1
	check("swinging a sword does not wake the dead", wrong == 0, "%d" % wrong)

	# --- a wail does, though -----------------------------------------------
	var wailed := 0
	for i in 60:
		var gs := _arena(25, 13)
		gs.rng = RandomNumberGenerator.new()
		gs.rng.seed = 11000 + i
		gs.player.x = 6
		gs.player.y = 6
		gs.map.set_tile(8, 6, Tiles.GRAVE)
		gs.grave_at[Vector2i(8, 6)] = armed
		gs._make_noise(Vector2i(10, 6), 7, &"wail")
		for e in gs.entities:
			if e.risen:
				wailed += 1
	check("a banshee wakes them too (%d of 60)" % wailed, wailed > 5)

	# --- it is wearing the gear, and hands all of it back -------------------
	var gs2 := _arena(25, 13)
	gs2.player.x = 6
	gs2.player.y = 6
	gs2.map.set_tile(8, 6, Tiles.GRAVE)
	gs2.grave_at[Vector2i(8, 6)] = armed
	gs2._raise_from(Vector2i(8, 6))
	var dead: Entity = null
	for e in gs2.entities:
		if e.risen:
			dead = e
	check("the risen dead is armed", dead != null and dead.equipped.size() == 2)
	check("and costs more than a bare skeleton (%d)" % (dead.threat if dead else 0),
		dead != null and dead.threat > 12)
	check("the stone STAYS while its occupant is up",
		gs2.map.get_tile(8, 6) == Tiles.GRAVE
			and gs2.grave_at.has(Vector2i(8, 6)))
	check("and it is still readable mid-fight",
		Morgue.epitaph(gs2.grave_at[Vector2i(8, 6)]).size() > 0)
	check("and a floor only gives up one", gs2.grave_risen)
	check("the floor remembers which stone woke",
		gs2.risen_grave == Vector2i(8, 6))

	gs2.ground = []
	dead.hp = 0
	dead.alive = false
	gs2._drop_loot(dead)
	check("it hands back everything it carried (%d items)" % gs2.ground.size(),
		gs2.ground.size() == 2, "%d" % gs2.ground.size())

	# Put down, and the stone settles -- but the morgue line is untouched.
	gs2._settle_the_grave()
	check("the stone goes once the fight is won",
		gs2.map.get_tile(8, 6) != Tiles.GRAVE
			and not gs2.grave_at.has(Vector2i(8, 6)))
	check("and the floor stops pointing at it",
		gs2.risen_grave == Vector2i(-1, -1))

	# --- and the flag survives a suspend ------------------------------------
	var back := GameState.new(1)
	back.new_game()
	back.apply_dict(gs2.to_dict())
	check("one-per-floor survives a suspend", back.grave_risen)

	# --- reclaiming crosses it off for good, without losing the line --------
	#
	# Against a SCRATCH morgue, never the player's own. This test writes to the
	# file, which is the one file in the game that cannot be regenerated.
	# Switched, then switched BACK below: use_scratch_files sets statics, so
	# leaving them pointed here would send every later test's morgue writes to
	# this file. Same shape as the static vault library above.
	GameState.use_scratch_files("reclaim_test")
	GameState.clear_scratch_files()
	var written := "2026-09-09 20:00:00  level 7  killed by an orc on depth 7, empty-handed, after 900 turns; bearing short bow +1"
	var keep := "2026-09-09 20:01:00  level 3  killed by a bat on depth 3, empty-handed, after 120 turns"
	var mf := FileAccess.open(GameState.MORGUE_PATH, FileAccess.WRITE)
	mf.store_line(written)
	mf.store_line(keep)
	mf.close()

	var before := Morgue.records(GameState.MORGUE_PATH)
	check("the scratch morgue holds both deaths", before.size() == 2)
	check("and one of them is armed", before[0].has("gear"))
	check("which has not been answered for yet", not before[0].has("reclaimed"))

	check("marking one succeeds",
		Morgue.mark_reclaimed(GameState.MORGUE_PATH, written))
	var after := Morgue.records(GameState.MORGUE_PATH)
	check("nothing was deleted (%d rows)" % after.size(), after.size() == 2)
	check("the answered death is marked", after[0].get("reclaimed", false))
	check("and still remembers what it carried", after[0].has("gear"))
	check("the other death is untouched", not after[1].has("reclaimed"))
	check("marking twice is harmless",
		Morgue.mark_reclaimed(GameState.MORGUE_PATH, after[0]["line"])
			and Morgue.records(GameState.MORGUE_PATH).size() == 2)
	check("a line the morgue never held is refused",
		not Morgue.mark_reclaimed(GameState.MORGUE_PATH, "not in this file"))
	check("the stone says it has been answered for",
		"already answered for" in Morgue.epitaph(after[0]))

	# Each piece on its own line, short enough for the look panel not to cut
	# it. The panel is roughly 24 characters wide at the shipped font size, and
	# "buried with dagger, lea.." is what comma-joining produced in play.
	var stone := Morgue.epitaph({"level": 7, "cause": "killed by an orc",
		"depth": 7, "turns": 900,
		"gear": ["war bow +2", "plate mail +1", "tower shield"]})
	check("the header names no items", "buried with" in stone)
	check("and each piece gets its own line",
		"  war bow +2" in stone and "  plate mail +1" in stone
			and "  tower shield" in stone)
	var longest := 0
	for line: String in stone:
		longest = maxi(longest, line.length())
	check("no epitaph line runs long (%d chars)" % longest, longest <= 26,
		"%d" % longest)

	# And a marked record never rises again, however loud you are.
	var settled := 0
	for i in 40:
		var gs3 := _arena(25, 13)
		gs3.rng = RandomNumberGenerator.new()
		gs3.rng.seed = 13000 + i
		gs3.player.x = 6
		gs3.player.y = 6
		gs3.map.set_tile(8, 6, Tiles.GRAVE)
		gs3.grave_at[Vector2i(8, 6)] = after[0]
		gs3._make_noise(Vector2i(6, 6), 7)
		for e in gs3.entities:
			if e.risen:
				settled += 1
	check("an answered grave never rises again", settled == 0, "%d" % settled)
	GameState.clear_scratch_files()
	GameState.use_scratch_files("tests")
	check("the suite's own scratch paths are back",
		GameState.MORGUE_PATH.contains("scratch_tests_"))

	# A fight interrupted by a suspend has to come back still owed.
	var mid := _arena(25, 13)
	mid.map.set_tile(8, 6, Tiles.GRAVE)
	mid.grave_at[Vector2i(8, 6)] = armed
	mid._raise_from(Vector2i(8, 6))
	var resumed := GameState.new(1)
	resumed.new_game()
	resumed.apply_dict(mid.to_dict())
	check("an unfinished fight remembers its stone",
		resumed.risen_grave == Vector2i(8, 6))

## The legend shows what you have MET, and nothing else.
func _test_bestiary_is_earned() -> void:
	# Against a scratch file, never the player's own record. Restored below.
	BestiaryLog.use_path("user://scratch_bestiary_test.txt")
	BestiaryLog.clear_scratch()

	check("a fresh record knows nothing", BestiaryLog.count() == 0)
	check("and admits it", not BestiaryLog.knows(&"dragon"))

	check("a first sighting is news", BestiaryLog.note(&"goblin"))
	check("and a second is not", not BestiaryLog.note(&"goblin"))
	check("but it is remembered", BestiaryLog.knows(&"goblin"))
	check("without inventing neighbours", not BestiaryLog.knows(&"orc"))
	check("the player is never an entry", not BestiaryLog.note(&"player"))

	# It survives the process, which is the whole point of all-time.
	BestiaryLog.note(&"bear")
	BestiaryLog._loaded = false
	BestiaryLog._seen = {}
	check("it survives being forgotten and reloaded (%d)" % BestiaryLog.count(),
		BestiaryLog.knows(&"goblin") and BestiaryLog.knows(&"bear"))

	# Seeing one on a real floor records it, through update_vision.
	var gs := _arena(21, 9)
	gs.player.x = 5
	gs.player.y = 4
	var seen_before := BestiaryLog.knows(&"skeleton")
	check("the skeleton is a stranger to begin with", not seen_before)
	_spawn(gs, "skeleton", 7, 4)
	gs.update_vision()
	check("looking at one is enough to learn it", BestiaryLog.knows(&"skeleton"))

	# And something out of sight teaches nothing.
	var hidden := _arena(21, 9)
	hidden.player.x = 2
	hidden.player.y = 2
	_spawn(hidden, "cave giant", 19, 7)
	# _arena hands back a fully lit map, which is convenient for every other
	# test and exactly wrong for this one.
	hidden.map.clear_visible()
	hidden._note_sightings()
	check("something you never saw is still a stranger",
		not BestiaryLog.knows(&"giant"))

	# The record can hold appearances the legend has no row for -- the killer
	# rabbit is a transformation, not a bestiary entry -- so counting the
	# record instead of the listed creatures reads "21/20".
	var listed := 0
	for entry in GameState.BESTIARY:
		if BestiaryLog.knows(entry["app"]):
			listed += 1
	BestiaryLog.note(&"killer_rabbit")
	var still := 0
	for entry in GameState.BESTIARY:
		if BestiaryLog.knows(entry["app"]):
			still += 1
	check("a creature with no row does not inflate the tally (%d then %d)"
		% [listed, still], still == listed)
	check("though it is still remembered", BestiaryLog.knows(&"killer_rabbit"))

	# A corrupted sighting is its own fact, not a flag on the base entry.
	check("meeting a rat says nothing about the corrupted kind",
		BestiaryLog.knows(&"rat") == BestiaryLog.knows(&"rat")
			and not BestiaryLog.knows_corrupted(&"rat"))
	BestiaryLog.note_corrupted(&"rat")
	check("and the corrupted kind is learned on its own",
		BestiaryLog.knows_corrupted(&"rat"))
	check("without claiming you met the ordinary one",
		BestiaryLog.knows(&"goblin") and not BestiaryLog.knows_corrupted(&"goblin"))

	# Seeing one in play records the corrupted key, not the plain one.
	var vg := _arena(21, 9)
	vg.player.x = 5
	vg.player.y = 4
	var vermin := _spawn(vg, "kobold", 7, 4)
	vg._corrupt(vermin)
	vg.update_vision()
	check("a violet kobold teaches the violet kobold",
		BestiaryLog.knows_corrupted(&"kobold"))
	check("and not the ordinary one", not BestiaryLog.knows(&"kobold"))
	check("corruption doubled it (%d hp, %d power, %d threat)"
		% [vermin.max_hp, vermin.power, vermin.threat],
		vermin.max_hp == 12 and vermin.power == 6 and vermin.threat == 6)
	check("and it says so in its name", vermin.name.begins_with("corrupted"))
	check("and it survives a suspend",
		Entity.from_dict(vermin.to_dict()).corrupted)

	BestiaryLog.clear_scratch()
	BestiaryLog.use_path("user://scratch_tests_bestiary.txt")
	check("the suite's own record path is back",
		BestiaryLog._path.contains("scratch_tests_"))

## A haunch is worth what the rabbit made it worth, before and after a save.
func _test_meat_keeps_its_worth() -> void:
	var gs := _arena(21, 9)
	gs.player.x = 4
	gs.player.y = 4
	gs.depth = 9
	var bun := _spawn(gs, "rabbit", 6, 4)
	bun.meal = 2
	gs.ground = []
	gs._drop_meat(bun)
	check("a rabbit leaves a haunch", gs.ground.size() == 1)
	var haunch: Item = gs.ground[0]
	var want := GameState.MEAT_BASE + 2 + int(floor(9.0 / GameState.MEAT_PER_DEPTH))
	check("worth base plus what it ate plus depth (%d, wanted %d)"
		% [haunch.effective_magnitude(), want],
		haunch.effective_magnitude() == want)

	# The bug: magnitude was never serialised, so a suspend handed back the
	# catalogue's placeholder of 1 and an eight-point meal became a one-point
	# one without a word in the log.
	var back := Item.from_dict(haunch.to_dict())
	check("and it is still worth that after a suspend (%d)"
		% back.effective_magnitude(),
		back.effective_magnitude() == want)

	# A save written before magnitude was kept must not crash or read as zero.
	var old_save := {"id": "meat", "letter": "", "x": 0, "y": 0,
		"pow": 0, "def": 0, "ammo": 0, "boost": 0}
	var legacy := Item.from_dict(old_save)
	check("an older save still yields a usable haunch",
		legacy != null and legacy.effective_magnitude() >= 1)

	# And you eat it. You do not drink it.
	check("meat is eaten", haunch.verb() == "eat")
	check("a potion is still drunk",
		Item.make(&"potion_healing").verb() == "drink")
	gs.player.hp = 1
	gs.player.max_hp = 99
	var log_before := gs.msg_log.entries.size()
	gs._apply_effect(haunch)
	check("the log says so", gs.msg_log.entries.size() > log_before)

## A gem goes into a weapon at a dying brazier, once, forever.
func _test_binding_a_stone() -> void:
	var gs := _arena(21, 9)
	gs.player.x = 5
	gs.player.y = 4
	var blade := Item.make(&"dagger")
	gs.player.inventory.append(blade)
	gs.player.equipped[Item.Slot.WEAPON] = blade
	var gem := Item.make(&"gem_fire")
	gs.player.inventory.append(gem)

	# No brazier at all.
	check("a gem needs a fire", not gs.player_bind(gs.player.inventory.find(gem)))
	check("and is not spent trying", gs.player.inventory.has(gem))

	# A LIT brazier does not SET the gem -- it rakes down to coals instead, so
	# a player at full health with nothing to merge is not locked out of the
	# forge entirely. Two deliberate clicks, no dialog.
	gs.map.set_tile(6, 4, Tiles.BRAZIER)
	gs.brazier_charge[Vector2i(6, 4)] = GameState.BRAZIER_CHARGE
	check("a lit brazier is offered", gs.can_bind_gem(gem))
	check("and the first click rakes it down",
		gs.player_bind(gs.player.inventory.find(gem)))
	check("the gem is NOT spent on that click", gs.player.inventory.has(gem))
	check("the blade is still bare", blade.element == &"")
	check("the fire is coals now",
		gs.map.get_tile(6, 4) == Tiles.BRAZIER_SPENT)
	check("and the warmth is gone with it",
		int(gs.brazier_charge.get(Vector2i(6, 4), 0)) == 0)

	# And the second click sets it into the blade.
	check("dying coals will", gs.can_bind_gem(gem))
	check("and it takes", gs.player_bind(gs.player.inventory.find(gem)))
	check("the blade holds the element", blade.element == &"fire")
	check("and says so in its name (%s)" % blade.display_name(),
		blade.display_name().contains("("))
	check("a plain weapon says nothing extra",
		not Item.make(&"dagger").display_name().contains("("))
	# The tag means "this weapon has been given an element". On the gem itself
	# the element IS the name, and "gem of frost (frost)" stutters.
	check("and a gem does not repeat itself (%s)"
		% Item.make(&"gem_frost").display_name(),
		Item.make(&"gem_frost").display_name() == "gem of frost")
	check("the gem is spent", not gs.player.inventory.has(gem))
	check("and the brazier is black for good",
		gs.map.get_tile(6, 4) == Tiles.BRAZIER_DEAD)

	# One stone, forever.
	var second := Item.make(&"gem_frost")
	gs.player.inventory.append(second)
	gs.map.set_tile(4, 4, Tiles.BRAZIER_SPENT)
	gs.ember_until[Vector2i(4, 4)] = gs.turns + GameState.EMBER_TURNS
	check("a bound weapon is never offered another", not gs.can_bind_gem(second))
	check("and refuses one", not gs.player_bind(gs.player.inventory.find(second)))
	check("the first element stands", blade.element == &"fire")
	check("and the second gem is not eaten", gs.player.inventory.has(second))

	# It survives a suspend, or the save quietly unbinds it.
	check("a binding survives a suspend",
		Item.from_dict(blade.to_dict()).element == &"fire")
	check("and a plain weapon stays plain",
		Item.from_dict(Item.make(&"dagger").to_dict()).element == &"")

	# Never into something you cannot swing.
	#
	# The ring is Kind.WEAPON so the slot machinery understands it, and that
	# spare part made it a legal target for every gem. Measured before the
	# fix: a fire gem bound, was consumed, and left "ring of the rat (fire)"
	# on an item that can never land a blow -- and binding is irreversible, so
	# it cost a gem, the brazier's warmth and the brazier, for nothing.
	for el in [&"fire", &"crag", &"leech", &"frost"]:
		check("the ring refuses a %s gem" % el,
			not Item.make(&"rat_ring").accepts_element(el))

	var furred := _forge_arena()
	var worn := Item.make(&"rat_ring")
	furred.give_item(worn)
	furred.player.equipped[Item.Slot.WEAPON] = worn
	var wasted := Item.make(&"gem_fire")
	furred.give_item(wasted)
	var wi := furred.player.inventory.find(wasted)
	# Twice: the first press only rakes the brazier down to coals.
	furred.player_bind(wi)
	check("and a rat at a forge cannot set one", not furred.player_bind(wi))
	check("the gem is still in the pack", furred.player.inventory.has(wasted))
	check("and the ring holds nothing", worn.element == &"")

## What a bound gem actually does when the blow lands.
func _test_gems_bite() -> void:
	# --- fire adds a share, not a flat number ---------------------------
	var gs := _arena(21, 9)
	gs.player.x = 4
	gs.player.y = 4
	gs.player.power = 20
	var blade := Item.make(&"dagger")
	gs.player.inventory.append(blade)
	gs.player.equipped[Item.Slot.WEAPON] = blade

	var plain := _spawn(gs, "cave troll", 5, 4)
	plain.max_hp = 9999
	plain.hp = 9999
	gs._attack(gs.player, plain)
	var without := 9999 - plain.hp

	blade.element = &"fire"
	plain.hp = 9999
	gs._attack(gs.player, plain)
	var with_fire := 9999 - plain.hp
	check("fire hits harder (%d vs %d)" % [with_fire, without], with_fire > without)

	# --- frost slows, including things that fly --------------------------
	blade.element = &"frost"
	var bird := _spawn(gs, "wyvern", 3, 4)
	var warm := gs.move_cost_for(bird, 3, 5)
	gs._attack(gs.player, bird)
	check("frost takes hold", bird.chilled > 0)
	var cold := gs.move_cost_for(bird, 3, 5)
	check("a chilled flier is slower (%d vs %d)" % [cold, warm], cold > warm)
	var was := bird.chilled
	gs._take_ai_turn(bird)
	check("one turn at a time (%d then %d)" % [was, bird.chilled],
		bird.chilled < was)

	# --- leech returns a share of the blow -------------------------------
	blade.element = &"leech"
	gs.player.max_hp = 200
	gs.player.hp = 50
	var sack := _spawn(gs, "cave troll", 5, 4)
	sack.max_hp = 9999
	sack.hp = 9999
	gs._attack(gs.player, sack)
	check("leech heals the wielder (%d)" % gs.player.hp, gs.player.hp > 50)
	check("but never past whole", gs.player.hp <= gs.player.max_hp)
	gs.player.hp = gs.player.max_hp
	var full := gs.player.hp
	gs._attack(gs.player, sack)
	check("and gives nothing when you are whole", gs.player.hp == full)

	# --- the crag raises spires, and never on the player -----------------
	blade.element = &"crag"
	var stuck := _spawn(gs, "cave troll", 8, 4)
	stuck.max_hp = 9999
	stuck.hp = 9999
	gs.player.x = 7
	gs.player.y = 4
	var before := 0
	for y in gs.map.height:
		for x in gs.map.width:
			if gs.map.get_tile(x, y) == Tiles.STALAGMITE:
				before += 1
	gs._attack(gs.player, stuck)
	var after := 0
	for y in gs.map.height:
		for x in gs.map.width:
			if gs.map.get_tile(x, y) == Tiles.STALAGMITE:
				after += 1
	check("the crag raises stone (%d spires)" % (after - before), after > before)
	check("never more than the cap",
		after - before <= GameState.GEM_CRAG_SPIRES)
	check("and never under the player who swung",
		gs.map.get_tile(gs.player.x, gs.player.y) != Tiles.STALAGMITE)

	# --- a bow carries no element ---------------------------------------
	var bow := Item.make(&"short_bow")
	bow.element = &"fire"
	gs.player.equipped[Item.Slot.WEAPON] = bow
	check("a gem does not fire down a bowstring",
		gs._gem_of(gs.player, true) == &"")
	check("though it is still bound to the weapon", bow.element == &"fire")

	# --- and the chill survives a suspend --------------------------------
	bird.chilled = 3
	check("frost survives a suspend",
		Entity.from_dict(bird.to_dict()).chilled == 3)

## Arrows come home, and only to the weapon that earns them.
func _test_gem_of_returning() -> void:
	# --- who will hold which gem ---------------------------------------
	var bow := Item.make(&"short_bow")
	var sling := Item.make(&"sling")
	var dagger := Item.make(&"dagger")
	var mail := Item.make(&"chain_mail")

	check("a bow takes returning", bow.accepts_element(&"return"))
	check("a sling does not -- it knaps its own",
		not sling.accepts_element(&"return"))
	check("nor does a blade", not dagger.accepts_element(&"return"))
	check("frost is melee only", dagger.accepts_element(&"frost")
		and not bow.accepts_element(&"frost"))
	check("so is leech", dagger.accepts_element(&"leech")
		and not bow.accepts_element(&"leech"))
	check("fire goes anywhere", dagger.accepts_element(&"fire")
		and bow.accepts_element(&"fire") and sling.accepts_element(&"fire"))
	check("and so does the crag", sling.accepts_element(&"crag"))
	check("armour holds nothing at all", not mail.accepts_element(&"fire"))

	# --- the forge refuses what the weapon will not take ---------------
	var gs := _arena(21, 9)
	gs.player.x = 5
	gs.player.y = 4
	gs.player.inventory.append(bow)
	gs.player.equipped[Item.Slot.WEAPON] = bow
	var frost := Item.make(&"gem_frost")
	gs.player.inventory.append(frost)
	gs.map.set_tile(6, 4, Tiles.BRAZIER_SPENT)
	gs.ember_until[Vector2i(6, 4)] = gs.turns + GameState.EMBER_TURNS
	check("a bow is never offered frost", not gs.can_bind_gem(frost))
	check("and refuses it at the coals",
		not gs.player_bind(gs.player.inventory.find(frost)))

	var back := Item.make(&"gem_return")
	gs.player.inventory.append(back)
	check("but takes returning", gs.can_bind_gem(back))
	check("and binds it", gs.player_bind(gs.player.inventory.find(back)))
	check("the bow holds it", bow.element == &"return")

	# --- and the arrows come home --------------------------------------
	bow.ammo = bow.ammo_max - 4
	# Binding ended a turn, so the counter is already at one. Zeroed here
	# rather than counted around: a test that quietly starts from a different
	# number than it claims is a test that will lie later.
	gs._return_walk = 0
	var pile := Item.make(&"arrows")
	pile.ammo = 4
	pile.x = 9
	pile.y = 4
	gs.ground = [pile]
	gs.take_events()

	for i in GameState.GEM_RETURN_STEPS - 1:
		gs._end_player_turn()
	check("nothing comes back early (%d)" % bow.ammo, bow.ammo == bow.ammo_max - 4)
	gs._end_player_turn()
	check("then the quiver fills (%d/%d)" % [bow.ammo, bow.ammo_max],
		bow.ammo == bow.ammo_max)
	check("and the pile is gone", gs.ground.is_empty())
	var flights := 0
	for ev in gs.take_events():
		if ev["kind"] == &"recall":
			flights += 1
	check("the flight is drawn (%d)" % flights, flights == 1)

	# A full quiver leaves them where they lie.
	var spare := Item.make(&"arrows")
	spare.ammo = 3
	spare.x = 9
	spare.y = 4
	gs.ground = [spare]
	for i in GameState.GEM_RETURN_STEPS + 1:
		gs._end_player_turn()
	check("a full quiver calls nothing", gs.ground.size() == 1)

	# Unbinding stops the clock rather than banking it.
	gs.player.equipped[Item.Slot.WEAPON] = dagger
	gs._end_player_turn()
	check("a blade counts no steps", gs._return_walk == 0)

## Every player meets a gem, early, whatever the dice do.
func _test_the_first_gem_is_certain() -> void:
	# Measured before the guarantee existed: half of depth-2 floors carried no
	# gem, a third of depth-3, two thirds of the caves -- about one run in six
	# reached floor three having never seen one.
	var barren := 0
	var doubled := 0
	for i in 60:
		var gs := GameState.new(5200 + i)
		gs.new_game()
		gs.depth = 2
		gs.build_level()
		var found := 0
		for it in gs.ground:
			if it.kind == Item.Kind.GEM:
				found += 1
		if found == 0:
			barren += 1
		if found > 1:
			doubled += 1
	check("floor two always holds a gem now (%d barren of 60)" % barren,
		barren == 0, "%d" % barren)
	# Written when gems were ordinary loot and a lucky floor could carry two.
	# They are chest-only now, so exactly one -- the guaranteed one -- is the
	# correct answer and more would mean the guarantee had become a second
	# source rather than a backstop.
	check("and never more than the one (%d floors had two)" % doubled,
		doubled == 0, "%d" % doubled)

	# Only the first. Once one has been seen, later floors are ordinary again.
	var run := GameState.new(77)
	run.new_game()
	run.depth = 2
	run.build_level()
	check("the run remembers having produced one", run.gem_found)
	# Once one has been produced the guarantee is spent, so later floors are
	# ordinary again -- which across many runs means some of them carry none.
	var later_barren := 0
	for i in 40:
		var r := GameState.new(6100 + i)
		r.new_game()
		r.gem_found = true
		r.depth = 4
		r.build_level()
		var any := false
		for it in r.ground:
			if it.kind == Item.Kind.GEM:
				any = true
		if not any:
			later_barren += 1
	check("later floors are back to chance (%d of 40 barren)" % later_barren,
		later_barren > 0, "%d" % later_barren)

	# It survives a suspend, or a resumed run gets a second free gem.
	var back := GameState.new(1)
	back.new_game()
	back.apply_dict(run.to_dict())
	check("the guarantee is spent across a suspend", back.gem_found)

	# And the climb never triggers it.
	var up := GameState.new(31)
	up.new_game()
	up.gem_found = false
	up.ascending = true
	up.depth = 2
	up.build_level()
	var climbing := 0
	for it in up.ground:
		if it.kind == Item.Kind.GEM:
			climbing += 1
	check("the climb is not given one", not up.gem_found or climbing == 0)

## Every item kind must have somewhere to be shown.
##
## The inventory draws by walking GROUPS, not by walking the pack, so a kind
## with no group is carried and never appears -- which is exactly what happened
## to the first gem picked up in play.
func _test_every_kind_is_listed() -> void:
	var panel := InventoryPanel.new()
	var grouped := {}
	for g in InventoryPanel.GROUPS:
		grouped[g[0]] = true

	var homeless: Array[String] = []
	for key in Item.CATALOGUE:
		var it := Item.make(key)
		var shown := false
		for g in InventoryPanel.GROUPS:
			if panel._matches(it, g[0]):
				shown = true
				break
		if not shown:
			homeless.append(String(key))
	check("every item in the catalogue has a group (%d homeless)"
		% homeless.size(), homeless.is_empty(), str(homeless))
	check("and the gem tab finds them",
		panel._matches(Item.make(&"gem_fire"), InventoryPanel.Filter.GEMS))
	check("without catching anything else",
		not panel._matches(Item.make(&"dagger"), InventoryPanel.Filter.GEMS))
	panel.free()

## The gem goes into the weapon you CHOOSE, not the one in your hand.
func _test_choosing_the_bound_weapon() -> void:
	var gs := _arena(21, 9)
	gs.player.x = 5
	gs.player.y = 4

	var sword := Item.make(&"short_sword")
	var dagger := Item.make(&"dagger")
	var bow := Item.make(&"short_bow")
	gs.player.inventory.append(sword)
	gs.player.inventory.append(dagger)
	gs.player.inventory.append(bow)
	gs.player.equipped[Item.Slot.WEAPON] = sword

	var gem := Item.make(&"gem_frost")
	gs.player.inventory.append(gem)
	gs.map.set_tile(6, 4, Tiles.BRAZIER_SPENT)
	gs.ember_until[Vector2i(6, 4)] = gs.turns + GameState.EMBER_TURNS

	# The whole point: the sword is in hand, and the dagger gets it anyway.
	var gi := gs.player.inventory.find(gem)
	var di := gs.player.inventory.find(dagger)
	check("binding takes a chosen target", gs.player_bind(gi, di))
	check("the dagger holds it", dagger.element == &"frost")
	check("and the wielded sword does not", sword.element == &"")

	# A target that cannot take it is refused rather than silently redirected.
	var gem2 := Item.make(&"gem_frost")
	gs.player.inventory.append(gem2)
	gs.map.set_tile(4, 4, Tiles.BRAZIER_SPENT)
	gs.ember_until[Vector2i(4, 4)] = gs.turns + GameState.EMBER_TURNS
	var gi2 := gs.player.inventory.find(gem2)
	var bi := gs.player.inventory.find(bow)
	check("a bow will not take frost", not gs.player_bind(gi2, bi))
	check("and the gem is not spent on the attempt",
		gs.player.inventory.has(gem2))
	check("a weapon that already holds one is refused",
		not gs.player_bind(gi2, gs.player.inventory.find(dagger)))

	# The shortlist only offers weapons that would actually take it.
	var panel := InventoryPanel.new()
	panel.state = gs
	panel.open_for_bind(gi2)
	check("the shortlist takes a bare sword", panel._takes_the_gem(sword))
	check("but not the bow", not panel._takes_the_gem(bow))
	check("nor the dagger it is already in", not panel._takes_the_gem(dagger))
	check("nor a potion", not panel._takes_the_gem(Item.make(&"potion_healing")))
	panel.free()

## Merging must never spend a better piece to make a worse one its equal.
func _test_the_better_piece_is_kept() -> void:
	var gs := _forge_arena()
	gs.brazier_charge = {Vector2i(6, 4): 100}
	var good := Item.make(&"leather_armour")
	good.upgrade()
	var plain := Item.make(&"leather_armour")
	gs.give_item(good)
	gs.give_item(plain)

	# Clicking the plain one when the only donor is the +1 used to consume the
	# +1 and hand back a +1 -- two pieces became one and the forging bought
	# nothing at all.
	check("the forge does not offer a losing merge", not gs.can_forge_item(plain))
	check("and refuses one asked for", not gs.player_merge(
		gs.player.inventory.find(plain)))
	check("both pieces are still in the pack",
		gs.player.inventory.has(good) and gs.player.inventory.has(plain))
	check("and neither changed",
		good.upgrade_level() == 1 and plain.upgrade_level() == 0)

	# The other way round is the sensible merge and still works.
	check("working the better one is offered", gs.can_forge_item(good))
	check("and it takes", gs.player_merge(gs.player.inventory.find(good)))
	check("the good piece improved", good.upgrade_level() == 2)
	check("and the plain one was spent", not gs.player.inventory.has(plain))

## Chests: one a band, opened by walking into them, and the only source of gems.
func _test_chests() -> void:
	# Gems are off the loot table entirely now.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var loose := 0
	for i in 3000:
		var it := Item.roll(rng, 9)
		if it != null and it.kind == Item.Kind.GEM:
			loose += 1
	check("gems are not floor loot any more (%d of 3000)" % loose, loose == 0)
	check("but a chest can still find one",
		Item.roll_gem(rng, 9) != null)
	check("and none exist above their depth",
		Item.roll_gem(rng, 1) == null)

	# One per band, on the band's middle floor, both directions.
	var with_chest := {}
	for d in [1, 2, 3, 5, 8, 10]:
		var seen := 0
		for i in 20:
			var gs := GameState.new(8800 + i)
			gs.new_game()
			gs.depth = d
			gs.build_level()
			for y in gs.map.height:
				for x in gs.map.width:
					if gs.map.get_tile(x, y) == Tiles.CHEST:
						seen += 1
		with_chest[d] = seen
	check("the band's middle floors carry one (d2 %d, d5 %d, d8 %d)"
		% [with_chest[2], with_chest[5], with_chest[8]],
		with_chest[2] > 0 and with_chest[5] > 0 and with_chest[8] > 0)
	check("and the others carry none (d1 %d, d3 %d)"
		% [with_chest[1], with_chest[3]],
		with_chest[1] == 0 and with_chest[3] == 0)
	check("never more than one on a floor",
		with_chest[2] <= 20 and with_chest[5] <= 20)

	# Walking into it opens it, and it gives up a gem.
	var gs2 := _arena(21, 9)
	# Depth matters: gems start at 2 and 3, so a chest opened on floor one
	# would honestly have nothing in it.
	gs2.depth = 5
	gs2.player.x = 5
	gs2.player.y = 4
	gs2.map.set_tile(6, 4, Tiles.CHEST)
	gs2.pathfinder = Pathfinder.new(gs2.map)
	gs2.ground = []
	check("a chest is solid", not gs2.map.is_walkable(6, 4))
	gs2.player_move(1, 0)
	check("walking into it opens it",
		gs2.map.get_tile(6, 4) != Tiles.CHEST)
	check("and you do not step onto it", gs2.player.x == 5)
	# The FIRST chest of a run hands out a unique -- there is one ring in a
	# dungeon and a chest is the only way to it. Gems are what chests hold once
	# the uniques are spent.
	var prize := ""
	for it in gs2.ground:
		prize = String(it.id)
	check("the first chest holds the unique (%s)" % prize, prize == "rat_ring")
	check("and the run remembers it", gs2.uniques_found.has(&"rat_ring"))

	# A second chest, with the ring already found, gives a gem instead.
	gs2.ground = []
	gs2.map.set_tile(4, 4, Tiles.CHEST)
	gs2.pathfinder = Pathfinder.new(gs2.map)
	gs2.player.x = 5
	gs2.player.y = 4
	gs2.player_move(-1, 0)
	var gems := 0
	for it in gs2.ground:
		if it.kind == Item.Kind.GEM:
			gems += 1
	check("a later chest holds a gem (%d)" % gems, gems == 1)
	check("and that counts as the run's first gem", gs2.gem_found)
	check("and the ring is never handed out twice",
		gs2.uniques_found.size() == 1)

## Who counts as dead, and who does not.
##
## Written alongside its first consumer rather than ahead of it -- a flag
## nothing reads is a lie in the save file, and this project has shipped two of
## those already.
func _test_the_dead_are_marked() -> void:
	var gs := _arena(21, 9)
	var dead := ["skeleton", "wight", "shadow", "banshee", "arch lich"]
	var living := ["giant rat", "goblin", "orc", "cave bear", "rabbit",
		"young dragon", "cave troll"]
	for n in dead:
		var e := _spawn(gs, n, 2, 2)
		check_silent(e != null and e.unliving)
		if e != null:
			e.alive = false
	check_gathered("the dead are marked as such")
	for n in living:
		var e := _spawn(gs, n, 3, 3)
		check_silent(e != null and not e.unliving)
		if e != null:
			e.alive = false
	check_gathered("and the living are not")

	# The golem is the interesting edge: never alive, but not a corpse either.
	var golem := _spawn(gs, "stone golem", 4, 4)
	check("a golem is not counted among the dead",
		golem != null and not golem.unliving)

	var back := Entity.from_dict(_spawn(gs, "skeleton", 5, 5).to_dict())
	check("and it survives a suspend", back.unliving)

## What you hit a thing WITH, and whether it cares.
func _test_damage_types() -> void:
	var gs := _arena(21, 9)
	gs.player.x = 4
	gs.player.y = 4
	gs.player.power = 20

	check("a sword slashes", Item.make(&"short_sword").damage_type == &"slash")
	check("a bow pierces", Item.make(&"war_bow").damage_type == &"pierce")
	check("a sling is blunt", Item.make(&"sling").damage_type == &"blunt")
	check("and so is a mace", Item.make(&"mace").damage_type == &"blunt")
	check("bare hands are nothing in particular",
		Item.make(&"potion_healing").damage_type == &"")

	# A skeleton has nothing to cut and nothing to puncture.
	var bones := _spawn(gs, "skeleton", 5, 4)
	check("a skeleton shrugs off steel",
		bones.resists.has(&"slash") and bones.resists.has(&"pierce"))
	check("and feels a mace", bones.weak_to.has(&"blunt"))

	# Measured across many swings, because a single blow carries a +/-1 roll.
	var sword := Item.make(&"short_sword")
	var mace := Item.make(&"mace")
	var slashed := 0
	var clubbed := 0
	for i in 400:
		bones.max_hp = 99999
		bones.hp = 99999
		gs.player.equipped[Item.Slot.WEAPON] = sword
		gs._attack(gs.player, bones)
		slashed += 99999 - bones.hp
		bones.hp = 99999
		gs.player.equipped[Item.Slot.WEAPON] = mace
		gs._attack(gs.player, bones)
		clubbed += 99999 - bones.hp
	check("the mace hurts it more than the sword (%d vs %d over 400)"
		% [clubbed, slashed], clubbed > slashed)

	# And something alive does not care which it was.
	var orc := _spawn(gs, "orc", 6, 4)
	check("an orc resists nothing", orc.resists.is_empty()
		and orc.weak_to.is_empty())

	# The golem is stone, not dead -- it resists without being unliving.
	var golem := _spawn(gs, "stone golem", 7, 4)
	check("a golem resists steel", golem.resists.has(&"slash"))
	check("but is not counted among the dead", not golem.unliving)
	check("and it throws rather than shuffles", golem.attack_range > 1)

	# Its corpse is ammunition.
	gs.map.set_tile(7, 4, Tiles.FLOOR)
	golem.hp = 0
	golem.alive = false
	gs._drop_loot(golem)
	check("a fallen golem leaves rubble",
		gs.map.get_tile(7, 4) == Tiles.RUBBLE)

	check("resistance survives a suspend",
		Entity.from_dict(bones.to_dict()).resists.has(&"blunt") == false
			and Entity.from_dict(bones.to_dict()).weak_to.has(&"blunt"))

func _test_cave_bear() -> void:
	var gs := _arena(21, 9)
	gs.player.x = 8
	gs.player.y = 4
	var bear := _spawn(gs, "cave bear", 7, 4)
	check("a bear knows how to shove", bear.knockback == 2)

	gs._attack(bear, gs.player)
	check("a bear's hit moves the player away (%d,%d)" % [gs.player.x, gs.player.y],
		gs.player.x == 10 and gs.player.y == 4)

	# Back to a wall: the shove is real, the ground is not there to give.
	gs.player.x = 19
	gs.player.y = 4
	bear.x = 18
	bear.y = 4
	gs._attack(bear, gs.player)
	check("a wall behind you stops the shove dead", gs.player.x == 19)

	# One free cell, not two.
	gs.player.x = 18
	gs.player.y = 4
	bear.x = 17
	bear.y = 4
	gs._attack(bear, gs.player)
	check("a shove stops at the first thing it cannot cross", gs.player.x == 19)

	# A pit behind you is not a shortcut the bear gets to choose for you.
	gs.player.x = 8
	gs.player.y = 4
	bear.x = 7
	bear.y = 4
	gs.map.set_tile(9, 4, Tiles.PIT)
	gs._attack(bear, gs.player)
	check("nothing is ever shoved into a pit", gs.player.x == 8)
	gs.map.set_tile(9, 4, Tiles.FLOOR)

	# Diagonals travel on the diagonal, rather than being flattened to an axis.
	gs.player.x = 8
	gs.player.y = 4
	bear.x = 7
	bear.y = 3
	gs._attack(bear, gs.player)
	check("a shove travels along the diagonal it came from (%d,%d)"
		% [gs.player.x, gs.player.y], gs.player.x == 10 and gs.player.y == 6)

	# Somebody standing where you would land stops it, same as a wall.
	gs.player.x = 8
	gs.player.y = 4
	bear.x = 7
	bear.y = 3
	var blocker := _spawn(gs, "giant rat", 9, 5)
	gs._attack(bear, gs.player)
	check("a creature in the way stops a shove",
		gs.player.x == 8 and gs.player.y == 4)
	blocker.x = 15
	blocker.y = 6

	# A monster is shoved by the same rule -- but the player has no knockback,
	# so this only happens if something ever gives one out.
	check("the player shoves nothing by default", gs.player.knockback == 0)

	# Ranged attacks never shove, or every archer would be a bear.
	gs.player.x = 8
	gs.player.y = 4
	bear.x = 4
	bear.y = 4
	gs._attack(bear, gs.player, true)
	check("a ranged hit never shoves", gs.player.x == 8)

	# It has to survive a suspend, or the save quietly disarms it.
	var back := Entity.from_dict(bear.to_dict())
	check("knockback survives a suspend", back.knockback == 2)

## The giant is the bear's ascent counterpart: same verb, different problem. It
## follows its own knockback, so the shove buys no distance.
## An authored pit obeys the same rule the generator's own pits do.
##
## Built from a synthetic vault rather than one in assets/, deliberately: the
## only shipped vault that ever had a pit had them swapped for water the day
## this guard was written, so a test reading the real library would have passed
## by finding nothing and gone on passing forever.
func _test_authored_pits_obey_the_rule() -> void:
	var text := "name: pit-probe\nweight: 100\nmin_depth: 1\nmax_depth: 19\n" \
		+ "rotate: no\nterrain: fixed\nLAYOUT\n" \
		+ "#####\n#X.X#\n#...#\n#X.X#\n##+##\n"
	var probe := Vault.parse(text, "pit_probe")
	check("the probe vault parses", probe != null)

	# _vault_library is STATIC and lazily loaded, so swapping it in reaches
	# every test that runs after this one. Put back in both directions below.
	var real_library := GameState._vault_library
	var down := 0
	var up := 0
	for i in 30:
		for climbing in [false, true]:
			var gs := GameState.new(88000 + i)
			gs.new_game()
			gs.ascending = climbing
			# Effective 7 descending, effective 11 climbing: both fortress, so
			# both ask for three or four vaults and the probe is sure to land.
			gs.depth = 7 if not climbing else 9
			GameState._vault_library = [probe] as Array[Vault]
			gs.build_level()
			var pits := 0
			for vr in gs.vault_rects:
				for y in range(vr.position.y, vr.end.y):
					for x in range(vr.position.x, vr.end.x):
						if gs.map.get_tile(x, y) == Tiles.PIT:
							pits += 1
			if climbing:
				up += pits
			else:
				down += pits

	GameState._vault_library = real_library
	check("an authored pit is real on the way down (%d)" % down, down > 0)
	check("and is solid ground on the way back up (%d)" % up, up == 0, "%d" % up)
	check("the real vault library is put back",
		GameState._vault_library.size() == real_library.size())

func _test_cave_giant() -> void:
	var gs := _arena(25, 11)
	gs.player.x = 10
	gs.player.y = 5
	var giant := _spawn(gs, "cave giant", 9, 5)
	check("a giant shoves further than a bear", giant.knockback == 3)
	check("and it charges", giant.charges)

	gs._attack(giant, gs.player)
	check("a charge keeps it adjacent (%d,%d vs %d,%d)"
		% [giant.x, giant.y, gs.player.x, gs.player.y],
		maxi(absi(giant.x - gs.player.x), absi(giant.y - gs.player.y)) == 1)
	check("the player is still moved across the map", gs.player.x == 13)

	# Back to a wall: nothing was pushed, so nothing is followed. Without the
	# cap the giant would walk into the player's own cell.
	gs.player.x = 23
	gs.player.y = 5
	giant.x = 22
	giant.y = 5
	gs._attack(giant, gs.player)
	check("a blocked shove is not followed", giant.x == 22 and gs.player.x == 23)

	# The bear is the control: same verb, no charge, so it gets left behind.
	var bear := _spawn(gs, "cave bear", 4, 5)
	gs.player.x = 5
	gs.player.y = 5
	gs._attack(bear, gs.player)
	check("a bear does NOT follow its own shove",
		bear.x == 4 and gs.player.x == 7)

	var back := Entity.from_dict(giant.to_dict())
	check("charging survives a suspend", back.charges and back.knockback == 3)

	# Ascent-only, like the lich.
	var seen_down := 0
	for i in 30:
		var g2 := GameState.new(41000 + i)
		g2.new_game()
		for d in range(1, GameState.MAX_DEPTH + 1):
			g2.depth = d
			g2.build_level()
			for e in g2.entities:
				if e.name == "cave giant":
					seen_down += 1
	check("no giant on the way down", seen_down == 0, str(seen_down))

func _test_banshee() -> void:
	# The learning floors stay clean, and then it never ages out -- min_depth
	# and no_fade are independent axes, which is the whole reason it can do
	# both.
	var early := 0
	var late := 0
	var most := 0
	for i in 30:
		var gs := GameState.new(50000 + i)
		gs.new_game()
		for d in [1, 2]:
			gs.depth = d
			gs.build_level()
			for e in gs.entities:
				if e.name == "banshee":
					early += 1
		gs.depth = 10
		gs.build_level()
		var here := 0
		for e in gs.entities:
			if e.name == "banshee":
				here += 1
				late += 1
		most = maxi(most, here)
	check("no banshee on the two learning floors", early == 0, str(early))
	check("but it has not faded out by depth 10 (%d)" % late, late > 0)
	# Uncapped it arrived nine to a floor at depth 10, because holding weight at
	# 1.0 while everything else decays makes a no-fade entry dominant.
	check("and never more than one to a floor", most <= 1, str(most))

	# It walks through stone. Nothing else does.
	var gs2 := _arena(21, 11)
	gs2.player.x = 4
	gs2.player.y = 5
	for y in range(1, 10):
		gs2.map.set_tile(8, y, Tiles.WALL)
	var ban := _spawn(gs2, "banshee", 12, 5)
	ban.alertness = Entity.Alert.AWAKE
	check("a banshee phases", ban.phasing)
	check("and senses without seeing", ban.senses)
	var start_d := Los.steps(ban.x, ban.y, 4, 5)
	# Enough turns to reach and cross the wall, wails included.
	for i in 12:
		gs2._take_ai_turn(ban)
	check("it closes across a solid wall (%d -> %d)"
		% [start_d, Los.steps(ban.x, ban.y, 4, 5)],
		Los.steps(ban.x, ban.y, 4, 5) < start_d)

	# Sensing: no line of sight, no light, still found.
	var dark := _arena(21, 11)
	dark.player.x = 4
	dark.player.y = 5
	for y in range(1, 10):
		dark.map.set_tile(8, y, Tiles.WALL)
	var blind := _spawn(dark, "banshee", 12, 5)
	blind.alertness = Entity.Alert.ASLEEP
	check("nothing can see through the wall",
		not Los.clear(dark.map, blind.x, blind.y, 4, 5))
	check("but the banshee finds you anyway",
		dark._notices_player(blind, Los.steps(blind.x, blind.y, 4, 5)))
	# A wight in the same spot cannot.
	var wight := _spawn(dark, "wight", 12, 6)
	check("and an ordinary thing cannot",
		not dark._notices_player(wight, Los.steps(wight.x, wight.y, 4, 5)))

	# It never strikes, and it does wake the neighbours.
	var noisy := _arena(31, 11)
	noisy.player.x = 15
	noisy.player.y = 5
	noisy.player.hp = 40
	noisy.player.max_hp = 40
	var wailer := _spawn(noisy, "banshee", 16, 5)
	wailer.alertness = Entity.Alert.AWAKE
	var sleeper := _spawn(noisy, "goblin", 22, 5)
	sleeper.alertness = Entity.Alert.ASLEEP
	noisy.take_events()
	var wails := 0
	for i in GameState.WAIL_EVERY * 2:
		noisy._take_ai_turn(wailer)
		for ev in noisy.take_events():
			if ev["kind"] == &"noise" and ev["cause"] == &"wail":
				wails += 1
	check("it cries on a cadence rather than every turn (%d in %d turns)"
		% [wails, GameState.WAIL_EVERY * 2], wails >= 1 and wails <= 3, str(wails))
	check("and the cry wakes the neighbours",
		sleeper.alertness == Entity.Alert.AWAKE)
	check("standing beside you, it never lays a finger on you",
		noisy.player.hp == 40, str(noisy.player.hp))

	# Killable inside the stone: player_move tests for an entity before it
	# tests the ground, so walking into the wall it occupies is an attack.
	var kill := _arena(21, 11)
	kill.player.x = 5
	kill.player.y = 5
	kill.map.set_tile(6, 5, Tiles.WALL)
	var stuck := _spawn(kill, "banshee", 6, 5)
	kill.player.power = 99
	check("it can be struck where it stands, wall or no", kill.player_move(1, 0))
	check("and it dies like anything else", not stuck.alive)

	# The flags survive a suspend.
	var kept := Entity.from_dict(wailer.to_dict())
	check("its nature survives a suspend",
		kept.phasing and kept.senses and kept.wail_radius == wailer.wail_radius)
	check("and an older save has none of it",
		not Entity.from_dict({"name": "orc", "app": "orc", "x": 1, "y": 1}).phasing)

## The two casters, and the system trap that adding them nearly sprang.
func _test_casters() -> void:
	# THE TRAP. deepest_tier() is the largest min_depth in the table and it caps
	# the tier-fade window for every monster. Giving the arch lich a deep
	# min_depth to make it "late" would push that cap from 10 to 15 and fade the
	# dragon, shadow, golem and wight out of the very floors they were written
	# to carry. This assertion is the guard.
	check("the deepest tier is still the dragon's",
		GameState.deepest_tier() == 10, str(GameState.deepest_tier()))

	# The ascent keeps its variety -- the thing the trap would have destroyed.
	var deep_kinds := {}
	for i in 40:
		var gs := GameState.new(31000 + i)
		gs.new_game()
		gs.ascending = true
		gs.depth = 1
		gs.build_level()
		for e in gs.entities:
			if not e.is_player:
				deep_kinds[e.name] = true
	check("the last floor of the climb still fields several kinds (%d)"
		% deep_kinds.size(), deep_kinds.size() >= 4, str(deep_kinds.keys()))

	# The lich is ascent-only, and late.
	var seen_down := 0
	for i in 40:
		var gs := GameState.new(32000 + i)
		gs.new_game()
		for d in range(1, GameState.MAX_DEPTH + 1):
			gs.depth = d
			gs.build_level()
			for e in gs.entities:
				if e.name == "arch lich":
					seen_down += 1
	check("no lich on the way down", seen_down == 0, str(seen_down))

	var seen_up := 0
	var seen_early_up := 0
	for i in 40:
		var gs := GameState.new(33000 + i)
		gs.new_game()
		gs.ascending = true
		for d in range(GameState.MAX_DEPTH - 1, 0, -1):
			gs.depth = d
			gs.build_level()
			for e in gs.entities:
				if e.name == "arch lich":
					if gs.effective_depth() >= 16:
						seen_up += 1
					else:
						seen_early_up += 1
	check("liches climb out with you (%d)" % seen_up, seen_up > 0, str(seen_up))
	check("but never early on the climb", seen_early_up == 0, str(seen_early_up))

	# The wizard is a descent monster, from depth 8 -- OUT ON THE FLOOR.
	#
	# A vault's `M` marker is documented to draw "a guardian from two tiers
	# deeper", so at depth 7 it reaches tier 9 and the wizard becomes legal
	# inside an authored room. That is the entire point of the marker: a
	# guardian is meant to be worse than its floor, and the room is optional
	# content the player chooses to open.
	#
	# This check used to count every wizard anywhere and passed only because
	# one vault in the library used `M`. Two more arrived and it started
	# failing on something the game does on purpose -- so it was measuring
	# library composition, not the difficulty curve it is named for.
	var early := 0
	var guarded := 0
	for i in 30:
		var gs := GameState.new(34000 + i)
		gs.new_game()
		for d in [1, 4, 7]:
			gs.depth = d
			gs.build_level()
			for e in gs.entities:
				if e.name != "wizard":
					continue
				if vault_holds(gs, Vector2i(e.x, e.y)):
					guarded += 1
				else:
					early += 1
	check("no wizard above depth 8 out on the floor", early == 0, str(early))
	# Not asserted as a minimum -- whether any vault rolls one is down to the
	# library -- but counted, so the exception stays visible rather than
	# becoming a hole nobody remembers widening.
	print("        (%d early wizards, every one a vault guardian)" % guarded)

## How the casters actually fight: they refuse to be reached.
func _test_caster_standoff_and_blink() -> void:
	var gs := _arena(31, 11)
	gs.player.x = 15
	gs.player.y = 5
	var wiz := _spawn(gs, "wizard", 18, 5)
	wiz.alertness = Entity.Alert.AWAKE
	check("a wizard is slower than you (%d)" % wiz.speed, wiz.speed < 100,
		str(wiz.speed))
	check("and keeps its distance", wiz.standoff == 3, str(wiz.standoff))

	# Three cells is inside its comfort, so it gives ground rather than shoots.
	var before := Los.steps(wiz.x, wiz.y, gs.player.x, gs.player.y)
	gs._take_ai_turn(wiz)
	check("inside its stand-off it backs away (%d -> %d)"
		% [before, Los.steps(wiz.x, wiz.y, gs.player.x, gs.player.y)],
		Los.steps(wiz.x, wiz.y, gs.player.x, gs.player.y) > before)

	# A slinger's comfort is still one cell -- the new field must not have
	# quietly changed everything that was already tuned.
	var sling := _spawn(gs, "kobold slinger", 22, 5)
	check("a slinger still stands and shoots", sling.standoff == 1,
		str(sling.standoff))

	# The lich blinks instead of stepping, and only on its cooldown.
	var lich_arena := _arena(31, 11)
	lich_arena.player.x = 15
	lich_arena.player.y = 5
	var lich := _spawn(lich_arena, "arch lich", 16, 5)
	lich.alertness = Entity.Alert.AWAKE
	check("a lich can blink", lich.blink_range > 0, str(lich.blink_range))
	var was := Vector2i(lich.x, lich.y)
	lich_arena.take_events()
	lich_arena._take_ai_turn(lich)
	var moved := Vector2i(lich.x, lich.y)
	# A step is not a blink. The first version of this asked only whether the
	# thing had moved, and passed for weeks' worth of the wrong reason while
	# blink_range was silently zero and _step_away was doing all the work.
	var folded := false
	for ev in lich_arena.take_events():
		if ev["kind"] == &"blink":
			folded = true
	check("cornered, it folds away rather than stepping", folded,
		"%s -> %s" % [was, moved])
	check("further than a stride could carry it",
		Los.steps(was.x, was.y, moved.x, moved.y) > 1,
		str(Los.steps(was.x, was.y, moved.x, moved.y)))
	check("landing out of reach",
		Los.steps(moved.x, moved.y, 15, 5) > lich.standoff,
		str(Los.steps(moved.x, moved.y, 15, 5)))
	check("onto ground it can stand on",
		Tiles.is_walkable(lich_arena.map.get_tile(moved.x, moved.y)))
	check("and the cooldown is now running",
		lich.blink_cool == GameState.BLINK_COOLDOWN, str(lich.blink_cool))

	# It cannot do it again immediately, which is the only reason it can ever
	# be caught and killed.
	lich.x = 16
	lich.y = 5
	var again := Vector2i(lich.x, lich.y)
	lich_arena._take_ai_turn(lich)
	check("it cannot blink again at once",
		Vector2i(lich.x, lich.y) != again or lich.blink_cool > 0,
		str(lich.blink_cool))
	# Wind the cooldown down and it can.
	lich.blink_cool = 0
	lich.x = 16
	lich.y = 5
	lich_arena.take_events()
	lich_arena._take_ai_turn(lich)
	var again_folded := false
	for ev in lich_arena.take_events():
		if ev["kind"] == &"blink":
			again_folded = true
	check("once the cooldown lapses it folds again", again_folded)

	# The fields survive a suspend, or a resumed lich forgets how to escape.
	var kept := Entity.from_dict(lich.to_dict())
	check("blink survives a suspend",
		kept.blink_range == lich.blink_range and kept.standoff == lich.standoff)
	# Saves written before casters existed carry neither field.
	var older := {"name": "orc", "app": "orc", "x": 1, "y": 1}
	check("and an older save defaults to standing its ground",
		Entity.from_dict(older).standoff == 1
		and Entity.from_dict(older).blink_range == 0)

func _test_graves_remember_the_dead() -> void:
	# Parsing, including a line written before the run recorder existed. That
	# older format is the one line the real morgue actually holds, so it has to
	# keep working.
	var old := Morgue.parse(
		"2026-09-03 23:09:49  level 1  killed by a kobold on depth 1, empty-handed, after 228 turns")
	check("an older morgue line still parses", not old.is_empty(), str(old))
	check("its depth is read", int(old.get("depth", -1)) == 1, str(old))
	check("its level is read", int(old.get("level", -1)) == 1)
	check("its cause is read", String(old.get("cause", "")) == "killed by a kobold",
		String(old.get("cause", "")))
	check("and it claims no kill count it never had", not old.has("slain"))

	var rich := Morgue.parse("2026-09-07 20:56:10  level 19  killed by a wyvern "
		+ "on depth 7, empty-handed, after 10720 turns; 62 slain, most often cave bat")
	check("a recorded death carries its tally", int(rich.get("slain", 0)) == 62, str(rich))
	check("and its nemesis", String(rich.get("nemesis", "")) == "cave bat",
		String(rich.get("nemesis", "")))

	# An escape leaves no grave -- nobody who walked out is buried down here.
	check("an escape is not a death", Morgue.parse("2026-09-05 10:00:00  level 19  "
		+ "escaped the dungeon with the Amulet of the Deep, with the Amulet, "
		+ "after 9000 turns").is_empty())
	check("and neither is a blank line", Morgue.parse("").is_empty())

	# A death round-trips through the file the game actually writes.
	var died := _arena(21, 9)
	died.depth = 4
	died.player.name = "you"
	died.stats = {"kills": {"cave bat": 5, "kobold": 2}}
	died.player.level = 6
	died.turns = 400
	died.death_cause = "killed by an ogre"
	died.write_morgue()
	var back := Morgue.records(GameState.MORGUE_PATH)
	check("the written line reads back", not back.is_empty())
	if not back.is_empty():
		var last: Dictionary = back[-1]
		check("with the depth it died on", int(last.get("depth", -1)) == 4, str(last))
		check("and the tally it recorded", int(last.get("slain", 0)) == 7, str(last))
		check("naming what killed most", String(last.get("nemesis", "")) == "cave bat",
			String(last.get("nemesis", "")))

	# And a floor at that depth buries it.
	var gs := GameState.new(4242)
	gs.new_game()
	gs.depth = 4
	gs.build_level()
	check("a floor buries the runs that ended on it", not gs.grave_at.is_empty(),
		str(gs.grave_at.size()))
	check("never more than the cap",
		gs.grave_at.size() <= GameState.MAX_GRAVES, str(gs.grave_at.size()))
	var on_ground := true
	for cell in gs.grave_at:
		if gs.map.get_tile(cell.x, cell.y) != Tiles.GRAVE:
			on_ground = false
		# Walkable by design, so a grave can never wall off a route.
		if not Tiles.is_walkable(gs.map.get_tile(cell.x, cell.y)):
			on_ground = false
		if cell == gs.stairs:
			on_ground = false
	check("every grave is a walkable grave tile, clear of the stairs", on_ground)

	# A floor nothing died on stays empty.
	var clean := GameState.new(4242)
	clean.new_game()
	clean.depth = 9
	clean.build_level()
	check("a floor with no dead has no graves", clean.grave_at.is_empty(),
		str(clean.grave_at.size()))

	# The stone survives a suspend, or resuming would open the earth.
	var text := JSON.stringify(gs.to_dict())
	var loaded := GameState.new(1)
	loaded.new_game()
	loaded.apply_dict(JSON.parse_string(text))
	check("graves survive a suspend", loaded.grave_at.size() == gs.grave_at.size(),
		"%d vs %d" % [loaded.grave_at.size(), gs.grave_at.size()])
	check("and an older save simply has none",
		GameState.new(1).grave_at.is_empty())

func _test_elapsed_is_time_not_keypresses() -> void:
	var gs := _arena(21, 9)
	gs.player.x = 5
	gs.player.y = 4
	for x in range(6, 10):
		gs.map.set_tile(x, 4, Tiles.MUD)
	var before_turns := gs.turns
	var before := gs.elapsed
	gs.player_move(1, 0)
	check("a step through mud is one turn", gs.turns - before_turns == 1)
	check("but costs two units of time (%d)" % (gs.elapsed - before),
		gs.elapsed - before == Scheduler.ACTION_COST * 2,
		str(gs.elapsed - before))

	var clean := _arena(21, 9)
	clean.player.x = 5
	clean.player.y = 4
	var was := clean.elapsed
	clean.player_move(1, 0)
	check("clean stone costs one", clean.elapsed - was == Scheduler.ACTION_COST)

	# Six seconds a round, out of D&D, and the arithmetic has to survive the
	# division rather than truncating a mud step down to a clean one.
	check("ten rounds is a minute",
		Clock.seconds(Scheduler.ACTION_COST * 10) == 60,
		str(Clock.seconds(Scheduler.ACTION_COST * 10)))
	check("Brad's escape reads as 17h 52m",
		Clock.text(Clock.seconds(10720 * Scheduler.ACTION_COST)) == "17h 52m",
		Clock.text(Clock.seconds(10720 * Scheduler.ACTION_COST)))
	check("a long crawl carries days",
		Clock.text(200000) == "2d 7h 33m", Clock.text(200000))
	check("and a short one keeps its seconds",
		Clock.text(126) == "2m 06s", Clock.text(126))

## The recorder, and the rule that the end screen skips what it never counted.
func _test_run_is_recorded() -> void:
	var gs := _arena(21, 9)
	gs.player.x = 5
	gs.player.y = 4
	gs.player.power = 99
	var rat := _spawn(gs, "giant rat", 6, 4)
	gs.player_move(1, 0)
	check("a kill is tallied by name",
		int(gs.stats.get("kills", {}).get("giant rat", 0)) == 1,
		str(gs.stats.get("kills", {})))
	check("damage dealt is tallied", int(gs.stats.get("dealt", 0)) > 0)
	check("and what was swung with it",
		gs.stats.get("swings", {}).has("bare hands"), str(gs.stats.get("swings", {})))

	# A save from before any of this existed carries no stats at all, and the
	# load must leave it that way rather than inventing zeroes.
	var old := gs.to_dict()
	old.erase("stats")
	old.erase("elapsed")
	old.erase("elapsed_est")
	var back := GameState.new(1)
	back.new_game()
	check("an older save loads with nothing recorded",
		back.apply_dict(old) and back.stats.is_empty(), str(back.stats))
	check("and its time is marked as reconstructed", back.elapsed_estimated)
	check("reconstructed from the turn count rather than zero",
		back.elapsed == back.turns * Scheduler.ACTION_COST,
		"%d vs %d" % [back.elapsed, back.turns])

	# A current save round-trips, and JSON's doubles come back as integers --
	# "3.0 kills" on the end screen is exactly what the normalising is for.
	var text := JSON.stringify(gs.to_dict())
	var reloaded := GameState.new(1)
	reloaded.new_game()
	reloaded.apply_dict(JSON.parse_string(text))
	check("a recorded run survives JSON intact",
		int(reloaded.stats.get("kills", {}).get("giant rat", 0)) == 1,
		str(reloaded.stats))
	check("counters come back as integers, not doubles",
		typeof(reloaded.stats["kills"]["giant rat"]) == TYPE_INT)
	check("and its time is not marked reconstructed", not reloaded.elapsed_estimated)

func _test_ember_heat_reads_the_clock() -> void:
	var gs := _forge_arena()
	var cell := Vector2i(6, 4)
	check("cold stone has no heat", gs.ember_heat(9, 4) == 0.0)
	check("nor does a burning brazier", gs.ember_heat(cell.x, cell.y) == 0.0)

	gs.player.max_hp = 40
	gs.player.hp = 30
	for i in 5:
		gs.player_wait()
	var full := gs.ember_heat(cell.x, cell.y)
	check("the turn it gutters, the embers are at full heat (%.2f)" % full,
		full > 0.9, str(full))

	# Monotonic all the way down, which is what makes it readable as a gauge.
	var last := full
	var fell := true
	for i in GameState.EMBER_TURNS:
		gs.turns += 1
		var now := gs.ember_heat(cell.x, cell.y)
		if now > last:
			fell = false
		last = now
	check("and cool without ever rising", fell)
	check("reaching nothing exactly as the window shuts", last == 0.0, str(last))

	# It must not go negative, or the renderer would ramp back past the coldest
	# colour into something that reads as heat again.
	gs.turns += 100
	check("and stay at nothing afterwards",
		gs.ember_heat(cell.x, cell.y) == 0.0)

	# A forged brazier is black, not cooling: the entry is gone, not expired.
	var forged := _forge_arena()
	forged.map.set_tile(cell.x, cell.y, Tiles.BRAZIER_SPENT)
	forged.brazier_charge.clear()
	forged.ember_until[cell] = forged.turns + GameState.EMBER_TURNS
	forged.give_item(Item.make(&"dagger"))
	forged.give_item(Item.make(&"dagger"))
	forged.player_merge(0)
	check("a brazier forged in has no heat to draw",
		forged.ember_heat(cell.x, cell.y) == 0.0)

## Embers work metal and nothing else, and they go cold.
func _test_embers_cool_and_refuse_glass() -> void:
	var cell := Vector2i(6, 4)

	# Glass. A bed of coals will not hold a decoction at temperature, and the
	# rule is what stops the ember forge becoming a potion-stacking engine
	# running on every burnt-out brazier in the dungeon.
	var glass := _forge_arena()
	glass.map.set_tile(cell.x, cell.y, Tiles.BRAZIER_SPENT)
	glass.brazier_charge.clear()
	glass.ember_until[cell] = glass.turns + GameState.EMBER_TURNS
	glass._gather_lights()
	glass.give_item(Item.make(&"potion_healing"))
	glass.give_item(Item.make(&"potion_healing"))
	check("embers will not boil two potions together",
		not glass.can_forge_item(glass.player.inventory[0]))
	check("and refuse the merge outright", not glass.player_merge(0))
	check("the brazier is untouched by the refusal",
		glass.map.get_tile(cell.x, cell.y) == Tiles.BRAZIER_SPENT)
	# The same coals take iron.
	glass.give_item(Item.make(&"dagger"))
	glass.give_item(Item.make(&"dagger"))
	check("but they take iron", glass.player_merge(2))

	# Cold. The clock is what stops "clear the floor, then walk back round it".
	var cold := _forge_arena()
	cold.map.set_tile(cell.x, cell.y, Tiles.BRAZIER_SPENT)
	cold.brazier_charge.clear()
	cold.ember_until[cell] = cold.turns + GameState.EMBER_TURNS
	cold._gather_lights()
	cold.give_item(Item.make(&"dagger"))
	cold.give_item(Item.make(&"dagger"))
	check("hot embers forge", cold.can_forge_here())
	cold.turns += GameState.EMBER_TURNS
	check("cold ones do not", not cold.can_forge_here())
	check("and the merge is refused", not cold.player_merge(0))
	check("but a scroll still relights cold ash",
		cold._adjacent_spent_brazier() == cell)

	# The clock is absolute turns, so it has to survive a suspend intact.
	var kept := _forge_arena()
	kept.map.set_tile(cell.x, cell.y, Tiles.BRAZIER_SPENT)
	kept.brazier_charge.clear()
	kept.turns = 400
	kept.ember_until[cell] = 415
	var back := GameState.new(1)
	back.new_game()
	check("a save round trip keeps the ember clock",
		back.apply_dict(kept.to_dict()) and int(back.ember_until.get(cell, -1)) == 415,
		str(back.ember_until))
	# Saves written before embers existed carry no such key.
	var older := kept.to_dict()
	older.erase("embers")
	var plain := GameState.new(1)
	plain.new_game()
	check("and an older save loads with no embers at all",
		plain.apply_dict(older) and plain.ember_until.is_empty())

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

	# Reported from play: sling, sword, sling left the buckler in the pack for
	# the rest of the run. The offhand rule only ever took a shield away.
	var posture := _arena(21, 9)
	posture.player.x = 5
	posture.player.y = 4
	var sword := Item.make(&"short_sword")
	var buckler := Item.make(&"buckler")
	var sling := Item.make(&"sling")
	for it in [sword, buckler, sling]:
		posture.give_item(it)
	posture.player_use(posture.player.inventory.find(sword))
	posture.player_use(posture.player.inventory.find(buckler))
	check("blade and shield to begin with",
		posture.player.is_equipped(sword) and posture.player.is_equipped(buckler))
	posture.player_swap_weapon()
	check("reaching for the sling gives up the shield",
		posture.player.is_equipped(sling) and not posture.player.is_equipped(buckler))
	posture.player_swap_weapon()
	check("and coming back to the blade puts it up again",
		posture.player.is_equipped(sword) and posture.player.is_equipped(buckler))
	check("in one turn, not two", posture.turns == 4, str(posture.turns))

	# It picks the best one carried, not the first found.
	var better := _arena(21, 9)
	better.player.x = 5
	better.player.y = 4
	for want in [&"short_sword", &"buckler", &"tower_shield", &"sling"]:
		better.give_item(Item.make(want))
	better.player_use(0)
	better.player_swap_weapon()
	better.player_swap_weapon()
	var raised: Item = better.player.equipped.get(Item.Slot.OFFHAND, null)
	check("and raises the heaviest shield carried",
		raised != null and raised.id == &"tower_shield",
		"none" if raised == null else String(raised.id))

	# The swap key.
	var before := gs.turns
	check("swapping from blade reaches for the bow", gs.player_swap_weapon())
	check("the bow is now in hand", gs.player.is_equipped(bow))
	check("which also cost the shield", not gs.player.is_equipped(kite))
	check("and it cost a turn", gs.turns > before)
	check("swapping back reaches for the blade", gs.player_swap_weapon())
	check("the axe is in hand again", gs.player.is_equipped(axe))

	# The swap key must never hand you a polymorph.
	#
	# Reachable without trying: throw your only dagger, hold a bow, carry the
	# ring, and the key that exists to put a blade in a cornered archer's hands
	# made him a blind, handless rat. It denies nothing -- the ring goes on from
	# the pack for the same one turn -- but it used to be quietly BETTER than
	# the pack, because the swap re-raises your shield on the way to a
	# one-handed item. A rat holding a buckler.
	var trap := _arena(21, 9)
	trap.player.x = 5
	trap.player.y = 4
	for held in trap.player.inventory.duplicate():
		if held.slot == Item.Slot.WEAPON:
			trap.player.inventory.erase(held)
	trap.player.equipped.erase(Item.Slot.WEAPON)
	var trap_bow := Item.make(&"war_bow")
	var trap_ring := Item.make(&"rat_ring")
	trap.give_item(trap_bow)
	trap.give_item(trap_ring)
	trap.player.equipped[Item.Slot.WEAPON] = trap_bow
	check("with only the ring to fall back on, the swap is refused",
		not trap.player_swap_weapon())
	check("and it did not turn you into a rat", not trap.ratted())

	# The way OUT still works, which is the half of this that plays well: a rat
	# cannot attack, so one key putting a weapon back in your hands is the
	# form's answer to being cornered. One-way on purpose -- becoming a rat
	# stays a deliberate act you go to the pack for.
	var out := _arena(21, 9)
	out.player.x = 5
	out.player.y = 4
	for held in out.player.inventory.duplicate():
		if held.slot == Item.Slot.WEAPON:
			out.player.inventory.erase(held)
	var out_bow := Item.make(&"war_bow")
	var out_ring := Item.make(&"rat_ring")
	out.give_item(out_bow)
	out.give_item(out_ring)
	out.give_item(Item.make(&"war_axe"))
	out.player.equipped[Item.Slot.WEAPON] = out_ring
	check("a rat is a rat", out.ratted())
	check("the swap key gets you out", out.player_swap_weapon())
	check("and you are yourself again", not out.ratted())
	check("holding the bow", out.player.is_equipped(out_bow))
	out.player_swap_weapon()
	check("and swapping on reaches the axe, never back to the ring",
		out.player.is_equipped(out.player.inventory[2]) and not out.ratted())

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

	# The check that runs the OTHER way, and the one that was missing.
	#
	# The three checks above start from the theme tables and ask whether the
	# font can draw them. Nothing started from the ITEM CATALOGUE and asked
	# whether the themes know it. So a new item with a mistyped "app" -- or,
	# more likely, a new item whose author added the theme entry to the glyph
	# table and forgot the ASCII one -- drew the fallback "?" in letter mode
	# and raised nothing anywhere. The mace and the axe were the first items to
	# get appearance ids of their own, which is when this hole became reachable.
	var undrawable: Array = []
	for id in Item.CATALOGUE:
		var app: StringName = Item.CATALOGUE[id].get("app", &"")
		if not AsciiTheme.TABLE.has(app):
			undrawable.append("%s -> %s" % [id, app])
	check("every catalogue item has an appearance the themes know",
		undrawable.is_empty(), str(undrawable))

	# The look panel draws one icon of its own, and it draws it with the TEXT
	# face rather than the map's. That face has no icon range by itself, so the
	# skull renders as nothing unless the fallback chain is wired -- the same
	# failure as the invisible shrine and brazier glyphs, which were also real
	# codepoints drawn with a font that did not carry them.
	var panel := Sidebar.ui_font()
	check("the look panel's font carries its skull",
		panel != null and panel.has_char(Sidebar.SKULL),
		"U+%X" % Sidebar.SKULL)
	# And it still draws ordinary words, which is the whole point of the order.
	check("and still has its letters",
		panel != null and panel.has_char("k".unicode_at(0)))

	# "killed by a kobold slinger" is 26 characters against a panel about 24
	# wide, and arrived truncated in play as "killed by a kobold slin..".
	var bar := Sidebar.new()
	check("the skull replaces the words",
		bar._skullify("killed by a kobold slinger") == char(Sidebar.SKULL) + " kobold slinger")
	check("and handles an, too",
		bar._skullify("killed by an orc") == char(Sidebar.SKULL) + " orc")
	check("a fall is left as written",
		bar._skullify("broken by a fall") == "broken by a fall")
	check("and so is walking out",
		bar._skullify("left the dungeon on depth 4") == "left the dungeon on depth 4")
	bar.free()
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

	# You are an outline while every humanoid is solid, so the player must not
	# share a figure with anything that can kill him.
	var you: String = icons.appearance(&"player")["ch"]
	var clashes: Array = []
	for e in GameState.BESTIARY:
		if icons.appearance(e["app"])["ch"] == you:
			clashes.append(e["name"])
	check("nothing in the bestiary looks like you", clashes.is_empty(), str(clashes))

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


## Ammunition, and the exploit it exists to close.
##
## A first-time player found shoot-and-retreat in one sitting, and the numbers
## agreed with him: reach 8 against a longest monster reach of 6, and eight of
## fifteen monsters slower than the player, so they can never close on someone
## backing away. The stone golem at speed 70 literally cannot reach you in open
## ground.
##
## Noise was tried first and measured, because it was the cheap answer. Firing
## twelve shots at something that cannot catch you drew nobody 94% of the time
## at the old radius and 52% of the time at a radius larger than a boneyard.
## Noise wakes things, and the things it wakes are the same slow ones that
## could not reach you -- so the lever was always wrong. Shots have to cost.
func _test_ammunition() -> void:
	var gs := _arena(25, 11)
	gs.player.x = 4
	gs.player.y = 5
	var bow := Item.make(&"war_bow")
	gs.give_item(bow)
	gs.player.equipped[Item.Slot.WEAPON] = bow
	check("a bow is found loaded (%d)" % bow.ammo, bow.ammo == bow.ammo_max)
	check("and its quiver holds twenty", bow.ammo_max == 20, str(bow.ammo_max))

	var mark := _spawn(gs, "kobold", 12, 5)
	mark.max_hp = 9999
	mark.hp = 9999
	var start := bow.ammo
	gs.player_fire(Vector2i(12, 5))
	check("firing spends a shot", bow.ammo == start - 1, str(bow.ammo))

	# The spent arrow lands where it hit, which is the point of the whole thing:
	# retreating means backing away from your own ammunition.
	var landed := 0
	for it in gs.items_at(12, 5):
		if it.id == &"arrows":
			landed += it.ammo
	check("and the arrow lands on the target", landed == 1, str(landed))

	# Aim at where it IS each time: a woken monster walks toward you between
	# shots, and firing at the cell it used to occupy is refused.
	for i in 40:
		gs.player_fire(Vector2i(mark.x, mark.y))
	check("an empty bow stops shooting", bow.ammo == 0, str(bow.ammo))
	var turns := gs.turns
	check("and firing it is refused", not gs.player_fire(Vector2i(mark.x, mark.y)))
	check("without costing a turn", gs.turns == turns)

	# Walk to the biggest pile and gather it back.
	var pile: Item = null
	for it in gs.ground:
		if it.id == &"arrows" and (pile == null or it.ammo > pile.ammo):
			pile = it
	check("spent arrows are lying about", pile != null)
	if pile == null:
		return
	gs.entities.erase(mark)
	gs.player.x = pile.x
	gs.player.y = pile.y
	check("gathering spent arrows works", gs.player_pickup())
	check("the quiver refills", bow.ammo > 0, str(bow.ammo))
	check("but never past its capacity", bow.ammo <= bow.ammo_max)

	# Rubble is a sling's supply, and taking it destroys the rubble.
	var sl := _arena(21, 9)
	sl.player.x = 5
	sl.player.y = 4
	var sling := Item.make(&"sling")
	sl.give_item(sling)
	sl.player.equipped[Item.Slot.WEAPON] = sling
	check("a sling holds thirty stones", sling.ammo_max == 30, str(sling.ammo_max))
	sling.ammo = 0
	sl.map.set_tile(5, 4, Tiles.RUBBLE)
	check("knapping rubble gives a stone", sl.player_pickup())
	check("one per tile, so a shot costs a turn owed", sling.ammo == 1, str(sling.ammo))
	check("and the rubble is gone", sl.map.get_tile(5, 4) != Tiles.RUBBLE)

	# A sling cannot be loaded with arrows, nor a bow with stones.
	var mixed := _arena(21, 9)
	mixed.player.x = 5
	mixed.player.y = 4
	var bow2 := Item.make(&"short_bow")
	mixed.give_item(bow2)
	mixed.player.equipped[Item.Slot.WEAPON] = bow2
	mixed.map.set_tile(5, 4, Tiles.RUBBLE)
	check("a bow gets nothing from rubble", not mixed.player_pickup())
	check("the rubble survives that", mixed.map.get_tile(5, 4) == Tiles.RUBBLE)

	# Slung stones do not litter the floor; nobody would cross a room for one.
	var st := _arena(25, 11)
	st.player.x = 4
	st.player.y = 5
	var sling2 := Item.make(&"sling")
	st.give_item(sling2)
	st.player.equipped[Item.Slot.WEAPON] = sling2
	var target2 := _spawn(st, "kobold", 8, 5)
	target2.max_hp = 9999
	target2.hp = 9999
	st.player_fire(Vector2i(8, 5))
	check("a slung stone leaves nothing behind", st.items_at(8, 5).is_empty())

	# A resumed run keeps its quiver.
	var kept := Item.from_dict(bow.to_dict())
	check("ammunition survives a suspend",
		kept.ammo == bow.ammo, "%d vs %d" % [kept.ammo, bow.ammo])
	var older := {"id": "war_bow", "letter": "a", "x": 0, "y": 0, "pow": 0, "def": 0}
	check("and an older save comes back loaded rather than dry",
		Item.from_dict(older).ammo == 20)


## Merging must never eat the better item.
##
## Reported from play: with a potion +1 already in the pack, merging two plain
## potions consumed the +1 as the donor. You finished with one +1 where you
## started with one, two plain potions gone, and nothing saying where the good
## one went. The donor was simply the first id match in pack order.
func _test_merging_spends_the_cheapest() -> void:
	var gs := _forge_arena()
	gs.brazier_charge = {Vector2i(6, 4): 100}
	# The upgraded one FIRST, which is the order that used to lose it.
	var precious := Item.make(&"potion_healing")
	precious.upgrade()
	gs.give_item(precious)
	var plain_a := Item.make(&"potion_healing")
	var plain_b := Item.make(&"potion_healing")
	gs.give_item(plain_a)
	gs.give_item(plain_b)

	check("merging a plain one keeps the good one",
		gs.player_merge(gs.player.inventory.find(plain_a)))
	check("the +1 is still in the pack", gs.player.inventory.has(precious))
	check("it is still a +1", precious.upgrade_level() == 1,
		str(precious.upgrade_level()))
	check("and the plain donor was the one spent",
		not gs.player.inventory.has(plain_b))

	# Two upgraded potions are a legitimate way to reach +2 when that is all
	# there is, so the rule is "cheapest", not "never an upgraded one".
	var pair := _forge_arena()
	pair.brazier_charge = {Vector2i(6, 4): 100}
	var one := Item.make(&"potion_healing")
	var two := Item.make(&"potion_healing")
	one.upgrade()
	two.upgrade()
	pair.give_item(one)
	pair.give_item(two)
	check("two +1s can still be combined", pair.player_merge(0))
	check("into a +2", pair.player.inventory[0].upgrade_level() == 2,
		str(pair.player.inventory[0].upgrade_level()))
	check("worth 28 hit points",
		pair.player.inventory[0].effective_magnitude() == 28,
		str(pair.player.inventory[0].effective_magnitude()))

	# The same rule protects gear, which nobody had tested either.
	var gear := _forge_arena()
	gear.brazier_charge = {Vector2i(6, 4): 100}
	var sharp := Item.make(&"short_sword")
	sharp.upgrade()
	gear.give_item(sharp)
	var dull_a := Item.make(&"short_sword")
	var dull_b := Item.make(&"short_sword")
	gear.give_item(dull_a)
	gear.give_item(dull_b)
	gear.player_merge(gear.player.inventory.find(dull_a))
	check("a sword +1 is not eaten to improve a plain one",
		gear.player.inventory.has(sharp) and sharp.upgrade_level() == 1)
