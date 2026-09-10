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
## with an optional `; 62 slain, most often cave bat` and an optional
## `; bearing short bow +1, chain mail +2`.
##
## Both suffixes are optional and independent, so all four shapes parse: lines
## from before the run recorder, lines from before gear was logged, and lines
## with either or both. `nemesis` is `[^;]+?` rather than `.+?` so it cannot
## swallow the clause that follows it.
const PATTERN := "level (?<level>\\d+)\\s+(?<cause>.+?) on depth (?<depth>\\d+), (?<carried>[^,]*), after (?<turns>\\d+) turns(?:; (?<slain>\\d+) slain(?:, most often (?<nemesis>[^;]+?))?)?(?:; bearing (?<gear>[^;]+?))?(?:; (?<reclaimed>reclaimed))?\\s*$"

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
		var raw := f.get_line()
		var rec := parse(raw)
		if not rec.is_empty():
			# The line exactly as written, so `mark_reclaimed` can find this
			# one row again without needing an id the format does not have.
			# The timestamp at the front is outside PATTERN, so there is
			# nothing else unique to match on.
			rec["line"] = raw
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
	# Kept as the written words. Turning them back into Items is the caller's
	# job, because this class parses a file and knows nothing about the
	# catalogue -- and a grave that only ever gets READ should not have to.
	if m.get_string("reclaimed") != "":
		rec["reclaimed"] = true
	if m.get_string("gear") != "":
		var worn: Array[String] = []
		for part in m.get_string("gear").split(","):
			var name := String(part).strip_edges()
			if name != "":
				worn.append(name)
		if not worn.is_empty():
			rec["gear"] = worn
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
	# Last, and deliberately plain. This is the line that decides whether a
	# player makes noise near the stone, so it has to be readable at a glance
	# and it must not editorialise -- no "beware", no "richly equipped". The
	# gear is the warning; saying so as well would do the player's thinking.
	if rec.has("gear"):
		# ONE LINE PER PIECE, and the sidebar already knew this: showing a live
		# monster's kit comma-joined overran the panel and came out as
		# "short sword, leather ..", so that code puts each piece on its own
		# line. This came out as "buried with dagger, lea.." in play -- the one
		# line the whole decision rests on, cut off exactly where it mattered.
		#
		# It matters more here than for a monster. Bones sit beside EVERY
		# grave, so nothing on the floor distinguishes a stone that can rise
		# from one that cannot; reading this is the only way to know, which
		# makes an unreadable line the same as no line.
		out.append("buried with")
		for piece in rec["gear"]:
			out.append("  " + String(piece))
	# Said plainly, because the player earned the right to know. A stone they
	# have already answered for is safe, and hiding that would only leave them
	# wondering why the bones no longer wake it.
	if rec.has("reclaimed"):
		out.append("already answered for")
	return out

## Crosses one death off as settled, WITHOUT losing it.
##
## The morgue is the player's own history of every run they have made, and it
## is append-only by design -- something you can `cat`. So this adds a clause
## rather than removing a row: the death still happened, still raises a stone,
## and still reads. It simply has nothing left to give, and by the rule that
## only armed graves rise, it stays shut.
##
## Written to a temporary file and renamed over the original rather than edited
## in place. This is the one file in the game that cannot be regenerated, and a
## write interrupted halfway would take every run with it. If any step fails,
## the original is left exactly as it was and the caller is told.
static func mark_reclaimed(path: String, raw_line: String) -> bool:
	if raw_line.strip_edges() == "":
		return false
	var lines := PackedStringArray()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	while not f.eof_reached():
		lines.append(f.get_line())
	f.close()

	var hit := -1
	for i in lines.size():
		if lines[i] == raw_line:
			hit = i
			break
	if hit < 0:
		return false
	if lines[hit].ends_with("; reclaimed"):
		return true
	lines[hit] = lines[hit] + "; reclaimed"

	var temp := path + ".tmp"
	var out := FileAccess.open(temp, FileAccess.WRITE)
	if out == null:
		return false
	for i in lines.size():
		# The reader skips blanks, so a trailing empty line is harmless -- but
		# not reproducing one keeps the file identical bar the added clause.
		if i == lines.size() - 1 and lines[i] == "":
			continue
		out.store_line(lines[i])
	out.close()

	# Verify before replacing. A short temp file means something went wrong,
	# and the right answer then is to change nothing.
	var check := FileAccess.open(temp, FileAccess.READ)
	if check == null:
		return false
	var written := 0
	while not check.eof_reached():
		if check.get_line().strip_edges() != "":
			written += 1
	check.close()
	var expected := 0
	for i in lines.size():
		if lines[i].strip_edges() != "":
			expected += 1
	if written != expected:
		DirAccess.remove_absolute(temp)
		return false

	DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(temp, path) == OK

## One sentence, for the log line printed on stepping onto it.
static func inscription(rec: Dictionary) -> String:
	var s := "Here lies one who reached level %d, %s." % [
		int(rec.get("level", 1)), String(rec.get("cause", "and died here"))]
	if rec.has("slain"):
		s += " %d things died first." % int(rec["slain"])
	if rec.has("gear"):
		s += " Buried with %s." % ", ".join(rec["gear"])
	return s
