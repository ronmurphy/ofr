class_name SoundDeck
extends Node

## Reads the same event queue the renderer animates from, and plays tones.
##
## The rule this file exists to enforce: SOUND ONLY WHERE IT CARRIES
## INFORMATION THE EYE CAN MISS. There is no footstep, no swing, no door, no
## staircase, no pickup -- all of those are already fully visible the instant
## they happen, and a turn-based game where every keypress chirps is a game
## people play muted within ten minutes.
##
## What is left is the short list of things the game currently only tells you
## in the message log, which is precisely where players stop looking:
##
##   the noise you make          invisible by design; the whole point of bones
##   something noticing you      pairs with the "!"
##   damage, and dying           the health bar is at the edge of vision
##   a trap springing            happens TO you, with no warning frame
##   a change of footing         the mud slowdown was completely unreadable
##   a shrine, a forging         rare, and confirmable no other way
##
## Adding to that list is easy and should be resisted.

const POOL := 10
const SETTINGS := "user://settings.cfg"

## Matches GlyphGrid.SHOT_PER_CELL. An arrow's impact is drawn when the
## projectile lands, so the thud has to wait for it too -- otherwise a shot
## across a room sounds a tenth of a second before it arrives, which reads as
## a bug even to someone who could not say why.
const SHOT_PER_CELL := 0.028

var muted := false
var volume := 0.65

var _bank := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
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
	_load_settings()
	_ready_ok = true

func _process(delta: float) -> void:
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

	for e in evts:
		match e["kind"]:
			&"notice":
				_loudest(now, &"notice", 1.0)
			&"levelup":
				_loudest(now, &"levelup", 1.0)
			&"noise":
				# Louder the further it carries. Bones reach seven cells and
				# are the loudest thing you can do by accident.
				var r := float(e.get("radius", 1))
				_loudest(now, &"crunch", clampf(r / 7.0, 0.35, 1.0))
			&"trap":
				_loudest(now, &"trap", 1.0)
			&"pray":
				_loudest(now, &"pray", 1.0)
			&"forge":
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
	_pending.clear()
	for p in _players:
		p.stop()

# ---------------------------------------------------------------- settings ---

func toggle_mute() -> String:
	muted = not muted
	if muted:
		stop_all()
	_save_settings()
	return "Sound off." if muted else "Sound on."

func nudge_volume(step: float) -> String:
	volume = clampf(volume + step, 0.0, 1.0)
	if volume > 0.0 and muted:
		muted = false
	_save_settings()
	# Play the change so the number is not the only feedback.
	play(&"hit")
	return "Sound %d%%." % int(round(volume * 100.0))

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) != OK:
		return
	volume = clampf(float(cfg.get_value("audio", "volume", volume)), 0.0, 1.0)
	muted = bool(cfg.get_value("audio", "muted", muted))

## Settings outlive a run on purpose. Someone who turns the sound off wants it
## off tomorrow too, and the suspend slot is destroyed on load -- so it is the
## wrong place to keep anything a player expects to persist.
func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("audio", "muted", muted)
	cfg.save(SETTINGS)
