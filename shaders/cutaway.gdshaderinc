// The see-through circle round the work (main._update_cutaway): parts of the
// hoist and the boom tower between the camera and someone at work are cut
// away in a soft-edged circle round them on screen, clear in the middle and
// dithered out to solid at the rim. Only what's in front of the work is cut.
uniform int cut_n = 0;
uniform vec4 cut_p[6];   // the work points: world position, circle radius (m)

float cut_bayer(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	const float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[y * 4 + x] + 0.5) / 16.0;
}

// True when this fragment (view-space `v`) falls inside a cut.
bool cut_hidden(vec3 v, mat4 view, vec2 frag) {
	float a = 1.0;
	float fd = -v.z;
	for (int i = 0; i < 6; i++) {
		if (i >= cut_n) {
			break;
		}
		vec3 w = (view * vec4(cut_p[i].xyz, 1.0)).xyz;
		float wd = -w.z;
		if (wd <= 0.5) {
			continue;
		}
		// (on screen: the angle off the work, against the circle's angle)
		float r = length(v.xy / fd - w.xy / wd) / (cut_p[i].w / wd);
		float ring = smoothstep(0.45, 1.0, r);
		// (only in front of the work, fading in over the last couple of metres)
		float front = 1.0 - smoothstep(wd - cut_p[i].w * 0.6, wd - cut_p[i].w * 0.2, fd);
		a = min(a, mix(1.0, ring, front));
	}
	return a < cut_bayer(frag);
}
