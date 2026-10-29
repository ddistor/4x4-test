shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

// Muddy still water: paddies and the creek. Opaque-ish brown with a slow
// ripple so it reads as water, not a painted plane.
uniform vec4 tint : source_color = vec4(0.45, 0.32, 0.18, 0.85);
uniform float ripple_speed = 0.6;

void fragment() {
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	float t = TIME * ripple_speed;
	float w = sin(p.x * 2.1 + t) * 0.5 + sin(p.y * 1.7 - t * 1.3) * 0.5;
	w += sin((p.x + p.y) * 0.9 + t * 0.7) * 0.5;
	NORMAL_MAP = normalize(vec3(w * 0.08, 1.0, w * 0.06)) * 0.5 + 0.5;
	ALBEDO = tint.rgb * (0.9 + 0.1 * w);
	ALPHA = tint.a;
	ROUGHNESS = 0.35;
	SPECULAR = 0.4;
	METALLIC = 0.0;
}
