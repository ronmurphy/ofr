class_name MessageLog
extends RefCounted

const MAX := 200

var entries: Array = []

func add(text: String, color: Color = Color(0.78, 0.78, 0.72)) -> void:
	# Collapse repeats into "(x3)" so a long fight does not scroll the log away.
	if not entries.is_empty() and entries[-1]["text"] == text:
		entries[-1]["count"] += 1
		return
	entries.append({"text": text, "color": color, "count": 1})
	if entries.size() > MAX:
		entries.remove_at(0)

func tail(n: int) -> Array:
	var start := maxi(0, entries.size() - n)
	return entries.slice(start, entries.size())
