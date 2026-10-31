shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;

// A rig's glass: tinted, glossy, see-through; in the rain, beads of water that
// bend what's behind them, gathering while it rains and running down the
// steep glass, and on the windscreen two wipers sweeping an arc clear that
// fills again between passes. Positions are rig space (the glass mesh sits at
// the rig's origin); forward is -Z.

uniform vec4 tint : source_color = vec4(0.45, 0.52, 0.56, 0.3);
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
// the windscreen, for the wipers: its lower edge (y), half width, height
uniform float screen_bottom = 1.0;
uniform float screen_half = 0.6;
uniform float screen_height = 0.5;
uniform float wipers = 0.0;        // 0 off, else sweeps a second (about 0.8 slow, 1.5 fast)
uniform float wiper_phase = 0.0;   // the sweep's own clock (RigWiper), seconds of sweeping

global uniform float rain_now;
global uniform float rain_soak;

varying vec3 lp;
varying vec3 ln;

float hash(vec2 p) {
	uvec2 q = floatBitsToUint(p);
	uint h = q.x * 1597334677u ^ q.y * 3812015801u;
	h = (h ^ (h >> 16u)) * 2246822519u;
	h = (h ^ (h >> 13u)) * 3266489917u;
	h ^= h >> 16u;
	return float(h) * (1.0 / 4294967295.0);
}

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

// Beads on the glass at `q` (metres across it): `cover` of the cells hold one
// (each comes and goes on its own clock, evaporating and landing again);
// returns the bead's strength, `n` its slope (for the bending).
float beads(vec2 q, float cover, float t, out vec2 n) {
	n = vec2(0.0);
	float best = 0.0;
	for (int k = 0; k < 2; k++) {
		vec2 g = q * (k == 0 ? 34.0 : 61.0) + float(k) * 3.7;
		vec2 c = floor(g);
		vec2 f = fract(g) - 0.5;
		float h = hash(c + float(k) * 11.0);
		float life = fract(t * (0.05 + 0.08 * hash(c + 2.0)) + h * 9.0);
		if (h > cover || life > 0.9) continue;
		vec2 o = (vec2(hash(c + 1.3), hash(c + 2.7)) - 0.5) * 0.5;
		float r = (0.16 + 0.22 * hash(c + 5.1)) * smoothstep(0.0, 0.15, life);
		vec2 d = f - o;
		d.y *= 1.25;   // a little pear-shaped, heavier at the bottom
		float m = smoothstep(r, r * 0.55, length(d));
		if (m > best) {
			best = m;
			n = d / max(r, 1e-3);
		}
	}
	return best;
}

// Runnels: drops that got big enough to run, sliding down the glass and
// leaving a thin wet trail; `steep` is how upright the glass is.
float runnels(vec2 q, float cover, float t, float steep, out vec2 n) {
	n = vec2(0.0);
	float col = floor(q.x * 22.0);
	float h = hash(vec2(col, 7.0));
	if (h > cover * 0.5 || steep < 0.3) return 0.0;
	float speed = (0.06 + 0.12 * hash(vec2(col, 9.0))) * steep;
	float head = 1.0 - fract(t * speed + h * 13.0);   // falls from the top
	float y = fract(q.y * 0.9);
	float fx = fract(q.x * 22.0) - 0.5;
	float drop = smoothstep(0.03, 0.0, length(vec2(fx * 0.045, y - head)));
	float trail = smoothstep(0.12, 0.0, abs(fx)) * step(head, y) * smoothstep(head + 0.25, head, y) * 0.5;
	n = vec2(fx * 4.0, 0.6) * drop;
	return max(drop, trail);
}

void fragment() {
	vec3 col = tint.rgb;
	float alpha = tint.a;
	float rough = 0.05;
	// how much water the glass is carrying: it beads up while it rains and
	// lingers a while after
	float cover = clamp(rain_now * 0.45 + rain_soak * 0.08, 0.0, 0.45);
	if (cover > 0.01) {
		vec3 an = abs(ln);
		// coordinates across this pane: the windscreen and back by x/y, the sides by z/y
		vec2 q = an.z > an.x ? lp.xy : lp.zy;
		q.y = -q.y;   // (down the glass is +y in q)
		float steep = 1.0 - an.y;
		// the windscreen: facing fore-and-aft, in the front half of the rig
		float front = step(an.x, an.z) * step(an.y, an.z) * step(lp.z, 0.0);
		float fill = 1.0;
		float blade = 0.0;
		if (front > 0.5 && wipers > 0.0) {
			// two blades parked lying left to right along the lower edge, sweeping
			// up through 105 deg and back together; a bead comes back the longer
			// since the blade last went over it
			float period = 1.0 / wipers;
			float s = fract(wiper_phase / period);
			float now_a = radians(105.0) * (0.5 - 0.5 * cos(TAU * s));
			float arm = min(screen_height * 0.95, screen_half * 0.95);
			for (int w = 0; w < 2; w++) {
				vec2 pivot = vec2(w == 0 ? -screen_half * 0.62 : screen_half * 0.12, screen_bottom + 0.03);
				vec2 d = lp.xy - pivot;
				float r = length(d);
				float a = atan(d.y, d.x);   // 0 along +x, up is positive
				if (r < arm && a >= -0.05 && a <= radians(108.0)) {
					float k = clamp(a / radians(105.0), 0.0, 1.0);
					float s1 = acos(1.0 - 2.0 * k) / TAU;
					float since = min(fract(s - s1), fract(s - (1.0 - s1))) * period;
					fill = min(fill, clamp(since / 2.5, 0.0, 1.0));
					// the blade and its arm
					float off = abs(a - now_a) * r;
					blade = max(blade, smoothstep(0.012, 0.006, off) * step(arm * 0.15, r));
				}
			}
		}
		vec2 n1;
		float b = beads(q, cover * fill, TIME, n1);
		vec2 n2;
		float run = runnels(q, cover * fill, TIME, steep, n2);
		vec2 bend = (n1 * b + n2 * run) * 0.02;
		float wet = max(b, run);
		// a bead is a little lens: what's behind it, shifted and blurred
		vec3 behind = textureLod(screen_tex, SCREEN_UV - bend, 1.0).rgb;
		// mostly clear: the view through it a little bent and brighter, and a
		// bright rim where the bead curves away
		float rim = smoothstep(0.35, 0.9, length(n1)) * b;
		col = mix(col, behind * 1.12 + rim * 0.25, wet);
		alpha = mix(alpha, 1.0, wet * 0.55);
		rough = mix(rough, 0.02, wet);
		// a smear of film over the glass while it's wet
		alpha = max(alpha, tint.a + 0.05 * cover * fill);
		col = mix(col, vec3(0.02), blade);
		alpha = max(alpha, blade);
	}
	ALBEDO = col;
	ALPHA = alpha;
	ROUGHNESS = rough;
	METALLIC = 0.0;
	SPECULAR = 0.9;
}
