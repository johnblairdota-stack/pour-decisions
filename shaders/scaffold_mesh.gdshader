// The containment mesh on the perimeter scaffold (scripts/spire_scaffold.gd): shade cloth you can
// half see through, with a solid hem every lift, and the same see-through circle round the work
// as everything else between the camera and the crew (cutaway.gdshaderinc).
shader_type spatial;
render_mode diffuse_toon, specular_toon, cull_disabled;
#include "res://shaders/look.gdshaderinc"

#include "res://shaders/cutaway.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.16, 0.38, 0.66, 1.0);
uniform float cover = 0.5;       // how much of the sheet is cloth (the rest is seen through)
uniform float hem = 1.0;         // m between the solid hems
uniform float hem_w = 0.05;      // m, the hem's width

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (cut_hidden(VERTEX, VIEW_MATRIX, INV_VIEW_MATRIX, FRAGCOORD.xy)) {
		discard;
	}
	lk_rim = 0.0;
	float h = abs(fract(wpos.y / hem) - 0.5) * hem;
	if (h > hem_w * 0.5 && cut_bayer(FRAGCOORD.xy + vec2(2.0, 1.0)) > cover) {
		discard;
	}
	ALBEDO = albedo.rgb;
	ROUGHNESS = 0.8;
	LOOK_END
}
