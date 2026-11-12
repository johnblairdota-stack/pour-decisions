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

global uniform float look_shade;
global uniform float look_wrap;
global uniform float look_bands;
global uniform float look_edge;
global uniform vec4 look_tint;
global uniform float look_rim;
global uniform float look_spec;

varying float lk_rim;

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
			DIFFUSE_LIGHT += LIGHT_COLOR * k * ATTENUATION * SPECULAR_AMOUNT * look_spec;
		} else {
			// soft Blinn-Phong
			vec3 h = normalize(VIEW + LIGHT);
			float p = exp2(10.0 * (1.0 - r) + 1.0);
			float k = pow(max(dot(NORMAL, h), 0.0), p) * (p + 8.0) / (8.0 * PI) * 0.04;
			SPECULAR_LIGHT += LIGHT_COLOR * k * max(ndl, 0.0) * ATTENUATION * SPECULAR_AMOUNT * look_spec;
		}
	}
}
