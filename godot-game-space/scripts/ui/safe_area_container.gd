class_name SafeAreaContainer
extends MarginContainer
## Keeps its children inside the notch / punch-hole / gesture-bar safe area on 18:9, 20:9 and 21:9 phones.

@export var extra_margin := 8

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().root.size_changed.connect(_update)
	_update()

func _update() -> void:
	var r := safe_rect(self)
	var vis := get_viewport_rect().size
	add_theme_constant_override("margin_left", int(r.position.x) + extra_margin)
	add_theme_constant_override("margin_top", int(r.position.y) + extra_margin)
	add_theme_constant_override("margin_right", int(vis.x - r.end.x) + extra_margin)
	add_theme_constant_override("margin_bottom", int(vis.y - r.end.y) + extra_margin)

## Safe rectangle in the node's own UI coordinates (the stretched canvas, not raw screen pixels).
static func safe_rect(node: Node) -> Rect2:
	var vp := node.get_viewport()
	var vis := vp.get_visible_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if win.x <= 0.0 or win.y <= 0.0 or safe.size.x <= 0.0 or safe.size.y <= 0.0:
		return Rect2(Vector2.ZERO, vis)
	var win_pos := Vector2(DisplayServer.window_get_position())
	safe.position -= win_pos
	safe = safe.intersection(Rect2(Vector2.ZERO, win))
	if safe.size.x <= 0.0:
		return Rect2(Vector2.ZERO, vis)
	var k := vis / win
	return Rect2(safe.position * k, safe.size * k)
