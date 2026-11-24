// The fly-in's film (scripts/fly_film.gd): the city's buildings as the site's camera sees them. Pure
// black and nothing else: where one stands in front of the site, the site isn't drawn, and the film's
// own picture of that building shows there.
shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled, cull_disabled;

void fragment() {
	ALBEDO = vec3(0.0);
}
