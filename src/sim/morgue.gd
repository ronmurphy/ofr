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
const PATTERN := "level (?<level>\\d+)\\s+(?<cause>.+?) on depth (?<depth>\\d+), (?<carried>[^,]*), after (?<turns>\\d+) turns(?:; (?<slain>\\d+) slain(?:, most often (?<nemesis>[^;]+?))?)?(?:; bearing (?<gear>[^;]+?))?(?:; known as (?<name>[^;]+?))?(?:; (?<reclaimed>reclaimed))?(?:; (?<sold>sold))?\\s*$"

## Names for the dead who never gave one.
##
## Every line written before names existed has no name in it, and this project
## has a standing rule about not orphaning a player's own files -- there are
## real deaths in that morgue and the risen-dead system reads them back. So the
## field is optional and the nameless get called something.
##
## Weighted so the plain ones are ordinary and the references are a find. An
## easter egg you meet once in twenty graves is a delight; one you meet at every
## stone is furniture.
const NAMELESS := ["Nameless", "Nameless", "Nameless", "Unknown", "Unknown",
	"Forgotten", "Forgotten",
	## Dragon Warrior's hero, Brad's reference.
	"Erdrick",
	## The wizard from Rogue, which given this game's name and its amulet is
	## the right ghost to have wandering its graveyard.
	"Rodney"]

## Names the dungeon gives you when you do not give one.
##
## Distinct from NAMELESS above, and the difference matters. NAMELESS is for
## records written before names existed -- there is no name to report, so the
## stone says so. These are for a LIVING character who declined to type one:
## they get a real name, rolled, and find out what it is from the sidebar. A run
## from now on is always named; only the old dead are anonymous.
##
## Short on purpose. This sits above the HP bar in a 256px sidebar and goes into
## a morgue line that has to parse back, so NAME_MAX caps what a player can type
## and these stay well inside it.
const NAME_MAX := 16

const ROLLED := ["Bram", "Edda", "Hale", "Mira", "Nell", "Osric", "Pike",
	"Sten", "Tam", "Wynn", "Corin", "Della", "Fenn", "Hob", "Jory", "Rowan",
	"Thane", "Wren"]

## Rare finds, kept few. An easter egg you meet every run is furniture.
##
## Erdrick is Dragon Warrior's hero, Brad's reference. Rodney is the wizard from
## Rogue -- the right ghost to haunt a game called "old fashioned roguelike" --
## and Yendor is his amulet, which is also his name backwards, so the two are
## secretly the same joke.
const ROLLED_RARE := ["Erdrick", "Rodney", "Yendor"]

## One in this many rolled names is a rare one.
const RARE_ONE_IN := 12

static func roll_name(rng: RandomNumberGenerator) -> String:
	if rng.randi_range(1, RARE_ONE_IN) == 1:
		return ROLLED_RARE[rng.randi_range(0, ROLLED_RARE.size() - 1)]
	return ROLLED[rng.randi_range(0, ROLLED.size() - 1)]

## What a typed name is allowed to be.
##
## Semicolons and newlines would split a morgue record in half on the way back
## in -- the format is "; "-separated and read a line at a time -- so they are
## replaced rather than rejected, and the whole thing is capped to what the
## sidebar can draw.
static func clean_name(raw: String) -> String:
	var out := raw.strip_edges().replace(";", ",").replace("\n", " ")
	if out.length() > NAME_MAX:
		out = out.substr(0, NAME_MAX).strip_edges()
	return out

## The name on a record, or a stable invented one.
##
## DETERMINISTIC, and that is the whole point. Rolled fresh each call, the same
## grave would read "Nameless" when you looked at it and raise "Erdrick" a turn
## later -- the stone and the skeleton disagreeing about who is buried there.
## Hashing the record's own line means a given dead adventurer is named once and
## forever, without storing anything new.
static func name_of(rec: Dictionary) -> String:
	var given := String(rec.get("name", "")).strip_edges()
	if given != "":
		return given
	var seed_text := String(rec.get("line", ""))
	if seed_text == "":
		seed_text = "%s|%s|%s" % [str(rec.get("level", 0)),
			str(rec.get("turns", 0)), str(rec.get("cause", ""))]
	return NAMELESS[absi(seed_text.hash()) % NAMELESS.size()]

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
	# The trader sold this hero's kit to somebody. It is not offered again, in
	# this run or any other -- see GameState's trader stock.
	if m.get_string("sold") != "":
		rec["sold"] = true
	# Adding a group to PATTERN is only half of adding a field: nothing reaches
	# the record unless it is pulled out here. The first version of the name
	# matched perfectly and never appeared, because this block did not know to
	# ask for it.
	if m.get_string("name") != "":
		rec["name"] = m.get_string("name")
	if m.get_string("gear") != "":
		var worn: Array[String] = []
		for part in m.get_string("gear").split(","):
			var piece := String(part).strip_edges()
			if piece != "":
				worn.append(piece)
		if not worn.is_empty():
			rec["gear"] = worn
	return rec

## The stone's own words, in the order they should be read. Short lines,
## because the widest thing that shows them is the cursor panel.
static func epitaph(rec: Dictionary) -> Array:
	var out: Array = ["a grave"]
	# The name gets its own line rather than sharing one with the level.
	#
	# "Erdrick, who reached level 7" is 28 characters against a panel that fits
	# 26, and this stone is drawn in the same cursor panel that once cut "killed
	# by a kobold slinger" in half. One short line per fact is how the rest of
	# this epitaph is already built -- the gear puts each piece on its own line
	# for exactly the same reason.
	out.append(name_of(rec))
	out.append("reached level %d" % int(rec.get("level", 1)))
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
	return _add_clause(path, raw_line, "reclaimed")

## The trader has sold the last of this hero's kit. Written after `reclaimed`,
## which is the order PATTERN reads them in.
static func mark_sold(path: String, raw_line: String) -> bool:
	return _add_clause(path, raw_line, "sold")

## Appends "; <clause>" to one line of the morgue, safely.
##
## One routine for every mark, because the morgue is the one file in this game
## that cannot be regenerated, and a second copy of the careful part is a second
## place for it to go wrong.
##
## "Already there" is checked as a CLAUSE, not with ends_with. With two marks a
## line ends "; reclaimed; sold", so asking whether it ends with "; reclaimed"
## says no -- and the first version would have appended "reclaimed" a second
## time, producing a line PATTERN cannot read. A hero lost to the parser loses
## their epitaph, their grave and their kit at once.
static func _add_clause(path: String, raw_line: String, clause: String) -> bool:
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
	if Array(lines[hit].split("; ")).has(clause):
		return true
	lines[hit] = lines[hit] + "; " + clause

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
	var s := "Here lies %s, who reached level %d, %s." % [
		name_of(rec), int(rec.get("level", 1)),
		String(rec.get("cause", "and died here"))]
	if rec.has("slain"):
		s += " %d things died first." % int(rec["slain"])
	if rec.has("gear"):
		s += " Buried with %s." % ", ".join(rec["gear"])
	return s
