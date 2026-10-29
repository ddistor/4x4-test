// Shared Morong-clay look for anything that gets muddy (body, tires, axles).
// Fresh mud is dark, glossy and lumpy; it dries to a pale, matte, cracked crust.

float mud_hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float mud_noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(mud_hash(i), mud_hash(i + vec3(1, 0, 0)), f.x),
	               mix(mud_hash(i + vec3(0, 1, 0)), mud_hash(i + vec3(1, 1, 0)), f.x), f.y),
	           mix(mix(mud_hash(i + vec3(0, 0, 1)), mud_hash(i + vec3(1, 0, 1)), f.x),
	               mix(mud_hash(i + vec3(0, 1, 1)), mud_hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float mud_fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * mud_noise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return v;
}

// Distance to the nearest crack line of a cell pattern (0 on the crack).
float mud_cracks(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int z = -1; z <= 1; z++)
	for (int y = -1; y <= 1; y++)
	for (int x = -1; x <= 1; x++) {
		vec3 g = vec3(float(x), float(y), float(z));
		vec3 o = vec3(mud_hash(i + g), mud_hash(i + g + 31.7), mud_hash(i + g + 71.3));
		float d = length(g + o - f);
		if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
	}
	return d2 - d1;
}

// Albedo/roughness/specular of clay at point p (mesh space), given how thick
// it is there (0..1) and how dry the whole rig is (0..1).
void mud_material(vec3 p, float thick, float dryness, out vec3 albedo, out float rough, out float spec) {
	float n = mud_fbm(p * 11.0);
	vec3 wet = vec3(0.25, 0.10, 0.04);
	vec3 dry = vec3(0.55, 0.28, 0.14);
	// thin films dry first, thick dollops stay dark longer
	float d = clamp(dryness * (1.35 - 0.7 * thick), 0.0, 1.0);
	albedo = mix(wet, dry, d) * (0.82 + 0.36 * n);
	// a bit of laterite red in the lumps
	albedo = mix(albedo, vec3(0.45, 0.16, 0.06), 0.25 * thick * (1.0 - d));
	// fine crazing on the thick crust only, warped so it isn't a tidy grid
	vec3 q = p * 32.0 + vec3(mud_noise(p * 9.0), mud_noise(p * 9.0 + 5.3), 0.0) * 1.5;
	float crack = smoothstep(0.0, 0.06, mud_cracks(q));
	albedo *= mix(1.0, 0.55 + 0.45 * crack, d * smoothstep(0.3, 0.9, thick));
	rough = mix(0.22, 0.95, d);
	spec = mix(0.6, 0.12, d);
}

// Lumpy mud: bends the view-space normal by the slope of a noise height field.
vec3 mud_bump(vec3 normal_v, vec3 p, float amount, mat3 to_view) {
	float e = 0.004;
	float s = 26.0;
	float h = mud_fbm(p * s);
	vec3 g = vec3(mud_fbm((p + vec3(e, 0, 0)) * s) - h,
	              mud_fbm((p + vec3(0, e, 0)) * s) - h,
	              mud_fbm((p + vec3(0, 0, e)) * s) - h) / e;
	vec3 gv = to_view * g;
	gv -= normal_v * dot(gv, normal_v);
	return normalize(normal_v - gv * 0.012 * amount);
}
