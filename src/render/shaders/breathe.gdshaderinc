// Light that moves, for both map views: included by block_anim.gdshader
// (classic) and diorama_surface.gdshader (3D), so a flame flickers, fungus
// breathes and water catches the light by the same maths in each. Where each
// view LOOKS different -- classic snaps to steps and stays on its cells, 3D is
// smooth -- is decided by the caller, never in here.
//
// The per-cell inputs come from LivingLight (src/render/living_light.gd), which
// is also the CPU half of this for the "simple" setting. BREATH_DEPTH and
// BREATH_RATE are mirrored there; the view tests check the two agree.

const float BREATH_DEPTH = 0.22;
const float BREATH_RATE = 0.8;

// Tile ids, matching src/sim/tiles.gd. Compared as scaled bytes.
const float ID_BRAZIER = 6.0;
const float ID_WATER   = 9.0;
const float ID_FUNGUS  = 18.0;

// Snaps `v` to `steps` discrete levels; 0 leaves it smooth.
//
// ROUND, not floor. Flooring only ever rounds down, so quantising an effect
// quietly halves it -- water measured 17/255 before this function and 7.5/255
// after, and it was reported from play as "I still can't see any water
// effects". Rounding keeps the average where the designer put it and only
// changes when the value moves, which is the point.
float quantise_to(float v, int steps) {
	if (steps <= 0) {
		return v;
	}
	return floor(v * float(steps) + 0.5) / float(steps);
}

// A phase byte from LivingLight back to radians. Zero means "none" and is
// checked by the caller; 1..254 carry the phase.
float phase_from_byte(float b) {
	return (b * 255.0 - 1.0) / 253.0 * 6.2831853;
}

// Firelight follows the LIGHT, not the tile: the multiplier the nearest flame's
// flicker puts on a cell's light, 1 where no flame reaches.
//
// This lights the whole area a flame reaches rather than the cell the flame
// sits in, which is what the CPU version always did and what the first draft of
// the classic shader missed. Keyed on the brazier tile alone, the torch flicker
// vanished completely on "full" -- a torch is not a tile, and neither is the
// floor it lights. Reported from play as "I don't see the torch flicker under
// full".
float flame(float fire_byte, float t) {
	if (fire_byte <= 0.0) {
		return 1.0;
	}
	float fire = phase_from_byte(fire_byte);
	return 1.0 + (sin(t * 11.0 + fire) * 0.06 + sin(t * 23.7 + fire * 2.0) * 0.04);
}

// Fungus light breathing: slow and shallow, 1 where no fungus is the light.
// Slower and weaker than fire. It glows, it does not burn.
float breath(float breath_byte, float t) {
	if (breath_byte <= 0.0) {
		return 1.0;
	}
	return 1.0 + BREATH_DEPTH * sin(t * BREATH_RATE + phase_from_byte(breath_byte));
}

// Water: three waves, not one.
//
// The first version rolled a single sine diagonally across the pool, which is
// a conveyor belt rather than a surface -- every cell doing the same thing a
// fixed moment later. Summing waves at different angles, speeds and
// wavelengths makes them interfere, and the interference is what reads as
// water. It is the cheapest honest approximation of a real surface and it
// costs three sines. `at` is in cells: whole cells for classic, anywhere on
// the surface for 3D.
float water_wave(vec2 at, float t) {
	float w = sin(t * 1.70 + at.x * 0.90 + at.y * 0.40)
		+ sin(t * 1.10 - at.x * 0.35 + at.y * 1.05) * 0.8
		+ sin(t * 2.60 + (at.x + at.y) * 0.22) * 0.5;
	return w / 2.3;
}

// The light a wave adds to the water, from water_wave().
vec3 water_light(float w, int steps) {
	// Crests, not a uniform shimmer. Raising the positive half to a power
	// leaves most of the pool alone and lights the few cells where the waves
	// happen to agree -- which is how light on water actually behaves, in
	// bright moving specks rather than an even pulse over everything.
	// A gentler power than the 2.5 this started with. That exponent pushed
	// almost every value under the first quantisation step, so the pool sat
	// dark and nothing appeared to happen.
	float crest = quantise_to(pow(max(w, 0.0), 1.3), steps);
	// Cool, so it reads as light ON water rather than water glowing. Sized so
	// a full crest is about 30/255 -- four visible steps rather than four
	// indistinguishable ones.
	vec3 add = vec3(0.045, 0.100, 0.135) * crest;
	// A little darkening in the troughs, which gives the surface depth
	// without brightening the pool overall.
	add += vec3(0.010, 0.018, 0.024) * -quantise_to(-min(w, 0.0), steps);
	return add;
}

// The shimmer on a fungus tile itself, from its per-cell phase.
vec3 fungus_glow(float phase, float t, int steps) {
	float g = sin(t * 2.4 + phase);
	return vec3(0.020, 0.048, 0.032) * sign(g) * quantise_to(abs(g), steps);
}
