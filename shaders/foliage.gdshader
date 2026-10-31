shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

// Leaves, grass, rice, fronds. Two-sided, light shines through (backlight),
// sways in the wind from the base up, and every plant is a slightly different
// green. Leaf cards use an alpha-cut texture; geometry-only plants run
// without one and take their colour from the vertex colour.
// Vertex colour alpha = how much that vertex flutters on its own.

uniform sampler2D leaf_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool use_tex = false;
uniform vec3 tint : source_color = vec3(1.0);
uniform float hue_jitter = 0.18;      // per-plant colour spread
uniform float sway = 0.15;            // metres of drift at sway_height
uniform float sway_height = 10.0;
uniform float flutter = 0.03;
uniform float translucency = 0.45;
uniform float roughness = 0.7;
// ground plants under the tires: the mud field (alpha: how worn) flattens
// them, then wears them away to nothing where the wheels keep running
uniform bool use_wear = false;
uniform sampler2D wear_tex : filter_linear, repeat_disable;
uniform vec2 wear_world = vec2(160.0, 160.0);

varying vec3 plant_tint;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float worn = 0.0;
	if (use_wear) {
		worn = textureLod(wear_tex, origin.xz / wear_world, 0.0).a;
		// laid flat first (pressed down and outward), then gone
		VERTEX.y *= 1.0 - 0.8 * smoothstep(0.03, 0.4, worn);
		VERTEX.xz *= 1.0 + 0.35 * smoothstep(0.03, 0.4, worn);
		VERTEX *= 1.0 - smoothstep(0.45, 0.85, worn);
	}
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float ph = dot(origin.xz, vec2(0.13, 0.17));
	float h = clamp(VERTEX.y / sway_height, 0.0, 1.5);
	float t = TIME;
	// gusts roll across the map, so neighbouring plants move together
	float gust = 0.6 + 0.4 * sin(t * 0.35 + origin.x * 0.02 + origin.z * 0.015);
	vec2 wind = vec2(sin(t * 0.9 + ph) + 0.35 * sin(t * 2.3 + ph * 1.7), 0.5 * cos(t * 0.7 + ph * 1.3));
	VERTEX.xz += wind * sway * gust * h * h;
	VERTEX += NORMAL * sin(t * 7.0 + wp.x * 3.1 + wp.z * 2.3) * flutter * COLOR.a * gust;

	float r = hash(origin.xz);
	float r2 = hash(origin.zx + 3.7);
	// spread between yellower and bluer greens, and a little light/dark
	plant_tint = mix(vec3(1.0 + hue_jitter, 1.0 + hue_jitter * 0.4, 0.8), vec3(0.85, 1.0, 1.0 + hue_jitter * 0.5), r);
	plant_tint *= 0.85 + 0.3 * r2;
	// crushed grass goes yellow-brown
	plant_tint = mix(plant_tint, vec3(0.95, 0.8, 0.5), smoothstep(0.05, 0.4, worn) * 0.6);
}

void fragment() {
	vec4 tx = use_tex ? texture(leaf_tex, UV) : vec4(1.0);
	// vertex colours are authored as sRGB, like the source_color uniforms;
	// clamped because MSAA can sample a hair outside thin blade tips, and
	// pow() of a negative is NaN (which glow then smears into white blobs)
	vec3 col = tx.rgb * pow(clamp(COLOR.rgb, 0.0, 1.0), vec3(2.2)) * tint * plant_tint;
	ALBEDO = col;
	ALPHA = tx.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = roughness;
	SPECULAR = 0.35;
	BACKLIGHT = col * translucency;
}
