class_name SoundDeck
extends Node

## Plays turn-event effects and generated music. Effects read the same event
## queue the renderer animates from; music follows the title or dungeon band.
##
## Effects only play where they carry INFORMATION THE EYE CAN MISS. There is no
## footstep, no swing, no door, no
## staircase, no pickup -- all of those are already fully visible the instant
## they happen, and a turn-based game where every keypress chirps is a game
## people play muted within ten minutes.
##
## What is left in the effect catalogue is the short list of things the game
## currently only tells you in the message log, which is where players stop
## looking:
##
##   the noise you make          invisible by design; the whole point of bones
##   something noticing you      pairs with the "!"
##   damage, and dying           the health bar is at the edge of vision
##   a trap springing            happens TO you, with no warning frame
##   a change of footing         the mud slowdown was completely unreadable
##   a shrine, forging or fungus burning -- rare, confirmable no other way
##
## The music is a quiet exception: it carries no gameplay information, and
## changes when the title hands off to a run or the dungeon changes bands.

const POOL := 10
const MUSIC_FADE_SECONDS := 1.8
const MUSIC_OFFSET_DB := -9.0
const SILENT_DB := -80.0


## Matches GlyphGrid.SHOT_PER_CELL. An arrow's impact is drawn when the
## projectile lands, so the thud has to wait for it too -- otherwise a shot
## across a room sounds a tenth of a second before it arrives, which reads as
## a bug even to someone who could not say why.
const SHOT_PER_CELL := 0.028

var muted := false
var volume := 0.65
## The music on its own switch, separate from `muted` (which silences
## everything): the effects carry information and the music does not, so a
## player can want one without the other. Saved with the other audio settings.
var music_on := true

var _bank := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music_player: AudioStreamPlayer
var _music_generator: AudioStreamGenerator
var _music_playback: AudioStreamGeneratorPlayback
var _music_profile: Dictionary = {}
var _music_from_profile: Dictionary = {}
var _music_key := ""
var _music_depth := 1
## True while the title's theme is the one playing, so switching the music or
## the sound back on returns to the title and not to a band. The title-music
## patch used this without declaring it -- it did not compile as sent.
var _music_is_title := false
var _music_time := 0.0
var _music_fade_elapsed := MUSIC_FADE_SECONDS
## Sounds waiting on a projectile: {id, gain, at}.
var _pending: Array = []
var _ready_ok := false

func _ready() -> void:
	_bank = Synth.bank()
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = &"Master"
		add_child(p)
		_players.append(p)
	_music_generator = AudioStreamGenerator.new()
	_music_generator.mix_rate = Synth.MUSIC_RATE
	_music_generator.buffer_length = 0.25
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "ProceduralMusic"
	_music_player.bus = &"Master"
	_music_player.stream = _music_generator
	_music_player.volume_db = SILENT_DB
	add_child(_music_player)
	_load_settings()
	_apply_music_volume()
	_ready_ok = true

func _process(delta: float) -> void:
	_fill_music()
	if _pending.is_empty():
		return
	var still: Array = []
	for q in _pending:
		q["at"] -= delta
		if q["at"] <= 0.0:
			play(q["id"], float(q["gain"]))
		else:
			still.append(q)
	_pending = still

## Selects the generated ambience from the same folded depth used by the
## dungeon. A theme only changes at band boundaries, and the return trip gets
## its altered version through Bands.is_corrupted().
func sync_music(effective_depth: int) -> void:
	_music_is_title = false
	_music_depth = effective_depth
	_sync_music_profile(Synth.music_profile(effective_depth),
		"%d:%d" % [int(Bands.of(effective_depth)),
			int(Bands.is_corrupted(effective_depth))])

func sync_title_music() -> void:
	_music_is_title = true
	_sync_music_profile(Synth.title_music_profile(), "title")

func _sync_music_profile(profile: Dictionary, key: String) -> void:
	if muted or not music_on or _music_player == null:
		return
	if not _music_player.playing:
		_music_player.play()
		_music_playback = null
	if key == _music_key:
		return
	_music_from_profile = _music_profile
	_music_profile = profile
	_music_key = key
	_music_fade_elapsed = 0.0

func _fill_music() -> void:
	if _music_player == null or not _music_player.playing:
		return
	if _music_playback == null:
		_music_playback = _music_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if _music_playback == null:
		return
	var sample_step := 1.0 / float(Synth.MUSIC_RATE)
	for _frame in _music_playback.get_frames_available():
		var sample := 0.0
		if not muted and music_on and not _music_profile.is_empty():
			var current := Synth.music_sample(_music_profile, _music_time)
			if _music_fade_elapsed < MUSIC_FADE_SECONDS:
				var previous := 0.0
				if not _music_from_profile.is_empty():
					previous = Synth.music_sample(_music_from_profile, _music_time)
				var blend := clampf(_music_fade_elapsed / MUSIC_FADE_SECONDS, 0.0, 1.0)
				sample = previous * cos(blend * PI * 0.5) \
					+ current * sin(blend * PI * 0.5)
				_music_fade_elapsed += sample_step
				if _music_fade_elapsed >= MUSIC_FADE_SECONDS:
					_music_from_profile.clear()
			else:
				sample = current
		_music_playback.push_frame(Vector2(sample, sample))
		_music_time = fposmod(_music_time + sample_step, Synth.MUSIC_LOOP_SECONDS)

func _apply_music_volume() -> void:
	if _music_player == null:
		return
	_music_player.volume_db = SILENT_DB if muted or not music_on else \
		linear_to_db(maxf(0.0008, volume)) + MUSIC_OFFSET_DB

# ------------------------------------------------------------------ events ---

## One pass per resolved turn.
func play_events(evts: Array) -> void:
	if not _ready_ok or muted or evts.is_empty():
		return
	var picked := choose(evts)
	for id in picked["now"]:
		play(id, float(picked["now"][id]))
	for id in picked["later"]:
		_pending.append({"id": id, "gain": 1.0, "at": float(picked["later"][id])})

## Which sounds a turn's events call for, with no node, no bank and no audio
## server involved -- so the mapping can be tested headless alongside the rest
## of the game. Returns {"now": {id: gain}, "later": {id: delay_seconds}}.
##
## Identical sounds are collapsed, because a room of six goblins all noticing
## you at once should be one alarm rather than six. Played straight, six
## overlapping copies of a 100ms blip is not six alarms; it is a click.
func choose(evts: Array) -> Dictionary:
	var now := {}
	var later := {}
	# The shrine of the vigil is the one that calls out, and it should not also
	# chime. Detected from the noise it makes rather than from a flag on the
	# pray event, so the simulation never has to name a sound.
	var called_out := false

	for e in evts:
		match e["kind"]:
			&"notice":
				_loudest(now, &"notice", 1.0)
			&"levelup":
				_loudest(now, &"levelup", 1.0)
			&"noise":
				# Only footfalls get the crunch. Combat raises noise through the
				# same system now -- a bowshot calls things towards where the
				# bow was -- but it already has its own sounds, and hearing bone
				# splinter every time an arrow leaves the string would be a lie
				# about what just happened.
				if e.get("cause", &"step") == &"clamour":
					called_out = true
				if e.get("cause", &"step") == &"step":
					# Louder the further it carries. Bones reach seven cells and
					# are the loudest thing you can do by accident.
					var r := float(e.get("radius", 1))
					_loudest(now, &"crunch", clampf(r / 7.0, 0.35, 1.0))
			&"trap":
				_loudest(now, &"trap", 1.0)
			&"pray":
				_loudest(now, &"pray", 1.0)
			&"forge", &"burn":
				_loudest(now, &"forge", 1.0)
			&"kill":
				_loudest(now, &"kill", 1.0)
			&"death":
				_loudest(now, &"death", 1.0)
			&"lowhp":
				_loudest(now, &"lowhp", 1.0)
			&"footing":
				var id := _footing_sound(int(e.get("tile", -1)))
				if id != &"":
					_loudest(now, id, 1.0)
			&"melee":
				_loudest(now, &"hurt" if e["on_player"] else &"hit", 1.0)
			&"ranged":
				_loudest(now, &"shot", 1.0)
				# Held back to land with the projectile.
				var cells := Los.steps(e["from"].x, e["from"].y, e["to"].x, e["to"].y)
				_loudest(later, &"hurt" if e["on_player"] else &"hit",
					float(cells) * SHOT_PER_CELL)

	# Swap the chime for the gong. Done here rather than at the call site
	# because a shrine emits its noise and its prayer as separate events and
	# only the whole turn's queue knows both happened.
	if called_out:
		now.erase(&"pray")
		_loudest(now, &"gong", 1.0)

	return {"now": now, "later": later}

func _loudest(into: Dictionary, id: StringName, value: float) -> void:
	into[id] = maxf(float(into.get(id, 0.0)), value)

func _footing_sound(tile: int) -> StringName:
	match tile:
		Tiles.WATER:  return &"splash"
		Tiles.MUD:    return &"squelch"
		Tiles.RUBBLE: return &"scrape"
	# Bones deliberately fall through: stepping on them already fires a noise
	# event, and hearing the crunch twice would be worse than not at all.
	return &""

# -------------------------------------------------------------------- play ---

func play(id: StringName, gain: float = 1.0) -> void:
	if not _ready_ok or muted or not _bank.has(id):
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = _bank[id]
	p.volume_db = linear_to_db(maxf(0.0008, volume * gain))
	# A little detune per play. Repeated identical samples are what make
	# synthesized sound read as cheap; a few percent of pitch scatter costs
	# nothing and removes most of that.
	p.pitch_scale = randf_range(0.95, 1.05)
	p.play()

func stop_all() -> void:
	stop_effects()
	if _music_player != null:
		_music_player.stop()
	_music_playback = null
	_music_profile.clear()
	_music_from_profile.clear()
	_music_key = ""
	_music_fade_elapsed = MUSIC_FADE_SECONDS

func stop_effects() -> void:
	_pending.clear()
	for p in _players:
		p.stop()

# ---------------------------------------------------------------- settings ---

func toggle_mute() -> String:
	muted = not muted
	if muted:
		stop_all()
	else:
		_sync_current_music()
	_apply_music_volume()
	_save_settings()
	return "Sound off." if muted else "Sound on."

## Music alone, on or off. Shift+M in play, and a row on the title's settings.
func toggle_music() -> String:
	music_on = not music_on
	if not music_on:
		if _music_player != null:
			_music_player.stop()
		_music_playback = null
		_music_profile.clear()
		_music_from_profile.clear()
	_music_key = ""
	_sync_current_music()
	_apply_music_volume()
	_save_settings()
	return "Music on." if music_on else "Music off."

func nudge_volume(step: float) -> String:
	volume = clampf(volume + step, 0.0, 1.0)
	if volume > 0.0 and muted:
		muted = false
		_music_key = ""
		_sync_current_music()
	_apply_music_volume()
	_save_settings()
	# Play the change so the number is not the only feedback.
	play(&"hit")
	return "Sound %d%%." % int(round(volume * 100.0))

func _sync_current_music() -> void:
	if _music_is_title:
		sync_title_music()
	else:
		sync_music(_music_depth)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(GameState.SETTINGS_PATH) != OK:
		return
	volume = clampf(float(cfg.get_value("audio", "volume", volume)), 0.0, 1.0)
	muted = bool(cfg.get_value("audio", "muted", muted))
	music_on = bool(cfg.get_value("audio", "music", music_on))

## Settings outlive a run on purpose. Someone who turns the sound off wants it
## off tomorrow too, and the suspend slot is destroyed on load -- so it is the
## wrong place to keep anything a player expects to persist.
func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(GameState.SETTINGS_PATH)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("audio", "music", music_on)
	cfg.save(GameState.SETTINGS_PATH)
