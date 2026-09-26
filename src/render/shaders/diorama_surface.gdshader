shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Multimesh instance colours carry the palette and simulated light. These
// small patterns add material character without changing that game information.
uniform int surface_style = 0; // 0 floor, 1 masonry, 2 worked stone, 3 natural rock
uniform float roughness = 0.9;

varying vec3 world_position;
varying vec3 world_normal;
varying vec4 instance_tint;

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

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
	instance_tint = INSTANCE_CUSTOM;
}

void fragment() {
	vec3 base = instance_tint.rgb;
	float grain = hash31(floor(world_position * 47.0));
	float broad = value_noise(world_position * 2.2);
	float pattern = 1.0;
	float material_roughness = roughness;
	float material_specular = 0.22;

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
		material_roughness = 0.76;
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
		// Still water catches broken, overlapping bands of reflected light.
		float ripple_a = sin((world_position.x + world_position.z * 0.58) * 15.0);
		float ripple_b = sin((world_position.z - world_position.x * 0.37) * 11.0);
		pattern = 0.77 + (ripple_a + ripple_b) * 0.075 + broad * 0.08;
		material_roughness = 0.28;
		material_specular = 0.42;
	} else if (surface_style == 7 && world_normal.y > 0.78) {
		// Mud has soft patches rather than the sharp seams of cut stone.
		float patches = smoothstep(0.30, 0.72, value_noise(world_position * 6.0));
		pattern = 0.58 + patches * 0.34 + grain * 0.035;
		material_roughness = 1.0;
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
		material_roughness = 0.62;
	} else if (surface_style == 13 && world_normal.y > 0.78) {
		// The shrine's coloured stone radiates from a circular carved seal.
		float radius = length(UV - vec2(0.5));
		float ring = 1.0 - smoothstep(0.025, 0.07, abs(radius - 0.30));
		pattern = 0.72 + broad * 0.12 + ring * 0.22;
	} else {
		// Natural rock is rougher and less regular than dressed masonry.
		float strata = sin((world_position.x + world_position.y * 0.37
			+ world_position.z * 0.61) * 17.0 + broad * 4.0);
		pattern = 0.72 + broad * 0.20 + grain * 0.04 + abs(strata) * 0.07;
	}

	if (surface_style == 10 && world_normal.y > 0.78) {
		float radius = length(UV - vec2(0.5));
		float hole = 1.0 - smoothstep(0.30, 0.36, radius);
		float rim = 1.0 - smoothstep(0.36, 0.40, abs(radius - 0.38));
		ALBEDO = mix(base * (0.78 + broad * 0.12), vec3(0.006, 0.007, 0.010), hole);
		ALBEDO = mix(ALBEDO, base * 1.12, rim * 0.72);
		ROUGHNESS = 1.0;
		SPECULAR = 0.05;
	} else {
		ALBEDO = base * pattern;
		ROUGHNESS = material_roughness;
		SPECULAR = material_specular;
	}
}
