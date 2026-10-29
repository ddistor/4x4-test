shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// Body paint that progressively cakes with red clay. `cake` is 0 (clean)
// to 1 (looks like it just did the creek sideways). Mud builds from the
// bottom of the body up, with a noisy edge, and dries lighter over time.
uniform vec4 paint : source_color = vec4(0.78, 0.12, 0.10, 1.0);
uniform float cake : hint_range(0.0, 1.0) = 0.0;
uniform float dryness : hint_range(0.0, 1.0) = 0.3;
uniform float body_bottom = 0.05;   // model-space y of the lowest paint
uniform float body_top = 1.65;      // model-space y of the roof
uniform float metallic_paint = 0.3;

varying vec3 model_pos;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash(i);
	float n100 = hash(i + vec3(1, 0, 0));
	float n010 = hash(i + vec3(0, 1, 0));
	float n110 = hash(i + vec3(1, 1, 0));
	float n001 = hash(i + vec3(0, 0, 1));
	float n101 = hash(i + vec3(1, 0, 1));
	float n011 = hash(i + vec3(0, 1, 1));
	float n111 = hash(i + vec3(1, 1, 1));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
	           mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

void vertex() {
	model_pos = VERTEX;
}

void fragment() {
	float h = clamp((model_pos.y - body_bottom) / (body_top - body_bottom), 0.0, 1.0);
	float n = vnoise(model_pos * 9.0) * 0.6 + vnoise(model_pos * 31.0) * 0.4;
	// mud line climbs the body as cake increases; splatter dots above it
	float line = cake * 1.15 - h + (n - 0.5) * 0.35;
	float mud = smoothstep(-0.05, 0.12, line);
	float splatter = step(0.72, n) * smoothstep(0.15, 0.6, cake) * (1.0 - h) * 0.9;
	mud = max(mud, splatter);

	vec3 wet_clay = vec3(0.36, 0.17, 0.07);
	vec3 dry_clay = vec3(0.66, 0.38, 0.18);
	vec3 clay = mix(wet_clay, dry_clay, dryness) * (0.85 + 0.3 * n);

	ALBEDO = mix(paint.rgb, clay, mud);
	ROUGHNESS = mix(0.35, mix(0.45, 0.95, dryness), mud);
	METALLIC = mix(metallic_paint, 0.0, mud);
	SPECULAR = mix(0.5, 0.2, mud);
}
