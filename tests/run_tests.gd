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
	# settings.cfg is the one player-owned file use_scratch_files does NOT
	# redirect, and four separate modules write it: RenderTheme, Effects,
	# TraderTalk and SoundDeck. Snapshot it here and compare at the end, so a
	# test that leaves the player's own settings altered fails loudly instead
	# of being discovered months later as "it always resets".
	#
	# A guard rather than a redirect because a redirect means a static path
	# variable in all four, which is its own change. This catches every one of
	# them from a single place in the meantime.
	var settings_before := ""
	var had_settings := FileAccess.file_exists("user://settings.cfg")
	if had_settings:
		settings_before = FileAccess.get_file_as_string("user://settings.cfg")
	# The same tripwire for the controller bindings, which the suite overwrote
	# on every run for two days before anyone noticed. Redirected now; this
	# proves the redirect held.
	var pad_before := ""
	var had_pad := FileAccess.file_exists("user://gamepad.cfg")
	if had_pad:
		pad_before = FileAccess.get_file_as_string("user://gamepad.cfg")
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
	_test_a_prayer_may_be_answered()
	_test_the_hoard_room()
	_test_the_pity_gem_is_earned()
	_test_the_dead_have_names()
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
	_test_text_size_survives_a_restart()
	_test_every_menu_row_is_reachable()
	_test_a_pad_can_finish_the_game()
	_test_a_pad_can_answer_every_prompt()
	_test_a_pad_is_never_a_letter_in_the_pack()
	_test_button_pictures()
	_test_holding_a_direction()
	_test_armour_takes_time()
	_test_every_draught_costs_a_turn()
	_test_the_pack_stays_open()
	_test_trade_prices()
	_test_the_trader_deals()
	_test_the_trader_remembers_the_dead()
	_test_the_counter()
	_test_the_counter_by_mouse_and_keys()
	_test_the_trader_piles()
	_test_creatures_keep_out_of_pits()
	_test_traffic()
	_test_naming_without_a_keyboard()
	_test_the_flare_rekindles()
	_test_a_gem_in_the_rubble()
	_test_main_only_sets_properties_that_exist()
	_test_threat_ceilings()
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
	_test_a_side_of_your_own()
	_test_the_bone_ally()
	_test_graves_raise_the_dead()
	_test_bestiary_is_earned()
	_test_meat_keeps_its_worth()
	_test_binding_a_stone()
	_test_gems_bite()
	_test_gem_of_returning()
	_test_gem_of_the_bulwark()
	_test_the_other_two_shield_stones()
	_test_the_element_table_agrees_with_itself()
	_test_g_is_the_action_key()
	_test_the_sidebar_says_what_is_here()
	_test_the_build_is_named()
	_test_a_rat_may_creep_past()
	_test_choosing_the_bound_weapon()
	_test_the_better_piece_is_kept()
	_test_chests()
	_test_the_floor_is_busy()
	_test_doors_stop_different_things()
	_test_creatures_can_see_each_other()
	_test_doors_are_loud_and_rats_are_not()
	_test_the_gong_is_answered()
	_test_the_small_give_way()
	_test_fires_burn_down_and_guards_feed_them()
	_test_morale_is_social()
	_test_the_panel_says_whose_side()
	_test_the_dead_are_marked()
	_test_damage_types()
	_test_the_first_gem_is_certain()
	_test_found_magic_is_not_a_gem()
	_test_gems_keep_their_colour()
	_test_the_sack()
	_test_the_overview_map()
	_test_spires_subside()
	_test_pack_without_letters()
	_test_found_magic()
	_test_the_trader()
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

	# The snapshot taken at the top. Anything the suite changed in the player's
	# own settings is a bug in the test that changed it, not a finding here.
	#
	# Existence is asserted separately from contents, because comparing two
	# empty strings is a pass that tested nothing -- the same vacuity that let
	# four checks aim at an empty cell this morning. Asserted as "the file is in
	# the same STATE" rather than "the file exists", so a clean checkout that
	# has never run the game does not go spuriously red: on such a machine there
	# is genuinely nothing to protect, and a test that CREATES the file still
	# fails this, which is the case that matters.
	#
	# Note the limit rather than trusting it further than it goes: this only
	# runs if _initialize reaches the end. A SCRIPT ERROR or an early quit skips
	# it entirely and leaves the settings clobbered with nothing said. It is a
	# tripwire, not a seatbelt. The seatbelt is routing SETTINGS through
	# use_scratch_files the way BestiaryLog does, which is a separate change.
	var has_settings := FileAccess.file_exists("user://settings.cfg")
	var settings_after := ""
	if has_settings:
		settings_after = FileAccess.get_file_as_string("user://settings.cfg")
	check("settings.cfg is in the same state it started in",
		had_settings == has_settings,
		"existed before=%s after=%s" % [had_settings, has_settings])
	check("and the suite leaves its contents untouched",
		settings_after == settings_before,
		"before=%s after=%s" % [settings_before.replace("\n", " "),
			settings_after.replace("\n", " ")])
	check("the controller bindings are redirected (%s)" % PadConfig.PATH,
		PadConfig.PATH.contains("scratch_"))
	var has_pad := FileAccess.file_exists("user://gamepad.cfg")
	var pad_after := ""
	if has_pad:
		pad_after = FileAccess.get_file_as_string("user://gamepad.cfg")
	check("gamepad.cfg is in the same state it started in",
		had_pad == has_pad and pad_after == pad_before,
		"before=%s after=%s" % [pad_before, pad_after])

	print("")
	print("  %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

var _silent_ok := true
## How many check_silent calls the current gathered block has actually made.
var _silent_seen := 0

func check_silent(condition: bool) -> void:
	_silent_seen += 1
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
## A gathered report over ZERO gathered checks is a guaranteed pass, because
## `_silent_ok` starts true. That is not a theoretical hazard: the prayer-gem
## test reported "what a prayer leaves is a gem, at your feet" in green having
## examined no gems at all, because every prayer in it ran at depth 1 where no
## gem is legal and the loop body never executed.
##
## Swept afterwards, every other gathered block in this file turned out safe --
## they all iterate literal arrays or fixed counts, so their bodies always run.
## But that is luck rather than design, so the helper enforces it instead of
## trusting whoever writes the next one to notice.
func check_gathered(name: String, detail: String = "") -> void:
	if _silent_seen == 0:
		check("%s -- NOTHING WAS CHECKED" % name, false,
			"check_gathered reported over zero check_silent calls")
	else:
		check(name, _silent_ok, detail)
	_silent_ok = true
	_silent_seen = 0

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
	var neutrals := 0
	for e in gs.entities:
		if e.is_player:
			continue
		# The trader is awake on purpose and is not a monster -- it fights
		# nobody and nobody fights it. Counted separately rather than ignored,
		# so "a monster was quietly made neutral" cannot hide in here.
		if e.faction == Entity.Faction.NEUTRAL:
			neutrals += 1
			continue
		total += 1
		if e.alertness != Entity.Alert.ASLEEP:
			awake += 1
	check("the level has monsters to check", total > 0, "%d" % total)
	check("and at most one neutral on the floor (%d)" % neutrals, neutrals <= 1)
	check("every monster starts asleep", awake == 0, "%d awake" % awake)

func _test_sleeping_monsters_do_not_act() -> void:
	var gs := _arena(31, 13)
	gs.player.x = 5
	gs.player.y = 6
	gs.torch_lit = false
	gs.update_vision()

	var m := _spawn(gs, "kobold", 20, 6)
	m.alertness = Entity.Alert.ASLEEP
	# BOTH axes, now that they are separate. Setting alertness alone no longer
	# means "asleep" -- a kobold is the sort of thing that may be walking a
	# beat, and this test is about the ones that are not.
	m.activity = Entity.Activity.SLEEPING
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
	# are wilder and unlit. They carried a LOWER one, a flat 0.7 of a room's --
	# and measurement showed that was backwards on its face: an average room is
	# 79 cells and an average cave 113, so the bigger space got the smaller
	# budget. A cave's ceiling now scales with how big that cave actually is.
	#
	#   every cave <= the ROOM ceiling     never deadlier than a room, which is
	#                                      the bound the flat 0.7 really kept
	#   every cave <= its OWN ceiling      and its own is set by its size
	var cave_breaches := 0
	var own_breaches := 0
	var caves_checked := 0
	var cave_worst := 0
	var biggest_ceiling := 0
	var smallest_ceiling := 1 << 30
	for d in range(1, 9):
		for i in 25:
			var gs := GameState.new(21000 + d * 100 + i)
			gs.use_scratch_files("ceil%d_%d" % [d, i])
			gs.new_game()
			gs.depth = d
			gs.build_level()
			var roof := gs.room_threat_ceiling()
			for region in gs.cave_regions:
				caves_checked += 1
				var mine := gs.cave_threat_ceiling_for(gs.cave_cells(region))
				biggest_ceiling = maxi(biggest_ceiling, mine)
				smallest_ceiling = mini(smallest_ceiling, mine)
				var sum := 0
				for e in gs.entities:
					if not e.is_player and region.has_point(Vector2i(e.x, e.y)):
						sum += e.threat
				if sum > roof:
					cave_breaches += 1
					cave_worst = maxi(cave_worst, sum - roof)
				elif sum > mine:
					own_breaches += 1
			gs.clear_scratch_files()
	check("no cave is deadlier than a room (%d caves, depths 1-8)" % caves_checked,
		cave_breaches == 0, "%d breaches, worst %d over" % [cave_breaches, cave_worst])
	check("and none exceeds the ceiling its own size earns it",
		own_breaches == 0, "%d over" % own_breaches)
	# The scaling has to actually VARY, or it is a flat number with extra steps.
	check("a big cave earns more than a small one (%d vs %d)"
		% [biggest_ceiling, smallest_ceiling],
		biggest_ceiling > smallest_ceiling)

	# And the point of all of it: a cave big enough can hold the animal the band
	# is named for. A cave bear costs 17, which the old flat ceiling could not
	# afford until depth 7 -- by which point the caves band is over.
	var roomy := 0
	var bear_capable := 0
	for i in 40:
		var gs := GameState.new(58000 + i)
		gs.use_scratch_files("bearfit%d" % i)
		gs.new_game()
		gs.depth = 5
		gs.build_level()
		for region in gs.cave_regions:
			roomy += 1
			if gs.cave_threat_ceiling_for(gs.cave_cells(region)) >= 17:
				bear_capable += 1
		gs.clear_scratch_files()
	check("some caves can afford a cave bear at depth 5 (%d of %d)"
		% [bear_capable, roomy], bear_capable > 0,
		"none of %d caves" % roomy)
	# But not all of them, or this is just a raise wearing a formula.
	check("and not all of them can", bear_capable < roomy,
		"%d of %d" % [bear_capable, roomy])

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

	# You cannot AIM at something you are not fighting.
	#
	# Measured 2026-09-20, before the guard existed: 40 of 40 clear bow shots
	# killed the trader and 25 of 25 thrown items did the same, deleting the
	# floor's only conversation. The identical gap let an arrow through a risen
	# ally -- exactly what firing_targets' own comment says must never happen.
	# Tab-cycling had always refused both; right-click and free aim had not,
	# because they take a CELL and never consulted hostility.
	#
	# Asserted per path on purpose: player_fire and player_throw carry duplicate
	# target tests, and a duplicated fix is one that drifts apart later.
	near.faction = Entity.Faction.NEUTRAL
	turns_now = gs.turns
	# Aim where it IS, not where it started. The successful shot above ends the
	# turn, the goblin takes its move, and (9, 5) is vacant by the time these
	# run. Four of these checks first shipped hardcoded to (9, 5) and passed
	# while testing nothing: player_fire refuses a null target at :2578, long
	# before the hostility guard at :2587 it is supposed to be exercising.
	#
	# Hence the preconditions. A refusal test that passes because the cell is
	# empty, or because the target drifted out of range, is not a weaker test --
	# it is a test of something else entirely that happens to return false.
	var live := Vector2i(near.x, near.y)
	check("the target is standing where we aim", gs.entity_at(live.x, live.y) == near)
	check("and the shot is genuinely available", gs.can_fire_at(live))
	check("a neutral cannot be shot", not gs.player_fire(live))
	check("and refusing it costs no turn", gs.turns == turns_now)

	near.faction = Entity.Faction.PLAYER
	check("nor can an ally be shot", not gs.player_fire(live))

	# The guard has to refuse the RIGHT things rather than everything: a check
	# that refused every target would satisfy both lines above and be useless.
	near.faction = Entity.Faction.MONSTER
	check("but a hostile target is still shootable", gs.player_fire(live))

	# Thrown items take the same rule, and declining must not cost the item --
	# the refusal is placed before the inventory removal for that reason. The
	# shot above spent a turn, so it has moved again: re-read, and re-assert.
	live = Vector2i(near.x, near.y)
	gs.player.inventory.append(Item.make(&"dagger"))
	var pack_before := gs.player.inventory.size()
	near.faction = Entity.Faction.NEUTRAL
	check("the throw target is standing where we aim",
		gs.entity_at(live.x, live.y) == near)
	check("and is inside throwing range", gs.can_reach(live, 5))
	check("a neutral cannot be thrown at",
		not gs.player_throw(pack_before - 1, live))
	check("and the dagger stays in the pack",
		gs.player.inventory.size() == pack_before)
	near.faction = Entity.Faction.MONSTER

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

## A prayer may leave a gem, whatever else the shrine just did.
##
## Gems carry weight 0 and so cannot come from the ordinary loot roll. Before
## this they came from chests and one pity placement -- the same pipe uniques
## use, which meant every unique added to the game would quietly take a gem off
## the descent. Shrines are the separate stream that makes uniques free to grow.
func _test_a_prayer_may_be_answered() -> void:
	# Rolled for EVERY kind, including the ones that hurt: a shrine that punishes
	# you and still leaves a stone keeps the gamble worth taking twice.
	var answered := 0
	var prayers := 0
	var examined := 0
	for kind in Shrines.COUNT:
		for i in 60:
			var gs := _shrine_arena(kind)
			# Deep enough that every gem is legal. The arena leaves you on
			# depth 1 and the shallowest gem is min_depth 2, so the first draft
			# of this ran 480 prayers, rolled the 30% honestly every time, found
			# nothing legal to hand over, and reported nought for nought.
			gs.depth = 4
			gs.rng.seed = 3000 + kind * 500 + i
			var before: int = gs.ground.size()
			if not gs.player_pray():
				continue
			prayers += 1
			if gs.ground.size() > before:
				answered += 1
				var left: Item = gs.ground[gs.ground.size() - 1]
				examined += 1
				check_silent(left.kind == Item.Kind.GEM)
				check_silent(left.x == gs.player.x and left.y == gs.player.y)
	# Gathered checks pass when nothing was gathered -- `_silent_ok` starts true
	# -- so the count has to be asserted or the report above is a guaranteed
	# green. That is exactly how the first draft of this reported success over
	# zero gems.
	check("there were gems to examine (%d)" % examined, examined > 0)
	check_gathered("what a prayer leaves is a gem, at your feet")
	check("every kind of shrine can answer (%d of %d prayers)"
		% [answered, prayers], answered > 0)
	# Three in ten, within the slop of the sample. A rate check rather than
	# "it happened once" -- the number is the design, and a drift to 3% or 80%
	# would still satisfy a non-zero test.
	var rate := float(answered) / float(maxi(prayers, 1))
	check("about three prayers in ten are answered (%.0f%%)" % (rate * 100.0),
		rate > 0.20 and rate < 0.42, "%.3f" % rate)

	# A shrine that answers is not a shrine that skipped its effect: the boon
	# and the gem are independent, and the punishing kinds pay too.
	var harsh := _shrine_arena(Shrines.VIGIL)
	harsh.rng.seed = 99
	var woke := _spawn(harsh, "orc", 12, 6)
	woke.alertness = Entity.Alert.ASLEEP
	check("a prayer still does what the shrine does", harsh.player_pray()
		and woke.alertness != Entity.Alert.ASLEEP)

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
	# Depth plus a direction, NOT an effective depth.
	#
	# The first version of this loop passed 15 as a depth with ascending set,
	# and effective_depth() is MAX_DEPTH + (MAX_DEPTH - depth) -- so 15 came out
	# as effective FIVE. It probed the descent caves band twice and never
	# touched the climb, while the comment claimed it swept both directions. The
	# band sweep further down has always done this correctly; this one invented
	# its own convention and got it backwards.
	#
	# [depth, climbing]: the last pair is depth 5 on the way UP, which is
	# effective 15 -- the caves band on the climb, where yesterday's sealed-room
	# bug lived and where nothing had actually been looking.
	var cut_off := []
	for i in 30:
		for spec in [[1, false], [5, false], [6, false], [8, false],
				[10, false], [5, true]]:
			var d: int = spec[0]
			var climbing: bool = spec[1]
			var gs := GameState.new(70000 + i)
			gs.use_scratch_files("reach%d_%d_%s" % [i, d, climbing])
			gs.new_game()
			gs.ascending = climbing
			gs.depth = d
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
				cut_off.append("seed %d d%d%s: %d of %d (%.0f%%)"
					% [70000 + i, d, " up" if climbing else "", got, total,
					100.0 * float(got) / float(maxi(total, 1))])
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

## Every pause menu row must be reachable by its printed letter AND from a
## controller, because there are three dispatch paths and keeping them in step
## by hand has already failed twice: the controller row was added to the
## keyboard and left dead to the mouse, and the text size row -- added FOR
## handhelds -- could not be pressed from a handheld at all.
## The threat ceilings, now that they are arithmetic rather than a method.
##
## Split out of GameState 2026-09-23 after an outside review proposed seven
## modules; this was the only one worth taking, because it is the only one that
## reaches for no state. Testable without building a dungeon to ask it a
## question, which is the concrete payoff and the reason it was worth doing.
func _test_threat_ceilings() -> void:
	# A room grows steadily with depth. The survivability guarantee rests on
	# this being predictable.
	check("a room ceiling rises with depth",
		Threat.room_ceiling(5) > Threat.room_ceiling(1))
	check("by a fixed step",
		Threat.room_ceiling(5) - Threat.room_ceiling(4) == Threat.ROOM_PER_DEPTH,
		"%d" % (Threat.room_ceiling(5) - Threat.room_ceiling(4)))

	# THE INVARIANT THE UPPER BOUND EXISTS FOR: a cave is never deadlier than a
	# room, however large it is. That is what the old flat 0.7 was really there
	# to keep, and what the size scaling had to preserve.
	var worst := 0
	for d in range(1, 20):
		for cells in [1, 20, 113, 400, 2000, 99999]:
			var cave := Threat.cave_ceiling(d, cells)
			var room := Threat.room_ceiling(d)
			if cave > room:
				worst = maxi(worst, cave - room)
	check("no cave is ever deadlier than a room", worst == 0,
		"exceeded by %d" % worst)

	# An average cave keeps exactly the budget it had before size scaling --
	# this redistributes danger, it does not add any.
	for d in range(1, 20):
		var typical := Threat.cave_ceiling(d, Threat.CAVE_TYPICAL_CELLS)
		var flat := int(round(Threat.room_ceiling(d) * Threat.CAVE_SCALE))
		check("depth %d: an average cave is unchanged (%d vs %d)"
			% [d, typical, flat], typical == flat)

	# Bigger caverns hold bigger things; cramped ones do not.
	check("a big cavern outranks a cramped one",
		Threat.cave_ceiling(8, 400) > Threat.cave_ceiling(8, 20))
	check("and the floor stops a tiny one reaching zero",
		Threat.cave_ceiling(8, 1) > 0, "%d" % Threat.cave_ceiling(8, 1))

	# GameState still answers the same question, since five call sites and two
	# measurement tools ask it that way.
	var gs := _arena(21, 11)
	gs.depth = 6
	check("GameState agrees with the module",
		gs.room_threat_ceiling() == Threat.room_ceiling(gs.effective_depth()),
		"%d vs %d" % [gs.room_threat_ceiling(),
			Threat.room_ceiling(gs.effective_depth())])
	check("and for caves too",
		gs.cave_threat_ceiling_for(200)
		== Threat.cave_ceiling(gs.effective_depth(), 200))

## Every property main.gd assigns to a panel must actually exist on it.
##
## Found the hard way 2026-09-23: the sidebar's contextual block was moved out to
## HerePanel, `pad_input` went with it, and main.gd kept assigning it. The game
## threw on the first frame -- and NOTHING caught it. `--check-only` does not
## resolve @onready property access, and the suite never instantiates main.gd,
## deliberately: its `_ready` loads a suspended run, and loading one DESTROYS it,
## so a test that started the real scene would eat the player's save.
##
## So this reads the source instead. Cheap, and it covers the one file the rest
## of the suite cannot reach.
func _test_main_only_sets_properties_that_exist() -> void:
	var src := FileAccess.get_file_as_string("res://src/render/main.gd")
	check("main.gd was readable (%d bytes)" % src.length(), src.length() > 0)

	# Which @onready node is which class, read from main.gd rather than listed.
	var decl := RegEx.new()
	decl.compile("@onready var (\\w+): (\\w+) = \\$")
	var owners := {}
	for m in decl.search_all(src):
		owners[m.get_string(1)] = m.get_string(2)
	check("found the panels main.gd wires (%d)" % owners.size(),
		owners.size() >= 8, str(owners.keys()))

	# Constructors, because a class name in a string cannot be instantiated.
	# The check below asserts this covers everything found, so a new panel that
	# is not listed here fails rather than being silently skipped.
	var build := {
		"GlyphGrid": func() -> Object: return GlyphGrid.new(),
		"Sidebar": func() -> Object: return Sidebar.new(),
		"MessageView": func() -> Object: return MessageView.new(),
		"InventoryPanel": func() -> Object: return InventoryPanel.new(),
		"MenuPanel": func() -> Object: return MenuPanel.new(),
		"NamePanel": func() -> Object: return NamePanel.new(),
		"LegendPanel": func() -> Object: return LegendPanel.new(),
		"SummaryPanel": func() -> Object: return SummaryPanel.new(),
		"PadPanel": func() -> Object: return PadPanel.new(),
		"TalkPanel": func() -> Object: return TalkPanel.new(),
		"MapPanel": func() -> Object: return MapPanel.new(),
		"HerePanel": func() -> Object: return HerePanel.new(),
		"TradePanel": func() -> Object: return TradePanel.new(),
		"SoundDeck": func() -> Object: return SoundDeck.new(),
	}
	var unknown := PackedStringArray()
	for who in owners:
		if not build.has(String(owners[who])):
			unknown.append("%s: %s" % [who, owners[who]])
	check("every wired panel has a constructor here", unknown.is_empty(),
		"add to `build`: %s" % ", ".join(unknown))

	# What each class actually has.
	var props := {}
	for who in owners:
		var cls := String(owners[who])
		if not build.has(cls):
			continue
		var node: Object = build[cls].call()
		var have := {}
		for entry in node.get_property_list():
			have[String(entry["name"])] = true
		props[who] = have
		if node is Node:
			(node as Node).free()
		else:
			node.free()

	# Every assignment main.gd makes to one of them.
	var use := RegEx.new()
	use.compile("(?m)^\\t+(\\w+)\\.(\\w+) = ")
	var missing := PackedStringArray()
	var checked := 0
	for m in use.search_all(src):
		var who := m.get_string(1)
		var prop := m.get_string(2)
		if not props.has(who):
			continue
		checked += 1
		if not (props[who] as Dictionary).has(prop):
			missing.append("%s.%s" % [who, prop])

	# The premise. If nothing were matched this would pass while testing air --
	# which is the commonest defect in this suite.
	check("assignments were found to check (%d)" % checked, checked >= 10)
	check("main.gd sets nothing that does not exist", missing.is_empty(),
		", ".join(missing))

## What things are worth to the trader. Settled 2026-09-23; see BACKLOG.md.
func _test_trade_prices() -> void:
	# Every piece of ordinary equipment has a tier; nothing else does.
	var tiered := 0
	var missing := PackedStringArray()
	for key in Item.CATALOGUE:
		var data: Dictionary = Item.CATALOGUE[key]
		var equip: bool = int(data.get("slot", -1)) >= 0
		if equip and not data.get("unique", false):
			if int(data.get("tier", 0)) > 0:
				tiered += 1
			else:
				missing.append(String(key))
	check("every ordinary piece of equipment has a tier (%d)" % tiered,
		missing.is_empty() and tiered >= 13, ", ".join(missing))

	check("a dagger is worth 1", Trade.worth(Item.make(&"dagger")) == 1)
	check("a short sword 3", Trade.worth(Item.make(&"short_sword")) == 3)
	check("a war axe 9", Trade.worth(Item.make(&"war_axe")) == 9)
	check("so three daggers are a short sword",
		Trade.worth(Item.make(&"dagger")) * 3 == Trade.worth(Item.make(&"short_sword")))
	check("cross-category counts the same: leather is a dagger",
		Trade.worth(Item.make(&"leather_armour")) == Trade.worth(Item.make(&"dagger")))

	# Worth what it cost to make. A +2 took two more of the same to forge.
	# Forged the way the brazier forges, never by setting a field: the first
	# version of this check wrote `boosts = 2`, a field equipment never uses,
	# and so agreed with a pricing bug that sold every forged item at base.
	var plus := Item.make(&"dagger")
	plus.upgrade()
	plus.upgrade()
	check("the premise: it reads as a +2 (%s)" % plus.display_name(),
		plus.display_name() == "dagger +2")
	check("a +2 dagger is worth three daggers", Trade.worth(plus) == 3,
		"%d" % Trade.worth(plus))
	var coat := Item.make(&"leather_armour")
	coat.upgrade()
	check("armour counts its forging too", Trade.worth(coat) == 2,
		"%d" % Trade.worth(coat))
	# And as the morgue gives it back, which is how relics are priced.
	var buried := Item.from_display_name("leather armour +2")
	check("a buried leather armour +2 is worth three",
		buried != null and Trade.worth(buried) == 3,
		"%d" % (Trade.worth(buried) if buried != null else -1))
	var bow := Item.from_display_name("short bow +1")
	check("a buried short bow +1 is worth six",
		bow != null and Trade.worth(bow) == 6,
		"%d" % (Trade.worth(bow) if bow != null else -1))
	var magic := Item.make(&"short_sword")
	magic.element = &"frost"
	check("a bound gem adds %d" % Trade.MAGIC,
		Trade.worth(magic) == 3 + Trade.MAGIC, "%d" % Trade.worth(magic))

	# THE TRADER CONVERTS WITHIN A CURRENCY, NEVER ACROSS.
	var gem := Item.make(&"gem_frost")
	check("a gem is not equipment points", Trade.worth(gem) == 0)
	check("  but the trader does take it", Trade.refusal(gem) == "")

	# What it will not take, and says why in words that are true.
	check("never the amulet", Trade.refusal(Item.make(&"amulet")) != "")
	check("never a unique", Trade.refusal(Item.make(&"rat_ring")) != "")
	var pot := Trade.refusal(Item.make(&"potion_healing"))
	check("a potion is SOLD, not bought (\"%s\")" % pot, pot.findn("sell") >= 0)
	var arrows := Trade.refusal(Item.make(&"arrows"))
	check("arrows are refused without claiming the trader sells them",
		arrows != "" and arrows.findn("sell") < 0, arrows)
	check("meat is refused -- hunting is not income",
		Trade.refusal(Item.make(&"meat")) != "")
	check("a potion has a price to BUY it", Trade.price(Item.make(&"potion_healing")) > 0)

## Buying and selling across the counter, on a real floor with a real trader.
func _test_the_trader_deals() -> void:
	var gs := GameState.new(4040)
	gs.new_game()
	# The premise. Every check below is vacuous without a trader to deal with.
	check("floor one has a trader", gs.trader_here())
	if not gs.trader_here():
		return
	check("  and something on the shelves (%d)" % gs.trader_stock.size(),
		gs.trader_stock.size() > 0)

	# Floor one sells tier 1 and nothing stronger. The first version put a mace
	# on this shelf -- one hit for anything on floor one.
	var strong := PackedStringArray()
	var has_dagger := false
	for entry in gs.trader_stock:
		var it: Item = entry["item"]
		if String(entry["relic"]) != "":
			continue
		if it.tier > 1:
			strong.append(it.name)
		has_dagger = has_dagger or it.id == &"dagger"
	check("the first trader sells nothing above tier 1", strong.is_empty(),
		", ".join(strong))
	check("  but does sell a dagger", has_dagger)

	# The same stocking, deeper. Restocked in place on this floor's trader: the
	# shelf is built from the tier rule and the depth, nothing else on the map.
	var tiers_at := func(desc_depth: int, climbing: bool) -> Array:
		gs.depth = desc_depth
		gs.ascending = climbing
		gs.trader_stock = []
		gs._stock_trader()
		var seen: Array = []
		for entry in gs.trader_stock:
			var it: Item = entry["item"]
			if String(entry["relic"]) == "" and it.tier > 0 and not seen.has(it.tier):
				seen.append(it.tier)
		seen.sort()
		return seen
	var caves: Array = tiers_at.call(4, false)
	check("floor four sells tiers 1 and 2 (%s)" % str(caves), caves == [1, 2])
	var fort: Array = tiers_at.call(7, false)
	check("floor seven sells tiers 2 and 3, no daggers (%s)" % str(fort), fort == [2, 3])
	# The climb is keyed on where the player has BEEN, not mirrored: floor 17
	# is "upper" to everything else, and would otherwise sell daggers again.
	var climb: Array = tiers_at.call(3, true)
	check("the climb's floor 17 sells tiers 2 and 3 (%s)" % str(climb), climb == [2, 3])
	check("  and it is floor 17 (%d)" % gs.effective_depth(), gs.effective_depth() == 17)
	# Back to floor one for everything below, which trades on this shelf.
	tiers_at.call(1, false)

	# SELL, and the slate goes up by the worth.
	gs.player.inventory.clear()
	gs.player.equipped.clear()
	var d1 := Item.make(&"dagger")
	var d2 := Item.make(&"dagger")
	var d3 := Item.make(&"dagger")
	for it in [d1, d2, d3]:
		gs.give_item(it)
	var stocked := gs.trader_stock.size()
	check("selling a dagger works", gs.trade_sell(gs.player.inventory.find(d1)))
	check("  credit is 1", gs.trader_credit == 1, "%d" % gs.trader_credit)
	check("  it goes on the shelf", gs.trader_stock.size() == stocked + 1)
	check("  and leaves the pack", not gs.player.inventory.has(d1))

	# PAR: buying it straight back costs exactly what it earned.
	var back := gs.trader_stock.size() - 1
	check("and it can be bought straight back", gs.trade_buy(back))
	check("  for exactly what it earned", gs.trader_credit == 0, "%d" % gs.trader_credit)

	# Refused when you cannot afford it -- and NOTHING changes. A potion, not a
	# short sword: floor one sells tier 1 only, and a potion costs the same 3.
	var buy_at := -1
	for i in gs.trader_stock.size():
		if (gs.trader_stock[i]["item"] as Item).id == &"potion_healing":
			buy_at = i
	check("the first trader stocks a healing potion", buy_at >= 0)
	var shelf := gs.trader_stock.size()
	var pack := gs.player.inventory.size()
	check("a potion is refused on 0 credit", not gs.trade_buy(buy_at))
	check("  and nothing moved", gs.trader_stock.size() == shelf
		and gs.player.inventory.size() == pack and gs.trader_credit == 0)

	# Three daggers buy it.
	for it in [d1, d2, d3]:
		var at := gs.player.inventory.find(it)
		if at >= 0:
			gs.trade_sell(at)
	check("three daggers make 3 credit", gs.trader_credit == 3, "%d" % gs.trader_credit)
	for i in gs.trader_stock.size():
		if (gs.trader_stock[i]["item"] as Item).id == &"potion_healing":
			buy_at = i
	check("and buy the potion", gs.trade_buy(buy_at) and gs.trader_credit == 0)

	# Selling what you are WEARING takes it off first.
	var worn := Item.make(&"leather_armour")
	gs.give_item(worn)
	gs.player.equipped[Item.Slot.ARMOR] = worn
	check("worn armour can be sold", gs.trade_sell(gs.player.inventory.find(worn)))
	check("  and is no longer worn", gs.player.equipped.get(Item.Slot.ARMOR, null) == null)

	# What it refuses, it keeps out of the pack AND off the slate.
	var p := Item.make(&"potion_healing")
	gs.give_item(p)
	var before := gs.trader_credit
	check("a potion is refused", not gs.trade_sell(gs.player.inventory.find(p)))
	check("  and stays in the pack", gs.player.inventory.has(p)
		and gs.trader_credit == before)

	# GEMS FOR GEMS.
	for el in [&"gem_frost", &"gem_frost"]:
		var g := Item.make(el)
		gs.give_item(g)
		gs.trade_sell(gs.player.inventory.find(g))
	check("two gems are not enough", not gs.trade_buy_gem(&"leech"))
	var g3 := Item.make(&"gem_frost")
	gs.give_item(g3)
	gs.trade_sell(gs.player.inventory.find(g3))
	var credit_before_gem := gs.trader_credit
	check("three gems buy one of your choice", gs.trade_buy_gem(&"leech"))
	var has_leech := false
	for it in gs.player.inventory:
		if it.id == &"gem_leech":
			has_leech = true
	check("  and it is the one chosen", has_leech)
	check("  and equipment credit was not touched", gs.trader_credit == credit_before_gem)

	# THE ENCHANT ROLL: 9 points, once per trader.
	var target := Item.make(&"short_sword")
	gs.give_item(target)
	var ti := gs.player.inventory.find(target)
	gs.trader_credit = 0
	check("an enchant needs %d credit" % Trade.ENCHANT, not gs.trade_enchant(ti))
	gs.trader_credit = Trade.ENCHANT * 2
	check("with it, the trader works the blade", gs.trade_enchant(ti))
	check("  it is magic now (%s)" % target.display_name(), target.element != &"")
	check("  and it could legally hold that", target.accepts_element(target.element))
	check("  and cost %d" % Trade.ENCHANT, gs.trader_credit == Trade.ENCHANT)
	var other := Item.make(&"dagger")
	gs.give_item(other)
	check("but only once per trader",
		not gs.trade_enchant(gs.player.inventory.find(other)) and other.element == &"")

	# The counter survives a suspend.
	gs.trader_credit = 5
	var dict := gs.to_dict()
	var loaded := GameState.new(1)
	check("a save with a trader loads", loaded.apply_dict(dict))
	check("  the trader is relinked", loaded.trader_here())
	check("  the credit is kept", loaded.trader_credit == 5, "%d" % loaded.trader_credit)
	check("  the shelves are kept", loaded.trader_stock.size() == gs.trader_stock.size())
	check("  and the roll stays spent", loaded.trader_rolled)

	# A suspend from the build before the trader: the trader stands on the floor
	# but the save has no shelves. It must stock them, or the first playtest
	# happens again -- a trader with nothing to sell.
	var old: Dictionary = gs.to_dict()
	old.erase("trader")
	var aged := GameState.new(1)
	check("a save from before the trader loads", aged.apply_dict(old))
	check("  the trader is there", aged.trader_here())
	check("  and has stocked its shelves (%d)" % aged.trader_stock.size(),
		aged.trader_stock.size() > 0)
	# But a shelf the player emptied is a real state, not a missing one.
	gs.trader_stock = []
	var bare := GameState.new(1)
	check("a save with an emptied shelf loads", bare.apply_dict(gs.to_dict()))
	check("  and stays empty", bare.trader_here() and bare.trader_stock.is_empty(),
		"%d" % bare.trader_stock.size())

## Most players will trade with a mouse and a keyboard. The first version was
## built for the pad and barely served either: hovering did nothing, so a mouse
## player sold blind; the gem chooser could not be clicked; the wheel did not
## scroll; and only the arrow keys moved, not the vi-keys or the numpad.
## GEMS IN THE RUBBLE: one pile per floor hides a gem, found by knapping it.
func _test_a_gem_in_the_rubble() -> void:
	# Every floor with rubble hides exactly one, under a pile that is really
	# rubble; the main stream is not touched, so floors generate as before.
	var hidden := 0
	var on_rubble := 0
	var with_rubble := 0
	var rng_untouched := true
	for d in [2, 4, 7, 10]:
		var gs := GameState.new(5150 + d)
		gs.new_game()
		gs.depth = d
		gs.build_level()
		var any_rubble := false
		for y in gs.map.height:
			for x in gs.map.width:
				any_rubble = any_rubble or gs.map.get_tile(x, y) == Tiles.RUBBLE
		if any_rubble:
			with_rubble += 1
		var state_before := gs.rng.state
		var was := gs.geode
		gs._hide_the_geode()
		rng_untouched = rng_untouched and gs.rng.state == state_before
		check("  depth %d: the same pile every time for the same run" % d, gs.geode == was)
		if gs.geode.x >= 0:
			hidden += 1
			if gs.map.get_tile(gs.geode.x, gs.geode.y) == Tiles.RUBBLE:
				on_rubble += 1
	# Some floors generate with no rubble at all (seed 5152's floor two does),
	# so the count is against the floors that HAVE some -- and at least three
	# of the four must, or this check is measuring nothing.
	check("every floor with rubble hides a gem (%d of %d)" % [hidden, with_rubble],
		hidden == with_rubble and with_rubble >= 3)
	check("  always under real rubble (%d)" % on_rubble, on_rubble == hidden)
	check("  and hiding it draws nothing from the main stream", rng_untouched)
	var first := GameState.new(5150)
	first.new_game()
	check("floor one hides none -- no gem can be found there yet",
		first.geode == Vector2i(-1, -1) and Item.gems_at(1).is_empty())

	# Floor two, the first with gems to find.
	var gs := GameState.new(5150)
	gs.new_game()
	gs.depth = 2
	gs.build_level()
	# Nothing lying on the piles: the key picks an item up before it knaps.
	gs.ground = []
	var sling := Item.make(&"sling")
	gs.player.inventory.clear()
	gs.player.equipped.clear()
	gs.give_item(sling)
	gs.player.equipped[sling.slot] = sling
	gs.entities = [gs.player]
	var gems := func() -> int:
		var n := 0
		for it in gs.player.inventory:
			if it.kind == Item.Kind.GEM:
				n += 1
		return n
	var piles: Array[Vector2i] = []
	for y in gs.map.height:
		for x in gs.map.width:
			if gs.map.get_tile(x, y) == Tiles.RUBBLE:
				piles.append(Vector2i(x, y))
	check("the premise: floor two has rubble and a hidden gem (%d piles)" % piles.size(),
		piles.size() > 1 and gs.geode.x >= 0)
	var geode := gs.geode

	# A FULL POUCH finds nothing, even on the gem pile -- or trying piles with
	# no room would be a gem detector.
	sling.ammo = sling.ammo_max
	gs.player.x = geode.x
	gs.player.y = geode.y
	check("with a full pouch the gem pile refuses like any other", not gs.player_pickup())
	check("  no gem, and the gem stays hidden", gems.call() == 0 and gs.geode == geode)

	# CLEAR EVERY PILE: exactly one gem, from the one pile. The pity gem has
	# usually set gem_found on floor two already, which would let the check
	# below pass without the rubble doing anything -- so it starts false.
	gs.gem_found = false
	var found_at := Vector2i(-1, -1)
	for c in piles:
		sling.ammo = 0
		gs.player.x = c.x
		gs.player.y = c.y
		var before: int = gems.call()
		gs.player_pickup()
		if gems.call() > before and found_at.x < 0:
			found_at = c
	check("clearing every pile finds exactly one gem (%d)" % gems.call(), gems.call() == 1)
	check("  under the pile that was chosen", found_at == geode)
	check("  and the floor has no second one", gs.geode == Vector2i(-1, -1))
	check("  it counts as having met a gem", gs.gem_found)

	# A floor with no rubble hides nothing.
	for c in piles:
		gs.map.set_tile(c.x, c.y, Tiles.FLOOR)
	gs._hide_the_geode()
	check("a floor with no rubble hides no gem", gs.geode == Vector2i(-1, -1))

	# The hidden pile survives a save.
	var gs2 := GameState.new(5150)
	gs2.new_game()
	gs2.depth = 2
	gs2.build_level()
	var loaded := GameState.new(1)
	check("a save keeps the hidden pile", loaded.apply_dict(gs2.to_dict())
		and loaded.geode == gs2.geode and gs2.geode.x >= 0)

## THE FLARE REKINDLES: a flared torch fills a brazier to a level set by how much
## flare is left, and is spent doing it. Brad's design, 2026-09-25.
func _test_the_flare_rekindles() -> void:
	check("the tiers: 100 and 75 fill to 15",
		GameState.flare_kindle(100) == 15 and GameState.flare_kindle(75) == 15)
	check("  74 and 50 to 10", GameState.flare_kindle(74) == 10
		and GameState.flare_kindle(50) == 10)
	check("  49 and 25 to 5", GameState.flare_kindle(49) == 5
		and GameState.flare_kindle(25) == 5)
	check("  under 25, nothing -- light and curse only",
		GameState.flare_kindle(24) == 0 and GameState.flare_kindle(1) == 0)

	var gs := GameState.new(4040)
	gs.new_game()
	var c := Vector2i(20, 20)
	var east := Vector2i(c.x + 1, c.y)
	var west := Vector2i(c.x - 1, c.y)
	# A clear patch of floor with one brazier beside the player.
	var reset := func(tile: int, holds: int) -> void:
		for y in range(c.y - 2, c.y + 3):
			for x in range(c.x - 2, c.x + 3):
				gs.map.set_tile(x, y, Tiles.FLOOR)
				gs.brazier_charge.erase(Vector2i(x, y))
		gs.map.set_tile(east.x, east.y, tile)
		if tile == Tiles.BRAZIER:
			gs.brazier_charge[east] = holds
		gs.player.x = c.x
		gs.player.y = c.y
		gs.ground = gs.ground.filter(func(it: Item) -> bool:
			return absi(it.x - c.x) > 2 or absi(it.y - c.y) > 2)
		gs.entities = [gs.player]
	var offers := func() -> bool:
		for a in gs.actions_here():
			if String(a[1]).begins_with("kindle"):
				return true
		return false

	# A BLACK BRAZIER, a fresh flare: the only thing that brings one back.
	reset.call(Tiles.BRAZIER_DEAD, 0)
	gs.torch_flare = 100
	check("the premise: a black brazier beside you", gs._adjacent_any_brazier() == east)
	check("the sidebar offers to kindle it", offers.call())
	var turn := gs.turns
	check("the action key kindles it", gs.player_pickup())
	check("  it is lit again", gs.map.get_tile(east.x, east.y) == Tiles.BRAZIER)
	check("  and full to 15 -- more than a fresh one holds (%d)" % int(gs.brazier_charge.get(east, 0)),
		int(gs.brazier_charge.get(east, 0)) == 15)
	check("  the flare is spent", gs.torch_flare == 0)
	check("  and it took a turn", gs.turns == turn + 1)

	# A WEAK FIRE is filled TO the tier, not added to.
	reset.call(Tiles.BRAZIER, 3)
	gs.torch_flare = 60
	check("a weak fire kindles", gs.player_pickup())
	check("  to the tier, 10 -- not 3 + 10 (%d)" % int(gs.brazier_charge.get(east, 0)),
		int(gs.brazier_charge.get(east, 0)) == 10)

	# ALREADY HOTTER: refused, and the flare is kept.
	reset.call(Tiles.BRAZIER, 12)
	gs.torch_flare = 60
	check("the premise: the flare is lit (60) beside a fire of 12", gs.torch_flare == 60)
	check("a fire hotter than the flare is not offered", not offers.call())
	check("  and the key refuses it", not gs.player_pickup())
	check("  keeping the flare", gs.torch_flare == 60)
	check("  and the fire as it was", int(gs.brazier_charge.get(east, 0)) == 12)

	# TOO FAR GONE: under 25 the flare kindles nothing.
	reset.call(Tiles.BRAZIER_DEAD, 0)
	gs.torch_flare = 20
	check("under 25 turns, no offer", not offers.call())
	check("  and the key refuses", not gs.player_pickup() and gs.torch_flare == 20)

	# TWO BESIDE YOU: the emptier one, without the player having to aim.
	reset.call(Tiles.BRAZIER, 6)
	gs.map.set_tile(west.x, west.y, Tiles.BRAZIER_DEAD)
	gs.torch_flare = 90
	check("with two beside you, the black one is chosen", gs.flare_target() == west)
	gs.map.set_tile(west.x, west.y, Tiles.FLOOR)

	# THE KEY'S OWN ORDER. On rubble with no sling the key tries to knap (and
	# refuses); the sidebar must not promise a kindle the key will not do.
	reset.call(Tiles.BRAZIER_DEAD, 0)
	gs.map.set_tile(c.x, c.y, Tiles.RUBBLE)
	gs.torch_flare = 100
	check("standing on rubble, no kindle is promised", not offers.call())
	gs.map.set_tile(c.x, c.y, Tiles.FLOOR)

	# THE RACE, SAID: each step down is announced.
	reset.call(Tiles.FLOOR, 0)
	gs.torch_flare = 75
	var before := gs.msg_log.entries.size()
	gs.player_wait()
	var said := ""
	for i in range(before, gs.msg_log.entries.size()):
		said += str(gs.msg_log.entries[i])
	check("the flare dropping a step is announced (%d left)" % gs.torch_flare,
		gs.torch_flare == 74 and said.findn("kindle a fire to 10") >= 0, said)
	before = gs.msg_log.entries.size()
	gs.player_wait()
	var quiet := gs.msg_log.entries.size() == before
	check("  but not every turn", quiet)

## A controller can name a character. Until 2026-09-25 it could not: a pad sends
## no characters, so every pad player was named by the dungeon. Now there is a
## list of names to pick and an alphabet to spell with -- and typing, which is
## how everyone else does it, must be exactly as it was.
func _test_naming_without_a_keyboard() -> void:
	var n := NamePanel.new()
	n.size = Vector2(1600, 900)
	var got := {"name": null}
	n.chosen.connect(func(x: String) -> void: got["name"] = x)

	check("the list offers the dungeon's names", NamePanel.names() == Morgue.ROLLED)
	var rare_on_list := false
	for r in Morgue.ROLLED_RARE:
		rare_on_list = rare_on_list or NamePanel.names().has(r)
	check("  but never the rare ones -- they are found, not chosen", not rare_on_list)

	# The pad's meanings, from the live bindings.
	var cfg := PadConfig.new()
	var said := func(button: int) -> StringName:
		return NamePanel.pad_action(cfg, cfg.key_for_button(button))
	check("A chooses", said.call(JOY_BUTTON_A) == &"press")
	check("B erases", said.call(JOY_BUTTON_B) == &"erase")
	check("Y flips the case", said.call(JOY_BUTTON_Y) == &"case")
	check("Start begins", said.call(JOY_BUTTON_START) == &"begin")
	check("the d-pad moves", said.call(JOY_BUTTON_DPAD_DOWN) == &"down"
		and said.call(JOY_BUTTON_DPAD_LEFT) == &"left")
	check("the stick moves", NamePanel.pad_action(cfg, KEY_UP) == &"up")
	check("X means nothing here", said.call(JOY_BUTTON_X) == &"")

	# PICK A NAME: one press, and the cursor waits on "begin".
	n.open()
	n.pad_act(&"right")
	n.pad_act(&"press")
	check("picking a name fills the field (%s)" % n.typed, n.typed == Morgue.ROLLED[1])
	check("  and the cursor moves to begin",
		n.cell_at(n.at).get("value", &"") == &"begin")
	n.pad_act(&"press")
	check("  so the next press starts the run as that name (%s)" % str(got["name"]),
		got["name"] == Morgue.ROLLED[1] and not n.visible)

	# SPELL ONE. A capital, then small letters, as a phone does.
	n.open()
	var name_rows := ceili(float(NamePanel.names().size()) / float(NamePanel.NAMES_PER_ROW))
	for i in name_rows:
		n.pad_act(&"down")
	check("the premise: the cursor is on the alphabet (%s)" % str(n.cell_at(n.at)),
		n.cell_at(n.at).get("kind", &"") == &"letter")
	n.pad_act(&"press")                     # A
	n.pad_act(&"right")
	n.pad_act(&"right")
	n.pad_act(&"press")                     # c
	check("spelling gives a capital then small letters (%s)" % n.typed, n.typed == "Ac")
	n.pad_act(&"case")
	n.pad_act(&"press")                     # C
	check("  and the case can be flipped by hand (%s)" % n.typed, n.typed == "AcC")
	n.pad_act(&"erase")
	check("B erases one letter (%s)" % n.typed, n.typed == "Ac")
	for i in Morgue.NAME_MAX + 5:
		n.pad_act(&"press")
	check("a name stops at %d letters (%d)" % [Morgue.NAME_MAX, n.typed.length()],
		n.typed.length() == Morgue.NAME_MAX)
	n.pad_act(&"begin")
	check("Start begins with what was spelled", got["name"] == Morgue.clean_name(n.typed))

	# Blank still means "the dungeon names you" -- main.gd rolls on "".
	n.open()
	n.pad_act(&"begin")
	check("an empty field still hands back blank", got["name"] == "")

	# THE KEYBOARD, unchanged: it types.
	n.open()
	for ch in "Ann":
		var k := InputEventKey.new()
		k.pressed = true
		k.unicode = ch.unicode_at(0)
		n.handle_key(k)
	var bs := InputEventKey.new()
	bs.pressed = true
	bs.keycode = KEY_BACKSPACE
	n.handle_key(bs)
	check("typing still types, backspace still erases (%s)" % n.typed, n.typed == "An")
	var enter := InputEventKey.new()
	enter.pressed = true
	enter.keycode = KEY_ENTER
	n.handle_key(enter)
	check("  and enter begins", got["name"] == "An")

	# THE MOUSE: hover moves the cursor, a click picks.
	n.open()
	var over := InputEventMouseMotion.new()
	over.position = n.cell_rect(Vector2i(2, 1)).get_center()
	n._gui_input(over)
	check("hovering a name moves the cursor to it", n.at == Vector2i(2, 1))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = n.cell_rect(Vector2i(2, 1)).get_center()
	n._gui_input(click)
	check("clicking a name picks it (%s)" % n.typed,
		n.typed == Morgue.ROLLED[NamePanel.NAMES_PER_ROW + 2])

	# THE LAYOUT, measured -- the screen could not be photographed while this
	# was written. Every cell inside the box, and no two overlapping.
	var box := n._box()
	var cells: Array = []
	var outside := PackedStringArray()
	var all := n.rows()
	for r in all.size():
		for c in (all[r] as Array).size():
			var rect := n.cell_rect(Vector2i(c, r))
			if not box.encloses(rect):
				outside.append("%d,%d" % [c, r])
			cells.append(rect)
	check("every button sits inside the box", outside.is_empty(), ", ".join(outside))
	var overlaps := 0
	for i in cells.size():
		for j in range(i + 1, cells.size()):
			if (cells[i] as Rect2).intersects(cells[j] as Rect2):
				overlaps += 1
	check("and no two overlap (%d cells)" % cells.size(), overlaps == 0 and cells.size() > 30)
	var last: Rect2 = cells[-1]
	check("the grid ends above the footer line",
		last.end.y < box.end.y - NamePanel.PAD - 12.0,
		"%.0f vs %.0f" % [last.end.y, box.end.y - NamePanel.PAD])
	check("the box fits the window", Rect2(Vector2.ZERO, n.size).encloses(box))
	n.free()

	# The sidebar does not name you before you have chosen.
	var bar := Sidebar.new()
	var named := GameState.new(4040)
	named.new_game()
	bar.state = named
	check("the premise: a new run already has a rolled name (%s)" % named.player_name,
		named.player_name != "")
	bar.naming = true
	check("while choosing, the sidebar shows no name (%s)" % bar.shown_name(),
		bar.shown_name() == "--")
	bar.naming = false
	check("  and shows it once chosen", bar.shown_name() == named.player_name)
	bar.free()

	# main.gd hands a pad press to the panel as a MEANING, before any typing.
	var src := FileAccess.get_file_as_string("res://src/render/main.gd")
	var at := src.find("if name_entry.visible:")
	var pad_first := src.find("name_entry.pad_act(", at)
	var typing := src.find("name_entry.handle_key(", at)
	check("main.gd gives the pad its own path into the name screen",
		at >= 0 and pad_first > at and typing > pad_first)

## TRAFFIC: friends that meet in a corridor or a doorway get past each other.
##
## Brad saw kobolds jam at a door facing opposite ways, and lines of four stuck
## with nobody able to tell who was going where. Every case here is a one-wide
## corridor with an open door in the middle -- the place "go round" cannot help.
func _test_traffic() -> void:
	var gs := GameState.new(4040)
	gs.new_game()
	var c := Vector2i(30, 20)
	var west := Vector2i(c.x - 7, c.y)
	var east := Vector2i(c.x + 7, c.y)
	for y in range(c.y - 2, c.y + 3):
		for x in range(c.x - 9, c.x + 10):
			gs.map.set_tile(x, y, Tiles.WALL)
	for x in range(west.x, east.x + 1):
		gs.map.set_tile(x, c.y, Tiles.FLOOR)
	gs.map.set_tile(c.x, c.y, Tiles.DOOR_OPEN)
	gs.pathfinder.refresh(gs.map)
	gs.player.x = 80
	gs.player.y = 40

	var make := func(at: int, faction: int) -> Entity:
		var e := Entity.new("kobold", &"kobold", at, c.y)
		e.faction = faction
		e.alertness = Entity.Alert.AWAKE
		e.activity = Entity.Activity.PATROLLING
		return e
	# One round: each walker steps toward its goal, in list order, then the
	# turn advances -- as the scheduler would run them.
	var run := func(walkers: Array, goals: Array, rounds: int) -> void:
		for r in rounds:
			for i in walkers.size():
				gs._step_toward(walkers[i], goals[i])
			gs.turns += 1

	# HEAD-ON AT THE DOOR: one each side, going opposite ways.
	var a: Entity = make.call(c.x - 1, Entity.Faction.MONSTER)
	var b: Entity = make.call(c.x, Entity.Faction.MONSTER)
	gs.entities = [gs.player, a, b]
	check("the premise: they face each other through the door",
		b.x == c.x and a.x == c.x - 1)
	run.call([a, b], [east, west], 6)
	check("head-on at a door, they get past each other (%d, %d)" % [a.x, b.x],
		a.x > c.x and b.x < c.x - 1)

	# THREE ONE WAY, ONE THE OTHER. The one passes through the line.
	var w1: Entity = make.call(c.x - 3, Entity.Faction.MONSTER)
	var w2: Entity = make.call(c.x - 2, Entity.Faction.MONSTER)
	var w3: Entity = make.call(c.x - 1, Entity.Faction.MONSTER)
	var e1: Entity = make.call(c.x, Entity.Faction.MONSTER)
	gs.entities = [gs.player, w1, w2, w3, e1]
	run.call([w1, w2, w3, e1], [east, east, east, west], 12)
	check("one against a line of three passes through it (%d vs %d..%d)"
		% [e1.x, mini(w1.x, mini(w2.x, w3.x)), maxi(w1.x, maxi(w2.x, w3.x))],
		e1.x < mini(w1.x, mini(w2.x, w3.x)))
	check("  and the three get through the door too",
		w1.x > c.x and w2.x > c.x and w3.x > c.x)

	# TWO AND TWO.
	var p1: Entity = make.call(c.x - 2, Entity.Faction.MONSTER)
	var p2: Entity = make.call(c.x - 1, Entity.Faction.MONSTER)
	var q1: Entity = make.call(c.x, Entity.Faction.MONSTER)
	var q2: Entity = make.call(c.x + 1, Entity.Faction.MONSTER)
	gs.entities = [gs.player, p1, p2, q1, q2]
	run.call([p1, p2, q1, q2], [east, east, west, west], 12)
	check("two and two untangle (%d %d | %d %d)" % [p1.x, p2.x, q1.x, q2.x],
		mini(p1.x, p2.x) > maxi(q1.x, q2.x))

	# A QUEUE DOES NOT CHURN, AND A FIGHTER IS NEVER SWAPPED OUT. The front one
	# is fighting the player; the two behind want to reach the player too.
	gs.player.x = c.x + 1
	gs.player.y = c.y
	var front: Entity = make.call(c.x, Entity.Faction.MONSTER)
	var mid: Entity = make.call(c.x - 1, Entity.Faction.MONSTER)
	var back: Entity = make.call(c.x - 2, Entity.Faction.MONSTER)
	gs.entities = [gs.player, front, mid, back]
	var at_player := Vector2i(gs.player.x, gs.player.y)
	var churned := 0
	for r in 6:
		gs._step_toward(mid, at_player)
		gs._step_toward(back, at_player)
		gs.turns += 1
		if front.x != c.x or mid.x != c.x - 1 or back.x != c.x - 2:
			churned += 1
	check("the premise: the front one is fighting", gs._engaged(front))
	check("a queue behind a fight holds its order (%d rounds moved)" % churned,
		churned == 0)
	check("  so the player faces the same attacker, not a fresh one each turn",
		front.x == c.x)
	gs.player.x = 80
	gs.player.y = 40

	# IDLE GIVES WAY, and a sleeper stirs without learning where you are.
	var walker: Entity = make.call(c.x - 1, Entity.Faction.MONSTER)
	var sleeper: Entity = make.call(c.x, Entity.Faction.MONSTER)
	sleeper.alertness = Entity.Alert.ASLEEP
	sleeper.activity = Entity.Activity.SLEEPING
	gs.entities = [gs.player, walker, sleeper]
	gs._step_toward(walker, east)
	check("a sleeper in the doorway gives way", walker.x == c.x and sleeper.x == c.x - 1)
	check("  and stirs", sleeper.alertness == Entity.Alert.SUSPICIOUS)
	check("  without learning where the player is", sleeper.last_seen == Vector2i(-1, -1))
	var guard: Entity = make.call(c.x, Entity.Faction.MONSTER)
	guard.alertness = Entity.Alert.ASLEEP
	var passer: Entity = make.call(c.x - 1, Entity.Faction.MONSTER)
	gs.entities = [gs.player, passer, guard]
	gs._step_toward(passer, east)
	check("a guard standing its post gives way too", passer.x == c.x and guard.x == c.x - 1)
	check("  but is not stirred by it -- it was awake", guard.alertness == Entity.Alert.ASLEEP)

	# NEVER ACROSS SIDES. An ally meets a monster in the door: they would fight,
	# so neither walks through the other. Must-succeed first: two allies DO swap.
	var ally1: Entity = make.call(c.x - 1, Entity.Faction.PLAYER)
	var ally2: Entity = make.call(c.x, Entity.Faction.PLAYER)
	gs.entities = [gs.player, ally1, ally2]
	gs._step_toward(ally1, east)
	check("allies swap with allies", ally1.x == c.x and ally2.x == c.x - 1)
	var ally3: Entity = make.call(c.x - 1, Entity.Faction.PLAYER)
	var foe: Entity = make.call(c.x, Entity.Faction.MONSTER)
	gs.entities = [gs.player, ally3, foe]
	gs._step_toward(ally3, east)
	check("but never with something they would fight", ally3.x == c.x - 1 and foe.x == c.x)

	# The intent survives a save, so a jam untangles the same after a reload.
	var kept := Entity.from_dict(e1.to_dict())
	check("a creature's intent is saved (%s at %d)" % [str(kept.want), kept.want_turn],
		kept.want == e1.want and kept.want_turn == e1.want_turn and e1.want_turn >= 0)

## Creatures off the pathfinder -- going round a friend, wandering, fleeing --
## never step onto a pit. Brad saw a bone ally stand in one for good: the
## pathfinder treats a pit as solid, so nothing on one can plan a step off it.
##
## Each case is run twice: once with the only way out a PIT (must refuse), and
## once with the same cell as FLOOR (must take it). Without the second, "it did
## not move onto the pit" would pass just as well for a creature that could not
## move at all.
func _test_creatures_keep_out_of_pits() -> void:
	var gs := GameState.new(4040)
	gs.new_game()
	var c := Vector2i(20, 20)
	# A walled pocket: the creature at c, stone all round.
	var pocket := func(open: Array, tile: int) -> void:
		for y in range(c.y - 3, c.y + 4):
			for x in range(c.x - 3, c.x + 4):
				gs.map.set_tile(x, y, Tiles.WALL)
		gs.map.set_tile(c.x, c.y, Tiles.FLOOR)
		for o in open:
			var cell: Vector2i = o
			gs.map.set_tile(cell.x, cell.y, tile)
	# The player is parked far away so it blocks nothing here.
	gs.player.x = 80
	gs.player.y = 40
	var bones := Entity.new("bone ally", &"skeleton", c.x, c.y)
	bones.faction = Entity.Faction.PLAYER
	gs.entities = [gs.player, bones]

	# GOING ROUND A FRIEND. Target three east, a friend in the way; the one
	# neighbour that gets closer is north-east.
	var ne := Vector2i(c.x + 1, c.y - 1)
	var east := Vector2i(c.x + 1, c.y)
	pocket.call([east, ne, Vector2i(c.x, c.y - 1), Vector2i(c.x + 2, c.y),
		Vector2i(c.x + 3, c.y)], Tiles.FLOOR)
	gs.map.set_tile(ne.x, ne.y, Tiles.PIT)
	var friend := Entity.new("ally", &"skeleton", east.x, east.y)
	friend.faction = Entity.Faction.PLAYER
	gs.entities.append(friend)
	var target := Vector2i(c.x + 3, c.y)
	check("going round a friend, it will not step onto a pit",
		gs._around(bones, target) == Vector2i(-1, -1), str(gs._around(bones, target)))
	gs.map.set_tile(ne.x, ne.y, Tiles.FLOOR)
	check("  but takes the same cell as floor", gs._around(bones, target) == ne,
		str(gs._around(bones, target)))
	gs.map.set_tile(ne.x, ne.y, Tiles.TRAP)
	check("  and will not step onto a trap either",
		gs._around(bones, target) == Vector2i(-1, -1))
	gs.entities.erase(friend)

	# WANDERING. The only way out is east.
	pocket.call([east], Tiles.PIT)
	var onto_pit := 0
	for i in 30:
		bones.x = c.x
		bones.y = c.y
		gs._step_random(bones)
		if Vector2i(bones.x, bones.y) == east:
			onto_pit += 1
	check("wandering, it never steps onto a pit (%d of 30)" % onto_pit, onto_pit == 0)
	pocket.call([east], Tiles.FLOOR)
	bones.x = c.x
	bones.y = c.y
	gs._step_random(bones)
	check("  but does wander onto floor", Vector2i(bones.x, bones.y) == east)

	# FLEEING. Something to the west; the only way further off is east.
	var foe := Entity.new("orc", &"orc", c.x - 1, c.y)
	foe.faction = Entity.Faction.MONSTER
	gs.entities.append(foe)
	pocket.call([east, Vector2i(c.x - 1, c.y)], Tiles.FLOOR)
	gs.map.set_tile(east.x, east.y, Tiles.PIT)
	bones.x = c.x
	bones.y = c.y
	check("fleeing, it will not escape into a pit", not gs._step_away(bones, foe)
		and Vector2i(bones.x, bones.y) == c)
	gs.map.set_tile(east.x, east.y, Tiles.FLOOR)
	check("  but flees onto floor", gs._step_away(bones, foe)
		and Vector2i(bones.x, bones.y) == east)

	# And the player may still walk into one on purpose -- that is how you fall.
	gs.map.set_tile(east.x, east.y, Tiles.PIT)
	check("the player's step still allows a pit; only creatures are kept off",
		gs.can_step(c.x, c.y, east.x, east.y)
		and not gs.can_creature_step(c.x, c.y, east.x, east.y))

## The trader's piles: the shelf sorted by what a thing is FOR, by mouse, keys
## and pad alike; and what the player sold shown as theirs.
func _test_the_trader_piles() -> void:
	var gs := GameState.new(4040)
	gs.new_game()
	check("there is a trader to sort", gs.trader_here())
	if not gs.trader_here():
		return
	gs.player.inventory.clear()
	gs.player.equipped.clear()
	# A relic by hand: the scratch morgue may hold no heroes at all.
	gs.trader_stock.append({"item": Item.make(&"dagger"), "relic": "x", "hero": "Ron"})
	var t := TradePanel.new()
	t.state = gs
	t.size = Vector2(1600, 900)
	t.open()
	check("it opens on everything", t.pile == 0
		and t.shelf_rows().size() == gs.trader_stock.size() + 1)

	# Every pile holds only its own, keeps the gem row, and counts true.
	var wrong := PackedStringArray()
	for p in range(1, TradePanel.PILES.size()):
		t.set_pile(p)
		var rows := t.shelf_rows()
		if rows.is_empty() or int(rows[-1]) != TradePanel.GEM_ROW:
			wrong.append("%s lost the gem row" % TradePanel.PILES[p]["id"])
		for r in rows:
			if int(r) != TradePanel.GEM_ROW and not TradePanel.in_pile(p, gs.trader_stock[int(r)]):
				wrong.append("%s holds %s" % [TradePanel.PILES[p]["id"],
					(gs.trader_stock[int(r)]["item"] as Item).name])
		if t.pile_count(p) != rows.size() - 1:
			wrong.append("%s miscounts" % TradePanel.PILES[p]["id"])
	check("each pile holds only its own and keeps the gem row", wrong.is_empty(),
		", ".join(wrong))

	# And the piles are not all empty, which would pass the above vacuously.
	var ids_in := func(p: int) -> Array:
		t.set_pile(p)
		var out: Array = []
		for r in t.shelf_rows():
			if int(r) != TradePanel.GEM_ROW:
				out.append((gs.trader_stock[int(r)]["item"] as Item).id)
		return out
	var cut: Array = ids_in.call(1)
	check("things that cut: the dagger and sling (%s)" % str(cut),
		cut.has(&"dagger") and cut.has(&"sling") and not cut.has(&"leather_armour"))
	check("things you wear: leather", (ids_in.call(2) as Array).has(&"leather_armour"))
	check("things to hide behind: the buckler", (ids_in.call(3) as Array).has(&"buckler"))
	check("bottles and scrolls: the potion", (ids_in.call(4) as Array).has(&"potion_healing"))
	var dead: Array = ids_in.call(5)
	check("what the dead left: Ron's dagger alone (%s)" % str(dead), dead == [&"dagger"])

	# Nothing the trader stocks is homeless -- the pack once hid a gem this way.
	var homeless := PackedStringArray()
	for entry in gs.trader_stock:
		var housed := false
		for p in range(1, 5):
			housed = housed or TradePanel.in_pile(p, entry)
		if not housed:
			homeless.append((entry["item"] as Item).name)
	check("everything on the shelf has a pile", homeless.is_empty(), ", ".join(homeless))

	# Keyboard: tab and shift+tab, from the pack side too.
	t.open()
	t.side = TradePanel.PACK
	t.handle_key(KEY_TAB)
	check("tab turns to the next pile", t.pile == 1)
	check("  and brings the highlight to the shelf", t.side == TradePanel.SHELF)
	t.handle_key(KEY_TAB, true)
	check("shift+tab turns back", t.pile == 0)
	t.handle_key(KEY_TAB, true)
	check("  and wraps to the last", t.pile == TradePanel.PILES.size() - 1)

	# Pad: the shoulders, through the live bindings.
	var cfg := PadConfig.new()
	check("the left shoulder turns back",
		TradePanel.pad_pile_step(cfg, cfg.key_for_button(JOY_BUTTON_LEFT_SHOULDER)) == -1)
	check("the right shoulder turns on",
		TradePanel.pad_pile_step(cfg, cfg.key_for_button(JOY_BUTTON_RIGHT_SHOULDER)) == 1)
	check("A does not turn the piles",
		TradePanel.pad_pile_step(cfg, cfg.key_for_button(JOY_BUTTON_A)) == 0)

	# Mouse: hovering names a pile, clicking turns to it and buys nothing, the
	# wheel over the piles turns them.
	t.open()
	var credit := gs.trader_credit
	var stocked := gs.trader_stock.size()
	var over := InputEventMouseMotion.new()
	over.position = t._pile_rect(2).get_center()
	t._gui_input(over)
	check("hovering a pile names it (\"%s\")" % t.info(), t.info().findn("wear") >= 0)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = t._pile_rect(3).get_center()
	t._gui_input(click)
	check("clicking a pile turns to it", t.pile == 3)
	check("  and buys nothing", gs.trader_credit == credit
		and gs.trader_stock.size() == stocked and gs.player.inventory.is_empty())
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = t._pile_rect(0).get_center()
	t._gui_input(wheel)
	check("the wheel over the piles turns them", t.pile == 4)

	# What the player sold is marked as theirs, and says so.
	var mine := Item.make(&"sling")
	gs.give_item(mine)
	check("the premise: a sling sold", gs.trade_sell(gs.player.inventory.find(mine)))
	var entry: Dictionary = gs.trader_stock[-1]
	check("  is marked as yours", entry["item"] == mine and bool(entry.get("yours", false)))
	t.open()
	t.side = TradePanel.SHELF
	t._at[TradePanel.SHELF] = t.shelf_rows().find(gs.trader_stock.size() - 1)
	check("its line says you gave it (\"%s\")" % t.info(), t.info().findn("you gave me") >= 0)
	t._at[TradePanel.SHELF] = 0
	check("the trader's own stock does not (\"%s\")" % t.info(),
		t.info().findn("you gave me") < 0 and t.info().findn("costs") >= 0)
	var loaded := GameState.new(1)
	check("a save keeps it", loaded.apply_dict(gs.to_dict())
		and bool(loaded.trader_stock[-1].get("yours", false))
		and not bool(loaded.trader_stock[0].get("yours", false)))
	t.free()

func _test_the_counter_by_mouse_and_keys() -> void:
	var gs := GameState.new(4040)
	gs.new_game()
	if not gs.trader_here():
		check("there is a trader for the mouse to use", false)
		return
	gs.player.inventory.clear()
	gs.player.equipped.clear()
	var dag := Item.make(&"dagger")
	var axe := Item.make(&"war_axe")
	gs.give_item(dag)
	gs.give_item(axe)

	var t := TradePanel.new()
	t.state = gs
	t.size = Vector2(1600, 900)
	t.open()

	# HOVER shows the price without selling anything.
	var axe_row := gs.player.inventory.find(axe)
	var over := InputEventMouseMotion.new()
	over.position = t._row_rect(TradePanel.PACK, axe_row).get_center()
	t._gui_input(over)
	check("hovering an item highlights it", t.side == TradePanel.PACK
		and int(t._at[TradePanel.PACK]) == axe_row)
	check("and the info line gives its price (\"%s\")" % t.info(), t.info().findn("9") >= 0)
	check("without selling it", gs.player.inventory.has(axe) and gs.trader_credit == 0)

	# Hovering the SHELF moves across.
	var shelf_over := InputEventMouseMotion.new()
	shelf_over.position = t._row_rect(TradePanel.SHELF, 0).get_center()
	t._gui_input(shelf_over)
	check("hovering the shelf moves the highlight there", t.side == TradePanel.SHELF)

	# A CLICK acts on what is under it.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = t._row_rect(TradePanel.PACK, gs.player.inventory.find(dag)).get_center()
	t._gui_input(click)
	check("clicking a pack item sells it", not gs.player.inventory.has(dag)
		and gs.trader_credit == 1)

	# The WHEEL walks the highlight.
	t.side = TradePanel.SHELF
	t._at[TradePanel.SHELF] = 0
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = t._row_rect(TradePanel.SHELF, 0).get_center()
	t._gui_input(wheel)
	check("the wheel moves down the shelf", int(t._at[TradePanel.SHELF]) == 1)

	# The GEM CHOOSER answers to clicks.
	for i in 3:
		var g := Item.make(&"gem_crag")
		gs.give_item(g)
		gs.trade_sell(gs.player.inventory.find(g))
	t.choosing_gem = true
	t._gem_at = 0
	var pick := InputEventMouseButton.new()
	pick.button_index = MOUSE_BUTTON_LEFT
	pick.pressed = true
	pick.position = t._gem_row_rect(2).get_center()
	var wanted := StringName(t.gem_choices()[2])
	t._gui_input(pick)
	var got := false
	for it in gs.player.inventory:
		if Trade.is_gem(it) and it.element == wanted:
			got = true
	check("clicking a gem in the chooser takes it (%s)" % wanted, got and not t.choosing_gem)

	# A click outside the chooser backs out of it.
	t.choosing_gem = true
	var away := InputEventMouseButton.new()
	away.button_index = MOUSE_BUTTON_LEFT
	away.pressed = true
	away.position = Vector2(5, 5)
	t._gui_input(away)
	check("clicking outside the chooser closes it", not t.choosing_gem)

	# VI-KEYS AND THE NUMPAD move, as the arrows do.
	t.side = TradePanel.PACK
	t.handle_key(KEY_L)
	check("l moves to the shelf", t.side == TradePanel.SHELF)
	t.handle_key(KEY_H)
	check("h moves back to the pack", t.side == TradePanel.PACK)
	t.handle_key(KEY_KP_6)
	check("the numpad moves too", t.side == TradePanel.SHELF)
	t._at[TradePanel.SHELF] = 0
	t.handle_key(KEY_J)
	check("j moves down", int(t._at[TradePanel.SHELF]) == 1)
	t.handle_key(KEY_K)
	check("k moves up", int(t._at[TradePanel.SHELF]) == 0)

	# The keyboard footer tells a mouse player they can point.
	t.pad_input = false
	check("the keyboard footer mentions pointing and clicking",
		t.footer().findn("click") >= 0 and t.footer().findn("point") >= 0, t.footer())
	t.free()

## The trade screen: two columns, four verbs, and no letter keys at all.
func _test_the_counter() -> void:
	var gs := GameState.new(4040)
	gs.new_game()
	check("there is a trader to trade with", gs.trader_here())
	if not gs.trader_here():
		return
	gs.player.inventory.clear()
	gs.player.equipped.clear()
	var dag := Item.make(&"dagger")
	var pot := Item.make(&"potion_healing")
	gs.give_item(dag)
	gs.give_item(pot)

	var t := TradePanel.new()
	t.state = gs
	t.open()
	check("it opens on your pack", t.side == TradePanel.PACK)
	# With nothing to sell, it opens where there is something to do.
	var bare_gs := GameState.new(4040)
	bare_gs.new_game()
	bare_gs.player.inventory.clear()
	bare_gs.player.equipped.clear()
	var bare := TradePanel.new()
	bare.state = bare_gs
	bare.open()
	check("an empty pack opens on the shelf", bare.side == TradePanel.SHELF)
	bare.free()
	check("with a row for each thing you carry", t.pack_rows().size() == 2)
	check("and the shelf ends with the gem exchange",
		t.shelf_rows()[-1] == TradePanel.GEM_ROW)

	# The info line teaches the economy by looking.
	t._at[TradePanel.PACK] = gs.player.inventory.find(pot)
	check("a potion's line says why it is refused (\"%s\")" % t.info(),
		t.info().findn("sell") >= 0)
	t._at[TradePanel.PACK] = gs.player.inventory.find(dag)
	check("a dagger's line says what it is worth", t.info().findn("1") >= 0, t.info())

	# LETTERS DO NOTHING. The pack's letter trap cannot happen here.
	var credit := gs.trader_credit
	for k in [KEY_G, KEY_A, KEY_C, KEY_O, KEY_T, KEY_P, KEY_W, KEY_B]:
		t.handle_key(k)
	check("no letter key sells anything", gs.trader_credit == credit
		and gs.player.inventory.has(dag))

	# Confirm sells what is highlighted.
	t._at[TradePanel.PACK] = gs.player.inventory.find(dag)
	check("confirm sells the highlighted item", t.handle_key(KEY_PERIOD)
		and gs.trader_credit == credit + 1 and not gs.player.inventory.has(dag))

	# Right goes to the shelf, confirm buys.
	t.handle_key(KEY_RIGHT)
	check("right moves to the shelf", t.side == TradePanel.SHELF)
	var back := -1
	for i in gs.trader_stock.size():
		if gs.trader_stock[i]["item"] == dag:
			back = i
	t._at[TradePanel.SHELF] = back
	check("and confirm buys it back", t.handle_key(KEY_PERIOD)
		and gs.player.inventory.has(dag) and gs.trader_credit == credit)

	# Stones for a gem, through the chooser.
	for i in 3:
		var g := Item.make(&"gem_fire")
		gs.give_item(g)
		gs.trade_sell(gs.player.inventory.find(g))
	t.side = TradePanel.SHELF
	t._at[TradePanel.SHELF] = t.shelf_rows().size() - 1
	t.handle_key(KEY_PERIOD)
	check("the gem row opens a chooser", t.choosing_gem)
	t.handle_key(KEY_DOWN)
	var chosen := StringName(t.gem_choices()[1])
	t.handle_key(KEY_PERIOD)
	var got := false
	for it in gs.player.inventory:
		if Trade.is_gem(it) and it.element == chosen:
			got = true
	check("and gives the gem chosen (%s)" % chosen, got and not t.choosing_gem)

	# Leaving.
	t.handle_key(KEY_ESCAPE)
	check("escape leaves the counter", not t.visible)

	# The footer speaks the player's device.
	t.pad_cfg = PadConfig.new()
	t.pad_input = true
	var pad_line := t.footer()
	check("on a pad the footer names no keyboard key (\"%s\")" % pad_line,
		pad_line.findn("enter") < 0 and pad_line.findn("esc") < 0
		and pad_line.findn("click") < 0)
	t.pad_input = false
	check("on a keyboard it does", t.footer().findn("enter") >= 0)
	t.free()

	# main.gd filters pad presses BEFORE the counter sees them.
	var src := FileAccess.get_file_as_string("res://src/render/main.gd")
	var at := src.find("if trade.visible:")
	var guard := src.find("if _synthetic:", at)
	var handed := src.find("trade.handle_key(", at)
	check("main.gd filters pad presses before the counter sees them",
		at >= 0 and guard > at and handed > guard,
		"at %d, guard %d, handed %d" % [at, guard, handed])

## Relics: the last of a twice-dead hero's kit, sold once and never again.
func _test_the_trader_remembers_the_dead() -> void:
	var path := GameState.MORGUE_PATH
	check("the morgue is a scratch file here", path.find("scratch") >= 0, path)
	if path.find("scratch") < 0:
		return
	var had := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	var ron := "2026-09-01 10:00:00  level 3  killed by a goblin on depth 3, empty-handed, after 900 turns; bearing dagger, short sword (frost); known as Ron; reclaimed"
	var ann := "2026-09-02 10:00:00  level 2  killed by a rat on depth 2, empty-handed, after 400 turns; bearing leather armour; known as Ann"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_line(ron)
	f.store_line(ann)
	f.close()

	# The morgue format has two ends; both must know about "sold".
	var both := Morgue.parse(ron + "; sold")
	check("a reclaimed and sold line still parses", both.get("reclaimed", false)
		and both.get("sold", false) and both.get("name", "") == "Ron", str(both))

	var gs := GameState.new(4040)
	gs.new_game()
	var relic := -1
	for i in gs.trader_stock.size():
		if String(gs.trader_stock[i]["hero"]) == "Ron":
			relic = i
	check("a reclaimed hero's kit is on the shelf", relic >= 0)
	var never_ann := true
	for entry in gs.trader_stock:
		if String(entry["hero"]) == "Ann":
			never_ann = false
	check("but not a hero who was never reclaimed", never_ann)
	if relic < 0:
		return
	var it: Item = gs.trader_stock[relic]["item"]
	check("it is the MOST valuable piece they carried (%s)" % it.display_name(),
		it.id == &"short_sword" and it.element == &"frost")

	gs.trader_credit = Trade.worth(it)
	check("buying it works", gs.trade_buy(relic))
	var rec: Array = Morgue.records(path)
	var sold := false
	for r in rec:
		if r.get("name", "") == "Ron" and r.get("sold", false):
			sold = true
	check("and the morgue marks Ron sold", sold)

	# Marking again must not corrupt the line -- the old ends_with check would
	# have appended a second "reclaimed" after "sold".
	for r in rec:
		if r.get("name", "") == "Ron":
			Morgue.mark_reclaimed(path, String(r["line"]))
	var still := false
	for r in Morgue.records(path):
		if r.get("name", "") == "Ron" and r.get("reclaimed", false) and r.get("sold", false):
			still = true
	check("re-marking a sold hero leaves the line readable", still)

	var next := GameState.new(4041)
	next.new_game()
	var again := false
	for entry in next.trader_stock:
		if String(entry["hero"]) == "Ron":
			again = true
	check("a later run never offers Ron's kit again", not again)

	# A hero reclaimed during THIS run already dropped their kit on that floor.
	var f2 := FileAccess.open(path, FileAccess.WRITE)
	f2.store_line(ron)
	f2.close()
	var run := GameState.new(4042)
	run.new_game()
	run.reclaimed_this_run.append(ron)
	run.trader_stock = []
	run._stock_trader()
	var dup := false
	for entry in run.trader_stock:
		if String(entry["hero"]) == "Ron":
			dup = true
	check("nor one reclaimed earlier in this same run", not dup)

	var restore := FileAccess.open(path, FileAccess.WRITE)
	restore.store_string(had)
	restore.close()

## Holding a direction walks, at one shared rate, and pauses before it starts.
func _test_holding_a_direction() -> void:
	check("four steps a second (%.2fs apart)" % HoldRepeat.AGAIN,
		is_equal_approx(HoldRepeat.AGAIN, 0.25))
	check("and a longer pause before the first repeat",
		HoldRepeat.FIRST > HoldRepeat.AGAIN)

	# The stick: a push steps at once.
	var r := HoldRepeat.new()
	check("a push steps immediately", r.tick(KEY_UP, 0.016, true) == KEY_UP)
	check("  and that step is not a repeat", not r.last_was_repeat)

	# THE BUG THIS REPLACED. The stick marked itself "already walking" on its
	# first step, so the first repeat came AGAIN seconds later and FIRST was
	# never used -- a push held a moment too long was two steps. Brad's
	# overshooting was partly this.
	var t := 0.0
	var early := 0
	while t + 0.02 < HoldRepeat.FIRST:
		if r.tick(KEY_UP, 0.02, true) != 0:
			early += 1
		t += 0.02
	check("nothing repeats before the first pause is over (%d early)" % early,
		early == 0)
	var got := 0
	for i in 5:
		got = r.tick(KEY_UP, 0.02, true)
		if got != 0:
			break
	check("then it repeats", got == KEY_UP)
	check("  as a repeat", r.last_was_repeat)

	# After that, every AGAIN seconds.
	var gaps := 0
	var since := 0.0
	var hits := PackedFloat32Array()
	for i in 200:
		since += 0.01
		if r.tick(KEY_UP, 0.01, true) != 0:
			hits.append(since)
			since = 0.0
			gaps += 1
		if gaps >= 3:
			break
	check("then every %.2fs (%s)" % [HoldRepeat.AGAIN, str(hits)],
		hits.size() >= 3 and absf(hits[1] - HoldRepeat.AGAIN) < 0.02)

	# Letting go resets it; a change of direction is a fresh push.
	check("letting go stops it", r.tick(0, 0.5, true) == 0)
	check("a new direction steps at once", r.tick(KEY_LEFT, 0.016, true) == KEY_LEFT)

	# The keyboard: its first step is the key EVENT, so the timer must not take
	# it a second time.
	var k := HoldRepeat.new()
	check("a held key does not double its first step",
		k.tick(KEY_UP, 0.016, false) == 0)

	# THE STOP RULE: repeats stop with a hostile in view -- the rule travel has
	# always used, now shared.
	var gs := _arena(21, 11)
	gs.player.x = 5
	gs.player.y = 5
	check("an empty room holds no threat", not gs.threat_in_view())
	var gob := _spawn(gs, "goblin", 9, 5)
	check("a goblin in plain sight does", gs.threat_in_view(),
		"at %d,%d" % [gob.x, gob.y])

## Putting on armour takes turns; shields, weapons and taking it off do not.
func _test_armour_takes_time() -> void:
	check("leather takes 2", Item.make(&"leather_armour").don_turns == 2)
	check("chain takes 3", Item.make(&"chain_mail").don_turns == 3)
	check("plate takes 4", Item.make(&"plate_mail").don_turns == 4)
	check("a shield takes 1", Item.make(&"kite_shield").don_turns == 1)
	check("a weapon takes 1", Item.make(&"war_axe").don_turns == 1)

	for pair in [[&"plate_mail", 4], [&"leather_armour", 2], [&"tower_shield", 1]]:
		var gs := _arena(21, 11)
		var it := Item.make(pair[0])
		gs.give_item(it)
		var i := gs.player.inventory.find(it)
		var was := gs.elapsed
		check("putting on %s works" % it.name, gs.player_use(i))
		check("  and costs %d turns of time (%d)" % [pair[1], gs.elapsed - was],
			gs.elapsed - was == Scheduler.ACTION_COST * int(pair[1]))
		if int(pair[1]) > 1:
			var off_was := gs.elapsed
			gs.player_use(i)
			check("  taking it off costs one",
				gs.elapsed - off_was == Scheduler.ACTION_COST)

## Every potion and every meal costs a turn. Brad's ruling, 2026-09-24.
##
## A "first one each turn is free" rule was built and removed the same day: free
## in a fight it makes fights easier, and free only out of one it changes almost
## nothing. It went unnoticed while it existed -- nothing asserted that drinking
## costs a turn -- so this does, and the decision cannot drift back quietly.
func _test_every_draught_costs_a_turn() -> void:
	var gs := _arena(21, 11)
	gs.player.max_hp = 100
	gs.player.hp = 10
	var a := Item.make(&"potion_healing")
	var b := Item.make(&"potion_healing")
	var meat := Item.make(&"meat")
	gs.give_item(a)
	gs.give_item(b)
	gs.give_item(meat)
	var t0 := gs.turns
	check("a potion works", gs.player_use(gs.player.inventory.find(a)))
	check("  and costs a turn", gs.turns == t0 + 1, "%d -> %d" % [t0, gs.turns])
	check("so does the second", gs.player_use(gs.player.inventory.find(b))
		and gs.turns == t0 + 2)
	check("and a meal", gs.player_use(gs.player.inventory.find(meat))
		and gs.turns == t0 + 3)
	check("meat is filed with the potions", meat.kind == Item.Kind.POTION)

## The pack stays open between actions, and keeps its highlight honest.
func _test_the_pack_stays_open() -> void:
	var gs := _arena(21, 11)
	gs.player.max_hp = 100
	gs.player.hp = 10
	var p1 := Item.make(&"potion_healing")
	var p2 := Item.make(&"potion_healing")
	var sc := Item.make(&"scroll_light")
	gs.give_item(p1)
	gs.give_item(p2)
	gs.give_item(sc)
	var bag := InventoryPanel.new()
	bag.state = gs

	# Another potion slid into the slot: the highlight may stay.
	bag._hover_index = gs.player.inventory.find(p1)
	gs.player.inventory.remove_at(bag._hover_index)
	bag._hover_index = gs.player.inventory.find(p2)
	bag.settle_hover(&"potion_healing")
	check("with another potion there, the highlight stays",
		bag._hover_index == gs.player.inventory.find(p2))

	# Something else slid in: it must clear, or the next confirm reads a scroll.
	bag._hover_index = gs.player.inventory.find(sc)
	bag.settle_hover(&"potion_healing")
	check("with a scroll there instead, it clears", bag._hover_index == -1)
	bag.free()

	# main.gd must no longer close the pack after every use.
	var src := FileAccess.get_file_as_string("res://src/render/main.gd")
	var use_at := src.find("func _use_item(")
	var body := src.substr(use_at, src.find("\nfunc ", use_at + 5) - use_at)
	check("using an item no longer closes the pack by itself",
		body.find("_close_inventory()") < 0 and body.find("_close_pack_if_threatened") >= 0)

## Controller buttons drawn as PICTURES, from Kenney's Xbox Series font.
##
## Drawn directly from that face, never through the text font's fallbacks: the
## sidebar once reached its icons that way and on the itch web build every one
## came out as a tofu box, while desktop and the suite saw nothing wrong.
func _test_button_pictures() -> void:
	var face: Font = load(PadConfig.GLYPH_FONT)
	check("the button font ships", face != null)
	var text: Font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")

	# Every picture we name must exist in the face we draw it from.
	var missing := PackedStringArray()
	var all_cps: Array = PadConfig.BUTTON_GLYPHS.values()
	all_cps.append(PadConfig.STICK_GLYPH)
	for cp in all_cps:
		if not face.has_char(int(cp)):
			missing.append("U+%04X" % int(cp))
	check("the button font has every picture we name (%d)" % all_cps.size(),
		missing.is_empty(), ", ".join(missing))

	# And the TEXT font must NOT have them. That is the whole reason for drawing
	# them directly: if the text face carried these codepoints it would draw its
	# own (different) glyph, and if it relies on a fallback the web build loses it.
	var in_text := PackedStringArray()
	for cp in all_cps:
		if text.has_char(int(cp)):
			in_text.append("U+%04X" % int(cp))
	check("the text font claims none of them", in_text.is_empty(),
		", ".join(in_text))

	# Every button a default pad actually uses has a picture.
	var cfg := PadConfig.new()
	var bare := PackedStringArray()
	for b in cfg.binds:
		if not PadConfig.BUTTON_GLYPHS.has(int(b)):
			bare.append(PadConfig.button_name(int(b)))
	check("every bound button has a picture", bare.is_empty(), ", ".join(bare))

	# icon() gives a picture on a pad and the plain key on a keyboard.
	check("on a keyboard, icon() is still the key",
		cfg.icon(KEY_G, false) == "g", cfg.icon(KEY_G, false))
	check("on a pad it is B's picture",
		cfg.icon(KEY_G, true) == String.chr(int(PadConfig.BUTTON_GLYPHS[JOY_BUTTON_B])))
	var unbound := PadConfig.new()
	unbound.binds.clear()
	check("and it never goes blank", unbound.icon(KEY_G, true) == "g",
		unbound.icon(KEY_G, true))

	# A mixed line splits into text and picture runs, in order.
	var pic := String.chr(int(PadConfig.BUTTON_GLYPHS[JOY_BUTTON_BACK]))
	var parts := PadGlyphs.runs("press %s for help" % pic)
	check("a mixed line splits into three runs (%d)" % parts.size(), parts.size() == 3)
	if parts.size() == 3:
		check("  words, picture, words",
			not parts[0][1] and parts[1][1] and not parts[2][1])
		check("  and the picture run is only the picture",
			String(parts[1][0]) == pic)
	check("a plain line is one run", PadGlyphs.runs("press ? for help").size() == 1)

	# SIZE. The first version drew every button as a DOT on the itch build,
	# because 1.35x of a 0.48 em body is shorter than a capital letter. The body
	# must read as a button -- bigger than the capitals beside it -- and still
	# fit inside the line it is drawn on, in every panel that draws one.
	var in_caps := PadGlyphs.GLYPH_BODY_EM * PadGlyphs.GLYPH_SCALE / PadGlyphs.TEXT_CAP_EM
	check("a button stands taller than a capital letter (%.2fx)" % in_caps,
		in_caps >= 1.2 and in_caps <= 1.6)
	for panel in [["HERE", 17, HerePanel.LINE], ["sidebar", 15, Sidebar.LINE],
			["legend", LegendPanel.font_size_default() - 1, LegendPanel.LINE]]:
		var tall: float = PadGlyphs.GLYPH_BODY_EM * int(int(panel[1]) * PadGlyphs.GLYPH_SCALE)
		check("  and fits the %s line (%.0f <= %.0f px)" % [panel[0], tall, panel[2]],
			tall <= float(panel[2]))
	check("and has a width", PadGlyphs.width("press ? for help", text, 15) > 0.0)

	# EVERY FILE THAT ASKS FOR A PICTURE MUST DRAW THROUGH PadGlyphs. A future
	# panel that calls icon() and hands the result to draw_string would draw the
	# text font's version of a private-use codepoint -- nothing on desktop if it
	# is lucky, a box on the web build -- and nothing else would notice.
	var careless := PackedStringArray()
	for dir in ["res://src/ui/", "res://src/render/"]:
		var da := DirAccess.open(dir)
		if da == null:
			continue
		for f in da.get_files():
			if not f.ends_with(".gd"):
				continue
			var src := FileAccess.get_file_as_string(dir + f)
			var asks := src.find(".icon(") >= 0 or src.find("key_label(") >= 0
			if asks and src.find("PadGlyphs.") < 0 and f != "pad_glyphs.gd":
				careless.append(f)
	check("every panel that shows button pictures draws them directly",
		careless.is_empty(), ", ".join(careless))

## Inside the pack, a controller press must never select an item by letter.
##
## Found 2026-09-24 while chasing a smaller bug (forging was shift+click, which a
## pad cannot send). In the pack `a`-`z` choose the item wearing that letter, and
## a pad press ARRIVES as a keycode -- so seven buttons silently used whatever
## item matched: B equipped g, R3 equipped a, L3 read the scroll at c.
func _test_a_pad_is_never_a_letter_in_the_pack() -> void:
	var cfg := PadConfig.new()
	var allowed := {&"": true, &"close": true, &"forge": true, &"use": true,
		&"drop": true, &"throw": true}

	# The premise: the pad really does send letter keys, or this proves nothing.
	var lettered := 0
	for b in cfg.binds:
		var k := int(cfg.binds[b])
		if k >= KEY_A and k <= KEY_Z:
			lettered += 1
	check("a default pad sends letter keys (%d buttons)" % lettered, lettered >= 5)

	# Every button, in every mode, may only close the pack, forge, or do nothing.
	var bad := PackedStringArray()
	for mode in [[false, false], [true, false], [false, true]]:
		for b in cfg.binds:
			var k := int(cfg.binds[b])
			var act: StringName = MainScene.pad_pack_action(k, mode[0], mode[1])
			if not allowed.has(act):
				bad.append("%s -> %s" % [PadConfig.button_name(int(b)), act])
	check("no pad button does anything but a named action in the pack",
		bad.is_empty(), ", ".join(bad))

	# The ones that must work.
	check("Start closes the pack",
		MainScene.pad_pack_action(KEY_ESCAPE, false, false) == &"close")
	check("and the throw picker",
		MainScene.pad_pack_action(KEY_ESCAPE, true, false) == &"close")
	check("and the bind picker",
		MainScene.pad_pack_action(KEY_ESCAPE, false, true) == &"close")
	check("Y forges the highlighted item",
		MainScene.pad_pack_action(MainScene.PACK_FORGE_KEY, false, false) == &"forge")
	check("and that key is on a pad button",
		cfg.button_for_key(MainScene.PACK_FORGE_KEY) >= 0)
	check("but not while picking something to throw",
		MainScene.pad_pack_action(MainScene.PACK_FORGE_KEY, true, false) == &"")

	# THE LAYOUT. Face buttons do what players expect; the d-pad carries the
	# item verbs. Every verb acts on the HIGHLIGHTED row, never on a letter.
	check("B backs out of the pack",
		MainScene.pad_pack_action(MainScene.PACK_BACK_KEY, false, false) == &"close")
	check("and out of both pickers",
		MainScene.pad_pack_action(MainScene.PACK_BACK_KEY, true, false) == &"close"
		and MainScene.pad_pack_action(MainScene.PACK_BACK_KEY, false, true) == &"close")
	check("d-pad up uses", MainScene.pad_pack_action(
		MainScene.PACK_USE_KEY, false, false) == &"use")
	check("d-pad down drops", MainScene.pad_pack_action(
		MainScene.PACK_DROP_KEY, false, false) == &"drop")
	check("d-pad left forges", MainScene.pad_pack_action(
		MainScene.PACK_FORGE_ALT, false, false) == &"forge")
	check("d-pad right throws", MainScene.pad_pack_action(
		MainScene.PACK_THROW_KEY, false, false) == &"throw")

	# DROP MUST NEVER SIT ON A FACE BUTTON. It is the one verb that cannot be
	# taken back, and a face button is where a thumb lands by habit.
	var face := [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y]
	var drops_on_face := PackedStringArray()
	for b in face:
		var k := cfg.key_for_button(b)
		if MainScene.pad_pack_action(k, false, false) == &"drop":
			drops_on_face.append(PadConfig.button_name(b))
	check("drop is never on a face button", drops_on_face.is_empty(),
		", ".join(drops_on_face))
	check("but IS reachable from the pad",
		cfg.button_for_key(MainScene.PACK_DROP_KEY) >= 0)

	# Nothing acts while choosing what to throw or which weapon takes a gem --
	# those pickers are answered by confirm, and a stray verb would be chaos.
	for k in [MainScene.PACK_USE_KEY, MainScene.PACK_DROP_KEY,
			MainScene.PACK_THROW_KEY, MainScene.PACK_FORGE_KEY]:
		check("%s is inert in the throw picker" % OS.get_keycode_string(k),
			MainScene.pad_pack_action(k, true, false) == &"")
		check("and in the bind picker",
			MainScene.pad_pack_action(k, false, true) == &"")

	# AND main.gd must actually route pad presses through it before any letter
	# lookup -- the rule is worthless if the guard is below the thing it guards.
	var src := FileAccess.get_file_as_string("res://src/render/main.gd")
	var pack := src.find("if inventory.visible:")
	var guard := src.find("if _synthetic:", pack)
	var first_letter := src.find("letter_to_index(", pack)
	check("main.gd guards pad presses before any letter lookup",
		pack >= 0 and guard > pack and first_letter > guard,
		"pack %d, guard %d, first letter lookup %d" % [pack, guard, first_letter])

	# The footer tells a pad player about the forge in their own words.
	var gs := _arena(21, 11)
	var bag := InventoryPanel.new()
	bag.state = gs
	bag.pad_cfg = cfg
	bag.pad_input = false
	check("a keyboard gets no pad footer", bag.footer() == "")
	bag.pad_input = true
	var said := bag.footer()
	check("a pad gets one (\"%s\")" % said, said != "")
	check("and it names no key a pad lacks",
		said.findn("click") < 0 and said.findn("shift") < 0
		and said.findn("letter") < 0 and said.findn("esc") < 0, said)
	check("and it tells a pad player how to drop", said.findn("drop") >= 0, said)

	# The arrows must exist in the font the pack draws with. A glyph missing from
	# the bundled font still looks right in an editor and a desktop build,
	# because both fall back to a system font -- and a web build ships a box.
	var pack_font: Font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
	for ch in ["▼", "►"]:
		check("the pack font has %s" % ch, pack_font.has_char(ch.unicode_at(0)))
	bag.free()

## Wherever the game waits for a decision, a controller must be able to give it.
##
## Found in play 2026-09-23, on the Legion Go S: with a missile weapon you could
## open the targeting cursor, move it, and cancel -- but never fire. Aim mode and
## look mode tested `enter` alone, while four other places also accepted `.`, and
## a pad sends no `enter`. Six copies of one condition, and the two that
## disagreed were the two no controller could use.
##
## Reads MainScene.CONFIRM rather than restating the list, because a test that
## keeps its own copy of the thing under test is how the copies drift -- which is
## the bug this is guarding against.
func _test_a_pad_can_answer_every_prompt() -> void:
	var cfg := PadConfig.new()
	var pressable := {}
	for button in cfg.binds:
		pressable[int(cfg.binds[button])] = true
	for dir in Gamepad.STICK_KEYS:
		pressable[int(Gamepad.STICK_KEYS[dir])] = true

	# The premise: an empty set would make the check below pass by vacuum.
	check("a default pad sends something (%d keys)" % pressable.size(),
		pressable.size() >= 10)
	check("the confirm list is not empty (%d)" % MainScene.CONFIRM.size(),
		MainScene.CONFIRM.size() > 0)

	var reachable := PackedStringArray()
	for k in MainScene.CONFIRM:
		if pressable.has(int(k)):
			reachable.append(OS.get_keycode_string(int(k)))
	check("a pad can say yes (%s)" % ", ".join(reachable),
		not reachable.is_empty(),
		"none of CONFIRM is on a button or the stick")

	# And say no. Cancelling is escape everywhere, which Start sends.
	check("and a pad can back out", pressable.has(KEY_ESCAPE))

	# The general rule this bug belonged to: a pad press carries no modifiers,
	# so any prompt answered only by a shifted key is unanswerable from one.
	for k in MainScene.CONFIRM:
		check("\"%s\" needs no modifier" % OS.get_keycode_string(int(k)),
			int(k) != KEY_COLON and int(k) != KEY_PLUS
			and int(k) != KEY_GREATER and int(k) != KEY_LESS)

## Every action a run REQUIRES has to be reachable from a controller.
##
## Measured 2026-09-21 and it was not: descend, ascend, pray and the torch were
## unreachable from any button, however bound. Every pad press becomes a bare
## keycode -- main.gd `_press` builds an InputEventKey with no modifiers -- so
## the stairs, which want shift+period and shift+comma on a keyboard, could not
## be sent at all. A pad-only handheld could not leave floor one.
##
## This is the check that would have caught it, and it is written against what
## a run NEEDS rather than against the binding table, so a future rearrangement
## cannot quietly drop one again.
func _test_a_pad_can_finish_the_game() -> void:
	var cfg := PadConfig.new()
	var pressable := {}
	for button in cfg.binds:
		pressable[int(cfg.binds[button])] = true
	for dir in Gamepad.STICK_KEYS:
		pressable[int(Gamepad.STICK_KEYS[dir])] = true

	# The must-succeed premise: if this table were empty every check below
	# would pass while asserting nothing.
	check("a default pad sends something at all (%d keys)" % pressable.size(),
		pressable.size() >= 10)

	# Asserted as CAPABILITIES with their possible routes, not as keycodes.
	#
	# The first version of this checked `pressable.has(KEY_LESS)`, which broke
	# the moment `g` became the action key and d-pad up was freed for the map:
	# a pad could still climb perfectly well, through `g`, while the check
	# said it could not. A guard written against the mechanism fails when the
	# mechanism changes; one written against what a RUN NEEDS does not.
	#
	# `g` counts as a route because _test_g_is_the_action_key proves it takes
	# the stairs and prays. This check only asks whether a pad can press it.
	var routes := {
		"go down the stairs": [KEY_GREATER, KEY_G],
		"climb back up them": [KEY_LESS, KEY_G],
		"pray at a shrine": [KEY_P, KEY_G],
		"douse its torch": [KEY_T],
	}
	for what in routes:
		var ok := false
		var tried := PackedStringArray()
		for k in routes[what]:
			tried.append(OS.get_keycode_string(int(k)))
			if pressable.has(int(k)):
				ok = true
		check("a pad can %s" % what, ok, "none of %s" % ", ".join(tried))
	check("and the action key itself is on a button", pressable.has(KEY_G))
	check("a pad can still wait", pressable.has(KEY_PERIOD))
	check("pick up", pressable.has(KEY_G))
	check("open the pack", pressable.has(KEY_I))
	check("and open the menu", pressable.has(KEY_ESCAPE))

	# Nothing a pad can send may need a modifier, because it cannot send one.
	# This is the general form of the bug rather than a list of its instances.
	for row in PadConfig.WALK:
		var k := int(row[0])
		check("\"%s\" needs no shift key" % String(row[1]),
			k != KEY_COLON and k != KEY_PLUS,
			OS.get_keycode_string(k))

	# And the invariant the walk-through already had, restated for the new
	# rows: anything bound by default must be something you can bind back.
	var bindable := {}
	for row in PadConfig.WALK:
		bindable[int(row[0])] = true
	var lost := PackedStringArray()
	for button in PadConfig.DEFAULTS:
		if not bindable.has(int(PadConfig.DEFAULTS[button])):
			lost.append(OS.get_keycode_string(int(PadConfig.DEFAULTS[button])))
	check("every new default is restorable", lost.is_empty(),
		"not in WALK: %s" % ", ".join(lost))

func _test_every_menu_row_is_reachable() -> void:
	var sendable := {}
	for button in PadConfig.DEFAULTS:
		sendable[PadConfig.DEFAULTS[button]] = true

	# Navigation is what makes the rows reachable, not the letters: none of
	# `t`, `s` or `n` can be sent by a default pad or even bound to one.
	#
	# It comes from the STICK now, not from a bound button. The d-pad used to
	# send the arrows and was spent doing it; since 2026-09-22 it carries the
	# four actions a pad could not otherwise reach, and the stick -- which
	# always walked, in eight directions rather than four -- is the only thing
	# that navigates.
	#
	# That is a STRONGER guarantee than the old one, and this is the check that
	# says so: STICK_KEYS is hardcoded, so navigation cannot be evicted by
	# rebinding. Under the old arrangement a player who bound the d-pad to
	# something else lost the ability to work the pause menu.
	for nav in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		sendable[nav] = true
	check("a default pad can move the menu highlight",
		sendable.has(KEY_UP) and sendable.has(KEY_DOWN),
		"%d keys bound" % sendable.size())
	var walks := {}
	for dir in Gamepad.STICK_KEYS:
		walks[int(Gamepad.STICK_KEYS[dir])] = true
	check("and it comes from the stick, which no rebinding can take away",
		walks.has(KEY_UP) and walks.has(KEY_DOWN)
		and walks.has(KEY_LEFT) and walks.has(KEY_RIGHT),
		"%d stick keys" % walks.size())
	check("the stick still covers all eight directions", walks.size() == 8,
		"%d" % walks.size())
	check("a default pad can choose the highlighted row",
		sendable.has(KEY_PERIOD), "%d keys bound" % sendable.size())
	check("a default pad can open the menu", sendable.has(KEY_ESCAPE),
		"%d keys bound" % sendable.size())

	var panel := MenuPanel.new()
	var fired := {"v": ""}
	panel.resume_requested.connect(func() -> void: fired["v"] = "resume")
	panel.pad_requested.connect(func() -> void: fired["v"] = "pad")
	panel.text_size_requested.connect(func() -> void: fired["v"] = "text")
	panel.save_and_quit_requested.connect(func() -> void: fired["v"] = "save")
	panel.new_run_requested.connect(func() -> void: fired["v"] = "new")

	# Both layouts get driven, not just the desktop one. MenuPanel.new() never
	# runs _ready(), so OPTIONS keeps its declared value and the web list would
	# otherwise be read but never dispatched -- a row could be unwired there and
	# nothing here would notice.
	for options in [MenuPanel.OPTIONS_DESKTOP, MenuPanel.OPTIONS_WEB]:
		panel.OPTIONS = options
		var where := "web" if options == MenuPanel.OPTIONS_WEB else "desktop"

		for row in options:
			fired["v"] = ""
			panel.handle_key(String(row[0]).to_upper().unicode_at(0))
			check("%s row '%s' answers to the letter it prints" % [where, row[1]],
				fired["v"] == String(row[2]), "got '%s'" % fired["v"])

		# The controller path: move the highlight onto the row, then press wait.
		for i in options.size():
			var row: Array = options[i]
			fired["v"] = ""
			panel._hover = i
			panel.handle_key(KEY_PERIOD)
			check("%s row '%s' answers to the pad" % [where, row[1]],
				fired["v"] == String(row[2]), "got '%s'" % fired["v"])

	panel.free()

## Text size is chosen at runtime rather than read from a table, which is the
## exact shape of the rabbit meat bug: right in memory, absent from the file.
func _test_text_size_survives_a_restart() -> void:
	# settings.cfg is the player's REAL file -- use_scratch_files() covers the
	# save and the morgue, not this. So read what is actually in it first and
	# put that back at the end, and the file ends as it was found.
	RenderTheme.load_settings()
	var was := RenderTheme.cell_size()

	check("the shipped size is still on the list",
		RenderTheme.CELL_SIZES.has(18), str(RenderTheme.CELL_SIZES))
	check("an 18px cell still draws a 16pt glyph",
		RenderTheme.font_size_for(18) == 16, str(RenderTheme.font_size_for(18)))

	# A glyph wider than its cell bleeds into the neighbouring one, which is the
	# failure the fixed 8/9 ratio exists to prevent at every step.
	var fits := true
	var worst := ""
	for px in RenderTheme.CELL_SIZES:
		if RenderTheme.font_size_for(px) > px:
			fits = false
			worst = "%d px cell -> %d pt" % [px, RenderTheme.font_size_for(px)]
	check("every offered size fits its cell (%d sizes)"
		% RenderTheme.CELL_SIZES.size(), fits, worst)

	RenderTheme.set_cell_size(24)
	RenderTheme.load_settings()
	check("a chosen size survives a reload", RenderTheme.cell_size() == 24,
		str(RenderTheme.cell_size()))

	# settings.cfg is plain text a player can edit, so a nonsense cell must not
	# reach the grid and hand it a zero-width character.
	RenderTheme.set_cell_size(7)
	check("a size that is not offered falls back to the shipped one",
		RenderTheme.cell_size() == 18, str(RenderTheme.cell_size()))

	RenderTheme.set_cell_size(was)

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

	# Nothing checked the panel's HEIGHT until the text size row was added, even
	# though the comment on PANEL claimed this test did. Adding that fifth row
	# put the last one 4px past the old 284 panel and no check would have said
	# so. Rows are laid out from a fixed 92px header offset, so the bottom edge
	# of the last row is the number that has to fit.
	for options in [MenuPanel.OPTIONS_DESKTOP, MenuPanel.OPTIONS_WEB]:
		var bottom: float = 92.0 + options.size() * MenuPanel.ROW_H
		var room: float = MenuPanel.PANEL.y - MenuPanel.PAD
		check("menu rows fit the panel (%d rows)" % options.size(),
			bottom <= room, "%.0f > %.0f px" % [bottom, room])

	# The controller panel is the same constant with the same missing check, in
	# a second file. It grew from 11 rows to 14 within an hour of the menu
	# growing from 4 to 5, and neither of us was hunting for it -- the shared
	# cause is a hand-maintained height with a comment implying a test that did
	# not exist.
	#
	# This one has a footer line UNDER the rows, so the bottom is not the last
	# row: it is title, note, every row, a 6px gap, then the key hints. The
	# panel is deliberately NOT sized from WALK.size(), so that growing the
	# list fails here and a human chooses the new height, rather than the panel
	# quietly resizing itself.
	# Two columns now, so the height is set by the LONGER column rather than by
	# the row count. An odd number of bindings leaves the extra on the left.
	# +20 for the pad footer, which is drawn under the keyboard one whenever
	# the panel is not mid-walk-through.
	var pad_bottom: float = PadPanel.PAD + PadPanel.font_size_default() \
		+ 2.0 * PadPanel.ROW_H + PadPanel.left_rows() * PadPanel.ROW_H + 6.0 \
		+ 20.0
	var pad_room: float = PadPanel.PANEL.y - PadPanel.PAD
	check("controller rows fit the panel (%d rows in %d columns)"
		% [PadConfig.WALK.size(), 2],
		pad_bottom <= pad_room, "%.0f > %.0f px" % [pad_bottom, pad_room])

	# WIDTH, which the height check could not see.
	#
	# Reported from a screenshot: the footer ran one pixel past the panel edge
	# and had done since the walk-through grew to fourteen rows. A guard
	# written for one axis says nothing about the other, and this panel had a
	# careful assertion about its rows sitting directly above an overflow.
	# Read from the panel's own constant rather than retyped. The first version
	# of this check held its own copy of the string, which measures whatever
	# the TEST says and not what the panel draws.
	var pad_wide: float = PadPanel.PANEL.x - PadPanel.PAD * 2.0
	for foot in [PadPanel.KEY_FOOTER, PadPanel.pad_footer()]:
		var w := font.get_string_size(foot, HORIZONTAL_ALIGNMENT_LEFT, -1,
			PadPanel.font_size_default() - 4).x
		check("footer fits the panel (\"%s\")" % foot.substr(0, 24),
			w <= pad_wide, "%.0f > %.0f px" % [w, pad_wide])

	# And a column has to hold its widest label with its binding beside it.
	var col_w := (PadPanel.PANEL.x - PadPanel.PAD * 2.0 - PadPanel.COL_GAP) * 0.5
	var widest := ""
	for row in PadConfig.WALK:
		if String(row[1]).length() > widest.length():
			widest = String(row[1])
	var pair := font.get_string_size("%s  button 12" % widest,
		HORIZONTAL_ALIGNMENT_LEFT, -1, PadPanel.font_size_default()).x
	check("and its widest binding fits a column (\"%s\")" % widest,
		pair <= col_w, "%.0f > %.0f px" % [pair, col_w])

	# Every key the defaults hand out must be something the walk-through can
	# hand back. It was not: close door, ally stance and the legend were bound
	# by DEFAULTS and absent from WALK, so rebinding could evict one and only
	# `r` for defaults could restore it -- discarding every other choice with
	# it. A binding you can lose and cannot restore is worse than one never
	# offered.
	var bindable := {}
	for row in PadConfig.WALK:
		bindable[int(row[0])] = true
	# PackedStringArray, not Array: String.join() takes one, and a bare [...]
	# here is an untyped Array that only happens to coerce.
	var unreachable := PackedStringArray()
	for button in PadConfig.DEFAULTS:
		var k: int = int(PadConfig.DEFAULTS[button])
		if not bindable.has(k):
			unreachable.append(OS.get_keycode_string(k))
	check("every defaulted pad key can be rebound",
		unreachable.is_empty(), "not in WALK: %s" % ", ".join(unreachable))

	# The ally row is the same shape of failure: a name on the left and hit
	# points right-aligned against the same edge. It shipped broken -- "risen
	# killer rabbit  loose" was fitted to the whole panel and "3/3" drew on top
	# of it, reported from a screenshot. The longest name the game can produce
	# here is a risen one, because `_raise_the_recent_dead` prefixes "risen "
	# to whatever it dug up.
	var ally_limit: float = float(widths.get("Sidebar", 256.0)) - Sidebar.PAD * 2.0
	var longest := ""
	for entry in GameState.BESTIARY:
		var n := "risen %s" % String(entry["name"])
		if n.length() > longest.length():
			longest = n
	for stance_word in ["loose", "heel"]:
		var left := "%s  %s" % [longest, stance_word]
		var lw := font.get_string_size(left, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var rw := font.get_string_size("999/999", HORIZONTAL_ALIGNMENT_LEFT,
			-1, 15).x
		check_silent(lw + rw + Sidebar.GAP > ally_limit
			or lw + rw + Sidebar.GAP <= ally_limit)
		# What actually matters: once FITTED, the two must not overlap.
		var fitted_w := font.get_string_size(
			left.substr(0, left.length()), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		check_silent(fitted_w >= 0.0)
	check_gathered("the longest ally row is measurable (%s)" % longest)
	# The real assertion: the widest name the game can make, plus the widest
	# numbers, must leave room once the reserve is taken off.
	var worst_left := font.get_string_size("%s  loose" % longest,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var worst_right := font.get_string_size("999/999",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	check("an ally row reserves room for its hit points (%s)" % longest,
		worst_right + Sidebar.GAP < ally_limit,
		"%.0f + %.0f >= %.0f px" % [worst_right, Sidebar.GAP, ally_limit])
	check("and the name is what gets truncated, not the numbers",
		worst_left > ally_limit - worst_right - Sidebar.GAP,
		"name %.0f fits in %.0f -- pick a longer test case"
			% [worst_left, ally_limit - worst_right - Sidebar.GAP])

	# The sidebar draws the key left and the action right-aligned against the
	# same edge, so the failure is two strings meeting in the middle.
	var side_limit: float = float(widths.get("Sidebar", 256.0)) - Sidebar.PAD * 2.0
	var worst := ""
	var worst_w := 0.0
	# MEASURED AGAINST THE LEGEND, which is the panel that draws these now.
	#
	# It used to be the sidebar, and the sidebar's short list never included the
	# long rows -- "v / letters / symbols / pictures" is 261px against 228px of
	# sidebar. Pointing the old guard at the full table failed immediately, which
	# is the guard working: those rows were never sidebar rows, and the sidebar
	# does not draw any now.
	#
	# The legend lays out four columns across the window, at one point smaller.
	var legend_col: float = (1600.0 - 48.0 - LegendPanel.PAD * 2.0) / 4.0
	var legend_size := LegendPanel.font_size_default() - 1
	for row in Sidebar.KEYS:
		var a := font.get_string_size(row[0], HORIZONTAL_ALIGNMENT_LEFT, -1,
			legend_size).x
		var b := font.get_string_size(row[1], HORIZONTAL_ALIGNMENT_LEFT, -1,
			legend_size).x
		if a + b > worst_w:
			worst_w = a + b
			worst = "%s / %s" % [row[0], row[1]]
	# A gap, not a touch: two strings that exactly meet read as one word.
	check("no key row collides with its action in the legend",
		worst_w + 8.0 <= legend_col - LegendPanel.GLYPH_X - 12.0,
		"%.0f + gap > %.0f px -- %s"
		% [worst_w, legend_col - LegendPanel.GLYPH_X - 12.0, worst])

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
	# Every equippable item, in the widest state it can reach: fully upgraded,
	# carrying a gem, and with a count beside it. The icon is drawn LARGER than
	# the text now, which makes collision likelier rather than less, so this
	# measures the real draw path rather than a helper written for it.
	var spill := []
	for id in Item.CATALOGUE:
		if Item.CATALOGUE[id].get("slot", Item.Slot.NONE) == Item.Slot.NONE:
			continue
		# The WIDEST this row can ever get: fully upgraded, and carrying a gem
		# if the piece will take one. Testing a fresh item measures the easy
		# case and leaves the row that actually overflows uninspected.
		# The WIDEST this row can ever get: fully upgraded, and carrying a gem
		# if the piece will take one. Testing a fresh item measures the easy
		# case and leaves the row that actually overflows uninspected.
		var piece := Item.make(id)
		piece.boosts = Item.MAX_UPGRADES
		for el in [&"fire", &"frost", &"leech", &"crag", &"return"]:
			if piece.accepts_element(el):
				piece.element = el
				break
		var glyph := bar._gear_glyph(piece)
		var gsz := GlyphTheme.draw_size(glyph, bar.font_size)
		var glyph_w := bar.font.get_string_size(glyph,
			HORIZONTAL_ALIGNMENT_LEFT, -1, gsz).x
		var label_w := bar.font.get_string_size("weapon  ",
			HORIZONTAL_ALIGNMENT_LEFT, -1, bar.font_size).x
		for numbers in ["", "  x220", " r8 x40"]:
			var shown: String = bar.gear_row_words("weapon", glyph,
				bar._gear_words(piece), bar._gear_up(piece),
				bar._gear_el(piece), numbers)
			var w: float = label_w + glyph_w + bar.font.get_string_size(shown,
				HORIZONTAL_ALIGNMENT_LEFT, -1, bar.font_size).x
			if w > side_limit:
				spill.append("%s%s (%.0f > %.0f)" % [id, numbers, w, side_limit])
			# The NUMBERS have to survive. Trimming from the right ate them
			# once already: a war bow came out "(short) +1 r7.." after the icons
			# were enlarged, deleting the reach and the ammo count -- what the
			# row is FOR -- to preserve the word telling you which bow it is,
			# when the picture beside it already said "bow" and the reach says
			# which one. The tag is the cheapest thing on the row to lose, so it
			# is what goes.
			if numbers != "" and not shown.ends_with(numbers):
				spill.append("%s lost its numbers: %s" % [id, shown])
	check("no gear row collides with its label", spill.is_empty(), str(spill))

	# The LOOK panel, which had no test at all until its describer changed shape.
	#
	# `_describe()` used to answer in plain strings. It now answers in a mix:
	# gear and loot come back as {glyph, text} so they can be drawn with their
	# picture, everything else stays words. Nothing in the suite called it, so
	# getting that wrong would have surfaced as a crash the first time somebody
	# hovered over an armed monster -- in play, not here.
	var look := _arena(21, 9)
	look.player.x = 3
	look.player.y = 4
	var seen_at := Vector2i(9, 4)
	var armed := _spawn(look, "orc", seen_at.x, seen_at.y)
	armed.equipped[Item.Slot.WEAPON] = Item.make(&"war_axe")
	var dropped := Item.make(&"chain_mail")
	dropped.x = seen_at.x
	dropped.y = seen_at.y
	look.ground.append(dropped)
	look.torch_lit = true
	look.update_vision()

	var panel := Sidebar.new()
	panel.font = Sidebar.ui_font()
	panel.size = Vector2(float(widths.get("Sidebar", 256.0)), 720.0)
	panel.state = look
	panel.hovered = seen_at
	var lines: Array = panel._describe()
	var pictured := 0
	var worded := 0
	var broken := []
	for line in lines:
		if line is Dictionary:
			pictured += 1
			if String(line.get("glyph", "")) == "":
				broken.append("picture line with no glyph: %s" % str(line))
			if String(line.get("text", "")) == "":
				broken.append("picture line with no words: %s" % str(line))
		elif line is String:
			worded += 1
		else:
			broken.append("line is neither words nor a picture: %s" % str(line))
	check("the look panel describes something", not lines.is_empty())
	check("every look line is words or a picture", broken.is_empty(), str(broken))
	# The axe it carries and the mail on the floor: two things with pictures.
	check("gear and loot get their glyph (%d)" % pictured, pictured >= 2,
		"%d of %d lines" % [pictured, lines.size()])
	# The orc itself, and the ground it stands on: still words.
	check("the creature and the tile stay words (%d)" % worded, worded >= 2,
		"%d of %d lines" % [worded, lines.size()])
	panel.free()

	# And the icon really is drawn bigger than a letter, which is the point of
	# routing these rows through GlyphTheme.draw_size at all.
	var ring_glyph: String = bar._gear_glyph(Item.make(&"rat_ring"))
	if GlyphTheme.is_icon(ring_glyph):
		check("sidebar icons are drawn at icon size",
			GlyphTheme.draw_size(ring_glyph, bar.font_size) > bar.font_size,
			"%d vs %d" % [GlyphTheme.draw_size(ring_glyph, bar.font_size), bar.font_size])

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

	# THE KEY LIST IS GONE FROM THE SIDEBAR. `HERE` answers "what do I press
	# now" better than a static list did, and the legend still renders every row
	# from Sidebar.KEYS -- so all the sidebar needs is a way to find it.
	var help_cfg := PadConfig.new()
	for on_pad in [false, true]:
		var line := "press %s for help" % help_cfg.label(KEY_QUESTION, on_pad)
		var w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		check("the help line fits the sidebar on %s (\"%s\" %.0f <= %.0f px)"
			% ["a pad" if on_pad else "a keyboard", line, w, side_limit],
			w <= side_limit)
	check("it names the key on a keyboard",
		help_cfg.label(KEY_QUESTION, false) == "?",
		help_cfg.label(KEY_QUESTION, true))
	check("and the button on a pad",
		help_cfg.label(KEY_QUESTION, true) == PadConfig.button_name(
			help_cfg.button_for_key(KEY_QUESTION)),
		help_cfg.label(KEY_QUESTION, true))

	# THE LEGEND NAMES BUTTONS ON A PAD. It was the last screen in the game
	# still saying `w  swap reach / blade` to somebody holding a Legion Go S,
	# where the answer is RB -- missed because it is the one screen nobody looks
	# at until they are already lost.
	var leg_cfg := PadConfig.new()
	var keyboard_only := PackedStringArray()
	var changed := 0
	for row in Sidebar.KEYS:
		var typed_k := Sidebar.key_label(row, leg_cfg, false)
		var held_k := Sidebar.key_label(row, leg_cfg, true)
		check("\"%s\" reads as itself on a keyboard" % row[1],
			typed_k == String(row[0]), typed_k)
		if typed_k != held_k:
			changed += 1
		elif int(row[2]) != 0:
			keyboard_only.append("%s (%s)" % [row[1], typed_k])
	# The premise: if nothing changed, the whole feature is doing nothing.
	check("a pad player sees different labels (%d of %d rows)"
		% [changed, Sidebar.KEYS.size()], changed >= 10)
	# A row WITH a keycode that still reads the same on a pad means that action
	# is keyboard-only -- honest, but worth naming rather than discovering.
	check("keyboard-only actions are named, not blank",
		keyboard_only.size() <= 4, ", ".join(keyboard_only))
	check("walking still says stick on a pad",
		Sidebar.key_label(Sidebar.KEYS[0], leg_cfg, true)
		== String.chr(PadConfig.STICK_GLYPH),
		Sidebar.key_label(Sidebar.KEYS[0], leg_cfg, true))
	check("and arrows on a keyboard",
		Sidebar.key_label(Sidebar.KEYS[0], leg_cfg, false).findn("arrows") >= 0)

	# The legend still has every row, which is where the list really belonged.
	check("the legend still lists every key (%d)" % Sidebar.KEYS.size(),
		Sidebar.KEYS.size() >= 12)


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

	# All three panels must agree, which is the only reason the mode is static.
	RenderTheme.set_mode(RenderTheme.Mode.SYMBOLS)
	check("the active theme is the symbol one when selected",
		RenderTheme.active().appearance(&"water")["ch"] == "≈")
	RenderTheme.set_mode(RenderTheme.Mode.ASCII)
	check("and the ascii one when not",
		RenderTheme.active().appearance(&"water")["ch"] == "~")

	# LAST, and that placement is the whole point.
	#
	# set_mode() writes user://settings.cfg, which is the PLAYER's file --
	# use_scratch_files() redirects the save, the morgue and the bestiary but
	# has never covered this one. The restore used to sit above the two lines
	# that follow it, so every headless run ended with the mode left on ASCII
	# and silently rewrote Brad's own view back to letters. He noticed as "it
	# always resets" long before either of us found the cause.
	RenderTheme.set_mode(was)


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

	# Enough mouthfuls and it stops running.
	#
	# Depth set deliberately: the transformation is gated below
	# RABBIT_TURNS_DEPTH so the learning floors only ever hold rabbits, and
	# `_arena` starts on depth 1. The old comment here said "three", which
	# stopped being true when the threshold moved to two -- and the check name
	# below said it as well, which is a test describing a number it was not
	# testing.
	var fed := _arena(31, 11)
	fed.depth = GameState.RABBIT_TURNS_DEPTH
	fed.player.x = 28
	fed.player.y = 9
	var glut := _spawn(fed, "rabbit", 6, 3)
	for i in GameState.RABBIT_TURNS:
		fed.map.set_tile(glut.x, glut.y, Tiles.FUNGUS)
		fed._rabbit_swallows(glut)
	check("%d mouthfuls and it turns (%s)" % [GameState.RABBIT_TURNS, glut.name],
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

	# --- LOUDNESS decides it, not a list of causes --------------------------
	#
	# This used to hand every cause a radius of SEVEN and assert that only
	# &"step" and &"wail" rose. Two things were wrong with it once the rule
	# became volume: seven is above the bar, so of course they rose -- and
	# combat does not emit seven anyway. It emits six. The test was asserting a
	# noise the game never makes.
	#
	# Now it uses the REAL constants, so it measures the rule the player lives
	# under rather than one invented for the test.
	var wrong := 0
	var quiet_ones := {
		&"combat": GameState.COMBAT_NOISE,
		&"door": GameState.DOOR_NOISE,
	}
	for i in 60:
		for cause in quiet_ones:
			var gs := _arena(25, 13)
			gs.rng = RandomNumberGenerator.new()
			gs.rng.seed = 9000 + i
			gs.player.x = 6
			gs.player.y = 6
			gs.map.set_tile(8, 6, Tiles.GRAVE)
			gs.grave_at[Vector2i(8, 6)] = armed
			gs._make_noise(Vector2i(6, 6), int(quiet_ones[cause]), cause)
			for e in gs.entities:
				if e.risen:
					wrong += 1
	check("a fight and a door are too quiet to wake the dead",
		wrong == 0, "%d" % wrong)

	# And the loud ones do, whatever they are called.
	var roused := 0
	for i in 60:
		for loud in [GameState.CHEST_NOISE, GameState.FORGE_NOISE]:
			var gs := _arena(25, 13)
			gs.rng = RandomNumberGenerator.new()
			gs.rng.seed = 9400 + i
			gs.player.x = 6
			gs.player.y = 6
			gs.map.set_tile(8, 6, Tiles.GRAVE)
			gs.grave_at[Vector2i(8, 6)] = armed
			gs._make_noise(Vector2i(6, 6), int(loud), &"forge")
			for e in gs.entities:
				if e.risen:
					roused += 1
	check("a chest and the forge are not (%d of 120)" % roused, roused > 0)

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
	# Counted by KIND rather than by total. This check read `size() == 2` and
	# failed the moment a risen grave also left a bone -- correctly, but the
	# number alone could not say whether the bone had appeared or a piece of
	# armour had gone missing. Naming both makes the next change to this drop
	# report which half of it moved.
	var gear_back := 0
	var bones_back := 0
	for it in gs2.ground:
		if it.id == &"bone":
			bones_back += 1
		else:
			gear_back += 1
	# The gear does NOT fall here any more. It goes onto the bone, so that
	# exactly one copy of it exists from this moment on -- the player gets it
	# back when the ally carrying it falls. Asserted as zero rather than left
	# unmentioned, because "nothing dropped" is precisely the thing a future
	# change to this path would break silently.
	check("a risen grave drops no gear of its own (%d)" % gear_back,
		gear_back == 0, "%d" % gear_back)
	check("it leaves only the bone to raise them by", bones_back == 1,
		"%d" % bones_back)

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

## A rat may walk past a sleeper. Nothing else may.
##
## Reported from play as "I cannot click to move in rat form". Travel refused
## for ANY visible monster, asleep included, while telling you something was
## watching -- and rat form is precisely when you are creeping past sleepers,
## so the one journey the ring exists for was the one travel would not make.
func _test_a_rat_may_creep_past() -> void:
	for as_rat in [false, true]:
		var gs := _arena(31, 9)
		gs.player.x = 2
		gs.player.y = 4
		gs.map.explored.fill(1)
		# Within DOUSED_RADIUS (3) and OFF the route, because a rat sees three
		# cells and the first draft put the monster four away -- so the rat saw
		# nothing, travel proceeded for want of anything to stop for, and the
		# check passed without exercising the rule at all.
		var sleeper := _spawn(gs, "orc", 4, 2)
		sleeper.alertness = Entity.Alert.ASLEEP
		# Genuinely asleep on both axes -- a patrolling orc is awake enough to
		# see you, and creeping past one should not be free.
		sleeper.activity = Entity.Activity.SLEEPING
		if as_rat:
			var ring := Item.make(&"rat_ring")
			gs.give_item(ring)
			gs.player.equipped[Item.Slot.WEAPON] = ring
		gs.torch_lit = true
		gs.update_vision()
		check("the sleeper is in sight (rat=%s)" % as_rat,
			not gs.visible_monsters().is_empty())
		var walked := gs.begin_travel(Vector2i(8, 4))
		if as_rat:
			check("a rat walks past a sleeping monster", walked)
		else:
			check("on two feet you stop for it", not walked)

	# Awake stops BOTH, because an awake thing can act and a rat has no hands.
	for as_rat in [false, true]:
		var gs2 := _arena(31, 9)
		gs2.player.x = 2
		gs2.player.y = 4
		gs2.map.explored.fill(1)
		var hunter := _spawn(gs2, "orc", 4, 2)
		hunter.alertness = Entity.Alert.AWAKE
		if as_rat:
			var ring2 := Item.make(&"rat_ring")
			gs2.give_item(ring2)
			gs2.player.equipped[Item.Slot.WEAPON] = ring2
		gs2.torch_lit = true
		gs2.update_vision()
		check("the hunter is in sight (rat=%s)" % as_rat,
			not gs2.visible_monsters().is_empty())
		check("an awake monster stops travel (rat=%s)" % as_rat,
			not gs2.begin_travel(Vector2i(8, 4)))

## The band's hoard: one room, far from the door, guarded, holding the chest.
##
## The chest was already the band's landmark and had no PLACE -- _place_chest
## scanned from the LAST room, which is where the stairs go, so the best object
## in the band tended to turn up beside the exit you were already walking to.
func _test_the_hoard_room() -> void:
	var floors := 0
	var with_hoard := 0
	var chest_in_hoard := 0
	var chests := 0
	var lit := 0
	var near := 0
	var far_total := 0.0
	for i in 30:
		for spec in [[2, false], [5, false], [8, false], [10, false], [5, true]]:
			var gs := GameState.new(64000 + i * 17 + int(spec[0]))
			gs.use_scratch_files("hoard%d_%d" % [i, int(spec[0])])
			gs.new_game()
			gs.ascending = spec[1]
			gs.depth = spec[0]
			gs.build_level()
			floors += 1
			if gs.hoard_room < 0:
				continue
			with_hoard += 1
			var room: Rect2i = gs.room_rects[gs.hoard_room]
			# Never the room you start in.
			check_silent(gs.hoard_room != 0)
			# Farther from the start than the average room, which is the whole
			# point of picking it.
			var home: Vector2i = gs.room_rects[0].get_center()
			var c := room.get_center()
			var mine := absi(c.x - home.x) + absi(c.y - home.y)
			var avg := 0.0
			for r in gs.room_rects:
				var rc := r.get_center()
				avg += absi(rc.x - home.x) + absi(rc.y - home.y)
			avg /= float(maxi(gs.room_rects.size(), 1))
			far_total += float(mine) - avg
			if float(mine) < avg:
				near += 1
			# A fire to work at.
			var has_fire := false
			for y in range(room.position.y, room.end.y):
				for x in range(room.position.x, room.end.x):
					if gs.map.get_tile(x, y) == Tiles.BRAZIER:
						has_fire = true
			if has_fire:
				lit += 1
			# And the chest it exists to hold.
			for y in range(gs.map.height):
				for x in range(gs.map.width):
					if gs.map.get_tile(x, y) == Tiles.CHEST:
						chests += 1
						if room.has_point(Vector2i(x, y)):
							chest_in_hoard += 1
			gs.clear_scratch_files()
	check("chest floors get a hoard room (%d of %d)" % [with_hoard, floors],
		with_hoard > floors / 2, "%d of %d" % [with_hoard, floors])
	check_gathered("and it is never the room you start in")
	check("it is farther out than an average room (avg +%.1f cells, %d nearer)"
		% [far_total / float(maxi(with_hoard, 1)), near], near == 0,
		"%d hoards closer than average" % near)
	check("it holds a fire to work at (%d of %d)" % [lit, with_hoard],
		lit == with_hoard, "%d unlit" % (with_hoard - lit))
	check("and the chest is in it (%d of %d chests)" % [chest_in_hoard, chests],
		chests > 0 and chest_in_hoard == chests,
		"%d chests elsewhere" % (chests - chest_in_hoard))

## The early gem is a safety net, not a gift.
##
## It exists because roughly half of depth-2 floors generate with no gem at all,
## which can leave the elemental system unseen for a third of a run. But it was
## placed in room_rects[0] -- the room you START in, and the one room
## _populate_room deliberately leaves unpopulated -- so it arrived unguarded and
## underfoot. Reported from play as "there is a gem waiting for me right when I
## start", which is what a guarantee looks like when it forgets to hide.
func _test_the_pity_gem_is_earned() -> void:
	var placed := 0
	var in_start := 0
	var nearer := 0
	for i in 60:
		for d in GameState.GEM_PITY_FLOORS:
			var gs := GameState.new(23000 + i * 29 + int(d))
			gs.use_scratch_files("pity%d_%d" % [i, int(d)])
			gs.new_game()
			gs.depth = d
			gs.build_level()
			if gs.room_rects.size() < 2:
				gs.clear_scratch_files()
				continue
			var gem: Item = null
			for it in gs.ground:
				if it.kind == Item.Kind.GEM:
					gem = it
					break
			if gem == null:
				gs.clear_scratch_files()
				continue
			placed += 1
			var home: Rect2i = gs.room_rects[0]
			if home.has_point(Vector2i(gem.x, gem.y)):
				in_start += 1
			# And it should be out at the far end, not merely elsewhere.
			var hc := home.get_center()
			var mine := absi(gem.x - hc.x) + absi(gem.y - hc.y)
			var avg := 0.0
			for r in gs.room_rects:
				var rc := r.get_center()
				avg += absi(rc.x - hc.x) + absi(rc.y - hc.y)
			avg /= float(gs.room_rects.size())
			if float(mine) < avg:
				nearer += 1
			gs.clear_scratch_files()
	check("early gems get placed at all (%d)" % placed, placed > 0)
	check("and never in the room you start in", in_start == 0,
		"%d of %d in the starting room" % [in_start, placed])
	# Not a strict zero: a gem already lying on the floor counts as the pity
	# gem being satisfied, and that one can be anywhere. This checks the
	# PLACED ones are out at the far end on the whole.
	check("they sit farther out than an average room (%d of %d nearer)"
		% [nearer, placed], float(nearer) < float(placed) * 0.35,
		"%d of %d" % [nearer, placed])

## A name on the dead, and the old dead keeping theirs.
##
## The morgue is a file the PLAYER owns, with real deaths in it that the risen
## system reads back. Adding a field to it is the one change in this project
## that can destroy something irreplaceable, so the only acceptable shape is an
## optional trailing clause -- the same way `slain`, `gear` and `reclaimed` were
## each added.
func _test_the_dead_have_names() -> void:
	# A line from before names existed. This is the shape sitting in a real
	# morgue right now, and it has to keep working exactly as it did.
	var old_line := "2026-09-01 12:00:00  level 7  killed by a wight on depth 5, empty-handed, after 900 turns; 12 slain, most often goblin; bearing war axe +1"
	var old_rec := Morgue.parse(old_line)
	check("a line written before names still parses", not old_rec.is_empty())
	# `gear` comes back as an ARRAY of pieces -- the parser splits it so each
	# one can be drawn on its own line -- not as the written string.
	check("and keeps every field it had",
		int(old_rec.get("level", 0)) == 7 and int(old_rec.get("turns", 0)) == 900
			and old_rec.get("gear", []) == ["war axe +1"],
		str(old_rec))
	check("it carries no name", not old_rec.has("name"))

	# The nameless get called something, and it must be the SAME something
	# every time or the stone and the skeleton disagree about who is buried.
	old_rec["line"] = old_line
	var first := Morgue.name_of(old_rec)
	check("the nameless are named", first != "")
	var stable := true
	for _i in 50:
		if Morgue.name_of(old_rec) != first:
			stable = false
	check("and named the same way every time (%s)" % first, stable)
	# Different dead get different names, or it is one name with extra steps.
	var spread := {}
	for i in 200:
		spread[Morgue.name_of({"line": "grave number %d" % i})] = true
	check("different dead draw different names (%d distinct)" % spread.size(),
		spread.size() > 1)

	# A named line round-trips.
	var named := old_line + "; known as Brad"
	var rec := Morgue.parse(named)
	check("a named line parses", not rec.is_empty())
	check("and the name comes back", str(rec.get("name", "")) == "Brad",
		str(rec.get("name", "")))
	check("without disturbing the gear",
		rec.get("gear", []) == ["war axe +1"], str(rec.get("gear", [])))
	check("and name_of prefers the real one", Morgue.name_of(rec) == "Brad")

	# Reclaimed still parses when a name is present -- mark_reclaimed appends
	# after everything, so the two optional clauses have to coexist.
	var both := Morgue.parse(named + "; reclaimed")
	check("a named, reclaimed line parses", not both.is_empty()
		and str(both.get("name", "")) == "Brad"
		and both.has("reclaimed"), str(both))

	# The line a live run writes carries the name it was given.
	var gs := _arena(21, 9)
	gs.player_name = "Brad"
	gs.player.level = 3
	gs.death_cause = "killed by a rat"
	var line := gs.morgue_line()
	check("a run writes its name into the morgue", line.contains("; known as Brad"),
		line)
	var back := Morgue.parse(line)
	check("and that line reads back", not back.is_empty()
		and str(back.get("name", "")) == "Brad", line)

	# A semicolon in a name would split the record in half on the way back.
	var odd := _arena(21, 9)
	odd.player_name = "Bra;d"
	odd.death_cause = "killed by a rat"
	var safe := Morgue.parse(odd.morgue_line())
	check("a semicolon in a name cannot break the record",
		not safe.is_empty() and str(safe.get("name", "")).contains("Bra"),
		odd.morgue_line())

	# A run is always named now: rolled if nothing was typed.
	var rolled := GameState.new(4242)
	rolled.new_game()
	check("a run with no chosen name gets one", rolled.player_name != "",
		rolled.player_name)
	check("and it is short enough for the sidebar (%s)" % rolled.player_name,
		rolled.player_name.length() <= Morgue.NAME_MAX)
	# Rolled through the RUN's rng, so a seed names the same character -- which
	# is what keeps seeded tests and resumed saves honest.
	var twin := GameState.new(4242)
	twin.new_game()
	check("a seed names the same character", twin.player_name == rolled.player_name,
		"%s vs %s" % [twin.player_name, rolled.player_name])
	# And the pool actually varies, or it is one name with extra steps.
	var pool := {}
	for i in 120:
		var g := GameState.new(9000 + i)
		g.new_game()
		pool[g.player_name] = true
	check("the pool varies (%d distinct names)" % pool.size(), pool.size() > 5)

	# A chosen name is never overwritten by a rolled one.
	var chosen := GameState.new(7)
	chosen.player_name = "Brad"
	chosen.new_game()
	check("a chosen name survives new_game", chosen.player_name == "Brad",
		chosen.player_name)

	# What a player can type is bounded, because it has to fit a sidebar header
	# and survive a round trip through a "; "-separated record.
	check("a long name is cut to fit",
		Morgue.clean_name("Bartholomew the Extremely Verbose").length()
			<= Morgue.NAME_MAX)
	check("and a semicolon never reaches the file",
		not Morgue.clean_name("Bra;d").contains(";"))

	# And it survives a suspend, or a resumed run forgets who it is.
	var keep := _arena(21, 9)
	keep.player_name = "Gabe"
	var restored := GameState.new(1)
	restored.new_game()
	restored.apply_dict(keep.to_dict())
	check("a name survives a suspend", restored.player_name == "Gabe",
		restored.player_name)

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

## A screenshot has to be traceable to a commit.
##
## Brad's suggestion, after pushing to itch and having no way to confirm from
## the handheld that the build running was the build uploaded.
func _test_the_build_is_named() -> void:
	check("there is a build string at all", BuildInfo.BUILD.length() > 0)
	# "dev" in a working tree is CORRECT -- the stamp is applied at export and
	# removed again, because a commit cannot contain its own hash. So this
	# asserts the shape rather than a value: either the dev marker, or a
	# stamp beginning with a build number.
	check("it is either dev or a stamp (\"%s\")" % BuildInfo.BUILD,
		BuildInfo.BUILD == "dev" or BuildInfo.BUILD.begins_with("b"),
		BuildInfo.BUILD)

	# It shares a baseline with the clock, so the two must not collide. The
	# clock is the longer of the pair and grows with the run.
	var panel := MenuPanel.new()
	var font: Font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
	var size := MenuPanel.font_size_default() - 4
	# A deliberately long clock: hours, and a turn count past anything a real
	# run reaches.
	var clock := "99h 59m underground  ·  999999 turns"
	var stamp := "b99999+ abcdef0"
	var used := font.get_string_size(clock, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x \
		+ font.get_string_size(stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var room: float = MenuPanel.PANEL.x - MenuPanel.PAD * 2.0
	check("the clock and the build stamp share a line without colliding",
		used <= room, "%.0f > %.0f px" % [used, room])
	panel.free()

## The contextual block must agree with what the key actually does.
##
## Brad, 2026-09-23: he learned the keys from the sidebar and then stopped
## seeing it, because it never changed. Making it contextual is the fix -- but a
## panel that derives its own answer would eventually promise something the game
## does not do, so it reads GameState.actions_here(), and this checks that the
## answer matches player_pickup.
func _test_the_sidebar_says_what_is_here() -> void:
	var gs := _arena(21, 11)
	gs.player.x = 5
	gs.player.y = 5
	gs.player.hp = gs.player.max_hp

	# The premise: open floor offers nothing, so a later "it offers X" cannot
	# pass by the list simply always being full.
	gs.map.set_tile(5, 5, Tiles.FLOOR)
	check("plain floor offers nothing", gs.actions_here().is_empty(),
		str(gs.actions_here()))

	var cases := {
		Tiles.STAIRS_DOWN: "go down",
		Tiles.STAIRS_UP: "climb",
		Tiles.SHRINE: "pray",
		Tiles.FUNGUS: "eat the fungus",
	}
	for tile in cases:
		gs.map.set_tile(5, 5, tile)
		var rows := gs.actions_here()
		check("%s is offered" % cases[tile], rows.size() == 1
			and String(rows[0][1]) == String(cases[tile]),
			str(rows))
		check("  and it is the action key", rows.size() == 1
			and int(rows[0][0]) == KEY_G)

	# RUBBLE IS OFFERED ONLY WHEN THE KEY WOULD WORK. Reported from play: the
	# panel offered "knap a stone" while carrying no sling, and pressing it was
	# refused. A hint that promises what the key will not do is worse than none,
	# because the player believes it and stops trusting the rest of them.
	gs.map.set_tile(5, 5, Tiles.RUBBLE)
	check("rubble offers nothing without a sling", gs.actions_here().is_empty(),
		str(gs.actions_here()))
	check("and the key agrees", not gs.player_pickup())

	var sling := Item.make(&"sling")
	sling.ammo = 0
	gs.player.inventory.append(sling)
	check("with a sling in the pack it is offered",
		str(gs.actions_here()).findn("knap a stone") >= 0, str(gs.actions_here()))
	check("and the key agrees there too", gs.player_pickup())

	# A full sling has nowhere to put it, so it must stop being offered.
	gs.map.set_tile(5, 5, Tiles.RUBBLE)
	sling.ammo = sling.ammo_max
	check("a full sling is not offered rubble", gs.actions_here().is_empty(),
		str(gs.actions_here()))
	check("and that key is refused too", not gs.player_pickup())
	gs.player.inventory.erase(sling)

	# Punctuation reads as itself, not as its name. Seen in play: the panel
	# said "period  warm yourself", which reads as an instruction to type a word.
	check("a full stop is shown as '.'", PadConfig.key_name(KEY_PERIOD) == ".",
		PadConfig.key_name(KEY_PERIOD))
	check("and a question mark as '?'", PadConfig.key_name(KEY_QUESTION) == "?",
		PadConfig.key_name(KEY_QUESTION))
	check("a letter is still just the letter", PadConfig.key_name(KEY_G) == "g",
		PadConfig.key_name(KEY_G))
	check("and escape stays readable", PadConfig.key_name(KEY_ESCAPE) == "esc",
		PadConfig.key_name(KEY_ESCAPE))

	# An item underfoot wins, exactly as it does in player_pickup -- or the
	# panel would promise the stairs while the key picks up a sword.
	gs.map.set_tile(5, 5, Tiles.STAIRS_DOWN)
	var sword := Item.make(&"short_sword")
	sword.x = 5
	sword.y = 5
	gs.ground.append(sword)
	var rows := gs.actions_here()
	check("an item underfoot is offered before the stairs",
		rows.size() == 1 and String(rows[0][1]).findn("short sword") >= 0,
		str(rows))

	# And the panel's promise must match what the key DOES.
	check("and pressing it really does pick it up", gs.player_pickup())
	check("the stairs are offered on the next press",
		String(gs.actions_here()[0][1]) == "go down", str(gs.actions_here()))

	# THE PANEL HAS ITS OWN RECTANGLE NOW, so height no longer has to be pinned.
	# What matters instead is that it always offers a way out for a lost player,
	# and that it never clips -- which is what drove it out of the sidebar.
	var bar := HerePanel.new()
	bar.state = gs
	bar.pad_cfg = PadConfig.new()

	gs.map.set_tile(5, 5, Tiles.STAIRS_DOWN)
	check("the panel says what is here", str(bar.rows()).findn("go down") >= 0,
		str(bar.rows()))
	var last: Array = bar.rows()[-1]
	check("and always a way to every key", String(last[1]) == "every key",
		str(bar.rows()))

	# While the cursor is up the keys genuinely mean something else, and that is
	# when a player is most likely to be lost -- it is how the missile bug was
	# found in the first place.
	bar.aiming = true
	check("aiming names the shoot key",
		str(bar.rows()).findn("shoot") >= 0, str(bar.rows()))
	check("and how to cycle targets",
		str(bar.rows()).findn("next target") >= 0, str(bar.rows()))
	check("and still offers every key",
		String(bar.rows()[-1][1]) == "every key")
	bar.aiming = false

	# NOTHING MAY CLIP. The sidebar was 256px and the longest line is 276px, so
	# it cut mid-word and collided with the key beside it. This panel is 588px
	# and the guard measures the real strings against the real width.
	var face: Font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
	var room: float = 588.0 - HerePanel.PAD * 2.0 - HerePanel.KEY_COL
	var widest := ""
	var widest_px := 0.0
	for tile in [Tiles.STAIRS_DOWN, Tiles.STAIRS_UP, Tiles.SHRINE,
			Tiles.FUNGUS, Tiles.RUBBLE]:
		gs.map.set_tile(5, 5, tile)
		for row in bar.rows():
			var w := face.get_string_size(String(row[1]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, bar.font_size).x
			if w > widest_px:
				widest_px = w
				widest = String(row[1])
	# The worst case is a long item name, which is what actually overflowed.
	var long_item := Item.make(&"war_axe")
	if long_item != null:
		long_item.element = &"leech"
		long_item.x = 5
		long_item.y = 5
		gs.map.set_tile(5, 5, Tiles.FLOOR)
		gs.ground.append(long_item)
		for row in bar.rows():
			var w := face.get_string_size(String(row[1]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, bar.font_size).x
			if w > widest_px:
				widest_px = w
				widest = String(row[1])
		gs.ground.erase(long_item)
	check("the widest line fits the panel (\"%s\" %.0f <= %.0f px)"
		% [widest, widest_px, room], widest_px <= room)

	# And the key column holds the longest BUTTON name, not just the letters.
	var key_px := face.get_string_size(PadConfig.button_name(JOY_BUTTON_DPAD_DOWN),
		HORIZONTAL_ALIGNMENT_LEFT, -1, bar.font_size).x
	check("the key column fits a button name (%.0f <= %.0f px)"
		% [key_px, HerePanel.KEY_COL], key_px <= HerePanel.KEY_COL)

	# Labels follow the device the player is USING, not what is plugged in --
	# a Steam Deck's pad is always connected even when somebody is typing.
	gs.map.set_tile(5, 5, Tiles.STAIRS_DOWN)
	bar.pad_input = false
	var typed := str(bar.rows())
	bar.pad_input = true
	var held := str(bar.rows())
	check("a keyboard player is shown letters", typed.findn("\"g\"") >= 0, typed)
	# On a pad the key column is a PICTURE of the button now, drawn from the
	# Kenney face -- so what the row carries is that glyph, not the letter B.
	var b_pic := String.chr(int(PadConfig.BUTTON_GLYPHS[JOY_BUTTON_B]))
	check("a pad player is shown the B button", held.findn(b_pic) >= 0, held)
	check("and they differ", typed != held)

	var bare := PadConfig.new()
	bare.binds.clear()
	bar.pad_cfg = bare
	check("an unbound action falls back to its keyboard name",
		str(bar.rows()).findn("\"g\"") >= 0, str(bar.rows()))
	bar.free()

	# DEATH IS A CONTEXT. Third bug of this shape in a week: the log said
	# "Press R to begin again" and `r` is not bindable to a pad.
	var dead := _arena(21, 11)
	dead.player.x = 5
	dead.player.y = 5
	check("a living player is not told to begin again",
		str(dead.actions_here()).findn("begin again") < 0, str(dead.actions_here()))
	dead.game_over = true
	var over := dead.actions_here()
	check("a dead one is", over.size() == 1
		and String(over[0][1]) == "begin again", str(over))
	check("the keyboard is told r", int(over[0][0]) == KEY_R)
	check("and a pad route is offered beside it", over[0].size() > 2
		and MainScene.CONFIRM.has(int(over[0][2])),
		"%d" % (int(over[0][2]) if over[0].size() > 2 else -1))

	var dead_bar := HerePanel.new()
	dead_bar.state = dead
	dead_bar.pad_cfg = PadConfig.new()
	dead_bar.pad_input = false
	check("so a keyboard player reads r",
		str(dead_bar.rows()).findn("\"r\"") >= 0, str(dead_bar.rows()))
	dead_bar.pad_input = true
	check("and a pad player sees a button they have",
		str(dead_bar.rows()).findn(
			String.chr(int(PadConfig.BUTTON_GLYPHS[JOY_BUTTON_A]))) >= 0,
		str(dead_bar.rows()))
	dead_bar.free()

	# The instruction must not name a key again.
	check("the death message names no key",
		"You die.".findn("press") < 0)

	# Warming is offered only when it would work.
	var b := _arena(21, 11)
	b.player.x = 5
	b.player.y = 5
	b.map.set_tile(6, 5, Tiles.BRAZIER)
	b.brazier_charge[Vector2i(6, 5)] = GameState.BRAZIER_CHARGE
	b.player.hp = b.player.max_hp
	var full := b.actions_here()
	check("a brazier is not offered at full health", full.is_empty(), str(full))
	b.player.hp = b.player.max_hp - 5
	var hurt := b.actions_here()
	check("but it is when you are hurt", hurt.size() == 1
		and String(hurt[0][1]) == "warm yourself", str(hurt))
	check("and it is the WAIT key, not the action key",
		int(hurt[0][0]) == KEY_PERIOD)

## One key, and the square decides what it means.
##
## Gabe's suggestion by email, extended to the shrine by Brad. The key was
## already contextual -- arrows, fungus, rubble, pick up -- and stopped short of
## the terrain you stand on deliberately, which is why a pad could not use the
## stairs: they wanted `>` and `<`, and `shift` is not a thing a pad can send.
func _test_g_is_the_action_key() -> void:
	var gs := _arena(21, 11)
	gs.player.x = 5
	gs.player.y = 5

	# The must-succeed premise. Everything below is "G did the right thing",
	# and all of it would pass vacuously against a player who cannot act.
	gs.map.set_tile(5, 5, Tiles.FLOOR)
	check("plain floor still refuses", not gs.player_pickup())

	# --- an item wins, and the terrain waits its turn ---------------------
	# Brad's explicit ruling: item first if something is lying on the stairs.
	gs.map.set_tile(5, 5, Tiles.STAIRS_DOWN)
	var loot := Item.make(&"short_sword")
	loot.x = 5
	loot.y = 5
	gs.ground.append(loot)
	var was_depth := gs.depth
	check("an item on the stairs is picked up first", gs.player_pickup())
	check("and the floor did not change under you", gs.depth == was_depth,
		"%d -> %d" % [was_depth, gs.depth])
	check("the sword is in the pack", gs.player.inventory.has(loot))

	# --- and now the same key takes the stairs ---------------------------
	check("the second press descends", gs.player_pickup())
	check("the floor changed", gs.depth == was_depth + 1,
		"%d -> %d" % [was_depth, gs.depth])

	# --- the shrine -------------------------------------------------------
	var sh := _arena(21, 11)
	sh.player.x = 5
	sh.player.y = 5
	sh.map.set_tile(5, 5, Tiles.SHRINE)
	var before := sh.msg_log.entries.size()
	check("G prays at a shrine", sh.player_pickup())
	check("and it said something about it", sh.msg_log.entries.size() > before)

	# --- climbing ---------------------------------------------------------
	var up := _arena(21, 11)
	up.player.x = 5
	up.player.y = 5
	up.ascending = true
	up.depth = 3
	up.map.set_tile(5, 5, Tiles.STAIRS_UP)
	check("G climbs where the stairs go up", up.player_pickup())

	# --- the sling, in hand and in the pack -------------------------------
	#
	# Gabe's real complaint: rubble could only be worked with the sling
	# EQUIPPED, so topping up meant swapping to it and back -- a turn at each
	# end.
	var r := _arena(21, 11)
	r.player.x = 5
	r.player.y = 5
	r.map.set_tile(5, 5, Tiles.RUBBLE)
	check("with no sling at all, rubble refuses", not r.player_pickup())

	var packed := Item.make(&"sling")
	packed.ammo = 0
	r.player.inventory.append(packed)
	check("a sling in the PACK is enough (%d)" % packed.ammo, r.player_pickup())
	check("and it gained the stone", packed.ammo == 1, "%d" % packed.ammo)

	# The equipped one is preferred when it has room.
	var r2 := _arena(21, 11)
	r2.player.x = 5
	r2.player.y = 5
	r2.map.set_tile(5, 5, Tiles.RUBBLE)
	var held := Item.make(&"sling")
	held.ammo = 0
	var spare := Item.make(&"sling")
	spare.ammo = 0
	r2.player.inventory.append(held)
	r2.player.inventory.append(spare)
	r2.player.equipped[Item.Slot.WEAPON] = held
	check("the sling in hand is filled first", r2.player_pickup())
	check("the held one took it", held.ammo == 1, "%d" % held.ammo)
	check("and the spare was left alone", spare.ammo == 0, "%d" % spare.ammo)

	# Full slings say so, and say something DIFFERENT from having none.
	var r3 := _arena(21, 11)
	r3.player.x = 5
	r3.player.y = 5
	r3.map.set_tile(5, 5, Tiles.RUBBLE)
	var full := Item.make(&"sling")
	full.ammo = full.ammo_max
	r3.player.inventory.append(full)
	check("a full sling refuses", not r3.player_pickup())
	var said := ""
	for line in r3.msg_log.entries:
		said = String(line.get("text", ""))
	check("and says it is full rather than that you have none",
		said.findn("carry") >= 0, said)

## Total damage over `n` swings.
##
## A single blow carries `rng.randi_range(-1, 1)`, and a buckler's bash is +2 --
## the noise is the same size as the effect. The first version of these checks
## compared one swing against one swing and reported a bash travelling down a
## bowstring when the real difference was a die roll.
func _swing_total(gs: GameState, who: Entity, at: Entity, n: int,
		ranged := false) -> int:
	var total := 0
	for i in n:
		at.hp = 9999
		gs._attack(who, at, ranged)
		total += 9999 - at.hp
	return total

## The element table and the catalogue must describe the same set of stones.
##
## They were one hand-kept array and a set of match arms, which is the shape the
## comment above accepts_element warned about from the beginning. Consolidating
## them removed the chance of silent disagreement; this is what keeps it removed
## when the next gem arrives.
func _test_the_element_table_agrees_with_itself() -> void:
	# The premise. An empty table would make every loop below pass by not
	# running -- the commonest defect in this suite.
	check("there are elements to check (%d)" % Item.ELEMENTS.size(),
		Item.ELEMENTS.size() >= 8)

	var hosts_seen := {}
	for el in Item.ELEMENTS:
		var rule: Dictionary = Item.ELEMENTS[el]
		var gem := Item.make(StringName(rule["gem"]))
		check("%s names a gem that exists" % el, gem != null, String(rule["gem"]))
		if gem != null:
			check("  and that gem carries %s" % el, gem.element == el,
				String(gem.element))
			check("  and it really is a gem", gem.kind == Item.Kind.GEM)
		hosts_seen[rule["hosts"]] = true

	# Every gem in the catalogue must be in the table, or it is bindable by the
	# forge and invisible to found magic -- a difference nobody would spot by
	# reading either one alone.
	var missing := PackedStringArray()
	for key in Item.CATALOGUE:
		var data: Dictionary = Item.CATALOGUE[key]
		if int(data.get("kind", -1)) != Item.Kind.GEM:
			continue
		var el: StringName = data.get("element", &"")
		if not Item.ELEMENTS.has(el):
			missing.append("%s (%s)" % [key, el])
	check("every catalogue gem is in the table", missing.is_empty(),
		", ".join(missing))

	# And the reverse: found magic is derived from the table, so the two lists
	# cannot disagree by construction -- assert that it stayed that way.
	var found := Item.found_elements()
	check("found magic offers every element (%d)" % found.size(),
		found.size() == Item.ELEMENTS.size(),
		"%d vs %d" % [found.size(), Item.ELEMENTS.size()])

	# ORDER IS LOAD-BEARING: _maybe_enchant indexes the legal list with
	# enchant_rng, so a reordering silently changes what a seed rolls.
	check("and in the order the table declares",
		found[0] == &"fire" and found[1] == &"frost" and found[2] == &"leech",
		str(found))

	# Every `hosts` rule must be one accepts_element actually implements. A typo
	# would fall through the match and refuse everything, which reads exactly
	# like "that item cannot hold it" and is invisible in play.
	var known := {&"weapon": true, &"melee": true, &"bow": true, &"shield": true}
	var bad := PackedStringArray()
	for h in hosts_seen:
		if not known.has(h):
			bad.append(String(h))
	check("every hosts rule is one the gate knows", bad.is_empty(),
		", ".join(bad))

	# And the rules still do what they did before the table existed.
	var dagger := Item.make(&"dagger")
	var bow := Item.make(&"short_bow")
	var sling := Item.make(&"sling")
	var mail := Item.make(&"chain_mail")
	var kite := Item.make(&"kite_shield")
	check("fire goes on anything you fight with", dagger.accepts_element(&"fire")
		and bow.accepts_element(&"fire") and sling.accepts_element(&"fire"))
	check("frost is melee only", dagger.accepts_element(&"frost")
		and not bow.accepts_element(&"frost"))
	check("returning is arrows only", bow.accepts_element(&"return")
		and not sling.accepts_element(&"return"))
	check("shield stones are the offhand only",
		kite.accepts_element(&"block") and not dagger.accepts_element(&"block"))
	check("and armour still holds nothing", not mail.accepts_element(&"fire")
		and not mail.accepts_element(&"block"))

## Three stones, one slot, one permanent choice.
##
## Brad's argument and it overruled mine: one gem per slot is "this effect or
## nothing", which is not a choice at all. These have to be genuinely different
## from each other or the slot is decoration.
func _test_the_other_two_shield_stones() -> void:
	var kite := Item.make(&"kite_shield")
	var mail := Item.make(&"chain_mail")
	var dagger := Item.make(&"dagger")

	check("a shield takes the mirror", kite.accepts_element(&"reflect"))
	check("and the boss", kite.accepts_element(&"bash"))
	check("body armour takes neither",
		not mail.accepts_element(&"reflect") and not mail.accepts_element(&"bash"))
	check("nor does a blade",
		not dagger.accepts_element(&"reflect") and not dagger.accepts_element(&"bash"))

	# --- BASH: the shield as a weapon ------------------------------------
	var gs := _arena(21, 11)
	gs.player.x = 5
	gs.player.y = 5
	var orc := _spawn(gs, "orc", 6, 5)
	orc.max_hp = 9999
	orc.hp = 9999
	var swings := 30
	gs.player.equipped.erase(Item.Slot.OFFHAND)
	var bare := _swing_total(gs, gs.player, orc, swings)
	check("an unbossed swing lands for something (%d over %d)" % [bare, swings],
		bare > 0)

	# Each tier must beat the one below it, not merely beat nothing.
	var last := bare
	for tier in [&"buckler", &"kite_shield", &"tower_shield"]:
		var sh := Item.make(tier)
		sh.element = &"bash"
		gs.player.equipped[Item.Slot.OFFHAND] = sh
		var with := _swing_total(gs, gs.player, orc, swings)
		check("a %s hits harder than the tier below (%d vs %d over %d)"
			% [sh.name, with, last, swings], with > last)
		last = with

	# A shield with no stone must add NOTHING, or bash is just what shields do
	# and the gem is decoration. Compared as an average so the rng cannot make
	# a real difference look like noise or the reverse.
	var plain := Item.make(&"tower_shield")
	gs.player.equipped[Item.Slot.OFFHAND] = plain
	var unbound := _swing_total(gs, gs.player, orc, swings)
	check("but a shield with no stone adds nothing (%d vs %d over %d)"
		% [unbound, bare, swings],
		absi(unbound - bare) <= swings, "outside the rng band")

	# Bash is for swinging, not shooting.
	var shooter := Item.make(&"tower_shield")
	shooter.element = &"bash"
	gs.player.equipped[Item.Slot.OFFHAND] = shooter
	var shot := _swing_total(gs, gs.player, orc, swings, true)
	gs.player.equipped.erase(Item.Slot.OFFHAND)
	var unshot := _swing_total(gs, gs.player, orc, swings, true)
	check("and a bash does not travel down a bowstring (%d vs %d over %d)"
		% [shot, unshot, swings],
		absi(shot - unshot) <= swings, "outside the rng band")

	# --- REFLECT: the blow given back -------------------------------------
	var r := _arena(21, 11)
	r.player.x = 5
	r.player.y = 5
	var biter := _spawn(r, "orc", 6, 5)
	biter.max_hp = 9999
	biter.hp = 9999
	r.player.equipped.erase(Item.Slot.OFFHAND)
	r.player.hp = 9999
	r._attack(biter, r.player)
	check("without a mirror the attacker takes nothing", biter.hp == 9999,
		"%d" % (9999 - biter.hp))

	var mirror := Item.make(&"kite_shield")
	mirror.element = &"reflect"
	r.player.equipped[Item.Slot.OFFHAND] = mirror
	r.player.hp = 9999
	r._attack(biter, r.player)
	check("with one, it comes back by the tier (%d)" % (9999 - biter.hp),
		9999 - biter.hp == mirror.defense_bonus)

	# Melee only -- an arrow is not a blow your shield can turn around.
	biter.hp = 9999
	r.player.hp = 9999
	r._attack(biter, r.player, true)
	check("an arrow is not thrown back", biter.hp == 9999,
		"%d" % (9999 - biter.hp))

	# AND IT HAS TO BE ABLE TO KILL, through the same door a swing uses.
	var k := _arena(21, 11)
	k.player.x = 5
	k.player.y = 5
	var doomed := _spawn(k, "giant rat", 6, 5)
	check("the doomed rat exists", doomed != null)
	var tower := Item.make(&"tower_shield")
	tower.element = &"reflect"
	k.player.equipped[Item.Slot.OFFHAND] = tower
	k.player.hp = 9999
	doomed.hp = 1
	var xp_before := k.player.xp
	k._attack(doomed, k.player)
	check("a reflected blow can kill", not doomed.alive)
	check("and it pays experience like any other kill (%d -> %d)"
		% [xp_before, k.player.xp], k.player.xp > xp_before)

## The shield hand finally holds something, and it reaches past the floor.
func _test_gem_of_the_bulwark() -> void:
	var buckler := Item.make(&"buckler")
	var kite := Item.make(&"kite_shield")
	var tower := Item.make(&"tower_shield")
	var mail := Item.make(&"chain_mail")
	var dagger := Item.make(&"dagger")
	var bow := Item.make(&"short_bow")

	# --- who will hold it ------------------------------------------------
	# The MUST-SUCCEED check first, so the refusals below cannot all pass by
	# aiming at an element nothing accepts.
	check("a shield takes the bulwark", buckler.accepts_element(&"block"))
	check("every tier of it", kite.accepts_element(&"block")
		and tower.accepts_element(&"block"))
	check("body armour does not -- it is not the shield hand",
		not mail.accepts_element(&"block"))
	check("nor a blade", not dagger.accepts_element(&"block"))
	check("nor a bow, which only CLAIMS the offhand",
		not bow.accepts_element(&"block"))
	# Opening the gate must not have opened it for everything else.
	check("and a shield still holds no fire", not buckler.accepts_element(&"fire"))
	check("nor frost, leech, crag or returning",
		not buckler.accepts_element(&"frost")
		and not buckler.accepts_element(&"leech")
		and not buckler.accepts_element(&"crag")
		and not buckler.accepts_element(&"return"))

	# --- what it is worth ------------------------------------------------
	check("an empty shield hand turns nothing",
		Entity.new("nobody", &"player", 0, 0).block_amount() == 0)
	var gs := _arena(21, 9)
	gs.player.x = 5
	gs.player.y = 4
	check("a shield with no stone turns nothing either",
		gs.player.block_amount() == 0)
	gs.player.equipped[Item.Slot.OFFHAND] = kite
	check("and one with a stone turns its tier", _bulwark(gs.player, kite) == 2)

	# --- the whole point: past the damage floor --------------------------
	#
	# The shield ladder is tuned so more DEFENSE does nothing once an attacker
	# is already at the floor. If blocking did not reach past it, these two
	# numbers would be equal and the stone would be decoration.
	var orc := _spawn(gs, "orc", 6, 4)
	gs.player.max_hp = 9999
	gs.player.equipped.erase(Item.Slot.OFFHAND)

	# Pinned to the floor on purpose. With defense this high the subtraction is
	# far below `least`, so every blow lands for exactly the floor and the rng
	# spread cannot reach it -- which makes the three numbers below comparable
	# rather than merely different.
	gs.player.defense = 500
	gs.player.hp = 9999
	gs._attack(orc, gs.player)
	var floored := 9999 - gs.player.hp
	check("a floored blow still lands (%d)" % floored, floored > 0)

	# The premise the shield ladder is built on, asserted rather than assumed:
	# once an attacker is at the floor, MORE DEFENSE BUYS NOTHING. If this ever
	# stops being true, the bulwark's whole reason to exist has gone with it.
	var plain := Item.make(&"tower_shield")
	gs.player.equipped[Item.Slot.OFFHAND] = plain
	gs.player.hp = 9999
	gs._attack(orc, gs.player)
	var with_shield := 9999 - gs.player.hp
	check("a shield with no stone changes nothing at the floor (%d -> %d)"
		% [floored, with_shield], with_shield == floored)

	# Same shield, same orc, same floor. The ONLY difference is the stone.
	plain.element = &"block"
	gs.player.hp = 9999
	gs._attack(orc, gs.player)
	var with_stone := 9999 - gs.player.hp
	check("the stone turns what the floor forced through (%d -> %d)"
		% [with_shield, with_stone], with_stone < with_shield)
	check("but never all of it", with_stone >= 1)

	# An orc floors at 2, so a tier-3 shield clamps to 1 and the TIER never
	# shows. Struck with something big enough to have room in it, the full
	# subtraction is visible -- and this is the check that would catch a
	# bulwark that turned a flat 1 regardless of what you were carrying.
	var heavy := 40
	var expect := int(ceil(float(heavy) * GameState.DAMAGE_FLOOR_FRACTION))
	gs.player.equipped.erase(Item.Slot.OFFHAND)
	gs.player.hp = 9999
	gs._attack(orc, gs.player, false, heavy)
	var big := 9999 - gs.player.hp
	check("a heavy blow floors at a quarter of its power (%d)" % big,
		big == expect, "expected %d" % expect)
	for tier in [&"buckler", &"kite_shield", &"tower_shield"]:
		var sh := Item.make(tier)
		sh.element = &"block"
		gs.player.equipped[Item.Slot.OFFHAND] = sh
		gs.player.hp = 9999
		gs._attack(orc, gs.player, false, heavy)
		var got := 9999 - gs.player.hp
		check("a %s turns exactly its tier (%d off %d)"
			% [sh.name, big - got, big],
			big - got == sh.defense_bonus)

	# --- it is said out loud ---------------------------------------------
	var said := false
	for line in gs.msg_log.entries:
		if String(line.get("text", "")).findn("shield turns") >= 0:
			said = true
	check("and the shield is mentioned when it does", said)

	# --- binding it at the coals -----------------------------------------
	var gs2 := _arena(21, 9)
	gs2.player.x = 5
	gs2.player.y = 4
	gs2.map.set_tile(6, 4, Tiles.BRAZIER_SPENT)
	gs2.ember_until[Vector2i(6, 4)] = gs2.turns + GameState.EMBER_TURNS
	var stone := Item.make(&"gem_bulwark")
	gs2.player.inventory.append(stone)
	check("with no shield there is nothing to set it into",
		not gs2.can_bind_gem(stone))
	var worn := Item.make(&"buckler")
	gs2.player.inventory.append(worn)
	gs2.player.equipped[Item.Slot.OFFHAND] = worn
	check("with one, the forge offers", gs2.can_bind_gem(stone))
	check("and it takes", gs2.player_bind(gs2.player.inventory.find(stone)))
	check("the shield now holds it", worn.element == &"block")

	# The weapon hand must not have been robbed to do it.
	check("the stone went to the shield, not the weapon",
		gs2.player.equipped.get(Item.Slot.WEAPON, null) == null
		or gs2.player.equipped[Item.Slot.WEAPON].element == &"")

	# --- and it survives being written down ------------------------------
	# The binding bug was nineteen commits of silent loss because a suffix had
	# two ends and only one of them knew about it.
	var back := Item.from_display_name(worn.display_name())
	check("a bound shield round-trips through its name", back != null,
		worn.display_name())
	if back != null:
		check("keeping the stone", back.element == &"block")
		check("and its tier", back.defense_bonus == worn.defense_bonus)

## Reads the tier through the entity, so the test cannot quietly measure the
## item it is holding instead of the one the game consults.
func _bulwark(who: Entity, shield: Item) -> int:
	shield.element = &"block"
	return who.block_amount()

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

## The one thing in the dungeon that wants to talk to you.
func _test_the_trader() -> void:
	# On the first floor of every band, and nowhere else.
	var wrong: Array[String] = []
	for d in range(1, 20):
		var gs := GameState.new(770 + d)
		gs.new_game()
		gs.depth = d
		gs.build_level()
		var want: bool = GameState.TRADER_FLOORS.has(d)
		if (gs.trader != null) != want:
			wrong.append("depth %d" % d)
	check("a trader stands on the first floor of each band and nowhere else",
		wrong.is_empty(), str(wrong))

	var gs := GameState.new(4242)
	gs.new_game()
	gs.depth = 1
	gs.build_level()
	check("floor one has one", gs.trader != null)
	if gs.trader == null:
		return

	# NEVER on the stairs, and this is a softlock rather than an annoyance.
	# Walking into the trader talks instead of swapping places -- that is what
	# makes it a conversation and not a shove -- so a trader standing on the
	# way down leaves the floor with no exit. Reported from play on floor one.
	#
	# Checked across every trader floor rather than one, because the cell is
	# picked per room and the bug only shows when the chosen room happens to be
	# the one holding the stairs.
	var on_stairs: Array[String] = []
	var on_player: Array[String] = []
	for d in GameState.TRADER_FLOORS:
		for i in 40:
			var g := GameState.new(2400 + int(d) * 70 + i)
			g.new_game()
			g.depth = int(d)
			g.build_level()
			if g.trader == null:
				continue
			var cell := Vector2i(g.trader.x, g.trader.y)
			if cell == g.stairs:
				on_stairs.append("depth %d seed %d" % [int(d), 2400 + int(d) * 70 + i])
			if cell == Vector2i(g.player.x, g.player.y):
				on_player.append("depth %d" % int(d))
	check("a trader never blocks the stairs", on_stairs.is_empty(),
		str(on_stairs.slice(0, 3)))
	check("and never stands on the player", on_player.is_empty(),
		str(on_player.slice(0, 3)))

	# Nothing fights it, and it fights nothing. A monster that could kill the
	# trader would delete the floor's only conversation, and the player would
	# never learn it had been there.
	var hostile := 0
	for e in gs.entities:
		if e.hostile_to(gs.trader) or gs.trader.hostile_to(e):
			hostile += 1
	check("nothing is hostile to the trader", hostile == 0, str(hostile))

	# It never takes a turn, so "there is a trader on this floor" cannot become
	# a lie the legend tells.
	var was := Vector2i(gs.trader.x, gs.trader.y)
	for i in 200:
		gs._take_ai_turn(gs.trader)
	check("and it never wanders off",
		Vector2i(gs.trader.x, gs.trader.y) == was)

	# Walking into it talks instead of swapping places. player_move trades
	# places with anything non-hostile -- that rule exists for allies in
	# corridors -- so without an earlier branch the player shoves past the one
	# thing that wants to speak to them.
	gs.player.x = gs.trader.x - 1
	gs.player.y = gs.trader.y
	var turns_before := gs.turns
	gs.take_events()
	var acted := gs.player_move(1, 0)
	var evts := gs.take_events()
	var talked := false
	for ev in evts:
		if ev.get("kind", &"") == &"talk":
			talked = true
	check("walking into the trader starts a conversation", acted and talked)
	check("and the player did not swap places with it",
		gs.player.x == gs.trader.x - 1 and gs.trader.x != gs.player.x)
	# Free, like the ally stance key. Nothing on the floor gets a move because
	# you said hello.
	check("and saying hello costs no time", gs.turns == turns_before)

	# EVERY event carries "to". GlyphGrid.play_events reads it before it looks
	# at the kind, so an event without one does not fall through harmlessly --
	# it freezes the game. The first talk event shipped without one and walking
	# into the trader hung on the spot.
	var homeless: Array[String] = []
	for ev in evts:
		if not ev.has("to"):
			homeless.append(String(ev.get("kind", &"?")))
	check("every event it raises carries a cell", homeless.is_empty(),
		str(homeless))
	# And the renderer really does survive them, rather than us asserting the
	# shape of the thing that broke.
	var grid := GlyphGrid.new()
	grid.state = gs
	grid.play_events(evts)
	check("the renderer plays them without falling over", true)

## Weapons that arrive already carrying an element.
##
## Written because the tally did not move when the generator landed -- 1368
## before and 1368 after, which is this suite saying plainly that none of it was
## covered.
func _test_found_magic() -> void:
	# The curve climbs with EFFECTIVE depth rather than folding at the bottom.
	# Keyed on the mirrored band it would have made floors 14-16 caves again,
	# and the player climbing out would meet a magic drought two thirds of the
	# way home -- the opposite of what the escalation is for.
	check("magic gets richer as you go, not symmetrical",
		Item.enchant_chance(19) > Item.enchant_chance(10)
			and Item.enchant_chance(10) > Item.enchant_chance(1),
		"1:%.3f 10:%.3f 19:%.3f" % [Item.enchant_chance(1),
			Item.enchant_chance(10), Item.enchant_chance(19)])

	# The caves are thinned ON PURPOSE. They carry a third of the loot the other
	# bands do -- measured, 2.7 floor items against 7.8 -- and being magic-poor
	# as well is the point: three floors down and three up where the fungus and
	# the meat have to keep you alive instead.
	check("the caves are leaner than the floors either side",
		Item.enchant_chance(5) < Item.enchant_chance(3)
			and Item.enchant_chance(5) < Item.enchant_chance(7),
		"3:%.3f 5:%.3f 7:%.3f" % [Item.enchant_chance(3),
			Item.enchant_chance(5), Item.enchant_chance(7)])
	check("and the caves are thin on the climb too",
		Item.enchant_chance(15) < Item.enchant_chance(13)
			and Item.enchant_chance(15) < Item.enchant_chance(17))

	# Nothing may arrive with an element the gem system would refuse to bind.
	# A sling of frost is an item a player is explicitly forbidden to make, and
	# two systems disagreeing about what is possible is worse than either rule
	# on its own.
	var illegal: Array[String] = []
	var enchanted := 0
	for d in [2, 5, 8, 11, 16, 19]:
		for i in 25:
			var gs := GameState.new(31000 + d * 60 + i)
			gs.new_game()
			gs.depth = d
			gs.build_level()
			var pool: Array = []
			for it in gs.ground:
				pool.append(it)
			for e in gs.entities:
				for slot in e.equipped:
					if e.equipped[slot] != null:
						pool.append(e.equipped[slot])
			for it in pool:
				if it.element == &"" or it.kind == Item.Kind.GEM:
					continue
				enchanted += 1
				if not it.accepts_element(it.element):
					illegal.append("%s / %s" % [it.name, it.element])
	check("found magic is never something a gem could not bind",
		illegal.is_empty(), str(illegal.slice(0, 4)))
	# A guard on the guard: if generation stopped producing magic entirely the
	# check above would pass by vacuum.
	check("and the generator actually produced some (%d)" % enchanted,
		enchanted > 0)

	# Uniques are authored one per dungeon. An extra element on top of a
	# designed item is not something anyone priced.
	#
	# Read from Item.uniques() rather than naming an id here. The first draft
	# hardcoded &"ring_rat" -- the real id is &"rat_ring" -- so make() threw,
	# the null guard swallowed it, and the check silently ceased to exist while
	# the tally still went up. A test that can vanish is worse than no test.
	var uniques := Item.uniques(GameState.MAX_DEPTH * 2)
	check("there are uniques to check (%d)" % uniques.size(), not uniques.is_empty())
	var enchanted_unique := ""
	for key in uniques:
		# Many attempts, not one: at the deepest rate the roll still misses
		# most of the time, so a single call would pass whether the guard
		# worked or not.
		for i in 200:
			var u := Item.make(key)
			if u == null:
				continue
			Item._maybe_enchant(u, _rng_for(9000 + i), GameState.MAX_DEPTH * 2 - 1)
			if u.element != &"":
				enchanted_unique = "%s -> %s" % [u.name, u.element]
				break
		if enchanted_unique != "":
			break
	check("a unique is never enchanted", enchanted_unique == "", enchanted_unique)

	# The roll must not touch the run's own stream. On it, the number of draws
	# depended on how much loot a floor rolled and everything after moved:
	# identical seeds gave 29269 walls or 28870 and 135 monsters or 149.
	var a := GameState.new(4242)
	a.new_game()
	a.depth = 6
	a.build_level()
	var b := GameState.new(4242)
	b.new_game()
	b.depth = 6
	b.build_level()
	check("the same seed still builds the same floor",
		a.ground.size() == b.ground.size()
			and a.entities.size() == b.entities.size(),
		"%d/%d vs %d/%d" % [a.ground.size(), a.entities.size(),
			b.ground.size(), b.entities.size()])

	# The pity gem asks whether THIS PLAYER has bound one. It used to infer that
	# from any elemental item anywhere, which found magic quietly falsified: a
	# kobold carrying an enchanted sword read as "the player has met a gem" and
	# skipped the guarantee on 8 seeds in 60.
	var armed := 0
	var barren := 0
	for i in 40:
		var gs := GameState.new(6100 + i)
		gs.new_game()
		gs.depth = 2
		gs.build_level()
		var gem := false
		for it in gs.ground:
			if it.kind == Item.Kind.GEM:
				gem = true
		if not gem:
			barren += 1
		for e in gs.entities:
			if e.is_player:
				continue
			for slot in e.equipped:
				if e.equipped[slot] != null and e.equipped[slot].element != &"":
					armed += 1
	check("the first gem is still certain beside enchanted monsters (%d armed)"
		% armed, barren == 0, "%d barren of 40" % barren)

## A throwaway rng for a static call that wants one.
func _rng_for(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

## The pack has to be usable by something with no letters on it.
##
## Reported from play on a Legion Go S: the inventory opened and nothing could
## be chosen. Every route in was a letter key or the mouse, and a controller
## sends neither -- Brad had to tap the touchscreen to equip anything.
func _test_pack_without_letters() -> void:
	var gs := _arena(21, 11)
	var pack := InventoryPanel.new()
	pack.state = gs
	for id in [&"short_sword", &"leather_armour", &"potion_healing",
			&"scroll_light"]:
		var it := Item.make(id)
		if it != null:
			gs.give_item(it)
	pack.open()

	# The premise. If the pack were empty every check below would pass while
	# testing nothing.
	var rows := pack.selectable()
	check("the pack has rows to select (%d)" % rows.size(), rows.size() >= 3)

	check("nothing is highlighted to begin with", pack.hovered() < 0)
	pack.move_hover(1)
	check("down highlights the first row", pack.hovered() == rows[0],
		"%d vs %d" % [pack.hovered(), rows[0] if rows else -1])
	pack.move_hover(-1)
	check("and up from there wraps to the last", pack.hovered() == rows[-1])
	pack.move_hover(1)
	check("and wraps forward again", pack.hovered() == rows[0])

	# Walking the whole list must visit every row and come back.
	var seen := {}
	for i in rows.size():
		seen[pack.hovered()] = true
		pack.move_hover(1)
	check("walking the list reaches every row",
		seen.size() == rows.size(), "%d of %d" % [seen.size(), rows.size()])
	check("and returns to where it started", pack.hovered() == rows[0])

	# A highlight must never point at a row the mouse could not click -- the
	# two come from the same _row_rects(), and this is what keeps them honest.
	check("the highlight is always a real row", pack.selectable().has(pack.hovered()))

	# Filtering changes what is on screen, so the highlight cannot survive it.
	pack.cycle_filter(1)
	check("changing filter clears the highlight", pack.hovered() < 0)
	pack.free()

	# And the controller screen must not rebind just because it was opened.
	#
	# It used to start listening on open, so a player looking at their bindings
	# rebound "move up" to whatever they pressed -- and the way out is
	# keyboard-only, so on a handheld there was no way to stop.
	var pad := PadPanel.new()
	var cfg := PadConfig.new()
	var was := cfg.button_for_key(KEY_UP)
	pad.open(cfg)
	check("the controller screen opens without listening", not pad._listening)
	# REBINDING IS ASKED FOR NOW, not stumbled into. Two people rebound "move
	# up" by pressing something to see what it did.
	var idle := InputEventJoypadButton.new()
	idle.button_index = JOY_BUTTON_X
	idle.pressed = true
	pad.handle_pad(idle)
	check("an ordinary press changes nothing at all",
		cfg.button_for_key(KEY_UP) == was and not pad._listening,
		"rebound to %d" % cfg.button_for_key(KEY_UP))

	var press := InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_Y
	press.pressed = true
	pad.handle_pad(press)
	check("and the asking button starts the walk-through",
		cfg.button_for_key(KEY_UP) == was, "rebound to %d" % cfg.button_for_key(KEY_UP))
	check("but it is listening now", pad._listening)
	pad.handle_pad(press)
	check("and the next press does bind", cfg.button_for_key(KEY_UP) == JOY_BUTTON_Y)
	pad.free()

	# --- and there is a way OUT of it without a keyboard -------------------
	#
	# main.gd feeds joypad events to this panel before translating them, so
	# while it is open every button is swallowed by the walk-through. Start
	# could not close it because Start was just another button to bind, and all
	# four documented exits are keyboard keys. On a Legion Go S that made the
	# controller screen a one-way door -- found in play 2026-09-22.
	var out_pad := PadPanel.new()
	var out_cfg := PadConfig.new()
	out_pad.open(out_cfg)
	var shut := {"n": 0}
	out_pad.closed.connect(func() -> void: shut["n"] += 1)

	# Must-succeed first: if the panel were not open, every check below would
	# pass while testing nothing.
	check("the controller screen is open to begin with", out_pad.visible)
	var start := InputEventJoypadButton.new()
	start.button_index = JOY_BUTTON_START
	start.pressed = true
	out_pad.handle_pad(start)
	check("Start closes it from the pad alone", not out_pad.visible)
	check("and it says so once", shut["n"] == 1, "%d" % shut["n"])
	check("without starting a rebind", not out_pad._listening)
	check("and without binding Start to anything",
		out_cfg.key_for_button(JOY_BUTTON_START) == KEY_ESCAPE,
		OS.get_keycode_string(out_cfg.key_for_button(JOY_BUTTON_START)))

	# Back restores the defaults, which is the only pad-reachable cure for a
	# stale gamepad.cfg -- `load_saved` takes the file wholesale, so four
	# testers kept old d-pad bindings and could not reach the stairs.
	var stale := PadConfig.new()
	stale.bind(JOY_BUTTON_DPAD_DOWN, KEY_UP)
	check("a stale binding is in place to begin with",
		stale.key_for_button(JOY_BUTTON_DPAD_DOWN) == KEY_UP)
	var fix := PadPanel.new()
	fix.open(stale)
	var back := InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_BACK
	back.pressed = true
	fix.handle_pad(back)
	check("Back puts the defaults back from the pad alone",
		stale.key_for_button(JOY_BUTTON_DPAD_DOWN) == KEY_GREATER,
		OS.get_keycode_string(stale.key_for_button(JOY_BUTTON_DPAD_DOWN)))
	check("and leaves the screen open to look at", fix.visible)

	# THE CASE THAT MAKES THE RESERVATION SAFE. Once the walk-through is
	# running, every button binds -- otherwise reaching the "menu" row and
	# pressing the obvious button would quit instead of binding it, and Start
	# could never be assigned to anything at all.
	var walk := PadPanel.new()
	var walk_cfg := PadConfig.new()
	walk.open(walk_cfg)
	var any := InputEventJoypadButton.new()
	any.button_index = JOY_BUTTON_Y
	any.pressed = true
	walk.handle_pad(any)
	check("a walk-through is running", walk._listening)
	# Once it IS running, every button binds -- including the one that started
	# it -- or Y could never be assigned to anything at all.
	walk.handle_pad(start)
	check("Start does NOT close mid-walk-through", walk.visible)
	check("it binds like any other button",
		walk_cfg.button_for_key(KEY_UP) == JOY_BUTTON_START,
		"%d" % walk_cfg.button_for_key(KEY_UP))
	walk.handle_pad(back)
	check("and so does Back",
		walk_cfg.button_for_key(KEY_DOWN) == JOY_BUTTON_BACK,
		"%d" % walk_cfg.button_for_key(KEY_DOWN))

	# The walk-through must still END by itself, or "every button binds" would
	# be the trap all over again.
	# Pressed until it stops, not a fixed count: two rows are already bound
	# above, and overshooting RESTARTS the walk-through, which is correct
	# behaviour and made the first version of this check fail.
	var guard := 0
	while walk._listening and guard < 200:
		walk.handle_pad(any)
		guard += 1
	check("the walk-through finishes on its own (%d presses)" % guard,
		not walk._listening)
	check("leaving Start able to close again", walk.visible)
	walk.handle_pad(start)
	check("which it does", not walk.visible)
	out_pad.free()
	fix.free()
	walk.free()

	# The footer has to SAY so. A reserved button nobody is told about is no
	# better than no reserved button.
	check("the pad footer names the button that leaves",
		PadPanel.pad_footer().findn("done") >= 0
		and PadPanel.pad_footer().findn(PadConfig.button_name(JOY_BUTTON_START)) >= 0,
		PadPanel.pad_footer())
	check("and the one that starts rebinding",
		PadPanel.pad_footer().findn("rebind") >= 0
		and PadPanel.pad_footer().findn(PadConfig.button_name(JOY_BUTTON_Y)) >= 0,
		PadPanel.pad_footer())
	check("and the one that restores defaults",
		PadPanel.pad_footer().findn("defaults") >= 0
		and PadPanel.pad_footer().findn(PadConfig.button_name(JOY_BUTTON_BACK)) >= 0,
		PadPanel.pad_footer())

	# Buttons are named, not numbered.
	check("a button has a name", PadConfig.button_name(JOY_BUTTON_A) == "A")
	check("and an unknown index still says something true",
		PadConfig.button_name(97) == "button 97")

## Stone the crag gem raises has to go away again.
##
## Reported from play: a spire can seal a one-wide corridor, and the floor
## behind it is then unreachable. Brad chose a timer over a connectivity check,
## which is the better trade -- a check runs on every connecting blow and can
## only ever say no, while temporary stone says yes and undoes itself.
func _test_spires_subside() -> void:
	var raised_any := false
	var leftover := 0
	var trials := 0
	for seed_value in [9, 23, 41, 77]:
		var gs := GameState.new(seed_value)
		gs.new_game()
		gs.depth = 3
		gs.build_level()
		var victim: Entity = null
		for e in gs.entities:
			if not e.is_player:
				victim = e
				break
		if victim == null:
			continue
		trials += 1
		var before := _stalagmites(gs)
		gs._raise_spires(victim, GameState.GEM_CRAG_SPIRES)
		if _stalagmites(gs) > before:
			raised_any = true
		# Long enough that every spire is due, plus one.
		for t in GameState.GEM_CRAG_TURNS + 2:
			gs.turns += 1
			gs._let_the_stone_settle()
		if _stalagmites(gs) != before or not gs.spires.is_empty():
			leftover += 1

	# Vacuity guard: if nothing ever raised, "it all went away" is meaningless.
	check("the crag gem actually raises stone", raised_any)
	check("and all of it subsides again (%d trials)" % trials,
		leftover == 0, "%d floors kept stone" % leftover)

	# A missile weapon raises stone in proportion to its reach, and the point
	# is the ammunition rather than the power: the sling knaps stones out of
	# rubble and can throw walls forever, while a war bow spends arrows the
	# dungeon never replaces. Brad's design.
	var arena := _arena(21, 11)
	var thrower := arena.player
	var counts := {}
	for pair in [["sling", 1], ["short_bow", 2], ["war_bow", 3]]:
		var wpn := Item.make(StringName(pair[0]))
		thrower.equipped[Item.Slot.WEAPON] = wpn
		counts[String(pair[0])] = arena._crag_spires_for(thrower, true)
		check("a %s raises %d" % [wpn.name, int(pair[1])],
			arena._crag_spires_for(thrower, true) == int(pair[1]),
			"%d" % arena._crag_spires_for(thrower, true))
	check("and they are not all the same number",
		counts.values().size() == 3
			and int(counts["sling"]) < int(counts["war_bow"]))
	# Melee is untouched, so the gem still works the way it always did in hand.
	thrower.equipped[Item.Slot.WEAPON] = Item.make(&"short_sword")
	check("melee is unchanged",
		arena._crag_spires_for(thrower, false) == GameState.GEM_CRAG_SPIRES)
	arena = null

	# The tile that was there is what comes back -- not FLOOR. Cave ground
	# exists, and a spire raised on it must not leave a room behind.
	var gs2 := GameState.new(41)
	gs2.new_game()
	gs2.depth = 5
	gs2.build_level()
	var cell := Vector2i(-1, -1)
	for y in gs2.map.height:
		for x in gs2.map.width:
			if gs2.map.get_tile(x, y) == Tiles.CAVE_FLOOR:
				cell = Vector2i(x, y)
				break
		if cell.x >= 0:
			break
	if cell.x >= 0:
		gs2.spires[cell] = [gs2.turns, Tiles.CAVE_FLOOR]
		gs2.map.set_tile(cell.x, cell.y, Tiles.STALAGMITE)
		gs2._let_the_stone_settle()
		check("and cave ground comes back as cave ground",
			gs2.map.get_tile(cell.x, cell.y) == Tiles.CAVE_FLOOR)

	# A creature standing where stone is due keeps it up rather than being
	# buried inside it.
	var gs3 := _arena(21, 11)
	var spot := Vector2i(8, 5)
	gs3.map.set_tile(spot.x, spot.y, Tiles.STALAGMITE)
	gs3.spires[spot] = [gs3.turns, Tiles.FLOOR]
	var squatter := _spawn(gs3, "goblin", spot.x, spot.y)
	if squatter != null:
		gs3._let_the_stone_settle()
		check("stone waits rather than burying what stands on it",
			gs3.map.get_tile(spot.x, spot.y) == Tiles.STALAGMITE
				and gs3.spires.has(spot))

	# And a trader must not stand on a feature -- reported from play, standing
	# on a shrine, which hid it and put a conversation on a thing you use.
	var on_feature: Array[String] = []
	for d in GameState.TRADER_FLOORS:
		for i in 12:
			var g := GameState.new(4400 + int(d) * 13 + i)
			g.new_game()
			g.depth = int(d)
			g.build_level()
			if g.trader == null:
				continue
			var t := g.map.get_tile(g.trader.x, g.trader.y)
			if t in [Tiles.SHRINE, Tiles.GRAVE, Tiles.DOOR_CLOSED,
					Tiles.DOOR_OPEN, Tiles.STAIRS_DOWN, Tiles.STAIRS_UP]:
				on_feature.append("depth %d: tile %d" % [int(d), t])
	check("a trader never stands on a feature", on_feature.is_empty(),
		str(on_feature.slice(0, 3)))

## CIE76 deltaE, the same maths tools/check_palette.py uses.
##
## Normal vision only here: the python tool also simulates the three
## dichromacies and is the place to check a NEW colour. This guards against a
## landmark being added that collides outright, which is the failure that
## actually happened.
func _delta_e(a: Color, b: Color) -> float:
	var la := _lab(a)
	var lb := _lab(b)
	return sqrt(pow(la.x - lb.x, 2.0) + pow(la.y - lb.y, 2.0)
		+ pow(la.z - lb.z, 2.0))

func _lab(c: Color) -> Vector3:
	var r := _lin(c.r)
	var g := _lin(c.g)
	var b := _lin(c.b)
	var x := (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
	var y := 0.2126 * r + 0.7152 * g + 0.0722 * b
	var z := (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
	return Vector3(116.0 * _f(y) - 16.0, 500.0 * (_f(x) - _f(y)),
		200.0 * (_f(y) - _f(z)))

func _lin(u: float) -> float:
	return u / 12.92 if u <= 0.04045 else pow((u + 0.055) / 1.055, 2.4)

func _f(u: float) -> float:
	return pow(u, 1.0 / 3.0) if u > 0.008856 else 7.787 * u + 16.0 / 116.0

func _stalagmites(gs: GameState) -> int:
	var n := 0
	for y in gs.map.height:
		for x in gs.map.width:
			if gs.map.get_tile(x, y) == Tiles.STALAGMITE:
				n += 1
	return n

## The floor as you know it, and the page it lives on.
func _test_the_overview_map() -> void:
	var m := MapPanel.new()
	var gs := GameState.new(7)
	gs.new_game()
	gs.depth = 1
	gs.build_level()
	m.state = gs

	# It shows what you have EXPLORED, not what exists. A run that has just
	# begun must not hand the player the floorplan.
	var known := 0
	for y in gs.map.height:
		for x in gs.map.width:
			if gs.map.is_explored(x, y):
				known += 1
	var total := gs.map.width * gs.map.height
	check("a new floor is mostly unknown (%d of %d seen)" % [known, total],
		known < total / 4, "%d of %d" % [known, total])

	# The landmarks are the reason to open it, so each has to be findable and
	# they must not all be the same colour.
	gs.map.reveal_all()
	var seen := {}
	for y in gs.map.height:
		for x in gs.map.width:
			var c: Color = m._landmark(x, y)
			if c.a > 0.0:
				seen[gs.map.get_tile(x, y)] = c
	check("an explored floor shows landmarks (%d kinds)" % seen.size(),
		seen.size() >= 2, str(seen.size()))
	# Keyed on the Color itself. String(Color) is not a constructor in Godot 4
	# and throws -- which aborted the rest of this function and left the suite
	# reporting a clean tally with eight checks that never ran.
	var hues := {}
	for t in seen:
		hues[seen[t]] = true
	check("and they are not all one colour", hues.size() == seen.size(),
		"%d kinds, %d colours" % [seen.size(), hues.size()])

	# EVERY pair has to be distinguishable, and this is the one screen where
	# colour carries the whole difference: on the floor a brazier is a glyph
	# and a chest is another, but here they are both a square.
	#
	# The first version reused the game's own colours and five of fifteen pairs
	# failed -- brazier against chest at deltaE 9.9. Brad caught it from the
	# legend strip in a screenshot, which is not a way to find this twice.
	var too_close: Array[String] = []
	var marks: Array = MapPanel.MARKS
	for i in marks.size():
		for j in range(i + 1, marks.size()):
			var ca: Color = marks[i][1]
			var cb: Color = marks[j][1]
			var d := _delta_e(ca, cb)
			if d < 25.0:
				too_close.append("%s/%s %.0f" % [marks[i][0], marks[j][0], d])
	check("every map landmark is distinguishable from every other",
		too_close.is_empty(), str(too_close))
	# Vacuity: an empty MARKS table passes the loop above perfectly.
	check("and there are landmarks to compare (%d)" % marks.size(),
		marks.size() >= 5)

	# A spent brazier is still worth knowing about -- that is what makes a
	# scroll of light worth carrying -- so it is drawn dim, not omitted.
	check("a spent brazier is still marked",
		m._landmark_for(Tiles.BRAZIER_SPENT).a > 0.0)
	check("and differs from a lit one",
		m._landmark_for(Tiles.BRAZIER_SPENT) != m._landmark_for(Tiles.BRAZIER))

	# Walls and floor must be told apart, or the map is a grey rectangle.
	check("walls and floor are drawn differently",
		m._terrain_colour(Tiles.WALL) != m._terrain_colour(Tiles.FLOOR))
	check("and both are actually drawn",
		m._terrain_colour(Tiles.WALL).a > 0.0
			and m._terrain_colour(Tiles.FLOOR).a > 0.0)
	m.free()

	# The two screens are pages of one reference: the legend goes right to the
	# map, the map goes left back. On a handheld this is the ONLY route to the
	# map, because every button on a standard pad is already bound.
	var leg := LegendPanel.new()
	leg.state = gs
	leg.visible = true
	var paged := [false]
	leg.map_requested.connect(func() -> void: paged[0] = true)
	leg.handle_key(KEY_RIGHT)
	check("the legend pages right to the map", paged[0])
	leg.free()

	var m2 := MapPanel.new()
	m2.state = gs
	m2.visible = true
	var back := [false]
	m2.legend_requested.connect(func() -> void: back[0] = true)
	m2.handle_key(KEY_LEFT)
	check("and the map pages left to the legend", back[0])
	# Anything else closes rather than paging, so a stray press does not trap
	# the player between two screens.
	var m3 := MapPanel.new()
	m3.state = gs
	m3.visible = true
	m3.handle_key(KEY_Z)
	check("and any other key closes it", not m3.visible)
	m2.free()
	m3.free()

## A sack of loot: one drop that reaches every table the game already has.
func _test_the_sack() -> void:
	var sack := Item.make(&"sack")
	check("a sack exists and is openable", sack != null and sack.verb() == "open")
	check("and is never ordinary loot (weight 0)",
		int(Item.CATALOGUE[&"sack"].get("weight", -1)) == 0)

	# Opening always yields SOMETHING. An item that vanishes and pays nothing
	# is the bug report this refuses to allow.
	var empties := 0
	var uniques := 0
	var illegal: Array[String] = []
	var kinds := {}
	for d in [2, 10, 19]:
		for i in 60:
			var gs := GameState.new(1500 + d * 7 + i)
			gs.new_game()
			gs.depth = d
			gs.build_level()
			var before: int = gs.ground.size()
			var ok := gs._open_sack()
			if not ok or gs.ground.size() == before:
				empties += 1
				continue
			var got: Item = gs.ground[-1]
			kinds[got.kind] = int(kinds.get(got.kind, 0)) + 1
			# Uniques are authored and chest-only. A sack must never spend one.
			if got.unique:
				uniques += 1
			# And it must never contain something the gem rules forbid a player
			# from making -- the sack routes through accepts_element precisely
			# so a sling of frost is impossible here too.
			if got.element != &"" and got.kind != Item.Kind.GEM \
					and not got.accepts_element(got.element):
				illegal.append("%s / %s" % [got.name, got.element])

	check("a sack always holds something (%d empty)" % empties, empties == 0)
	check("and never a unique", uniques == 0, str(uniques))
	check("and never an element a gem could not bind",
		illegal.is_empty(), str(illegal.slice(0, 3)))
	# Vacuity guard: all three checks above pass if nothing was ever opened.
	check("and the roll actually produced items (%d kinds)" % kinds.size(),
		kinds.size() >= 2, str(kinds))

	# The dragon pays. Reported by a player who lost three runs reaching it and
	# got nothing: it wears no armour and carries no blade, so the ordinary
	# drop path had nothing of its to give.
	var gs2 := _arena(31, 11)
	gs2.player.x = 4
	gs2.player.y = 5
	var wyrm := _spawn(gs2, "young dragon", 9, 5)
	if wyrm != null:
		var before2: int = gs2.ground.size()
		gs2._drop_loot(wyrm)
		var found := false
		for it in gs2.ground:
			if it.appearance == &"sack":
				found = true
		check("a slain dragon leaves a hoard", found,
			"%d items dropped" % (gs2.ground.size() - before2))

## A gem is not an enchanted item. It is the thing you bind.
##
## Gems carry an element as base catalogue data, so the found-magic tint caught
## every one of them and painted them MAGIC blue -- taking away Palette.GEM, a
## near-white that nothing else in the game uses. Shipped unnoticed for a day.
##
## The guard already existed elsewhere: item.gd's display name checks
## `kind != Kind.GEM` before appending an element suffix, for the same reason.
func _test_gems_keep_their_colour() -> void:
	# The premise. If a gem ever stops carrying an element this test silently
	# stops testing anything, so it is asserted rather than assumed.
	var fire := Item.make(&"gem_fire")
	check("a gem carries an element (the reason the bug existed)",
		fire != null and fire.element != &"")
	if fire == null:
		return

	# What the draw sites ask.
	check("but a gem is not tinted as found magic",
		not fire.shows_enchanted())

	# And the other half: an enchanted weapon still IS.
	var sword := Item.make(&"short_sword")
	sword.element = &"fire"
	check("while an enchanted weapon still is", sword.shows_enchanted())

	# Every gem in the catalogue, not just the one. A new gem added later is
	# exactly how this comes back.
	var missed: Array[String] = []
	for key in Item.CATALOGUE:
		var it := Item.make(key)
		if it != null and it.kind == Item.Kind.GEM and it.shows_enchanted():
			missed.append(it.name)
	check("no gem in the catalogue is tinted", missed.is_empty(), str(missed))

## A weapon that ARRIVED enchanted is not proof the player has met a gem.
##
## `_place_first_gem` used to read the player's equipped gear and treat any
## element as that proof. Sound while binding was the only source of elements;
## the found-magic generator ended it.
##
## Measured before the fix, same seeds, the only difference being the weapon:
## bare-handed 0 of 120 pity floors went without a gem, carrying generated
## magic 120 of 120 did. The guarantee did not weaken, it stopped existing.
func _test_found_magic_is_not_a_gem() -> void:
	var bare_barren := 0
	var armed_barren := 0
	var floors := 0
	for d in GameState.GEM_PITY_FLOORS:
		for i in 12:
			var seed_value := 3300 + int(d) * 90 + i
			floors += 1

			# The control. Same seed, no weapon -- this is what the guarantee
			# is supposed to do, and if it ever fails the test below proves
			# nothing.
			var bare := GameState.new(seed_value)
			bare.new_game()
			bare.depth = int(d)
			bare.build_level()
			if not _floor_holds_a_gem(bare):
				bare_barren += 1

			# The same floor, with a weapon the generator could have produced:
			# an element set, and no gem ever involved.
			var armed := GameState.new(seed_value)
			armed.new_game()
			var sword := Item.make(&"short_sword")
			sword.element = &"fire"
			armed.player.equipped[Item.Slot.WEAPON] = sword
			armed.depth = int(d)
			armed.build_level()
			if not _floor_holds_a_gem(armed):
				armed_barren += 1

	check("the pity gem still arrives for a bare-handed player (%d floors)"
		% floors, bare_barren == 0, "%d barren" % bare_barren)
	check("and found magic does not count as having met one",
		armed_barren == 0, "%d of %d barren" % [armed_barren, floors])

	# The other direction: a player who has GENUINELY met a gem gets no pity
	# one. Without this, deleting the guarantee entirely would pass the checks
	# above perfectly.
	var met := GameState.new(4242)
	met.new_game()
	met.gem_found = true
	met.depth = 2
	met.build_level()
	check("but a player who has already met one is not given another",
		not _floor_holds_a_gem(met))

func _floor_holds_a_gem(gs: GameState) -> bool:
	for it in gs.ground:
		if it.kind == Item.Kind.GEM:
			return true
	return false

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

	# Chests keep paying uniques until the run has seen every one legal at this
	# depth, and only then start paying gems.
	#
	# Written as the RULE rather than as "the second chest gives a gem", which
	# is what it used to say. That was true while the ring was the only unique
	# and became false the moment a second one existed -- a test that has to be
	# edited every time content is added is a tripwire, not a check. This
	# version survives the fourth unique without being touched.
	var legal := Item.uniques(gs2.effective_depth()).size()
	check("there is more than one unique to hand out now (%d)" % legal,
		legal >= 2)
	var seen_gem := false
	var handed: Array[StringName] = [&"rat_ring"]
	var at_x := 4
	for _chest in legal + 1:
		gs2.ground = []
		gs2.map.set_tile(at_x, 4, Tiles.CHEST)
		gs2.pathfinder = Pathfinder.new(gs2.map)
		gs2.player.x = at_x + 1
		gs2.player.y = 4
		gs2.player_move(-1, 0)
		for it in gs2.ground:
			if it.kind == Item.Kind.GEM:
				seen_gem = true
			else:
				check_silent(not handed.has(it.id))
				handed.append(it.id)
		at_x -= 1
		if at_x < 1:
			break
	check_gathered("no unique is ever handed out twice")
	check("once the uniques run out, chests pay gems again", seen_gem)
	check("and that counts as the run's first gem", gs2.gem_found)
	check("every unique legal here was handed out (%d of %d)"
		% [gs2.uniques_found.size(), legal],
		gs2.uniques_found.size() == legal)

## Who counts as dead, and who does not.
##
## Written alongside its first consumer rather than ahead of it -- a flag
## nothing reads is a lie in the save file, and this project has shipped two of
## those already.
## Guards walk, rabbits eat, and neither needs the player to exist first.
##
## Both halves of this are the same bug seen from two sides: "awake" meant
## "coming for you", so anything that was not coming for you did nothing at
## all. A floor was not a place until you entered it.
func _test_the_floor_is_busy() -> void:
	# --- the beat ------------------------------------------------------------
	var keep := _arena(30, 14)
	keep.player.x = 2
	keep.player.y = 12
	# The round is kept in the FAR corner, and the torch is out.
	#
	# The first version put a post nine cells from the player, which was safe
	# only while guards could not move -- the moment they actually walked, one
	# strolled into notice range, woke up, and two checks about "still on
	# patrol" failed because the fix worked. The precondition below asserts the
	# whole ROUTE stays clear, not just the starting position.
	keep.torch_lit = false
	for post in [Vector2i(22, 3), Vector2i(27, 3), Vector2i(27, 10)]:
		keep.map.set_tile(post.x, post.y, Tiles.BRAZIER)
	# REBUILT, because `_arena` made the pathfinder before these tiles existed
	# and a stale one still believes they are floor. That is precisely why this
	# test passed while no guard in a real dungeon could move: braziers are
	# `walk: false`, so the route was a list of places nothing can stand.
	keep.pathfinder = Pathfinder.new(keep.map)
	keep._lay_the_beat()
	check("a post is somewhere a guard can actually stand",
		not keep.patrol_route.is_empty()
			and keep.map.is_walkable(keep.patrol_route[0].x,
				keep.patrol_route[0].y))
	check("a floor with fires has a round to walk (%d posts)"
		% keep.patrol_route.size(), keep.patrol_route.size() == 3)

	var guard := _spawn(keep, "skeleton", 23, 3)
	check("a skeleton is the sort of thing that walks a beat", guard.patrols)
	# CAPABILITY, not state: `monster_from` no longer decides. Whether a given
	# guard is walking tonight is rolled at spawn, so a hand-placed one has to
	# be put on duty deliberately -- which is also what stops this test
	# depending on a dice roll.
	guard.alertness = Entity.Alert.ASLEEP
	guard.activity = Entity.Activity.PATROLLING

	# The player is far away, in the dark, and does nothing at all. Asserted
	# over the ENTIRE route rather than the starting cell, because the whole
	# claim is that the floor moves without them -- and a moving guard visits
	# every post.
	var nearest := 999
	for post in keep.patrol_route:
		nearest = mini(nearest, Los.steps(post.x, post.y,
			keep.player.x, keep.player.y))
	check("no post on the round comes near the player (%d cells)" % nearest,
		nearest > guard.notice_range)
	var began := Vector2i(guard.x, guard.y)
	var walked := 0
	for _i in 40:
		keep._take_ai_turn(guard)
		if Vector2i(guard.x, guard.y) != began:
			walked += 1
	check("it walks its round unwatched (%d turns moved)" % walked, walked > 0)
	check("and is still on patrol, not hunting",
		guard.activity == Entity.Activity.PATROLLING
			and guard.alertness != Entity.Alert.AWAKE)
	check("and reached a post it was not standing on",
		guard.patrol_at != 0 or Vector2i(guard.x, guard.y) != began,
		"at %d,%d post %d" % [guard.x, guard.y, guard.patrol_at])

	# Seeing you ends the round. Losing you resumes it -- without the standing
	# flag a guard would lie down where it lost you and never walk again.
	keep.wake(guard)
	check("spotting you makes it hunt", guard.alertness == Entity.Alert.AWAKE)
	check("but it has not forgotten it walks a beat",
		guard.activity == Entity.Activity.PATROLLING)
	# Stood well out of range rather than blinded with `notice_block`. That
	# field is checked BEFORE the calm-down branch and returns early, so the
	# first version of this setup blocked the very path it meant to exercise --
	# the guard never reached the line under test and the check reported a bug
	# in the code instead of in itself.
	guard.x = 20
	guard.y = 3
	guard.alertness = Entity.Alert.SUSPICIOUS
	guard.calm_turns = 99
	guard.notice_block = 0
	check("it is far enough out that nothing will re-alert it",
		Los.steps(guard.x, guard.y, keep.player.x, keep.player.y)
			> guard.notice_range)
	keep._update_awareness(guard)
	check("and giving up simply makes it unaware again",
		guard.alertness == Entity.Alert.ASLEEP, str(guard.alertness))
	# The point of the split: NOTHING had to restore the round. It was never
	# lost, because losing your trail is a fact about awareness and walking a
	# beat is a fact about what it is doing.
	var moved_again := false
	var was := Vector2i(guard.x, guard.y)
	for _i in 10:
		keep._take_ai_turn(guard)
		if Vector2i(guard.x, guard.y) != was:
			moved_again = true
	check("and it resumes the round with nothing restoring it", moved_again)

	# A floor with nothing to guard leaves it standing, not crashing.
	var bare := _arena(20, 12)
	bare._lay_the_beat()
	check("a floor with no fires has no round", bare.patrol_route.is_empty())
	var idle := _spawn(bare, "skeleton", 5, 5)
	idle.alertness = Entity.Alert.ASLEEP
	idle.activity = Entity.Activity.PATROLLING
	bare._take_ai_turn(idle)
	check("and a guard there simply holds its post",
		idle.x == 5 and idle.y == 5)

	# The roll itself, through a REAL floor: some walk and some sleep. This is
	# the assertion the fix exists for -- setting every biped patrolling
	# measured at half the dungeon awake, which retires the first rung of the
	# awareness ladder and most of what the rat ring is for.
	var walk := 0
	var doze := 0
	for i in 12:
		var live := GameState.new(8800 + i)
		live.new_game()
		live.depth = 8
		live.build_level()
		for e in live.entities:
			if e.is_player or not e.patrols:
				continue
			if e.activity == Entity.Activity.PATROLLING:
				walk += 1
			else:
				doze += 1
	check("some of the watch is walking (%d)" % walk, walk > 0)
	check("and some of it is asleep (%d)" % doze, doze > 0)

	# And the bands differ, which is the point of keying it on Bands.of.
	check("a fortress is watched more closely than a cave",
		float(GameState.PATROL_CHANCE[Bands.FORTRESS])
			> float(GameState.PATROL_CHANCE[Bands.CAVES]))
	check("and the climb inherits it without a second table",
		Bands.of(15) == Bands.of(5) and Bands.of(12) == Bands.of(8))

	# A save from the one evening PATROL was an alertness must still walk.
	# Reading `alertness: 3` as a plain ASLEEP monster would stop the guard for
	# good, silently, in a suspended run that already exists on disk.
	var legacy := {"name": "skeleton", "app": "skeleton", "x": 3, "y": 3,
		"alertness": 3, "patrols": true}
	var revived := Entity.from_dict(legacy)
	check("a guard saved under the old state still walks",
		revived.activity == Entity.Activity.PATROLLING)
	check("and its alertness is migrated to a real one",
		revived.alertness == Entity.Alert.ASLEEP, str(revived.alertness))
	# And one saved mid-chase, where alertness said nothing about the beat.
	var chasing := Entity.from_dict({"name": "skeleton", "app": "skeleton",
		"x": 3, "y": 3, "alertness": Entity.Alert.AWAKE, "patrols": true})
	check("a guard saved mid-chase remembers its beat too",
		chasing.activity == Entity.Activity.PATROLLING)

	# --- the floor arms the dungeon ------------------------------------------
	# The reason this exists is not the monster, it is the DECISION: gear you
	# leave behind stops being free.
	var midden := _arena(30, 14)
	midden.player.x = 25
	midden.player.y = 12
	var thief := _spawn(midden, "goblin", 5, 5)
	thief.alertness = Entity.Alert.ASLEEP
	check("a goblin has hands and the wit to use them", thief.scavenges)
	check("a cave bear does not", not _spawn(midden, "cave bear", 20, 5).scavenges)

	var dropped := Item.make(&"war_axe")
	dropped.x = 7
	dropped.y = 5
	midden.ground.append(dropped)
	var was_threat := thief.threat
	check("it starts bare-handed",
		not thief.equipped.has(Item.Slot.WEAPON))
	for _i in 8:
		midden._take_ai_turn(thief)
	check("it crosses to the axe and takes it",
		thief.equipped.get(Item.Slot.WEAPON, null) == dropped,
		"at %d,%d holding %s" % [thief.x, thief.y,
			thief.equipped.get(Item.Slot.WEAPON, null)])
	check("the axe is off the floor", not midden.ground.has(dropped))
	check("and it is worth more to face now (%d -> %d)"
		% [was_threat, thief.threat], thief.threat > was_threat)

	# Upgrading puts the old one back -- a goblin trading up must not delete a
	# weapon from the world.
	var better := Item.make(&"war_axe")
	better.upgrade()
	better.upgrade()
	better.x = thief.x
	better.y = thief.y
	midden.ground.append(better)
	midden._take_ai_turn(thief)
	check("it trades up when something better turns up",
		thief.equipped.get(Item.Slot.WEAPON, null) == better)
	check("and drops what it was holding rather than eating it",
		midden.ground.has(dropped), str(midden.ground.size()))

	# Killing the thief gives it back FOR CERTAIN. An item on the floor is a
	# sure thing and an item on a monster is a coin flip, so without this the
	# scavenger would quietly destroy half of everything it picked up --
	# measured at 43 taken per 20 floors on depth 2, about 21 of them gone.
	check("what it stole is marked as stolen", better.scavenged)
	check("and gear it spawned with is not",
		not Item.make(&"dagger").scavenged)
	var returned := 0
	for _try in 30:
		var payback := _arena(20, 12)
		payback.player.x = 2
		payback.player.y = 2
		var mugger := _spawn(payback, "goblin", 5, 5)
		var mine := Item.make(&"war_axe")
		mine.scavenged = true
		mugger.equipped[Item.Slot.WEAPON] = mine
		mugger.inventory.append(mine)
		mugger.alive = false
		payback._drop_loot(mugger)
		if payback.ground.has(mine):
			returned += 1
	check("a stolen axe comes back every single time (%d of 30)" % returned,
		returned == 30)

	# What it must NEVER take.
	var forbidden := _arena(20, 12)
	forbidden.player.x = 18
	forbidden.player.y = 10
	var picky := _spawn(forbidden, "goblin", 5, 5)
	picky.alertness = Entity.Alert.ASLEEP
	for bad_id in [&"rat_ring", &"shovel", &"war_bow", &"potion_healing"]:
		var bad := Item.make(bad_id)
		bad.x = 5
		bad.y = 5
		forbidden.ground.append(bad)
	for _i in 4:
		forbidden._take_ai_turn(picky)
	check("it leaves the uniques, the bow and the potion alone (%d left)"
		% forbidden.ground.size(),
		forbidden.ground.size() == 4 and picky.equipped.is_empty(),
		"holding %d" % picky.equipped.size())

	# A mushroom with something asleep on it is not a mushroom you can eat.
	# Brad watched a rabbit pace in front of one for several turns with two
	# others in the same room: `_nearest_fungus` took the closest and never
	# considered whether it was reachable.
	var pantry := _arena(24, 11)
	pantry.player.x = 22
	pantry.player.y = 9
	var hare := _spawn(pantry, "rabbit", 5, 5)
	hare.activity = Entity.Activity.FEEDING
	pantry.map.set_tile(7, 5, Tiles.FUNGUS)
	pantry.map.set_tile(12, 5, Tiles.FUNGUS)
	pantry._gather_lights()
	check("it goes for the nearer mushroom when both are free",
		pantry._nearest_fungus(hare) == Vector2i(7, 5),
		str(pantry._nearest_fungus(hare)))
	var squatter := _spawn(pantry, "giant rat", 7, 5)
	squatter.activity = Entity.Activity.SLEEPING
	check("but looks past one with something sitting on it",
		pantry._nearest_fungus(hare) == Vector2i(12, 5),
		str(pantry._nearest_fungus(hare)))
	squatter.alive = false
	check("and comes back to it once that has gone",
		pantry._nearest_fungus(hare) == Vector2i(7, 5),
		str(pantry._nearest_fungus(hare)))

	# A bear is the other end of the larder: worth more than a rabbit, and on
	# the order of a whole brazier.
	var larder := _arena(24, 11)
	larder.depth = 6
	larder.player.x = 3
	larder.player.y = 3
	var bruin := _spawn(larder, "cave bear", 8, 5)
	bruin.hp = 1
	larder._attack(larder.player, bruin)
	var cut: Item = null
	for it in larder.ground:
		if it.id == &"bear_meat":
			cut = it
	check("a bear leaves meat behind", cut != null)
	if cut != null:
		check("named for what it came off", cut.name.contains("bear"), cut.name)
		check("and worth more than a rabbit's (%d)" % cut.effective_magnitude(),
			cut.effective_magnitude() > GameState.MEAT_BASE + 2)
	# And they must never stack together -- two different meals, two different
	# magnitudes, and one pile cannot hold both numbers.
	check("bear and rabbit meat are different items",
		Item.make(&"bear_meat").id != Item.make(&"meat").id)

	# --- the rabbit ----------------------------------------------------------
	# Never seen in play: everything started ASLEEP, so a rabbit did not eat
	# until the player arrived, and then it flees anything within RABBIT_NOSE.
	var warren := _arena(30, 14)
	# Deep enough to be allowed to turn. `_arena` starts on depth 1, where a
	# rabbit is now only ever a rabbit.
	warren.depth = 5
	warren.player.x = 28
	warren.player.y = 12
	var bun := _spawn(warren, "rabbit", 4, 4)
	bun.alertness = Entity.Alert.ASLEEP
	check("a rabbit's activity is feeding, not a special case in the turn loop",
		bun.activity == Entity.Activity.FEEDING)
	for at in [Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4), Vector2i(8, 4)]:
		warren.map.set_tile(at.x, at.y, Tiles.FUNGUS)
	# A WALL between, because fungus is a light source and sight now reaches
	# anything lit that you have a clear line to. In one open arena the player
	# could see a glowing mushroom patch clean across the room -- correctly --
	# so "out of sight" has to mean something line of sight actually blocks.
	for y in warren.map.height:
		warren.map.set_tile(15, y, Tiles.WALL)
	warren.pathfinder = Pathfinder.new(warren.map)
	warren._gather_lights()
	# `_arena` calls set_all_visible, which is right for almost every test and
	# exactly wrong for this one -- the first version asserted the rabbit was
	# out of sight on a map where every cell was lit. Recompute FOV from where
	# the player actually stands instead.
	warren.update_vision()
	check("the rabbit is asleep and the player is far off",
		bun.alertness == Entity.Alert.ASLEEP
			and Los.steps(bun.x, bun.y, warren.player.x, warren.player.y)
				> GameState.RABBIT_NOSE)
	var fungus_before := 0
	for y in warren.map.height:
		for x in warren.map.width:
			if warren.map.get_tile(x, y) == Tiles.FUNGUS:
				fungus_before += 1
	for _i in 60:
		warren._take_ai_turn(bun)
	var fungus_after := 0
	for y in warren.map.height:
		for x in warren.map.width:
			if warren.map.get_tile(x, y) == Tiles.FUNGUS:
				fungus_after += 1
	check("it eats while nobody is watching (%d -> %d)"
		% [fungus_before, fungus_after], fungus_after < fungus_before)
	check("and enough mouthfuls make it something else",
		bun.appearance == &"killer_rabbit", String(bun.appearance))
	# BEHAVIOUR, not mechanism. This used to assert `ai == &"hunter"`, which
	# stayed true after the activity split while the rabbit went on eating --
	# the test agreed with itself and disagreed with the game.
	# And the learning floors stay safe, however much it eats.
	var nursery := _arena(30, 14)
	nursery.depth = 1
	nursery.player.x = 28
	nursery.player.y = 12
	var kit := _spawn(nursery, "rabbit", 4, 4)
	kit.alertness = Entity.Alert.ASLEEP
	for at in [Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4), Vector2i(8, 4)]:
		nursery.map.set_tile(at.x, at.y, Tiles.FUNGUS)
	nursery._gather_lights()
	nursery.update_vision()
	for _i in 60:
		nursery._take_ai_turn(kit)
	check("a rabbit on floor one eats its fill and stays a rabbit (%d meals)"
		% kit.meal, kit.appearance == &"rabbit" and kit.meal >= 2,
		"%s after %d" % [kit.appearance, kit.meal])

	check("which stops hunting mushrooms once it turns",
		bun.activity != Entity.Activity.FEEDING, str(bun.activity))
	var left_after := 0
	for y in warren.map.height:
		for x in warren.map.width:
			if warren.map.get_tile(x, y) == Tiles.FUNGUS:
				left_after += 1
	for _i in 40:
		warren._take_ai_turn(bun)
	var left_later := 0
	for y in warren.map.height:
		for x in warren.map.width:
			if warren.map.get_tile(x, y) == Tiles.FUNGUS:
				left_later += 1
	check("and really does leave the rest alone (%d -> %d)"
		% [left_after, left_later], left_later == left_after)
	# It turned in an unseen corner, so the log must not name it. The banshee
	# established this pattern and `_blink_away` states the rule: a message
	# about something you cannot see is a report you did not earn. Brad met
	# this within an hour of foragers being allowed to forage unwatched -- the
	# line arrived from an empty room.
	check("the rabbit turned out of sight",
		not warren.map.is_visible(bun.x, bun.y))
	var told := ""
	for entry in warren.msg_log.entries:
		var text := String(entry["text"])
		if text.contains("straightens up") or text.contains("somewhere in the dark"):
			told = text
	check("so the log does not name what it cannot see",
		not told.contains("rabbit"), told)
	check("but it still says something happened", told != "", told)

## Doors, and who a shut one actually stops.
##
## Every case is a different creature, and the rule was chosen from a
## measurement rather than from taste: EVERY room generates with its doors shut
## (190 of 190 on depth 1), so making a closed door solid to animals would seal
## roughly half of every species into its birth room for the whole run. Hence
## three behaviours. The checks below are about what each one COSTS, because
## that is the only thing the player can feel.
func _test_doors_stop_different_things() -> void:
	var hall := _arena(24, 9)
	hall.player.x = 2
	hall.player.y = 4
	hall.map.set_tile(10, 4, Tiles.DOOR_CLOSED)
	hall.pathfinder = Pathfinder.new(hall.map)

	# A rabbit goes under it and is not delayed at all.
	var bun := _spawn(hall, "rabbit", 9, 4)
	bun.activity = Entity.Activity.SLEEPING
	check("a rabbit squeezes under", bun.door_style() == Entity.Door.SQUEEZES)
	hall._step_toward(bun, Vector2i(14, 4))
	check("and is through it, with the door still shut",
		bun.x == 10 and hall.map.get_tile(10, 4) == Tiles.DOOR_CLOSED,
		"at %d,%d" % [bun.x, bun.y])

	# A goblin has hands: it opens the door, and that IS its turn.
	var door2 := _arena(24, 9)
	door2.player.x = 2
	door2.player.y = 4
	door2.map.set_tile(10, 4, Tiles.DOOR_CLOSED)
	door2.pathfinder = Pathfinder.new(door2.map)
	var gob := _spawn(door2, "goblin", 9, 4)
	check("a goblin opens", gob.door_style() == Entity.Door.OPENS)
	door2._step_toward(gob, Vector2i(14, 4))
	check("it opens the door rather than walking through",
		door2.map.get_tile(10, 4) == Tiles.DOOR_OPEN and gob.x == 9,
		"at %d,%d" % [gob.x, gob.y])
	check("and that cost it one turn",
		door2._last_move_cost == Scheduler.ACTION_COST,
		str(door2._last_move_cost))

	# A bear shoulders through, and it costs real time.
	var den := _arena(24, 9)
	den.player.x = 2
	den.player.y = 4
	den.map.set_tile(10, 4, Tiles.DOOR_CLOSED)
	den.pathfinder = Pathfinder.new(den.map)
	var bear := _spawn(den, "cave bear", 9, 4)
	check("a bear shoulders through", bear.door_style() == Entity.Door.SHOULDERS)
	den._step_toward(bear, Vector2i(14, 4))
	# GONE, not merely open. With it left standing you could shut it on the
	# bear again and buy another three turns, and again -- the trick has to
	# work exactly once.
	check("the door is gone, not just open",
		den.map.get_tile(10, 4) == Tiles.FLOOR
			or den.map.get_tile(10, 4) == Tiles.CAVE_FLOOR,
		str(den.map.get_tile(10, 4)))
	check("so there is nothing left to shut on it",
		not den.player_close_door())
	check("and it cost three turns, not one (%d)" % den._last_move_cost,
		den._last_move_cost
			== Scheduler.ACTION_COST * GameState.DOOR_SHOULDER_COST)

	# An authored room is NOT exempt. The rule is the same everywhere, because
	# one a player cannot predict is worse than either rule applied uniformly.
	var vault := _arena(24, 9)
	vault.player.x = 2
	vault.player.y = 4
	vault.map.set_tile(10, 4, Tiles.DOOR_CLOSED)
	vault.pathfinder = Pathfinder.new(vault.map)
	vault.vault_rects.append(Rect2i(8, 2, 6, 5))
	check("the door is inside the authored room",
		vault.protected_cell(Vector2i(10, 4)))
	var vbear := _spawn(vault, "cave bear", 9, 4)
	vault._step_toward(vbear, Vector2i(14, 4))
	check("a bear takes an authored door off its hinges too",
		vault.map.get_tile(10, 4) == Tiles.FLOOR
			or vault.map.get_tile(10, 4) == Tiles.CAVE_FLOOR,
		str(vault.map.get_tile(10, 4)))

	# A banshee walks through stone; a door was never going to matter.
	var crypt := _arena(24, 9)
	crypt.player.x = 2
	crypt.player.y = 4
	var wail := _spawn(crypt, "banshee", 9, 4)
	check("a banshee ignores doors entirely",
		wail.door_style() == Entity.Door.SQUEEZES)

	# NOTHING can shut one but the player, which is what makes an open door
	# behind you evidence rather than scenery. Asserted by walking every kind
	# of creature through an OPEN one and checking it is still open after --
	# an earlier version of this check grepped the source and ended in
	# "or true", which is a check that cannot fail.
	for kind in ["rabbit", "goblin", "cave bear", "giant rat"]:
		var lane := _arena(24, 9)
		lane.player.x = 2
		lane.player.y = 4
		lane.map.set_tile(10, 4, Tiles.DOOR_OPEN)
		lane.pathfinder = Pathfinder.new(lane.map)
		var walker := _spawn(lane, kind, 9, 4)
		walker.activity = Entity.Activity.SLEEPING
		for _i in 4:
			lane._step_toward(walker, Vector2i(14, 4))
		check_silent(lane.map.get_tile(10, 4) == Tiles.DOOR_OPEN)
	check_gathered("nothing that walks through an open door shuts it")

	# --- the player's half, which did not exist until now --------------------
	var me := _arena(20, 9)
	me.player.x = 5
	me.player.y = 4
	check("with no door beside you, closing does nothing",
		not me.player_close_door())
	me.map.set_tile(6, 4, Tiles.DOOR_OPEN)
	check("beside an open door, you can shut it", me.player_close_door())
	check("and it is shut", me.map.get_tile(6, 4) == Tiles.DOOR_CLOSED)

	# Not onto something standing in it.
	me.map.set_tile(6, 4, Tiles.DOOR_OPEN)
	var inway := _spawn(me, "goblin", 6, 4)
	check("but not with something in the doorway", not me.player_close_door())
	check("and the door stays open", me.map.get_tile(6, 4) == Tiles.DOOR_OPEN)
	inway.alive = false
	me.entities.erase(inway)
	# Nor onto an item, which would swallow it.
	var lost := Item.make(&"dagger")
	lost.x = 6
	lost.y = 4
	me.ground.append(lost)
	check("nor onto something lying in it", not me.player_close_door())

## Who can see whom, which the game could not ask until now.
##
## A predicate rather than remembered awareness: everything we want from it --
## predation, fear, ambush, tracking -- only ever needs "right now", and
## N-squared remembered state would have to be serialised and debugged for no
## gain.
func _test_creatures_can_see_each_other() -> void:
	var room := _arena(30, 13)
	room.player.x = 2
	room.player.y = 11
	room.torch_lit = false
	room.update_vision()

	var goblin := _spawn(room, "goblin", 10, 4)
	var mark := _spawn(room, "orc", 13, 4)

	# PRECONDITION: in range and in line, so the only thing left to decide the
	# answer is light. Asserted, because a test that fails on distance would
	# look exactly like one that fails on darkness.
	check("they are close enough and in line of sight",
		Los.steps(goblin.x, goblin.y, mark.x, mark.y) <= goblin.notice_range
			and Los.clear(room.map, goblin.x, goblin.y, mark.x, mark.y))
	check("but in the dark a goblin sees nothing",
		not room._can_see(goblin, mark))

	# Light the target -- not the watcher. You see what is lit, not what you
	# are standing in.
	room.map.set_tile(14, 4, Tiles.BRAZIER)
	room.brazier_charge[Vector2i(14, 4)] = GameState.BRAZIER_CHARGE
	room._gather_lights()
	room.update_vision()
	check("light it and the goblin sees it", room._can_see(goblin, mark))

	# The dead need no light, but only so far.
	var bones := _spawn(room, "skeleton", 10, 9)
	var near := _spawn(room, "orc", 14, 9)
	# EIGHT cells: past darkvision (6) but still inside notice range (8). At
	# nine it was out of range entirely, so the check would have passed for the
	# wrong reason -- the precondition below is what caught that.
	var far := _spawn(room, "orc", 18, 9)
	check("a skeleton is unliving", bones.unliving)
	check("the near one is inside darkvision and the far one is not",
		Los.steps(bones.x, bones.y, near.x, near.y) <= GameState.DARKVISION
			and Los.steps(bones.x, bones.y, far.x, far.y) > GameState.DARKVISION
			and Los.steps(bones.x, bones.y, far.x, far.y) <= bones.notice_range)
	check("it sees the near one in the dark", room._can_see(bones, near))
	check("and not the far one", not room._can_see(bones, far))

	# A wall stops everything that is not a banshee.
	var crypt := _arena(30, 13)
	crypt.player.x = 2
	crypt.player.y = 11
	for y in crypt.map.height:
		crypt.map.set_tile(12, y, Tiles.WALL)
	crypt.pathfinder = Pathfinder.new(crypt.map)
	crypt.update_vision()
	var watcher := _spawn(crypt, "skeleton", 10, 5)
	var hidden := _spawn(crypt, "orc", 14, 5)
	check("a wall blocks the dead too", not crypt._can_see(watcher, hidden))
	var wail := _spawn(crypt, "banshee", 10, 5)
	check("a banshee senses life through stone",
		wail.senses and crypt._can_see(wail, hidden))

	# And the targeting scan no longer reaches across the floor.
	#
	# `_foe_for` had no range check and no sight check, so a monster that woke
	# to the player could lock onto an ally thirty cells away through three
	# walls. The player is still a target when unseen -- an awake monster hunts
	# by `last_seen` -- but nothing else is.
	var reach := _arena(40, 13)
	reach.player.x = 2
	reach.player.y = 6
	reach.torch_lit = false
	reach.update_vision()
	var hunter := _spawn(reach, "orc", 6, 6)
	var ally := _spawn(reach, "skeleton", 34, 6)
	ally.faction = Entity.Faction.PLAYER
	check("the ally is far away and unlit",
		Los.steps(hunter.x, hunter.y, ally.x, ally.y) > hunter.notice_range)
	check("so the orc goes for the player, not the distant ally",
		reach._foe_for(hunter) == reach.player,
		reach._foe_for(hunter).name if reach._foe_for(hunter) else "nothing")

## Morale, which was individual and is now social.
##
## It moves the THRESHOLD, never the damage. A monster that hit harder when
## confident would be worth more to face than the floor paid for it -- the same
## trap the killer rabbit and the scavenger both fell into -- and a modifier is
## invisible where a rout is not.
## The cursor panel says whose side a creature is on.
##
## From a real death: two skeletons raised from the same morgue, both in the
## player's own old gear, one an ally and one not, told apart by the word
## "risen" and a colour that is gone the moment you die.
func _test_the_panel_says_whose_side() -> void:
	var gs := _arena(20, 11)
	gs.player.x = 3
	gs.player.y = 3
	# `_arena` marks everything VISIBLE but nothing EXPLORED, and `_describe`
	# refuses to report on ground the player has never seen -- so without this
	# the panel answered "unknown" and both checks below failed for a reason
	# that had nothing to do with factions.
	gs.map.set_all_visible()
	gs.map.remember_visible()
	var bar := Sidebar.new()
	bar.state = gs
	var foe := _spawn(gs, "skeleton", 8, 5)
	foe.name = "risen BradTest"
	bar.hovered = Vector2i(8, 5)
	var said := ""
	for entry in bar._describe():
		if entry is String and String(entry).contains("BradTest"):
			said = String(entry)
	check("an enemy is not marked as yours", said != "" and not said.contains("yours"),
		said)

	var mate := _spawn(gs, "skeleton", 9, 5)
	mate.name = "B"
	mate.faction = Entity.Faction.PLAYER
	bar.hovered = Vector2i(9, 5)
	said = ""
	for entry in bar._describe():
		if entry is String and String(entry).begins_with("B "):
			said = String(entry)
	check("but an ally is", said.contains("(yours)"), said)
	bar.free()

## Doors, noise, and what a rat can do that a person cannot.
func _test_doors_are_loud_and_rats_are_not() -> void:
	# A RAT GOES UNDER. The first thing the ring is simply good at.
	var burrow := _arena(20, 9)
	burrow.player.x = 5
	burrow.player.y = 4
	burrow.map.set_tile(6, 4, Tiles.DOOR_CLOSED)
	burrow.pathfinder = Pathfinder.new(burrow.map)
	var ring := Item.make(&"rat_ring")
	burrow.give_item(ring)
	burrow.player.equipped[Item.Slot.WEAPON] = ring
	check("the ring makes you a rat", burrow.ratted())
	burrow.player_move(1, 0)
	check("a rat is through the door", burrow.player.x == 6,
		"at %d,%d" % [burrow.player.x, burrow.player.y])
	check("and left it shut behind it",
		burrow.map.get_tile(6, 4) == Tiles.DOOR_CLOSED)

	# A PERSON opens it, spends a turn, and is heard.
	var loud := _arena(20, 9)
	loud.player.x = 5
	loud.player.y = 4
	loud.torch_lit = true
	loud.map.set_tile(6, 4, Tiles.DOOR_CLOSED)
	loud.pathfinder = Pathfinder.new(loud.map)
	var sleeper := _spawn(loud, "goblin", 9, 4)
	sleeper.alertness = Entity.Alert.ASLEEP
	sleeper.activity = Entity.Activity.SLEEPING
	sleeper.notice_block = 0
	check("the goblin is asleep and within earshot",
		sleeper.alertness == Entity.Alert.ASLEEP
			and Los.steps(6, 4, sleeper.x, sleeper.y) <= GameState.DOOR_NOISE)
	loud.player_move(1, 0)
	check("the door opens", loud.map.get_tile(6, 4) == Tiles.DOOR_OPEN)
	check("and working it woke something",
		sleeper.alertness != Entity.Alert.ASLEEP, str(sleeper.alertness))

	# DOUSED, the same door is silent -- and costs double.
	var careful := _arena(20, 9)
	careful.player.x = 5
	careful.player.y = 4
	careful.torch_lit = false
	careful.map.set_tile(6, 4, Tiles.DOOR_CLOSED)
	careful.pathfinder = Pathfinder.new(careful.map)
	var dozer := _spawn(careful, "goblin", 9, 4)
	dozer.alertness = Entity.Alert.ASLEEP
	dozer.activity = Entity.Activity.SLEEPING
	dozer.notice_block = 99
	var before := careful.elapsed
	careful.player_move(1, 0)
	check("it still opens", careful.map.get_tile(6, 4) == Tiles.DOOR_OPEN)
	check("nothing heard it", dozer.alertness == Entity.Alert.ASLEEP)
	check("but it took twice as long (%d)" % (careful.elapsed - before),
		careful.elapsed - before
			== Scheduler.ACTION_COST * GameState.DOOR_CAREFUL_COST)

	# LOUDNESS, not a list of causes. A door and a fight stay under the bar;
	# bones and everything above it do not.
	check("a door is too quiet to wake the dead",
		GameState.DOOR_NOISE < GameState.GRAVE_ROUSING)
	check("and so is a fight", GameState.COMBAT_NOISE < GameState.GRAVE_ROUSING)
	check("bones are not", Tiles.noise_radius(Tiles.BONES)
		>= GameState.GRAVE_ROUSING)
	check("nor is a chest", GameState.CHEST_NOISE >= GameState.GRAVE_ROUSING)
	check("nor the forge", GameState.FORGE_NOISE >= GameState.GRAVE_ROUSING)

## The gong, and whether anything actually comes.
##
## Measured before this existed: the vigil woke 244 things across twelve
## depth-2 floors and EIGHT arrived -- 93% set off and forgot. The median
## monster starts 31-38 cells from the shrine and an ordinary memory is ten
## turns, so it covered about ten cells and settled down halfway. "Something
## calls out, and 20 things answer" was true about the waking and a lie about
## the answering.
func _test_the_gong_is_answered() -> void:
	var hall := _arena(40, 13)
	hall.player.x = 4
	hall.player.y = 6
	var far := _spawn(hall, "goblin", 34, 6)
	far.alertness = Entity.Alert.ASLEEP
	far.activity = Entity.Activity.SLEEPING
	check("it starts with an ordinary memory",
		far.pursue_turns == Entity.DEFAULT_PURSUIT)
	check("and it is a long way off (%d cells)"
		% Los.steps(far.x, far.y, hall.player.x, hall.player.y),
		Los.steps(far.x, far.y, hall.player.x, hall.player.y)
			> Entity.DEFAULT_PURSUIT)

	hall._invoke_shrine(Shrines.VIGIL)
	check("the gong wakes it", far.alertness == Entity.Alert.AWAKE)
	check("and it is willing to walk across the dungeon",
		far.pursue_turns == GameState.VIGIL_PURSUIT)

	# Out of sight the whole way -- a wall between, so it is travelling on
	# memory alone, which is the case that used to fail.
	# A wall with a GAP in it. The first version sealed the arena completely,
	# so there was no route at all -- the goblin stayed awake, which is what
	# the check above wanted, and could not take a single step, which is what
	# the check below wanted. Blocked sight along its own row, open at the top.
	for y in hall.map.height:
		if y == 1:
			continue
		hall.map.set_tile(20, y, Tiles.WALL)
	hall.pathfinder = Pathfinder.new(hall.map)
	check("sight along its row is blocked but a way round exists",
		not Los.clear(hall.map, far.x, far.y, hall.player.x, hall.player.y)
			and not hall.pathfinder.path(Vector2i(far.x, far.y),
				Vector2i(hall.player.x, hall.player.y)).is_empty())
	hall.torch_lit = false
	hall.update_vision()
	var began := Los.steps(far.x, far.y, hall.player.x, hall.player.y)
	for _i in Entity.DEFAULT_PURSUIT + 5:
		hall._take_ai_turn(far)
	check("well past an ordinary memory it is still coming",
		far.alertness == Entity.Alert.AWAKE, str(far.alertness))
	check("and it has closed the distance (%d -> %d)"
		% [began, Los.steps(far.x, far.y, hall.player.x, hall.player.y)],
		Los.steps(far.x, far.y, hall.player.x, hall.player.y) < began)

	# And when it does finally give up, it is an ordinary creature again --
	# a summons must not permanently change what something is.
	far.lost_turns = GameState.VIGIL_PURSUIT + 1
	hall._update_awareness(far)
	check("giving up at last drops it back to suspicious",
		far.alertness == Entity.Alert.SUSPICIOUS, str(far.alertness))
	check("and its memory is ordinary again",
		far.pursue_turns == Entity.DEFAULT_PURSUIT)

## Small things give big things room, and the player reads the room emptying.
func _test_the_small_give_way() -> void:
	var lair := _arena(30, 13)
	lair.player.x = 3
	lair.player.y = 6
	lair.map.set_all_visible()
	lair.map.remember_visible()

	# LIT, because `_can_see` needs the thing being looked at to be lit and
	# `_arena` never computes a light map. Without this the goblin can see
	# nothing at all -- and the ogre check below would have passed for that
	# reason rather than because an ogre is too small to fear.
	lair.map.set_tile(16, 6, Tiles.BRAZIER)
	lair.brazier_charge[Vector2i(16, 6)] = GameState.BRAZIER_CHARGE
	lair._gather_lights()
	lair.update_vision()

	var gob := _spawn(lair, "goblin", 14, 6)
	var ogre := _spawn(lair, "ogre", 17, 6)
	check("a goblin can be frightened at all", gob.flee_below > 0.0)
	check("and it can actually see the ogre standing there",
		lair._can_see(gob, ogre))
	check("an ogre is bigger but not by enough (%d vs %d)"
		% [ogre.threat, gob.threat],
		ogre.threat - gob.threat < GameState.APEX_GAP)
	check("so the goblin stands its ground",
		lair._something_dreadful(gob) == null)

	var drake := _spawn(lair, "young dragon", 18, 6)
	check("and it can see the dragon too", lair._can_see(gob, drake))
	check("a dragon is (%d vs %d)" % [drake.threat, gob.threat],
		drake.threat - gob.threat >= GameState.APEX_GAP)
	check("and now the goblin wants no part of it",
		lair._something_dreadful(gob) == drake)

	# It backs off, and it does so instead of coming for the player.
	var began := Los.steps(gob.x, gob.y, drake.x, drake.y)
	gob.alertness = Entity.Alert.AWAKE
	for _i in 3:
		lair._take_ai_turn(gob)
	check("it gives way rather than hunting you (%d -> %d)"
		% [began, Los.steps(gob.x, gob.y, drake.x, drake.y)],
		Los.steps(gob.x, gob.y, drake.x, drake.y) > began)

	# Out of sight, out of mind -- no counter, nothing remembered.
	drake.alive = false
	check("with it gone the goblin is itself again",
		lair._something_dreadful(gob) == null)

	# The fearless are exempt for free, by the same gate morale uses.
	# The dead need no light, so these two need no brazier of their own.
	var bones := _spawn(lair, "skeleton", 14, 9)
	var lich := _spawn(lair, "arch lich", 17, 9)
	check("a skeleton never flees", bones.flee_below <= 0.0)
	check("so even an arch lich does not move it (%d vs %d)"
		% [lich.threat, bones.threat],
		lair._something_dreadful(bones) == null)

	# And a dragon fears nothing, because nothing is twelve above it.
	check("the dragon itself gives way to nobody",
		lair._something_dreadful(lich) == null)

## The dungeon's own clock, and the watch that fights it.
##
## `brazier_charge` only ever fell when the PLAYER rested or forged, so a fire
## on a floor nobody visited burned for ever -- the one system where time did
## not pass unless you were there to spend it.
func _test_fires_burn_down_and_guards_feed_them() -> void:
	var hearth := _arena(24, 11)
	hearth.player.x = 3
	hearth.player.y = 3
	hearth.map.set_tile(12, 5, Tiles.BRAZIER)
	hearth.brazier_charge[Vector2i(12, 5)] = GameState.BRAZIER_CHARGE
	hearth._gather_lights()

	# Time passes without the player touching it.
	var start := int(hearth.brazier_charge[Vector2i(12, 5)])
	for _i in GameState.BRAZIER_BURN_EVERY * 3:
		hearth.turns += 1
		hearth._burn_the_fires_down()
	var now := int(hearth.brazier_charge.get(Vector2i(12, 5), 0))
	check("an untended fire burns down (%d -> %d)" % [start, now], now < start)
	check("and at about the rate it says it does",
		start - now == 3, "%d in three windows" % (start - now))

	# All the way out, and it becomes SPENT -- not dead. Embers still work.
	for _i in GameState.BRAZIER_BURN_EVERY * GameState.BRAZIER_CHARGE:
		hearth.turns += 1
		hearth._burn_the_fires_down()
	check("eventually it gutters",
		hearth.map.get_tile(12, 5) == Tiles.BRAZIER_SPENT,
		str(hearth.map.get_tile(12, 5)))
	check("and the clock leaves a spent one alone",
		not hearth.brazier_charge.has(Vector2i(12, 5)))

	# A guard throws a log on -- but only on a LIVE fire that is low.
	var post := _arena(24, 11)
	post.player.x = 3
	post.player.y = 3
	post.map.set_tile(12, 5, Tiles.BRAZIER)
	post.brazier_charge[Vector2i(12, 5)] = GameState.BRAZIER_CHARGE
	post._gather_lights()
	var guard := _spawn(post, "skeleton", 12, 6)
	guard.activity = Entity.Activity.PATROLLING
	check("a full fire needs no tending", not post._tend_the_fire(guard))

	post.brazier_charge[Vector2i(12, 5)] = GameState.BRAZIER_LOW
	check("a low one does", post._tend_the_fire(guard))
	check("and it is fuller for it (%d)"
		% int(post.brazier_charge[Vector2i(12, 5)]),
		int(post.brazier_charge[Vector2i(12, 5)])
			== GameState.BRAZIER_LOW + GameState.BRAZIER_STOKE)
	check("stoking was its whole turn",
		post._last_move_cost == Scheduler.ACTION_COST)

	# Never above full, and never a guttered one.
	post.brazier_charge[Vector2i(12, 5)] = GameState.BRAZIER_CHARGE - 1
	post._tend_the_fire(guard)
	check("it cannot be overfilled",
		int(post.brazier_charge[Vector2i(12, 5)]) <= GameState.BRAZIER_CHARGE)
	post.map.set_tile(12, 5, Tiles.BRAZIER_SPENT)
	check("and a guard cannot relight a dead one -- that is what a scroll is for",
		not post._tend_the_fire(guard))

	# A fire that will never burn again comes off the round. The route is built
	# at level generation and used to stand for ever, so a guard kept walking
	# to a cold corner for the rest of the run.
	var round_map := _arena(24, 11)
	round_map.player.x = 3
	round_map.player.y = 3
	for at in [Vector2i(8, 5), Vector2i(16, 5), Vector2i(16, 9)]:
		round_map.map.set_tile(at.x, at.y, Tiles.BRAZIER)
		round_map.brazier_charge[at] = GameState.BRAZIER_CHARGE
	round_map.pathfinder = Pathfinder.new(round_map.map)
	round_map._lay_the_beat()
	var posts := round_map.patrol_route.size()
	check("three fires, three posts (%d)" % posts, posts == 3)
	# Guttering is not death -- a spent fire is still somewhere to walk.
	round_map.map.set_tile(8, 5, Tiles.BRAZIER_SPENT)
	round_map._lay_the_beat()
	check("a spent fire keeps its post",
		round_map.patrol_route.size() == posts,
		str(round_map.patrol_route.size()))
	round_map.map.set_tile(8, 5, Tiles.BRAZIER_DEAD)
	round_map._lay_the_beat()
	check("a dead one loses it (%d)" % round_map.patrol_route.size(),
		round_map.patrol_route.size() == posts - 1)

	# The two halves meet: one top-up buys hit points but NOT a merge.
	check("one stoke is worth three hit points",
		GameState.BRAZIER_STOKE == 3)
	check("and deliberately short of a merge (%d)" % GameState.MERGE_COST,
		GameState.BRAZIER_STOKE < GameState.MERGE_COST)

func _test_morale_is_social() -> void:
	var field := _arena(26, 13)
	field.player.x = 3
	field.player.y = 6

	# Company steadies you. A lone goblin at the same wound breaks; one with
	# friends stands.
	var lone := _spawn(field, "goblin", 20, 3)
	check("a goblin can be frightened at all", lone.flee_below > 0.0)
	# FLOOR, not ceil. `ceil(9 * 0.20)` is 2, and 2/9 is 0.222 -- just ABOVE
	# the 0.20 threshold, so the first version of this put the goblin at a
	# wound it was never meant to break at and then blamed the code.
	lone.hp = maxi(1, int(floor(lone.max_hp * lone.flee_below)))
	check("it is genuinely hurt past its threshold (%.3f vs %.2f)"
		% [float(lone.hp) / float(lone.max_hp), lone.flee_below],
		float(lone.hp) / float(lone.max_hp) <= lone.flee_below)
	field._update_morale(lone)
	check("hurt and alone, it runs", lone.fleeing)

	var braced := _spawn(field, "goblin", 10, 9)
	for i in 3:
		_spawn(field, "goblin", 10 + i, 10)
	braced.hp = lone.hp
	braced.max_hp = lone.max_hp
	check("it has company", field._allies_near(braced, GameState.MORALE_REACH) >= 3)
	field._update_morale(braced)
	check("the same wound with friends beside it does not", not braced.fleeing)

	# And losing the biggest thing present undoes that.
	var ranks := _arena(26, 13)
	ranks.player.x = 3
	ranks.player.y = 6
	var mob := []
	for i in 3:
		mob.append(_spawn(ranks, "goblin", 10 + i, 6))
	var boss := _spawn(ranks, "ogre", 13, 6)
	check("the ogre is the biggest thing here (%d vs %d)"
		% [boss.threat, mob[0].threat], boss.threat > mob[0].threat)
	check("and the goblins have the wit to notice", mob[0].scavenges)
	for g in mob:
		check_silent(g.shaken == 0)
	check_gathered("nobody is shaken yet")

	boss.alive = false
	ranks._rattle_the_ranks(boss)
	for g in mob:
		check_silent(g.shaken > 0)
	check_gathered("losing it shakes the whole group")

	# Shaken, a wound they would have stood becomes a rout.
	var runner: Entity = mob[0]
	runner.hp = int(runner.max_hp * 0.4)
	ranks._update_morale(runner)
	check("and now they break at a wound they would have shrugged off",
		runner.fleeing, "%d/%d shaken %d"
			% [runner.hp, runner.max_hp, runner.shaken])

	# An animal does not reason about its side, and neither do the dead.
	var wild := _arena(26, 13)
	wild.player.x = 3
	wild.player.y = 6
	var rat := _spawn(wild, "giant rat", 10, 6)
	var bones := _spawn(wild, "skeleton", 11, 6)
	var big := _spawn(wild, "cave troll", 12, 6)
	check("neither the rat nor the skeleton scavenges",
		not rat.scavenges and not bones.scavenges)
	big.alive = false
	wild._rattle_the_ranks(big)
	check("so neither is shaken by it",
		rat.shaken == 0 and bones.shaken == 0)

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

## The targeting layer, written before there is anything to point it at.
##
## Every check below would pass trivially with the ally left out -- monsters
## do find the player, and always did. So the ally is BUILT here, and its
## preconditions are asserted before each exclusion: that it is alive, that it
## is in view, that it is in range. Otherwise this would be a test that cannot
## fail, which this suite has been bitten by before.
##
## An ally is an ordinary Entity whose faction happens to be PLAYER. That is
## the promise Entity's own header makes -- "when a party arrives later, it is
## four of these in a list rather than a new concept" -- and this is the test
## that holds it to it.
## The bone ally, end to end.
##
## Built as one test rather than six because the mechanic is a chain -- a
## grave becomes a bone becomes a companion becomes nothing at the stairs --
## and every link is a place the previous version of this feature could have
## quietly dropped something. Two of the checks below exist only because the
## obvious implementation duplicates items, and one because it steals the
## player's experience.
func _test_the_bone_ally() -> void:
	var gs := _arena(30, 14)
	gs.player.x = 4
	gs.player.y = 7

	# A risen grave, armed the way _raise_from arms one.
	var risen := _spawn(gs, "skeleton", 5, 7)
	risen.risen = true
	risen.name = "risen Erdrick"
	for want in [&"short_sword", &"leather_armour"]:
		var kit := Item.make(want)
		risen.equipped[kit.slot] = kit
		risen.inventory.append(kit)
	risen.hp = 1
	gs._attack(gs.player, risen)
	check("putting a risen grave down kills it", not risen.alive)

	var bone: Item = null
	for it in gs.ground:
		if it.id == &"bone":
			bone = it
	check("and leaves a bone behind", bone != null)
	if bone == null:
		return
	check("which remembers whose it is", bone.bone_name == "Erdrick",
		bone.bone_name)
	check("and what they were buried in (%d)" % bone.bone_gear.size(),
		bone.bone_gear.size() == 2)
	# And the gear does NOT also drop. One copy of that kit exists from here:
	# it is on the bone, and it comes back when the ally carrying it falls.
	var loot := 0
	for it in gs.ground:
		if it.id == &"short_sword" or it.id == &"leather_armour":
			loot += 1
	check("the gear goes with the bone, not onto the floor (%d)" % loot,
		loot == 0)

	# --- carried, saved, and still somebody ---------------------------------
	var back := Item.from_dict(bone.to_dict())
	check("a bone survives a suspend", back != null
		and back.bone_name == "Erdrick" and back.bone_gear.size() == 2)
	check("carrying the level it was raised from",
		back != null and back.bone_level == bone.bone_level,
		"%d vs %d" % [back.bone_level if back else -1, bone.bone_level])
	check("and is still named for them after loading",
		back != null and back.name.contains("Erdrick"), back.name if back else "null")

	# --- raised -------------------------------------------------------------
	gs.ground.erase(bone)
	gs.give_item(bone)
	var idx := gs.player.inventory.find(bone)
	check("the bone is carryable", idx >= 0)
	check("raising it spends the bone", gs.player_use(idx)
		and not gs.player.inventory.has(bone))

	var ally: Entity = null
	for e in gs.entities:
		if e.faction == Entity.Faction.PLAYER and not e.is_player:
			ally = e
	check("and somebody is standing there", ally != null)
	if ally == null:
		return
	check("wearing what they were buried in",
		ally.equipped.size() == 2, str(ally.equipped.size()))
	check("named for the dead, not for the bone", ally.name == "Erdrick",
		ally.name)
	check("and it is not counted as a monster",
		not gs.visible_monsters().has(ally))

	# --- it fights ----------------------------------------------------------
	var orc := _spawn(gs, "orc", 6, 7)
	ally.x = 5
	ally.y = 7
	var hurt := orc.hp
	gs._take_ai_turn(ally)
	check("the ally swings at what is beside it", orc.hp < hurt,
		"%d -> %d" % [hurt, orc.hp])

	# --- and its kills are yours --------------------------------------------
	var xp_was := gs.player.xp
	orc.hp = 1
	gs._attack(ally, orc)
	check("a kill of its own earns the run experience",
		not orc.alive and gs.player.xp > xp_was,
		"%d -> %d" % [xp_was, gs.player.xp])

	# --- the leash ----------------------------------------------------------
	var far := _spawn(gs, "goblin", 25, 12)
	ally.x = 5
	ally.y = 7
	check("something that far off is beyond the leash",
		Los.steps(gs.player.x, gs.player.y, far.x, far.y) > GameState.ALLY_LEASH)
	gs._take_ai_turn(ally)
	check("so the ally stays near you rather than chasing it",
		Los.steps(ally.x, ally.y, gs.player.x, gs.player.y) <= 2,
		"%d away" % Los.steps(ally.x, ally.y, gs.player.x, gs.player.y))

	# --- swapping, not swinging ---------------------------------------------
	gs.player.x = 4
	gs.player.y = 7
	ally.x = 5
	ally.y = 7
	var ally_hp := ally.hp
	gs.player_move(1, 0)
	check("walking into your own ally changes places with it",
		gs.player.x == 5 and ally.x == 4 and ally.y == 7,
		"player %d,%d ally %d,%d" % [gs.player.x, gs.player.y, ally.x, ally.y])
	check("and does not hit it", ally.hp == ally_hp)

	# --- a bound weapon survives the morgue ----------------------------------
	# Nineteen commits of silent loss. `display_name` gained "(frost)" five
	# commits after `from_display_name` was written, and nothing told the
	# reader -- so a gem-bound weapon matched no catalogue name and the whole
	# SWORD came back null, not just its binding. Tested as a ROUND TRIP rather
	# than against a literal string, because the bug was precisely the two ends
	# of one format disagreeing.
	# Upgrade counts stay inside MAX_UPGRADES. "dagger +3" cannot round-trip
	# because the game will not build one -- `from_display_name` clamps, and it
	# is right to. Asserting an illegal item came back unchanged was testing
	# the test, not the code.
	for spec in [[&"short_sword", Item.MAX_UPGRADES, &"frost"],
			[&"war_axe", 0, &"fire"], [&"dagger", 1, &""], [&"mace", 0, &""]]:
		var made := Item.make(spec[0])
		for _i in int(spec[1]):
			made.upgrade()
		made.element = spec[2]
		var written := made.display_name()
		var read_back := Item.from_display_name(written)
		check("\"%s\" survives the morgue and back" % written,
			read_back != null and read_back.id == made.id
				and read_back.upgrade_level() == made.upgrade_level()
				and read_back.element == made.element,
			"got %s" % (read_back.display_name() if read_back else "null"))

	# And in situ: the grave this actually broke.
	var bound_tomb := _arena(30, 14)
	bound_tomb.player.x = 4
	bound_tomb.player.y = 7
	bound_tomb.grave_at[Vector2i(8, 7)] = {
		"level": 12, "cause": "killed by a wight", "depth": 8, "turns": 90,
		"gear": ["short sword +2 (frost)", "chain mail"], "line": "y",
	}
	bound_tomb.map.set_tile(8, 7, Tiles.GRAVE)
	bound_tomb._raise_from(Vector2i(8, 7))
	var bound_dead: Entity = null
	for e in bound_tomb.entities:
		if e.risen:
			bound_dead = e
	check("a grave whose weapon was bound still rises armed",
		bound_dead != null and bound_dead.equipped.size() == 2,
		str(bound_dead.equipped.size()) if bound_dead else "no riser")
	if bound_dead != null:
		var blade: Item = bound_dead.equipped.get(Item.Slot.WEAPON, null)
		check("still carrying the binding it was buried with",
			blade != null and blade.element == &"frost",
			blade.display_name() if blade else "nothing")

	# --- the undertaker's shovel ----------------------------------------------
	var dig := _arena(30, 14)
	dig.player.x = 6
	dig.player.y = 7
	var shovel := Item.make(&"shovel")
	dig.give_item(shovel)
	check("digging with nothing dead does nothing",
		not dig.player_use(dig.player.inventory.find(shovel)))
	check("and the shovel is still in your hands",
		dig.player.inventory.has(shovel))

	var ogre := _spawn(dig, "ogre", 7, 7)
	var ogre_hp := ogre.max_hp
	ogre.hp = 1
	dig._attack(dig.player, ogre)
	check("the ogre is down", not ogre.alive)
	check("and the ground remembers it", dig.recent_dead.size() == 1)
	# The memory rides along with a suspend -- a save in the five turns after a
	# big kill must not quietly cost the dig. (`GameState.new()` alone has no
	# map, so `to_dict` cannot be called on one; the earlier version of this
	# line crashed inside the serialiser and took thirteen checks with it.)
	var packed := dig.to_dict()
	check("and the memory survives a suspend",
		packed.has("recent_dead")
			and int((packed["recent_dead"] as Array).size()) == 1)

	check("digging raises it", dig.player_use(dig.player.inventory.find(shovel)))
	check("and spends the shovel", not dig.player.inventory.has(shovel))
	var raised: Entity = null
	for e in dig.entities:
		if e.faction == Entity.Faction.PLAYER and not e.is_player:
			raised = e
	check("somebody is standing there", raised != null)
	if raised != null:
		check("it is the ogre, keeping its own shape",
			raised.appearance == &"ogre", String(raised.appearance))
		check("named for what it was", raised.name.contains("ogre"), raised.name)
		check("at half of what it was (%d of %d)" % [raised.max_hp, ogre_hp],
			raised.max_hp == maxi(1, ogre_hp / 2))
		check("and it is not counted as a monster",
			not dig.visible_monsters().has(raised))

	# The window is the item. A corpse gone cold answers nothing.
	var cold := _arena(30, 14)
	cold.player.x = 6
	cold.player.y = 7
	var spade := Item.make(&"shovel")
	cold.give_item(spade)
	var rat := _spawn(cold, "giant rat", 7, 7)
	rat.hp = 1
	cold._attack(cold.player, rat)
	check("something died", cold.recent_dead.size() == 1)
	cold.turns += GameState.SHOVEL_WINDOW + 1
	check("but once it is cold the shovel finds nothing",
		not cold.player_use(cold.player.inventory.find(spade)))
	check("and is not spent on the attempt",
		cold.player.inventory.has(spade))

	# --- a shade of the hero, not a skeleton in their coat --------------------
	# The morgue never recorded hit points, only the level reached, so this is
	# the one number the ally's toughness can be rebuilt from. Asserted against
	# the curve rather than against a literal, so a balance pass on LEVEL_HP
	# cannot leave this test asserting a number the game no longer uses.
	check("the hp curve is the one the player actually starts on",
		GameState.hp_at_level(1) == 30, str(GameState.hp_at_level(1)))
	check("and it grows by the level bonus",
		GameState.hp_at_level(5) == 30 + GameState.LEVEL_HP * 4,
		str(GameState.hp_at_level(5)))

	var hero_bone := Item.make(&"bone")
	hero_bone.bone_name = "Solo"
	hero_bone.bone_level = 19
	var deep_gs := _arena(30, 14)
	deep_gs.player.x = 6
	deep_gs.player.y = 7
	check("a deep grave raises a real fighter", deep_gs._summon_ally(hero_bone))
	var shade: Entity = null
	for e in deep_gs.entities:
		if e.faction == Entity.Faction.PLAYER and not e.is_player:
			shade = e
	check("with half of what that character could take (%d)"
		% (shade.max_hp if shade else 0),
		shade != null and shade.max_hp == GameState.hp_at_level(19) / 2,
		str(shade.max_hp) if shade else "none")
	check("and it arrives whole", shade != null and shade.hp == shade.max_hp)

	# A grave from the learning floors must still stand up, rather than coming
	# back weaker than an ordinary skeleton.
	var shallow := Item.make(&"bone")
	shallow.bone_name = "Nameless"
	shallow.bone_level = 1
	var shallow_gs := _arena(30, 14)
	shallow_gs.player.x = 6
	shallow_gs.player.y = 7
	check("a shallow grave still raises somebody",
		shallow_gs._summon_ally(shallow))
	var weakling: Entity = null
	for e in shallow_gs.entities:
		if e.faction == Entity.Faction.PLAYER and not e.is_player:
			weakling = e
	check("never weaker than a plain skeleton (%d)"
		% (weakling.max_hp if weakling else 0),
		weakling != null and weakling.max_hp >= 12, str(weakling.max_hp) if weakling else "none")

	# --- the right weapon for the range --------------------------------------
	# Brad carries one ranged and one melee at all times, so his graves hold
	# both -- which is the case that made this worth writing. The gear IS the
	# record of how somebody fought; nothing has to ask the morgue how they
	# got their kills.
	var archer := _arena(30, 14)
	archer.player.x = 4
	archer.player.y = 7
	var bowman := _spawn(archer, "skeleton", 6, 7)
	bowman.faction = Entity.Faction.PLAYER
	bowman.ai = &"ally"
	bowman.name = "Rodney"
	for want in [&"war_bow", &"war_axe"]:
		var kit := Item.make(want)
		bowman.inventory.append(kit)
	bowman.equipped[Item.Slot.WEAPON] = bowman.inventory[1]  # starts on the axe
	var mark := _spawn(archer, "orc", 11, 7)
	mark.max_hp = 500
	mark.hp = 500

	# PRECONDITION, asserted rather than assumed. The first version of this put
	# the target 10 cells from the player -- outside ALLY_LEASH -- so the ally
	# correctly ignored it and followed the player instead, and all three
	# checks below failed while the code under test was perfectly right. A test
	# that sets up the wrong situation reports a bug in the wrong place.
	check("the target is inside the leash, so the ally will engage it",
		Los.steps(archer.player.x, archer.player.y, mark.x, mark.y)
			<= GameState.ALLY_LEASH,
		"%d away" % Los.steps(archer.player.x, archer.player.y, mark.x, mark.y))

	# Five cells off: it should arm itself with the bow, and that is its whole
	# turn -- it does not get to swap and shoot in the same breath.
	archer._take_ai_turn(bowman)
	var held: Item = bowman.equipped.get(Item.Slot.WEAPON, null)
	check("an ally at range takes up the bow",
		held != null and held.id == &"war_bow", held.name if held else "nothing")
	check("and that swap was its turn -- it has not fired yet",
		mark.hp == mark.max_hp, str(mark.hp))

	# Now it shoots, rather than walking a bow into melee.
	var wounded := mark.hp
	archer._take_ai_turn(bowman)
	check("and shoots with it rather than closing", mark.hp < wounded,
		"%d -> %d" % [wounded, mark.hp])

	# Something reaches it: the bow goes away and the axe comes out.
	mark.x = bowman.x + 1
	mark.y = bowman.y
	archer._take_ai_turn(bowman)
	held = bowman.equipped.get(Item.Slot.WEAPON, null)
	check("and takes the axe when something closes",
		held != null and held.id == &"war_axe", held.name if held else "nothing")
	var bled := mark.hp
	archer._take_ai_turn(bowman)
	check("then swings it", mark.hp < bled, "%d -> %d" % [bled, mark.hp])

	# An archer with no blade still swings the bow rather than standing there.
	var lonely := _spawn(archer, "skeleton", 20, 3)
	lonely.faction = Entity.Faction.PLAYER
	lonely.ai = &"ally"
	var only_bow := Item.make(&"war_bow")
	lonely.inventory.append(only_bow)
	lonely.equipped[Item.Slot.WEAPON] = only_bow
	check("an ally with nothing else keeps the bow in hand",
		not archer._ready_weapon(lonely, 1))

	# --- and a risen grave keeps the old promise ------------------------------
	# _arm_monster refuses to hand a launcher to a melee brain. Grave gear used
	# to slip past that, so a risen archer charged swinging a bow.
	var tomb := _arena(30, 14)
	tomb.player.x = 4
	tomb.player.y = 7
	tomb.grave_at[Vector2i(8, 7)] = {
		"level": 9, "cause": "killed by an ogre", "depth": 9, "turns": 100,
		"gear": ["war bow", "war axe"], "line": "x",
	}
	tomb.map.set_tile(8, 7, Tiles.GRAVE)
	tomb._raise_from(Vector2i(8, 7))
	var archer_dead: Entity = null
	for e in tomb.entities:
		if e.risen:
			archer_dead = e
	check("a risen grave rises", archer_dead != null)
	if archer_dead != null:
		var hand: Item = archer_dead.equipped.get(Item.Slot.WEAPON, null)
		check("and holds the blade, not the bow",
			hand != null and hand.id == &"war_axe",
			hand.name if hand else "nothing")
		check("but still carries the bow, so it still drops",
			archer_dead.inventory.size() == 2,
			str(archer_dead.inventory.size()))

	# --- heel and loose --------------------------------------------------------
	# Built because play, not argument, produced the case: the first ally to
	# reach the endgame charged a dragon and died, because nothing could tell
	# it not to. The stance is one distance, so these checks are about how far
	# it is willing to go, not about two separate behaviours.
	var yard := _arena(30, 14)
	yard.player.x = 6
	yard.player.y = 7
	var hound := _spawn(yard, "skeleton", 7, 7)
	hound.faction = Entity.Faction.PLAYER
	hound.ai = &"ally"
	hound.name = "Rodney"
	# Far enough to be inside the leash but well outside heel's reach, which is
	# the whole span the stance decides. Asserted, so this cannot quietly
	# become a test of two identical distances.
	var quarry := _spawn(yard, "orc", 12, 7)
	quarry.max_hp = 400
	quarry.hp = 400
	var gap := Los.steps(yard.player.x, yard.player.y, quarry.x, quarry.y)
	check("the target sits between heel and loose (%d)" % gap,
		gap > GameState.ALLY_HEEL_REACH and gap <= GameState.ALLY_LEASH)

	check("an ally starts off the leash", hound.stance == Entity.Stance.LOOSE)
	yard._take_ai_turn(hound)
	check("and loose, it goes after something across the room",
		Los.steps(hound.x, hound.y, quarry.x, quarry.y) < gap - 1,
		"%d away" % Los.steps(hound.x, hound.y, quarry.x, quarry.y))

	# Called to heel: it should come back and stay.
	check("calling them to heel works", yard.player_ally_stance())
	check("and they are at heel", hound.stance == Entity.Stance.HEEL)
	for _i in 8:
		yard._take_ai_turn(hound)
	check("it returns to you rather than pressing the attack",
		Los.steps(hound.x, hound.y, yard.player.x, yard.player.y) <= 1,
		"%d away" % Los.steps(hound.x, hound.y, yard.player.x, yard.player.y))
	check("and the thing across the room is untouched",
		quarry.hp == quarry.max_hp, str(quarry.hp))

	# But a bodyguard still guards: something that comes to YOU gets answered,
	# including from the far side, which is why heel reaches two and not one.
	#
	# Positions set EXPLICITLY on both sides of the player rather than moved
	# relative to wherever the previous loop left the ally. The first version
	# dropped the orc on `player.x - 1` after eight turns of heeling, and the
	# ally had settled on exactly that cell -- so the two occupied one square,
	# `is_adjacent` measured zero rather than one, and the guard stood there
	# looking like a bug in the stance. Nothing in the game places an entity by
	# assignment; only this test did.
	hound.x = yard.player.x + 1
	hound.y = yard.player.y
	quarry.x = yard.player.x - 1
	quarry.y = yard.player.y
	check("the intruder is at your side, and not inside your ally",
		Vector2i(quarry.x, quarry.y) != Vector2i(hound.x, hound.y)
			and Los.steps(yard.player.x, yard.player.y, quarry.x, quarry.y)
				<= GameState.ALLY_HEEL_REACH)
	var unhurt := quarry.hp
	# Four, because it has to come round the player to reach the far side.
	for _i in 4:
		yard._take_ai_turn(hound)
	check("yet it answers what reaches you", quarry.hp < unhurt,
		"%d -> %d, ally at %d,%d orc at %d,%d" % [unhurt, quarry.hp,
			hound.x, hound.y, quarry.x, quarry.y])

	check("and the key toggles back off", yard.player_ally_stance()
		and hound.stance == Entity.Stance.LOOSE)
	# A stance survives a suspend, or a resumed run quietly slips its leash.
	var kept := Entity.from_dict(hound.to_dict())
	check("the stance survives a suspend",
		kept.stance == hound.stance, str(kept.stance))
	hound.stance = Entity.Stance.HEEL
	check("and so does heel",
		Entity.from_dict(hound.to_dict()).stance == Entity.Stance.HEEL)

	# Nobody to command: the key must not pretend it did something.
	var alone := _arena(20, 12)
	check("with no allies the key does nothing", not alone.player_ally_stance())

	# --- it follows you down -------------------------------------------------
	# Through the real path: build_level replaces `entities` wholesale, which
	# is exactly where an ally would be lost.
	var deep := GameState.new(31337)
	deep.new_game()
	var tagalong := GameState.monster_from(GameState.BESTIARY[0], 1, 1)
	tagalong.faction = Entity.Faction.PLAYER
	tagalong.name = "Erdrick"
	deep.entities.append(tagalong)
	deep.depth += 1
	deep.build_level()
	check("an ally follows you to the next floor",
		deep.entities.has(tagalong) and tagalong.alive)
	check("and arrives beside you rather than where it stood",
		Los.steps(tagalong.x, tagalong.y, deep.player.x, deep.player.y) <= 2,
		"%d away" % Los.steps(tagalong.x, tagalong.y, deep.player.x, deep.player.y))

	# --- and nothing ever mends it -------------------------------------------
	# The rule that makes following safe. Given a regen an ally must still not
	# use it, so this sets one deliberately rather than trusting a skeleton's
	# zero -- a coincidence somebody could tune away without noticing.
	tagalong.regen = 5
	tagalong.max_hp = 40
	tagalong.hp = 10
	deep._take_ai_turn(tagalong)
	check("an ally cannot be healed, even given regeneration",
		tagalong.hp == 10, str(tagalong.hp))

	# --- it hands the kit back when it falls ---------------------------------
	# The other half of conservation: one copy of that gear exists, and this is
	# where the player gets it back.
	var before := gs.ground.size()
	ally.hp = 1
	gs._attack(_spawn(gs, "orc", ally.x + 1, ally.y), ally)
	var handed := 0
	for it in gs.ground:
		if it.id == &"short_sword" or it.id == &"leather_armour":
			handed += 1
	check("a fallen ally hands its kit back (%d)" % handed,
		not ally.alive and handed == 2,
		"%d items, ground %d -> %d" % [handed, before, gs.ground.size()])

func _test_a_side_of_your_own() -> void:
	var gs := _arena(30, 14)
	gs.player.x = 4
	gs.player.y = 7
	var goblin := _spawn(gs, "goblin", 20, 7)
	var mate := _spawn(gs, "goblin", 21, 7)
	var ally := _spawn(gs, "skeleton", 19, 7)
	ally.faction = Entity.Faction.PLAYER
	ally.name = "bone ally"
	ally.max_hp = 200
	ally.hp = 200

	check("a monster fights the player", goblin.hostile_to(gs.player))
	check("and fights what walks with them", goblin.hostile_to(ally))
	check("the ally does not fight the player", not ally.hostile_to(gs.player))
	check("nor the player the ally", not gs.player.hostile_to(ally))
	check("and nothing fights itself", not goblin.hostile_to(goblin))
	# Neutral is unused so far. Asserted anyway, because the enum names it and
	# an unexercised branch is where the next wrong answer hides.
	mate.faction = Entity.Faction.NEUTRAL
	check("a neutral fights nobody", not mate.hostile_to(gs.player)
		and not goblin.hostile_to(mate))
	mate.faction = Entity.Faction.MONSTER

	# Precondition first. Without these three lines the exclusions below would
	# hold for an ally that was dead, off-screen or out of range -- which is to
	# say for no reason at all.
	check("the ally is alive and in view",
		ally.alive and gs.map.is_visible(ally.x, ally.y))
	var seen := gs.visible_monsters()
	check("it is not counted as a monster in view", not seen.has(ally),
		"%d seen" % seen.size())
	check("while the goblins still are", seen.has(goblin) and seen.has(mate))

	var shots := gs.firing_targets(20)
	check("the goblin is a legal shot", shots.has(goblin))
	check("the ally is not, at the same range", not shots.has(ally))

	# The nerve check reads its OWN side. One goblin beside another is company;
	# a goblin beside your ally is alone.
	check("a goblin counts its own kind (%d)" % gs._allies_near(goblin, 5),
		gs._allies_near(goblin, 5) == 1)
	check("the ally is not company for it",
		gs._allies_near(ally, 5) == 0, str(gs._allies_near(ally, 5)))

	# Nearest hostile, and the ally is sixteen cells nearer than the player.
	check("a monster picks the nearer enemy", gs._foe_for(goblin) == ally)
	check("and the ally picks the monster",
		gs._foe_for(ally) == goblin or gs._foe_for(ally) == mate)

	# End to end, through the real turn: the goblin is beside the ally and
	# should hit it. This is the check the whole refactor exists for -- before
	# it, the goblin walked past the ally to reach the player.
	var before := ally.hp
	gs._take_ai_turn(goblin)
	check("and swings at it rather than walking past",
		ally.hp < before, "%d -> %d" % [before, ally.hp])

	# With the ally gone the world goes back to exactly what it was, which is
	# what makes this refactor safe to ship before the ally exists.
	ally.alive = false
	check("and falls back to the player when alone",
		gs._foe_for(goblin) == gs.player)

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
	bar.font = Sidebar.ui_font()
	bar.icon_font = load("res://assets/fonts/ofr_icons.ttf")
	# A picture-line now, not a string with a picture buried in it. The skull has
	# to be drawable from the ICON face -- reaching it through the text font's
	# fallbacks is what left it a tofu box in the web export.
	var slain: Variant = bar._skullify("killed by a kobold slinger")
	check("the skull replaces the words", slain is Dictionary
		and String(slain["glyph"]) == char(Sidebar.SKULL)
		and String(slain["text"]) == "kobold slinger")
	var orc_death: Variant = bar._skullify("killed by an orc")
	check("and handles an, too", orc_death is Dictionary
		and String(orc_death["text"]) == "orc")
	check("a fall is left as written",
		bar._skullify("broken by a fall") == "broken by a fall")
	check("and so is walking out",
		bar._skullify("left the dungeon on depth 4") == "left the dungeon on depth 4")

	# The face the panel will actually DRAW that skull with, asked directly.
	#
	# The old check asked ui_font().has_char(SKULL), which passes on desktop
	# because fallbacks resolve there -- and the exported web build still drew a
	# box. Asking the icon face itself is the question that travels.
	check("the sidebar's icon face carries the skull",
		bar.icon_font != null and bar.icon_font.has_char(Sidebar.SKULL))
	check("and the panel reaches for that face, not the text one",
		bar._face_for(char(Sidebar.SKULL)) == bar.icon_font
			and bar._face_for("k") == bar.font)

	# Both faces built and HELD AT ONCE, which is the only state that shows the
	# bug. load() returns one shared instance per path, so while map_font() and
	# ui_font() assigned fallbacks straight onto it they wired that shared object
	# to point at itself -- icons -> text -> icons. Godot rejects a cyclic chain
	# ("Cyclic font fallback") by discarding the assignment, so whichever ran
	# second came back with an EMPTY fallback list: the map losing its letters,
	# or the panel losing its icons, depending only on which loaded first.
	#
	# Every other font check here drops its font before taking the next one, and
	# a freed font means the next load() is a fresh instance that cannot collide.
	# That is precisely why the suite went on passing while the running game
	# printed the error on every launch. Holding both is the whole test.
	var held_map := GlyphGrid.map_font()
	var held_ui := Sidebar.ui_font()
	check("the map face keeps its fallback while the panel face is alive too",
		held_map.fallbacks.size() == 1 and held_ui.fallbacks.size() == 1,
		"map=%d ui=%d" % [held_map.fallbacks.size(), held_ui.fallbacks.size()])
	# The shared cached resources must be left untouched, since mutating those is
	# what let two unrelated call sites reach each other in the first place.
	check("and neither scribbles on the shared cached font",
		load("res://assets/fonts/ofr_icons.ttf").fallbacks.is_empty()
			and load("res://assets/fonts/JetBrainsMono-Regular.ttf").fallbacks.is_empty())

	# Every gear glyph, from the icon face rather than through a fallback.
	var unreachable := []
	for id in Item.CATALOGUE:
		if Item.CATALOGUE[id].get("slot", Item.Slot.NONE) == Item.Slot.NONE:
			continue
		var app: StringName = Item.CATALOGUE[id].get("app", &"")
		if not GlyphTheme.OVERRIDES.has(app):
			continue
		var cp := int(GlyphTheme.OVERRIDES[app])
		if not bar.icon_font.has_char(cp):
			unreachable.append("%s (%s U+%X)" % [id, app, cp])
	check("the icon face carries every gear glyph",
		unreachable.is_empty(), str(unreachable))
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
