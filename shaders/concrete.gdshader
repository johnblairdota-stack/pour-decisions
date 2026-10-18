// Fresh concrete surface drawn from the pour heightfield.
// Placed concrete starts lumpy and matte, full of trapped air. A poker in it
// makes the surface tremble and spit little air bubbles, and once it's
// compacted the cream comes up and it goes smooth and glossy. Screeding
// flattens the lumps into a satin finish. Then matte light-grey once cured.
shader_type spatial;

uniform sampler2D height_tex : filter_linear, repeat_disable;
// r: how far through its open time (1 = gone off)
// g: 1 = cold joint, 0.5 = bleed water, 0.25 = the wet edge
// b: vibrated (compacted)
// a: screeded
uniform sampler2D state_tex : filter_nearest, repeat_disable;
uniform vec2 cell_m = vec2(0.333, 0.333);
uniform vec2 slab_size = vec2(16.0, 12.0);
uniform float cured : hint_range(0.0, 1.0) = 0.0;
// Up to four pokers running: local x, local z, strength 0..1
uniform vec4 shiver[4];
// Someone holding the poker sees the concrete still to be vibrated; someone
// holding the screed board sees what's ready to screed
uniform float poker_view : hint_range(0.0, 1.0) = 0.0;
uniform float screed_view : hint_range(0.0, 1.0) = 0.0;
// The wet edge glows: green while it's fresh, amber as it ages, red and
// pulsing fast when it's about to go off. Brighter for whoever's on the boom.
uniform float edge_view : hint_range(0.0, 1.0) = 0.4;
// > 0: a round slab of this radius (local metres); outside it there's no slab
uniform float round_r = 0.0;

varying float vh;
varying vec2 lp;
varying float near_poker;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	vec2 px = 1.0 / vec2(textureSize(height_tex, 0));
	float hh = textureLod(height_tex, UV, 0.0).r;
	float hl = textureLod(height_tex, UV - vec2(px.x, 0.0), 0.0).r;
	float hr = textureLod(height_tex, UV + vec2(px.x, 0.0), 0.0).r;
	float hd = textureLod(height_tex, UV - vec2(0.0, px.y), 0.0).r;
	float hu = textureLod(height_tex, UV + vec2(0.0, px.y), 0.0).r;
	vh = hh;
	lp = VERTEX.xz;
	// The surface trembles around a running poker
	float near = 0.0;
	for (int i = 0; i < 4; i++) {
		vec4 s = shiver[i];
		if (s.z > 0.0) {
			float d = distance(VERTEX.xz, s.xy);
			near = max(near, s.z * exp(-d * d / 1.1));
		}
	}
	near_poker = near;
	float tremble = near * 0.016 * sin(TIME * 95.0 + hash(floor(VERTEX.xz * 9.0)) * 6.283);
	VERTEX.y = hh > 0.004 ? hh + tremble * step(0.05, hh) : -0.14;
	NORMAL = normalize(vec3((hl - hr) / (2.0 * cell_m.x), 1.0, (hd - hu) / (2.0 * cell_m.y)));
}

void fragment() {
	if (round_r > 0.0 && length(lp) > round_r) {
		discard;
	}
	// (noise sized in metres: the same grain on any size of slab)
	vec2 nuv = UV * slab_size / vec2(16.0, 12.0);
	float grit = hash(floor(nuv * vec2(1400.0, 1050.0)));
	float blot = hash(floor(nuv * vec2(90.0, 70.0)));
	float depth = smoothstep(0.0, 0.22, vh);
	vec4 st = texture(state_tex, UV);
	float cold = step(0.75, st.g);
	float bleedw = step(0.3, st.g) * (1.0 - cold);
	float vib = st.b;
	float scr = st.a;

	vec3 bleed = vec3(0.27, 0.29, 0.31);
	vec3 wet = vec3(0.43, 0.44, 0.45);
	vec3 crest = vec3(0.56, 0.56, 0.55);
	vec3 c = mix(bleed, wet, depth);
	c = mix(c, crest, smoothstep(0.32, 0.9, vh));
	c *= 0.9 + 0.12 * grit + 0.05 * blot;

	// Raw: stony and matte, with dark air pockets. Compacted: cream comes up.
	float raw = (1.0 - vib) * depth;
	float stones = step(0.7, vnoise(nuv * vec2(520.0, 390.0)));
	c = mix(c, c * 0.72 + vec3(0.05, 0.04, 0.02) * stones, raw * 0.8);
	float pocket = step(0.93, hash(floor(nuv * vec2(700.0, 525.0)))) * raw;
	c = mix(c, vec3(0.2, 0.2, 0.21), pocket * 0.7);
	vec3 cream = vec3(0.74, 0.71, 0.62);
	c = mix(c, cream, vib * depth * 0.6);

	// Air bubbles popping where a poker is working
	float bub = step(0.986, hash(floor(nuv * vec2(620.0, 465.0)) + floor(TIME * 14.0))) * near_poker * (1.0 - vib * 0.85);
	c = mix(c, vec3(0.95, 0.96, 0.98), bub);

	// Going off: lighter and duller as it stiffens
	float going = smoothstep(0.55, 1.0, st.r);
	c = mix(c, vec3(0.6, 0.6, 0.58), going * 0.55);

	// Unscreeded: lumpy. Screeded: flat satin.
	float lump = (vnoise(nuv * vec2(64.0, 48.0)) - 0.5) * (1.0 - scr) * depth * (1.0 - cured);
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(lump * 0.9, 0.0, lump * 0.6, 0.0)).xyz);
	c = mix(c, c * 1.05 + vec3(0.02), scr * depth * 0.6);

	// Honeycomb on thick concrete that went off unvibrated
	float honey = (1.0 - vib) * depth * going * step(0.6, hash(floor(nuv * vec2(620.0, 465.0))));
	vec3 finished = vec3(0.71, 0.71, 0.69) * (0.95 + 0.06 * blot + 0.03 * grit);
	vec3 col = mix(c, finished, cured);
	col = mix(col, vec3(0.3, 0.29, 0.27), honey * 0.6);
	// Over-vibrated: bleed water sitting on top, a bluish wet sheen
	col = mix(col, vec3(0.45, 0.55, 0.66), bleedw * 0.55 * (1.0 - cured * 0.6));
	// Cold joint: a dark seam where fresh met gone-off concrete
	col = mix(col, vec3(0.16, 0.16, 0.18), cold * 0.85);
	// Work overlays: soft pulsing tints over what still needs doing
	float todo_v = (1.0 - smoothstep(0.6, 0.84, vib)) * step(0.1, vh) * (1.0 - step(0.999, st.r)) * poker_view;
	float hurry = smoothstep(0.45, 0.8, st.r);
	vec3 vcol = mix(vec3(0.62, 0.42, 0.98), vec3(1.0, 0.3, 0.45), hurry);
	float vp = (0.38 + 0.14 * sin(TIME * 4.0 + nuv.x * 20.0)) * todo_v;
	col = mix(col, vcol, vp);
	float todo_s = smoothstep(0.5, 0.8, vib) * (1.0 - smoothstep(0.3, 0.7, scr)) * step(0.18, vh) * (1.0 - step(0.999, st.r)) * screed_view;
	float sp = (0.3 + 0.12 * sin(TIME * 4.0 + nuv.y * 20.0)) * todo_s;
	col = mix(col, vec3(0.72, 1.0, 0.86), sp);   // cool green-white: gold is kept for the assist
	float edge = step(0.15, st.g) * (1.0 - step(0.3, st.g)) * (1.0 - cured);
	vec3 ecol = mix(vec3(0.3, 0.95, 0.55), vec3(1.0, 0.72, 0.15), smoothstep(0.3, 0.6, st.r));
	ecol = mix(ecol, vec3(1.0, 0.18, 0.12), smoothstep(0.6, 0.8, st.r));
	float erate = mix(3.0, 12.0, smoothstep(0.5, 0.85, st.r));
	float ep = edge * edge_view * (0.55 + 0.45 * sin(TIME * erate + (nuv.x + nuv.y) * 30.0));
	col = mix(col, ecol, ep * 0.75);
	EMISSION = vcol * vp * 0.35 + vec3(0.72, 1.0, 0.86) * sp * 0.3 + ecol * ep * 0.6;
	ALBEDO = col;
	float rough = mix(0.06, 0.22, depth) + 0.06 * grit + 0.5 * going;
	rough = mix(rough, 0.55, raw * 0.8);
	rough = mix(rough, 0.02, vib * depth * 0.85 * (1.0 - going));
	rough = mix(rough, 0.3, scr * depth * 0.5);
	ROUGHNESS = mix(rough, 0.85, cured);
	SPECULAR = mix(mix(0.5, 1.0, vib * depth), 0.3, cured);
	METALLIC = 0.0;
}
