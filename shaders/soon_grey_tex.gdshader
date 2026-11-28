// A "coming soon" tower's card (scripts/coming_soon.gd): its picture, grey and dim.
shader_type canvas_item;

uniform float grey = 0.8;
uniform float dark = 0.8;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(mix(c.rgb, vec3(dot(c.rgb, vec3(0.299, 0.587, 0.114))), grey) * dark, c.a);
}
