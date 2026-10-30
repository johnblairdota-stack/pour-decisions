// Three-strand rope: the strands twist round it, each with a dark groove
// between, and a few fuzzy fibres. UV.x runs along the rope (m), UV.y round it.
shader_type spatial;
render_mode cull_back, diffuse_toon, specular_disabled;

uniform vec4 color : source_color = vec4(0.85, 0.76, 0.48, 1.0);
uniform float lay = 9.0;      // strand turns per metre
uniform vec4 tracer : source_color = vec4(0.2, 0.42, 0.85, 1.0);  // a coloured strand marker

void fragment() {
	float u = UV.y * 3.0 + UV.x * lay;
	float f = fract(u);
	float groove = smoothstep(0.0, 0.18, f) * smoothstep(1.0, 0.82, f);
	vec3 c = color.rgb * mix(0.55, 1.05, groove);
	// one strand carries a coloured tracer yarn
	float which = mod(floor(u), 3.0);
	float yarn = step(which, 0.5) * step(0.42, f) * step(f, 0.58);
	c = mix(c, tracer.rgb, yarn * 0.8);
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
