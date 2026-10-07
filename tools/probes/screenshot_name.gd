extends SceneTree

## RENDERS the name screen (pad list + alphabet) to a PNG. Same needs as
## screenshot_trade.gd: a real display and an unlocked screen.
##   SHOT_OUT=/tmp/name.png SHOT_PAD=1 godot --path . --resolution 1600x900 -s tools/probes/screenshot_name.gd
func _initialize() -> void:
	GameState.use_scratch_files("shot")
	_run.call_deferred()
func _run() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1600, 900)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.06)
	bg.size = Vector2(1600, 900)
	vp.add_child(bg)
	var n := NamePanel.new()
	vp.add_child(n)
	n.size = Vector2(1600, 900)
	n.open()
	n.pad_cfg = PadConfig.new()
	n.pad_input = OS.get_environment("SHOT_PAD") == "1"
	for a in [&"down", &"down", &"down", &"right", &"press", &"right", &"right", &"press"]:
		n.pad_act(a)
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(OS.get_environment("SHOT_OUT"))
	# Leave nothing in the player's save folder (2026-10-07).
	GameState.clear_scratch_files()
	quit()
