extends SceneTree

## RENDERS the F8 pad watch to a PNG, with a fake Firefox-style push fed in.
## Works with the screen locked (force_draw); needs a real display.
##   SHOT_OUT=/tmp/padwatch.png godot --path . --resolution 1600x900 -s tools/probes/screenshot_padwatch.gd
func _initialize() -> void:
	GameState.use_scratch_files("shot")
	_run.call_deferred()
func _run() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1600, 900)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.06)
	bg.size = Vector2(1600, 900)
	vp.add_child(bg)
	var w := PadWatch.new()
	vp.add_child(w)
	w.position = Vector2(12, 12)
	w.toggle()
	w.set_process(false)
	w.sample(PackedFloat32Array([0, 0, 0, 0, 0.5, 0.5, 0, 0, 0, 0]))
	w.sample(PackedFloat32Array([0, 0, 0, 0, 1.0, 0.5, 0, 0, 0, 0]))
	w.camera_line = "camera: RX +0.00 LT +1.00 RT +0.50 firefox-mode -> +1.00"
	w._note("device 0  axis 4 at +1.00")
	w._ever[3] = true
	# force_draw rather than awaiting frame_post_draw: with the screen locked
	# the window cannot draw, so the engine skips drawing and that signal
	# never comes. process_frame still does, and lets _draw run.
	for i in 4:
		await process_frame
		RenderingServer.force_draw(false)
	vp.get_texture().get_image().save_png(OS.get_environment("SHOT_OUT"))
	quit()
