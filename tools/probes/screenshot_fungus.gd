extends SceneTree

## RENDERS the wrong fungus -- a purple patch, a red patch and a red chain
## crawling toward a body -- beside the player, in both views. Scratch files;
## works with the screen locked.
##   SHOT_DIR=/tmp godot --path . --resolution 1600x900 -s tools/probes/screenshot_fungus.gd
func _initialize() -> void:
	GameState.use_scratch_files("fungusshot")
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
	var g := GameState.new(424242)
	g.new_game()
	g.depth = 7
	g.build_level()
	scene._bind_state(g)
	var o := Vector2i(g.player.x, g.player.y)
	for dy in range(-3, 4):
		for dx in range(-5, 6):
			g.map.set_tile(o.x + dx, o.y + dy, Tiles.FLOOR)
	g.entities = [g.player]
	for c in [Vector2i(-3, -2), Vector2i(-2, -2), Vector2i(-3, -1)]:
		g.map.set_tile(o.x + c.x, o.y + c.y, Tiles.FUNGUS_PURPLE)
	for c in [Vector2i(2, -2), Vector2i(3, -2), Vector2i(2, -1)]:
		g.map.set_tile(o.x + c.x, o.y + c.y, Tiles.FUNGUS_RED)
	g.map.set_tile(o.x - 1, o.y + 2, Tiles.FUNGUS)
	g.bodies = [{"x": o.x + 4, "y": o.y + 2, "app": "goblin", "turn": g.turns,
		"corrupted": false, "e": {"name": "goblin"}, "seeded": -1, "claimed": false}]
	g.map.set_tile(o.x + 2, o.y + 1, Tiles.FUNGUS_RED)
	# Marked creatures, to show the outline: a red-marked kobold and a
	# purple-marked (corrupted) goblin.
	var redk := GameState.monster_from(GameState.BESTIARY[1], o.x - 2, o.y + 1)
	redk.take_spores(&"red")
	var purg := GameState.monster_from(GameState.BESTIARY[4], o.x + 1, o.y + 2)
	g._corrupt(purg)
	g.entities = [g.player, redk, purg]
	g.pathfinder = Pathfinder.new(g.map)
	g._gather_lights()
	g.update_vision()
	scene._select_map_view(false)
	scene._refresh()
	await _shot("fungus_classic.png")
	scene._select_map_view(true)
	scene._refresh()
	await _shot("fungus_3d.png")
	GameState.clear_scratch_files()
	quit()
