shader_type spatial;
render_mode cull_back;

// The driver: skin, shirt, jorts, helmet in their vertex colours, catching
// clay as the rig gets muddy. Flecks first, then splatters that join up; the
// same Morong clay as the body, dark and wet when fresh, pale when it dries.
// The tee can carry a print (the club logo), projected flat onto the chest
// and muddied like the rest of the shirt.

#include "res://shaders/mud_common.gdshaderinc"

uniform float mud = 0.0;       // 0 clean .. 1 plastered (from the rig)
uniform float dryness = 0.4;
uniform vec3 skin_col = vec3(0.5, 0.355, 0.28);   // sRGB, as authored in driver.gd
uniform vec3 shirt_col = vec3(0.52, 0.13, 0.12);
uniform bool has_print = false;
uniform sampler2D print_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform mat4 print_inv;        // mesh space -> print space: xy across it (-0.5..0.5), +z out of the shirt

varying vec3 lp;
varying vec3 ln;
varying vec3 base;
varying float skin;    // 1 on skin, 0 on clothes
varying float tee;     // 1 on the shirt body, where the print may go

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
	vec3 c = clamp(COLOR.rgb, 0.0, 1.0);
	base = pow(c, vec3(2.2));
	// skin and its darker shade both read as skin
	skin = 1.0 - smoothstep(0.03, 0.08, min(distance(c, skin_col), distance(c, skin_col * 0.81)));
	tee = 1.0 - step(0.02, distance(c, shirt_col));
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
	vec3 col = base;
	// skin: faint blotches and tone variation; cloth: a fine weave and wear
	float blot = mud_fbm(lp * 22.0);
	float weave = mud_noise(lp * 900.0) * 0.5 + mud_noise(lp * 300.0) * 0.5;
	col *= mix(0.94 + weave * 0.1, 0.93 + blot * 0.12, skin);
	col = mix(col, col * vec3(1.04, 0.97, 0.95), skin * smoothstep(0.55, 0.8, blot));
	float rough = mix(0.93, 0.52, skin);
	float spec = mix(0.25, 0.38, skin);
	if (has_print && tee > 0.5) {
		vec3 d = (print_inv * vec4(lp, 1.0)).xyz;
		float facing = (print_inv * vec4(ln, 0.0)).z;
		if (max(abs(d.x), abs(d.y)) < 0.5 && facing > 0.0) {
			vec4 t = texture(print_tex, vec2(d.x + 0.5, 0.5 - d.y));
			col = mix(col, t.rgb * 0.92, t.a);   // ink a touch faded, like a worn print
		}
	}
	ALBEDO = mix(col, ma, m);
	ROUGHNESS = mix(rough, mr, m);
	SPECULAR = mix(spec, ms, m);
	// light through the edges of skin (ears, fingers, the rim of an arm)
	BACKLIGHT = vec3(0.18, 0.07, 0.04) * skin * (1.0 - m);
	if (m > 0.01) {
		NORMAL = mud_bump(NORMAL, lp, m, mat3(VIEW_MATRIX * MODEL_MATRIX));
	}
}
