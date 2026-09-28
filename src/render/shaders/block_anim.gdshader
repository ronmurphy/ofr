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

// The maths of moving light, shared with the 3D view's surface shader.
#include "res://src/render/shaders/breathe.gdshaderinc"

// One texel per map cell, from LivingLight. NEAREST, always: every block stays
// hard-edged.
//   r = tile id / 255      what this cell is
//   g = per-cell hash      so neighbours never animate in lockstep
//   b = firelight phase    0 = no flame reaches here; otherwise the phase of
//                          the nearest flickering light, torch included
//   a = 1 if visible       animation only runs on what you can actually see
uniform sampler2D cell_data : filter_nearest, repeat_disable;
//   r = fungus breath phase, 0 where no fungus is the light
//   g, b, a: not read here (g is memory, which the CPU draws)
uniform sampler2D cell_extra : hint_default_black, filter_nearest, repeat_disable;
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

// See quantise_to in breathe.gdshaderinc.
float quantise(float v) {
	return quantise_to(v, steps);
}

// Where this fragment is INSIDE THE GRID CONTROL, in the same pixels
// `cell_size` is measured in.
//
// This started as `FRAGCOORD.xy - control_origin`, which is a different space
// and only looked right by coincidence. FRAGCOORD is in real framebuffer
// pixels; the control's position and cell_size are in the project's 1600x900
// stretch space, and `stretch/mode = canvas_items` makes those two the same
// thing ONLY when the window is exactly 1600x900. Every desktop launch is, and
// no browser is -- the web export sizes its canvas to the page -- so the bug
// was invisible in the editor and shipped to itch, where the water and ember
// effects sat measurably off their own tiles. Measured on desktop at 1200x675:
// the animated region moved from x 0.060-0.241 of the width to 0.069-0.298.
//
// VERTEX in a canvas_item vertex shader is already in the CanvasItem's local
// space, before the stretch transform is applied -- exactly the space
// _screen_f() draws in. So it needs no origin uniform and no correction, and
// it is right at any canvas size rather than right at one of them.
varying vec2 local_px;

void vertex() {
	local_px = VERTEX;
}

void fragment() {
	vec2 cell = local_px / cell_size + camera_cell;
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
		// Firelight follows the LIGHT, not the tile, and fungus light breathes
		// where no flame reaches -- see flame() and breath().
		float mul = flame(d.b, t) * breath(texture(cell_extra, uv).r, t);
		vec3 add = vec3(0.0);

		// Water: three waves, whole cells at a time -- see water_wave().
		if (id == ID_WATER) {
			add += water_light(water_wave(floor(cell), t), steps);
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
			add += fungus_glow(phase, t, steps);
		}

		COLOR.rgb *= mix(1.0, 1.0 + (mul - 1.0) * strength, seen);
		COLOR.rgb += add * strength * seen;
	}
}
