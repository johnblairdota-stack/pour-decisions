// toon.gdshader with the see-through circle round the work cut out of it.
shader_type spatial;
render_mode diffuse_toon, specular_toon;
#include "res://shaders/look.gdshaderinc"

#include "res://shaders/cutaway.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float rim_amount : hint_range(0.0, 1.0) = 0.35;
// The modelled assets' baked ambient occlusion (vertex colour), how much of
// it shows: 0 for everything built in code (factory.gd sets it for models).
uniform float vc_ao = 0.0;

void fragment() {
	if (cut_hidden(VERTEX, VIEW_MATRIX, FRAGCOORD.xy)) {
		discard;
	}
	ALBEDO = albedo.rgb;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
	lk_rim = rim_amount;
	if (vc_ao > 0.0) {
		ALBEDO *= mix(vec3(1.0), sqrt(COLOR.rgb), vc_ao);
	}
	EMISSION = emission_color.rgb;
	LOOK_END
}
