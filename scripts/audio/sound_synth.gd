class_name SoundSynth
extends RefCounted
## Every sound in the game, synthesised at startup into short loops and
## one-shots (no audio files, like everything else here). Loops are a whole
## number of cycles long so they wrap without a click; the rig pitches and
## mixes them at runtime.

const RATE := 22050


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


## In-place 2-pole low-pass (RBJ biquad). Run twice for a steeper slope.
static func _lowpass(buf: PackedFloat32Array, cutoff: float, q := 0.707) -> void:
	var w0 := TAU * cutoff / RATE
	var alpha := sin(w0) / (2.0 * q)
	var c := cos(w0)
	var a0 := 1.0 + alpha
	var b0 := (1.0 - c) * 0.5 / a0
	var b1 := (1.0 - c) / a0
	var a1 := -2.0 * c / a0
	var a2 := (1.0 - alpha) / a0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in range(buf.size()):
		var x := buf[i]
		var y := b0 * x + b1 * x1 + b0 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		buf[i] = y


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


## Add a decaying, downward-sweeping tone at sample `at` (wraps round the loop).
static func _blip(buf: PackedFloat32Array, at: int, f0: float, f1: float, dur: float, amp: float) -> void:
	var len := int(dur * RATE)
	var ph := 0.0
	for i in range(len):
		var t := float(i) / len
		ph += TAU * lerpf(f0, f1, t) / RATE
		var env := (1.0 - t) * (1.0 - t) * minf(1.0, i / 60.0)
		var j := (at + i) % buf.size()
		buf[j] += sin(ph) * env * amp


# --- engine --------------------------------------------------------------------

## A lumpy V8 at a fixed rpm: firing harmonics, the cross-plane burble below
## them, a firing pulse per cylinder with a little misfire jitter, exhaust hiss.
## `bright` opens the filter up for the high-rpm layer.
static func engine(rpm: float, bright: float, seed_v: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var fire := rpm / 60.0 * 4.0  # 8 cylinders, 4-stroke
	var n := RATE  # 1 s: a whole number of quarter-firing cycles at the rpms we use
	var freqs: Array[float] = []
	var amps: Array[float] = []
	var phases: Array[float] = []
	for h in range(1, 13):
		freqs.append(fire * h)
		amps.append(1.0 / pow(h, 0.85) * rng.randf_range(0.7, 1.3))
		phases.append(rng.randf() * TAU)
	for sub: float in [0.25, 0.5, 0.75]:
		freqs.append(fire * sub)
		amps.append(0.45 if sub == 0.5 else 0.3)
		phases.append(rng.randf() * TAU)
	var pulses := PackedFloat32Array()
	for k in range(int(fire) + 2):
		pulses.append(1.0 + rng.randfn() * 0.12)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var hiss := 0.0
	for i in range(n):
		var t := float(i) / RATE
		var s := 0.0
		for h in range(freqs.size()):
			s += amps[h] * sin(TAU * freqs[h] * t + phases[h])
		var cyc := t * fire
		var pos := cyc - floorf(cyc)
		var pulse := exp(-pos * 9.0) * pulses[int(cyc)]
		hiss += (rng.randf_range(-1.0, 1.0) - hiss) * 0.3
		s = s * 0.35 + pulse * 1.2 + hiss * (0.25 + 0.6 * pulse) * (0.4 + bright)
		buf[i] = tanh(s * 0.9)
	_lowpass(buf, lerpf(700.0, 2400.0, bright), 0.9)
	_lowpass(buf, lerpf(1400.0, 4000.0, bright))
	_highpass(buf, 25.0)
	return _to_wav(buf, true)


# --- ground and water ---------------------------------------------------------

## Tires churning clay: a wet low rumble with sucking squelches popping out of it.
static func mud(seed_v: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var n := RATE * 2
	var buf := _noise(n, rng)
	_lowpass(buf, 260.0)
	_lowpass(buf, 260.0)
	for i in range(n):
		buf[i] *= 2.5
	for k in range(26):
		var f0 := rng.randf_range(160.0, 320.0)
		_blip(buf, rng.randi() % n, f0, f0 * 0.4, rng.randf_range(0.06, 0.16), rng.randf_range(0.3, 0.8))
	# slap of clods
	var slap := _noise(n, rng)
	_lowpass(slap, 1200.0)
	var env := 0.0
	for i in range(n):
		if rng.randf() < 0.0009:
			env = rng.randf_range(0.3, 0.7)
		env *= 0.996
		buf[i] += slap[i] * env
	return _to_wav(buf, true)


## Rolling on gravel: a carpet of tiny stone clicks over road rumble.
static func gravel(seed_v: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var n := RATE * 2
	var rumble := _noise(n, rng)
	_lowpass(rumble, 180.0)
	var clicks := PackedFloat32Array()
	clicks.resize(n)
	for k in range(900):
		var at := rng.randi() % n
		var amp := rng.randf_range(0.2, 1.0)
		for i in range(rng.randi_range(20, 70)):
			clicks[(at + i) % n] += rng.randf_range(-1.0, 1.0) * amp * exp(-i / 12.0)
	_highpass(clicks, 1200.0)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in range(n):
		buf[i] = rumble[i] * 1.6 + clicks[i] * 0.5
	return _to_wav(buf, true)


## Pushing through water: broadband swash rising and falling, with low slaps.
static func water(seed_v: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var n := RATE * 3
	var hi := _noise(n, rng)
	_highpass(hi, 350.0)
	_lowpass(hi, 3500.0)
	var lo := _noise(n, rng)
	_lowpass(lo, 140.0)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in range(n):
		var t := float(i) / n
		# swells that complete a whole number of cycles per loop
		var swell := 0.55 + 0.25 * sin(TAU * 3.0 * t) + 0.2 * sin(TAU * 7.0 * t + 1.3)
		buf[i] = hi[i] * swell + lo[i] * 3.0
	for k in range(10):
		_blip(buf, rng.randi() % n, rng.randf_range(90.0, 140.0), 50.0, 0.25, 0.6)
	return _to_wav(buf, true)


## Winch motor under load: a sawtooth whine with gear mesh on top.
static func winch() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var n := RATE
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in range(n):
		var t := float(i) / RATE
		var s := 0.0
		for h in range(1, 9):
			s += sin(TAU * 140.0 * h * t) / h
		s += 0.35 * sin(TAU * 560.0 * t) * (0.5 + 0.5 * sin(TAU * 20.0 * t))
		buf[i] = s + rng.randf_range(-1.0, 1.0) * 0.15
	_lowpass(buf, 2500.0)
	return _to_wav(buf, true)


# --- ambience -----------------------------------------------------------------

## Paddies by the lake: frogs (palaka) croaking in groups, crickets, a breeze.
static func paddy_ambience() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 501
	var n := RATE * 10
	var buf := _noise(n, rng)
	_lowpass(buf, 400.0)
	for i in range(n):
		buf[i] *= 0.35 * (0.7 + 0.3 * sin(TAU * 2.0 * i / n))
	# frogs: buzzy pulse trains at a few pitches
	for frog in range(5):
		var pitch := rng.randf_range(220.0, 520.0)
		var at := rng.randi() % n
		for call in range(rng.randi_range(3, 7)):
			var start := at + call * int(rng.randf_range(0.55, 1.2) * RATE)
			var len := int(rng.randf_range(0.12, 0.22) * RATE)
			var amp := rng.randf_range(0.2, 0.45)
			for i in range(len):
				var t := float(i) / RATE
				var env := sin(PI * float(i) / len)
				var buzz := signf(sin(TAU * pitch * t)) * (0.5 + 0.5 * sin(TAU * 28.0 * t))
				buf[(start + i) % n] += buzz * env * amp
	# crickets: high chirps in pairs
	for c in range(40):
		var at := rng.randi() % n
		var f := rng.randf_range(4200.0, 5200.0)
		for rep in range(2):
			for i in range(int(0.04 * RATE)):
				var t := float(i) / RATE
				buf[(at + rep * int(0.09 * RATE) + i) % n] += sin(TAU * f * t) * sin(PI * t / 0.04) * 0.08
	return _to_wav(buf, true)


## Secondary forest: cicada (kuliglig) choruses swelling in and out, birdsong,
## wind in the canopy.
static func forest_ambience() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 502
	var n := RATE * 10
	var buf := _noise(n, rng)
	_lowpass(buf, 700.0)
	_highpass(buf, 80.0)
	for i in range(n):
		buf[i] *= 0.3 * (0.6 + 0.4 * sin(TAU * 3.0 * i / n + 0.4))
	# cicadas: a tight cluster of high tones, buzzing at ~70 Hz, swelling
	var tones := [4300.0, 4420.0, 4610.0, 4900.0]
	for i in range(n):
		var t := float(i) / RATE
		var swell := pow(maxf(0.0, sin(TAU * 2.0 * i / n)), 2.0)
		var buzz := 0.5 + 0.5 * sin(TAU * 70.0 * t)
		var s := 0.0
		for f: float in tones:
			s += sin(TAU * f * t)
		buf[i] += s * 0.035 * swell * buzz
	# birds: rising whistles in short phrases
	for bird in range(9):
		var at := rng.randi() % n
		var base := rng.randf_range(2000.0, 3200.0)
		for note in range(rng.randi_range(2, 5)):
			var start := at + note * int(rng.randf_range(0.12, 0.2) * RATE)
			var dur := rng.randf_range(0.06, 0.12)
			var len := int(dur * RATE)
			var ph := 0.0
			var f0 := base * rng.randf_range(0.9, 1.1)
			var f1 := f0 * rng.randf_range(1.15, 1.5)
			for i in range(len):
				var u := float(i) / len
				ph += TAU * lerpf(f0, f1, u) / RATE
				buf[(start + i) % n] += sin(ph) * sin(PI * u) * 0.22
	return _to_wav(buf, true)


# --- one-shots ------------------------------------------------------------------

## Driveline clunk: diff lock, transfer case, winch clutch.
static func clunk() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var n := int(RATE * 0.35)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in range(n):
		var t := float(i) / RATE
		buf[i] = sin(TAU * 85.0 * t) * exp(-t * 18.0) + sin(TAU * 1150.0 * t) * exp(-t * 40.0) * 0.4 + rng.randf_range(-1.0, 1.0) * exp(-t * 60.0) * 0.5
	return _to_wav(buf, false)


## Hitting water at speed: a heavy slap and a falling shower.
static func splash() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 10
	var n := int(RATE * 1.4)
	var buf := _noise(n, rng)
	_lowpass(buf, 3000.0)
	for i in range(n):
		var t := float(i) / RATE
		buf[i] *= exp(-t * 2.8) * (0.4 + 0.6 * exp(-t * 12.0))
		buf[i] += sin(TAU * 70.0 * t) * exp(-t * 10.0) * 1.2
	return _to_wav(buf, false)
