// Inverted-hull outline, used as a next pass on characters and the boom.
shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 color : source_color = vec4(0.06, 0.08, 0.14, 1.0);
uniform float thickness = 0.035;

void vertex() {
	VERTEX += NORMAL * thickness;
}

void fragment() {
	ALBEDO = color.rgb;
}
