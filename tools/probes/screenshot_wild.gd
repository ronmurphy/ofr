extends SceneTree

## RENDERS the wild tint beside the player, in both views: a bear, a rabbit
## and a bat in the one wild colour, a goblin for contrast, and a second
## bear that has been struck -- the same colour, because the colour says the
## KIND; the sidebar says which has turned. Scratch files; works with the
## screen locked.
##   SHOT_DIR=/tmp godot --path . --resolution 1600x900 -s tools/probes/screenshot_wild.gd
func _initialize() -> void:
	GameState.use_scratch_files("wildshot")
	GameState.clear_scratch_files()
	_run.call_deferred()

func _shot(name: String) -> void:
	for i in 14:
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
	var g := GameState.new(424242)
	g.new_game()
	g.depth = 5
	g.build_level()
	scene._bind_state(g)
	var o := Vector2i(g.player.x, g.player.y)
	for dy in range(-3, 4):
		for dx in range(-5, 6):
			g.map.set_tile(o.x + dx, o.y + dy, Tiles.FLOOR)
	var bear := GameState.monster_from(_by_name("cave bear"), o.x - 2, o.y - 1)
	var bun := GameState.monster_from(_by_name("rabbit"), o.x + 2, o.y - 1)
	var bat := GameState.monster_from(_by_name("cave bat"), o.x - 2, o.y + 2)
	var gob := GameState.monster_from(_by_name("goblin"), o.x + 2, o.y + 2)
	var angry := GameState.monster_from(_by_name("cave bear"), o.x + 3, o.y)
	angry.provoked = true
	for e in [bear, bun, bat, gob, angry]:
		e.alertness = Entity.Alert.AWAKE
	g.entities = [g.player, bear, bun, bat, gob, angry]
	g.pathfinder = Pathfinder.new(g.map)
	g._gather_lights()
	g.update_vision()
	Effects._mode = Effects.Mode.NONE
	scene._select_map_view(false)
	scene._refresh()
	await _shot("wild_classic.png")
	scene._select_map_view(true)
	scene._refresh()
	await _shot("wild_3d.png")
	GameState.clear_scratch_files()
	quit()
