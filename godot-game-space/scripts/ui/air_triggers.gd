class_name AirTriggers
extends Control
## On-screen shoulder triggers (like the capacitive "air triggers" on gaming phones). Each trigger is a
## translucent pad in an upper corner; pressing it injects a touch into the game at a position you map
## (drawer > Air Triggers > Map). Supports holding and multi-touch (both triggers + your thumbs at once).

signal mapping_finished

var upscaler: UpscalerManager
var _pads: Array[Control] = []
var _held := [false, false]
var _map_overlay := Control.new()
var _map_hint := Label.new()
var _mapping := -1

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 2:
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(96, 96)
		pad.size = Vector2(96, 96)
		pad.mouse_filter = Control.MOUSE_FILTER_STOP
		pad.draw.connect(_draw_pad.bind(pad, i))
		pad.gui_input.connect(_on_pad_input.bind(i))
		add_child(pad)
		_pads.append(pad)
	_map_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_map_overlay.visible = false
	_map_overlay.gui_input.connect(_on_map_input)
	add_child(_map_overlay)
	_map_hint.add_theme_font_size_override("font_size", 24)
	_map_hint.set_anchors_preset(Control.PRESET_CENTER)
	_map_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_map_overlay.add_child(_map_hint)
	get_tree().root.size_changed.connect(_layout)
	_layout()

func _process(_dt: float) -> void:
	var on := Settings.triggers_on
	for p in _pads:
		p.visible = on
	if on:
		_layout()

func _layout() -> void:
	var safe := SafeAreaContainer.safe_rect(self)
	if _pads.size() < 2:
		return
	_pads[0].position = Vector2(safe.position.x + 56.0, safe.position.y + safe.size.y * 0.16)
	_pads[1].position = Vector2(safe.end.x - 56.0 - 96.0, safe.position.y + safe.size.y * 0.16)

func _draw_pad(pad: Control, idx: int) -> void:
	var c := pad.size * 0.5
	var col := Color(0.0, 0.95, 1.0) if idx == 0 else Color(1.0, 0.17, 0.84)
	var down: bool = _held[idx]
	pad.draw_circle(c, 44.0, Color(col, 0.35 if down else 0.12))
	pad.draw_arc(c, 44.0, 0.0, TAU, 48, Color(col, 0.9 if down else 0.55), 3.0, true)
	pad.draw_string(ThemeDB.fallback_font, c + Vector2(-8, 8), "L" if idx == 0 else "R", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.85))

func _on_pad_input(event: InputEvent, idx: int) -> void:
	var t := event as InputEventScreenTouch
	var m := event as InputEventMouseButton
	var pressed := false
	var released := false
	if t != null:
		pressed = t.pressed
		released = not t.pressed
	elif m != null and m.button_index == MOUSE_BUTTON_LEFT:
		pressed = m.pressed
		released = not m.pressed
	else:
		return
	if pressed and not _held[idx]:
		_held[idx] = true
		_inject(idx, true)
	elif released and _held[idx]:
		_held[idx] = false
		_inject(idx, false)
	_pads[idx].queue_redraw()

func _inject(idx: int, down: bool) -> void:
	if upscaler == null:
		return
	var vp := upscaler.get_game_viewport()
	var norm: Vector2 = Settings.trigger_l if idx == 0 else Settings.trigger_r
	var pos := norm * Vector2(vp.size)
	var touch := InputEventScreenTouch.new()
	touch.index = 20 + idx
	touch.pressed = down
	touch.position = pos
	vp.push_input(touch)
	var click := InputEventMouseButton.new() # for games that read the mouse instead of touch
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = down
	click.position = pos
	click.global_position = pos
	vp.push_input(click)

## Start mapping: the next tap anywhere on the game sets the target of trigger `idx` (0 = L, 1 = R).
func begin_mapping(idx: int) -> void:
	_mapping = idx
	_map_hint.text = "Tap where trigger %s should press" % ("L" if idx == 0 else "R")
	_map_overlay.visible = true
	_map_overlay.move_to_front()

func _on_map_input(event: InputEvent) -> void:
	var t := event as InputEventScreenTouch
	var m := event as InputEventMouseButton
	var pos := Vector2.ZERO
	if t != null and t.pressed:
		pos = t.position
	elif m != null and m.pressed:
		pos = m.position
	else:
		return
	var norm := pos / get_viewport_rect().size
	if _mapping == 0:
		Settings.trigger_l = norm
	else:
		Settings.trigger_r = norm
	Settings.save_settings()
	_map_overlay.visible = false
	_mapping = -1
	mapping_finished.emit()
