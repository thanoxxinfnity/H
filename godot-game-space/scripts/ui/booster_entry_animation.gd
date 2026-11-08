class_name BoosterEntryAnimation
extends Control
## Cyberpunk "game booster" boot sequence: scan line, CPU / GPU frequency dials ramping up, RAM sweep,
## particle ignition, status ticker. Timeline is an AnimationPlayer; the dials/ticker use Tweens.
## If an AI-generated clip is cached it plays behind the HUD; if the API is offline or the format cannot be
## decoded, the fully procedural version below runs by itself (no assets needed).
## Cost: one _draw pass of ~150 primitives per frame + one CPUParticles2D burst - fine for 4 GB phones at 60 FPS.

signal finished

const LENGTH := 4.2 # procedural intro length; with a clip it is the clip length
const NEON := Color(1.0, 0.12, 0.24) # red (name kept)
const PINK := Color(1.0, 0.42, 0.1) # orange
const LIME := Color(1.0, 0.8, 0.2)

# Animated by the AnimationPlayer (setters redraw).
var scan := 0.0: set = _set_scan
var flash := 0.0: set = _set_flash
# Animated by Tweens.
var cpu := 0.0: set = _set_cpu
var gpu := 0.0: set = _set_gpu
var ram_sweep := 0.0: set = _set_ram

var _player := AnimationPlayer.new()
var _particles := CPUParticles2D.new()
var _ember := CPUParticles2D.new()
var _status := "STANDBY"
var _bg_media: Node
var _playing := false
var _cpu_target := 0.92
var _gpu_target := 0.88
var _freed_text := ""
var _clock := 0.0
var _len := LENGTH
var _anim_name := "boot0"
var _runs := 0
var target_name := "" # game being launched, shown under the title

func _set_scan(v: float) -> void: scan = v; queue_redraw()
func _set_flash(v: float) -> void: flash = v; queue_redraw()
func _set_cpu(v: float) -> void: cpu = v; queue_redraw()
func _set_gpu(v: float) -> void: gpu = v; queue_redraw()
func _set_ram(v: float) -> void: ram_sweep = v; queue_redraw()

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_particles()
	_build_animation()
	gui_input.connect(_on_gui_input)

## Starts the intro. `media_path` is an optional cached AI animation (see AIVideoGenerator).
func play(media_path := "", clip_seconds := 8.0) -> void:
	if _playing:
		return
	_playing = true
	visible = true
	modulate.a = 0.0
	if _bg_media != null:
		_bg_media.queue_free()
		_bg_media = null
	if media_path != "":
		_bg_media = AIVideoGenerator.play_into(self, media_path, true)
		if _bg_media is CanvasItem:
			(_bg_media as CanvasItem).show_behind_parent = true # clip behind the HUD that _draw() paints
	_len = clip_seconds if _bg_media != null else LENGTH
	_rebuild_animation()
	_particles.visible = _bg_media == null
	Engine.max_fps = 60 # lock the intro to 60 FPS
	_cpu_target = clampf(maxf(Telemetry.cpu_load, 0.0) * 0.35 + 0.62, 0.7, 0.98)
	_gpu_target = clampf(_cpu_target - 0.05 + randf() * 0.06, 0.7, 0.97)
	cpu = 0.0
	gpu = 0.0
	ram_sweep = 0.0
	_freed_text = ""
	_player.play(_anim_name)

	var t := create_tween().set_parallel(true)
	t.tween_property(self, "cpu", _cpu_target, 1.7).set_delay(0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "gpu", _gpu_target, 1.7).set_delay(0.8).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "ram_sweep", 1.0, 1.1).set_delay(1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var k := _len / LENGTH
	var s := create_tween()
	s.tween_callback(_set_status.bind("INITIALIZING CORE")).set_delay(0.3 * k)
	s.tween_callback(_set_status.bind("CPU / GPU RAMP-UP")).set_delay(0.7 * k)
	s.tween_callback(_set_status.bind("SWEEPING MEMORY")).set_delay(0.9 * k)
	s.tween_callback(func() -> void:
		_set_status("IGNITION")
		if _bg_media == null:
			_particles.restart()
			_ember.emitting = true).set_delay(1.0 * k)
	s.tween_callback(_set_status.bind("BOOST ENGAGED")).set_delay(0.7 * k)

func set_result(r: Dictionary) -> void:
	var freed: float = r.get("freed_mb", -1.0)
	var killed: int = r.get("killed", 0)
	if freed > 0.5:
		_freed_text = "+%d MB FREE" % int(freed)
	elif killed > 0:
		_freed_text = "%d BACKGROUND APPS CLOSED" % killed
	queue_redraw()

func _set_status(text: String) -> void:
	_status = text
	queue_redraw()

func _on_gui_input(event: InputEvent) -> void:
	var tap := event as InputEventScreenTouch
	if _playing and tap != null and tap.pressed and _player.current_animation_position > 0.8:
		_player.seek(maxf(0.0, _len - 0.45), true) # tap to skip: jump to the fade-out

func _on_done() -> void:
	_playing = false
	_ember.emitting = false
	if _bg_media != null:
		_bg_media.queue_free()
		_bg_media = null
	visible = false
	finished.emit()

# ------------------------------------------------------------------ build
func _build_animation() -> void:
	var lib := AnimationLibrary.new()
	_player.add_animation_library("", lib)
	add_child(_player)
	_rebuild_animation()

func _rebuild_animation() -> void:
	var a := Animation.new()
	a.length = _len
	var i := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(i, ".:modulate:a")
	a.track_insert_key(i, 0.0, 0.0)
	a.track_insert_key(i, 0.35, 1.0)
	a.track_insert_key(i, _len - 0.5, 1.0)
	a.track_insert_key(i, _len, 0.0)
	i = a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(i, ".:scan")
	a.track_insert_key(i, 0.0, 0.0)
	a.track_insert_key(i, 2.3, 1.0)
	i = a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(i, ".:flash")
	a.track_insert_key(i, 0.0, 0.0)
	a.track_insert_key(i, 2.28, 0.0)
	a.track_insert_key(i, 2.38, 1.0)
	a.track_insert_key(i, 3.0, 0.0)
	i = a.add_track(Animation.TYPE_METHOD)
	a.track_set_path(i, ".")
	a.track_insert_key(i, _len, {"method": "_on_done", "args": []})
	var lib := _player.get_animation_library("")
	_player.stop()
	if lib.has_animation(_anim_name):
		lib.remove_animation(_anim_name)
	_runs += 1
	_anim_name = "boot%d" % _runs # a fresh name each run: AnimationPlayer keeps the old resource cached otherwise
	lib.add_animation(_anim_name, a)

func _build_particles() -> void:
	_particles.one_shot = true
	_particles.emitting = false
	_particles.amount = 140
	_particles.lifetime = 1.1
	_particles.explosiveness = 1.0
	_particles.spread = 180.0
	_particles.direction = Vector2.UP
	_particles.gravity = Vector2.ZERO
	_particles.initial_velocity_min = 260.0
	_particles.initial_velocity_max = 760.0
	_particles.damping_min = 120.0
	_particles.damping_max = 240.0
	_particles.scale_amount_min = 2.0
	_particles.scale_amount_max = 5.0
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1.0, 0.17, 0.84, 0.0))
	g.add_point(0.35, NEON)
	_particles.color_ramp = g
	add_child(_particles)

	_ember.emitting = false
	_ember.amount = 36
	_ember.lifetime = 1.6
	_ember.direction = Vector2.UP
	_ember.spread = 35.0
	_ember.gravity = Vector2(0, -60)
	_ember.initial_velocity_min = 40.0
	_ember.initial_velocity_max = 140.0
	_ember.scale_amount_min = 1.5
	_ember.scale_amount_max = 3.0
	_ember.color = Color(0.0, 0.95, 1.0, 0.8)
	add_child(_ember)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_instance_valid(_particles):
		var c := size * 0.5
		_particles.position = c
		_ember.position = Vector2(c.x, size.y * 0.82)
		_ember.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		_ember.emission_rect_extents = Vector2(size.x * 0.35, 4)

# ------------------------------------------------------------------ draw
func _draw() -> void:
	var s := size
	var safe := SafeAreaContainer.safe_rect(self)
	if _bg_media != null:
		_draw_video_overlay(s, safe)
		return
	if _bg_media == null:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.03, 0.01, 0.02))
		draw_texture_rect(Drawables.texture("hex_bg", maxf(1.0, s.x / 640.0)), Rect2(Vector2.ZERO, s), false)
		_draw_grid(s)
	else:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.35))
	_draw_turbine(safe)
	_draw_armor(s)
	MagicLight.draw_border(self, s, _clock, 0, 0.35 + 0.6 * clampf(cpu, 0.0, 1.0), 6.0)
	# scan line + trailing glow
	var y := s.y * scan
	if scan > 0.0 and scan < 1.0:
		for k in 6:
			draw_line(Vector2(0, y - k * 3.0), Vector2(s.x, y - k * 3.0), Color(NEON, 0.5 / (k + 1)), 2.0)
	var center := safe.get_center()
	var r := minf(safe.size.y * 0.30, safe.size.x * 0.2)
	_draw_dial(Vector2(safe.position.x + safe.size.x * 0.22, center.y), r, cpu, "CPU", NEON)
	_draw_dial(Vector2(safe.end.x - safe.size.x * 0.22, center.y), r, gpu, "GPU", PINK)
	_draw_ram(Rect2(center.x - safe.size.x * 0.17, center.y + r * 0.2, safe.size.x * 0.34, 16.0))
	var font := ThemeDB.fallback_font
	var title_size := int(clampf(safe.size.y * 0.085, 22.0, 60.0))
	var title := "GAME BOOSTER"
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	var tp := Vector2(center.x - tw * 0.5, center.y - r * 0.55)
	draw_string(font, tp + Vector2(2, 2), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(PINK, 0.6))
	draw_string(font, tp, title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color.WHITE)
	var ss := int(clampf(safe.size.y * 0.04, 13.0, 24.0))
	var sw := font.get_string_size(_status, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x
	draw_string(font, Vector2(center.x - sw * 0.5, center.y - r * 0.55 + ss * 2.0), _status, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, NEON)
	if target_name != "":
		var nl := "LAUNCHING: " + target_name.to_upper()
		var nw := font.get_string_size(nl, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x
		draw_string(font, Vector2(center.x - nw * 0.5, center.y - r * 0.55 + ss * 3.6), nl, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, Color(1, 1, 1, 0.9))
	if _freed_text != "":
		var fw := font.get_string_size(_freed_text, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x
		draw_string(font, Vector2(center.x - fw * 0.5, center.y + r * 0.2 + 16 + ss * 2.0), _freed_text, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, LIME)
	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, flash * 0.55))
		draw_circle(center, s.y * 0.6 * flash, Color(NEON, 0.12 * flash))

func _draw_grid(s: Vector2) -> void:
	var step := 48.0
	var x := fmod(Time.get_ticks_msec() * 0.02, step)
	while x < s.x:
		draw_line(Vector2(x, 0), Vector2(x, s.y), Color(0.6, 0.1, 0.15, 0.16), 1.0)
		x += step
	var yy := 0.0
	while yy < s.y:
		draw_line(Vector2(0, yy), Vector2(s.x, yy), Color(0.6, 0.1, 0.15, 0.16), 1.0)
		yy += step

func _draw_dial(c: Vector2, r: float, value: float, label: String, col: Color) -> void:
	var a0 := deg_to_rad(135.0)
	var span := deg_to_rad(270.0)
	draw_arc(c, r, a0, a0 + span, 64, Color(1, 1, 1, 0.10), 6.0, true)
	for i in 28:
		var t := i / 27.0
		var ang := a0 + span * t
		var long_tick := i % 3 == 0
		var p1 := c + Vector2.from_angle(ang) * (r - (14.0 if long_tick else 9.0))
		var p2 := c + Vector2.from_angle(ang) * (r - 4.0)
		draw_line(p1, p2, Color(col, 0.9 if t <= value else 0.2), 2.0)
	draw_arc(c, r, a0, a0 + span * value, 64, col, 7.0, true)
	draw_arc(c, r * 0.72, a0, a0 + span * value, 48, Color(col, 0.35), 3.0, true)
	var needle := c + Vector2.from_angle(a0 + span * value) * (r - 18.0)
	draw_line(c, needle, Color.WHITE, 3.0)
	draw_circle(c, 7.0, col)
	var font := ThemeDB.fallback_font
	var fs := int(r * 0.34)
	var txt := "%d%%" % int(value * 100.0)
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(c.x - w * 0.5, c.y + r * 0.62), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(r * 0.2)).x
	draw_string(font, Vector2(c.x - lw * 0.5, c.y + r * 1.0 + 6.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(r * 0.2), Color(col, 0.9))

func _draw_ram(rect: Rect2) -> void:
	draw_rect(rect, Color(1, 1, 1, 0.08))
	var cells := 24
	var cw := rect.size.x / cells
	var head := ram_sweep * (cells + 4)
	for i in cells:
		var d := head - i
		var a := clampf(1.0 - absf(d - 2.0) / 4.0, 0.0, 1.0)
		var filled := ram_sweep >= 1.0
		var col := LIME if filled else NEON
		draw_rect(Rect2(rect.position.x + i * cw + 1.0, rect.position.y, cw - 2.0, rect.size.y), Color(col, 0.85 if filled else a))
	var font := ThemeDB.fallback_font
	draw_string(font, rect.position + Vector2(0, rect.size.y + 20.0), "RAM", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.7))

## Spinning cooling-turbine rings behind the dials; they speed up as the CPU dial rises.
func _draw_turbine(safe: Rect2) -> void:
	var c := safe.get_center()
	var base := minf(safe.size.x, safe.size.y) * 0.5
	var spin := _clock * (1.0 + 7.0 * cpu)
	for ring in 3:
		var r := base * (0.55 + 0.22 * ring)
		var dir := 1.0 if ring % 2 == 0 else -1.0
		var col := NEON if ring != 1 else PINK
		for seg in 14:
			var a0 := spin * dir * (0.6 + 0.25 * ring) + seg * TAU / 14.0
			draw_arc(c, r, a0, a0 + TAU / 14.0 * 0.58, 8, Color(col, 0.16 + 0.34 * cpu), 3.0 + ring, true)
	draw_circle(c, base * 0.12 * (0.6 + cpu), Color(NEON, 0.10 + 0.25 * cpu))

## Two heavy armor plates that start closed and slide apart as the scan line sweeps down.
func _draw_armor(s: Vector2) -> void:
	var open := smoothstep(0.08, 0.55, scan)
	if open >= 1.0:
		return
	var h := s.y * 0.5 * (1.0 - open)
	var steel := Color(0.05, 0.07, 0.11)
	var top := PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, h * 0.9), Vector2(s.x * 0.5, h), Vector2(0, h * 0.9)])
	var bot := PackedVector2Array([Vector2(0, s.y), Vector2(s.x, s.y), Vector2(s.x, s.y - h * 0.9), Vector2(s.x * 0.5, s.y - h), Vector2(0, s.y - h * 0.9)])
	draw_colored_polygon(top, steel)
	draw_colored_polygon(bot, steel)
	var edge := Color(NEON, 0.9 * (1.0 - open))
	draw_polyline(PackedVector2Array([top[4], top[3], top[2]]), edge, 3.0, true)
	draw_polyline(PackedVector2Array([bot[4], bot[3], bot[2]]), Color(PINK, 0.9 * (1.0 - open)), 3.0, true)

## With a clip playing, the clip carries the show; only the live facts are drawn over it.
func _draw_video_overlay(s: Vector2, safe: Rect2) -> void:
	var font := ThemeDB.fallback_font
	var band := Rect2(0, s.y - 96.0 - (s.y - safe.end.y), s.x, 96.0 + (s.y - safe.end.y))
	draw_rect(band, Color(0, 0, 0, 0.5))
	draw_line(band.position, band.position + Vector2(s.x, 0), Color(PINK, 0.8), 2.0)
	var x := safe.position.x + 20.0
	var y := band.position.y + 34.0
	draw_string(font, Vector2(x, y), _status, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, NEON)
	if target_name != "":
		draw_string(font, Vector2(x, y + 30.0), "LAUNCHING: " + target_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.9))
	if _freed_text != "":
		var fw := font.get_string_size(_freed_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(font, Vector2(safe.end.x - fw - 20.0, y), _freed_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, LIME)
	var bar_w := s.x - 2.0 * (safe.position.x + 20.0)
	var prog := clampf(_player.current_animation_position / maxf(0.1, _len), 0.0, 1.0)
	draw_rect(Rect2(safe.position.x + 20.0, band.end.y - 18.0 - (s.y - safe.end.y), bar_w, 4.0), Color(1, 1, 1, 0.15))
	draw_rect(Rect2(safe.position.x + 20.0, band.end.y - 18.0 - (s.y - safe.end.y), bar_w * prog, 4.0), NEON)
	MagicLight.draw_border(self, s, _clock, 0, 0.5, 4.0)
