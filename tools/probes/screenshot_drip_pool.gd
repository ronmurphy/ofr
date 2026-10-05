extends SceneTree

## RENDERS a cave floor's drip pool beside the player, in both views, on
## full effects: the pool should sit under the falling drips. Builds depth 5
## floors until one has a pool and stands you next to it. Scratch files;
## works with the screen locked.
##   SHOT_DIR=/tmp godot --path . --resolution 1600x900 -s tools/probes/screenshot_drip_pool.gd
func _initialize() -> void:
	GameState.use_scratch_files("dripshot")
	GameState.clear_scratch_files()
	_run.call_deferred()

func _shot(name: String) -> void:
	for i in 14:
		await process_frame
		RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/" + name)

func _run() -> void:
	var scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.name_entry.visible = false
	var g: GameState = null
	var pool := Vector2i(-1, -1)
	for i in 30:
		g = GameState.new(60000 + i)
		g.new_game()
		g.depth = 5
		g.build_level()
		for region in g.cave_regions:
			for y in range(region.position.y, region.end.y):
				for x in range(region.position.x, region.end.x):
					if g.map.get_tile(x, y) == Tiles.WATER and pool.x < 0:
						pool = Vector2i(x, y)
		if pool.x >= 0:
			break
	if pool.x < 0:
		print("no pool found")
		quit()
		return
	# Stand beside the pool, alone, with the torch lit.
	g.entities = [g.player]
	var spot := pool + Vector2i(2, 0)
	if not g.map.is_walkable(spot.x, spot.y):
		spot = pool + Vector2i(-2, 0)
	g.player.x = spot.x
	g.player.y = spot.y
	g.torch_lit = true
	g.pathfinder = Pathfinder.new(g.map)
	g._gather_lights()
	g.update_vision()
	scene._bind_state(g)
	Effects._mode = Effects.Mode.SHADERS
	scene._select_map_view(false)
	scene._refresh()
	await _shot("drip_pool_classic.png")
	scene._select_map_view(true)
	scene._refresh()
	await _shot("drip_pool_3d.png")
	print("pool at ", pool, " seed ", g.rng.seed)
	GameState.clear_scratch_files()
	quit()
