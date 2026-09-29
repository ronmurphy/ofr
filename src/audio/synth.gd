class_name Synth
extends RefCounted

## There are no audio files. Short effects are rendered into a small PCM bank
## at startup; the background bed is synthesized a sample at a time while it
## plays.
##
## Three reasons, in order of how much they mattered:
##
## 1. The screen is a font and a colour table. A recorded door hinge would be
##    the only literal thing in the entire game, and it would sound like it had
##    wandered in from somewhere else. A square wave belongs next to a `@`.
## 2. A voice is a Dictionary, so sound is tuned in a text editor beside the
##    tile table and the bestiary rather than in an audio program. That keeps
##    the whole game editable the same way.
## 3. Nothing to license, nothing to ship, nothing to load.
##
## The synthesis is deliberately primitive -- oscillator, one-pole lowpass,
## sample-and-hold, exponential decay. That is the entire toolkit, and it is
## enough, because the ear needs far less than people assume to tell a snapping
## mechanism from a breaking bone.

## 22kHz. Nothing here has meaningful content above 11kHz, and halving the rate
## halves both the render cost at startup and the memory the bank sits in.
const RATE := 22050

## What a `gain` of 1.0 is worth, measured as RMS. Sounds are normalised onto
## this scale rather than played at whatever amplitude their voices happened to
## sum to -- see `render`.
const REFERENCE_RMS := 0.18
## Nothing is allowed nearer the rail than this, whatever its gain asks for.
const CEILING := 0.95
## Roughly how long the ear integrates before it calls something loud. Without
## a fixed window, a 60ms click and a 1.3s fall get compared on completely
## different terms and the short one always loses.
const LOUDNESS_WINDOW := 0.25

## The background bed is streamed rather than baked into WAV files. 11.025kHz
## suits these low, deliberately grainy tones and keeps the GDScript generator
## light enough to refill in small chunks.
const MUSIC_RATE := 11025
const MUSIC_LOOP_SECONDS := 16.0

## One small phrase per band. The same phrase returns on the climb with a few
## notes bent upward and a close, semitone undertone -- the way back through a
## familiar place that has shifted while you were below.
const MUSIC_PROFILES := {
	Bands.UPPER: {
		"root": 110.0, "scale": [0, 3, 7, 10, 12],
		"motif": [0, 2, 3, 2, 1, 0, 2, 4], "wave": &"triangle",
		"bass_gain": 0.095, "lead_gain": 0.075, "air_gain": 0.018,
		"air_ratio": 3.0, "harmonic_gain": 0.16,
	},
	Bands.CAVES: {
		"root": 82.41, "scale": [0, 1, 5, 7, 8],
		"motif": [0, 1, 2, 1, 3, 2, 1, 0], "wave": &"sine",
		"bass_gain": 0.105, "lead_gain": 0.060, "air_gain": 0.030,
		"air_ratio": 1.4142, "harmonic_gain": 0.08,
	},
	Bands.FORTRESS: {
		"root": 98.0, "scale": [0, 3, 5, 7, 10],
		"motif": [0, 2, 1, 2, 3, 2, 1, 4, 0, 2, 1, 2, 3, 2, 4, 1],
		"wave": &"pulse", "bass_gain": 0.085, "lead_gain": 0.050,
		"air_gain": 0.018, "air_ratio": 2.01, "harmonic_gain": 0.10,
	},
	Bands.DEEP: {
		"root": 55.0, "scale": [0, 1, 6, 7],
		"motif": [0, 1, 2, 1], "wave": &"sine",
		"bass_gain": 0.125, "lead_gain": 0.048, "air_gain": 0.033,
		"air_ratio": 1.4142, "harmonic_gain": 0.12,
	},
}

## A more settled phrase for the hall above the dungeon: open fifths and
## suspended notes keep it welcoming without turning the level-up triad into
## background harmony. It still uses the same small oscillator palette.
const TITLE_MUSIC_PROFILE := {
	"root": 65.406, "scale": [0, 2, 5, 7, 9],
	"motif": [0, 3, 4, 2, 1, 2, 3, 0], "wave": &"sine",
	"bass_gain": 0.075, "lead_gain": 0.082, "air_gain": 0.018,
	"air_ratio": 3.0, "harmonic_gain": 0.08,
	"attack": 0.16, "decay": 2.5,
}

## Builds the few per-theme values that are constant during playback. Keeping
## exponentiation out of the sample loop matters more than it sounds in GDScript.
static func music_profile(effective_depth: int) -> Dictionary:
	var band := Bands.of(effective_depth)
	var profile: Dictionary = MUSIC_PROFILES[band].duplicate(true)
	var corrupted := Bands.is_corrupted(effective_depth)
	return _with_music_cycles(profile, band, corrupted)

## The title cue is selected by the front door, then the current band takes
## over when a run is loaded or started.
static func title_music_profile() -> Dictionary:
	return _with_music_cycles(TITLE_MUSIC_PROFILE.duplicate(true), -1, false)

static func _with_music_cycles(profile: Dictionary, band: int,
		corrupted: bool) -> Dictionary:
	var root_hz := float(profile["root"])
	var scale: Array = profile["scale"]
	var motif: Array = profile["motif"]
	var lead_cycles := PackedInt32Array()
	for i in motif.size():
		var semitone := int(scale[int(motif[i])])
		# Two notes in each returning phrase lean a little too bright, like a
		# memory of the original tune that cannot quite settle back into place.
		if corrupted and (i == 3 or i == motif.size() - 1):
			semitone += 1
		var hz := root_hz * 2.0 * pow(2.0, float(semitone) / 12.0)
		lead_cycles.append(int(round(hz * MUSIC_LOOP_SECONDS)))
	profile["band"] = band
	profile["corrupted"] = corrupted
	profile["lead_cycles"] = lead_cycles
	profile["bass_cycles"] = int(round(root_hz * 0.5 * MUSIC_LOOP_SECONDS))
	profile["air_cycles"] = int(round(root_hz * float(profile["air_ratio"])
		* MUSIC_LOOP_SECONDS))
	profile["discord_cycles"] = int(round(root_hz * pow(2.0, 1.0 / 12.0)
		* MUSIC_LOOP_SECONDS))
	profile["step_seconds"] = MUSIC_LOOP_SECONDS / float(motif.size())
	profile["discord_gain"] = 0.022 if corrupted else 0.0
	return profile

## One mono sample of the looping bed. Every oscillator completes an integer
## number of cycles in the 16-second phrase, so the drones meet themselves at
## the loop point. Note envelopes fade nearly to zero before their next pitch.
static func music_sample(profile: Dictionary, seconds: float) -> float:
	var t := fposmod(seconds, MUSIC_LOOP_SECONDS)
	var loop_phase := t / MUSIC_LOOP_SECONDS
	var bass_cycles := int(profile["bass_cycles"])
	var air_cycles := int(profile["air_cycles"])
	var sample := sin(TAU * float(bass_cycles) * loop_phase) \
		* float(profile["bass_gain"])
	sample += sin(TAU * float(air_cycles) * loop_phase) \
		* float(profile["air_gain"])

	var lead_cycles: PackedInt32Array = profile["lead_cycles"]
	var step_seconds := float(profile["step_seconds"])
	var note_index := mini(lead_cycles.size() - 1, int(t / step_seconds))
	var local := fposmod(t, step_seconds)
	var phase := fposmod(float(lead_cycles[note_index]) * loop_phase, 1.0)
	var lead_wave := 0.0
	match profile["wave"]:
		&"triangle":
			lead_wave = 1.0 - absf(phase * 4.0 - 2.0)
		&"pulse":
			var fundamental := sin(phase * TAU)
			lead_wave = fundamental * 0.78 + (0.22 if phase < 0.5 else -0.22)
		_:
			lead_wave = sin(phase * TAU)
	lead_wave += sin(phase * TAU * 2.0) * float(profile["harmonic_gain"])
	var attack := float(profile.get("attack", 0.075))
	var decay := float(profile.get("decay", 4.0))
	var envelope := minf(1.0, local / attack) * exp(-decay * local / step_seconds)
	sample += lead_wave * envelope * float(profile["lead_gain"])

	var discord_gain := float(profile["discord_gain"])
	if discord_gain > 0.0:
		sample += sin(TAU * float(profile["discord_cycles"]) * loop_phase) \
			* discord_gain
	return clampf(sample, -0.5, 0.5)

# ------------------------------------------------------------------ voices ---
#
# A voice is one oscillator with an envelope. A sound is a list of them, so
# layering is how character is built: the crunch is filtered noise plus two
# low clicks, and the clicks are what stop it sounding like radio static.
#
#   wave       sine | square | tri | saw | noise
#   f0, f1     start and end frequency; f1 defaults to f0 (no glide)
#   len        seconds
#   delay      seconds to wait before this voice starts
#   gain       0..1
#   attack     seconds of fade-in; a hard zero clicks, which sometimes helps
#   curve      decay steepness -- 2 is a bloom, 12 is a tick
#   lp         one-pole lowpass, 1.0 = off. Turns hiss into thud.
#   crush      sample-and-hold divisor, 1 = off. Granularity: this is the
#              difference between something BREAKING and something rushing.
#   wob_rate   vibrato in Hz, with
#   wob_depth  as a fraction of the frequency

const SOUNDS := {
	# The one that started this. Stepping on bones is the game's loudest act
	# and until now it was a line of text.
	&"crunch": {"gain": 0.85, "voices": [
		{"wave": &"noise", "f0": 1.0, "len": 0.16, "gain": 0.9,
			"curve": 9.0, "lp": 0.30, "crush": 5, "attack": 0.001},
		{"wave": &"square", "f0": 120.0, "f1": 74.0, "len": 0.05, "gain": 0.5,
			"curve": 11.0, "crush": 3, "attack": 0.0},
		{"wave": &"square", "f0": 96.0, "f1": 60.0, "len": 0.06, "gain": 0.4,
			"delay": 0.045, "curve": 10.0, "crush": 4, "attack": 0.0},
		{"wave": &"noise", "f0": 1.0, "len": 0.09, "gain": 0.35,
			"delay": 0.06, "curve": 12.0, "lp": 0.55, "crush": 7},
	]},

	# Pairs with the "!" over its head. Rising, because everything else that
	# matters here falls, and the ear sorts by direction before it sorts by
	# pitch.
	&"notice": {"gain": 0.55, "voices": [
		{"wave": &"square", "f0": 620.0, "f1": 660.0, "len": 0.055, "gain": 0.6,
			"curve": 5.0, "attack": 0.002},
		{"wave": &"square", "f0": 960.0, "f1": 1020.0, "len": 0.10, "gain": 0.55,
			"delay": 0.055, "curve": 4.0, "attack": 0.002},
	]},

	# Landing on you. Low and blunt: it should be felt somewhere below the
	# music of the rest of it.
	&"hurt": {"gain": 0.9, "voices": [
		{"wave": &"sine", "f0": 240.0, "f1": 84.0, "len": 0.20, "gain": 0.9,
			"curve": 6.0, "attack": 0.0},
		{"wave": &"noise", "f0": 1.0, "len": 0.07, "gain": 0.5,
			"curve": 13.0, "lp": 0.22, "crush": 3},
	]},

	# You landing one. Quiet on purpose -- you already know you swung, so this
	# is only confirming it connected, which matters when the target is off
	# screen or in the dark.
	&"hit": {"gain": 0.42, "voices": [
		{"wave": &"tri", "f0": 430.0, "f1": 300.0, "len": 0.06, "gain": 0.7,
			"curve": 10.0, "attack": 0.001},
		{"wave": &"noise", "f0": 1.0, "len": 0.035, "gain": 0.3,
			"curve": 14.0, "lp": 0.5, "crush": 2},
	]},

	# Something died. Falls further and slower than a hit, so "hurt it" and
	# "killed it" never have to be read off the log.
	&"kill": {"gain": 0.7, "voices": [
		{"wave": &"saw", "f0": 330.0, "f1": 62.0, "len": 0.26, "gain": 0.6,
			"curve": 5.0, "lp": 0.4, "attack": 0.002},
		{"wave": &"noise", "f0": 1.0, "len": 0.16, "gain": 0.32,
			"delay": 0.03, "curve": 7.0, "lp": 0.18, "crush": 6},
	]},

	# Your death. Long, slow, and the only sound in the game that takes its
	# time -- everything else is over in a fifth of a second.
	&"death": {"gain": 0.9, "voices": [
		{"wave": &"sine", "f0": 300.0, "f1": 52.0, "len": 1.30, "gain": 0.75,
			"curve": 2.2, "attack": 0.01, "wob_rate": 5.5, "wob_depth": 0.02},
		{"wave": &"sine", "f0": 151.0, "f1": 26.0, "len": 1.30, "gain": 0.45,
			"curve": 2.0, "attack": 0.02},
		{"wave": &"noise", "f0": 1.0, "len": 0.7, "gain": 0.18,
			"curve": 4.0, "lp": 0.09, "crush": 11},
	]},

	# A heartbeat, fired once on crossing below 30%. The slinger got its kill
	# because the health bar is at the edge of vision while you read the map;
	# this is the same warning arriving somewhere you cannot look away from.
	&"lowhp": {"gain": 0.75, "voices": [
		{"wave": &"sine", "f0": 96.0, "f1": 62.0, "len": 0.17, "gain": 0.9,
			"curve": 7.0, "attack": 0.004},
		{"wave": &"sine", "f0": 88.0, "f1": 55.0, "len": 0.24, "gain": 0.7,
			"delay": 0.20, "curve": 6.0, "attack": 0.004},
	]},

	# The only unambiguously good news in the game, so it is the only major
	# triad in it.
	&"levelup": {"gain": 0.55, "voices": [
		{"wave": &"tri", "f0": 523.0, "len": 0.11, "gain": 0.6, "curve": 4.0},
		{"wave": &"tri", "f0": 659.0, "len": 0.11, "gain": 0.6,
			"delay": 0.075, "curve": 4.0},
		{"wave": &"tri", "f0": 784.0, "len": 0.30, "gain": 0.6,
			"delay": 0.15, "curve": 3.0},
		{"wave": &"tri", "f0": 1046.0, "len": 0.34, "gain": 0.3,
			"delay": 0.15, "curve": 3.0},
	]},

	# A loosed shot. Short and high so it never masks the impact that follows
	# it a moment later.
	&"shot": {"gain": 0.5, "voices": [
		{"wave": &"noise", "f0": 1.0, "len": 0.05, "gain": 0.55,
			"curve": 12.0, "lp": 0.85, "crush": 2},
		{"wave": &"tri", "f0": 880.0, "f1": 1500.0, "len": 0.06, "gain": 0.35,
			"curve": 9.0, "attack": 0.001},
	]},

	# Metal, and fast. A trap is the one thing in the dungeon that happens to
	# you rather than because of you, and it should sound mechanical against a
	# world that is otherwise stone and meat.
	&"trap": {"gain": 0.85, "voices": [
		{"wave": &"square", "f0": 1750.0, "f1": 260.0, "len": 0.055, "gain": 0.6,
			"curve": 10.0, "attack": 0.0, "crush": 2},
		{"wave": &"square", "f0": 1310.0, "f1": 197.0, "len": 0.07, "gain": 0.4,
			"curve": 9.0, "attack": 0.0},
		{"wave": &"noise", "f0": 1.0, "len": 0.10, "gain": 0.45,
			"curve": 11.0, "lp": 0.75, "crush": 3},
	]},

	# Shrines get a bell, with a slow attack. Nothing else in the game fades
	# in, so a shrine firing is audibly a different category of event from
	# anything that can hit you.
	&"pray": {"gain": 0.6, "voices": [
		{"wave": &"sine", "f0": 528.0, "len": 1.0, "gain": 0.5,
			"curve": 3.2, "attack": 0.03},
		{"wave": &"sine", "f0": 792.0, "len": 0.85, "gain": 0.28,
			"curve": 3.8, "attack": 0.05},
		{"wave": &"sine", "f0": 1584.0, "len": 0.4, "gain": 0.10,
			"curve": 6.0, "attack": 0.02},
	]},

	# The shrine that calls out. A gong, not a bell, and the difference is
	# inharmonicity: a bell's partials sit near whole-number ratios and give it
	# a clear pitch, while a gong's do not, which is why it reads as a slab of
	# metal rather than a note. Ratios here are 1.73, 2.79 and 4.21 -- close
	# enough to hear as one object, far enough off to have no key.
	#
	# Long, slow to start and slow to die, so it sits under the other sounds
	# rather than competing with them. It replaces the bell for this shrine
	# instead of layering over it; both at once was mud.
	&"gong": {"gain": 0.8, "voices": [
		{"wave": &"sine", "f0": 116.0, "len": 2.6, "gain": 0.55,
			"curve": 1.9, "attack": 0.045},
		{"wave": &"sine", "f0": 201.0, "len": 2.2, "gain": 0.30,
			"curve": 2.3, "attack": 0.05},
		{"wave": &"sine", "f0": 324.0, "len": 1.7, "gain": 0.18,
			"curve": 3.0, "attack": 0.06},
		{"wave": &"sine", "f0": 488.0, "len": 1.2, "gain": 0.10,
			"curve": 3.6, "attack": 0.07},
		# The shimmer that says "struck", sweeping down as it dies.
		{"wave": &"sine", "f0": 1655.0, "f1": 1560.0, "len": 0.9, "gain": 0.07,
			"curve": 4.5, "attack": 0.02},
		# The strike itself, dark and brief.
		{"wave": &"noise", "f0": 1.0, "len": 0.09, "gain": 0.30,
			"curve": 9.0, "lp": 0.10},
	]},

	# An anvil. Two oscillators at a ratio that is deliberately NOT a musical
	# interval -- inharmonicity is what the ear reads as struck metal.
	&"forge": {"gain": 0.7, "voices": [
		{"wave": &"square", "f0": 247.0, "len": 0.55, "gain": 0.45,
			"curve": 4.5, "attack": 0.0, "crush": 2},
		{"wave": &"square", "f0": 371.0, "len": 0.45, "gain": 0.3,
			"curve": 5.5, "attack": 0.0},
		{"wave": &"sine", "f0": 1490.0, "f1": 1420.0, "len": 0.35, "gain": 0.2,
			"curve": 6.0, "attack": 0.0},
		{"wave": &"noise", "f0": 1.0, "len": 0.05, "gain": 0.4,
			"curve": 14.0, "lp": 0.6, "crush": 2},
	]},

	# --- footing ------------------------------------------------------------
	# These fire once when the ground under you CHANGES, never per step. The
	# energy cost of mud was working perfectly and was completely invisible --
	# "i can't tell that i am moving slower" -- and a sound at the boundary is
	# the cheapest possible fix that does not add another row to the sidebar.

	&"splash": {"gain": 0.6, "voices": [
		{"wave": &"noise", "f0": 1.0, "len": 0.28, "gain": 0.7,
			"curve": 4.5, "lp": 0.16, "crush": 2, "attack": 0.008},
		{"wave": &"sine", "f0": 420.0, "f1": 900.0, "len": 0.16, "gain": 0.12,
			"curve": 5.0, "attack": 0.01},
	]},

	&"squelch": {"gain": 0.65, "voices": [
		{"wave": &"noise", "f0": 1.0, "len": 0.30, "gain": 0.8,
			"curve": 5.0, "lp": 0.055, "crush": 9, "attack": 0.01},
		{"wave": &"sine", "f0": 150.0, "f1": 72.0, "len": 0.22, "gain": 0.3,
			"curve": 5.0, "attack": 0.01},
	]},

	&"scrape": {"gain": 0.6, "voices": [
		{"wave": &"noise", "f0": 1.0, "len": 0.20, "gain": 0.75,
			"curve": 6.0, "lp": 0.38, "crush": 6},
		{"wave": &"noise", "f0": 1.0, "len": 0.12, "gain": 0.4,
			"delay": 0.07, "curve": 8.0, "lp": 0.5, "crush": 4},
	]},
}

# ------------------------------------------------------------------ render ---

## Renders the whole catalogue. Roughly a hundred thousand samples all told,
## which is a few milliseconds at startup and then never again.
static func bank() -> Dictionary:
	var out := {}
	for id in SOUNDS:
		out[id] = render(SOUNDS[id])
	return out

static func render(sound: Dictionary) -> AudioStreamWAV:
	var voices: Array = sound["voices"]
	var length := 0.0
	for v in voices:
		length = maxf(length, float(v.get("delay", 0.0)) + float(v["len"]))

	var count := int(ceil(length * RATE)) + 1
	var buf := PackedFloat32Array()
	buf.resize(count)
	for v in voices:
		_lay(buf, v)

	# Normalise on loudness rather than on peak or on raw sum.
	#
	# `gain` in the catalogue is a statement of intent -- how loud this should
	# be relative to everything else -- and that intent has no business being
	# at the mercy of the filter chain. The first draft played the voices as
	# summed, and the mud squelch came out five times quieter than the thud
	# beside it purely because mud needs a heavy lowpass and a lowpass throws
	# away energy. Tuning that by hand means re-tuning every sound whenever one
	# filter coefficient moves.
	var master: float = float(sound.get("gain", 1.0))
	var window := mini(count, int(LOUDNESS_WINDOW * RATE))
	var energy := 0.0
	var peak := 0.0
	for i in count:
		peak = maxf(peak, absf(buf[i]))
		if i < window:
			energy += buf[i] * buf[i]
	var loudness := sqrt(energy / float(maxi(1, window)))
	var scale := 1.0
	if loudness > 0.0001:
		scale = master * REFERENCE_RMS / loudness
	if peak * scale > CEILING:
		scale = CEILING / maxf(0.0001, peak)

	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		# Soft clip rather than hard. Voices are summed, so peaks overlap by
		# design; a cubic knee lets them thicken instead of crackle.
		var s := clampf(buf[i] * scale, -1.0, 1.0)
		s = 1.5 * s - 0.5 * s * s * s
		data.encode_s16(i * 2, int(clampf(s * 31000.0, -32768.0, 32767.0)))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream

static func _lay(buf: PackedFloat32Array, v: Dictionary) -> void:
	var count := int(float(v["len"]) * RATE)
	if count <= 0:
		return
	var start := int(float(v.get("delay", 0.0)) * RATE)

	var wave: StringName = v.get("wave", &"sine")
	var f0: float = float(v.get("f0", 440.0))
	var f1: float = float(v.get("f1", f0))
	var gain: float = float(v.get("gain", 1.0))
	var curve: float = float(v.get("curve", 6.0))
	var attack: float = maxf(0.0, float(v.get("attack", 0.003)))
	var lp: float = clampf(float(v.get("lp", 1.0)), 0.0005, 1.0)
	var crush: int = maxi(1, int(v.get("crush", 1)))
	var wob_rate: float = float(v.get("wob_rate", 0.0))
	var wob_depth: float = float(v.get("wob_depth", 0.0))

	# Seeded, so a sound renders identically every run. Noise that shifts
	# between launches is a bug you find six months later.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(v)

	var phase := 0.0
	var filtered := 0.0
	var held := 0.0

	for i in count:
		var at := start + i
		if at >= buf.size():
			break
		var t := float(i) / float(count)
		var secs := float(i) / float(RATE)

		var freq := lerpf(f0, f1, t)
		if wob_rate > 0.0:
			freq *= 1.0 + sin(secs * TAU * wob_rate) * wob_depth
		phase = fposmod(phase + freq / float(RATE), 1.0)

		var s := 0.0
		match wave:
			&"sine":   s = sin(phase * TAU)
			&"square": s = 1.0 if phase < 0.5 else -1.0
			&"saw":    s = phase * 2.0 - 1.0
			&"tri":    s = 1.0 - absf(phase * 4.0 - 2.0)
			&"noise":  s = rng.randf_range(-1.0, 1.0)

		filtered += (s - filtered) * lp
		s = filtered

		if crush > 1:
			if i % crush == 0:
				held = s
			s = held

		var env: float = exp(-t * curve)
		if attack > 0.0 and secs < attack:
			env *= secs / attack

		buf[at] += s * env * gain
