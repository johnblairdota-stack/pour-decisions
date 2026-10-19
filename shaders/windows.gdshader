// Toon facade with procedural lit windows, placed in world space so any box tiles cleanly.
shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform vec4 frame_color : source_color = vec4(0.12, 0.17, 0.29, 1.0);
uniform vec4 glass_color : source_color = vec4(0.20, 0.30, 0.46, 1.0);
uniform vec4 lit_color : source_color = vec4(1.0, 0.82, 0.48, 1.0);
uniform vec2 cell = vec2(2.0, 3.0);
uniform float lit_ratio = 0.5;
uniform float glow = 1.2;
// Riverlight's residential skin: a white slab band every floor, dark-framed
// grey-green glass with a glass balustrade across the bottom, and a charcoal
// panel column every few bays
uniform bool riverlight = false;
uniform vec4 panel_color : source_color = vec4(0.35, 0.37, 0.41, 1.0);
uniform vec4 mullion_color : source_color = vec4(0.17, 0.18, 0.20, 1.0);
uniform float panel_every = 4.0;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float h = abs(wnorm.x) > abs(wnorm.z) ? wpos.z : wpos.x;
	vec2 uv = vec2(h, wpos.y) / cell;
	vec2 f = fract(uv);
	float win = step(0.14, f.x) * step(f.x, 0.86) * step(0.22, f.y) * step(f.y, 0.82);
	if (abs(wnorm.y) > 0.9) {
		win = 0.0;
	}
	float lit = step(1.0 - lit_ratio, hash(floor(uv) + floor(wpos.xz * 0.01)));
	ALBEDO = mix(frame_color.rgb, glass_color.rgb, win);
	if (riverlight && abs(wnorm.y) < 0.9) {
		float band = 1.0 - step(0.05, f.y) * step(f.y, 0.86);
		float bay = floor(uv.x);
		float panel = step(panel_every - 0.5, mod(bay, panel_every));
		float mull = 1.0 - step(0.04, f.x) * step(f.x, 0.96);
		float rail = step(0.33, f.y) * step(f.y, 0.36);
		vec3 glass = f.y < 0.34 ? mix(glass_color.rgb, vec3(0.62, 0.70, 0.72), 0.45) : glass_color.rgb;
		vec3 c = mix(glass, mullion_color.rgb, max(mull, rail));
		c = mix(c, panel_color.rgb, panel);
		ALBEDO = mix(c, frame_color.rgb, band);
		win = (1.0 - band) * (1.0 - panel) * (1.0 - mull) * step(0.36, f.y);
	}
	EMISSION = win * lit * lit_color.rgb * glow;
	ROUGHNESS = 0.6;
}
