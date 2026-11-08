class_name VideoGeneratorPanel
extends PanelContainer
## Prompt -> AI video. Finished files are saved in user://videos (Godot cannot play MP4,
## so "Open" hands the file to the system video player).

var client := VideoApiClient.new()
var _key := LineEdit.new()
var _model := OptionButton.new()
var _prompt := TextEdit.new()
var _duration := SpinBox.new()
var _ratio := OptionButton.new()
var _go := Button.new()
var _status := Label.new()
var _files := ItemList.new()
var _paths: Array[String] = []

func _ready() -> void:
	visible = false
	add_child(client)
	client.status_changed.connect(func(_id: String, s: String) -> void: _status.text = "Status: %s" % s)
	client.finished.connect(_on_finished)
	client.failed.connect(_on_failed)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.12, 0.98)
	style.set_corner_radius_all(20)
	style.set_content_margin_all(18)
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(520, 560)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	var head := HBoxContainer.new()
	var title := Label.new()
	title.text = "AI Video Generator"
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "✕"
	close.pressed.connect(func() -> void: visible = false)
	head.add_child(close)
	box.add_child(head)

	_key.placeholder_text = "API key (saved only on this device)"
	_key.secret = true
	_key.text = Settings.api_key
	_key.text_changed.connect(func(t: String) -> void:
		Settings.api_key = t.strip_edges()
		Settings.save_settings())
	box.add_child(_key)

	_model.add_item(Settings.model)
	box.add_child(_model)
	_model.item_selected.connect(func(i: int) -> void:
		Settings.model = _model.get_item_text(i)
		Settings.save_settings())

	_prompt.placeholder_text = "Describe the scene, subject, action and mood…"
	_prompt.custom_minimum_size.y = 110
	_prompt.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(_prompt)

	var row := HBoxContainer.new()
	var dl := Label.new()
	dl.text = "Seconds"
	row.add_child(dl)
	_duration.min_value = 5
	_duration.max_value = 15
	_duration.value = 5
	row.add_child(_duration)
	for r in ["16:9", "9:16", "1:1"]:
		_ratio.add_item(r)
	row.add_child(_ratio)
	box.add_child(row)

	_go.text = "Generate"
	_go.pressed.connect(_on_generate)
	box.add_child(_go)
	_status.text = "Ready. Videos are AI-generated."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)

	_files.custom_minimum_size.y = 120
	_files.item_activated.connect(func(i: int) -> void: OS.shell_open(ProjectSettings.globalize_path(_paths[i])))
	box.add_child(_files)

	_load_models()

func _load_models() -> void:
	var ids := await client.fetch_models()
	if ids.is_empty():
		return
	_model.clear()
	var pick := 0
	for i in ids.size():
		_model.add_item(ids[i])
		if ids[i] == Settings.model:
			pick = i
	_model.select(pick)
	Settings.model = _model.get_item_text(pick)

func open() -> void:
	visible = true

func _on_generate() -> void:
	var text := _prompt.text.strip_edges()
	if text.length() < 5:
		_status.text = "Write a longer prompt first."
		return
	client.api_key = Settings.api_key
	client.model = _model.get_item_text(_model.selected)
	_go.disabled = true
	_status.text = "Sending…"
	client.generate(text, int(_duration.value), _ratio.get_item_text(_ratio.selected))

func _on_finished(_id: String, path: String) -> void:
	_go.disabled = false
	_status.text = "Done. Double-click the file to open it."
	_paths.append(path)
	_files.add_item(path.get_file())

func _on_failed(_id: String, message: String) -> void:
	_go.disabled = false
	_status.text = "Failed: %s" % message
