// The "coming soon" level select (scripts/coming_soon.gd): whatever's behind it (the tower's film, or
// its roof view) goes grey and dim, except through the viewing window in the hoarding.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float grey = 0.85;
uniform float dark = 0.62;
uniform float fade = 1.0;          // 0: the picture as it is .. 1: greyed
uniform vec2 hole = vec2(-1.0);    // the window's centre (screen uv)
uniform float hole_r = 0.0;        // its radius, in screen heights

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	vec3 g = mix(c, vec3(dot(c, vec3(0.299, 0.587, 0.114))), grey) * dark;
	float r = hole_r / SCREEN_PIXEL_SIZE.y;
	float inside = 1.0 - smoothstep(r - 1.5, r + 1.5, length((SCREEN_UV - hole) / SCREEN_PIXEL_SIZE));
	COLOR = vec4(mix(c, g, fade * (1.0 - inside)), 1.0);
}
