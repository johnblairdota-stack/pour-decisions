// The verb tag behind a world cue's words: a dark pill with the job's dot at
// its left end (Site Kit). Faces the camera and draws on top, like the cue.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, blend_mix, shadows_disabled;

uniform vec4 color : source_color = vec4(0.102, 0.114, 0.141, 0.92);
uniform vec4 dot_color : source_color = vec4(1.0, 0.78, 0.17, 1.0);
uniform vec4 edge : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec2 box = vec2(4.0, 1.0);   // its size in world units (for the rounding)

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 q = (UV - 0.5) * box;
	float r = box.y * 0.5;
	vec2 d = abs(q) - vec2(box.x * 0.5 - r, 0.0);
	float sd = length(max(d, 0.0)) - r;
	float aa = box.y * 0.03;
	float m = smoothstep(aa, -aa, sd);
	vec3 col = color.rgb;
	float a = m * color.a;
	float e = smoothstep(aa, -aa, sd) * smoothstep(-aa * 3.0, -aa * 1.0, sd) * edge.a;
	col = mix(col, edge.rgb, e);
	// The job dot
	vec2 dc = vec2(-box.x * 0.5 + r, 0.0);
	float dm = smoothstep(r * 0.42 + aa, r * 0.42 - aa, length(q - dc));
	col = mix(col, dot_color.rgb, dm * dot_color.a);
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 1.0);
}
