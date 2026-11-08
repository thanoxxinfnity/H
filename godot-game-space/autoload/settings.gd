extends Node
## Persistent user settings in user://settings.cfg (never in the project files, so API keys stay on the device).

const PATH := "user://settings.cfg"
const PROPS := [
	"api_key", "api_provider", "api_model", "sr_mode", "performance_mode", "do_not_disturb",
	"show_telemetry", "brightness_lock", "brightness_value", "entry_asset", "boost_on_launch", "entry_prompt",
	"light_on", "light_theme", "triggers_on", "trigger_l", "trigger_r", "thermal_guard", "bypass_charging", "playtime_total",
]

var api_key := ""
var api_provider := "revana" # revana | replicate | luma
var api_model := "minimax-h3-free"
var sr_mode := 1 # 0 = off, 1 = balanced, 2 = ultra performance
var performance_mode := 1 # 0 = Eco (30 fps), 1 = Balanced (60), 2 = Performance (90), 3 = X-Boost (display max, up to 144)
var do_not_disturb := false
var show_telemetry := true
var brightness_lock := false
var brightness_value := 1.0
var entry_asset := "" # cached AI animation that replaces the procedural intro
var boost_on_launch := true
var light_on := true
var light_theme := 0 # 0 cyan, 1 magenta, 2 rainbow, 3 red alert, 4 cyber duo
var triggers_on := false
var trigger_l := Vector2(0.22, 0.72) # where the left air trigger taps the game (0..1 of the screen)
var trigger_r := Vector2(0.78, 0.72)
var thermal_guard := true
var bypass_charging := false
var playtime_total := 0.0 # seconds
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
