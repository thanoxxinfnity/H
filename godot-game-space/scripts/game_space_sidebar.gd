class_name GameSpaceSidebar
extends Control
## Vivo-style "Game Space" side panel: swipe in from the left edge (or tap the handle).

signal open_video_generator
signal take_screenshot
signal display_changed

const PANEL_W := 340.0
const EDGE_SWIPE_PX := 24.0

var _panel := PanelContainer.new()
var _dim := ColorRect.new()
var _handle := Button.new()
var _fps_label := Label.new()
var _open := false
var _tween: Tween
var _swipe_start := Vector2(-1, -1)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_dim.color = Color(0, 0, 0, 0.0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if _open and mb != null and mb.pressed:
			toggle(false))
	add_child(_dim)

	_handle.text = "›"
	_handle.flat = true
	_handle.custom_minimum_size = Vector2(22, 90)
	_handle.anchor_left = 0.0
	_handle.anchor_right = 0.0
	_handle.anchor_top = 0.5
	_handle.anchor_bottom = 0.5
	_handle.offset_left = 0.0
	_handle.offset_right = 22.0
	_handle.offset_top = -45.0
	_handle.offset_bottom = 45.0
	_handle.modulate = Color(1, 1, 1, 0.55)
	_handle.pressed.connect(func() -> void: toggle(true))
	add_child(_handle)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.12, 0.96)
	style.set_corner_radius_all(0)
	style.corner_radius_top_right = 24
	style.corner_radius_bottom_right = 24
	style.set_content_margin_all(18)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.anchor_left = 0.0
	_panel.anchor_right = 0.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -PANEL_W - 8.0
	_panel.offset_right = -8.0
	_panel.offset_top = 0.0
	_panel.offset_bottom = 0.0
	add_child(_panel)
	_build_content()
	_apply_performance(Settings.performance_mode)

func _process(_dt: float) -> void:
	_fps_label.visible = Settings.show_fps
	_fps_label.text = "%d FPS" % Engine.get_frames_per_second()

# ---------- content ----------
func _build_content() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = PANEL_W - 36.0
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)

	var title := Label.new()
	title.text = "Game Space"
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	_fps_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.8))
	box.add_child(_fps_label)

	box.add_child(_section("Focus"))
	box.add_child(_toggle("Do Not Disturb (hide notifications)", Settings.do_not_disturb, func(on: bool) -> void:
		Settings.do_not_disturb = on
		Settings.save_settings()))
	box.add_child(_toggle("Show FPS", Settings.show_fps, func(on: bool) -> void:
		Settings.show_fps = on
		Settings.save_settings()))

	box.add_child(_section("Performance"))
	var perf := OptionButton.new()
	perf.add_item("Power saver (30 FPS)", 0)
	perf.add_item("Balanced (60 FPS)", 1)
	perf.add_item("Ultra (120 FPS)", 2)
	perf.select(Settings.performance_mode)
	perf.item_selected.connect(func(i: int) -> void:
		_apply_performance(i)
		Settings.save_settings())
	box.add_child(perf)

	box.add_child(_section("Upscaler (AMD CAS)"))
	box.add_child(_toggle("Render low-res + sharpen", Settings.cas_enabled, func(on: bool) -> void:
		Settings.cas_enabled = on
		_changed()))
	box.add_child(_slider("Sharpness", Settings.cas_sharpness, 0.0, 1.0, 0.05, func(v: float) -> void:
		Settings.cas_sharpness = v
		_changed()))
	box.add_child(_slider("Render scale", Settings.render_scale, 0.5, 1.0, 0.05, func(v: float) -> void:
		Settings.render_scale = v
		_changed()))

	box.add_child(_section("Tools"))
	var shot := Button.new()
	shot.text = "Screenshot"
	shot.pressed.connect(func() -> void:
		toggle(false)
		take_screenshot.emit())
	box.add_child(shot)
	var vid := Button.new()
	vid.text = "AI Video Generator"
	vid.pressed.connect(func() -> void:
		toggle(false)
		open_video_generator.emit())
	box.add_child(vid)

func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.55, 0.65, 0.9))
	return l

func _toggle(text: String, value: bool, cb: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = value
	c.toggled.connect(cb)
	return c

func _slider(text: String, value: float, lo: float, hi: float, step: float, cb: Callable) -> VBoxContainer:
	var v := VBoxContainer.new()
	var l := Label.new()
	l.text = "%s: %d%%" % [text, roundi(value * 100.0)]
	v.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.value_changed.connect(func(x: float) -> void:
		l.text = "%s: %d%%" % [text, roundi(x * 100.0)]
		cb.call(x))
	v.add_child(s)
	return v

func _changed() -> void:
	Settings.save_settings()
	display_changed.emit()

func _apply_performance(mode: int) -> void:
	Settings.performance_mode = mode
	Engine.max_fps = [30, 60, 120][clampi(mode, 0, 2)]

# ---------- open / close ----------
func toggle(open: bool) -> void:
	_open = open
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_panel, "position:x", 0.0 if open else -PANEL_W - 8.0, 0.25)
	_tween.tween_property(_dim, "color:a", 0.45 if open else 0.0, 0.25)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE
	_handle.visible = not open

## Swipe in from the left edge with a finger (or the mouse) to open, swipe back to close.
func _input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	var pressed := false
	var released := false
	var moved := false
	var touch := event as InputEventScreenTouch
	var drag := event as InputEventScreenDrag
	var mb := event as InputEventMouseButton
	var mm := event as InputEventMouseMotion
	if touch != null:
		pos = touch.position
		pressed = touch.pressed
		released = not touch.pressed
	elif drag != null:
		pos = drag.position
		moved = true
	elif mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		pos = mb.position
		pressed = mb.pressed
		released = not mb.pressed
	elif mm != null and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		pos = mm.position
		moved = true
	else:
		return
	if pressed:
		_swipe_start = pos if (pos.x <= EDGE_SWIPE_PX or _open) else Vector2(-1, -1)
	elif moved and _swipe_start.x >= 0.0:
		var dx := pos.x - _swipe_start.x
		if not _open and dx > 60.0:
			toggle(true)
			_swipe_start = Vector2(-1, -1)
		elif _open and dx < -60.0:
			toggle(false)
			_swipe_start = Vector2(-1, -1)
	elif released:
		_swipe_start = Vector2(-1, -1)
