class_name DemoGame
extends Node2D
## Stand-in "game" with fine lines, text and motion so the CAS sharpening and FPS are easy to judge.
## Replace it with your real game scene: upscaler.add_game_node(my_game).

var _t := 0.0

func _process(dt: float) -> void:
	_t += dt
	queue_redraw()

func _draw() -> void:
	var size := get_viewport().get_visible_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.06, 0.11))
	var step := maxf(24.0, size.y / 18.0)
	var x := 0.0
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.2, 0.25, 0.4, 0.55), 1.0)
		x += step
	var y := 0.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.2, 0.25, 0.4, 0.55), 1.0)
		y += step
	for i in 7:
		var a := _t * (0.6 + i * 0.15) + i
		var c := size * 0.5 + Vector2(cos(a), sin(a * 1.3)) * Vector2(size.x * 0.32, size.y * 0.28)
		var r := size.y * (0.03 + i * 0.006)
		draw_circle(c, r, Color.from_hsv(fmod(0.1 * i + _t * 0.05, 1.0), 0.7, 1.0))
		draw_arc(c, r * 1.6, 0, TAU, 48, Color.WHITE, 1.5, true)
	var msg := "Swipe in from the upper-left or upper-right edge for Game Space"
	var fs := int(clampf(size.y * 0.04, 14.0, 28.0))
	var w := ThemeDB.fallback_font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(ThemeDB.fallback_font, Vector2((size.x - w) * 0.5, size.y * 0.92), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.85))
