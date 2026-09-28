class_name BodyLook
extends RefCounted

## HOW A BODY LOOKS AS IT ROTS. One function both views read, so a body is the
## same colour at the same age in either -- the shared-layer rule (see Fx):
## the game records a thing once, and each view only draws it.
##
## Fresh, the creature's own colour a little darkened -- still recognisably
## the rat you just killed. Then it greys toward a dark earth colour and fades,
## and at GameState.BODY_ROT it is gone.
const ROTTEN := Color(0.30, 0.28, 0.22)

static func colour(fg: Color, age: int) -> Color:
	var t := clampf(float(age) / float(GameState.BODY_ROT), 0.0, 1.0)
	var c := fg.darkened(0.30).lerp(ROTTEN, t)
	c.a = lerpf(0.95, 0.30, t)
	return c

## Whether a body of this age is still there to draw.
static func showing(age: int) -> bool:
	return age >= 0 and age < GameState.BODY_ROT
