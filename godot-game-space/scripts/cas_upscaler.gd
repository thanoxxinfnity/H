class_name CasUpscaler
extends Control
## Renders the game into a SubViewport at (window size x render_scale), then shows it full screen
## through the CAS shader. Add game content with `add_game_node()`.

var _viewport := SubViewport.new()
var _view := TextureRect.new()
var _material := ShaderMaterial.new()
var _enabled := true
var _scale := 0.75

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.transparent_bg = false
	_viewport.handle_input_locally = false
	_viewport.gui_disable_input = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	_material.shader = load("res://shaders/cas.gdshader")
	_view.texture = _viewport.get_texture()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)

	get_tree().root.size_changed.connect(_resize)
	apply(Settings.cas_enabled, Settings.cas_sharpness, Settings.render_scale)

func add_game_node(node: Node) -> void:
	_viewport.add_child(node)

func apply(enabled: bool, sharpness: float, render_scale: float) -> void:
	_enabled = enabled
	_scale = clampf(render_scale, 0.5, 1.0)
	_material.set_shader_parameter("sharpness", clampf(sharpness, 0.0, 1.0))
	# With CAS off the viewport is shown 1:1 without any sharpening (and at full resolution).
	_view.material = _material if _enabled else null
	_resize()

func _resize() -> void:
	var win := Vector2(get_tree().root.size)
	var s := _scale if _enabled else 1.0
	_viewport.size = Vector2i(maxi(1, int(win.x * s)), maxi(1, int(win.y * s)))

## The game lives in a SubViewport, so forward input the UI did not use (mouse positions are rescaled).
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
