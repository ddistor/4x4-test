shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// Morong ground, layered per pixel: grass (sunburnt and lush patches), leaf
// litter under the forest, raw laterite where banks are cut steep, compacted
// gravel road through the paddies, and the trail's clay - glossy where wet,
// darker in the ruts, with standing water in the low spots.

// R = rut depth (m), G = wetness 0..1, B = soft mud thickness (m)
uniform sampler2D mud_tex : filter_linear, repeat_disable;
// R = distance to trail centre / 32 m, G = forest cover 0..1
uniform sampler2D cover_tex : filter_linear, repeat_disable;
uniform float world_size = 256.0;
uniform float creek_level = 0.0;
uniform float paddy_water = -0.2;

uniform vec3 clay_dry : source_color = vec3(0.60, 0.31, 0.14);     // Morong laterite, sun-baked
uniform vec3 clay_wet : source_color = vec3(0.33, 0.14, 0.06);     // same clay after rain
uniform vec3 laterite : source_color = vec3(0.56, 0.25, 0.1);      // fresh cut bank
uniform vec3 grass_a  : source_color = vec3(0.22, 0.36, 0.09);
uniform vec3 grass_b  : source_color = vec3(0.40, 0.45, 0.16);     // sunburnt cogon
uniform vec3 grass_dk : source_color = vec3(0.10, 0.20, 0.05);
uniform vec3 paddy    : source_color = vec3(0.27, 0.38, 0.12);
uniform vec3 litter_a : source_color = vec3(0.26, 0.17, 0.09);
uniform vec3 litter_b : source_color = vec3(0.46, 0.31, 0.15);
uniform vec3 gravel   : source_color = vec3(0.50, 0.44, 0.36);
uniform vec3 stone    : source_color = vec3(0.66, 0.63, 0.57);
uniform vec3 silt     : source_color = vec3(0.12, 0.10, 0.06);
uniform vec3 puddle_col : source_color = vec3(0.10, 0.06, 0.03);

varying vec3 world_pos;

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

// x: distance to nearest cell point, y: that cell's random id
vec2 cells(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float best = 8.0;
	float id = 0.0;
	for (int y = -1; y <= 1; y++)
	for (int x = -1; x <= 1; x++) {
		vec2 g = vec2(float(x), float(y));
		vec2 o = vec2(hash(i + g), hash(i + g + 17.3));
		float d = length(g + o - f);
		if (d < best) { best = d; id = hash(i + g + 41.7); }
	}
	return vec2(best, id);
}

// Bump the view-space normal by a scalar height field using screen-space
// derivatives (no tangents needed on a generated mesh).
vec3 bump(vec3 n, vec3 pos, float h) {
	vec3 dpdx = dFdx(pos);
	vec3 dpdy = dFdy(pos);
	float dhdx = dFdx(h);
	float dhdy = dFdy(h);
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhdx * r1 + dhdy * r2);
	return normalize(abs(det) * n - grad);
}

void vertex() {
	// Ruts carve the visual surface down. The collider stays put; the wheel
	// code reads the same data to sink the contact point.
	VERTEX.y -= texture(mud_tex, UV).r;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 m = texture(mud_tex, UV).rgb;
	vec2 cov = texture(cover_tex, UV).rg;
	float forest = cov.g;
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float slope = 1.0 - wn.y;
	vec2 p = world_pos.xz;
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	float detail = 1.0 - smoothstep(20.0, 70.0, dist);

	float g1 = fbm(p * 0.07);
	float g2 = fbm(p * 0.55 + 3.1);
	float g3 = noise(p * 4.0);
	float g4 = noise(p * 17.0);

	// --- grass ---------------------------------------------------------------
	vec3 grass = mix(grass_a, grass_b, smoothstep(0.42, 0.75, g1));
	grass = mix(grass, grass_dk, smoothstep(0.5, 0.8, g2) * 0.6);
	grass *= 0.78 + 0.3 * g3 + 0.2 * (g4 - 0.5) * detail;
	float bare = smoothstep(0.64, 0.74, fbm(p * 0.22 + 7.0));
	grass = mix(grass, mix(laterite * 0.65, litter_a, 0.5), bare * 0.55);
	float h = (g3 * 0.5 + g4 * 0.5) * 0.02;

	// --- forest floor --------------------------------------------------------
	vec2 leaf = cells(p * 6.0);
	vec3 litter = mix(litter_a, litter_b, leaf.y) * (0.7 + 0.5 * g3);
	litter = mix(litter, grass_dk * 1.3, smoothstep(0.5, 0.85, g2) * 0.55);
	litter *= mix(1.0, 0.75, smoothstep(0.1, 0.45, leaf.x));  // shadowed gaps between leaves
	vec3 ground = mix(grass, litter, forest);
	h = mix(h, (1.0 - leaf.x) * 0.012, forest);

	// --- cut banks: raw laterite, banded where the cut exposes layers -------
	float band = noise(vec2(world_pos.y * 4.0, (p.x + p.y) * 0.08));
	vec3 bank = laterite * (0.72 + 0.3 * band) * (0.8 + 0.3 * g4) * (0.85 + 0.3 * g2);
	// roots and soil darken the top of the cut; the forest keeps its litter on steep ground
	bank = mix(bank, litter_a * 0.8, smoothstep(0.55, 0.8, g1) * 0.5);
	float steep = smoothstep(0.22, 0.42, slope + (g2 - 0.5) * 0.2) * (1.0 - 0.7 * forest);
	ground = mix(ground, bank, steep);
	h = mix(h, g4 * 0.012 + g3 * 0.01, steep);

	float soft = smoothstep(0.02, 0.12, m.b);
	float rough_ground = mix(0.92, 0.85, forest);

	// --- paddies and the gravel road ---------------------------------------
	if (world_pos.z < 45.0) {
		vec3 dike = paddy * (0.8 + 0.35 * g3);
		float under = 1.0 - smoothstep(paddy_water - 0.1, paddy_water + 0.06, world_pos.y);
		ground = mix(dike, silt * (0.8 + 0.4 * g3), under);
		float road = 1.0 - smoothstep(0.06, 0.2, m.b);
		vec2 st = cells(p * 11.0);
		float pebble = smoothstep(0.26, 0.1, st.x) * step(0.35, st.y) * detail;
		vec3 grav = gravel * (0.8 + 0.3 * g3);
		grav = mix(grav, stone * (0.6 + 0.4 * st.y), pebble * 0.45);
		ground = mix(ground, grav, road);
		h = mix(h, pebble * 0.025 * (0.5 + st.y), road);
		soft = 0.0;
	}

	// mud piled up by the tires (negative rut) is clay wherever it landed,
	// grass and gravel road included
	float pile = smoothstep(0.004, 0.04, -m.r);
	soft = max(soft, pile);

	// --- trail clay ------------------------------------------------------------
	vec3 clay = mix(clay_dry, clay_wet, m.g);
	clay *= 0.8 + 0.28 * fbm(p * 1.4) + 0.2 * (g4 - 0.5) * detail;
	float rut_k = smoothstep(0.02, 0.18, m.r);
	clay = mix(clay, clay_wet * 0.72, rut_k * (0.5 + 0.5 * g3));
	float clods = fbm(p * 3.5);
	vec3 col = mix(ground, clay, soft);
	h = mix(h, clods * 0.05 + g4 * 0.012, soft);
	float rough = mix(rough_ground, mix(0.85, 0.28, pow(m.g, 1.4)), soft);
	float spec = mix(0.3, 0.5, soft * m.g);

	// --- standing water: in deep wet ruts, low spots on wet clay, the creek --
	float pool = m.g * (0.45 + rut_k) - fbm(p * 0.16 + 11.0) * 0.75;
	float puddle = smoothstep(0.1, 0.16, pool) * soft;
	float underwater = step(world_pos.y, creek_level) * step(92.0, world_pos.z) * step(world_pos.z, 132.0);
	float water = max(puddle, underwater);
	// a dark wet margin round each puddle
	col *= 1.0 - 0.3 * smoothstep(0.04, 0.1, pool) * soft * (1.0 - puddle);
	col = mix(col, puddle_col, water * 0.85);
	rough = mix(rough, 0.03, water);
	spec = mix(spec, 0.5, water);
	h = mix(h, 0.0015 * sin(p.x * 9.0 + TIME * 1.3) * sin(p.y * 7.0 - TIME), water);

	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
	// Ruts and berms move the surface in the vertex shader; tilt the normal to
	// match so their walls catch the light (surface = base - rut).
	vec2 tx = 1.0 / vec2(textureSize(mud_tex, 0));
	float cell = world_size * tx.x;
	float rl = texture(mud_tex, UV - vec2(tx.x, 0.0)).r;
	float rr = texture(mud_tex, UV + vec2(tx.x, 0.0)).r;
	float rd = texture(mud_tex, UV - vec2(0.0, tx.y)).r;
	float ru = texture(mud_tex, UV + vec2(0.0, tx.y)).r;
	vec3 rutted = normalize(wn + vec3(rr - rl, 0.0, ru - rd) / (2.0 * cell));
	NORMAL = normalize((VIEW_MATRIX * vec4(rutted, 0.0)).xyz);
	NORMAL = bump(NORMAL, VERTEX, h * mix(0.3, 1.0, detail));
}
