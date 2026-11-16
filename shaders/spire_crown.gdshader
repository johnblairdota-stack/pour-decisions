// Spire's far tree crowns: sunlit tops and shaded undersides in two greens, so a crown reads as a
// rounded head of leaves and not one flat tile.
shader_type spatial;

uniform vec4 light_col : source_color = vec4(0.42, 0.56, 0.26, 1.0);
uniform vec4 dark_col : source_color = vec4(0.16, 0.28, 0.14, 1.0);

varying vec3 wn;
varying vec3 wp;

void vertex() {
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// (a little patchiness from where the leaf stands, so neighbouring crowns differ)
	float patch = sin(wp.x * 0.9) * sin(wp.z * 1.1 + wp.y * 0.7) * 0.12;
	float up = smoothstep(-0.35, 0.75, normalize(wn).y + patch);
	ALBEDO = mix(dark_col.rgb, light_col.rgb, up);
	ROUGHNESS = 0.95;
	SPECULAR = 0.05;
}
