// Chain-link wire (scripts/fences.gd): a diamond mesh close up, a fine
// see-through dither further off so it never shimmers.
shader_type spatial;
render_mode diffuse_toon, specular_toon, cull_disabled;

uniform vec4 wire : source_color = vec4(0.73, 0.76, 0.79, 1.0);
uniform float pitch = 0.06;      // diamond size, m
uniform float near = 10.0;       // the diamonds fade into the dither from here
uniform float far = 30.0;
uniform float cover = 0.3;       // how much of the fence the dither fills

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float u = abs(wnorm.x) > abs(wnorm.z) ? wpos.z : wpos.x;
	vec2 q = vec2(u + wpos.y, u - wpos.y) / pitch;
	vec2 f = abs(fract(q) - 0.5);
	float wire_on = step(0.38, max(f.x, f.y));
	ivec2 px = ivec2(FRAGCOORD.xy) % 4;
	float bayer = float((px.x * 4 + px.y * 7) % 16) / 16.0;
	float dither = step(bayer, cover);
	float k = smoothstep(near, far, length(wpos - CAMERA_POSITION_WORLD));
	if (mix(wire_on, dither, k) < 0.5) {
		discard;
	}
	ALBEDO = wire.rgb;
	ROUGHNESS = 0.6;
}
