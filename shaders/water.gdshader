shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

// Every water sheet on the stage: muddy paddies and creeks (clarity 0, the
// tint is the water), and clear mountain rivers (clarity 1) where you see the
// stones on the bed, the colour deepens with depth, white water froths
// round anything breaking the surface and the current streaks downstream.
uniform vec4 tint : source_color = vec4(0.45, 0.32, 0.18, 0.85);
uniform float ripple_speed = 0.6;
uniform float clarity = 0.0;
uniform vec2 flow = vec2(0.0);  // m/s, along the river
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
// the terrain's soil map: A says where water may stand (a river sheet only shows in its channel)
uniform bool use_mask = false;
uniform sampler2D soil_tex : filter_linear, repeat_disable;
uniform vec2 world_size = vec2(160.0, 1000.0);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	if (use_mask && texture(soil_tex, p / world_size).a < 0.5) {
		discard;
	}
	float t = TIME * ripple_speed;
	vec2 drift = flow * TIME;
	float w = sin(p.x * 2.1 + t) * 0.5 + sin(p.y * 1.7 - t * 1.3) * 0.5;
	w += sin((p.x + p.y) * 0.9 + t * 0.7) * 0.5;
	// running water: choppy noise carried downstream
	float run = length(flow);
	float chop = noise((p - drift) * 3.0) + 0.5 * noise((p - drift * 1.3) * 7.0);
	w = mix(w, (chop - 0.75) * 2.0, smoothstep(0.0, 0.8, run));
	NORMAL_MAP = normalize(vec3(w * (0.08 + 0.06 * run), 1.0, w * (0.06 + 0.06 * run))) * 0.5 + 0.5;

	vec3 col = tint.rgb * (0.9 + 0.1 * w);
	float alpha = tint.a;
	if (clarity > 0.0) {
		// how much water the eye looks through to reach the bed
		float d = texture(depth_tex, SCREEN_UV).r;
		vec4 bed = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
		bed.xyz /= bed.w;
		float thick = max(0.0, length(bed.xyz) - length(VERTEX));
		float absorb = 1.0 - exp(-thick * mix(6.0, 1.6, clarity));
		alpha = mix(tint.a, 0.08 + 0.9 * absorb, clarity);
		col = mix(col * 1.3, col, absorb);
		// white water: thin water over stones and round anything in the current
		float shallow = 1.0 - smoothstep(0.02, 0.12 + 0.1 * run, thick);
		float streak = smoothstep(0.55, 0.85, noise((p - drift) * vec2(1.2, 4.0)) * chop * 0.8);
		float foam = clamp(shallow * (0.6 + chop * 0.6) + streak * 0.25 * run, 0.0, 1.0);
		col = mix(col, vec3(0.92, 0.94, 0.92), foam);
		alpha = max(alpha, foam * 0.85);
	}
	ALBEDO = col;
	ALPHA = alpha;
	ROUGHNESS = mix(0.35, 0.06, clarity);
	SPECULAR = 0.5;
	METALLIC = 0.0;
}
