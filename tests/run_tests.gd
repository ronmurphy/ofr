extends SceneTree

## Headless test suite:  godot --headless --script res://tests/run_tests.gd
##
## This is the concrete reason the simulation owns no Godot nodes. Generating
## two hundred dungeons and asserting every one is completable takes under a
## second here, and needs no window, no renderer and no human.

var _passed := 0
var _failed := 0

func _initialize() -> void:
	# THE PRE-RUN IS OFF for the suite's floors (2026-10-06). It is a tenth of
	# a second at a staircase, and the suite builds thousands of floors: on,
	# the suite went from 15 minutes to 38. Nothing the generation tests check
	# can move under it -- it never touches a wall and never moves a hostile
	# monster -- and _test_the_floor_was_alive_before_you switches it on and
	# proves its invariants. Measured per test before deciding (CLAUDE.md).
	GameState.prerun_turns = 0
	# Point the save and the death log somewhere harmless BEFORE anything runs.
	#
	# This suite writes real files: the suspend tests call clear_suspend() and
	# save_suspend(), and every death test appends a line to the morgue. While
	# those paths were constants it did that to the player's own files, and it
	# deleted a suspended run that was actually being played.
	GameState.use_scratch_files("tests")
	# settings.cfg IS redirected now (SETTINGS_PATH, in use_scratch_files), and
	# four modules write it: RenderTheme, Effects, TraderTalk and SoundDeck.
	# This snapshot stays as a second line of defence: it compares the REAL
	# file at the end, so anything that writes it by a path of its own fails
	# loudly instead of being discovered months later as "it always resets".
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
	# And the legends, which every ending in this suite appends to.
	var legends_before := ""
	var had_legends := FileAccess.file_exists("user://legends.json")
	if had_legends:
		legends_before = FileAccess.get_file_as_string("user://legends.json")
	print("")
	_test_screenshot_paths_and_key()
	_test_scratch_cleanup_removes_only_scratch_settings()
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
	_test_vault_fungus_symbols()
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
	_test_the_wild_are_not_the_budget()
	_test_the_slime()
	_test_the_wolf_pack()
	_test_rabbits_keep_to_the_warren()
	_test_vaults_ship_in_every_export()
	_test_sprites_ship_in_every_export()
	_test_art_sets_ship_in_every_export()
	_test_every_art_set_is_whole()
	_test_pixel_sprites_read_the_editors_files()
	_test_every_sprite_is_a_look_the_game_draws()
	_test_animals_nap()
	_test_let_sleeping_bears_lie()
	_test_hunger()
	_test_guards_walk_their_own_beats()
	_test_fungus_grows_on_mud()
	_test_picking_a_fight_is_deliberate()
	_test_the_embers_come_first()
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
	_test_an_ending_clears_the_slot()
	_test_legends_log()
	_test_bodies_lie_and_rot()
	_test_slingers_reload()
	_test_the_wrong_fungus()
	_test_the_dark_is_fair()
	_test_the_fungus_spreads()
	_test_the_miasma()
	_test_water_cleanses()
	_test_the_red_raises_the_dead()
	_test_fire_relights_braziers()
	_test_gems_feed_the_uniques()
	_test_burying_and_the_red_withering()
	_test_the_gem_of_thirst()
	_test_a_bone_ally_can_carry_the_red()
	_test_the_undertakers_pay()
	_test_gems_in_the_world()
	_test_a_lost_hunter_goes_where_it_last_saw_you()
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
	_test_pits_are_an_escape()
	_test_the_foragers_satchel()
	_test_fungus_glows()
	_test_traps()
	_test_hidden_traps()
	_test_disarming_and_the_floors_own()
	_test_traps_by_band()
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
	_test_a_moved_button_leaves_its_row_marked()
	_test_the_conversation_footer_names_what_works()
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
	_test_the_trader_explains_its_tally()
	_test_a_blank_name_changes_nothing()
	_test_the_road()
	_test_doors_shut_behind_guards()
	_test_fair_shots()
	_test_travel_opens_doors()
	_test_a_full_pack_still_takes_the_stairs()
	_test_the_trader_is_relinked_by_identity()
	_test_main_only_sets_properties_that_exist()
	_test_threat_ceilings()
	_test_every_theme_glyph_is_drawable()
	_test_symbol_theme()
	_test_icon_theme()
	_test_billboard_sizes()
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
	_test_the_wild_are_no_ones_enemy()
	_test_hunters_eat_the_wild()
	_test_allies_back_out_of_the_poison()
	_test_the_desktops_review_points()
	_test_drip_pools_in_the_caves()
	_test_tending_the_fire_with_the_torch()
	_test_animals_drink()
	_test_bodies_say_who_killed_them()
	_test_taming_the_wolves()
	_test_the_floor_was_alive_before_you()
	_test_graves_raise_the_dead()
	_test_bestiary_is_earned()
	_test_the_bestiary_page()
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
	_test_cave_vaults()
	_test_creatures_by_name()
	_test_the_latched_gate()
	_test_fire_as_a_fear()
	_test_the_spider()
	_test_the_web()
	_test_the_web_flies()
	_test_casters()
	_test_caster_standoff_and_blink()
	_test_nothing_arrives_inside_a_door()
	_test_graves_remember_the_dead()
	_test_elapsed_is_time_not_keypresses()
	_test_run_is_recorded()
	_test_offhand_and_swap()
	_test_ammunition()
	_test_merging_spends_the_cheapest()
	_test_inventory_letters_dodge_the_keys()
	_test_worn_gear_is_not_in_the_pack()
	_test_stacks_in_the_pack()
	_test_the_forge_mark_keeps_its_word()
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
	check("the legends are redirected (%s)" % LegendsLog.PATH,
		LegendsLog.PATH.contains("scratch_"))
	var has_legends := FileAccess.file_exists("user://legends.json")
	check("legends.json is in the same state it started in",
		had_legends == has_legends and (not has_legends
			or FileAccess.get_file_as_string("user://legends.json") == legends_before))

	print("")
	print("  %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func _test_screenshot_paths_and_key() -> void:
	check("screenshot folder is redirected with the other player files",
		GameState.SCREENSHOT_DIR == "user://scratch_tests_screenshots")
	var folder := MainScene.screenshot_folder()
	check("and under scratch files it is never the desktop",
		folder == ProjectSettings.globalize_path("user://scratch_tests_screenshots")
		and folder != OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP))
	# Numbered, one past the highest already there -- gaps never reused.
	DirAccess.make_dir_recursive_absolute(folder)
	for f in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(f))
	check("an empty folder starts at 001",
		MainScene.next_screenshot_name(folder) == "ofr_screenshot_001.png")
	for n in ["ofr_screenshot_001.png", "ofr_screenshot_003.png", "holiday.png"]:
		var f := FileAccess.open(folder.path_join(n), FileAccess.WRITE)
		f.close()
	check("after 001 and 003 (and someone else's picture) comes 004",
		MainScene.next_screenshot_name(folder) == "ofr_screenshot_004.png",
		MainScene.next_screenshot_name(folder))
	for f in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(f))
	DirAccess.remove_absolute(folder)
	# The browser keeps its count in settings (scratch here).
	var first := MainScene.next_web_screenshot_name()
	var second := MainScene.next_web_screenshot_name()
	check("in a browser the count carries on from settings",
		first.begins_with("ofr_screenshot_") and second != first
		and second.trim_prefix("ofr_screenshot_").to_int()
			== first.trim_prefix("ofr_screenshot_").to_int() + 1, "%s then %s" % [first, second])
	var f9_is_listed := false
	for row in Sidebar.KEYS:
		if row[0] == "F9" and row[1] == "screenshot" and int(row[2]) == KEY_F9:
			f9_is_listed = true
	check("F9 screenshot is listed in the legend keys", f9_is_listed)

func _test_scratch_cleanup_removes_only_scratch_settings() -> void:
	var real_existed_before := FileAccess.file_exists("user://settings.cfg")
	var real_before := FileAccess.get_file_as_string("user://settings.cfg") \
		if real_existed_before else ""
	GameState.clear_scratch_files()
	GameState.use_scratch_files("clear_settings_test")
	var scratch_settings := GameState.SETTINGS_PATH
	var scratch_file := FileAccess.open(scratch_settings, FileAccess.WRITE)
	if scratch_file != null:
		scratch_file.store_string("scratch setting")
		scratch_file.close()
	var scratch_existed_before := FileAccess.file_exists(scratch_settings)
	GameState.clear_scratch_files()
	check("scratch cleanup has a settings file to remove", scratch_existed_before)
	check("scratch cleanup removes its settings file",
		not FileAccess.file_exists(scratch_settings))

	# Point only the settings path at the real file: the same guard must protect
	# it even while the other paths still point into scratch storage.
	GameState.SETTINGS_PATH = "user://settings.cfg"
	GameState.clear_scratch_files()
	var real_existed_after := FileAccess.file_exists("user://settings.cfg")
	var real_after := FileAccess.get_file_as_string("user://settings.cfg") \
		if real_existed_after else ""
	check("scratch cleanup leaves real settings.cfg untouched",
		real_existed_before == real_existed_after and real_before == real_after)
	GameState.use_scratch_files("tests")

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
		# The animals are up on arrival, on purpose (the pre-run, 2026-10-06):
		# a wild thing is no monster and is nobody's enemy unstruck.
		if e.alertness != Entity.Alert.ASLEEP and not e.is_wild():
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
					if not e.is_player and not e.is_wild() and room.has_point(Vector2i(e.x, e.y)):
						sum += e.threat
				if sum > ceiling:
					breaches += 1
					worst_over = maxi(worst_over, sum - ceiling)
	check("no room on the climb exceeds its ceiling (%d rooms, %d liches met)"
		% [rooms_checked, liches], breaches == 0,
		"%d breaches, worst %d over" % [breaches, worst_over])
	check("and the climb actually fielded some liches", liches > 0, str(liches))

## The headline guarantee: no room can roll something unsurvivable.
## THE WOLF (the wild creatures update, 2026-10-05): it comes as a pack, the
## pack is nobody's enemy until one is struck and then turns together, its
## company is its own kind, and a provoked pack hunts you.
func _test_the_wolf_pack() -> void:
	var gs := _arena(21, 11)
	gs.depth = 5
	gs.player.x = 3
	gs.player.y = 5
	gs.player.max_hp = 200
	gs.player.hp = 200
	var row := _bestiary_entry("wolf")
	check("precondition: the wolf is wild, eats, and comes in a pack in the caves",
		bool(row.get("wild", false)) and bool(row.get("eats", false)) and gs._pack_size(row) == 4)
	# Brad's bands (2026-10-05): a pair on the upper floors, four in the caves,
	# on both halves of the dungeon; none in either fortress.
	check("the pack is a pair on the upper floors and four in the caves, going down and coming up",
		gs._pack_size(row, 2) == 2 and gs._pack_size(row, 5) == 4
		and gs._pack_size(row, 15) == 4 and gs._pack_size(row, 18) == 2)
	check("and a thing without a pack is one", gs._pack_size(_bestiary_entry("goblin")) == 1)
	var leader := _spawn(gs, "wolf", 12, 5)
	gs._spawn_pack(leader, row, gs._pack_size(row) - 1)
	var wolves := []
	for e in gs.entities:
		if e.appearance == &"wolf":
			wolves.append(e)
	var close := true
	for w in wolves:
		close = close and Los.steps(w.x, w.y, leader.x, leader.y) <= 3
	check("the pack stands together (%d wolves)" % wolves.size(),
		wolves.size() == gs._pack_size(row) and close)
	# Unstruck: nobody's enemy, and your turn is not stopped by them.
	var quiet := true
	for w in wolves:
		quiet = quiet and not w.hostile_to(gs.player) and w.is_wild()
	check("unstruck, none of them is your enemy", quiet)
	var rabbit := _spawn(gs, "rabbit", leader.x + 1, leader.y)
	check("a rabbit beside a wolf is supper, not company",
		gs._allies_near(leader, 5) == wolves.size() - 1)
	# Struck: the pack turns as one.
	# PACK_REACH is 8 in steps; (19, 9) was 7 from the leader and turned too.
	var far := _spawn(gs, "wolf", 1, 1)
	var said := func() -> String:
		var all := ""
		for line in gs.msg_log.entries:
			all += str(line["text"]) + "|"
		return all
	gs.player.x = leader.x - 1
	gs.player.y = leader.y
	gs._attack(gs.player, leader)
	var turned := 0
	for w in wolves:
		if w.provoked and w.hostile_to(gs.player):
			turned += 1
	check("struck, every wolf within reach turns on you (and must)",
		turned == wolves.size() and said.call().contains("and the pack with it"), said.call())
	check("one too far off does not", not far.provoked)
	# No cannibals: a wolf never hunts its own kind, and a rabbit is supper.
	var hungry: Entity = wolves[2]
	hungry.alertness = Entity.Alert.AWAKE
	hungry.grudge = null
	# (The first rabbit may have been eaten by now; it is out of this.)
	if rabbit.alive:
		rabbit.x = 1
		rabbit.y = 9
	check("precondition: a packmate in plain sight, no rabbit near",
		gs._can_see(hungry, leader) and gs._prey_for(hungry) != rabbit)
	check("a wolf never hunts its own kind", gs._prey_for(hungry) == null
		or gs._prey_for(hungry).appearance != &"wolf")
	# At arm's length, as the packmates are: the arena is dark, and a wolf
	# finds what is beside it however dark (as _can_see says).
	var spot := Vector2i(-1, -1)
	for i in 8:
		var d := Entity.turned(Vector2i(1, 0), i)
		if gs.entity_at(hungry.x + d.x, hungry.y + d.y) == null and gs._can_rest_on(hungry.x + d.x, hungry.y + d.y):
			spot = Vector2i(hungry.x + d.x, hungry.y + d.y)
			break
	check("precondition: a free cell beside it", spot.x >= 0)
	var supper := _spawn(gs, "rabbit", spot.x, spot.y)
	check("precondition: it can see the rabbit", gs._can_see(hungry, supper))
	check("  the rabbit beside it is supper (and must be)", gs._prey_for(hungry) == supper)
	# A pack remembers together: an orc that spears one wolf has the whole
	# pack's grudge, without any of them turning on you.
	var orc := _spawn(gs, "orc", far.x + 1, far.y)
	var fresh := _spawn(gs, "wolf", far.x + 1, far.y + 1)
	gs._attack(orc, far)
	check("struck by an orc, a wolf and its packmate in reach hold the grudge",
		far.grudge == orc and fresh.grudge == orc and fresh.alertness == Entity.Alert.AWAKE)
	check("  and neither is your enemy for it", not far.provoked and not fresh.provoked)
	# A provoked pack hunts: a wolf with company steps in.
	var hunter: Entity = wolves[1]
	var before := Los.steps(hunter.x, hunter.y, gs.player.x, gs.player.y)
	hunter.alertness = Entity.Alert.AWAKE
	gs._take_ai_turn(hunter)
	check("with the pack round it, a provoked wolf closes on you",
		Los.steps(hunter.x, hunter.y, gs.player.x, gs.player.y) <= before)
	# Saved: the grudge against your side survives a reload.
	var back := GameState.new(1)
	back.new_game()
	var kept := 0
	if back.apply_dict(gs.to_dict()):
		for e in back.entities:
			if e.appearance == &"wolf" and e.provoked:
				kept += 1
	check("the pack's grudge is saved", kept == turned)
	# The fauna roll lands a pack, not a wolf: one pack a floor at most.
	var packs := 0
	var lone := 0
	for i in 30:
		var floor_gs := GameState.new(40000 + i)
		floor_gs.new_game()
		floor_gs.depth = 4
		floor_gs.build_level()
		var n := 0
		for e in floor_gs.entities:
			if e.appearance == &"wolf":
				n += 1
		if n >= 3:
			packs += 1
		elif n > 0:
			lone += 1
	check("on the floors they roam, wolves come in packs (%d packs, %d lone, of 30 floors)"
		% [packs, lone], packs >= 3 and lone <= packs)
	# The bands, measured: floors 1-6 and 14 on have wolves and bears; the
	# fortress (7-9) and the corrupted fortress (11-13) have neither; the
	# upper floors' packs are pairs. Unpriced now, a bear can land on floor 1
	# (a room there could never afford a 17), but on a minority of floors.
	var where := {}
	var pairs := 0
	var odd_packs := 0
	var bears_at_1 := 0
	for d in [1, 2, 5, 7, 8, 9, 11, 12, 13, 15, 18]:
		var wolf_floors := 0
		var bear_floors := 0
		for i in 12:
			var floor_gs := GameState.new(41000 + d * 100 + i)
			floor_gs.new_game()
			floor_gs.ascending = d > 10
			floor_gs.depth = d if d <= 10 else 20 - d
			floor_gs.build_level()
			var n := 0
			var b := 0
			for e in floor_gs.entities:
				if e.appearance == &"wolf":
					n += 1
				elif e.appearance == &"bear":
					b += 1
			if n > 0:
				wolf_floors += 1
			if b > 0:
				bear_floors += 1
			if d == 1:
				bears_at_1 += b
			if n > 0 and Bands.of(floor_gs.effective_depth()) == Bands.UPPER:
				if n == 2:
					pairs += 1
				else:
					odd_packs += 1
		where[d] = [wolf_floors, bear_floors]
	var fortress_clear := true
	for d in [7, 8, 9, 11, 12, 13]:
		fortress_clear = fortress_clear and where[d][0] == 0 and where[d][1] == 0
	check("neither fortress has a wolf or a bear (12 floors each of 7-9 and 11-13)", fortress_clear, str(where))
	check("floors 1, 2, 5, 15 and 18 have wolves (%s)" % str(where),
		where[1][0] >= 4 and where[2][0] >= 4 and where[5][0] >= 4 and where[15][0] >= 4 and where[18][0] >= 4)
	check("the caves have bears, going down and coming up (%d, %d of 12)" % [where[5][1], where[15][1]],
		where[5][1] >= 4 and where[15][1] >= 4)
	check("on the upper floors a pack is a pair (%d pairs, %d other)" % [pairs, odd_packs],
		pairs >= 6 and odd_packs == 0)
	check("a bear can be on floor 1 now, on some floors, not most (%d of 12 floors, %d bears)"
		% [where[1][1], bears_at_1], where[1][1] >= 1 and where[1][1] <= 7 and bears_at_1 == where[1][1])

## FUNGUS GROWS ON MUD (Brad, 2026-10-08): the red stalled at the first band
## of mud between it and a body, and never went for a body lying in mud. Now
## every fungus may grow on mud, water still stops it, and the mud comes back
## when the fungus goes.
func _test_fungus_grows_on_mud() -> void:
	var lay := func(between: int, body_on: int) -> GameState:
		var g := _arena(21, 9)
		g.player.x = 1
		g.player.y = 1
		g.entities = [g.player]
		g.bodies = []
		for y in range(1, 8):
			for x in range(8, 13):
				g.map.set_tile(x, y, between)
		g.map.set_tile(13, 4, body_on)
		g._set_fungus(Vector2i(7, 4), Tiles.FUNGUS_RED)
		g.bodies = [{"x": 13, "y": 4, "app": "kobold", "turn": g.turns, "corrupted": false,
			"e": {"name": "kobold", "max_hp": 6}, "seeded": -1, "claimed": false,
			"still": false, "rises": -1}]
		for i in 15:
			g._crawl_red()
		return g
	var mud: GameState = lay.call(Tiles.MUD, Tiles.FLOOR)
	check("the red crosses a band of mud to the body (and must)", bool(mud.bodies[0]["claimed"]))
	var in_mud: GameState = lay.call(Tiles.FLOOR, Tiles.MUD)
	check("  and goes for a body lying in mud", bool(in_mud.bodies[0]["claimed"]))
	var wet: GameState = lay.call(Tiles.WATER, Tiles.FLOOR)
	check("water still stops it", not bool(wet.bodies[0]["claimed"])
		and wet.map.get_tile(8, 4) == Tiles.WATER)
	# The mud comes back when the fungus goes: burned...
	check("precondition: the red grew over mud on its way", mud.map.get_tile(9, 4) == Tiles.FUNGUS_RED
		and mud.mud_under.has(Vector2i(9, 4)))
	mud._burn_fungus(Vector2i(9, 4))
	check("burn red that grew on mud and the mud is still there", mud.map.get_tile(9, 4) == Tiles.MUD)
	mud._burn_fungus(Vector2i(7, 4))
	check("  red on plain floor burns to plain floor", mud.map.get_tile(7, 4) == Tiles.FLOOR)
	# ...eaten by a rabbit...
	var g := _arena(15, 7)
	g.player.x = 1
	g.player.y = 1
	g.map.set_tile(6, 3, Tiles.MUD)
	g._set_fungus(Vector2i(6, 3), Tiles.FUNGUS)
	var bun := _spawn(g, "rabbit", 6, 3)
	g._rabbit_swallows(bun)
	check("a rabbit eats green off mud and leaves the mud", g.map.get_tile(6, 3) == Tiles.MUD)
	# ...and rooted from the satchel into mud, then picked again.
	var bag := Item.make(&"satchel")
	g.give_item(bag)
	var shroom := Item.make(&"fungus")
	bag.contents.append(shroom)
	g.player.x = 6
	g.player.y = 3
	check("a fungus takes root in mud (and must)", g.player_drop_from_satchel(0)
		and g.map.get_tile(6, 3) == Tiles.FUNGUS)
	var saved := GameState.new(1)
	saved.new_game()
	check("  the mud under it is saved", saved.apply_dict(g.to_dict())
		and saved.mud_under.has(Vector2i(6, 3)))
	g.player.hp = g.player.max_hp - 5
	check("precondition: hurt, so it may be eaten", g._eat_fungus())
	check("  eat it and the mud is back", g.map.get_tile(6, 3) == Tiles.MUD
		and not g.mud_under.has(Vector2i(6, 3)))

## EACH GUARD WALKS ITS OWN BEAT (2026-10-07): on one shared round the guards
## formed convoys (Brad's "lines of four"); now the round is dealt out in
## stretches, walked back and forth, and they stay spread.
func _test_guards_walk_their_own_beats() -> void:
	var gs := _arena(21, 9)
	gs.player.x = 1
	gs.player.y = 1
	var posts := [Vector2i(3, 4), Vector2i(8, 4), Vector2i(13, 4), Vector2i(18, 4)]
	gs.patrol_route = posts.duplicate()
	var guard := _spawn(gs, "kobold", 8, 4)
	guard.activity = Entity.Activity.PATROLLING
	guard.alertness = Entity.Alert.ASLEEP
	gs.entities = [gs.player, guard]
	gs._assign_beats()
	check("precondition: a lone guard is dealt the whole round as its beat",
		guard.beat_lo == 0 and guard.beat_hi == 3, "%d..%d" % [guard.beat_lo, guard.beat_hi])
	# Its own stretch, back and forth, and nowhere else.
	guard.beat_lo = 1
	guard.beat_hi = 2
	guard.patrol_at = 1
	guard.patrol_dir = 1
	var reached_far := false
	var back_again := false
	var strayed := false
	for i in 60:
		gs._ai_patrol(guard)
		var at := Vector2i(guard.x, guard.y)
		if at == posts[2]:
			reached_far = true
		elif at == posts[1] and reached_far:
			back_again = true
		if at.x < 7 or at.x > 14:
			strayed = true
	check("it walks to the far end of its beat and back (and must)", reached_far and back_again)
	check("  and never past either end", not strayed)
	check("  its beat is saved", Entity.from_dict(guard.to_dict()).beat_hi == 2
		and Entity.from_dict(guard.to_dict()).beat_lo == 1)
	# A guard from a save before beats walks the whole round, as it did.
	guard.beat_lo = 0
	guard.beat_hi = 0
	guard.patrol_at = 0
	var visited := {}
	for i in 120:
		gs._ai_patrol(guard)
		visited[guard.patrol_at] = true
	check("with no beat it walks the whole round (%d posts)" % visited.size(), visited.size() == 4)
	# Real fortress floors: the round dealt out, and the guards stay spread.
	var floors := 0
	var dealt_ok := true
	var crowded := 0
	var counted := 0
	var most := 0
	for i in 8:
		var f := GameState.new(55000 + i)
		f.new_game()
		f.depth = 7 + (i % 3)
		f.build_level()
		var guards: Array = []
		for e in f.entities:
			if e.alive and not e.is_player and e.patrols and e.faction != Entity.Faction.NEUTRAL \
					and e.activity == Entity.Activity.PATROLLING:
				guards.append(e)
		if guards.size() < 2 or f.patrol_route.size() < 2:
			continue
		floors += 1
		var covered := {}
		for e in guards:
			if not (e.beat_lo < e.beat_hi and e.beat_hi < f.patrol_route.size()):
				dealt_ok = false
			for k in range(e.beat_lo, e.beat_hi + 1):
				covered[k] = true
		if covered.size() != f.patrol_route.size():
			dealt_ok = false
		for t in 300:
			for e in guards:
				f._ai_patrol(e)
		for e in guards:
			counted += 1
			for o in guards:
				if o != e and Los.steps(e.x, e.y, o.x, o.y) <= 2:
					crowded += 1
					break
		for r in f.room_rects:
			var n := 0
			for e in guards:
				if r.has_point(Vector2i(e.x, e.y)):
					n += 1
			most = maxi(most, n)
	check("precondition: fortress floors with two or more guards (%d of 8)" % floors, floors >= 5)
	check("every guard has a beat on the round, and together they cover it", dealt_ok)
	var share := float(crowded) / maxf(1.0, float(counted))
	check("after 300 turns of rounds they walk apart: %.0f%% within two cells of another (was 64%%)"
		% (100.0 * share), share <= 0.40)
	check("  and no room holds more than four of them (%d)" % most, most <= 4)

## SOMETIMES SOMEONE JUST NEEDS A NAP (Brad, 2026-10-07). A bear in its den
## hibernates: the pre-run leaves it asleep, it never wakes on its own, and
## noise -- the den's bones -- wakes it. Other animals with nothing to do doze
## off now and then, wake on their own, or are woken by something passing.
## A rabbit is always about its mushrooms.
func _test_animals_nap() -> void:
	# A cave floor, the pre-run on: a den bear is asleep when you arrive.
	var was := GameState.prerun_turns
	GameState.prerun_turns = GameState.PRERUN_TURNS
	var denned := 0
	var asleep_in_den := 0
	for i in 12:
		var f := GameState.new(77700 + i)
		f.new_game()
		f.depth = 5
		f.build_level()
		for e in f.entities:
			if e.alive and e.appearance == &"bear" and e.denned:
				denned += 1
				if e.alertness == Entity.Alert.ASLEEP:
					asleep_in_den += 1
	GameState.prerun_turns = was
	check("precondition: cave floors have bears in dens (%d in 12)" % denned, denned >= 4)
	check("a bear in its den is asleep when you arrive (%d of %d)" % [asleep_in_den, denned],
		asleep_in_den * 4 >= denned * 3)
	# In an arena: a den bear never wakes on its own, however long.
	var gs := _arena(21, 9)
	gs.player.x = 1
	gs.player.y = 1
	gs.entities = [gs.player]
	var bear := _spawn(gs, "cave bear", 15, 6)
	bear.denned = true
	bear.alertness = Entity.Alert.ASLEEP
	for i in 300:
		gs._take_ai_turn(bear)
	check("left alone, a den bear sleeps on (300 turns)",
		bear.alertness == Entity.Alert.ASLEEP and bear.x == 15 and bear.y == 6)
	# Its bones: a noise in the den wakes it (and must).
	gs._make_noise(Vector2i(14, 6), 7, &"bones")
	check("a noise in the den wakes it", bear.alertness != Entity.Alert.ASLEEP)
	# With nothing near it, it goes back to sleep in the den (2026-10-07;
	# it used to come out an ordinary bear -- see _keeps_to_the_den).
	for i in GameState.DEN_SETTLE_TURNS:
		gs._take_ai_turn(bear)
	check("  and with nothing near, it settles back to sleep in its den",
		bear.alertness == Entity.Alert.ASLEEP and bear.denned
		and bear.x == 15 and bear.y == 6)
	# An ordinary animal: it naps now and then, and wakes on its own.
	var wolf := _spawn(gs, "wolf", 4, 6)
	wolf.alertness = Entity.Alert.AWAKE
	gs.entities = [gs.player, wolf]
	var naps := 0
	var wakes := 0
	var asleep_turns := 0
	var last := wolf.alertness
	for i in 1500:
		gs._take_ai_turn(wolf)
		if wolf.alertness == Entity.Alert.ASLEEP:
			asleep_turns += 1
		if last == Entity.Alert.AWAKE and wolf.alertness == Entity.Alert.ASLEEP:
			naps += 1
		if last == Entity.Alert.ASLEEP and wolf.alertness == Entity.Alert.AWAKE:
			wakes += 1
		last = wolf.alertness
	check("an idle wolf dozes off now and then (%d naps in 1500 turns)" % naps, naps >= 3)
	check("  and wakes on its own (%d)" % wakes, wakes >= 2)
	check("  and is up more than it sleeps (%d of 1500 asleep)" % asleep_turns, asleep_turns < 750)
	# A passer-by wakes a sleeper.
	wolf.alertness = Entity.Alert.ASLEEP
	var passer := _spawn(gs, "wolf", wolf.x + 1, wolf.y)
	passer.alertness = Entity.Alert.AWAKE
	gs.entities = [gs.player, wolf, passer]
	var woke := false
	for i in 10:
		gs._stir(wolf)
		if wolf.alertness == Entity.Alert.AWAKE:
			woke = true
			break
	check("precondition: something awake stands beside it", passer.is_adjacent(wolf))
	check("an awake creature passing beside a sleeper wakes it", woke)
	# A rabbit never naps.
	var bun := _spawn(gs, "rabbit", 10, 2)
	bun.alertness = Entity.Alert.AWAKE
	gs.entities = [gs.player, bun]
	var dozed := false
	for i in 500:
		gs._take_ai_turn(bun)
		if bun.alertness == Entity.Alert.ASLEEP:
			dozed = true
	check("a rabbit never naps: it is about its mushrooms", not dozed)
	# Its own stream, saved; the den is saved.
	check("naps draw on their own stream, saved", gs.to_dict().has("nap_rng"))
	bear.denned = true
	check("a den bear is saved as one", Entity.from_dict(bear.to_dict()).denned)

## LET SLEEPING BEARS LIE (Brad, 2026-10-07): anything within
## DEN_WAKE_REACH wakes a den bear, you included; up, it watches, and may come
## out after game or after you, or settles back to sleep when all is quiet.
func _test_let_sleeping_bears_lie() -> void:
	var den_bear := func(gs: GameState) -> Entity:
		var b := _spawn(gs, "cave bear", 10, 4)
		b.denned = true
		b.alertness = Entity.Alert.ASLEEP
		return b
	var gs := _arena(21, 9)
	gs.player.x = 1
	gs.player.y = 1
	var bear: Entity = den_bear.call(gs)
	# Something awake three steps off does not wake it; at two it does.
	var wolf := _spawn(gs, "wolf", 13, 4)
	wolf.alertness = Entity.Alert.AWAKE
	gs.entities = [gs.player, bear, wolf]
	for i in 50:
		gs._take_ai_turn(bear)
	check("precondition: a wolf three steps from the den, awake",
		Los.steps(bear.x, bear.y, wolf.x, wolf.y) == 3 and wolf.alertness == Entity.Alert.AWAKE)
	check("a wolf three steps off does not wake a den bear (50 turns)",
		bear.alertness == Entity.Alert.ASLEEP)
	wolf.x = 12
	gs._take_ai_turn(bear)
	check("a wolf two steps off wakes it, for certain",
		bear.alertness == Entity.Alert.AWAKE)
	# A kobold wakes it too, but is not game: it watches, and stays.
	gs = _arena(21, 9)
	gs.player.x = 1
	gs.player.y = 1
	bear = den_bear.call(gs)
	var kob := _spawn(gs, "kobold", 12, 4)
	kob.alertness = Entity.Alert.AWAKE
	gs.entities = [gs.player, bear, kob]
	gs._take_ai_turn(bear)
	check("a kobold two steps off wakes it", bear.alertness == Entity.Alert.AWAKE)
	for i in 40:
		gs._take_ai_turn(bear)
	check("  but a kobold is no meal yet: it watches from its den (40 turns)",
		bear.denned and bear.alertness == Entity.Alert.AWAKE
		and bear.x == 10 and bear.y == 4 and kob.alive)
	# The kobold goes: quiet for DEN_SETTLE_TURNS, it sleeps again.
	gs.entities = [gs.player, bear]
	for i in GameState.DEN_SETTLE_TURNS - 1:
		gs._take_ai_turn(bear)
	check("  not asleep before DEN_SETTLE_TURNS of quiet",
		bear.alertness == Entity.Alert.AWAKE)
	gs._take_ai_turn(bear)
	check("  and asleep in its den after them",
		bear.alertness == Entity.Alert.ASLEEP and bear.denned)
	# A rabbit beside it is game: the bear comes out after it.
	var hunted := 0
	var tries := 0
	for k in 10:
		gs = _arena(21, 9)
		gs.player.x = 1
		gs.player.y = 1
		gs.nap_rng.seed = 4400 + k
		bear = den_bear.call(gs)
		var bun := _spawn(gs, "rabbit", 11, 4)
		bun.alertness = Entity.Alert.AWAKE
		gs.entities = [gs.player, bear, bun]
		tries += 1
		for i in 30:
			gs._take_ai_turn(bear)
			if not bear.denned:
				hunted += 1
				break
	check("a rabbit beside the den: the bear comes out after it (%d of %d)" % [hunted, tries],
		hunted >= 8)
	# You, two steps off: it wakes, and may come for you as if struck.
	var turned := 0
	var logged := false
	for k in 10:
		gs = _arena(21, 9)
		gs.nap_rng.seed = 5500 + k
		bear = den_bear.call(gs)
		gs.player.x = 8
		gs.player.y = 4
		gs.entities = [gs.player, bear]
		gs._take_ai_turn(bear)
		if k == 0:
			check("you two steps off wake a den bear", bear.alertness == Entity.Alert.AWAKE)
			check("  and the log says so", _log_says(gs, "stirs in its den"))
		for i in 30:
			if bear.provoked:
				break
			gs._take_ai_turn(bear)
		if bear.provoked and bear.grudge == gs.player and bear.hostile_to(gs.player):
			turned += 1
			if _log_says(gs, "comes for you"):
				logged = true
	check("waking a bear is not a good thing: it comes for you (%d of 10)" % turned, turned >= 8)
	check("  and the log says so", logged)
	# During the pre-run you are not on the floor: you wake nothing.
	gs = _arena(21, 9)
	bear = den_bear.call(gs)
	gs.player.x = 9
	gs.player.y = 4
	gs.entities = [gs.player, bear]
	gs._prerunning = true
	gs._stir(bear)
	gs._prerunning = false
	check("in the pre-run, you beside the den wake nothing",
		bear.alertness == Entity.Alert.ASLEEP)
	gs._stir(bear)
	check("  and out of it, the same place wakes it", bear.alertness == Entity.Alert.AWAKE)
	# Saved.
	bear.den_quiet = 2
	check("a den bear's quiet turns are saved", Entity.from_dict(bear.to_dict()).den_quiet == 2)

## HUNGER, for the monsters and the animals (Brad, 2026-10-07): a fed eater
## lets game and meat be, a hungry one hunts; it grows by the turn, not in
## the pre-run or a nap; eating resets it; a floor deals appetites out.
func _test_hunger() -> void:
	# The same bear and rabbit, fed and then hungry.
	var make := func(hunger: int) -> Array:
		var gs := _arena(24, 11)
		gs.player.x = 2
		gs.player.y = 2
		gs.entities = [gs.player]
		var bear := _spawn(gs, "cave bear", 10, 5)
		var bun := _spawn(gs, "rabbit", 11, 5)
		bear.hunger = hunger
		bun.hp = 1
		return [gs, bear, bun]
	var fed: Array = make.call(0)
	var fbear: Entity = fed[1]
	var fbun: Entity = fed[2]
	check("precondition: a fed bear beside a rabbit it would take",
		not fbear.is_hungry() and (fed[0] as GameState)._is_game(fbear, fbun)
		and fbear.is_adjacent(fbun))
	for i in 20:
		(fed[0] as GameState)._take_ai_turn(fbear)
	check("a fed bear lets the rabbit beside it be (20 turns)", fbun.alive)
	var hungry: Array = make.call(Entity.HUNGRY_AT)
	var hbear: Entity = hungry[1]
	var hbun: Entity = hungry[2]
	check("precondition: the same bear, hungry", hbear.is_hungry())
	(hungry[0] as GameState)._take_ai_turn(hbear)
	check("a hungry bear takes it", not hbun.alive)
	# Eating resets it: the haunch it just made, underfoot.
	var gs: GameState = hungry[0]
	gs.ground.append(Item.make(&"meat"))
	gs.ground[-1].x = hbear.x
	gs.ground[-1].y = hbear.y
	check("precondition: meat under a hungry bear",
		hbear.is_hungry() and gs._is_meat(gs.ground[-1]))
	gs._hunt(hbear)
	check("eating sets its hunger back to nothing", hbear.hunger == 0)
	# A fed kobold leaves meat where it lies.
	var kob := _spawn(gs, "kobold", 4, 8)
	kob.hunger = 0
	var steak := Item.make(&"meat")
	steak.x = 4
	steak.y = 8
	gs.ground.append(steak)
	check("a fed kobold leaves meat underfoot", not gs._hunt(kob) and gs.ground.has(steak))
	kob.hunger = Entity.HUNGRY_AT
	check("  a hungry one eats it", gs._hunt(kob) and not gs.ground.has(steak))
	# It grows by the turn; not in a nap, not in the pre-run, not for yours.
	var h0 := hbear.hunger
	for i in 10:
		gs._grow_hungry(hbear)
	check("an animal awake grows hungrier by the turn (%d -> %d)" % [h0, hbear.hunger],
		hbear.hunger == h0 + 10)
	hbear.alertness = Entity.Alert.ASLEEP
	gs._grow_hungry(hbear)
	check("  not while it naps", hbear.hunger == h0 + 10)
	hbear.alertness = Entity.Alert.AWAKE
	gs._prerunning = true
	gs._grow_hungry(hbear)
	gs._prerunning = false
	check("  nor in the pre-run, or all would arrive starving", hbear.hunger == h0 + 10)
	hbear.faction = Entity.Faction.PLAYER
	gs._grow_hungry(hbear)
	check("  nor for one of yours", hbear.hunger == h0 + 10)
	# A fed den bear is slower to come out than a hungry one.
	var out := [0, 0]
	for which in 2:
		for k in 20:
			var den := _arena(21, 9)
			den.player.x = 1
			den.player.y = 1
			den.nap_rng.seed = 6600 + k
			var b := _spawn(den, "cave bear", 10, 4)
			b.denned = true
			b.hunger = 0 if which == 0 else Entity.HUNGRY_AT
			var r := _spawn(den, "rabbit", 11, 4)
			den.entities = [den.player, b, r]
			for i in 6:
				den._take_ai_turn(b)
				if not b.denned:
					out[which] += 1
					break
	check("a hungry den bear comes out sooner than a fed one (fed %d, hungry %d of 20)"
		% [out[0], out[1]], out[1] > out[0] and out[1] >= 12)
	# A floor deals appetites: some hungry, some fed, the same every time.
	var eaters := 0
	var hungry_n := 0
	var first: Array = []
	var again: Array = []
	for i in 6:
		for pass_n in 2:
			var f := GameState.new(88100 + i)
			f.new_game()
			f.depth = 5
			f.build_level()
			for e in f.entities:
				if e.alive and e.eats and not e.is_player:
					if pass_n == 0:
						eaters += 1
						if e.is_hungry():
							hungry_n += 1
						first.append(e.hunger)
					else:
						again.append(e.hunger)
	check("precondition: cave floors have eaters (%d on 6)" % eaters, eaters >= 20)
	check("about one in three arrives hungry (%d of %d)" % [hungry_n, eaters],
		hungry_n * 6 >= eaters and hungry_n * 2 <= eaters)
	check("  dealt the same from the same seed", first == again)
	# Saved.
	hbear.hunger = 123
	check("hunger is saved", Entity.from_dict(hbear.to_dict()).hunger == 123)
	check("  and so is its stream", gs.to_dict().has("hunger_rng"))

## THE VAULTS SHIP (2026-10-08). Every export preset was
## `export_filter="all_resources"` with an empty include filter, and a vault is
## a plain .txt file, which is not a resource: no vault file had ever reached
## an exported build. The desktop found it reading the packed game -- the
## scripts were there, not one assets/vaults/ path -- so on itch the barracks,
## the shrines, the coliseum, the warren and every cave vault were never met,
## while the editor, which reads the project folder, had them all along.
## Each preset now includes `assets/vaults/*.txt`, and `*` crosses folders
## (assets/vaults/caves/ ships too; checked in a test export).
func _test_vaults_ship_in_every_export() -> void:
	_check_folder_ships("assets/vaults/", "vault files", 20)

## The sprite files are plain .txt too (2026-10-09), so the same hazard: a
## sprite the export leaves out is a picture in every build but the editor's.
func _test_sprites_ship_in_every_export() -> void:
	_check_folder_ships("assets/sprites/", "sprite files", 40)

## The portraits and every art set are plain .txt too (2026-10-10).
func _test_art_sets_ship_in_every_export() -> void:
	_check_folder_ships("assets/portraits/", "portrait files", 28, false)
	_check_folder_ships("assets/skins/", "art set files", 90)

## Every export preset's include_filter carries `folder`*.txt, and that
## filter matches every .txt the game loads from it, subfolders too
## (`nested`: the folder must hold one in a subfolder, to prove that).
func _check_folder_ships(folder: String, what: String, at_least: int, nested := true) -> void:
	var filter := folder + "*.txt"
	var presets := ConfigFile.new()
	check("precondition: the export presets load", presets.load("res://export_presets.cfg") == OK)
	var names := []
	var missing := []
	for section in presets.get_sections():
		if not section.begins_with("preset.") or section.ends_with(".options"):
			continue
		var preset_name := String(presets.get_value(section, "name", section))
		names.append(preset_name)
		var filters := String(presets.get_value(section, "include_filter", "")).split(",")
		var covered := false
		for f in filters:
			if f.strip_edges() == filter:
				covered = true
		if not covered:
			missing.append(preset_name)
	check("precondition: three export presets (%s)" % ", ".join(names), names.size() == 3)
	check("every export includes the %s" % what, missing.is_empty(), str(missing))
	# And the filter really covers every file the game loads, subfolders too.
	var paths := []
	var dirs := ["res://" + folder]
	while not dirs.is_empty():
		var dir: String = dirs.pop_back()
		var d := DirAccess.open(dir)
		if d == null:
			continue
		for f in d.get_files():
			if f.ends_with(".txt"):
				paths.append(dir.trim_prefix("res://") + f)
		for sub in d.get_directories():
			dirs.append(dir + sub + "/")
	var unmatched := []
	for path in paths:
		if not String(path).matchn(filter):
			unmatched.append(path)
	check("precondition: the %s are there (%d files)%s" % [what, paths.size(),
			", one in a subfolder" if nested else ""],
		paths.size() >= at_least and (not nested or paths.any(func(p): return String(p).count("/") > 2)))
	check("  and the filter matches every one of them, subfolders too", unmatched.is_empty(), str(unmatched))

## ART SETS (2026-10-10): the original set and the folders under
## assets/skins/, each a whole game -- every file a drawing of a look the game
## draws, drawn once, and every look the original has still drawn under every
## set (what a set lacks falls back to the original). See PixelSprites.
func _test_every_art_set_is_whole() -> void:
	var sets := PixelSprites.skins()
	check("precondition: the original and three sets (%s)" % str(sets),
		sets.size() >= 4 and sets[0] == PixelSprites.ORIGINAL
		and sets.has(&"detailed") and sets.has(&"horror") and sets.has(&"cute"))
	var looks := AsciiTheme.TABLE
	var broken := []
	var stray := []
	var twice := []
	var unnamed := []
	var groups := {"res://assets/portraits/": PixelSprites.PORTRAITS}
	for id in sets:
		if id == PixelSprites.ORIGINAL:
			continue
		var root := PixelSprites.SKINS + String(id) + "/"
		if not FileAccess.get_file_as_string(root + "skin.txt").contains("name:"):
			unnamed.append(id)
		groups[root + "portraits/"] = root + "portraits/"
		groups[root + "cards"] = root
	for key in groups:
		var seen := {}
		var dirs: Array = []
		if String(key).ends_with("cards"):
			for folder in PixelSprites.CARD_FOLDERS:
				dirs.append(String(groups[key]) + folder)
		else:
			dirs.append(groups[key])
		while not dirs.is_empty():
			var dir: String = dirs.pop_back()
			var d := DirAccess.open(dir)
			if d == null:
				continue
			for f in d.get_files():
				if not f.ends_with(".txt"):
					continue
				var id := StringName(f.trim_suffix(".txt"))
				if seen.has(id):
					twice.append(dir + f)
				seen[id] = true
				var parsed := PixelSprites.parse(FileAccess.get_file_as_string(dir + f))
				if parsed.is_empty() or PixelSprites.image(parsed) == null:
					broken.append(dir + f)
				if not looks.has(id):
					stray.append(dir + f)
			for sub in d.get_directories():
				dirs.append(dir + sub + "/")
	check("every art set names itself in its skin.txt", unnamed.is_empty(), str(unnamed))
	check("every file in every art set is a drawing", broken.is_empty(), str(broken))
	check("  of a look the game draws", stray.is_empty(), str(stray))
	check("  and no look is drawn twice in one set", twice.is_empty(), str(twice))
	# Fallback: every look the original draws is still drawn under every set.
	PixelSprites.use_skin(PixelSprites.ORIGINAL)
	var original: Dictionary = PixelSprites.paths().duplicate()
	var lost := []
	for id in sets:
		PixelSprites.use_skin(id)
		for look in original:
			if not PixelSprites.has(look):
				lost.append("%s:%s" % [id, look])
	check("precondition: the original draws its set (%d looks)" % original.size(), original.size() >= 47)
	check("no art set loses a look the original draws", lost.is_empty(), str(lost))
	# Where each card and portrait comes from.
	PixelSprites.use_skin(&"horror")
	var horror_ok := PixelSprites.skin() == &"horror" \
		and String(PixelSprites.paths()[&"wolf"]).contains("skins/horror/portraits") \
		and String(PixelSprites.paths()[&"weapon"]).contains("skins/horror/items")
	PixelSprites.use_skin(&"detailed")
	var detailed_ok := String(PixelSprites.paths()[&"wolf"]) == "res://assets/portraits/wolf.txt" \
		and String(PixelSprites.paths()[&"weapon"]).begins_with("res://assets/sprites/")
	PixelSprites.use_skin(PixelSprites.ORIGINAL)
	var original_ok := String(PixelSprites.paths()[&"wolf"]) == "res://assets/sprites/creatures/wolf.txt" \
		and PixelSprites.portrait_path(&"wolf") == "res://assets/portraits/wolf.txt" \
		and PixelSprites.portrait_path(&"weapon") == String(PixelSprites.paths()[&"weapon"]) \
		and not PixelSprites.portrait(&"wolf").is_empty()
	check("horror's portraits are its creature cards, its items its own (the must-succeed)", horror_ok)
	check("  detailed shows the original's portraits as cards, the original's items", detailed_ok)
	check("  the original keeps its small cards, with portraits for the bestiary; no portrait, the card",
		original_ok)
	PixelSprites.use_skin(&"no_such_set")
	check("a set that is not there is the original", PixelSprites.skin() == PixelSprites.ORIGINAL)
	PixelSprites.use_skin(PixelSprites.ORIGINAL)

## PIXEL SPRITES (2026-10-09): the game reads exactly what
## tools/sprite_editor.html writes. A sprite here is written by hand in the
## editor's format, with every rough edge a hand-edited file can have.
func _test_pixel_sprites_read_the_editors_files() -> void:
	var text := "\r\n".join([
		"name: test",
		"size: 6x4",
		"color a: #141418",
		"color b: #808080",
		"color c: #ffffff",
		"color q: nonsense",
		"a comment line the editor would skip",
		"variant ally: b #7fd69a, z #ff0000",
		"PIXELS",
		"......",
		".abba.",
		".aqc?",
	])
	var s := PixelSprites.parse(text)
	check("a sprite in the editor's format reads (the must-succeed check)",
		not s.is_empty() and s["name"] == "test" and s["w"] == 6 and s["h"] == 4)
	var rows: PackedStringArray = s.get("rows", PackedStringArray())
	check("  every row is the full width: a short row and a missing one are padded",
		rows.size() == 4 and rows[2] == ".aqc.." and rows[3] == "......", str(rows))
	check("  a colour that is not #rrggbb is no colour; a stray character is see-through",
		not (s["colours"] as Dictionary).has("q") and rows[2][4] == ".")
	check("  the variant keeps its letters, z included", (s["variants"] as Dictionary).has("ally")
		and (s["variants"]["ally"] as Dictionary).size() == 2)
	check("  no PIXELS line, or no size, is not a sprite",
		PixelSprites.parse("name: x\nsize: 2x2\n").is_empty()
		and PixelSprites.parse("name: x\nPIXELS\naa\n").is_empty())
	check("  a size past the editor's 64 is cut to it",
		int(PixelSprites.parse("size: 90x3\nPIXELS\n").get("w", 0)) == PixelSprites.MAX_SIDE)
	var img := PixelSprites.image(s)
	check("  the image is cropped to what is drawn: 4x2 of a 6x4 canvas",
		img != null and img.get_width() == 4 and img.get_height() == 2,
		"%s" % [Vector2i(img.get_width(), img.get_height()) if img != null else "null"])
	if img != null:
		check("  each letter in its colour; a letter with no colour is see-through",
			img.get_pixel(0, 0).is_equal_approx(Color("141418"))
			and img.get_pixel(1, 0).is_equal_approx(Color("808080"))
			and img.get_pixel(1, 1).a == 0.0
			and img.get_pixel(2, 1).is_equal_approx(Color("ffffff")))
		var ally := PixelSprites.image(s, "ally")
		check("  a variant changes its letters only",
			ally.get_pixel(1, 0).is_equal_approx(Color("7fd69a"))
			and ally.get_pixel(0, 0).is_equal_approx(Color("141418"))
			and ally.get_pixel(2, 1).is_equal_approx(Color("ffffff")))
		var tint := Color("c05a3a")
		var tinted := PixelSprites.tinted(img, tint)
		check("  tinted: the commonest colour becomes the tint, the outline stays dark",
			tinted.get_pixel(1, 0).is_equal_approx(tint)
			and tinted.get_pixel(0, 0).get_luminance() < 0.2
			and tinted.get_pixel(1, 1).a == 0.0)
		var shape := PixelSprites.silhouette(img, Color.BLACK, Color.RED)
		var rim := PixelSprites.rim(img)
		var r := PixelSprites.RIM
		check("  the silhouette keeps the shape; the frame is RIM wider and stays outside it",
			shape.get_pixel(0, 0) == Color.RED and shape.get_pixel(1, 1).a == 0.0
			and rim.get_width() == img.get_width() + r * 2
			and rim.get_pixel(r, r).a == 0.0 and rim.get_pixel(0, r).a > 0.0
			and rim.get_pixel(r + 1, r + 1).a > 0.0)
	var ring := PixelSprites.image(PixelSprites.parse("size: 3x3\ncolor a: #808080\nPIXELS\naaa\na.a\naaa\n"))
	var framed := PixelSprites.rim(ring)
	var rr := PixelSprites.RIM
	check("  a hole the drawing closes round is not framed (the frame shows through it)",
		ring.get_pixel(1, 1).a == 0.0 and framed.get_pixel(rr + 1, rr + 1).a == 0.0
		and framed.get_pixel(rr - 1, rr + 1).a > 0.0)
	check("  nothing drawn is no image",
		PixelSprites.image(PixelSprites.parse("size: 3x1\nPIXELS\nzzz\n")) == null)

## Every sprite file is a drawing (it parses and has pixels) of a look the
## game puts on a card, drawn once. The game finds a sprite by its file
## name, so a file named after anything else is a drawing nobody ever sees.
func _test_every_sprite_is_a_look_the_game_draws() -> void:
	PixelSprites.reload()
	var paths := PixelSprites.paths()
	var looks := AsciiTheme.TABLE
	var broken := []
	var stray := []
	var seen := {}
	var twice := []
	var dirs := ["res://assets/sprites/"]
	while not dirs.is_empty():
		var dir: String = dirs.pop_back()
		var d := DirAccess.open(dir)
		if d == null:
			continue
		for f in d.get_files():
			if not f.ends_with(".txt"):
				continue
			var id := StringName(f.trim_suffix(".txt"))
			if seen.has(id):
				twice.append(id)
			seen[id] = true
			var parsed := PixelSprites.parse(FileAccess.get_file_as_string(dir + f))
			if parsed.is_empty() or PixelSprites.image(parsed) == null:
				broken.append(dir + f)
			if not looks.has(id):
				stray.append(f)
		for sub in d.get_directories():
			dirs.append(dir + sub + "/")
	check("precondition: the sprite folder has the starter set (%d files)" % seen.size(),
		seen.size() >= 40 and paths.size() == seen.size() - twice.size())
	check("every sprite file is a drawing", broken.is_empty(), str(broken))
	check("every sprite is named after a look the game draws", stray.is_empty(), str(stray))
	check("no look is drawn twice", twice.is_empty(), str(twice))
	var missing := []
	for row in GameState.BESTIARY:
		if not PixelSprites.has(row["app"]):
			missing.append(row["app"])
	if not missing.is_empty():
		print("  NOTE: no drawing yet for %s -- they keep their pictures; tools/make_starter_sprites.py makes starters" % str(missing))

## THE WARREN (Brad, 2026-10-07): wild things keep out of a fortress, so the
## ordinary roll never puts a rabbit in one, going down or coming up; the
## garrison's warren vault, with its `r` markers, is the only way in. The
## caves keep every rabbit they had.
## THE WEB, the spider's night 2 (2026-10-10): a struck spider spits a web
## over its foe from 2 to WEB_RANGE away; whatever stands in a web is held --
## its next move only tears it free (two turns, loud) -- unless it burns the
## web (one turn, torch or fire blade). A bear and a spider walk through.
## THE WEB IN FLIGHT (2026-10-10, the desktop, the Legion's loose end 1): a
## spider's shot is an event the views draw as silk flying from it to where
## the web lands -- a shot with no damage number, as recall's arrows are.
func _test_the_web_flies() -> void:
	var gs := _arena(21, 9)
	gs.player.x = 5
	gs.player.y = 4
	gs.torch_lit = true
	var spi := _spawn(gs, "spider", 8, 4)
	spi.provoked = true
	spi.grudge = gs.player
	gs.entities = [gs.player, spi]
	gs._gather_lights()
	gs.update_vision()
	gs.events.clear()
	check("precondition: the spider spits (the must-succeed)", gs._shoot_web(spi, gs.player))
	var flew := {}
	for e in gs.events:
		if e["kind"] == &"web":
			flew = e
	check("  and says so: from the spider to where the web lands",
		not flew.is_empty() and flew["from"] == Vector2i(8, 4) and flew["to"] == Vector2i(5, 4))
	var was := Effects.mode()
	Effects.set_mode(Effects.Mode.SHADERS)
	var fx := Fx.new()
	fx.add_events([flew], 16)
	var silk := 0
	var numbers := 0
	for item in fx.list:
		if item["type"] == &"shot" and bool(item.get("silk", false)):
			silk += 1
		elif item["type"] == &"popup":
			numbers += 1
	check("  drawn as one shot of silk, and no damage number", silk == 1 and numbers == 0)
	Effects.set_mode(Effects.Mode.NONE)
	var still := Fx.new()
	still.add_events([flew], 16)
	check("  and on still, nothing flies", still.list.is_empty())
	Effects.set_mode(was)

func _test_the_web() -> void:
	check("a web is ground you can walk into and see through",
		Tiles.is_walkable(Tiles.WEB) and Tiles.is_transparent(Tiles.WEB)
		and Vault.TERRAIN.get("w", -1) == Tiles.WEB)
	var gs := _arena(21, 9)
	gs.player.x = 5
	gs.player.y = 4
	gs.torch_lit = true
	var spi := _spawn(gs, "spider", 8, 4)
	spi.provoked = true
	spi.grudge = gs.player
	gs.entities = [gs.player, spi]
	gs._gather_lights()
	gs.update_vision()
	check("precondition: a struck spider three steps off, and it can see you",
		spi.hostile_to(gs.player) and gs._can_see(spi, gs.player) and spi.webs)
	gs._take_ai_turn(spi)
	check("it spits a web over you", gs.map.get_tile(5, 4) == Tiles.WEB
		and _log_says(gs, "spits a web over you"))
	check("  over the floor it remembers", int(gs.web_under.get(Vector2i(5, 4), -1)) == Tiles.FLOOR)
	check("  and must wait before the next", spi.web_cool == GameState.WEB_COOL
		and not gs._shoot_web(spi, gs.player))
	# Held: your move only tears you free, for two turns, loudly.
	var t0 := gs.elapsed
	gs.player_move(-1, 0)
	check("caught, a move only tears you free (you stay put)",
		gs.player.x == 5 and gs.map.get_tile(5, 4) == Tiles.FLOOR
		and _log_says(gs, "tear yourself free"))
	check("  and it costs two turns (%d)" % (gs.elapsed - t0),
		gs.elapsed - t0 == Scheduler.ACTION_COST * GameState.WEB_TEAR_COST)
	gs.player_move(-1, 0)
	check("  free, the next move walks", gs.player.x == 4)
	# Burning: one turn, with the torch, and the HERE box offers it.
	gs.player.x = 5
	gs._spin_web(Vector2i(5, 4))
	var offered := false
	for row in gs.actions_here():
		if String(row[1]) == "burn the web":
			offered = true
	check("caught with a lit torch, the HERE box offers to burn the web", offered)
	t0 = gs.elapsed
	gs.player_pickup()
	check("  G burns it in one turn (%d)" % (gs.elapsed - t0),
		gs.map.get_tile(5, 4) == Tiles.FLOOR and gs.elapsed - t0 == Scheduler.ACTION_COST
		and _log_says(gs, "shrivels"))
	gs.torch_lit = false
	gs._spin_web(Vector2i(5, 4))
	check("  doused, with no fire blade, there is nothing to burn it with",
		not gs._burn_at(Vector2i(5, 4)) and gs.map.get_tile(5, 4) == Tiles.WEB)
	# Over mud, the mud comes back.
	gs.map.set_tile(12, 6, Tiles.MUD)
	gs._spin_web(Vector2i(12, 6))
	gs._unweb(Vector2i(12, 6))
	check("a web over mud gives the mud back", gs.map.get_tile(12, 6) == Tiles.MUD)
	# Not at arm's length: there it bites.
	gs = _arena(21, 9)
	gs.player.x = 5
	gs.player.y = 4
	gs.torch_lit = true
	spi = _spawn(gs, "spider", 6, 4)
	spi.provoked = true
	gs.entities = [gs.player, spi]
	gs._gather_lights()
	gs.update_vision()
	check("beside you it does not spit, it bites", not gs._shoot_web(spi, gs.player)
		and gs.map.get_tile(5, 4) != Tiles.WEB)
	# Who it holds.
	gs = _arena(21, 9)
	gs.player.x = 1
	gs.player.y = 1
	var gob := _spawn(gs, "goblin", 6, 4)
	var bear := _spawn(gs, "cave bear", 6, 6)
	var bat := _spawn(gs, "cave bat", 10, 4)
	var other := _spawn(gs, "spider", 10, 6)
	gs.entities = [gs.player, gob, bear, bat, other]
	for e in [gob, bear, bat, other]:
		gs._spin_web(Vector2i(e.x, e.y))
	check("a goblin in a web only tears free", gs._torn_free(gob)
		and gs._last_move_cost == Scheduler.ACTION_COST * GameState.WEB_TEAR_COST
		and gs.map.get_tile(6, 4) != Tiles.WEB)
	check("  a bat too: webs hold flyers", gs._torn_free(bat))
	check("  but a bear walks through", not gs._torn_free(bear) and gs.map.get_tile(6, 6) == Tiles.WEB)
	check("  and a spider is at home in one", not gs._torn_free(other))
	# Saved.
	var back := GameState.new(1)
	back.apply_dict(gs.to_dict())
	check("what a web was spun over is saved", back.web_under.has(Vector2i(6, 6)))
	check("the bestiary says it webs",
		BestiaryPanel.traits(gs._bestiary_row(&"spider")).has("Spits webs that hold you fast. Fire frees you."))

## THE SPIDER, night 1 of 3 (2026-10-09): WILD, its bite poisons, it flees
## up the walls and climbs down after, it hunts bats; upper floors, caves and
## the fortress. Its web (night 2) and nest (night 3) are still to come.
func _test_the_spider() -> void:
	var row: Dictionary = {}
	for e in GameState.BESTIARY:
		if e["name"] == "spider":
			row = e
	check("the spider is in the bestiary, wild, solitary",
		not row.is_empty() and row.get("wild", false) and not row.has("pack")
		and row["app"] == &"spider")
	check("  and the fortress is one of its bands -- the one wild exception",
		(row.get("bands", {}) as Dictionary).has(&"fortress"))
	# Found where it should be.
	var seen := {"upper": 0, "caves": 0, "fortress": 0}
	for band_depth in [[2, "upper"], [5, "caves"], [8, "fortress"]]:
		for i in 12:
			var f := GameState.new(95000 + i)
			f.new_game()
			f.depth = int(band_depth[0])
			f.build_level()
			for e in f.entities:
				if e.alive and e.appearance == &"spider":
					seen[band_depth[1]] += 1
	check("spiders turn up on the upper floors, in the caves and in the fortress %s" % str(seen),
		seen["upper"] > 0 and seen["caves"] > 0 and seen["fortress"] > 0)
	# Unstruck, nobody's enemy; its bite poisons.
	var gs := _arena(21, 9)
	gs.player.x = 5
	gs.player.y = 4
	gs.torch_lit = false
	var spi := _spawn(gs, "spider", 6, 4)
	gs.entities = [gs.player, spi]
	check("an unstruck spider is no enemy of yours", not spi.hostile_to(gs.player))
	check("precondition: you are not poisoned", gs.player.poisoned == 0)
	gs.player.hp = gs.player.max_hp
	gs._attack(spi, gs.player)
	check("its bite poisons you for three turns (%d)" % gs.player.poisoned,
		gs.player.poisoned == 3 and _log_says(gs, "bite burns"))
	var bones := _spawn(gs, "skeleton", 7, 5)
	gs._attack(spi, bones)
	check("  but nothing unliving", bones.poisoned == 0)
	# It flees up the wall, and climbs down after.
	gs = _arena(21, 9)
	gs.player.x = 5
	gs.player.y = 4
	gs.torch_lit = false
	for y in range(1, 8):
		gs.map.set_tile(7, y, Tiles.WALL)
	gs.pathfinder = Pathfinder.new(gs.map)
	spi = _spawn(gs, "spider", 6, 4)
	gs.entities = [gs.player, spi]
	spi.provoked = true
	spi.fleeing = true
	check("precondition: a fleeing spider with its back to a wall",
		not gs.map.is_walkable(7, 4) and spi.fleeing)
	gs._ai_flee(spi, gs.player)
	check("it goes up the wall, away from you (%d,%d)" % [spi.x, spi.y],
		spi.x == 7 and not gs.map.is_walkable(spi.x, spi.y))
	# Beside it, one move is the blow (two would give it a turn between,
	# and it climbs on).
	gs.player.x = 6
	var whole := spi.hp
	gs.player_move(1, 0)
	check("  and is still killable there: walking at it strikes it (%d -> %d)" % [whole, spi.hp],
		spi.hp < whole or not spi.alive)
	spi.hp = spi.max_hp
	spi.fleeing = false
	gs._take_ai_turn(spi)
	check("no longer fleeing, it climbs down onto open ground",
		gs.map.is_walkable(spi.x, spi.y) and gs._can_rest_on(spi.x, spi.y))
	# The food web: bats are its game; it is a bear's, never a wolf's.
	gs = _arena(21, 9)
	gs.player.x = 1
	gs.player.y = 1
	spi = _spawn(gs, "spider", 10, 4)
	var bat := _spawn(gs, "cave bat", 11, 4)
	var wolf := _spawn(gs, "wolf", 9, 5)
	var bear := _spawn(gs, "cave bear", 12, 5)
	gs.entities = [gs.player, spi, bat, wolf, bear]
	check("a bat is a spider's game", gs._is_game(spi, bat))
	check("  a spider is not a wolf's (threat 7 to its 6)", not gs._is_game(wolf, spi))
	check("  but it is a bear's", gs._is_game(bear, spi))
	check("  and never another spider's", not gs._is_game(spi, _spawn(gs, "spider", 13, 4)))
	# A vault's x is a spider.
	gs = _arena(21, 9)
	gs.player.x = 1
	gs.player.y = 1
	gs.depth = 5
	var gen := MapGen.new(gs.rng)
	gen.vault_contents = [{"ch": "x", "pos": Vector2i(8, 4)}]
	gs._place_vault_contents(gen)
	var drawn: Entity = gs.entity_at(8, 4)
	check("a vault's x places a spider", drawn != null and drawn.appearance == &"spider")
	# Saved.
	var back := Entity.from_dict(drawn.to_dict())
	check("its venom and its climbing are saved", back.venom == 3 and back.climbs)

## FIRE, AN INNATE FEAR (built 2026-10-09, Brad's numbers): an unstruck
## animal keeps FIRE_FEAR_REACH from your lit torch and lit braziers; a
## struck bear or wolf beside fire fights CORNERED_BONUS harder and will not
## flee; monsters ignore fire.
func _test_fire_as_a_fear() -> void:
	var gs := _arena(25, 9)
	gs.player.x = 5
	gs.player.y = 4
	gs.torch_lit = true
	var wolf := _spawn(gs, "wolf", 6, 4)
	gs.entities = [gs.player, wolf]
	check("precondition: an unstruck wolf beside your lit torch",
		wolf.is_wild() and not wolf.provoked and gs.torch_lit and wolf.is_adjacent(gs.player))
	# Directly, not over several turns: a wolf left alone wanders off anyway,
	# and a check that passes for that reason cannot fail (it did not).
	check("it steps back from the torch", gs._keeps_back_from_fire(wolf)
		and Los.steps(wolf.x, wolf.y, 5, 4) == 2)
	check("  and again, out past FIRE_FEAR_REACH", gs._keeps_back_from_fire(wolf)
		and Los.steps(wolf.x, wolf.y, 5, 4) == GameState.FIRE_FEAR_REACH + 1)
	check("  where the fire no longer moves it", not gs._keeps_back_from_fire(wolf))
	# Doused: no fire, no fear.
	wolf.x = 6
	wolf.y = 4
	gs.torch_lit = false
	check("douse the torch and it no longer keeps back", not gs._keeps_back_from_fire(wolf)
		and wolf.x == 6)
	# A lit brazier frightens too, with you nowhere near.
	gs.torch_lit = true
	gs.player.x = 1
	gs.player.y = 1
	gs.map.set_tile(15, 4, Tiles.BRAZIER)
	var bun := _spawn(gs, "rabbit", 16, 4)
	gs.entities = [gs.player, wolf, bun]
	check("a rabbit beside a lit brazier steps away from it",
		gs._keeps_back_from_fire(bun) and Los.steps(bun.x, bun.y, 15, 4) == 2)
	gs.map.set_tile(15, 4, Tiles.BRAZIER_DEAD)
	bun.x = 16
	check("  but not from a dead one", not gs._keeps_back_from_fire(bun) and bun.x == 16)
	# Monsters do not fear fire.
	gs.player.x = 5
	gs.player.y = 4
	var gob := _spawn(gs, "goblin", 6, 5)
	check("a goblin beside your torch does not keep back", not gs._keeps_back_from_fire(gob))
	# In the pre-run you are not on the floor: your torch frightens nothing.
	wolf.x = 6
	wolf.y = 4
	gs._prerunning = true
	check("in the pre-run your torch frightens nothing", gs._fire_near(Vector2i(6, 4)).x < 0)
	gs._prerunning = false
	# Struck: no longer afraid -- cornered.
	wolf.provoked = true
	wolf.grudge = gs.player
	check("a struck wolf beside fire does not back off", not gs._keeps_back_from_fire(wolf))
	check("  it is cornered by the flame", gs._cornered_by_flame(wolf))
	var bear := _spawn(gs, "cave bear", 4, 3)
	bear.provoked = true
	check("  so is a struck bear", gs._cornered_by_flame(bear))
	bun.provoked = true
	bun.x = 4
	bun.y = 5
	check("  but not a struck rabbit", not gs._cornered_by_flame(bun))
	# The bonus, measured: the same blows with the same rolls, fire and none.
	gs.entities = [gs.player, wolf]
	var dealt := func(lit: bool) -> int:
		gs.torch_lit = lit
		gs.rng.seed = 777
		var total := 0
		for i in 20:
			gs.player.hp = gs.player.max_hp
			gs._attack(wolf, gs.player)
			total += gs.player.max_hp - gs.player.hp
		return total
	var cold: int = dealt.call(false)
	var hot: int = dealt.call(true)
	check("cornered, it hits CORNERED_BONUS harder (%d against %d over 20 blows)" % [hot, cold],
		hot == cold + 20 * GameState.CORNERED_BONUS)
	check("  and the log says so, once", _log_says(gs, "Cornered by the flame"))
	# It will not flee beside fire; away from it, it does.
	wolf.hp = 1
	wolf.fleeing = false
	gs.torch_lit = true
	gs._update_morale(wolf)
	check("cornered by flame, a beaten wolf does not flee", not wolf.fleeing)
	gs.torch_lit = false
	gs._update_morale(wolf)
	check("  without the fire, it does", wolf.fleeing)

## THE LATCHED GATE (Brad, 2026-10-07; built 2026-10-09): no animal gets
## past it, anything with hands lifts the latch, a bear smashes it, and a
## phasing thing goes through as it goes through stone.
## A pen: a wall down x=10 with one doorway at (10, 4).
func _gate_pen(door_tile: int) -> GameState:
	var gs := _arena(21, 9)
	gs.player.x = 1
	gs.player.y = 1
	for y in range(1, 8):
		gs.map.set_tile(10, y, Tiles.WALL)
	gs.map.set_tile(10, 4, door_tile)
	gs.pathfinder = Pathfinder.new(gs.map)
	gs.entities = [gs.player]
	return gs

func _test_the_latched_gate() -> void:
	check("a vault's H is a latched gate", Vault.TERRAIN.get("H", -1) == Tiles.GATE_CLOSED)
	check("  shut it is a shut doorway, open an open one",
		Tiles.is_shut(Tiles.GATE_CLOSED) and Tiles.is_open_door(Tiles.GATE_OPEN)
		and Tiles.opened(Tiles.GATE_CLOSED) == Tiles.GATE_OPEN
		and Tiles.closed(Tiles.GATE_OPEN) == Tiles.GATE_CLOSED
		and Tiles.opened(Tiles.DOOR_CLOSED) == Tiles.DOOR_OPEN)
	# A rabbit penned with its supper outside.
	var crossed := func(door_tile: int) -> bool:
		var gs := _gate_pen(door_tile)
		gs.map.set_tile(13, 4, Tiles.FUNGUS)
		var bun := _spawn(gs, "rabbit", 7, 4)
		for i in 120:
			gs._take_ai_turn(bun)
			if bun.x > 10:
				return true
		return false
	check("precondition: a rabbit goes under a plain shut door to its supper",
		crossed.call(Tiles.DOOR_CLOSED))
	check("a rabbit stays behind a latched gate (120 turns)", not crossed.call(Tiles.GATE_CLOSED))
	# A wolf: the step is refused, and its routes go round (here: none).
	var gs := _gate_pen(Tiles.GATE_CLOSED)
	var wolf := _spawn(gs, "wolf", 9, 4)
	check("precondition: a wolf squeezes under doors", wolf.door_style() == Entity.Door.SQUEEZES)
	check("a wolf may not step into a latched gate", not gs.can_creature_step(9, 4, 10, 4, wolf))
	check("  and its route through the pen wall finds nothing",
		gs.pathfinder.path(Vector2i(9, 4), Vector2i(12, 4), false, false, true).is_empty())
	check("  while an ordinary route goes through the gate",
		not gs.pathfinder.path(Vector2i(9, 4), Vector2i(12, 4)).is_empty())
	check("  and the backstop holds it if it tries", gs._through_the_door(wolf, Vector2i(10, 4))
		and gs.map.get_tile(10, 4) == Tiles.GATE_CLOSED)
	for i in 30:
		gs._step_toward(wolf, Vector2i(12, 4))
	check("  a wolf walking at it stays its side (30 tries)", wolf.x < 10)
	# A goblin has hands.
	var gob := _spawn(gs, "goblin", 9, 3)
	check("precondition: a goblin opens doors", gob.door_style() == Entity.Door.OPENS)
	check("a goblin lifts the latch", gs._through_the_door(gob, Vector2i(10, 4))
		and gs.map.get_tile(10, 4) == Tiles.GATE_OPEN and _log_says(gs, "lifts the latch"))
	check("  and once open, the animals' routes go through",
		not gs.pathfinder.path(Vector2i(9, 4), Vector2i(12, 4), false, false, true).is_empty())
	# Shut behind it, it latches again.
	gob.x = 11
	gob.y = 4
	gob.shut_behind = Vector2i(10, 4)
	gob.alertness = Entity.Alert.ASLEEP
	gs.entities = [gs.player, gob]
	check("a guard shutting a gate behind it latches it",
		gs._shut_behind(gob) and gs.map.get_tile(10, 4) == Tiles.GATE_CLOSED)
	check("  and the animals' routes know it again",
		gs.pathfinder.path(Vector2i(9, 4), Vector2i(12, 4), false, false, true).is_empty())
	# A bear smashes it.
	var bear := _spawn(gs, "cave bear", 9, 5)
	check("a bear smashes a gate like any door", gs._through_the_door(bear, Vector2i(10, 4))
		and gs.map.get_tile(10, 4) == Tiles.FLOOR and _log_says(gs, "smashes the gate"))
	# A banshee goes through stone, so through a gate.
	gs = _gate_pen(Tiles.GATE_CLOSED)
	var ghost := _spawn(gs, "banshee", 9, 4)
	check("a phasing thing passes a latched gate",
		ghost.phasing and gs.can_creature_step(9, 4, 10, 4, ghost)
		and not gs._through_the_door(ghost, Vector2i(10, 4)))
	# You lift the latch, and shut it again.
	gs = _gate_pen(Tiles.GATE_CLOSED)
	gs.player.x = 9
	gs.player.y = 4
	gs.player_move(1, 0)
	check("you lift the latch and open the gate",
		gs.map.get_tile(10, 4) == Tiles.GATE_OPEN and gs.player.x == 9)
	check("  you close it: it latches", gs.player_close_door()
		and gs.map.get_tile(10, 4) == Tiles.GATE_CLOSED)
	# The bulwark bars a gate, and the bar comes off as an open gate.
	var bulwark := Item.make(&"gem_bulwark")
	check("the bulwark bars a gate", gs._bar_the_door(bulwark)
		and gs.map.get_tile(10, 4) == Tiles.DOOR_BARRED and gs.barred_gates.has(Vector2i(10, 4)))
	var back := GameState.new(1)
	back.apply_dict(gs.to_dict())
	check("  remembered across a save", back.barred_gates.has(Vector2i(10, 4)))
	gs._unbar(Vector2i(10, 4))
	check("  lifted, it is an open gate, not a door", gs.map.get_tile(10, 4) == Tiles.GATE_OPEN)
	# The cursor names it.
	var bar := Sidebar.new()
	bar.state = gs
	gs.map.set_tile(10, 4, Tiles.GATE_CLOSED)
	gs.map.set_all_visible()
	gs.map.remember_visible()
	bar.hovered = Vector2i(10, 4)
	var said := ""
	for entry in bar._describe():
		if entry is String:
			said += String(entry) + "|"
	check("the cursor says 'a latched gate'", said.contains("a latched gate"), said)
	bar.free()

func _test_rabbits_keep_to_the_warren() -> void:
	var gs := _arena(15, 9)
	var rabbits_at := func(tier: int) -> int:
		var n := 0
		for i in 300:
			var pick := gs._roll_monster(GameState.WILD_UNPRICED, tier, true)
			if not pick.is_empty() and pick["name"] == "rabbit":
				n += 1
		return n
	check("precondition: the animal roll buys rabbits in the caves (%d of 300)" % rabbits_at.call(5),
		rabbits_at.call(5) > 0)
	check("never in the fortress going down (%d of 300)" % rabbits_at.call(8), rabbits_at.call(8) == 0)
	check("nor in the fortress coming up (%d of 300)" % rabbits_at.call(12), rabbits_at.call(12) == 0)
	check("and floor 10 keeps its rabbits (%d of 300)" % rabbits_at.call(10), rabbits_at.call(10) > 0)
	# The marker: a rabbit where the author put it, wild, and only one a cell.
	var gen := MapGen.new(gs.rng)
	gen.vault_contents = [{"ch": "r", "pos": Vector2i(6, 4)}, {"ch": "r", "pos": Vector2i(6, 4)}]
	var before := gs.entities.size()
	gs._place_vault_contents(gen)
	var kept: Entity = gs.entity_at(6, 4)
	check("an r marker sets a wild rabbit down where it was drawn (and must)",
		kept != null and kept.appearance == &"rabbit" and kept.is_wild())
	check("  and a second marker on a taken cell places nothing", gs.entities.size() == before + 1)
	# The vault itself: the fortress's, both halves, rabbits and no mushrooms
	# (two make a killer rabbit at this depth).
	var warren: Vault = null
	for v in Vault.load_all():
		if v.name == "the warren":
			warren = v
	var marks := 0
	var mushrooms := 0
	if warren != null:
		for row in warren.rows:
			marks += row.count("r")
			mushrooms += row.count("*")
	check("the warren is a fortress vault with rabbits and no mushrooms (%d rabbits)" % marks,
		warren != null and warren.suits(Bands.FORTRESS) and not warren.suits(Bands.CAVES)
		and marks >= 2 and mushrooms == 0)
	# Built fortress floors: a floor has the warren's rabbits or none at all.
	# (Seeds chosen so some floors have the warren; if mapgen's draws change,
	# re-probe for a seed range that still holds one -- CLAUDE.md.)
	var with_warren := 0
	var stray := []
	for i in 16:
		var f := GameState.new(99800 + i)
		f.new_game()
		f.ascending = i % 2 == 1
		f.depth = 8 if i % 2 == 0 else 7
		f.build_level()
		var n := 0
		for e in f.entities:
			if e.alive and e.appearance == &"rabbit":
				n += 1
		if n == marks:
			with_warren += 1
		elif n != 0:
			stray.append("seed %d: %d rabbits" % [99800 + i, n])
	check("precondition: some of 16 fortress floors have the warren (%d)" % with_warren, with_warren >= 2)
	check("every fortress rabbit is a warren rabbit: a floor has its %d or none" % marks,
		stray.is_empty(), str(stray))

## THE EMBERS COME FIRST (Brad's play, 2026-10-05): at a guttering brazier
## with a bow in hand, pressing a gem of returning SETS it; it was crushed
## for its own use instead. At a lit brazier, or with nothing to hold it,
## the gem's own use stands.
func _test_the_embers_come_first() -> void:
	var gs := _arena(21, 9)
	gs.player.x = 5
	gs.player.y = 4
	gs.player.inventory.clear()
	var bow := Item.make(&"short_bow")
	gs.player.inventory.append(bow)
	gs.player.equipped[Item.Slot.WEAPON] = bow
	var back := Item.make(&"gem_return")
	gs.player.inventory.append(back)
	var panel := InventoryPanel.new()
	panel.state = gs
	# A LIT brazier beside you: the gem's own use, mark the fire.
	gs.map.set_tile(6, 4, Tiles.BRAZIER)
	gs.brazier_charge[Vector2i(6, 4)] = 10
	check("precondition: a lit brazier is not the forge",
		gs._adjacent_embers().x < 0 and gs._adjacent_brazier().x >= 0 and gs.return_target() == &"mark")
	check("beside a lit brazier the gem does not set", not gs.gem_sets_here(back))
	check("  and the pack says mark this brazier", panel._action_hint(back) == "mark this brazier",
		panel._action_hint(back))
	# Now the coals: setting comes first.
	gs.map.set_tile(6, 4, Tiles.BRAZIER_SPENT)
	gs.brazier_charge.erase(Vector2i(6, 4))
	gs.ember_until[Vector2i(6, 4)] = gs.turns + GameState.EMBER_TURNS
	check("precondition: embers beside you, a bow in hand that takes returning",
		gs._adjacent_embers().x >= 0 and bow.accepts_element(&"return") and gs.return_target() == &"mark")
	check("at the embers the gem sets", gs.gem_sets_here(back))
	check("  the pack says set into the bow", panel._action_hint(back) == "set into short bow",
		panel._action_hint(back))
	check("  and the HERE box offers the setting", gs.gem_use_here(back) == "set the gem of returning",
		gs.gem_use_here(back))
	check("pressing the gem SETS it (and must)", gs.player_use(gs.player.inventory.find(back))
		and bow.element == &"return" and not gs.player.inventory.has(back))
	check("  and the fire was not marked", gs.recall_mark.x < 0)
	# Embers again, but nothing to hold a second stone: its own use stands.
	gs.map.set_tile(5, 5, Tiles.BRAZIER_SPENT)
	gs.ember_until[Vector2i(5, 5)] = gs.turns + GameState.EMBER_TURNS
	var second := Item.make(&"gem_return")
	gs.player.inventory.append(second)
	check("precondition: the bow is set already, the embers are hot",
		bow.element == &"return" and gs._adjacent_embers().x >= 0)
	check("with nothing to hold it the gem does not set", not gs.gem_sets_here(second))
	check("  and pressing it marks the fire (and must)",
		gs.player_use(gs.player.inventory.find(second)) and gs.recall_mark.x >= 0)
	panel.free()

## THE BUMP WARNING (2026-10-05): a wild thing that could hurt you is not
## attacked by the first move into it; the second, straight after, is the
## fight. A rabbit is hit at once, a provoked animal too, and anything done
## in between starts the warning over.
func _test_picking_a_fight_is_deliberate() -> void:
	var gs := _arena(15, 7)
	gs.player.x = 3
	gs.player.y = 3
	gs.player.max_hp = 200
	gs.player.hp = 200
	var wolf := _spawn(gs, "wolf", 4, 3)
	wolf.alertness = Entity.Alert.AWAKE
	var hp := wolf.hp
	var t := gs.turns
	check("precondition: a wolf, wild, unprovoked, beside you, able to bite",
		wolf.is_wild() and not wolf.hostile_to(gs.player) and wolf.power > 0 and wolf.is_adjacent(gs.player))
	check("the first move into it is a warning: no blow, no turn, no grudge",
		not gs.player_move(1, 0) and wolf.hp == hp and gs.turns == t and not wolf.provoked
		and _log_says(gs, "That is a wolf, and it has done nothing to you"))
	# Something else in between -- a step away and back -- starts it over.
	check("precondition: a step away is a move", gs.player_move(0, 1) and gs.player.y == 4)
	gs.player.x = 3
	gs.player.y = 3
	wolf.x = 4
	wolf.y = 3
	t = gs.turns
	check("after another move, the warning is given again",
		not gs.player_move(1, 0) and wolf.hp == hp and gs.turns == t and not wolf.provoked)
	# The same move again: the fight (and it must happen).
	check("the move repeated is the attack", gs.player_move(1, 0) and gs.turns == t + 1
		and (wolf.hp < hp or not wolf.alive) and wolf.provoked)
	# A rabbit: no warning, it is supper. A provoked thing: no warning, it is
	# your enemy already.
	# (On free cells: the first wolf still stands east of you.)
	check("precondition: the cell above you is free", gs.entity_at(gs.player.x, gs.player.y - 1) == null)
	var rabbit := _spawn(gs, "rabbit", gs.player.x, gs.player.y - 1)
	var rhp := rabbit.hp
	check("a rabbit is struck by the first move", gs.player_move(0, -1) and (rabbit.hp < rhp or not rabbit.alive))
	check("precondition: the cell west of you is free", gs.entity_at(gs.player.x - 1, gs.player.y) == null)
	var other := _spawn(gs, "wolf", gs.player.x - 1, gs.player.y)
	other.provoked = true
	other.alertness = Entity.Alert.AWAKE
	var ohp := other.hp
	check("precondition: a provoked wolf is your enemy", other.hostile_to(gs.player))
	check("and is struck by the first move, no warning",
		gs.player_move(-1, 0) and (other.hp < ohp or not other.alive))

## THE SLIME (Brad's design, 2026-10-05): it goes for what lies on the floor
## before anything else, swallows it and drops it all when it dies; meat and
## fungus it eats; its hit leaves acid that water washes off and rabbits do
## not shrug off; it seeds the dead like a rat; the climb corrupts it.
func _test_the_slime() -> void:
	var gs := _arena(21, 9)
	gs.player.x = 3
	gs.player.y = 4
	gs.player.inventory.clear()
	var slime := _spawn(gs, "slime", 8, 4)
	check("precondition: a slime, slow, acid, no appetite flag needed",
		slime.ai == &"slime" and slime.acid and slime.speed < 100)
	# A lure: a dagger lying two cells off. It goes for the dagger, not you.
	var bait := Item.make(&"dagger")
	bait.x = 10
	bait.y = 4
	gs.ground = [bait]
	var d0 := Los.steps(slime.x, slime.y, gs.player.x, gs.player.y)
	for i in 3:
		gs._take_ai_turn(slime)
	check("lured, it walks to what lies there and swallows it (and must)",
		not gs.ground.has(bait) and slime.inventory.has(bait) and bait.scavenged
		and Los.steps(slime.x, slime.y, gs.player.x, gs.player.y) >= d0)
	# Meat and fungus are eaten, not kept.
	var meat := Item.make(&"meat")
	meat.magnitude = 3
	meat.x = slime.x
	meat.y = slime.y
	gs.ground = [meat]
	slime.hp = 1
	gs._take_ai_turn(slime)
	check("meat under it is eaten, not carried", not gs.ground.has(meat)
		and not slime.inventory.has(meat) and slime.hp > 1)
	gs.map.set_tile(slime.x, slime.y, Tiles.FUNGUS)
	gs._take_ai_turn(slime)
	check("fungus under it is dissolved", gs.map.get_tile(slime.x, slime.y) == Tiles.FLOOR)
	# Nothing left to take: it hunts you, and its hit clings.
	gs.ground = []
	slime.x = 4
	slime.y = 4
	gs.player.hp = 50
	gs.player.max_hp = 50
	var hit := 0
	for i in 6:
		gs._attack(slime, gs.player)
		if gs.player.acid_turns > 0:
			hit += 1
			break
	check("its hit leaves acid on you (and must)", gs.player.acid_turns == GameState.ACID_LINGER
		and hit == 1)
	var here := HerePanel.new()
	here.state = gs
	check("the box says acid, and how to be rid of it",
		here.status_line().begins_with("acid") and here.status_line().contains("water"),
		here.status_line())
	var hp0 := gs.player.hp
	gs._acid_bites(gs.player)
	check("acid eats a point a turn", gs.player.hp == hp0 - GameState.ACID_HURT
		and gs.player.acid_turns == GameState.ACID_LINGER - 1)
	gs.map.set_tile(gs.player.x, gs.player.y, Tiles.WATER)
	gs._wash(gs.player)
	check("water washes the acid off", gs.player.acid_turns == 0)
	gs.map.set_tile(gs.player.x, gs.player.y, Tiles.FLOOR)
	# A rabbit shrugs off the purple, not the acid.
	var bunny := _spawn(gs, "rabbit", 12, 6)
	bunny.acid_turns = 2
	var bhp := bunny.hp
	gs._acid_bites(bunny)
	check("acid is not the miasma: a rabbit is eaten by it", bunny.hp < bhp)
	# It drops everything it swallowed when it dies.
	_kill(gs, slime, gs.player)
	var dropped := false
	for it in gs.ground:
		if it == bait:
			dropped = true
	check("killed, it drops what it swallowed, every time (scavenged)", dropped)
	# A carrier of the red: beside a body, it seeds it.
	var cs := _arena(15, 9)
	cs.player.x = 2
	cs.player.y = 2
	var carrier := _spawn(cs, "slime", 8, 4)
	cs.bodies = [{"x": 9, "y": 4, "app": "kobold", "turn": cs.turns, "corrupted": false,
		"e": GameState.monster_from(_bestiary_entry("kobold"), 9, 4).to_dict(), "seeded": -1,
		"claimed": false, "still": false, "rises": -1}]
	cs.ground = []
	cs._grow_fungus()
	check("beside a body it seeds the fungus, like a rat", int(cs.bodies[0].get("seeded", -1)) >= 0
		and GameState.SPORE_CARRIERS.has(&"slime"))
	# Deep down it still appears, and the climb corrupts it.
	var deep := GameState.new(77)
	deep.new_game()
	deep.depth = 9
	deep.build_level()
	var slimes := 0
	for i in 300:
		var pick := deep._roll_monster(99)
		if not pick.is_empty() and pick["name"] == "slime":
			slimes += 1
	check("at depth 9 the roll still finds it, rarely (%d of 300)" % slimes, slimes > 0 and slimes < 90)
	var corruptible := false
	for i in 200:
		var pick := deep._roll_corruptible(20)
		if not pick.is_empty() and pick["name"] == "slime":
			corruptible = true
	check("and the climb can corrupt it", corruptible)

## THE WILD ARE NOT THE BUDGET (2026-10-05): the hostile roll never buys an
## animal, the fauna roll buys nothing else, floors keep the danger the
## ceiling promises, and the animals are still there.
func _test_the_wild_are_not_the_budget() -> void:
	var gs := GameState.new(5)
	gs.new_game()
	gs.depth = 5
	gs.build_level()
	var wild_in_budget := 0
	var tame_in_fauna := 0
	var fauna_rolled := 0
	for i in 200:
		var pick := gs._roll_monster(99)
		if not pick.is_empty() and bool(pick.get("wild", false)):
			wild_in_budget += 1
		var beast := gs._roll_monster(99, -1, true)
		if not beast.is_empty():
			fauna_rolled += 1
			if not bool(beast.get("wild", false)):
				tame_in_fauna += 1
	check("the hostile roll never buys an animal (0 of 200)", wild_in_budget == 0, "%d" % wild_in_budget)
	check("the fauna roll buys nothing but animals (%d rolled)" % fauna_rolled,
		fauna_rolled == 200 and tame_in_fauna == 0, "%d tame" % tame_in_fauna)
	# Floors keep their danger, and their animals. Depth 6 carried about 131
	# threat all told before the animals went wild (probe, 2026-10-05); the
	# enemies alone must still carry most of that, with animals on top.
	var hostile := 0.0
	var animals := 0
	var bears := 0
	var bats_at_3 := 0
	for i in 20:
		var six := GameState.new(60000 + i)
		six.new_game()
		six.depth = 6
		six.build_level()
		for e in six.entities:
			if e.is_player:
				continue
			if e.hostile_to(six.player):
				hostile += e.threat
			if e.is_wild():
				animals += 1
				if e.appearance == &"bear":
					bears += 1
		var three := GameState.new(30000 + i)
		three.new_game()
		three.depth = 3
		three.build_level()
		for e in three.entities:
			if not e.is_player and e.appearance == &"bat":
				bats_at_3 += 1
	check("depth 6 keeps its hostile threat with the animals on top (mean %.0f)" % (hostile / 20.0),
		hostile / 20.0 >= 110.0)
	check("and still has its animals (%d in 20 floors, %d bears)" % [animals, bears],
		animals >= 40 and bears >= 5)
	check("and depth 3 its bats (%d in 20 floors)" % bats_at_3, bats_at_3 >= 20)

func _test_threat_ceiling_holds() -> void:
	# The wild are left out of every sum: an animal is nobody's enemy until
	# struck, and since 2026-10-05 the ceiling never bought one (_place_fauna).
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
					if not e.is_player and not e.is_wild() and room.has_point(Vector2i(e.x, e.y)):
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
	GameState.clear_scratch_files()
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
					if not e.is_player and not e.is_wild() and region.has_point(Vector2i(e.x, e.y)):
						sum += e.threat
				if sum > roof:
					cave_breaches += 1
					cave_worst = maxi(cave_worst, sum - roof)
				elif sum > mine:
					own_breaches += 1
			GameState.clear_scratch_files()
	GameState.clear_scratch_files()
	GameState.use_scratch_files("tests")
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
	GameState.clear_scratch_files()
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
		GameState.clear_scratch_files()
	GameState.clear_scratch_files()
	GameState.use_scratch_files("tests")
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
	# The donor is worn first: a worn thing is never a stack, so the keeper
	# arrives in its own slot (2026-10-03).
	worn.give_item(donor)
	worn.player.equipped[Item.Slot.ARMOR] = donor
	worn.give_item(keep)
	check("precondition: two slots, the worn one apart", worn.player.inventory.size() == 2)
	check("merging a worn donor works", worn.player_merge(worn.player.inventory.find(keep)))
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

## THE MIASMA (strand 3): purple breathes a poison cloud over itself and its
## eight neighbours -- 1 hp a turn, lingering 3 turns after you leave.
func _test_the_miasma() -> void:
	# A rabbit is at home in the purple's air (Brad, 2026-10-01: its meat is
	# the cure, so the cloud cannot be what kills it); a kobold is not.
	var air := _arena(11, 7)
	air.player.x = 2
	air.player.y = 3
	air.map.set_tile(7, 3, Tiles.FUNGUS_PURPLE)
	var bunny := _spawn(air, "rabbit", 7, 2)
	var breather := _spawn(air, "kobold", 6, 3)
	check("precondition: both stand in the cloud", air.in_miasma(bunny.x, bunny.y)
		and air.in_miasma(breather.x, breather.y))
	var bunny_hp := bunny.hp
	var breather_hp := breather.hp
	for i in 3:
		air._breathe(bunny)
		air._breathe(breather)
	check("the rabbit breathes it unharmed", bunny.hp == bunny_hp and bunny.poisoned == 0)
	check("the kobold is poisoned and hurt (the premise)",
		breather.hp < breather_hp and breather.poisoned > 0)
	var g := GameState.new(9393)
	g.new_game()
	g.depth = 7
	g.build_level()
	var o := Vector2i(g.player.x, g.player.y)
	for dy in range(-6, 7):
		for dx in range(-9, 10):
			g.map.set_tile(o.x + dx, o.y + dy, Tiles.FLOOR)
	g.entities = [g.player]
	g.bodies = []
	g.pathfinder = Pathfinder.new(g.map)
	var purple := o + Vector2i(1, 0)
	g._set_fungus(purple, Tiles.FUNGUS_PURPLE)
	check("beside purple is in the cloud; two away is not",
		g.in_miasma(o.x, o.y) and not g.in_miasma(o.x - 1, o.y))
	g.player.hp = g.player.max_hp
	g._breathe(g.player)
	check("breathing it poisons and bites once",
		g.player.poisoned == GameState.POISON_LINGER - 1
		and g.player.hp == g.player.max_hp - GameState.POISON_HURT)
	# Out of the cloud: it lingers, then passes.
	g.player.x -= 3
	var hp_left := g.player.hp
	for i in 5:
		g._breathe(g.player)
	check("out of the cloud it lingers its turns, then passes",
		g.player.poisoned == 0 and g.player.hp == hp_left - (GameState.POISON_LINGER - 1),
		"%d -> %d" % [hp_left, g.player.hp])
	g.player.x += 3
	# A monster in the cloud: poisoned, and killed by it with a body left.
	var kob := GameState.monster_from(_bestiary_entry("kobold"), o.x + 1, o.y + 1)
	kob.alertness = Entity.Alert.AWAKE
	kob.hp = 1
	g.entities = [g.player, kob]
	g._grow_fungus()
	check("a monster breathing it dies of it, leaving a body",
		not kob.alive and g.bodies.size() == 1)
	# It is air: a bat above the fungus is spared the ground, not the cloud.
	var bat := GameState.monster_from(_bestiary_entry("cave bat"), o.x + 1, o.y - 1)
	g.entities = [g.player, bat]
	var bat_hp := bat.hp
	g._grow_fungus()
	check("a bat breathes it too", bat.poisoned > 0 and bat.hp == bat_hp - GameState.POISON_HURT)
	# The player's turn: poison can kill, and says so.
	g.entities = [g.player]
	g.player.hp = 1
	g._end_player_turn()
	check("the miasma can kill you, and the morgue says how",
		g.game_over and g.death_cause == "poisoned by the miasma")
	check("poison is saved with the creature", Entity.from_dict(bat.to_dict()).poisoned == bat.poisoned)
	# The cloud the views tint: the purple's eight neighbours, and it follows
	# the fungus -- burn it and the cloud goes with it.
	var cloud := g.miasma_cloud()
	check("the cloud covers the squares round the purple",
		cloud.has(purple + Vector2i(1, 1)) and cloud.has(purple + Vector2i(-1, 0))
		and not cloud.has(purple + Vector2i(2, 0)))
	g._burn_fungus(purple)
	check("and goes when the fungus burns", not g.miasma_cloud().has(purple + Vector2i(1, 1)))

## WATER CLEANSES (Brad, 2026-10-01): a living thing in water loses the
## spores it carries and the purple's poison; a risen does not; and wading is
## loud enough for the blind risen to hear, never loud enough for a grave.
func _test_water_cleanses() -> void:
	var gs := _arena(21, 11)
	gs.player.x = 3
	gs.player.y = 4
	gs.torch_lit = false
	for y in range(3, 10):
		gs.map.set_tile(10, y, Tiles.WATER)
	gs.update_vision()
	var said := func() -> String:
		var all := ""
		for line in gs.msg_log.entries:
			all += str(line["text"]) + "|"
		return all

	# A marked, poisoned rat: dry, it keeps both; in the water, it loses both,
	# and the poison does not bite on the turn it is washed off.
	var rat := _spawn(gs, "giant rat", 9, 6)
	rat.alertness = Entity.Alert.ASLEEP
	rat.take_spores(&"red")
	rat.poisoned = 2
	check("precondition: the rat carries the red and is poisoned",
		rat.spores == &"red" and rat.poisoned == 2)
	gs._grow_fungus()
	check("on dry ground the mark stays and the poison bites",
		rat.spores == &"red" and rat.poisoned == 1)
	rat.x = 10
	var rat_hp := rat.hp
	# The torch is out for the noise checks below; the log line wants the
	# rat in view.
	gs.map.set_all_visible()
	gs._grow_fungus()
	check("in water the rat loses its spores and its poison",
		rat.spores == &"" and rat.poisoned == 0)
	check("and the poison did not bite that turn", rat.hp == rat_hp)
	check("and the log says what the water took",
		said.call().contains("takes the red off the giant rat"), said.call())

	# A risen is a dead thing: the red has it, whichever way it got up.
	var fungal := _spawn(gs, "kobold", 10, 7)
	fungal.alertness = Entity.Alert.ASLEEP
	fungal.faction = Entity.Faction.RISEN
	fungal.fungal = true
	fungal.take_spores(&"red")
	var dug := _spawn(gs, "orc", 10, 8)
	dug.alertness = Entity.Alert.ASLEEP
	dug.faction = Entity.Faction.PLAYER
	dug.risen = true
	dug.take_spores(&"red")
	# A bat is OVER the water, not in it.
	var bat := _spawn(gs, "cave bat", 10, 3)
	bat.alertness = Entity.Alert.ASLEEP
	bat.take_spores(&"purple")
	check("precondition: all three stand in water, marked",
		gs.map.get_tile(fungal.x, fungal.y) == Tiles.WATER
		and gs.map.get_tile(dug.x, dug.y) == Tiles.WATER
		and gs.map.get_tile(bat.x, bat.y) == Tiles.WATER and bat.flying
		and fungal.spores == &"red" and dug.spores == &"red" and bat.spores == &"purple")
	gs._grow_fungus()
	check("the red's risen keeps its spores in water", fungal.spores == &"red")
	check("so does one dug from a grave", dug.spores == &"red")
	check("and a bat over the water is not washed", bat.spores == &"purple")

	# The player: wading ends the poison at once, before it bites.
	gs.entities = [gs.player, fungal]
	gs.player.x = 9
	gs.player.y = 5
	gs.player.poisoned = 2
	var hp := gs.player.hp
	gs.player_move(1, 0)
	check("precondition: the player is standing in water",
		gs.map.get_tile(gs.player.x, gs.player.y) == Tiles.WATER)
	check("wading ends the player's poison without a last bite",
		gs.player.poisoned == 0 and gs.player.hp == hp,
		"poisoned %d, hp %d -> %d" % [gs.player.poisoned, hp, gs.player.hp])
	check("and says so", said.call().contains("washes the poison off you"))
	# The trade: the splash reaches the risen, two squares off.
	check("the risen heard the splash", fungal.heard == Vector2i(gs.player.x, gs.player.y),
		str(fungal.heard))

	# Beside the purple, a pool keeps nothing off you: breathed again.
	gs._set_fungus(Vector2i(11, 5), Tiles.FUNGUS_PURPLE)
	check("precondition: the pool square is in the cloud",
		gs.in_miasma(gs.player.x, gs.player.y))
	gs._end_player_turn()
	check("in a pool beside the purple you breathe it again", gs.player.poisoned > 0)
	gs._burn_fungus(Vector2i(11, 5))

	# The noise itself: loud enough to carry, under a fight and under a grave.
	check("wading is a noise", Tiles.noise_radius(Tiles.WATER) == Tiles.WADING_NOISE
		and Tiles.WADING_NOISE > 0)
	check("quieter than a fight, and never a grave-raiser",
		Tiles.WADING_NOISE < GameState.COMBAT_NOISE
		and Tiles.WADING_NOISE < GameState.GRAVE_ROUSING)
	var near := _spawn(gs, "orc", 10 + Tiles.WADING_NOISE, 9)
	var far := _spawn(gs, "orc", 10 + Tiles.WADING_NOISE + 1, 9)
	near.alertness = Entity.Alert.ASLEEP
	far.alertness = Entity.Alert.ASLEEP
	gs.player.x = 10
	gs.player.y = 8
	gs.player.poisoned = 0
	gs.player_move(0, 1)
	check("precondition: still wading", gs.map.get_tile(gs.player.x, gs.player.y) == Tiles.WATER
		and gs.player.y == 9)
	check("a sleeper at the edge of the splash wakes", near.alertness == Entity.Alert.AWAKE)
	check("one square further sleeps on", far.alertness == Entity.Alert.ASLEEP)
	# Dry again: a step on floor makes no noise at all.
	var third := _spawn(gs, "orc", 9 + Tiles.WADING_NOISE, 2)
	third.alertness = Entity.Alert.ASLEEP
	gs.player.x = 8
	gs.player.y = 2
	gs.player_move(1, 0)
	check("and a step on plain floor beside it is silent", third.alertness == Entity.Alert.ASLEEP)

## Kills a creature and settles its death, as a blow would. `_settle_death`
## alone handles what FOLLOWS a death and leaves the creature alive -- a test
## "corpse" made with it stood up and hit the player for 7 (2026-10-01).
func _kill(gs: GameState, victim: Entity, killer: Entity) -> void:
	victim.take_damage(victim.hp)
	gs._settle_death(victim, killer)

## THE RED RAISES THE DEAD (strand 4): claimed bodies rise on a timer that
## grows with size, held to their room until the gong; fire stops them; the
## second death is the last.
func _test_the_red_raises_the_dead() -> void:
	var g := GameState.new(9494)
	g.new_game()
	g.depth = 7
	g.build_level()
	# Centred on the map, not on wherever this seed starts you: the start
	# moved to the map's left edge when the warren joined the fortress's
	# vaults (2026-10-07; it was (21, 22), now (5, 8)), and the rot cell at
	# the end of this test fell off the map.
	g.player.x = g.map.width / 2
	g.player.y = g.map.height / 2
	var o := Vector2i(g.player.x, g.player.y)
	for dy in range(-6, 7):
		for dx in range(-9, 10):
			g.map.set_tile(o.x + dx, o.y + dy, Tiles.FLOOR)
	g.entities = [g.player]
	g.bodies = []
	g.recent_dead = []
	var room := Rect2i(o.x - 3, o.y - 3, 7, 7)
	g.room_rects = [room]
	g.vault_rects = []
	g.pathfinder = Pathfinder.new(g.map)
	g._gather_lights()
	g.update_vision()

	# Who the red can raise: the living and skeletons; not the other undead,
	# not the golem.
	var kinds := {"kobold": true, "skeleton": true, "wight": false, "stone golem": false}
	for name in kinds:
		var m := GameState.monster_from(_bestiary_entry(name), o.x + 2, o.y)
		check("the red %s %s" % ["can raise a" if kinds[name] else "cannot raise a", name],
			g._can_rise(m) == kinds[name])

	# A red-marked kobold dies: red under it, claimed, a timer by its size.
	var kob := GameState.monster_from(_bestiary_entry("kobold"), o.x + 2, o.y)
	kob.spores = &"red"
	kob.inventory.append(Item.make(&"meat"))
	g.entities = [g.player, kob]
	_kill(g, kob, kob)
	var at := Vector2i(o.x + 2, o.y)
	check("a red-marked death is claimed, with red under it",
		g.bodies.size() == 1 and bool(g.bodies[0]["claimed"])
		and g.map.get_tile(at.x, at.y) == Tiles.FUNGUS_RED)
	var rises := int(g.bodies[0]["rises"])
	check("it rises RISE_BASE + its max hp turns later",
		rises == g.turns + GameState.RISE_BASE + kob.max_hp, "%d" % rises)
	# A red-marked wight: red grows, nothing is claimed.
	var wight := GameState.monster_from(_bestiary_entry("wight"), o.x - 2, o.y)
	wight.spores = &"red"
	g.entities = [g.player, wight]
	_kill(g, wight, wight)
	check("a wight's body gets red under it but is never claimed",
		g.map.get_tile(o.x - 2, o.y) == Tiles.FUNGUS_RED
		and not bool(g.bodies[1]["claimed"]) and bool(g.bodies[1]["still"]))
	g.bodies.pop_back()
	g.recent_dead.pop_back()
	g.entities = [g.player]
	check("precondition: the shovel remembers the kobold", g.recent_dead.size() == 1)

	# Claimed bodies do not rot while they wait.
	var t0 := g.turns
	g.turns = t0 + GameState.BODY_ROT + 1
	g._rot_bodies()
	check("a claimed body does not rot away", g.bodies.size() == 1)
	g.turns = t0

	# Before its time, nothing; at the warning, a stir; then it gets up.
	g._raise_the_red()
	check("before its time it lies still",
		g.bodies.size() == 1 and g.entities.size() == 1)
	g.turns = rises - GameState.RISE_WARNING
	g._raise_the_red()
	check("a few turns before, a body you can see stirs",
		g.bodies.size() == 1 and bool(g.bodies[0].get("stirred", false)))
	g.turns = rises
	var sitter := GameState.monster_from(_bestiary_entry("giant rat"), at.x, at.y)
	g.entities = [g.player, sitter]
	g._raise_the_red()
	check("something standing on it holds it down", g.bodies.size() == 1)
	g.entities = [g.player]
	g._raise_the_red()
	check("then it rises, and the body is gone",
		g.bodies.is_empty() and g.entities.size() == 2)
	var risen: Entity = g.entities[1]
	check("the risen kobold is the kobold, on no one's side",
		risen.name == "risen kobold" and risen.faction == Entity.Faction.RISEN
		and risen.fungal and risen.spores == &"red"
		and risen.hostile_to(g.player) and risen.hostile_to(sitter))
	check("at half its hp, hitting half as hard again",
		risen.max_hp == maxi(1, kob.max_hp / 2) and risen.hp == risen.max_hp
		and risen.power == ceili(kob.power * GameState.RISEN_HITS),
		"hp %d power %d" % [risen.max_hp, risen.power])
	check("held to the room it rose in", risen.leash == room)
	check("what rose, the shovel cannot also dig up", g.recent_dead.is_empty())
	var back := Entity.from_dict(risen.to_dict())
	check("and all of that is saved",
		back.fungal and back.leash == room and back.faction == Entity.Faction.RISEN)
	# It STANDS THERE. Dying drops `blocks` with `alive`, and the body's record
	# is taken after; the first risen were walked through, by the player and
	# by everything else, and could not be bumped (Brad, 2026-10-01).
	check("precondition: the cell beside it is open and the risen is where it rose",
		g.entity_at(at.x, at.y) == risen and g.entity_at(at.x - 1, at.y) == null)
	g.player.x = at.x - 1
	g.player.y = at.y
	# Enough hp to take the blow: a risen kobold has 3, and a hit is 1 at least.
	risen.max_hp = 30
	risen.hp = 30
	var acted := g.player_move(1, 0)
	check("it blocks: walking into it is a bump that lands, not a step through it",
		acted and g.player.x == at.x - 1 and risen.alive and risen.hp < 30
		and g.entity_at(at.x, at.y) == risen,
		"player at %d (cell %d), risen hp 30 -> %d" % [g.player.x, at.x, risen.hp])

	# It walks the red unharmed.
	var hp_before := risen.hp
	g._grow_fungus()
	check("it stands in the red without hurt", risen.alive and risen.hp == hp_before)

	# THE ROOM. Just outside it, close enough to hear: it stays. At its edge:
	# it comes to the edge and no further. The gong: it follows you out.
	g.player.x = o.x + 5
	g.player.y = o.y
	risen.x = o.x + 3
	risen.y = o.y
	g._gather_lights()
	g.update_vision()
	check("precondition: it hears you out there", g._risen_perceives(risen, g.player))
	g._take_ai_turn(risen)
	check("you outside its room: it does not come", risen.x == o.x + 3)
	g.player.x = o.x + 4
	risen.x = o.x + 1
	for i in 4:
		g._take_ai_turn(risen)
	check("you at its edge: it comes to the edge (and must)",
		risen.x == o.x + 3 and risen.is_adjacent(g.player), "x %d" % (risen.x - o.x))
	g.player.x = o.x + 6
	for i in 3:
		g._take_ai_turn(risen)
	check("you step back out: it stays in", risen.x == o.x + 3)
	g._invoke_shrine(Shrines.VIGIL)
	check("the gong frees it", not risen.leash.has_area())
	g._take_ai_turn(risen)
	check("and it follows you out", risen.x == o.x + 4)

	# BLIND (Brad: sound over sight). A risen kobold in the room, you lit
	# across it: unseen. Within earshot: found.
	var blind := GameState.monster_from(_bestiary_entry("kobold"), o.x - 2, o.y)
	blind.faction = Entity.Faction.RISEN
	blind.fungal = true
	blind.leash = room
	g.entities = [g.player, blind]
	g.player.x = o.x + 2
	g.player.y = o.y
	g._gather_lights()
	g.update_vision()
	check("a risen kobold does not see you across its room, lit or not",
		not g._risen_perceives(blind, g.player))
	g.player.x = o.x + 1
	check("but hears you within three (and must)", g._risen_perceives(blind, g.player))
	# The ring: a rat makes no footsteps, not even brushing past.
	var prev: Variant = g.player.equipped.get(Item.Slot.WEAPON, null)
	var ring := Item.make(&"rat_ring")
	g.give_item(ring)
	g.player.equipped[Item.Slot.WEAPON] = ring
	check("precondition: you are a rat", g.ratted())
	check("a ring-rat within earshot goes unheard", not g._risen_perceives(blind, g.player))
	g.player.x = o.x - 1
	check("even brushing past it", not g._risen_perceives(blind, g.player))
	# Noise gives it away: it turns to the sound, and finds the rat there.
	g._make_noise(Vector2i(g.player.x, g.player.y), GameState.COMBAT_NOISE, &"combat")
	check("a noise in its room is heard, where it was",
		blind.heard == Vector2i(g.player.x, g.player.y))
	check("and at the sound, a ring-rat is caught", g._risen_perceives(blind, g.player))
	check("what it heard is saved", Entity.from_dict(blind.to_dict()).heard == blind.heard)
	blind.heard = Vector2i(-1, -1)
	g._make_noise(Vector2i(o.x + 8, o.y), 12, &"combat")
	check("a noise outside its room is not its business", blind.heard.x < 0)
	# A risen skeleton keeps its eyes, and the ring does not fool it.
	var bones := GameState.monster_from(_bestiary_entry("skeleton"), o.x - 3, o.y + 2)
	bones.faction = Entity.Faction.RISEN
	bones.fungal = true
	bones.leash = room
	g.player.x = o.x + 1
	g.entities = [g.player, blind, bones]
	check("a risen skeleton sees the ring-rat across the room",
		g._risen_perceives(bones, g.player) and not g._risen_perceives(blind, g.player))
	# The red and its carriers: a real rat is never hunted, and never bitten.
	var carrier := GameState.monster_from(_bestiary_entry("giant rat"), blind.x + 1, blind.y)
	check("a real rat beside it is let be", not g._risen_perceives(blind, carrier))
	g._set_fungus(Vector2i(o.x - 1, o.y + 3), Tiles.FUNGUS_RED)
	carrier.x = o.x - 1
	carrier.y = o.y + 3
	var gob2 := GameState.monster_from(_bestiary_entry("goblin"), o.x - 1, o.y + 3)
	g.entities = [g.player, gob2]
	var gob_hp := gob2.hp
	g._grow_fungus()
	check("precondition: the red bites a goblin", gob2.hp < gob_hp)
	g.entities = [g.player, carrier]
	var rat_hp := carrier.hp
	g._grow_fungus()
	check("but only marks a rat", carrier.hp == rat_hp and carrier.spores == &"red")
	var my_hp := g.player.hp
	g._fungus_underfoot(Tiles.FUNGUS_RED)
	check("nor bites a ring-rat", g.player.hp == my_hp)
	g.player.equipped.erase(Item.Slot.WEAPON)
	if prev != null:
		g.player.equipped[Item.Slot.WEAPON] = prev
	g._fungus_underfoot(Tiles.FUNGUS_RED)
	check("and you, yourself again, it bites", g.player.hp < my_hp)
	g.entities = [g.player, risen]

	# The snowball: what it hits carries the red, and wakes to it, not you.
	var gob := GameState.monster_from(_bestiary_entry("goblin"), risen.x, risen.y + 1)
	gob.alertness = Entity.Alert.ASLEEP
	g.entities = [g.player, risen, gob]
	check("precondition: the goblin is unmarked", gob.spores == &"")
	g._attack(risen, gob)
	check("a risen hit marks its victim red and wakes it toward the risen",
		gob.spores == &"red" and gob.alertness == Entity.Alert.AWAKE
		and gob.last_seen == Vector2i(risen.x, risen.y))

	# The second death is the last: nothing dropped, no body to raise, no dig.
	risen.inventory.append(Item.make(&"meat"))
	var r_at := Vector2i(risen.x, risen.y)
	var ground_before := g.items_at(r_at.x, r_at.y).size()
	g.bodies = []
	_kill(g, risen, g.player)
	check("a risen dies for good: its body is never claimed",
		g.bodies.size() == 1 and not bool(g.bodies[0]["claimed"])
		and bool(g.bodies[0]["still"]))
	check("it drops nothing a second time",
		g.items_at(r_at.x, r_at.y).size() == ground_before)
	check("and the shovel cannot have it", g.recent_dead.is_empty())

	# The crawl claims a body it reaches, and puts red under it; not a still one.
	g.bodies = []
	var goner := GameState.monster_from(_bestiary_entry("goblin"), o.x - 2, o.y + 2)
	g.entities = [g.player, goner]
	_kill(g, goner, goner)
	check("precondition: an unmarked body is unclaimed",
		g.bodies.size() == 1 and not bool(g.bodies[0]["claimed"]))
	g._set_fungus(Vector2i(o.x - 3, o.y + 2), Tiles.FUNGUS_RED)
	g._crawl_red()
	check("red beside a body claims it, grows under it and starts its clock",
		bool(g.bodies[0]["claimed"]) and int(g.bodies[0]["rises"]) > g.turns
		and g.map.get_tile(o.x - 2, o.y + 2) == Tiles.FUNGUS_RED)
	# Fire: burn the red it lies in and the body burns with it.
	g._burn_fungus(Vector2i(o.x - 2, o.y + 2))
	check("burning the red it lies in burns the body", g.bodies.is_empty())

	# The tell keeps its promise: a purple-marked body rots PURPLE, even where
	# the floor's table leans red; an unmarked one rolls the table.
	var rot_at := Vector2i(o.x - 6, o.y - 5)
	check("precondition: the rot cell is on the map", g.map.in_bounds(rot_at.x, rot_at.y))
	g.entities = [g.player]
	g.turns += 100  # "seeded ROOT turns ago" must not be a negative turn
	var rotted := {"purple": [], "plain": []}
	for kind in ["purple", "plain"]:
		for i in 12:
			g.bodies = [{"x": rot_at.x, "y": rot_at.y, "app": "kobold", "turn": g.turns,
				"corrupted": kind == "purple", "e": {"name": "kobold",
				"spores": "purple" if kind == "purple" else ""},
				"seeded": g.turns - GameState.FUNGUS_ROOT, "claimed": false}]
			g._grow_fungus()
			rotted[kind].append(g.map.get_tile(rot_at.x, rot_at.y))
			g._set_fungus(rot_at, Tiles.FLOOR)
	check("unmarked bodies roll the table: some rot red here (the premise)",
		rotted["plain"].has(Tiles.FUNGUS_RED))
	check("a purple-marked body always rots purple",
		rotted["purple"].count(Tiles.FUNGUS_PURPLE) == 12, str(rotted["purple"]))

## FIRE RELIGHTS A COLD BRAZIER (Brad, 2026-09-30): a gem of fire for a big
## fire, a fire weapon's fire (not the weapon) for an ordinary one.
func _test_fire_relights_braziers() -> void:
	var gs := _arena(12, 9)
	gs.player.x = 5
	gs.player.y = 4
	var br := Vector2i(6, 4)
	gs.map.set_tile(br.x, br.y, Tiles.BRAZIER_DEAD)
	gs.player.equipped.erase(Item.Slot.WEAPON)
	gs.player.inventory.clear()
	var offers := func() -> String:
		var words := ""
		for a in gs.actions_here():
			words += String(a[1]) + "|"
		return words
	# Nothing to give: G refuses and spends nothing; the box offers nothing.
	check("no fire, no relight", not gs.player_pickup()
		and gs.map.get_tile(br.x, br.y) == Tiles.BRAZIER_DEAD
		and not offers.call().contains("relight"))
	# A gem of fire: crushed in, a big fire.
	var gem := Item.make(&"gem_fire")
	gs.give_item(gem)
	check("the box offers the gem", offers.call().contains("relight with the gem of fire (15)"),
		offers.call())
	check("a gem of fire relights a black brazier (and must)", gs.player_pickup()
		and gs.map.get_tile(br.x, br.y) == Tiles.BRAZIER
		and int(gs.brazier_charge[br]) == GameState.GEM_KINDLE)
	check("and the gem is gone", not gs.player.inventory.has(gem))
	# A fire blade in hand, with a gem in the pack too: the blade goes first,
	# gives its fire, and is kept.
	gs.map.set_tile(br.x, br.y, Tiles.BRAZIER_SPENT)
	gs.ember_until[br] = gs.turns + 10
	var blade := Item.make(&"short_sword")
	blade.element = &"fire"
	gs.give_item(blade)
	gs.player.equipped[Item.Slot.WEAPON] = blade
	var spare := Item.make(&"gem_fire")
	gs.give_item(spare)
	check("the box offers the blade's fire", offers.call().contains("short sword's fire (10)"),
		offers.call())
	gs.player_pickup()
	check("a fire blade relights a guttered brazier to an ordinary fire",
		gs.map.get_tile(br.x, br.y) == Tiles.BRAZIER
		and int(gs.brazier_charge[br]) == GameState.BLADE_KINDLE
		and not gs.ember_until.has(br))
	check("the blade is kept, plain, and can take another stone",
		gs.player.inventory.has(blade) and blade.element == &""
		and not blade.display_name().contains("fire"))
	check("the gem in the pack was not spent", gs.player.inventory.has(spare))
	# A lit brazier wants nothing.
	check("a lit brazier is not offered a relight", not offers.call().contains("relight"))
	# The red first: with fungus beside you and fire in hand, G burns the
	# fungus and the brazier stays cold.
	gs.map.set_tile(br.x, br.y, Tiles.BRAZIER_DEAD)
	blade.element = &"fire"
	gs.pathfinder = Pathfinder.new(gs.map)
	gs._set_fungus(Vector2i(4, 4), Tiles.FUNGUS_RED)
	gs.player.facing = Vector2i(-1, 0)
	gs.player_pickup()
	check("fungus beside you is burned before any fire is spent",
		gs.map.get_tile(4, 4) != Tiles.FUNGUS_RED
		and gs.map.get_tile(br.x, br.y) == Tiles.BRAZIER_DEAD and blade.element == &"fire")

## GEMS FEED THE UNIQUES (6c): the ring goes cold at 0 and the shovel dull
## after a raise, and a gem at the embers brings either back. With the gaps
## found designing it: one second life per body, shared by shovel and red; a
## raised creature drops nothing; the shovel takes the red off what it raises.
func _test_gems_feed_the_uniques() -> void:
	var gs := _arena(14, 9)
	gs.player.x = 5
	gs.player.y = 4
	gs.player.inventory.clear()
	gs.player.equipped.clear()
	# THE RING GOES COLD, NOT GONE.
	var ring := Item.make(&"rat_ring")
	gs.give_item(ring)
	# Putting it on takes a turn, and a turn as a rat burns a charge.
	ring.charges = 5
	check("precondition: a warm ring makes you a rat",
		gs.player_use(gs.player.inventory.find(ring)) and gs.ratted())
	ring.charges = 1
	gs._burn_the_ring()
	check("at 0 the ring goes cold: you are yourself, and you keep it",
		not gs.ratted() and gs.player.inventory.has(ring) and ring.charges == 0
		and not gs.player.is_equipped(ring))
	check("a cold ring will not go on",
		not gs.player_use(gs.player.inventory.find(ring)) and not gs.ratted())
	var panel := InventoryPanel.new()
	panel.state = gs
	check("the pack says what it wants", panel._action_hint(ring).begins_with("cold"),
		panel._action_hint(ring))
	# FED AT THE EMBERS.
	var br := Vector2i(6, 4)
	gs.map.set_tile(br.x, br.y, Tiles.BRAZIER_SPENT)
	gs.ember_until[br] = gs.turns + 10
	var frost := Item.make(&"gem_frost")
	gs.give_item(frost)
	check("a gem asks for the cold ring at the embers", gs.can_bind_gem(frost)
		and panel._action_hint(frost) == "feed the ring", panel._action_hint(frost))
	check("a gem feeds the cold ring (and must)",
		gs.player_bind(gs.player.inventory.find(frost))
		and ring.charges == GameState.RING_FEED and not gs.player.inventory.has(frost))
	check("and the embers are spent, as any setting spends them",
		gs.map.get_tile(br.x, br.y) == Tiles.BRAZIER_DEAD)
	check("a warmed ring goes on again",
		gs.player_use(gs.player.inventory.find(ring)) and gs.ratted())
	gs.player.equipped.erase(Item.Slot.WEAPON)
	# Up to full, and no further; a full ring takes nothing.
	ring.charges = GameState.RING_FULL - 10
	gs.map.set_tile(br.x, br.y, Tiles.BRAZIER_SPENT)
	gs.ember_until[br] = gs.turns + 10
	var crag := Item.make(&"gem_crag")
	gs.give_item(crag)
	gs.player_bind(gs.player.inventory.find(crag), gs.player.inventory.find(ring))
	check("feeding stops at the ring's full", ring.charges == GameState.RING_FULL)
	check("a full ring takes no gem", not gs.can_feed(ring))
	# Gear that can still take the stone comes first; a set one gives way.
	ring.charges = 0
	var dagger := Item.make(&"dagger")
	gs.give_item(dagger)
	gs.player.equipped[Item.Slot.WEAPON] = dagger
	var fire := Item.make(&"gem_fire")
	gs.give_item(fire)
	check("an unset blade in hand is asked first", gs._gem_host(fire) == dagger)
	dagger.element = &"frost"
	check("a set blade gives way to the cold ring", gs._gem_host(fire) == ring)

	# THE SHOVEL GOES DULL, NOT GONE -- and what it raises is clean.
	var dig := _arena(30, 14)
	dig.player.x = 6
	dig.player.y = 7
	var shovel := Item.make(&"shovel")
	dig.give_item(shovel)
	var kob := _spawn(dig, "kobold", 7, 7)
	kob.spores = &"red"
	_kill(dig, kob, dig.player)
	check("precondition: a red kill lies claimed",
		dig.bodies.size() == 1 and bool(dig.bodies[0]["claimed"]))
	check("the shovel raises it (and must)",
		dig.player_use(dig.player.inventory.find(shovel)))
	var ally: Entity = null
	for e in dig.entities:
		if e.faction == Entity.Faction.PLAYER and not e.is_player:
			ally = e
	check("an ally stands there, and the claimed body is gone",
		ally != null and dig.bodies.is_empty())
	if ally != null:
		check("taken from the red: no spores on it", ally.spores == &"")
		check("one second life: the red will never raise it", ally.raised
			and not dig._can_rise(ally))
		var at := Vector2i(ally.x, ally.y)
		var before := dig.items_at(at.x, at.y).size()
		ally.equipped[Item.Slot.WEAPON] = Item.make(&"short_sword")
		dig._drop_loot(ally)
		check("and it drops nothing when it falls (its gear dropped already)",
			dig.items_at(at.x, at.y).size() == before)
	# Precondition for that: an ally NOT raised (a grave's bone ally) hands
	# back what it carries -- that kit is the only copy.
	var bone := _spawn(dig, "goblin", 10, 7)
	bone.faction = Entity.Faction.PLAYER
	bone.equipped[Item.Slot.WEAPON] = Item.make(&"short_sword")
	dig._drop_loot(bone)
	check("a bone ally still hands its kit back (and must)",
		dig.items_at(10, 7).size() > 0)
	check("the shovel is kept, and dull", dig.player.inventory.has(shovel) and shovel.dull)
	var gob := _spawn(dig, "goblin", 5, 7)
	_kill(dig, gob, dig.player)
	var crowd := dig.entities.size()
	check("a dull shovel raises nothing, and is not lost for trying",
		not dig.player_use(dig.player.inventory.find(shovel))
		and dig.entities.size() == crowd and dig.player.inventory.has(shovel))
	var hearth := Vector2i(6, 8)
	dig.map.set_tile(hearth.x, hearth.y, Tiles.BRAZIER_SPENT)
	dig.ember_until[hearth] = dig.turns + 10
	var whet := Item.make(&"gem_crag")
	dig.give_item(whet)
	check("a gem at the embers sharpens it",
		dig.player_bind(dig.player.inventory.find(whet), dig.player.inventory.find(shovel))
		and not shovel.dull)
	# Old saves.
	check("a shovel saved before dullness existed is sharp",
		not Item.from_dict({"id": "shovel", "charges": 0}).dull)
	var old := kob.to_dict()
	old.erase("raised")
	old["fungal"] = true
	check("a red risen saved before `raised` existed reads as raised",
		Entity.from_dict(old).raised)

## BURYING (Brad, 2026-10-01): the shovel puts a claimed body under before it
## rises, loudly, and the red's chain withers back to its source.
func _test_burying_and_the_red_withering() -> void:
	var gs := _arena(24, 12)
	gs.player.x = 10
	gs.player.y = 6
	gs.player.inventory.clear()
	gs.player.equipped.clear()
	gs.bodies = []
	gs.torch_lit = true
	var source := Vector2i(4, 6)
	gs._set_fungus(source, Tiles.FUNGUS_RED)
	var gob := _spawn(gs, "goblin", 9, 6)
	_kill(gs, gob, gob)
	for i in 6:
		gs._crawl_red()
	check("precondition: the crawl claimed the body and kept its chain",
		gs.bodies.size() == 1 and bool(gs.bodies[0]["claimed"])
		and gs.red_from.size() == 5 and gs.red_from.get(Vector2i(9, 6)) == Vector2i(8, 6),
		str(gs.red_from))
	check("no shovel, nothing to bury", gs.bury_target().is_empty())
	var shovel := Item.make(&"shovel")
	shovel.dull = true
	gs.give_item(shovel)
	check("even a dull shovel offers the claimed body beside you",
		not gs.bury_target().is_empty())
	var offered := ""
	for a in gs.actions_here():
		offered += String(a[1]) + "|"
	check("and the box says so", offered.contains("bury the goblin"), offered)
	gs.events.clear()
	gs.player_pickup()
	check("G digs rather than scorching with the torch",
		gs.bodies.size() == 1 and int(gs.bodies[0].get("dug", 0)) == 1
		and gs.map.get_tile(9, 6) == Tiles.FUNGUS_RED and not gs.scorched.has("9,6"))
	var dug_loud := false
	for ev in gs.events:
		if ev.get("kind") == &"noise" and ev.get("cause") == &"dig":
			dug_loud = true
	check("and it is loud", dug_loud)
	gs.player_pickup()
	gs.player_pickup()
	check("three spadefuls and it is under", gs.bodies.is_empty())
	# Withering: tip first, back to the source, which stays.
	gs._wither_red()
	check("the chain dies back from the tip",
		gs.map.get_tile(9, 6) != Tiles.FUNGUS_RED and gs.map.get_tile(5, 6) == Tiles.FUNGUS_RED)
	for i in 6:
		gs._wither_red()
	var gone := true
	for x in range(5, 10):
		if gs.map.get_tile(x, 6) == Tiles.FUNGUS_RED:
			gone = false
	check("all the way back", gone and gs.withering.is_empty() and gs.red_from.is_empty())
	check("but the source it grew from stays", gs.map.get_tile(source.x, source.y) == Tiles.FUNGUS_RED)
	# Another body in reach: the red turns to it instead of withering.
	gs.red_from = {Vector2i(5, 6): source}
	gs._red_loses(Vector2i(5, 6))
	check("precondition: with nothing else to take, it withers", gs.withering.size() == 1)
	gs.withering = []
	gs.bodies = [{"x": 7, "y": 6, "app": "rat", "turn": gs.turns, "corrupted": false,
		"e": {"name": "giant rat"}, "seeded": -1, "claimed": false}]
	gs._red_loses(Vector2i(5, 6))
	check("with another body in reach, it does not", gs.withering.is_empty())
	# Saved.
	gs.withering = [[Vector2i(5, 6)]]
	var back := GameState.new(1)
	back.apply_dict(JSON.parse_string(JSON.stringify(gs.to_dict())))
	check("the chains and the withering survive a save",
		back.red_from.get(Vector2i(5, 6)) == source
		and back.withering.size() == 1 and back.withering[0][0] == Vector2i(5, 6))
	# A fire blade burns before the shovel digs: one stroke beats three.
	gs.bodies = []
	gs.red_from = {}
	var kob := _spawn(gs, "kobold", 9, 6)
	kob.spores = &"red"
	_kill(gs, kob, kob)
	var blade := Item.make(&"short_sword")
	blade.element = &"fire"
	gs.give_item(blade)
	gs.player.equipped[Item.Slot.WEAPON] = blade
	check("precondition: a claimed body beside you, and a shovel",
		not gs.bury_target().is_empty())
	gs.player_pickup()
	check("fire in hand: G burns it, body and all", gs.bodies.is_empty()
		and gs.map.get_tile(9, 6) != Tiles.FUNGUS_RED)

## THE GEM OF THIRST (6d): crushed on a body, it drinks it for you.
func _test_the_gem_of_thirst() -> void:
	var gs := _arena(14, 9)
	gs.player.x = 5
	gs.player.y = 4
	gs.player.inventory.clear()
	gs.bodies = []
	var gem := Item.make(&"gem_leech")
	gs.give_item(gem)
	gs.player.hp = gs.player.max_hp - 500
	check("no body: refused, and the gem is kept",
		not gs.player_use(gs.player.inventory.find(gem)) and gs.player.inventory.has(gem))
	var troll := _spawn(gs, "cave troll", 6, 4)
	_kill(gs, troll, troll)
	var panel := InventoryPanel.new()
	panel.state = gs
	check("the pack offers the drink", panel._action_hint(gem).begins_with("drink the cave troll"),
		panel._action_hint(gem))
	var hp := gs.player.hp
	check("crushed beside a body, it drinks it (and must)",
		gs.player_use(gs.player.inventory.find(gem))
		and gs.player.hp == hp + maxi(1, troll.max_hp / GameState.THIRST_SHARE))
	check("the body and the gem are gone", gs.bodies.is_empty()
		and not gs.player.inventory.has(gem))
	# Whole: refused for a plain body, allowed for a claimed one -- denying the
	# red is the point.
	gs.player.hp = gs.player.max_hp
	var gem2 := Item.make(&"gem_leech")
	gs.give_item(gem2)
	var kob := _spawn(gs, "kobold", 4, 4)
	_kill(gs, kob, kob)
	check("whole, a plain body is not worth the gem",
		not gs.player_use(gs.player.inventory.find(gem2)) and gs.bodies.size() == 1)
	# And nothing OFFERS it either (day-7 hunt, 2026-10-04: the pack said
	# "drink the kobold" here while the key refused). The body must still be
	# there, or "nothing offered" is true of an empty floor: with the gate
	# broken, the key above drinks it and this passed on nothing.
	check("whole, beside a plain body, neither the pack nor the HERE box offers it",
		gs.bodies.size() == 1 and not panel._action_hint(gem2).begins_with("drink")
			and gs.gem_use_here(gem2) == "",
		"pack '%s' / here '%s'" % [panel._action_hint(gem2), gs.gem_use_here(gem2)])
	# Whole, a claimed body beside a RICHER plain one: the claimed one is the
	# drink -- it used to pick the richer, refuse, and never offer the other.
	var red_rat := _spawn(gs, "giant rat", 6, 5)
	red_rat.spores = &"red"
	_kill(gs, red_rat, red_rat)
	check("precondition: a plain kobold and a claimed rat, both in reach",
		gs.bodies.size() == 2 and gs.thirst_target().get("app", &"") == &"rat",
		str(gs.thirst_target().get("app", "none")))
	check("whole, the claimed one is offered and drunk; the plain one stays",
		panel._action_hint(gem2).begins_with("drink the")
		and gs.player_use(gs.player.inventory.find(gem2)) and gs.bodies.size() == 1
		and not bool(gs.bodies[0].get("claimed", false)),
		panel._action_hint(gem2))
	gem2 = Item.make(&"gem_leech")
	gs.give_item(gem2)
	gs.bodies = []
	var red_kob := _spawn(gs, "kobold", 4, 5)
	red_kob.spores = &"red"
	_kill(gs, red_kob, red_kob)
	check("precondition: that one is claimed", bool(gs.bodies[0]["claimed"]))
	check("whole, a claimed body is still drunk: the red loses it",
		gs.player_use(gs.player.inventory.find(gem2)) and gs.bodies.is_empty())
	# Any other gem, clicked, says where gems go instead of doing nothing.
	var frost := Item.make(&"gem_frost")
	gs.give_item(frost)
	check("another gem is not used up by a click",
		not gs.player_use(gs.player.inventory.find(frost)) and gs.player.inventory.has(frost))

## A BONE ALLY CAN CATCH THE RED (Brad, 2026-10-01): a risen's blows mark it;
## if it falls marked, it rises against you -- and the log says so, with what
## stops it.
func _test_a_bone_ally_can_carry_the_red() -> void:
	var gs := _arena(20, 9)
	gs.player.x = 5
	gs.player.y = 4
	gs.player.inventory.clear()
	gs.bodies = []
	var bone := Item.make(&"bone")
	bone.bone_name = "Erdrick"
	bone.bone_level = 6
	check("precondition: the bone raises an ally", gs._summon_ally(bone))
	var ally: Entity = null
	for e in gs.entities:
		if e.appearance == &"bone_ally":
			ally = e
	check("and it is the bone ally", ally != null)
	if ally == null:
		return
	var said := func() -> String:
		var all := ""
		for line in gs.msg_log.entries:
			all += str(line) + "|"
		return all
	gs._warn_of_red_allies()
	check("an unmarked ally draws no warning", not said.call().contains("laid claim"))
	# A risen's blow marks it.
	var zombie := _spawn(gs, "kobold", ally.x + 1, ally.y)
	zombie.fungal = true
	zombie.faction = Entity.Faction.RISEN
	gs._attack(zombie, ally)
	check("a risen's blow marks the ally red", ally.spores == &"red")
	check("and the log says who it hit -- not \"hits you\"",
		said.call().contains("The kobold hits Erdrick for")
		and not said.call().contains("hits you"), said.call())
	gs._warn_of_red_allies()
	check("and the log says so, with what stops it (no shovel: fire)",
		said.call().contains("laid claim to Erdrick")
		and said.call().contains("Fire can burn the body"), said.call())
	var before: int = gs.msg_log.entries.size()
	gs._warn_of_red_allies()
	check("once", gs.msg_log.entries.size() == before)
	check("the warning is kept with a save", Entity.from_dict(ally.to_dict()).red_warned)
	# It falls: claimed, and told how long and what to do.
	gs.give_item(Item.make(&"shovel"))
	gs.entities.erase(zombie)
	_kill(gs, ally, ally)
	check("a marked bone ally falls claimed",
		gs.bodies.size() == 1 and bool(gs.bodies[0]["claimed"]))
	check("a hero dies by name, not \"The Erdrick\"",
		said.call().contains("Erdrick dies.") and not said.call().contains("The Erdrick"),
		said.call())
	check("the log says when it rises, and to bury it",
		said.call().contains("Erdrick falls, and the red takes them")
		and said.call().contains("Bury them with the shovel"), said.call())
	# Left alone, it rises against you.
	gs.turns = int(gs.bodies[0]["rises"])
	gs._raise_the_red()
	var turned: Entity = null
	for e in gs.entities:
		if e.faction == Entity.Faction.RISEN and e.name == "risen Erdrick":
			turned = e
	check("left alone, Erdrick rises against you",
		turned != null and turned.hostile_to(gs.player))

## THE UNDERTAKER'S PAY (Gabe, 2026-10-01): graves dug for the red's dead --
## claimed bodies and fallen risen -- count on the shovel; five sharpen it.
func _test_the_undertakers_pay() -> void:
	var gs := _arena(16, 9)
	gs.player.x = 5
	gs.player.y = 4
	gs.player.inventory.clear()
	gs.bodies = []
	var shovel := Item.make(&"shovel")
	shovel.dull = true
	gs.give_item(shovel)
	var panel := InventoryPanel.new()
	panel.state = gs
	check("the pack names both roads back",
		panel._action_hint(shovel) == "dull: a gem, or 5 more red graves", panel._action_hint(shovel))
	# An ordinary body can be buried (2026-10-04: the rats will not have it)
	# but earns nothing: there is no red to deny.
	gs.bodies = [{"x": 6, "y": 4, "app": "goblin", "turn": gs.turns, "corrupted": false,
		"e": {"name": "goblin"}, "seeded": -1, "claimed": false}]
	check("a plain body is offered for burial", not gs.bury_target().is_empty())
	for spade in GameState.BURY_SPADEFULS:
		gs.player_pickup()
	check("  and buried: gone, for the rats and the fungus both", gs.bodies.is_empty()
		and _log_says(gs, "The rats will not have it"))
	check("  but it pays nothing toward the edge", shovel.dull and shovel.laid_to_rest == 0)
	# The red's dead come first when both lie in reach.
	gs.bodies = [{"x": 6, "y": 4, "app": "goblin", "turn": gs.turns, "corrupted": false,
		"e": {"name": "goblin"}, "seeded": -1, "claimed": false},
		{"x": 4, "y": 4, "app": "kobold", "turn": gs.turns, "corrupted": false,
		"e": {"name": "risen kobold", "fungal": true}, "seeded": -1, "claimed": false}]
	check("with a plain body and the red's dead both in reach, the red's dead is dug first",
		String(gs.bury_target()["e"]["name"]) == "risen kobold")
	gs.bodies = []
	# Five fallen risen beside you, buried one after another.
	for i in GameState.BURIALS_TO_SHARPEN:
		gs.bodies = [{"x": 6, "y": 4, "app": "kobold", "turn": gs.turns, "corrupted": false,
			"e": {"name": "risen kobold", "fungal": true}, "seeded": -1, "claimed": false,
			"still": true}]
		check("precondition: a fallen risen is offered for burial (%d)" % (i + 1),
			not gs.bury_target().is_empty())
		for spade in GameState.BURY_SPADEFULS:
			gs.player_pickup()
		check("and buried (%d)" % (i + 1), gs.bodies.is_empty())
		if i < GameState.BURIALS_TO_SHARPEN - 1:
			check("still dull, counting (%d)" % (i + 1),
				shovel.dull and shovel.laid_to_rest == i + 1)
	check("five graves sharpen the shovel (and must)",
		not shovel.dull and shovel.laid_to_rest == 0)
	# Sharp, the count waits at five -- and pays for the next raise at once.
	shovel.laid_to_rest = GameState.BURIALS_TO_SHARPEN - 1
	gs.bodies = [{"x": 6, "y": 4, "app": "kobold", "turn": gs.turns, "corrupted": false,
		"e": {"name": "risen kobold", "fungal": true}, "seeded": -1, "claimed": false}]
	for spade in GameState.BURY_SPADEFULS:
		gs.player_pickup()
	check("a sharp shovel's count holds at five", not shovel.dull
		and shovel.laid_to_rest == GameState.BURIALS_TO_SHARPEN)
	var kob := _spawn(gs, "kobold", 4, 4)
	_kill(gs, kob, gs.player)
	check("precondition: the shovel raises", gs.player_use(gs.player.inventory.find(shovel)))
	check("and the banked graves keep its edge", not shovel.dull and shovel.laid_to_rest == 0)
	check("the count survives a save",
		Item.from_dict({"id": "shovel", "laid_to_rest": 3}).laid_to_rest == 3)

## GEMS IN THE WORLD (6d): the boss gem thrown as a decoy crash, the mirror
## gem naming a shrine.
func _test_gems_in_the_world() -> void:
	# THE BOSS: a crash where it lands.
	var gs := _arena(26, 12)
	gs.player.x = 4
	gs.player.y = 6
	gs.player.inventory.clear()
	var boss := Item.make(&"gem_boss")
	gs.give_item(boss)
	check("the gem of the boss can be thrown", boss.is_throwable()
		and gs.throwables().has(boss))
	var dagger := Item.make(&"dagger")
	gs.give_item(dagger)
	var crash := Vector2i(12, 6)
	check("precondition: an ordinary throw wants a target",
		not gs.player_throw(gs.player.inventory.find(dagger), crash)
		and gs.player.inventory.has(dagger))
	# Too far: refused, and kept.
	check("out of reach it is refused and kept",
		not gs.player_throw(gs.player.inventory.find(boss), Vector2i(20, 6))
		and gs.player.inventory.has(boss))
	# A sleeper near the crash, far from you; a hunter that lost you; a free
	# risen -- all too far from you to find you again this turn.
	var sleeper := _spawn(gs, "kobold", 22, 8)
	sleeper.alertness = Entity.Alert.ASLEEP
	var hunter := _spawn(gs, "goblin", 22, 6)
	hunter.alertness = Entity.Alert.AWAKE
	hunter.last_seen = Vector2i(gs.player.x, gs.player.y)
	hunter.lost_turns = 2
	var risen := _spawn(gs, "kobold", 20, 4)
	risen.faction = Entity.Faction.RISEN
	risen.fungal = true
	var turn := gs.turns
	check("thrown at an empty square, it goes (and must)",
		gs.player_throw(gs.player.inventory.find(boss), crash) and gs.turns == turn + 1)
	check("the gem is gone, and nothing lies there",
		not gs.player.inventory.has(boss) and gs.items_at(crash.x, crash.y).is_empty())
	check("a sleeper wakes and turns to the crash",
		sleeper.alertness == Entity.Alert.AWAKE and sleeper.last_seen == crash)
	check("a hunter that lost you goes to the crash instead", hunter.last_seen == crash)
	check("a risen heard it", risen.heard == crash)
	var said := ""
	for line in gs.msg_log.entries:
		said += str(line) + "|"
	check("and the log counts the fooled", said.contains("1 thing hunting you goes to the sound"),
		said)

	# THE MIRROR: a shrine shown for what it is.
	var ms := _arena(12, 9)
	ms.player.x = 5
	ms.player.y = 4
	ms.player.inventory.clear()
	var here := Vector2i(5, 4)
	var mirror := Item.make(&"gem_mirror")
	ms.give_item(mirror)
	check("off a shrine the mirror is refused and kept",
		not ms.player_use(ms.player.inventory.find(mirror)) and ms.player.inventory.has(mirror))
	ms.map.set_tile(here.x, here.y, Tiles.SHRINE)
	ms.shrine_at[here] = Shrines.VIGIL
	ms.shrine_known.clear()
	check("precondition: the shrine is unfamiliar", ms.shrine_label(Shrines.VIGIL)
		== "an unfamiliar shrine" and ms.mirror_target() == Shrines.VIGIL)
	var panel := InventoryPanel.new()
	panel.state = ms
	check("the pack offers to name it", panel._action_hint(mirror) == "name the shrine",
		panel._action_hint(mirror))
	check("on it, the mirror names the shrine (and must)",
		ms.player_use(ms.player.inventory.find(mirror)) and ms.shrine_known.has(Shrines.VIGIL)
		and ms.shrine_label(Shrines.VIGIL) == "shrine of the vigil")
	check("the gem is spent; the shrine is not",
		not ms.player.inventory.has(mirror) and ms.map.get_tile(here.x, here.y) == Tiles.SHRINE
		and ms.shrine_at.has(here))

	# THE CRAG: stone into a pit beside you.
	var cs := _arena(12, 9)
	cs.player.x = 5
	cs.player.y = 4
	cs.player.inventory.clear()
	var crag := Item.make(&"gem_crag")
	cs.give_item(crag)
	check("with no pit beside you the crag is refused and kept",
		not cs.player_use(cs.player.inventory.find(crag)) and cs.player.inventory.has(crag)
		and cs.crag_target().x < 0)
	var hole := Vector2i(6, 4)
	cs.map.set_tile(hole.x, hole.y, Tiles.PIT)
	cs.pathfinder.refresh(cs.map)
	check("precondition: a pit is never routed to",
		cs.pathfinder.path(Vector2i(5, 4), hole).is_empty() and cs.crag_target() == hole)
	var cp := InventoryPanel.new()
	cp.state = cs
	check("the pack offers to fill it", cp._action_hint(crag) == "fill the pit", cp._action_hint(crag))
	var ct := cs.turns
	check("used, the pit is floor (and must)",
		cs.player_use(cs.player.inventory.find(crag))
		and Tiles.is_open_floor(cs.map.get_tile(hole.x, hole.y)) and cs.turns == ct + 1)
	check("the gem is spent and the way is open",
		not cs.player.inventory.has(crag) and not cs.pathfinder.path(Vector2i(5, 4), hole).is_empty())

	# THE BULWARK: a barred door.
	check("the barred door is appended after every older tile (saves hold ints)",
		Tiles.DOOR_BARRED > Tiles.FUNGUS_RED and Tiles.is_walkable(Tiles.DOOR_BARRED)
		and not Tiles.is_transparent(Tiles.DOOR_BARRED))
	var bs := _arena(14, 9)
	bs.player.x = 5
	bs.player.y = 4
	bs.player.inventory.clear()
	var bulwark := Item.make(&"gem_bulwark")
	bs.give_item(bulwark)
	check("with no door beside you the bulwark is refused and kept",
		not bs.player_use(bs.player.inventory.find(bulwark)) and bs.player.inventory.has(bulwark)
		and bs.bulwark_target().x < 0)
	for y in range(1, 8):
		bs.map.set_tile(6, y, Tiles.WALL)
	var door := Vector2i(6, 4)
	bs.map.set_tile(door.x, door.y, Tiles.DOOR_OPEN)
	bs.pathfinder.refresh(bs.map)
	var kob := _spawn(bs, "kobold", door.x, door.y)
	check("a doorway with something standing in it cannot be barred",
		not bs.player_use(bs.player.inventory.find(bulwark)) and bs.player.inventory.has(bulwark))
	kob.x = 9
	kob.y = 4
	var bp := InventoryPanel.new()
	bp.state = bs
	check("the pack offers to bar it", bp._action_hint(bulwark) == "bar the door",
		bp._action_hint(bulwark))
	var bt := bs.turns
	check("used, the door is barred (and must)",
		bs.player_use(bs.player.inventory.find(bulwark))
		and bs.map.get_tile(door.x, door.y) == Tiles.DOOR_BARRED
		and int(bs.barred.get(door, 0)) == GameState.BAR_HOLDS and bs.turns == bt + 1
		and not bs.player.inventory.has(bulwark))
	# A kobold opens doors; against the bar it heaves, and the bar counts.
	kob.patrols = true
	kob.heavy = false
	check("precondition: a kobold opens doors", kob.door_style() == Entity.Door.OPENS)
	kob.x = 7
	kob.y = 4
	check("it heaves at the bar and the door holds",
		bs._through_the_door(kob, door) and bs.map.get_tile(door.x, door.y) == Tiles.DOOR_BARRED
		and int(bs.barred[door]) == GameState.BAR_HOLDS - 1)
	for i in GameState.BAR_HOLDS - 1:
		bs._through_the_door(kob, door)
	check("after BAR_HOLDS heaves the bar gives and the door is open",
		bs.map.get_tile(door.x, door.y) == Tiles.DOOR_OPEN and not bs.barred.has(door))
	# Barred again: a bear takes it off its hinges, bar and all.
	bs.map.set_tile(door.x, door.y, Tiles.DOOR_BARRED)
	bs.barred[door] = GameState.BAR_HOLDS
	kob.heavy = true
	check("precondition: heavy shoulders doors", kob.door_style() == Entity.Door.SHOULDERS)
	check("a bear goes through it: the door is gone",
		bs._through_the_door(kob, door) and Tiles.is_open_floor(bs.map.get_tile(door.x, door.y))
		and not bs.barred.has(door))
	# Barred again: you lift the bar yourself, and it is spent.
	bs.map.set_tile(door.x, door.y, Tiles.DOOR_BARRED)
	bs.barred[door] = 3
	kob.x = 11
	check("walking into it, you lift the bar and the door opens",
		bs.player_move(1, 0) and bs.map.get_tile(door.x, door.y) == Tiles.DOOR_OPEN
		and not bs.barred.has(door) and bs.player.x == 5)
	# Barred, saved and restored.
	bs.map.set_tile(door.x, door.y, Tiles.DOOR_BARRED)
	bs.barred[door] = 3
	var saved := GameState.new(1)
	saved.new_game()
	check("the bar is saved with the floor",
		saved.apply_dict(bs.to_dict()) and saved.map.get_tile(door.x, door.y) == Tiles.DOOR_BARRED
		and int(saved.barred.get(door, 0)) == 3)

	# THE ROAD: the way out, on the map.
	var rs := _arena(20, 10)
	rs.player.x = 3
	rs.player.y = 5
	rs.player.inventory.clear()
	rs.stairs = Vector2i(17, 5)
	rs.map.set_tile(17, 5, Tiles.STAIRS_DOWN)
	rs.map.explored.fill(0)
	var road := Item.make(&"gem_travel")
	rs.give_item(road)
	var rp := InventoryPanel.new()
	rp.state = rs
	check("the pack offers the way out", rp._action_hint(road) == "show the way out",
		rp._action_hint(road))
	check("precondition: no route is shown and the stairs are unseen",
		rs.road_route().is_empty() and not rs.map.is_explored(17, 5))
	check("used, the route to the stairs is shown, stairs and all (and must)",
		rs.player_use(rs.player.inventory.find(road)) and rs.road_shown
		and not rs.road_route().is_empty() and rs.road_route()[-1] == rs.stairs
		and rs.map.is_explored(17, 5) and not rs.player.inventory.has(road))
	var road2 := Item.make(&"gem_travel")
	rs.give_item(road2)
	check("a second is refused and kept", not rs.player_use(rs.player.inventory.find(road2))
		and rs.player.inventory.has(road2) and rp._action_hint(road2) != "show the way out")
	var rsaved := GameState.new(1)
	rsaved.new_game()
	check("the road is saved", rsaved.apply_dict(rs.to_dict()) and rsaved.road_shown)
	rs.depth += 1
	rs.build_level()
	check("a new floor starts without it", not rs.road_shown and rs.road_route().is_empty())

	# RETURNING: a fire marked, and the step back to it.
	var ts := _arena(20, 10)
	ts.player.x = 3
	ts.player.y = 5
	ts.player.inventory.clear()
	var back1 := Item.make(&"gem_return")
	ts.give_item(back1)
	check("with no fire beside you and no mark, returning is refused and kept",
		not ts.player_use(ts.player.inventory.find(back1)) and ts.player.inventory.has(back1)
		and ts.return_target() == &"")
	ts.map.set_tile(4, 5, Tiles.BRAZIER)
	var tp := InventoryPanel.new()
	tp.state = ts
	check("beside a brazier the pack offers to mark it",
		tp._action_hint(back1) == "mark this brazier", tp._action_hint(back1))
	check("used, the fire is marked (and must)",
		ts.player_use(ts.player.inventory.find(back1)) and ts.recall_mark == Vector2i(4, 5)
		and not ts.player.inventory.has(back1))
	var back2 := Item.make(&"gem_return")
	ts.give_item(back2)
	check("beside the mark a second is refused: you are there already",
		not ts.player_use(ts.player.inventory.find(back2)) and ts.player.inventory.has(back2)
		and tp._action_hint(back2) != "return to the fire")
	ts.player.x = 15
	ts.player.y = 7
	check("far from it the pack offers the way back",
		tp._action_hint(back2) == "return to the fire", tp._action_hint(back2))
	var tt := ts.turns
	check("used, you stand by the fire again and the mark is spent",
		ts.player_use(ts.player.inventory.find(back2))
		and maxi(absi(ts.player.x - 4), absi(ts.player.y - 5)) == 1
		and ts.recall_mark.x < 0 and ts.turns == tt + 1 and not ts.player.inventory.has(back2),
		"player at %d,%d" % [ts.player.x, ts.player.y])
	ts.recall_mark = Vector2i(4, 5)
	var tsaved := GameState.new(1)
	tsaved.new_game()
	check("the mark is saved", tsaved.apply_dict(ts.to_dict()) and tsaved.recall_mark == Vector2i(4, 5))

	# FROST: the frozen room.
	var fs := _arena(22, 12)
	fs.player.x = 3
	fs.player.y = 6
	fs.player.inventory.clear()
	# The room is the left part of the arena, two doors in its east wall.
	var cold_room := Rect2i(1, 1, 12, 10)
	fs.room_rects = [cold_room]
	fs.vault_rects = []
	fs.map.set_tile(13, 6, Tiles.DOOR_OPEN)
	fs.map.set_tile(13, 3, Tiles.DOOR_CLOSED)
	var frost := Item.make(&"gem_frost")
	fs.give_item(frost)
	check("the gem of frost can be thrown", frost.is_throwable() and fs.throwables().has(frost))
	check("from the pack it only says so",
		not fs.player_use(fs.player.inventory.find(frost)) and fs.player.inventory.has(frost))
	var inside := _spawn(fs, "kobold", 8, 6)
	var cold_risen := _spawn(fs, "kobold", 11, 4)
	cold_risen.faction = Entity.Faction.RISEN
	cold_risen.fungal = true
	var cold_ally := _spawn(fs, "kobold", 4, 7)
	cold_ally.faction = Entity.Faction.PLAYER
	var outside := _spawn(fs, "goblin", 17, 6)
	outside.alertness = Entity.Alert.ASLEEP
	var ft := fs.turns
	check("thrown into the room, it freezes what stands in it, not you, not outside (and must)",
		fs.player_throw(fs.player.inventory.find(frost), Vector2i(7, 6))
		and inside.frozen >= 9 and cold_risen.frozen >= 9 and cold_ally.frozen >= 9
		and fs.player.frozen == 0 and outside.frozen == 0 and fs.turns == ft + 1
		and not fs.player.inventory.has(frost),
		"frozen %d %d %d / %d" % [inside.frozen, cold_risen.frozen, cold_ally.frozen, outside.frozen])
	check("for the room's longer side less its doors (12 - 2)",
		fs.frozen_rooms.size() == 1 and fs.frozen_rooms[0][0] == cold_room
		and int(fs.frozen_rooms[0][1]) == ft + 10, str(fs.frozen_rooms))
	check("a frozen thing wears the cold and its count over its head",
		CreatureMarks.awareness(inside)["text"].begins_with("✶"))
	var stood := Vector2i(inside.x, inside.y)
	var left := inside.frozen
	fs._take_ai_turn(inside)
	check("its own turn: it stands where it is, and thaws nothing",
		Vector2i(inside.x, inside.y) == stood and inside.frozen == left)
	fs._thaw_rooms()
	check("your turn thaws it by one", inside.frozen == left - 1)
	# In YOUR turns whatever its speed (Brad, 2026-10-04). Counted on its own,
	# a fast thing was free early and a slow one outlived the room's silence.
	# The fast one is given two turns to each of yours, the slow one one.
	var quick := _spawn(fs, "kobold", 9, 8)
	quick.speed = 170
	quick.frozen = 3
	var plodder := _spawn(fs, "kobold", 10, 8)
	plodder.speed = 70
	plodder.frozen = 3
	for _t in 2:
		fs._take_ai_turn(quick)
		fs._take_ai_turn(quick)
		fs._take_ai_turn(plodder)
		fs._thaw_rooms()
	check("a fast thing and a slow one, frozen together, thaw together (%d, %d)"
		% [quick.frozen, plodder.frozen], quick.frozen == 1 and plodder.frozen == 1)
	outside.alertness = Entity.Alert.ASLEEP
	fs._make_noise(Vector2i(5, 6), 20, &"crash")
	check("noise made in the frozen room carries nowhere",
		outside.alertness == Entity.Alert.ASLEEP and cold_risen.heard != Vector2i(5, 6))
	fs._make_noise(Vector2i(17, 8), 20, &"crash")
	check("outside it sound carries -- but not to the frozen",
		outside.alertness == Entity.Alert.AWAKE and cold_risen.heard != Vector2i(17, 8))
	fs.turns = ft + 10
	fs._thaw_rooms()
	check("when its turns are up the room's silence ends", fs.frozen_rooms.is_empty())
	fs.frozen_rooms = [[cold_room, fs.turns + 5]]
	inside.frozen = 4
	var fsaved := GameState.new(1)
	fsaved.new_game()
	var kept_cold := false
	if fsaved.apply_dict(fs.to_dict()):
		for e in fsaved.entities:
			kept_cold = kept_cold or e.frozen == 4
	check("the cold is saved, room and creature",
		kept_cold and fsaved.frozen_rooms.size() == 1 and fsaved.frozen_rooms[0][0] == cold_room)

	# THE VEIL: in armour, the light on you counts less; crushed, every hunter
	# loses you -- but not the thing beside you.
	check("the veil and the lantern are armour's stones, found magic's too",
		Item.ELEMENTS[&"veil"]["hosts"] == &"armour" and Item.ELEMENTS[&"lantern"]["hosts"] == &"armour"
		and Item.found_elements().has(&"veil") and Item.found_elements().has(&"lantern")
		and Item.make(&"chain_mail").accepts_element(&"veil"))
	var vs := _arena(21, 9)
	vs.player.x = 5
	vs.player.y = 4
	vs.player.inventory.clear()
	vs.torch_lit = true
	vs._gather_lights()
	vs.update_vision()
	var plain := vs._light_on_you()
	var veil_mail := Item.make(&"chain_mail")
	veil_mail.element = &"veil"
	vs.give_item(veil_mail)
	vs._toggle_equip(veil_mail)
	check("veiled, the light on you counts %.0f%% of itself (%.2f -> %.2f)"
		% [GameState.VEIL_LIGHT * 100.0, plain, vs._light_on_you()],
		plain > 0.0 and is_equal_approx(vs._light_on_you(), plain * GameState.VEIL_LIGHT))
	vs._toggle_equip(veil_mail)
	var far_hunter := _spawn(vs, "kobold", 12, 4)
	far_hunter.last_seen = Vector2i(5, 4)
	var near_hunter := _spawn(vs, "goblin", 6, 4)
	near_hunter.last_seen = Vector2i(5, 4)
	var veil := Item.make(&"gem_veil")
	vs.give_item(veil)
	var vp := InventoryPanel.new()
	vp.state = vs
	check("hunted, the pack and the HERE box offer the veil",
		vp._action_hint(veil) == "vanish from the hunt" and vs.gem_use_here(veil) == "veil: lose every hunter",
		vp._action_hint(veil))
	var vt := vs.turns
	var hunted := vs._hunters().size()
	var veiled := vs.player_use(vs.player.inventory.find(veil))
	check("crushed, the far hunter loses the thread; the one beside you does not (and must)",
		veiled and far_hunter.alertness == Entity.Alert.SUSPICIOUS and far_hunter.last_seen.x < 0
		and far_hunter.notice_block > 0 and near_hunter.alertness == Entity.Alert.AWAKE
		and not vs.player.inventory.has(veil) and vs.turns == vt + 1,
		"hunted %d used %s far alert %d seen %s block %d near alert %d turns %d/%d" % [hunted, veiled,
			far_hunter.alertness, far_hunter.last_seen, far_hunter.notice_block, near_hunter.alertness,
			vs.turns, vt + 1])
	var quiet := _arena(11, 7)
	quiet.player.inventory.clear()
	var sleeper_v := _spawn(quiet, "kobold", 8, 3)
	sleeper_v.alertness = Entity.Alert.ASLEEP
	var veil2 := Item.make(&"gem_veil")
	quiet.give_item(veil2)
	check("with nothing hunting you it is refused and kept",
		not quiet.player_use(quiet.player.inventory.find(veil2)) and quiet.player.inventory.has(veil2))

	# THE LANTERN: a cell further for the torch and for the things that see
	# you; crushed, a flare.
	var ls := _arena(21, 9)
	ls.player.x = 5
	ls.player.y = 4
	ls.player.inventory.clear()
	var watcher := _spawn(ls, "kobold", 12, 4)
	var reach0 := ls.torch_radius()
	var seen0 := ls._notice_reach(watcher)
	var lantern_mail := Item.make(&"chain_mail")
	lantern_mail.element = &"lantern"
	ls.give_item(lantern_mail)
	ls._toggle_equip(lantern_mail)
	check("the lantern in your armour: the torch reaches a cell further, and so do their eyes",
		ls.torch_radius() == reach0 + GameState.LANTERN_CELLS
		and ls._notice_reach(watcher) == seen0 + GameState.LANTERN_CELLS)
	ls._toggle_equip(lantern_mail)
	check("taken off, both are as they were", ls.torch_radius() == reach0
		and ls._notice_reach(watcher) == seen0)
	var lantern := Item.make(&"gem_lantern")
	ls.give_item(lantern)
	var lp := InventoryPanel.new()
	lp.state = ls
	check("the pack offers the flare", lp._action_hint(lantern) == "flare the torch", lp._action_hint(lantern))
	check("crushed, the torch flares (and must)",
		ls.player_use(ls.player.inventory.find(lantern)) and ls.torch_flare >= GameState.FLARE_TURNS - 1
		and ls.torch_flare > 0 and ls.torch_lit and not ls.player.inventory.has(lantern))
	var lantern2 := Item.make(&"gem_lantern")
	ls.give_item(lantern2)
	check("a second while it flares is refused and kept",
		not ls.player_use(ls.player.inventory.find(lantern2)) and ls.player.inventory.has(lantern2)
		and lp._action_hint(lantern2) != "flare the torch")
	var second := Item.make(&"gem_mirror")
	ms.give_item(second)
	check("a known shrine takes no second mirror",
		not ms.player_use(ms.player.inventory.find(second)) and ms.player.inventory.has(second)
		and panel._action_hint(second) != "name the shrine")

## A HUNTER THAT HAS LOST YOU GOES WHERE IT LAST SAW YOU (Brad, 2026-10-04).
##
## `last_seen` was written in seven places and read in none, so every awake
## thing steered by your true position, seen or not. The boss gem's checks
## asked for the field -- `hunter.last_seen == crash` -- and passed while the
## goblin walked straight at you. So every check here takes a STEP and asks
## which way it went, with you and the mark on opposite sides of it.
func _test_a_lost_hunter_goes_where_it_last_saw_you() -> void:
	# A noise to the east; you far to the west, out of its sight.
	var gs := _arena(30, 14)
	gs.player.x = 2
	gs.player.y = 1
	var orc := _spawn(gs, "orc", 22, 10)
	orc.alertness = Entity.Alert.ASLEEP
	gs._make_noise(Vector2i(27, 10), 8, &"trap")
	check("precondition: the noise wakes it and marks where it was",
		orc.alertness == Entity.Alert.AWAKE and orc.last_seen == Vector2i(27, 10))
	gs._take_ai_turn(orc)
	check("precondition: it cannot see you (%d turns lost)" % orc.lost_turns, orc.lost_turns > 0)
	check("woken by a noise, it goes to the noise, not to you (%s)" % Vector2i(orc.x, orc.y),
		orc.x == 23 and orc.y == 10)
	for _t in 6:
		gs._take_ai_turn(orc)
	check("and once there it stands, still hunting (%s, %d lost)"
		% [Vector2i(orc.x, orc.y), orc.lost_turns],
		Vector2i(orc.x, orc.y) == Vector2i(27, 10) and orc.alertness == Entity.Alert.AWAKE)
	# A sight of you moves the mark, and the hunt is on you again.
	gs.player.x = 20
	gs.player.y = 6
	gs._take_ai_turn(orc)
	check("seen again, the mark is you (%s)" % orc.last_seen,
		orc.last_seen == Vector2i(20, 6) and orc.lost_turns == 0)
	check("and it comes for you (%s)" % Vector2i(orc.x, orc.y),
		Los.steps(orc.x, orc.y, 20, 6) < Los.steps(27, 10, 20, 6))

	# THE BOSS GEM'S DECOY, thrown for real at a hunter that has lost you.
	var ds := _arena(30, 14)
	ds.player.x = 4
	ds.player.y = 2
	ds.player.inventory.clear()
	var boss := Item.make(&"gem_boss")
	ds.give_item(boss)
	# An orc, not the goblin of the probe: a lone goblin hangs back about half
	# its turns, and this is about the way it goes, not its nerve.
	var decoyed := _spawn(ds, "orc", 22, 10)
	decoyed.last_seen = Vector2i(4, 2)
	decoyed.lost_turns = 2
	check("precondition: the crash is thrown",
		ds.player_throw(ds.player.inventory.find(boss), Vector2i(12, 10)))
	# The throw's own turn moves it too, so this asks the way, not the cell:
	# along row 10 to the crash -- toward you would climb toward row 2.
	ds._take_ai_turn(decoyed)
	check("a hunter that lost you walks to the crash, not to you (%s)" % Vector2i(decoyed.x, decoyed.y),
		decoyed.x < 22 and decoyed.y == 10)

	# Only WHERE it goes changed, not what it is: a lone goblin that has lost
	# you still hangs back about half its turns, as _ai_pack has it do in
	# sight. Its mark is far off, so it never arrives in these eight turns,
	# and it starts one turn lost so it stays on the trail throughout.
	var shy := _spawn(ds, "goblin", 27, 4)
	shy.last_seen = Vector2i(27, 12)
	var shy_moves := 0
	for _t in 8:
		shy.lost_turns = 1
		var shy_was := Vector2i(shy.x, shy.y)
		ds._take_ai_turn(shy)
		if Vector2i(shy.x, shy.y) != shy_was:
			shy_moves += 1
	check("a lone goblin on your trail still hangs back some turns (%d of 8 moved)" % shy_moves,
		shy_moves > 0 and shy_moves < 8)

	# With no mark at all it stands. (Walking "to" (-1, -1) would find no
	# route either -- this pins the standing, not the guard.)
	var blank := _spawn(ds, "orc", 22, 3)
	blank.last_seen = Vector2i(-1, -1)
	blank.lost_turns = 2
	ds._take_ai_turn(blank)
	check("with no mark at all it stands where it is",
		Vector2i(blank.x, blank.y) == Vector2i(22, 3) and blank.lost_turns > 0)

	# What senses life never needed to see you: it still comes for YOU.
	var wail := _spawn(ds, "banshee", 22, 12)
	wail.wail_cool = 5
	wail.last_seen = Vector2i(28, 12)
	wail.lost_turns = 2
	var wail_was := Los.steps(wail.x, wail.y, 4, 2)
	ds._take_ai_turn(wail)
	check("precondition: the banshee has lost sight of you too", wail.lost_turns > 0)
	check("but it senses life, and comes for you (%d -> %d)"
		% [wail_was, Los.steps(wail.x, wail.y, 4, 2)], Los.steps(wail.x, wail.y, 4, 2) < wail_was)

	# And a rabbit is no hunter: its "foe" is what it runs from. The monsters
	# leave first: since 2026-10-04 a rabbit fears monsters too, and this is
	# about the trail, not about them.
	ds.entities = [ds.player]
	var bun := _spawn(ds, "rabbit", 25, 7)
	ds.map.set_tile(28, 7, Tiles.FUNGUS)
	bun.last_seen = Vector2i(21, 7)
	bun.lost_turns = 2
	ds._take_ai_turn(bun)
	check("precondition: lost as well", bun.lost_turns > 0)
	check("a rabbit goes to its supper, not down your trail (%s)" % Vector2i(bun.x, bun.y),
		bun.x == 26 and bun.y == 7)

	# Something it can SEE beats a memory (Brad, 2026-10-04): a hunter that
	# has lost you turns on your ally in view rather than walk your trail.
	# YOU must be the nearer, behind a wall: with the ally nearer, `_foe_for`
	# already picked it and the LOST step never ran -- the first version of
	# this check put the ally beside it and passed with the change undone.
	var vs := _arena(30, 14)
	for wy in [9, 10, 11]:
		vs.map.set_tile(21, wy, Tiles.WALL)
	vs.pathfinder = Pathfinder.new(vs.map)
	vs.player.x = 20
	vs.player.y = 10
	var hunter := _spawn(vs, "orc", 22, 10)
	hunter.last_seen = Vector2i(27, 10)
	hunter.lost_turns = 2
	var friend := _spawn(vs, "kobold", 22, 7)
	friend.faction = Entity.Faction.PLAYER
	# And in LIGHT: past arm's length a living thing sees only what is lit
	# (`_can_see`), and the first rebuild left the ally in the dark.
	vs.map.set_tile(23, 6, Tiles.BRAZIER)
	vs.brazier_charge = {Vector2i(23, 6): GameState.BRAZIER_CHARGE}
	vs._gather_lights()
	vs.update_vision()
	check("precondition: you are nearer than the ally, but behind the wall",
		Los.steps(22, 10, 20, 10) < Los.steps(22, 10, 22, 7)
		and not Los.clear(vs.map, 22, 10, 20, 10))
	vs._take_ai_turn(hunter)
	check("precondition: it has lost you (%d)" % hunter.lost_turns, hunter.lost_turns > 0)
	check("precondition: it can see your ally", vs._can_see(hunter, friend))
	check("so it turns on the ally it can see, not down your trail (%s)"
		% Vector2i(hunter.x, hunter.y),
		Los.steps(hunter.x, hunter.y, friend.x, friend.y) < 3 and hunter.x <= 22)

## SPREADING (Dwarf Fortress plan, strand 2b): marks, marked deaths, trails,
## and rats drawn to fresh bodies.
func _test_the_fungus_spreads() -> void:
	var g := GameState.new(9191)
	g.new_game()
	g.depth = 7
	g.build_level()
	var o := Vector2i(g.player.x, g.player.y)
	for dy in range(-6, 7):
		for dx in range(-9, 10):
			g.map.set_tile(o.x + dx, o.y + dy, Tiles.FLOOR)
	g.entities = [g.player]
	g.bodies = []
	g.pathfinder = Pathfinder.new(g.map)
	g._gather_lights()
	g.update_vision()

	var gob := GameState.monster_from(_bestiary_entry("goblin"), o.x + 3, o.y)
	g._corrupt(gob)
	check("a corrupted creature is born purple-marked (Brad's lore)", gob.spores == &"purple")
	gob.take_spores(&"red")
	gob.take_spores(&"purple")
	check("red is never downgraded to purple", gob.spores == &"red")
	check("an old save's red mark carries over",
		Entity.from_dict({"name": "rat", "app": "rat", "spore_marked": true}).spores == &"red")

	# Marked deaths take their fungus with them.
	var pur := GameState.monster_from(_bestiary_entry("kobold"), o.x + 4, o.y + 2)
	pur.take_spores(&"purple")
	pur.hp = 0
	pur.alive = false
	g._settle_death(pur, g.player)
	var pb: Dictionary = g.bodies[-1]
	check("a purple-marked body is seeded as it falls, no rat needed",
		int(pb["seeded"]) == g.turns and not bool(pb["claimed"]))
	var red := GameState.monster_from(_bestiary_entry("kobold"), o.x - 4, o.y + 2)
	red.take_spores(&"red")
	red.hp = 0
	red.alive = false
	g._settle_death(red, g.player)
	var rb: Dictionary = g.bodies[-1]
	check("a red-marked body is claimed, with red under it",
		bool(rb["claimed"]) and g.map.get_tile(red.x, red.y) == Tiles.FUNGUS_RED)
	g._burn_fungus(Vector2i(red.x, red.y))
	g.bodies = []

	# Trails: only an awake, marked walker leaves them.
	var walker := GameState.monster_from(_bestiary_entry("kobold"), o.x + 6, o.y - 4)
	walker.alertness = Entity.Alert.AWAKE
	var plain := GameState.monster_from(_bestiary_entry("kobold"), o.x - 6, o.y - 4)
	plain.alertness = Entity.Alert.AWAKE
	var dozing := GameState.monster_from(_bestiary_entry("kobold"), o.x - 6, o.y + 4)
	dozing.take_spores(&"purple")
	g.entities = [g.player, walker, plain, dozing]
	walker.take_spores(&"purple")
	var trail := false
	for i in 400:
		g.turns += 1
		g._grow_fungus()
		if g.map.get_tile(walker.x, walker.y) == Tiles.FUNGUS_PURPLE:
			trail = true
			break
	check("a marked walker leaves its fungus behind, now and then", trail)
	check("an unmarked one never does",
		not Tiles.is_bad_fungus(g.map.get_tile(plain.x, plain.y)))
	check("nor a marked one asleep",
		not Tiles.is_bad_fungus(g.map.get_tile(dozing.x, dozing.y)))
	g._burn_fungus(Vector2i(walker.x, walker.y))

	# Rats: drawn to a fresh body, not to one already seeded.
	var rat := GameState.monster_from(_bestiary_entry("giant rat"), o.x - 7, o.y)
	g.entities = [g.player, rat]
	var body_at := o + Vector2i(-2, 0)
	g.bodies = [{"x": body_at.x, "y": body_at.y, "app": "kobold", "turn": g.turns,
		"corrupted": false, "e": {"name": "kobold"}, "seeded": -1, "claimed": false}]
	var was := Los.steps(rat.x, rat.y, body_at.x, body_at.y)
	check("a sleeping rat smells a fresh body, stirs and goes to it",
		g._rat_to_body(rat) and rat.alertness == Entity.Alert.SUSPICIOUS
		and Los.steps(rat.x, rat.y, body_at.x, body_at.y) < was)
	g.bodies[0]["seeded"] = g.turns
	check("but not to one already seeded", not g._rat_to_body(rat))

## Shooters in the dark: a margin of 2 past a full torch, none where the torch
## is cut down; and a magic shot lights the shooter (Brad, 2026-09-29, at 2 hp).
func _test_the_dark_is_fair() -> void:
	var room := GameState.new(8181)
	room.new_game()
	room.depth = 2
	room.build_level()
	check("with a full torch on a room floor, shooters keep a margin of 2",
		room.dark_shot_grace() == GameState.DARK_SHOT_GRACE)
	var climb := GameState.new(8282)
	climb.new_game()
	climb.ascending = true
	climb.depth = 5
	climb.build_level()
	check("in the climb's caves the torch is short (the premise)",
		climb.torch_radius() < GameState.TORCH_RADIUS)
	check("and there a shooter must be at the very edge of your light",
		climb.dark_shot_grace() == 0)
	climb.torch_flare = 5
	check("unless your flare is burning", climb.dark_shot_grace() == GameState.DARK_SHOT_GRACE)
	climb.torch_flare = 0
	# THE LANTERN DOES NOT BUY IT BACK (day-7 hunt, 2026-10-04): a cell more of
	# torch in the caves is still the caves. Pinned here so a tuned constant
	# cannot quietly hand the grace back.
	var lantern_mail := Item.make(&"chain_mail")
	lantern_mail.element = &"lantern"
	climb.give_item(lantern_mail)
	climb._toggle_equip(lantern_mail)
	check("precondition: the lantern lengthens the torch", climb.torch_radius()
		== GameState.CORRUPT_TORCH + GameState.LANTERN_CELLS)
	check("and in the caves the grace stays 0 with it", climb.dark_shot_grace() == 0)
	room.give_item(Item.make(&"chain_mail"))
	var up_mail: Item = room.player.inventory[-1]
	up_mail.element = &"lantern"
	room._toggle_equip(up_mail)
	check("while on a room floor the lantern keeps the full torch's margin (and must)",
		room.dark_shot_grace() == GameState.DARK_SHOT_GRACE)
	check("the dragon, wizard and arch lich cast; a slinger does not",
		GameState.monster_from(_bestiary_entry("young dragon"), 0, 0).casts
		and GameState.monster_from(_bestiary_entry("wizard"), 0, 0).casts
		and GameState.monster_from(_bestiary_entry("arch lich"), 0, 0).casts
		and not GameState.monster_from(_bestiary_entry("kobold slinger"), 0, 0).casts)

	# A flare shows the shooter across the dark. An open strip beyond the torch.
	var g := GameState.new(8383)
	g.new_game()
	g.ascending = true
	g.depth = 5
	g.build_level()
	var o := Vector2i(g.player.x, g.player.y)
	for dx in range(-1, 12):
		for dy in range(-1, 2):
			g.map.set_tile(o.x + dx, o.y + dy, Tiles.FLOOR)
	g.static_lights = []
	var far := o + Vector2i(g.torch_radius() + 4, 0)
	var dragon := GameState.monster_from(_bestiary_entry("young dragon"), far.x, far.y)
	g.entities = [g.player, dragon]
	g.update_vision()
	check("a dragon beyond your light is unseen (the premise)",
		not g.map.is_visible(far.x, far.y))
	dragon.flare_until = g.turns
	g.update_vision()
	check("its breath lights it: you see it where it stands", g.map.is_visible(far.x, far.y))
	g.turns += GameState.CAST_FLARE_TURNS + 1
	g.update_vision()
	check("and the flare dies away", not g.map.is_visible(far.x, far.y))
	check("a flare is saved with the creature",
		Entity.from_dict(dragon.to_dict()).flare_until == dragon.flare_until)

## A bestiary entry by name, for tests that want a particular creature.
func _bestiary_entry(name: String) -> Dictionary:
	for entry in GameState.BESTIARY:
		if entry["name"] == name:
			return entry
	return {}

## THE WRONG FUNGUS (Dwarf Fortress plan, strand 2): purple and red, where
## they grow, bodies taken by them, red crawling to the dead, and fire.
func _test_the_wrong_fungus() -> void:
	check("the new fungi are appended after every older tile (saves hold ints)",
		Tiles.FUNGUS_PURPLE > Tiles.CHEST and Tiles.FUNGUS_RED > Tiles.CHEST)
	check("the ground never walls it off: purple and red are bad fungus, not avoided ground",
		not Tiles.is_avoided(Tiles.FUNGUS_PURPLE) and not Tiles.is_avoided(Tiles.FUNGUS_RED)
		and Tiles.is_bad_fungus(Tiles.FUNGUS_RED) and not Tiles.is_bad_fungus(Tiles.FUNGUS))
	check("the smart kinds are careful; a kobold is not",
		GameState.monster_from(_bestiary_entry("young dragon"), 0, 0).careful
		and GameState.monster_from(_bestiary_entry("wizard"), 0, 0).careful
		and GameState.monster_from(_bestiary_entry("arch lich"), 0, 0).careful
		and not GameState.monster_from(_bestiary_entry("kobold"), 0, 0).careful)
	# Brad's table.
	check("floors 1-2 grow only green, whatever the roll",
		MapGen.fungus_for(1, 0.999) == Tiles.FUNGUS and MapGen.fungus_for(2, 0.5) == Tiles.FUNGUS)
	check("floor 3 grows purple but never red",
		MapGen.fungus_for(3, 0.9) == Tiles.FUNGUS_PURPLE and MapGen.fungus_for(3, 0.999) == Tiles.FUNGUS_PURPLE)
	check("the caves keep most of their green, with a little of each",
		MapGen.fungus_for(4, 0.69) == Tiles.FUNGUS and MapGen.fungus_for(4, 0.94) == Tiles.FUNGUS_PURPLE
		and MapGen.fungus_for(4, 0.97) == Tiles.FUNGUS_RED)
	check("floors 7-9 are mostly red", MapGen.fungus_for(8, 0.65) == Tiles.FUNGUS_RED)
	# The climb is worse than the way down, by the same floor numbers.
	var down_green := 0
	var up_green := 0
	for f in range(1, 10):
		down_green += int(MapGen.fungus_parts(f)[0])
		up_green += int(MapGen.fungus_parts(f, true)[0])
	check("the climb grows less green than the descent, floor for floor",
		up_green < down_green, "%d vs %d" % [up_green, down_green])
	check("but its caves keep real green to eat",
		int(MapGen.fungus_parts(5, true)[0]) >= 40)
	check("and the top of the climb grows the wrong fungus, where the way down had none",
		MapGen.fungus_for(1, 0.9, true) != Tiles.FUNGUS and MapGen.fungus_for(1, 0.1, true) == Tiles.FUNGUS)
	# Real floors: none on 1-2; some on the deep floors; none by a lit brazier.
	var shallow_bad := 0
	var deep_bad := 0
	var by_fire := 0
	for seed_no in 10:
		for d in [1, 2, 8, 9]:
			var gs := GameState.new(7000 + seed_no)
			gs.new_game()
			gs.depth = d
			gs.build_level()
			for y in gs.map.height:
				for x in gs.map.width:
					if Tiles.is_bad_fungus(gs.map.get_tile(x, y)):
						if d <= 2:
							shallow_bad += 1
						else:
							deep_bad += 1
						if gs._near_fire(Vector2i(x, y)):
							by_fire += 1
	check("no purple or red is generated on floors 1-2", shallow_bad == 0, "%d" % shallow_bad)
	check("floors 8-9 do generate it", deep_bad > 0, "%d" % deep_bad)
	check("and none grows beside a lit brazier", by_fire == 0, "%d" % by_fire)

	# A clean room to work in, on floor 7.
	var g := GameState.new(7171)
	g.new_game()
	g.depth = 7
	g.build_level()
	var o := Vector2i(g.player.x, g.player.y)
	for dy in range(-4, 5):
		for dx in range(-6, 7):
			g.map.set_tile(o.x + dx, o.y + dy, Tiles.FLOOR)
	g.entities = [g.player]
	g.bodies = []
	g.pathfinder = Pathfinder.new(g.map)
	g._gather_lights()
	g.update_vision()

	# Bodies: seeded by a passing rat, taken after the spores root.
	var at := o + Vector2i(3, 0)
	g.bodies = [{"x": at.x, "y": at.y, "app": "kobold", "turn": g.turns,
		"corrupted": false, "e": {"name": "kobold"}, "seeded": -1, "claimed": false}]
	var rat := GameState.monster_from(GameState.BESTIARY[0], at.x, at.y + 1)
	g.entities.append(rat)
	g._grow_fungus()
	check("a rat beside a body carries spores to it (the premise)",
		int(g.bodies[0]["seeded"]) == g.turns)
	g.entities.erase(rat)
	g.turns += GameState.FUNGUS_ROOT
	g._grow_fungus()
	var grew := g.map.get_tile(at.x, at.y)
	check("the rooted body is gone and purple or red stands there, never green",
		g.bodies.is_empty() and Tiles.is_bad_fungus(grew), Tiles.appearance_id(grew))
	g._burn_fungus(at)

	# On floor 1 a body never grows the wrong fungus.
	var one := GameState.new(7272)
	one.new_game()
	check("floor 1 grows no fungus from bodies", one._body_fungus() == -1)

	# Red crawls toward a body, one square a crawl, and claims it.
	var body_at := o + Vector2i(5, 2)
	var red_at := o + Vector2i(0, 2)
	g.bodies = [{"x": body_at.x, "y": body_at.y, "app": "goblin", "turn": g.turns,
		"corrupted": false, "e": {"name": "goblin"}, "seeded": -1, "claimed": false}]
	g._set_fungus(red_at, Tiles.FUNGUS_RED)
	g._crawl_red()
	check("red grows one square toward the body",
		g.map.get_tile(red_at.x + 1, red_at.y) == Tiles.FUNGUS_RED)
	for i in 5:
		g._crawl_red()
	check("and reaches it, claiming it", bool(g.bodies[0]["claimed"]))
	check("and grows under it (strand 4: a claimed body lies in red)",
		g.map.get_tile(body_at.x, body_at.y) == Tiles.FUNGUS_RED)
	# A cut chain: burn the links, and the crawl starts again from what is left.
	# The red under the body is cleared by hand, not burned -- burning it would
	# burn the body too.
	g.bodies[0]["claimed"] = false
	g._set_fungus(body_at, Tiles.FLOOR)
	for x in range(1, 5):
		g._burn_fungus(Vector2i(red_at.x + x, red_at.y))
	g._crawl_red()
	check("a burned chain regrows from what is left, not across the gap",
		g.map.get_tile(red_at.x + 1, red_at.y) == Tiles.FUNGUS_RED
		and g.map.get_tile(red_at.x + 2, red_at.y) != Tiles.FUNGUS_RED)
	for y in range(-4, 5):
		for x in range(-6, 7):
			if Tiles.is_bad_fungus(g.map.get_tile(o.x + x, o.y + y)):
				g._burn_fungus(o + Vector2i(x, y))
	g.bodies = []

	# Careful routes go round it; careless ones straight through.
	var wall_x := o.x + 2
	for y in range(-4, 5):
		g._set_fungus(Vector2i(wall_x, o.y + y), Tiles.FUNGUS_PURPLE)
	var from := Vector2i(o.x, o.y)
	var to := Vector2i(o.x + 4, o.y)
	var careless_route: Array = g.pathfinder.path(from, to)
	var careful_route: Array = g.pathfinder.path(from, to, true)
	check("a careless route walks straight through the purple (the premise: one exists)",
		not careless_route.is_empty() and careless_route.any(func(c): return c.x == wall_x))
	check("a careful route will not cross it", careful_route.is_empty()
		or not careful_route.any(func(c): return Tiles.is_bad_fungus(g.map.get_tile(c.x, c.y))))
	for y in range(-4, 5):
		g._burn_fungus(Vector2i(wall_x, o.y + y))

	# G burns: the one ahead first. A fire weapon in one press, a torch in
	# three. Walking into it is a CHOICE: you step on, and it hurts.
	var p_at := Vector2i(g.player.x, g.player.y)
	var purple := p_at + Vector2i(1, 0)
	var side := p_at + Vector2i(0, 1)
	g._set_fungus(purple, Tiles.FUNGUS_PURPLE)
	g._set_fungus(side, Tiles.FUNGUS_RED)
	g.player.facing = Vector2i(1, 0)
	check("G aims at the fungus ahead, not the one beside", g.burn_target() == purple)
	var sword := Item.make(&"short_sword")
	sword.element = &"fire"
	g.player.inventory = [sword]
	g.player.equipped = {Item.Slot.WEAPON: sword}
	var here_rows: Array = g.actions_here()
	check("the HERE box teaches it: G, burn the fungus",
		here_rows.any(func(r): return r[0] == KEY_G and String(r[1]) == "burn the fungus"))
	var turns_was := g.turns
	g.player_pickup()
	check("a fire blade burns it in one press of G, without a step",
		g.map.get_tile(purple.x, purple.y) != Tiles.FUNGUS_PURPLE
		and Vector2i(g.player.x, g.player.y) == p_at and g.turns == turns_was + 1)
	check("and then G turns to the one beside", g.burn_target() == side)
	g._burn_fungus(side)
	g.player.equipped = {}
	g._set_fungus(purple, Tiles.FUNGUS_PURPLE)
	g.torch_lit = true
	g.player.facing = Vector2i(1, 0)
	g.player_pickup()
	g.player_pickup()
	var after_two := g.map.get_tile(purple.x, purple.y)
	g.player_pickup()
	check("a torch scorches it away on the third press, not before",
		after_two == Tiles.FUNGUS_PURPLE and g.map.get_tile(purple.x, purple.y) != Tiles.FUNGUS_PURPLE)
	g._set_fungus(purple, Tiles.FUNGUS_PURPLE)
	g.player.hp = g.player.max_hp
	g.player_move(1, 0)
	check("walking into it -- torch lit or not -- steps on, and it hurts",
		Vector2i(g.player.x, g.player.y) == purple
		and g.player.hp == g.player.max_hp - GameState.PURPLE_HURT - GameState.POISON_HURT,
		"%d/%d" % [g.player.hp, g.player.max_hp])
	g.player_move(-1, 0)
	g._burn_fungus(purple)

	# Careless walkers are hurt; flyers are not.
	var kobold := GameState.monster_from(_bestiary_entry("kobold"), p_at.x + 2, p_at.y + 2)
	# Awake: it walked in by choice. (A sleeper would shuffle off -- below.)
	kobold.alertness = Entity.Alert.AWAKE
	var bat := GameState.monster_from(_bestiary_entry("cave bat"), p_at.x + 3, p_at.y + 2)
	g._set_fungus(Vector2i(kobold.x, kobold.y), Tiles.FUNGUS_PURPLE)
	g._set_fungus(Vector2i(bat.x, bat.y), Tiles.FUNGUS_PURPLE)
	g.entities = [g.player, kobold, bat]
	var k_hp := kobold.hp
	var b_hp := bat.hp
	g._grow_fungus()
	# The ground's bite and the cloud's (strand 3, the miasma) together.
	check("a kobold standing in purple is hurt by the ground and the cloud",
		kobold.hp == k_hp - GameState.PURPLE_HURT - GameState.POISON_HURT,
		"%d -> %d" % [k_hp, kobold.hp])
	check("a bat flying over it is spared the ground, not the air",
		bat.hp == b_hp - GameState.POISON_HURT, "%d -> %d" % [b_hp, bat.hp])
	kobold.hp = 1
	g.bodies = []
	g._grow_fungus()
	check("and one that dies in it leaves a body, like any death",
		not kobold.alive and g.bodies.size() == 1)
	# A sleeper in it stirs, shuffles off, and sleeps on -- marked if red.
	var sleeper := GameState.monster_from(_bestiary_entry("goblin"), p_at.x - 2, p_at.y - 2)
	sleeper.alertness = Entity.Alert.ASLEEP
	var bed := Vector2i(sleeper.x, sleeper.y)
	g._set_fungus(bed, Tiles.FUNGUS_RED)
	g.entities = [g.player, sleeper]
	var s_hp := sleeper.hp
	g._grow_fungus()
	check("a sleeper in red takes its bite and is marked (the premise)",
		sleeper.hp == s_hp - GameState.RED_HURT and sleeper.spores == &"red")
	check("then shuffles off it onto safe ground, still asleep",
		Vector2i(sleeper.x, sleeper.y) != bed
		and not Tiles.is_bad_fungus(g.map.get_tile(sleeper.x, sleeper.y))
		and sleeper.alertness == Entity.Alert.ASLEEP)
	var boxed := GameState.monster_from(_bestiary_entry("goblin"), p_at.x + 3, p_at.y - 3)
	boxed.alertness = Entity.Alert.ASLEEP
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			g._set_fungus(Vector2i(boxed.x + dx, boxed.y + dy), Tiles.FUNGUS_PURPLE)
	g.entities = [g.player, boxed]
	var boxed_at := Vector2i(boxed.x, boxed.y)
	g._grow_fungus()
	check("one ringed by fungus has nowhere to go, and stays",
		Vector2i(boxed.x, boxed.y) == boxed_at)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			g._burn_fungus(Vector2i(boxed.x + dx, boxed.y + dy))
	g._burn_fungus(bed)
	g._burn_fungus(Vector2i(kobold.x, kobold.y))
	g._burn_fungus(Vector2i(bat.x, bat.y))
	g.bodies = []
	g.entities = [g.player]

	# A fire shot burns it from range; any other shot refuses.
	var far := Vector2i(g.player.x + 3, g.player.y)
	g._set_fungus(far, Tiles.FUNGUS_RED)
	g.update_vision()
	var sling := Item.make(&"sling")
	sling.ammo = 5
	g.player.inventory = [sling]
	g.player.equipped = {Item.Slot.WEAPON: sling}
	check("a plain sling will not touch it", not g.player_fire(far)
		and g.map.get_tile(far.x, far.y) == Tiles.FUNGUS_RED)
	sling.element = &"fire"
	check("a fire sling burns it from range, and spends the stone",
		g.player_fire(far) and g.map.get_tile(far.x, far.y) != Tiles.FUNGUS_RED and sling.ammo == 4)

	# Auto-travel stops short.
	g._set_fungus(far, Tiles.FUNGUS_RED)
	var stand := Vector2i(g.player.x, g.player.y)
	g._travel = [stand + Vector2i(1, 0)]
	g._set_fungus(stand + Vector2i(1, 0), Tiles.FUNGUS_RED)
	check("auto-travel stops short of it", not g._step_travel(true)
		and Vector2i(g.player.x, g.player.y) == stand)
	# Rabbits only eat green.
	var bunny := GameState.monster_from(GameState.BESTIARY[0], stand.x, stand.y + 2)
	bunny.appearance = &"rabbit"
	g.entities = [g.player, bunny]
	var meal := g._nearest_fungus(bunny)
	check("a rabbit does not go for purple or red",
		meal.x < 0 or g.map.get_tile(meal.x, meal.y) == Tiles.FUNGUS, str(meal))
	# Anything that stands on red is marked by it, and keeps the mark.
	var walker := GameState.monster_from(GameState.BESTIARY[1], far.x, far.y)
	g.entities = [g.player, walker]
	g._grow_fungus()
	check("a creature standing on red is marked, and the mark is saved",
		walker.spores == &"red" and Entity.from_dict(walker.to_dict()).spores == &"red")
	# Saved: the torch's work in progress.
	g.scorched = {"3,4": 2}
	var back := GameState.new(1)
	back.apply_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	check("a half-scorched fungus is still half-scorched after a save",
		int(back.scorched.get("3,4", 0)) == 2)

## Slingers reload: every other turn on their first floor, 0-2 turns elsewhere.
## Brad's call (2026-09-28): 8 of his 22 deaths were slingers on floors 1-2.
func _test_slingers_reload() -> void:
	var sling: Dictionary = {}
	var other_shooter: Dictionary = {}
	for entry in GameState.BESTIARY:
		if entry["app"] == &"slinger":
			sling = entry
		elif entry.get("ai", &"") == &"ranged" and not entry.get("reload", false) \
				and other_shooter.is_empty():
			other_shooter = entry
	check("a slinger reloads; a kobold does not",
		GameState.monster_from(sling, 0, 0).reload_style == Entity.Reload.RANDOM
		and GameState.monster_from(GameState.BESTIARY[1], 0, 0).reload_style == Entity.Reload.NONE)

	var gs := GameState.new(7171)
	gs.new_game()
	# An open strip east of the player, so the slinger always has its shot.
	for dy in range(-1, 2):
		for dx in range(-1, 8):
			gs.map.set_tile(gs.player.x + dx, gs.player.y + dy, Tiles.FLOOR)
	gs.player.max_hp = 9999
	gs.player.hp = 9999
	var shooter := func(entry: Dictionary, style: int) -> Entity:
		var m := GameState.monster_from(entry, gs.player.x + 4, gs.player.y)
		m.reload_style = style
		m.alertness = Entity.Alert.AWAKE
		gs.entities = [gs.player, m]
		gs.update_vision()
		return m
	var fires := func(m: Entity, turns: int) -> Array:
		var out := []
		for i in turns:
			gs.events.clear()
			gs._ai_ranged(m, gs.player)
			var shot := 0
			for e in gs.events:
				if e["kind"] == &"ranged" and e["from"] == Vector2i(m.x, m.y):
					shot = 1
			out.append(shot)
		return out

	var steady: Entity = shooter.call(sling, Entity.Reload.STEADY)
	var pattern: Array = fires.call(steady, 8)
	check("on its first floor a slinger fires every other turn",
		pattern == [1, 0, 1, 0, 1, 0, 1, 0], str(pattern))

	var loose: Entity = shooter.call(sling, Entity.Reload.RANDOM)
	var long: Array = fires.call(loose, 300)
	var gaps := {}
	var last := -1
	for i in long.size():
		if long[i] == 1:
			if last >= 0:
				gaps[i - last - 1] = true
			last = i
	var rate := float(long.count(1)) / float(long.size())
	check("elsewhere it waits 0, 1 or 2 turns -- each of them, and never more",
		gaps.keys().size() == 3 and gaps.has(0) and gaps.has(1) and gaps.has(2),
		str(gaps.keys()))
	check("so it fires a little over half the time", rate > 0.5 and rate < 0.75,
		"%.2f" % rate)

	if not other_shooter.is_empty():
		var caster: Entity = shooter.call(other_shooter, Entity.Reload.NONE)
		caster.standoff = 1
		check("a shooter that does not reload never pauses (%s)" % other_shooter["name"],
			not (0 in fires.call(caster, 6)))

	# The teaching floor is the slinger's first floor, on the way down only.
	var teach := GameState.monster_from(sling, 0, 0)
	gs.entities = [gs.player, teach]
	gs.ascending = false
	gs.depth = GameState.first_floor_of(&"slinger")
	gs._teach_the_slingers()
	check("on floor %d going down, it is steady" % gs.depth,
		teach.reload_style == Entity.Reload.STEADY)
	teach.reload_style = Entity.Reload.RANDOM
	gs.depth += 1
	gs._teach_the_slingers()
	check("one floor deeper it is not", teach.reload_style == Entity.Reload.RANDOM)
	gs.depth = GameState.first_floor_of(&"slinger")
	gs.ascending = true
	gs._teach_the_slingers()
	check("nor on the climb", teach.reload_style == Entity.Reload.RANDOM)

	teach.reload_style = Entity.Reload.STEADY
	teach.reload_left = 1
	var back := Entity.from_dict(teach.to_dict())
	check("a reload survives a save", back.reload_style == Entity.Reload.STEADY
		and back.reload_left == 1)

## The dead lie where they fell and rot away (Dwarf Fortress plan, strand 1).
func _test_bodies_lie_and_rot() -> void:
	var gs := GameState.new(6161)
	gs.new_game()
	var victim: Entity = null
	for e in gs.entities:
		if not e.is_player and e.alive and e.hostile_to(gs.player):
			victim = e
			break
	check("a floor has a monster to kill (the premise)", victim != null)
	if victim == null:
		return
	check("no bodies before anything dies", gs.bodies.is_empty())
	var at := Vector2i(victim.x, victim.y)
	victim.hp = 0
	victim.alive = false
	gs._settle_death(victim, gs.player)
	check("a kill leaves one body", gs.bodies.size() == 1)
	var b: Dictionary = gs.bodies[0]
	check("where it fell, as what it was, whole",
		Vector2i(int(b["x"]), int(b["y"])) == at and b["app"] == String(victim.appearance)
		and b["e"] is Dictionary and b["e"].get("name", "") == victim.name)

	var back := GameState.new(1)
	back.apply_dict(JSON.parse_string(JSON.stringify(gs.to_dict())))
	check("bodies survive a save", back.bodies.size() == 1
		and int(back.bodies[0]["x"]) == at.x and int(back.bodies[0]["turn"]) == gs.turns)

	gs.turns += GameState.BODY_ROT - 1
	gs._rot_bodies()
	check("a body lasts until it has rotted", gs.bodies.size() == 1)
	gs.turns += 1
	gs._rot_bodies()
	check("and then it is gone", gs.bodies.is_empty())

	# The shovel takes the body it raises.
	var dig := GameState.new(6262)
	dig.new_game()
	var fresh: Entity = null
	for e in dig.entities:
		if not e.is_player and e.alive and e.hostile_to(dig.player):
			fresh = e
			break
	# Killed the real way: take_damage drops `blocks` with `alive`, which is
	# what the raise has to undo (see _rise_from).
	_kill(dig, fresh, dig.player)
	check("a fresh kill lies there to dig (the premise)", dig.bodies.size() == 1)
	var raised := dig._raise_the_recent_dead()
	check("raising it takes the body off the floor", raised and dig.bodies.is_empty())
	var dug: Entity = null
	for e in dig.entities:
		if e.name.begins_with("risen ") and e.faction == Entity.Faction.PLAYER:
			dug = e
	check("and what the shovel raises stands in its cell, not under everyone's feet",
		dug != null and dug.alive and dig.entity_at(dug.x, dug.y) == dug)

	dig._settle_death(fresh, dig.player)
	dig.depth += 1
	dig.build_level()
	check("a new floor starts with no bodies", dig.bodies.is_empty())

## Every ending leaves a full record in legends.json -- the hero exactly, the
## stats, an id -- and the old text morgue is imported once, duplicates merged.
func _test_legends_log() -> void:
	var saved_morgue := GameState.MORGUE_PATH
	GameState.MORGUE_PATH = "user://scratch_legends_test_morgue.txt"
	for p in [GameState.MORGUE_PATH, LegendsLog.PATH]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)

	# Brad's real itch morgue, plus one death from before names existed.
	var f := FileAccess.open(GameState.MORGUE_PATH, FileAccess.WRITE)
	f.store_line("2026-09-07 01:29:17  level 19  escaped the dungeon with the Amulet of the Deep, with the Amulet, after 10720 turns")
	f.store_line("2026-09-07 23:50:39  level 19  escaped the dungeon with the Amulet of the Deep, with the Amulet, after 10720 turns")
	f.store_line("2026-09-03 23:09:49  level 1  killed by a kobold on depth 1, empty-handed, after 228 turns")
	f.close()
	var imported := LegendsLog.import_text(GameState.MORGUE_PATH)
	check("the text morgue imports: one escape, one death",
		imported.size() == 2, "%d records" % imported.size())
	check("and Brad's escape written twice becomes one",
		imported.filter(func(r): return r["fate"] == "escaped").size() == 1)
	var old := LegendsLog.hero_from(imported[0])
	check("an imported escape rebuilds as a level-19 hero",
		old.level == 19 and old.max_hp == GameState.hp_at_level(19))

	# A real death, with no legends file yet: the morgue is imported first and
	# the run added once -- not twice via its own new text line.
	check("no legends file yet (the premise)", not FileAccess.file_exists(LegendsLog.PATH))
	var gs := GameState.new(5151)
	gs.new_game()
	gs.player.hp = 1
	gs._fall_into_pit()
	check("the fall killed (the premise)", gs.game_over and not gs.won)
	var all := LegendsLog.runs()
	check("the first ending imports the old morgue and adds itself once",
		all.size() == 3, "%d records" % all.size())
	var last: Dictionary = all[-1]
	check("the new record is the whole run",
		last["fate"] == "died" and last["source"] == "run"
		and last["hero"] is Dictionary and last["stats"] is Dictionary
		and last["turns"] == gs.turns and last["name"] == gs.player_name)
	var back := LegendsLog.hero_from(last)
	check("and its hero rebuilds exactly",
		back.level == gs.player.level and back.max_hp == gs.player.max_hp
		and back.inventory.size() == gs.player.inventory.size()
		and back.equipped.size() == gs.player.equipped.size())

	# The same ending cannot be recorded twice.
	LegendsLog.record(gs)
	check("recording the same ending again adds nothing", LegendsLog.runs().size() == 3)

	# A win is an escape, and the unlock sees it.
	var wins := GameState.new(5252)
	wins.new_game()
	wins.depth = 1
	wins.map.set_tile(wins.player.x, wins.player.y, Tiles.STAIRS_UP)
	wins.player_ascend()
	check("a win is recorded as an escape",
		LegendsLog.escapes().size() == 2 and LegendsLog.runs().size() == 4)

	# The import is once only: a later morgue line is not pulled in again.
	f = FileAccess.open(GameState.MORGUE_PATH, FileAccess.READ_WRITE)
	f.seek_end()
	f.store_line("2026-09-04 20:00:00  level 2  killed by a rat on depth 1, empty-handed, after 300 turns")
	f.close()
	check("the text morgue is imported only once", LegendsLog.runs().size() == 4)

	# A file it cannot read is never written over.
	var g := FileAccess.open(LegendsLog.PATH, FileAccess.WRITE)
	g.store_string("{ this is not json")
	g.close()
	var dies := GameState.new(5353)
	dies.new_game()
	dies.player.hp = 1
	dies._fall_into_pit()
	check("an unreadable legends file is left alone, not replaced",
		FileAccess.get_file_as_string(LegendsLog.PATH) == "{ this is not json")

	for p in [GameState.MORGUE_PATH, LegendsLog.PATH]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	GameState.MORGUE_PATH = saved_morgue

## A run that has ENDED cannot be resumed. Brad's itch exploit, 2026-09-28:
## save, climb out, refresh, load the save, climb out again -- one escape in
## the morgue twice. The same hole reloaded a death on the web, where every
## tab switch writes the slot. Both real endings are driven, not simulated.
func _test_an_ending_clears_the_slot() -> void:
	var gs := GameState.new(4242)
	gs.new_game()
	check("a live run saves its slot",
		gs.save_suspend() and GameState.has_suspend())
	gs.depth = 1
	gs.map.set_tile(gs.player.x, gs.player.y, Tiles.STAIRS_UP)
	gs.player_ascend()
	check("climbing out wins (the premise)", gs.won and gs.game_over)
	check("and the win clears the slot, so it cannot be replayed",
		not GameState.has_suspend())

	var dies := GameState.new(4343)
	dies.new_game()
	dies.save_suspend()
	check("a second live run has a slot (the premise)", GameState.has_suspend())
	dies.player.hp = 1
	dies._fall_into_pit()
	check("a fall at 1 hp kills (the premise)", dies.game_over and not dies.won)
	check("and the death clears the slot, so a reload is not a second life",
		not GameState.has_suspend())

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
	check("and says it once", victory.count("with the Amulet") == 1, victory)
	var probe_path := "user://scratch_escape_line_probe.txt"
	var pf := FileAccess.open(probe_path, FileAccess.WRITE)
	pf.store_line(victory)
	pf.close()
	var read_back := LegendsLog.import_text(probe_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(probe_path))
	check("and the Legends importer still reads it as an escape",
		read_back.size() == 1 and read_back[0]["fate"] == "escaped"
		and int(read_back[0]["turns"]) == gs.turns, str(read_back))

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
	# Knowing where you stood (2026-10-04, when hunters began following their
	# mark): without one, a thing called up behind a pillar stood there. The
	# shrine itself, not the prayer -- the prayer's own turn lets them see you,
	# which would hand them the mark and hide a missing one.
	var call2 := _shrine_arena(Shrines.SUMMONS)
	var before2 := call2.entities.size()
	call2._invoke_shrine(Shrines.SUMMONS)
	var all_marked := call2.entities.size() > before2
	for i in range(before2, call2.entities.size()):
		if call2.entities[i].last_seen != Vector2i(call2.player.x, call2.player.y):
			all_marked = false
	check("and it knows where you stood when it was called", all_marked)

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

## HIDDEN TRAPS (the 2026-09-26 playtest): every trap starts hidden -- floor
## to the eye and the route -- and springs underfoot; each turn you may spot
## one in reach, likelier in torchlight; the trapwright's glass helps.
func _test_hidden_traps() -> void:
	# A real floor: whatever traps it laid, none shows at the start.
	var laid: GameState = null
	for seed in range(1, 40):
		var g := GameState.new(seed)
		g.new_game()
		g.depth = 2
		g.build_level()
		if not g.hidden_traps.is_empty():
			laid = g
			break
	check("precondition: a floor with traps was found", laid != null)
	if laid != null:
		var shown := 0
		for y in laid.map.height:
			for x in laid.map.width:
				if laid.map.get_tile(x, y) == Tiles.TRAP:
					shown += 1
		check("every trap it laid is hidden, and none shows", shown == 0)
		for c in laid.hidden_traps:
			check("  a hidden trap's square is floor", Tiles.is_open_floor(laid.map.get_tile(c.x, c.y)))
			break

	# Beside you: floor to the route, floor to the eye.
	var gs := _arena(21, 9)
	gs.player.x = 5
	gs.player.y = 4
	gs.player.max_hp = 200
	gs.player.hp = 200
	gs.torch_lit = true
	gs.map.set_tile(7, 4, Tiles.TRAP)
	gs._hide_the_traps()
	gs.pathfinder = Pathfinder.new(gs.map)
	gs._gather_lights()
	gs.update_vision()
	check("hidden, its square is floor and a walk routes straight over it",
		gs.map.get_tile(7, 4) == Tiles.FLOOR and gs.hidden_traps.has(Vector2i(7, 4))
		and gs.pathfinder.path(Vector2i(5, 4), Vector2i(9, 4)).has(Vector2i(7, 4)))
	# The chance: light, distance, the glass.
	var lit_near := gs._spot_chance(Vector2i(7, 4))
	gs.map.set_tile(8, 4, Tiles.FLOOR)
	gs.hidden_traps[Vector2i(8, 4)] = true
	var lit_far := gs._spot_chance(Vector2i(8, 4))
	gs.torch_lit = false
	gs._gather_lights()
	gs.update_vision()
	var dark_near := gs._spot_chance(Vector2i(7, 4))
	check("in torchlight a trap two cells off is spotted about half the time a turn (%.2f)" % lit_near,
		lit_near > 0.40 and lit_near < 0.70)
	check("farther, less (%.2f < %.2f)" % [lit_far, lit_near], lit_far < lit_near and lit_far > 0.0)
	check("in the dark, far less (%.2f)" % dark_near, dark_near < lit_near * 0.5 and dark_near > 0.0)
	var glass := Item.make(&"trap_glass")
	gs.give_item(glass)
	gs._toggle_equip(glass)
	check("the trapwright's glass, worn, adds half again",
		gs._spots_traps_better()
		and is_equal_approx(gs._spot_chance(Vector2i(7, 4)), minf(1.0, dark_near * GameState.SPOT_GLASS)))
	gs._toggle_equip(glass)
	gs.player.inventory.erase(glass)
	gs.hidden_traps.erase(Vector2i(8, 4))
	check("out of reach or out of sight, no chance at all",
		gs._spot_chance(Vector2i(15, 4)) == 0.0)
	# Spotted: the tile, the route, the word.
	gs.torch_lit = true
	gs._gather_lights()
	gs.update_vision()
	gs.trap_rng.seed = 12345
	var turns_taken := 0
	while gs.hidden_traps.has(Vector2i(7, 4)) and turns_taken < 40:
		gs._spot_traps()
		turns_taken += 1
	var said := ""
	for line in gs.msg_log.entries:
		said += str(line) + "|"
	check("standing in torchlight beside it, it is spotted within a few turns (%d)" % turns_taken,
		gs.map.get_tile(7, 4) == Tiles.TRAP and not gs.hidden_traps.has(Vector2i(7, 4))
		and turns_taken < 12)
	check("and said, and your travel routes round it from then on", said.contains("You spot a trap")
		and not gs.pathfinder.path(Vector2i(5, 4), Vector2i(9, 4), true, true).has(Vector2i(7, 4)))
	check("  while a monster still walks over it",
		gs.pathfinder.path(Vector2i(5, 4), Vector2i(9, 4)).has(Vector2i(7, 4)))

	# Unseen underfoot, it springs -- and a walk stops there.
	var hs := _arena(21, 9)
	hs.player.x = 5
	hs.player.y = 4
	hs.player.max_hp = 200
	hs.player.hp = 200
	hs.map.set_tile(6, 4, Tiles.TRAP)
	hs._hide_the_traps()
	var hp0 := hs.player.hp
	check("stepping onto a hidden trap springs it (and must)", hs.player_move(1, 0)
		and hs.player.hp < hp0 and hs.player.x == 6 and not hs.hidden_traps.has(Vector2i(6, 4))
		and hs.map.get_tile(6, 4) == Tiles.FLOOR)
	var ws := _arena(21, 9)
	ws.player.x = 5
	ws.player.y = 4
	ws.player.max_hp = 200
	ws.player.hp = 200
	ws.map.set_tile(7, 4, Tiles.TRAP)
	ws._hide_the_traps()
	ws.pathfinder = Pathfinder.new(ws.map)
	ws._travel = [Vector2i(6, 4), Vector2i(7, 4), Vector2i(8, 4), Vector2i(9, 4)]
	ws._step_travel(false)
	var hp1 := ws.player.hp
	ws._step_travel(false)
	check("a walk springs the hidden trap under its next step and ends there",
		ws.player.hp < hp1 and ws.player.x == 7 and ws._travel.is_empty())

	# Saved: what is hidden, and the roll to come.
	var ss := _arena(21, 9)
	ss.map.set_tile(7, 4, Tiles.TRAP)
	ss.map.set_tile(9, 6, Tiles.TRAP)
	ss._hide_the_traps()
	ss.trap_rng.seed = 99
	var back := GameState.new(1)
	back.new_game()
	check("the hidden traps and their rng are saved",
		back.apply_dict(ss.to_dict()) and back.hidden_traps.size() == 2
		and back.hidden_traps.has(Vector2i(9, 6)) and back.trap_rng.seed == 99)
	check("the glass is a unique the chests can give", Item.uniques(2).has(&"trap_glass"))

## THE SECOND TRAP PASS (2026-10-02): G disarms a found trap on a roll the
## glass improves; the floor's own step over every trap and only your side
## springs them; a found trap in a doorway stops your travel and nothing else.
func _test_disarming_and_the_floors_own() -> void:
	var gs := _arena(21, 9)
	gs.player.x = 5
	gs.player.y = 4
	gs.player.max_hp = 200
	gs.player.hp = 200
	gs.torch_lit = false
	gs.map.set_tile(6, 4, Tiles.TRAP)
	gs.pathfinder = Pathfinder.new(gs.map)
	gs.player.facing = Vector2i(1, 0)
	var said := func() -> String:
		var all := ""
		for line in gs.msg_log.entries:
			all += str(line["text"]) + "|"
		return all
	var offered := func() -> String:
		var all := ""
		for row in gs.actions_here():
			all += str(row[1]) + "|"
		return all
	check("precondition: the found trap ahead is the target", gs.disarm_target() == Vector2i(6, 4))
	check("the HERE box offers it, with the odds", offered.call().contains("disarm the trap (50%)"),
		offered.call())
	# Seeds whose first roll fails, and succeeds, bare-handed.
	var probe := RandomNumberGenerator.new()
	var fumble := -1
	var deft := -1
	for sd in range(1, 400):
		probe.seed = sd
		var r := probe.randf()
		if r >= GameState.DISARM_GLASS and fumble < 0:
			fumble = sd
		if r < GameState.DISARM_BARE and deft < 0:
			deft = sd
	check("precondition: a fumbling seed and a deft one were found", fumble > 0 and deft > 0)
	gs.trap_rng.seed = fumble
	var hp0 := gs.player.hp
	var turn0 := gs.turns
	check("fumbled, it springs under your hands and is gone", gs.player_disarm()
		and gs.player.hp < hp0 and gs.map.get_tile(6, 4) == Tiles.FLOOR)
	check("  for half: at most 2 here", hp0 - gs.player.hp <= 2, "%d" % (hp0 - gs.player.hp))
	check("  and it cost the turn", gs.turns == turn0 + 1)
	check("  and said so", said.call().contains("Your hand slips"))
	gs.map.set_tile(6, 4, Tiles.TRAP)
	gs.pathfinder.set_trap(6, 4, true)
	check("precondition: armed again, and your travel goes round it",
		not gs.pathfinder.path(Vector2i(5, 4), Vector2i(8, 4), true, true).has(Vector2i(6, 4)))
	gs.trap_rng.seed = deft
	hp0 = gs.player.hp
	check("made, the trap is gone for good and nothing hurt", gs.player_disarm()
		and gs.player.hp == hp0 and gs.map.get_tile(6, 4) == Tiles.FLOOR
		and said.call().contains("disarm the trap"))
	check("  and your travel goes straight through again",
		gs.pathfinder.path(Vector2i(5, 4), Vector2i(8, 4), true, true).has(Vector2i(6, 4)))
	check("with no trap in reach the key refuses", not gs.player_disarm())
	# The glass's second job.
	var glass := Item.make(&"trap_glass")
	gs.give_item(glass)
	gs._toggle_equip(glass)
	gs.map.set_tile(6, 4, Tiles.TRAP)
	check("the trapwright's glass raises the odds, and the box says so",
		is_equal_approx(gs.disarm_chance(), GameState.DISARM_GLASS)
		and offered.call().contains("disarm the trap (90%)"), offered.call())
	gs._toggle_equip(glass)
	gs.player.inventory.erase(glass)
	check("precondition: bare again", is_equal_approx(gs.disarm_chance(), GameState.DISARM_BARE))

	# YOUR SIDE SPRINGS THEM; THE FLOOR'S OWN DO NOT.
	var hs := _arena(21, 9)
	hs.player.x = 3
	hs.player.y = 4
	hs.torch_lit = false
	hs.hidden_traps[Vector2i(8, 4)] = true
	hs.hidden_traps[Vector2i(8, 6)] = true
	hs.map.set_tile(12, 4, Tiles.TRAP)
	var mate := _spawn(hs, "orc", 8, 4)
	mate.faction = Entity.Faction.PLAYER
	mate.ai = &"ally"
	var mob := _spawn(hs, "orc", 8, 6)
	var standing := _spawn(hs, "orc", 12, 4)
	check("precondition: an ally and a monster stand on hidden traps, a monster on a found one",
		hs.hidden_traps.has(Vector2i(mate.x, mate.y)) and hs.hidden_traps.has(Vector2i(mob.x, mob.y))
		and hs.map.get_tile(standing.x, standing.y) == Tiles.TRAP
		and not hs._owns_the_floor(mate) and hs._owns_the_floor(mob))
	var mate_hp := mate.hp
	var mob_hp := mob.hp
	var standing_hp := standing.hp
	hs._spring_under_allies()
	var heard := ""
	for line in hs.msg_log.entries:
		heard += str(line["text"]) + "|"
	check("an ally on a hidden trap springs it, and you learn where it was",
		mate.hp < mate_hp and not hs.hidden_traps.has(Vector2i(8, 4))
		and heard.contains("clicks under the orc"), heard)
	check("a monster on one does not: it is their floor",
		mob.hp == mob_hp and hs.hidden_traps.has(Vector2i(8, 6)))
	check("nor on a found one", standing.hp == standing_hp and hs.map.get_tile(12, 4) == Tiles.TRAP)
	# Hand-rolled steps keep the same rule.
	check("a monster may side-step onto a found trap", hs.can_creature_step(11, 4, 12, 4, mob))
	check("an ally may not", not hs.can_creature_step(11, 4, 12, 4, mate))
	check("and with no actor named, the strict rule holds", not hs.can_creature_step(11, 4, 12, 4))
	hs.map.set_tile(12, 5, Tiles.PIT)
	check("nobody side-steps onto a pit", not hs.can_creature_step(11, 4, 12, 5, mob))

	# A FOUND TRAP IN THE ONE DOORWAY: your travel has no way through; every
	# monster's route does; and you can still step over it yourself.
	var ds := _arena(21, 9)
	ds.player.x = 9
	ds.player.y = 4
	ds.torch_lit = false
	for y in range(1, 8):
		ds.map.set_tile(10, y, Tiles.WALL)
	ds.map.set_tile(10, 4, Tiles.DOOR_OPEN)
	ds.map.set_tile(11, 4, Tiles.TRAP)
	ds.pathfinder = Pathfinder.new(ds.map)
	check("precondition: the doorway is the only way, and a monster's route runs through it",
		ds.pathfinder.path(Vector2i(15, 4), Vector2i(5, 4)).has(Vector2i(11, 4)))
	check("a careful monster's too", ds.pathfinder.path(Vector2i(15, 4), Vector2i(5, 4), true).has(Vector2i(11, 4)))
	check("your travel finds no way", ds.pathfinder.path(Vector2i(9, 4), Vector2i(15, 4), true, true).is_empty())
	check("nor does an ally's", ds.pathfinder.path(Vector2i(9, 4), Vector2i(15, 4), false, true).is_empty())
	ds.player_move(1, 0)
	var hp2 := ds.player.hp
	check("but you step over it yourself, unhurt", ds.player_move(1, 0)
		and ds.player.x == 11 and ds.player.hp == hp2 and ds.map.get_tile(11, 4) == Tiles.TRAP)
	# A walk laid before the trap was found stops at it rather than crossing.
	ds.player.x = 9
	ds.player.y = 4
	ds._travel = [Vector2i(10, 4), Vector2i(11, 4), Vector2i(12, 4)]
	ds._step_travel(false)
	check("precondition: the walk took its first step", ds.player.x == 10)
	check("a walk stops short of a found trap", not ds._step_travel(false)
		and ds.player.x == 10 and ds._travel.is_empty())

## WHERE TRAPS ARE LAID (2026-10-02): none in the caves, most in the fortress
## and on the amulet's floor, and about half of those on a threshold.
func _test_traps_by_band() -> void:
	var counts := {}
	var thresholds := 0
	for d in [2, 5, 8, 10]:
		var total := 0
		for i in 12:
			var g := GameState.new(50000 + i)
			g.new_game()
			g.depth = d
			g.build_level()
			total += g.hidden_traps.size()
			if d != 8:
				continue
			for c in g.hidden_traps:
				for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var t := g.map.get_tile(c.x + step.x, c.y + step.y)
					if t == Tiles.DOOR_CLOSED or t == Tiles.DOOR_OPEN:
						thresholds += 1
						break
		counts[d] = total
	check("the caves lay none (%d in 12 floors)" % counts[5], counts[5] == 0)
	check("the upper floors lay a few (%d in 12)" % counts[2], counts[2] > 0)
	check("the fortress lays more (%d vs %d)" % [counts[8], counts[2]], counts[8] > counts[2])
	check("and so does the amulet's floor (%d)" % counts[10], counts[10] > counts[2])
	check("about half the fortress's wait on a threshold (%d of %d)" % [thresholds, counts[8]],
		thresholds * 4 >= counts[8] and thresholds * 4 <= counts[8] * 3)

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

	gs.torch_lit = false
	var route := gs.pathfinder.path(Vector2i(5, 6), Vector2i(8, 6), true, true)
	check("your travel goes around a found trap", not route.has(Vector2i(6, 6)), str(route))
	check("a monster's route goes straight over it: its own floor",
		gs.pathfinder.path(Vector2i(5, 6), Vector2i(8, 6)).has(Vector2i(6, 6)))

	# Something asleep in earshot of a spring, to prove a careful step is not one.
	var dozing := _spawn(gs, "orc", 11, 6)
	dozing.alertness = Entity.Alert.ASLEEP

	# A FOUND trap is stepped over (2026-10-02): slow, unhurt, still armed.
	var hp_before := gs.player.hp
	var spent := gs.elapsed
	check("stepping onto a found trap works", gs.player_move(1, 0))
	check("and does not hurt: you step over it", gs.player.hp == hp_before)
	check("you end up standing on the square",
		gs.player.x == 6 and gs.player.y == 6)
	check("the trap stays armed behind you", gs.map.get_tile(6, 6) == Tiles.TRAP)
	check("the careful step costs double",
		gs.elapsed - spent == Scheduler.ACTION_COST * GameState.TRAP_STEP_OVER,
		"%d" % (gs.elapsed - spent))
	check("and makes no noise", dozing.alertness == Entity.Alert.ASLEEP)

	# A HIDDEN one under the next step springs, hurts, and is loud.
	gs.hidden_traps[Vector2i(7, 6)] = true
	check("stepping onto a hidden trap works (and must)", gs.player_move(1, 0))
	check("it hurts", gs.player.hp < hp_before)
	check("and it has sprung for good", gs.map.get_tile(7, 6) == Tiles.FLOOR
		and not gs.hidden_traps.has(Vector2i(7, 6)))
	check("springing one is loud", dozing.alertness == Entity.Alert.AWAKE)

	# Crossing again is free (the orc it woke is sent away first: a careful
	# step costs double, and it was closing fast).
	gs.entities = [gs.player]
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
	doomed.hidden_traps[Vector2i(6, 4)] = true
	doomed.player_move(1, 0)
	check("a trap can finish you", doomed.game_over)
	check("and the morgue knows what did it",
		doomed.death_cause.contains("trap"), doomed.death_cause)

	# They generate -- hidden, since 2026-10-01, so they are counted where
	# they wait rather than on the map.
	var seen := 0
	var showing := 0
	for i in 30:
		var level := GameState.new(93000 + i)
		level.new_game()
		seen += level.hidden_traps.size()
		for y in level.map.height:
			for x in level.map.width:
				if level.map.get_tile(x, y) == Tiles.TRAP:
					showing += 1
	check("levels have traps on them (%d / 30)" % seen, seen > 0)
	check("and none of them shows at the start (%d)" % showing, showing == 0)

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

func _test_vault_fungus_symbols() -> void:
	var vault := Vault.parse("name: fungus symbols\nweight: 8\nLAYOUT\n" \
		+ "#####\n#v;.#\n##+##\n", "fungus_symbols")
	check("a small vault with both fungus marks parses", vault != null)
	if vault == null:
		return
	var gen := MapGen.new(RandomNumberGenerator.new())
	var map := DungeonMap.new(5, 3)
	map.tiles.fill(Tiles.WALL)
	gen.vault_spots.append({"grid": vault.oriented(0, false),
		"rect": Rect2i(0, 0, 5, 3), "vault": vault})
	gen._stamp_vaults(map)
	check("v stamps purple fungus into a vault", map.get_tile(1, 1) == Tiles.FUNGUS_PURPLE)
	check("; stamps red fungus into a vault", map.get_tile(2, 1) == Tiles.FUNGUS_RED)

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
				# A cave vault IS one of the floor's caves (2026-10-08): its
				# own region is not an overlap. Any other cave still is.
				if vr.intersects(cave) and vr != cave:
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
	# It saw you there before you put the pillar between you. _spawn hands it
	# AWAKE with no mark, which play never does (2026-10-04: a hunter that
	# has lost you now goes where it last saw you, and with no mark, nowhere).
	archer.last_seen = Vector2i(3, 4)
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
	var meat := Item.make(&"meat")
	var rat_ring := Item.make(&"rat_ring")
	var shovel := Item.make(&"shovel")
	for it in [potion, meat, dagger, axe, mail, rat_ring, shovel]:
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
	var in_uniques := false
	var in_food_and_potions := false
	var unique_group_items: Array[Item] = []
	var food_is_in_its_group: bool = false
	for r in rows:
		if r.has("header"):
			in_weapons = r["header"] == "WEAPONS"
			in_uniques = r["header"] == "UNIQUES"
			in_food_and_potions = r["header"] == "FOOD & POTIONS"
			continue
		if in_weapons:
			weapons.append(r["item"].name)
		if in_uniques:
			unique_group_items.append(r["item"])
		if in_food_and_potions and r["item"] == meat:
			food_is_in_its_group = true
	check("better weapon sorts above worse", weapons == ["war axe", "dagger"], str(weapons))
	check("unique ring and shovel have their own group",
		unique_group_items.size() == 2 and unique_group_items.has(rat_ring)
		and unique_group_items.has(shovel))
	check("food is listed under FOOD & POTIONS", food_is_in_its_group)

	panel.filter = InventoryPanel.Filter.POTIONS
	var only: Array = panel._build_rows()
	check("food and potions share their filter",
		only.size() == 2 and only.any(func(r): return r["item"] == potion)
		and only.any(func(r): return r["item"] == meat))
	check("filtering drops the group headers",
		only.filter(func(r): return r.has("header")).is_empty())

	panel.filter = InventoryPanel.Filter.UNIQUES
	var unique_only: Array = panel._build_rows()
	check("the uniques filter finds both unique items",
		unique_only.size() == 2 and unique_only.any(func(r): return r["item"] == rat_ring)
		and unique_only.any(func(r): return r["item"] == shovel))
	panel.filter = InventoryPanel.Filter.WEAPONS
	var weapons_only: Array = panel._build_rows()
	check("the unique ring is excluded from weapons",
		weapons_only.size() == 2 and not weapons_only.any(func(r): return r["item"] == rat_ring))
	panel.filter = InventoryPanel.Filter.SCROLLS
	var scrolls_only: Array = panel._build_rows()
	check("the unique shovel is excluded from scrolls",
		scrolls_only.is_empty())

	panel.filter = InventoryPanel.Filter.GEMS
	panel.cycle_filter()
	check("filter cycling reaches uniques after gems",
		panel.filter == InventoryPanel.Filter.UNIQUES)
	panel.cycle_filter()
	check("filter cycling wraps from uniques to all",
		panel.filter == InventoryPanel.Filter.ALL)
	panel.cycle_filter(-1)
	check("reverse filter cycling reaches uniques",
		panel.filter == InventoryPanel.Filter.UNIQUES)

	gs.player.equipped[Item.Slot.WEAPON] = rat_ring
	panel.filter = InventoryPanel.Filter.ALL
	var worn_unique_rows: Array = panel._build_rows()
	var in_equipped: bool = false
	var unique_is_equipped: bool = false
	var equipped_unique_is_duplicated: bool = false
	for r in worn_unique_rows:
		if r.has("header"):
			in_equipped = r["header"] == "EQUIPPED"
			in_uniques = r["header"] == "UNIQUES"
			continue
		if r["item"] == rat_ring:
			unique_is_equipped = in_equipped
			equipped_unique_is_duplicated = in_uniques
	check("an equipped unique stays in EQUIPPED only",
		unique_is_equipped and not equipped_unique_is_duplicated)

	panel.font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
	panel.size = Vector2(1600, 900)
	var chips: Array = panel._chip_rects()
	var panel_rect: Rect2 = panel._panel_rect()
	var last_chip: Dictionary = chips.back()
	var last_right: float = last_chip["rect"].end.x
	var inner_right: float = panel_rect.end.x - InventoryPanel.PAD
	check("filter chips include the long label and fit the panel",
		chips.size() == 7 and chips[3]["label"] == "food & potions"
		and chips[6]["label"] == "uniques" and last_right <= inner_right,
		"last chip ends at %.1f; panel edge is %.1f" % [last_right, inner_right])
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
	GameState.clear_scratch_files()
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
			GameState.clear_scratch_files()
	GameState.clear_scratch_files()
	GameState.use_scratch_files("tests")
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
		{"kind": &"burn", "to": Vector2i(3, 3)},
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
	var burn_sound: Dictionary = deck.choose([{"kind": &"burn",
		"to": Vector2i(3, 3)}])["now"]
	check("burning fungus plays the forge sound", burn_sound.has(&"forge")
		and not burn_sound.has(&"burn"))
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
		"DioramaView": func() -> Object: return DioramaView.new(),
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
	check("  and the stack is one lighter", d1.count == 2 and gs.player.inventory.has(d1))

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

	# Three daggers buy it -- one stack, sold a dagger at a time (2026-10-03).
	check("precondition: the three daggers are one stack", d1.count == 3
		and not gs.player.inventory.has(d2) and not gs.player.inventory.has(d3))
	for i in 3:
		var at := gs.player.inventory.find(d1)
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
	# It joined the bought potion's stack; the stack is what the counter sees.
	var pi := -1
	for i in gs.player.inventory.size():
		if gs.player.inventory[i].id == &"potion_healing":
			pi = i
	var held: int = gs.player.inventory[pi].count
	var before := gs.trader_credit
	check("a potion is refused", pi >= 0 and not gs.trade_sell(pi))
	check("  and stays in the pack", gs.player.inventory[pi].count == held
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
## FAIR SHOTS (day-7 hunt, 2026-09-27, from the playtest report "monsters can
## target you around a corner and you can't do the same").
func _test_fair_shots() -> void:
	# A corner of this kind on this seed's floor: one-way clear, the other
	# blocked. The hunt's original was (63, 5) / (59, 2); the floor was laid
	# differently once traps were counted by band (2026-10-02) -- (36, 2) /
	# (39, 8) -- and again when the wild got their own roll (2026-10-05).
	# Each pair was found by the same probe on the new layout: every walkable
	# cell against every walkable cell within six, first disagreement wins.
	var gs := GameState.new(20260927)
	gs.new_game()
	gs.depth = 1
	gs.build_level()
	var a := Vector2i(37, 1)
	var b := Vector2i(35, 5)
	var there := Los.clear(gs.map, a.x, a.y, b.x, b.y)
	var back := Los.clear(gs.map, b.x, b.y, a.x, a.y)
	check("the premise: the one-way line disagrees at this corner (%s / %s)" % [there, back],
		there != back)
	check("a shot line agrees both ways there",
		Los.clear_both(gs.map, a.x, a.y, b.x, b.y) == Los.clear_both(gs.map, b.x, b.y, a.x, a.y))

	# And everywhere: sampled pairs in shooting range on this floor.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var raw_bad := 0
	var both_bad := 0
	var both_open := 0
	for k in 3000:
		var p := Vector2i(rng.randi_range(1, gs.map.width - 2), rng.randi_range(1, gs.map.height - 2))
		var q := p + Vector2i(rng.randi_range(-7, 7), rng.randi_range(-7, 7))
		if not gs.map.is_walkable(p.x, p.y) or not gs.map.in_bounds(q.x, q.y) \
				or not gs.map.is_walkable(q.x, q.y):
			continue
		if Los.clear(gs.map, p.x, p.y, q.x, q.y) != Los.clear(gs.map, q.x, q.y, p.x, p.y):
			raw_bad += 1
		var pq := Los.clear_both(gs.map, p.x, p.y, q.x, q.y)
		if pq != Los.clear_both(gs.map, q.x, q.y, p.x, p.y):
			both_bad += 1
		if pq:
			both_open += 1
	check("the premise: the one-way line is asymmetric somewhere here (%d)" % raw_bad, raw_bad > 0)
	check("a shot line never is (%d)" % both_bad, both_bad == 0)
	check("  and still finds open shots (%d) -- it did not just refuse everything" % both_open,
		both_open > 100)
	# All three shooters use it.
	var src := FileAccess.get_file_as_string("res://src/sim/game_state.gd")
	check("the player, monsters and allies all aim with the both-ways line",
		src.count("Los.clear_both(") >= 3
		and not src.contains("return Los.clear(map, player.x, player.y, cell.x, cell.y)"))
	check("  and monsters also check the dark-shot bound",
		src.contains("and _fair_from_the_dark(actor, foe)"))

	# THE DARK-SHOT BOUND: a shooter no more than 2 cells past the sight edge.
	var ar := GameState.new(4040)
	ar.new_game()
	ar.player.x = 20
	ar.player.y = 20
	var shooter := Entity.new("kobold slinger", &"slinger", 26, 20)
	shooter.faction = Entity.Faction.MONSTER
	var see_up_to := func(n: int) -> void:
		ar.map.visible_now.fill(0)
		for x in range(20, 20 + n + 1):
			ar.map.visible_now[ar.map.idx(x, 20)] = 1
	see_up_to.call(4)
	check("a shooter 2 cells past the edge of your sight may fire",
		ar._fair_from_the_dark(shooter, ar.player))
	see_up_to.call(3)
	check("  3 cells past may not -- it must step closer first",
		not ar._fair_from_the_dark(shooter, ar.player))
	see_up_to.call(6)
	check("  one you can see may always fire", ar._fair_from_the_dark(shooter, ar.player))
	see_up_to.call(0)
	var ally := Entity.new("bone ally", &"skeleton", 20, 20)
	ally.faction = Entity.Faction.PLAYER
	check("  and the bound is only for shots at the player (who has a field of view)",
		ar._fair_from_the_dark(shooter, ally))

## A full pack must not block the stairs (hunt 2026-09-27): with an item lying on
## them, the action key -- a pad's only way down -- used to refuse outright.
func _test_a_full_pack_still_takes_the_stairs() -> void:
	var setup := func(fill: bool) -> GameState:
		var g := GameState.new(4040)
		g.new_game()
		g.entities = [g.player]
		g.player.x = g.stairs.x
		g.player.y = g.stairs.y
		g.player.inventory.clear()
		g.player.equipped.clear()
		if fill:
			while g.player.inventory.size() < Entity.INVENTORY_MAX:
				g.give_item(Item.make(&"dagger"))
		var lying := Item.make(&"buckler")
		lying.x = g.stairs.x
		lying.y = g.stairs.y
		g.ground = [lying]
		return g
	var offers_down := func(g: GameState) -> bool:
		for a in g.actions_here():
			if String(a[1]) == "go down":
				return true
		return false

	var full: GameState = setup.call(true)
	check("the premise: standing on the stairs, pack full, a buckler underfoot",
		full.map.get_tile(full.player.x, full.player.y) == Tiles.STAIRS_DOWN
		and full.player.inventory.size() == Entity.INVENTORY_MAX
		and not full.items_at(full.player.x, full.player.y).is_empty())
	check("the context box offers the stairs", offers_down.call(full))
	var went := full.player_pickup()
	check("and the key takes them (now depth %d)" % full.depth, went and full.depth == 2)

	# Off the stairs, a full pack says what to do -- for the amulet too.
	var plain: GameState = setup.call(true)
	plain.map.set_tile(plain.player.x, plain.player.y, Tiles.FLOOR)
	var amulet := Item.make(&"amulet")
	if amulet != null:
		amulet.x = plain.player.x
		amulet.y = plain.player.y
		plain.ground = [amulet]
	check("the premise: an amulet at your feet, pack full",
		amulet != null and plain.player.inventory.size() == Entity.INVENTORY_MAX)
	check("a full pack refuses it", not plain.player_pickup())
	var said: String = plain.msg_log.entries[-1]["text"]
	check("  and says to make room for it (\"%s\")" % said,
		said.findn("make room for the") >= 0 and said.findn(amulet.name if amulet != null else "?") >= 0)

	var room: GameState = setup.call(false)
	check("with room in the pack, the item still comes first (must succeed)",
		not offers_down.call(room) and room.player_pickup() and room.depth == 1
		and room.player.inventory.size() == 1)

## On load, the trader is found by WHO it is. With a second living neutral on
## the floor after it (mercenaries, wolves), the old relink took the last
## neutral and pointed `trader` at the wrong creature. (Hunt, 2026-09-27.)
func _test_the_trader_is_relinked_by_identity() -> void:
	var gs := GameState.new(4040)
	gs.new_game()
	check("the premise: floor one has a trader", gs.trader_here())
	if not gs.trader_here():
		return
	var real := gs.trader
	var other := Entity.new("wolf", &"wolf", real.x + 3, real.y)
	other.faction = Entity.Faction.NEUTRAL
	gs.entities.append(other)
	check("the premise: a second living neutral stands AFTER the trader",
		gs.entities.find(other) > gs.entities.find(real))
	var loaded := GameState.new(1)
	check("the save loads", loaded.apply_dict(gs.to_dict()))
	check("  and the trader is the trader, not the other neutral (%s)"
		% (loaded.trader.name if loaded.trader != null else "none"),
		loaded.trader != null and loaded.trader.appearance == &"trader")

## Travel opens a shut door instead of walking into it. Found in the 2026-09-27
## hunt: travel stood the player INSIDE a closed, opaque door.
func _test_travel_opens_doors() -> void:
	var gs := GameState.new(4040)
	gs.new_game()
	var c := Vector2i(30, 20)
	for y in range(c.y - 2, c.y + 3):
		for x in range(c.x - 9, c.x + 10):
			gs.map.set_tile(x, y, Tiles.WALL)
	for x in range(c.x - 7, c.x + 8):
		gs.map.set_tile(x, c.y, Tiles.FLOOR)
	gs.map.set_tile(c.x, c.y, Tiles.DOOR_CLOSED)
	gs.map.reveal_all()
	gs.pathfinder.refresh(gs.map)
	gs.entities = [gs.player]
	gs.ground = []
	gs.player.x = c.x - 5
	gs.player.y = c.y
	var goal := Vector2i(c.x + 5, c.y)
	check("the premise: travel plans a route through the shut door",
		gs.begin_travel(goal))
	var inside := 0
	for i in 30:
		if gs.map.get_tile(gs.player.x, gs.player.y) == Tiles.DOOR_CLOSED:
			inside += 1
		if not gs.travelling():
			break
		gs.step_travel()
	check("travel never stands you inside a shut door (%d times)" % inside, inside == 0)
	check("  it opened the door", gs.map.get_tile(c.x, c.y) == Tiles.DOOR_OPEN)
	check("  and arrived (%d, %d)" % [gs.player.x, gs.player.y],
		Vector2i(gs.player.x, gs.player.y) == goal)

## DOORS SHUT BEHIND THINGS: a guard on its round closes the door it came through.
## A door you left open and find shut means something careful passed.
func _test_doors_shut_behind_guards() -> void:
	var gs := GameState.new(4040)
	gs.new_game()
	var c := Vector2i(30, 20)
	var west := Vector2i(c.x - 7, c.y)
	var east := Vector2i(c.x + 7, c.y)
	var build := func(door: int) -> void:
		for y in range(c.y - 2, c.y + 3):
			for x in range(c.x - 9, c.x + 10):
				gs.map.set_tile(x, y, Tiles.WALL)
		for x in range(west.x, east.x + 1):
			gs.map.set_tile(x, c.y, Tiles.FLOOR)
		gs.map.set_tile(c.x, c.y, door)
		gs.pathfinder.refresh(gs.map)
		gs.ground = []
	gs.player.x = 80
	gs.player.y = 40
	var guard_at := func(x: int) -> Entity:
		var g := Entity.new("kobold", &"kobold", x, c.y)
		g.faction = Entity.Faction.MONSTER
		g.patrols = true
		g.alertness = Entity.Alert.ASLEEP
		g.activity = Entity.Activity.PATROLLING
		return g

	# A GUARD ON ITS ROUND, through the real turn logic: it opens the door,
	# walks through, and shuts it behind it.
	build.call(Tiles.DOOR_CLOSED)
	var guard: Entity = guard_at.call(c.x - 2)
	gs.entities = [gs.player, guard]
	gs.patrol_route = [east]
	guard.patrol_at = 0
	var opened := false
	for turn in 10:
		gs._take_ai_turn(guard)
		gs.turns += 1
		opened = opened or gs.map.get_tile(c.x, c.y) == Tiles.DOOR_OPEN
	check("the premise: a guard is a door-opener", guard.door_style() == Entity.Door.OPENS)
	check("the guard opened the door and went through (at %d)" % guard.x,
		opened and guard.x > c.x)
	check("  and shut it behind itself", gs.map.get_tile(c.x, c.y) == Tiles.DOOR_CLOSED)

	# HUNTING, it does not stop to tidy up.
	build.call(Tiles.DOOR_OPEN)
	var chaser: Entity = guard_at.call(c.x - 1)
	chaser.alertness = Entity.Alert.AWAKE
	gs.entities = [gs.player, chaser]
	gs._step_toward(chaser, east)
	gs._step_toward(chaser, east)
	check("the premise: the chaser is past the door (%d)" % chaser.x, chaser.x == c.x + 1)
	check("a creature hunting you leaves the door open",
		not gs._shut_behind(chaser) and gs.map.get_tile(c.x, c.y) == Tiles.DOOR_OPEN)

	# A SQUEEZER never shuts one: it has no hands for doors.
	build.call(Tiles.DOOR_OPEN)
	var rat := Entity.new("giant rat", &"rat", c.x - 1, c.y)
	rat.faction = Entity.Faction.MONSTER
	rat.alertness = Entity.Alert.ASLEEP
	gs.entities = [gs.player, rat]
	gs._step_toward(rat, east)
	gs._step_toward(rat, east)
	check("a rat leaves it as it was", rat.x == c.x + 1
		and not gs._shut_behind(rat) and gs.map.get_tile(c.x, c.y) == Tiles.DOOR_OPEN)

	# NOT ON A FRIEND: the one behind gets through first, then it shuts.
	build.call(Tiles.DOOR_OPEN)
	var lead: Entity = guard_at.call(c.x - 1)
	var follow: Entity = guard_at.call(c.x - 2)
	gs.entities = [gs.player, lead, follow]
	gs._step_toward(lead, east)             # lead onto the door
	gs._step_toward(lead, east)             # lead off it: it means to shut it
	gs._step_toward(follow, east)
	gs._step_toward(follow, east)           # follow now IN the doorway
	check("the premise: the follower is in the doorway, the leader just past it (%d, %d)"
		% [follow.x, lead.x], follow.x == c.x and lead.x == c.x + 1
		and lead.shut_behind == c)
	check("a guard does not shut the door on its friend",
		not gs._shut_behind(lead) and gs.map.get_tile(c.x, c.y) == Tiles.DOOR_OPEN)
	gs._step_toward(lead, east)             # the leader walks on
	gs._step_toward(follow, east)           # the follower steps off the door
	check("the premise: the follower is the last one through (%d, %d)"
		% [follow.x, lead.x], follow.x == c.x + 1 and lead.x == c.x + 2)
	check("  the last one through shuts it (must succeed)",
		gs._shut_behind(follow) and gs.map.get_tile(c.x, c.y) == Tiles.DOOR_CLOSED)

	# NOT ON SOMETHING LYING IN IT.
	build.call(Tiles.DOOR_OPEN)
	var tidy: Entity = guard_at.call(c.x - 1)
	gs.entities = [gs.player, tidy]
	var dropped := Item.make(&"dagger")
	dropped.x = c.x
	dropped.y = c.y
	gs._step_toward(tidy, east)
	gs._step_toward(tidy, east)
	gs.ground = [dropped]
	check("a door with something lying in it stays open",
		not gs._shut_behind(tidy) and gs.map.get_tile(c.x, c.y) == Tiles.DOOR_OPEN)

	# The intent to shut survives a save.
	var mid: Entity = guard_at.call(c.x - 1)
	build.call(Tiles.DOOR_OPEN)
	gs.entities = [gs.player, mid]
	gs._step_toward(mid, east)
	gs._step_toward(mid, east)
	var kept := Entity.from_dict(mid.to_dict())
	check("a guard's door to shut is saved (%s)" % str(kept.shut_behind),
		kept.shut_behind == c and mid.shut_behind == c)

## THE ROAD: the first armour stone, found only in rubble. +1 defense per 4 new
## rooms on this floor, up to +3, starting again on each floor.
func _test_the_road() -> void:
	# --- only from rubble -------------------------------------------------
	check("the premise: the road is in the element table",
		Item.ELEMENTS.has(&"travel") and Item.CATALOGUE.has(&"gem_travel"))
	check("found magic never rolls it", not Item.found_elements().has(&"travel"))
	check("  nor does the trader's three-for-one offer it",
		not Item.chosen_elements().has(&"travel"))
	check("chests, shrines and sacks never hold it",
		not Item.gems_at(10).has(&"gem_travel"))
	check("the rubble roll can", Item.rubble_gems_at(10).has(&"gem_travel"))
	check("  alongside the ordinary gems, not instead of them",
		Item.rubble_gems_at(10).size() == Item.gems_at(10).size() + 1)
	check("  and not on floor one, where no gem exists yet",
		Item.rubble_gems_at(1).is_empty())
	# Found armour: the road is never rolled; the veil and the lantern are
	# (armour's own stones, 2026-10-01), so armour can arrive enchanted now.
	var erng := RandomNumberGenerator.new()
	erng.seed = 77
	var magic_armour := 0
	var roads := 0
	for i in 400:
		var mail := Item._maybe_enchant(Item.make(&"chain_mail"), erng, 19)
		if mail.element == &"travel":
			roads += 1
		elif mail.element != &"":
			magic_armour += 1
	check("no generated armour carries the road (%d of 400)" % roads, roads == 0)
	check("but armour now arrives with the veil or the lantern sometimes (%d of 400)" % magic_armour,
		magic_armour > 0 and magic_armour < 400)
	var trader_gs := GameState.new(4040)
	trader_gs.new_game()
	trader_gs.trader_gems = Trade.GEMS_FOR_ONE
	check("naming it at the counter buys nothing", not trader_gs.trade_buy_gem(&"travel"))
	check("  though a real choice still works (must succeed)",
		trader_gs.trader_here() and trader_gs.trade_buy_gem(&"fire"))

	# The loose stone is REFUSED, in the trader's voice; an ordinary gem is not.
	trader_gs.player.inventory.clear()
	trader_gs.player.equipped.clear()
	trader_gs.trader_gems = 0
	var road_stone := Item.make(&"gem_travel")
	var fire_stone := Item.make(&"gem_fire")
	trader_gs.give_item(road_stone)
	trader_gs.give_item(fire_stone)
	check("the trader will not take a stone of the road",
		Trade.refusal(road_stone).findn("stone of the road") >= 0
		and not trader_gs.trade_sell(trader_gs.player.inventory.find(road_stone)))
	check("  it stays yours", trader_gs.player.inventory.has(road_stone)
		and trader_gs.trader_gems == 0)
	check("  while an ordinary gem is taken (must succeed)",
		trader_gs.trade_sell(trader_gs.player.inventory.find(fire_stone))
		and trader_gs.trader_gems == 1)

	# ROAD ARMOUR is sold only when offered twice.
	var road_coat := Item.make(&"leather_armour")
	road_coat.element = &"travel"
	var spare := Item.make(&"dagger")
	trader_gs.give_item(road_coat)
	trader_gs.give_item(spare)
	var credit_was := trader_gs.trader_credit
	check("offering road armour once stops your hand",
		not trader_gs.trade_sell(trader_gs.player.inventory.find(road_coat)))
	check("  nothing changes hands", trader_gs.player.inventory.has(road_coat)
		and trader_gs.trader_credit == credit_was)
	check("  and the trader says why", trader_gs.msg_log.entries[-1]["text"].findn("stone of the road") >= 0)
	check("offering it again sells it",
		trader_gs.trade_sell(trader_gs.player.inventory.find(road_coat))
		and not trader_gs.player.inventory.has(road_coat)
		and trader_gs.trader_credit == credit_was + Trade.worth(road_coat))
	check("  at the full magic price (%d)" % Trade.worth(road_coat),
		Trade.worth(road_coat) == 1 + Trade.MAGIC)
	# Anything else in between starts it over.
	var road_coat2 := Item.make(&"leather_armour")
	road_coat2.element = &"travel"
	trader_gs.give_item(road_coat2)
	trader_gs.trade_sell(trader_gs.player.inventory.find(road_coat2))
	trader_gs.trade_sell(trader_gs.player.inventory.find(spare))
	check("selling something else in between means asking again",
		not trader_gs.trade_sell(trader_gs.player.inventory.find(road_coat2))
		and trader_gs.player.inventory.has(road_coat2))
	var counter := TradePanel.new()
	counter.state = trader_gs
	counter.close()
	check("  and so does walking away from the counter", trader_gs.road_offered == null)
	counter.free()

	# --- what may hold it ---------------------------------------------------
	check("body armour takes it", Item.make(&"leather_armour").accepts_element(&"travel"))
	check("  a weapon does not", not Item.make(&"dagger").accepts_element(&"travel"))
	check("  nor a shield", not Item.make(&"buckler").accepts_element(&"travel"))

	# --- the bonus --------------------------------------------------------
	var gs := GameState.new(4040)
	gs.new_game()
	gs.entities = [gs.player]
	var coat := Item.make(&"leather_armour")
	coat.element = &"travel"
	gs.player.inventory.clear()
	gs.player.equipped.clear()
	gs.give_item(coat)
	gs.player.equipped[coat.slot] = coat
	# Seventeen small rooms, laid out by hand so the count is exact: room 0 is
	# the start, then sixteen to walk into.
	gs.room_rects.clear()
	for i in 17:
		gs.room_rects.append(Rect2i(2 + (i % 8) * 10, 2 + (i / 8) * 10, 4, 4))
	gs.rooms_found = {0: true}
	gs.player.travel_rooms = 0
	var enter := func(i: int) -> void:
		gs.player.x = gs.room_rects[i].position.x + 1
		gs.player.y = gs.room_rects[i].position.y + 1
		gs._note_rooms()
	var plain_def := gs.player.total_defense()
	enter.call(0)
	check("the starting room does not count", gs.player.travel_rooms == 0)
	var steps: Array = []
	for i in range(1, 17):
		enter.call(i)
		steps.append(gs.player.travel_bonus())
	check("+1 at 4 rooms, +2 at 8, +3 at 12 (%s)" % str(steps),
		steps[2] == 0 and steps[3] == 1 and steps[7] == 2 and steps[11] == 3)
	check("  and never past +3 (%d at 16 rooms)" % steps[15], steps[15] == 3)
	check("it is real defense (%d -> %d)" % [plain_def, gs.player.total_defense()],
		gs.player.total_defense() == plain_def + 3)
	enter.call(5)
	check("a room entered twice counts once", gs.player.travel_rooms == 16)
	gs.player.x = 1
	gs.player.y = 1
	gs._note_rooms()
	check("a corridor counts for nothing", gs.player.travel_rooms == 16)

	var said := false
	for line in gs.msg_log.entries:
		if String(line.get("text", "")).findn("road settles") >= 0:
			said = true
	check("the log says when it grows", said)

	gs.player.equipped.erase(coat.slot)
	check("taken off, it gives nothing", gs.player.travel_bonus() == 0)
	gs.player.equipped[coat.slot] = coat
	check("  put back on, what was walked still counts", gs.player.travel_bonus() == 3)

	# Survives a save.
	var loaded := GameState.new(1)
	check("a save keeps the road (%d rooms)" % gs.player.travel_rooms,
		loaded.apply_dict(gs.to_dict()) and loaded.player.travel_rooms == 16
		and loaded.rooms_found.size() == 17)

	# A new floor starts again at nothing.
	gs.depth += 1
	gs.build_level()
	check("a new floor starts the road again", gs.player.travel_rooms == 0
		and gs.player.travel_bonus() == 0 and gs.rooms_found.size() == 1)

	# A round trip through its name, for the morgue.
	var back := Item.from_display_name(coat.display_name())
	check("road armour round-trips through its name (%s)" % coat.display_name(),
		back != null and back.element == &"travel")

## Leaving the name blank must not change the run. It used to roll a second
## name from the run's rng, so the same seed played differently depending on
## whether you typed one.
func _test_a_blank_name_changes_nothing() -> void:
	var typed := GameState.new(8080)
	typed.new_game()
	var blank := GameState.new(8080)
	blank.new_game()
	var rolled := blank.player_name
	check("the premise: the same seed starts in the same place",
		typed.rng.state == blank.rng.state and rolled != "")
	typed.choose_name("Brad")
	blank.choose_name("")
	check("a typed name is taken (%s)" % typed.player_name, typed.player_name == "Brad")
	check("a blank name keeps the one the dungeon rolled (%s)" % blank.player_name,
		blank.player_name == rolled)
	check("and neither draws from the run -- the seed plays the same either way",
		typed.rng.state == blank.rng.state)
	blank.choose_name("   ")
	check("  spaces alone count as blank", blank.player_name == rolled)
	var long := GameState.new(8080)
	long.new_game()
	long.choose_name("A;name;far;too;long;for;a;stone")
	check("a typed name is cleaned for the morgue (%s)" % long.player_name,
		not long.player_name.contains(";")
		and long.player_name.length() <= Morgue.NAME_MAX)
	# The bug lived in main.gd, not here, so guard the place it lived: naming a
	# run goes through choose_name and never rolls a second name.
	var src := FileAccess.get_file_as_string("res://src/render/main.gd")
	check("main.gd names the run through choose_name",
		src.contains("state.choose_name(") and not src.contains("roll_name("))

## THE TRADER SAYS HOW IT COUNTS, with the scale. Gabe and Brad both stalled on
## the first counter, where every price is 1; the trader now names 1 / 3 / 9.
func _test_the_trader_explains_its_tally() -> void:
	var tally := String(TraderTalk.TALLY["text"])
	var has_tally := func(script: Array) -> bool:
		for beat in script:
			if String(beat["text"]) == tally:
				return true
		return false
	check("the first meeting explains the tally", has_tally.call(TraderTalk.intro()))
	check("so does every run's floor-one trader", has_tally.call(TraderTalk.greeting(true)))
	check("  but not the deeper ones, which stay short",
		not has_tally.call(TraderTalk.greeting(false))
		and TraderTalk.greeting(false).size() < TraderTalk.greeting(true).size())
	# Told BEFORE the counter opens, so it comes before the invitation to trade.
	var g: Array = TraderTalk.greeting(true)
	check("  and before the invitation to show your pack",
		String(g[g.size() - 1]["text"]).begins_with("Show me"))

	# The trader quotes prices. If the prices change, these words must too --
	# this fails first, rather than the trader quietly lying.
	check("the dagger it quotes is worth 1 (%d)" % Trade.worth(Item.make(&"dagger")),
		tally.contains("dagger is worth one") and Trade.worth(Item.make(&"dagger")) == 1)
	check("the short sword, 3 (%d)" % Trade.worth(Item.make(&"short_sword")),
		tally.contains("short sword, three") and Trade.worth(Item.make(&"short_sword")) == 3)
	check("the war axe, 9 (%d)" % Trade.worth(Item.make(&"war_axe")),
		tally.contains("war axe, nine") and Trade.worth(Item.make(&"war_axe")) == 9)
	check("and three gems for one", tally.contains("bring me three")
		and Trade.GEMS_FOR_ONE == 3)

	# The conversation's footer speaks the player's device.
	var talker := TalkPanel.new()
	talker.beats = TraderTalk.greeting(true)
	check("on a keyboard the conversation says space and esc (\"%s\")" % talker.footer(),
		talker.footer().contains("space") and talker.footer().contains("esc"))
	talker.pad_cfg = PadConfig.new()
	talker.pad_input = true
	var pad_foot := talker.footer()
	check("on a pad it names no keyboard key (\"%s\")" % pad_foot,
		not pad_foot.contains("space") and not pad_foot.contains("esc")
		and not pad_foot.contains("backspace"))
	check("  and does name buttons", pad_foot.contains("go on") and pad_foot.contains("leave"))
	talker._at = 1
	check("  offering back once there is a page behind", talker.footer().contains("back"))
	talker.free()
	# main.gd turns B into leaving, before the conversation sees it.
	var msrc := FileAccess.get_file_as_string("res://src/render/main.gd")
	var at_talk := msrc.find("if talk.visible:")
	var b_leaves := msrc.find("key == PACK_BACK_KEY", at_talk)
	var talk_handled := msrc.find("talk.handle_key(", at_talk)
	check("B leaves a conversation on a pad",
		at_talk >= 0 and b_leaves > at_talk and talk_handled > b_leaves)

	# It fits the conversation panel as laid out on a 1600x900 screen.
	var panel := TalkPanel.new()
	panel.font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
	var lines := panel._wrap(tally, TalkPanel.TEXT_MAX)
	var room := int((900.0 - TalkPanel.PAD * 4.0) / TalkPanel.LINE_H)
	check("the tally fits the panel (%d lines of %d)" % [lines.size(), room],
		lines.size() > 1 and lines.size() <= room)
	panel.free()

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
## THE FORAGER'S SATCHEL: a unique offhand bag of ten; worn, it takes the
## food and potions you pick up and lets you pick fungus; from its chooser a
## use costs a turn; set down, fungus takes root; in the pack it still works.
func _test_the_foragers_satchel() -> void:
	var gs := _arena(15, 9)
	gs.player.x = 5
	gs.player.y = 4
	gs.player.max_hp = 30
	gs.player.hp = 10
	gs.player.inventory.clear()
	check("the satchel is a unique the chests can give", Item.uniques(3).has(&"satchel")
		and not Item.uniques(2).has(&"satchel"))
	var bag := Item.make(&"satchel")
	gs.give_item(bag)
	check("it is an offhand piece that holds ten of each", bag.is_satchel() and bag.slot == Item.Slot.OFFHAND
		and bag.holds == 10 and bag.display_name() == "forager's satchel, 0 inside")
	check("in the pack, unworn, it is still the satchel you would open", gs._the_satchel() == bag
		and gs._worn_satchel() == null)
	var potion := Item.make(&"potion_healing")
	potion.x = 5
	potion.y = 4
	gs.ground.append(potion)
	check("unworn, a potion picked up still goes into it (worn only adds the key)",
		gs.player_pickup() and bag.contents.has(potion) and not gs.player.inventory.has(potion))
	bag.contents.erase(potion)
	check("it cannot be dropped: it lives with you",
		not gs.player_drop(gs.player.inventory.find(bag)) and gs.player.inventory.has(bag)
		and gs.msg_log.entries[-1]["text"].contains("stays with you"))
	gs._toggle_equip(bag)
	check("worn in the offhand", gs.player.is_equipped(bag) and gs._worn_satchel() == bag)
	potion.x = 5
	potion.y = 4
	gs.ground.append(potion)
	var t0 := gs.turns
	check("worn, a potion picked up goes into it, for a turn (and must)",
		gs.player_pickup() and bag.contents.has(potion) and not gs.player.inventory.has(potion)
		and gs.turns == t0 + 1)
	# Fungus is picked, not eaten, and stacks.
	gs.map.set_tile(5, 4, Tiles.FUNGUS)
	check("standing on fungus, worn, the box offers to pick it",
		str(gs.actions_here()).findn("pick the fungus") >= 0, str(gs.actions_here()))
	check("picked: the tile is bare and the satchel has a stack (and must)",
		gs.player_pickup() and gs.map.get_tile(5, 4) == Tiles.FLOOR
		and bag.contents.size() == 2 and bag.contents[1].id == &"fungus" and bag.contents[1].count == 1)
	gs.map.set_tile(5, 4, Tiles.FUNGUS)
	check("a second fungus joins the stack", gs.player_pickup() and bag.contents.size() == 2
		and bag.contents[1].count == 2 and bag.contents[1].display_name() == "fungus x2")
	# The chooser.
	var panel := InventoryPanel.new()
	panel.state = gs
	panel.open_for_satchel()
	check("the chooser lists what it holds, lettered a, b",
		panel.satchel_mode and panel._build_rows().size() == 2
		and panel.letter_to_index(KEY_A) == 0 and panel.letter_to_index(KEY_B) == 1
		and panel._keyboard_footer().contains("set down"))
	check("its title counts the satchel, not the pack", panel.count_line() == "3 inside · 10 of each",
		panel.count_line())
	check("it is slung, not raised", bag.verb() == "sling" and Item.make(&"buckler").verb() == "raise")
	var hp0 := gs.player.hp
	var t1 := gs.turns
	check("using the potion from it heals, spends it, and costs a turn (and must)",
		gs.player_use_from_satchel(0) and gs.player.hp > hp0 and not bag.contents.has(potion)
		and gs.turns == t1 + 1)
	check("eating one fungus from the stack takes one",
		gs.player_use_from_satchel(0) and bag.contents.size() == 1 and bag.contents[0].count == 1)
	gs.player.hp = gs.player.max_hp
	check("whole, the fungus is refused and kept", not gs.player_use_from_satchel(0)
		and bag.contents.size() == 1)
	# Set down, it takes root -- on open floor only.
	gs.map.set_tile(5, 4, Tiles.WATER)
	check("on water it will not take root", not gs.player_drop_from_satchel(0)
		and bag.contents.size() == 1)
	gs.map.set_tile(5, 4, Tiles.FLOOR)
	check("on floor it does, and glows again (and must)", gs.player_drop_from_satchel(0)
		and gs.map.get_tile(5, 4) == Tiles.FUNGUS and bag.contents.is_empty())
	gs.map.set_tile(5, 4, Tiles.FLOOR)
	# Anything else comes out ONE at a time, as from the pack (day-7 hunt,
	# 2026-10-04: the whole shelf hit the floor while the log said "drop it").
	var shelf3 := Item.make(&"potion_healing")
	shelf3.count = 3
	bag.contents.append(shelf3)
	var floor_had := gs.items_at(5, 4).size()
	var dropped_one := gs.player_drop_from_satchel(0)
	var said_drop := str(gs.msg_log.entries.back())
	check("a potion out of a shelf of three drops ONE, and says how many are left (and must)",
		dropped_one and gs.items_at(5, 4).size() == floor_had + 1
		and gs.items_at(5, 4).back().count == 1 and shelf3.count == 2
		and bag.contents.has(shelf3) and said_drop.contains("x2 left"), said_drop)
	gs.player_drop_from_satchel(0)
	check("and the last one takes the shelf with it",
		gs.player_drop_from_satchel(0) and bag.contents.is_empty()
		and gs.items_at(5, 4).size() == floor_had + 3)
	# Cleared: the shelf test below picks up off this same square.
	for lying in gs.items_at(5, 4):
		gs.ground.erase(lying)
	# A SHELF PER KIND, ten to a shelf (2026-10-03). Full of potions, the pack
	# takes the eleventh; a haunch still has a shelf of its own.
	var ten := Item.make(&"potion_healing")
	ten.count = 10
	bag.contents.append(ten)
	var extra := Item.make(&"potion_healing")
	extra.x = 5
	extra.y = 4
	gs.ground.append(extra)
	check("a full shelf sends the eleventh potion to the pack",
		gs.player_pickup() and gs.player.inventory.has(extra) and bag.contents.size() == 1
		and ten.count == 10 and bag.display_name() == "forager's satchel, 10 inside")
	var haunch := Item.make(&"meat")
	haunch.x = 5
	haunch.y = 4
	gs.ground.append(haunch)
	check("while a haunch goes in on its own shelf (and must)",
		gs.player_pickup() and bag.contents.has(haunch) and bag.contents.size() == 2
		and gs.msg_log.entries[-1]["text"].contains("(x1)"))
	var shrooms := Item.make(&"fungus")
	shrooms.count = 10
	bag.contents.append(shrooms)
	check("ten fungus fill their shelf: eaten, not picked", not gs._can_pick_fungus())
	shrooms.count = 9
	check("  nine leave room for one more", gs._can_pick_fungus())
	# Saved inside the item.
	ten.count = 3
	var back := Item.from_dict(bag.to_dict())
	check("what it holds is saved with it, stacks and all",
		back != null and back.is_satchel() and back.contents.size() == 3
		and back.contents[0].count == 3)
	# TAKING IT FILLS IT: what the pack held that fits moves in, ten of each,
	# the rest staying put, and the log says what moved.
	var finder := _arena(15, 9)
	finder.player.x = 5
	finder.player.y = 4
	finder.player.inventory.clear()
	finder.player.equipped.clear()
	var dozen := Item.make(&"potion_healing")
	dozen.count = 12
	finder.give_item(dozen)
	var rabbit := Item.make(&"meat")
	finder.give_item(rabbit)
	var blade := Item.make(&"dagger")
	finder.give_item(blade)
	var lying_bag := Item.make(&"satchel")
	lying_bag.x = 5
	lying_bag.y = 4
	finder.ground.append(lying_bag)
	check("precondition: twelve potions, a haunch and a dagger in the pack, the satchel underfoot",
		finder.player.inventory.size() == 3 and dozen.count == 12 and finder.items_at(5, 4).has(lying_bag))
	check("picking it up moves the food in: ten potions and the haunch (and must)",
		finder.player_pickup() and finder.player.inventory.has(lying_bag)
		and lying_bag.contents.size() == 2 and lying_bag.contents[0].id == &"potion_healing"
		and lying_bag.contents[0].count == 10 and lying_bag.contents[1] == rabbit
		and lying_bag.satchel_count() == 11)
	check("  the two potions over the shelf stay in the pack, the dagger too",
		dozen.count == 2 and finder.player.inventory.has(dozen) and finder.player.inventory.has(blade)
		and not finder.player.inventory.has(rabbit) and rabbit.letter == "")
	var told2 := ""
	for line in finder.msg_log.entries:
		told2 += str(line["text"]) + "|"
	check("  and the log says what moved", told2.contains("go into the satchel: potion of healing x10, haunch of rabbit"), told2)
	check("  worn or not, fungus can be picked", finder._can_pick_fungus())

	# An old save's satchel of ten single haunches folds onto shelves on load.
	var olds := _arena(15, 9)
	olds.player.inventory.clear()
	olds.player.equipped.clear()
	var oldbag := Item.make(&"satchel")
	for i in 4:
		oldbag.contents.append(Item.make(&"meat"))
	for i in 2:
		oldbag.contents.append(Item.make(&"potion_healing"))
	olds.player.inventory.append(oldbag)
	var loaded := GameState.new(1)
	loaded.new_game()
	check("an old satchel's slots fold onto shelves on load", loaded.apply_dict(olds.to_dict())
		and loaded.player.inventory[0].contents.size() == 2
		and loaded.player.inventory[0].satchel_count() == 6)
	# The keys: s on a keyboard, d-pad down on a pad, and the pack's d-pad
	# down still drops.
	check("s opens it and d-pad down is bound to it",
		int(PadConfig.DEFAULTS[JOY_BUTTON_DPAD_DOWN]) == KEY_S
		and MainScene.pad_pack_action(KEY_S, false, false) == &"drop")
	# The pane says how to open it and what it holds (Brad, 2026-10-01).
	var pane := InventoryPanel.new()
	pane.state = gs
	pane.font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
	var told := ""
	for line in pane.detail_lines(bag):
		told += String(line["text"]) + "|"
	check("the pack's pane names the key and lists its shelves",
		told.contains("s: open it") and told.contains("· potion of healing x3")
		and told.contains("· fungus x9") and not told.contains("more"), told)
	pane.pad_cfg = PadConfig.new()
	pane.pad_input = true
	told = ""
	for line in pane.detail_lines(bag):
		told += String(line["text"]) + "|"
	check("and on a pad, the button",
		told.contains("%s: open it" % PadConfig.button_name(JOY_BUTTON_DPAD_DOWN)), told)
	bag.contents.clear()
	told = ""
	for line in pane.detail_lines(bag):
		told += String(line["text"]) + "|"
	check("empty, it says so", told.contains("empty"), told)

	# It takes no hand (Brad, from play: wearing it put his weapon on his
	# back): a bow and the satchel together, a shield and a bow still not.
	var hands := _arena(9, 7)
	hands.player.inventory.clear()
	var bow := Item.make(&"short_bow")
	var strap := Item.make(&"satchel")
	var buckler := Item.make(&"buckler")
	for it in [bow, strap, buckler]:
		hands.give_item(it)
	hands._toggle_equip(bow)
	hands._toggle_equip(strap)
	check("a bow in hand and the satchel on its strap, together",
		hands.player.is_equipped(bow) and hands.player.is_equipped(strap))
	hands._toggle_equip(strap)
	hands._toggle_equip(buckler)
	check("precondition: a shield still takes the bow's hands",
		hands.player.is_equipped(buckler) and not hands.player.is_equipped(bow))
	hands._toggle_equip(strap)
	hands._toggle_equip(bow)
	check("and a bow taken up keeps the satchel on", hands.player.is_equipped(bow)
		and hands.player.is_equipped(strap) and not hands.player.is_equipped(buckler))

	# BY THE CAVES (Brad): a run that reaches the first cave floor without one
	# finds it lying there, in the far room; a run carrying one does not; and
	# the floor above the caves holds no such promise.
	var first_cave := -1
	for d in range(2, 8):
		if Bands.is_caves(d) and not Bands.is_caves(d - 1):
			first_cave = d
	check("precondition: the caves begin at a known floor", first_cave == 4, "%d" % first_cave)
	var lying := func(g: GameState) -> Item:
		for it in g.ground:
			if it.is_satchel():
				return it
		return null
	var above := GameState.new(777)
	above.new_game()
	above.depth = first_cave - 1
	above.build_level()
	check("the floor above the caves lays none down", lying.call(above) == null
		and not above.uniques_found.has(&"satchel"))
	var cave := GameState.new(777)
	cave.new_game()
	cave.depth = first_cave
	cave.build_level()
	var found: Item = lying.call(cave)
	check("the first cave floor has one lying there (and must)", found != null
		and cave.uniques_found.has(&"satchel"))
	check("not in the room you woke in", found != null and not cave.room_rects.is_empty()
		and not cave.room_rects[0].has_point(Vector2i(found.x, found.y)))
	var carrying := GameState.new(777)
	carrying.new_game()
	carrying.give_item(Item.make(&"satchel"))
	carrying.depth = first_cave
	carrying.build_level()
	check("a run already carrying one is not given a second", lying.call(carrying) == null
		and carrying.uniques_found.has(&"satchel"))
	var climbing := GameState.new(777)
	climbing.new_game()
	climbing.ascending = true
	climbing.depth = first_cave
	climbing.build_level()
	check("nothing on the climb", lying.call(climbing) == null)

## PITS AS ESCAPE (Dwarf Fortress plan, strand 5): a fleeing creature chased
## in your light turns running leaps into a pit beside it, and lands on the
## next floor wounded, awake, hunting and vengeful; the trader has heard.
func _test_pits_are_an_escape() -> void:
	# A corridor: the bear can only run east, and the pit is where the
	# corridor would have cornered it -- the case the strand exists for.
	var gs := _arena(21, 3)
	# Three cells off, not two: within FIRE_FEAR_REACH of your torch a struck
	# bear is cornered by flame and will not flee (2026-10-09).
	gs.player.x = 4
	gs.player.y = 1
	gs.torch_lit = true
	gs.map.set_tile(9, 1, Tiles.PIT)
	gs.pathfinder = Pathfinder.new(gs.map)
	var bear := _spawn(gs, "cave bear", 7, 1)
	bear.hp = 4
	# A bear you have been fighting: WILD since 2026-10-04, it has to have
	# been struck to be hunting you, and only a hunter breaks and runs.
	bear.provoked = true
	var bear_power := bear.power
	var bear_threat := bear.threat
	gs._gather_lights()
	gs.update_vision()
	check("precondition: the bear is in your light and your sight",
		gs.map.is_visible(bear.x, bear.y)
		and gs.light_map.get_light(bear.x, bear.y).get_luminance() >= GameState.CHASE_LIGHT)
	gs._take_ai_turn(bear)
	check("it breaks, and the chase is counted", bear.fleeing and bear.chased == 1
		and gs.entities.has(bear), "chased %d" % bear.chased)
	for i in 4:
		if not gs.entities.has(bear):
			break
		gs._take_ai_turn(bear)
	var said := ""
	for line in gs.msg_log.entries:
		said += str(line) + "|"
	check("chased three turns in the light, it leaps into the pit (and must)",
		not gs.entities.has(bear) and gs.fallen.size() == 1, "chased %d, fallen %d" % [bear.chased, gs.fallen.size()])
	check("and the log says so", said.contains("leaps into the pit"), said)
	var d: Dictionary = gs.fallen[0] if not gs.fallen.is_empty() else {}
	check("it goes down with half what it had, vengeful, stronger, worth more",
		int(d.get("hp", 0)) == 2 and bool(d.get("vengeful", false))
		and String(d.get("name", "")) == "vengeful cave bear"
		and int(d.get("power", 0)) == bear_power + GameState.REVENGE_POWER
		and int(d.get("threat", 0)) > bear_threat, str(d.get("name", "")))
	var saved := GameState.new(1)
	saved.new_game()
	check("the fall is saved with the run", saved.apply_dict(gs.to_dict()) and saved.fallen.size() == 1)
	gs.depth += 1
	gs.build_level()
	var landed: Entity = null
	for e in gs.entities:
		if e.name == "vengeful cave bear":
			landed = e
	check("it lands on the next floor, awake, hunting you, and not at your feet",
		landed != null and landed.alive and landed.blocks
		and landed.alertness == Entity.Alert.AWAKE
		and landed.last_seen == Vector2i(gs.player.x, gs.player.y)
		and Los.steps(landed.x, landed.y, gs.player.x, gs.player.y) > 5)
	check("the list is spent, and the trader has heard",
		gs.fallen.is_empty() and gs.something_fell
		and str(TraderTalk.greeting(false, true)).findn("fell in from above") >= 0)
	check("and says nothing of the kind otherwise",
		str(TraderTalk.greeting(false, false)).findn("fell in") < 0)
	gs.depth += 1
	gs.build_level()
	check("the floor after starts clean", not gs.something_fell)

	# In the dark it is only running: the count never starts, and no leap.
	var ds := _arena(21, 3)
	ds.player.x = 5
	ds.player.y = 1
	ds.torch_lit = false
	ds.map.set_tile(9, 1, Tiles.PIT)
	ds.pathfinder = Pathfinder.new(ds.map)
	var dark_bear := _spawn(ds, "cave bear", 7, 1)
	dark_bear.hp = 4
	dark_bear.provoked = true
	ds._gather_lights()
	ds.update_vision()
	check("precondition: unlit", ds.light_map.get_light(dark_bear.x, dark_bear.y).get_luminance()
		< GameState.CHASE_LIGHT)
	for i in 5:
		if ds.entities.has(dark_bear):
			ds._take_ai_turn(dark_bear)
	check("in the dark it runs and never leaps",
		ds.entities.has(dark_bear) and ds.fallen.is_empty() and dark_bear.chased == 0,
		"chased %d" % dark_bear.chased)

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
	check("precondition: the two potions are one stack", a.count == 2
		and not gs.player.inventory.has(b))
	check("a potion works", gs.player_use(gs.player.inventory.find(a)))
	check("  and costs a turn", gs.turns == t0 + 1, "%d -> %d" % [t0, gs.turns])
	check("so does the second", gs.player_use(gs.player.inventory.find(a))
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
			# Keycap is the second honest route: it draws every label through
			# PadGlyphs itself (checked below), so a panel that draws its keys
			# as caps asks for pictures and never touches the text font.
			if asks and src.find("PadGlyphs.") < 0 and src.find("Keycap.") < 0 \
					and f != "pad_glyphs.gd":
				careless.append(f)
	check("every panel that shows button pictures draws them directly",
		careless.is_empty(), ", ".join(careless))
	var keycap_src := FileAccess.get_file_as_string("res://src/ui/keycap.gd")
	check("and a keycap is lettered through PadGlyphs (the premise of the route above)",
		keycap_src.find("PadGlyphs.draw(") >= 0 and keycap_src.find("PadGlyphs.width(") >= 0)

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

	# EVERY DOCUMENTED BUTTON REACHES ITS ACTION, through the DEFAULT bindings.
	#
	# The checks below this block only prove no button does anything
	# UNEXPECTED -- and a button that does nothing at all passes them. That is
	# how a 3D-view patch (2026-09-26) rebound d-pad up from `O` to `Q` while the
	# pack still listened for `O`, silently killing "use" on every controller,
	# and this suite stayed green. So: the button, as bound out of the box, and
	# what it must do.
	var via := func(button: int) -> StringName:
		return MainScene.pad_pack_action(cfg.key_for_button(button), false, false)
	var wiring := {
		JOY_BUTTON_DPAD_UP: &"use", JOY_BUTTON_DPAD_DOWN: &"drop",
		JOY_BUTTON_DPAD_LEFT: &"forge", JOY_BUTTON_DPAD_RIGHT: &"throw",
		JOY_BUTTON_Y: &"forge", JOY_BUTTON_B: &"close", JOY_BUTTON_START: &"close",
	}
	var unwired := PackedStringArray()
	for button in wiring:
		var got: StringName = via.call(button)
		if got != wiring[button]:
			unwired.append("%s -> %s, not %s" % [PadConfig.button_name(int(button)),
				got if got != &"" else &"nothing", wiring[button]])
	check("each pack button does its job out of the box (%d)" % wiring.size(),
		unwired.is_empty(), ", ".join(unwired))
	# The trader's counter reads the same constants: A confirms, Y enchants, B leaves.
	check("at the trader, A confirms",
		cfg.key_for_button(JOY_BUTTON_A) in MainScene.CONFIRM)
	check("  Y is the enchant key",
		cfg.key_for_button(JOY_BUTTON_Y) == MainScene.PACK_FORGE_KEY)
	check("  B is the leave key",
		cfg.key_for_button(JOY_BUTTON_B) == MainScene.PACK_BACK_KEY)

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
	panel.morgue_requested.connect(func() -> void: fired["v"] = "morgue")
	panel.help_requested.connect(func() -> void: fired["v"] = "help")

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
	# +24 for the pad footer, a row of caps drawn 24px under the keyboard one,
	# and +5 for a cap's reach below its baseline (Keycap.H - 15).
	var pad_bottom: float = PadPanel.PAD + PadPanel.font_size_default() \
		+ 2.0 * PadPanel.ROW_H + PadPanel.left_rows() * PadPanel.ROW_H + 6.0 \
		+ 24.0 + 5.0
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
		if line is Dictionary and line.has("chips"):
			# A creature's state chips (2026-10-07): each needs its words.
			for chip in line["chips"]:
				if String(chip.get("text", "")) == "":
					broken.append("chip with no words: %s" % str(line))
		elif line is Dictionary:
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

## The 3D view sizes its billboards from ink measured out of the font, so the
## measurements have to cover every picture it can stand up -- a missing one
## falls back to a letter's shape and the creature comes out the wrong size
## with nothing reported. Rebuilding the font rewrites the table; this catches
## an icon added to the theme without that step.
##
## And the reason the table exists: the font draws the child figure 39% taller
## than the adult one, so sizing by em put the kobold above the orc. The 3D
## ladder must read small < adult < heavy, as GlyphTheme promises for classic.
func _test_billboard_sizes() -> void:
	var unmeasured: Array = []
	for id in GlyphTheme.OVERRIDES:
		if not GlyphMetrics.GLYPHS.has(int(GlyphTheme.OVERRIDES[id])):
			unmeasured.append(id)
	check("every picture the 3D view can stand up has measured ink",
		unmeasured.is_empty(), "run tools/build_icon_font.py --metrics: %s" % str(unmeasured))

	# A typo here would size nothing and fall silently to the default.
	var unknown: Array = []
	for id in BillboardSizes.BOX:
		if not AsciiTheme.TABLE.has(id):
			unknown.append(id)
	check("every 3D size names a real appearance", unknown.is_empty(), str(unknown))

	var theme := GlyphTheme.new()
	var tall := {}
	for id in [&"kobold", &"orc", &"ogre"]:
		var ch: String = theme.appearance(id)["ch"]
		tall[id] = DioramaView._ink_size(ch,
			BillboardSizes.box(id, BillboardSizes.CREATURE)).y
	check("in 3D a kobold stands shorter than an orc, an orc than an ogre (%.2f / %.2f / %.2f)"
		% [tall[&"kobold"], tall[&"orc"], tall[&"ogre"]],
		tall[&"kobold"] < tall[&"orc"] and tall[&"orc"] < tall[&"ogre"])
	# The fit keeps a picture's shape inside its box, and fills it one way.
	var box := BillboardSizes.box(&"dragon", BillboardSizes.CREATURE)
	var dragon := DioramaView._ink_size(theme.appearance(&"dragon")["ch"], box)
	check("a picture fits its box and fills it one way (dragon %.2f x %.2f)" % [dragon.x, dragon.y],
		dragon.x <= box.x + 0.001 and dragon.y <= box.y + 0.001
		and (is_equal_approx(dragon.x, box.x) or is_equal_approx(dragon.y, box.y)))

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
	var cave_down := MapMemory.CAVE_MEMORY
	check("and the corrupted ones only just (Brad, 2026-09-29: barely visible)",
		grid._memory_strength() > 0.0 and grid._memory_strength() < cave_down,
		str(grid._memory_strength()))
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
		var was := Vector2i(gs.player.x, gs.player.y)
		var walked := gs.begin_travel(Vector2i(8, 4))
		if as_rat:
			check("a rat walks past a sleeping monster", walked)
		else:
			# ONE STEP PER CLICK while something watches (Gabe's rule, kept by
			# Brad 2026-09-27: a click is an explicit command, and a mouse player
			# near a monster needs the same careful single step a key gives).
			# The click moves you one cell, then the queued route is dropped.
			var moved := maxi(absi(gs.player.x - was.x), absi(gs.player.y - was.y))
			check("on two feet a click takes one step (%d), then you stop for it" % moved,
				walked and moved == 1 and not gs.travelling())

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
		var was2 := Vector2i(gs2.player.x, gs2.player.y)
		var went := gs2.begin_travel(Vector2i(8, 4))
		var moved2 := maxi(absi(gs2.player.x - was2.x), absi(gs2.player.y - was2.y))
		check("an awake monster holds travel to one step per click (rat=%s, moved %d)"
			% [as_rat, moved2], went and moved2 == 1 and not gs2.travelling())

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
	GameState.clear_scratch_files()
	for i in 60:
		for d in GameState.GEM_PITY_FLOORS:
			var gs := GameState.new(23000 + i * 29 + int(d))
			gs.use_scratch_files("pity%d_%d" % [i, int(d)])
			gs.new_game()
			gs.depth = d
			gs.build_level()
			if gs.room_rects.size() < 2:
				GameState.clear_scratch_files()
				continue
			var gem: Item = null
			for it in gs.ground:
				if it.kind == Item.Kind.GEM:
					gem = it
					break
			if gem == null:
				GameState.clear_scratch_files()
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
			GameState.clear_scratch_files()
	GameState.clear_scratch_files()
	GameState.use_scratch_files("tests")
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

## THE BESTIARY PAGE (2026-10-10): what is not met is "???" and nothing else;
## what is, its words and numbers from its own table; items known once seen,
## lying or carried. See BestiaryPanel.
func _test_the_bestiary_page() -> void:
	var was := BestiaryLog._path
	BestiaryLog.use_path("user://scratch_bestiary_page.txt")
	BestiaryLog.clear_scratch()
	var panel := BestiaryPanel.new()
	var creatures := BestiaryPanel.creature_entries()
	var items := BestiaryPanel.item_entries()
	var ids := []
	for e in creatures:
		ids.append(e["id"])
	check("precondition: every creature has an entry, you and the trader first (%d)" % creatures.size(),
		creatures.size() == GameState.BESTIARY.size() + 4 and ids[0] == &"player"
		and ids[1] == &"trader" and ids.has(&"spider") and ids.has(&"killer_rabbit"))
	check("  and every item in the catalogue (%d)" % items.size(), items.size() == Item.CATALOGUE.size())
	check("a fresh record knows you and the trader, and nothing else",
		BestiaryPanel.known_count(creatures) == 2 and BestiaryPanel.known_count(items) == 0)
	var spider: Dictionary = {}
	for e in creatures:
		if e["id"] == &"spider":
			spider = e
	var hidden := panel.describe(spider)
	check("an unmet creature is ??? -- no tags, no numbers",
		hidden["title"] == "???" and hidden["tags"] == "" and (hidden["stats"] as Array).is_empty())
	BestiaryLog.note(&"spider")
	creatures = BestiaryPanel.creature_entries()
	for e in creatures:
		if e["id"] == &"spider":
			spider = e
	var shown := panel.describe(spider)
	var stats := {}
	for row in shown["stats"]:
		stats[row[0]] = row[1]
	var row: Dictionary = spider["row"]
	check("met, it has its name, its tags, its ways and its numbers (the must-succeed)",
		shown["title"] == "SPIDER" and String(shown["tags"]).begins_with("wild animal")
		and (shown["lines"] as Array).has("Its bite poisons.")
		and (shown["lines"] as Array).has("Flees up the walls.")
		and stats.get("HP") == str(int(row["hp"])) and stats.get("power") == str(int(row["power"])))
	# Items: seen lying, or carried.
	var gs := _arena(21, 9)
	gs.player.x = 5
	gs.player.y = 4
	gs.player.inventory.clear()
	var sword := Item.make(&"short_sword")
	sword.x = 7
	sword.y = 4
	gs.ground.append(sword)
	var far := Item.make(&"war_bow")
	far.x = 18
	far.y = 7
	gs.ground.append(far)
	gs.map.clear_visible()
	gs.map.show_cell(7, 4)
	gs._note_sightings()
	check("an item in sight is learned, one out of sight is not",
		BestiaryLog.knows_item(&"short_sword") and not BestiaryLog.knows_item(&"war_bow"))
	gs.player.inventory.append(Item.make(&"potion_healing"))
	gs._note_sightings()
	check("  and what you carry is known", BestiaryLog.knows_item(&"potion_healing"))
	var by_id := {}
	for e in BestiaryPanel.item_entries():
		by_id[e["id"]] = e
	var blade := panel.describe(by_id[&"short_sword"])
	var potion := panel.describe(by_id[&"potion_healing"])
	var unseen := panel.describe(by_id[&"war_bow"])
	check("a known weapon says what it is and its power",
		String(blade["tags"]).begins_with("weapon") and (blade["stats"] as Array).has(["power", "+4"]))
	check("  a potion what it does", (potion["lines"] as Array).has("Heals 12."))
	check("  and an unseen bow is ???", unseen["title"] == "???" and (unseen["stats"] as Array).is_empty())
	check("creature records are untouched by item ones", not BestiaryLog.knows(&"short_sword"))
	panel.free()
	BestiaryLog.clear_scratch()
	BestiaryLog.use_path(was)

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
	# A wolf leaves its own (2026-10-05): a rabbit's base worth, and never
	# merged with a rabbit's haunch.
	var wolf := _spawn(gs, "wolf", 8, 4)
	gs._drop_meat(wolf)
	var wolf_cut: Item = null
	for it in gs.ground:
		if it.id == &"wolf_meat":
			wolf_cut = it
	check("a wolf leaves a haunch of wolf", wolf_cut != null and wolf_cut.name == "haunch of wolf")
	check("  worth a rabbit's base plus depth (%d)" % (wolf_cut.effective_magnitude() if wolf_cut else -1),
		wolf_cut != null and wolf_cut.effective_magnitude()
			== GameState.MEAT_BASE + int(floor(9.0 / GameState.MEAT_PER_DEPTH)))
	check("  and it never stacks with a rabbit's", wolf_cut != null and not haunch.stacks_with(wolf_cut))
	check("  a hunter eats it like any haunch", GameState._is_meat(wolf_cut))
	# INTO THE SATCHEL FIRST (Brad, 2026-10-05; shown by a probe that day,
	# owed a test until 2026-10-07): picked up, a wolf's haunch goes on its
	# own shelf in the satchel and the pack is not touched; a rabbit's
	# beside it takes a shelf of its own.
	var sack := Item.make(&"satchel")
	gs.give_item(sack)
	wolf_cut.x = gs.player.x
	wolf_cut.y = gs.player.y
	var pack_n := gs.player.pack_count()
	check("precondition: a satchel with a shelf for the haunch of wolf, under your feet",
		gs._the_satchel() == sack and sack.satchel_takes(wolf_cut)
		and gs.ground.has(wolf_cut) and sack.satchel_count() == 0)
	check("a haunch of wolf picked up goes into the satchel",
		gs.player_pickup() and not gs.ground.has(wolf_cut) and sack.satchel_count() == 1
		and sack.contents[0].id == &"wolf_meat")
	check("  and the pack is not touched (%d -> %d)" % [pack_n, gs.player.pack_count()],
		gs.player.pack_count() == pack_n)
	var shelf_cut := Item.make(&"meat")
	shelf_cut.x = gs.player.x
	shelf_cut.y = gs.player.y
	gs.ground.append(shelf_cut)
	gs.player_pickup()
	check("  a rabbit's haunch beside it takes its own shelf",
		sack.contents.size() == 2 and sack.satchel_count() == 2)
	gs.ground.erase(shelf_cut)
	gs.player.inventory.erase(sack)
	gs.player.equipped.erase(Item.Slot.OFFHAND)
	gs.ground.erase(wolf_cut)
	gs.entities.erase(wolf)
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
	# FULL, BUT THE ITEM STILL GOES: into a stack it matches, or the satchel's
	# shelf. The key takes it (2026-10-03) -- so the box must offer it, not
	# the stairs (day-7 hunt, 2026-10-04: it offered "go down" while g picked
	# up the potion). Then, with nowhere for it at all, both say the stairs.
	gs.player.inventory.clear()
	gs.player.equipped.clear()
	# Twenty things that stack with nothing: elemental daggers are one to a
	# slot. On a fungus square, so the square's own action is harmless.
	for i in Entity.INVENTORY_MAX:
		var blade := Item.make(&"dagger")
		blade.element = &"fire"
		gs.give_item(blade)
	gs.map.set_tile(5, 5, Tiles.FUNGUS)
	gs.player.hp = gs.player.max_hp
	check("precondition: the pack is full, twenty slots", gs.player.pack_count() == Entity.INVENTORY_MAX
		and gs.player.inventory.size() == Entity.INVENTORY_MAX)
	var heal := Item.make(&"potion_healing")
	heal.x = 5
	heal.y = 5
	gs.ground = [heal]
	var left := gs.actions_here()
	check("full, a potion that stacks with nothing is left for the square's own use",
		String(left[0][1]) == "eat the fungus", str(left))
	check("  and the key agrees: it tries the fungus (whole, refused) and leaves the potion",
		not gs.player_pickup() and gs.ground.has(heal) and gs.player.inventory.size() == Entity.INVENTORY_MAX)
	var carried := Item.make(&"potion_healing")
	gs.player.inventory.remove_at(0)
	gs.give_item(carried)
	check("precondition: full again, with one potion in the pack to stack on",
		gs.player.pack_count() == Entity.INVENTORY_MAX and gs._stack_for(heal) == carried)
	var stacked := gs.actions_here()
	check("full, a potion that joins a stack is offered, not the square",
		String(stacked[0][1]) == "pick up the potion of healing", str(stacked))
	check("  and the key picks it up onto the stack", gs.player_pickup()
		and carried.count == 2 and not gs.ground.has(heal))
	# The satchel's shelf: the same promise.
	gs.player.inventory.erase(carried)
	var bag := Item.make(&"satchel")
	gs.give_item(bag)
	var meal := Item.make(&"meat")
	meal.x = 5
	meal.y = 5
	gs.ground = [meal]
	check("precondition: full, and the satchel has a shelf for the haunch",
		gs.player.pack_count() == Entity.INVENTORY_MAX and bag.satchel_takes(meal))
	var shelved := gs.actions_here()
	check("full, food the satchel takes is offered, not the square",
		String(shelved[0][1]) == "pick up the haunch of rabbit", str(shelved))
	check("  and the key puts it in the satchel", gs.player_pickup() and bag.satchel_count() == 1
		and not gs.ground.has(meal))
	gs.ground = []
	gs.player.inventory.clear()
	gs.player.equipped.clear()
	gs.map.set_tile(5, 5, Tiles.STAIRS_DOWN)
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
	# The relight offers name the weapon or the gem, and "relight it with the
	# short sword's fire (10)" came out one character past the box (Brad,
	# 2026-10-01). Every weapon in the catalogue, as a fire blade in hand
	# beside a cold brazier, and the gem of fire from the pack.
	gs.map.set_tile(6, 5, Tiles.BRAZIER_DEAD)
	var relights := 0
	for id in Item.CATALOGUE:
		var blade := Item.make(id)
		if blade == null or blade.slot != Item.Slot.WEAPON or blade.transforms():
			continue
		blade.element = &"fire"
		gs.player.equipped[Item.Slot.WEAPON] = blade
		for row in bar.rows():
			var text := String(row[1])
			if not text.begins_with("relight"):
				continue
			relights += 1
			var w := face.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, bar.font_size).x
			if w > widest_px:
				widest_px = w
				widest = text
	gs.player.equipped.erase(Item.Slot.WEAPON)
	var fire_gem := Item.make(&"gem_fire")
	gs.give_item(fire_gem)
	for row in bar.rows():
		var text := String(row[1])
		if text.begins_with("relight"):
			relights += 1
			var w := face.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, bar.font_size).x
			if w > widest_px:
				widest_px = w
				widest = text
	gs.player.inventory.erase(fire_gem)
	gs.map.set_tile(6, 5, Tiles.FLOOR)
	check("precondition: the relight offers were measured (%d)" % relights, relights >= 5)

	# A GEM WITH A USE HERE IS OFFERED BY THE PACK KEY (Brad, 2026-10-01: he had
	# to open the pack to find the crag and the bulwark had one), in words the
	# pack repeats, that fit, and only while the box has room for a row.
	gs.map.set_tile(5, 5, Tiles.FLOOR)
	var crag_gem := Item.make(&"gem_crag")
	gs.give_item(crag_gem)
	check("a crag gem with no pit beside you is not offered",
		str(gs.actions_here()).findn("crag") < 0, str(gs.actions_here()))
	gs.map.set_tile(6, 5, Tiles.PIT)
	var crag_rows := gs.actions_here()
	check("beside a pit the crag is offered, by the pack key",
		crag_rows.size() == 1 and int(crag_rows[0][0]) == KEY_I
		and String(crag_rows[0][1]) == "pack: crag: fill the pit", str(crag_rows))
	# Said as the pack's (Brad, 2026-10-06), and always inside the box.
	check("the row says it is the pack's, and the longest gem row still fits",
		GameState.pack_row("thirst: drink risen kobold slinger (+12)") == "pack: drink risen kobold slinger (+12)"
		and GameState.pack_row("thirst: drink risen kobold slinger (+12)").length() <= GameState.HERE_ROW_CHARS
		and GameState.pack_row("set the gem of frost") == "pack: set the gem of frost")
	var pack := InventoryPanel.new()
	pack.state = gs
	check("and in the pack's own words",
		String(crag_rows[0][1]).ends_with(pack._action_hint(crag_gem)), pack._action_hint(crag_gem))
	gs.map.set_tile(6, 5, Tiles.FLOOR)
	gs.player.inventory.erase(crag_gem)
	# The widest gem line is the drink, named after the body: every creature
	# the bestiary can leave lying there, risen.
	var thirst_gem := Item.make(&"gem_leech")
	gs.give_item(thirst_gem)
	gs.player.hp = 1
	var drinks := 0
	for e in GameState.BESTIARY:
		var m := GameState.monster_from(e, 6, 5)
		m.name = "risen " + m.name
		gs.bodies = [{"x": 6, "y": 5, "app": String(m.appearance), "turn": gs.turns,
			"corrupted": false, "e": m.to_dict(), "seeded": -1, "claimed": false,
			"still": false, "rises": -1}]
		for row in bar.rows():
			var text := String(row[1])
			if not text.contains("drink"):
				continue
			drinks += 1
			var w := face.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, bar.font_size).x
			if w > widest_px:
				widest_px = w
				widest = text
	gs.bodies = []
	gs.player.inventory.erase(thirst_gem)
	check("precondition: the drink offers were measured (%d)" % drinks,
		drinks >= GameState.BESTIARY.size())
	# The fullest the box gets: hurt beside a lit brazier (warm), a cold one
	# beside you with a gem of fire in the pack (relight), and a gem with a
	# use here -- three rows, and "every key" makes four, which is what the box
	# holds. A second gem with a use adds nothing: one gem row at most.
	gs.map.set_tile(4, 5, Tiles.BRAZIER)
	gs.brazier_charge[Vector2i(4, 5)] = 10
	gs.map.set_tile(6, 4, Tiles.BRAZIER_DEAD)
	gs.give_item(fire_gem)
	gs.give_item(crag_gem)
	gs.map.set_tile(6, 5, Tiles.PIT)
	var crowded := gs.actions_here()
	check("warm, relight and a gem's use: three rows, the box's whole room",
		crowded.size() == 3 and str(crowded).findn("warm") >= 0
		and str(crowded).findn("relight") >= 0 and str(crowded).findn("crag") >= 0, str(crowded))
	var bulwark_gem := Item.make(&"gem_bulwark")
	gs.give_item(bulwark_gem)
	gs.map.set_tile(5, 4, Tiles.DOOR_OPEN)
	check("precondition: the second gem has a use here too", gs.bulwark_target().x >= 0)
	check("and still three rows: one gem speaks for the pack", gs.actions_here().size() == 3,
		str(gs.actions_here()))
	gs.player.hp = gs.player.max_hp
	for g in [fire_gem, crag_gem, bulwark_gem]:
		gs.player.inventory.erase(g)
	gs.brazier_charge.erase(Vector2i(4, 5))
	for c in [Vector2i(4, 5), Vector2i(6, 4), Vector2i(6, 5), Vector2i(5, 5), Vector2i(5, 4)]:
		gs.map.set_tile(c.x, c.y, Tiles.FLOOR)
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
	# cannot disagree by construction -- assert that it stayed that way. Every
	# element EXCEPT those deliberately marked `only_from` (the gem of the road,
	# 2026-09-26: the one stone you must explore to find). Exact, so an element
	# dropping out by accident still fails here.
	var found := Item.found_elements()
	var kept_out := 0
	for el in Item.ELEMENTS:
		if Item.ELEMENTS[el].has("only_from"):
			kept_out += 1
		elif not found.has(el):
			kept_out -= 1000
	check("found magic offers every element not kept out (%d, %d kept out)"
		% [found.size(), kept_out],
		kept_out >= 0 and found.size() == Item.ELEMENTS.size() - kept_out,
		"%d vs %d" % [found.size(), Item.ELEMENTS.size()])

	# ORDER IS LOAD-BEARING: _maybe_enchant indexes the legal list with
	# enchant_rng, so a reordering silently changes what a seed rolls.
	check("and in the order the table declares",
		found[0] == &"fire" and found[1] == &"frost" and found[2] == &"leech",
		str(found))

	# Every `hosts` rule must be one accepts_element actually implements. A typo
	# would fall through the match and refuse everything, which reads exactly
	# like "that item cannot hold it" and is invisible in play.
	var known := {&"weapon": true, &"melee": true, &"bow": true, &"shield": true,
		&"armour": true}
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
	check("and armour holds no weapon or shield stone", not mail.accepts_element(&"fire")
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

	# AT MOST HALF A BLOW. Uncapped, a tower bulwark over heavy armour took every
	# hit on the climb to 1 -- the young dragon's (power 14) and the arch lich's
	# (15) included -- so ninety hit points were ninety hits. The table Brad
	# agreed, 2026-09-26: a floored 4 becomes 2, a floored 3 becomes 2.
	var capped := Item.make(&"tower_shield")
	capped.element = &"block"
	gs.player.equipped[Item.Slot.OFFHAND] = capped
	for blow in [[14, 2, "a young dragon"], [15, 2, "an arch lich"], [9, 2, "an ogre"]]:
		gs.player.hp = 9999
		gs._attack(orc, gs.player, false, int(blow[0]))
		var landed := 9999 - gs.player.hp
		check("the bulwark takes %s's floored blow to %d, not 1 (%d)"
			% [blow[2], int(blow[1]), landed], landed == int(blow[1]))

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
## A button pressed twice in the rebinding walk-through MOVES, and the action it
## left must not look finished. Found in the 2026-09-27 hunt: that row stayed
## green, the "done" colour, beside a "--". When the orphan was pick-up the pad
## also lost its way back out of the pack, the conversation and the counter,
## which all go back on whatever button picks up.
func _test_a_moved_button_leaves_its_row_marked() -> void:
	var pad := PadPanel.new()
	var cfg := PadConfig.new()
	pad.open(cfg)
	var pick_up := -1
	var inventory := -1
	for i in PadConfig.WALK.size():
		if int(PadConfig.WALK[i][0]) == KEY_G:
			pick_up = i
		elif int(PadConfig.WALK[i][0]) == KEY_I:
			inventory = i
	check("the premise: pick-up is asked for before inventory",
		pick_up >= 0 and inventory > pick_up, "%d, %d" % [pick_up, inventory])

	# A real walk binds every row it passes -- `_at` only advances inside
	# `bind` -- so bind move-up as the walk would. The defaults leave movement
	# UNBOUND on purpose (the stick sends the arrows natively), which is why
	# jumping `_at` forward without this made an untouched row read as lost:
	# the first version of this test assumed a default that is not there.
	cfg.bind(JOY_BUTTON_DPAD_UP, KEY_UP)
	# B for pick-up, then B again for inventory, walking past both.
	cfg.bind(JOY_BUTTON_B, KEY_G)
	cfg.bind(JOY_BUTTON_B, KEY_I)
	pad._at = inventory + 1
	check("the premise: pick-up is left with no button at all",
		cfg.button_for_key(KEY_G) == -1)
	check("the premise: move-up was bound on the way past",
		cfg.button_for_key(KEY_UP) == JOY_BUTTON_DPAD_UP)

	check("the row a button was taken from reads as lost, not done",
		pad.row_state(pick_up) == &"lost", String(pad.row_state(pick_up)))
	check("  and the row that took it reads as done",
		pad.row_state(inventory) == &"done", String(pad.row_state(inventory)))
	# The two that keep this honest: a helper calling everything lost would
	# pass the line above and fail these.
	check("  while a row nobody touched is still done",
		pad.row_state(0) == &"done", String(pad.row_state(0)))
	check("  and a row not reached yet is still to do",
		pad.row_state(inventory + 1) == &"todo", String(pad.row_state(inventory + 1)))

	# ofr-69's catch: movement is unbound BY DEFAULT (the stick sends the
	# arrows), so a move row passed with no button is working, not lost. The
	# first version of row_state painted it red.
	var fresh := PadPanel.new()
	var plain := PadConfig.new()
	fresh.open(plain)
	fresh._at = inventory + 1
	check("the premise: move-up has no button by default",
		plain.button_for_key(KEY_UP) == -1)
	check("  and a move row passed without one is not called lost",
		fresh.row_state(0) == &"done", String(fresh.row_state(0)))
	fresh.free()
	pad.free()

## The conversation footer must name the button that actually leaves. It used to
## name the B button whatever B was bound to, while leaving listens for the
## pick-up key -- so after moving pick-up to X it said "B leave" and B did
## nothing. Found in the 2026-09-27 hunt.
func _test_the_conversation_footer_names_what_works() -> void:
	var talk := TalkPanel.new()
	var cfg := PadConfig.new()
	talk.pad_input = true
	talk.pad_cfg = cfg
	cfg.bind(JOY_BUTTON_X, MainScene.PACK_BACK_KEY)
	check("the premise: X is now the button that leaves a conversation",
		cfg.button_for_key(MainScene.PACK_BACK_KEY) == JOY_BUTTON_X)
	check("the premise: and B no longer is",
		cfg.key_for_button(JOY_BUTTON_B) != MainScene.PACK_BACK_KEY)
	var foot := talk.footer()
	check("the footer names X as the way to leave",
		foot.contains(cfg.icon(MainScene.PACK_BACK_KEY, true) + "  leave"), foot)
	check("  and the wait key as the way on",
		foot.contains(cfg.icon(KEY_PERIOD, true) + "  go on"), foot)
	talk.free()

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
		stale.key_for_button(JOY_BUTTON_DPAD_DOWN) == int(PadConfig.DEFAULTS[JOY_BUTTON_DPAD_DOWN]),
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

	# THREE pages of one reference in a RING (2026-10-10): legend, bestiary,
	# map. Right goes on round, left goes back. On a handheld this is the ONLY
	# route to the map and the bestiary, because every button on a standard
	# pad is already bound.
	var turned := []
	var leg := LegendPanel.new()
	leg.state = gs
	leg.bestiary_requested.connect(func() -> void: turned.append("legend>bestiary"))
	leg.map_requested.connect(func() -> void: turned.append("legend<map"))
	leg.visible = true
	leg.handle_key(KEY_RIGHT)
	leg.visible = true
	leg.handle_key(KEY_LEFT)
	leg.free()
	var m2 := MapPanel.new()
	m2.state = gs
	m2.bestiary_requested.connect(func() -> void: turned.append("map<bestiary"))
	m2.legend_requested.connect(func() -> void: turned.append("map>legend"))
	m2.visible = true
	m2.handle_key(KEY_LEFT)
	m2.visible = true
	m2.handle_key(KEY_RIGHT)
	var b := BestiaryPanel.new()
	b.state = gs
	b.legend_requested.connect(func() -> void: turned.append("bestiary<legend"))
	b.map_requested.connect(func() -> void: turned.append("bestiary>map"))
	b.open(&"player")
	b.handle_key(KEY_LEFT)
	b.open(&"player")
	b.handle_key(KEY_RIGHT)
	var moved_inside: bool = b.visible and int(b._pick[BestiaryPanel.CREATURES]) == 1
	for i in BestiaryPanel.COLS[BestiaryPanel.CREATURES]:
		b.handle_key(KEY_RIGHT)
	check("the three pages turn in a ring, both ways (%s)" % ", ".join(turned),
		turned == ["legend>bestiary", "legend<map", "map<bestiary", "map>legend",
			"bestiary<legend", "bestiary>map"])
	check("  the bestiary moves inside its grid and turns the page only at its edge",
		moved_inside and not b.visible)
	b.open(&"player")
	b.handle_key(KEY_TAB)
	var tabbed := b.tab == BestiaryPanel.ITEMS
	b.handle_key(KEY_TAB, true)
	check("  tab changes between creatures and items, and back",
		tabbed and b.tab == BestiaryPanel.CREATURES)
	b.handle_key(KEY_Z)
	check("  and any other key closes it", not b.visible)
	b.free()
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

	# A creature's state is a row of chips under its name (2026-10-07).
	var states := func(c: Vector2i) -> String:
		bar.hovered = c
		var words := []
		for entry in bar._describe():
			if entry is Dictionary and entry.has("chips"):
				for chip in entry["chips"]:
					words.append(String(chip["text"]))
		return ",".join(words)
	check("  and carries no chip at all", states.call(Vector2i(8, 5)) == "")

	var mate := _spawn(gs, "skeleton", 9, 5)
	mate.name = "B"
	mate.faction = Entity.Faction.PLAYER
	check("but an ally is: a 'yours' chip", states.call(Vector2i(9, 5)) == "yours",
		states.call(Vector2i(9, 5)))
	var bruin := _spawn(gs, "cave bear", 10, 5)
	# Hunger (2026-10-07): a hungry one says so, a fed one does not.
	check("precondition: this bear is hungry and unstruck",
		bruin.is_hungry() and not bruin.provoked)
	check("an unstruck animal is marked wild, so it is not read as hunting you",
		states.call(Vector2i(10, 5)).begins_with("wild"), states.call(Vector2i(10, 5)))
	check("  a hungry animal says so: it hunts",
		states.call(Vector2i(10, 5)) == "wild,hungry", states.call(Vector2i(10, 5)))
	bruin.hunger = 0
	check("  a fed one is only wild", states.call(Vector2i(10, 5)) == "wild",
		states.call(Vector2i(10, 5)))
	bruin.provoked = true
	check("  and once struck it is not", states.call(Vector2i(10, 5)) == "",
		states.call(Vector2i(10, 5)))
	gs.entities.erase(bruin)

	# IT FITS (the desktop's review, 2026-10-07): "(wild, hungry)" on the
	# name's line was cut to "(w.." on the real 256 px panel, so nothing ever
	# said hungry. Every wild creature at full health, hungry: its name line
	# whole, and its chips on one row inside the panel.
	bar.font = Sidebar.ui_font()
	bar.size = Vector2(256.0, 720.0)
	var cut := []
	var looked := 0
	for row in GameState.BESTIARY:
		if not row.get("wild", false):
			continue
		var beast := _spawn(gs, String(row["name"]), 12, 5)
		beast.hunger = Entity.HUNGRY_AT
		bar.hovered = Vector2i(12, 5)
		var lines: Array = bar._describe()
		var name_line := ""
		var chips: Array = []
		for k in lines.size():
			if lines[k] is Dictionary and lines[k].has("chips"):
				chips = lines[k]["chips"]
				name_line = String(lines[k - 1])
		# Wild, and hungry if it eats at all (a rabbit grazes, a bat flits).
		if chips.size() != (2 if beast.eats else 1):
			cut.append("%s: chips %s" % [row["name"], str(chips)])
		elif bar._fit(name_line) != name_line:
			cut.append("%s: name line cut, '%s'" % [row["name"], bar._fit(name_line)])
		else:
			var widths: Array = []
			for c in chips:
				widths.append(bar.chip_width(c))
			if Sidebar.chip_rows(widths, bar.size.x - Sidebar.PAD * 2.0 - 10.0).size() != 1:
				cut.append("%s: chips wrap" % row["name"])
		looked += 1
		gs.entities.erase(beast)
	check("precondition: every wild kind looked at (%d)" % looked, looked >= 4)
	check("every wild creature's name and its chips fit the panel uncut",
		cut.is_empty(), str(cut))
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
	#
	# Back behind the wall first. This used to run from wherever the walk
	# ended, so it passed only while the walk happened to end out of sight.
	# A draft of the 2026-10-04 last_seen change walked the goblin further;
	# it rounded the wall and SAW you, and a thing that sees you never gives up.
	far.x = 34
	far.y = 6
	check("precondition: from there it cannot see you",
		not Los.clear(hall.map, far.x, far.y, hall.player.x, hall.player.y))
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

## CAVE VAULTS (Brad and the desktop, 2026-10-08; tools/VAULTS_GAME_SIDE.md):
## a `kind: cave` vault is painted in place of a grown cave on cave floors,
## going down and coming up; it takes the band's vault so no masonry room
## lands in a cavern; it is met twice a run at most, turned differently.
## Synthetic vaults, as in _test_authored_pits_obey_the_rule: assets/ holds
## no cave vault yet, so a test reading it would pass by finding nothing.
const CAVE_PROBE_LAYOUT := "################\n####____########\n##________~~####\n#_____r_____~~##\n#____________###\n##___?_______###\n###____________#\n####_________###\n######____######\n################"

func _cave_probe(rotate := true) -> Vault:
	return Vault.parse("name: cave-probe\nkind: cave\nband: caves\nweight: 100\n"
		+ "min_depth: 4\nmax_depth: 6\nrotate: %s\nterrain: fixed\nLAYOUT\n" % ("yes" if rotate else "no")
		+ CAVE_PROBE_LAYOUT + "\n", "cave_probe")

func _test_cave_vaults() -> void:
	# Brad keeps cave vaults in assets/vaults/caves/ (2026-10-08): the loader
	# reads every subfolder, so the library is every .txt under the folder.
	var files := 0
	var folders := ["res://assets/vaults/"]
	var sub_files := 0
	while not folders.is_empty():
		var dir_path: String = folders.pop_back()
		var d := DirAccess.open(dir_path)
		if d == null:
			continue
		for f in d.get_files():
			if String(f).ends_with(".txt"):
				files += 1
				if dir_path != "res://assets/vaults/":
					sub_files += 1
		for sub in d.get_directories():
			folders.append(dir_path + sub + "/")
	check("the vault library is every vault file, subfolders included (%d files, %d in subfolders)"
		% [files, sub_files], Vault.load_all().size() == files)
	var probe := _cave_probe()
	check("a cave vault parses as a cave", probe != null and probe.is_cave())
	check("  and a vault without a kind is a room, as every vault was",
		not Vault.parse("name: r\nLAYOUT\n#.#\n", "r").is_cave())
	# A room vault welcome anywhere, so the caves WOULD take it without the
	# preference -- the rule under test has something to refuse.
	var room := Vault.parse("name: room-probe\nweight: 100\nmin_depth: 1\n"
		+ "max_depth: 19\nLAYOUT\n#####\n#...#\n#...#\n##+##\n", "room_probe")
	var real_library := GameState._vault_library
	var built := 0
	var placed := 0
	var rooms_in_caves := 0
	var bad_cells := []
	var walls_on_rim := 0
	var unreachable := 0
	var peopled := 0
	var rabbits := 0
	var climb_placed := 0
	var first: GameState = null
	for i in 40:
		for climbing in [false, true]:
			var gs := GameState.new(91000 + i)
			gs.new_game()
			GameState._vault_library = [probe, room] as Array[Vault]
			gs.ascending = climbing
			gs.depth = 5
			gs.build_level()
			built += 1
			for n in gs.vault_names:
				if n == "room-probe":
					rooms_in_caves += 1
			if not gs.cave_vaults_seen.has("cave-probe"):
				continue
			if climbing:
				climb_placed += 1
				continue
			placed += 1
			if first == null:
				first = gs
			var turn: Array = gs.cave_vaults_seen["cave-probe"][0]
			var grid := probe.oriented(int(turn[0]), bool(turn[1]))
			var rect := Rect2i()
			for k in gs.vault_names.size():
				if gs.vault_names[k] == "cave-probe":
					rect = gs.vault_rects[k]
			if not gs.cave_regions.has(rect):
				bad_cells.append("its rect is not one of the floor's caves")
			var goal := Vector2i(-1, -1)
			for y in grid.size():
				for x in String(grid[y]).length():
					var ch := String(grid[y])[x]
					var c := rect.position + Vector2i(x, y)
					var t := gs.map.get_tile(c.x, c.y)
					# A past hero's grave and its bones may lie on drawn ground,
					# as they always could in a room vault (_place_graves): the
					# morgue's history, not a pass rewriting the drawing. Seen
					# only in the full suite, which has a morgue to draw on.
					if ch == "_" and t != Tiles.CAVE_FLOOR and t != Tiles.GRAVE \
							and t != Tiles.BONES:
						bad_cells.append("%s: '_' is tile %d" % [c, t])
					if ch == "~" and t != Tiles.WATER:
						bad_cells.append("%s: '~' is tile %d" % [c, t])
					if ch == "_":
						goal = c
						for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
							if gs.map.get_tile(c.x + d.x, c.y + d.y) == Tiles.WALL:
								walls_on_rim += 1
			# You can walk there from where you start.
			var seen := {Vector2i(gs.player.x, gs.player.y): true}
			var todo := [Vector2i(gs.player.x, gs.player.y)]
			while not todo.is_empty():
				var cur: Vector2i = todo.pop_back()
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
						Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
					var n: Vector2i = cur + d
					if seen.has(n) or not gs.map.in_bounds(n.x, n.y):
						continue
					var t := gs.map.get_tile(n.x, n.y)
					if gs.map.is_walkable(n.x, n.y) or t == Tiles.DOOR_CLOSED or t == Tiles.WATER:
						seen[n] = true
						todo.append(n)
			if not seen.has(goal):
				unreachable += 1
			for e in gs.entities:
				if e.alive and not e.is_player and rect.has_point(Vector2i(e.x, e.y)):
					peopled += 1
					if e.appearance == &"rabbit":
						rabbits += 1
	GameState._vault_library = real_library
	check("the real vault library is put back",
		GameState._vault_library.size() == real_library.size())
	check("precondition: cave floors built, going down and coming up (%d)" % built, built == 80)
	check("a cave vault is placed on about a quarter of cave floors going down (%d of 40)" % placed,
		placed >= 4 and placed <= 18)
	check("  and on the climb's caves too (%d of 40)" % climb_placed, climb_placed >= 4)
	check("while a cave vault can be had, no masonry room lands in the caves (%d)" % rooms_in_caves,
		rooms_in_caves == 0)
	check("it is painted as drawn, one of the floor's caves", bad_cells.is_empty(), str(bad_cells.slice(0, 4)))
	check("  its rim is cave stone, never masonry (%d walls)" % walls_on_rim, walls_on_rim == 0)
	check("  you can walk into it from where you start (%d cut off)" % unreachable, unreachable == 0)
	check("  it is peopled like a cave, and its rabbit marker holds a rabbit (%d in it, %d rabbits)"
		% [peopled, rabbits], peopled > rabbits and rabbits >= 1)

	# Met twice at most, the second time turned differently.
	check("precondition: a floor that placed it", first != null)
	if first != null:
		var seed_of: int = 0
		for i in 40:
			var gs := GameState.new(91000 + i)
			gs.new_game()
			GameState._vault_library = [probe] as Array[Vault]
			gs.depth = 5
			gs.build_level()
			if gs.cave_vaults_seen.has("cave-probe"):
				seed_of = 91000 + i
				break
		var twice := GameState.new(seed_of)
		twice.new_game()
		GameState._vault_library = [probe] as Array[Vault]
		twice.depth = 5
		var met_turn: Array = []
		twice.build_level()
		met_turn = twice.cave_vaults_seen["cave-probe"][0]
		# The same floor again, remembering that turn: placed, turned anew.
		var redo := GameState.new(seed_of)
		redo.new_game()
		redo.cave_vaults_seen = {"cave-probe": [met_turn]}
		redo.depth = 5
		redo.build_level()
		var second: Array = redo.cave_vaults_seen["cave-probe"]
		check("met once, it comes again turned differently (%s then %s)" % [str(met_turn), str(second)],
			second.size() == 2 and (int(second[1][0]) != int(met_turn[0])
				or bool(second[1][1]) != bool(met_turn[1])))
		# Met twice: never a third time.
		var third := GameState.new(seed_of)
		third.new_game()
		third.cave_vaults_seen = {"cave-probe": [[0, false], [1, false]]}
		third.depth = 5
		third.build_level()
		check("  met twice, never a third time", third.cave_vaults_seen["cave-probe"].size() == 2)
		# A vault that cannot turn is met once only.
		GameState._vault_library = [_cave_probe(false)] as Array[Vault]
		var stiff := GameState.new(seed_of)
		stiff.new_game()
		stiff.cave_vaults_seen = {"cave-probe": [[0, false]]}
		stiff.depth = 5
		stiff.build_level()
		check("  one that cannot be turned is met once only",
			stiff.cave_vaults_seen["cave-probe"].size() == 1)
		# Saved.
		var back := GameState.new(1)
		back.apply_dict(redo.to_dict())
		check("what the run has met is saved",
			back.cave_vaults_seen.get("cave-probe", []).size() == 2, str(back.cave_vaults_seen))
	GameState._vault_library = real_library

## CREATURES BY NAME (2026-10-08; tools/VAULTS_GAME_SIDE.md part 2):
## `place 1: cave bear` and a 1 on the board. Placed only where the roll could
## meet it; an animal on top of the budget, a monster within it or not at all.
func _test_creatures_by_name() -> void:
	var v := Vault.parse("name: named\nplace 1: cave bear\nplace 2: kobold\n"
		+ "place x: rat\nLAYOUT\n#####\n#1.2#\n##+##\n", "named")
	check("place lines parse to digit -> name",
		v != null and v.places.get("1", "") == "cave bear" and v.places.get("2", "") == "kobold"
		and v.places.size() == 2, str(v.places if v else {}))
	# The game side, from what the stamp hands it.
	var gs := _arena(21, 9)
	gs.player.x = 1
	gs.player.y = 1
	gs.depth = 5
	var gen := MapGen.new(gs.rng)
	gen.vault_contents = [
		{"ch": "creature", "name": "cave bear", "pos": Vector2i(5, 4)},
		{"ch": "creature", "name": "kobold", "pos": Vector2i(9, 4)},
		{"ch": "creature", "name": "no such beast", "pos": Vector2i(12, 4)},
	]
	gs._place_vault_contents(gen)
	var bear: Entity = gs.entity_at(5, 4)
	var kob: Entity = gs.entity_at(9, 4)
	check("a named animal is placed where drawn, wild",
		bear != null and bear.appearance == &"bear" and bear.is_wild())
	check("a named monster is placed where drawn",
		kob != null and kob.name == "kobold" and kob.faction == Entity.Faction.MONSTER)
	check("  and a name the bestiary lacks places nothing", gs.entity_at(12, 4) == null)
	# The budget: a monster the room cannot afford is left out, the cheap
	# one beside it is not.
	check("precondition: an ogre (14) costs more than 5", int(gs._bestiary_row(&"ogre")["threat"]) > 5)
	check("an unaffordable named monster is left out",
		gs._place_named(Vector2i(5, 6), "ogre", 5) == 0 and gs.entity_at(5, 6) == null)
	var cheap := gs._place_named(Vector2i(9, 6), "kobold", 5)
	check("  the affordable one is placed, within what was left (%d)" % cheap,
		cheap > 0 and cheap <= 5 and gs.entity_at(9, 6) != null)
	check("an animal costs the budget nothing",
		gs._place_named(Vector2i(13, 6), "rabbit", 0) == 0 and gs.entity_at(13, 6) != null)
	# Where the roll could meet it.
	gs.depth = 2
	check("not above its depth: no cave troll on floor 2",
		gs._place_named(Vector2i(5, 2), "cave troll", 999) == 0 and gs.entity_at(5, 2) == null)
	gs.depth = 9
	check("precondition: the cave giant is the climb's (ascent_from 14)",
		int(gs._bestiary_row(&"giant").get("ascent_from", 0)) == 14)
	check("an ascent-only creature is absent on the way down",
		gs._place_named(Vector2i(7, 2), "cave giant", 999) == 0 and gs.entity_at(7, 2) == null)
	gs.ascending = true
	gs.depth = GameState.MAX_DEPTH * 2 - 14
	check("  and present on the climb from its floor (effective %d)" % gs.effective_depth(),
		gs._place_named(Vector2i(7, 2), "cave giant", 999) > 0 and gs.entity_at(7, 2) != null)
	# Through the real generator: the digit is stamped, the creature stands
	# in the vault.
	var probe := Vault.parse("name: named-probe\nweight: 100\nmin_depth: 1\nmax_depth: 19\n"
		+ "band: fortress\nrotate: no\nplace 1: cave bear\nLAYOUT\n"
		+ "#######\n#.....#\n#..1..#\n#.....#\n###+###\n", "named_probe")
	var real_library := GameState._vault_library
	var stood := 0
	var placed := 0
	for i in 12:
		var f := GameState.new(93000 + i)
		f.new_game()
		GameState._vault_library = [probe] as Array[Vault]
		f.depth = 7
		f.build_level()
		for k in f.vault_names.size():
			if f.vault_names[k] != "named-probe":
				continue
			placed += 1
			for e in f.entities:
				if e.alive and e.appearance == &"bear" and f.vault_rects[k].has_point(Vector2i(e.x, e.y)):
					stood += 1
					break
	GameState._vault_library = real_library
	check("precondition: the named vault was placed on fortress floors (%d)" % placed, placed >= 3)
	check("the named bear stands in its vault each time (%d of %d)" % [stood, placed], stood == placed)

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
## Whether the log has said `text` since the game began.
func _log_says(gs: GameState, text: String) -> bool:
	for line in gs.msg_log.entries:
		if String(line["text"]).contains(text):
			return true
	return false

## THE WILD FACTION (Brad, 2026-10-04): a bear, a rabbit, a bat act and live
## their own lives, and are nobody's enemy until your side strikes them.
func _test_the_wild_are_no_ones_enemy() -> void:
	var gs := _arena(21, 9)
	gs.player.x = 5
	gs.player.y = 4
	gs.player.hp = gs.player.max_hp
	gs.entities = [gs.player]
	var bear := _spawn(gs, "cave bear", 6, 4)
	check("a cave bear is wild", bear.is_wild())
	check("unstruck, it is not your enemy, nor you its",
		not bear.hostile_to(gs.player) and not gs.player.hostile_to(bear))
	check("  it is not among the monsters that stop a journey or forbid a rest",
		not gs.visible_monsters().has(bear))
	check("  but it is in sight, for the sidebar", gs.visible_wild().has(bear))
	check("  and it may be shot: a bow is how you provoke a bear from afar",
		gs.firing_targets(6).has(bear))
	check("precondition: awake and beside you", bear.alertness == Entity.Alert.AWAKE
		and bear.is_adjacent(gs.player))
	var hp_before := gs.player.hp
	gs._take_ai_turn(bear)
	check("its turn: it does not strike you; it gives you room (%d away)"
		% Los.steps(bear.x, bear.y, 5, 4),
		gs.player.hp == hp_before and Los.steps(bear.x, bear.y, 5, 4) == 2)
	# Walk into it: that is picking the fight, not trading places.
	bear.x = 6
	bear.y = 4
	var bear_hp := bear.hp
	var hp_at_bump := gs.player.hp
	# The first bump is a warning, not a blow (2026-10-05): no turn passes,
	# the bear is untouched and still nobody's enemy. The same move again is
	# the fight.
	var turns_at_bump := gs.turns
	check("the first move into it is refused, with a warning, at no cost",
		not gs.player_move(1, 0) and gs.turns == turns_at_bump and bear.hp == bear_hp
		and not bear.provoked and _log_says(gs, "done nothing to you"))
	check("precondition: the second move is a bump", gs.player_move(1, 0))
	# The move ends your turn, so the bear answers inside it -- and its answer
	# is a shove, so you are not where you stood. What must be true: it was
	# hit, and you never changed places with it.
	check("walking into a bear strikes it, and never swaps you with it",
		bear.hp < bear_hp and not (gs.player.x == 6 and gs.player.y == 4)
		and bear.x == 6 and bear.y == 4, "player %d,%d" % [gs.player.x, gs.player.y])
	check("  and it hit back at once, inside your move (%d -> %d)" % [hp_at_bump, gs.player.hp],
		gs.player.hp < hp_at_bump)
	check("  struck, it is your enemy for good", bear.provoked and bear.hostile_to(gs.player)
		and gs.player.hostile_to(bear))
	check("  the log says so", _log_says(gs, "turns on you"))
	check("  and it counts among the monsters now", gs.visible_monsters().has(bear)
		and not gs.visible_wild().has(bear))
	gs.player.x = 5
	gs.player.y = 4
	hp_before = gs.player.hp
	gs._take_ai_turn(bear)
	check("  its next turn, beside you again, it hits you (%d -> %d)" % [hp_before, gs.player.hp],
		gs.player.hp < hp_before)
	check("  and a save keeps the grudge and the kind",
		Entity.from_dict(bear.to_dict()).provoked
		and Entity.from_dict(bear.to_dict()).faction == Entity.Faction.WILD)

	# The others on the floor.
	var den := _arena(21, 9)
	den.player.x = 2
	den.player.y = 1
	den.entities = [den.player]
	var gob := _spawn(den, "goblin", 10, 4)
	var bun := _spawn(den, "rabbit", 11, 4)
	check("a goblin's foe is you, never the rabbit beside it", den._foe_for(gob) == den.player)
	check("an unstruck rabbit has no foe at all", den._foe_for(bun) == null)
	check("  and a goblin walks round it rather than waiting on it", not gob.hostile_to(bun))
	# It fears the goblin beside it more than you across the room.
	den._take_ai_turn(bun)
	check("a rabbit flees a monster beside it, not only you (%d away now)"
		% Los.steps(bun.x, bun.y, gob.x, gob.y), Los.steps(bun.x, bun.y, gob.x, gob.y) > 1)
	# Speared by a goblin, it runs from the goblin even with you nearer.
	bun.x = 4
	bun.y = 1
	gob.x = 8
	gob.y = 1
	den._attack(gob, bun)
	check("struck by a monster, a rabbit remembers it", bun.alive and bun.grudge == gob
		and bun.hostile_to(gob) and not bun.provoked)
	den._take_ai_turn(bun)
	check("  and runs from THAT, though you stand nearer (%d from the goblin, %d from you)"
		% [Los.steps(bun.x, bun.y, gob.x, gob.y), Los.steps(bun.x, bun.y, 2, 1)],
		Los.steps(bun.x, bun.y, gob.x, gob.y) > 4)
	check("  without becoming your enemy", not bun.hostile_to(den.player))
	gob.x = 10
	gob.y = 4
	bun.x = 11
	bun.y = 4
	bun.grudge = null
	var pal := _spawn(den, "skeleton", 12, 4)
	pal.faction = Entity.Faction.PLAYER
	check("your ally leaves it be: its foe is the goblin, never the rabbit",
		not pal.hostile_to(bun) and den._foe_for(pal) == gob)
	var dead := _spawn(den, "goblin", 10, 6)
	dead.faction = Entity.Faction.RISEN
	check("the risen eat the living, wild or not", dead.hostile_to(bun) and bun.hostile_to(dead))
	den._attack(pal, bun)
	check("struck by your ally, it is your side's enemy (and no 'turns on you' for a rabbit)",
		bun.provoked and pal.hostile_to(bun) and bun.hostile_to(den.player)
		and not _log_says(den, "turns on you"))
	var bun2 := _spawn(den, "rabbit", 14, 4)
	den._rabbit_turns(bun2)
	check("the killer rabbit is a monster, your enemy unstruck",
		bun2.faction == Entity.Faction.MONSTER and bun2.hostile_to(den.player))
	var bat := _spawn(den, "cave bat", 15, 4)
	check("a cave bat is wild", bat.is_wild())
	den._corrupt(bat)
	check("corrupted, it is a monster: the purple takes the wild out of it",
		bat.faction == Entity.Faction.MONSTER and bat.hostile_to(den.player))
	# A bear with a goblin's spear in it has a goblin problem, not a you
	# problem -- and its answer is the shove, on a monster as on you.
	var lair := _arena(21, 9)
	lair.player.x = 2
	lair.player.y = 4
	lair.entities = [lair.player]
	var bruin := _spawn(lair, "cave bear", 6, 4)
	var spear := _spawn(lair, "goblin", 7, 4)
	# Lit by your torch, so the goblin can SEE the bear it is about to prefer
	# (past arm's length a living thing sees only what is lit); and tough
	# enough to live through the bear's answer. Found 2026-10-05: the goblin
	# used to die to that blow and the foe check below passed on
	# `not spear.alive` without ever asking its question.
	lair.torch_lit = true
	lair._gather_lights()
	lair.update_vision()
	spear.max_hp = 40
	spear.hp = 40
	lair._attack(spear, bruin)
	check("precondition: the goblin struck the bear", bruin.hp < bruin.max_hp and bruin.grudge == spear)
	check("a bear struck by a monster is that monster's enemy, not yours",
		bruin.hostile_to(spear) and spear.hostile_to(bruin) and not bruin.hostile_to(lair.player)
		and not bruin.provoked)
	var gob_hp := spear.hp
	var player_hp := lair.player.hp
	lair._take_ai_turn(bruin)
	check("  its turn, it hits the goblin back (%d -> %d) and leaves you be" % [gob_hp, spear.hp],
		spear.hp < gob_hp and lair.player.hp == player_hp)
	check("  and the shove lands on a monster as on you (goblin at %d,%d)" % [spear.x, spear.y],
		spear.alive and spear.x > 7)
	check("  precondition: it lives, and can see the bear in your torchlight",
		spear.alive and lair._can_see(spear, bruin))
	check("  the goblin's own foe is now the bear, since it is nearer than you",
		spear.alive and lair._foe_for(spear) == bruin)
	var trader := Entity.new("trader", &"trader", 16, 4)
	trader.faction = Entity.Faction.NEUTRAL
	check("the trader is still nobody's: not fair game, not swappable",
		not den._fair_game(trader) and not bear.hostile_to(trader))

## A FLOOR THAT WAS ALIVE BEFORE YOU ARRIVED (2026-10-06): the floor lives
## PRERUN_TURNS quiet turns before you are placed -- and Brad's rule, nobody
## dies, holds: same creatures, same threat, same main rng, nothing said.
func _test_the_floor_was_alive_before_you() -> void:
	var build := func(seed_value: int, depth: int, turns: int, climbing: bool) -> GameState:
		var was := GameState.prerun_turns
		GameState.prerun_turns = turns
		var g := GameState.new(seed_value)
		g.new_game()
		g.ascending = climbing
		g.depth = depth
		g.build_level()
		GameState.prerun_turns = was
		return g
	var census := func(g: GameState) -> Dictionary:
		var alive := 0
		var threat := 0
		var at := []
		for e in g.entities:
			if e.is_player:
				continue
			if e.alive:
				alive += 1
				threat += e.threat
			at.append(Vector2i(e.x, e.y))
		return {"alive": alive, "threat": threat, "at": at, "n": g.entities.size()}
	var moved_floors := 0
	var bad := []
	# Eight floors going down, and two on the CLIMB (Brad, 2026-10-06: the
	# ascent plays differently) -- its caves and upper floors, effective 15
	# and 18, where the wolves and the bears live again.
	var floors := []
	for i in 8:
		floors.append([80000 + i, 2 + (i % 5), false])
	floors.append([80100, 5, true])
	floors.append([80101, 2, true])
	var climb_animals := 0
	var climb_moved := 0
	var on_the_climb := 0
	for f in floors:
		var i: int = f[0]
		var depth: int = f[1]
		var up: bool = f[2]
		var still: GameState = build.call(i, depth, 0, up)
		var lived: GameState = build.call(i, depth, GameState.PRERUN_TURNS, up)
		if up:
			if lived.effective_depth() > GameState.MAX_DEPTH:
				on_the_climb += 1
			for e in lived.entities:
				if e.alive and e.is_wild():
					climb_animals += 1
		var a: Dictionary = census.call(still)
		var b: Dictionary = census.call(lived)
		if a["n"] != b["n"]:
			bad.append("creature count on seed %d" % i)
		if a["alive"] != b["alive"]:
			bad.append("deaths on seed %d (%d -> %d)" % [i, a["alive"], b["alive"]])
		if a["threat"] != b["threat"]:
			bad.append("threat on seed %d (%d -> %d)" % [i, a["threat"], b["threat"]])
		if still.rng.state != lived.rng.state:
			bad.append("main rng moved on seed %d" % i)
		if still.msg_log.entries.size() != lived.msg_log.entries.size() or not lived.events.is_empty():
			bad.append("the pre-run spoke on seed %d" % i)
		if a["at"] != b["at"]:
			moved_floors += 1
			if up:
				climb_moved += 1
	check("precondition: two floors really are on the climb (%d), and carry animals (%d)"
		% [on_the_climb, climb_animals], on_the_climb == 2 and climb_animals >= 4)
	check("nobody dies, no threat changes, the main rng never moves, nothing is said (%d floors, two on the climb)"
		% floors.size(), bad.is_empty(), str(bad))
	check("and the floor has moved: creatures are not where they were placed (%d of %d)"
		% [moved_floors, floors.size()], moved_floors >= floors.size() - 2)
	check("  on the climb too (%d of 2)" % climb_moved, climb_moved == 2)
	var one: GameState = build.call(80003, 5, GameState.PRERUN_TURNS, false)
	var two: GameState = build.call(80003, 5, GameState.PRERUN_TURNS, false)
	check("the same seed lives the same pre-run", census.call(one)["at"] == census.call(two)["at"])
	var hunting := 0
	for e in one.entities:
		if not e.is_player and e.alive and e.hostile_to(one.player) \
				and Los.steps(e.x, e.y, one.player.x, one.player.y) <= 1:
			hunting += 1
	check("nothing hostile waits at your feet when you arrive", hunting == 0)
	# Up and about -- or napping (2026-10-07): most of a floor's animals are
	# awake when you arrive, some doze. A bear in its den sleeps.
	var up := 0
	var wild := 0
	for e in one.entities:
		if e.alive and e.is_wild() and not e.denned:
			wild += 1
			if e.alertness == Entity.Alert.AWAKE:
				up += 1
	check("most of the animals are up and about (%d of %d)" % [up, wild], wild == 0 or up * 2 >= wild)

## TAMING THE WOLVES (Brad's design 2026-10-05): a pack on your side for
## haunches to its count or a knucklebone; it hunts for you and heals only
## when hurt, from meat lying about.
func _test_taming_the_wolves() -> void:
	var cave := _arena(24, 11)
	cave.depth = 5
	cave.player.x = 6
	cave.player.y = 5
	cave.player.inventory.clear()
	cave.player.equipped.clear()
	cave.entities = [cave.player]
	cave.ground = []
	cave.map.set_all_visible()
	var row := _bestiary_entry("wolf")
	check("precondition: the wolf is tameable, at the pack's count (%d in the caves)" % cave._pack_size(row),
		bool(row.get("tame", false)) and cave._pack_size(row) == 4)
	var leader := _spawn(cave, "wolf", 7, 5)
	cave._spawn_pack(leader, row, 3)
	var far := _spawn(cave, "wolf", 20, 9)
	var pack := []
	for e in cave.entities:
		if e.appearance == &"wolf" and e != far:
			pack.append(e)
	check("precondition: a pack of four beside you, one far off", pack.size() == 4
		and Los.steps(far.x, far.y, leader.x, leader.y) > GameState.PACK_REACH)
	# Without the price, the warning names it.
	check("without the price, the first move warns and names the price",
		not cave.player_move(1, 0) and leader.is_wild() and not leader.provoked
		and _log_says(cave, "4 haunches, or a knucklebone, would tame the pack instead."))
	cave._meant = null
	# Three haunches are not four.
	for i in 3:
		cave.give_item(Item.make(&"meat"))
	check("precondition: three haunches carried", cave._haunches_carried() == 3 and not cave._can_tame(leader))
	cave.give_item(Item.make(&"bear_meat"))
	check("a bear's haunch counts: four now, and the pack can be tamed",
		cave._haunches_carried() == 4 and cave._can_tame(leader))
	var t0 := cave.turns
	check("the first move into it OFFERS, at no cost", not cave.player_move(1, 0) and cave.turns == t0
		and leader.is_wild() and _log_says(cave, "tame the pack with 4 haunches; shoot to fight it."))
	check("  and every line of it fits the log (about 95 characters)",
		"That is a wolf. Move into it again to tame the pack with 4 haunches; shoot to fight it.".length() <= 95
		and "That is a wolf. Move into it again to tame the pack with the knucklebone; shoot to fight it.".length() <= 95)
	cave.events.clear()
	check("the second move pays and tames", cave.player_move(1, 0) and cave.turns == t0 + 1)
	var turned := 0
	for w in pack:
		if w.faction == Entity.Faction.PLAYER and not w.provoked and w.grudge == null:
			turned += 1
	check("the whole pack turns to you (%d of 4)" % turned, turned == 4)
	check("  the far wolf keeps its peace, wild", far.is_wild() and far.faction == Entity.Faction.WILD)
	check("  the haunches are spent", cave._haunches_carried() == 0)
	check("  the log says so", _log_says(cave, "The pack eats, and is yours."))
	var hearts := 0
	for ev in cave.events:
		if ev["kind"] == &"tamed":
			hearts += 1
	check("  and a heart floats over each (%d)" % hearts, hearts == 4)
	check("  they stand with you", cave.allies().size() == 4)
	var fx := Fx.new()
	fx.add_events(cave.events, 14)
	var heart_popups := 0
	for e in fx.list:
		if e["type"] == &"popup" and e["text"] == String.chr(GlyphTheme.TAMED):
			heart_popups += 1
	check("  the views draw them as heart popups (%d)" % heart_popups, heart_popups == 4)
	var icons: FontFile = load("res://assets/fonts/ofr_icons.ttf")
	check("  and the heart is in the font we ship", icons.has_char(GlyphTheme.TAMED))

	# The pack hunts for you: a rabbit within your reach, the haunch left.
	var bun := _spawn(cave, "rabbit", 9, 5)
	bun.hp = 1
	var dog: Entity = pack[0]
	dog.x = 8
	dog.y = 5
	var others := pack.slice(1)
	for w in others:
		cave.entities.erase(w)
	cave._take_ai_turn(dog)
	check("a tamed wolf takes the rabbit beside it", not bun.alive)
	var haunch_lies := false
	for it in cave.ground:
		if it.id == &"meat":
			haunch_lies = true
	check("precondition: the haunch lies where the rabbit fell", haunch_lies)
	dog.x = 9
	dog.y = 5
	cave._take_ai_turn(dog)
	var still_lies := false
	for it in cave.ground:
		if it.id == &"meat":
			still_lies = true
	check("a well wolf leaves the haunch for you (and must)", dog.hp == dog.max_hp and still_lies)
	# Well, it came back toward you; hurt, it goes back for the meat: a turn
	# to reach it and a turn to eat.
	dog.hp = dog.max_hp - 3
	for i in 3:
		cave._take_ai_turn(dog)
	var eaten := true
	for it in cave.ground:
		if it.id == &"meat":
			eaten = false
	check("a hurt wolf goes back for it, eats and heals -- the first ally that heals, paid for (%d/%d)"
		% [dog.hp, dog.max_hp], eaten and dog.hp > dog.max_hp - 3)
	check("  a tamed wolf is saved as yours",
		Entity.from_dict(dog.to_dict()).faction == Entity.Faction.PLAYER)

	# The knucklebone pays when haunches cannot.
	var den := _arena(24, 11)
	den.depth = 2
	den.player.x = 6
	den.player.y = 5
	den.player.inventory.clear()
	den.player.equipped.clear()
	den.entities = [den.player]
	var bone := Item.make(&"bone")
	den.give_item(bone)
	var lead2 := _spawn(den, "wolf", 7, 5)
	den._spawn_pack(lead2, row, den._pack_size(row) - 1)
	check("precondition: a pair on an upper floor, no haunches, a knucklebone",
		den._pack_size(row) == 2 and den._haunches_carried() == 0 and den._can_tame(lead2))
	check("the offer names the bone", not den.player_move(1, 0)
		and _log_says(den, "tame the pack with the knucklebone; shoot to fight it."))
	check("and the second move spends it for the pair", den.player_move(1, 0)
		and not den.player.inventory.has(bone) and den.allies().size() == 2
		and _log_says(den, "The wolf takes it, and the pack comes with it."))

## BODIES SAY WHO KILLED THEM (Brad, 2026-10-05): the cursor over a body
## names its killer, so a cave's history can be read from its dead.
func _test_bodies_say_who_killed_them() -> void:
	var gs := _arena(21, 9)
	gs.player.x = 3
	gs.player.y = 4
	gs.player.inventory.clear()
	gs.map.set_all_visible()
	gs.map.remember_visible()
	gs.entities = [gs.player]
	gs.bodies = []
	var bar := Sidebar.new()
	bar.state = gs
	var read := func(c: Vector2i) -> String:
		bar.hovered = c
		var all := ""
		for entry in bar._describe():
			if entry is String:
				all += String(entry) + "|"
		return all
	# A wolf's kill.
	var bun := _spawn(gs, "rabbit", 10, 4)
	var wolf := _spawn(gs, "wolf", 11, 4)
	_kill(gs, bun, wolf)
	check("a rabbit killed by a wolf: 'torn by a wolf'", read.call(Vector2i(10, 4)).contains("rabbit's body, torn by a wolf"),
		read.call(Vector2i(10, 4)))
	# Your own kill, and your ally's.
	var gob := _spawn(gs, "goblin", 12, 4)
	_kill(gs, gob, gs.player)
	check("your kill: 'slain by you'", read.call(Vector2i(12, 4)).contains("goblin's body, slain by you"),
		read.call(Vector2i(12, 4)))
	var kob := _spawn(gs, "kobold", 13, 4)
	var pal := _spawn(gs, "skeleton", 14, 4)
	pal.faction = Entity.Faction.PLAYER
	pal.name = "bone skeleton"
	_kill(gs, kob, pal)
	check("your ally's kill names it as yours", read.call(Vector2i(13, 4)).contains("slain by your bone skeleton"),
		read.call(Vector2i(13, 4)))
	# A monster's kill, and the article.
	var orc := _spawn(gs, "orc", 15, 5)
	var bun2 := _spawn(gs, "rabbit", 15, 4)
	_kill(gs, bun2, orc)
	check("an orc's kill: 'slain by an orc'", read.call(Vector2i(15, 4)).contains("slain by an orc"),
		read.call(Vector2i(15, 4)))
	# The floor's own killers.
	var rat := _spawn(gs, "giant rat", 16, 4)
	rat.hp = 1
	rat.acid_turns = 1
	gs._grow_fungus()
	check("acid: 'eaten by acid'", not rat.alive and read.call(Vector2i(16, 4)).contains("eaten by acid"),
		read.call(Vector2i(16, 4)))
	# A body the red has claimed says so.
	gs._set_fungus(Vector2i(17, 4), Tiles.FUNGUS_RED)
	var kob2 := _spawn(gs, "kobold", 17, 5)
	kob2.take_spores(&"red")
	_kill(gs, kob2, gs.player)
	check("a claimed body says the red has it", read.call(Vector2i(17, 5)).contains("the red has it"),
		read.call(Vector2i(17, 5)))
	# Rotted away, it is not described; unseen, not either.
	gs.turns += GameState.BODY_ROT
	check("a body rotted away is not described", not read.call(Vector2i(10, 4)).contains("body"))
	gs.turns -= GameState.BODY_ROT
	check("precondition: visible again it is", read.call(Vector2i(10, 4)).contains("body"))
	# And the record travels with the save.
	var saved := GameState.new(1)
	saved.new_game()
	check("the killer is saved with the body", saved.apply_dict(gs.to_dict())
		and String(saved.bodies[0].get("killed_by", "")) == "torn by a wolf")
	bar.free()

## ANIMALS DRINK (Brad, 2026-10-05): the first routine that is not about you.
func _test_animals_drink() -> void:
	var cave := _arena(21, 9)
	cave.player.x = 2
	cave.player.y = 7
	cave.entities = [cave.player]
	cave.map.set_all_visible()
	for y in range(1, 8):
		cave.map.set_tile(5, y, Tiles.WALL)
	cave.map.set_tile(15, 4, Tiles.WATER)
	cave.pathfinder = Pathfinder.new(cave.map)
	var bear := _spawn(cave, "cave bear", 11, 4)
	check("precondition: an awake, unstruck bear with a pool four cells off",
		bear.is_wild() and not bear.provoked and cave._water_near(bear, GameState.DRINK_REACH) == Vector2i(15, 4))
	var drank := false
	var reached := false
	for i in 80:
		cave._take_ai_turn(bear)
		if cave.map.get_tile(bear.x, bear.y) == Tiles.WATER:
			reached = true
		if bear.drinking > 0:
			drank = true
			break
	check("left to itself, it goes to the water and drinks (%d turns)" % 80, reached and drank
		and _log_says(cave, "The cave bear drinks."))
	bear.drinking = 0
	var sips := 0
	var up_turns := 0
	for i in 200:
		cave._take_ai_turn(bear)
		if bear.drinking == GameState.DRINK_TURNS:
			sips += 1
		if bear.alertness == Entity.Alert.AWAKE:
			up_turns += 1
	check("  and over a long while it drinks now and then, not always (%d sips in 200)" % sips,
		sips >= 3 and sips <= 80)
	# It may nap now (2026-10-07), but it does not doze off the moment you
	# leave its sight, as it did before "up stays up": up most of the time.
	check("  an unstruck animal is up most of the time, naps or not (%d of 200 turns)" % up_turns,
		up_turns >= 100)
	bear.alertness = Entity.Alert.AWAKE
	check("  and it heals nothing by it", bear.hp == bear.max_hp)
	check("  a drink is saved mid-sip", Entity.from_dict(bear.to_dict()).drinking == bear.drinking)
	# Its own stream: drinking never draws on the main rng.
	var main_state := cave.rng.state
	bear.drinking = 0
	for i in 10:
		cave._drinks(bear)
	check("drinking never draws on the main rng (its own stream, saved)",
		cave.rng.state == main_state and cave.to_dict().has("drink_rng"))
	# A provoked bear has better things to do.
	var angry := _spawn(cave, "cave bear", 11, 6)
	angry.provoked = true
	var sipped := false
	for i in 30:
		cave._take_ai_turn(angry)
		if angry.drinking > 0:
			sipped = true
	check("a bear that is hunting you never stops to drink", not sipped)
	# A rabbit drinks too, when nothing frightens it; frightened, it runs.
	var warren := _arena(21, 9)
	warren.player.x = 2
	warren.player.y = 7
	warren.entities = [warren.player]
	warren.map.set_all_visible()
	for y in range(1, 8):
		warren.map.set_tile(5, y, Tiles.WALL)
	warren.map.set_tile(15, 4, Tiles.WATER)
	warren.pathfinder = Pathfinder.new(warren.map)
	var bun := _spawn(warren, "rabbit", 13, 4)
	var bun_drank := false
	for i in 120:
		warren._take_ai_turn(bun)
		if bun.drinking > 0:
			bun_drank = true
			break
	check("a rabbit with nothing to fear drinks too", bun_drank)
	bun.drinking = 0
	bun.x = 14
	bun.y = 4
	# Beside it: in the dark a rabbit sees only at arm's length.
	var gob := _spawn(warren, "goblin", 13, 4)
	warren._take_ai_turn(bun)
	check("but frightened, it runs rather than drinks (%d from the goblin)"
		% Los.steps(bun.x, bun.y, gob.x, gob.y), bun.drinking == 0
		and Los.steps(bun.x, bun.y, gob.x, gob.y) > 1)

## TENDING A FIRE WITH YOUR TORCH (Brad, 2026-10-05): the guards' job with
## their numbers; a dead brazier stays a paid problem.
func _test_tending_the_fire_with_the_torch() -> void:
	var gs := _arena(16, 9)
	gs.player.x = 5
	gs.player.y = 4
	gs.player.inventory.clear()
	gs.player.equipped.clear()
	gs.torch_lit = true
	gs.map.set_tile(6, 4, Tiles.BRAZIER)
	gs.brazier_charge[Vector2i(6, 4)] = 3
	gs._gather_lights()
	var rows := func() -> String:
		var all := ""
		for a in gs.actions_here():
			all += String(a[1]) + "|"
		return all
	check("a low fire beside you is one the torch can feed", gs.tend_target() == Vector2i(6, 4))
	check("  and the box offers it, counting", rows.call().contains("feed the fire (torch) 0/3"),
		rows.call())
	var t0 := gs.turns
	check("the first press spends a turn and changes nothing yet",
		gs.player_pickup() and gs.turns == t0 + 1 and int(gs.brazier_charge[Vector2i(6, 4)]) == 3
		and rows.call().contains("feed the fire (torch) 1/3"), rows.call())
	gs.player_pickup()
	gs.player_pickup()
	check("three turns of tending bring it up by the guard's three (and must)",
		int(gs.brazier_charge[Vector2i(6, 4)]) == 6 and _log_says(gs, "burns brighter (+3)"))
	check("  no longer low, it is not offered again", gs.tend_target().x < 0
		and not rows.call().contains("feed the fire"))
	# The guard's own number, never more: a fire at 4 comes to 7, not 10.
	gs.brazier_charge[Vector2i(6, 4)] = GameState.BRAZIER_LOW
	for i in GameState.TORCH_TENDING:
		gs.player_pickup()
	check("the torch is never better than the watch it stands in for (%d)"
		% int(gs.brazier_charge[Vector2i(6, 4)]),
		int(gs.brazier_charge[Vector2i(6, 4)]) == GameState.BRAZIER_LOW + GameState.BRAZIER_STOKE)
	# A dead brazier is not this.
	gs.map.set_tile(6, 4, Tiles.BRAZIER_DEAD)
	gs.brazier_charge[Vector2i(6, 4)] = 0
	check("a dead brazier is not the torch's to relight", gs.tend_target().x < 0
		and not rows.call().contains("feed the fire"))
	check("  and with no fire to give, the key does nothing there", not gs.player_pickup())
	# Nor is a fire with the torch out.
	gs.map.set_tile(6, 4, Tiles.BRAZIER)
	gs.brazier_charge[Vector2i(6, 4)] = 2
	gs.torch_lit = false
	check("with the torch out there is nothing to feed it with", gs.tend_target().x < 0)
	gs.torch_lit = true
	# Progress is the floor's, and saved with it.
	gs.player_pickup()
	var saved := GameState.new(1)
	saved.new_game()
	check("a half-fed fire is remembered by the save",
		saved.apply_dict(gs.to_dict()) and int(saved.tending.get("6,4", 0)) == 1)

## DRIP POOLS (Brad, 2026-10-05): most caves hold a little water, so the
## purple's poison and the slime's acid have their answer where they live.
func _test_drip_pools_in_the_caves() -> void:
	var regions := 0
	var wet_regions := 0
	var pool_cells := 0
	var seeds := 10
	for i in seeds:
		var gs := GameState.new(60000 + i)
		gs.new_game()
		gs.depth = 5
		gs.build_level()
		for region in gs.cave_regions:
			regions += 1
			var water := 0
			for y in range(region.position.y, region.end.y):
				for x in range(region.position.x, region.end.x):
					if gs.map.get_tile(x, y) == Tiles.WATER:
						water += 1
			if water > 0:
				wet_regions += 1
			pool_cells += water
	check("precondition: cave floors have caves (%d regions in %d floors)" % [regions, seeds], regions >= seeds)
	check("most caves hold water now (%d of %d)" % [wet_regions, regions],
		float(wet_regions) / float(maxi(1, regions)) >= 0.55)
	check("and it is pools, not floods (%.1f cells a wet cave)" % (float(pool_cells) / maxi(1, wet_regions)),
		float(pool_cells) / maxi(1, wet_regions) <= 14.0)
	# The pools draw from their own stream: the same seed lays the same floor.
	var a := GameState.new(60003)
	a.new_game()
	a.depth = 5
	a.build_level()
	var b := GameState.new(60003)
	b.new_game()
	b.depth = 5
	b.build_level()
	var same := true
	for y in a.map.height:
		for x in a.map.width:
			if a.map.get_tile(x, y) != b.map.get_tile(x, y):
				same = false
	check("the same seed lays the same pools", same)
	check("the poison lingers five turns now, so a short walk to water is worth it",
		GameState.POISON_LINGER == 5)

## The desktop's four review points of 2026-10-04, built 2026-10-05: a
## grudge dies with the floor, the slime leaves the run's own things, the
## HERE box says the eaters are about, the ally's walk is bounded.
func _test_the_desktops_review_points() -> void:
	# A stale grudge: the orc that speared the wolf leaps into a pit.
	var gs := _arena(21, 9)
	gs.player.x = 3
	gs.player.y = 4
	gs.entities = [gs.player]
	var wolf := _spawn(gs, "wolf", 10, 4)
	var orc := _spawn(gs, "orc", 11, 4)
	gs._attack(orc, wolf)
	check("precondition: the wolf holds the orc's grudge and minds it",
		wolf.alive and wolf.grudge == orc and gs._minds(wolf, orc))
	gs.entities.erase(orc)
	check("the orc gone from the floor, alive, the grudge no longer weighs",
		orc.alive and not gs._minds(wolf, orc))
	wolf.x = 10
	wolf.y = 4
	gs._take_ai_turn(wolf)
	check("  and the wolf does not hunt the ghost (%d,%d)" % [wolf.x, wolf.y],
		not (wolf.x == 11 and wolf.y == 4))
	wolf.grudge = gs.player
	check("  you are always on the floor", gs._minds(wolf, gs.player))

	# The slime leaves the run's own things.
	var pit := _arena(21, 9)
	pit.player.x = 3
	pit.player.y = 4
	pit.entities = [pit.player]
	var slime := _spawn(pit, "slime", 10, 4)
	var amulet := Item.make(&"amulet")
	var bag := Item.make(&"satchel")
	var blade := Item.make(&"dagger")
	check("precondition: an amulet and a satchel are things a slime refuses, a dagger is not",
		amulet != null and bag != null and pit._slime_refuses(amulet)
		and pit._slime_refuses(bag) and not pit._slime_refuses(blade))
	for it in [amulet, bag, blade]:
		it.x = 10
		it.y = 4
	pit.ground = [amulet, bag, blade]
	check("under it all three, it swallows the dagger alone",
		pit._slime_feeds(slime) and slime.inventory.has(blade)
		and pit.ground.has(amulet) and pit.ground.has(bag))
	check("  and with only those left underfoot it feeds no more", not pit._slime_feeds(slime))
	pit.ground = [amulet]
	amulet.x = 13
	amulet.y = 4
	pit._ai_slime(slime, pit.player)
	check("an amulet lying near is no lure: it hunts you instead (%d,%d)" % [slime.x, slime.y],
		slime.x < 10)

	# The HERE box over meat says the eaters are about.
	var den := _arena(21, 9)
	den.player.x = 5
	den.player.y = 4
	den.entities = [den.player]
	den.map.set_tile(5, 4, Tiles.FLOOR)
	var haunch := Item.make(&"meat")
	haunch.x = 5
	haunch.y = 4
	den.ground = [haunch]
	var rows := func() -> String:
		var all := ""
		for a in den.actions_here():
			all += String(a[1]) + "|"
		return all
	check("with no eater alive, meat underfoot is plain", rows.call().contains("pick up the haunch of rabbit|"),
		rows.call())
	var diner := _spawn(den, "goblin", 15, 4)
	check("with an eater on the floor, the box says so", rows.call().contains("haunch of rabbit; eaters about"),
		rows.call())
	# Only the hungry count (2026-10-07): a fed one leaves meat be.
	diner.hunger = 0
	check("  a fed eater is no threat to it: plain again",
		rows.call().contains("pick up the haunch of rabbit|"), rows.call())
	diner.hunger = Entity.HUNGRY_AT
	check("  hungry again, the box says so again",
		rows.call().contains("haunch of rabbit; eaters about"), rows.call())
	check("  within the box's width", "pick up the haunch of rabbit; eaters about".length() <= 42)

	# The ally's walk is bounded.
	check("an ally's own walk looks a bounded distance before settling",
		GameState.ALLY_WALK_REACH <= 40 and GameState.ALLY_WALK_REACH >= GameState.RETREAT_REACH)

## AN ALLY STEPS OUT OF THE POISON ON ITS OWN (Brad, 2026-10-04, after a
## bear ally died in the purple's cloud while he stood still).
func _test_allies_back_out_of_the_poison() -> void:
	var gs := _arena(21, 11)
	gs.player.x = 3
	gs.player.y = 5
	gs.entities = [gs.player]
	gs.map.set_all_visible()
	var pal := _spawn(gs, "skeleton", 10, 5)
	pal.faction = Entity.Faction.PLAYER
	pal.name = "bone skeleton"
	gs._set_fungus(Vector2i(11, 5), Tiles.FUNGUS_PURPLE)
	check("precondition: the ally stands in the purple's cloud", gs.in_miasma(pal.x, pal.y)
		and gs._harmful_ground(pal.x, pal.y))
	gs._take_ai_turn(pal)
	check("its turn: it steps clear of the cloud (%d,%d)" % [pal.x, pal.y],
		not gs._harmful_ground(pal.x, pal.y))
	check("  and the log says so", _log_says(gs, "backs out of the poison"))
	# With a foe beside it in the cloud, it still steps clear first.
	pal.x = 10
	pal.y = 5
	var orc := _spawn(gs, "orc", 10, 4)
	var orc_hp := orc.hp
	gs._take_ai_turn(pal)
	check("beside a foe, it steps clear before it swings (%d,%d; orc %d/%d)"
		% [pal.x, pal.y, orc.hp, orc_hp], not gs._harmful_ground(pal.x, pal.y) and orc.hp == orc_hp)
	gs.entities.erase(orc)
	# Boxed in by walls with the purple at the mouth: nothing clear in reach,
	# so it holds -- and does not walk deeper in.
	var box := _arena(21, 11)
	box.player.x = 3
	box.player.y = 5
	box.entities = [box.player]
	for y in range(1, 10):
		for x in range(12, 20):
			box.map.set_tile(x, y, Tiles.WALL)
	box.map.set_tile(14, 5, Tiles.FLOOR)
	box.map.set_tile(13, 5, Tiles.FLOOR)
	box._set_fungus(Vector2i(13, 5), Tiles.FUNGUS_PURPLE)
	box.pathfinder = Pathfinder.new(box.map)
	var shut := _spawn(box, "skeleton", 14, 5)
	shut.faction = Entity.Faction.PLAYER
	check("precondition: in the cloud with nowhere clear in reach",
		box.in_miasma(14, 5) and not box._back_out_of_harm(shut))
	box._take_ai_turn(shut)
	check("boxed in, it holds (%d,%d)" % [shut.x, shut.y], shut.x == 14 and shut.y == 5)
	# And on the way to you it goes ROUND the purple and its cloud: a patch
	# across the middle of the room, clear floor at the top and bottom.
	var road := _arena(21, 9)
	road.player.x = 3
	road.player.y = 4
	road.entities = [road.player]
	for y in range(3, 6):
		road._set_fungus(Vector2i(9, y), Tiles.FUNGUS_PURPLE)
	var walker := _spawn(road, "skeleton", 15, 4)
	walker.faction = Entity.Faction.PLAYER
	var trod := false
	for i in 24:
		road._take_ai_turn(walker)
		if road._harmful_ground(walker.x, walker.y):
			trod = true
	check("coming to heel, it never sets foot in the cloud (ends %d,%d)" % [walker.x, walker.y],
		not trod and Los.steps(walker.x, walker.y, 3, 4) <= 1)
	# No way round at all: it waits at the cloud's edge rather than wading in.
	var wall := _arena(21, 9)
	wall.player.x = 3
	wall.player.y = 4
	wall.entities = [wall.player]
	for y in range(1, 8):
		wall._set_fungus(Vector2i(9, y), Tiles.FUNGUS_PURPLE)
	var waiter := _spawn(wall, "skeleton", 15, 4)
	waiter.faction = Entity.Faction.PLAYER
	trod = false
	for i in 12:
		wall._take_ai_turn(waiter)
		if wall._harmful_ground(waiter.x, waiter.y):
			trod = true
	check("with no clear way to you, it waits at the edge and never wades in (%d,%d)"
		% [waiter.x, waiter.y], not trod and waiter.x >= 11 and waiter.x <= 12)

	# AND WASHES ITSELF (Brad, 2026-10-05): poisoned, with a pool near, a
	# risen ally wades in and the water takes the poison off it -- the red
	# keeps its dead's spores, but not their poison.
	var pool := _arena(21, 9)
	pool.player.x = 3
	pool.player.y = 4
	pool.entities = [pool.player]
	pool.map.set_all_visible()
	pool.map.set_tile(13, 4, Tiles.WATER)
	var bones := _spawn(pool, "skeleton", 11, 4)
	bones.faction = Entity.Faction.PLAYER
	bones.risen = true
	bones.name = "bone skeleton"
	bones.poisoned = 3
	pool._take_ai_turn(bones)
	check("poisoned, with water two steps off, it makes for the pool (%d,%d)" % [bones.x, bones.y],
		Los.steps(bones.x, bones.y, 13, 4) == 1 and _log_says(pool, "makes for the water"))
	pool._take_ai_turn(bones)
	check("  and wades in", pool.map.get_tile(bones.x, bones.y) == Tiles.WATER)
	pool._wash(bones)
	check("  where the water takes the poison off a RISEN ally (and must)", bones.poisoned == 0
		and _log_says(pool, "washes the poison off"))
	bones.spores = &"red"
	pool._wash(bones)
	check("  but never the red's claim on its dead", bones.spores == &"red")
	# Not worth it: more steps than hurt left.
	var far_pool := _arena(21, 9)
	far_pool.player.x = 3
	far_pool.player.y = 4
	far_pool.entities = [far_pool.player]
	far_pool.map.set_tile(18, 4, Tiles.WATER)
	var sore := _spawn(far_pool, "skeleton", 4, 4)
	sore.faction = Entity.Faction.PLAYER
	sore.poisoned = 2
	far_pool._take_ai_turn(sore)
	check("with the pool further than the hurt is long, it stays at heel (%d,%d)" % [sore.x, sore.y],
		sore.x <= 5)
	sore.poisoned = 0
	sore.x = 11
	sore.y = 4
	far_pool._take_ai_turn(sore)
	check("and a well ally never goes paddling", sore.x < 11)

## THEY HAVE TO EAT TOO (Brad, 2026-10-04): while unaware of you, a monster
## with an appetite hunts the wild, and eats the kill off the floor.
func _test_hunters_eat_the_wild() -> void:
	var cave := _arena(24, 11)
	cave.player.x = 2
	cave.player.y = 2
	cave.torch_lit = false
	cave.entities = [cave.player]
	# A mushroom lights the rabbit grazing on it: the hunter needs to SEE.
	cave.map.set_tile(12, 5, Tiles.FUNGUS)
	cave.map.set_tile(12, 8, Tiles.FUNGUS)
	# And a wall between you and the hunting ground: in the dark a creature
	# still has a small chance a turn of noticing you, and one lucky roll
	# would turn a hunter into a hunter of YOU.
	for y in range(1, 10):
		cave.map.set_tile(5, y, Tiles.WALL)
	cave.pathfinder = Pathfinder.new(cave.map)
	cave._gather_lights()
	cave.update_vision()
	var gob := _spawn(cave, "goblin", 9, 5)
	gob.alertness = Entity.Alert.PATROL
	var bun := _spawn(cave, "rabbit", 12, 5)
	check("precondition: a goblin has an appetite, and can see the rabbit in the fungus light",
		gob.eats and cave._can_see(gob, bun))
	check("a rabbit is a goblin's game", cave._prey_for(gob) == bun)
	var skel := _spawn(cave, "skeleton", 9, 7)
	check("a skeleton has no appetite", not skel.eats)
	var kob := _spawn(cave, "kobold", 11, 5)
	var bruin := _spawn(cave, "cave bear", 10, 4)
	check("precondition: the kobold can see the bear beside it", cave._can_see(kob, bruin))
	cave.entities.erase(bun)
	check("a kobold never hunts a bear", cave._prey_for(kob) == null)
	cave.entities.append(bun)
	cave.entities.erase(bruin)
	cave.entities.erase(kob)
	cave.entities.erase(skel)

	var d0 := Los.steps(gob.x, gob.y, bun.x, bun.y)
	cave._take_ai_turn(gob)
	check("unaware of you, the goblin goes for the rabbit (%d -> %d)"
		% [d0, Los.steps(gob.x, gob.y, bun.x, bun.y)], Los.steps(gob.x, gob.y, bun.x, bun.y) < d0)
	check("  and is no enemy of the rabbit yet", not gob.hostile_to(bun) and not bun.provoked)
	# Beside it, with the rabbit on its last legs: the kill, and the haunch.
	gob.x = 11
	gob.y = 5
	bun.hp = 1
	cave._take_ai_turn(gob)
	check("beside it, the goblin kills the rabbit", not bun.alive)
	check("  its own racket does not wake it to hunting you", gob.alertness != Entity.Alert.AWAKE)
	var haunch: Item = null
	for it in cave.ground:
		if it.id == &"meat":
			haunch = it
	check("the haunch lies where the rabbit fell", haunch != null and haunch.x == 12 and haunch.y == 5,
		str(cave.ground.map(func(i): return [i.id, i.x, i.y])))
	gob.hp = 3
	cave._take_ai_turn(gob)
	check("the goblin walks to the meat", gob.x == 12 and gob.y == 5, "%d,%d" % [gob.x, gob.y])
	# In your sight for the meal, so the log has to say so.
	cave.map.set_all_visible()
	cave._take_ai_turn(gob)
	check("and eats it: gone from the floor, and it is healed (%d hp)" % gob.hp,
		not cave.ground.has(haunch) and gob.hp > 3 and _log_says(cave, "eats the haunch"))

	# Aware of you, nothing stops for supper.
	var bun2 := _spawn(cave, "rabbit", 13, 5)
	gob.alertness = Entity.Alert.AWAKE
	cave._take_ai_turn(gob)
	check("a goblin that has seen you leaves the rabbit beside it alone", bun2.hp == bun2.max_hp)

	# The ranged take the bats. And a bat shot at fights back.
	var sling := _spawn(cave, "kobold slinger", 9, 8)
	sling.alertness = Entity.Alert.PATROL
	var bat := _spawn(cave, "cave bat", 12, 8)
	check("precondition: the slinger can see the bat", cave._can_see(sling, bat))
	check("a bat is the slinger's game, and never a goblin's",
		cave._prey_for(sling) == bat and cave._prey_for(gob) != bat)
	for i in 4:
		if bat.hp < bat.max_hp:
			break
		cave._take_ai_turn(sling)
	check("the slinger slings at the bat (%d of %d)" % [bat.hp, bat.max_hp], bat.hp < bat.max_hp,
		"slinger alert %d at %d,%d reload %d; bat at %d,%d" % [sling.alertness, sling.x, sling.y,
			sling.reload_left, bat.x, bat.y])
	check("  which remembers the slinger, and no one else", bat.grudge == sling and not bat.provoked)
	var bd := Los.steps(bat.x, bat.y, sling.x, sling.y)
	var sling_hp := sling.hp
	cave._take_ai_turn(bat)
	check("  and comes for it (%d -> %d)" % [bd, Los.steps(bat.x, bat.y, sling.x, sling.y)],
		Los.steps(bat.x, bat.y, sling.x, sling.y) < bd or sling.hp < sling_hp)
	check("a monster's appetite is saved", Entity.from_dict(gob.to_dict()).eats)
	# And a save from before appetites existed gets them back on loading.
	var old_save := cave.to_dict()
	for entry in old_save["entities"]:
		entry.erase("eats")
	var loaded := GameState.new(1)
	loaded.new_game()
	check("precondition: the old save loads", loaded.apply_dict(old_save))
	var fed := 0
	for e in loaded.entities:
		if e.appearance == &"goblin" and e.eats:
			fed += 1
	check("a save without appetites recorded gets them back from the bestiary", fed >= 1,
		str(loaded.entities.map(func(e): return [e.appearance, e.eats])))

	# The food web: a bear, awake and unstruck, hunts the rabbit it can see,
	# and the rabbit fears it as it fears a goblin.
	var wood := _arena(24, 11)
	wood.player.x = 2
	wood.player.y = 2
	wood.torch_lit = false
	wood.entities = [wood.player]
	wood.map.set_tile(12, 5, Tiles.FUNGUS)
	for y in range(1, 10):
		wood.map.set_tile(5, y, Tiles.WALL)
	wood.pathfinder = Pathfinder.new(wood.map)
	wood._gather_lights()
	wood.update_vision()
	# Two cells apart, both in the mushroom's glow: each has to SEE the
	# other, and the dark three cells out hides a bear from a rabbit.
	var ursa := _spawn(wood, "cave bear", 10, 5)
	var hare := _spawn(wood, "rabbit", 12, 5)
	check("precondition: an awake bear with an appetite, and a rabbit in its sight (and it in the rabbit's)",
		ursa.eats and ursa.alertness == Entity.Alert.AWAKE and wood._can_see(ursa, hare)
		and wood._can_see(hare, ursa))
	check("a rabbit is a bear's game; another bear never is",
		wood._prey_for(ursa) == hare and wood._what_scares(hare) == ursa)
	var bd0 := Los.steps(ursa.x, ursa.y, hare.x, hare.y)
	wood._take_ai_turn(ursa)
	check("the bear goes for the rabbit (%d -> %d)" % [bd0, Los.steps(ursa.x, ursa.y, hare.x, hare.y)],
		Los.steps(ursa.x, ursa.y, hare.x, hare.y) < bd0 and not ursa.provoked)
	var hd0 := Los.steps(ursa.x, ursa.y, hare.x, hare.y)
	wood._take_ai_turn(hare)
	check("and the rabbit runs from the bear (%d -> %d)" % [hd0, Los.steps(ursa.x, ursa.y, hare.x, hare.y)],
		Los.steps(ursa.x, ursa.y, hare.x, hare.y) > hd0)
	ursa.x = hare.x - 1
	ursa.y = hare.y
	hare.hp = 1
	wood._take_ai_turn(ursa)
	check("beside it, the bear kills it, and is still no enemy of yours",
		not hare.alive and not ursa.hostile_to(wood.player))
	ursa.hp = 20
	wood._take_ai_turn(ursa)
	wood._take_ai_turn(ursa)
	check("and eats the haunch (%d hp)" % ursa.hp, ursa.hp > 20
		and wood.ground.filter(func(i): return i.id == &"meat").is_empty())

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

	# The same bug, again (day-7 hunt, 2026-10-04): stacks and the satchel
	# taught display_name " x3" and "(14)" on 2026-10-03, and nothing told
	# the reader. A worn satchel is in every morgue line that wears one.
	var three_daggers := Item.make(&"dagger")
	three_daggers.count = 3
	var three_back := Item.from_display_name(three_daggers.display_name())
	check("\"%s\" survives the morgue and back" % three_daggers.display_name(),
		three_back != null and three_back.id == &"dagger" and three_back.count == 3,
		"got %s" % (three_back.display_name() if three_back else "null"))
	var worn_bag := Item.make(&"satchel")
	var bag_back := Item.from_display_name(worn_bag.display_name())
	check("\"%s\" comes back a satchel, its count not read as a binding"
		% worn_bag.display_name(),
		bag_back != null and bag_back.id == &"satchel" and bag_back.element == &"",
		"got %s" % (bag_back.display_name() + " element '%s'" % bag_back.element
			if bag_back else "null"))
	var bag_twice: Item = Item.from_display_name(bag_back.display_name()) if bag_back else null
	check("and survives a second trip, as a bone ally's kit takes it",
		bag_twice != null and bag_twice.id == &"satchel")
	# Written "(14)" for one day; those morgue lines are the player's and stay.
	var old_bag := Item.from_display_name("forager's satchel (14)")
	check("a morgue line from the \"(14)\" day still reads as a plain satchel",
		old_bag != null and old_bag.id == &"satchel" and old_bag.element == &"",
		"got %s" % (old_bag.display_name() if old_bag else "null"))
	# Every catalogue item, plain, there and back -- the must-succeed half.
	var name_lost: Array = []
	for id in Item.CATALOGUE:
		var plain_item := Item.make(id)
		if plain_item == null:
			continue
		var plain_back := Item.from_display_name(plain_item.display_name())
		if plain_back == null or plain_back.display_name() != plain_item.display_name():
			name_lost.append(plain_item.display_name())
	check("every catalogue item reads back as itself", name_lost.is_empty(), str(name_lost))

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
	check("and keeps the shovel, dull (6c: a gem sharpens it)",
		dig.player.inventory.has(shovel) and shovel.dull)
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

## Nothing ARRIVES inside a door (day 7, 2026-10-04). Shut and barred doors are
## walkable -- walking into one is how it opens -- so every arrival that asked
## only "walkable?" took them: a lich's blink stood it inside a shut, opaque
## door, and the blink scroll, whose own copy of the rule lacked is_avoided
## too, could set you over a pit with no fall (that lives only in player_move)
## or on a found trap. Four arrivals share GameState._can_land_on now.
##
## Each is tried in a sealed cell whose only ground is the forbidden squares
## and one of floor, so an arrival that refused EVERYTHING fails the "every
## time" checks instead of passing the "never" ones quietly.
##
## A HIDDEN trap is floor to every arrival, and landing on one does not spring
## it -- Brad's call, 2026-10-04 (see GameState._can_land_on). Nothing below
## asserts it either way.
func _test_nothing_arrives_inside_a_door() -> void:
	var shut := Vector2i(12, 3)
	var barred := Vector2i(12, 4)
	var pit := Vector2i(12, 5)
	var found_trap := Vector2i(12, 6)
	var open_floor := Vector2i(12, 7)
	var gs := _arena(31, 11)
	for y in range(1, 10):
		for x in range(1, 30):
			gs.map.set_tile(x, y, Tiles.WALL)
	gs.map.set_tile(5, 5, Tiles.FLOOR)
	gs.map.set_tile(6, 5, Tiles.FLOOR)
	gs.map.set_tile(shut.x, shut.y, Tiles.DOOR_CLOSED)
	gs.map.set_tile(barred.x, barred.y, Tiles.DOOR_BARRED)
	gs.map.set_tile(pit.x, pit.y, Tiles.PIT)
	gs.map.set_tile(found_trap.x, found_trap.y, Tiles.TRAP)
	gs.map.set_tile(open_floor.x, open_floor.y, Tiles.FLOOR)
	gs.pathfinder = Pathfinder.new(gs.map)
	gs.player.x = 5
	gs.player.y = 5
	var lich := _spawn(gs, "arch lich", 6, 5)

	# The doors are ground the old rule took, and every square lies inside a
	# blink's reach and past the caster's stand-off -- or the "never" checks
	# below would pass for the wrong reason.
	check("a shut and a barred door are both walkable ground",
		gs.map.is_walkable(shut.x, shut.y) and gs.map.is_walkable(barred.x, barred.y))
	var placed := true
	for c in [shut, barred, pit, found_trap, open_floor]:
		placed = placed and Los.steps(6, 5, c.x, c.y) <= lich.blink_range \
			and Los.steps(5, 5, c.x, c.y) > lich.standoff
	check("and every square is in reach, out of the quarry's", placed)

	var blinked := 0
	var lich_landed := {}
	for i in 24:
		lich.x = 6
		lich.y = 5
		lich.blink_cool = 0
		if gs._blink_away(lich, gs.player):
			blinked += 1
			lich_landed[Vector2i(lich.x, lich.y)] = true
	check("a cornered caster still blinks every time (%d of 24)" % blinked, blinked == 24)
	check("never into a shut door", not lich_landed.has(shut), str(lich_landed.keys()))
	check("never into a barred door", not lich_landed.has(barred), str(lich_landed.keys()))
	check("only ever onto the floor", lich_landed.keys() == [open_floor],
		str(lich_landed.keys()))

	# The scroll, in the same cell. Its effect itself rather than player_use,
	# so no end of turn can change the cell between reads.
	gs.entities.erase(lich)
	gs.map.set_tile(6, 5, Tiles.WALL)
	var read := 0
	var you_landed := {}
	for i in 24:
		gs.player.x = 5
		gs.player.y = 5
		if gs._apply_effect(Item.make(&"scroll_blink")):
			read += 1
			you_landed[Vector2i(gs.player.x, gs.player.y)] = true
	check("the scroll still works every time (%d of 24)" % read, read == 24)
	check("it never sets you inside a shut door", not you_landed.has(shut),
		str(you_landed.keys()))
	check("or a barred one", not you_landed.has(barred), str(you_landed.keys()))
	check("or over a pit, with no fall to follow", not you_landed.has(pit),
		str(you_landed.keys()))
	check("or on a trap you have found", not you_landed.has(found_trap),
		str(you_landed.keys()))
	check("the scroll lands only on the floor", you_landed.keys() == [open_floor],
		str(you_landed.keys()))

	# The returning gem's ring round the fire is searched in a fixed order, and
	# a shut door sits first in it, a barred one second.
	gs.map.set_tile(19, 4, Tiles.DOOR_CLOSED)
	gs.map.set_tile(20, 4, Tiles.DOOR_BARRED)
	gs.map.set_tile(21, 6, Tiles.FLOOR)
	var back := gs._recall_spot(Vector2i(20, 5))
	check("the returning gem sets you by the fire, not in its doorway (%s)" % back,
		back == Vector2i(21, 6))

	# And the fallen land on the farthest open square -- here a door, with
	# floor one step nearer.
	gs.map.set_tile(28, 5, Tiles.DOOR_CLOSED)
	gs.map.set_tile(27, 5, Tiles.FLOOR)
	gs.player.x = 5
	gs.player.y = 5
	var far := gs._far_landing()
	check("the fallen land on the farthest floor, not in a door (%s)" % far,
		far == Vector2i(27, 5))

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
	check("but they take iron", glass.player_merge(glass.player.inventory.size() - 1))

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
## LIKE KINDS STACK IN THE PACK (Brad, 2026-10-02; built 2026-10-03): one
## slot, one letter, up to twenty; gear and uniques never; one leaves at a
## time by use, drop, throw, sale and binding; a forge works two into one.
## THE ● KEEPS ITS WORD (day-7 hunt, 2026-10-04): a stack of three or more
## with a full pack cannot be forged (nowhere to set the plain ones apart),
## and the mark and the hint say so before the key refuses; a stack of two
## forges as ever, full pack or not.
func _test_the_forge_mark_keeps_its_word() -> void:
	var gs := _arena(11, 7)
	gs.player.x = 5
	gs.player.y = 3
	gs.player.inventory.clear()
	gs.player.equipped.clear()
	gs.map.set_tile(6, 3, Tiles.BRAZIER)
	gs.brazier_charge[Vector2i(6, 3)] = 60
	for i in Entity.INVENTORY_MAX - 1:
		var blade := Item.make(&"dagger")
		blade.element = &"fire"
		gs.give_item(blade)
	var stack := Item.make(&"dagger")
	gs.give_item(stack)
	gs.give_item(Item.make(&"dagger"))
	gs.give_item(Item.make(&"dagger"))
	check("precondition: a full pack, with a stack of three plain daggers in it",
		gs.player.pack_count() == Entity.INVENTORY_MAX and stack.count == 3
		and gs.can_forge_here() and not gs._forge_site(stack).is_empty())
	var panel := InventoryPanel.new()
	panel.state = gs
	panel.font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
	check("full, the stack of three wears no ● and the hint says why",
		not gs.can_forge_item(stack)
		and panel._action_hint(stack) == "pack full: nowhere to set the rest apart",
		panel._action_hint(stack))
	check("  and the key refuses it with nothing spent",
		not gs.player_merge(gs.player.inventory.find(stack)) and stack.count == 3)
	# Two in the stack: the worked one IS the slot, nothing is set apart.
	stack.count = 2
	check("a stack of two forges with a full pack (and must)", gs.can_forge_item(stack)
		and panel._action_hint(stack) == "merge -> +1"
		and gs.player_merge(gs.player.inventory.find(stack))
		and stack.upgrade_level() == 1 and stack.count == 1)
	# Room made: three forges again, and the plain one left is set apart.
	stack.count = 3
	stack.power_bonus = stack.base_power_bonus
	stack.boosts = 0
	gs.player.inventory.remove_at(0)
	check("precondition: a slot free", gs.player.pack_count() == Entity.INVENTORY_MAX - 1)
	var rows_before := gs.player.inventory.size()
	check("with a slot free the ● comes back and the forge sets the rest apart",
		gs.can_forge_item(stack) and gs.player_merge(gs.player.inventory.find(stack))
		and stack.count == 1 and stack.upgrade_level() == 1
		and gs.player.inventory.size() == rows_before + 1)

func _test_stacks_in_the_pack() -> void:
	var gs := _arena(21, 9)
	gs.player.x = 5
	gs.player.y = 4
	gs.player.inventory.clear()
	gs.player.equipped.clear()
	gs.torch_lit = false
	for i in 3:
		check_silent(gs.give_item(Item.make(&"potion_healing")))
	check_gathered("three potions are taken")
	check("and sit in one slot, under one letter, counted as one",
		gs.player.inventory.size() == 1 and gs.player.inventory[0].count == 3
		and gs.player.inventory[0].letter != "" and gs.player.pack_count() == 1)
	var pot: Item = gs.player.inventory[0]
	check("the name says how many", pot.display_name().ends_with("x3"), pot.display_name())
	gs.give_item(Item.make(&"scroll_light"))
	var boosted := Item.make(&"potion_healing")
	boosted.boosts = 1
	gs.give_item(boosted)
	check("a scroll and a worked potion each take their own slot",
		gs.player.inventory.size() == 3 and pot.count == 3)
	var fire1 := Item.make(&"gem_fire")
	var fire2 := Item.make(&"gem_fire")
	var frost := Item.make(&"gem_frost")
	gs.give_item(fire1)
	gs.give_item(fire2)
	gs.give_item(frost)
	check("gems of one element stack; another element does not",
		fire1.count == 2 and gs.player.inventory.has(frost) and not gs.player.inventory.has(fire2))
	# GEAR: plain stacks with plain; a forge level or an element sets it apart.
	var d1 := Item.make(&"dagger")
	var d2 := Item.make(&"dagger")
	var worked := Item.make(&"dagger")
	worked.upgrade()
	var fiery := Item.make(&"dagger")
	fiery.element = &"fire"
	gs.give_item(d1)
	gs.give_item(d2)
	gs.give_item(worked)
	gs.give_item(fiery)
	var daggers := 0
	for it in gs.player.inventory:
		if it.id == &"dagger":
			daggers += 1
	check("plain daggers stack; a worked one and a fiery one each sit alone",
		d1.count == 2 and not gs.player.inventory.has(d2) and daggers == 3)
	# Wielding from the stack splits one off, into its own slot after it.
	var d_at := gs.player.inventory.find(d1)
	check("precondition: wielding from the stack works", gs.player_use(d_at))
	var held: Item = gs.player.equipped.get(Item.Slot.WEAPON, null)
	check("the one in hand is its own item, beside the stack",
		held != null and held != d1 and held.id == &"dagger" and held.count == 1
		and d1.count == 1 and gs.player.inventory.find(held) == d_at + 1
		and held.letter != "" and held.letter != d1.letter)
	gs.give_item(Item.make(&"dagger"))
	check("a plain dagger picked up joins the stack, never the one in hand",
		d1.count == 2 and held.count == 1)
	var bow := Item.make(&"war_bow")
	gs.give_item(bow)
	gs.give_item(Item.make(&"war_bow"))
	check("launchers carry a quiver and never stack", bow.count == 1)
	gs.player.equipped.erase(Item.Slot.WEAPON)
	gs.player.inventory.erase(held)
	gs.player.inventory.erase(bow)
	for it in gs.player.inventory.duplicate():
		if it.id == &"war_bow":
			gs.player.inventory.erase(it)
	# Meat: the stack carries the average worth.
	var lean := Item.make(&"bear_meat")
	lean.magnitude = 5
	var fat := Item.make(&"bear_meat")
	fat.magnitude = 9
	gs.give_item(lean)
	gs.give_item(fat)
	check("two haunches stack, and the stack is worth their average (%d)" % lean.magnitude,
		lean.count == 2 and lean.magnitude == 7 and not gs.player.inventory.has(fat))

	# Twenty is the stack; the twenty-first starts another slot.
	for i in 17:
		gs.give_item(Item.make(&"potion_healing"))
	check("a stack holds twenty", pot.count == Item.PACK_STACK)
	var before := gs.player.inventory.size()
	gs.give_item(Item.make(&"potion_healing"))
	check("and the twenty-first starts a new one", gs.player.inventory.size() == before + 1)

	# A FULL pack still takes one more of what it holds, and nothing new.
	# Filled with potions of ever higher forge level: each its own stack.
	var filler := 1
	while gs.player.pack_count() < Entity.INVENTORY_MAX:
		var f := Item.make(&"potion_healing")
		f.boosts = filler
		filler += 1
		if not gs.give_item(f):
			break
	check("precondition: the pack is full", gs.player.pack_count() == Entity.INVENTORY_MAX)
	check("full, it still takes a potion onto a stack with room",
		gs.give_item(Item.make(&"potion_healing")))
	check("  and refuses something it has no slot for", not gs.give_item(Item.make(&"scroll_blink")))

	# ONE AT A TIME. Use, drop, throw: the slot and the letter stay.
	var letter := pot.letter
	var at := gs.player.inventory.find(pot)
	gs.player.max_hp = 500
	gs.player.hp = 100
	var n := pot.count
	check("drinking one takes one off the stack and keeps the slot",
		gs.player_use(at) and pot.count == n - 1 and gs.player.inventory[at] == pot
		and pot.letter == letter and gs.player.hp > 100)
	n = pot.count
	var on_floor := gs.ground.size()
	check("dropping one puts one on the floor and keeps the rest",
		gs.player_drop(at) and pot.count == n - 1 and gs.ground.size() == on_floor + 1
		and gs.ground[-1].id == &"potion_healing" and gs.ground[-1].count == 1
		and gs.ground[-1].letter == "" and gs.player.inventory.has(pot))
	var kob := _spawn(gs, "kobold", 7, 4)
	kob.hp = 100
	gs.torch_lit = true
	gs._gather_lights()
	gs.update_vision()
	var d_stack_at := gs.player.inventory.find(d1)
	check("precondition: the dagger stack is two, and the kobold is in reach",
		d_stack_at >= 0 and d1.count == 2 and d1.is_throwable()
		and gs.can_reach(Vector2i(7, 4), d1.throw_range))
	# Throwing from the stack: one dagger flies, the other stays lettered.
	var thrown := gs.player_throw(d_stack_at, Vector2i(7, 4))
	check("throwing from a stack throws one",
		thrown and d1.count == 1 and gs.player.inventory.has(d1) and d1.letter != "",
		"thrown=%s count=%d last=%s" % [thrown, d1.count, str(gs.msg_log.entries[-1]["text"])])
	# Picking the dropped potion back up rejoins the stack and says so.
	var dropped_pot: Item = null
	for it in gs.ground:
		if it.id == &"potion_healing":
			dropped_pot = it
	gs.ground = [dropped_pot]
	dropped_pot.x = gs.player.x
	dropped_pot.y = gs.player.y
	n = pot.count
	gs.entities = [gs.player]
	check("precondition: the pack is full and the stack has room",
		gs.player.pack_count() >= Entity.INVENTORY_MAX and pot.count < Item.PACK_STACK)
	check("picking one up again rejoins the stack", gs.player_pickup() and pot.count == n + 1
		and gs.msg_log.entries[-1]["text"].contains("x%d now" % pot.count),
		gs.msg_log.entries[-1]["text"])
	# Saved and loaded, the stack is a stack.
	var back := GameState.new(1)
	back.new_game()
	check("a suspend keeps the stacks", back.apply_dict(gs.to_dict())
		and back.player.inventory.size() == gs.player.inventory.size()
		and back.player.inventory[at].count == pot.count)
	# A save from before stacking, or any save: the pack is folded on load,
	# worn things left alone (Brad, resuming a run, saw three plain daggers in
	# three rows).
	var old := _arena(21, 9)
	old.player.inventory.clear()
	old.player.equipped.clear()
	var loose: Array = []
	for i in 3:
		var d := Item.make(&"dagger")
		d.letter = "abc"[i]
		loose.append(d)
	var wornd := Item.make(&"dagger")
	wornd.letter = "d"
	loose.append(wornd)
	for i in 2:
		var pp := Item.make(&"potion_healing")
		pp.letter = "eg"[i]
		loose.append(pp)
	for it in loose:
		old.player.inventory.append(it)
	old.player.equipped[Item.Slot.WEAPON] = wornd
	check("precondition: six rows written straight in, one worn",
		old.player.inventory.size() == 6 and old.player.is_equipped(wornd))
	var loaded := GameState.new(1)
	loaded.new_game()
	check("loaded, like things fold together and the worn one stays apart",
		loaded.apply_dict(old.to_dict()) and loaded.player.inventory.size() == 3
		and loaded.player.inventory[0].id == &"dagger" and loaded.player.inventory[0].count == 3
		and loaded.player.inventory[0].letter == "a"
		and loaded.player.inventory[1].count == 1 and loaded.player.is_equipped(loaded.player.inventory[1])
		and loaded.player.inventory[2].count == 2,
		str(loaded.player.inventory.map(func(x): return x.display_name())))

	# The last one leaves the slot and frees the letter.
	var one := _arena(21, 9)
	one.player.inventory.clear()
	one.player.equipped.clear()
	one.give_item(Item.make(&"scroll_light"))
	one.give_item(Item.make(&"scroll_light"))
	var sc: Item = one.player.inventory[0]
	var sc_letter := sc.letter
	one.player_use(0)
	check("precondition: one scroll left in the slot", sc.count == 1 and one.player.inventory.has(sc))
	one.player_use(0)
	check("the last of a stack leaves the slot and its letter",
		not one.player.inventory.has(sc) and sc.letter == "" and one.player.inventory.is_empty())
	check("and the letter is free for the next thing",
		one.give_item(Item.make(&"dagger")) and one.player.inventory[0].letter == sc_letter)

## WORN GEAR IS NOT IN THE PACK (Brad, 2026-10-02): a sword, a coat and a
## shield on you leave all twenty slots free; the pack is full at twenty
## unworn things; taking something off needs room; a swap needs none.
func _test_worn_gear_is_not_in_the_pack() -> void:
	var gs := _arena(21, 9)
	gs.player.x = 5
	gs.player.y = 4
	gs.player.inventory.clear()
	gs.player.equipped.clear()
	var sword := Item.make(&"short_sword")
	var coat := Item.make(&"leather_armour")
	var shield := Item.make(&"buckler")
	for worn in [sword, coat, shield]:
		check_silent(worn != null and gs.give_item(worn))
		if worn != null:
			gs._toggle_equip(worn)
	check_gathered("precondition: three things are worn")
	check("precondition: all three are worn, and the pack counts none of them",
		gs.player.is_equipped(sword) and gs.player.is_equipped(coat)
		and gs.player.is_equipped(shield) and gs.player.pack_count() == 0
		and gs.player.inventory.size() == 3)
	var handed := 0
	var other_blade := Item.make(&"dagger")
	if gs.give_item(other_blade):
		handed += 1
	for i in Entity.INVENTORY_MAX - 1:
		# Each at its own forge level, so none joins another's stack.
		var filler := Item.make(&"potion_healing")
		filler.boosts = i + 1
		if gs.give_item(filler):
			handed += 1
	check("twenty more fit in the pack beside them (%d)" % handed,
		handed == Entity.INVENTORY_MAX and gs.player.pack_count() == Entity.INVENTORY_MAX
		and gs.player.inventory.size() == Entity.INVENTORY_MAX + Entity.WORN_SLOTS)
	var extra := Item.make(&"potion_healing")
	extra.boosts = 99
	check("the twenty-first does not", not gs.give_item(extra))
	# A second plain dagger joins the first's stack even now: a stack has room.
	check("but a plain dagger joins the one already there", gs.give_item(Item.make(&"dagger"))
		and other_blade.count == 2)
	# Wielding one off that stack would send the sword into a pack with no
	# room (the stack stays): refused, like taking something off.
	var t_before := gs.turns
	check("wielding from a stack into a full pack is refused",
		not gs.player_use(gs.player.inventory.find(other_blade)) and gs.player.is_equipped(sword)
		and other_blade.count == 2 and gs.turns == t_before)
	# Back to a single dagger for the swap below.
	other_blade.count = 1
	var blank := 0
	var seen := {}
	for it in gs.player.inventory:
		if it.letter == "" or seen.has(it.letter):
			blank += 1
		seen[it.letter] = true
	check("and every one of the twenty-three has its own letter", blank == 0, "%d" % blank)
	# The HERE box and the key agree the pack is full.
	var lying := Item.make(&"potion_healing")
	lying.x = gs.player.x
	lying.y = gs.player.y
	gs.ground = [lying]
	check("the key refuses a pickup the pack cannot take",
		not gs.player_pickup() and gs.ground.has(lying))
	# Taking something off needs a slot; swapping does not.
	var turn0 := gs.turns
	check("taking the shield off with a full pack is refused, and costs nothing",
		not gs.player_use(gs.player.inventory.find(shield))
		and gs.player.is_equipped(shield) and gs.turns == turn0)
	var said: String = gs.msg_log.entries[-1]["text"]
	check("  and says what to do (\"%s\")" % said, said.contains("Drop something"))
	check("wielding a dagger from the pack in the sword's place works",
		gs.player_use(gs.player.inventory.find(other_blade))
		and gs.player.is_equipped(other_blade) and not gs.player.is_equipped(sword)
		and gs.player.pack_count() == Entity.INVENTORY_MAX)
	# A bow from the pack swaps with the sword and sends the shield to the pack
	# as before -- still a swap, the count unchanged.
	var bow := Item.make(&"war_bow")
	# The sword is in the pack now; dropping it is what makes room. Taking the
	# worn dagger out would free nothing, which is the point of this test.
	gs.player.inventory.erase(sword)
	gs.player.equipped.erase(Item.Slot.WEAPON)
	# The dagger stays as the blade to fall back on; a filler goes instead.
	for it in gs.player.inventory:
		if it.id == &"potion_healing":
			gs.player.inventory.erase(it)
			break
	check("precondition: a slot was made for the bow", gs.give_item(bow)
		and gs.player.pack_count() == Entity.INVENTORY_MAX)
	check("the swap key still reaches the bow with a full pack",
		gs.player_swap_weapon() and gs.player.is_equipped(bow)
		and not gs.player.is_equipped(shield) and gs.player.pack_count() == Entity.INVENTORY_MAX,
		"%d in the pack" % gs.player.pack_count())
	check("and back to a blade, the shield comes up again",
		gs.player_swap_weapon() and gs.player.is_equipped(shield)
		and not gs.player.is_equipped(bow))
	# Saved and loaded, the worn things are still worn and still not counted.
	var back := GameState.new(1)
	back.new_game()
	check("a suspend keeps what is worn out of the count",
		back.apply_dict(gs.to_dict()) and back.player.pack_count() == gs.player.pack_count()
		and back.player.inventory.size() == gs.player.inventory.size()
		and back.player.pack_count() < back.player.inventory.size())
	# Fill the pack again, drop one whole thing, and the coat can come off.
	var level := 50
	while gs.player.pack_count() < Entity.INVENTORY_MAX:
		var more := Item.make(&"potion_healing")
		more.boosts = level
		level += 1
		if not gs.give_item(more):
			break
	check("precondition: full again, and the coat cannot come off",
		gs.player.pack_count() == Entity.INVENTORY_MAX
		and not gs.player_use(gs.player.inventory.find(coat)) and gs.player.is_equipped(coat))
	var spare := -1
	for i in gs.player.inventory.size():
		var it: Item = gs.player.inventory[i]
		if it.count == 1 and not gs.player.is_equipped(it) and not it.is_equipment():
			spare = i
			break
	check("precondition: a single unworn thing to drop", spare >= 0 and gs.player_drop(spare))
	check("with room made, taking the coat off works",
		gs.player.pack_count() < Entity.INVENTORY_MAX
		and gs.player_use(gs.player.inventory.find(coat)) and not gs.player.is_equipped(coat))

func _test_inventory_letters_dodge_the_keys() -> void:
	for i in GameState.RESERVED_LETTERS.length():
		var ch := GameState.RESERVED_LETTERS[i]
		check("the pool never offers \"%s\"" % ch,
			not GameState.LETTERS.contains(ch))
	check("and is still long enough for a full pack and everything worn (%d for %d + %d)"
		% [GameState.LETTERS.length(), Entity.INVENTORY_MAX, Entity.WORN_SLOTS],
		GameState.LETTERS.length() >= Entity.INVENTORY_MAX + Entity.WORN_SLOTS)

	# Fill a pack and check nothing unreachable comes out of it. Potions at
	# twenty different forge levels: like things would stack under one letter.
	var gs := _arena(21, 9)
	var handed := 0
	for i in Entity.INVENTORY_MAX:
		var filler := Item.make(&"potion_healing")
		filler.boosts = i + 1
		if gs.give_item(filler):
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
	# Four slots: the two potions are one stack (2026-10-03).
	check("with the run intact", back.depth == 9 and back.ascending
		and back.player.level == 9 and back.player.inventory.size() == 4
		and back.player.inventory[2].count == 2)
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
