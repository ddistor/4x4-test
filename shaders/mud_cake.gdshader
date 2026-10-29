shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// Rig bodywork that cakes with red clay where the tires throw it.
// Each corner's tire builds up its own patch around and behind the wheel:
// solid round the arch, thinning to splatter further out, dripping down.
// Deep bogging adds a belly line from the bottom up.

#include "res://shaders/mud_common.gdshaderinc"

uniform vec4 paint : source_color = vec4(0.02, 0.02, 0.022, 1.0);
uniform float paint_roughness = 0.2;
uniform float paint_metallic = 0.0;
uniform float clearcoat = 1.0;
// per tire: xyz = wheel centre in rig space, w = mud it has thrown (0..2)
uniform vec4 corner_fl;
uniform vec4 corner_fr;
uniform vec4 corner_rl;
uniform vec4 corner_rr;

vec4 corner(int i) {
	return i == 0 ? corner_fl : i == 1 ? corner_fr : i == 2 ? corner_rl : corner_rr;
}
uniform float cake : hint_range(0.0, 1.0) = 0.0;   // belly line from sinking
uniform float dryness : hint_range(0.0, 1.0) = 0.3;
uniform float body_bottom = -0.1;
uniform float body_top = 1.3;
// mesh space -> rig space, for parts that move on their own (axles)
uniform mat4 part_xform = mat4(1.0);

varying vec3 rig_pos;

void vertex() {
	rig_pos = (part_xform * vec4(VERTEX, 1.0)).xyz;
}

float coverage(vec3 p) {
	float total = 0.0;
	for (int i = 0; i < 4; i++) {
		vec3 r = p - corner(i).xyz;
		float amt = corner(i).w;
		// thrown back and up: long reach behind the tire, short in front, less on the far side
		float rz = r.z > 0.0 ? r.z / 2.2 : r.z / 0.9;
		float ry = r.y > 0.0 ? r.y / 1.2 : r.y / 0.7;
		float d = length(vec2(rz, ry));
		float side = mix(0.3, 1.0, exp(-r.x * r.x / 0.35));
		total += amt * side * max(0.0, 1.1 - d);
	}
	return total;
}

float speckle_reach(vec3 p) {
	float total = 0.0;
	for (int i = 0; i < 4; i++) {
		vec3 r = p - corner(i).xyz;
		float rz = r.z > 0.0 ? r.z / 3.6 : r.z / 1.4;
		float ry = r.y > 0.0 ? r.y / 2.3 : r.y / 0.9;
		float d = length(vec2(rz, ry));
		float side = mix(0.25, 1.0, exp(-r.x * r.x / 0.5));
		total += corner(i).w * side * max(0.0, 1.0 - d);
	}
	return total;
}

void fragment() {
	vec3 p = rig_pos;
	float n = mud_fbm(p * 7.0);

	// mud runs down: look a little way up for mud that has dripped from there
	float streak = mud_noise(vec3(p.x * 22.0, 0.0, p.z * 22.0));
	float drip = (0.04 + 0.22 * streak * streak) * (1.0 - 0.6 * dryness);
	float cov = max(coverage(p), coverage(p + vec3(0.0, drip, 0.0)) * 0.92);

	float edge = cov - (0.38 + (n - 0.5) * 0.35);
	float mud = smoothstep(-0.02, 0.05, edge);
	float thick = clamp(edge * 2.5 + 0.25, 0.0, 1.0);

	// belly line from wallowing in it
	float h = clamp((p.y - body_bottom) / (body_top - body_bottom), 0.0, 1.0);
	float belly = cake * 1.1 - h + (n - 0.5) * 0.3;
	mud = max(mud, smoothstep(-0.03, 0.06, belly));
	thick = max(thick, clamp(belly * 3.0 + 0.3, 0.0, 1.0) * step(0.0, belly));

	// flung droplets further out
	float spk = speckle_reach(p);
	float dots = mud_noise(p * 46.0) * 0.7 + mud_noise(p * 97.0) * 0.3;
	float speck = step(1.0 - 0.22 * min(spk, 1.6), dots) * step(0.02, spk);
	mud = max(mud, speck);

	vec3 mud_col;
	float mud_rough;
	float mud_spec;
	mud_material(p, max(thick, speck * 0.5), dryness, mud_col, mud_rough, mud_spec);
	// a wet halo where a fresh patch thins out
	float rim = smoothstep(-0.02, 0.02, edge) - smoothstep(0.02, 0.1, edge);
	mud_col *= 1.0 - 0.3 * rim * (1.0 - dryness);

	ALBEDO = mix(paint.rgb, mud_col, mud);
	ROUGHNESS = mix(paint_roughness, mud_rough, mud);
	METALLIC = mix(paint_metallic, 0.0, mud);
	SPECULAR = mix(0.35, mud_spec, mud);
	CLEARCOAT = clearcoat * 0.6 * (1.0 - mud);
	CLEARCOAT_ROUGHNESS = 0.08;
	mat3 to_view = mat3(VIEW_MATRIX) * mat3(MODEL_MATRIX);
	NORMAL = mud_bump(NORMAL, p, mud * (0.4 + thick), to_view);
}
