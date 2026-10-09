extends SceneTree

## RENDERS the pixel look beside the picture look (2026-10-09): one room with
## a line of creatures, a tamed wolf (ally), a corrupted goblin, a body and
## some items, in the 3D view and the overhead view, pictures then pixel art.
## Scratch files; works with the screen locked.
##   SHOT_DIR=/tmp godot --path . --resolution 1600x900 -s tools/probes/screenshot_sprites.gd
func _initialize() -> void:
	GameState.use_scratch_files("spriteshot")
	GameState.clear_scratch_files()
	_run.call_deferred()

func _shot(name: String) -> void:
	for i in 14:
		await process_frame
		RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/" + name)

func _by_name(name: String) -> Dictionary:
	for e in GameState.BESTIARY:
		if e["name"] == name:
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
	var o := Vector2i(g.player.x, g.player.y)
	for dy in range(-4, 5):
		for dx in range(-6, 7):
			g.map.set_tile(o.x + dx, o.y + dy, Tiles.FLOOR)
	var line := ["giant rat", "kobold", "goblin", "orc", "cave troll", "skeleton",
		"wolf", "cave bear", "rabbit", "cave bat", "young dragon"]
	var placed: Array = [g.player]
	var spots := [Vector2i(-5, -3), Vector2i(-3, -3), Vector2i(-1, -3), Vector2i(1, -3),
		Vector2i(3, -3), Vector2i(5, -3), Vector2i(-5, 1), Vector2i(-3, 1),
		Vector2i(3, 1), Vector2i(5, 1), Vector2i(4, -1)]
	for i in line.size():
		var e := GameState.monster_from(_by_name(line[i]), o.x + spots[i].x, o.y + spots[i].y)
		e.alertness = Entity.Alert.AWAKE
		placed.append(e)
	var tame := GameState.monster_from(_by_name("wolf"), o.x - 1, o.y + 1)
	tame.faction = Entity.Faction.PLAYER
	placed.append(tame)
	var bad := GameState.monster_from(_by_name("goblin"), o.x + 1, o.y + 1)
	bad.corrupted = true
	placed.append(bad)
	g.entities = placed
	g.bodies.append({"x": o.x - 2, "y": o.y + 3, "app": "orc", "turn": g.turns,
		"corrupted": false})
	g.ground.clear()
	var stuff := [[&"short_sword", Vector2i(-4, 3)], [&"potion_healing", Vector2i(0, 3)],
		[&"gem_fire", Vector2i(2, 3)], [&"meat", Vector2i(4, 3)], [&"kite_shield", Vector2i(-6, 3)]]
	for row in stuff:
		var it := Item.make(row[0])
		it.x = o.x + (row[1] as Vector2i).x
		it.y = o.y + (row[1] as Vector2i).y
		g.ground.append(it)
	g.pathfinder = Pathfinder.new(g.map)
	g._gather_lights()
	g.update_vision()
	Effects._mode = Effects.Mode.NONE
	RenderTheme._overhead = false
	scene._select_map_view(true)
	for sprites in [false, true]:
		RenderTheme._sprites = sprites
		PixelSprites.reload()
		for over in [false, true]:
			scene.diorama.set_overhead(over)
			scene.diorama.forget_metrics()
			scene._refresh()
			await _shot("sprites_%s_%s.png" % ["pixels" if sprites else "pictures",
				"overhead" if over else "3d"])
	GameState.clear_scratch_files()
	quit()
