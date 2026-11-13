// The map's ground (scripts/surrounds.gd, the revetment in scripts/water.gd):
// vertex coloured and toon lit like the rest of the world, with each
// surface's own texture on top (shaders/ground_detail.gdshaderinc). Which
// surface a triangle is comes in UV.x.
shader_type spatial;
render_mode diffuse_toon, specular_toon, cull_disabled;
#include "res://shaders/look.gdshaderinc"

#include "res://shaders/ground_detail.gdshaderinc"

varying vec2 wp;
varying flat int code;
global uniform float wetness;   // after rain (as toon.gdshader)

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	code = int(UV.x + 0.5);
	// (the colours are sRGB, as StandardMaterial3D's vertex_color_is_srgb)
	if (!OUTPUT_IS_SRGB) {
		COLOR.rgb = mix(pow((COLOR.rgb + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), COLOR.rgb * (1.0 / 12.92),
			lessThan(COLOR.rgb, vec3(0.04045)));
	}
}

void fragment() {
	lk_rim = 0.0;
	float px = max(length(dFdx(wp)), length(dFdy(wp)));
	float wet = wetness * smoothstep(0.55, 0.85, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y);
	ALBEDO = ground_detail(COLOR.rgb, code, wp, px) * (1.0 - 0.3 * wet);
	ROUGHNESS = mix(0.9, 0.3, wet);
	SPECULAR = mix(0.25, 0.55, wet);
	LOOK_END
}
