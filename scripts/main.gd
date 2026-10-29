extends Node3D
## M1 mud playground: builds the Morong trail, drops the rig at the paddies,
## and wires up camera + HUD. Everything is procedural so the whole scene
## lives in text.


func _ready() -> void:
	_build_environment()
	var terrain := Terrain.new()
	terrain.name = "Terrain"
	add_child(terrain)

	var rig := Rig.new()
	rig.name = "Rig"
	rig.terrain_path = terrain.get_path()
	add_child(rig)
	rig.reset_to_spawn()

	var cam := load("res://scripts/camera/chase_camera.gd").new() as Camera3D
	cam.name = "ChaseCamera"
	cam.target_path = rig.get_path()
	add_child(cam)
	cam.current = true

	var hud := load("res://scripts/ui/hud.gd").new() as CanvasLayer
	hud.name = "HUD"
	hud.rig_path = rig.get_path()
	add_child(hud)


func _build_environment() -> void:
	# Late-afternoon rainy-season light: soft, warm, hazy.
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 1.8
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	sun.rotation_degrees = Vector3(-42, 35, 0)
	add_child(sun)

	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.45, 0.6, 0.78)
	sky_mat.sky_horizon_color = Color(0.72, 0.76, 0.7)
	sky_mat.ground_bottom_color = Color(0.3, 0.32, 0.25)
	sky_mat.ground_horizon_color = Color(0.7, 0.72, 0.66)
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.fog_enabled = true
	env.fog_light_color = Color(0.76, 0.8, 0.74)
	env.fog_density = 0.0012
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)
