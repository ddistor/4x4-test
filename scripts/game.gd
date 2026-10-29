extends Node
## Autoload "Game": which stage is being driven, and moving between the start
## menu and a stage. `--seed N` (and `--weather dry|rain`, `--level 0|1|2`) after `--` on the command line pick the
## stage; otherwise every launch starts with a fresh random one.

const MENU := "res://scenes/menu.tscn"
const STAGE := "res://scenes/main.tscn"

var stage_seed := 0
## -1 random (the seed decides), 0 dry season, 1 rainy season
var weather := -1
## key into StagePlan.DIFFICULTY: 0 moderate, 1 hard, 2 extreme
var level := 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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


static func random_seed() -> int:
	return randi_range(1, 999999)


func start_stage(seed_v: int) -> void:
	stage_seed = seed_v
	get_tree().paused = false
	get_tree().change_scene_to_file(STAGE)


func to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MENU)
