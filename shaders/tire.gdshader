shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// Mud-terrain tire on a black beadlock wheel. Vertex colour masks:
// r = tread lug, g = wheel (steel), b = holes in the wheel face.
// Mud packs the grooves first, then the lug faces, then the wheel.

#include "res://shaders/mud_common.gdshaderinc"

uniform float tire_mud : hint_range(0.0, 1.0) = 0.0;
uniform float dryness : hint_range(0.0, 1.0) = 0.3;

varying vec3 lp;
varying vec3 mask;

void vertex() {
	lp = VERTEX;
	mask = COLOR.rgb;
}

void fragment() {
	float lug = mask.r;
	float wheel = mask.g;
	vec3 base = mix(vec3(0.028, 0.028, 0.03), vec3(0.03, 0.03, 0.032), wheel);
	base *= 1.0 - 0.85 * mask.b;
	float rough = mix(0.88, 0.4, wheel);

	float n = mud_fbm(lp * 16.0);
	float exposed = lug * 0.55 + wheel * 0.8;
	float edge = tire_mud * 1.45 - exposed - (n - 0.5) * 0.4 - 0.25;
	float mud = smoothstep(0.0, 0.08, edge);
	float thick = clamp(edge * 2.0 + 0.2, 0.0, 1.0);

	vec3 mud_col;
	float mud_rough;
	float mud_spec;
	mud_material(lp, thick, dryness, mud_col, mud_rough, mud_spec);

	ALBEDO = mix(base, mud_col, mud);
	ROUGHNESS = mix(rough, mud_rough, mud);
	METALLIC = mix(wheel * 0.5, 0.0, mud);
	SPECULAR = mix(mix(0.3, 0.5, wheel), mud_spec, mud);
	mat3 to_view = mat3(VIEW_MATRIX) * mat3(MODEL_MATRIX);
	NORMAL = mud_bump(NORMAL, lp, mud * (0.5 + thick), to_view);
}
