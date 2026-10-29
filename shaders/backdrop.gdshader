shader_type spatial;
render_mode cull_back;

// Far hills beyond the playable square: forested Sierra Madre foothills,
// a pale lakeshore. Only ever seen through haze, so it stays simple.

uniform vec3 forest : source_color = vec3(0.12, 0.22, 0.08);
uniform vec3 forest_light : source_color = vec3(0.26, 0.36, 0.14);
uniform vec3 shore : source_color = vec3(0.42, 0.40, 0.28);

varying vec3 wp;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = noise(wp.xz * 0.02) * 0.6 + noise(wp.xz * 0.11) * 0.4;
	// canopy clumps read as mottling even at a distance
	float clumps = noise(wp.xz * 0.35);
	vec3 col = mix(forest, forest_light, smoothstep(0.35, 0.75, n)) * (0.75 + 0.5 * clumps);
	col = mix(shore, col, smoothstep(0.2, 2.5, wp.y));
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
