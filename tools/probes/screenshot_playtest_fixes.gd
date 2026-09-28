extends SceneTree

## RENDERS the playtest fixes in the real scene: the player in water on floor 1
## (the status line and the HERE header), a fresh player's gold help hint, and
## the sidebar's menu button. Scratch files; works with the screen locked.
##   SHOT_OUT=/tmp/pt.png godot --path . --resolution 1600x900 -s tools/probes/screenshot_playtest_fixes.gd
func _initialize() -> void:
	GameState.use_scratch_files("ptshot")
	GameState.clear_scratch_files()
	_run.call_deferred()
func _run() -> void:
	var scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	LegendPanel.forget_seen()
	var s: GameState = scene.state
	s.map.set_tile(s.player.x, s.player.y, Tiles.WATER)
	scene.name_entry.close() if scene.name_entry.has_method("close") else null
	# SHOT_PAD=1: as a controller player sees it.
	scene._pad_input = OS.get_environment("SHOT_PAD") == "1"
	scene._refresh()
	for i in 12:
		await process_frame
		RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_OUT"))
	GameState.clear_scratch_files()
	quit()
