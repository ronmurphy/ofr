shader_type canvas_item;
// THE LAST PASS (the 3D look, 2026-10-01): over the finished 3D frame, a
// vignette that gathers the eye to the torch, and a little grain so flat
// dark is never flat. Drawn on a ColorRect over the viewport container, so
// it reads the frame BEHIND it: a ColorRect's own TEXTURE is a white pixel,
// and the first version painted the whole view white with it. The grain is
// still on "still" -- its seed is fed, not TIME -- so a screenshot holds and
// nothing moves for anyone who asked for nothing to move.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float vignette = 0.55;
uniform float grain = 0.045;
uniform float seed = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec4 c = texture(screen_tex, SCREEN_UV);
	vec2 d = UV - vec2(0.5);
	float r = length(d * vec2(1.25, 1.0));
	float dark = smoothstep(0.42, 0.95, r) * vignette;
	float g = (hash21(FRAGCOORD.xy + vec2(seed)) - 0.5) * grain;
	COLOR = vec4(c.rgb * (1.0 - dark) + vec3(g), 1.0);
}
