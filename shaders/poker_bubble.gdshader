// The poker's air bubbles: wet glossy domes of grey slurry that swell up out
// of the concrete, wobble and pop. Big and shiny on purpose, with a bright
// rim and a hot highlight, so they read from the couch: while they're coming
// up the spot isn't done yet. Per bubble (INSTANCE_CUSTOM): r = grow 0..1,
// g = wobble phase, b = pop 0..1 (the skin thins and clears), a = fade.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 skin : source_color = vec4(0.56, 0.55, 0.52, 1.0);
uniform vec4 rim : source_color = vec4(0.97, 0.96, 0.92, 1.0);
uniform float low_light = 0.0;

varying vec4 cd;

void vertex() {
	cd = INSTANCE_CUSTOM;
	// (swells up from flat, wobbles a little, flattens as it pops)
	float wob = sin(cd.g * 6.2831 + TIME * 14.0) * 0.08 * cd.r;
	VERTEX.xz *= 1.0 + wob + cd.b * 0.35;
	VERTEX.y *= cd.r * (1.0 - wob) * (1.0 - cd.b * 0.8);
}

void fragment() {
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 2.2);
	// a sun highlight up and to one side, and a second smaller one
	vec3 hdir = normalize((VIEW_MATRIX * vec4(-0.4, 1.0, 0.3, 0.0)).xyz);
	vec3 h = normalize(hdir + VIEW);
	float spec = pow(max(dot(NORMAL, h), 0.0), 60.0);
	float spec2 = pow(max(dot(NORMAL, normalize(VIEW + vec3(0.3, -0.2, 0.0))), 0.0), 120.0) * 0.6;
	vec3 c = mix(skin.rgb, rim.rgb, fres * 0.9);
	c += vec3(1.0) * (spec * 1.4 + spec2);
	c *= 1.0 + low_light * 0.35;
	ALBEDO = c;
	// (the middle of the dome goes see-through as the skin thins to pop)
	float a = mix(0.92, 0.35 + fres * 0.65, cd.b);
	ALPHA = clamp(a + spec, 0.0, 1.0) * cd.a;
}
