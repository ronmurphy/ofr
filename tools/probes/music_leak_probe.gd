extends SceneTree

## Reproduces the one "leaked object" Godot reports at every quit since the
## music (BACKLOG, Known gaps): an AudioStreamGeneratorPlayback still playing
## when the program ends. Engine-side and harmless. LEAK_MODE=scene or deck.
##   LEAK_MODE=deck godot --headless --path . -s tools/probes/music_leak_probe.gd
func _initialize() -> void:
	GameState.use_scratch_files("leak")
	var mode := OS.get_environment("LEAK_MODE")
	if mode == "scene":
		var scene: Control = load("res://scenes/main.tscn").instantiate()
		root.add_child(scene)
	else:
		var deck := SoundDeck.new()
		root.add_child(deck)
		for i in 3:
			await process_frame
		if not deck.music_on:
			deck.toggle_music()
		deck.sync_music(1)
	for i in 10:
		await process_frame
	GameState.clear_scratch_files()
	quit()
