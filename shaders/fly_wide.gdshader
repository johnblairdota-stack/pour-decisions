shader_type canvas_item;
// The fly-in film's screen (scripts/fly_film.gd). The film's first frames are ordinary pictures, set in
// the middle of a taller frame (`rect`), and are shown as they are. Its later frames are WIDE: fisheye
// pictures taking in far more than the screen (the angle off the picture's middle is the distance
// from it, `ppd` pixels a degree). From those the game's own view is cut: each pixel's ray out of the
// game's camera is turned into the film camera's (`rot`) and looked up. So the game's camera can look
// down onto the deck it is going to stop at, whichever deck that is, with the one film.
// Which kind the frame on the screen is, is read off the frame itself (an ordinary one has black above
// and below it, a wide one has sky there): the film's clock can be a frame out, and one frame shown
// the wrong way would flash.
uniform mat3 rot = mat3(1.0);
uniform float tan_half = 0.4663;      // tan of half the camera's angle, up and down
uniform float aspect = 1.7778;        // the screen's
uniform float ppd = 14.0;
uniform vec2 tex_size = vec2(1280.0, 1568.0);
uniform vec4 rect = vec4(0.0, 0.0, 1.0, 1.0);   // the ordinary picture in the frame: x, y, w, h (0..1)
uniform float rect_aspect = 1.7778;

void fragment() {
	vec2 s = UV * 2.0 - 1.0;
	vec2 uv;
	float top = max(texture(TEXTURE, vec2(0.5, 0.012)).g, max(texture(TEXTURE, vec2(0.25, 0.012)).g, texture(TEXTURE, vec2(0.75, 0.012)).g));
	if (top > 0.12) {
		vec3 w = rot * normalize(vec3(s.x * tan_half * aspect, -s.y * tan_half, -1.0));
		float ang = degrees(acos(clamp(-w.z, -1.0, 1.0)));
		vec2 d = w.xy / max(length(w.xy), 1e-6);
		uv = (tex_size * 0.5 + ppd * ang * vec2(d.x, -d.y)) / tex_size;
	} else {
		// (fills the screen, the overhang cut off evenly)
		vec2 k = aspect > rect_aspect ? vec2(1.0, rect_aspect / aspect) : vec2(aspect / rect_aspect, 1.0);
		uv = rect.xy + (0.5 + 0.5 * s * k) * rect.zw;
	}
	COLOR = vec4(texture(TEXTURE, uv).rgb, COLOR.a);
}
