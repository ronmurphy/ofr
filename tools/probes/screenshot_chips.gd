extends SceneTree

## RENDERS the look panel's state chips (2026-10-07): a hungry wild bear
## under the cursor ("wild" "hungry"), then a fed one ("wild"), then a bone
## ally ("yours"). Scratch files; works with the screen locked.
##   SHOT_DIR=/tmp godot --path . --resolution 1600x900 -s tools/probes/screenshot_chips.gd
func _initialize() -> void:
	GameState.use_scratch_files("chipshot")
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
	bear.alertness = Entity.Alert.AWAKE
	bear.hunger = Entity.HUNGRY_AT
	var bones := GameState.monster_from(_by_name("skeleton"), o.x + 2, o.y)
	bones.faction = Entity.Faction.PLAYER
	g.entities = [g.player, bear, bones]
	g.pathfinder = Pathfinder.new(g.map)
	g._gather_lights()
	g.update_vision()
	Effects._mode = Effects.Mode.NONE
	scene._select_map_view(false)
	scene._look = true
	scene._look_at = Vector2i(bear.x, bear.y)
	scene._refresh()
	await _shot("chips_hungry.png")
	bear.hunger = 0
	scene._refresh()
	await _shot("chips_fed.png")
	scene._look_at = Vector2i(bones.x, bones.y)
	scene._refresh()
	await _shot("chips_yours.png")
	GameState.clear_scratch_files()
	quit()
