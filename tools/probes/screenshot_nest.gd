extends SceneTree

## RENDERS a spider's nest (2026-10-10, for Brad and the Legion): a cave, the
## egg sac at the nest's heart with the webs the game strings round it
## (GameState._make_a_nest, the real thing), the spider beside it, a bat
## nearby, and the player at the nest's edge with the torch lit. Four shots:
## the 3D view, the overhead view, and both again under the pixel look.
## Scratch files; works with the screen locked.
##   SHOT_DIR=/tmp godot --path . --resolution 1600x900 -s tools/probes/screenshot_nest.gd
func _initialize() -> void:
	GameState.use_scratch_files("nestshot")
	GameState.clear_scratch_files()
	_run.call_deferred()

func _shot(name: String) -> void:
	for i in 14:
		await process_frame
		RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/" + name)

func _row(app: StringName) -> Dictionary:
	for e in GameState.BESTIARY:
		if e["app"] == app:
			return e
	return {}

func _run() -> void:
	var scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.name_entry.visible = false
	var g := GameState.new(424242)
	g.new_game()
	g.depth = 5
	g.build_level()
	scene._bind_state(g)
	# A cave: rough rock round an open floor, the player at its west end.
	var o := Vector2i(g.player.x, g.player.y)
	var cave := Rect2i(o - Vector2i(3, 4), Vector2i(15, 9))
	for y in range(cave.position.y - 1, cave.end.y + 1):
		for x in range(cave.position.x - 1, cave.end.x + 1):
			var inside := cave.has_point(Vector2i(x, y))
			# Ragged edges: a few rocks bite into the corners.
			var corner := (x - cave.position.x) + (y - cave.position.y) < 2 \
				or (cave.end.x - 1 - x) + (cave.end.y - 1 - y) < 2
			g.map.set_tile(x, y, Tiles.CAVE_FLOOR if inside and not corner else Tiles.ROCK)
	g.ground.clear()
	var spider := GameState.monster_from(_row(&"spider"), o.x + 5, o.y)
	var bat := GameState.monster_from(_row(&"bat"), o.x + 8, o.y - 3)
	g.entities = [g.player, spider, bat]
	g._make_a_nest(spider, cave)
	g.torch_lit = true
	g.pathfinder = Pathfinder.new(g.map)
	g._gather_lights()
	g.update_vision()
	# The whole cave in view, so the nest shows beyond the torch's circle --
	# it stays dark there, as a cave is, but seen.
	for y in range(cave.position.y, cave.end.y):
		for x in range(cave.position.x, cave.end.x):
			g.map.show_cell(x, y)
	Effects._mode = Effects.Mode.NONE
	scene._select_map_view(true)
	for pixels in [false, true]:
		RenderTheme._sprites = pixels
		PixelSprites.reload()
		for over in [false, true]:
			scene.diorama.set_overhead(over)
			scene.diorama.forget_metrics()
			scene._refresh()
			await _shot("nest_%s_%s.png" % ["pixels" if pixels else "pictures",
				"overhead" if over else "3d"])
	RenderTheme._sprites = false
	GameState.clear_scratch_files()
	quit()
