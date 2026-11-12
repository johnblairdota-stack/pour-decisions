// Comic Ink look (scripts/look.gd): ink lines round everything, found from
// the depth buffer. A full-screen quad, drawn first among the see-through
// things so the cues, labels and rings still sit on top of the lines.
// One pass over the screen, five depth reads a pixel: the one look that
// costs a little (switched off on Lite).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, blend_mix, shadows_disabled, fog_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec4 ink : source_color = vec4(0.05, 0.05, 0.08, 1.0);
uniform float width = 1.0;       // px, at 900 high
uniform float strength = 0.9;
uniform float near_fade = 140.0; // m: lines thin out to nothing by here
uniform float far_fade = 260.0;

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

float lin(vec2 uv, mat4 inv_proj) {
	float d = textureLod(depth_tex, uv, 0.0).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	d = d * 2.0 - 1.0;
#endif
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}

void fragment() {
	vec2 px = width * max(VIEWPORT_SIZE.y / 900.0, 1.0) / VIEWPORT_SIZE;
	float c = lin(SCREEN_UV, INV_PROJECTION_MATRIX);
	float l = lin(SCREEN_UV - vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	float r = lin(SCREEN_UV + vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	float u = lin(SCREEN_UV - vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	float d = lin(SCREEN_UV + vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	// (the second difference: a step in depth is an edge, a slope isn't)
	float e = (abs(l + r - 2.0 * c) + abs(u + d - 2.0 * c)) / max(c, 0.5);
	float a = smoothstep(0.04, 0.12, e);
	a *= 1.0 - smoothstep(near_fade, far_fade, c);
	ALBEDO = ink.rgb;
	ALPHA = a * strength;
}
