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
// The deck's section cut (Spire, John's pick C, 28 Nov): on the parts that take it (near_on: the
// perimeter scaffold, its screens and the floors), the camera side is cut away like a section drawing.
// Over the deck, everything past a line through the deck's middle goes, down to the toe board; under
// the deck, the outside few metres of the storey below go, so you see into it. The cut's edges are
// hatched (cut_section). cut_near: towards the camera on the ground (x, z), the deck's middle (x, z).
// cut_near2: the deck's top (y), the line over the deck, the line under it (m from the middle,
// towards the camera), the storey's height (0: off).
uniform bool near_on = false;
uniform vec4 cut_near = vec4(0.0);
uniform vec4 cut_near2 = vec4(0.0);
const float NEAR_TOE = 0.17;   // m over the deck the toe boards keep to
const float NEAR_EDGE = 0.25;  // m, the hatched band along the cut

// 0 kept, 1 cut away, 2 the hatched edge of the cut (world position `wp`).
int cut_near_zone(vec3 wp) {
	if (!near_on || cut_near2.w <= 0.0) {
		return 0;
	}
	float s = dot(wp.xz - cut_near.zw, cut_near.xy);
	float dy = wp.y - cut_near2.x;
	float line = 1e6;
	if (dy > NEAR_TOE && dy < 4.0) {
		line = cut_near2.y;
	} else if (dy < -0.35 && dy > 0.25 - cut_near2.w) {
		line = cut_near2.z;
	}
	if (s > line) {
		return 1;
	}
	if (s > line - NEAR_EDGE) {
		return 2;
	}
	return 0;
}

// The colour a part shows: hatched where the section cut runs through it.
vec3 cut_section(vec3 albedo, vec3 v, mat4 inv_view, vec2 frag) {
	if (!near_on) {
		return albedo;
	}
	vec3 wp = (inv_view * vec4(v, 1.0)).xyz;
	if (cut_near_zone(wp) != 2) {
		return albedo;
	}
	return fract((frag.x + frag.y) / 9.0) < 0.45 ? vec3(0.17, 0.18, 0.21) : vec3(0.56, 0.55, 0.51);
}

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
	if (near_on && cut_near_zone((inv_view * vec4(v, 1.0)).xyz) == 1) {
		return true;
	}
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
