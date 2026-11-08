class_name UpscalerManager
extends Control
## Spatial super-resolution for the whole game: the game renders in a SubViewport at a fraction of the
## screen resolution and is shown full screen through the CAS (contrast adaptive sharpening) shader.
## Less pixels to shade = lower GPU load and heat; the sharpening hides most of the lost detail.

signal mode_changed(mode: int)

const MODES := [
	{"name": "Off", "scale": 1.0, "sharp": 0.0},
	{"name": "Balanced", "scale": 0.77, "sharp": 0.55},
	{"name": "Ultra Performance", "scale": 0.59, "sharp": 0.85},
]

var mode := 1
var _viewport := SubViewport.new()
var _view := TextureRect.new()
var _material := ShaderMaterial.new()

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.transparent_bg = false
	_viewport.msaa_2d = Viewport.MSAA_DISABLED
	_viewport.handle_input_locally = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	_material.shader = load("res://scripts/optional/cas.gdshader")
	_view.texture = _viewport.get_texture()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)

	get_tree().root.size_changed.connect(_resize)
	set_mode(Settings.sr_mode, false)

func add_game_node(node: Node) -> void:
	_viewport.add_child(node)

## Stops rendering the game while another screen (the home) covers it.
func set_active(on: bool) -> void:
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	_view.visible = on

func get_game_viewport() -> SubViewport:
	return _viewport

func set_mode(new_mode: int, save := true) -> void:
	mode = clampi(new_mode, 0, MODES.size() - 1)
	var m: Dictionary = MODES[mode]
	_material.set_shader_parameter("sharpness", m.sharp)
	_view.material = null if mode == 0 else _material
	_resize()
	if save:
		Settings.sr_mode = mode
		Settings.save_settings()
	mode_changed.emit(mode)

func render_size() -> Vector2i:
	return _viewport.size

func _resize() -> void:
	var win := Vector2(get_tree().root.size)
	var s: float = MODES[mode].scale
	_viewport.size = Vector2i(maxi(1, int(win.x * s)), maxi(1, int(win.y * s)))

## The game lives in a SubViewport, so forward input the UI did not use (positions are rescaled).
func _unhandled_input(event: InputEvent) -> void:
	var ev := event.duplicate() as InputEvent
	var ratio := float(_viewport.size.x) / maxf(1.0, get_viewport_rect().size.x)
	var mouse := ev as InputEventMouse
	var touch := ev as InputEventScreenTouch
	var drag := ev as InputEventScreenDrag
	if mouse != null:
		mouse.position *= ratio
		mouse.global_position *= ratio
	elif touch != null:
		touch.position *= ratio
	elif drag != null:
		drag.position *= ratio
	_viewport.push_input(ev)
