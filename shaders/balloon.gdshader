// A speech balloon behind a spoken line: a rounded box sized to the text,
// with a dark edge and a little tail pointing down at whoever said it.
// Always faces the camera and draws on top, like the text in it.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, blend_mix, shadows_disabled;

uniform vec2 size = vec2(2.0, 0.5);   // the box, m (the quad is this plus the tail)
uniform float tail = 0.22;            // m the tail hangs below the box
uniform float radius = 0.16;
uniform vec4 fill : source_color = vec4(1.0, 1.0, 1.0, 0.96);
uniform vec4 edge : source_color = vec4(0.06, 0.11, 0.18, 1.0);
uniform float edge_w = 0.035;
uniform float alpha = 1.0;

varying vec2 lp;

void vertex() {
	lp = VERTEX.xy;
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sc.x, INV_VIEW_MATRIX[1] * sc.y, INV_VIEW_MATRIX[2] * sc.z, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

float box_d(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - (half_size - vec2(r));
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	// The quad's centre is the middle of box + tail: the box sits on top
	vec2 p = lp - vec2(0.0, tail * 0.5);
	float d = box_d(p, size * 0.5, min(radius, min(size.x, size.y) * 0.5));
	// The tail: a triangle from the box's bottom edge down to a point
	float bottom = -size.y * 0.5;
	float ty = (bottom - p.y) / max(tail, 0.001);          // 0 at the box, 1 at the tip
	float tx = abs(p.x);
	float half_w = 0.16 * (1.0 - ty);
	float dt = max(tx - half_w, max(-ty * tail, (ty - 1.0) * tail));
	d = min(d, dt);
	float aa = fwidth(d) * 1.2;
	float a = 1.0 - smoothstep(-aa, aa, d);
	float e = smoothstep(-edge_w - aa, -edge_w + aa, d);
	vec4 col = mix(fill, edge, e);
	ALBEDO = col.rgb;
	ALPHA = a * col.a * alpha;
}
