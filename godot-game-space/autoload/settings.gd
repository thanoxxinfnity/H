extends Node
## Persistent user settings (stored in user://settings.cfg, never in the project files).

const PATH := "user://settings.cfg"

var api_key := ""
var model := "minimax-h3-free"
var cas_enabled := true
var cas_sharpness := 0.6
var render_scale := 0.75
var performance_mode := 1 # 0 = power saver (30 fps), 1 = balanced (60), 2 = ultra (120)
var do_not_disturb := false
var show_fps := true

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	api_key = cfg.get_value("video", "api_key", api_key)
	model = cfg.get_value("video", "model", model)
	cas_enabled = cfg.get_value("display", "cas_enabled", cas_enabled)
	cas_sharpness = cfg.get_value("display", "cas_sharpness", cas_sharpness)
	render_scale = cfg.get_value("display", "render_scale", render_scale)
	performance_mode = cfg.get_value("space", "performance_mode", performance_mode)
	do_not_disturb = cfg.get_value("space", "do_not_disturb", do_not_disturb)
	show_fps = cfg.get_value("space", "show_fps", show_fps)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "api_key", api_key)
	cfg.set_value("video", "model", model)
	cfg.set_value("display", "cas_enabled", cas_enabled)
	cfg.set_value("display", "cas_sharpness", cas_sharpness)
	cfg.set_value("display", "render_scale", render_scale)
	cfg.set_value("space", "performance_mode", performance_mode)
	cfg.set_value("space", "do_not_disturb", do_not_disturb)
	cfg.set_value("space", "show_fps", show_fps)
	cfg.save(PATH)
