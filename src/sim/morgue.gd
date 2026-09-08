class_name Morgue
extends RefCounted

## The death log, and the one thing in the game that reads it back.
##
## The morgue was write-only for the whole project: every run appended a line
## and nothing could ever show it. Gravestones are what make it a record rather
## than a file -- a floor remembers the runs that ended on it.
##
## The format stays a HUMAN-READABLE line rather than becoming JSON, because a
## morgue is traditionally something you can `cat`, and because the lines
## already written have to keep working. Parsing is a regex over the format
## `write_morgue` has always produced, with the run-record suffix optional --
## so a death recorded before any of tonight's counters existed still yields a
## gravestone, just a quieter one.

## `... level 19  killed by a wyvern on depth 7, empty-handed, after 10720 turns`
## with an optional `; 62 slain, most often cave bat`.
const PATTERN := "level (?<level>\\d+)\\s+(?<cause>.+?) on depth (?<depth>\\d+), (?<carried>[^,]*), after (?<turns>\\d+) turns(?:; (?<slain>\\d+) slain(?:, most often (?<nemesis>.+?))?)?\\s*$"

## Every death the log holds. Escapes are skipped -- someone who walked out
## into daylight is not buried in the dungeon.
static func records(path: String) -> Array:
	var out: Array = []
	if not FileAccess.file_exists(path):
		return out
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var rec := parse(f.get_line())
		if not rec.is_empty():
			out.append(rec)
	f.close()
	return out

static func parse(line: String) -> Dictionary:
	if line.strip_edges() == "":
		return {}
	var re := RegEx.new()
	re.compile(PATTERN)
	var m := re.search(line)
	if m == null:
		return {}
	var rec := {
		"level": m.get_string("level").to_int(),
		"cause": m.get_string("cause"),
		"depth": m.get_string("depth").to_int(),
		"turns": m.get_string("turns").to_int(),
	}
	# Only present on deaths recorded after the run recorder existed. Absent is
	# absent -- the epitaph simply says less, rather than claiming a zero.
	if m.get_string("slain") != "":
		rec["slain"] = m.get_string("slain").to_int()
	if m.get_string("nemesis") != "":
		rec["nemesis"] = m.get_string("nemesis")
	return rec

## The stone's own words, in the order they should be read. Short lines,
## because the widest thing that shows them is the cursor panel.
static func epitaph(rec: Dictionary) -> Array:
	var out: Array = ["a grave"]
	out.append("one who reached level %d" % int(rec.get("level", 1)))
	out.append(String(rec.get("cause", "died here")))
	if rec.has("slain"):
		out.append("%d died first" % int(rec["slain"]))
		if rec.has("nemesis"):
			out.append("most often %s" % String(rec["nemesis"]))
	out.append("%d turns" % int(rec.get("turns", 0)))
	return out

## One sentence, for the log line printed on stepping onto it.
static func inscription(rec: Dictionary) -> String:
	var s := "Here lies one who reached level %d, %s." % [
		int(rec.get("level", 1)), String(rec.get("cause", "and died here"))]
	if rec.has("slain"):
		s += " %d things died first." % int(rec["slain"])
	return s
