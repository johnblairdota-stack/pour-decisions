// Compacted concrete: the cream comes up and the spot goes glossy. A soft
// disc of pale cream over the slurry with a wobbly edge, and streaks of
// sky-glare sliding slowly across it, so a done spot looks wet and shiny
// next to the dull grey raw concrete. `amount` 0..1 brings it in.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float amount = 0.0;
uniform vec4 cream : source_color = vec4(0.82, 0.79, 0.69, 1.0);
uniform vec4 glare : source_color = vec4(1.0, 0.99, 0.95, 1.0);
uniform float seed = 0.0;
uniform float low_light = 0.0;

varying vec3 wp;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float ang = atan(p.y, p.x);
	// (the edge wobbles, and creeps out as the cream comes up)
	float edge = 0.55 + 0.4 * amount + 0.07 * (noise(vec2(ang * 1.6 + seed, seed)) - 0.5) + 0.03 * sin(ang * 3.0 + seed) + 0.02 * sin(ang * 7.0 - seed);
	float r = length(p);
	float body = 1.0 - smoothstep(edge - 0.25, edge, r);
	// glare streaks drifting across in world space, so neighbouring spots line up
	vec2 s = wp.xz * vec2(1.3, 0.35) + vec2(TIME * 0.12, 0.0);
	float streak = smoothstep(0.62, 0.95, noise(s * 2.0 + seed)) * 0.9;
	// (little round glints that come and go)
	vec2 cell = wp.xz * 22.0;
	float glint = step(0.93, hash(floor(cell) + floor(TIME * 2.0 + hash(floor(cell)))));
	float sparkle = glint * (1.0 - smoothstep(0.08, 0.2, length(fract(cell) - 0.5))) * 0.9;
	vec3 c = mix(cream.rgb, glare.rgb, clamp(streak + sparkle, 0.0, 1.0));
	// a faint darker wet line just inside the edge
	c *= 1.0 - 0.12 * smoothstep(edge - 0.12, edge - 0.04, r) * (1.0 - smoothstep(edge - 0.04, edge, r));
	c *= 1.0 + low_light * 0.3;
	ALBEDO = c;
	ALPHA = body * amount * 0.82;
}
