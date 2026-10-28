// The ground's surfaces, drawn on top of their flat colours in world space
// (shaders/ground.gdshader, shaders/base_ground.gdshader): grass in mottled
// patches with the odd dry spot (mown in stripes on the golf course and the
// pitch), the beach's sand grained and wind-rippled, bare dirt, concrete
// pavers on the footpaths and the riverwalk, and the road's asphalt. Each
// pattern fades out once it's finer than a pixel, so far off the ground is
// its plain colour and doesn't shimmer.

const int GD_PLAIN = 0;
const int GD_GRASS = 1;
const int GD_GOLF = 2;
const int GD_SCRUB = 3;
const int GD_SAND = 4;
const int GD_DIRT = 5;
const int GD_PAVERS = 6;
const int GD_ASPHALT = 7;

float gd_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float gd_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(gd_hash(i), gd_hash(i + vec2(1.0, 0.0)), u.x),
		mix(gd_hash(i + vec2(0.0, 1.0)), gd_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float gd_fbm(vec2 p) {
	return gd_noise(p) * 0.55 + gd_noise(p * 2.13 + 7.1) * 0.3 + gd_noise(p * 4.37 - 3.3) * 0.15;
}

// How much of a pattern this size (m) still shows when a pixel covers px m
float gd_fade(float size, float px) {
	return 1.0 - smoothstep(size * 0.35, size * 1.2, px);
}

vec3 gd_grass(vec3 col, vec2 wp, float px, bool mown) {
	// big soft patches, lighter and darker
	col *= mix(0.86, 1.1, gd_fbm(wp * 0.07));
	// the odd dry, yellowed patch
	float dry = smoothstep(0.62, 0.78, gd_fbm(wp * 0.023 + 11.0));
	col = mix(col, col * vec3(1.18, 1.08, 0.72), dry * 0.55);
	// clumps
	col *= 1.0 + (gd_noise(wp * 1.3) - 0.5) * 0.14 * gd_fade(0.8, px);
	// blades
	col *= 1.0 + (gd_noise(wp * 9.0) - 0.5) * 0.14 * gd_fade(0.11, px);
	if (mown) {
		// mowing stripes, 6 m wide, across the fairways
		float s = step(0.5, fract(dot(wp, vec2(0.6, 0.8)) / 12.0));
		col *= mix(0.93, 1.06, s);
	}
	return col;
}

vec3 gd_sand(vec3 col, vec2 wp, float px) {
	col *= mix(0.93, 1.05, gd_fbm(wp * 0.15));
	// wind ripples, wobbly, a hand span apart
	float rip = sin(dot(wp, vec2(0.35, 0.94)) * 26.0 + gd_noise(wp * 0.6) * 6.0);
	col *= 1.0 + rip * 0.035 * gd_fade(0.25, px);
	// grains, and darker shell grit
	col *= 1.0 + (gd_noise(wp * 30.0) - 0.5) * 0.1 * gd_fade(0.033, px);
	col *= 1.0 - smoothstep(0.86, 0.93, gd_noise(wp * 9.0 + 3.0)) * 0.25 * gd_fade(0.1, px);
	return col;
}

vec3 gd_dirt(vec3 col, vec2 wp, float px) {
	col *= mix(0.84, 1.1, gd_fbm(wp * 0.09));
	// darker damp hollows
	col *= 1.0 - smoothstep(0.6, 0.8, gd_fbm(wp * 0.03 - 5.0)) * 0.15;
	// stones
	float st = smoothstep(0.8, 0.86, gd_noise(wp * 5.0 + 9.0));
	col = mix(col, vec3(0.62, 0.6, 0.56), st * 0.45 * gd_fade(0.2, px));
	col *= 1.0 + (gd_noise(wp * 18.0) - 0.5) * 0.14 * gd_fade(0.055, px);
	return col;
}

// Concrete pavers, 600 x 300 laid in stretcher bond, each its own shade,
// grey joints between
vec3 gd_pavers(vec3 col, vec2 wp, float px) {
	vec2 sz = vec2(0.6, 0.3);
	vec2 q = wp / sz;
	q.x += step(1.0, mod(floor(q.y), 2.0)) * 0.5;
	vec2 id = floor(q);
	vec2 f = fract(q);
	float shade = mix(0.93, 1.05, gd_hash(id + 17.0));
	// (a few of them a warmer, sandier mix)
	vec3 tone = mix(col, col * vec3(1.03, 1.0, 0.94), step(0.8, gd_hash(id + 3.0)));
	float k = gd_fade(0.3, px);
	vec3 c = mix(col, tone * shade, k);
	// joints: 6 mm in a 300 mm paver, wider in screen terms as it gets small
	vec2 jw = vec2(0.012) / sz;
	vec2 edge = smoothstep(vec2(0.0), jw, f) * smoothstep(vec2(0.0), jw, 1.0 - f);
	float joint = 1.0 - edge.x * edge.y;
	c = mix(c, c * 0.78, joint * gd_fade(0.12, px));
	// weathering across the whole walk
	c *= mix(0.93, 1.04, gd_fbm(wp * 0.11));
	return c;
}

vec3 gd_asphalt(vec3 col, vec2 wp, float px) {
	col *= mix(0.92, 1.06, gd_fbm(wp * 0.05));
	col *= 1.0 + (gd_noise(wp * 20.0) - 0.5) * 0.14 * gd_fade(0.05, px);
	return col;
}

vec3 ground_detail(vec3 col, int code, vec2 wp, float px) {
	if (code == GD_GRASS) {
		return gd_grass(col, wp, px, false);
	} else if (code == GD_GOLF) {
		return gd_grass(col, wp, px, true);
	} else if (code == GD_SCRUB) {
		return gd_grass(col, wp * 1.7, px, false) * mix(0.9, 1.05, gd_noise(wp * 0.4));
	} else if (code == GD_SAND) {
		return gd_sand(col, wp, px);
	} else if (code == GD_DIRT) {
		return gd_dirt(col, wp, px);
	} else if (code == GD_PAVERS) {
		return gd_pavers(col, wp, px);
	} else if (code == GD_ASPHALT) {
		return gd_asphalt(col, wp, px);
	}
	return col;
}
