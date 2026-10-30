// What's left when a bubble pops: a thin bright ring that spreads out over
// the slurry and fades, and the spatter flung up (drawn as little flat dots
// that face the camera). INSTANCE_CUSTOM.r = 0..1 through its life.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.95, 0.94, 0.9, 1.0);
uniform bool spatter = false;   // a spatter drop instead of a ring

varying vec4 cd;
varying vec2 lp;

void vertex() {
	cd = INSTANCE_CUSTOM;
	lp = VERTEX.xz;
	if (spatter) {
		lp = VERTEX.xy;
		vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
		mat4 world = MODEL_MATRIX;
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sc.x, INV_VIEW_MATRIX[1] * sc.y, INV_VIEW_MATRIX[2] * sc.z, world[3]);
	}
}

void fragment() {
	float r = length(lp) * 2.0;
	float aa = fwidth(r) * 1.5;
	if (spatter) {
		float a = 1.0 - smoothstep(1.0 - aa, 1.0, r);
		ALBEDO = mix(vec3(0.5, 0.49, 0.46), tint.rgb, 1.0 - r * 0.6);
		ALPHA = a * (1.0 - cd.r * cd.r);
	} else {
		// a ring that thins as it grows
		float w = mix(0.22, 0.06, cd.r);
		float d = abs(r - 0.85);
		float a = 1.0 - smoothstep(w - aa, w + aa, d);
		ALBEDO = tint.rgb;
		ALPHA = a * (1.0 - cd.r) * 0.9;
	}
}
