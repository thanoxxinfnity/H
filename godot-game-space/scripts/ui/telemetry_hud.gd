class_name TelemetryHud
extends PanelContainer
## Minimal always-on HUD: FPS · frame time · battery temperature (colour coded). Lives inside a SafeAreaContainer.

var _label := Label.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.01, 0.03, 0.65)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	add_theme_stylebox_override("panel", sb)
	_label.add_theme_font_size_override("font_size", 15)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	Telemetry.updated.connect(_refresh)
	_refresh()

func _refresh() -> void:
	visible = Settings.show_telemetry
	var temp := "--" if Telemetry.battery_temp_c < 0.0 else "%.0f°C" % Telemetry.battery_temp_c
	_label.text = "%d FPS  ·  %.1f ms  ·  %s" % [Telemetry.fps, Telemetry.frame_ms, temp]
	var col := Color(1.0, 0.95, 0.95)
	if Telemetry.fps < 45 or Telemetry.battery_temp_c >= 42.0:
		col = Color(1.0, 0.8, 0.2)
	if Telemetry.fps < 28 or Telemetry.battery_temp_c >= 46.0:
		col = Color(1.0, 0.3, 0.35)
	_label.add_theme_color_override("font_color", col)
