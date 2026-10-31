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


# --- engine: EngineSynth (each rig's own) ------------------------------------------


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
# The beds loop, so they hold nothing you could pick out and notice repeating:
# just air and a distant insect wash. Every animal is a separate call that
# RigAudio scatters around the listener at random.

## Paddies by the lake: breeze over the rice, a faint far-off insect wash.
static func paddy_bed() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 501
	var n := RATE * 12
	var buf := _noise(n, rng)
	_lowpass(buf, 450.0)
	var hiss := _noise(n, rng)
	_bandpass(hiss, 5200.0, 2.0)
	for i in range(n):
		var t := float(i) / n
		buf[i] = buf[i] * (0.65 + 0.2 * sin(TAU * 2.0 * t) + 0.15 * sin(TAU * 5.0 * t + 2.0)) + hiss[i] * 0.03
	return _to_wav(buf, true)


## Secondary forest: wind moving through the canopy, a distant cicada hiss.
static func forest_bed() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 502
	var n := RATE * 12
	var buf := _noise(n, rng)
	_lowpass(buf, 650.0)
	_highpass(buf, 60.0)
	var hiss := _noise(n, rng)
	_bandpass(hiss, 4600.0, 2.5)
	for i in range(n):
		var t := float(i) / n
		buf[i] = buf[i] * (0.55 + 0.3 * sin(TAU * 3.0 * t + 0.4) + 0.15 * sin(TAU * 7.0 * t)) + hiss[i] * 0.04
	return _to_wav(buf, true)


## Rain: the steady hiss of drops on leaves and ground (broadband, soft at
## the top), with a patter of nearer drops picked out over it, and a low
## roar under heavy rain. Loops; Weather sets the volume.
static func rain() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 610
	var n := RATE * 6
	var hiss := _noise(n, rng)
	_highpass(hiss, 700.0)
	_lowpass(hiss, 7500.0)
	var roar := _noise(n, rng)
	_lowpass(roar, 300.0)
	var buf := _zeros(n)
	for i in range(n):
		var t := float(i) / n
		# gusts: the rain sheets come and go a little
		var gust := 0.8 + 0.12 * sin(TAU * 2.0 * t + 0.7) + 0.08 * sin(TAU * 5.0 * t)
		buf[i] = hiss[i] * 0.55 * gust + roar[i] * 0.9
	# individual drops close by: a short tick on a leaf, a duller tap on the ground
	for k in range(2600):
		_burst(buf, rng.randi() % n, rng.randf_range(0.006, 0.02), rng.randf_range(1800.0, 5200.0), 3.0,
			rng.randf_range(0.05, 0.22), rng, 9.0)
	for k in range(500):
		_burst(buf, rng.randi() % n, 0.03, rng.randf_range(500.0, 1100.0), 2.5, rng.randf_range(0.08, 0.2), rng, 7.0)
	return _to_wav(buf, true)


## Distant thunder: a low rumble that rolls in, grumbles on and dies away.
static func thunder(seed_v: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var n := int(RATE * rng.randf_range(4.0, 6.0))
	var buf := _noise(n, rng)
	_lowpass(buf, 120.0)
	_lowpass(buf, 160.0)
	var crackle := _noise(n, rng)
	_bandpass(crackle, 420.0, 0.8)
	for i in range(n):
		var t := float(i) / n
		var env := smoothstep(0.0, 0.08, t) * exp(-t * 2.2) * (0.75 + 0.25 * sin(t * 37.0 + seed_v))
		buf[i] = (buf[i] * 5.0 + crackle[i] * 0.4 * exp(-t * 6.0)) * env
	return _to_wav(buf, false)


## One palaka bout: a run of knocking croaks at one frog's pitch.
static func frog_call(seed_v: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var pitch := rng.randf_range(420.0, 1150.0)
	var calls := rng.randi_range(2, 8)
	var gap := rng.randf_range(0.08, 0.17)
	var buf := _zeros(int((calls * gap + 0.2) * RATE))
	for k in range(calls):
		_burst(buf, int(k * gap * RATE), rng.randf_range(0.025, 0.055), pitch * rng.randf_range(0.97, 1.03), rng.randf_range(5.0, 9.0), rng.randf_range(0.6, 1.0), rng, 5.0)
	return _to_wav(buf, false)


## One bird phrase: a few whistled notes with a natural wobble.
static func bird_call(seed_v: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var notes := rng.randi_range(2, 6)
	var base := rng.randf_range(1800.0, 3400.0)
	var buf := _zeros(int((notes * 0.26 + 0.2) * RATE))
	var at := 0
	var up := rng.randf() < 0.5
	for note in range(notes):
		var len := int(rng.randf_range(0.06, 0.16) * RATE)
		var f0 := base * rng.randf_range(0.9, 1.1)
		var f1 := f0 * (rng.randf_range(1.1, 1.45) if up else rng.randf_range(0.7, 0.92))
		var ph := 0.0
		for i in range(len):
			var u := float(i) / len
			ph += TAU * lerpf(f0, f1, u) * (1.0 + 0.03 * sin(TAU * 32.0 * float(i) / RATE)) / RATE
			var env := sin(PI * u) * sin(PI * u)
			buf[at + i] += (sin(ph) + 0.18 * sin(2.0 * ph)) * env
		at += len + int(rng.randf_range(0.05, 0.1) * RATE)
	_lowpass(buf, 7000.0)
	return _to_wav(buf, false)


## A cricket: a short trill of tight pulses.
static func cricket_call(seed_v: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var pulses := rng.randi_range(3, 14)
	var rate := rng.randf_range(0.025, 0.045)
	var f := rng.randf_range(4200.0, 5400.0)
	var buf := _zeros(int((pulses * rate + 0.1) * RATE))
	for k in range(pulses):
		_burst(buf, int(k * rate * RATE), 0.016, f, 14.0, 1.0, rng, 3.0)
	return _to_wav(buf, false)


## A kuliglig chorus: a buzz that swells over a few seconds and dies away.
static func cicada_call(seed_v: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var dur := rng.randf_range(4.0, 8.0)
	var n := int(dur * RATE)
	var buf := _noise(n, rng)
	_bandpass(buf, rng.randf_range(4200.0, 5200.0), 3.0)
	var buzz_hz := rng.randf_range(80.0, 120.0)
	var peak := rng.randf_range(0.3, 0.6)
	for i in range(n):
		var u := float(i) / n
		var env := smoothstep(0.0, peak, u) * (1.0 - smoothstep(peak + 0.2, 1.0, u))
		buf[i] *= env * pow(0.5 + 0.5 * sin(TAU * buzz_hz * float(i) / RATE), 3.0)
	return _to_wav(buf, false)


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
