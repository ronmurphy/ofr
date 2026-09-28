extends SceneTree

## RENDERS three bodies beside the player -- fresh, half rotted, nearly gone --
## in both views. Scratch files; works with the screen locked.
##   SHOT_DIR=/tmp godot --path . --resolution 1600x900 -s tools/probes/screenshot_bodies.gd
func _initialize() -> void:
	GameState.use_scratch_files("bodyshot")
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
	var fixed := GameState.new(424242)
	fixed.new_game()
	scene._bind_state(fixed)
	var s: GameState = scene.state
	s.turns = 200
	var ages := [0, 60, 110]
	var apps := ["kobold", "rat", "goblin"]
	for i in 3:
		s.bodies.append({"x": s.player.x - 1 + i, "y": s.player.y + 1, "app": apps[i],
			"turn": s.turns - ages[i], "corrupted": false, "e": {}})
	s.update_vision()
	scene._select_map_view(false)
	scene._refresh()
	await _shot("bodies_classic.png")
	scene._select_map_view(true)
	scene._refresh()
	await _shot("bodies_3d.png")
	GameState.clear_scratch_files()
	quit()
