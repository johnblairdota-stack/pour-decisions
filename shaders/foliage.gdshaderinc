// Trees and planting (scripts/flora.gd): the toon look, tinted per tree by the
// multimesh's instance colour, the whole tree leaning in a light breeze.
uniform vec4 albedo : source_color = vec4(1.0);
uniform float sway = 0.0;      // m a point 10 m up moves (grows with height squared)
uniform float flutter = 0.0;   // m of shimmer on strap leaves
uniform float rim_amount : hint_range(0.0, 1.0) = 0.3;
// Within these distances of the camera a tree dithers away, so an orbiting
// camera that ends up in a crown still sees the site
uniform float fade_near = 10.0;
uniform float fade_far = 30.0;
// The crown's depth (flora.gd): darker deep inside and low in the crown,
// brighter at the tips and the top, as light really falls into a tree.
// crown_top 0 leaves it off.
uniform float crown_top = 0.0;   // m, the model's top at scale 1
uniform float crown_r = 1.0;     // m, the crown's half-width at scale 1
varying float crown_k;

void vertex() {
	crown_k = 1.0;
	if (crown_top > 0.0) {
		float up = smoothstep(0.3, 1.0, VERTEX.y / crown_top);
		float outw = smoothstep(0.15, 1.0, length(VERTEX.xz) / crown_r);
		crown_k = mix(0.7, 1.08, up * 0.55 + outw * 0.45);
	}
	vec3 o = MODEL_MATRIX[3].xyz;
	float ph = o.x * 0.11 + o.z * 0.07;
	float h = max(VERTEX.y, 0.0) * 0.1;
	float s = (sin(TIME * 0.9 + ph) * 0.7 + sin(TIME * 2.1 + ph * 1.9) * 0.3) * sway * h * h;
	VERTEX.x += s;
	VERTEX.z += s * 0.6;
	if (flutter > 0.0) {
		VERTEX.y += sin(TIME * 4.0 + dot(VERTEX, vec3(3.1, 2.3, 1.7)) + ph) * flutter * h;
	}
}

void fragment() {
	float d = length(VERTEX);
	if (d < fade_far) {
		float a = smoothstep(fade_near, fade_far, d);
		float ign = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
		if (ign > a) {
			discard;
		}
	}
	ALBEDO = albedo.rgb * COLOR.rgb * crown_k;
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
	lk_rim = rim_amount;
	LOOK_END
}
