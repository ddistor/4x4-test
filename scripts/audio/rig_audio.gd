class_name RigAudio
extends Node3D
## Mixes the synthesised loops from what the rig is doing: the rig's own
## engine (EngineSynth: its exhaust from the tailpipe, intake and block from
## the bay) at the gearbox's rpm, on or off load, through the closed cab's
## walls when you're inside; gear whine in reverse, first and low range;
## squelch follows mud and slip,
## swash follows water, and the ambience fades from paddies to forest as you
## climb. One-shots for the diff lock / low range / winch and big splashes.

var rig: Rig

# the engine: its baked loops (EngineSynth.build) once they're ready; two
# players a layer and load (even and odd rev points, crossfaded between)
var _eng := {}
var _ex := []          # [slot][0 on load, 1 off] AudioStreamPlayer3D at the tailpipe
var _in := []          # the same in the engine bay
var _load := 0.0
var _whine: AudioStreamPlayer3D
var _kind := ""
var _mud: AudioStreamPlayer3D
var _gravel: AudioStreamPlayer3D
var _water: AudioStreamPlayer3D
var _winch: AudioStreamPlayer3D
var _air: AudioStreamPlayer3D
var _compressor: AudioStreamPlayer3D
var _oneshot: AudioStreamPlayer3D
var _knocks := 0
var _breaks := 0
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
	_engine_setup()
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


func _loop3d(stream: AudioStream, unit: float, at := Vector3.ZERO, bus := "Master") -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.unit_size = unit
	p.position = at
	p.volume_db = -80.0
	p.autoplay = stream != null
	if bus != "Master":
		_engine_bus(bus)
		p.bus = bus
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

	_engine_step(delta)

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
	# damage: a dull bang for a knock that hurt, a deep crack when it broke
	var dmg: Damage = rig.damage
	if dmg.breaks != _breaks:
		_play(_clunk, 2.0, 0.45)
	elif dmg.knocks != _knocks:
		_play(_clunk, -1.0, 0.65)
	_knocks = dmg.knocks
	_breaks = dmg.breaks
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


# --- the engine ------------------------------------------------------------------

func _engine_setup() -> void:
	var s := rig.spec
	var l := CabinKit.layout(s)
	_kind = l["engine"]
	var tail := Vector3(0.35, 0.45, float(l["tail"]))
	var bay := Vector3(0.0, 0.9, float(l["bay"][0]) + 0.45)
	for slot in range(2):
		_ex.append([_loop3d(null, 4.0, tail, "EngineOut"), _loop3d(null, 4.0, tail, "EngineOut")])
		_in.append([_loop3d(null, 3.0, bay, "EngineIn"), _loop3d(null, 3.0, bay, "EngineIn")])
	_whine = _loop3d(EngineSynth.whine(), 2.5, Vector3(0.0, 0.45, s.seat.z - 0.4), "EngineOut")
	# made while the stage loads (usually already, in the garage)
	_eng = Game.engine_sound(s)


## Two buses the engine plays through, each with a low-pass: outside, wide
## open; from the seat of a closed cab the exhaust comes through the floor
## and glass dull and low, the bay through the firewall a little brighter.
static func _engine_bus(name_: String) -> int:
	var i := AudioServer.get_bus_index(name_)
	if i >= 0:
		return i
	AudioServer.add_bus()
	i = AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, name_)
	AudioServer.set_bus_send(i, "Master")
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(i, lp)
	# and a limiter: right by an open tub's engine at full throttle it must not break up
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = -1.5
	AudioServer.add_bus_effect(i, lim)
	return i


func _engine_step(delta: float) -> void:
	var gb := rig.gearbox
	var on := 1.0 if gb.running else smoothstep(0.0, 300.0, gb.rpm) * 0.6
	# on load: the throttle open and the engine pulling; off: closed, coasting
	# on engine braking, or the clutch out for a shift
	var want := clampf(rig.pedal_gas * 1.3, 0.0, 1.0)
	if gb.shifting > 0.0 or gb.torque_out < 0.0:
		want = 0.0
	_load = move_toward(_load, want, delta * (6.0 if want > _load else 3.0))
	# inside or out: the seat camera in a closed cab hears it through the body
	var cam := get_viewport().get_camera_3d()
	var inside: bool = cam != null and cam.get("hood_cam") == true
	var closed := rig.spec.closed()
	var out_bus := _engine_bus("EngineOut")
	var in_bus := _engine_bus("EngineIn")
	(AudioServer.get_bus_effect(out_bus, 0) as AudioEffectLowPassFilter).cutoff_hz = (650.0 if closed else 5000.0) if inside else 20000.0
	(AudioServer.get_bus_effect(in_bus, 0) as AudioEffectLowPassFilter).cutoff_hz = (1800.0 if closed else 9000.0) if inside else 20000.0
	AudioServer.set_bus_volume_db(out_bus, (-13.0 if closed else -3.0) if inside else 0.0)
	AudioServer.set_bus_volume_db(in_bus, (-10.0 if closed else -4.0) if inside else 0.0)
	# gear whine: shaft speed x teeth. The straight-cut reverse idler sings
	# loudest, first a little, the transfer case's reduction gears in low
	var r := maxf(gb.rpm, 1.0)
	var ratio: float = gb.reverse_ratio if gb.gear < 0 else float(gb.gears[clampi(gb.gear - 1, 0, gb.gears.size() - 1)])
	var mesh_hz := r / 60.0 * 23.0
	var whine := 0.0
	if gb.gear < 0:
		whine = 0.5
	elif rig.low_range:
		mesh_hz = r / ratio / 60.0 * 31.0
		whine = 0.3
	elif gb.gear == 1:
		whine = 0.12
	whine *= smoothstep(400.0, 1600.0, r) * on
	_whine.pitch_scale = clampf(mesh_hz / 500.0, 0.05, 8.0)
	_whine.volume_db = lerpf(_whine.volume_db, _db(whine) - 10.0, 1.0 - exp(-delta * 6.0))
	if _eng.is_empty():
		for slot in range(2):
			for k in range(2):
				_ex[slot][k].volume_db = -80.0
				_in[slot][k].volume_db = -80.0
		return
	# between which two rev points, and how far
	var pts: Array = _eng["rpm"]
	var i := 0
	while i < pts.size() - 2 and r > float(pts[i + 1]):
		i += 1
	var f := clampf(log(r / float(pts[i])) / log(float(pts[i + 1]) / float(pts[i])), 0.0, 1.0)
	var weights := {i: cos(f * PI * 0.5), i + 1: sin(f * PI * 0.5)}
	var size := sqrt(float(_eng["litres"]) / 5.7)   # a big V8 is louder than a 1.6
	for idx: int in weights:
		var slot := idx % 2
		for k in range(2):
			var key := "on" if k == 0 else "off"
			_assign(_ex[slot][k], _eng["ex_" + key][idx])
			_assign(_in[slot][k], _eng["in_" + key][idx])
			var lw := sqrt(_load) if k == 0 else sqrt(1.0 - _load)
			var g: float = weights[idx] * lw * on * lerpf(0.75, 1.0, size)
			for pl: AudioStreamPlayer3D in [_ex[slot][k], _in[slot][k]]:
				pl.pitch_scale = clampf(r / float(pts[idx]), 0.05, 4.0)
			_ex[slot][k].volume_db = _db(g) - 1.0
			_in[slot][k].volume_db = _db(g) - 8.0


## Give a player the loop for a rev point (only when it changes: that restarts it).
func _assign(pl: AudioStreamPlayer3D, w: AudioStream) -> void:
	if pl.stream == w:
		return
	pl.stream = w
	pl.play()


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
