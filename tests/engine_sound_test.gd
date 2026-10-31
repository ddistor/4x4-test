extends Node
## Bakes every engine and checks it against the physics: how long each takes,
## and which engine orders (multiples of half the crank speed) carry the most
## energy - a four-stroke's firing order is cylinders / 2, so a V8's loudest
## should be order 4, a six's 3, a four's 2. Writes each engine's loops as WAV
## files into snaps/ to listen to:
##   godot --headless --path . res://tests/engine_sound_test.tscn [-- --kind v8]
const KINDS := {"v8": [750.0, 4800.0], "v6": [700.0, 6400.0], "i6": [650.0, 4000.0], "i4": [800.0, 6000.0],
	"i6d": [650.0, 4000.0], "i4d": [700.0, 4000.0]}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var only := args[args.find("--kind") + 1] if args.has("--kind") else ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://snaps/engine"))
	var ok := true
	for kind: String in KINDS:
		if only != "" and kind != only:
			continue
		var t0 := Time.get_ticks_msec()
		var eng := EngineSynth.build(kind, KINDS[kind][0], KINDS[kind][1])
		var ms := Time.get_ticks_msec() - t0
		var cyl: int = EngineSynth.ENGINES[kind]["order"].size()
		var line := "%s: %d loops in %d ms;" % [kind, eng["rpm"].size() * 4, ms]
		for i in range(eng["rpm"].size()):
			var rpm: float = eng["rpm"][i]
			for key: String in ["ex_on", "ex_off", "in_on"]:
				var w: AudioStreamWAV = eng[key][i]
				w.save_to_wav("res://snaps/engine/%s_%04d_%s.wav" % [kind, int(rpm), key])
			if i == 1:
				var top := _orders(eng["ex_on"][i], rpm)
				line += " exhaust at %d rpm, strongest orders %s (firing order %.1f)" % [int(rpm), str(top), cyl / 2.0]
				if not top.has(cyl / 2.0):
					ok = false
		print(line)
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


## The three strongest half-orders in a loop (magnitude by a plain DFT at
## each order's frequency, over orders 0.5 .. 8).
func _orders(w: AudioStreamWAV, rpm: float) -> Array:
	var data := w.data
	var n := data.size() / 2
	var mags := []
	for h in range(1, 17):
		var f := rpm / 60.0 * h * 0.5
		var re := 0.0
		var im := 0.0
		for i in range(0, n, 2):
			var x := data.decode_s16(i * 2) / 32768.0
			var a := TAU * f * i / SoundSynth.RATE
			re += x * cos(a)
			im += x * sin(a)
		mags.append([sqrt(re * re + im * im), h * 0.5])
	mags.sort_custom(func(a, b): return a[0] > b[0])
	return [mags[0][1], mags[1][1], mags[2][1]]
