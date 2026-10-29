shader_type spatial;
render_mode cull_back;

// Trunks, branches, bamboo culms, palm stems. Base colour from the vertex
// colour; vertical bark streaks, pale lichen patches, and a splash of red
// clay up the bottom of anything standing near the trail.

uniform float lichen = 0.35;
uniform float streak_scale = 7.0;

varying vec3 lp;
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
	lp = VERTEX;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float around = (lp.x + lp.z) * streak_scale;
	float streak = noise(vec2(around, lp.y * 0.6)) * 0.6 + noise(vec2(around * 3.0, lp.y * 2.0)) * 0.4;
	// vertex colours are authored as sRGB, like the source_color uniforms;
	// clamped because MSAA can sample a hair outside thin blade tips, and
	// pow() of a negative is NaN (which glow then smears into white blobs)
	vec3 col = pow(clamp(COLOR.rgb, 0.0, 1.0), vec3(2.2)) * (0.7 + 0.5 * streak);
	float patch = smoothstep(0.55, 0.75, noise(vec2(around * 0.4, lp.y * 0.5) + 5.0));
	col = mix(col, vec3(0.34, 0.36, 0.28), patch * lichen);
	// clay splash near the ground
	col = mix(col, vec3(0.15, 0.04, 0.012), (1.0 - smoothstep(0.1, 0.6, lp.y)) * 0.6 * COLOR.a);
	ALBEDO = col;
	ROUGHNESS = 0.9;
	SPECULAR = 0.25;
}
