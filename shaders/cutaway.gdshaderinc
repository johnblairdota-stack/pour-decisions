// The see-through circle round the work (main._update_cutaway): parts of the
// hoist and the boom tower between the camera and someone at work are cut
// away in a soft-edged circle round them on screen, clear in the middle and
// dithered out to solid at the rim. Only what's in front of the work is cut.
uniform int cut_n = 0;
uniform vec4 cut_p[6];   // the work points: world position, circle radius (m)
// The section slot (Spire's boom column and line, up inside the building): everything in a
// vertical slot from the street face in to the column is cut away, floor by floor, so the
// column, its ladder and the line read like a section drawing. x0, x1, the z it stops at
// (world), and whether it's on; then the heights it runs between.
uniform vec4 cut_slot = vec4(0.0);
uniform vec3 cut_slot_y = vec3(0.0);   // from this height, to this one; and the z of the street face it starts at

float cut_bayer(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	const float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[y * 4 + x] + 0.5) / 16.0;
}

// True when this fragment (view-space `v`) falls inside a cut.
bool cut_hidden(vec3 v, mat4 view, mat4 inv_view, vec2 frag) {
	float a = 1.0;
	float fd = -v.z;
	if (cut_slot.w > 0.5) {
		vec3 wp = (inv_view * vec4(v, 1.0)).xyz;
		if (wp.z > cut_slot.z && wp.z < cut_slot_y.z && wp.y > cut_slot_y.x && wp.y < cut_slot_y.y) {
			// (soft at its two sides, so the floors either side fade in)
			float e = min(min(wp.x - cut_slot.x, cut_slot.y - wp.x), min(wp.y - cut_slot_y.x, cut_slot_y.y - wp.y) * 2.0);
			a = 1.0 - smoothstep(0.0, 0.9, e);
		}
	}
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
