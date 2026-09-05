extends SceneTree

## Dev tool: writes every synthesized sound out as a .wav so the palette can be
## listened to without playing to depth three to hear one of them.
##   godot --headless --script res://tests/audition.gd -- /path/to/outdir
##
## Also loads the real scene, which is the only way to find out that the deck
## fails to start.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp"

	var scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for _i in 10:
		await process_frame
	var deck: SoundDeck = scene.get_node("Sound")
	print("  deck started with %d voices" % deck._bank.size())

	print("")
	print("  %-10s %7s %7s %8s   %s" % ["sound", "secs", "peak", "kB", "file"])
	var ids: Array = Synth.SOUNDS.keys()
	ids.sort()
	for id in ids:
		var stream: AudioStreamWAV = deck._bank[id]
		var secs := float(stream.data.size() / 2) / float(Synth.RATE)
		var peak := 0.0
		var rms := 0.0
		var d := stream.data
		for i in range(0, d.size(), 2):
			var v := absf(float(d.decode_s16(i)) / 32768.0)
			peak = maxf(peak, v)
			rms += v * v
		rms = sqrt(rms / float(d.size() / 2))
		var path := "%s/%s.wav" % [out, id]
		stream.save_to_wav(path)
		print("  %-10s %7.3f %7.2f %8.1f   %s (rms %.2f)"
			% [id, secs, peak, float(d.size()) / 1024.0, path.get_file(), rms])

	# Play them through the real deck, in order, so any runtime fault in the
	# pool or the bus shows up here rather than in a play session.
	for id in ids:
		deck.play(id)
		await process_frame
	await process_frame
	print("")
	print("  all %d played through the deck without fault" % ids.size())
	quit(0)
