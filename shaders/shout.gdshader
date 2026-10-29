// A shout balloon: the leading hand's spray. A spiky burst round the text
// instead of the speech balloon's rounded box, hot yellow with a red edge,
// and it shivers. Faces the camera and draws on top, like a speech balloon.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, blend_mix, shadows_disabled;

uniform vec2 size = vec2(2.0, 0.6);   // the text box, m (the quad is bigger, for the spikes)
uniform float spikes = 14.0;          // points round the burst
uniform float spike_h = 0.22;         // m each point sticks out
uniform vec4 fill : source_color = vec4(1.0, 0.93, 0.35, 0.97);
uniform vec4 edge : source_color = vec4(0.78, 0.09, 0.07, 1.0);
uniform float edge_w = 0.05;
uniform float alpha = 1.0;
uniform float seed = 0.0;             // each balloon's points sit a little differently

varying vec2 lp;

void vertex() {
	lp = VERTEX.xy;
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sc.x, INV_VIEW_MATRIX[1] * sc.y, INV_VIEW_MATRIX[2] * sc.z, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	// An ellipse round the text, pushed out into points
	vec2 half_size = size * 0.72 + vec2(0.12);
	vec2 q = lp / half_size;
	float ang = atan(q.y, q.x);
	float r = length(q);
	// (jagged, not even: every other point a bit longer, and they wobble)
	float wave = abs(fract(ang / 6.2831853 * spikes + seed) - 0.5) * 2.0;
	float uneven = 0.75 + 0.25 * sin(ang * 3.0 + seed * 6.0 + TIME * 9.0);
	float reach = 1.0 + (spike_h / min(half_size.x, half_size.y)) * (1.0 - wave) * uneven;
	float d = (r - reach) * min(half_size.x, half_size.y);
	float aa = fwidth(d) * 1.2;
	float a = 1.0 - smoothstep(-aa, aa, d);
	float e = smoothstep(-edge_w - aa, -edge_w + aa, d);
	vec4 col = mix(fill, edge, e);
	ALBEDO = col.rgb;
	ALPHA = a * col.a * alpha;
}
