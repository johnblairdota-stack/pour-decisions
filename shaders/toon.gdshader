// Stylized cel shading: hard light bands from Godot's toon diffuse, plus a soft rim.
shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float rim_amount : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
	RIM = rim_amount;
	RIM_TINT = 0.6;
	EMISSION = emission_color.rgb;
}
