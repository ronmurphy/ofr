extends SceneTree

## Drives the REAL scene's title screen with keypresses and screenshots each
## step. Scratch files, so nothing the player owns is read or written.
##   SHOT_DIR=/tmp godot --path . --resolution 1600x900 -s tools/probes/title_flow.gd
var scene: Control
func _initialize() -> void:
	GameState.use_scratch_files("titleflow")
	GameState.clear_scratch_files()
	_run.call_deferred()

func _key(k: int) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.pressed = true
	scene._unhandled_key_input(e)

func _shot(name: String) -> void:
	for i in 12:
		await process_frame
		RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/" + name)

func _run() -> void:
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	# The harness skips the title, so open it by hand -- as a player with a
	# suspended run and one escape would see it.
	scene.title.open(true, true, 7)
	print("title up: ", scene.title.visible, "  rows: ", scene.title.rows().map(func(r): return r[1]))
	await _shot("t1_main.png")
	_key(KEY_DOWN); _key(KEY_DOWN); _key(KEY_DOWN); _key(KEY_ENTER)
	print("page: ", scene.title.page, "  rows: ", scene.title.rows().map(func(r): return "%s=%s" % [r[1], r[2]]))
	_key(KEY_DOWN); _key(KEY_ENTER)
	print("after effects press: ", scene.title.rows()[1][2])
	await _shot("t2_settings.png")
	_key(KEY_ESCAPE)
	print("back to: ", scene.title.page)
	_key(KEY_DOWN); _key(KEY_DOWN); _key(KEY_ENTER)
	print("legends note: ", scene.title.note)
	_key(KEY_UP); _key(KEY_ENTER)
	print("new armed: ", scene.title._new_armed, "  title still up: ", scene.title.visible)
	await _shot("t3_armed.png")
	_key(KEY_ENTER)
	print("after second press: title ", scene.title.visible, "  name entry ", scene.name_entry.visible)
	await _shot("t4_name.png")
	GameState.clear_scratch_files()
	quit()
