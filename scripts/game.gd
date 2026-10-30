extends Node
## Autoload "Game": which stage is being driven, and moving between the start
## menu and a stage. `--seed N` (and `--weather dry|rain`, `--level 0|1|2`) after `--` on the command line pick the
## stage; otherwise every launch starts with a fresh random one. `--rig ID` picks
## the rig (RigSpec ids), `--look P,S,J` the paint, shirt and jorts colours by index,
## `--logo N` the shirt print. `--career` goes straight to the career garage;
## `--parts lift=4,tires=37_mt` drives career parts in free play (for tests).

const MENU := "res://scenes/menu.tscn"
const STAGE := "res://scenes/main.tscn"
const GARAGE := "res://scenes/garage.tscn"

var stage_seed := 0
## -1 random (the seed decides), 0 dry season, 1 rainy season
var weather := -1
## key into StagePlan.DIFFICULTY: 0 moderate, 1 hard, 2 extreme
var level := 1

## Colours you pick in the start menu, kept between launches in user://look.cfg.
## Each list is [name, colour as authored (sRGB)]; a paint may add a
## metallic amount (stainless).
const PAINTS := [
	["Gloss black", Color(0.012, 0.012, 0.014)], ["Army green", Color(0.15, 0.19, 0.11)],
	["Jeepney red", Color(0.46, 0.04, 0.03)], ["Laterite orange", Color(0.62, 0.24, 0.08)],
	["Bay blue", Color(0.08, 0.2, 0.42)], ["Kalabaw grey", Color(0.36, 0.36, 0.35)],
	["Cream", Color(0.82, 0.78, 0.66)], ["Mango yellow", Color(0.85, 0.62, 0.06)],
	["Stainless steel", Color(0.74, 0.74, 0.72), 0.92]]
const SHIRTS := [
	["Maroon", Color(0.52, 0.13, 0.12)], ["Club black", Color(0.06, 0.06, 0.065)],
	["White", Color(0.86, 0.86, 0.84)], ["Navy", Color(0.1, 0.14, 0.3)],
	["Olive", Color(0.3, 0.33, 0.17)], ["Mustard", Color(0.72, 0.53, 0.12)],
	["Heather grey", Color(0.48, 0.48, 0.5)]]
const SHORTS := [
	["Blue denim", Color(0.27, 0.36, 0.52)], ["Faded denim", Color(0.45, 0.55, 0.68)],
	["Black denim", Color(0.12, 0.12, 0.14)], ["Khaki", Color(0.55, 0.48, 0.34)]]
## Prints for the front of the shirt: [name, image] ("" for a plain tee).
const LOGOS := [
	["Tropang Saligawsaw", "res://assets/driver/tropang_saligawsaw.png"],
	["Saligawsaw 4x4", "res://assets/driver/saligawsaw_4x4.png"],
	["None", ""]]
const LOOK_FILE := "user://look.cfg"
var rig_kind := 0   # index into RigSpec.kinds()
var logo := 0
var paint := 0
var shirt := 0
var shorts := 0
## Graphics settings (user://graphics.cfg): the settings screen changes them.
var gfx := GraphicsSettings.new()
## Career mode (user://career.cfg): on while you're in it, from the start
## menu's Career button until you go back to the start menu.
var career := Career.new()
var in_career := false
## `--parts slot=id,...`: drive with career parts outside the career (tests)
var test_parts := {}
var career_flag_used := false   # `--career` on the command line: done once
var _free_rig := -1   # the free-play pick, put back when you leave the career


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	gfx.load_file()
	gfx.apply.call_deferred()
	var args := OS.get_cmdline_user_args()
	var i := args.find("--seed")
	if i >= 0 and i + 1 < args.size():
		stage_seed = int(args[i + 1])
	else:
		stage_seed = random_seed()
	var wi := args.find("--weather")
	if wi >= 0 and wi + 1 < args.size():
		weather = {"dry": 0, "rain": 1}.get(args[wi + 1], -1)
	var li := args.find("--level")
	if li >= 0 and li + 1 < args.size():
		level = clampi(int(args[li + 1]), 0, 2)
	var cfg := ConfigFile.new()
	if cfg.load(LOOK_FILE) == OK:
		rig_kind = clampi(cfg.get_value("look", "rig", 0), 0, RigSpec.kinds().size() - 1)
		paint = clampi(cfg.get_value("look", "paint", 0), 0, PAINTS.size() - 1)
		shirt = clampi(cfg.get_value("look", "shirt", 0), 0, SHIRTS.size() - 1)
		shorts = clampi(cfg.get_value("look", "shorts", 0), 0, SHORTS.size() - 1)
		logo = clampi(cfg.get_value("look", "logo", 0), 0, LOGOS.size() - 1)
	var ri := args.find("--rig")
	if ri >= 0 and ri + 1 < args.size():
		for k in RigSpec.kinds().size():
			if RigSpec.kinds()[k].id == args[ri + 1]:
				rig_kind = k
	var pi := args.find("--parts")
	if pi >= 0 and pi + 1 < args.size():
		for kv in args[pi + 1].split(","):
			var p := kv.split("=")
			if p.size() == 2:
				test_parts[p[0]] = p[1]
	var gi := args.find("--logo")
	if gi >= 0 and gi + 1 < args.size():
		logo = clampi(int(args[gi + 1]), 0, LOGOS.size() - 1)
	# --look P,S,J picks paint, shirt and jorts by index for this run (snapshots)
	var ki := args.find("--look")
	if ki >= 0 and ki + 1 < args.size():
		var v := args[ki + 1].split(",")
		if v.size() == 3:
			paint = clampi(int(v[0]), 0, PAINTS.size() - 1)
			shirt = clampi(int(v[1]), 0, SHIRTS.size() - 1)
			shorts = clampi(int(v[2]), 0, SHORTS.size() - 1)


## Enter career mode: the garage, where a new career picks its rig.
func to_career() -> void:
	career.load_file()
	in_career = true
	if career.started:
		use_career_rig()
	to_garage(random_seed())


## The career rig and its event's trail, for the garage and the stage.
func use_career_rig() -> void:
	if _free_rig < 0:
		_free_rig = rig_kind
	rig_kind = career.rig_kind()
	level = Career.EVENTS[career.event][1]


## Parts on the rig you're about to drive: the career's, none in free play.
func fitted_parts() -> Dictionary:
	if in_career and career.started:
		return career.fitted
	return test_parts


## Out of a stage from the pause menu: the garage in career, else the menu.
func leave_stage() -> void:
	if in_career:
		to_garage(random_seed())
	else:
		to_menu()


func save_look() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("look", "rig", _free_rig if _free_rig >= 0 else rig_kind)
	cfg.set_value("look", "paint", paint)
	cfg.set_value("look", "shirt", shirt)
	cfg.set_value("look", "shorts", shorts)
	cfg.set_value("look", "logo", logo)
	cfg.save(LOOK_FILE)


func paint_color() -> Color:
	return PAINTS[paint][1]


## 0 for paint, up to 1 for bare polished metal.
func paint_metal() -> float:
	var p: Array = PAINTS[paint]
	return p[2] if p.size() > 2 else 0.0


func shirt_color() -> Color:
	return SHIRTS[shirt][1]


func shorts_color() -> Color:
	return SHORTS[shorts][1]


func logo_path() -> String:
	return LOGOS[logo][1]


static func random_seed() -> int:
	return randi_range(1, 999999)


func start_stage(seed_v: int) -> void:
	stage_seed = seed_v
	get_tree().paused = false
	get_tree().change_scene_to_file(STAGE)


## The garage: see the rig and driver you picked before driving `seed_v`.
func to_garage(seed_v: int) -> void:
	stage_seed = seed_v
	get_tree().paused = false
	get_tree().change_scene_to_file(GARAGE)


func to_menu() -> void:
	in_career = false
	if _free_rig >= 0:
		rig_kind = _free_rig
		_free_rig = -1
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MENU)
