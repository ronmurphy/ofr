extends SceneTree

## RENDERS the 3D look: a room with a brazier, water, both wrong fungi, a
## risen and a rat beside the player, in the 3D view. Scratch files; works
## with the screen locked. Run it once per renderer to see the two tiers:
##   SHOT_DIR=/tmp godot --path . --resolution 1600x900 --rendering-method gl_compatibility -s tools/probes/screenshot_look.gd
##   SHOT_DIR=/tmp godot --path . --resolution 1600x900 --rendering-method forward_plus -s tools/probes/screenshot_look.gd
func _initialize() -> void:
	GameState.use_scratch_files("lookshot")
	GameState.clear_scratch_files()
	_run.call_deferred()

func _shot(name: String) -> void:
	for i in 24:
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
	# A room: floor round the player, walls on two sides, a doorway.
	for dy in range(-6, 5):
		for dx in range(-7, 7):
			g.map.set_tile(o.x + dx, o.y + dy, Tiles.FLOOR)
	for dx in range(-7, 7):
		g.map.set_tile(o.x + dx, o.y - 6, Tiles.WALL)
	g.map.set_tile(o.x + 2, o.y - 6, Tiles.FLOOR)
	g.map.set_tile(o.x + 2, o.y - 7, Tiles.FLOOR)
	for dy in range(-6, 5):
		g.map.set_tile(o.x - 7, o.y + dy, Tiles.WALL)
	g.map.set_tile(o.x + 1, o.y, Tiles.PILLAR)
	g.map.set_tile(o.x - 4, o.y - 4, Tiles.BRAZIER)
	g.brazier_charge[Vector2i(o.x - 4, o.y - 4)] = 10
	for c in [Vector2i(4, 1), Vector2i(5, 1), Vector2i(5, 2), Vector2i(4, 2)]:
		g.map.set_tile(o.x + c.x, o.y + c.y, Tiles.WATER)
	for c in [Vector2i(-2, 3), Vector2i(-1, 3)]:
		g.map.set_tile(o.x + c.x, o.y + c.y, Tiles.FUNGUS_PURPLE)
	for c in [Vector2i(3, -4), Vector2i(4, -4), Vector2i(4, -3)]:
		g.map.set_tile(o.x + c.x, o.y + c.y, Tiles.FUNGUS_RED)
	g.map.set_tile(o.x + 5, o.y - 2, Tiles.RUBBLE)
	g.map.set_tile(o.x + 1, o.y - 4, Tiles.BONES)
	g.map.set_tile(o.x - 5, o.y + 2, Tiles.FUNGUS)
	g.entities = [g.player]
	var risen := GameState.monster_from(GameState.BESTIARY[1], o.x + 3, o.y - 3)
	risen.faction = Entity.Faction.RISEN
	risen.fungal = true
	risen.raised = true
	risen.spores = &"red"
	risen.name = "risen kobold"
	var rat := GameState.monster_from(GameState.BESTIARY[0], o.x - 4, o.y + 1)
	g.entities = [g.player, risen, rat]
	g.pathfinder = Pathfinder.new(g.map)
	g.torch_lit = true
	g._gather_lights()
	g.update_vision()
	# Closer than the default, so surfaces can be judged.
	RenderTheme.set_cell_size(32)
	scene._select_map_view(true)
	scene._refresh()
	var tier := RenderingServer.get_current_rendering_method()
	var tag := ""
	# Diagnostics: OFR_SHOT=nopost drops the last pass, =noglow the glow.
	if OS.get_environment("OFR_SHOT") == "nopost":
		scene.diorama._post.visible = false
		tag = "_nopost"
	elif OS.get_environment("OFR_SHOT") == "noglow":
		scene.diorama._environment.glow_enabled = false
		tag = "_noglow"
	await _shot("look_%s%s.png" % [tier, tag])
	# And the same scene from overhead.
	scene.diorama.set_overhead(true)
	scene._refresh()
	await _shot("look_%s%s_overhead.png" % [tier, tag])
	GameState.clear_scratch_files()
	quit()
