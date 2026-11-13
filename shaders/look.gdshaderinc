// The game's look (scripts/look.gd): how every toon-lit thing takes the light.
// Included by toon, toon_cut, ground, foliage and the rest in place of
// Godot's own diffuse_toon, so a Look can swap the shading for the whole
// world by setting a few shader globals: no new materials, no extra passes.
//
// Each shader that includes this sets `lk_rim` in fragment() (its rim
// strength; 0 for none), as it used to set RIM.
//
//   look_shade  0 Site Toon: Godot's own toon (a soft band set by roughness)
//               1 smooth: wrapped Lambert, soft like clay or paint
//               2 banded: hard cel bands (look_bands of them) with crisp edges
//   look_wrap   how far light wraps round the dark side (smooth and banded)
//   look_bands  bands for banded shading (1 = lit/shadow two-tone)
//   look_edge   softness of a band's edge
//   look_tint   rgb: the colour the sun's dark side and shadows lean to,
//               a: how much (cool blue shadows, warm bounce, ...)
//   look_rim    the rim light, times each shader's own
//   look_spec   the shine, times the usual
//   look_clouds how dark the cloud shadows drifting over the site get (0 none)
//   look_wind   the cloud shadows' drift, m/s (x, z)
//   look_base   how much the bottom half-metre of walls, posts and wheels
//               darkens where they meet the ground or the deck
//   look_deck   the deck's top (m), the second "ground" things stand on
//
// Each shader also ends its fragment() with LOOK_END, which sets lk_w (the
// world position) and darkens the base of things.

global uniform float look_shade;
global uniform float look_wrap;
global uniform float look_bands;
global uniform float look_edge;
global uniform vec4 look_tint;
global uniform float look_rim;
global uniform float look_spec;
global uniform float look_clouds;
global uniform vec2 look_wind;
global uniform float look_base;
global uniform float look_deck;

varying float lk_rim;
varying vec3 lk_w;

#define LOOK_END lk_w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz; ALBEDO *= look_base_k(lk_w, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);

float lk_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float lk_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(lk_hash(i), lk_hash(i + vec2(1.0, 0.0)), f.x),
		mix(lk_hash(i + vec2(0.0, 1.0)), lk_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// 1 in sun, down to 1 - look_clouds under a cloud's shadow
float look_cloud(vec3 w) {
	if (look_clouds <= 0.0) {
		return 1.0;
	}
	vec2 p = (w.xz - look_wind * TIME) / 70.0;
	float n = lk_noise(p) * 0.65 + lk_noise(p * 2.3 + 17.0) * 0.35;
	return 1.0 - look_clouds * smoothstep(0.5, 0.68, n);
}

// The bottom half-metre of anything standing (not the ground itself) a
// touch darker, where it meets the ground (y 0) or the deck
float look_base_k(vec3 w, vec3 n) {
	if (look_base <= 0.0) {
		return 1.0;
	}
	float side = 1.0 - abs(normalize(n).y);
	float lev = w.y >= look_deck - 0.05 ? look_deck : 0.0;
	float h = w.y - lev;
	if (h < 0.0) {
		return 1.0;
	}
	return 1.0 - look_base * side * (1.0 - smoothstep(0.0, 0.6, h));
}

void light() {
	float r = ROUGHNESS;
	float ndl = dot(NORMAL, LIGHT);
	float lit;
	if (look_shade < 0.5) {
		// Godot's diffuse_toon, as it was
		lit = smoothstep(-r, max(r, 0.01), ndl) * ATTENUATION;
	} else {
		float w = clamp((ndl + look_wrap) / (1.0 + look_wrap), 0.0, 1.0) * ATTENUATION;
		if (look_shade > 1.5) {
			float b = max(look_bands, 1.0);
			float q = w * b;
			w = (floor(q) + smoothstep(0.5 - look_edge, 0.5 + look_edge, fract(q))) / b;
		}
		lit = w;
	}
	// (cloud shadows drift over the site in the sun)
	float sky = LIGHT_IS_DIRECTIONAL ? look_cloud(lk_w) : 1.0;
	lit *= sky;
	DIFFUSE_LIGHT += LIGHT_COLOR * lit / PI;
	// The sun's dark side and its shadows lean to the look's tint
	if (LIGHT_IS_DIRECTIONAL && look_tint.a > 0.0) {
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * (1.0 - lit) * look_tint.rgb * look_tint.a;
	}
	// Rim (as Godot's: not shadowed)
	if (lk_rim > 0.0 && look_rim > 0.0) {
		float nv = max(dot(NORMAL, VIEW), 1e-4);
		float rim = pow(max(1e-4, 1.0 - nv), max(0.0, (1.0 - r) * 16.0));
		DIFFUSE_LIGHT += rim * lk_rim * look_rim * mix(vec3(1.0), ALBEDO, 0.6) * LIGHT_COLOR;
	}
	// Shine
	if (look_spec > 0.0) {
		if (look_shade < 0.5 || look_shade > 1.5) {
			// Godot's specular_toon: a hard-edged highlight, in the diffuse
			vec3 rr = normalize(-reflect(LIGHT, NORMAL));
			float mid = (1.0 - r) * (1.0 - r);
			float k = smoothstep(mid - r * 0.5, mid + r * 0.5, dot(rr, VIEW)) * mid;
			DIFFUSE_LIGHT += LIGHT_COLOR * k * ATTENUATION * sky * SPECULAR_AMOUNT * look_spec;
		} else {
			// soft Blinn-Phong
			vec3 h = normalize(VIEW + LIGHT);
			float p = exp2(10.0 * (1.0 - r) + 1.0);
			float k = pow(max(dot(NORMAL, h), 0.0), p) * (p + 8.0) / (8.0 * PI) * 0.04;
			SPECULAR_LIGHT += LIGHT_COLOR * k * max(ndl, 0.0) * ATTENUATION * sky * SPECULAR_AMOUNT * look_spec;
		}
	}
}
