class_name HoldRepeat
extends RefCounted

## Turns "this is being held" into a step now and then, at a steady rate.
##
## ONE TIMING FOR THE STICK AND THE KEYBOARD. The stick had its own copy, and
## the keyboard had none at all -- holding an arrow key moved you once, because
## the OS's own key repeat is filtered out on purpose (its speed is whatever the
## player's desktop happens to be set to). Brad's report: the stick felt fast
## and good, the keyboard felt like wading.
##
## The stick's copy also carried a bug that fed his other complaint, which was
## OVERSHOOTING. It was meant to wait FIRST seconds after the first step before
## repeating, so a quick push is one clean step. But it marked itself as
## "already walking" on that very first step, so the first repeat came AGAIN
## seconds later instead -- the pause never happened, and a push held a moment
## too long was two steps. `STICK_FIRST` was defined and never once used.

## Before the FIRST repeat. Long enough that a deliberate tap is one step.
const FIRST := 0.35
## Between repeats after that. 0.25 is four steps a second -- Brad's call on
## 2026-09-24, down from about eight, which walked him past pits and into a
## patroller's path. One number now, for both inputs.
const AGAIN := 0.25

var _held := 0
var _hold := 0.0
var _walked := false
## True when the last value tick() returned came from holding, not pressing.
var last_was_repeat := false

## Feed whatever is held right now (0 for nothing). Answers what to act on this
## frame, or 0.
##
## `emit_first`: the stick has no "pressed" event, so the first step has to come
## from here; the keyboard does, and its first step has already happened by the
## time this sees the key, so it must not be taken twice.
func tick(held: int, delta: float, emit_first: bool) -> int:
	last_was_repeat = false
	if held == 0:
		_held = 0
		_hold = 0.0
		_walked = false
		return 0
	if held != _held:
		_held = held
		_hold = 0.0
		_walked = false
		return held if emit_first else 0
	_hold += delta
	if _hold >= (AGAIN if _walked else FIRST):
		_hold = 0.0
		_walked = true
		last_was_repeat = true
		return held
	return 0
