// Spire's ground: paving grey in the city blocks, lawn inside the river's bend at Kangaroo Point.
shader_type spatial;

uniform vec4 paving : source_color = vec4(0.61, 0.60, 0.58, 1.0);
uniform vec4 lawn : source_color = vec4(0.37, 0.5, 0.27, 1.0);
uniform vec2 ring[8];

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	bool inside = false;
	for (int i = 0; i < 8; i++) {
		vec2 a = ring[i];
		vec2 b = ring[(i + 1) % 8];
		if ((a.y > p.y) != (b.y > p.y) && p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) {
			inside = !inside;
		}
	}
	// (a little mottling so the lawn isn't one flat tone)
	float m = sin(p.x * 0.11) * sin(p.y * 0.13 + 1.3) * 0.06;
	ALBEDO = inside ? lawn.rgb * (1.0 + m) : paving.rgb;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}
