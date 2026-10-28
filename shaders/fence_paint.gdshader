// Fence paint (scripts/fences.gd): each run its own colour, from the
// multimesh instance colour; both faces drawn (Colorbond is one sheet).
shader_type spatial;
render_mode diffuse_toon, specular_toon, cull_disabled;

void fragment() {
	ALBEDO = pow(COLOR.rgb, vec3(2.2));
	ROUGHNESS = 0.55;
	SPECULAR = 0.4;
}
