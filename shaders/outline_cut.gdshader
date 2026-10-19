// outline.gdshader with the see-through circle round the work cut out of it.
shader_type spatial;
render_mode unshaded, cull_front;

#include "res://shaders/cutaway.gdshaderinc"

uniform vec4 color : source_color = vec4(0.06, 0.08, 0.14, 1.0);
uniform float thickness = 0.035;

void vertex() {
	VERTEX += NORMAL * thickness;
}

void fragment() {
	if (cut_hidden(VERTEX, VIEW_MATRIX, FRAGCOORD.xy)) {
		discard;
	}
	ALBEDO = color.rgb;
}
