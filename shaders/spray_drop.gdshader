// Wash-down water: each drop a soft streak stretched along its flight (the
// script lines the quad up with its velocity), white in the middle and blue
// at the edge, with a glint. INSTANCE_CUSTOM.r = 0..1 through its life,
// g = 1 for a splash ring on the ground instead of a drop.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 water : source_color = vec4(0.62, 0.8, 0.95, 1.0);

varying vec4 cd;
varying vec2 lp;

void vertex() {
	cd = INSTANCE_CUSTOM;
	lp = VERTEX.xy;
}

void fragment() {
	if (cd.g > 0.5) {
		// a splash ring
		float r = length(lp) * 2.0;
		float w = mix(0.25, 0.08, cd.r);
		float a = 1.0 - smoothstep(w * 0.6, w, abs(r - 0.8));
		ALBEDO = vec3(0.92, 0.96, 1.0);
		ALPHA = a * (1.0 - cd.r) * 0.85;
	} else {
		// a capsule
		vec2 q = vec2(lp.x * 2.0, max(abs(lp.y * 2.0) - 0.5, 0.0) * 2.0);
		float r = length(q);
		float a = 1.0 - smoothstep(0.6, 1.0, r);
		ALBEDO = mix(vec3(1.0), water.rgb, smoothstep(0.0, 0.9, r));
		ALPHA = a * 0.85 * (1.0 - cd.r * cd.r);
	}
}
