shader_type spatial;
render_mode cull_back;

// Boulders and river stones: grey andesite with darker veins, lichen on the
// tops, a laterite stain where they sit in the clay, and dark and glossy
// wherever the river wets them.

// B = water level (m), from the terrain's soil map
uniform sampler2D soil_tex : filter_linear, repeat_disable;
uniform vec2 world_size = vec2(160.0, 1000.0);
uniform vec3 stone_a : source_color = vec3(0.50, 0.48, 0.45);
uniform vec3 stone_b : source_color = vec3(0.33, 0.31, 0.29);
uniform vec3 lichen : source_color = vec3(0.45, 0.47, 0.32);
uniform vec3 stain : source_color = vec3(0.45, 0.24, 0.11);
uniform vec3 ash_stain : source_color = vec3(0.6, 0.58, 0.53);   // grey lahar ash

varying vec3 wp;
varying float coat;   // how much clay this stone wears (per instance)
varying float ashy;   // and whether that's red clay or grey lahar ash
varying vec3 wn;
varying float base_y;

// Integer hash of the float's bits: exact at any distance from the origin.
// (The old fract(p * 456.21) ran out of float precision a few hundred metres
// up the stage and the noise broke into blocks: the ground went to squares.)
float hash(vec2 p) {
	uvec2 q = floatBitsToUint(p);
	uint h = q.x * 1597334677u ^ q.y * 3812015801u;
	h = (h ^ (h >> 16u)) * 2246822519u;
	h = (h ^ (h >> 13u)) * 3266489917u;
	h ^= h >> 16u;
	return float(h) * (1.0 / 4294967295.0);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

vec3 bump(vec3 n, vec3 pos, float h) {
	vec3 dpdx = dFdx(pos);
	vec3 dpdy = dFdy(pos);
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	return normalize(abs(det) * n - grad);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	base_y = (MODEL_MATRIX * vec4(0.0, -0.45, 0.0, 1.0)).y;
	coat = INSTANCE_CUSTOM.r;
	ashy = INSTANCE_CUSTOM.g;
}

global uniform float rain_soak;

void fragment() {
	// project the noise along the dominant axis so steep faces don't smear
	vec2 p = abs(wn.y) > 0.6 ? wp.xz : (abs(wn.x) > abs(wn.z) ? wp.zy : wp.xy);
	float n = fbm(p * 1.6);
	float fine = noise(p * 14.0);
	vec3 col = mix(stone_b, stone_a, smoothstep(0.3, 0.7, n));
	col *= 0.85 + 0.25 * fine;
	float vein = smoothstep(0.03, 0.0, abs(fbm(p * 0.9 + 4.0) - 0.5));
	col = mix(col, stone_b * 0.6, vein * 0.6);
	col = mix(col, lichen, smoothstep(0.55, 0.9, wn.y) * smoothstep(0.5, 0.65, fbm(p * 0.7 + 2.0)) * 0.6);
	// clay splashed up the bottom; in a muddy gully, smeared most of the way up,
	// wet and dark, with the stone showing through where tires have scrubbed it
	float scrub = smoothstep(0.45, 0.75, fbm(p * 2.2 + 7.0));
	float mud_line = base_y + 0.45 + coat * 0.9 * (0.75 + 0.5 * n);
	float smear = (1.0 - smoothstep(mud_line - 0.08, mud_line, wp.y)) * mix(0.55, 0.92 * (1.0 - 0.7 * scrub), coat);
	vec3 st = mix(stain, ash_stain, ashy);
	col = mix(col, mix(st, st * 0.55, coat), smear);

	float level = texture(soil_tex, wp.xz / world_size).b;
	float wet = 1.0 - smoothstep(level - 0.05, level + 0.25, wp.y);
	wet = max(wet, rain_soak * 0.7);   // rain-wet stone: darker, a sheen
	col *= mix(1.0, 0.5, wet);
	ALBEDO = col;
	ROUGHNESS = mix(mix(0.82, 0.35, smear * coat), 0.2, wet);
	SPECULAR = mix(0.4, 0.6, wet);
	NORMAL = bump(NORMAL, VERTEX, (n * 0.04 + fine * 0.008 - vein * 0.01));
}
