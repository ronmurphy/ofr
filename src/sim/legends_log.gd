class_name LegendsLog
extends RefCounted

## EVERY RUN THAT HAS ENDED, in full: user://legends.json.
##
## The morgue is one line of text per run, and that line cannot rebuild a hero:
## no pack, gear only as display names, and several parsing bugs in its history.
## The run's own state is deleted when it ends (see write_morgue). This is what
## survives -- the whole hero exactly as the save writes it, the numbers the
## stats page shows, and enough to know the run again.
##
## Brad, 2026-09-28: the Legends Run needs "all of the needed info", and
## escapes are what it is built from. Deaths are recorded too, so the same file
## can later carry graves and a chronicle.
##
## A PLAYER-OWNED FILE, and redirected by GameState.use_scratch_files() from
## its first commit -- see CLAUDE.md on the gamepad.cfg that was not.
##
## Records are appended and never rewritten, and each carries an id (the run's
## seed and turn count) so the same ending cannot be recorded twice. Brad's one
## escape sits in his morgue twice -- his save-escape-reload trick, since
## closed -- and the id is what keeps that from happening here.

const VERSION := 1
static var PATH := "user://legends.json"
## False after runs() met a file it could not read. record() then refuses to
## write, rather than replace a file someone might still recover by hand.
static var _readable := true

## Every recorded run, oldest first. The first time this is asked and the file
## does not exist, the text morgue is imported into it -- once.
static func runs() -> Array:
	_readable = true
	if not FileAccess.file_exists(PATH):
		var imported := import_text(GameState.MORGUE_PATH)
		if not imported.is_empty():
			_save(imported)
		return imported
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary and parsed.get("runs") is Array:
		return parsed["runs"]
	_readable = false
	push_warning("legends.json could not be read; nothing will be added to it")
	return []

static func escapes() -> Array:
	return runs().filter(func(r): return r.get("fate", "") == "escaped")

## Adds the run that has just ended. Called from write_morgue, BEFORE the text
## line is written -- otherwise a first-ever record would import the morgue
## with this run's line already in it, and record the run twice.
static func record(gs: GameState) -> void:
	var all := runs()
	if not _readable:
		return
	var rec := record_from(gs)
	for r in all:
		if r.get("id", "") == rec["id"]:
			return
	all.append(rec)
	_save(all)

## One run's record, from its state at the moment it ended.
static func record_from(gs: GameState) -> Dictionary:
	var fate := "left"
	if gs.won:
		fate = "escaped"
	elif gs.death_cause != "":
		fate = "died"
	var uniques := []
	for k in gs.uniques_found:
		uniques.append(String(k))
	return {
		"id": "%s-%d" % [str(gs.rng.seed), gs.turns],
		"when": Time.get_datetime_string_from_system(false, true),
		"fate": fate,
		"cause": gs.death_cause,
		"depth": gs.depth,
		"turns": gs.turns,
		"seconds": gs.time_underground(),
		"name": gs.player_name,
		"level": gs.player.level,
		"seed": str(gs.rng.seed),
		"hero": gs.player.to_dict(),
		"stats": gs.stats.duplicate(true),
		"uniques": uniques,
		"source": "run",
	}

## The hero a record describes, as an Entity. A full record rebuilds exactly;
## one imported from the text morgue has a level, perhaps a name, and at most
## the gear it was wearing.
static func hero_from(rec: Dictionary) -> Entity:
	if rec.get("hero") is Dictionary:
		return Entity.from_dict(rec["hero"])
	var name: String = rec.get("name", "")
	var e := Entity.new(name if name != "" else "a nameless hero", &"player", 0, 0)
	e.faction = Entity.Faction.PLAYER
	e.level = int(rec.get("level", 1))
	e.max_hp = GameState.hp_at_level(e.level)
	e.hp = e.max_hp
	for gear_name in rec.get("gear", []):
		var it := Item.from_display_name(String(gear_name))
		if it != null:
			e.inventory.append(it)
			e.equipped[it.slot] = it
	return e

## The text morgue as partial records. Identical lines -- one run written twice
## -- become one record, because the id is built from what the line says.
static func import_text(path: String) -> Array:
	var out: Array = []
	if not FileAccess.file_exists(path):
		return out
	var seen := {}
	var escape_re := RegEx.new()
	escape_re.compile("^(?<when>\\S+ \\S+)\\s+level (?<level>\\d+)\\s+escaped the dungeon.*?, after (?<turns>\\d+) turns(?:; (?<slain>\\d+) slain(?:, most often (?<nemesis>[^;]+?))?)?(?:; bearing (?<gear>[^;]+?))?(?:; known as (?<name>[^;]+?))?(?:;.*)?\\s*$")
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if line.strip_edges() == "":
			continue
		var rec := {}
		var m := escape_re.search(line)
		if m != null:
			rec = {"fate": "escaped", "cause": "", "depth": 0,
				"level": m.get_string("level").to_int(),
				"turns": m.get_string("turns").to_int(),
				"when": m.get_string("when"),
				"name": m.get_string("name"),
				"gear": _gear(m.get_string("gear"))}
		else:
			var d := Morgue.parse(line)
			if d.is_empty():
				continue
			rec = {"fate": "died", "cause": String(d.get("cause", "")),
				"depth": int(d.get("depth", 0)), "level": int(d.get("level", 1)),
				"turns": int(d.get("turns", 0)), "when": line.left(19),
				"name": String(d.get("name", "")),
				"gear": d.get("gear", [])}
		rec["id"] = "text-%s-%d-%d-%s-%s" % [rec["fate"], rec["level"],
			rec["turns"], rec["name"], rec["cause"]]
		if seen.has(rec["id"]):
			continue
		seen[rec["id"]] = true
		rec["source"] = "morgue.txt"
		rec["hero"] = null
		out.append(rec)
	return out

static func _gear(text: String) -> Array:
	var out := []
	for part in text.split(","):
		if part.strip_edges() != "":
			out.append(part.strip_edges())
	return out

static func _save(all: Array) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"version": VERSION, "runs": all}, "\t"))
	f.close()
