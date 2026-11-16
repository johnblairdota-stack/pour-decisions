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
uniform float gloss = 0.8;        // (how much sky it mirrors: Spire's muddy river takes less)
uniform float rough = 0.12;
// Spire's river from the bridge and the CityCat: the Story Bridge's shadow lying across the water, and
// soft darker smears running towards the camera off the far bank, as the towers' reflections do.
uniform float smear = 0.0;
uniform vec4 shade_line = vec4(0.0);      // (a point on the bridge's centre line xz, its direction xz)
uniform vec4 far_tint : source_color = vec4(0.42, 0.52, 0.60, 1.0);
uniform float far_mix = 0.0;
uniform float shade_dark = 0.38;
uniform float shade_half = 0.0;           // (half the shadow's width, m: 0 = none)

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
	if (smear > 0.0) {
		vec3 cam = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		vec2 to = p - cam.xz;
		float ang = atan(to.y, to.x);
		// (broad soft bands only: fine ones read as scratches down the picture)
		float k = sin(ang * 19.0) * 0.6 + sin(ang * 41.0 + 1.7) * 0.4;
		float far = smoothstep(120.0, 420.0, dist);
		ALBEDO *= 1.0 - smear * far * smoothstep(-0.2, 0.9, k);
		// (the far reach takes the sky's colour, as flat water seen at a low angle does)
		ALBEDO = mix(ALBEDO, far_tint.rgb, far_mix * smoothstep(150.0, 900.0, dist));
	}
	if (shade_half > 0.0) {
		vec2 rel = p - shade_line.xy;
		float off = abs(rel.x * shade_line.w - rel.y * shade_line.z);
		ALBEDO *= 1.0 - shade_dark * (1.0 - smoothstep(shade_half * 0.75, shade_half, off));
	}
	ROUGHNESS = rough;
	SPECULAR = gloss;
	// Glints: the steepest ripple crests, now and then
	float c = sin(p.x * 1.9 + TIME * 1.3) * sin(p.y * 2.3 - TIME * 0.9) * sin((p.x + p.y) * 0.7 + TIME * 0.5);
	EMISSION = vec3(1.0, 0.97, 0.88) * smoothstep(0.93, 0.99, c) * 0.35 * glint * near;
}
