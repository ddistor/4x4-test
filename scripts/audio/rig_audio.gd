class_name RigAudio
extends Node3D
## Mixes the synthesised loops from what the rig is doing: engine rpm comes
## from the gearbox (so gears, wheelspin and stalls all show), squelch follows mud and slip,
## swash follows water, and the ambience fades from paddies to forest as you
## climb. One-shots for the diff lock / low range / winch and big splashes.

const IDLE_RPM := 750.0
const MAX_RPM := 5200.0
const LO_RPM := 1200.0   # the rpm each engine loop was synthesised at
const HI_RPM := 3000.0

var rig: Rig
var rpm := IDLE_RPM

var _engine_lo: AudioStreamPlayer3D
var _engine_hi: AudioStreamPlayer3D
var _mud: AudioStreamPlayer3D
var _gravel: AudioStreamPlayer3D
var _water: AudioStreamPlayer3D
var _winch: AudioStreamPlayer3D
var _air: AudioStreamPlayer3D
var _compressor: AudioStreamPlayer3D
var _oneshot: AudioStreamPlayer3D
var _paddy_amb: AudioStreamPlayer
var _forest_amb: AudioStreamPlayer
var _clunk: AudioStream
var _splash: AudioStream
var _last := {}
var _was_wet := false
var _forest := 0.0  # 0 open country .. 1 in the trees, eased so it doesn't flicker

# wildlife: a bank of separate calls, played at random round the listener
var _calls := {}           # kind -> Array[AudioStream]
var _last_variant := {}    # kind -> index, so the same call never plays twice running
var _critters: Array[AudioStreamPlayer3D] = []
var _next_call := 4.0
var _rng := RandomNumberGenerator.new()


func setup(r: Rig) -> void:
	rig = r
	_engine_lo = _loop3d(SoundSynth.engine(LO_RPM, 0.0, 1), 4.0)
	_engine_hi = _loop3d(SoundSynth.engine(HI_RPM, 1.0, 2), 4.0)
	_mud = _loop3d(SoundSynth.mud(3), 3.0)
	_gravel = _loop3d(SoundSynth.gravel(4), 3.0)
	_water = _loop3d(SoundSynth.water(5), 3.0)
	_winch = _loop3d(SoundSynth.winch(), 3.0, Vector3(0, 0.75, -1.8))
	_air = _loop3d(SoundSynth.air_hiss(), 2.0, Vector3(-0.8, 0.1, -1.3))
	_compressor = _loop3d(SoundSynth.compressor(), 2.5, Vector3(0, 0.8, 1.2))
	_oneshot = AudioStreamPlayer3D.new()
	_oneshot.unit_size = 4.0
	add_child(_oneshot)
	_clunk = SoundSynth.clunk()
	_splash = SoundSynth.splash()
	_paddy_amb = _loop2d(SoundSynth.paddy_bed())
	_forest_amb = _loop2d(SoundSynth.forest_bed())
	_build_critters()
	_last = {"diff": rig.diff_locked, "low": rig.low_range, "winch": rig.winch_active}


func _loop3d(stream: AudioStream, unit: float, at := Vector3.ZERO) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.unit_size = unit
	p.position = at
	p.volume_db = -80.0
	p.autoplay = true
	add_child(p)
	return p


func _loop2d(stream: AudioStream) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = -80.0
	p.autoplay = true
	add_child(p)
	return p


static func _db(linear: float) -> float:
	return linear_to_db(maxf(linear, 0.0001))


func _process(delta: float) -> void:
	if rig == null or rig.wheel_status.size() < 4:
		return
	var smooth := 1.0 - exp(-delta * 8.0)

	# --- engine: the gearbox's rpm; quiet when it has stalled -----------------
	# (each engine's rpm range is mapped onto the loops' so a diesel at its
	# 4000 redline sounds as wound up as a V8 at 4800)
	var gb := rig.gearbox
	var load := maxf(rig.throttle, rig.brake * 0.6)
	var span := (gb.rpm - gb.idle_rpm) / (gb.redline - gb.idle_rpm)
	var target := IDLE_RPM + span * (MAX_RPM - IDLE_RPM) if gb.rpm > gb.idle_rpm * 0.5 else gb.rpm
	rpm = lerpf(rpm, target, 1.0 - exp(-delta * 12.0))
	var on := 1.0 if gb.running else smoothstep(0.0, 400.0, gb.rpm) * 0.5
	var x := smoothstep(1500.0, 3400.0, rpm)
	_engine_lo.pitch_scale = maxf(rpm, 150.0) / LO_RPM
	_engine_hi.pitch_scale = maxf(rpm, 150.0) / HI_RPM
	_engine_lo.volume_db = _db((1.0 - x) * (0.55 + 0.45 * load) * on) - 2.0
	_engine_hi.volume_db = _db(x * (0.45 + 0.55 * load) * on) - 3.0

	# --- tires on the ground ----------------------------------------------------
	var mud := 0.0
	var slip := 0.0
	var water := 0.0
	var contact := 0.0
	for s in rig.wheel_status:
		mud += s["in_mud"]
		slip = maxf(slip, s["slip"])
		water = maxf(water, s["in_water"])
	for w in rig.wheels:
		contact += 1.0 if w.contact else 0.0
	mud /= 4.0
	contact /= 4.0
	var speed := rig.speed_kmh / 3.6
	var churn := mud * clampf(slip * 0.9 + speed / 7.0, 0.0, 1.2)
	_mud.volume_db = lerpf(_mud.volume_db, _db(churn) - 2.0, smooth)
	_mud.pitch_scale = 0.8 + 0.35 * slip + speed * 0.02
	var roll := (1.0 - mud) * contact * clampf(speed / 9.0, 0.0, 1.0) * (1.0 - smoothstep(0.05, 0.3, water))
	_gravel.volume_db = lerpf(_gravel.volume_db, _db(roll) - 6.0, smooth)
	_gravel.pitch_scale = 0.75 + speed * 0.025
	var swash := smoothstep(0.05, 0.4, water) * clampf(0.25 + speed / 5.0, 0.0, 1.2)
	_water.volume_db = lerpf(_water.volume_db, _db(swash), smooth)
	_water.pitch_scale = 0.85 + speed * 0.03
	_winch.volume_db = lerpf(_winch.volume_db, -6.0 if rig.winch_active else -80.0, smooth)
	_air.volume_db = lerpf(_air.volume_db, -12.0 if rig.airing < 0 else -80.0, smooth)
	_compressor.volume_db = lerpf(_compressor.volume_db, -8.0 if rig.airing > 0 else -80.0, smooth)

	# --- one-shots ------------------------------------------------------------
	var now := {"diff": rig.diff_locked, "low": rig.low_range, "winch": rig.winch_active}
	for key: String in now:
		if now[key] != _last[key]:
			_play(_clunk, -4.0, 0.9 if key == "low" else 1.1)
	_last = now
	var wet := water > 0.15
	if wet and not _was_wet and speed > 2.5:
		_play(_splash, clampf(-10.0 + speed * 1.5, -10.0, 2.0), 1.0)
	_was_wet = wet

	# --- ambience: paddies by the lake, forest once you're in the trees -------
	var at := rig.global_position
	var woods := (rig.terrain.forest_at(at.x - 12.0, at.z) + rig.terrain.forest_at(at.x + 12.0, at.z)) * 0.5
	_forest = lerpf(_forest, smoothstep(0.1, 0.6, woods), 1.0 - exp(-delta * 0.5))
	var f := _forest
	_paddy_amb.volume_db = _db((1.0 - f) * 0.5) - 6.0
	_forest_amb.volume_db = _db(f * 0.55) - 6.0
	_critter_step(delta, f)


func _play(stream: AudioStream, db: float, pitch: float) -> void:
	_oneshot.stream = stream
	_oneshot.volume_db = db
	_oneshot.pitch_scale = pitch
	_oneshot.play()


# --- wildlife -----------------------------------------------------------------------

const CALL_KINDS := {
	# kind: [variants, base dB, height above ground (min, max), distance (min, max)]
	"frog": [10, -10.0, Vector2(0.0, 0.3), Vector2(6.0, 35.0)],
	"bird": [10, -13.0, Vector2(5.0, 14.0), Vector2(10.0, 45.0)],
	"cricket": [6, -18.0, Vector2(0.1, 0.6), Vector2(4.0, 25.0)],
	"cicada": [4, -15.0, Vector2(6.0, 12.0), Vector2(15.0, 50.0)],
}


func _build_critters() -> void:
	_rng.randomize()
	for kind: String in CALL_KINDS:
		var bank: Array[AudioStream] = []
		for v in range(CALL_KINDS[kind][0]):
			var seed_v: int = 1000 + v * 37 + kind.length() * 1013
			match kind:
				"frog": bank.append(SoundSynth.frog_call(seed_v))
				"bird": bank.append(SoundSynth.bird_call(seed_v))
				"cricket": bank.append(SoundSynth.cricket_call(seed_v))
				"cicada": bank.append(SoundSynth.cicada_call(seed_v))
		_calls[kind] = bank
		_last_variant[kind] = -1
	for i in range(6):
		var p := AudioStreamPlayer3D.new()
		p.top_level = true  # placed in the world, not riding along on the rig
		p.unit_size = 8.0
		p.max_distance = 90.0
		add_child(p)
		_critters.append(p)


## Every so often, somewhere around the listener, something calls. What
## calls depends on where you are: frogs and crickets in the paddies, birds
## and cicadas once you're in the forest.
func _critter_step(delta: float, forest: float) -> void:
	_next_call -= delta
	if _next_call > 0.0:
		return
	var weights := {
		"frog": lerpf(0.6, 0.12, forest),
		"cricket": lerpf(0.32, 0.25, forest),
		"bird": lerpf(0.08, 0.45, forest),
		"cicada": lerpf(0.0, 0.18, forest),
	}
	var kind := "frog"
	var total := 0.0
	for k: String in weights:
		total += weights[k]
	var pick := _rng.randf() * total
	for k: String in weights:
		pick -= float(weights[k])
		if pick <= 0.0:
			kind = k
			break
	# one cicada chorus at a time; otherwise take a free player
	var player: AudioStreamPlayer3D = null
	for p in _critters:
		if kind == "cicada" and p.playing and _calls["cicada"].has(p.stream):
			_next_call = 0.3
			return
		if not p.playing and player == null:
			player = p
	if player == null:
		_next_call = 0.5
		return
	var bank: Array = _calls[kind]
	var v := _rng.randi() % bank.size()
	if v == int(_last_variant[kind]):
		v = (v + 1) % bank.size()
	_last_variant[kind] = v
	var spec: Array = CALL_KINDS[kind]
	var dir := Vector2.from_angle(_rng.randf() * TAU)
	var reach: Vector2 = spec[3]
	var lift: Vector2 = spec[2]
	var dist := _rng.randf_range(reach.x, reach.y)
	var at := rig.global_position + Vector3(dir.x, 0.0, dir.y) * dist
	at.y = rig.terrain.get_height(at.x, at.z) + _rng.randf_range(lift.x, lift.y)
	player.global_position = at
	player.stream = bank[v]
	player.pitch_scale = _rng.randf_range(0.88, 1.12)
	player.volume_db = float(spec[1]) + _rng.randf_range(-6.0, 1.0)
	player.play()

	# now and then a frog answers; otherwise a long, uneven quiet
	_next_call = _rng.randf_range(0.3, 0.8) if kind == "frog" and _rng.randf() < 0.15 else _rng.randf_range(5.0, 14.0)
