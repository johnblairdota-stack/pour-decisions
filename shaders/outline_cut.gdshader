// outline.gdshader with the see-through circle round the work cut out of it.
shader_type spatial;
render_mode unshaded, cull_front;

#include "res://shaders/cutaway.gdshaderinc"

uniform vec4 color : source_color = vec4(0.06, 0.08, 0.14, 1.0);
uniform float thickness = 0.035;
// The look's ink (scripts/look.gd): the line's weight, times this, and its
// colour, mixed toward look_ink.rgb by look_ink.a. Weight 0: no line.
global uniform float look_ink_w;
global uniform vec4 look_ink;

void vertex() {
	VERTEX += NORMAL * thickness * look_ink_w;
}

void fragment() {
	if (look_ink_w <= 0.0) {
		discard;
	}
	if (cut_hidden(VERTEX, VIEW_MATRIX, FRAGCOORD.xy)) {
		discard;
	}
	ALBEDO = mix(color.rgb, look_ink.rgb, look_ink.a);
}
