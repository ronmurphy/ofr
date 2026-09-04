extends SceneTree

## Dev tool: renders the game and writes PNGs, so visual changes can be checked
## without sitting through a play session.
##   godot --script res://tests/capture.gd -- /path/to/outdir

const SEED := 24601

var _out := "/tmp"
var _scene: Control

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	_run()

func _run() -> void:
	_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(_scene)
	for _i in 20:
		await process_frame

	# Fixed seed so shots are comparable between runs.
	var gs := GameState.new(SEED)
	gs.new_game()
	_use(gs)
	await _shot("01_start.png")

	# Capture-only: an immortal bot, so the shot shows a living dungeon rather
	# than whatever killed a random walker on the way.
	gs.player.max_hp = 9999
	gs.player.hp = 9999
	_walk_to_stairs(gs)
	_scene._refresh()
	await _shot("02_explored.png")

	# Inventory, stocked so the panel has something to show.
	for want in [&"potion_healing", &"scroll_light", &"dagger", &"leather_armour",
			&"scroll_blink", &"chain_mail", &"short_sword", &"potion_healing",
			&"dagger", &"leather_armour"]:
		gs.give_item(Item.make(want))
	# Stand at a brazier so the forge markers are exercised.
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var c := Vector2i(gs.player.x + d.x, gs.player.y + d.y)
		if gs.map.get_tile(c.x, c.y) == Tiles.FLOOR:
			gs.map.set_tile(c.x, c.y, Tiles.BRAZIER)
			gs.brazier_charge[c] = GameState.BRAZIER_CHARGE
			gs._gather_lights()
			gs.update_vision()
			break
	# Set directly rather than via player_use, so the shot is not disturbed by
	# the turns that equipping would cost.
	gs.player.equipped[Item.Slot.WEAPON] = gs.player.inventory[2]
	gs.player.equipped[Item.Slot.ARMOR] = gs.player.inventory[3]
	_scene._open_inventory()
	_scene.inventory._hover_index = 5  # show the hover affordance in the shot
	_scene._refresh()
	await _shot("07_inventory.png")
	_scene.inventory.filter = InventoryPanel.Filter.ARMOUR
	_scene._refresh()
	await _shot("08_inventory_filtered.png")
	_scene._close_inventory()

	# Look mode, parked on a brazier so the shot shows both new things at once.
	var target := _find_tile(gs, Tiles.BRAZIER)
	if target.x < 0:
		for e in gs.entities:
			if not e.is_player and e.alive and gs.map.is_visible(e.x, e.y):
				target = Vector2i(e.x, e.y)
				break
	if target.x < 0:
		target = Vector2i(gs.player.x, gs.player.y)
	print("  look target: %s (tile %d)" % [target, gs.map.get_tile(target.x, target.y)])
	if target.x >= 0:
		_scene._toggle_look()
		_scene._look_at = target
		_scene.grid.look_cursor = target
		_scene._refresh()
		await _shot("03_look_mode.png")
		_scene._end_look()

	for style in [
		{"v": GlyphGrid.WallStyle.SOLID, "f": "04_walls_solid.png"},
		{"v": GlyphGrid.WallStyle.GLYPH, "f": "05_walls_glyph.png"},
	]:
		_scene.grid.wall_style = style["v"]
		_scene._refresh()
		await _shot(style["f"])

	# Glyph check: braziers are sparse, so force one beside the player to keep
	# the Ω exercised. Catches a missing codepoint rendering as tofu.
	_scene.grid.wall_style = GlyphGrid.WallStyle.LINE
	var px := gs.player.x
	var py := gs.player.y
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if gs.map.get_tile(px + d.x, py + d.y) == Tiles.FLOOR:
			gs.map.set_tile(px + d.x, py + d.y, Tiles.BRAZIER)
			gs.static_lights.append(LightSource.new(px + d.x, py + d.y, 6,
				Color(0.95, 0.55, 0.20), Color(0.35, 0.20, 0.30), 0.85, true))
			break
	gs.update_vision()
	_scene._refresh()
	await _shot("06_glyph_check.png")

	# Combat feedback: stage a shot in an open arena and photograph it both
	# mid-flight and on impact.
	var fx := GameState.new(4242)
	fx.new_game()
	var aw := 40
	var ah := 22
	fx.map = DungeonMap.new(aw, ah)
	for y in range(1, ah - 1):
		for x in range(1, aw - 1):
			fx.map.set_tile(x, y, Tiles.FLOOR)
	fx.light_map = LightMap.new(aw, ah)
	fx.pathfinder = Pathfinder.new(fx.map)
	fx.entities = [fx.player]
	fx.ground = []
	fx.static_lights = []
	var fov := PackedByteArray()
	fov.resize(aw * ah)
	fx._fov_buffer = fov
	fx.player.x = 8
	fx.player.y = 10
	fx.player.max_hp = 40
	fx.player.hp = 11
	fx.player.alive = true

	var archer := Entity.new("kobold slinger", &"slinger", 14, 10)
	archer.max_hp = 5
	archer.hp = 5
	archer.power = 3
	archer.speed = 100
	archer.ai = &"ranged"
	archer.attack_range = 6
	fx.entities.append(archer)
	fx.update_vision()
	_use(fx)

	fx._take_ai_turn(archer)
	_scene._refresh()
	for _i in 3:
		await process_frame
	await _shot("10_shot_inflight.png")
	for _i in 8:
		await process_frame
	await _shot("11_impact.png")

	# Awareness markers and the torch trade.
	var sneak := GameState.new(777)
	sneak.new_game()
	var ww := 34
	var wh := 19
	sneak.map = DungeonMap.new(ww, wh)
	for y in range(1, wh - 1):
		for x in range(1, ww - 1):
			sneak.map.set_tile(x, y, Tiles.FLOOR)
	sneak.map.set_tile(10, 11, Tiles.PILLAR)
	sneak.map.set_tile(15, 8, Tiles.STALAGMITE)
	sneak.light_map = LightMap.new(ww, wh)
	sneak.pathfinder = Pathfinder.new(sneak.map)
	sneak.entities = [sneak.player]
	sneak.ground = []
	sneak.static_lights = []
	var fov2 := PackedByteArray()
	fov2.resize(ww * wh)
	sneak._fov_buffer = fov2
	sneak.player.x = 8
	sneak.player.y = 9
	sneak.player.hp = 30
	sneak.player.max_hp = 30
	sneak.player.alive = true
	sneak.torch_lit = true

	var sleepers := []
	for spec in [[12, 7, &"kobold", "kobold"], [13, 12, &"goblin", "goblin"],
			[11, 9, &"rat", "giant rat"], [14, 10, &"slinger", "kobold slinger"]]:
		var m := Entity.new(spec[3], spec[2], spec[0], spec[1])
		m.max_hp = 8
		m.hp = 8
		m.alertness = Entity.Alert.ASLEEP
		sneak.entities.append(m)
		sleepers.append(m)
	sleepers[2].alertness = Entity.Alert.SUSPICIOUS
	sneak.update_vision()
	_use(sneak)
	for _i in 3:
		await process_frame
	await _shot("12_awareness.png")

	# Arm one of them so the look panel's gear line is exercised.
	sleepers[0].equipped[Item.Slot.WEAPON] = Item.make(&"short_sword")
	sleepers[0].equipped[Item.Slot.ARMOR] = Item.make(&"leather_armour")
	_scene._toggle_look()
	_scene._look_at = Vector2i(sleepers[0].x, sleepers[0].y)
	_scene.grid.look_cursor = _scene._look_at
	_scene._refresh()
	for _i in 2:
		await process_frame
	await _shot("17_gear.png")
	_scene._end_look()

	sneak.wake(sleepers[3])
	_scene._refresh()
	for _i in 3:
		await process_frame
	await _shot("13_noticed.png")

	sneak.torch_lit = false
	sneak.update_vision()
	_scene._refresh()
	for _i in 3:
		await process_frame
	await _shot("14_doused.png")

	# Brazier resting: one burned out beside one still lit.
	var hearth := GameState.new(555)
	hearth.new_game()
	var hw := 30
	var hh := 15
	hearth.map = DungeonMap.new(hw, hh)
	for y in range(1, hh - 1):
		for x in range(1, hw - 1):
			hearth.map.set_tile(x, y, Tiles.FLOOR)
	hearth.map.set_tile(9, 7, Tiles.BRAZIER)
	hearth.map.set_tile(13, 7, Tiles.BRAZIER)
	hearth.light_map = LightMap.new(hw, hh)
	hearth.pathfinder = Pathfinder.new(hearth.map)
	hearth.entities = [hearth.player]
	hearth.ground = []
	hearth.brazier_charge = {
		Vector2i(9, 7): GameState.BRAZIER_CHARGE,
		Vector2i(13, 7): GameState.BRAZIER_CHARGE,
	}
	var fov3 := PackedByteArray()
	fov3.resize(hw * hh)
	hearth._fov_buffer = fov3
	hearth.player.x = 8
	hearth.player.y = 7
	hearth.player.max_hp = 30
	hearth.player.hp = 9
	hearth.player.alive = true
	hearth.torch_lit = true
	hearth._gather_lights()
	hearth.update_vision()
	_use(hearth)

	for _i in 7:
		hearth.player_wait()
	_scene._refresh()
	for _i in 3:
		await process_frame
	await _shot("15_hearth.png")

	# Stairs beacon: everything remembered, nothing currently lit.
	var beacon := GameState.new(4711)
	beacon.new_game()
	# Stand 12-18 cells from the stairs: far enough that they are remembered
	# rather than lit, close enough that both fit in one screen.
	var placed := false
	for ry in beacon.map.height:
		if placed:
			break
		for rx in beacon.map.width:
			var d := Los.steps(rx, ry, beacon.stairs.x, beacon.stairs.y)
			if d >= 12 and d <= 18 and beacon.map.is_walkable(rx, ry):
				beacon.player.x = rx
				beacon.player.y = ry
				placed = true
				break
	beacon.update_vision()
	beacon.map.reveal_all()
	_use(beacon)
	_scene.grid.centre_on_player()
	print("  stairs %s  player (%d,%d)" % [beacon.stairs, beacon.player.x, beacon.player.y])
	_scene._refresh()
	for _i in 3:
		await process_frame
	for boost in [1.0, 1.8, 2.6]:
		_scene.grid.memory_material_boost = boost
		_scene._refresh()
		for _i in 2:
			await process_frame
		await _shot("16_biome_%.1f.png" % boost)
	_scene.grid.memory_material_boost = 1.8

	# Targeting: a clear shot, and the same shot blocked by cover.
	var aim := GameState.new(3131)
	aim.new_game()
	var qw := 34
	var qh := 15
	aim.map = DungeonMap.new(qw, qh)
	for y in range(1, qh - 1):
		for x in range(1, qw - 1):
			aim.map.set_tile(x, y, Tiles.FLOOR)
	aim.light_map = LightMap.new(qw, qh)
	aim.pathfinder = Pathfinder.new(aim.map)
	aim.entities = [aim.player]
	aim.ground = []
	aim.static_lights = []
	var fov4 := PackedByteArray()
	fov4.resize(qw * qh)
	aim._fov_buffer = fov4
	aim.player.x = 6
	aim.player.y = 7
	aim.player.max_hp = 60
	aim.player.hp = 47
	aim.player.alive = true
	var bow := Item.make(&"short_bow")
	aim.player.inventory.append(bow)
	aim.player.equipped[Item.Slot.WEAPON] = bow

	var mark := Entity.new("goblin", &"goblin", 13, 7)
	mark.max_hp = 9
	mark.hp = 9
	mark.alertness = Entity.Alert.AWAKE
	aim.entities.append(mark)
	aim.update_vision()
	_use(aim)

	_scene._begin_aim()
	for _i in 2:
		await process_frame
	await _shot("20_aim_clear.png")

	aim.map.set_tile(10, 7, Tiles.PILLAR)
	aim.update_vision()
	_scene._update_aim()
	for _i in 2:
		await process_frame
	await _shot("21_aim_blocked.png")
	_scene._end_aim()

	# The off-hand: a melee weapon in hand, so f opens the pack instead.
	aim.map.set_tile(10, 7, Tiles.FLOOR)
	aim.player.equipped[Item.Slot.WEAPON] = Item.make(&"war_axe")
	for want in [&"dagger", &"dagger", &"short_sword", &"potion_healing"]:
		aim.give_item(Item.make(want))
	aim.update_vision()
	_scene._begin_throw_pick()
	for _i in 2:
		await process_frame
	await _shot("22_throw_pick.png")
	_scene._close_inventory()

	# The amulet, and the moment the run turns around.
	var relic_run := GameState.new(8800)
	relic_run.new_game()
	relic_run.depth = GameState.MAX_DEPTH
	relic_run.build_level()
	relic_run.player.max_hp = 90
	relic_run.player.hp = 71
	relic_run.award_xp(relic_run.xp_for_level(9))
	for it in relic_run.ground:
		if it.kind == Item.Kind.AMULET:
			relic_run.player.x = it.x
			relic_run.player.y = it.y
			break
	relic_run.update_vision()
	_use(relic_run)
	for _i in 2:
		await process_frame
	await _shot("18_amulet_before.png")

	relic_run.player_pickup()
	_scene._refresh()
	for _i in 3:
		await process_frame
	await _shot("19_amulet_taken.png")

	# A shrine in its sanctum, unidentified.
	for seed_try in range(2400, 2460):
		var holy := GameState.new(seed_try)
		holy.new_game()
		if holy.shrine_at.is_empty():
			continue
		var cell: Vector2i = holy.shrine_at.keys()[0]
		var spot := Vector2i(-1, -1)
		for d in [Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1),
				Vector2i(2, 0), Vector2i(-2, 0)]:
			if holy.map.is_walkable(cell.x + d.x, cell.y + d.y):
				spot = cell + d
				break
		if spot.x < 0:
			continue
		holy.player.x = spot.x
		holy.player.y = spot.y
		holy.update_vision()
		_use(holy)
		_scene._toggle_look()
		_scene._look_at = cell
		_scene.grid.look_cursor = cell
		_scene._refresh()
		for _i in 3:
			await process_frame
		await _shot("24_shrine.png")
		_scene._end_look()
		print("  shrine seed %d at %s" % [seed_try, cell])
		break

	# The legend, with a couple of shrines already learned so both states show.
	var lore := GameState.new(555)
	lore.new_game()
	lore.shrine_known[Shrines.QUIET] = true
	lore.shrine_known[Shrines.EMBERS] = true
	_use(lore)
	_scene.legend.open()
	_scene._refresh()
	for _i in 3:
		await process_frame
	await _shot("26_legend.png")
	_scene.legend.close()

	# The pause menu.
	_scene.menu.open()
	_scene._refresh()
	for _i in 2:
		await process_frame
	await _shot("23_menu.png")
	_scene.menu.close()

	# A vault, in place on a real level.
	for seed_try in range(7100, 7200):
		var vlevel := GameState.new(seed_try)
		vlevel.new_game()
		vlevel.depth = 4
		vlevel.build_level()
		if vlevel.vault_rects.is_empty():
			continue
		vlevel.light_map.ambient = Color(0.46, 0.47, 0.52)
		var vs: Array = [vlevel.player.light]
		vs.append_array(vlevel.static_lights)
		vlevel.light_map.compute(vlevel.map, vs)
		vlevel.map.reveal_all()
		vlevel.map.set_all_visible()
		_use(vlevel)
		var vr: Rect2i = vlevel.vault_rects[0]
		var vc2: Vector2i = _scene.grid.viewport_cells()
		_scene.grid._origin = Vector2i(
			clampi(vr.get_center().x - vc2.x / 2, 0, maxi(0, vlevel.map.width - vc2.x)),
			clampi(vr.get_center().y - vc2.y / 2, 0, maxi(0, vlevel.map.height - vc2.y)))
		_scene.grid.settle_camera()
		_scene._refresh()
		print("  vault seed %d at %s" % [seed_try, vr])
		for _i in 3:
			await process_frame
		await _shot("25_vault.png")
		break

	# Whole-level overview: everything revealed and lit, so generation can be
	# judged as a layout rather than through a torch-sized hole.
	for seed_value in [SEED, 8801, 8802]:
		var over := GameState.new(seed_value)
		over.new_game()
		_use(over)
		over.light_map.ambient = Color(0.46, 0.47, 0.52)
		var sources: Array = [over.player.light]
		sources.append_array(over.static_lights)
		over.light_map.compute(over.map, sources)
		over.map.reveal_all()
		over.map.set_all_visible()
		_scene._refresh()
		await _shot("09_layout_%d.png" % seed_value)

	quit()

func _use(gs: GameState) -> void:
	_scene._bind_state(gs)

## Follow the pathfinder to the stairs, recomputing whenever something gets in
## the way. Crosses several rooms, so the shot shows corridors, doors, and the
## contrast between lit terrain and remembered terrain.
func _walk_to_stairs(gs: GameState) -> void:
	for _attempt in 400:
		if Vector2i(gs.player.x, gs.player.y) == gs.stairs:
			return
		var route := gs.pathfinder.path(Vector2i(gs.player.x, gs.player.y), gs.stairs)
		if route.is_empty():
			return
		var step: Vector2i = route[0]
		if not gs.player_move(step.x - gs.player.x, step.y - gs.player.y):
			return

func _find_tile(gs: GameState, want: int) -> Vector2i:
	for y in gs.map.height:
		for x in gs.map.width:
			if gs.map.get_tile(x, y) == want and gs.map.is_explored(x, y):
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func _shot(name: String) -> void:
	# Must wait for the renderer to actually finish a frame, not just for the
	# scene tree to tick, or the captured texture comes back blank -- and two
	# frames was not always enough, which let a shot pick up the NEXT stage's
	# state instead of its own.
	for _f in 4:
		await process_frame
		RenderingServer.force_draw()
	var img := root.get_texture().get_image()
	img.save_png(_out.path_join(name))
	print("wrote %s" % name)
