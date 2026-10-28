// The sky over the site (scripts/main.gd): the blue overhead fading to the
// hazy horizon, the sun, and a Brisbane morning's clouds: scattered fair
// weather cumulus low down and a few wisps of cirrus high up. The clouds are
// lit by the sun itself (its colour, its height, which side it's on), so at
// a dawn pour they go from dark shapes on a dark sky to pink and gold edges
// as it comes up over Bulimba, then white by full morning. They don't move
// (a sky that changes every frame would relight the whole world every frame).
shader_type sky;

uniform vec3 sky_top : source_color = vec3(0.23, 0.47, 0.79);
uniform vec3 sky_horizon : source_color = vec3(0.81, 0.87, 0.91);
uniform float cover = 0.42;      // how much of the sky the cumulus covers, 0-1
uniform float sun_size = 0.025;  // the sun's disc, radians across

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), u.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += vnoise(p) * a;
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

// (crisp edged, like everything else in the toon world)
float cumulus(vec2 p) {
	float d = fbm(p);
	return smoothstep(1.0 - cover, 1.0 - cover + 0.06, d);
}

void sky() {
	vec3 dir = EYEDIR;
	float up = max(dir.y, 0.0);
	vec3 sun_dir = LIGHT0_ENABLED ? LIGHT0_DIRECTION : vec3(0.0, 1.0, 0.0);
	vec3 sun_col = LIGHT0_ENABLED ? LIGHT0_COLOR * LIGHT0_ENERGY : vec3(1.0);
	float sun_up = smoothstep(-0.12, 0.25, sun_dir.y);
	// Blue overhead, the haze at the horizon, warmer and brighter towards the sun
	vec3 col = mix(sky_horizon, sky_top, pow(up, 0.55));
	float toward = max(dot(dir, sun_dir), 0.0);
	col += sun_col * pow(toward, 8.0) * 0.18 * (1.0 - up * 0.6);
	// Below the horizon: the haze carries on (the land and the river cover it)
	if (dir.y < 0.0) {
		col = sky_horizon;
	}
	if (AT_CUBEMAP_PASS) {
		// (the light the world gets from the sky: no sun disc, the clouds as a
		// soft whitening)
		col = mix(col, mix(sky_horizon, vec3(0.85), 0.5) * (0.4 + 0.6 * sun_up), cover * 0.35 * smoothstep(0.0, 0.2, dir.y));
		COLOR = col;
	} else {
		// The sun's disc and its glare
		float ang = acos(clamp(dot(dir, sun_dir), -1.0, 1.0));
		col += sun_col * (smoothstep(sun_size, sun_size * 0.6, ang) * 6.0 + pow(toward, 300.0) * 0.6);
		if (dir.y > 0.0) {
			// Clouds on a flat layer overhead: further off they bunch up and
			// thin into the haze
			vec2 uv = dir.xz / (dir.y + 0.06);
			vec2 sxz = sun_dir.xz / max(length(sun_dir.xz), 0.001);
			float d = cumulus(uv * 0.55 + vec2(3.0, -1.0));
			// self shadowing: thicker cloud between here and the sun
			float d2 = cumulus(uv * 0.55 + vec2(3.0, -1.0) + sxz * 0.12);
			float lit = clamp(1.0 - (d2 - d) * 1.4 - d2 * 0.35, 0.0, 1.0);
			// (toon: lit or in shade, a soft step between)
			lit = smoothstep(0.35, 0.55, lit + (fbm(uv * 2.2) - 0.5) * 0.4);
			// flat grey-blue undersides, the sun's colour on the lit tops,
			// a bright rim where the sun's behind them
			vec3 shade = mix(sky_horizon, sky_top, 0.35) * mix(0.35, 0.85, sun_up);
			vec3 light = mix(shade, sun_col * 0.9 + sky_horizon * 0.25, lit);
			light += sun_col * pow(toward, 6.0) * (1.0 - d) * 0.8;
			float fade = smoothstep(0.0, 0.18, dir.y);
			col = mix(col, light, d * fade * 0.95);
			// Cirrus: faint streaks high up, catching the sun
			vec2 cu = dir.xz / (dir.y + 0.25) * vec2(0.9, 3.5);
			float ci = smoothstep(0.55, 0.85, fbm(cu * 0.6 + vec2(7.0, 2.0))) * smoothstep(0.1, 0.4, dir.y);
			col = mix(col, mix(sky_horizon, sun_col, 0.5 * sun_up) * (0.6 + 0.4 * sun_up), ci * 0.35 * (1.0 - d));
		}
		COLOR = col;
	}
}
