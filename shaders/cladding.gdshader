// Corrugated steel sheds (scripts/neighbours.gd): the wall colour from the
// vertex, vertical ribs that fade out with distance (no shimmer), a precast
// concrete plinth along the bottom and, every so often, a roller door.
shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform vec4 plinth : source_color = vec4(0.72, 0.71, 0.68, 1.0);
uniform vec4 door : source_color = vec4(0.55, 0.58, 0.61, 1.0);
uniform float rib = 0.76;        // rib spacing, m
uniform float bay = 9.0;         // a roller door can fall in each bay this wide

varying vec3 wpos;
varying vec3 wnorm;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 wall = pow(COLOR.rgb, vec3(2.2));
	// along the wall: whichever of x and z it runs along most
	float u = abs(wnorm.x) > abs(wnorm.z) ? wpos.z : wpos.x;
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	float near = 1.0 - smoothstep(40.0, 160.0, dist);
	float r = smoothstep(0.35, 0.5, abs(fract(u / rib) - 0.5) * 2.0);
	vec3 c = wall * (1.0 - 0.10 * r * near);
	// roller doors: some bays, 4.5 m high, with horizontal slats
	float b = floor(u / bay);
	float f = fract(u / bay);
	float has = step(0.62, hash(vec2(b, floor(wpos.x * 0.01 + wpos.z * 0.013))));
	float in_door = has * step(0.22, f) * step(f, 0.78) * step(wpos.y, 4.5);
	float slat = 1.0 - 0.12 * step(0.5, fract(wpos.y / 0.25)) * near;
	c = mix(c, door.rgb * slat, in_door);
	// the precast plinth
	c = mix(c, plinth.rgb, step(wpos.y, 1.2) * (1.0 - in_door));
	ALBEDO = c;
	ROUGHNESS = 0.7;
	SPECULAR = 0.3;
}
