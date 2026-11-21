// The CityCat's wake in the river flights: a V of foam off the stern with churned water down
// the middle, breaking up and thinning as it trails. One flat sheet behind the boat (main.gd),
// UV.y 0 at the stern and 1 at the far end. All of it's worked out here: nothing per frame in script.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 foam : source_color = vec3(0.92, 0.94, 0.90);
uniform float strength = 0.85;
uniform float run = 3.2;          // how fast the foam slides back along it

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float v = UV.y;
	float x = abs(UV.x - 0.5) * 2.0;
	// (the arms open from the hulls' width to the sheet's edge)
	float half_w = mix(0.2, 0.92, pow(v, 0.75));
	float n = noise(vec2(UV.x * 9.0, v * 46.0 - TIME * run));
	float n2 = noise(vec2(UV.x * 23.0, v * 120.0 - TIME * run * 1.7));
	float arm = smoothstep(0.16 + 0.1 * v, 0.0, abs(x - half_w + 0.08 * (n - 0.5)));
	float churn = smoothstep(half_w * 0.8, 0.0, x) * pow(1.0 - v, 1.6);
	float a = arm * (1.0 - v * v) * mix(0.5, 1.0, n) + churn * mix(0.35, 1.0, n2);
	a *= smoothstep(0.0, 0.04, v) * (1.0 - smoothstep(0.82, 1.0, v));
	ALBEDO = foam;
	ALPHA = clamp(a * strength, 0.0, 1.0);
}
