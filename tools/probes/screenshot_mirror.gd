extends SceneTree

## RENDERS the mirror tell beside the player, in both views: a kobold holding
## a mirror shield (the blue frame), a red-marked goblin holding one (red
## frame, mirror inside -- in 3D the two take turns), a plain kobold for
## contrast, and a mirror shield lying on the floor (it shines where it lies).
## On still, one PNG per view; on full, a strip of frames across one lap of
## the shine, for a GIF. Scratch files; works with the screen locked.
##   SHOT_DIR=/tmp godot --path . --resolution 1600x900 -s tools/probes/screenshot_mirror.gd
const FRAMES := 12

func _initialize() -> void:
	GameState.use_scratch_files("mirrorshot")
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
	var g := GameState.new(424242)
	g.new_game()
	g.depth = 5
	g.build_level()
	scene._bind_state(g)
	var o := Vector2i(g.player.x, g.player.y)
	for dy in range(-3, 4):
		for dx in range(-5, 6):
			g.map.set_tile(o.x + dx, o.y + dy, Tiles.FLOOR)
	var mirror_k := GameState.monster_from(GameState.BESTIARY[1], o.x - 2, o.y - 1)
	var m1 := Item.make(&"buckler")
	m1.element = &"reflect"
	mirror_k.equipped[Item.Slot.OFFHAND] = m1
	mirror_k.inventory.append(m1)
	var red_g := GameState.monster_from(GameState.BESTIARY[4], o.x + 2, o.y - 1)
	red_g.take_spores(&"red")
	var m2 := Item.make(&"kite_shield")
	m2.element = &"reflect"
	red_g.equipped[Item.Slot.OFFHAND] = m2
	red_g.inventory.append(m2)
	var plain_k := GameState.monster_from(GameState.BESTIARY[1], o.x + 2, o.y + 2)
	g.entities = [g.player, mirror_k, red_g, plain_k]
	var lying := Item.make(&"tower_shield")
	lying.element = &"reflect"
	lying.x = o.x - 2
	lying.y = o.y + 2
	g.ground.append(lying)
	var sword := Item.make(&"short_sword")
	sword.element = &"fire"
	sword.x = o.x
	sword.y = o.y + 2
	g.ground.append(sword)
	g.pathfinder = Pathfinder.new(g.map)
	g._gather_lights()
	g.update_vision()

	Effects._mode = Effects.Mode.NONE
	scene._select_map_view(false)
	scene._refresh()
	await _shot("mirror_still_classic.png")
	scene._select_map_view(true)
	scene._refresh()
	await _shot("mirror_still_3d.png")

	Effects._mode = Effects.Mode.SHADERS
	var lap := maxf(CreatureMarks.MIRROR_PERIOD, CreatureMarks.MIRROR_TURN * 2.0)
	for view in [false, true]:
		scene._select_map_view(view)
		scene._refresh()
		for i in FRAMES:
			var t := lap * i / FRAMES
			scene.grid.anim_time = t
			scene.diorama.anim_time = t
			scene.grid.queue_redraw()
			await _shot("mirror_full_%s_%02d.png" % ["3d" if view else "classic", i])
	scene.grid.anim_time = -1.0
	scene.diorama.anim_time = -1.0
	GameState.clear_scratch_files()
	quit()
