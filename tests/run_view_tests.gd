extends SceneTree

## The shared view layer: effects, step glides, creature marks, moving light,
## fading memory, colour by region and small life, which the classic grid and
## the 3D view both draw from -- and the 3D view's own camera and extras.
##
##     godot --headless --script res://tests/run_view_tests.gd
##
## A file of its own rather than more of run_tests.gd, so this work and the
## simulation's suite can move independently; it follows the same conventions
## (scratch files, the settings tripwire, one line per check).

var _passed := 0
var _failed := 0

func _initialize() -> void:
	# Same protections as run_tests.gd: scratch paths first -- the save, the
	# morgue, the bestiary, the settings and the pad bindings all move -- and a
	# tripwire on the real settings.cfg besides, in case anything writes it by
	# its own path.
	GameState.use_scratch_files("view_tests")
	var settings_before := ""
	var had_settings := FileAccess.file_exists("user://settings.cfg")
	if had_settings:
		settings_before = FileAccess.get_file_as_string("user://settings.cfg")
	print("")
	_test_hits_become_effects()
	_test_effects_answer_to_the_motion_setting()
	_test_every_effect_ends()
	_test_nothing_is_drawn_where_you_cannot_see()
	_test_steps_glide_and_settle()
	_test_creature_marks()
	_test_magic_weapons_spark()
	_test_a_kill_shatters()
	_test_blows_rock_within_the_tile()
	_test_hurt_reddens_the_edge()
	_test_still_keeps_only_information()
	_test_every_impact_ends()
	_test_light_knows_whose_it_is()
	_test_light_moves_only_when_asked()
	_test_shaders_read_what_light_writes()
	_test_memory_fades_but_keeps_landmarks()
	_test_the_trader_is_remembered()
	_test_magic_glows_and_embers_keep_their_rules()
	_test_regions_colour_the_stone_not_the_floor()
	_test_heavy_ground_slows_the_step()
	_test_footfalls_throw_up_the_ground()
	_test_small_life()
	_test_the_trader_idles()
	_test_fft_keys_walk_the_grid()
	_test_the_camera_turns_on_stick_or_triggers()
	_test_the_pad_watch()
	_test_the_camera_reads_reported_axes()
	await _test_the_title_screen()
	_test_the_playtest_fixes()
	await _test_davids_music()
	_test_reach_is_drawn()
	_test_bodies_look_the_same_in_both_views()
	_test_facing_and_the_follow_view()
	_test_new_players_start_in_3d()
	_test_the_gem_hint_asks_the_right_host()
	await _test_both_views_share_one_moment()
	var settings_after := ""
	if FileAccess.file_exists("user://settings.cfg"):
		settings_after = FileAccess.get_file_as_string("user://settings.cfg")
	check("the player's settings.cfg is untouched",
		settings_after == settings_before or not had_settings)
	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func check(name: String, condition: bool, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("  ok    %s" % name)
	else:
		_failed += 1
		print("  FAIL  %s   %s" % [name, detail])

## Effects mode is a static; set it for a moment WITHOUT Effects.set_mode(),
## which would write the player's settings file.
func _with_mode(mode: int, body: Callable) -> void:
	var was := Effects._mode
	Effects._mode = mode
	body.call()
	Effects._mode = was

func _open_map(w: int, h: int) -> DungeonMap:
	var map := DungeonMap.new(w, h)
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			map.set_tile(x, y, Tiles.FLOOR)
	map.set_all_visible()
	return map

func _types(fx: Fx) -> Array:
	var out: Array = []
	for e in fx.list:
		out.append(e["type"])
	return out

func _test_hits_become_effects() -> void:
	var fx := Fx.new()
	fx.add_events([{"kind": &"melee", "from": Vector2i(2, 2), "to": Vector2i(3, 2),
		"amount": 5, "on_player": false}], 16)
	check("a melee hit becomes a flash and a number",
		_types(fx) == [&"flash", &"popup"] and fx.list[1]["text"] == "5", str(_types(fx)))

	fx.clear()
	fx.add_events([{"kind": &"ranged", "from": Vector2i(1, 1), "to": Vector2i(6, 1),
		"amount": 2, "on_player": true}], 16)
	var shot: Dictionary = fx.list[0]
	var wait := float(shot["path"].size()) * Fx.SHOT_PER_CELL
	check("a ranged hit lands when its shot arrives, not before",
		shot["type"] == &"shot" and is_equal_approx(-float(fx.list[1]["t"]), wait))

	fx.clear()
	fx.add_events([{"kind": &"levelup", "to": Vector2i(4, 4)}], 16)
	check("levelling up says so over your head", fx.list.size() == 1
		and fx.list[0]["text"] == "LEVEL UP")

func _test_effects_answer_to_the_motion_setting() -> void:
	var noise := [{"kind": &"noise", "to": Vector2i(5, 5), "radius": 4}]
	var still := Fx.new()
	_with_mode(Effects.Mode.NONE, func(): still.add_events(noise, 16))
	var full := Fx.new()
	_with_mode(Effects.Mode.SHADERS, func(): full.add_events(noise, 16))
	check("a noise ring moves, so 'still' does not draw one",
		still.list.is_empty() and _types(full) == [&"ring"])

func _test_every_effect_ends() -> void:
	# Fx.expired's fallthrough is "expired", so an effect it was never taught
	# about dies on its first frame. Every kind the events can make must end,
	# and must not end at birth.
	var fx := Fx.new()
	var evts := [
		{"kind": &"melee", "from": Vector2i(2, 2), "to": Vector2i(3, 2), "amount": 1, "on_player": true},
		{"kind": &"ranged", "from": Vector2i(1, 1), "to": Vector2i(6, 1), "amount": 1, "on_player": false},
		{"kind": &"noise", "to": Vector2i(5, 5), "radius": 3},
		{"kind": &"recall", "from": Vector2i(1, 5), "to": Vector2i(6, 5)},
		{"kind": &"shove", "from": Vector2i(2, 6), "to": Vector2i(4, 6)},
		{"kind": &"notice", "to": Vector2i(3, 3)},
		{"kind": &"levelup", "to": Vector2i(3, 3)},
	]
	_with_mode(Effects.Mode.SHADERS, func(): fx.add_events(evts, 16))
	var bad: Array = []
	for e in fx.list:
		var born: Dictionary = e.duplicate()
		born["t"] = 0.0
		var old: Dictionary = e.duplicate()
		old["t"] = 1000.0
		if Fx.expired(born) or not Fx.expired(old):
			bad.append(e["type"])
	check("every effect lives, then ends (%d kinds made)" % fx.list.size(),
		bad.is_empty() and fx.list.size() >= 8, str(bad))

func _test_nothing_is_drawn_where_you_cannot_see() -> void:
	var map := _open_map(12, 12)
	var hidden := Vector2i(8, 6)
	map.visible_now[map.idx(hidden.x, hidden.y)] = 0
	# Radius 3 over 0.6s: at 0.4s the wavefront is two cells out -- exactly
	# where the hidden cell is -- and still visible.
	var ring := {"type": &"ring", "cell": Vector2i(6, 6), "t": 0.0, "radius": 3, "life": 0.6}
	var cells: Array = []
	for hit in Fx.ring_cells(ring, 0.4, map):
		cells.append(hit[0])
	check("a noise ring skips the cell you cannot see",
		not cells.is_empty() and not cells.has(hidden), str(cells))
	var flash := {"type": &"flash", "cell": hidden, "t": 0.0, "colour": Color.RED}
	var popup := {"type": &"popup", "cell": hidden, "t": 0.0, "text": "3", "colour": Color.RED}
	check("no flash and no number over unseen ground",
		Fx.flash_alpha(flash, 0.0, map) == 0.0 and float(Fx.popup_state(popup, 0.0, map)[1]) == 0.0)
	# And both DO show on ground you can see -- or the check above passes for a
	# flash that never shows anywhere. (Hardened when merged, 2026-09-28.)
	var seen := Vector2i(6, 6)
	var flash_seen := {"type": &"flash", "cell": seen, "t": 0.0, "colour": Color.RED}
	var popup_seen := {"type": &"popup", "cell": seen, "t": 0.0, "text": "3", "colour": Color.RED}
	check("  while both show on ground you can see",
		Fx.flash_alpha(flash_seen, 0.0, map) > 0.0
		and float(Fx.popup_state(popup_seen, 0.0, map)[1]) > 0.0)
	var shot := {"type": &"shot", "path": [Vector2i(6, 6), Vector2i(7, 6), hidden], "t": 0.0}
	check("a shot vanishes while it crosses unseen ground",
		Fx.shot_cell(shot, 0.0, map) == Vector2i(6, 6)
		and Fx.shot_cell(shot, 2.5 * Fx.SHOT_PER_CELL, map) == Vector2i(-1, -1))

func _test_steps_glide_and_settle() -> void:
	var gs := GameState.new(1)
	gs.new_game()
	var motion := StepMotion.new()
	motion.sync(gs.entities)
	var p := gs.player
	var from := Vector2(p.x, p.y)
	p.x += 1
	motion.sync(gs.entities)
	motion.tick(StepMotion.STEP_TIME * 0.5)
	var mid := motion.visual_cell(p)
	check("a step is drawn part way while it glides",
		motion.running() and mid.x > from.x and mid.x < from.x + 1.0, str(mid))
	motion.settle()
	check("settling lands it at once, so input never waits on a picture",
		not motion.running() and motion.visual_cell(p) == Vector2(p.x, p.y))

func _test_creature_marks() -> void:
	var m := Entity.new("orc", &"orc", 1, 1)
	m.max_hp = 20
	m.hp = 20
	m.alertness = Entity.Alert.SUSPICIOUS
	check("a suspicious creature shows a ?", CreatureMarks.awareness(m).get("text") == "?")
	m.alertness = Entity.Alert.AWAKE
	m.fleeing = true
	check("a fleeing one shows <<", CreatureMarks.awareness(m).get("text") == "<<")
	check("a whole one has no wash", CreatureMarks.wound(m).a == 0.0)
	m.hp = 2
	check("a badly hurt one has the critical wash",
		CreatureMarks.wound(m).is_equal_approx(Color(Palette.CRITICAL, Palette.CRITICAL_WASH)))

## A game with the player at a known spot and a monster beside it.
func _arena() -> Array:
	var gs := GameState.new(1)
	gs.new_game()
	var p := Vector2i(gs.player.x, gs.player.y)
	var spot := p
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if gs.map.is_walkable(p.x + d.x, p.y + d.y):
			spot = p + d
			break
	var orc: Entity = null
	for row in GameState.BESTIARY:
		if row["name"] == "orc":
			orc = GameState.monster_from(row, spot.x, spot.y)
			gs.entities.append(orc)
	return [gs, orc]

func _swing(gs: GameState, orc: Entity, fx: Fx, motion: StepMotion, amount := 3) -> void:
	fx.play([{"kind": &"melee", "from": Vector2i(gs.player.x, gs.player.y),
		"to": Vector2i(orc.x, orc.y), "amount": amount, "on_player": false}], 16, gs, motion)

func _test_magic_weapons_spark() -> void:
	var arena := _arena()
	var gs: GameState = arena[0]
	var orc: Entity = arena[1]
	var blade := Item.make(&"dagger")
	gs.player.equipped[Item.Slot.WEAPON] = blade
	var plain := Fx.new()
	_with_mode(Effects.Mode.SHADERS, func(): _swing(gs, orc, plain, StepMotion.new()))
	blade.element = &"fire"
	var magic := Fx.new()
	_with_mode(Effects.Mode.SHADERS, func(): _swing(gs, orc, magic, StepMotion.new()))
	var sparks: Array = magic.list.filter(func(e): return e["type"] == &"sparks")
	check("a magic weapon throws sparks in the magic colour; a plain one does not",
		not _types(plain).has(&"sparks") and sparks.size() == 1
		and sparks[0]["colour"] == Palette.MAGIC)

func _test_a_kill_shatters() -> void:
	var arena := _arena()
	var gs: GameState = arena[0]
	var orc: Entity = arena[1]
	orc.alive = false
	var fx := Fx.new()
	_with_mode(Effects.Mode.SHADERS, func(): fx.play([{"kind": &"kill",
		"to": Vector2i(orc.x, orc.y)}], 16, gs, StepMotion.new()))
	var shatter: Array = fx.list.filter(func(e): return e["type"] == &"shatter")
	check("a kill shatters what died, in its own picture",
		shatter.size() == 1 and shatter[0]["appearance"] == &"orc")

func _test_blows_rock_within_the_tile() -> void:
	var arena := _arena()
	var gs: GameState = arena[0]
	var orc: Entity = arena[1]
	orc.max_hp = 20
	var motion := StepMotion.new()
	var fx := Fx.new()
	_with_mode(Effects.Mode.SHADERS, func(): _swing(gs, orc, fx, motion, 2))
	motion.tick(StepMotion.LUNGE_TIME * 0.5)
	var lunge := motion.nudge_offset(gs.player).length()
	check("a swing lunges toward the target, and not a whole step (%.2f)" % lunge,
		lunge > 0.1 and lunge <= 0.34)
	var light := StepMotion.new()
	var heavy := StepMotion.new()
	_with_mode(Effects.Mode.SHADERS, func():
		_swing(gs, orc, Fx.new(), light, 1)
		_swing(gs, orc, Fx.new(), heavy, 9))
	for m in [light, heavy]:
		m.tick(StepMotion.LUNGE_TIME * 0.4 + StepMotion.RECOIL_TIME * 0.5)
	var small := light.nudge_offset(orc).length()
	var big := heavy.nudge_offset(orc).length()
	check("a harder blow rocks the target further, still inside its tile (%.2f < %.2f)"
		% [small, big], small < big and big <= 0.25)
	motion.settle()
	check("settling cancels a lunge at once", motion.nudge_offset(gs.player) == Vector2.ZERO)

func _test_hurt_reddens_the_edge() -> void:
	var arena := _arena()
	var gs: GameState = arena[0]
	var orc: Entity = arena[1]
	gs.player.max_hp = 20
	var levels: Array = []
	for amount in [1, 8]:
		var fx := Fx.new()
		fx.play([{"kind": &"melee", "from": Vector2i(orc.x, orc.y),
			"to": Vector2i(gs.player.x, gs.player.y), "amount": amount,
			"on_player": true}], 16, gs, null)
		levels.append(Fx.hurt_now(fx.list))
	check("being hurt reddens the edge, and a harder hit more (%.2f < %.2f)"
		% [levels[0], levels[1]], levels[0] > 0.0 and levels[0] < levels[1])

## On "still" nothing moves -- but what is information stays: the number, the
## flash and the red edge still say you were hit.
func _test_still_keeps_only_information() -> void:
	var arena := _arena()
	var gs: GameState = arena[0]
	var orc: Entity = arena[1]
	var blade := Item.make(&"dagger")
	blade.element = &"fire"
	gs.player.equipped[Item.Slot.WEAPON] = blade
	var fx := Fx.new()
	var motion := StepMotion.new()
	_with_mode(Effects.Mode.NONE, func():
		_swing(gs, orc, fx, motion)
		fx.play([{"kind": &"melee", "from": Vector2i(orc.x, orc.y),
			"to": Vector2i(gs.player.x, gs.player.y), "amount": 2,
			"on_player": true}, {"kind": &"levelup",
			"to": Vector2i(gs.player.x, gs.player.y)}], 16, gs, motion))
	var kinds := _types(fx)
	check("on 'still': no lunge, no sparks, no ring of light -- but the number, "
		+ "the flash and the red edge remain",
		not motion.running() and not kinds.has(&"sparks") and not kinds.has(&"ring")
		and kinds.has(&"popup") and kinds.has(&"flash") and kinds.has(&"hurt"), str(kinds))

func _test_every_impact_ends() -> void:
	var arena := _arena()
	var gs: GameState = arena[0]
	var orc: Entity = arena[1]
	var here := Vector2i(gs.player.x, gs.player.y)
	orc.alive = false
	var fx := Fx.new()
	_with_mode(Effects.Mode.SHADERS, func(): fx.play([
		{"kind": &"kill", "to": Vector2i(orc.x, orc.y)},
		{"kind": &"levelup", "to": here},
		{"kind": &"pray", "to": here},
		{"kind": &"forge", "to": here},
		{"kind": &"trap", "to": here},
		{"kind": &"blink", "from": here, "to": Vector2i(orc.x, orc.y)},
		{"kind": &"lowhp", "to": here},
	], 16, gs, StepMotion.new()))
	var bad: Array = []
	for e in fx.list:
		var born: Dictionary = e.duplicate()
		born["t"] = 0.0
		var old: Dictionary = e.duplicate()
		old["t"] = 1000.0
		if Fx.expired(born) or not Fx.expired(old):
			bad.append(e["type"])
	var kinds := _types(fx)
	check("every impact lives, then ends (%s)" % str(kinds),
		bad.is_empty() and kinds.has(&"shatter") and kinds.has(&"sparks")
		and kinds.has(&"hurt") and kinds.has(&"ring"), str(bad))

## The whole point of the layer: the real scene hands both views one list and
## one set of glides, and the 3D view draws what the list holds.
## A floor with a torch at the west end, a brazier in the middle, fungus at the
## east end out of reach of both, and a second fungus inside the brazier's
## light: [state, light].
func _lit_room() -> Array:
	var gs := GameState.new(1)
	gs.new_game()
	gs.map = _open_map(32, 11)
	gs.player.x = 3
	gs.player.y = 5
	gs.player.light.x = 3
	gs.player.light.y = 5
	gs.player.light.radius = 6
	gs.static_lights = [
		LightSource.new(14, 5, 5, Color(0.9, 0.5, 0.2), Color(0.3, 0.2, 0.3), 0.85, true),
		LightSource.new(26, 5, 3, Color(0.3, 0.8, 0.6), Color(0.1, 0.3, 0.2), 0.45, false),
		LightSource.new(16, 5, 3, Color(0.3, 0.8, 0.6), Color(0.1, 0.3, 0.2), 0.45, false),
	]
	var light := LivingLight.new()
	light.rebuild(gs)
	return [gs, light]

func _test_light_knows_whose_it_is() -> void:
	var made := _lit_room()
	var gs: GameState = made[0]
	var light: LivingLight = made[1]
	check("the torch is a flame (so the rest of this means something)",
		gs.player.light.flickers)
	check("ground under the torch has a flame's phase", light.fire_phase(4, 5) >= 0.0)
	check("and so does ground under the brazier", light.fire_phase(14, 7) >= 0.0)
	check("the torch and the brazier do not share a rhythm",
		not is_equal_approx(light.fire_phase(4, 5), light.fire_phase(14, 7)))
	check("fungus light out of the fire's reach breathes, and does not flicker",
		light.breath_phase(26, 6) >= 0.0 and light.fire_phase(26, 6) < 0.0)
	check("fungus light inside the fire's reach does not breathe -- the flame has it",
		light.breath_phase(16, 5) < 0.0 and light.fire_phase(16, 5) >= 0.0)
	check("ground nothing reaches has neither",
		light.fire_phase(21, 1) < 0.0 and light.breath_phase(21, 1) < 0.0)

func _test_light_moves_only_when_asked() -> void:
	var light: LivingLight = _lit_room()[1]
	var lo := 9.0
	var hi := -9.0
	var dark_moved := false
	for i in 40:
		light._t = float(i) * 0.37
		var p := light.pulse(26, 6)
		lo = minf(lo, p)
		hi = maxf(hi, p)
		dark_moved = dark_moved or light.pulse(21, 1) != 1.0
	check("fungus light breathes, within its depth (%.2f..%.2f)" % [lo, hi],
		hi - lo > LivingLight.BREATH_DEPTH
		and lo >= 1.0 - LivingLight.BREATH_DEPTH - 0.001
		and hi <= 1.0 + LivingLight.BREATH_DEPTH + 0.001)
	check("ground nothing reaches never moves", not dark_moved)
	# Classic animates on the CPU on "simple" only: the shader has "full",
	# and "still" is still.
	var grid := GlyphGrid.new()
	grid.light = light
	light._t = 1.0
	var by_mode := {}
	for mode in [Effects.Mode.NONE, Effects.Mode.TIMERS, Effects.Mode.SHADERS]:
		_with_mode(mode, func(): by_mode[mode] = grid._flicker_at(26, 6))
	check("classic breathes on the CPU on simple, and only there",
		by_mode[Effects.Mode.NONE] == 1.0 and by_mode[Effects.Mode.SHADERS] == 1.0
		and by_mode[Effects.Mode.TIMERS] == light.pulse(26, 6)
		and by_mode[Effects.Mode.TIMERS] != 1.0, str(by_mode))
	grid.free()

func _test_shaders_read_what_light_writes() -> void:
	var made := _lit_room()
	var gs: GameState = made[0]
	var light: LivingLight = made[1]
	var memory := MapMemory.new()
	light.upload(gs, memory)
	# The images LivingLight hands the textures: a headless run keeps no pixels
	# in a texture to read back.
	var cells := light._cells_img
	var extra := light._extra_img
	var fire_back := (cells.get_pixel(4, 5).b * 255.0 - 1.0) / 253.0 * TAU
	check("the firelight phase survives the trip to the shader",
		absf(fire_back - light.fire_phase(4, 5)) <= TAU / 253.0 + 0.001,
		"%f vs %f" % [fire_back, light.fire_phase(4, 5)])
	check("no flame reads as zero, and a phase of zero does not",
		cells.get_pixel(21, 1).b == 0.0 and LivingLight.phase_code(0.0) > 0)
	# The bytes are written directly; they must be exactly what the Color path
	# the classic shader was tuned against wrote.
	var same := true
	var reference := Image.create(gs.map.width, gs.map.height, false, Image.FORMAT_RGBA8)
	for y in gs.map.height:
		for x in gs.map.width:
			var ph := light.fire_phase(x, y)
			reference.set_pixel(x, y, Color(float(gs.map.get_tile(x, y)) / 255.0,
				LivingLight.hash01(x, y),
				(floor(ph / TAU * 253.0) + 1.0) / 255.0 if ph >= 0.0 else 0.0,
				1.0 if gs.map.is_visible(x, y) else 0.0))
	check("the fast upload writes exactly the bytes the Color path did",
		reference.get_data() == cells.get_data())
	check("the breath phase goes in the second texture",
		extra.get_pixel(26, 6).r > 0.0 and extra.get_pixel(4, 5).r == 0.0)
	check("tile, hash and sight are where the classic shader always read them",
		is_equal_approx(cells.get_pixel(4, 5).r * 255.0, float(Tiles.FLOOR))
		and absf(cells.get_pixel(4, 5).g - LivingLight.hash01(4, 5)) <= 1.0 / 255.0
		and cells.get_pixel(4, 5).a == 1.0)
	# A new turn is a fresh upload: the tile changes, and so does the texture.
	gs.map.set_tile(8, 8, Tiles.WATER)
	gs.turns += 1
	light.upload(gs, memory)
	check("a new turn reaches the shader",
		is_equal_approx(light._cells_img.get_pixel(8, 8).r * 255.0, float(Tiles.WATER)))
	# The two halves of the maths must agree on the numbers they share.
	var inc := FileAccess.get_file_as_string("res://src/render/shaders/breathe.gdshaderinc")
	var want := {"BREATH_DEPTH": LivingLight.BREATH_DEPTH, "BREATH_RATE": LivingLight.BREATH_RATE}
	var agree := true
	for name: String in want:
		var found := RegEx.create_from_string("const float %s = ([0-9.]+);" % name).search(inc)
		agree = agree and found != null \
			and is_equal_approx(float(found.get_string(1)), float(want[name]))
	check("the shader include and LivingLight agree on how fungus breathes", agree)

func _test_memory_fades_but_keeps_landmarks() -> void:
	check("memory holds, then fades to half, never below",
		MapMemory.fade_for_age(0) == 1.0 and MapMemory.fade_for_age(MapMemory.FADE_AFTER) == 1.0
		and MapMemory.fade_for_age(MapMemory.FADE_FULL) == MapMemory.FADE_FLOOR
		and MapMemory.fade_for_age(100000) == MapMemory.FADE_FLOOR
		and MapMemory.FADE_FLOOR == 0.5)
	var steady := true
	for age in range(0, 1000, 10):
		steady = steady and MapMemory.fade_for_age(age + 10) <= MapMemory.fade_for_age(age)
	check("and never brightens again as it ages", steady)
	var gs := GameState.new(1)
	gs.new_game()
	gs.map = _open_map(12, 8)
	var marks := {Vector2i(2, 2): Tiles.DOOR_CLOSED, Vector2i(3, 2): Tiles.STAIRS_DOWN,
		Vector2i(4, 2): Tiles.BRAZIER, Vector2i(5, 2): Tiles.SHRINE,
		Vector2i(6, 2): Tiles.BRAZIER_DEAD, Vector2i(7, 2): Tiles.STAIRS_UP}
	for at: Vector2i in marks:
		gs.map.set_tile(at.x, at.y, marks[at])
	gs.trader = null
	var memory := MapMemory.new()
	gs.turns = 0
	memory.update(gs)
	gs.map.remember_visible()
	gs.map.clear_visible()
	gs.turns = 600
	memory.update(gs)
	check("ground unseen for 600 turns is at half",
		memory.fade(8, 5, gs.turns) == 0.5, str(memory.fade(8, 5, gs.turns)))
	var kept := true
	for at: Vector2i in marks:
		kept = kept and memory.fade(at.x, at.y, gs.turns) == 1.0
	check("doors, stairs, braziers and shrines never fade", kept)
	var fades := memory.fades(gs.turns)
	var same := true
	for y in gs.map.height:
		for x in gs.map.width:
			same = same and fades[y * gs.map.width + x] == memory.fade(x, y, gs.turns)
	check("the whole-floor fades agree with the one-cell fade", same)
	# Sight changes with a turn, as in play.
	gs.turns = 610
	gs.map.set_all_visible()
	memory.update(gs)
	gs.map.clear_visible()
	gs.turns = 650
	memory.update(gs)
	check("seeing it again brings it back", memory.fade(8, 5, gs.turns) == 1.0)
	gs.map = _open_map(12, 8)
	gs.turns = 5000
	memory.update(gs)
	gs.map.reveal_all()
	gs.map.clear_visible()
	gs.turns = 5001
	memory.update(gs)
	check("a new floor starts remembered afresh", memory.fade(8, 5, gs.turns) == 1.0)

func _test_the_trader_is_remembered() -> void:
	var gs := GameState.new(1)
	gs.new_game()
	gs.map = _open_map(12, 8)
	gs.map.clear_visible()
	gs.trader = Entity.new("trader", &"trader", 7, 5)
	check("a trader on ground you never saw is not remembered",
		MapMemory.remembered_trader(gs) == Vector2i(-1, -1))
	gs.map.reveal_all()
	check("once you have seen their ground, you know where they stand",
		MapMemory.remembered_trader(gs) == Vector2i(7, 5))
	var memory := MapMemory.new()
	memory.update(gs)
	gs.turns = 900
	memory.update(gs)
	check("and they are a landmark: their cell never fades",
		memory.trader_cell == Vector2i(7, 5) and memory.fade(7, 5, gs.turns) == 1.0
		and memory.fade(8, 5, gs.turns) < 1.0)
	gs.trader.alive = false
	var dead := MapMemory.remembered_trader(gs)
	gs.trader = null
	check("no trader, or none left, is nothing to remember",
		dead == Vector2i(-1, -1) and MapMemory.remembered_trader(gs) == Vector2i(-1, -1))
	var on_map := false
	for row in MapPanel.MARKS:
		on_map = on_map or (row[0] == "trader" and row[1] == MapPanel.MARK_TRADER)
	check("the overview map has a mark for the trader", on_map)

func _test_magic_glows_and_embers_keep_their_rules() -> void:
	var enchanted := Item.make(&"dagger")
	enchanted.element = &"frost"
	var plain := Item.make(&"dagger")
	var gem: Item = null
	for id in Item.CATALOGUE:
		if Item.CATALOGUE[id].get("kind", -1) == Item.Kind.GEM:
			gem = Item.make(id)
			break
	var glows := {}
	_with_mode(Effects.Mode.NONE, func():
		glows["magic"] = LivingLight.item_glow(enchanted)
		glows["gem"] = LivingLight.item_glow(gem)
		glows["plain"] = LivingLight.item_glow(plain))
	check("magic and gems glow blue; a plain blade does not",
		glows["magic"].a > 0.0 and glows["gem"].a > 0.0 and glows["plain"].a == 0.0
		and Color(glows["magic"], 1.0) == Palette.MAGIC and Color(glows["gem"], 1.0) == Palette.MAGIC)
	check("with motion off the glow is steady, not gone",
		is_equal_approx(glows["magic"].a, LivingLight.ITEM_GLOW))
	check("a gem keeps its own colour: the glow goes under it, not on it",
		not gem.shows_enchanted())
	# Lambdas capture locals by value, so results come back in a dictionary.
	var got := {"lo": 9.0}
	_with_mode(Effects.Mode.SHADERS, func():
		got["lo"] = LivingLight.item_glow(enchanted).a)
	check("and breathes, never fading out, with motion on",
		got["lo"] >= LivingLight.ITEM_GLOW * 0.75 - 0.001
		and got["lo"] <= LivingLight.ITEM_GLOW + 0.001)
	var cold := Color(0.4, 0.3, 0.3)
	_with_mode(Effects.Mode.NONE, func():
		got["hot"] = LivingLight.embers(cold, 1.0, 3, 3)
		got["stairs"] = LivingLight.stairs_pulse())
	var want := (cold.lerp(Palette.EMBERS, 1.0) * (1.0 + LivingLight.EMBER_GLOW)).clamp()
	check("a hot brazier's gauge is its colour and glow, held still with motion off",
		(got["hot"] as Color).is_equal_approx(Color(want, 1.0)))
	check("remembered stairs are frozen at the top of their breath with motion off",
		got["stairs"] == 1.0)

## A floor with a strip of each kind of ground: [state, where each is].
func _ground_room() -> Array:
	var gs := GameState.new(1)
	gs.new_game()
	gs.map = _open_map(40, 16)
	var at := {"water": Vector2i(5, 4), "mud": Vector2i(6, 4), "rubble": Vector2i(7, 4),
		"floor": Vector2i(8, 4), "fungus": Vector2i(12, 8), "mud2": Vector2i(14, 8)}
	gs.map.set_tile(5, 4, Tiles.WATER)
	gs.map.set_tile(6, 4, Tiles.MUD)
	gs.map.set_tile(7, 4, Tiles.RUBBLE)
	gs.map.set_tile(12, 8, Tiles.FUNGUS)
	gs.map.set_tile(14, 8, Tiles.MUD)
	gs.player.x = 13
	gs.player.y = 9
	gs.player.light.radius = 6
	gs.light_map = LightMap.new(40, 16)
	# Lit everywhere, so what is being tested is small life and not the light.
	var lit := PackedColorArray()
	lit.resize(40 * 16)
	lit.fill(Color(0.8, 0.7, 0.5))
	gs.light_map.values = lit
	return [gs, at]

func _test_heavy_ground_slows_the_step() -> void:
	var map := _open_map(12, 8)
	map.set_tile(5, 4, Tiles.MUD)
	map.set_tile(6, 4, Tiles.WATER)
	var e := Entity.new("walker", &"rat", 4, 4)
	var motion := StepMotion.new()
	var got := {}
	_with_mode(Effects.Mode.TIMERS, func():
		motion.sync([e], map)
		got["none"] = motion.sync([e], map)
		e.x = 5
		got["moved"] = motion.sync([e], map)
		got["mud"] = float(motion._motion[e]["life"])
		motion.tick(StepMotion.STEP_TIME * 1.2)
		got["still going"] = motion.running()
		motion.tick(StepMotion.STEP_TIME)
		got["landed"] = not motion.running() and motion.visual_cell(e) == Vector2(5, 4)
		e.x = 6
		motion.sync([e], map)
		got["water"] = float(motion._motion[e]["life"])
		motion.settle()
		got["settled"] = not motion.running()
		e.x = 7
		motion.sync([e], map)
		got["floor"] = float(motion._motion[e]["life"]))
	check("sync says who moved, and only who moved",
		got["none"].is_empty() and got["moved"] == [e])
	check("a step into mud glides twice as long, into water 1.4 times, as the sim charges",
		is_equal_approx(got["mud"], StepMotion.STEP_TIME * Tiles.move_cost(Tiles.MUD))
		and is_equal_approx(got["water"], StepMotion.STEP_TIME * Tiles.move_cost(Tiles.WATER))
		and is_equal_approx(got["floor"], StepMotion.STEP_TIME), str(got))
	check("so it is still wading after a stride's time, and lands after its own",
		got["still going"] and got["landed"])
	check("and the next key still settles it at once", got["settled"])
	e.x = 4
	motion.settle()
	motion.sync([e], map)
	e.x = 5
	_with_mode(Effects.Mode.NONE, func(): motion.sync([e], map))
	check("with motion off, mud is an ordinary stride",
		is_equal_approx(float(motion._motion[e]["life"]), StepMotion.STEP_TIME))

func _test_footfalls_throw_up_the_ground() -> void:
	var made := _ground_room()
	var gs: GameState = made[0]
	var at: Dictionary = made[1]
	var walkers := []
	for k in ["water", "mud", "rubble", "floor"]:
		walkers.append(Entity.new(k, &"rat", at[k].x, at[k].y))
	var fx := Fx.new()
	_with_mode(Effects.Mode.TIMERS, func(): fx.footfalls(walkers, gs))
	var by_cell := {}
	for e in fx.list:
		by_cell[e["cell"]] = e
	check("water splashes, mud squelches, rubble puffs dust -- and floor does nothing",
		fx.list.size() == 3 and by_cell.has(at["water"]) and by_cell.has(at["mud"])
		and by_cell.has(at["rubble"]) and not by_cell.has(at["floor"]), str(_types(fx)))
	var water: Dictionary = by_cell.get(at["water"], {})
	check("in the ground's own paler colour",
		water.get("colour", Color()) == Fx.FOOTFALL[Tiles.WATER]["colour"])
	var low := true
	for piece in Fx.burst_points(water, 0.02, gs.map):
		low = low and float(piece[1]) < 0.15
	check("from the feet, not the middle of the cell", low and not water.is_empty())
	check("landing as the step lands", float(water.get("t", 0.0)) < 0.0)
	water["t"] = float(water["life"])
	check("and every footfall ends", Fx.expired(water))
	var quiet := Fx.new()
	_with_mode(Effects.Mode.NONE, func(): quiet.footfalls(walkers, gs))
	gs.map.clear_visible()
	var unseen := Fx.new()
	_with_mode(Effects.Mode.TIMERS, func(): unseen.footfalls(walkers, gs))
	check("nothing on still, and nothing where you cannot see",
		quiet.list.is_empty() and unseen.list.is_empty())

func _test_small_life() -> void:
	var made := _ground_room()
	var gs: GameState = made[0]
	var at: Dictionary = made[1]
	gs.depth = 1
	var life := SmallLife.new()
	life.rebuild(gs)
	var got := {}
	_with_mode(Effects.Mode.SHADERS, func():
		var spores := 0
		var bubbles := 0
		for i in 60:
			for m in life.motes(float(i) * 0.13):
				var cell := Vector2i(floori(m[0].x), floori(m[0].y))
				if (cell - at["fungus"]).length() <= 1.0 and float(m[1]) > 0.1:
					spores += 1
				if cell == at["mud"] or cell == at["mud2"]:
					bubbles += 1
		got["spores"] = spores
		got["bubbles"] = bubbles
		got["same"] = str(life.motes(4.2)) == str(life.motes(4.2)))
	check("on full, fungus drifts spores and mud bubbles (%d, %d)"
		% [got["spores"], got["bubbles"]], got["spores"] > 0 and got["bubbles"] > 0)
	check("and the same moment is the same motes, in either view", got["same"])
	_with_mode(Effects.Mode.TIMERS, func(): got["simple"] = life.motes(1.0).size())
	_with_mode(Effects.Mode.NONE, func(): got["still"] = life.motes(1.0).size())
	check("small life is only on full: none on simple or still",
		got["simple"] == 0 and got["still"] == 0)
	var lit_ok := true
	for c in life._dust:
		var d := c - Vector2i(gs.player.x, gs.player.y)
		lit_ok = lit_ok and d.length_squared() <= gs.player.light.radius * gs.player.light.radius
	check("dust hangs only in your light", lit_ok and not life._dust.is_empty())
	check("and nothing drips outside the caves", life._drips.is_empty())
	var caves := _ground_room()[0] as GameState
	caves.depth = 5
	for y in range(1, 15):
		for x in range(1, 39):
			if caves.map.get_tile(x, y) == Tiles.FLOOR:
				caves.map.set_tile(x, y, Tiles.CAVE_FLOOR)
	var cave_life := SmallLife.new()
	cave_life.rebuild(caves)
	check("but in them, a few cells drip", not cave_life._drips.is_empty()
		and cave_life._drips.size() <= SmallLife.MAX_DRIPS)
	# Hide all but the fungus: nothing may be drawn over what you cannot see.
	gs.map.clear_visible()
	life.rebuild(gs)
	var shown := {}
	_with_mode(Effects.Mode.SHADERS, func(): shown["n"] = life.motes(2.0).size())
	check("nothing is drawn where you cannot see", shown["n"] == 0)

## The trader idling (SmallLife.idle_offset): shifting about on "full" only,
## the same at the same moment, leaning towards you when you are near, and
## never out of their cell.
func _test_the_trader_idles() -> void:
	var gs: GameState = _ground_room()[0]
	var trader := Entity.new("trader", &"trader", 20, 8)
	gs.trader = trader
	var life := SmallLife.new()
	life.rebuild(gs)
	# A step to the east of them, and well out of their notice.
	var near := Vector2(21, 8)
	var far := Vector2(35, 8)
	var got := {}
	for mode in [Effects.Mode.NONE, Effects.Mode.TIMERS, Effects.Mode.SHADERS]:
		_with_mode(mode, func(): got[mode] = life.idle_offset(trader, near, 1.7))
	check("the trader idles on full only",
		got[Effects.Mode.NONE] == Vector2.ZERO and got[Effects.Mode.TIMERS] == Vector2.ZERO
		and got[Effects.Mode.SHADERS] != Vector2.ZERO, str(got))
	var other := Entity.new("rat", &"rat", 10, 8)
	_with_mode(Effects.Mode.SHADERS, func():
		got["other"] = life.idle_offset(other, near, 1.7)
		got["same"] = life.idle_offset(trader, near, 2.9) == life.idle_offset(trader, near, 2.9)
		got["moves"] = life.idle_offset(trader, far, 0.0) != life.idle_offset(trader, far, 1.0)
		# The lean is what being near adds, at the same moment.
		got["east"] = life.idle_offset(trader, near, 3.3) - life.idle_offset(trader, far, 3.3)
		got["north"] = life.idle_offset(trader, Vector2(20, 5), 3.3) \
			- life.idle_offset(trader, far, 3.3)
		var most := 0.0
		for i in 200:
			most = maxf(most, life.idle_offset(trader, near, float(i) * 0.37).length())
		got["most"] = most)
	check("nobody else does", got["other"] == Vector2.ZERO)
	check("the same moment is the same pose, in either view, and it shifts about",
		got["same"] and got["moves"])
	var east: Vector2 = got["east"]
	var north: Vector2 = got["north"]
	check("they lean towards you when you are near: east of them, and north",
		east.x > 0.1 and absf(east.y) < 0.001 and north.y < -0.05 and absf(north.x) < 0.001,
		"%s %s" % [east, north])
	check("and never leave their cell: at most %.2f of one" % got["most"],
		got["most"] <= 0.27)

## The camera's EIGHT views (45 degrees a press, Brad 2026-09-27): diamonds and
## straight-on views alternating. In a diamond view each arrow walks the grid
## line 45 degrees clockwise of it on screen (FFT's rule); in a straight view it
## walks exactly where it points. Either way opposite arrows go opposite ways,
## the four arrows cover the four grid lines, and diagonal keys walk diagonals.
func _test_fft_keys_walk_the_grid() -> void:
	var arrows := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var corners := [Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]
	var axes_ok := true
	var diamond_ok := true
	var straight_ok := true
	var diagonals_ok := true
	var diamonds := 0
	var straights := 0
	for view in DioramaView.VIEWS:
		var yaw := DioramaView.CAMERA_YAW + float(view) * DioramaView.TURN_STEP
		var is_diamond := view % 2 == 0
		if is_diamond:
			diamonds += 1
		else:
			straights += 1
		var seen := {}
		for k in arrows:
			var step := DioramaView.view_to_grid(k, yaw)
			seen[step] = true
			axes_ok = axes_ok and step in DioramaView.AXES \
				and DioramaView.view_to_grid(-k, yaw) == -step
			# How far the step turns from the key, on screen (y down: + is clockwise).
			var turn := Vector2(k).angle_to(DioramaView.grid_to_view(step, yaw))
			if is_diamond:
				diamond_ok = diamond_ok and absf(turn - PI / 4.0) < 0.01
			else:
				straight_ok = straight_ok and absf(turn) < 0.01
		axes_ok = axes_ok and seen.size() == 4
		var corner_seen := {}
		for k in corners:
			var step := DioramaView.view_to_grid(k, yaw)
			corner_seen[step] = true
			diagonals_ok = diagonals_ok and step in DioramaView.DIAGONALS
		diagonals_ok = diagonals_ok and corner_seen.size() == 4
	check("the premise: eight views, four diamonds and four straight (%d, %d)"
		% [diamonds, straights], DioramaView.VIEWS == 8 and diamonds == 4 and straights == 4)
	check("a turn is 45 degrees", is_equal_approx(DioramaView.TURN_STEP, PI / 4.0))
	check("each arrow walks a different grid line, and opposite arrows opposite ways",
		axes_ok)
	check("in a diamond view each shows 45 degrees clockwise of its arrow (FFT)", diamond_ok)
	check("in a straight view each walks exactly where it points", straight_ok)
	check("diagonal keys walk the grid's diagonals, in every view", diagonals_ok)
	check("from the first view, up walks north (up and to the right on screen)",
		DioramaView.view_to_grid(Vector2i(0, -1), DioramaView.CAMERA_YAW) == Vector2i(0, -1)
		and DioramaView.grid_to_view(Vector2i(0, -1), DioramaView.CAMERA_YAW).x > 0.0)

## The pad turns the camera with the right stick, or with the triggers -- which
## is also how Firefox delivers an Xbox Wireless pad's right stick (2026-09-28).
func _test_the_camera_turns_on_stick_or_triggers() -> void:
	check("the right stick turns it", DioramaView.turn_intent(0.9, 0.0, 0.0) > 0.75
		and DioramaView.turn_intent(-0.9, 0.0, 0.0) < -0.75)
	check("RT turns right and LT turns left", DioramaView.turn_intent(0.0, 0.0, 0.9) > 0.75
		and DioramaView.turn_intent(0.0, 0.9, 0.0) < -0.75)
	check("the stick wins over a resting trigger", DioramaView.turn_intent(-0.9, 0.0, 0.1) < -0.75)
	check("nothing pressed, nothing turns", absf(DioramaView.turn_intent(0.05, 0.1, 0.1)) < 0.30)
	# FIREFOX: the stick arrives as LT, resting at 0.5 (measured 2026-09-28).
	check("both triggers resting at 0.5 is recognised as Firefox's stick",
		DioramaView.looks_like_centred_triggers(0.5, 0.5))
	check("  but real triggers at rest are not",
		not DioramaView.looks_like_centred_triggers(0.0, 0.0)
		and not DioramaView.looks_like_centred_triggers(0.5, 0.0))
	check("in that case the stick at rest turns nothing",
		absf(DioramaView.turn_intent(0.0, 0.5, 0.5, true)) < 0.30)
	check("  stick right turns right, stick left turns left",
		DioramaView.turn_intent(0.0, 1.0, 0.5, true) > 0.75
		and DioramaView.turn_intent(0.0, 0.0, 0.5, true) < -0.75)
	check("  and the stick's up-down (on RT) turns nothing",
		absf(DioramaView.turn_intent(0.0, 0.5, 1.0, true)) < 0.30)
	# And in the second before it is recognised, that stick turns nothing: one
	# "trigger" moving while the other rests at 0.5 is not a trigger press.
	var early := true
	for lt_rt in [[1.0, 0.5], [0.0, 0.5], [0.5, 1.0], [0.5, 0.0], [0.5, 0.5]]:
		early = early and absf(DioramaView.turn_intent(0.0, lt_rt[0], lt_rt[1])) < 0.75
	check("  and before it is recognised, the stick turns nothing either way", early)

## The camera reads what the pad REPORTED, because in Firefox polling never
## sees the right stick (Brad's pad watch, 2026-09-28).
func _test_the_camera_reads_reported_axes() -> void:
	print("-- the camera reads the pad's reported axes")
	var g := Gamepad.new()
	check("  with no events, an axis reads as polled (0 in a headless run)",
		g.axis(JOY_AXIS_TRIGGER_RIGHT) == Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT))
	for v in [0.5, 1.0]:
		var e := InputEventJoypadMotion.new()
		e.device = 0
		e.axis = JOY_AXIS_TRIGGER_RIGHT
		e.axis_value = v
		g.track(e)
	check("  an event's value is what the camera reads",
		g.axis(JOY_AXIS_TRIGGER_RIGHT) == 1.0)
	var other := InputEventJoypadMotion.new()
	other.device = 1
	other.axis = JOY_AXIS_TRIGGER_LEFT
	other.axis_value = 1.0
	g.track(other)
	check("  a second pad's events do not steer the camera",
		g.axis(JOY_AXIS_TRIGGER_LEFT) == Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT))
	# End to end: Firefox's stick, recognised, turns the camera from events.
	var right := InputEventJoypadMotion.new()
	right.device = 0
	right.axis = JOY_AXIS_TRIGGER_LEFT
	right.axis_value = 1.0
	g.track(right)
	# Firefox writes a dead raw axis into the same slot every frame. Within a
	# frame the live value must win, whichever order they arrive in.
	var clash := Gamepad.new()
	for order in [[0.0, 1.0], [1.0, 0.0]]:
		for v in order:
			var ev := InputEventJoypadMotion.new()
			ev.device = 0
			ev.axis = JOY_AXIS_TRIGGER_LEFT
			ev.axis_value = v
			clash.track(ev, 100 if order[0] == 0.0 else 101)
		check("  the stick beats Firefox's dead axis in one frame (%s)" % str(order),
			clash.axis(JOY_AXIS_TRIGGER_LEFT) == 1.0)
	# ...but a NEW frame is a new reading, or the stick could never come back.
	var back := InputEventJoypadMotion.new()
	back.device = 0
	back.axis = JOY_AXIS_TRIGGER_LEFT
	back.axis_value = 0.5
	clash.track(back, 102)
	check("  and the next frame's reading replaces it", clash.axis(JOY_AXIS_TRIGGER_LEFT) == 0.5)
	# Firefox's real triggers, on axes 6 and 7, turn the camera either way.
	check("  a real trigger on axis 7 turns right, whatever the stick says",
		DioramaView.turn_intent(0.0, 0.0, 0.0, false, 0.0, 1.0) > 0.75
		and DioramaView.turn_intent(0.0, 0.5, 0.5, true, 0.0, 1.0) > 0.75)
	check("  and on axis 6 turns left",
		DioramaView.turn_intent(0.0, 0.0, 0.0, false, 1.0, 0.0) < -0.75)
	check("  and resting at 0 they change nothing",
		DioramaView.turn_intent(0.0, 0.0, 0.0, false, 0.0, 0.0) == 0.0)
	check("  and Firefox's stick pushed right turns the camera from them",
		DioramaView.turn_intent(g.axis(JOY_AXIS_RIGHT_X), g.axis(JOY_AXIS_TRIGGER_LEFT),
			0.5, true) > 0.75)

## The on-screen controller diagnostic (F8). Its whole job is to say WHICH axis
## moved, so the check that matters is that a push marks its own axis and only
## that one -- and that Firefox's resting 0.5 is not itself a movement.
func _test_the_pad_watch() -> void:
	print("-- the pad watch marks the axis that moved, and only that one")
	var w := PadWatch.new()
	w.reset()
	var rest := PackedFloat32Array([0, 0, 0, 0, 0.5, 0.5, 0, 0, 0, 0])
	w.sample(rest)
	check("  a pad at rest has moved nothing, even with the triggers at 0.5",
		not w.moved(4) and not w.moved(5) and not w.moved(2))
	var pushed := rest.duplicate()
	pushed[4] = 1.0
	w.sample(pushed)
	pushed[4] = 0.0
	w.sample(pushed)
	check("  the pushed axis is marked moved", w.moved(4))
	check("  and its neighbours are not", not w.moved(5) and not w.moved(2)
		and not w.moved(3))
	w.reset()
	check("  opening it again starts a fresh measurement", not w.moved(4))
	# Firefox: events report the stick while polling stays at zero. A push seen
	# only in events must still count.
	w.sample(rest)
	w.sample_event(5, 0.5)
	w.sample_event(5, 1.0)
	check("  a push seen only in the events counts as moved",
		w.moved(5) and not w.moved(4))
	w.reset()
	check("  it names Firefox from a user agent",
		PadWatch.browser_from("Mozilla/5.0 (X11; Linux x86_64; rv:131.0) Gecko/20100101 Firefox/131.0") == "Firefox/131.0")
	check("  and Edge as Edge, though it also claims to be Chrome",
		PadWatch.browser_from("Mozilla/5.0 AppleWebKit/537.36 Chrome/129.0 Safari/537.36 Edg/129.0.0") == "Edg/129.0.0")
	w.free()

## The title screen: its rows, the guard on New game, and the two floors it
## builds to look at -- neither of which may touch anything the player owns.
func _test_the_title_screen() -> void:
	print("-- the title screen")
	var t := TitleScreen.new()
	t.can_continue = false
	var ids := func() -> Array: return t.rows().map(func(r): return r[0])
	check("  with no saved run there is no continue, and new game comes first",
		not (&"continue" in ids.call()) and ids.call()[0] == &"new")
	check("  the Legends Run is hidden until unlocked", not (&"legends" in ids.call()))
	t.legends_open = true
	check("  and shown once it is", &"legends" in ids.call())
	check("  exit is offered where the build can quit",
		(&"exit" in ids.call()) == Platform.can_quit())

	# New game with a saved run: the first press only arms it.
	var fired := {"v": &""}
	t.chosen.connect(func(id: StringName) -> void: fired["v"] = id)
	t.can_continue = true
	check("  a saved run puts continue at the top", ids.call()[0] == &"continue")
	t.activate(1)
	check("  one press of new game over a saved run does not start one",
		fired["v"] == &"" and t._new_armed)
	t.activate(1)
	check("  the second press does", fired["v"] == &"new")
	fired["v"] = &""
	t._new_armed = false
	t.can_continue = false
	t.activate(0)
	check("  with no saved run, one press is enough", fired["v"] == &"new")

	# Settings is a page of the same list, and back returns.
	t.activate(ids.call().find(&"settings"))
	check("  settings opens its own page", t.page == &"settings"
		and &"3d" in ids.call() and &"back" in ids.call())
	t.handle_key(KEY_ESCAPE)
	check("  and escape comes back", t.page == &"main")
	# Every up/down set moves the highlight, not only the arrows.
	var moved_by_all := true
	for pair in [[KEY_DOWN, KEY_UP], [KEY_J, KEY_K], [KEY_S, KEY_W], [KEY_KP_2, KEY_KP_8]]:
		t._hover = 0
		t.handle_key(pair[0])
		var down_ok: bool = t._hover == 1
		t.handle_key(pair[1])
		moved_by_all = moved_by_all and down_ok and t._hover == 0
	check("  arrows, vi, WASD and the numpad all move the highlight", moved_by_all)
	t.free()

	# The mouse reaches the buttons: nothing drawn over them may take it. The
	# backdrop's own _ready claims the mouse, which put it over the rows.
	var shown := TitleScreen.new()
	root.add_child(shown)
	shown.size = Vector2(1600, 900)
	shown.open(false, false, 7)
	# A frame, as the game gets one: _ready -- where the mouse is claimed --
	# is deferred in a harness until the tree runs.
	await process_frame
	var takers := []
	for child in shown.get_children():
		if child is Control and child.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			takers.append("%s:%s" % [child.get_script().get_global_name() if child.get_script() else child.get_class(), child.mouse_filter])
	check("  an opened title has buttons to click", shown.rows().size() > 0
		and shown.mouse_filter == Control.MOUSE_FILTER_STOP)
	check("  and nothing over them takes the mouse", takers.is_empty(), str(takers))
	shown.queue_free()

	# The backdrop floor: monsters in sight, no hero, and the bestiary untouched.
	var known_before := BestiaryLog.count()
	var gs := TitleScreen.backdrop_state(7)
	var lit := 0
	for e in gs.entities:
		if gs.map.is_visible(e.x, e.y):
			lit += 1
	check("  the backdrop shows its monsters where they stand", lit > 0,
		"%d lit" % lit)
	check("  and no hero stands in it", not (gs.player in gs.entities))
	check("  building it noted nothing in the bestiary",
		BestiaryLog.count() == known_before and not BestiaryLog.paused)
	# That check passes vacuously if no monster happened to be in view while
	# the floor was built, so the hold is also asserted directly -- and must
	# not be a wall: a sighting after it still counts. A throwaway file, or the
	# test beast is "already known" on every run after the first.
	var scratch_bestiary := "user://scratch_view_tests_title_bestiary.txt"
	BestiaryLog.use_path(scratch_bestiary)
	BestiaryLog.paused = true
	check("  while held, the bestiary refuses a new sighting",
		not BestiaryLog.note(&"title_test_beast"))
	BestiaryLog.paused = false
	check("  and once released it notes the same one",
		BestiaryLog.note(&"title_test_beast"))
	DirAccess.remove_absolute(scratch_bestiary)
	BestiaryLog.use_path("user://scratch_view_tests_bestiary.txt")

	# The hall: three heroes, the traveller, nothing hostile, nothing outside.
	var hall := TitleHall.hall_state()
	var heroes := 0
	var travellers := 0
	var hostile := 0
	for e in hall.entities:
		if e.faction == Entity.Faction.PLAYER:
			heroes += 1
		elif e.appearance == &"trader" and e.faction == Entity.Faction.NEUTRAL:
			travellers += 1
		else:
			hostile += 1
	check("  the hall holds three heroes and the traveller, and no monster",
		heroes == 3 and travellers == 1 and hostile == 0,
		"%d heroes, %d travellers, %d others" % [heroes, travellers, hostile])
	check("  the hall is seen and the void round it is not",
		hall.map.is_visible(hall.player.x, hall.player.y)
		and not hall.map.is_explored(0, 0))

	# The Legends unlock reads escapes, which the grave parser cannot see.
	var path := "user://scratch_view_tests_title_morgue.txt"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_line("2026-09-01 20:00:00  level 3  killed by a kobold on depth 2, empty-handed, after 400 turns")
	f.store_line("2026-09-02 20:00:00  level 9  escaped the dungeon with the Amulet of the Deep, with the Amulet, after 9000 turns; known as Solo")
	f.close()
	check("  one escape in the morgue is counted", Morgue.escapes(path) == 1)
	check("  (and the grave parser still reads only the death)",
		Morgue.records(path).size() == 1)
	check("  no morgue, no escapes", Morgue.escapes("user://no_such_morgue.txt") == 0)
	DirAccess.remove_absolute(path)

## The inventory's gem hint asks the host the game would use. Brad's run,
## 2026-09-29: a set fire sling in hand, a buckler in the pack, a gem of the
## bulwark -- and the hint said the SLING was already set.
func _test_the_gem_hint_asks_the_right_host() -> void:
	print("-- the gem hint")
	var gs := GameState.new(99)
	gs.new_game()
	var sling := Item.make(&"sling")
	sling.element = &"fire"
	var buckler := Item.make(&"buckler")
	var bulwark := Item.make(&"gem_bulwark")
	var fire := Item.make(&"gem_fire")
	gs.player.inventory = [sling, buckler, bulwark, fire]
	gs.player.equipped = {Item.Slot.WEAPON: sling}
	var panel := InventoryPanel.new()
	panel.state = gs
	check("  a bulwark with the buckler in the pack asks for a shield",
		panel._action_hint(bulwark) == "needs a shield worn", panel._action_hint(bulwark))
	check("  a fire stone with the fire sling in hand says the sling is set",
		panel._action_hint(fire).ends_with("is already set"), panel._action_hint(fire))
	gs.player.equipped[Item.Slot.OFFHAND] = buckler
	var worn := panel._action_hint(bulwark)
	check("  and with the buckler worn, it no longer names the sling or a shield",
		not worn.contains("sling") and not worn.begins_with("needs a shield"), worn)
	panel.free()

## New players start in 3D with the follow camera (Brad, 2026-09-28); anyone
## who saved a choice keeps it. On the scratch settings file, restored after.
func _test_new_players_start_in_3d() -> void:
	print("-- new players start in 3D, following")
	var path := GameState.SETTINGS_PATH
	var had := FileAccess.file_exists(path)
	var kept := FileAccess.get_file_as_string(path) if had else ""
	if had:
		DirAccess.remove_absolute(path)
	RenderTheme.load_settings()
	check("  with no settings at all: the 3D view",
		RenderTheme.diorama_enabled())
	check("  and the camera follows", RenderTheme.camera_follows())
	var cfg := ConfigFile.new()
	cfg.set_value("view", "diorama", false)
	cfg.set_value("view", "follow", false)
	cfg.save(path)
	RenderTheme.load_settings()
	check("  a player who chose classic and a fixed camera keeps them",
		not RenderTheme.diorama_enabled() and not RenderTheme.camera_follows())
	DirAccess.remove_absolute(path)
	if had:
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(kept)
		f.close()
	RenderTheme.load_settings()

## Facing turns by eighths, and every facing has exactly one view that puts it
## straight up the screen -- the follow camera's whole geometry.
func _test_facing_and_the_follow_view() -> void:
	print("-- facing, and the view that puts it up")
	check("  north turned one eighth clockwise is north-east",
		Entity.turned(Vector2i(0, -1), 1) == Vector2i(1, -1)
		and Entity.turned(Vector2i(0, -1), -1) == Vector2i(-1, -1)
		and Entity.turned(Vector2i(1, 0), 2) == Vector2i(0, 1)
		and Entity.turned(Vector2i(1, 1), 8) == Vector2i(1, 1))
	var views := {}
	var all_up := true
	for step in Entity.CLOCKWISE:
		var v := DioramaView.view_facing(step)
		views[v] = true
		var on_screen := DioramaView.grid_to_view(step,
			DioramaView.CAMERA_YAW + float(v) * DioramaView.TURN_STEP).normalized()
		all_up = all_up and on_screen.dot(Vector2(0, -1)) > 0.99
	check("  every facing has a view that puts it straight up", all_up)
	check("  and each its own view", views.size() == 8, "%d views" % views.size())

## One rot for both views (BodyLook), and the 3D view lays a body only where
## one is there to see.
func _test_bodies_look_the_same_in_both_views() -> void:
	print("-- bodies")
	var fg := Color(0.8, 0.6, 0.4)
	var fresh := BodyLook.colour(fg, 0)
	var old := BodyLook.colour(fg, GameState.BODY_ROT - 1)
	check("  a fresh body is clearer than a rotten one",
		fresh.a > old.a and fresh.get_luminance() > old.get_luminance())
	check("  and still shows until the end", old.a > 0.0 and BodyLook.showing(GameState.BODY_ROT - 1))
	check("  and not after", not BodyLook.showing(GameState.BODY_ROT))

## While aiming, every cell a shot could land on is tinted -- asked of
## can_reach, so the picture cannot disagree with the shot.
func _test_reach_is_drawn() -> void:
	print("-- aiming shows the reach")
	var gs := GameState.new(31337)
	gs.new_game()
	var cells := gs.reach_cells(4)
	check("  a reach of 4 marks some cells (the premise)", cells.size() > 0,
		"%d cells" % cells.size())
	var agree := true
	var within := true
	for c in cells:
		agree = agree and gs.can_reach(c, 4)
		within = within and Los.steps(gs.player.x, gs.player.y, c.x, c.y) <= 4
	check("  every marked cell is one a shot can reach", agree and within)
	# And the converse over the whole square around the player: nothing
	# reachable is left unmarked.
	var missing := 0
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var c := Vector2i(gs.player.x + dx, gs.player.y + dy)
			if (dx != 0 or dy != 0) and gs.map.in_bounds(c.x, c.y) \
					and gs.can_reach(c, 4) and not (c in cells):
				missing += 1
	check("  and no reachable cell is left unmarked", missing == 0, "%d missing" % missing)
	check("  the player's own cell is not marked",
		not (Vector2i(gs.player.x, gs.player.y) in cells))
	check("  a melee reach marks nothing", gs.reach_cells(1).is_empty())

## David's generated background music (merged 2026-09-28): a theme per band,
## bent on the climb, in range, seamless at the loop -- and its own switch,
## separate from muting everything, which survives a restart.
func _test_davids_music() -> void:
	print("-- David's music")
	var bands := {}
	var descent_clean := true
	var climb_bent := true
	for d in range(1, GameState.MAX_DEPTH * 2):
		var p := Synth.music_profile(d)
		bands[int(p["band"])] = true
		if d <= GameState.MAX_DEPTH:
			descent_clean = descent_clean and not bool(p["corrupted"])
		else:
			climb_bent = climb_bent and bool(p["corrupted"])
	check("  every band has a theme, floor 1 to the top of the climb",
		bands.size() == 4, "%d bands" % bands.size())
	check("  the descent plays them straight", descent_clean)
	check("  and the climb plays them bent", climb_bent)
	check("  a floor on the climb is not the same tune as on the way down",
		Synth.music_profile(2)["lead_cycles"] != Synth.music_profile(GameState.MAX_DEPTH * 2 - 2)["lead_cycles"]
		and Synth.music_profile(2)["band"] == Synth.music_profile(GameState.MAX_DEPTH * 2 - 2)["band"])

	var in_range := true
	var seam := 0.0
	for d in [1, 4, 7, 10, 16]:
		var p := Synth.music_profile(d)
		for i in 400:
			var v := Synth.music_sample(p, i * Synth.MUSIC_LOOP_SECONDS / 400.0)
			in_range = in_range and is_finite(v) and absf(v) <= 1.0
		seam = maxf(seam, absf(Synth.music_sample(p, Synth.MUSIC_LOOP_SECONDS
			- 1.0 / Synth.MUSIC_RATE) - Synth.music_sample(p, 0.0)))
	check("  every sample is a number between -1 and 1", in_range)
	check("  and the loop meets itself without a click", seam < 0.05, "jump %.3f" % seam)

	# David's title theme (2026-09-28 patch): its own phrase, in range and
	# seamless like the bands.
	var title_p := Synth.title_music_profile()
	var title_ok := true
	for i in 400:
		var v := Synth.music_sample(title_p, i * Synth.MUSIC_LOOP_SECONDS / 400.0)
		title_ok = title_ok and is_finite(v) and absf(v) <= 1.0
	var title_seam := absf(Synth.music_sample(title_p, Synth.MUSIC_LOOP_SECONDS
		- 1.0 / Synth.MUSIC_RATE) - Synth.music_sample(title_p, 0.0))
	check("  the title has its own theme, not floor 1's",
		title_p["lead_cycles"] != Synth.music_profile(1)["lead_cycles"])
	check("  in range, and seamless at the loop", title_ok and title_seam < 0.05,
		"jump %.3f" % title_seam)

	# The switch: music off leaves the rest of the sound alone, and holds.
	var deck := SoundDeck.new()
	root.add_child(deck)
	await process_frame
	var was_on := deck.music_on
	var was_muted := deck.muted
	if not deck.music_on:
		deck.toggle_music()
	check("  music can be on (the premise)", deck.music_on)
	deck.toggle_music()
	deck.sync_music(1)
	check("  switching the music off stops it", not deck.music_on
		and not deck._music_player.playing)
	check("  and does not mute the effects", deck.muted == was_muted)
	var again := SoundDeck.new()
	root.add_child(again)
	await process_frame
	check("  and is remembered after a restart", not again.music_on)
	# The title theme hands over to the band, and a switch keeps whichever is on.
	again.toggle_music()
	again.sync_title_music()
	check("  the title plays its own theme", again._music_key == "title")
	again.toggle_music()
	again.toggle_music()
	check("  and switching the music off and on keeps the title's",
		again._music_key == "title")
	again.sync_music(1)
	check("  then a run hands over to the band's",
		again._music_key != "title" and not again._music_is_title)
	again.toggle_music()
	if again.music_on != was_on:
		again.toggle_music()
	for d in [again, deck]:
		d.stop_all()
		d.queue_free()
	await process_frame

## The three fixes from the 2026-09-26 playtest (teens and parents).
func _test_the_playtest_fixes() -> void:
	print("-- the playtest fixes: slow ground said, help found, a menu reachable")
	# Every slow ground has a word, and firm ground none -- across every tile,
	# so a new slow tile cannot arrive unexplained.
	var agree := true
	var slow := 0
	for t in range(Tiles.CHEST + 1):
		var is_slow := Tiles.move_cost(t) > 1.0
		if is_slow:
			slow += 1
		agree = agree and (is_slow == (Tiles.footing_word(t) != ""))
	check("  every slow ground, and only slow ground, has a status word",
		agree and slow >= 4, "%d slow tiles" % slow)
	check("  the status reads as the playtest asked",
		Sidebar.status_words("wading", 1.4) == "wading · slowed x1.4")

	var gs := GameState.new(77)
	gs.new_game()
	var here := HerePanel.new()
	here.state = gs
	gs.map.set_tile(gs.player.x, gs.player.y, Tiles.FLOOR)
	check("  on firm ground the HERE box says nothing extra", here.status_line() == "")
	gs.map.set_tile(gs.player.x, gs.player.y, Tiles.MUD)
	check("  in mud it says so, with the cost",
		here.status_line() == "sinking -- every step costs 2.0 turns", here.status_line())
	here.free()

	# The help hint: loud on floors 1-2 until the legend is opened once, and
	# the opening is remembered in settings (scratch here).
	var cfg := ConfigFile.new()
	cfg.load(GameState.SETTINGS_PATH)
	if cfg.has_section_key("help", "legend_seen"):
		cfg.erase_section_key("help", "legend_seen")
		cfg.save(GameState.SETTINGS_PATH)
	LegendPanel.forget_seen()
	check("  a new player on floor 1 gets the loud hint", Sidebar.help_is_loud(gs))
	gs.depth = 3
	check("  not on floor 3", not Sidebar.help_is_loud(gs))
	gs.depth = 1
	var legend := LegendPanel.new()
	legend.open()
	check("  and not once the legend has been opened", not Sidebar.help_is_loud(gs))
	LegendPanel.forget_seen()
	check("  which is remembered in settings, across runs", LegendPanel.seen_ever())
	legend.free()

	# The sidebar's buttons: the menu, the help line, and nothing elsewhere.
	var side := Sidebar.new()
	side.size = Vector2(256, 720)
	side.font = Sidebar.ui_font()
	side.font_bold = load("res://assets/fonts/JetBrainsMono-Bold.ttf")
	var got := {"v": ""}
	side.menu_clicked.connect(func() -> void: got["v"] = "menu")
	side.help_clicked.connect(func() -> void: got["v"] = "help")
	for case in [["menu", side.menu_button_rect().get_center()],
			["help", side.help_line_rect().get_center()],
			["", Vector2(128, 200)]]:
		got["v"] = ""
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = case[1]
		side._gui_input(click)
		check("  a click on the sidebar at %s opens %s" % [case[1],
			case[0] if case[0] != "" else "nothing"], got["v"] == case[0], got["v"])
	# The minimap: inside the panel, above the help line, and it GIVES WAY.
	var mini_gs := GameState.new(88)
	mini_gs.new_game()
	side.state = mini_gs
	side.show_minimap = true
	var mr := side.minimap_rect()
	check("  the minimap sits inside the sidebar, above the help line",
		mr.position.x >= Sidebar.PAD and mr.end.x <= side.size.x - Sidebar.PAD
		and mr.end.y < side.help_line_rect().position.y)
	side._look_bottom = 320.0
	check("  with a short description the minimap shows", side.minimap_fits())
	side._look_bottom = mr.position.y + 10.0
	check("  and it gives way when the words would reach it", not side.minimap_fits())
	side.show_minimap = false
	side._look_bottom = 320.0
	check("  and it is not drawn where it is not wanted", not side.minimap_fits())
	side.state = null
	check("  the menu button and the help line do not overlap",
		not side.menu_button_rect().intersects(side.help_line_rect()))
	# One line now (Brad): the loud, bold help text must fit left of the button.
	var help_w := side.font_bold.get_string_size("press ? for help",
		HORIZONTAL_ALIGNMENT_LEFT, -1, side.font_size).x
	check("  the bold help text fits beside the button",
		help_w <= side.help_line_rect().size.x,
		"%.0f px into %.0f" % [help_w, side.help_line_rect().size.x])
	check("  the button names the keyboard's key", side.menu_label() == "` menu")
	side.pad_cfg = PadConfig.new()
	side.pad_input = true
	var pad_label := side.menu_label()
	check("  and on a controller, the pad's own menu button",
		pad_label.ends_with(" menu") and not pad_label.begins_with("`")
		and pad_label != " menu", pad_label)
	# Measured as DRAWN, loud and bold: the first version checked only that
	# the two areas did not overlap, and on a pad the text ran into the button.
	for loud in [true, false]:
		side.help_loud = loud
		var face: Font = side.font_bold if loud else side.font
		var drawn := PadGlyphs.width(side.help_text(), face, side.font_size)
		check("  on a pad the help text fits beside the button (%s)" % ("loud" if loud else "quiet"),
			drawn <= side.help_line_rect().size.x,
			"%.0f px into %.0f: %s" % [drawn, side.help_line_rect().size.x, side.help_text()])
	side.pad_input = false
	check("  and both sit on the bottom line",
		absf(side.menu_button_rect().get_center().y - side.help_line_rect().get_center().y) < 6.0)
	side.free()

## The 3D view's own extras, on the scene the shared-moment test built.
func _test_3d_extras(scene: Control) -> void:
	var d = scene.diorama
	var gs: GameState = scene.state
	gs.map.set_all_visible()
	d._rebuild_world()
	var shaped: bool = not d._creatures.is_empty()
	for e in d._creatures:
		var nodes: Dictionary = d._creatures[e]
		var front: Label3D = nodes["label"]
		var back: Label3D = nodes.get("shape")
		shaped = shaped and back != null and back.no_depth_test and not front.no_depth_test \
			and back.render_priority < front.render_priority and back.text == front.text
	check("every creature is depth-tested, with a silhouette behind it for what walls hide",
		shaped)
	var pitch := deg_to_rad(DioramaView.CAMERA_PITCH_DEG)
	var reach := 1.4 * sin(pitch) - cos(pitch) * DioramaView.lean_pull(1.4)
	check("an ordinary creature stands where it is; the tallest are brought forward to clear the wall behind",
		DioramaView.lean_pull(0.8) == 0.0 and DioramaView.lean_pull(1.4) > 0.0 and reach <= 0.4501)
	var dot_labels := 0
	var dots := 0
	for node in d._scene_root.get_children():
		if node is Label3D and node.text == "·":
			dot_labels += 1
		elif node is MultiMeshInstance3D and node.name == "FloorDots":
			dots = node.multimesh.instance_count
	check("floor dots are one batch, not a label each (%d dots)" % dots,
		dot_labels == 0 and dots > 0)
	d._draw_fx()
	var shadows := 0
	for node in d._fx_root.get_children():
		if node is MultiMeshInstance3D and node.material_override == d._shadow_material:
			shadows = node.multimesh.instance_count
	check("a contact shadow under every creature in sight", shadows >= d._creatures.size()
		and shadows > 0)
	# A door that opens swings on "simple", and snaps on "still". Any open
	# floor will do for it: this scene is a real new game, on a new seed every
	# run, so nothing can be assumed about what is around the player -- asking
	# for floor two cells away failed on the run whose player had none.
	var p := Vector2i(gs.player.x, gs.player.y)
	var door := Vector2i(-1, -1)
	var was := -1
	for y in gs.map.height:
		for x in gs.map.width:
			var tile := gs.map.get_tile(x, y)
			if door.x < 0 and Vector2i(x, y) != p \
					and (tile == Tiles.FLOOR or tile == Tiles.CAVE_FLOOR):
				door = Vector2i(x, y)
				was = tile
	var swung := {}
	if door.x >= 0:
		gs.map.set_tile(door.x, door.y, Tiles.DOOR_CLOSED)
		for mode in [Effects.Mode.TIMERS, Effects.Mode.NONE]:
			_with_mode(mode, func():
				d._rebuild_world()
				gs.map.set_tile(door.x, door.y, Tiles.DOOR_OPEN)
				d._rebuild_world()
				swung[mode] = d._swings.has(door)
				d.settle_motion()
				gs.map.set_tile(door.x, door.y, Tiles.DOOR_CLOSED))
		gs.map.set_tile(door.x, door.y, was)
	check("a door swings open on simple, snaps on still, and the next key lands it (at %s)"
		% door, door.x >= 0 and swung.get(Effects.Mode.TIMERS, false)
		and not swung.get(Effects.Mode.NONE, true) and d._swings.is_empty(), str(swung))
	var hurt := [{"type": &"hurt", "t": 0.05, "strength": 0.45, "life": Fx.HURT_LIFE}]
	var jolt := {}
	for mode in [Effects.Mode.NONE, Effects.Mode.TIMERS, Effects.Mode.SHADERS]:
		_with_mode(mode, func(): jolt[mode] = DioramaView.camera_nudge(hurt, 1.3).length())
	check("the camera jolts when you are hurt on full only, and only a little",
		jolt[Effects.Mode.NONE] == 0.0 and jolt[Effects.Mode.TIMERS] == 0.0
		and jolt[Effects.Mode.SHADERS] > 0.0 and jolt[Effects.Mode.SHADERS] < 0.1, str(jolt))
	var turned := {}
	_with_mode(Effects.Mode.NONE, func():
		d.rotate_view(1)
		turned["snapped"] = is_equal_approx(d._rotation, d._rotation_target)
		d.rotate_view(-1))
	check("turning the camera snaps at once on still", turned["snapped"])

func _test_regions_colour_the_stone_not_the_floor() -> void:
	var names := []
	for eff in range(1, 20):
		names.append(String(RegionLook.for_depth(eff).label))
	check("each band has its look, the climb its corrupted one",
		names.slice(0, 3) == ["entrance", "entrance", "entrance"]
		and names.slice(3, 6) == ["caves", "caves", "caves"]
		and names.slice(6, 10) == ["fortress", "fortress", "fortress", "fortress"]
		and names[10] == "corrupted fortress" and names[14] == "corrupted caves"
		and names[18] == "corrupted entrance", str(names))
	var stones := [Palette.STONE_LIGHT, Palette.STONE_DARK, Palette.PILLAR,
		Palette.ROCK_LIGHT, Palette.ROCK_DARK]
	var bright_kept := true
	var apart := 99.0
	var dark := true
	for eff in range(1, 20):
		var look := RegionLook.for_depth(eff)
		for c: Color in stones:
			bright_kept = bright_kept \
				and absf(look.shift(c).get_luminance() - c.get_luminance()) < 0.003
		# The one thing stone must stay apart from is the door set into it.
		for c: Color in [Palette.STONE_LIGHT, Palette.PILLAR, Palette.ROCK_LIGHT]:
			apart = minf(apart, _delta_e(look.shift(c), Palette.DOOR))
		dark = dark and look.backdrop.get_luminance() < 0.06
	check("a region moves hue only: stone keeps its brightness", bright_kept)
	check("walls in every region stay readable against a door (%.1f)" % apart,
		apart >= 25.0)
	check("and the dark around the map stays dark", dark)
	var kept := true
	for t in [Tiles.FLOOR, Tiles.CAVE_FLOOR, Tiles.RUBBLE, Tiles.WATER, Tiles.MUD,
			Tiles.FUNGUS, Tiles.BONES, Tiles.TRAP, Tiles.DOOR_CLOSED, Tiles.DOOR_OPEN,
			Tiles.STAIRS_DOWN, Tiles.STAIRS_UP, Tiles.SHRINE, Tiles.BRAZIER]:
		kept = kept and not RegionLook.is_stone(t)
	check("the floor, and everything on it, keeps its own colours", kept
		and RegionLook.is_stone(Tiles.WALL) and RegionLook.is_stone(Tiles.ROCK))
	var wall := Palette.STONE_LIGHT
	check("the forest fades as you go down from the entrance",
		_delta_e(RegionLook.for_depth(1).shift(wall), wall)
			> _delta_e(RegionLook.for_depth(3).shift(wall), wall))
	check("the climb is not the descent: the same places, changed",
		RegionLook.for_depth(12).shift(wall) != RegionLook.for_depth(8).shift(wall)
		and RegionLook.for_depth(12).backdrop != RegionLook.for_depth(8).backdrop)

## CIE76 deltaE under normal vision, as run_tests.gd measures the overview's
## marks. The three dichromacies are measured with tools/check_palette.py.
func _delta_e(a: Color, b: Color) -> float:
	var la := _lab(a)
	var lb := _lab(b)
	return la.distance_to(lb)

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

func _test_both_views_share_one_moment() -> void:
	var scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for _i in 3:
		await process_frame
	check("a harness run skips the title and is playing at once",
		scene.title != null and not scene.title.visible and scene.state != null)
	# ` is a second Esc: it opens the menu, and closes it again.
	if scene.name_entry.visible:
		scene.name_entry.visible = false
	var tick := InputEventKey.new()
	tick.keycode = KEY_QUOTELEFT
	tick.pressed = true
	scene._unhandled_key_input(tick)
	check("` opens the menu, as Esc does", scene.menu.visible)
	scene._unhandled_key_input(tick)
	check("and closes it again", not scene.menu.visible)
	# The menu's help row: the legend for a pad whose View button never
	# arrives (Firefox).
	scene.menu.open()
	var help_row := -1
	for i in scene.menu.OPTIONS.size():
		if scene.menu.OPTIONS[i][2] == "help":
			help_row = i
	check("the pause menu has a help row", help_row >= 0)
	scene.menu._activate(help_row)
	check("and it closes the menu and opens the legend",
		not scene.menu.visible and scene.legend.visible)
	scene.legend.close()
	# A body where the player can see it is laid in 3D; a rotted one is not.
	var st: GameState = scene.state
	st.bodies = [{"x": st.player.x, "y": st.player.y, "app": "rat",
		"turn": st.turns, "corrupted": false, "e": {}}]
	scene.diorama._rebuild_world()
	check("a body in sight lies in the 3D view", scene.diorama._body_labels.size() == 1)
	st.bodies[0]["turn"] = st.turns - GameState.BODY_ROT
	scene.diorama._rebuild_world()
	check("and a rotted one does not", scene.diorama._body_labels.is_empty())
	st.bodies = []
	# Gabe's follow camera, in the real scene: turn free, step forward and back.
	var was_follow := RenderTheme.camera_follows()
	if not RenderTheme.camera_follows():
		RenderTheme.toggle_follow()
	scene._select_map_view(true)
	var gs2: GameState = scene.state
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			gs2.map.set_tile(gs2.player.x + dx, gs2.player.y + dy, Tiles.FLOOR)
	gs2.entities = [gs2.player]
	gs2.player.facing = Vector2i(0, -1)
	var start := Vector2i(gs2.player.x, gs2.player.y)
	var turns_was := gs2.turns
	var press := func(k: int) -> void:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.pressed = true
		scene._unhandled_key_input(ev)
	press.call(KEY_RIGHT)
	check("follow: right turns you, free, without a step",
		gs2.player.facing == Vector2i(1, -1) and Vector2i(gs2.player.x, gs2.player.y) == start
		and gs2.turns == turns_was)
	check("and the camera turns to put your facing up",
		scene.diorama._view == DioramaView.view_facing(Vector2i(1, -1)))
	press.call(KEY_UP)
	check("up steps forward, the way you face",
		Vector2i(gs2.player.x, gs2.player.y) == start + Vector2i(1, -1))
	press.call(KEY_DOWN)
	check("down steps back, still facing forward",
		Vector2i(gs2.player.x, gs2.player.y) == start and gs2.player.facing == Vector2i(1, -1))
	# Travelling: the camera holds, and swings once at the end.
	var view_before: int = scene.diorama._view
	gs2._travel = [start + Vector2i(1, 0)]
	gs2.player.facing = Vector2i(0, 1)
	scene._refresh()
	check("while travelling the camera does not swing", scene.diorama._view == view_before)
	gs2._travel = []
	scene._refresh()
	check("and swings once when travel ends",
		scene.diorama._view == DioramaView.view_facing(Vector2i(0, 1)))
	# Fixed: up is up the screen again, not "forward". Switched off by hand --
	# follow is the DEFAULT now, so the test cannot count on finding it off.
	if RenderTheme.camera_follows():
		RenderTheme.toggle_follow()
	gs2.player.facing = Vector2i(1, 0)
	var at := Vector2i(gs2.player.x, gs2.player.y)
	press.call(KEY_UP)
	check("with the camera fixed, up is the screen's up, whatever you face",
		Vector2i(gs2.player.x, gs2.player.y) - at == scene.diorama.map_relative_direction(Vector2i(0, -1)))
	if RenderTheme.camera_follows() != was_follow:
		RenderTheme.toggle_follow()
	scene._select_map_view(false)
	# The minimap is the 3D view's: on there, off in classic.
	scene._select_map_view(true)
	scene._process(0.0)
	var mini_in_3d: bool = scene.sidebar.show_minimap
	scene._select_map_view(false)
	scene._process(0.0)
	check("the minimap shows in 3D and not in classic",
		mini_in_3d and not scene.sidebar.show_minimap)
	# Aiming hands the reach to BOTH views, and ending it clears both.
	scene._begin_aim(4)
	check("aiming gives both views the same reach",
		scene._aiming and not scene.grid.reach_cells.is_empty()
		and scene.grid.reach_cells == scene.diorama.reach_cells)
	scene._end_aim()
	check("and ending the aim clears it from both",
		scene.grid.reach_cells.is_empty() and scene.diorama.reach_cells.is_empty())
	check("both views hold the same effects list and the same glides",
		scene.diorama.fx == scene.grid.fx and scene.diorama.motion == scene.grid.motion)
	scene._select_map_view(true)
	for _i in 2:
		await process_frame
	var p := Vector2i(scene.state.player.x, scene.state.player.y)
	scene.diorama.fx.hold = true
	scene.diorama.play_events([{"kind": &"melee", "from": p, "to": p,
		"amount": 37, "on_player": true}])
	for e in scene.diorama.fx.list:
		e["t"] = 0.1
	scene.diorama._update_dynamic()
	var drawn := false
	for node in scene.diorama._fx_root.get_children():
		if node is Label3D and node.text == "37":
			drawn = true
	check("the 3D view draws the damage number the list holds", drawn)
	# The red edge: one overlay over the map, hidden until something shows.
	scene.diorama.fx.list.clear()
	for _i in 2:
		await process_frame
	var hidden_when_idle: bool = not scene.screen_fx.visible
	scene.diorama.play_events([{"kind": &"melee", "from": p, "to": p,
		"amount": 5, "on_player": true}])
	for e in scene.diorama.fx.list:
		e["t"] = 0.1
	for _i in 2:
		await process_frame
	check("the whole-map overlay hides when idle and shows a hurt, for either view",
		hidden_when_idle and scene.screen_fx.visible
		and scene.screen_fx.get_index() == scene.diorama.get_index() + 1)
	scene.diorama.fx.hold = false
	scene.diorama.fx.list.clear()

	# Moving light and fading memory are shared the same way, and the 3D
	# surfaces are handed both of LivingLight's textures.
	check("both views hold the same light and the same memory",
		scene.diorama.light == scene.grid.light
		and scene.diorama.memory == scene.grid.memory)
	var gs: GameState = scene.state
	var trader := gs.trader
	var has_trader := trader != null and trader.alive
	if has_trader:
		# Seen once, out of sight now: remembered in both views.
		gs.map.reveal_all()
		gs.map.clear_visible()
	scene.diorama._rebuild_world()
	var fed: bool = not scene.diorama._surface_materials.is_empty()
	for m: ShaderMaterial in scene.diorama._surface_materials:
		fed = fed and m.get_shader_parameter("cell_data") == scene.diorama.light.cells \
			and m.get_shader_parameter("cell_extra") == scene.diorama.light.extra
	check("every 3D surface reads LivingLight's two textures", fed)
	var pictured := false
	for node in scene.diorama._scene_root.get_children():
		if node is Label3D and node.modulate.is_equal_approx(MapMemory.trader_colour()):
			pictured = true
	check("the 3D view draws the trader from memory, out of sight (floor has one: %s)"
		% has_trader, pictured or not has_trader)
	# Colour by region, in the 3D view: the dark is the region's, walls in
	# view take its colour, the floor and memory do not.
	var look := RegionLook.for_depth(gs.effective_depth())
	var d = scene.diorama
	check("the 3D backdrop is the region's dark",
		d._environment.background_color == look.backdrop)
	var p2 := Vector2i(gs.player.x, gs.player.y)
	check("in 3D the region colours walls in view, and not the floor or memory",
		d._surface_color(Tiles.WALL, p2.x, p2.y, true)
			!= d._surface_color(Tiles.WALL, p2.x, p2.y, false)
		and d._surface_color(Tiles.FLOOR, p2.x, p2.y, true)
			== d._surface_color(Tiles.FLOOR, p2.x, p2.y, false),
		"floor %d: %s" % [gs.effective_depth(), look.label])
	# Small life is shared too, and the 3D view draws it on "full".
	check("both views hold the same small life", d.life == scene.grid.life)
	var near_player := Vector2i(gs.player.x, gs.player.y)
	for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if gs.map.is_walkable(near_player.x + dd.x, near_player.y + dd.y):
			near_player += dd
			break
	gs.map.set_tile(near_player.x, near_player.y, Tiles.FUNGUS)
	gs.map.set_all_visible()
	d.life.rebuild(gs)
	# A dictionary, because a lambda captures a local bool by value.
	var drew := {"life": false}
	_with_mode(Effects.Mode.SHADERS, func():
		for t in [0.3, 1.1, 2.2, 3.4]:
			d.anim_time = t
			d._draw_fx()
			for node in d._fx_root.get_children():
				if node is MultiMeshInstance3D and node.multimesh.mesh == d._mote_mesh \
						and node.multimesh.instance_count > 0:
					drew["life"] = true)
	d.anim_time = -1.0
	check("and the 3D view draws spores off fungus on full", drew["life"])
	# The trader idles the same in both views: off their spot by
	# SmallLife.idle_offset on "full", exactly on it on "simple". A trader of
	# the test's own, beside you, whatever this floor has.
	var had_trader := gs.trader
	var keeper := Entity.new("trader", &"trader", gs.player.x + 2, gs.player.y)
	gs.trader = keeper
	var poses := {}
	for mode in [Effects.Mode.TIMERS, Effects.Mode.SHADERS]:
		_with_mode(mode, func():
			scene.grid.anim_time = 2.5
			d.anim_time = 2.5
			poses[mode] = [scene.grid._visual_cell(keeper), d._drawn_cell(keeper)])
	scene.grid.anim_time = -1.0
	d.anim_time = -1.0
	gs.trader = had_trader
	var spot := Vector2(keeper.x, keeper.y)
	check("both views pose the trader alike: idling on full, still on simple",
		poses[Effects.Mode.SHADERS][0] == poses[Effects.Mode.SHADERS][1]
		and poses[Effects.Mode.SHADERS][0] != spot
		and poses[Effects.Mode.TIMERS][0] == spot and poses[Effects.Mode.TIMERS][1] == spot,
		str(poses))
	var levels := {}
	for mode in [Effects.Mode.NONE, Effects.Mode.TIMERS, Effects.Mode.SHADERS]:
		_with_mode(mode, func(): levels[mode] = scene.diorama._motion_level())
	check("the 3D light is still, simple or full with the setting",
		levels == {Effects.Mode.NONE: 0, Effects.Mode.TIMERS: 1, Effects.Mode.SHADERS: 2},
		str(levels))
	await _test_3d_extras(scene)
	scene.queue_free()
	await process_frame
