// The fly-in's film (scripts/fly_film.gd): the game's own site laid over the film. Black is "not the
// site" (the buildings in front of it, shaders/fly_cover.gdshader): the film shows there.
shader_type canvas_item;

uniform float show = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float lit = max(c.r, max(c.g, c.b));
	COLOR = vec4(c.rgb, c.a * smoothstep(0.004, 0.03, lit) * show);
}
