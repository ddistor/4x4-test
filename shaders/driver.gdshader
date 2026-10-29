shader_type spatial;
render_mode cull_back;

// The driver: skin, shirt, jorts, helmet in their vertex colours, catching
// clay as the rig gets muddy. Flecks first, then splatters that join up; the
// same Morong clay as the body, dark and wet when fresh, pale when it dries.

#include "res://shaders/mud_common.gdshaderinc"

uniform float mud = 0.0;       // 0 clean .. 1 plastered (from the rig)
uniform float dryness = 0.4;
uniform float roughness = 0.75;

varying vec3 lp;
varying vec3 base;

void vertex() {
	lp = VERTEX;
	base = pow(clamp(COLOR.rgb, 0.0, 1.0), vec3(2.2));
}

void fragment() {
	float n = mud_fbm(lp * 9.0);
	float fleck = mud_noise(lp * 70.0);
	float reach = mud * 0.18;   // splattered, never dipped: ~40% at worst
	float splat = smoothstep(0.7 - reach, 0.73 - reach, n * 0.8 + fleck * 0.25);
	float specks = step(1.0 - mud * 0.18, fleck) * step(0.02, mud);
	float m = max(splat, specks);
	vec3 ma;
	float mr;
	float ms;
	mud_material(lp * 2.0, m * 0.7, dryness, ma, mr, ms);
	ALBEDO = mix(base, ma, m);
	ROUGHNESS = mix(roughness, mr, m);
	SPECULAR = mix(0.4, ms, m);
	if (m > 0.01) {
		NORMAL = mud_bump(NORMAL, lp, m, mat3(VIEW_MATRIX * MODEL_MATRIX));
	}
}
