class_name RecoveryKit
extends Node3D
## What's in the back of the rig for getting unstuck without a winch anchor.
## Each only works stopped; while you're out doing it the rig won't drive.
##   1  Shovel: dig the soft mud out round and ahead of every tire, down to
##      firm ground, and pile it to the sides. For a rig bogged to the axles.
##   2  Traction boards: lay a pair in front of the front tires (behind the
##      rear ones in reverse): firm, grippy ramps out of the hole. 2 again
##      picks them up; they're collected anyway once you're well past them.
##   3  High-lift jack: jack the rig up off whatever it's hung on, pack rocks
##      under the tires that were hanging, nudge it on a little the way it's
##      facing and let it down onto them. For a high-centre.

const DIG_TIME := 6.0
const JACK_TIME := 5.0
const JACK_LIFT := 0.5
const JACK_SHOVE := 0.3
const STACK := 0.28       # m of rock packed under a tire that was hanging
const BOARD_SIZE := Vector3(0.38, 0.05, 1.15)

var rig: Rig
var busy := 0.0          # seconds left in the job in hand
var job := ""
var _boards: Array[StaticBody3D] = []
var _board_mat: StandardMaterial3D
var _jack_from: Transform3D
var _jack_dir := Vector3.ZERO
var _stacked := 0
var _note := ""
var _note_t := 0.0


func setup(r: Rig) -> void:
	rig = r
	_board_mat = StandardMaterial3D.new()
	_board_mat.albedo_color = Color(0.85, 0.42, 0.06)   # the orange ones
	_board_mat.roughness = 0.7


func _unhandled_input(event: InputEvent) -> void:
	if rig == null or rig.preview:
		return
	if event.is_action_pressed("dig"):
		_start("dig")
	elif event.is_action_pressed("traction_boards"):
		if not _boards.is_empty():
			_stow_boards("Boards back in the rig")
		else:
			_start("boards")
	elif event.is_action_pressed("jack"):
		_start("jack")


func _start(what: String) -> void:
	if busy > 0.0:
		return
	if rig.speed_kmh > 2.0:
		_say("Stop first")
		return
	if rig.global_transform.basis.y.y < 0.6:
		_say("Not with it on its side: Backspace for a recovery")
		return
	if rig.winch_active:
		_say("Not while the winch is pulling")
		return
	job = what
	match what:
		"dig":
			busy = DIG_TIME
		"boards":
			_lay_boards()
		"jack":
			busy = JACK_TIME
			_jack_from = rig.global_transform
			# shove it the way it's facing (back if it's in reverse), level
			var f := -rig.global_transform.basis.z
			if rig.gearbox.gear < 0:
				f = -f
			_jack_dir = Vector3(f.x, 0.0, f.z).normalized()
			_stack_under_light_wheels()
			rig.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
			rig.freeze = true


func _physics_process(delta: float) -> void:
	if rig == null:
		return
	_note_t = maxf(0.0, _note_t - delta)
	# boards left behind get picked up
	if not _boards.is_empty() and rig.global_position.distance_to(_boards[0].global_position) > 20.0:
		_stow_boards("Boards picked up")
	if busy <= 0.0:
		return
	busy -= delta
	match job:
		"dig":
			if busy <= 0.0:
				_dig()
		"jack":
			_jack_step()


## How far the job in hand has got, for the HUD ("" when idle).
func status() -> String:
	if busy > 0.0:
		match job:
			"dig":
				return "DIGGING OUT  %.0f s" % ceilf(busy)
			"jack":
				return "HIGH-LIFT JACK  %.0f s" % ceilf(busy)
	if _note_t > 0.0:
		return _note
	if not _boards.is_empty():
		return "boards down (2 to pick up)"
	return ""


func _say(what: String) -> void:
	_note = what
	_note_t = 2.5


# --- shovel -----------------------------------------------------------------

func _dig() -> void:
	var mud := rig.terrain.mud
	var fwd := -rig.global_transform.basis.z
	var side := rig.global_transform.basis.x
	var moved := 0.0
	for w in rig.wheels:
		var at := Vector3(w.global_position.x, 0.0, w.global_position.z)
		# the hole the tire sits in, and a run-out 2.5 m ahead and a bit behind
		for k in range(-2, 8):
			var p := at + fwd * (k * 0.35)
			var xz := Vector2(p.x, p.z)
			var c := mud.world_to_cell(xz)
			if not mud.in_bounds(c):
				continue
			var i := mud.idx(c.x, c.y)
			var room: float = mud.thickness[i] - mud.rut[i]
			if room > 0.0:
				moved += mud.carve(xz, w.width * 0.6, room)
				# thrown up on the outside of the trench
				var out := side * signf(side.dot(w.global_position - rig.global_position))
				mud.deposit(Vector2(p.x, p.z) + Vector2(out.x, out.z) * 0.8, 0.35, room * 0.4, mud.wetness[i])
		w.sink = 0.0
		w.slip = 0.0
	_say("Dug out" if moved > 0.02 else "Nothing to dig: it's hung up on something hard (3 for the jack)")


# --- traction boards ---------------------------------------------------------

func _lay_boards() -> void:
	var b := rig.global_transform.basis
	var reverse := rig.gearbox.gear < 0
	var ahead := (b.z if reverse else -b.z)
	var pair := [rig.wheels[2], rig.wheels[3]] if reverse else [rig.wheels[0], rig.wheels[1]]
	for w: RigWheel in pair:
		var r := w.effective_radius()
		# jammed into the hole: the near end down at the bottom of the tire,
		# just in front of it, ramping up to the ground surface ahead
		var foot := w.contact_point if w.contact else w.global_position - b.y * (w.rest_length + r)
		var near := foot + ahead * (r * 0.3)
		var far := near + ahead * BOARD_SIZE.z
		far.y = maxf(_surface_at(far), near.y)
		var run := far - near
		var centre := (near + far) * 0.5 + Vector3.UP * BOARD_SIZE.y * 0.5
		var board := StaticBody3D.new()
		board.add_to_group("rock")       # firm ground to the tires...
		board.add_to_group("boards")     # ...and grippy (wheel.gd)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = BOARD_SIZE
		cs.shape = box
		board.add_child(cs)
		var mi := MeshInstance3D.new()
		var mesh := MeshKit.begin()
		MeshKit.rounded_box(mesh, BOARD_SIZE, 0.012, Transform3D.IDENTITY, Color.WHITE)
		# the moulded cleats across the top
		for k in range(9):
			MeshKit.rounded_box(mesh, Vector3(BOARD_SIZE.x * 0.85, 0.02, 0.03), 0.006,
				Transform3D(Basis.IDENTITY, Vector3(0, BOARD_SIZE.y * 0.5 + 0.008, (k - 4) * 0.12)), Color.WHITE)
		mi.mesh = MeshKit.commit(mesh, _board_mat)
		board.add_child(mi)
		rig.get_parent().add_child(board)
		board.global_transform = Transform3D(Basis.looking_at(run.normalized(), Vector3.UP), centre)
		_boards.append(board)
	_say("Boards down under the %s tires" % ("rear" if reverse else "front"))


## The visible ground at a point: firm floor plus the soft mud left on it.
func _surface_at(p: Vector3) -> float:
	var s := rig.terrain.mud.sample(Vector2(p.x, p.z))
	return rig.terrain.get_height(p.x, p.z) - float(s.get("rut", 0.0))


func _stow_boards(what: String) -> void:
	for board in _boards:
		board.queue_free()
	_boards.clear()
	_say(what)


# --- high-lift jack ------------------------------------------------------------

## The tires hanging at full droop or carrying next to nothing (cross-axled
## in the ruts, or the belly has the weight): pack stones under each, a little
## ahead where the rig will come down, so they bear it again. The stones are
## firm ground to the tires (group "rock") and stay on the trail.
func _stack_under_light_wheels() -> void:
	var share := rig.mass * 9.8 / 4.0
	var stacked := 0
	for w in rig.wheels:
		# hanging: at (or near) full droop, or carrying almost nothing
		var hanging := w.compression() < -0.6 * w.max_travel or w.load < share * 0.33
		if not hanging:
			continue
		var foot := w.contact_point if w.contact else w.global_position - rig.global_transform.basis.y * (w.rest_length + w.max_travel + w.effective_radius())
		foot += _jack_dir * JACK_SHOVE
		var ground := minf(_surface_at(foot), foot.y)
		var h := (foot.y - ground) + STACK
		var pile := StaticBody3D.new()
		pile.add_to_group("rock")
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.5, h, 0.6)
		cs.shape = box
		pile.add_child(cs)
		var mi := MeshInstance3D.new()
		var st := MeshKit.begin()
		# flat river stones, a few layers, roughly piled
		var layers := maxi(2, int(h / 0.09))
		for k in range(layers):
			var y := -h * 0.5 + (k + 0.5) * h / layers
			for j in range(2):
				var off := Vector3((j - 0.5) * 0.22 + randf_range(-0.04, 0.04), y, randf_range(-0.1, 0.1))
				MeshKit.rounded_box(st, Vector3(0.28, h / layers * 1.1, 0.5) * randf_range(0.85, 1.05), 0.04,
					Transform3D(Basis(Vector3.UP, randf_range(-0.3, 0.3)), off), Color.WHITE, 2)
		var stone := StandardMaterial3D.new()
		stone.albedo_color = Color(0.42, 0.4, 0.37)
		stone.roughness = 0.85
		mi.mesh = MeshKit.commit(st, stone)
		pile.add_child(mi)
		rig.get_parent().add_child(pile)
		pile.global_transform = Transform3D(Basis.looking_at(_jack_dir, Vector3.UP), Vector3(foot.x, ground + h * 0.5, foot.z))
		stacked += 1
	_stacked = stacked


func _jack_step() -> void:
	# up over the first 40%, across, then down; the driver works the handle
	var t := 1.0 - busy / JACK_TIME
	var up := smoothstep(0.0, 0.4, t) * (1.0 - smoothstep(0.75, 1.0, t))
	var across := smoothstep(0.45, 0.75, t)
	var xf := _jack_from
	xf.origin += Vector3.UP * JACK_LIFT * up + _jack_dir * JACK_SHOVE * across
	# set down level enough to sit on its wheels
	rig.global_transform = xf
	if busy <= 0.0:
		rig.freeze = false
		rig.linear_velocity = Vector3.ZERO
		rig.angular_velocity = Vector3.ZERO
		for w in rig.wheels:
			w.sink = 0.0
		_say("Jacked up, rocks under %d tire%s, set down" % [_stacked, "" if _stacked == 1 else "s"] if _stacked > 0 else "Jacked up and set down")
