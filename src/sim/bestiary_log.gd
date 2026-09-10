class_name BestiaryLog
extends RefCounted

## What the player has ever laid eyes on, across every run they have played.
##
## The legend panel used to list the WHOLE bestiary, which meant a player who
## had never left the second floor could read that there is an arch lich on the
## climb out and a young dragon at the bottom. A reference that answers
## questions you have not asked yet is a spoiler wearing a helpful face.
##
## ALL-TIME rather than per-run, deliberately. A per-run legend empties itself
## every time you die, which is exactly when its reference value is highest --
## you have just met something new and want to know what it was. The same
## reasoning shrines already follow: they name themselves once learned, and
## stay named.
##
## Kept beside the morgue and in the same spirit: a plain text file, one name a
## line, that a player can open and read. It is a record of what they have
## seen, and it belongs to them.

const PATH := "user://bestiary.txt"

## Appearance ids, not display names -- the id is what the render theme keys
## on, and a monster's printed name could change without changing what the
## player actually learned to recognise.
static var _seen: Dictionary = {}
static var _loaded := false

## Where the file lives. Overridden by the test suite and every dev tool, the
## same way GameState does it, so nothing headless can ever write over a
## player's own record.
static var _path := PATH

static func use_path(p: String) -> void:
	_path = p
	_loaded = false
	_seen = {}

static func reset_path() -> void:
	use_path(PATH)

## Everything ever seen. Loaded once, then held.
static func seen() -> Dictionary:
	if not _loaded:
		_load()
	return _seen

static func knows(app: StringName) -> bool:
	return seen().has(app)

static func count() -> int:
	return seen().size()

## Records a first sighting. Answers true only the FIRST time, so a caller can
## say something about it without having to remember whether it already did.
static func note(app: StringName) -> bool:
	if app == &"" or app == &"player":
		return false
	if not _loaded:
		_load()
	if _seen.has(app):
		return false
	_seen[app] = true
	_append(app)
	return true

static func _load() -> void:
	_loaded = true
	_seen = {}
	if not FileAccess.file_exists(_path):
		return
	var f := FileAccess.open(_path, FileAccess.READ)
	if f == null:
		return
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line != "":
			_seen[StringName(line)] = true
	f.close()

## Appended, never rewritten. The file only ever grows by one line, so a crash
## mid-write costs at most the sighting that was happening at the time -- and
## the next one you see puts it back.
static func _append(app: StringName) -> void:
	var f := FileAccess.open(_path, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(_path, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(String(app))
	f.close()

## Removes whatever use_path pointed at. Tests and tools only -- it refuses to
## touch anything that is not obviously a scratch file, for the same reason
## GameState.clear_scratch_files does.
static func clear_scratch() -> void:
	if _path.contains("scratch_") and FileAccess.file_exists(_path):
		DirAccess.remove_absolute(_path)
	_loaded = false
	_seen = {}
