// A controller button glyph floating in the world: a coloured disc with a
// white rim, an optional progress ring for "hold" actions, and a soft pulse
// halo. Always faces the camera and draws on top.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, blend_mix, shadows_disabled;

uniform vec4 color : source_color = vec4(0.31, 0.88, 0.78, 1.0);
uniform float progress = -1.0;   // < 0: no ring; 0..1: hold progress
uniform float pulse = 0.0;       // 0..1 halo strength
uniform float scale_mul = 1.0;
uniform float dim = 0.0;         // greyed out (not available yet)
uniform vec2 zone = vec2(-1.0, -1.0);  // a gold band on the ring: "let go in here"
uniform float assist = 0.0;      // the gold assist: a double ring with dashes running round it

void vertex() {
	VERTEX *= scale_mul;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	vec3 base = mix(color.rgb, vec3(0.45), dim);
	bool in_zone = zone.x >= 0.0 && progress >= zone.x && progress <= zone.y;
	bool past_zone = zone.x >= 0.0 && progress > zone.y;
	vec3 gold = vec3(1.0, 0.82, 0.22);
	// In the sweet zone the whole button lights up gold
	if (in_zone) { base = mix(base, gold, 0.65); }
	// Disc with a little top-lit shading so it reads as a button
	float disc = smoothstep(0.6, 0.57, r);
	vec3 col = base * (0.82 + 0.3 * (0.5 - 0.5 * p.y)) ;
	float rim = smoothstep(0.66, 0.63, r) * (1.0 - disc);
	float alpha = disc + rim;
	col = mix(col, vec3(1.0), rim);
	// Hold progress ring
	if (progress >= 0.0) {
		float ring = smoothstep(0.72, 0.75, r) * smoothstep(0.95, 0.92, r);
		float ang = atan(p.x, -p.y) / 6.28318 + 0.5;
		vec3 fill = in_zone ? gold : (past_zone ? vec3(1.0, 0.33, 0.3) : vec3(1.0));
		vec3 rc = ang <= progress ? fill : vec3(0.08, 0.1, 0.14);
		float ra = ang <= progress ? 1.0 : 0.55;
		col = mix(col, rc, ring);
		alpha = max(alpha, ring * ra);
	}
	// The sweet zone, drawn round the outside of the ring
	if (zone.x >= 0.0) {
		float band = smoothstep(0.86, 0.9, r) * smoothstep(1.0, 0.96, r);
		float ang2 = atan(p.x, -p.y) / 6.28318 + 0.5;
		float inz = step(zone.x, ang2) * step(ang2, zone.y);
		vec3 zc = in_zone ? vec3(1.0, 0.97, 0.55) : vec3(1.0, 0.72, 0.1);
		col = mix(col, zc, band * inz);
		alpha = max(alpha, band * inz);
	}
	// The gold assist: its own shape and motion, so it reads even next to a
	// yellow hard hat or the yellow Y button: a white ring, a gold ring, and
	// gold dashes chasing round between them
	if (assist > 0.0) {
		float ang3 = atan(p.x, -p.y) / 6.28318 + 0.5;
		float r1 = smoothstep(0.76, 0.78, r) * smoothstep(0.82, 0.8, r);
		float r2 = smoothstep(0.92, 0.94, r) * smoothstep(0.99, 0.97, r);
		float dash = step(0.5, fract(ang3 * 10.0 - TIME * 1.2)) * smoothstep(0.83, 0.85, r) * smoothstep(0.91, 0.89, r);
		col = mix(col, vec3(1.0), r1 * assist);
		col = mix(col, vec3(1.0, 0.82, 0.22), max(r2, dash) * assist);
		alpha = max(alpha, max(r1, max(r2, dash)) * assist);
	}
	// Pulse halo
	float halo = smoothstep(1.0, 0.62, r) * (1.0 - disc - rim) * pulse * (in_zone ? 1.0 : 0.55);
	col = mix(col, base * 1.4, halo / max(alpha + halo, 0.001));
	alpha = max(alpha, halo);
	ALBEDO = col;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
