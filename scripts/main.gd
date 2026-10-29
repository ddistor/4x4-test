extends Node3D
## M1 mud playground: builds the Morong trail, drops the rig at the paddies,
## and wires up camera + HUD. Everything is procedural so the whole scene
## lives in text.


func _ready() -> void:
	_build_environment()
	var terrain := Terrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	var backdrop := Backdrop.new()
	backdrop.name = "Backdrop"
	add_child(backdrop)
	backdrop.build(terrain)

	var rig := Rig.new()
	rig.name = "Rig"
	rig.terrain_path = terrain.get_path()
	add_child(rig)
	rig.reset_to_spawn()
	var audio := RigAudio.new()
	audio.name = "Audio"
	rig.add_child(audio)
	audio.setup(rig)

	var cam := load("res://scripts/camera/chase_camera.gd").new() as Camera3D
	cam.name = "ChaseCamera"
	cam.target_path = rig.get_path()
	add_child(cam)
	cam.current = true

	var hud := load("res://scripts/ui/hud.gd").new() as CanvasLayer
	hud.name = "HUD"
	hud.rig_path = rig.get_path()
	add_child(hud)

	if "--snap" in OS.get_cmdline_user_args():
		var snap: Node = load("res://scripts/snapshot.gd").new()
		snap.name = "Snapshot"
		add_child(snap)


func _build_environment() -> void:
	# Late-afternoon rainy-season light: soft, warm, hazy.
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 140.0
	sun.light_angular_distance = 0.6  # soft-edged shadows, the sun is hazy
	sun.rotation_degrees = Vector3(-38, 35, 0)
	add_child(sun)

	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_energy = 0.8
	# distance haze that takes its colour from the sky, plus a thin humid
	# volumetric layer so light shafts show through the canopy
	env.fog_enabled = true
	env.fog_light_color = Color(0.74, 0.79, 0.8)
	env.fog_density = 0.0006
	env.fog_aerial_perspective = 0.7
	env.fog_sky_affect = 0.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0015
	env.volumetric_fog_albedo = Color(0.9, 0.92, 0.9)
	env.volumetric_fog_anisotropy = 0.6
	env.volumetric_fog_length = 90.0
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.1
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.ssil_enabled = true
	env.ssr_enabled = true
	env.ssr_max_steps = 64
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.03
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)
