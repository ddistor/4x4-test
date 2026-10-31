shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// Morong ground, layered per pixel: grass (sunburnt and lush patches), leaf
// litter under the forest, raw laterite where banks are cut steep, compacted
// gravel road through the paddies, and the trail's clay - glossy where wet,
// darker in the ruts, with standing water in the low spots.

// R = rut depth (m), G = wetness 0..1, B = soft mud thickness (m)
uniform sampler2D mud_tex : filter_linear, repeat_disable;
// R = distance to trail centre / 32 m, G = forest cover, B = paddy, A = lahar ash
uniform sampler2D cover_tex : filter_linear, repeat_disable;
// R = bedrock, G = river cobbles, B = water level (m; -1000 where there's none)
uniform sampler2D soil_tex : filter_linear, repeat_disable;
uniform float world_size = 160.0;  // width of the map in metres

uniform vec3 clay_dry : source_color = vec3(0.60, 0.31, 0.14);     // Morong laterite, sun-baked
uniform vec3 clay_wet : source_color = vec3(0.33, 0.14, 0.06);     // same clay after rain
uniform vec3 laterite : source_color = vec3(0.56, 0.25, 0.1);      // fresh cut bank
uniform vec3 grass_a  : source_color = vec3(0.22, 0.36, 0.09);
uniform vec3 grass_b  : source_color = vec3(0.40, 0.45, 0.16);     // sunburnt cogon
uniform vec3 grass_dk : source_color = vec3(0.10, 0.20, 0.05);
uniform vec3 paddy    : source_color = vec3(0.27, 0.38, 0.12);
uniform vec3 litter_a : source_color = vec3(0.26, 0.17, 0.09);
uniform vec3 litter_b : source_color = vec3(0.46, 0.31, 0.15);
uniform vec3 gravel   : source_color = vec3(0.40, 0.34, 0.27);   // packed dirt and crushed adobe
uniform vec3 stone    : source_color = vec3(0.66, 0.63, 0.57);
uniform vec3 silt     : source_color = vec3(0.12, 0.10, 0.06);
uniform vec3 puddle_col : source_color = vec3(0.10, 0.06, 0.03);
uniform vec3 ash_dry : source_color = vec3(0.64, 0.61, 0.55);     // Pinatubo lahar sand
uniform vec3 ash_wet : source_color = vec3(0.36, 0.35, 0.33);
uniform vec3 bedrock : source_color = vec3(0.44, 0.42, 0.39);

varying vec3 world_pos;

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
	vec4 cov = texture(cover_tex, UV);
	vec4 soil = texture(soil_tex, UV);
	float forest = cov.g;
	float paddy_k = cov.b;
	float ash = cov.a;
	float water_level = soil.b;
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
	if (paddy_k > 0.01) {
		vec3 dike = paddy * (0.8 + 0.35 * g3);
		float under = 1.0 - smoothstep(water_level - 0.1, water_level + 0.06, world_pos.y);
		vec3 pg = mix(dike, silt * (0.8 + 0.4 * g3), under);
		float road = 1.0 - smoothstep(0.06, 0.2, m.b);
		vec2 st = cells(p * 11.0);
		float pebble = smoothstep(0.22, 0.08, st.x) * step(0.45, st.y) * detail;
		vec3 grav = gravel * (0.78 + 0.22 * g2 + 0.15 * g3);
		// loose stones are paler than the packed dirt round them, not dark specks
		grav = mix(grav, stone * (0.75 + 0.25 * st.y), pebble * 0.35);
		// the two wheel lines: packed smooth and darker, a grassy crown between
		float across = cov.r * 32.0;
		float lines = exp(-pow((across - 0.8) / 0.32, 2.0));
		float crown = 1.0 - smoothstep(0.15, 0.45, across);
		grav = mix(grav, gravel * 0.72, lines * 0.6);
		grav = mix(grav, mix(grav, grass_dk * 1.6, 0.5), crown * smoothstep(0.4, 0.7, g2) * 0.7);
		pebble *= 1.0 - lines * 0.8;
		pg = mix(pg, grav, road);
		ground = mix(ground, pg, paddy_k);
		h = mix(h, mix(h * 0.6, pebble * 0.008 * (0.5 + st.y), road), paddy_k);
		soft *= 1.0 - paddy_k;
	}

	// --- lahar: grey ash and sand, wind-rippled, cliffs of the same stuff ----
	if (ash > 0.01) {
		float ripple = sin(dot(p, vec2(0.8, 2.6)) + fbm(p * 0.4) * 6.0) * 0.5 + 0.5;
		vec3 ag = ash_dry * (0.85 + 0.2 * g2 + 0.12 * (g4 - 0.5) * detail);
		ag = mix(ag, ash_wet, smoothstep(0.25, 0.7, m.g) * 0.8);
		// layered banding on the cliffs
		ag *= mix(1.0, 0.8 + 0.25 * noise(vec2(world_pos.y * 3.0, p.x * 0.05)), smoothstep(0.2, 0.45, slope));
		ground = mix(ground, ag, ash);
		h = mix(h, ripple * 0.012 + g4 * 0.006, ash);
	}

	// --- bedrock: grey slabs with cracks where the trail climbs over rock ---
	float rock = soil.r;
	if (rock > 0.01) {
		vec2 slab = cells(p * 0.9);
		vec3 rc = bedrock * (0.75 + 0.35 * slab.y) * (0.85 + 0.25 * g2);
		float crack = smoothstep(0.035, 0.0, abs(fbm(p * 0.7 + slab.y) - 0.5)) * smoothstep(0.3, 0.6, slab.x);
		rc *= 1.0 - 0.3 * crack;
		ground = mix(ground, rc, rock);
		h = mix(h, (1.0 - crack) * 0.03 + g4 * 0.01, rock);
		soft *= 1.0 - 0.8 * rock;
	}

	// --- river bed: rounded cobbles of every colour -------------------------
	float cob = soil.g;
	if (cob > 0.01) {
		vec2 c1 = cells(p * 2.6);
		vec2 c2 = cells(p * 6.5 + 3.0);
		float big = smoothstep(0.62, 0.2, c1.x);
		float small = smoothstep(0.6, 0.25, c2.x);
		vec3 s1 = mix(vec3(0.3, 0.29, 0.27), vec3(0.4, 0.33, 0.26), c1.y) * (0.75 + 0.4 * hash(vec2(c1.y, 3.0)));
		vec3 s2 = mix(vec3(0.27, 0.26, 0.25), vec3(0.42, 0.4, 0.35), c2.y);
		vec3 sand = vec3(0.32, 0.29, 0.24) * (0.8 + 0.3 * g3);
		vec3 bed = mix(mix(sand, s2, small), s1, big);
		ground = mix(ground, bed, cob);
		h = mix(h, big * 0.06 + small * 0.025, cob);
		soft *= 1.0 - cob;
	}

	// --- worn by tires: grass flattened and yellowed, then rubbed through to
	// packed dirt where the wheels keep running (mud field alpha); bare rock
	// and the gravel road don't change, the forest floor scuffs to dirt too
	float worn = texture(mud_tex, UV).a * (1.0 - rock) * (1.0 - 0.8 * paddy_k);
	if (worn > 0.01) {
		vec3 flat_grass = mix(grass, grass_b * 0.95, 0.5) * 0.9;
		vec3 dirt = mix(clay_dry * 0.78, gravel, 0.35) * (0.82 + 0.25 * g2 + 0.12 * (g4 - 0.5) * detail);
		dirt = mix(dirt, clay_wet * 0.85, smoothstep(0.35, 0.8, m.g));
		ground = mix(ground, flat_grass, smoothstep(0.04, 0.3, worn) * (1.0 - forest) * 0.7);
		ground = mix(ground, dirt, smoothstep(0.25, 0.85, worn + (g3 - 0.5) * 0.15));
		h = mix(h, g4 * 0.008, smoothstep(0.25, 0.85, worn));
	}

	// mud piled up by the tires (negative rut) is clay wherever it landed,
	// grass and gravel road included
	float pile = smoothstep(0.004, 0.04, -m.r);
	soft = max(soft, pile);

	// --- trail clay ------------------------------------------------------------
	vec3 clay = mix(clay_dry, clay_wet, m.g);
	clay = mix(clay, mix(ash_dry * 0.92, ash_wet, m.g), ash);  // churned ash is grey, not red
	clay *= 0.8 + 0.28 * fbm(p * 1.4) + 0.2 * (g4 - 0.5) * detail;
	float rut_k = smoothstep(0.02, 0.18, m.r);
	// churned ruts go dark and wet: red clay, or grey ash in the lahar
	clay = mix(clay, mix(clay_wet * 0.72, ash_wet * 0.8, ash), rut_k * (0.5 + 0.5 * g3));
	float clods = fbm(p * 3.5);
	// dry-season clay: pale, dusty, split into plates along shrinkage cracks
	float dry = (1.0 - smoothstep(0.12, 0.35, m.g)) * (1.0 - ash) * (1.0 - rut_k);
	float crack = smoothstep(0.03, 0.0, abs(fbm(p * 1.9 + 5.0) - 0.5)) + 0.6 * smoothstep(0.02, 0.0, abs(fbm(p * 4.3) - 0.5));
	crack = min(crack, 1.0) * dry * detail;
	clay = mix(clay, clay * 1.12 + 0.03, dry * 0.5);
	clay *= 1.0 - 0.45 * crack;
	vec3 col = mix(ground, clay, soft);
	h = mix(h, clods * 0.05 + g4 * 0.012 - crack * 0.02, soft);
	float rough = mix(rough_ground, mix(0.85, 0.38, pow(m.g, 1.4)), soft);
	float spec = mix(0.3, 0.5, soft * m.g);

	// --- standing water: in deep wet ruts, low spots on wet clay -------------
	// (only where the ground is really wet, with soft edges: a fresh rut in
	// damp clay doesn't fill with water the moment it's dug)
	float pool = m.g * (0.35 + 0.7 * rut_k) - fbm(p * 0.16 + 11.0) * 0.75 + 0.08 * (g3 - 0.5);
	float puddle = smoothstep(0.1, 0.32, pool) * soft * smoothstep(0.55, 0.85, m.g);
	// a dark wet margin round each puddle
	col *= 1.0 - 0.3 * smoothstep(0.04, 0.1, pool) * soft * (1.0 - puddle);
	// muddy water: opaque brown (milky grey on the ash), a dull sheen, not a
	// mirror (a glassy puddle caught the sky and read as silver foil)
	col = mix(col, mix(mix(puddle_col, clay_wet * 0.6, 0.5), ash_wet * 0.6, ash), puddle * 0.8);
	rough = mix(rough, 0.22, puddle);
	spec = mix(spec, 0.25, puddle);
	h = mix(h, 0.0015 * sin(p.x * 9.0 + TIME * 1.3) * sin(p.y * 7.0 - TIME), puddle);
	// under a river, creek or paddy (the water sheet draws the surface):
	// soaked and dark, plus a wet band just above the waterline
	float wetline = (1.0 - smoothstep(water_level, water_level + 0.3, world_pos.y)) * smoothstep(0.3, 0.7, soil.a);
	col *= mix(1.0, 0.62, wetline);
	rough = mix(rough, 0.25, wetline);

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
	vec2 tilt = vec2(rr - rl, ru - rd) / (2.0 * cell);
	tilt *= min(1.0, 1.2 / max(length(tilt), 1e-4));   // a churned wall, not a mirror facing the sky
	vec3 rutted = normalize(wn + vec3(tilt.x, 0.0, tilt.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(rutted, 0.0)).xyz);
	NORMAL = bump(NORMAL, VERTEX, h * mix(0.3, 1.0, detail));
}
