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
// She's right: which strips (strip_cols columns of the grid_nx-wide state
// grid each) the poker has called for the screeder
uniform float strip_rel[32];
// The finish: r shiny bleed water after the screed, g floated, b matt and
// waiting for the bull float (glints gold for a new screeder: float_view)
uniform sampler2D fin_tex : filter_nearest, repeat_disable;
uniform float float_view : hint_range(0.0, 1.0) = 0.0;
uniform float strip_cols = 6.0;
uniform float grid_nx = 48.0;
// The wet edge glows: green while it's fresh, amber as it ages, red and
// pulsing fast when it's about to go off. Brighter for whoever's on the boom.
uniform float edge_view : hint_range(0.0, 1.0) = 0.4;
// 0 in full daylight, 1 in the dark before sunrise (a dawn pour): the work
// overlays lean on their own glow instead of the light, so a warm low sun or
// the floodlights don't wash the still-to-vibrate tint into the concrete
uniform float low_light : hint_range(0.0, 1.0) = 0.0;
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

	// After the screed: wet and shiny with bleed water, going matt; floated
	// it closes up smooth and a touch lighter
	vec4 fn = texture(fin_tex, UV);
	float shine = fn.r * (1.0 - cured);
	float floated = fn.g * (1.0 - cured);
	c = mix(c, c * 0.86 + vec3(0.0, 0.01, 0.03), shine * 0.55);
	c = mix(c, c * 1.07 + vec3(0.03), floated * 0.5);

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
	// (and the vibrated concrete beside it goes a touch darker,
	// so the edge between done and not done reads in any light)
	col = mix(col, col * 0.84, (1.0 - todo_v) * step(0.1, vh) * poker_view * (1.0 - cured) * 0.6);
	col = mix(col, vcol, vp);
	int strip_i = clamp(int(floor(UV.x * grid_nx / strip_cols)), 0, 31);
	float todo_s = smoothstep(0.5, 0.8, vib) * (1.0 - smoothstep(0.3, 0.7, scr)) * step(0.18, vh) * (1.0 - step(0.999, st.r)) * screed_view * strip_rel[strip_i];
	float sp = (0.3 + 0.12 * sin(TIME * 4.0 + nuv.y * 20.0)) * todo_s;
	col = mix(col, vec3(0.72, 1.0, 0.86), sp);   // cool green-white: gold is kept for the assist
	// The wet edge reads on the concrete itself: glossy while it's fresh,
	// dull and crazed as it ages toward going off. New to the boom, a thin
	// gold line still marks it (edge_view fades with the gold assist).
	float edge = step(0.15, st.g) * (1.0 - step(0.3, st.g)) * (1.0 - cured);
	float ageing = smoothstep(0.3, 0.85, st.r);
	float craze = 1.0 - smoothstep(0.0, 0.05, abs(vnoise(nuv * vec2(150.0, 112.0)) - 0.5));
	col = mix(col, col * 0.8 + vec3(0.06), edge * ageing * 0.6);
	col = mix(col, vec3(0.28, 0.28, 0.29), edge * ageing * craze * 0.7);
	vec3 ecol = vec3(1.0, 0.82, 0.25);
	float ep = edge * edge_view * (1.0 - ageing * 0.4) * (0.6 + 0.4 * sin(TIME * 4.0 + (nuv.x + nuv.y) * 30.0));
	col = mix(col, ecol, ep * 0.7);
	float glint = fn.b * float_view * step(0.93, hash(floor(nuv * vec2(260.0, 195.0)) + floor(TIME * 6.0))) * (1.0 - cured);
	col = mix(col, vec3(1.0, 0.82, 0.25), glint * 0.8);
	EMISSION = vcol * vp * mix(0.6, 1.4, low_light) + vec3(0.72, 1.0, 0.86) * sp * mix(0.3, 0.9, low_light) + ecol * ep * 0.6 + vec3(1.0, 0.82, 0.25) * glint * 0.8;
	ALBEDO = col;
	float rough = mix(0.06, 0.22, depth) + 0.06 * grit + 0.5 * going;
	rough = mix(rough, 0.55, raw * 0.8);
	rough = mix(rough, 0.02, vib * depth * 0.85 * (1.0 - going));
	rough = mix(rough, 0.3, scr * depth * 0.5);
	rough = mix(rough, 0.5, step(0.9, scr) * (1.0 - fn.r) * (1.0 - fn.g) * depth * 0.6);
	rough = mix(rough, 0.01, shine * 0.9);
	rough = mix(rough, 0.26, floated * 0.8);
	rough = mix(rough, 0.01, edge * (1.0 - ageing) * 0.7);
	rough = mix(rough, 0.65, edge * ageing);
	ROUGHNESS = mix(rough, 0.85, cured);
	SPECULAR = mix(mix(0.5, 1.0, vib * depth), 0.3, cured);
	METALLIC = 0.0;
}
