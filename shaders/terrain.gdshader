shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// R = rut depth (m), G = wetness 0..1, B = soft mud thickness (m)
uniform sampler2D mud_tex : filter_linear, repeat_disable;
uniform float world_size = 256.0;
uniform float creek_level = 0.0;

uniform vec3 clay_dry = vec3(0.62, 0.33, 0.14);     // Morong laterite, sun-baked
uniform vec3 clay_wet = vec3(0.36, 0.17, 0.07);     // same clay after rain
uniform vec3 grass    = vec3(0.22, 0.36, 0.12);
uniform vec3 paddy    = vec3(0.28, 0.46, 0.14);
uniform vec3 gravel   = vec3(0.42, 0.36, 0.28);

varying vec3 world_pos;
varying float v_rut;
varying float v_wet;
varying float v_thick;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
	           mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	vec3 m = texture(mud_tex, UV).rgb;
	v_rut = m.r;
	v_wet = m.g;
	v_thick = m.b;
	// Ruts carve the visual surface down. The collider stays put; the wheel
	// code reads the same texture data to sink the contact point.
	VERTEX.y -= v_rut;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = vnoise(world_pos.xz * 1.3);
	float n2 = vnoise(world_pos.xz * 7.0);

	float soft = smoothstep(0.02, 0.12, v_thick);
	vec3 clay = mix(clay_dry, clay_wet, v_wet);
	clay *= 0.85 + 0.3 * n;
	// churned mud in the ruts is darker and lumpy
	float rut_k = smoothstep(0.02, 0.2, v_rut);
	clay = mix(clay, clay_wet * 0.8, rut_k * (0.5 + 0.5 * n2));

	vec3 ground = grass * (0.8 + 0.4 * n);
	if (world_pos.z < 45.0) {
		// paddy floor under the water is dark silt; the dikes above it are grassy
		ground = mix(vec3(0.16, 0.14, 0.08), paddy * (0.85 + 0.3 * n2), smoothstep(-0.3, -0.05, world_pos.y));
		float road = 1.0 - smoothstep(2.6, 3.6, abs(world_pos.x - world_size * 0.5 - 14.0 * sin(world_pos.z * 0.035) - 0.0));
		ground = mix(ground, gravel * (0.9 + 0.2 * n2), road);
		soft = 0.0;
	}
	vec3 col = mix(ground, clay, soft);

	// standing water in deep wet ruts and below the creek level
	float pooled = smoothstep(0.08, 0.2, v_rut) * smoothstep(0.75, 1.0, v_wet);
	float underwater = step(world_pos.y, creek_level) * step(92.0, world_pos.z) * step(world_pos.z, 132.0);
	float water = max(pooled, underwater);
	col = mix(col, clay_wet * 0.7, water * 0.6);

	ALBEDO = col;
	ROUGHNESS = mix(mix(0.95, 0.55, v_wet * soft), 0.15, water);
	SPECULAR = mix(0.2, 0.6, water);
}
