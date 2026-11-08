class_name MagicLight
extends Control
## "Cyber light": animated RGB light strip running around the screen border (like the LED lighting on gaming
## phones). Also used by the intro. Redraws at 30 Hz, 96 line segments: negligible cost.

const THEMES := ["Crimson", "Inferno", "Rainbow", "Red alert", "Red + Cyan"]

var _acc := 0.0
var _t := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(dt: float) -> void:
	visible = Settings.light_on
	if not visible:
		return
	_t += dt
	_acc += dt
	if _acc >= 1.0 / 30.0:
		_acc = 0.0
		queue_redraw()

func _draw() -> void:
	var theme := Settings.light_theme
	var strength := 0.55
	if Telemetry.battery_temp_c >= PerformanceBooster.THERMAL_LIMIT_C:
		theme = 3 # pulses alarm-red when the phone runs hot
		strength = 0.9
	draw_border(self, size, _t, theme, strength, 4.0)

static func _perimeter(u: float, s: Vector2) -> Vector2:
	var d := u * 2.0 * (s.x + s.y)
	if d < s.x:
		return Vector2(d, 0.0)
	d -= s.x
	if d < s.y:
		return Vector2(s.x, d)
	d -= s.y
	if d < s.x:
		return Vector2(s.x - d, s.y)
	d -= s.x
	return Vector2(0.0, s.y - d)

static func color_at(theme: int, h: float, t: float) -> Color:
	match theme:
		1: return Color.from_hsv(0.02 + 0.07 * (0.5 + 0.5 * sin(h * TAU * 2.0)), 0.95, 1.0) # red -> orange fire
		2: return Color.from_hsv(fmod(h, 1.0), 0.9, 1.0)
		3: return Color.from_hsv(0.0 + 0.02 * sin(h * TAU * 2.0), 0.95, 0.6 + 0.4 * (0.5 + 0.5 * sin(t * 6.0)))
		4: return Color(0.0, 0.95, 1.0) if fmod(h * 4.0, 2.0) < 1.0 else Color(1.0, 0.15, 0.25)
	return Color.from_hsv(0.99 + 0.02 * sin(h * TAU), 0.92, 1.0) # crimson

static func draw_border(c: CanvasItem, s: Vector2, t: float, theme: int, strength := 0.6, thickness := 4.0) -> void:
	var n := 96
	for i in n:
		var u0 := float(i) / n
		var u1 := float(i + 1) / n
		var h := fmod(u0 + t * 0.22, 1.0)
		var pulse := 0.65 + 0.35 * sin((u0 * 6.0 - t * 3.0) * TAU * 0.5)
		var col := color_at(theme, h, t)
		col.a = clampf(strength * pulse, 0.0, 1.0)
		c.draw_line(_perimeter(u0, s), _perimeter(u1, s), col, thickness)
