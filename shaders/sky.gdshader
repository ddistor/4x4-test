shader_type sky;
render_mode use_debanding;

// Rainy-season afternoon over Laguna de Bay: hazy blue overhead, pale and
// humid at the horizon, big drifting cumulus, a soft warm sun.

uniform vec3 zenith : source_color = vec3(0.26, 0.45, 0.72);
uniform vec3 horizon : source_color = vec3(0.80, 0.84, 0.84);
uniform vec3 ground : source_color = vec3(0.30, 0.33, 0.27);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.55;
uniform float cloud_speed = 0.003;

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
	for (int i = 0; i < 6; i++) {
		v += a * noise(p);
		p = p * 2.07 + vec2(3.1, 1.7);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col = mix(horizon, zenith, pow(clamp(h, 0.0, 1.0), 0.5));
	float sd = max(dot(d, LIGHT0_DIRECTION), 0.0);
	vec3 sun_col = LIGHT0_COLOR * LIGHT0_ENERGY;
	// humid glow around the sun
	col += sun_col * (pow(sd, 6.0) * 0.18 + pow(sd, 60.0) * 0.4);

	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.12) * 0.55 + vec2(TIME * cloud_speed, TIME * cloud_speed * 0.4);
		float c = fbm(uv * 1.6);
		float cover = smoothstep(1.0 - cloud_cover - 0.05, 1.0 - cloud_cover + 0.3, c);
		// thicker = darker underside; edges facing the sun light up
		float thick = smoothstep(0.45, 0.95, c);
		vec3 shade = mix(vec3(0.78, 0.8, 0.82), vec3(0.42, 0.45, 0.5), thick);
		vec3 lit = mix(shade, vec3(1.08, 1.03, 0.96), pow(sd, 3.0) * (1.0 - thick) * 0.8);
		float fade = smoothstep(0.0, 0.18, h);
		col = mix(col, lit * mix(horizon, vec3(1.0), 0.4), cover * fade);
	} else {
		col = mix(horizon, ground, smoothstep(0.0, -0.25, h));
	}
	// the sun disc itself, only where clouds don't cover it
	if (!AT_CUBEMAP_PASS) {
		col += sun_col * smoothstep(0.9997, 0.99985, sd) * 6.0;
	}
	COLOR = col;
}
