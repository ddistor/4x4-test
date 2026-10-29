class_name SoundSynth
extends RefCounted
## Every sound in the game, synthesised at startup into short loops and
## one-shots (no audio files, like everything else here). Loops are a whole
## number of cycles long so they wrap without a click; the rig pitches and
## mixes them at runtime.
##
## Built from filtered noise rather than pure tones: an engine is pressure
## pulses ringing in an exhaust, a frog is a rasp, a cicada is a buzz. Pure
## sines and square waves are what made the first version sound like a chiptune.

const RATE := 32000


static func _to_wav(buf: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var peak := 0.0
	for v in buf:
		peak = maxf(peak, absf(v))
	var g := 0.89 / maxf(peak, 1e-6)
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in range(buf.size()):
		bytes.encode_s16(i * 2, int(clampf(buf[i] * g, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w


## RBJ biquad, in place. kind: 0 low-pass, 1 band-pass (0 dB peak).
static func _biquad(buf: PackedFloat32Array, kind: int, freq: float, q: float) -> void:
	var w0 := TAU * freq / RATE
	var alpha := sin(w0) / (2.0 * q)
	var c := cos(w0)
	var a0 := 1.0 + alpha
	var b0: float
	var b1: float
	var b2: float
	if kind == 0:
		b0 = (1.0 - c) * 0.5 / a0
		b1 = (1.0 - c) / a0
		b2 = b0
	else:
		b0 = alpha / a0
		b1 = 0.0
		b2 = -alpha / a0
	var a1 := -2.0 * c / a0
	var a2 := (1.0 - alpha) / a0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in range(buf.size()):
		var x := buf[i]
		var y := b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		buf[i] = y


static func _lowpass(buf: PackedFloat32Array, freq: float, q := 0.707) -> void:
	_biquad(buf, 0, freq, q)


static func _bandpass(buf: PackedFloat32Array, freq: float, q: float) -> void:
	_biquad(buf, 1, freq, q)


static func _highpass(buf: PackedFloat32Array, cutoff: float) -> void:
	var k := exp(-TAU * cutoff / RATE)
	var prev_x := 0.0
	var prev_y := 0.0
	for i in range(buf.size()):
		var y := k * (prev_y + buf[i] - prev_x)
		prev_x = buf[i]
		prev_y = y
		buf[i] = y


static func _noise(n: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(n)
	for i in range(n):
		b[i] = rng.randf_range(-1.0, 1.0)
	return b


static func _zeros(n: int) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(n)
	return b


static func _mix(into: PackedFloat32Array, src: PackedFloat32Array, gain: float, at := 0) -> void:
	for i in range(src.size()):
		var j := (at + i) % into.size()
		into[j] += src[i] * gain


## A burst of band-limited noise with a fast attack and exponential tail,
## mixed in at `at` (wrapping round the loop). The basic grain of squelches,
## croaks, slaps and knocks.
static func _burst(into: PackedFloat32Array, at: int, dur: float, freq: float, q: float, amp: float, rng: RandomNumberGenerator, decay := 4.0) -> void:
	var b := _noise(int(dur * RATE), rng)
	_bandpass(b, freq, q)
	var n := b.size()
	for i in range(n):
		var t := float(i) / n
		b[i] *= minf(1.0, i / (RATE * 0.003)) * exp(-t * decay)
	_mix(into, b, amp, at)


# --- engine ---------------------------------------------------------------------

## A lumpy V8 at a fixed rpm: each firing is a pressure pulse (a thump plus
## a burst of noise) that rings through the exhaust's resonances. Cross-plane
## firing makes the pulses uneven in a repeating 8-pulse pattern, which is
## the burble. `bright` adds the rasp of the high-rpm layer.
static func engine(rpm: float, bright: float, seed_v: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var fire := rpm / 60.0 * 4.0
	var n := RATE  # 1 s holds a whole number of 8-pulse engine cycles at 1200/3000 rpm
	var pattern := [1.0, 0.78, 1.1, 0.72, 0.95, 0.85, 1.06, 0.68]
	var exc := _zeros(n)
	var count := int(round(fire))
	for k in range(count):
		var at := int(k * RATE / fire + rng.randf_range(-0.0002, 0.0002) * RATE)
		var amp: float = pattern[k % 8] * (1.0 + rng.randfn() * 0.08)
		var len := int(RATE * 0.014)
		for i in range(len):
			var t := float(i) / RATE
			exc[(at + i + n) % n] += amp * (exp(-t / 0.0035) * 0.9 + rng.randf_range(-1.0, 1.0) * exp(-t / 0.0025) * 0.7)
	var body := exc.duplicate()
	_bandpass(body, lerpf(95.0, 140.0, bright), 1.8)
	var pipe := exc.duplicate()
	_bandpass(pipe, lerpf(320.0, 520.0, bright), 2.5)
	var rasp := exc.duplicate()
	_bandpass(rasp, lerpf(1100.0, 1900.0, bright), 1.2)
	var buf := _zeros(n)
	for i in range(n):
		var s := body[i] * 1.0 + pipe[i] * 0.55 + rasp[i] * (0.12 + 0.4 * bright) + exc[i] * 0.06
		buf[i] = tanh(s * 2.2)
	_lowpass(buf, lerpf(2200.0, 6000.0, bright))
	_highpass(buf, 30.0)
	return _to_wav(buf, true)


# --- ground and water -------------------------------------------------------------

## Tires churning clay: a wet low churn with squelches and sucking pops.
static func mud(seed_v: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var n := RATE * 2
	var buf := _noise(n, rng)
	_lowpass(buf, 220.0)
	_lowpass(buf, 220.0)
	for i in range(n):
		buf[i] *= 3.0
	for k in range(34):
		_burst(buf, rng.randi() % n, rng.randf_range(0.05, 0.16), rng.randf_range(160.0, 480.0), rng.randf_range(2.0, 5.0), rng.randf_range(0.5, 1.4), rng, 5.0)
	for k in range(10):  # sucking pops as a lug pulls free
		_burst(buf, rng.randi() % n, 0.04, rng.randf_range(700.0, 1100.0), 6.0, 0.5, rng, 8.0)
	return _to_wav(buf, true)


## Rolling on gravel: a carpet of tiny stone clicks over road rumble.
static func gravel(seed_v: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var n := RATE * 2
	var rumble := _noise(n, rng)
	_lowpass(rumble, 160.0)
	var clicks := _zeros(n)
	for k in range(1100):
		var at := rng.randi() % n
		var amp := rng.randf_range(0.2, 1.0)
		for i in range(rng.randi_range(20, 80)):
			clicks[(at + i) % n] += rng.randf_range(-1.0, 1.0) * amp * exp(-i / 14.0)
	_highpass(clicks, 1500.0)
	_lowpass(clicks, 7000.0)
	var buf := _zeros(n)
	for i in range(n):
		buf[i] = rumble[i] * 1.8 + clicks[i] * 0.45
	return _to_wav(buf, true)


## Pushing through water: broadband swash rising and falling, with low slaps.
static func water(seed_v: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var n := RATE * 3
	var hi := _noise(n, rng)
	_highpass(hi, 400.0)
	_lowpass(hi, 4500.0)
	var lo := _noise(n, rng)
	_lowpass(lo, 140.0)
	var buf := _zeros(n)
	for i in range(n):
		var t := float(i) / n
		# swells that complete a whole number of cycles per loop
		var swell := 0.55 + 0.25 * sin(TAU * 3.0 * t) + 0.2 * sin(TAU * 7.0 * t + 1.3)
		buf[i] = hi[i] * swell + lo[i] * 3.0
	for k in range(12):
		_burst(buf, rng.randi() % n, 0.2, rng.randf_range(90.0, 220.0), 1.5, 1.2, rng, 6.0)
	return _to_wav(buf, true)


## Winch motor under load: a motor whine (that one really is tonal) with
## brush and gear noise on it.
static func winch() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var n := RATE
	var buf := _noise(n, rng)
	_bandpass(buf, 1800.0, 1.0)
	for i in range(n):
		var t := float(i) / RATE
		var s := 0.0
		for h in range(1, 6):
			s += sin(TAU * 140.0 * h * t) / (h * h)
		buf[i] = buf[i] * 0.8 + s * 0.5 + 0.2 * sin(TAU * 560.0 * t) * (0.5 + 0.5 * sin(TAU * 20.0 * t))
	_lowpass(buf, 3000.0)
	return _to_wav(buf, true)


## Letting air out of a valve: a bright, steady hiss with a little flutter.
static func air_hiss() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 88
	var n := RATE
	var buf := _noise(n, rng)
	_highpass(buf, 2500.0)
	_lowpass(buf, 9000.0)
	for i in range(n):
		buf[i] *= 0.85 + 0.15 * sin(TAU * 13.0 * i / RATE)
	return _to_wav(buf, true)


## Portable 12 V compressor: a piston thudding ~30 times a second, motor
## buzz and the rattle of the housing.
static func compressor() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 89
	var n := RATE
	var buf := _zeros(n)
	for k in range(30):
		_burst(buf, int(k * RATE / 30.0), 0.03, 240.0, 1.5, 1.0, rng, 7.0)
		_burst(buf, int(k * RATE / 30.0), 0.015, 2200.0, 4.0, 0.35, rng, 9.0)
	var motor := _noise(n, rng)
	_bandpass(motor, 600.0, 2.0)
	_mix(buf, motor, 0.25)
	return _to_wav(buf, true)


# --- ambience ---------------------------------------------------------------------

## Paddies by the lake: a chorus of palaka knocking and rasping, distant
## crickets, breeze over the rice.
static func paddy_ambience() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 501
	var n := RATE * 10
	var buf := _noise(n, rng)
	_lowpass(buf, 500.0)
	for i in range(n):
		buf[i] *= 0.5 * (0.7 + 0.3 * sin(TAU * 2.0 * i / n))
	for frog in range(9):
		var pitch := rng.randf_range(450.0, 1100.0)
		var at := rng.randi() % n
		var amp := rng.randf_range(0.25, 0.7)
		for call in range(rng.randi_range(3, 9)):
			var start := at + call * int(rng.randf_range(0.09, 0.16) * RATE)
			_burst(buf, start, rng.randf_range(0.025, 0.05), pitch * rng.randf_range(0.97, 1.03), 7.0, amp, rng, 5.0)
	var crickets := _zeros(n)
	for c in range(30):
		var at := rng.randi() % n
		for pulse in range(rng.randi_range(4, 10)):
			_burst(crickets, at + pulse * int(0.032 * RATE), 0.018, rng.randf_range(4300.0, 5000.0), 14.0, 0.25, rng, 3.0)
	_mix(buf, crickets, 0.4)
	return _to_wav(buf, true)


## Secondary forest: kuliglig (cicada) choruses swelling in and out, a few
## birds, wind in the canopy.
static func forest_ambience() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 502
	var n := RATE * 10
	var buf := _noise(n, rng)
	_lowpass(buf, 600.0)
	_highpass(buf, 60.0)
	for i in range(n):
		buf[i] *= 0.6 * (0.55 + 0.45 * sin(TAU * 3.0 * i / n + 0.4))
	# cicadas: a hiss band round 4.5 kHz, chopped into a fast buzz, swelling
	var cic := _noise(n, rng)
	_bandpass(cic, 4600.0, 3.0)
	for i in range(n):
		var t := float(i) / RATE
		var swell := pow(maxf(0.0, sin(TAU * 2.0 * i / n)), 1.5)
		var buzz := pow(0.5 + 0.5 * sin(TAU * 95.0 * t), 3.0)
		buf[i] += cic[i] * 0.9 * swell * buzz
	# birds: short whistled phrases with a natural wobble, kept sparse and soft
	for bird in range(7):
		var at := rng.randi() % n
		var base := rng.randf_range(1900.0, 3000.0)
		for note in range(rng.randi_range(2, 4)):
			var start := at + note * int(rng.randf_range(0.14, 0.24) * RATE)
			var len := int(rng.randf_range(0.07, 0.14) * RATE)
			var ph := 0.0
			var f0 := base * rng.randf_range(0.92, 1.08)
			var f1 := f0 * rng.randf_range(1.1, 1.4)
			for i in range(len):
				var u := float(i) / len
				var vib := 1.0 + 0.03 * sin(TAU * 32.0 * float(i) / RATE)
				ph += TAU * lerpf(f0, f1, u) * vib / RATE
				var env := sin(PI * u) * sin(PI * u)
				buf[(start + i) % n] += (sin(ph) + 0.2 * sin(2.0 * ph)) * env * 0.12
	return _to_wav(buf, true)


# --- one-shots ----------------------------------------------------------------------

## Driveline clunk: diff lock, transfer case, winch clutch. A dull knock with
## a short metallic ring.
static func clunk() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var n := int(RATE * 0.35)
	var buf := _zeros(n)
	_burst(buf, 0, 0.3, 110.0, 1.2, 1.6, rng, 9.0)
	_burst(buf, 0, 0.12, 950.0, 12.0, 0.6, rng, 12.0)
	_burst(buf, 0, 0.08, 2600.0, 10.0, 0.25, rng, 14.0)
	return _to_wav(buf, false)


## Hitting water at speed: a heavy slap and a falling shower.
static func splash() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 10
	var n := int(RATE * 1.4)
	var buf := _noise(n, rng)
	_lowpass(buf, 3500.0)
	for i in range(n):
		var t := float(i) / RATE
		buf[i] *= exp(-t * 2.8) * (0.4 + 0.6 * exp(-t * 12.0))
	_burst(buf, 0, 0.3, 90.0, 1.0, 2.0, rng, 8.0)
	return _to_wav(buf, false)
