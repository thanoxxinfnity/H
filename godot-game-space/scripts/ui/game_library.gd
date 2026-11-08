class_name GameLibrary
extends Control
## "Game Space" home: auto-detected games as boost-and-launch tiles, per-game profiles, play time and a
## report of your last session. Tap BOOST & PLAY -> intro + real RAM clean -> the game launches.

signal play_game(entry: Dictionary)

const MODE_NAMES := ["Eco · 30 FPS", "Balanced · 60 FPS", "Performance", "X-Boost"]

var _grid := GridContainer.new()
var _picker := Control.new()
var _search := LineEdit.new()
var _list := ItemList.new()
var _manual := LineEdit.new()
var _apps: Array = []
var _stats := Label.new()
var _ring := TextureRect.new()
var _spin := 0.0
var _notice := Label.new()
var _report := Label.new()
var _empty := Label.new()
var _icon_queue: Array = []
# profile popup
var _profile := Control.new()
var _p_title := Label.new()
var _p_mode := OptionButton.new()
var _p_clean := Button.new()
var _p_dnd := Button.new()
var _p_bright_on := Button.new()
var _p_bright := HSlider.new()
var _p_pkg := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = GTTheme.build()
	var bg := ColorRect.new()
	bg.color = Pal.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var carbon := TextureRect.new()
	carbon.texture = Drawables.texture("carbon", 2.0)
	carbon.stretch_mode = TextureRect.STRETCH_TILE
	carbon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	carbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(carbon)
	_ring.texture = Drawables.texture("hud_ring", 1.6)
	_ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ring.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ring.modulate = Color(1, 1, 1, 0.4)
	_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ring)
	var vig := TextureRect.new()
	vig.texture = Drawables.texture("vignette", 2.0)
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig)

	var safe := SafeAreaContainer.new()
	safe.extra_margin = 18
	add_child(safe)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	safe.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var logo := TextureRect.new()
	logo.texture = Drawables.texture("emblem", 0.75)
	logo.custom_minimum_size = Vector2(56, 56)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(logo)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = "GAME SPACE"
	title.add_theme_font_size_override("font_size", 30)
	tv.add_child(title)
	_stats.add_theme_font_size_override("font_size", 13)
	_stats.add_theme_color_override("font_color", Pal.RED_HOT)
	tv.add_child(_stats)
	head.add_child(tv)
	var scan := Button.new()
	scan.text = "SCAN"
	scan.icon = Icons.get_icon("sweep", 32, Pal.TEXT)
	scan.custom_minimum_size = Vector2(0, 56)
	scan.pressed.connect(func() -> void:
		GameScanner.scan()
		_notice.text = "Scanning installed apps…" if AndroidBridge.available else "Desktop preview: the scanner runs on Android.")
	head.add_child(scan)
	var add := Button.new()
	add.text = "+ ADD APP"
	add.icon = Icons.get_icon("bolt", 36, Pal.TEXT)
	add.custom_minimum_size = Vector2(0, 56)
	add.pressed.connect(_open_picker)
	head.add_child(add)
	col.add_child(head)

	var hint := Label.new()
	hint.text = "GAMES ARE FOUND AUTOMATICALLY  ·  SWIPE IN FROM THE UPPER-LEFT / UPPER-RIGHT EDGE FOR THE BOOST PANEL"
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Pal.MUTED
	col.add_child(hint)
	_report.add_theme_font_size_override("font_size", 13)
	_report.add_theme_color_override("font_color", Pal.AMBER)
	col.add_child(_report)
	_notice.add_theme_font_size_override("font_size", 13)
	_notice.add_theme_color_override("font_color", Pal.OK)
	col.add_child(_notice)
	_empty.text = "NO GAMES FOUND YET\nInstall a game (Free Fire, BGMI, Minecraft…) and it appears here by itself."
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.add_theme_font_size_override("font_size", 18)
	_empty.modulate = Pal.MUTED
	_empty.custom_minimum_size = Vector2(0, 120)
	_empty.visible = false
	col.add_child(_empty)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

	_build_picker()
	_build_profile()
	GameScanner.games_changed.connect(_on_games_changed)
	GameSession.session_ended.connect(func(_r: Dictionary) -> void:
		_update_report()
		_refresh())
	get_tree().root.size_changed.connect(_refresh)
	Telemetry.updated.connect(_update_stats)
	_refresh()
	_update_stats()
	_update_report()

func _process(dt: float) -> void:
	if visible:
		_spin += dt * 0.12
		_ring.pivot_offset = _ring.size * 0.5
		_ring.rotation = _spin # the turbine ring from the intro clip keeps turning behind the tiles

func _update_stats() -> void:
	var free := Telemetry.free_ram_mb()
	var temp := "--" if Telemetry.battery_temp_c < 0.0 else "%.0f°C" % Telemetry.battery_temp_c
	_stats.text = "RAM FREE %s   ·   BATTERY %s   ·   MODE %s" % ["--" if free < 0.0 else "%d MB" % int(free), temp, ["ECO", "BALANCED", "PERFORMANCE", "X-BOOST"][clampi(Settings.performance_mode, 0, 3)]]

func _update_report() -> void:
	var r: Dictionary = Settings.last_session
	if r.is_empty():
		_report.text = ""
		return
	var parts: Array = ["LAST SESSION: %s" % str(r.get("label", "")).to_upper(), GameSession.fmt_duration(float(r.get("seconds", 0.0)))]
	if int(r.get("battery_drop", -1)) >= 0:
		parts.append("BATTERY -%d%%" % int(r.battery_drop))
	if float(r.get("temp_c", -1.0)) > 0.0:
		parts.append("%.0f°C" % float(r.temp_c))
	if float(r.get("freed_mb", 0.0)) > 0.5:
		parts.append("%d MB FREED AT LAUNCH" % int(float(r.freed_mb)))
	_report.text = "   ·   ".join(parts)

# ---------------------------------------------------------------- tiles
func _sorted_games() -> Array:
	var g: Array = Settings.games.duplicate()
	g.sort_custom(func(a, b) -> bool:
		var la: float = GameSession.stats_for(str(a.package)).last
		var lb: float = GameSession.stats_for(str(b.package)).last
		if la != lb:
			return la > lb
		return str(a.label).naturalnocasecmp_to(str(b.label)) < 0)
	return g

func _refresh() -> void:
	var w := get_viewport_rect().size.x
	_grid.columns = maxi(2, int((w - 36.0) / 190.0))
	for c in _grid.get_children():
		c.queue_free()
	_icon_queue.clear()
	for g in _sorted_games():
		var t := _tile(g)
		_grid.add_child(t)
		_icon_queue.append(t)
	_empty.visible = Settings.games.is_empty()
	_load_icons()

func _tile(entry: Dictionary) -> Control:
	var pkg := str(entry.get("package", ""))
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(176, 236)
	tile.add_theme_stylebox_override("panel", Drawables.box("tile_frame", 22, 1.0, 10))
	tile.set_meta("pkg", pkg)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	tile.add_child(v)
	var top := HBoxContainer.new()
	top.custom_minimum_size = Vector2(0, 26)
	var gear := Button.new()
	gear.icon = Icons.get_icon("cpu", 22, Pal.AMBER)
	gear.flat = true
	gear.custom_minimum_size = Vector2(28, 26)
	gear.pressed.connect(func() -> void: _open_profile(entry))
	top.add_child(gear)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var rm := Button.new()
	rm.icon = Icons.get_icon("close", 22, Pal.MUTED)
	rm.flat = true
	rm.custom_minimum_size = Vector2(28, 26)
	rm.pressed.connect(func() -> void: _remove(entry))
	top.add_child(rm)
	v.add_child(top)
	# icon holder: letter badge underneath, the game's real icon on top once it is available
	var holder := Control.new()
	holder.name = "Holder"
	holder.custom_minimum_size = Vector2(84, 84)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var badge := Badge.new()
	badge.setup(str(entry.get("label", "?")), pkg)
	badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(badge)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.visible = false
	holder.add_child(icon)
	v.add_child(holder)
	var name_label := Label.new()
	name_label.text = str(entry.get("label", "Game")).to_upper()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(0, 36)
	name_label.add_theme_font_size_override("font_size", 14)
	v.add_child(name_label)
	var st := GameSession.stats_for(pkg)
	var played := Label.new()
	played.text = "NEW" if int(st.launches) == 0 else "%s  ·  %d LAUNCH%s" % [GameSession.fmt_duration(float(st.seconds)), int(st.launches), "" if int(st.launches) == 1 else "ES"]
	played.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	played.add_theme_font_size_override("font_size", 10)
	played.modulate = Pal.MUTED
	v.add_child(played)
	var play := Button.new()
	play.text = "BOOST & PLAY"
	play.custom_minimum_size = Vector2(0, 44)
	play.add_theme_font_size_override("font_size", 14)
	play.pressed.connect(func() -> void: play_game.emit(entry))
	v.add_child(play)
	return tile

func _icon_path(pkg: String) -> String:
	return "user://icons/%s.png" % pkg

func _load_icons() -> void:
	for t in _icon_queue:
		if not is_instance_valid(t):
			continue
		var pkg := str(t.get_meta("pkg"))
		var tex: Texture2D = null
		var path := _icon_path(pkg)
		if FileAccess.file_exists(path): # cached from an earlier visit: instant
			var img := Image.load_from_file(path)
			if img != null and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
		if tex == null and AndroidBridge.available:
			await get_tree().process_frame
			if not is_instance_valid(t):
				continue
			tex = AndroidBridge.app_icon(pkg, 128)
			if tex != null:
				DirAccess.make_dir_recursive_absolute("user://icons")
				tex.get_image().save_png(path)
		if tex != null and is_instance_valid(t):
			var icon: TextureRect = t.get_node("VBoxContainer/Holder/Icon")
			icon.texture = tex
			icon.visible = true

func _remove(entry: Dictionary) -> void:
	GameScanner.forget(str(entry.package))
	_refresh()

func _on_games_changed(added: Array, removed: Array) -> void:
	var parts: Array = []
	if not added.is_empty():
		parts.append("NEW GAME: " + ", ".join(added.map(func(g) -> String: return str(g.label))))
	if not removed.is_empty():
		parts.append("REMOVED: " + ", ".join(removed.map(func(g) -> String: return str(g.label))))
	_notice.text = "   ·   ".join(parts)
	_refresh()

# ---------------------------------------------------------------- per-game profile
func _build_profile() -> void:
	_profile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_profile.visible = false
	add_child(_profile)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_profile.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Drawables.box("panel_chamfer", 24, 1.0, 20))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(520, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_profile.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	_p_title.add_theme_font_size_override("font_size", 22)
	v.add_child(_p_title)
	var sub := Label.new()
	sub.text = "GAME PROFILE  ·  applied when you BOOST & PLAY"
	sub.add_theme_font_size_override("font_size", 11)
	sub.modulate = Pal.MUTED
	v.add_child(sub)
	for i in MODE_NAMES.size():
		_p_mode.add_item(MODE_NAMES[i], i)
	_p_mode.custom_minimum_size = Vector2(0, 48)
	v.add_child(_p_mode)
	for b in [_p_clean, _p_dnd, _p_bright_on]:
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 48)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(b)
	_p_clean.text = " Close background apps (free RAM)"
	_p_dnd.text = " Do Not Disturb while playing"
	_p_bright_on.text = " Set screen brightness while playing"
	_p_bright_on.toggled.connect(func(on: bool) -> void:
		_p_bright.editable = on
		if on and AndroidBridge.available and not AndroidBridge.can_write_settings():
			AndroidBridge.request_write_settings())
	_p_bright.min_value = 0.1
	_p_bright.max_value = 1.0
	_p_bright.step = 0.01
	_p_bright.custom_minimum_size = Vector2(0, 32)
	v.add_child(_p_bright)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var cancel := Button.new()
	cancel.text = "CANCEL"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(func() -> void: _profile.visible = false)
	row.add_child(cancel)
	var save := Button.new()
	save.text = "SAVE"
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save.pressed.connect(_save_profile)
	row.add_child(save)
	v.add_child(row)

func _open_profile(entry: Dictionary) -> void:
	_p_pkg = str(entry.package)
	var p := GameSession.profile_for(_p_pkg)
	_p_title.text = str(entry.label).to_upper()
	_p_mode.select(int(p.mode))
	_p_clean.button_pressed = bool(p.clean)
	_p_dnd.button_pressed = bool(p.dnd)
	_p_bright_on.set_pressed_no_signal(float(p.bright) >= 0.0)
	_p_bright.value = float(p.bright) if float(p.bright) >= 0.0 else 0.8
	_p_bright.editable = float(p.bright) >= 0.0
	_profile.visible = true

func _save_profile() -> void:
	Settings.profiles[_p_pkg] = {"mode": _p_mode.selected, "clean": _p_clean.button_pressed, "dnd": _p_dnd.button_pressed, "bright": _p_bright.value if _p_bright_on.button_pressed else -1.0}
	Settings.save_settings()
	_profile.visible = false

# ---------------------------------------------------------------- manual add picker
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
	t.text = "ADD ANY APP MANUALLY"
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
		_apps = [{"package": "com.example.app", "label": "Sample App (desktop preview)"}]
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
	Settings.ignored.erase(entry.package)
	for g in Settings.games:
		if g.package == entry.package:
			_picker.visible = false
			return
	Settings.games.append({"package": entry.package, "label": entry.label})
	Settings.save_settings()
	_picker.visible = false
	_refresh()

## Placeholder icon (coloured rounded plate + initial) shown until the game's own icon is loaded from Android.
class Badge extends Control:
	var _letter := "?"
	var _col := Pal.RED

	func setup(label: String, pkg: String) -> void:
		_letter = label.substr(0, 1).to_upper()
		var palette := [Pal.RED, Pal.ORANGE, Color("d81b60"), Color("ff3d00"), Color("c2185b"), Color("e53935")]
		_col = palette[abs(pkg.hash()) % palette.size()]

	func _draw() -> void:
		var s := size
		var cut := s.x * 0.22
		var pts := PackedVector2Array([Vector2(cut, 0), Vector2(s.x, 0), Vector2(s.x, s.y - cut), Vector2(s.x - cut, s.y), Vector2(0, s.y), Vector2(0, cut)])
		draw_colored_polygon(pts, Color(_col, 0.22))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[5], pts[0]]), _col, 3.0)
		var f := ThemeDB.fallback_font
		var fs := int(s.y * 0.55)
		var w := f.get_string_size(_letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2((s.x - w) * 0.5, s.y * 0.7), _letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.TEXT)
