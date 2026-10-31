extends Node
## Records a rig's engine through the game's own mix (needs a window: the
## audio driver has to run): idle, a full-throttle rev to near the redline,
## lift off and coast down on engine braking, idle; once from the chase camera
## and once from the seat. snaps/engine/<rig>_outside.wav, <rig>_seat.wav
##   godot --path . res://tests/engine_listen.tscn -- --rig ronda --rain 0
var rig: Rig
var rec: AudioEffectRecord


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	rig = main.get_node("Rig")
	rec = AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, rec)
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://snaps/engine"))
	for i in 30:
		await get_tree().physics_frame
	rig.freeze = true
	rig.set_physics_process(false)
	var audio: RigAudio = rig.get_node("Audio")
	var t := 0.0
	while audio.get("_eng").is_empty() and t < 30.0:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	# quiet the world round it so the engine is what's heard
	for p in audio.get_children():
		if p is AudioStreamPlayer:
			(p as AudioStreamPlayer).stream_paused = true
	var cam: Camera3D = get_viewport().get_camera_3d()
	for view: String in ["outside", "seat"]:
		cam.set("hood_cam", view == "seat")
		rec.set_recording_active(true)
		await _sweep()
		rec.set_recording_active(false)
		rec.get_recording().save_to_wav("res://snaps/engine/%s_%s.wav" % [rig.spec.id, view])
	print("recorded ", rig.spec.id)
	get_tree().quit()


func _sweep() -> void:
	var gb := rig.gearbox
	var top := gb.redline * 0.85
	var phases := [[2.0, gb.idle_rpm, gb.idle_rpm, 0.0], [3.0, gb.idle_rpm, top, 1.0], [0.8, top, top, 1.0],
		[3.5, top, gb.idle_rpm * 1.1, 0.0], [1.5, gb.idle_rpm, gb.idle_rpm, 0.0]]
	for ph: Array in phases:
		var dur: float = ph[0]
		var t := 0.0
		while t < dur:
			await get_tree().process_frame
			t += get_process_delta_time()
			var u := clampf(t / dur, 0.0, 1.0)
			gb.rpm = lerpf(ph[1], ph[2], u)
			rig.pedal_gas = ph[3]
			gb.torque_out = -50.0 if ph[3] == 0.0 and ph[1] > ph[2] else 10.0
