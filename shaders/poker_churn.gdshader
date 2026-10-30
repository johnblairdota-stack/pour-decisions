// Round a working poker: the slurry churns. A pale, frothy patch with fine
// rings trembling out from the poker and foam specks that boil about. It's
// the bit that still reads from the couch when the bubbles are only dots:
// while it's there, the poker's still bringing air up. `amount` 0..1.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float amount = 0.0;
uniform vec4 froth : source_color = vec4(0.8, 0.79, 0.75, 1.0);
uniform float seed = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float edge = 0.85 + 0.1 * (noise(vec2(ang * 3.0 + seed, TIME * 2.0)) - 0.5);
	float body = 1.0 - smoothstep(edge - 0.35, edge, r);
	// trembling rings running out
	float rings = smoothstep(0.3, 1.0, sin(r * 30.0 - TIME * 16.0)) * (1.0 - r);
	// foam specks that churn about
	vec2 q = p * 9.0 + vec2(sin(TIME * 3.0 + r * 6.0), cos(TIME * 2.6 - r * 5.0)) * 0.6;
	float foam = smoothstep(0.55, 0.8, noise(q + seed) * noise(q * 1.9 - TIME * 1.5));
	ALBEDO = mix(froth.rgb * 0.9, vec3(0.97, 0.96, 0.93), clamp(rings * 0.6 + foam * 1.6, 0.0, 1.0));
	ALPHA = body * amount * clamp(0.35 + rings * 0.35 + foam * 0.9, 0.0, 0.85);
}
