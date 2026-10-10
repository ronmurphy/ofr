shader_type spatial;
// TWO LIGHTS, ONE TRUTH (the 3D look, 2026-10-01). The simulation's light map
// still decides everything that is INFORMATION: whether a cell is seen, how it
// is remembered, and the colour and reach of its light. It arrives as a
// texture, one texel per map cell, blended smoothly between cells, and goes
// out as EMISSION at `map_weight` -- so a lit floor reads lit with no engine
// light near it. Engine lights (OmniLight3D, placed by DioramaView on the
// SAME sources: the torch, the braziers, the fungi) add what a texel cannot:
// a direction. Faces brighten toward the fire, grooves and pits catch it,
// blocks cast shadows. Their contribution is masked by `seen` in light(), so
// a remembered wall is never lit by a fire you cannot see.
render_mode diffuse_lambert, specular_schlick_ggx;

// The maths of moving light, shared with the classic view's block_anim.
#include "res://src/render/shaders/breathe.gdshaderinc"

// Multimesh instance colours carry the UNLIT palette colour. Alpha is 1, or
// below 0.75 for a landmark whose remembered colour must be shown as it is.
// These small patterns add material character without changing that game
// information.
uniform int surface_style = 0; // 0 floor, 1 masonry, 2 worked stone, 3 natural rock, 14 glow
// rgb = light-map colour, a = 1 if the cell is in view now, 0 if remembered.
uniform sampler2D cell_light : filter_linear, repeat_disable;
uniform vec2 map_size = vec2(96.0, 54.0);
// The classic view's memory: pulled towards this colour, then dimmed.
uniform vec4 memory_tint;
uniform float memory_mix = 0.78;
uniform float memory_dim = 0.62;
// 1 on built floors, lower in the caves, 0 on the corrupted climb.
uniform float memory_strength = 1.0;
// Light is blended between cells; WHETHER a cell is in view is not, by
// default. Where your sight ends is a rule of the game, so its edge stays on
// the cell boundary the classic view draws. True blends that edge too.
uniform bool soft_view_edge = false;
// From LivingLight, the classic shader's own two textures, read unblended:
//   cell_data  r tile id, g per-cell hash, b firelight phase, a in view
//   cell_extra r fungus breath phase, g how far memory has faded (0 = none)
// Black when not handed over yet, which reads as a still, unfaded map.
uniform sampler2D cell_data : hint_default_black, filter_nearest, repeat_disable;
uniform sampler2D cell_extra : hint_default_black, filter_nearest, repeat_disable;
// The clock, fed rather than TIME so a screenshot can hold it still, and how
// much may move: 0 still, 1 simple (flames flicker, fungus breathes), 2 full
// (and water catches the light and fungus glitters).
uniform float t = 0.0;
uniform int motion = 0;
// How much of a seen cell's brightness the light map supplies as emission;
// the engine lights supply the rest, with direction. 1.0 is the old look.
uniform float map_weight = 0.55;
// How much the engine lights add, and how deep the surface relief reads.
uniform float light_weight = 1.0;
uniform float relief = 1.0;
// The palette is sRGB, and so is the light map. The Compatibility renderer
// draws in sRGB and shows them as they are; Forward+ works in linear and
// converts its output for the display, which lifted every mid-tone -- dark
// stone far from any fire came out light grey (the first PC render,
// 2026-10-01). On a linear renderer the view sets this and the colours are
// taken to linear first, so both tiers show the same stone.
uniform bool linear_light = false;

varying vec3 world_position;
varying vec3 world_normal;
varying vec4 instance_tint;
// Written in fragment(), read in light(): 1 in view, 0 remembered; and how
// glossy this surface is (water shines, stone does not).
varying float seen_v;
varying float gloss_v;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash31(i);
	float b = hash31(i + vec3(1.0, 0.0, 0.0));
	float c = hash31(i + vec3(0.0, 1.0, 0.0));
	float d = hash31(i + vec3(1.0, 1.0, 0.0));
	float e = hash31(i + vec3(0.0, 0.0, 1.0));
	float f1 = hash31(i + vec3(1.0, 0.0, 1.0));
	float g = hash31(i + vec3(0.0, 1.0, 1.0));
	float h = hash31(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(a, b, f.x), mix(c, d, f.x), f.y),
		mix(mix(e, f1, f.x), mix(g, h, f.x), f.y), f.z);
}

// How lit this point is right now, as a multiplier on its light: the flicker
// and breath of the four cells around it, weighted exactly as filter_linear
// weights their light. The phases are read unblended and only what they
// PRODUCE is mixed, so where two flames' reaches meet mid-room their rhythms
// cross-fade instead of meeting along a cell edge -- the classic view keeps
// that edge, because there every cell is a block anyway.
float living_pulse(vec2 probe) {
	vec2 p = probe - vec2(0.5);
	vec2 f = fract(p);
	ivec2 i0 = ivec2(floor(p));
	ivec2 last = ivec2(map_size) - ivec2(1);
	float sum = 0.0;
	for (int k = 0; k < 4; k++) {
		ivec2 o = ivec2(k % 2, k / 2);
		ivec2 c = clamp(i0 + o, ivec2(0), last);
		float w = (o.x == 1 ? f.x : 1.0 - f.x) * (o.y == 1 ? f.y : 1.0 - f.y);
		sum += w * flame(texelFetch(cell_data, c, 0).b, t)
			* breath(texelFetch(cell_extra, c, 0).r, t);
	}
	return sum;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
	instance_tint = INSTANCE_CUSTOM;
}

// The surface's height, for its relief: the broad swell of the stone, small
// pits, and on a floor a groove along every cell edge, so the joint the
// pattern draws is also a groove the light falls into.
float relief_height(vec3 p, int style, bool top) {
	float h = value_noise(p * 2.2) * 0.5 + value_noise(p * 22.0) * 0.18;
	if (style == 0 && top) {
		vec2 edge = min(fract(p.xz), vec2(1.0) - fract(p.xz));
		h -= (1.0 - smoothstep(0.02, 0.06, min(edge.x, edge.y))) * 0.35;
	} else if (style == 1) {
		vec2 bu = vec2(p.x + p.z, p.y) * vec2(2.0, 3.0);
		vec2 be = min(fract(bu), vec2(1.0) - fract(bu));
		h -= (1.0 - smoothstep(0.03, 0.08, min(be.x, be.y))) * 0.4;
	}
	return h;
}

void fragment() {
	vec3 base = instance_tint.rgb;
	float grain = hash31(floor(world_position * 47.0));
	float broad = value_noise(world_position * 2.2);
	float pattern = 1.0;

	if (surface_style == 0 && world_normal.y > 0.78) {
		// Each map cell reads as a worn flagstone, with a dark hairline joint,
		// mottled grain and tiny pits. The pattern follows cells as the camera turns.
		vec2 edge = min(UV, vec2(1.0) - UV);
		float joint = 1.0 - smoothstep(0.018, 0.045, min(edge.x, edge.y));
		float pits = value_noise(world_position * 22.0);
		pattern = 0.83 + broad * 0.15 + grain * 0.035 + pits * 0.045;
		pattern *= 1.0 - joint * 0.28;
	} else if (surface_style == 1) {
		// Hand-cut masonry blocks. Repeating joints are restrained so the wall
		// silhouette stays clear at game distance.
		vec2 brick_uv = UV * vec2(2.0, 3.0);
		vec2 brick_edge = min(fract(brick_uv), vec2(1.0) - fract(brick_uv));
		float joint = 1.0 - smoothstep(0.025, 0.075,
			min(brick_edge.x, brick_edge.y));
		float chisel = value_noise(world_position * 5.0);
		pattern = 0.78 + broad * 0.16 + chisel * 0.08 + grain * 0.025;
		pattern *= 1.0 - joint * 0.36;
	} else if (surface_style == 2) {
		// The made things (pillars, doors, and chests) get a smoother finish.
		pattern = 0.9 + broad * 0.10 + grain * 0.025;
	} else if (surface_style == 4 && world_normal.y > 0.78) {
		// Cave earth: coarse strata and a slightly warmer, uneven mineral bed.
		float strata = sin((world_position.x + world_position.z * 0.73) * 9.0);
		pattern = 0.72 + broad * 0.20 + abs(strata) * 0.08 + grain * 0.04;
	} else if (surface_style == 5 && world_normal.y > 0.78) {
		// Rubble chips break up the paving with many irregular dark fragments.
		vec2 chip_cell = UV * 8.0;
		vec2 chip_local = fract(chip_cell) - vec2(0.5);
		vec2 chip_id = floor(chip_cell);
		vec2 chip_offset = vec2(hash31(vec3(chip_id, 1.0)),
			hash31(vec3(chip_id, 2.0))) * 0.28 - vec2(0.14);
		float chips = 1.0 - smoothstep(0.12, 0.25, length(chip_local - chip_offset));
		pattern = 0.66 + broad * 0.16 + grain * 0.05 + chips * 0.26;
	} else if (surface_style == 6 && world_normal.y > 0.78) {
		// Still water shows broken, overlapping bands of ripple.
		float ripple_a = sin((world_position.x + world_position.z * 0.58) * 15.0);
		float ripple_b = sin((world_position.z - world_position.x * 0.37) * 11.0);
		pattern = 0.77 + (ripple_a + ripple_b) * 0.075 + broad * 0.08;
	} else if (surface_style == 7 && world_normal.y > 0.78) {
		// Mud has soft patches rather than the sharp seams of cut stone.
		float patches = smoothstep(0.30, 0.72, value_noise(world_position * 6.0));
		pattern = 0.58 + patches * 0.34 + grain * 0.035;
	} else if (surface_style == 8 && world_normal.y > 0.78) {
		// Small pale fragments make a bed of bones read differently from gravel.
		vec2 fragment_cell = UV * 7.0;
		vec2 fragment_local = fract(fragment_cell) - vec2(0.5);
		float fragments = 1.0 - smoothstep(0.11, 0.23,
			length(fragment_local * vec2(0.75, 1.25)));
		fragments *= step(0.28, hash31(vec3(floor(fragment_cell), 7.0)));
		pattern = 0.48 + broad * 0.12 + fragments * 0.48;
	} else if (surface_style == 9 && world_normal.y > 0.78) {
		// Fungus beds carry soft luminous-looking caps among darker moss.
		vec2 spore_cell = UV * 5.0;
		vec2 spore_local = fract(spore_cell) - vec2(0.5);
		float spores = 1.0 - smoothstep(0.10, 0.28, length(spore_local));
		spores *= step(0.46, hash31(vec3(floor(spore_cell), 9.0)));
		pattern = 0.60 + broad * 0.14 + spores * 0.40;
	} else if (surface_style == 10 && world_normal.y > 0.78) {
		// A pit is a hole in the floor, not a coloured tile: leave a stone lip
		// around a near-black centre, matching the classic renderer's open circle.
		pattern = 1.0;
	} else if (surface_style == 11 && world_normal.y > 0.78) {
		// Stair treads descend as four shaded bands towards their printed glyph.
		float tread = fract(UV.y * 4.0);
		float riser = 1.0 - smoothstep(0.03, 0.10, min(tread, 1.0 - tread));
		pattern = 0.72 + broad * 0.12 + (1.0 - riser * 0.32) * 0.18;
	} else if (surface_style == 12 && world_normal.y > 0.78) {
		// A trap's plate is visibly worked metal, with a faint cross-hatch.
		float hatch = abs(sin(UV.x * 48.0) * sin(UV.y * 48.0));
		pattern = 0.76 + broad * 0.12 + hatch * 0.10;
	} else if (surface_style == 13 && world_normal.y > 0.78) {
		// The shrine's coloured stone radiates from a circular carved seal.
		// Centred from the world position, for the pit's reason below.
		float radius = length(fract(world_position.xz) - vec2(0.5));
		float ring = 1.0 - smoothstep(0.025, 0.07, abs(radius - 0.30));
		pattern = 0.72 + broad * 0.12 + ring * 0.22;
	} else {
		// Natural rock is rougher and less regular than dressed masonry.
		float strata = sin((world_position.x + world_position.y * 0.37
			+ world_position.z * 0.61) * 17.0 + broad * 4.0);
		pattern = 0.72 + broad * 0.20 + grain * 0.04 + abs(strata) * 0.07;
	}

	vec3 surface;
	if (surface_style == 10 && world_normal.y > 0.78) {
		// The cell's own middle, from WHERE this is, not from UV: the floor is
		// a BoxMesh, whose six faces share one UV square -- the top face is a
		// patch of it that never contains (0.5, 0.5). Measured from UV, the
		// hole was never drawn, and a pit in the 3D view looked like floor
		// (Brad: "I keep falling in them and I never notice them").
		float radius = length(fract(world_position.xz) - vec2(0.5));
		float hole = 1.0 - smoothstep(0.30, 0.36, radius);
		// The lip: a thin ring just outside the hole. Its edges are distances
		// FROM the ring, so they are small. They were 0.36-0.40 -- as wide as
		// the whole tile -- which lit the "rim" at half strength everywhere,
		// the centre included, and painted the black hole back to a muddy
		// brown barely darker than the floor.
		float rim = 1.0 - smoothstep(0.012, 0.03, abs(radius - 0.38));
		surface = mix(base * (0.78 + broad * 0.12), vec3(0.006, 0.007, 0.010), hole);
		surface = mix(surface, base * 1.12, rim * 0.72);
	} else {
		surface = base * pattern;
	}

	// The cell this surface belongs to. A floor or a wall top is over its own
	// cell; a wall's side face sits on the boundary, so step half a cell back
	// into the wall -- the classic view lights a wall by its own cell too.
	vec2 probe = world_position.xz;
	if (abs(world_normal.y) < 0.5) {
		probe -= world_normal.xz * 0.49;
	}
	vec4 cell = texture(cell_light, probe / map_size);
	ivec2 texel = ivec2(clamp(floor(probe), vec2(0.0), map_size - vec2(1.0)));
	float seen = cell.a;
	if (!soft_view_edge) {
		// Read unblended, so in-view and remembered meet exactly on a cell edge.
		seen = texelFetch(cell_light, texel, 0).a;
	}
	vec3 lit = surface * cell.rgb;
	if (motion > 0) {
		lit *= living_pulse(probe);
	}
	if (motion > 1 && world_normal.y > 0.78) {
		// Smooth here: classic snaps these to its blocks, and a 3D surface has
		// no blocks to keep. Same waves, same colours.
		if (surface_style == 6) {
			lit += water_light(water_wave(world_position.xz, t), 0);
		} else if (surface_style == 9) {
			lit += fungus_glow(texelFetch(cell_data, texel, 0).g * 6.2831853, t, 0);
		}
	}
	// Memory fades with time, per cell as the classic view draws it -- see
	// MapMemory. A landmark arrives unfaded, and is also shown as it is below.
	float faded = texelFetch(cell_extra, texel, 0).g;
	vec3 remembered = mix(surface, memory_tint.rgb, memory_mix) * memory_dim
		* memory_strength * (1.0 - faded);
	// A landmark (the stairs) arrives already in its remembered colour.
	remembered = mix(remembered, surface, step(instance_tint.a, 0.75));
	// A fixed shade per face keeps a block's shape where no engine light
	// reaches: tops brightest, then the faces along one axis, then the other.
	float face = world_normal.y > 0.5 ? 1.0 : (abs(world_normal.z) > 0.5 ? 0.82 : 0.68);
	// Information goes out as emission: the light map's colour on a seen
	// cell (at map_weight, the lights supply the rest), the memory colour on
	// a remembered one. The albedo is what the engine lights have to work
	// with, and it is zero where nothing is seen.
	vec3 shown = lit * map_weight;
	// Style 14, a GLOW (the shrine's crystal, 2026-10-10): its own colour,
	// lit as a card is -- the cell's light, raised to at least 0.45 -- so it
	// reads in a dim room. Its own colour only: it lights nothing else, and
	// remembered it fades as everything does.
	if (surface_style == 14) {
		shown = surface * mix(cell.rgb, vec3(1.0), 0.45);
	}
	vec3 emit = mix(remembered, shown, seen) * face;
	vec3 albedo = surface * face * seen;
	if (linear_light) {
		emit = pow(max(emit, vec3(0.0)), vec3(2.2));
		albedo = pow(max(albedo, vec3(0.0)), vec3(2.2));
	}
	EMISSION = emit;
	ALBEDO = albedo;
	seen_v = seen;
	gloss_v = (surface_style == 6 && world_normal.y > 0.78) ? 1.0 : 0.0;
	ROUGHNESS = surface_style == 6 ? 0.15 : 0.95;
	SPECULAR = surface_style == 6 ? 0.5 : 0.1;
	// Relief: tilt the normal by the height's slope along the face's own two
	// axes, so the light that reaches a face finds grooves and pits in it.
	if (relief > 0.0 && surface_style != 6 && surface_style != 10) {
		bool top = world_normal.y > 0.78;
		vec3 ta = top ? vec3(1.0, 0.0, 0.0) : (abs(world_normal.x) > 0.5 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0));
		vec3 tb = top ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
		float e = 0.015;
		float h0 = relief_height(world_position, surface_style, top);
		float ha = relief_height(world_position + ta * e, surface_style, top);
		float hb = relief_height(world_position + tb * e, surface_style, top);
		vec3 bent = normalize(world_normal - (ta * (ha - h0) + tb * (hb - h0)) * (relief * 6.0));
		NORMAL = normalize((VIEW_MATRIX * vec4(bent, 0.0)).xyz);
	}
}

// Each engine light, masked by whether the cell is in view: Lambert on the
// relief normal, and a glossy highlight on water only.
void light() {
	float n_dot_l = max(dot(NORMAL, LIGHT), 0.0);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * n_dot_l * light_weight * seen_v;
	if (gloss_v > 0.0) {
		vec3 h = normalize(LIGHT + VIEW);
		float spec = pow(max(dot(NORMAL, h), 0.0), 48.0);
		SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * spec * 0.6 * seen_v;
	}
}
