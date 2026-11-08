class_name DemoGame
extends Node2D
## Tiny stand-in "game" with fine lines and text, so the CAS sharpening is easy to see.

var _t := 0.0

func _process(dt: float) -> void:
	_t += dt
	queue_redraw()

func _draw() -> void:
	var size := get_viewport().get_visible_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.07, 0.12))
	var step := 32.0
	var x := 0.0
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.2, 0.25, 0.4, 0.6), 1.0)
		x += step
	var y := 0.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.2, 0.25, 0.4, 0.6), 1.0)
		y += step
	for i in 6:
		var a := _t * (0.6 + i * 0.15) + i
		var c := size * 0.5 + Vector2(cos(a), sin(a * 1.3)) * Vector2(size.x * 0.32, size.y * 0.28)
		draw_circle(c, 16.0 + i * 3.0, Color.from_hsv(fmod(0.1 * i + _t * 0.05, 1.0), 0.7, 1.0))
		draw_arc(c, 26.0 + i * 3.0, 0, TAU, 48, Color.WHITE, 1.5, true)
	draw_string(ThemeDB.fallback_font, size * 0.5 - Vector2(190, 0), "Swipe from the left edge for Game Space", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
