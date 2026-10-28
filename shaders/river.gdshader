// The Brisbane River: its olive green-grey, glossy so it picks up the sky,
// small wind ripples drifting downstream (towards -x) and a few glints
// where they catch the sun. The ripples fade out with distance so the far
// reaches stay calm and don't shimmer.
shader_type spatial;
render_mode cull_disabled;

uniform vec4 water : source_color = vec4(0.31, 0.4, 0.376, 1.0);
uniform vec4 sky : source_color = vec4(0.66, 0.78, 0.86, 1.0);
uniform float ripple = 1.0;
uniform float glint = 1.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// One travelling wave's slope (d/dx, d/dz) for direction `d`, wavelength `l`.
vec2 slope(vec2 p, vec2 d, float l, float speed, float amp) {
	float k = 6.2832 / l;
	return d * k * amp * cos(dot(p, d) * k - TIME * speed * k);
}

void fragment() {
	vec2 p = wpos.xz;
	float dist = length(VERTEX);
	float near = ripple * 0.4 * (1.0 - smoothstep(25.0, 220.0, dist));
	vec2 g = slope(p, normalize(vec2(-1.0, 0.25)), 7.0, 0.6, 0.05)
		+ slope(p, normalize(vec2(-0.7, -0.7)), 3.1, 0.45, 0.025)
		+ slope(p, normalize(vec2(-0.2, 1.0)), 1.7, 0.35, 0.012)
		+ slope(p, normalize(vec2(-1.0, -0.15)), 13.0, 0.9, 0.08);
	g *= near;
	vec3 n = normalize(vec3(-g.x, 1.0, -g.y));
	// (the river's mesh faces away from the camera and has always been lit
	// from its underside, which is what gives it its deep grey-blue: keep that)
	if (!FRONT_FACING) {
		n.y = -n.y;
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	// (the sky's reflection does the rest: glossy, as the river always was)
	ALBEDO = mix(water.rgb, sky.rgb, clamp(-g.x * 1.5, 0.0, 0.06) * near);
	ROUGHNESS = 0.12;
	SPECULAR = 0.8;
	// Glints: the steepest ripple crests, now and then
	float c = sin(p.x * 1.9 + TIME * 1.3) * sin(p.y * 2.3 - TIME * 0.9) * sin((p.x + p.y) * 0.7 + TIME * 0.5);
	EMISSION = vec3(1.0, 0.97, 0.88) * smoothstep(0.93, 0.99, c) * 0.35 * glint * near;
}
