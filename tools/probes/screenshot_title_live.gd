extends SceneTree

## RENDERS the title as the GAME shows it: the real main scene, with its own
## 3D view underneath and, if the save folder holds a suspend.save, the
## "continue" row. The title probe builds the title alone, which hid a bug
## where the hall painted the game's view over itself. Works with the screen
## locked.
##   SHOT_OUT=/tmp/title_live.png godot --path . --resolution 1600x900 --rendering-method forward_plus -s tools/probes/screenshot_title_live.gd
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	# OFR_SHOT=post puts the hall's last pass back, to show the bug it had.
	if OS.get_environment("OFR_SHOT") == "post" and scene.title.home != null:
		scene.title.home._post.visible = true
	for i in 40:
		await process_frame
		RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_OUT"))
	quit()
