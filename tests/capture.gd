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
	for want in [&"potion_healing", &"scroll_light", &"scroll_blink", &"potion_healing"]:
		gs.player.inventory.append(Item.make(want))
	_scene._open_inventory()
	_scene.inventory._hover_row = 1  # show the hover affordance in the shot
	_scene._refresh()
	await _shot("07_inventory.png")
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
	# scene tree to tick, or the captured texture comes back blank.
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	var img := root.get_texture().get_image()
	img.save_png(_out.path_join(name))
	print("wrote %s" % name)
