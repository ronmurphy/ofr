extends SceneTree

## RENDERS the moment a pack turns to you: four wolves beside the player, the
## haunches thrown down, a heart over each, in both views on full effects.
## Scratch files; works with the screen locked.
##   SHOT_DIR=/tmp godot --path . --resolution 1600x900 -s tools/probes/screenshot_tamed.gd
func _initialize() -> void:
	GameState.use_scratch_files("tamedshot")
	GameState.clear_scratch_files()
	_run.call_deferred()

func _shot(name: String) -> void:
	# Two frames only: the hearts live POPUP_LIFE seconds and the shot
	# must catch them in the air.
	for i in 2:
		await process_frame
		RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/" + name)

func _by_name(name: String) -> Dictionary:
	for e in GameState.BESTIARY:
		if e["name"] == name:
			return e
	return {}

func _run() -> void:
	var scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.name_entry.visible = false
	for view in [false, true]:
		var g := GameState.new(424242)
		g.new_game()
		g.depth = 5
		g.build_level()
		var o := Vector2i(g.player.x, g.player.y)
		for dy in range(-3, 4):
			for dx in range(-5, 6):
				g.map.set_tile(o.x + dx, o.y + dy, Tiles.FLOOR)
		g.entities = [g.player]
		g.player.inventory.clear()
		g.player.equipped.clear()
		var leader := GameState.monster_from(_by_name("wolf"), o.x + 1, o.y)
		leader.alertness = Entity.Alert.AWAKE
		g.entities.append(leader)
		g._spawn_pack(leader, _by_name("wolf"), 3)
		for i in 4:
			g.give_item(Item.make(&"meat"))
		g.pathfinder = Pathfinder.new(g.map)
		g._gather_lights()
		g.update_vision()
		scene._bind_state(g)
		Effects._mode = Effects.Mode.SHADERS
		scene._select_map_view(view)
		scene._close_inventory()
		scene._refresh()
		# A frame first: the effects forget everything in flight the first
		# frame after the state changes under them (Fx.watch_map).
		await process_frame
		RenderingServer.force_draw(false)
		g.player_move(1, 0)
		g.player_move(1, 0)
		scene._refresh()
		# The hearts live POPUP_LIFE seconds and the first rendered frame after
		# a rebuild can take longer than that: hold the effects for the shot.
		scene.grid.fx.hold = true
		await _shot("tamed_%s.png" % ("3d" if view else "classic"))
		print("popups held for the shot: ", scene.grid.fx.list.size())
		scene.grid.fx.hold = false
	GameState.clear_scratch_files()
	quit()
