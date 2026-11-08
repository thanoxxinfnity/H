class_name GameLibrary
extends Control
## "Game Space" home: your games as boost-and-launch tiles + the built-in Arena benchmark.
## Tap a tile -> booster intro + real RAM clean -> the game launches (on Android through the PackageManager).

signal play_game(entry: Dictionary)

const ARENA := {"package": "", "label": "ARENA TEST", "builtin": true}

var _grid := GridContainer.new()
var _picker := Control.new()
var _search := LineEdit.new()
var _list := ItemList.new()
var _manual := LineEdit.new()
var _apps: Array = []
var _stats := Label.new()
var _icon_queue: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = GTTheme.build()
	var bg := ColorRect.new()
	bg.color = Pal.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	for art in ["hex_bg", "speed_lines"]:
		var tr := TextureRect.new()
		tr.texture = Drawables.texture(art, 2.0)
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tr)

	var safe := SafeAreaContainer.new()
	safe.extra_margin = 18
	add_child(safe)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	safe.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var logo := TextureRect.new()
	logo.texture = Drawables.texture("logo_mark", 0.5)
	logo.custom_minimum_size = Vector2(56, 56)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(logo)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = "GAME SPACE"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Pal.TEXT)
	tv.add_child(title)
	_stats.add_theme_font_size_override("font_size", 13)
	_stats.add_theme_color_override("font_color", Pal.RED_HOT)
	tv.add_child(_stats)
	head.add_child(tv)
	var add := Button.new()
	add.text = "+ ADD GAME"
	add.icon = Icons.get_icon("bolt", 36, Pal.TEXT)
	add.custom_minimum_size = Vector2(0, 56)
	add.pressed.connect(_open_picker)
	head.add_child(add)
	col.add_child(head)

	var hint := Label.new()
	hint.text = "SWIPE IN FROM THE UPPER-LEFT / UPPER-RIGHT EDGE FOR THE BOOST PANEL"
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Pal.MUTED
	col.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

	_build_picker()
	get_tree().root.size_changed.connect(_refresh)
	Telemetry.updated.connect(_update_stats)
	_refresh()
	_update_stats()

func _update_stats() -> void:
	var free := Telemetry.free_ram_mb()
	var temp := "--" if Telemetry.battery_temp_c < 0.0 else "%.0f°C" % Telemetry.battery_temp_c
	_stats.text = "RAM FREE %s   ·   BATTERY %s   ·   MODE %s" % ["--" if free < 0.0 else "%d MB" % int(free), temp, ["ECO", "BALANCED", "PERFORMANCE", "X-BOOST"][clampi(Settings.performance_mode, 0, 3)]]

func _refresh() -> void:
	var w := get_viewport_rect().size.x
	_grid.columns = maxi(2, int((w - 36.0) / 190.0))
	for c in _grid.get_children():
		c.queue_free()
	_grid.add_child(_tile(ARENA, true))
	for g in Settings.games:
		_grid.add_child(_tile(g, false))
	_icon_queue.clear()
	for t in _grid.get_children():
		if t.has_meta("pkg") and str(t.get_meta("pkg")) != "":
			_icon_queue.append(t)
	_load_icons()

func _tile(entry: Dictionary, builtin: bool) -> Control:
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(176, 222)
	tile.add_theme_stylebox_override("panel", Drawables.box("tile_frame", 22, 1.0, 10))
	tile.set_meta("pkg", str(entry.get("package", "")))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	tile.add_child(v)
	var top := HBoxContainer.new()
	top.custom_minimum_size = Vector2(0, 26)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	if not builtin:
		var rm := Button.new()
		rm.icon = Icons.get_icon("close", 22, Pal.MUTED)
		rm.flat = true
		rm.custom_minimum_size = Vector2(28, 26)
		rm.pressed.connect(func() -> void: _remove(entry))
		top.add_child(rm)
	v.add_child(top)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = Drawables.texture("flame" if builtin else "logo_mark", 1.5)
	icon.custom_minimum_size = Vector2(84, 84)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(icon)
	var name_label := Label.new()
	name_label.text = str(entry.get("label", "Game")).to_upper()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(0, 38)
	name_label.add_theme_font_size_override("font_size", 14)
	v.add_child(name_label)
	var play := Button.new()
	play.text = "BOOST & PLAY"
	play.custom_minimum_size = Vector2(0, 44)
	play.add_theme_font_size_override("font_size", 14)
	play.pressed.connect(func() -> void: play_game.emit(entry))
	v.add_child(play)
	return tile

func _load_icons() -> void:
	if not AndroidBridge.available:
		return
	for t in _icon_queue:
		if not is_instance_valid(t):
			continue
		await get_tree().process_frame
		var tex := AndroidBridge.app_icon(str(t.get_meta("pkg")))
		if tex != null and is_instance_valid(t):
			t.get_node("VBoxContainer/Icon").texture = tex

func _remove(entry: Dictionary) -> void:
	Settings.games = Settings.games.filter(func(g) -> bool: return g.package != entry.package)
	Settings.save_settings()
	_refresh()

# ---------------------------------------------------------------- add-game picker
func _build_picker() -> void:
	_picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picker.visible = false
	add_child(_picker)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picker.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Drawables.box("panel_chamfer", 24, 1.0, 18))
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 60
	panel.offset_right = -60
	panel.offset_top = 30
	panel.offset_bottom = -30
	_picker.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var h := HBoxContainer.new()
	var t := Label.new()
	t.text = "ADD A GAME"
	t.add_theme_font_size_override("font_size", 22)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	var close := Button.new()
	close.icon = Icons.get_icon("close", 32)
	close.pressed.connect(func() -> void: _picker.visible = false)
	h.add_child(close)
	v.add_child(h)
	_search.placeholder_text = "Search installed apps…"
	_search.text_changed.connect(func(_t: String) -> void: _fill_list())
	v.add_child(_search)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.add_theme_font_size_override("font_size", 18)
	_list.add_theme_color_override("font_color", Pal.TEXT)
	_list.add_theme_color_override("font_selected_color", Color.WHITE)
	var sel := StyleBoxFlat.new()
	sel.bg_color = Pal.RED_DEEP
	_list.add_theme_stylebox_override("selected", sel)
	_list.add_theme_stylebox_override("selected_focus", sel)
	_list.item_activated.connect(_on_pick)
	_list.item_selected.connect(_on_pick)
	v.add_child(_list)
	var row := HBoxContainer.new()
	_manual.placeholder_text = "…or type a package name (com.example.game)"
	_manual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_manual)
	var ok := Button.new()
	ok.text = "ADD"
	ok.pressed.connect(func() -> void:
		var p := _manual.text.strip_edges()
		if p != "":
			_add({"package": p, "label": p.get_extension().capitalize() if "." in p else p})
			_manual.text = "")
	row.add_child(ok)
	v.add_child(row)

func _open_picker() -> void:
	_picker.visible = true
	_search.text = ""
	if AndroidBridge.available:
		_apps = AndroidBridge.list_launchable_apps()
	else:
		_apps = [ # desktop preview only: no installed-app list exists off Android
			{"package": "com.example.racer", "label": "Sample Racer (desktop preview)"},
			{"package": "com.example.shooter", "label": "Sample Shooter (desktop preview)"},
		]
	_fill_list()

func _fill_list() -> void:
	_list.clear()
	var q := _search.text.strip_edges().to_lower()
	for a in _apps:
		if q == "" or q in str(a.label).to_lower() or q in str(a.package).to_lower():
			_list.add_item("%s   (%s)" % [a.label, a.package])
			_list.set_item_metadata(_list.item_count - 1, a)

func _on_pick(i: int) -> void:
	_add(_list.get_item_metadata(i))

func _add(entry: Dictionary) -> void:
	for g in Settings.games:
		if g.package == entry.package:
			_picker.visible = false
			return
	Settings.games.append({"package": entry.package, "label": entry.label})
	Settings.save_settings()
	_picker.visible = false
	_refresh()
