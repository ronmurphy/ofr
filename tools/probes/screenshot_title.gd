extends SceneTree

## RENDERS the title screen to a PNG. Works with the screen locked (force_draw).
##   SHOT_OUT=/tmp/title.png SHOT_SEED=7 SHOT_PAGE=settings godot --path . --resolution 1600x900 -s tools/probes/screenshot_title.gd
func _initialize() -> void:
	GameState.use_scratch_files("shot")
	_run.call_deferred()
func _run() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1600, 900)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var t := TitleScreen.new()
	vp.add_child(t)
	t.size = Vector2(1600, 900)
	var started := Time.get_ticks_msec()
	t.open(true, OS.get_environment("SHOT_LEGENDS") == "1",
		int(OS.get_environment("SHOT_SEED")) if OS.get_environment("SHOT_SEED") != "" else 7)
	print("backdrop built in %d ms" % (Time.get_ticks_msec() - started))
	if OS.get_environment("SHOT_PAGE") == "settings":
		t.value_of = func(id: StringName) -> String: return {&"3d": "3D", &"effects": "full",
			&"sound": "on", &"text": "24", &"pad": ""}.get(id, "")
		t.activate(t.rows().size() - 2)
	for i in 30:
		await process_frame
		RenderingServer.force_draw(false)
	vp.get_texture().get_image().save_png(OS.get_environment("SHOT_OUT"))
	quit()
