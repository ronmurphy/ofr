extends SceneTree

## RENDERS the latched gate in the 3D view (2026-10-09): a shut gate and an
## open one beside a plain door, for comparison. Scratch files; works with
## the screen locked.
##   SHOT_DIR=/tmp godot --path . --resolution 1600x900 -s tools/probes/screenshot_gate.gd
func _initialize() -> void:
	GameState.use_scratch_files("gateshot")
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
	g.depth = 2
	g.build_level()
	scene._bind_state(g)
	var o := Vector2i(g.player.x, g.player.y)
	for dy in range(-4, 5):
		for dx in range(-6, 7):
			g.map.set_tile(o.x + dx, o.y + dy, Tiles.FLOOR)
	# A wall two rows up with three doorways: door, shut gate, open gate.
	for dx in range(-6, 7):
		g.map.set_tile(o.x + dx, o.y - 2, Tiles.WALL)
	g.map.set_tile(o.x - 3, o.y - 2, Tiles.DOOR_CLOSED)
	g.map.set_tile(o.x, o.y - 2, Tiles.GATE_CLOSED)
	g.map.set_tile(o.x + 3, o.y - 2, Tiles.GATE_OPEN)
	g.entities = [g.player]
	g.pathfinder = Pathfinder.new(g.map)
	g._gather_lights()
	g.update_vision()
	Effects._mode = Effects.Mode.NONE
	scene._select_map_view(true)
	scene._refresh()
	await _shot("gate_3d.png")
	GameState.clear_scratch_files()
	quit()
