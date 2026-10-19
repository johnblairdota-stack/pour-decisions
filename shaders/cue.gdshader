// A controller button glyph floating in the world, in the Site Kit look the
// phone uses too: a coloured disc on a darker lip, a white rim, a hold ring
// outside it (dark track, white fill, gold in the sweet spot), and concrete
// filling the disc from the bottom while it's held. Always faces the camera
// and draws on top.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, blend_mix, shadows_disabled;

uniform vec4 color : source_color = vec4(0.247, 0.878, 0.773, 1.0);
uniform vec4 lip : source_color = vec4(0.106, 0.541, 0.431, 1.0);
uniform float progress = -1.0;   // < 0: no ring; 0..1: hold progress
uniform float pulse = 0.0;       // 0..1 halo strength
uniform float scale_mul = 1.0;
uniform float dim = 0.0;         // greyed out (not available yet)
uniform vec2 zone = vec2(-1.0, -1.0);  // a gold band on the ring: "let go in here"
uniform float assist = 0.0;      // the gold assist: a double ring with dashes running round it
uniform float gold_on = 0.0;     // 0..1: the gold moment (the face goes gold)
uniform float squash = 0.0;      // 0..1: just pressed (the disc sinks onto its lip)

const vec3 GOLD = vec3(1.0, 0.824, 0.247);
const vec3 TRACK = vec3(0.102, 0.114, 0.141);
const vec3 ALARM = vec3(1.0, 0.231, 0.184);
const vec3 CONCRETE = vec3(0.62, 0.61, 0.58);

void vertex() {
	VERTEX *= scale_mul;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

float ring_at(float r, float a, float b) {
	return smoothstep(a - 0.015, a + 0.015, r) * smoothstep(b + 0.015, b - 0.015, r);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float ang = atan(p.x, -p.y) / 6.28318 + 0.5;
	// The face sits up off its lip; a press sinks it most of the way down
	float lift = 0.07 * (1.0 - 0.7 * squash);
	vec2 pf = p + vec2(0.0, lift);
	float rf = length(pf);
	float rl = length(p - vec2(0.0, 0.07 - lift));
	bool in_zone = zone.x >= 0.0 && progress >= zone.x && progress <= zone.y;
	bool past_zone = zone.x >= 0.0 && progress > zone.y;
	vec3 face = mix(color.rgb, vec3(0.45), dim);
	vec3 lipc = mix(lip.rgb, vec3(0.3), dim);
	face = mix(face, GOLD, max(gold_on, in_zone ? 1.0 : 0.0) * 0.85);
	lipc = mix(lipc, vec3(0.69, 0.48, 0.0), max(gold_on, in_zone ? 1.0 : 0.0) * 0.85);
	float R = 0.52;
	float disc = smoothstep(R + 0.012, R - 0.012, rf);
	float lipm = smoothstep(R + 0.012, R - 0.012, rl) * (1.0 - disc);
	float rim = smoothstep(R + 0.07, R + 0.05, min(rf, rl)) * (1.0 - disc - lipm);
	// A little top light on the face
	vec3 col = face * (0.92 + 0.16 * (0.5 - 0.5 * pf.y / R));
	// Concrete fills the disc from the bottom while it's held
	if (progress >= 0.0) {
		float level = R - 2.0 * R * clamp(progress, 0.0, 1.0);
		float wave = 0.025 * sin(pf.x * 14.0 + TIME * 6.0);
		float fillm = smoothstep(level - 0.01, level + 0.01, pf.y + wave);
		col = mix(col, mix(CONCRETE, col, 0.35), fillm * 0.75 * disc);
	}
	col = col * disc + lipc * lipm + vec3(1.0) * rim;
	float alpha = disc + lipm + rim;
	// Hold ring, outside the rim
	if (progress >= 0.0) {
		float ring = ring_at(length(p), 0.7, 0.8);
		vec3 fill = in_zone ? GOLD : (past_zone ? ALARM : vec3(1.0));
		bool done = ang <= progress;
		col = mix(col, done ? fill : TRACK, ring);
		alpha = max(alpha, ring * (done ? 1.0 : 0.8));
	}
	// The sweet spot: a gold arc on the outside of the ring
	if (zone.x >= 0.0) {
		float band = ring_at(length(p), 0.84, 0.94);
		float inz = step(zone.x, ang) * step(ang, zone.y);
		vec3 zc = in_zone ? vec3(1.0, 0.97, 0.6) : GOLD;
		col = mix(col, zc, band * inz);
		alpha = max(alpha, band * inz);
	}
	// The gold assist: a white ring, a gold ring, and gold dashes chasing
	// round between them, so it reads next to a yellow hat or the Y button
	if (assist > 0.0) {
		float r = length(p);
		float r1 = ring_at(r, 0.72, 0.75);
		float r2 = ring_at(r, 0.92, 0.96);
		float dash = step(0.5, fract(ang * 10.0 - TIME * 1.2)) * ring_at(r, 0.8, 0.88);
		col = mix(col, vec3(1.0), r1 * assist);
		col = mix(col, GOLD, max(r2, dash) * assist);
		alpha = max(alpha, max(r1, max(r2, dash)) * assist);
	}
	// Soft halo
	float hr = length(p);
	float halo = smoothstep(1.0, 0.55, hr) * (1.0 - clamp(alpha, 0.0, 1.0)) * pulse * 0.6;
	vec3 hc = (in_zone || gold_on > 0.5) ? GOLD : face;
	col = mix(col, hc, halo / max(alpha + halo, 0.001));
	alpha = max(alpha, halo);
	ALBEDO = col;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
