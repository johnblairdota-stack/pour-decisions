// Toon facade with procedural lit windows, placed in world space so any box tiles cleanly.
shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform vec4 frame_color : source_color = vec4(0.12, 0.17, 0.29, 1.0);
uniform vec4 glass_color : source_color = vec4(0.20, 0.30, 0.46, 1.0);
uniform vec4 lit_color : source_color = vec4(1.0, 0.82, 0.48, 1.0);
uniform vec2 cell = vec2(2.0, 3.0);
uniform float lit_ratio = 0.5;
uniform float glow = 1.2;

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
	EMISSION = win * lit * lit_color.rgb * glow;
	ROUGHNESS = 0.6;
}
