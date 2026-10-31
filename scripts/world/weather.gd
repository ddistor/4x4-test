class_name Weather
extends Node3D
## Rain. How hard it's raining now (`intensity`, 0..1) and how soaked the
## surfaces are (`soak`, 0..1: it takes a couple of minutes of heavy rain to
## soak everything, a good while to dry after). The season (StagePlan.rain)
## is how wet the ground already is; this is the weather on the day:
##   dry season          no rain
##   between the rains   now and then a light shower
##   rainy season        showers coming and going
##   downpour            raining hard all the way (Game.weather 2)
## `-- --rain X` fixes it at X (tests, pictures).
##
## Everything that cares reads it: the global shader values `rain_now` and
## `rain_soak` (ground goes dark and slick and its hollows fill, rings on the
## water and in the puddles, wet stone, leaves, bark and paint), the terrain
## (`ground_sample` wetness, so grip and sinkage follow; the rivers rising in
## a long heavy rain, deeper and faster: `flood`), the rig (mud stays
## wet, a thin film rinses), the sky and the light, the rain itself (streaks
## round the camera that stop on roofs and under the canopy, splashes where
## they land) and its sound.

const SHOWER_PERIOD := 240.0   # s, roughly, between one shower and the next

var intensity := 0.0
var soak := 0.0
var flood := 0.0              # 0..1: how far up the rivers are (Terrain.set_flood)
var mode := 0                  # 0 dry, 1 now and then, 2 showers, 3 downpour, 4 fixed
var _fixed := -1.0
var _t := 0.0
var _noise := FastNoiseLite.new()
var _terrain: Terrain
var _env: Environment
var _sun: DirectionalLight3D
var _sky: ShaderMaterial
var _base := {}
var _drops: GPUParticles3D
var _splashes: GPUParticles3D
var _shield: GPUParticlesCollisionHeightField3D
var _sound: AudioStreamPlayer
var _thunder: AudioStreamPlayer
var _thunder_streams: Array[AudioStream] = []
var _next_thunder := 20.0
var _rng := RandomNumberGenerator.new()


## `downpour`: Game.weather 2. Start values: a rainy-season stage starts
## mid-shower more often than not, and wet from the last one.
func setup(terrain: Terrain, env: Environment, sun: DirectionalLight3D, downpour: bool) -> void:
	_terrain = terrain
	_env = env
	_sun = sun
	_sky = env.sky.sky_material as ShaderMaterial
	_base = {"sun": sun.light_energy, "ambient": env.ambient_light_energy, "fog": env.fog_density,
		"vfog": env.volumetric_fog_density, "fog_col": env.fog_light_color,
		# (the sky shader's own defaults unless something set them)
		"cover": _sky_param("cloud_cover", 0.55), "zenith": _sky_param("zenith", Color(0.26, 0.45, 0.72)),
		"horizon": _sky_param("horizon", Color(0.80, 0.84, 0.84)), "exposure": env.tonemap_exposure}
	var season := terrain.plan.rain
	_rng.seed = terrain.plan.seed_value + 77
	_noise.seed = terrain.plan.seed_value + 78
	_noise.frequency = 1.0 / SHOWER_PERIOD
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_t = _rng.randf_range(0.0, 3000.0)
	if downpour:
		mode = 3
	elif season >= 0.65:
		mode = 2
	elif season >= 0.3:
		mode = 1
	var args := OS.get_cmdline_user_args()
	var ri := args.find("--rain")
	if ri >= 0 and ri + 1 < args.size():
		_fixed = clampf(float(args[ri + 1]), 0.0, 1.0)
		mode = 4
	intensity = _target()
	soak = clampf(intensity * 1.2, 0.0, 1.0) if intensity > 0.05 else (0.25 if mode >= 2 else 0.0)
	# a downpour's been going a while already: the rivers are well up
	flood = _flood_target() * (0.7 if mode == 3 else 0.0)
	_build_rain()
	_build_sound()
	_apply(0.0)


func _sky_param(key: String, def: Variant) -> Variant:
	var v: Variant = _sky.get_shader_parameter(key)
	if v == null:
		return def
	if v is Vector3:
		return Color(v.x, v.y, v.z)
	return v


## How hard it wants to be raining now, by the mode and the clock.
func _target() -> float:
	match mode:
		4:
			return _fixed
		3:
			return 0.8 + 0.2 * _noise.get_noise_1d(_t * 6.0)
		2:
			# showers: about half the time, building and easing off
			return smoothstep(-0.05, 0.35, _noise.get_noise_1d(_t)) * (0.55 + 0.45 * (_noise.get_noise_1d(_t * 4.0 + 500.0) * 0.5 + 0.5))
		1:
			return smoothstep(0.35, 0.6, _noise.get_noise_1d(_t)) * 0.4
	return 0.0


func _process(delta: float) -> void:
	_t += delta
	# rain comes on over a minute or so and eases off the same
	intensity = move_toward(intensity, _target(), delta / 40.0)
	if mode == 4:
		intensity = _fixed
	# surfaces soak in a couple of minutes of hard rain; they dry slowly,
	# quicker once the sun's back out
	if intensity > 0.05:
		soak = minf(1.0, soak + delta * intensity / 110.0)
	else:
		soak = maxf(0.0, soak - delta / (900.0 if mode >= 2 else 420.0))
	# the rivers come up once the ground can't take any more (the runoff
	# from upstream arrives over a few minutes), and go down slower still
	var want := _flood_target()
	flood = move_toward(flood, want, delta / (240.0 if want > flood else 900.0))
	_apply(delta)


## How far up the rivers want to be: only once the ground's saturated, and
## properly only in a downpour (a shower barely moves them).
func _flood_target() -> float:
	var heavy := mode == 3 or (mode == 4 and _fixed > 0.6)
	return smoothstep(0.55, 1.0, soak) * (1.0 if heavy else 0.45)


func _apply(delta: float) -> void:
	RenderingServer.global_shader_parameter_set("rain_now", intensity)
	RenderingServer.global_shader_parameter_set("rain_soak", soak)
	_terrain.rain_soak = soak
	_terrain.rain_now = intensity
	_terrain.set_flood(flood)
	# overcast: the sun goes in, the haze thickens, the sky greys over
	var r := smoothstep(0.0, 0.7, intensity)
	var cloud := maxf(r, smoothstep(0.0, 0.4, soak) * 0.4)
	_sun.light_energy = lerpf(_base["sun"], _base["sun"] * 0.18, cloud)
	_sun.shadow_opacity = lerpf(1.0, 0.35, cloud)
	_env.ambient_light_energy = lerpf(_base["ambient"], _base["ambient"] * 0.85, cloud)
	_env.fog_density = lerpf(_base["fog"], 0.0055, r)
	_env.volumetric_fog_density = lerpf(_base["vfog"], 0.006, r)
	_env.fog_light_color = (_base["fog_col"] as Color).lerp(Color(0.6, 0.63, 0.64), r)
	_env.tonemap_exposure = lerpf(_base["exposure"], _base["exposure"] * 1.15, cloud)
	_sky.set_shader_parameter("cloud_cover", lerpf(_base["cover"], 1.0, cloud))
	_sky.set_shader_parameter("zenith", (_base["zenith"] as Color).lerp(Color(0.42, 0.45, 0.48), cloud))
	_sky.set_shader_parameter("horizon", (_base["horizon"] as Color).lerp(Color(0.6, 0.62, 0.62), cloud))
	for m in _terrain.water_mats:
		m.set_shader_parameter("sky_col", Color(0.62, 0.7, 0.76).lerp(Color(0.5, 0.53, 0.54), cloud))
	# the rain round whoever's watching
	var cam := get_viewport().get_camera_3d()
	if cam and _drops:
		var at := cam.global_position
		var ahead := -cam.global_basis.z
		ahead.y = 0.0
		_drops.global_position = at + ahead * 6.0 + Vector3(0, 14.0, 0)
		_drops.amount_ratio = clampf(intensity, 0.0, 1.0)
		_drops.emitting = intensity > 0.02
		_splashes.emitting = _drops.emitting
		_shield.global_position = at
	if _sound:
		_sound.volume_db = linear_to_db(maxf(intensity, 0.0001)) - 3.0
		if intensity > 0.02 and not _sound.playing:
			_sound.play()
		# distant thunder now and then in a heavy rain
		_next_thunder -= delta
		if _next_thunder <= 0.0:
			_next_thunder = _rng.randf_range(25.0, 70.0)
			if intensity > 0.6 and not _thunder_streams.is_empty():
				_thunder.stream = _thunder_streams[_rng.randi() % _thunder_streams.size()]
				_thunder.volume_db = _rng.randf_range(-14.0, -6.0)
				_thunder.pitch_scale = _rng.randf_range(0.85, 1.1)
				_thunder.play()


## Streaks falling round the camera, as many as the graphics allow; they
## stop where they hit something (a heightfield of the scene from above, so
## a roof or the canopy keeps them off), throwing a splash where they land.
func _build_rain() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var count := int(lerpf(3000.0, 9000.0, clampf(float(Game.gfx.grass) / 2.0, 0.0, 1.0)))
	_splashes = GPUParticles3D.new()
	_splashes.name = "RainSplashes"
	_splashes.amount = count / 2
	_splashes.lifetime = 0.22
	_splashes.local_coords = false
	var sp := ParticleProcessMaterial.new()
	sp.direction = Vector3.UP
	sp.spread = 70.0
	sp.initial_velocity_min = 0.6
	sp.initial_velocity_max = 1.6
	sp.gravity = Vector3(0, -9.8, 0)
	sp.scale_min = 0.6
	sp.scale_max = 1.2
	_splashes.process_material = sp
	var sm := SphereMesh.new()
	sm.radius = 0.012
	sm.height = 0.024
	sm.radial_segments = 4
	sm.rings = 2
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(0.82, 0.85, 0.88, 0.5)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.material = smat
	_splashes.draw_pass_1 = sm
	_splashes.visibility_aabb = AABB(Vector3(-60, -60, -60), Vector3(120, 120, 120))
	add_child(_splashes)

	_drops = GPUParticles3D.new()
	_drops.name = "Rain"
	_drops.amount = count
	_drops.lifetime = 2.6
	_drops.preprocess = 2.0
	_drops.local_coords = false
	_drops.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 60, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(22, 1, 22)
	pm.direction = Vector3(0.08, -1.0, 0.03)
	pm.spread = 3.0
	pm.initial_velocity_min = 8.0
	pm.initial_velocity_max = 10.0
	pm.gravity = Vector3(0, -2.0, 0)
	pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	pm.collision_use_scale = false
	pm.sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_AT_COLLISION
	pm.sub_emitter_amount_at_collision = 1
	_drops.process_material = pm
	_drops.sub_emitter = NodePath("../RainSplashes")
	# a thin streak, the length of the distance a drop falls in a frame or two
	var q := QuadMesh.new()
	q.size = Vector2(0.012, 0.55)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.albedo_color = Color(0.78, 0.82, 0.86, 0.28)
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	qm.billboard_keep_scale = true
	q.material = qm
	_drops.draw_pass_1 = q
	_drops.emitting = false
	add_child(_drops)

	# what keeps the rain off: the scene seen from above, round the camera
	_shield = GPUParticlesCollisionHeightField3D.new()
	_shield.name = "RainShield"
	_shield.size = Vector3(60, 60, 60)
	_shield.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_512
	_shield.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_ALWAYS
	_shield.follow_camera_enabled = true
	add_child(_shield)


func _build_sound() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_sound = AudioStreamPlayer.new()
	_sound.stream = SoundSynth.rain()
	_sound.volume_db = -80.0
	add_child(_sound)
	_thunder = AudioStreamPlayer.new()
	add_child(_thunder)
	for k in 3:
		_thunder_streams.append(SoundSynth.thunder(30 + k))
