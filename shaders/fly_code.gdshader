shader_type canvas_item;
// Reads the number stamped on the film frame that is on the screen (tools/blender/spire/film_pack.py:
// a column of black or white squares down its top left corner), one square to a pixel of a tiny
// viewport, for scripts/fly_film.gd to read back.
uniform sampler2D film : filter_nearest;
uniform vec2 tex_size = vec2(1280.0, 1568.0);
uniform float block = 16.0;
uniform float bits = 9.0;

void fragment() {
	float i = floor(UV.x * bits);
	float g = texture(film, vec2(block * 0.5, (i + 0.5) * block) / tex_size).g;
	COLOR = vec4(vec3(step(0.5, g)), 1.0);
}
