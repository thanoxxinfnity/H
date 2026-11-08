class_name GameSpaceSidebar
extends Control
## Vivo-style Game Space drawer. Swipe inward from the UPPER-LEFT or UPPER-RIGHT screen border to open it
## (swipe back outward or tap the dimmed game to close). The game keeps running underneath: nothing here
## ever pauses the SceneTree.

signal replay_intro

const EDGE_PX := 40.0 # width of the touch zone along each border
const OPEN_DX := 70.0 # inward travel needed to open
const NEON := Color(0.0, 0.95, 1.0)

var upscaler: UpscalerManager
var generator: AIVideoGenerator
var recorder: ScreenRecorder
var triggers: AirTriggers

var _open := false
var _side := -1 # -1 = drawer on the left, 1 = on the right
var _touch := -1
var _start := Vector2.ZERO
var _edge := 0
var _tween: Tween

var _dim := ColorRect.new()
var _drawer := Control.new()
var _glass := ColorRect.new()
var _glass_mat := ShaderMaterial.new()
var _pill_l := ColorRect.new()
var _pill_r := ColorRect.new()
var _dimmer_layer := CanvasLayer.new()
var _dimmer := ColorRect.new()

var _lbl_fps := Label.new()
var _lbl_ms := Label.new()
var _lbl_temp := Label.new()
var _lbl_cpu := Label.new()
var _lbl_ram := Label.new()
var _graph := Sparkline.new()
var _sr_buttons: Array[Button] = []
var _mode_buttons: Array[Button] = []
var _bypass_btn := Button.new()
var _lbl_ping := Label.new()
var _lbl_time := Label.new()
var _clean_label := Label.new()
var _rec_btn := Button.new()
var _dnd_btn := Button.new()
var _bright_btn := Button.new()
var _bright_slider := HSlider.new()
var _gen_status := Label.new()
var _gen_btn := Button.new()
var _prompt := TextEdit.new()
var _provider := OptionButton.new()
var _model := LineEdit.new()
var _key := LineEdit.new()

func setup(p_upscaler: UpscalerManager, p_generator: AIVideoGenerator, p_recorder: ScreenRecorder, p_triggers: AirTriggers) -> void:
	triggers = p_triggers
	PerformanceBooster.boost_changed.connect(func(_a: bool) -> void:
		for i in _mode_buttons.size():
			_mode_buttons[i].set_pressed_no_signal(i == Settings.performance_mode))
	upscaler = p_upscaler
	generator = p_generator
	recorder = p_recorder
	upscaler.mode_changed.connect(_sync_sr)
	_sync_sr(upscaler.mode)
	generator.progress.connect(func(_stage: String, detail: String) -> void: _gen_status.text = detail)
	generator.asset_ready.connect(_on_asset_ready)
	generator.failed.connect(_on_gen_failed)
	recorder.state_changed.connect(_on_rec_state)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("cleanable")

	_dim.color = Color(0, 0, 0, 0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)

	for pill in [_pill_l, _pill_r]:
		pill.color = Color(NEON, 0.55)
		pill.custom_minimum_size = Vector2(4, 64)
		pill.size = Vector2(4, 64)
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pill)
	var pulse := create_tween().set_loops()
	pulse.tween_property(_pill_l, "modulate:a", 0.25, 1.1)
	pulse.parallel().tween_property(_pill_r, "modulate:a", 0.25, 1.1)
	pulse.tween_property(_pill_l, "modulate:a", 1.0, 1.1)
	pulse.parallel().tween_property(_pill_r, "modulate:a", 1.0, 1.1)

	_drawer.visible = false
	_drawer.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_drawer)
	_glass_mat.shader = load("res://shaders/glass.gdshader")
	_glass.material = _glass_mat
	_glass.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glass.mouse_filter = Control.MOUSE_FILTER_STOP
	_drawer.add_child(_glass)
	_drawer.resized.connect(func() -> void: _glass_mat.set_shader_parameter("rect_size", _drawer.size))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_drawer.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	_build(box)

	get_tree().root.size_changed.connect(_layout)
	Telemetry.updated.connect(_refresh_telemetry)
	_apply_brightness()
	_layout()

func is_open() -> bool:
	return _open

# ------------------------------------------------------------------ layout / gestures
func _drawer_width() -> float:
	return clampf(get_viewport_rect().size.x * 0.40, 340.0, 470.0)

func _layout() -> void:
	var vis := get_viewport_rect().size
	var safe := SafeAreaContainer.safe_rect(self)
	var w := _drawer_width()
	_drawer.size = Vector2(w, safe.size.y - 16.0)
	_glass_mat.set_shader_parameter("rect_size", _drawer.size)
	_drawer.position = _drawer_pos(_open)
	_pill_l.position = Vector2(0, vis.y * 0.18)
	_pill_r.position = Vector2(vis.x - 4.0, vis.y * 0.18)

func _drawer_pos(opened: bool) -> Vector2:
	var vis := get_viewport_rect().size
	var safe := SafeAreaContainer.safe_rect(self)
	var w := _drawer.size.x
	var y := safe.position.y + 8.0
	if _side < 0:
		return Vector2(safe.position.x + 8.0 if opened else -w - 24.0, y)
	return Vector2(safe.end.x - w - 8.0 if opened else vis.x + 24.0, y)

func toggle(open: bool, side := _side) -> void:
	if open == _open and side == _side:
		return
	_open = open
	_side = side
	if _tween:
		_tween.kill()
	_layout()
	if open:
		_drawer.position = _drawer_pos(false)
		_drawer.visible = true
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_drawer, "position", _drawer_pos(open), 0.32)
	_tween.tween_property(_dim, "color:a", 0.35 if open else 0.0, 0.32)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE
	if not open:
		_tween.chain().tween_callback(func() -> void: _drawer.visible = false)
	else:
		_refresh_telemetry()

func _on_dim_input(event: InputEvent) -> void:
	var tap := event as InputEventScreenTouch
	var click := event as InputEventMouseButton
	if _open and ((tap != null and tap.pressed) or (click != null and click.pressed)):
		toggle(false)

func _edge_of(pos: Vector2) -> int:
	var vis := get_viewport_rect().size
	if pos.y > vis.y * 0.5:
		return 0 # only the upper half of each border opens the drawer
	if pos.x <= EDGE_PX:
		return -1
	if pos.x >= vis.x - EDGE_PX:
		return 1
	return 0

func _input(event: InputEvent) -> void:
	var t := event as InputEventScreenTouch
	if t != null:
		if t.pressed and _touch == -1:
			var edge := _edge_of(t.position)
			var outside := _open and not Rect2(_drawer.position, _drawer.size).has_point(t.position)
			if edge != 0 or outside:
				_touch = t.index
				_start = t.position
				_edge = edge
		elif not t.pressed and t.index == _touch:
			_touch = -1
		return
	var d := event as InputEventScreenDrag
	if d == null or d.index != _touch:
		return
	var dx := d.position.x - _start.x
	var dy := d.position.y - _start.y
	if not _open:
		if _edge != 0 and dx * float(-_edge) >= OPEN_DX and absf(dy) < absf(dx) * 1.3:
			toggle(true, _edge)
			_touch = -1
	elif dx * float(_side) >= OPEN_DX * 1.4:
		toggle(false)
		_touch = -1

# ------------------------------------------------------------------ content
func _build(box: VBoxContainer) -> void:
	var head := HBoxContainer.new()
	var logo := TextureRect.new()
	logo.texture = Icons.get_icon("bolt", 40, NEON)
	logo.custom_minimum_size = Vector2(30, 30)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(logo)
	var title := Label.new()
	title.text = " GAME SPACE"
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_icon_button("close", func() -> void: toggle(false)))
	box.add_child(head)

	# Telemetry
	box.add_child(_section("Telemetry"))
	_graph.custom_minimum_size = Vector2(0, 64)
	box.add_child(_graph)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	for pair in [["FPS", _lbl_fps], ["FRAME", _lbl_ms], ["BATTERY", _lbl_temp], ["CPU", _lbl_cpu], ["RAM USED", _lbl_ram], ["PING", _lbl_ping], ["SESSION", _lbl_time]]:
		var cell := VBoxContainer.new()
		var cap := Label.new()
		cap.text = pair[0]
		cap.add_theme_font_size_override("font_size", 11)
		cap.modulate = Color(1, 1, 1, 0.55)
		cell.add_child(cap)
		var val: Label = pair[1]
		val.add_theme_font_size_override("font_size", 20)
		cell.add_child(val)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(cell)
	box.add_child(grid)
	var tele_toggle := _toggle_button("Show FPS HUD", "gauge", Settings.show_telemetry, func(on: bool) -> void:
		Settings.show_telemetry = on
		Settings.save_settings()
		Telemetry.updated.emit())
	box.add_child(tele_toggle)

	# Super resolution
	box.add_child(_section("Super Resolution (CAS)"))
	var sr := HBoxContainer.new()
	sr.add_theme_constant_override("separation", 6)
	var group := ButtonGroup.new()
	for i in UpscalerManager.MODES.size():
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.text = ["Off", "Balanced", "Ultra"][i]
		b.custom_minimum_size = Vector2(0, 52)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			if upscaler != null:
				upscaler.set_mode(i))
		sr.add_child(b)
		_sr_buttons.append(b)
	box.add_child(sr)

	# GT mode (performance profiles)
	box.add_child(_section("GT Mode"))
	var modes := GridContainer.new()
	modes.columns = 2
	modes.add_theme_constant_override("h_separation", 6)
	modes.add_theme_constant_override("v_separation", 6)
	var mgroup := ButtonGroup.new()
	for i in 4:
		var mb := Button.new()
		mb.toggle_mode = true
		mb.button_group = mgroup
		mb.text = ["Eco · 30", "Balanced · 60", "Performance", "X-Boost"][i]
		mb.custom_minimum_size = Vector2(0, 52)
		mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mb.button_pressed = Settings.performance_mode == i
		mb.pressed.connect(func() -> void: PerformanceBooster.apply_mode(i))
		modes.add_child(mb)
		_mode_buttons.append(mb)
	box.add_child(modes)
	box.add_child(_action_button("Clean RAM", "sweep", _on_clean))
	_clean_label.add_theme_font_size_override("font_size", 12)
	_clean_label.modulate = Color(0.6, 1.0, 0.4)
	box.add_child(_clean_label)
	box.add_child(_toggle_button("Thermal guard (auto-cool above 43 °C)", "thermo", Settings.thermal_guard, func(on: bool) -> void:
		Settings.thermal_guard = on
		Settings.save_settings()))
	_bypass_btn = _toggle_button("Bypass charging", "bolt", Settings.bypass_charging, func(on: bool) -> void:
		if not PerformanceBooster.set_bypass_charging(on):
			_clean_label.text = "Bypass charging needs the GameSpaceAndroid plugin (hardware specific)."
			_bypass_btn.set_pressed_no_signal(false))
	box.add_child(_bypass_btn)

	# Cyber light
	box.add_child(_section("Cyber Light"))
	box.add_child(_toggle_button("Border RGB light", "sparkle", Settings.light_on, func(on: bool) -> void:
		Settings.light_on = on
		Settings.save_settings()))
	var themes := GridContainer.new()
	themes.columns = 3
	themes.add_theme_constant_override("h_separation", 6)
	themes.add_theme_constant_override("v_separation", 6)
	for i in MagicLight.THEMES.size():
		var tb := Button.new()
		tb.text = MagicLight.THEMES[i]
		tb.custom_minimum_size = Vector2(0, 44)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.pressed.connect(func() -> void:
			Settings.light_theme = i
			Settings.save_settings())
		themes.add_child(tb)
	box.add_child(themes)

	# Air triggers
	box.add_child(_section("Air Triggers"))
	box.add_child(_toggle_button("Shoulder triggers on screen", "gauge", Settings.triggers_on, func(on: bool) -> void:
		Settings.triggers_on = on
		Settings.save_settings()))
	var map_row := HBoxContainer.new()
	map_row.add_theme_constant_override("separation", 6)
	for i in 2:
		var mapb := Button.new()
		mapb.text = "Map L" if i == 0 else "Map R"
		mapb.custom_minimum_size = Vector2(0, 48)
		mapb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mapb.pressed.connect(func() -> void:
			toggle(false)
			if triggers != null:
				triggers.begin_mapping(i))
		map_row.add_child(mapb)
	box.add_child(map_row)

	# Tools
	box.add_child(_section("Game Tools"))
	_rec_btn = _toggle_button("Screen Record", "record", false, _on_record)
	box.add_child(_rec_btn)
	box.add_child(_action_button("Screenshot", "camera", _on_screenshot))
	_dnd_btn = _toggle_button("Do Not Disturb", "bell_off", Settings.do_not_disturb, func(on: bool) -> void:
		Settings.do_not_disturb = on
		Settings.save_settings()
		PerformanceBooster.call_plugin("setDnd", [on]))
	box.add_child(_dnd_btn)
	_bright_btn = _toggle_button("Brightness Lock", "sun", Settings.brightness_lock, func(on: bool) -> void:
		Settings.brightness_lock = on
		Settings.save_settings()
		_apply_brightness())
	box.add_child(_bright_btn)
	_bright_slider.min_value = 0.15
	_bright_slider.max_value = 1.0
	_bright_slider.step = 0.01
	_bright_slider.value = Settings.brightness_value
	_bright_slider.custom_minimum_size = Vector2(0, 36)
	_bright_slider.value_changed.connect(func(v: float) -> void:
		Settings.brightness_value = v
		Settings.save_settings()
		_apply_brightness())
	box.add_child(_bright_slider)

	# AI entry animation
	box.add_child(_section("AI Entry Animation"))
	_prompt.custom_minimum_size = Vector2(0, 92)
	_prompt.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_prompt.text = Settings.entry_prompt
	_prompt.text_changed.connect(func() -> void:
		Settings.entry_prompt = _prompt.text
		Settings.save_settings())
	box.add_child(_prompt)
	for k in AIVideoGenerator.PROFILES.keys():
		_provider.add_item(AIVideoGenerator.PROFILES[k].label)
		_provider.set_item_metadata(_provider.item_count - 1, k)
		if k == Settings.api_provider:
			_provider.select(_provider.item_count - 1)
	_provider.custom_minimum_size = Vector2(0, 48)
	_provider.item_selected.connect(func(i: int) -> void:
		Settings.api_provider = _provider.get_item_metadata(i)
		Settings.save_settings())
	box.add_child(_provider)
	_model.placeholder_text = "Model (e.g. minimax-h3-free)"
	_model.text = Settings.api_model
	_model.custom_minimum_size = Vector2(0, 48)
	_model.text_changed.connect(func(tx: String) -> void:
		Settings.api_model = tx.strip_edges()
		Settings.save_settings())
	box.add_child(_model)
	_key.placeholder_text = "API key (stored only on this device)"
	_key.secret = true
	_key.text = Settings.api_key
	_key.custom_minimum_size = Vector2(0, 48)
	_key.text_changed.connect(func(tx: String) -> void:
		Settings.api_key = tx.strip_edges()
		Settings.save_settings())
	box.add_child(_key)
	_gen_btn = _action_button("Generate entry animation", "sparkle", _on_generate)
	box.add_child(_gen_btn)
	_gen_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gen_status.add_theme_font_size_override("font_size", 12)
	_gen_status.modulate = Color(1, 1, 1, 0.7)
	_gen_status.text = "AI-generated clip replaces the default intro when your device can play it."
	box.add_child(_gen_status)
	box.add_child(_action_button("Replay intro", "play", func() -> void:
		toggle(false)
		replay_intro.emit()))

func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", NEON)
	return l

func _icon_button(icon_name: String, cb: Callable) -> Button:
	var b := Button.new()
	b.icon = Icons.get_icon(icon_name, 40)
	b.flat = true
	b.custom_minimum_size = Vector2(48, 48)
	b.pressed.connect(cb)
	return b

func _action_button(text: String, icon_name: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = " " + text
	b.icon = Icons.get_icon(icon_name, 40)
	b.custom_minimum_size = Vector2(0, 52)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb)
	return b

func _toggle_button(text: String, icon_name: String, value: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.text = " " + text
	b.icon = Icons.get_icon(icon_name, 40)
	b.custom_minimum_size = Vector2(0, 52)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.button_pressed = value
	b.toggled.connect(cb)
	return b

# ------------------------------------------------------------------ behaviour
func _refresh_telemetry() -> void:
	if not _open:
		return
	_lbl_fps.text = str(Telemetry.fps)
	_lbl_ms.text = "%.1f ms" % Telemetry.frame_ms
	_lbl_temp.text = ("--" if Telemetry.battery_temp_c < 0.0 else "%.0f °C" % Telemetry.battery_temp_c) + ("" if Telemetry.battery_pct < 0 else "  ·  %d%%" % Telemetry.battery_pct)
	_lbl_cpu.text = "--" if Telemetry.cpu_mhz < 0 else "%d MHz" % Telemetry.cpu_mhz
	_lbl_ram.text = "%d%%" % int(Telemetry.ram_used * 100.0)
	_lbl_ping.text = "--" if Telemetry.ping_ms < 0 else "%d ms" % Telemetry.ping_ms
	_lbl_time.text = "%s  (total %dh)" % [Telemetry.format_time(Telemetry.session_seconds), int(Settings.playtime_total / 3600.0)]
	_graph.queue_redraw()

func _sync_sr(mode: int) -> void:
	for i in _sr_buttons.size():
		_sr_buttons[i].set_pressed_no_signal(i == mode)

func _on_clean() -> void:
	_clean_label.text = "Cleaning…"
	var r: Dictionary = await PerformanceBooster.clean_memory()
	var freed: float = r.get("freed_mb", -1.0)
	_clean_label.text = "Done. %s" % ("Freed ~%d MB" % int(freed) if freed > 0.5 else "Memory already tidy")

func _on_record(on: bool) -> void:
	if recorder == null or upscaler == null:
		return
	if on:
		recorder.start(upscaler.get_game_viewport())
	else:
		recorder.stop()

func _on_rec_state(recording: bool, info: String) -> void:
	_rec_btn.set_pressed_no_signal(recording)
	_rec_btn.text = " " + ("Stop · " + info if recording else "Screen Record")
	if not recording:
		_gen_status.text = info

func _on_screenshot() -> void:
	toggle(false)
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	var path := "user://screenshots/shot_%d.png" % Time.get_unix_time_from_system()
	img.save_png(path)
	_gen_status.text = "Screenshot: " + ProjectSettings.globalize_path(path)

func _apply_brightness() -> void:
	if _dimmer_layer.get_parent() == null:
		_dimmer_layer.layer = 90
		_dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
		_dimmer.color = Color(0, 0, 0, 0)
		_dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dimmer_layer.add_child(_dimmer)
		add_child(_dimmer_layer)
	var level := Settings.brightness_value if Settings.brightness_lock else 1.0
	_dimmer.color.a = (1.0 - level) * 0.85 # software dimming: works on every device
	_bright_slider.editable = Settings.brightness_lock
	if Settings.brightness_lock:
		PerformanceBooster.call_plugin("setBrightness", [level]) # real window brightness, when the plugin is present

func _on_generate() -> void:
	if generator == null:
		return
	generator.provider = Settings.api_provider
	generator.model = Settings.api_model
	generator.api_key = Settings.api_key
	_gen_btn.disabled = true
	_gen_status.text = "Starting…"
	generator.generate(_prompt.text)

func _on_asset_ready(path: String) -> void:
	_gen_btn.disabled = false
	Settings.entry_asset = path
	Settings.save_settings()
	var ext := path.get_extension().to_lower()
	var playable := ext == "ogv" or ext in ["png", "webp", "jpg", "jpeg"] or (ClassDB.class_exists("FFmpegVideoStream") and ext in ["mp4", "webm", "mov"])
	_gen_status.text = "Saved %s. %s" % [path.get_file(), "Tap Replay intro to see it." if playable else "This device build cannot decode ." + ext + " - the procedural intro is used (see README)."]

func _on_gen_failed(message: String) -> void:
	_gen_btn.disabled = false
	_gen_status.text = "Failed: " + message

func clean_up() -> void:
	# Called by PerformanceBooster.clean_memory(): drop UI-side caches.
	_graph.queue_redraw()

# ------------------------------------------------------------------ FPS graph
class Sparkline extends Control:
	func _draw() -> void:
		var h := Telemetry.history
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.06))
		if h.size() < 2:
			return
		var top := 125.0
		var pts := PackedVector2Array()
		for i in h.size():
			pts.append(Vector2(size.x * i / 59.0, size.y - clampf(h[i] / top, 0.0, 1.0) * size.y))
		draw_polyline(pts, Color(0.0, 0.95, 1.0), 2.0, true)
		var y60 := size.y - 60.0 / top * size.y
		draw_line(Vector2(0, y60), Vector2(size.x, y60), Color(1, 1, 1, 0.18), 1.0)
