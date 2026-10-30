class_name Gearbox
extends RefCounted
## Engine, clutch and gears between the throttle and the tires.
##
## The engine makes torque along a curve (idle .. peak .. redline) that goes
## through the gear, the final drive and the transfer case (low range) to the
## wheels. Off the throttle in gear the engine holds the rig back: engine
## braking, strongest in low range, which is what keeps a rig crawling down
## a steep pitch instead of running away. Auto by default (shifts on rpm);
## E / Q shift up and down by hand and switch it to manual, T back to auto.
## In manual you can lug it: at idle against something it can't move in too
## tall a gear, it stalls; throttle cranks it again.
##
## The clutch looks after itself: it slips to pull away and lets go while
## you brake (the driver's left foot), so the rig never drags its engine to
## a stop at a standstill.

# from the RigSpec
var torque_nm := 350.0
var peak_rpm := 2800.0
var idle_rpm := 750.0
var redline := 4800.0
var gears: Array[float] = [4.02, 2.41, 1.41, 1.0]
var reverse_ratio := 4.0
var final_drive := 4.56
var low_ratio := 2.72
var efficiency := 0.85

var gear := 1               # 1.. forward, -1 reverse
var auto := true
var rpm := 750.0
var running := true
var shifting := 0.0         # s left in a shift: no drive while the clutch is out
var torque_out := 0.0       # N·m at the flywheel this step (+ drive, - engine braking)
var power := 1.0            # what's left of the torque (damage: wear, limp mode)
var seized := false         # hydrolocked or cooked: it won't crank
var _crank := 0.0
var _lugging := 0.0


func setup(spec: RigSpec) -> void:
	torque_nm = spec.torque_nm
	peak_rpm = spec.peak_rpm
	idle_rpm = spec.idle_rpm
	redline = spec.redline
	gears = spec.gears
	reverse_ratio = spec.reverse_ratio
	final_drive = spec.final_drive
	low_ratio = spec.low_ratio
	rpm = idle_rpm


## Overall reduction engine -> wheel in the current gear and range.
func ratio(low_range: bool) -> float:
	var g := reverse_ratio if gear < 0 else gears[gear - 1]
	return g * final_drive * (low_ratio if low_range else 1.0)


## Engine torque at full throttle and `r` rpm: builds from idle to the peak,
## tails off toward the redline.
func curve(r: float) -> float:
	if r <= peak_rpm:
		return torque_nm * lerpf(0.62, 1.0, smoothstep(idle_rpm * 0.6, peak_rpm, r))
	return torque_nm * lerpf(1.0, 0.72, clampf((r - peak_rpm) / (redline - peak_rpm), 0.0, 1.0))


func shift(step: int) -> void:
	auto = false
	if gear < 0:
		gear = 1
		return
	var g := clampi(gear + step, 1, gears.size())
	if g != gear:
		gear = g
		shifting = 0.3


## One physics step. `throttle` 0..1, `reverse` asks for reverse (the brake
## held at a standstill), `braking` means the driver is on the brake (clutch
## in). `v_fwd` the rig's speed along its nose, `r` the tire's rolling radius,
## `slip` how much the driven tires are spinning (0..1). Returns the total
## drive force at the tires, N (+ forward), and keeps `rpm` for the sound.
func step(delta: float, throttle: float, reverse: bool, braking: bool, low_range: bool,
		v_fwd: float, r: float, slip: float) -> float:
	torque_out = 0.0
	# reverse at a standstill on the brake, forward again on the throttle
	if reverse and gear > 0 and absf(v_fwd) < 0.6:
		gear = -1
		shifting = 0.25
	elif not reverse and gear < 0 and (throttle > 0.0 or v_fwd > 0.6):
		gear = 1
		shifting = 0.25
	var pedal := throttle
	var dir := -1.0 if gear < 0 else 1.0
	var k := ratio(low_range)
	# the rpm the wheels would turn the engine at (it can't turn backwards)
	var wheel_rpm := maxf(0.0, v_fwd * dir / r) * k * 60.0 / TAU

	if not running:
		rpm = move_toward(rpm, 0.0, 3000.0 * delta)
		if seized:
			_crank = 0.0
			return 0.0
		if throttle > 0.3:
			_crank += delta
			rpm = 180.0 + 60.0 * sin(_crank * 40.0)   # turning over
			if _crank > 0.7:
				running = true
				rpm = idle_rpm * 1.3
				_crank = 0.0
		else:
			_crank = 0.0
		return 0.0

	if shifting > 0.0:
		shifting -= delta
		rpm = lerpf(rpm, maxf(idle_rpm, wheel_rpm), 1.0 - exp(-delta * 10.0))
		return 0.0

	if braking:
		# clutch in: the engine just idles (or revs if you blip it); the
		# automatic drops to first as you come to a stop
		if auto and gear > 1 and wheel_rpm < idle_rpm:
			gear = 1
		rpm = lerpf(rpm, idle_rpm + pedal * (peak_rpm - idle_rpm) * 0.5, 1.0 - exp(-delta * 6.0))
		_lugging = 0.0
		return 0.0

	# the idle governor: at no throttle the engine still holds idle, so a
	# rig in low first crawls along on its own
	var gov := clampf((idle_rpm * 1.05 - wheel_rpm) / (idle_rpm * 0.3), 0.0, 0.32)
	var open := maxf(pedal, gov)
	var target: float
	if wheel_rpm < idle_rpm:
		# pulling away: the clutch slips, the engine sits above idle
		target = maxf(idle_rpm + pedal * (peak_rpm - idle_rpm) * 0.55, wheel_rpm)
	else:
		target = wheel_rpm
	# spinning tires let the engine rev toward where the throttle wants it
	target = lerpf(target, idle_rpm + pedal * (redline - idle_rpm) * 0.85, clampf(slip, 0.0, 1.0) * pedal)
	rpm = lerpf(rpm, target, 1.0 - exp(-delta * 12.0))

	var t := curve(rpm) * open * power
	if wheel_rpm > redline:
		t = 0.0   # fuel cut
	# engine braking: pumping and friction hold the rig back off the throttle
	if wheel_rpm > idle_rpm * 1.1:
		t -= torque_nm * (0.1 + 0.3 * minf(wheel_rpm / redline, 1.4)) * (1.0 - pedal)
	torque_out = t

	# lugging: in manual, at idle, the engine can't turn the wheels at all
	if not auto and pedal < 0.05 and wheel_rpm < idle_rpm * 0.35 and absf(v_fwd) < 0.3:
		_lugging += delta
		if _lugging > 1.2 and gear > 1:
			running = false
			_lugging = 0.0
			return 0.0
	else:
		_lugging = 0.0

	if auto:
		_auto_shift(throttle, wheel_rpm, slip)
	return dir * t * k * efficiency / r


## Shift on road speed (what the wheels turn the engine at), never on a
## flare from wheelspin: spinning in the mud it holds the gear it's in.
func _auto_shift(throttle: float, wheel_rpm: float, slip: float) -> void:
	if gear < 0:
		return
	if wheel_rpm > redline * 0.88 and gear < gears.size() and throttle > 0.2 and slip < 0.3:
		gear += 1
		shifting = 0.3
	elif gear > 1 and wheel_rpm < maxf(idle_rpm * 1.5, peak_rpm * 0.5):
		gear -= 1
		shifting = 0.2


## e.g. "2nd" / "R"
func gear_name() -> String:
	if gear < 0:
		return "R"
	return ["1st", "2nd", "3rd", "4th", "5th", "6th"][gear - 1]
