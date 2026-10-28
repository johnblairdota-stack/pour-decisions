// Car paint (scripts/cars.gd): toon shaded, each car its own colour, from the
// multimesh instance colour (parked cars) or the `tint` instance uniform (cars
// driving about).
shader_type spatial;
render_mode diffuse_toon, specular_toon;

instance uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	ALBEDO = tint.rgb * pow(COLOR.rgb, vec3(2.2));
	ROUGHNESS = 0.35;
	SPECULAR = 0.6;
}
