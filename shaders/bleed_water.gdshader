// Over-vibrated: bleed water. A grey-blue puddle that spreads out from the
// poker over the cream, with rings rippling out from the middle (the poker's
// still shaking it), sky reflected in it and glints on the ripples. It looks
// like the wrong thing on purpose: the spot's been held too long.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float amount = 0.0;    // 0..1: how far it's spread
uniform float shake = 1.0;     // 0..1: ripples while the poker's still in
uniform vec4 water : source_color = vec4(0.42, 0.52, 0.6, 1.0);
uniform vec4 sky : source_color = vec4(0.82, 0.9, 0.97, 1.0);
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
	// a puddle edge: lobes, not a circle
	float edge = amount * (0.78 + 0.18 * noise(vec2(ang * 1.8 + seed, seed * 3.0)));
	float aa = fwidth(r) * 2.0;
	float body = 1.0 - smoothstep(edge - aa - 0.03, edge, r);
	// ripple rings running out from the middle
	float rip = sin(r * 42.0 - TIME * 9.0) * shake * (1.0 - r);
	float ring = smoothstep(0.55, 1.0, rip);
	// sky reflected, brighter at the far side (view-ish), glints on ripples
	float refl = 0.35 + 0.35 * noise(p * 3.0 + vec2(TIME * 0.2, seed));
	vec3 c = mix(water.rgb, sky.rgb, refl);
	c = mix(c, vec3(1.0), ring * 0.65);
	float glint = step(0.97, hash(floor(p * 30.0) + floor(TIME * 6.0))) * ring;
	c += glint;
	// a bright meniscus line round the edge
	float lip = smoothstep(edge - 0.06, edge - 0.02, r) * body;
	c = mix(c, sky.rgb * 1.1, lip * 0.6);
	ALBEDO = c;
	ALPHA = body * clamp(amount * 3.0, 0.0, 1.0) * 0.78;
}
