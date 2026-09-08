shader_type canvas_item;

// Animation for the block style, without smoothing it.
//
// The blocks are the look, and they are also INFORMATION: each cell is a
// discrete readable light level, so you can see how far the torch reaches by
// reading the steps. An earlier experiment interpolated between cells and the
// room went uniform -- legible falloff turned into "one colour, then dark".
// Hence filter_nearest below, which is the entire difference between the two
// approaches and is not negotiable.
//
// What this DOES do is move animation off the CPU. GlyphGrid currently
// computes two sine waves per visible cell per redraw for torch flicker, plus
// separate timers for the ember pulse, the stairs and awareness markers. All
// of that is per-frame work in GDScript to make blocks move. Here a cell's
// identity arrives in a texture and the motion is a function of that identity
// and the clock -- no per-cell CPU maths, and room for effects that would be
// far too expensive to write by hand.

// One texel per map cell. NEAREST, always: every block stays hard-edged.
//   r = tile id / 255      what this cell is
//   g = per-cell hash      so neighbours never animate in lockstep
//   b = firelight phase    0 = no flame reaches here; otherwise the phase of
//                          the nearest flickering light, torch included
//   a = 1 if visible       animation only runs on what you can actually see
uniform sampler2D cell_data : filter_nearest, repeat_disable;
uniform vec2 control_origin;
uniform vec2 camera_cell;
uniform float cell_size;
uniform vec2 map_size;
// Fed explicitly rather than using TIME, so a screenshot tool can step it and
// produce a comparable sequence.
uniform float t = 0.0;
// Multiplier on every amplitude below. Purely a tuning aid: turn it up to
// three or four to confirm an effect is firing at all, then bring it back to
// judge the taste. Subtle is recoverable; gaudy is not, so the shipped values
// err small and are hard to SEE working.
uniform float strength = 1.0;
// How many discrete levels the animation snaps between. 0 disables the
// quantising and gives a smooth sine.
//
// This is the one idea worth taking from the shaders on godotshaders.com, and
// it did not come from what they were FOR. One thresholds noise to a hard
// yes/no to get crisp bands out of a smooth field; the other steps sprites by
// whole pixels on a clock instead of easing them. Neither interpolates.
//
// Our cells are already discrete, and smooth sinusoidal brightness is a modern
// habit that fights that. Snapping to a few levels is palette cycling, which
// is the technique this look actually comes from.
uniform int steps = 4;

float quantise(float v) {
	if (steps <= 0) {
		return v;
	}
	// ROUND, not floor. Flooring only ever rounds down, so quantising an
	// effect quietly halves it -- water measured 17/255 before this function
	// and 7.5/255 after, and it was reported from play as "I still can't see
	// any water effects". Rounding keeps the average where the designer put it
	// and only changes when the value moves, which is the point.
	return floor(v * float(steps) + 0.5) / float(steps);
}

// Tile ids, matching src/sim/tiles.gd. Compared as scaled bytes.
const float ID_BRAZIER = 6.0;
const float ID_WATER   = 9.0;
const float ID_FUNGUS  = 18.0;

void fragment() {
	vec2 cell = (FRAGCOORD.xy - control_origin) / cell_size + camera_cell;
	vec2 uv = cell / map_size;

	if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
		vec4 d = texture(cell_data, uv);
		float id = floor(d.r * 255.0 + 0.5);
		float phase = d.g * 6.2831853;
		float seen = d.a;

		// TWO channels of animation, and which one an effect uses matters more
		// than its amplitude.
		//
		// A MULTIPLY is proportional to what is already there: it moves a
		// bright pixel a lot and a dark one barely at all. Measured, the same
		// x1.10 moved a lit brazier glyph 20/255 and dark water 4/255 -- so
		// fire read as flickering and water read as still, at identical
		// settings. Turning the amplitude up would have made fire gaudy long
		// before water became visible.
		//
		// So: fire multiplies, because a brighter flame really does flicker
		// harder. Water and fungus ADD, because they are dark and want a fixed
		// absolute change -- light catching a ripple, not the pool getting
		// proportionally brighter.
		float mul = 1.0;
		vec3 add = vec3(0.0);

		// Firelight follows the LIGHT, not the tile.
		//
		// This lights the whole area a flame reaches rather than the cell the
		// flame sits in, which is what the CPU version always did and what the
		// first draft of this shader missed. Keyed on the brazier tile alone,
		// the torch flicker vanished completely on "full" -- a torch is not a
		// tile, and neither is the floor it lights. Reported from play as
		// "I don't see the torch flicker under full".
		if (d.b > 0.0) {
			float fire = (d.b * 255.0 - 1.0) / 253.0 * 6.2831853;
			mul += sin(t * 11.0 + fire) * 0.06 + sin(t * 23.7 + fire * 2.0) * 0.04;
		}

		// Water: three waves, not one.
		//
		// The first version rolled a single sine diagonally across the pool,
		// which is a conveyor belt rather than a surface -- every cell doing
		// the same thing a fixed moment later. Summing waves at different
		// angles, speeds and wavelengths makes them interfere, and the
		// interference is what reads as water. It is the cheapest honest
		// approximation of a real surface and it costs three sines.
		if (id == ID_WATER) {
			float cx = floor(cell.x);
			float cy = floor(cell.y);
			float w = sin(t * 1.70 + cx * 0.90 + cy * 0.40)
				+ sin(t * 1.10 - cx * 0.35 + cy * 1.05) * 0.8
				+ sin(t * 2.60 + (cx + cy) * 0.22) * 0.5;
			w /= 2.3;

			// Crests, not a uniform shimmer. Raising the positive half to a
			// power leaves most of the pool alone and lights the few cells
			// where the waves happen to agree -- which is how light on water
			// actually behaves, in bright moving specks rather than an even
			// pulse over everything.
			// A gentler power than the 2.5 this started with. That exponent
			// pushed almost every value under the first quantisation step, so
			// the pool sat dark and nothing appeared to happen.
			float crest = quantise(pow(max(w, 0.0), 1.3));
			// Cool, so it reads as light ON water rather than water glowing.
			// Sized so a full crest is about 30/255 -- four visible steps
			// rather than four indistinguishable ones.
			add += vec3(0.045, 0.100, 0.135) * crest;
			// A little darkening in the troughs, which gives the surface depth
			// without brightening the pool overall.
			add += vec3(0.010, 0.018, 0.024) * -quantise(-min(w, 0.0));
		}
		// Embers rising off a brazier.
		//
		// Grid-native rather than true particles: sub-cell motion would break
		// the block look, which is the whole reason this shader samples
		// nearest. Instead a cell asks whether there is a brazier one or two
		// BELOW it and, if so, lights briefly as a spark passes through. The
		// data is a texture, so a cell can read its neighbours for free -- no
		// extra channel and no CPU work.
		//
		// The player's torch is deliberately excluded. That cell already
		// carries the player glyph and is the busiest thing on screen.
		float ember = 0.0;
		for (int k = 1; k <= 2; k++) {
			vec2 src_uv = (floor(cell) + vec2(0.5, 0.5 + float(k))) / map_size;
			vec4 src = texture(cell_data, src_uv);
			if (floor(src.r * 255.0 + 0.5) == ID_BRAZIER && src.a > 0.0) {
				// Phase from the SOURCE cell, so two braziers in a room never
				// throw sparks together.
				float cycle = fract(t * 0.55 + src.g * 7.0);
				float want = float(k) * 0.30;
				// Brief, but not so brief it cannot be confirmed to exist.
				// The first window was 0.09 of the cycle -- about a tenth of a
				// second -- which measured as working and read on screen as
				// nothing. Same mistake as the water: erring subtle on an
				// effect nobody can yet verify is there.
				ember += smoothstep(0.20, 0.0, abs(cycle - want))
					* (1.0 - float(k) * 0.30);
			}
		}
		if (ember > 0.0) {
			add += vec3(0.150, 0.078, 0.020) * quantise(ember);
		}

		// Slower and weaker than fire. It glows, it does not burn.
		else if (id == ID_FUNGUS) {
			float g = sin(t * 2.4 + phase);
			add += vec3(0.020, 0.048, 0.032) * sign(g) * quantise(abs(g));
		}

		COLOR.rgb *= mix(1.0, 1.0 + (mul - 1.0) * strength, seen);
		COLOR.rgb += add * strength * seen;
	}
}
