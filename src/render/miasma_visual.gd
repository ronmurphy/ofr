class_name MiasmaVisual
extends RefCounted

## A slow, restrained change in opacity for the purple cloud. Both renderers
## use the same period and range so changing view does not change its rhythm.
const ALPHA_WOBBLE := 0.08
const PERIOD := 3.0

static func alpha_at(clock: float, moving: bool) -> float:
	if not moving:
		return Palette.MIASMA.a
	return Palette.MIASMA.a + sin(clock * TAU / PERIOD) * ALPHA_WOBBLE
