extends SceneTree

## Renders the in-game procedural ambience as standalone listening previews.
## These WAVs are not referenced by the game.
##   godot --headless --path . --script res://tools/export_ambience_previews.gd

const OUTPUT_DIR := "res://assets/audio/previews"
const PREVIEW_PEAK := 0.65
const CLIPS := [
	{"name": "title", "title": true},
	{"name": "upper", "depth": 1},
	{"name": "caves", "depth": 4},
	{"name": "fortress", "depth": 7},
	{"name": "deep", "depth": 10},
	{"name": "fortress_corrupted", "depth": 11},
	{"name": "caves_corrupted", "depth": 14},
	{"name": "upper_corrupted", "depth": 17},
]

func _initialize() -> void:
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR)
	if not DirAccess.dir_exists_absolute(output_path):
		var mkdir_error := DirAccess.make_dir_recursive_absolute(output_path)
		if mkdir_error != OK:
			push_error("Could not create %s (error %d)." % [output_path, mkdir_error])
			quit(1)
			return

	for clip in CLIPS:
		var profile: Dictionary
		if bool(clip.get("title", false)):
			profile = Synth.title_music_profile()
		else:
			profile = Synth.music_profile(int(clip["depth"]))
		var stream := _render(profile)
		var path := output_path.path_join("%s.wav" % clip["name"])
		var save_error := stream.save_to_wav(path)
		if save_error != OK:
			push_error("Could not write %s (error %d)." % [path, save_error])
			quit(1)
			return
		print("Wrote %s" % path)
	quit(0)

func _render(profile: Dictionary) -> AudioStreamWAV:
	var count := int(Synth.MUSIC_LOOP_SECONDS * float(Synth.MUSIC_RATE))
	var samples := PackedFloat32Array()
	samples.resize(count)
	var peak := 0.0
	for i in count:
		var sample := Synth.music_sample(profile, float(i) / float(Synth.MUSIC_RATE))
		samples[i] = sample
		peak = maxf(peak, absf(sample))

	# The game deliberately plays the score well below its short effects. Raise
	# each preview to the same peak for standalone playback; this changes level,
	# not its pitches, rhythm or texture.
	var scale := PREVIEW_PEAK / maxf(peak, 0.0001)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var sample := clampf(samples[i] * scale, -1.0, 1.0)
		data.encode_s16(i * 2, int(round(sample * 32767.0)))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = Synth.MUSIC_RATE
	stream.stereo = false
	stream.data = data
	return stream
