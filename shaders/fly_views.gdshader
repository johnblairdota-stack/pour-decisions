shader_type canvas_item;
// The rendered fly-in (scripts/fly_views.gd): one view pushed in, the next one coming up through its
// middle, and the cloud it starts in.
uniform sampler2D pic_a : filter_linear, repeat_disable;
uniform sampler2D pic_b : filter_linear, repeat_disable;
uniform float za = 1.0;        // how far view a is pushed in (1 and up)
uniform float zb = 1.0;        // view b's size on the way in (under 1 till it fills the screen)
uniform float mix_b = 0.0;
uniform vec2 fit = vec2(1.0);  // the picture cropped to the screen's shape
uniform float cloud = 0.0;     // 1: nothing but cloud, 0: clear
uniform float cloud_t = 0.0;   // s: the cloud streams out past the lens
uniform float aspect = 1.7778;
uniform float fade = 1.0;
uniform vec3 cloud_col : source_color = vec3(0.92, 0.93, 0.95);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 c = (UV - 0.5) * fit;
	vec3 col = texture(pic_a, c / za + 0.5).rgb;
	vec2 ub = c / zb + 0.5;
	float e = min(min(ub.x, 1.0 - ub.x), min(ub.y, 1.0 - ub.y));
	col = mix(col, texture(pic_b, ub).rgb, mix_b * smoothstep(0.0, 0.1, e));
	// (two decks of cloud, the near one streaming out faster)
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0);
	float far = fbm(p * 2.2 / (1.0 + cloud_t * 0.5) + vec2(3.0, 1.0));
	float near = fbm(p * 1.1 / (1.0 + cloud_t * 1.6) + vec2(-8.0, 5.0));
	float n = mix(far, near, 0.55);
	float d = clamp((n - 0.5) * 2.4 + 0.5 + cloud * 2.0 - 1.0, 0.0, 1.0);
	col = mix(col, cloud_col * (0.94 + 0.06 * far), d);
	COLOR = vec4(col, fade);
}
