shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

// Every water sheet on the stage: muddy paddies, bogs and creeks (clarity 0:
// the water is the colour of the clay in it) and clear mountain rivers
// (clarity 1: you see the stones on the bed in the shallows, the colour
// deepens to green with depth). How deep it is comes from the terrain's bed
// map, so it works the same on every renderer. On top: the sky reflected at a
// glancing angle, foam where it runs thin over the bed and along the banks,
// the current streaking downstream, and what the rig does to it - a wake
// and a ring of white water round each tire, and a plume of stirred-up clay
// drifting off downstream behind it.

uniform vec4 tint : source_color = vec4(0.45, 0.32, 0.18, 0.85);
uniform float ripple_speed = 0.6;
uniform float clarity = 0.0;
uniform vec2 flow = vec2(0.0);  // m/s, along the river
// the terrain's soil map: A says where water may stand (a river sheet only shows in its channel)
uniform bool use_mask = false;
uniform sampler2D soil_tex : filter_linear, repeat_disable;
uniform sampler2D bed_tex : filter_linear, repeat_disable;   // ground height (m)
uniform vec2 world_size = vec2(160.0, 1000.0);
uniform vec3 sky_col : source_color = vec3(0.62, 0.7, 0.76);  // what the surface mirrors
uniform vec3 deep_col : source_color = vec3(0.08, 0.22, 0.17);
// the rig: each wheel's world position and how fast it's moving through the water
uniform vec4 wheels[4];
uniform vec3 rig_vel = vec3(0.0);
// clay the rig has stirred up: xz where, z strength, w when (seconds, `now`)
uniform vec4 plumes[12];
uniform float now = 0.0;
uniform vec3 plume_col : source_color = vec3(0.42, 0.25, 0.12);

varying vec3 wpos;

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

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	vec2 uv = p / world_size;
	if (use_mask && texture(soil_tex, uv).a < 0.5) {
		discard;
	}
	float depth = wpos.y - texture(bed_tex, uv).r;
	if (depth <= 0.0) {
		discard;
	}
	float t = TIME * ripple_speed;
	vec2 drift = flow * TIME;
	float run = length(flow);

	// --- surface: slow swell on still water, choppy noise carried downstream
	float w = sin(p.x * 2.1 + t) * 0.5 + sin(p.y * 1.7 - t * 1.3) * 0.5;
	w += sin((p.x + p.y) * 0.9 + t * 0.7) * 0.5;
	float chop = noise((p - drift) * 3.0) + 0.5 * noise((p - drift * 1.3) * 7.0);
	w = mix(w * 0.4, (chop - 0.75) * 2.0, smoothstep(0.0, 0.8, run));
	// rougher where it runs shallow and fast over the stones
	float riffle = (1.0 - smoothstep(0.08, 0.45, depth)) * run;
	w *= 1.0 + 1.5 * riffle;

	// --- what the rig does to it ----------------------------------------------
	float wake = 0.0;
	float speed = length(rig_vel.xz);
	vec2 back = speed > 0.05 ? -rig_vel.xz / speed : vec2(0.0);
	for (int i = 0; i < 4; i++) {
		vec4 wh = wheels[i];
		if (wh.w <= 0.0) continue;
		vec2 d = p - wh.xz;
		float r = length(d);
		// white water piled round the tire
		wake += exp(-pow((r - 0.42) / 0.12, 2.0)) * (0.35 + 0.65 * min(wh.w, 1.0));
		// a V of ripples trailing behind it
		float along = dot(d, back);
		float across = abs(d.x * back.y - d.y * back.x);
		float vee = exp(-pow((across - along * 0.45) / 0.18, 2.0)) * step(0.0, along) * exp(-along / 3.0);
		wake += vee * min(speed / 2.0, 1.0) * (0.6 + 0.4 * sin(along * 9.0 - TIME * 6.0));
		w += vee * 1.2 * sin(along * 9.0 - TIME * 6.0);
	}
	wake = clamp(wake, 0.0, 1.0);

	// clay stirred off the tires, carried downstream and spreading as it goes
	float stir = 0.0;
	for (int i = 0; i < 12; i++) {
		vec4 pl = plumes[i];
		if (pl.z <= 0.0) continue;
		float age = now - pl.w;
		if (age < 0.0 || age > 45.0) continue;
		vec2 c = pl.xy + flow * age;
		float rad = 0.7 + 0.35 * age;
		float wobble = noise(p * 0.8 + vec2(age * 0.2, 0.0)) * 0.6;
		stir += pl.z * exp(-pow(length(p - c) / rad, 2.0) + wobble) * exp(-age / 18.0);
	}
	stir = clamp(stir * 0.5, 0.0, 0.85);

	NORMAL_MAP = normalize(vec3(w * (0.08 + 0.06 * run), 1.0, w * (0.06 + 0.06 * run))) * 0.5 + 0.5;

	// --- colour and see-through --------------------------------------------------
	// glancing angle: mostly sky; looking down: into the water
	vec3 V = normalize(CAMERA_POSITION_WORLD - wpos);
	float fres = 0.03 + 0.97 * pow(1.0 - clamp(V.y, 0.0, 1.0), 5.0);
	vec3 col;
	float alpha;
	if (clarity > 0.0) {
		// clear river: the bed shows through the shallows, green and dark in the pools
		float absorb = 1.0 - exp(-depth * 2.4);
		vec3 water = mix(tint.rgb * 1.25, deep_col, smoothstep(0.0, 1.0, absorb));
		col = water;
		alpha = mix(0.05, 0.92, absorb);
	} else {
		// muddy: opaque within a hand's depth, the thin edge shows the clay under it
		float absorb = 1.0 - exp(-depth * 14.0);
		col = tint.rgb * (0.9 + 0.1 * w);
		alpha = mix(0.35, tint.a, absorb);
	}
	// stirred clay clouds the water
	col = mix(col, plume_col * (0.85 + 0.2 * noise(p * 2.0)), stir * clarity);
	alpha = max(alpha, stir * 0.9 * clarity);
	// sky in the surface
	col = mix(col, sky_col, fres * 0.8);
	alpha = mix(alpha, 1.0, fres * 0.85);

	// --- foam: thin water over the bed, along the banks, in the current, at the rig
	float shallow = 1.0 - smoothstep(0.02, 0.08 + 0.12 * run, depth);
	float streak = smoothstep(0.55, 0.85, noise((p - drift) * vec2(1.2, 4.0)) * chop * 0.8);
	float foam = clarity * clamp(shallow * (0.4 + chop * 0.6) * min(run + 0.3, 1.0) + streak * 0.25 * run + riffle * 0.25 * chop, 0.0, 1.0);
	foam = max(foam, wake * mix(0.55, 0.9, clarity) * (0.6 + 0.4 * chop));
	vec3 foam_col = mix(vec3(0.62, 0.48, 0.34), vec3(0.92, 0.94, 0.92), clarity);   // brown froth on muddy water
	col = mix(col, foam_col, foam);
	alpha = max(alpha, foam * 0.9);
	// the waterline on the bank: a soft edge, not a cut
	alpha *= smoothstep(0.0, 0.025, depth);

	ALBEDO = col;
	ALPHA = alpha;
	ROUGHNESS = mix(mix(0.3, 0.05, clarity), 0.6, foam);
	SPECULAR = 0.5;
	METALLIC = 0.0;
}
