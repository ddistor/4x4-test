class_name GraphicsSettings
extends RefCounted
## Graphics settings: kept between launches in user://graphics.cfg, owned by
## Game (`Game.gfx`), changed in the settings screen (start menu and Esc).
## A preset sets the quality ones together; touching one by hand makes it
## Custom. Window, V-Sync and the frame cap stay out of the presets.
## Everything applies live: the window and the 3D viewport here, the sun,
## sky effects and vegetation of the stage that's running via `attach`.

const FILE := "user://graphics.cfg"

const PRESETS := ["Low", "Medium", "High", "Ultra", "Custom"]
const CUSTOM := 4
const WINDOWS := ["Windowed", "Fullscreen"]
const FPS := [["Unlimited", 0], ["30", 30], ["60", 60], ["120", 120], ["144", 144]]
const SCALES := [["50%", 0.5], ["67%", 0.67], ["77%", 0.77], ["85%", 0.85], ["100%", 1.0]]
const AA := ["Off", "FXAA", "MSAA 2x", "MSAA 4x", "TAA"]
## [name, atlas size, splits, max distance m, soft filter quality]
const SHADOWS := [["Off", 0, 2, 0.0, 0], ["Low", 2048, 2, 70.0, 1], ["Medium", 4096, 4, 100.0, 2],
	["High", 8192, 4, 140.0, 3], ["Ultra", 8192, 4, 200.0, 4]]
const GRASS := [["Near", 40.0], ["Medium", 70.0], ["Far", 110.0]]
const TREES := [["Near", 180.0], ["Medium", 300.0], ["Far", 450.0]]
const ON_OFF := ["Off", "On"]

## The quality settings each preset picks (not window, V-Sync or frame cap).
const PRESET_VALUES := [
	{"scale": 2, "aa": 1, "shadows": 1, "ao": 0, "ssr": 0, "vfog": 0, "glow": 1, "grass": 0, "trees": 0},
	{"scale": 4, "aa": 1, "shadows": 2, "ao": 1, "ssr": 0, "vfog": 0, "glow": 1, "grass": 1, "trees": 1},
	{"scale": 4, "aa": 2, "shadows": 3, "ao": 1, "ssr": 1, "vfog": 1, "glow": 1, "grass": 1, "trees": 1},
	{"scale": 4, "aa": 3, "shadows": 4, "ao": 1, "ssr": 1, "vfog": 1, "glow": 1, "grass": 2, "trees": 2},
]

var preset := 2
var window := 0
var vsync := 1
var fps := 0
var scale := 4
var aa := 2
var shadows := 3
var ao := 1
var ssr := 1
var vfog := 1
var glow := 1
var grass := 1
var trees := 1

var _env: Environment
var _sun: DirectionalLight3D
var _stage: Node


## Every setting the screen shows, in order: [key, label, options].
func rows() -> Array:
	return [
		["preset", "Quality preset", PRESETS.slice(0, CUSTOM) if preset != CUSTOM else PRESETS],
		["window", "Window", WINDOWS],
		["vsync", "V-Sync", ON_OFF],
		["fps", "Frame-rate cap", FPS.map(func(e: Array) -> String: return e[0])],
		["scale", "Render scale", SCALES.map(func(e: Array) -> String: return e[0])],
		["aa", "Anti-aliasing", AA],
		["shadows", "Shadows", SHADOWS.map(func(e: Array) -> String: return e[0])],
		["ao", "Ambient occlusion", ON_OFF],
		["ssr", "Reflections", ON_OFF],
		["vfog", "Volumetric fog", ON_OFF],
		["glow", "Glow", ON_OFF],
		["grass", "Grass distance", GRASS.map(func(e: Array) -> String: return "%s (%d m)" % [e[0], e[1]])],
		["trees", "Tree distance", TREES.map(func(e: Array) -> String: return "%s (%d m)" % [e[0], e[1]])],
	]


## Step one setting to its next option (wrapping), keep the preset honest,
## save and apply.
func cycle(key: String, step := 1) -> void:
	if key == "preset":
		var n := CUSTOM   # cycling skips Custom: it's where hand changes land
		preset = (preset + step + n) % n if preset != CUSTOM else (0 if step > 0 else n - 1)
		for k: String in PRESET_VALUES[preset]:
			set(k, PRESET_VALUES[preset][k])
	else:
		var count := 0
		for r: Array in rows():
			if r[0] == key:
				count = (r[2] as Array).size()
		set(key, (int(get(key)) + step + count) % count)
		if PRESET_VALUES[0].has(key):
			preset = _matching_preset()
	save()
	apply()


func _matching_preset() -> int:
	for p in range(PRESET_VALUES.size()):
		var same := true
		for k: String in PRESET_VALUES[p]:
			if int(get(k)) != int(PRESET_VALUES[p][k]):
				same = false
		if same:
			return p
	return CUSTOM


func load_file() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(FILE) != OK:
		return
	for r: Array in rows():
		var key: String = r[0]
		set(key, clampi(int(cfg.get_value("graphics", key, get(key))), 0, PRESETS.size() - 1 if key == "preset" else (r[2] as Array).size() - 1))
	preset = _matching_preset()


func save() -> void:
	var cfg := ConfigFile.new()
	for r: Array in rows():
		cfg.set_value("graphics", r[0], get(r[0]))
	cfg.save(FILE)


## The stage that's running hands over its environment and sun (main.gd),
## so changes made from the pause menu show straight away.
func attach(stage: Node, env: Environment, sun: DirectionalLight3D) -> void:
	_stage = stage
	_env = env
	_sun = sun
	apply()


func grass_range() -> float:
	return GRASS[grass][1]


func tree_range() -> float:
	return TREES[trees][1]


func apply() -> void:
	_apply_window()
	_apply_viewport(Game.get_tree().root)
	_apply_shadows()
	if _stage != null and is_instance_valid(_stage):
		_apply_stage()


func _apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if window == 1 else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want and not (want == DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED):
		DisplayServer.window_set_mode(want)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync == 1 else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = FPS[fps][1]


func _apply_viewport(vp: Viewport) -> void:
	var s: float = SCALES[scale][1]
	vp.scaling_3d_scale = s
	# FSR needs the Vulkan renderers; the compatibility one only stretches
	var fsr_ok := RenderingServer.get_current_rendering_method() != "gl_compatibility"
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if s < 1.0 and fsr_ok else Viewport.SCALING_3D_MODE_BILINEAR
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_DISABLED][aa]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if aa == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = aa == 4


func _apply_shadows() -> void:
	var sh: Array = SHADOWS[shadows]
	if int(sh[1]) > 0:
		RenderingServer.directional_shadow_atlas_set_size(int(sh[1]), true)
		RenderingServer.directional_soft_shadow_filter_set_quality(int(sh[4]) as RenderingServer.ShadowQuality)


func _apply_stage() -> void:
	var sh: Array = SHADOWS[shadows]
	if _sun != null and is_instance_valid(_sun):
		_sun.shadow_enabled = int(sh[1]) > 0
		_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if int(sh[2]) == 4 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		_sun.directional_shadow_max_distance = sh[3]
	if _env != null:
		_env.ssao_enabled = ao == 1
		_env.ssil_enabled = ao == 1
		_env.ssr_enabled = ssr == 1
		_env.volumetric_fog_enabled = vfog == 1
		_env.glow_enabled = glow == 1
	# vegetation drawn near the camera only: grass and the trees (vegetation.gd)
	for n in _stage.get_tree().get_nodes_in_group("veg_grass"):
		(n as GeometryInstance3D).visibility_range_end = grass_range()
	for n in _stage.get_tree().get_nodes_in_group("veg_trees"):
		(n as GeometryInstance3D).visibility_range_end = tree_range()
