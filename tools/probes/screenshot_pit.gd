extends SceneTree

## RENDERS a pit beside the player in both views, to judge whether it can be
## seen. Scratch files; works with the screen locked.
##   SHOT_DIR=/tmp godot --path . --resolution 1600x900 -s tools/probes/screenshot_pit.gd
func _initialize() -> void:
	GameState.use_scratch_files("pitshot")
	GameState.clear_scratch_files()
	_run.call_deferred()

func _shot(scene: Control, name: String) -> void:
	for i in 14:
		await process_frame
		RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/" + name)

func _run() -> void:
	var scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.name_entry.visible = false
	# A fixed floor, so shots compare between runs.
	var fixed := GameState.new(424242)
	fixed.new_game()
	scene._bind_state(fixed)
	var s: GameState = scene.state
	# A pit two cells east of the player, and a trap two cells west, on floor.
	for d in [Vector2i(2, 0), Vector2i(-2, 0)]:
		var c: Vector2i = Vector2i(s.player.x, s.player.y) + d
		if not s.map.is_walkable(c.x, c.y):
			print("not floor at ", c)
	# The pit in open floor -- every neighbour floor -- so no wall covers it.
	var pit_at := Vector2i(-1, -1)
	for r in range(1, 4):
		for off in [Vector2i(r, 0), Vector2i(0, r), Vector2i(-r, 0), Vector2i(0, -r)]:
			var c: Vector2i = Vector2i(s.player.x, s.player.y) + off
			var open := true
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					open = open and s.map.get_tile(c.x + dx, c.y + dy) == Tiles.FLOOR
			if open and pit_at.x < 0:
				pit_at = c
	print("pit at ", pit_at, " player at ", Vector2i(s.player.x, s.player.y))
	s.map.set_tile(pit_at.x, pit_at.y, Tiles.PIT)
	s.map.set_tile(s.player.x - 2, s.player.y, Tiles.TRAP)
	s.update_vision()
	scene._select_map_view(false)
	scene._refresh()
	await _shot(scene, "pit_classic.png")
	scene._select_map_view(true)
	scene._refresh()
	await _shot(scene, "pit_3d.png")
	# And aiming, with a reach of 5: the floor shows how far a shot goes.
	scene._begin_aim(5)
	await _shot(scene, "aim_3d.png")
	scene._select_map_view(false)
	scene._refresh()
	await _shot(scene, "aim_classic.png")
	GameState.clear_scratch_files()
	quit()
