class_name RigAudio
extends Node3D
## Mixes the synthesised loops from what the rig is doing: engine rpm follows
## wheel speed and gear (so wheelspin flares it), squelch follows mud and slip,
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
var _oneshot: AudioStreamPlayer3D
var _paddy_amb: AudioStreamPlayer
var _forest_amb: AudioStreamPlayer
var _clunk: AudioStream
var _splash: AudioStream
var _last := {}
var _was_wet := false


func setup(r: Rig) -> void:
	rig = r
	_engine_lo = _loop3d(SoundSynth.engine(LO_RPM, 0.0, 1), 4.0)
	_engine_hi = _loop3d(SoundSynth.engine(HI_RPM, 1.0, 2), 4.0)
	_mud = _loop3d(SoundSynth.mud(3), 3.0)
	_gravel = _loop3d(SoundSynth.gravel(4), 3.0)
	_water = _loop3d(SoundSynth.water(5), 3.0)
	_winch = _loop3d(SoundSynth.winch(), 3.0, Vector3(0, 0.75, -1.8))
	_oneshot = AudioStreamPlayer3D.new()
	_oneshot.unit_size = 4.0
	add_child(_oneshot)
	_clunk = SoundSynth.clunk()
	_splash = SoundSynth.splash()
	_paddy_amb = _loop2d(SoundSynth.paddy_ambience())
	_forest_amb = _loop2d(SoundSynth.forest_ambience())
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

	# --- engine: rpm from how fast the wheels are turning through the gears ---
	var omega := 0.0
	for w in rig.wheels:
		omega += absf(w.omega)
	omega /= rig.wheels.size()
	var ratio := 150.0 if rig.low_range else 64.0
	var load := maxf(rig.throttle, rig.brake * 0.6)
	var target := clampf(maxf(IDLE_RPM + load * 900.0, 600.0 + omega * ratio), IDLE_RPM, MAX_RPM)
	rpm = lerpf(rpm, target, 1.0 - exp(-delta * (5.0 if target > rpm else 3.0)))
	var x := smoothstep(1500.0, 3400.0, rpm)
	_engine_lo.pitch_scale = rpm / LO_RPM
	_engine_hi.pitch_scale = rpm / HI_RPM
	_engine_lo.volume_db = _db((1.0 - x) * (0.55 + 0.45 * load)) - 2.0
	_engine_hi.volume_db = _db(x * (0.45 + 0.55 * load)) - 3.0

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
	var z := rig.global_position.z
	var f := smoothstep(35.0, 70.0, z)
	_paddy_amb.volume_db = _db((1.0 - f) * 0.5) - 6.0
	_forest_amb.volume_db = _db(f * 0.55) - 6.0


func _play(stream: AudioStream, db: float, pitch: float) -> void:
	_oneshot.stream = stream
	_oneshot.volume_db = db
	_oneshot.pitch_scale = pitch
	_oneshot.play()
