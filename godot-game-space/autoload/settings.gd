extends Node
## Persistent user settings in user://settings.cfg (never in the project files, so API keys stay on the device).

const PATH := "user://settings.cfg"
const PROPS := [
	"api_key", "api_provider", "api_model", "sr_mode", "performance_mode", "do_not_disturb",
	"show_telemetry", "brightness_lock", "brightness_value", "entry_asset", "boost_on_launch", "entry_prompt",
]

var api_key := ""
var api_provider := "revana" # revana | replicate | luma
var api_model := "minimax-h3-free"
var sr_mode := 1 # 0 = off, 1 = balanced, 2 = ultra performance
var performance_mode := 1 # 0 = power saver, 1 = balanced, 2 = boost
var do_not_disturb := false
var show_telemetry := true
var brightness_lock := false
var brightness_value := 1.0
var entry_asset := "" # cached AI animation that replaces the procedural intro
var boost_on_launch := true
var entry_prompt := "Cinematic neon nitro vortex boost entry animation, 60fps loop, dark cyberpunk theme"

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for p in PROPS:
		if cfg.has_section_key("s", p):
			set(p, cfg.get_value("s", p))

func save_settings() -> void:
	var cfg := ConfigFile.new()
	for p in PROPS:
		cfg.set_value("s", p, get(p))
	cfg.save(PATH)
