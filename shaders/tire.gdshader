shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// Mud-terrain tire on a black beadlock wheel. Vertex colour masks:
// r = tread lug, g = wheel (steel), b = holes in the wheel face.
// Mud packs the grooves first, then the lug faces, then the wheel.

#include "res://shaders/mud_common.gdshaderinc"

uniform float tire_mud : hint_range(0.0, 1.0) = 0.0;
uniform float dryness : hint_range(0.0, 1.0) = 0.3;
uniform vec3 wheel_paint : source_color = vec3(0.03, 0.03, 0.032);   // black, or silver steelies
// the spare: it never rolls in anything, so nothing packs its tread; it only
// catches spatter off the rear tires, most on its lower half (`spatter_down`:
// which way is down, in the tire's own space). 0 for a tire on the ground.
uniform float spatter : hint_range(0.0, 1.0) = 0.0;
uniform vec3 spatter_down = vec3(0.0, -1.0, 0.0);

varying vec3 lp;
varying vec3 mask;

void vertex() {
	lp = VERTEX;
	mask = COLOR.rgb;
}

void fragment() {
	float lug = mask.r;
	float wheel = mask.g;
	vec3 base = mix(vec3(0.028, 0.028, 0.03), wheel_paint, wheel);
	base *= 1.0 - 0.85 * mask.b;
	float rough = mix(0.88, 0.4, wheel);

	float n = mud_fbm(lp * 16.0);
	float exposed = lug * 0.55 + wheel * 0.8;
	float edge = tire_mud * 1.45 - exposed - (n - 0.5) * 0.4 - 0.25;
	float mud = smoothstep(0.0, 0.08, edge);
	float thick = clamp(edge * 2.0 + 0.2, 0.0, 1.0);
	if (spatter > 0.0) {
		// flecks and drips, lugs and grooves alike, thickest low down
		float low = smoothstep(-0.2, 0.35, dot(lp, normalize(spatter_down)));
		float cover = spatter * (0.35 + 0.65 * low);
		float fleck = mud_fbm(lp * 11.0 + 7.0);
		float s = smoothstep(fleck - 0.04, fleck + 0.04, 0.12 + 0.62 * cover);
		mud = max(mud, s);
		thick = max(thick, s * (0.1 + 0.25 * cover));
	}

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
