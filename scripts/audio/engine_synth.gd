class_name EngineSynth
extends RefCounted
## Each rig's own engine, synthesised from how an engine makes its sound
## (no recordings): every cylinder's exhaust blowdown is a pressure pulse,
## timed by the real firing order and crank angles, that travels down its
## header (bank by bank on a V) into one pipe, rings in the pipe, the muffler
## and the tailpipe at their own fixed lengths, and radiates from the tail.
## Up front, the intake strokes pull pulses through the snorkel and airbox,
## with induction roar as the throttle opens; the block adds its own:
## valvetrain tick on a petrol, combustion knock and the pump's tick on a diesel.
##
## Baked at startup into loops across the rev range (a whole number of engine
## cycles each, so they loop clean), on load and off load. The resonances
## stay where the pipes put them; RigAudio only nudges each loop's pitch to
## the rpm between two of them and crossfades.
##
## Figures: firing frequency = rpm x cylinders / 120 (four-stroke); sound in
## hot exhaust ~480-520 m/s, ~420 near the tail, 343 in the intake; blowdown
## lasts ~30-100 crank degrees; a cross-plane V8's banks fire unevenly
## (gaps of 270/180/90/180 deg per bank) which with unequal pipe runs is the
## burble; diesel knock rings the block at roughly 1-2.5 kHz, loudest at idle.

const RATE := SoundSynth.RATE
const C_HOT := 500.0     # m/s, sound in the hot pipe
const C_TAIL := 420.0    # cooler toward the tail
const C_AIR := 343.0

## Per engine (CabinKit LAYOUT's kinds): firing order (cylinder numbers), the
## bank each cylinder exhausts into (V engines: odd left, even right),
## crank angle between firings, header run per cylinder (m), the crossover
## that one bank's gas takes to reach the merge (m), pipe to the muffler,
## muffler chamber, tailpipe (m), the muffler's cut-off (Hz), litres,
## diesel, idle irregularity.
const ENGINES := {
	"v8": {"order": [1, 8, 4, 3, 6, 5, 7, 2], "v": true, "cross": 0.55, "header": [0.55, 0.6, 0.62, 0.66, 0.7, 0.74, 0.78, 0.82],
		"pipe": 1.7, "muffler": 0.45, "tail": 0.55, "cut": 650.0, "litres": 5.7, "diesel": false, "lumpy": 0.09},
	"v6": {"order": [1, 2, 3, 4, 5, 6], "v": true, "cross": 0.45, "header": [0.42, 0.45, 0.5, 0.52, 0.58, 0.6],
		"pipe": 2.1, "muffler": 0.5, "tail": 0.5, "cut": 520.0, "litres": 3.6, "diesel": false, "lumpy": 0.04},
	"i6": {"order": [1, 5, 3, 6, 2, 4], "v": false, "cross": 0.0, "header": [0.85, 0.76, 0.67, 0.58, 0.49, 0.4],
		"pipe": 1.8, "muffler": 0.45, "tail": 0.5, "cut": 460.0, "litres": 4.2, "diesel": false, "lumpy": 0.04},
	"i4": {"order": [1, 3, 4, 2], "v": false, "cross": 0.0, "header": [0.62, 0.52, 0.48, 0.4],
		"pipe": 1.6, "muffler": 0.4, "tail": 0.45, "cut": 720.0, "litres": 1.6, "diesel": false, "lumpy": 0.05},
	"i6d": {"order": [1, 5, 3, 6, 2, 4], "v": false, "cross": 0.0, "header": [0.85, 0.76, 0.67, 0.58, 0.49, 0.4],
		"pipe": 2.2, "muffler": 0.5, "tail": 0.55, "cut": 380.0, "litres": 4.2, "diesel": true, "lumpy": 0.03},
	"i4d": {"order": [1, 3, 4, 2], "v": false, "cross": 0.0, "header": [0.62, 0.52, 0.48, 0.4],
		"pipe": 1.9, "muffler": 0.45, "tail": 0.5, "cut": 420.0, "litres": 2.8, "diesel": true, "lumpy": 0.04},
}


## Bump when the synthesis changes, so cached engines are made again.
const CACHE_VERSION := 1


## An engine's loops from the cache in user://, or {} if it isn't there yet.
static func load_cached(kind: String, idle: float, redline: float) -> Dictionary:
	var dir := _cache_dir(kind, idle, redline)
	var cfg := ConfigFile.new()
	if cfg.load(dir + "/meta.cfg") != OK:
		return {}
	var out := {"rpm": cfg.get_value("engine", "rpm"), "litres": cfg.get_value("engine", "litres"),
		"diesel": cfg.get_value("engine", "diesel")}
	for key: String in ["ex_on", "ex_off", "in_on", "in_off"]:
		var list := []
		for i in range(out["rpm"].size()):
			var w := load("%s/%s_%d.res" % [dir, key, i]) as AudioStreamWAV
			if w == null:
				return {}
			list.append(w)
		out[key] = list
	return out


## Keep an engine's loops so the next drive doesn't bake them again.
static func save_cached(kind: String, idle: float, redline: float, eng: Dictionary) -> void:
	var dir := _cache_dir(kind, idle, redline)
	DirAccess.make_dir_recursive_absolute(dir)
	for key: String in ["ex_on", "ex_off", "in_on", "in_off"]:
		for i in range(eng[key].size()):
			ResourceSaver.save(eng[key][i], "%s/%s_%d.res" % [dir, key, i])
	var cfg := ConfigFile.new()
	cfg.set_value("engine", "rpm", eng["rpm"])
	cfg.set_value("engine", "litres", eng["litres"])
	cfg.set_value("engine", "diesel", eng["diesel"])
	cfg.save(dir + "/meta.cfg")


static func _cache_dir(kind: String, idle: float, redline: float) -> String:
	return "user://engine_sound/%s_%d_%d_v%d" % [kind, int(idle), int(redline), CACHE_VERSION]


## The rev points the loops are baked at, idle to just past the redline,
## no more than ~35% apart (so no loop is pitched far from where it was made).
static func rev_points(idle: float, redline: float) -> PackedFloat32Array:
	var pts := PackedFloat32Array()
	var top := redline * 1.05
	var n := maxi(2, int(ceil(log(top / idle) / log(1.35))) + 1)
	for k in range(n):
		pts.append(idle * pow(top / idle, float(k) / (n - 1)))
	return pts


## Everything one engine needs: per rev point the exhaust and the front
## (intake and block) loops, on load and off, with the rpm each was truly
## made at. {"rpm": [...], "ex_on": [...], "ex_off": [...], "in_on": [...], "in_off": [...], "litres"}
static func build(kind: String, idle: float, redline: float, seed_v := 1) -> Dictionary:
	var e: Dictionary = ENGINES.get(kind, ENGINES["v8"])
	var pts := rev_points(idle, redline)
	var out := {"rpm": [], "ex_on": [], "ex_off": [], "in_on": [], "in_off": [], "litres": e["litres"], "diesel": e["diesel"]}
	var raw := {"ex_on": [], "ex_off": [], "in_on": [], "in_off": []}
	for k in range(pts.size()):
		# a whole number of engine cycles (two turns each), about a second long
		var cyc := maxi(4, int(round(1.0 * pts[k] / 120.0)))
		var n := int(round(cyc * 120.0 / pts[k] * RATE))
		var rpm := cyc * 120.0 * RATE / n
		out["rpm"].append(rpm)
		for load: float in [1.0, 0.0]:
			var pair := _bake(e, rpm, load, n, cyc, seed_v + k * 7 + int(load))
			raw["ex_on" if load > 0.5 else "ex_off"].append(pair[0])
			raw["in_on" if load > 0.5 else "in_off"].append(pair[1])
	# one gain per layer for the whole engine, so loud stays loud and idle quiet
	for layer: String in ["ex", "in"]:
		var peak := 1e-6
		for key: String in [layer + "_on", layer + "_off"]:
			for b: PackedFloat32Array in raw[key]:
				for v in b:
					peak = maxf(peak, absf(v))
		for key: String in [layer + "_on", layer + "_off"]:
			for b: PackedFloat32Array in raw[key]:
				out[key].append(_wav(b, 0.89 / peak))
	return out


## One rev point at one load: [exhaust at the tail, intake and block up front].
static func _bake(e: Dictionary, rpm: float, load: float, n: int, cycles: int, seed_v: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var order: Array = e["order"]
	var cyl := order.size()
	var diesel: bool = e["diesel"]
	var deg_s := rpm * 6.0                       # crank degrees a second
	var gap := 720.0 / cyl                       # between firings
	var hi := clampf((rpm - 700.0) / 4000.0, 0.0, 1.0)
	# how hard each cylinder blows down: the charge it burnt. A petrol off
	# the throttle has little in it; a diesel off the fuel still pushes out
	# the air it compressed.
	var strength := (1.0 if load > 0.5 else (0.3 if diesel else 0.22))
	var per_cyl := []   # a cylinder's own small difference (rings, valves, cam)
	for c in range(cyl):
		per_cyl.append(1.0 + rng.randfn() * 0.05)
	# the loop is made twice over and the second pass kept, so every pipe is
	# already ringing from the pass before when the loop starts: no seam
	var m := n * 2
	var ex := [SoundSynth._zeros(m), SoundSynth._zeros(m)]   # per bank, at the merge
	var front := SoundSynth._zeros(m)
	var blow := clampf(70.0 / deg_s, 0.0015, 0.05)          # blowdown, ~70 crank deg
	var rise := blow * 0.22
	var lumpy: float = e["lumpy"] * (1.0 - hi * 0.7)
	for c in range(cycles):
		var cyc_amp := 1.0 + rng.randfn() * lumpy
		for k in range(cyl):
			var num: int = order[k]
			var bank := (0 if num % 2 == 1 else 1) if e["v"] else 0
			var amp: float = strength * per_cyl[num - 1] * cyc_amp * (1.0 + rng.randfn() * lumpy * 0.6)
			var fire_t := (c * 720.0 + k * gap) / deg_s + rng.randfn() * 0.00008
			# exhaust valve opens ~130 deg after firing; the pulse runs down its header
			var t0 := fire_t + 130.0 / deg_s + float(e["header"][num - 1]) / C_HOT
			if bank == 1:
				t0 += float(e["cross"]) / C_HOT
			for p in range(2):
				_pulse(ex[bank], (t0 + p * n / float(RATE)), rise, amp, (0.25 + 0.35 * load) * amp, rng)
			# overrun: a rich mix lighting in the hot pipe now and then
			if not diesel and load < 0.5 and rpm > 1800.0 and rng.randf() < 0.012:
				for p in range(2):
					_crack(ex[bank], t0 + 0.004 + p * n / float(RATE), 0.9 + rng.randf() * 0.6, rng)
			# intake: the stroke ~360 deg before firing draws a pulse back up
			# the intake, as strong as the throttle lets air through
			var flow := (0.35 + 0.65 * load) if diesel else (0.12 + 0.88 * load)
			var ti := fire_t - 330.0 / deg_s
			for p in range(2):
				_pulse(front, ti + p * n / float(RATE), rise * 1.4, -0.45 * flow, 0.1 * flow, rng)
			# the block: diesel knock as the injected fuel lights all at once
			# (sharpest at idle and on load), the pump's tick; a petrol's
			# combustion thud and its valves ticking
			for p in range(2):
				var at := fire_t + p * n / float(RATE)
				if diesel:
					var knock := (1.0 if load > 0.5 else 0.12) * lerpf(1.0, 0.5, hi) * (1.0 + rng.randfn() * 0.1)
					_ring(front, at, [1350.0, 2250.0, 3400.0], [0.6, 0.45, 0.2], 0.0045, knock * 0.55, rng)
					_ring(front, at - 12.0 / deg_s, [3800.0], [1.0], 0.0012, 0.08, rng)
				else:
					_ring(front, at, [650.0], [1.0], 0.006, 0.07 * strength, rng)
					_ring(front, at + gap * 0.5 / deg_s, [5200.0], [1.0], 0.0008, 0.025, rng)
	# --- the exhaust: merge, pipe, muffler, tailpipe, out into the air ----------
	var pipe: PackedFloat32Array = ex[0]
	for i in range(m):
		pipe[i] += ex[1][i]
	# turbulence: the gas tearing through, more of it the harder it flows
	var hiss := SoundSynth._noise(m, rng)
	SoundSynth._bandpass(hiss, 1800.0, 0.7)
	var env: PackedFloat32Array = pipe.duplicate()
	SoundSynth._lowpass(env, 60.0)
	for i in range(m):
		pipe[i] += hiss[i] * absf(env[i]) * (0.8 + 1.2 * load)
	# each section rings at its own length; where it widens into the muffler,
	# or opens to the air, the wave comes back inverted
	_tube(pipe, float(e["pipe"]), C_HOT, -0.6, 0.5)
	SoundSynth._lowpass(pipe, float(e["cut"]), 0.9)
	_tube(pipe, float(e["muffler"]), C_HOT, -0.45, 0.4)
	_tube(pipe, float(e["tail"]), C_TAIL, -0.55, 0.6)
	_radiate(pipe)
	SoundSynth._lowpass(pipe, 7000.0)
	SoundSynth._highpass(pipe, 28.0)
	# --- up front: snorkel and airbox, induction roar, the block -----------------
	var roar := SoundSynth._noise(m, rng)
	SoundSynth._bandpass(roar, 2400.0, 0.8)
	var air := ((0.35 + 0.65 * load) if diesel else (0.1 + 0.9 * load)) * (0.2 + 0.8 * hi)
	for i in range(m):
		front[i] += roar[i] * 0.06 * air
	_tube(front, 0.7, C_AIR, -0.6, 0.5)
	SoundSynth._lowpass(front, 9000.0)
	SoundSynth._highpass(front, 35.0)
	# a four's second-order shake: a drone at twice crank speed through the body
	if cyl == 4:
		var f2 := rpm / 60.0 * 2.0
		for i in range(m):
			front[i] += sin(TAU * f2 * i / RATE) * 0.05
	return [_tanh(pipe.slice(n, m), 1.4), _tanh(front.slice(n, m), 1.2)]


## A blowdown: a fast rise and an exponential fall, `rise` to the peak, with
## a little turbulence riding on it. Wraps round the doubled buffer.
static func _pulse(buf: PackedFloat32Array, t0: float, rise: float, amp: float, noise: float, rng: RandomNumberGenerator) -> void:
	var m := buf.size()
	var start := int(t0 * RATE)
	var len := int(rise * 7.0 * RATE) + 2
	for i in range(len):
		var u := float(i) / (rise * RATE)
		var p := u * exp(1.0 - u)
		buf[(start + i + m * 4) % m] += amp * p + noise * p * rng.randf_range(-1.0, 1.0)


## An overrun pop: a sharp crack in the pipe.
static func _crack(buf: PackedFloat32Array, t0: float, amp: float, rng: RandomNumberGenerator) -> void:
	var m := buf.size()
	var start := int(t0 * RATE)
	for i in range(int(0.004 * RATE)):
		var t := float(i) / RATE
		buf[(start + i + m * 4) % m] += amp * (exp(-t / 0.0005) * 1.5 + rng.randf_range(-1.0, 1.0) * exp(-t / 0.0012))


## The block ringing: decaying partials at `freqs` with their weights.
static func _ring(buf: PackedFloat32Array, t0: float, freqs: Array, weights: Array, decay: float, amp: float, rng: RandomNumberGenerator) -> void:
	var m := buf.size()
	var start := int(t0 * RATE)
	var len := int(decay * 5.0 * RATE)
	var ph := rng.randf() * TAU
	for i in range(len):
		var t := float(i) / RATE
		var s := 0.0
		for j in range(freqs.size()):
			s += sin(TAU * float(freqs[j]) * t + ph * (j + 1)) * float(weights[j])
		s += rng.randf_range(-0.4, 0.4) * exp(-t / 0.0006)
		buf[(start + i + m * 4) % m] += amp * s * exp(-t / decay)


## A length of pipe: the wave runs to the far end and back (2L / c) and
## returns times `g` (negative where it opens up), losing its top end each
## trip (`damp`, 0 none .. 1 a lot). Resonates at fixed frequencies.
static func _tube(buf: PackedFloat32Array, length: float, c: float, g: float, damp: float) -> void:
	var d := maxi(1, int(round(2.0 * length / c * RATE)))
	var m := buf.size()
	var lp := 0.0
	var k := 1.0 - damp * 0.8
	var y: PackedFloat32Array = buf.duplicate()
	for i in range(d, m):
		lp += k * (y[i - d] - lp)
		y[i] = buf[i] + g * lp
	for i in range(m):
		buf[i] = y[i]


## What leaves an open pipe end rises with frequency (the radiated pressure
## goes with the rate of change of the flow), but a real tailpipe's firing
## order still leads its spectrum: so a shelf, flat below ~250 Hz and rising
## 6 dB an octave above, not a pure derivative.
static func _radiate(buf: PackedFloat32Array) -> void:
	var k := RATE / (TAU * 250.0)
	var prev := 0.0
	for i in range(buf.size()):
		var x := buf[i]
		buf[i] = x + (x - prev) * k
		prev = x


static func _tanh(buf: PackedFloat32Array, drive: float) -> PackedFloat32Array:
	for i in range(buf.size()):
		buf[i] = tanh(buf[i] * drive)
	return buf


static func _wav(buf: PackedFloat32Array, gain: float) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in range(buf.size()):
		bytes.encode_s16(i * 2, int(clampf(buf[i] * gain, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = buf.size()
	return w


## Gear whine: a tooth-mesh tone with its harmonics and a little roughness,
## made at 500 Hz; RigAudio pitches it to shaft speed x teeth.
static func whine() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var n := RATE / 2
	var buf := SoundSynth._zeros(n)
	var f := 500.0
	for i in range(n):
		var t := float(i) / RATE
		var wob := 1.0 + 0.15 * sin(TAU * 2.0 * t)
		buf[i] = (sin(TAU * f * t) + 0.35 * sin(TAU * f * 2.0 * t) + 0.12 * sin(TAU * f * 3.0 * t)) * wob
	var rough := SoundSynth._noise(n, rng)
	SoundSynth._bandpass(rough, f, 6.0)
	for i in range(n):
		buf[i] += rough[i] * 0.6
	return _wav(buf, 0.5)
