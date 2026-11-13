// Stylized cel shading: hard light bands from Godot's toon diffuse, plus a soft rim.
shader_type spatial;
render_mode diffuse_toon, specular_toon;
#include "res://shaders/look.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float rim_amount : hint_range(0.0, 1.0) = 0.35;
// The modelled assets' baked ambient occlusion (vertex colour), how much of
// it shows: 0 for everything built in code (factory.gd sets it for models).
uniform float vc_ao = 0.0;
// After rain (main.gd _update_weather_fx): what faces the sky goes darker
// and glossy, and dries off again.
global uniform float wetness;

void fragment() {
	float wet = wetness * smoothstep(0.55, 0.85, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y);
	ALBEDO = albedo.rgb * (1.0 - 0.3 * wet);
	ROUGHNESS = mix(0.85, 0.3, wet);
	SPECULAR = mix(0.2, 0.55, wet);
	lk_rim = rim_amount;
	if (vc_ao > 0.0) {
		ALBEDO *= mix(vec3(1.0), sqrt(COLOR.rgb), vc_ao);
	}
	EMISSION = emission_color.rgb;
	LOOK_END
}
