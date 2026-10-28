// The grass plane under the whole world (scripts/surrounds.gd), toon like
// shaders/toon.gdshader, with a hole wherever data/river_mask.png says the
// river is (tools/river_banks.py), so the river can lie down below the land.
shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D wet : filter_nearest, repeat_disable;

varying vec2 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	// top 4096 rows: +-2048 m at 1 m a pixel; bottom 2048: +-8192 m
	vec2 uv;
	if (abs(wp.x) < 2047.0 && abs(wp.y) < 2047.0) {
		uv = vec2((2048.0 - wp.x) / 4096.0, (2048.0 - wp.y) / 6144.0);
	} else {
		uv = vec2((8192.0 - wp.x) / 16384.0, (4096.0 + (8192.0 - wp.y) / 8.0) / 6144.0);
	}
	if (texture(wet, uv).r > 0.5) {
		discard;
	}
	ALBEDO = albedo.rgb;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
	RIM = 0.35;
	RIM_TINT = 0.6;
}
